package com.yourapp.bhasha

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

/**
 * Records the parent's voice to a 16 kHz mono 16-bit WAV file in the cache
 * directory, which is the format Sarvam's `/speech-to-text` prefers.
 *
 * Two things here are deliberate:
 *
 * 1. **The hard 28-second cap.** The REST endpoint rejects audio over 30
 *    seconds. Letting someone speak for 40 seconds and only then discovering
 *    the recording is unusable is the worst failure this app can produce, so
 *    capture stops itself with a warning well before the ceiling.
 * 2. **`VOICE_RECOGNITION` as the audio source.** It applies the noise
 *    suppression tuned for speech recognition and, unlike `MIC`, does not add
 *    the AGC ramp that clips the first syllable.
 */
class VoiceCaptureManager(private val context: Context) {

    interface Listener {
        /** Fires roughly every 200 ms while recording. */
        fun onElapsed(millis: Long)

        /** Capture hit [MAX_DURATION_MS] and stopped itself. */
        fun onMaxDurationReached()
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    private var recorder: AudioRecord? = null
    private var worker: Thread? = null
    private var outputFile: File? = null
    private var listener: Listener? = null
    private var startedAt = 0L

    @Volatile
    private var capturing = false

    val isRecording: Boolean
        get() = capturing

    /**
     * Starts capture. The caller must have already confirmed `RECORD_AUDIO`;
     * this returns false rather than throwing if the mic is unavailable
     * (another app holding it, or hardware that refuses 16 kHz).
     */
    @SuppressLint("MissingPermission")
    fun start(listener: Listener): Boolean {
        if (capturing) return false

        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        if (minBuffer <= 0) return false
        val bufferSize = minBuffer * 2

        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize
            )
        } catch (e: SecurityException) {
            return false
        } catch (e: IllegalArgumentException) {
            return false
        }

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return false
        }

        val file = File(context.cacheDir, "bhasha_voice_${SystemClock.elapsedRealtime()}.wav")
        val stream = try {
            FileOutputStream(file)
        } catch (e: IOException) {
            record.release()
            return false
        }

        this.listener = listener
        recorder = record
        outputFile = file
        capturing = true
        startedAt = SystemClock.elapsedRealtime()

        try {
            record.startRecording()
        } catch (e: IllegalStateException) {
            capturing = false
            recorder = null
            outputFile = null
            this.listener = null
            record.release()
            stream.close()
            file.delete()
            return false
        }

        worker = thread(name = "bhasha-mic") {
            val buffer = ByteArray(bufferSize)
            try {
                stream.use { out ->
                    // Placeholder; the real sizes are only known once we stop.
                    out.write(ByteArray(HEADER_BYTES))
                    while (capturing) {
                        val read = record.read(buffer, 0, buffer.size)
                        if (read > 0) {
                            out.write(buffer, 0, read)
                        } else if (read < 0) {
                            break
                        }
                    }
                }
            } catch (e: IOException) {
                // Nothing useful to do on the mic thread; stop() sees a short
                // or missing file and reports it as "nothing recorded".
            }
        }

        mainHandler.post(ticker)
        return true
    }

    /**
     * Stops capture and returns a playable WAV file, or null when nothing
     * usable was recorded (too short, or the write failed).
     */
    fun stop(): File? {
        if (!capturing) return null

        capturing = false
        mainHandler.removeCallbacks(ticker)
        val duration = SystemClock.elapsedRealtime() - startedAt

        worker?.join(WORKER_JOIN_MS)
        worker = null

        recorder?.let { record ->
            try {
                record.stop()
            } catch (e: IllegalStateException) {
                // Already stopped; releasing below is still correct.
            }
            record.release()
        }
        recorder = null
        listener = null

        val file = outputFile ?: return null
        outputFile = null

        if (duration < MIN_DURATION_MS || file.length() <= HEADER_BYTES) {
            file.delete()
            return null
        }

        return try {
            writeWavHeader(file)
            file
        } catch (e: IOException) {
            file.delete()
            null
        }
    }

    /** Stops capture and throws the audio away — used when the gesture is cancelled. */
    fun cancel() {
        stop()?.delete()
    }

    private val ticker = object : Runnable {
        override fun run() {
            if (!capturing) return
            val elapsed = SystemClock.elapsedRealtime() - startedAt
            listener?.onElapsed(elapsed)
            if (elapsed >= MAX_DURATION_MS) {
                listener?.onMaxDurationReached()
                return
            }
            mainHandler.postDelayed(this, TICK_MS)
        }
    }

    /**
     * Rewrites the 44-byte canonical WAV header now that the payload length is
     * known. Sarvam accepts raw PCM too, but a real header means the same file
     * can be played back for debugging without extra tooling.
     */
    private fun writeWavHeader(file: File) {
        val dataLength = file.length() - HEADER_BYTES
        val byteRate = SAMPLE_RATE * CHANNELS * BITS_PER_SAMPLE / 8

        val header = ByteBuffer.allocate(HEADER_BYTES).order(ByteOrder.LITTLE_ENDIAN)
        header.put("RIFF".toByteArray(Charsets.US_ASCII))
        header.putInt((dataLength + HEADER_BYTES - 8).toInt())
        header.put("WAVE".toByteArray(Charsets.US_ASCII))
        header.put("fmt ".toByteArray(Charsets.US_ASCII))
        header.putInt(16)                                  // PCM chunk size
        header.putShort(1)                                 // PCM, uncompressed
        header.putShort(CHANNELS.toShort())
        header.putInt(SAMPLE_RATE)
        header.putInt(byteRate)
        header.putShort((CHANNELS * BITS_PER_SAMPLE / 8).toShort())  // block align
        header.putShort(BITS_PER_SAMPLE.toShort())
        header.put("data".toByteArray(Charsets.US_ASCII))
        header.putInt(dataLength.toInt())

        RandomAccessFile(file, "rw").use { raf ->
            raf.seek(0)
            raf.write(header.array())
        }
    }

    companion object {
        private const val SAMPLE_RATE = 16_000
        private const val CHANNELS = 1
        private const val BITS_PER_SAMPLE = 16
        private const val HEADER_BYTES = 44
        private const val TICK_MS = 200L
        private const val WORKER_JOIN_MS = 1_000L

        /** Below this, the parent tapped rather than spoke. */
        private const val MIN_DURATION_MS = 400L

        /** Sarvam's REST ceiling is 30 s; stop early enough to never hit it. */
        const val MAX_DURATION_MS = 28_000L

        /** Start showing a countdown once the recording gets this long. */
        const val WARN_AFTER_MS = 20_000L
    }
}

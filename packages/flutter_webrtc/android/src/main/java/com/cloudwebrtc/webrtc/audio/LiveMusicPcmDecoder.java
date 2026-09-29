package com.cloudwebrtc.webrtc.audio;

import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.os.Build;
import android.util.Log;

import java.io.IOException;
import java.nio.ByteBuffer;

/**
 * Decode an audio file to PCM16 using MediaExtractor + MediaCodec.
 * This is intentionally minimal: it supports common AAC/MP3 type tracks.
 */
public class LiveMusicPcmDecoder {

    private static final String TAG = "LiveMusicPcmDecoder";

    public interface Callback {
        void onFormat(int sampleRate, int channelCount);
        void onPcmData(ByteBuffer pcm16LE);
        void onStopped();
        void onError(Exception e);
    }

    private Thread thread;
    private volatile boolean running = false;

    private final Object stateLock = new Object();
    private volatile boolean paused = false;
    private volatile boolean pendingSeek = false;
    private volatile long pendingSeekUs = 0;

    private volatile long durationUs = 0;
    private volatile long positionUs = 0;

    private volatile int sampleRate = 48000;
    private volatile int channels = 1;

    private volatile String currentFilePath;

    public long getDurationMs() {
        final long dUs = durationUs;
        if (dUs <= 0) return 0;
        return dUs / 1000;
    }

    public long getPositionMs() {
        final long pUs = positionUs;
        if (pUs <= 0) return 0;
        return pUs / 1000;
    }

    public void pause() {
        paused = true;
    }

    public void resume() {
        paused = false;
        synchronized (stateLock) {
            stateLock.notifyAll();
        }
    }

    public void seekToMs(long positionMs) {
        final long targetUs = Math.max(0, positionMs) * 1000L;
        pendingSeekUs = targetUs;
        pendingSeek = true;
        synchronized (stateLock) {
            stateLock.notifyAll();
        }
    }

    public void start(final String filePath, final Callback cb) {
        stop();
        running = true;
        paused = false;
        pendingSeek = false;
        pendingSeekUs = 0;
        durationUs = 0;
        positionUs = 0;
        currentFilePath = filePath;
        thread = new Thread(() -> {
            MediaExtractor extractor = null;
            MediaCodec codec = null;
            int audioTrackIndex = -1;
            MediaFormat format = null;
            try {
                extractor = new MediaExtractor();
                extractor.setDataSource(filePath);
                for (int i = 0; i < extractor.getTrackCount(); i++) {
                    MediaFormat f = extractor.getTrackFormat(i);
                    String mime = f.getString(MediaFormat.KEY_MIME);
                    if (mime != null && mime.startsWith("audio/")) {
                        audioTrackIndex = i;
                        format = f;
                        break;
                    }
                }
                if (audioTrackIndex < 0 || format == null) {
                    throw new IOException("No audio track found");
                }

                extractor.selectTrack(audioTrackIndex);

                if (format.containsKey(MediaFormat.KEY_DURATION)) {
                    // MediaFormat duration is in microseconds.
                    durationUs = format.getLong(MediaFormat.KEY_DURATION);
                }

                String mime = format.getString(MediaFormat.KEY_MIME);
                if (mime == null) {
                    throw new IOException("Audio mime is null");
                }

                codec = MediaCodec.createDecoderByType(mime);
                codec.configure(format, null, null, 0);
                codec.start();

                sampleRate = format.containsKey(MediaFormat.KEY_SAMPLE_RATE)
                        ? format.getInteger(MediaFormat.KEY_SAMPLE_RATE) : 48000;
                channels = format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)
                        ? format.getInteger(MediaFormat.KEY_CHANNEL_COUNT) : 1;
                cb.onFormat(sampleRate, channels);

                MediaCodec.BufferInfo info = new MediaCodec.BufferInfo();
                boolean inputDone = false;
                boolean outputDone = false;

                while (running && !outputDone) {
                    if (paused) {
                        synchronized (stateLock) {
                            while (running && paused && !pendingSeek) {
                                try {
                                    stateLock.wait(50);
                                } catch (InterruptedException ignored) {
                                }
                            }
                        }
                    }

                    if (pendingSeek) {
                        final long seekUs = pendingSeekUs;
                        pendingSeek = false;
                        positionUs = seekUs;

                        if (extractor != null) {
                            try {
                                extractor.seekTo(seekUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC);
                            } catch (Exception e) {
                                Log.e(TAG, "seekTo failed: " + e);
                            }
                        }

                        // Reset codec state so decode resumes from new extractor position.
                        if (codec != null) {
                            try {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                                    codec.flush();
                                }
                            } catch (Exception flushErr) {
                                Log.e(TAG, "codec.flush failed: " + flushErr);
                                try {
                                    codec.stop();
                                } catch (Exception ignored) {
                                }
                                try {
                                    codec.release();
                                } catch (Exception ignored) {
                                }
                                codec = MediaCodec.createDecoderByType(mime);
                                codec.configure(format, null, null, 0);
                                codec.start();
                            }
                        }

                        inputDone = false;
                        outputDone = false;
                    }

                    if (!running) {
                        break;
                    }

                    if (!inputDone) {
                        int inIndex = codec.dequeueInputBuffer(10_000);
                        if (inIndex >= 0) {
                            ByteBuffer inBuf = codec.getInputBuffer(inIndex);
                            if (inBuf == null) {
                                throw new IOException("Input buffer is null");
                            }
                            int sampleSize = extractor.readSampleData(inBuf, 0);
                            if (sampleSize < 0) {
                                codec.queueInputBuffer(inIndex, 0, 0, 0,
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM);
                                inputDone = true;
                            } else {
                                long ptsUs = extractor.getSampleTime();
                                if (ptsUs > 0) {
                                    positionUs = ptsUs;
                                }
                                codec.queueInputBuffer(inIndex, 0, sampleSize, ptsUs, 0);
                                extractor.advance();
                            }
                        }
                    }

                    int outIndex = codec.dequeueOutputBuffer(info, 10_000);
                    if (outIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        MediaFormat outFmt = codec.getOutputFormat();
                        if (outFmt.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                            sampleRate = outFmt.getInteger(MediaFormat.KEY_SAMPLE_RATE);
                        }
                        if (outFmt.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                            channels = outFmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT);
                        }
                        cb.onFormat(sampleRate, channels);
                    } else if (outIndex >= 0) {
                        ByteBuffer outBuf = codec.getOutputBuffer(outIndex);
                        if (outBuf != null && info.size > 0) {
                            outBuf.position(info.offset);
                            outBuf.limit(info.offset + info.size);
                            // Copy to a fresh buffer because codec buffer reused.
                            ByteBuffer pcm = ByteBuffer.allocateDirect(info.size);
                            pcm.put(outBuf);
                            pcm.flip();
                            if (!paused) {
                                cb.onPcmData(pcm);
                            }
                        }
                        codec.releaseOutputBuffer(outIndex, false);
                        if ((info.flags & MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            outputDone = true;
                        }
                    }
                }

                cb.onStopped();
            } catch (Exception e) {
                cb.onError(e);
            } finally {
                try {
                    if (extractor != null) {
                        extractor.release();
                    }
                } catch (Exception ignored) {}
                try {
                    if (codec != null) {
                        codec.stop();
                        codec.release();
                    }
                } catch (Exception ignored) {}
            }
        }, "LiveMusicPcmDecoder");
        thread.setDaemon(true);
        thread.start();
    }

    public void stop() {
        running = false;
        paused = false;
        pendingSeek = false;
        if (thread != null) {
            try {
                thread.join(300);
            } catch (InterruptedException ignored) {}
            thread = null;
        }
    }
}

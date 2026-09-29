package com.cloudwebrtc.webrtc.audio;

import android.util.Log;

import java.nio.ByteBuffer;

/**
 * Singleton controller to manage music decoding + mixing.
 */
public class LiveMusicMixController implements LiveMusicMixerProcessor.MusicProvider {

    private static final String TAG = "LiveMusicMix";

    private final PcmRingBuffer ringBuffer = new PcmRingBuffer(48000 * 2 * 5); // ~5s @ 48k stereo
    private final LiveMusicPcmDecoder decoder = new LiveMusicPcmDecoder();

    private volatile boolean enabled = false;
    private volatile float volume = 0.6f;
    private volatile float micVolume = 1.0f;

    private volatile int musicSampleRate = 48000;
    private volatile int musicChannels = 1;

    private volatile long lastStatsLogMs = 0;
    private volatile long totalWrittenSamples = 0;
    private volatile long totalReadSamples = 0;

    private final LiveMusicMixerProcessor processor;

    public LiveMusicMixController(AudioProcessingController apc) {
        processor = new LiveMusicMixerProcessor(this);
        apc.capturePostProcessing.addProcessor(processor);
    }

    public synchronized void start(String filePath, float volume) {
        this.volume = volume;
        enabled = true;
        ringBuffer.clear();
        totalWrittenSamples = 0;
        totalReadSamples = 0;
        Log.d(TAG, "start filePath=" + filePath + " volume=" + volume);
        decoder.start(filePath, new LiveMusicPcmDecoder.Callback() {
            @Override
            public void onFormat(int sampleRate, int channelCount) {
                musicSampleRate = sampleRate;
                musicChannels = channelCount;
                Log.d(TAG, "decoder format sampleRate=" + sampleRate + " channels=" + channelCount);
            }

            @Override
            public void onPcmData(ByteBuffer pcm16LE) {
                if (!enabled) return;
                final int wroteSamples = (pcm16LE.remaining() / 2);
                ringBuffer.writePcm16(pcm16LE);

                totalWrittenSamples += wroteSamples;
                final long nowMs = android.os.SystemClock.elapsedRealtime();
                if (nowMs - lastStatsLogMs > 1000) {
                    lastStatsLogMs = nowMs;
                    Log.d(TAG, "stats enabled=" + enabled +
                            " avail=" + ringBuffer.availableSamples() +
                            " cap=" + ringBuffer.capacitySamples() +
                            " written=" + totalWrittenSamples +
                            " read=" + totalReadSamples);
                }
            }

            @Override
            public void onStopped() {
                Log.d(TAG, "decoder stopped");
            }

            @Override
            public void onError(Exception e) {
                Log.e(TAG, "decoder error: " + e);
            }
        });
    }

    public synchronized void stop() {
        enabled = false;
        ringBuffer.clear();
        decoder.stop();
    }

    public synchronized void setVolume(float v) {
        this.volume = v;
    }

    public synchronized void setMicVolume(float v) {
        if (v < 0f) v = 0f;
        if (v > 1f) v = 1f;
        this.micVolume = v;
    }

    public synchronized void pause() {
        enabled = false;
        decoder.pause();
    }

    public synchronized void resume() {
        enabled = true;
        decoder.resume();
    }

    public synchronized void seekTo(int positionMs) {
        ringBuffer.clear();
        decoder.seekToMs(positionMs);
    }

    public long getPositionMs() {
        return decoder.getPositionMs();
    }

    public long getDurationMs() {
        return decoder.getDurationMs();
    }

    @Override
    public int getSampleRate() {
        return musicSampleRate;
    }

    @Override
    public int getChannelCount() {
        return musicChannels;
    }

    @Override
    public float getVolume() {
        return volume;
    }

    @Override
    public float getMicVolume() {
        return micVolume;
    }

    @Override
    public int readMusicSamples(short[] out, int offset, int samples) {
        int n = ringBuffer.read(out, offset, samples);
        totalReadSamples += n;
        return n;
    }

    @Override
    public boolean isEnabled() {
        return enabled;
    }
}

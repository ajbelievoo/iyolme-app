package com.cloudwebrtc.webrtc.audio;

import android.util.Log;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/**
 * Mixes decoded music PCM16 into microphone PCM16 in-place.
 */
public class LiveMusicMixerProcessor implements AudioProcessingAdapter.ExternalAudioFrameProcessing {

    public interface MusicProvider {
        int getSampleRate();
        int getChannelCount();
        float getVolume();
        float getMicVolume();
        int readMusicSamples(short[] out, int offset, int samples);
        boolean isEnabled();
    }

    private int sampleRateHz;
    private int numChannels;
    private final MusicProvider provider;

    // temp buffer for pulling from ring buffer
    private short[] musicTmp = new short[0];

    // buffered music samples (interleaved by provider.getChannelCount())
    private short[] musicBuf = new short[0];
    private int musicBufLen = 0;
    private int musicBufPos = 0;
    private double musicPhaseFrames = 0.0;

    private static final String TAG = "LiveMusicMixer";
    private long lastProcessLogMs = 0;
    private long lastBufferLogMs = 0;
    private long lastLevelLogMs = 0;

    public LiveMusicMixerProcessor(MusicProvider provider) {
        this.provider = provider;
    }

    @Override
    public void initialize(int sampleRateHz, int numChannels) {
        this.sampleRateHz = sampleRateHz;
        this.numChannels = numChannels;
    }

    @Override
    public void reset(int newRate) {
        this.sampleRateHz = newRate;
    }

    @Override
    public void process(int numBands, int numFrames, ByteBuffer buffer) {
        if (!provider.isEnabled()) return;

        if (sampleRateHz <= 0 || numChannels <= 0) return;

        final int musicRate = provider.getSampleRate();
        final int musicCh = provider.getChannelCount();
        if (musicRate <= 0 || musicCh <= 0) return;

        final long nowMs = android.os.SystemClock.elapsedRealtime();
        if (nowMs - lastProcessLogMs > 1000) {
            lastProcessLogMs = nowMs;
            Log.d(TAG, "process() captureRate=" + sampleRateHz +
                    " captureCh=" + numChannels +
                    " musicRate=" + musicRate +
                    " musicCh=" + musicCh +
                    " enabled=" + provider.isEnabled());
        }

        buffer.order(ByteOrder.LITTLE_ENDIAN);
        int samples = buffer.remaining() / 2;
        if (samples <= 0) return;

        final int outChannels = Math.max(1, numChannels);
        final int outFrames = samples / outChannels;
        if (outFrames <= 0) return;

        final double step = (double) musicRate / (double) sampleRateHz;
        final int needInFrames = (int) Math.ceil(musicPhaseFrames + step * (outFrames + 2)) + 2;
        final int needInSamples = needInFrames * musicCh;

        // Ensure musicBuf has enough samples.
        if (musicBufPos > 0 && musicBufLen > musicBufPos) {
            final int remain = musicBufLen - musicBufPos;
            System.arraycopy(musicBuf, musicBufPos, musicBuf, 0, remain);
            musicBufLen = remain;
            musicBufPos = 0;
        } else if (musicBufPos > 0) {
            musicBufLen = 0;
            musicBufPos = 0;
        }

        if (musicBuf.length < needInSamples) {
            musicBuf = new short[Math.max(needInSamples, musicBuf.length * 2 + 1024)];
            musicBufLen = 0;
            musicBufPos = 0;
        }

        while (musicBufLen < needInSamples) {
            int read = provider.readMusicSamples(musicBuf, musicBufLen, musicBuf.length - musicBufLen);
            if (read <= 0) break;
            musicBufLen += read;
        }

        if (nowMs - lastBufferLogMs > 1000) {
            lastBufferLogMs = nowMs;
            Log.d(TAG, "buffer musicBufLen=" + musicBufLen + " musicBufPos=" + musicBufPos + " needInSamples=" + needInSamples);
        }

        if (musicTmp.length < samples) {
            musicTmp = new short[samples];
        }

        // Build resampled + channel-mapped music into musicTmp (same layout as mic buffer).
        int availableInFrames = (musicBufLen / musicCh);
        for (int f = 0; f < outFrames; f++) {
            final double pos = musicPhaseFrames + step * f;
            final int base = (int) pos;
            final double frac = pos - base;

            if (base + 1 >= availableInFrames) {
                // Not enough data: output silence
                for (int c = 0; c < outChannels; c++) {
                    musicTmp[f * outChannels + c] = 0;
                }
                continue;
            }

            if (musicCh == 1) {
                final int s0 = musicBuf[base] ;
                final int s1 = musicBuf[base + 1];
                final int v = (int) Math.round(s0 + (s1 - s0) * frac);
                final short out = (short) v;
                for (int c = 0; c < outChannels; c++) {
                    musicTmp[f * outChannels + c] = out;
                }
            } else {
                // use first two channels for stereo mapping
                final int baseIdx0 = base * musicCh;
                final int baseIdx1 = (base + 1) * musicCh;

                final int l0 = musicBuf[baseIdx0];
                final int r0 = musicBuf[baseIdx0 + 1];
                final int l1 = musicBuf[baseIdx1];
                final int r1 = musicBuf[baseIdx1 + 1];

                final int l = (int) Math.round(l0 + (l1 - l0) * frac);
                final int r = (int) Math.round(r0 + (r1 - r0) * frac);

                if (outChannels == 1) {
                    musicTmp[f] = (short) ((l + r) / 2);
                } else {
                    musicTmp[f * outChannels] = (short) l;
                    musicTmp[f * outChannels + 1] = (short) r;
                    for (int c = 2; c < outChannels; c++) {
                        musicTmp[f * outChannels + c] = 0;
                    }
                }
            }
        }

        // Advance phase & consume input frames.
        musicPhaseFrames += step * outFrames;
        final int consumeFrames = (int) musicPhaseFrames;
        if (consumeFrames > 0) {
            musicBufPos += consumeFrames * musicCh;
            if (musicBufPos > 0 && musicBufPos <= musicBufLen) {
                // compact next call
            }
            musicPhaseFrames -= consumeFrames;
        }

        float vol = provider.getVolume();
        float micVol = provider.getMicVolume();

        // Mix in-place.
        int micPeak = 0;
        int musPeak = 0;
        int mixPeak = 0;
        for (int i = 0; i < samples; i++) {
            int mic = buffer.getShort(i * 2);
            int mus = musicTmp[i];
            int mixed = (int) (mic * micVol) + (int) (mus * vol);
            if (mixed > Short.MAX_VALUE) mixed = Short.MAX_VALUE;
            if (mixed < Short.MIN_VALUE) mixed = Short.MIN_VALUE;
            buffer.putShort(i * 2, (short) mixed);

            int am = mic < 0 ? -mic : mic;
            int au = mus < 0 ? -mus : mus;
            int ax = mixed < 0 ? -mixed : mixed;
            if (am > micPeak) micPeak = am;
            if (au > musPeak) musPeak = au;
            if (ax > mixPeak) mixPeak = ax;
        }

        if (nowMs - lastLevelLogMs > 1000) {
            lastLevelLogMs = nowMs;
            Log.d(TAG, "levels micPeak=" + micPeak + " musPeak=" + musPeak + " mixPeak=" + mixPeak +
                    " micVol=" + micVol + " musicVol=" + vol);
        }
    }
}

package com.cloudwebrtc.webrtc.audio;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/**
 * Simple thread-safe PCM16 ring buffer (interleaved).
 */
public class PcmRingBuffer {
    private final short[] buffer;
    private int writePos = 0;
    private int readPos = 0;
    private int size = 0;

    public PcmRingBuffer(int capacitySamples) {
        this.buffer = new short[capacitySamples];
    }

    public synchronized void clear() {
        writePos = 0;
        readPos = 0;
        size = 0;
        notifyAll();
    }

    public synchronized int availableSamples() {
        return size;
    }

    public int capacitySamples() {
        return buffer.length;
    }

    public synchronized void writePcm16(ByteBuffer pcmBytesLE) {
        pcmBytesLE.order(ByteOrder.LITTLE_ENDIAN);
        int samples = pcmBytesLE.remaining() / 2;
        for (int i = 0; i < samples; i++) {
            while (size == buffer.length) {
                try {
                    wait(20);
                } catch (InterruptedException ignored) {
                    return;
                }
            }
            short v = pcmBytesLE.getShort();
            buffer[writePos] = v;
            writePos = (writePos + 1) % buffer.length;
            size++;
        }
    }

    public synchronized int read(short[] out, int offset, int maxSamples) {
        int n = Math.min(maxSamples, size);
        for (int i = 0; i < n; i++) {
            out[offset + i] = buffer[readPos];
            readPos = (readPos + 1) % buffer.length;
        }
        size -= n;
        if (n > 0) {
            notifyAll();
        }
        return n;
    }
}

package com.cloudwebrtc.webrtc.video;

import android.content.Context;
import android.media.Image;
import android.graphics.Bitmap;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.webrtc.JavaI420Buffer;
import org.webrtc.VideoFrame;

import java.io.Closeable;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.TimeUnit;

import ai.deepar.ar.AREventListener;
import ai.deepar.ar.DeepAR;
import ai.deepar.ar.DeepARImageFormat;

public final class DeepArProcessor implements LocalVideoTrack.ExternalVideoFrameProcessing, Closeable, AREventListener {
  private final Context appContext;
  private final Object initLock = new Object();
  private final ArrayBlockingQueue<VideoFrame> outQueue = new ArrayBlockingQueue<>(1);

  private volatile boolean enabled = true;
  private volatile boolean initialized = false;

  private volatile String licenseKey = "";
  private volatile String effectPath = "";
  private volatile String filterPath = "";
  private volatile boolean mirror = true;
  
  private Map<String, Object> cachedParams = null;

  private DeepAR deepAR;
  private int inWidth = 0;
  private int inHeight = 0;
  private ByteBuffer inBuffer;
  private volatile String loadedEffectPath = "";
  private volatile String loadedFilterPath = "";

  public DeepArProcessor(@NonNull Context context, @Nullable Map<String, Object> params) {
    this.appContext = context.getApplicationContext();
    updateParams(params);
  }

  public void updateParams(@Nullable Map<String, Object> params) {
    if (params == null) return;
    this.cachedParams = params;
    
    final Object k = params.get("token");
    if (k instanceof String) licenseKey = ((String) k).trim();
    final Object e = params.get("effectPath");
    if (e instanceof String) effectPath = ((String) e).trim();
    final Object f = params.get("filterPath");
    if (f instanceof String) filterPath = ((String) f).trim();
    final Object m = params.get("mirror");
    if (m instanceof Boolean) mirror = (Boolean) m;
    
    if (initialized && deepAR != null) {
        applyBeautyParams(params);
    }
  }

  private void applyBeautyParams(Map<String, Object> params) {
      try {
          // Beauty Parameters
          if (params.containsKey("smooth")) {
              deepAR.changeParameterFloat("Beauty", "Beauty", "strength", getFloat(params.get("smooth")));
          }
          if (params.containsKey("brighten")) {
              deepAR.changeParameterFloat("Beauty", "Beauty", "whiten", getFloat(params.get("brighten")));
          }
          if (params.containsKey("sharpen")) {
              deepAR.changeParameterFloat("Beauty", "Beauty", "sharpen", getFloat(params.get("sharpen")));
          }
          if (params.containsKey("eyeSize")) {
              deepAR.changeParameterFloat("FaceMorph", "FaceMorph", "eye_size", getFloat(params.get("eyeSize")));
          }
          if (params.containsKey("faceShape")) {
              deepAR.changeParameterFloat("FaceMorph", "FaceMorph", "face_shape", getFloat(params.get("faceShape")));
          }
          if (params.containsKey("noseSize")) {
              deepAR.changeParameterFloat("FaceMorph", "FaceMorph", "nose_size", getFloat(params.get("noseSize")));
          }
          if (params.containsKey("chinSize")) {
              deepAR.changeParameterFloat("FaceMorph", "FaceMorph", "chin_size", getFloat(params.get("chinSize")));
          }
          if (params.containsKey("mouthPos")) {
              deepAR.changeParameterFloat("FaceMorph", "FaceMorph", "mouth_pos", getFloat(params.get("mouthPos")));
          }

          // Makeup Parameters
          if (params.containsKey("makeup")) {
              Map<String, Object> makeup = (Map<String, Object>) params.get("makeup");
              if (makeup != null) {
                  if (makeup.containsKey("lips")) deepAR.changeParameterFloat("Makeup", "Makeup", "lips", getFloat(makeup.get("lips")));
                  if (makeup.containsKey("blush")) deepAR.changeParameterFloat("Makeup", "Makeup", "blush", getFloat(makeup.get("blush")));
                  if (makeup.containsKey("foundation")) deepAR.changeParameterFloat("Makeup", "Makeup", "foundation", getFloat(makeup.get("foundation")));
                  if (makeup.containsKey("eyeshadow")) deepAR.changeParameterFloat("Makeup", "Makeup", "eyeshadow", getFloat(makeup.get("eyeshadow")));
                  if (makeup.containsKey("eyelashes")) deepAR.changeParameterFloat("Makeup", "Makeup", "eyelashes", getFloat(makeup.get("eyelashes")));
                  if (makeup.containsKey("eyebrows")) deepAR.changeParameterFloat("Makeup", "Makeup", "eyebrows", getFloat(makeup.get("eyebrows")));

                  if (makeup.containsKey("hair")) {
                      Map<String, Object> hair = (Map<String, Object>) makeup.get("hair");
                      if (hair != null) {
                          if (hair.containsKey("strength")) {
                              deepAR.changeParameterFloat("Hair", "Hair", "strength", getFloat(hair.get("strength")));
                          }
                          if (hair.containsKey("color")) {
                              List<?> colorList = (List<?>) hair.get("color");
                              if (colorList != null && colorList.size() >= 3) {
                                  float r = getFloat(colorList.get(0));
                                  float g = getFloat(colorList.get(1));
                                  float b = getFloat(colorList.get(2));
                                  deepAR.changeParameterVec3("Hair", "Hair", "color", r, g, b);
                              }
                          }
                      }
                  }
              }
          }
      } catch (Exception e) {
          // Ignore errors during parameter application
      }
  }

  private float getFloat(Object o) {
      if (o instanceof Number) return ((Number) o).floatValue();
      return 0f;
  }

  private void ensureInit(int width, int height) {
    if (initialized) return;
    synchronized (initLock) {
      if (initialized) return;
      if (licenseKey == null || licenseKey.isEmpty()) return;

      try {
        deepAR = new DeepAR(appContext);
        deepAR.setLicenseKey(licenseKey);
        deepAR.initialize(appContext, this);
        deepAR.changeLiveMode(true);
        deepAR.setOffscreenRendering(width, height);
        inWidth = width;
        inHeight = height;
        inBuffer = ByteBuffer.allocateDirect(width * height * 3 / 2);
        inBuffer.order(ByteOrder.nativeOrder());

        loadedEffectPath = effectPath != null ? effectPath : "";
        if (!loadedEffectPath.isEmpty()) {
          deepAR.switchEffect("mask", loadedEffectPath);
        } else {
          deepAR.switchEffect("mask", "");
        }

        loadedFilterPath = filterPath != null ? filterPath : "";
        if (!loadedFilterPath.isEmpty()) {
          deepAR.switchEffect("filters", loadedFilterPath);
        } else {
          deepAR.switchEffect("filters", "");
        }

        initialized = true;
        if (cachedParams != null) {
            applyBeautyParams(cachedParams);
        }
      } catch (Throwable t) {
        initialized = false;
      }
    }
  }

  @Override
  @Nullable
  public VideoFrame onFrame(@NonNull VideoFrame frame) {
    if (!enabled) return frame;
    final VideoFrame.I420Buffer i420 = frame.getBuffer().toI420();
    final int w = i420.getWidth();
    final int h = i420.getHeight();
    ensureInit(w, h);
    if (!initialized || deepAR == null) {
      i420.release();
      return frame;
    }

    try {
      if (w != inWidth || h != inHeight) {
        // DeepAR offscreen target is fixed; recreate for new size.
        deepAR.setOffscreenRendering(w, h);
        inWidth = w;
        inHeight = h;
        inBuffer = ByteBuffer.allocateDirect(w * h * 3 / 2);
        inBuffer.order(ByteOrder.nativeOrder());
      }

      final String currentEffect = effectPath != null ? effectPath : "";
      if (!currentEffect.equals(loadedEffectPath)) {
        loadedEffectPath = currentEffect;
        deepAR.switchEffect("mask", loadedEffectPath);
      }

      final String currentFilter = filterPath != null ? filterPath : "";
      if (!currentFilter.equals(loadedFilterPath)) {
        loadedFilterPath = currentFilter;
        deepAR.switchEffect("filters", loadedFilterPath);
      }

      if (inBuffer == null || inBuffer.capacity() < (w * h * 3 / 2)) {
        inBuffer = ByteBuffer.allocateDirect(w * h * 3 / 2);
        inBuffer.order(ByteOrder.nativeOrder());
      }
      inBuffer.position(0);

      copyPlaneCompact(i420.getDataY(), i420.getStrideY(), inBuffer, w, h);
      copyPlaneCompact(i420.getDataV(), i420.getStrideV(), inBuffer, (w + 1) / 2, (h + 1) / 2);
      copyPlaneCompact(i420.getDataU(), i420.getStrideU(), inBuffer, (w + 1) / 2, (h + 1) / 2);
      inBuffer.position(0);

      i420.release();

      deepAR.receiveFrame(
          inBuffer,
          w,
          h,
          frame.getRotation(),
          mirror,
          DeepARImageFormat.YUV_420_888,
          1
      );

      final VideoFrame out = outQueue.poll(35, TimeUnit.MILLISECONDS);
      return out != null ? out : frame;
    } catch (Throwable t) {
      i420.release();
      return frame;
    }
  }

  private static void copyPlaneCompact(
      @NonNull ByteBuffer src,
      int srcStride,
      @NonNull ByteBuffer dst,
      int width,
      int height
  ) {
    final ByteBuffer srcDup = src.duplicate();
    for (int row = 0; row < height; row++) {
      final int srcPos = row * srcStride;
      srcDup.position(srcPos);
      srcDup.limit(srcPos + width);
      dst.put(srcDup);
      srcDup.clear();
    }
  }

  @Override
  public void frameAvailable(Image image) {
    if (image == null) return;
    try {
      final int width = image.getWidth();
      final int height = image.getHeight();
      final Image.Plane[] planes = image.getPlanes();
      if (planes == null || planes.length < 3) {
        image.close();
        return;
      }

      final JavaI420Buffer out = JavaI420Buffer.allocate(width, height);

      // Y
      copyYuvPlaneToI420(
          planes[0].getBuffer(),
          planes[0].getRowStride(),
          planes[0].getPixelStride(),
          out.getDataY(),
          out.getStrideY(),
          width,
          height
      );
      // U
      copyYuvPlaneToI420(
          planes[1].getBuffer(),
          planes[1].getRowStride(),
          planes[1].getPixelStride(),
          out.getDataU(),
          out.getStrideU(),
          (width + 1) / 2,
          (height + 1) / 2
      );
      // V
      copyYuvPlaneToI420(
          planes[2].getBuffer(),
          planes[2].getRowStride(),
          planes[2].getPixelStride(),
          out.getDataV(),
          out.getStrideV(),
          (width + 1) / 2,
          (height + 1) / 2
      );

      final VideoFrame vf = new VideoFrame(out, 0, System.nanoTime());
      final VideoFrame prev = outQueue.poll();
      if (prev != null) prev.release();
      outQueue.offer(vf);
    } catch (Throwable ignored) {
    } finally {
      try {
        image.close();
      } catch (Throwable ignored2) {}
    }
  }

  private static void copyYuvPlaneToI420(
      @NonNull ByteBuffer src,
      int srcRowStride,
      int srcPixelStride,
      @NonNull ByteBuffer dst,
      int dstRowStride,
      int width,
      int height
  ) {
    final ByteBuffer srcDup = src.duplicate();
    final ByteBuffer dstDup = dst.duplicate();
    for (int row = 0; row < height; row++) {
      final int srcRowStart = row * srcRowStride;
      final int dstRowStart = row * dstRowStride;
      for (int col = 0; col < width; col++) {
        final int srcIndex = srcRowStart + col * srcPixelStride;
        final int dstIndex = dstRowStart + col;
        dstDup.put(dstIndex, srcDup.get(srcIndex));
      }
    }
  }

  @Override
  public void screenshotTaken(Bitmap bitmap) {}

  @Override
  public void initialized() {}

  @Override
  public void shutdownFinished() {}

  @Override
  public void error(ai.deepar.ar.ARErrorType arErrorType, String s) {}

  @Override
  public void effectSwitched(String s) {}

  @Override
  public void faceVisibilityChanged(boolean b) {}

  @Override
  public void imageVisibilityChanged(String s, boolean b) {}

  @Override
  public void videoRecordingStarted() {}

  @Override
  public void videoRecordingFailed() {}

  @Override
  public void videoRecordingFinished() {}

  @Override
  public void videoRecordingPrepared() {}

  @Override
  public void close() {
    enabled = false;
    initialized = false;
    final VideoFrame prev = outQueue.poll();
    if (prev != null) prev.release();
    try {
      if (deepAR != null) deepAR.release();
    } catch (Throwable ignored) {}
    deepAR = null;
  }
}

package com.deepar.ai;

import android.app.Activity;

import ai.deepar.ar.CameraResolutionPreset;
import ai.deepar.ar.DeepAR;
import io.flutter.plugin.common.MethodChannel;

/**
 * SafeCameraXHandler extends {@link CameraXHandler} and additionally keeps a
 * reference to the plugin's main MethodChannel so camera lifecycle events can
 * be forwarded back to Dart when needed.
 */
public class SafeCameraXHandler extends CameraXHandler {

    private final MethodChannel channel;

    SafeCameraXHandler(Activity activity,
                       long textureId,
                       DeepAR deepAR,
                       CameraResolutionPreset cameraResolutionPreset,
                       MethodChannel channel) {
        super(activity, textureId, deepAR, cameraResolutionPreset);
        this.channel = channel;
    }
}

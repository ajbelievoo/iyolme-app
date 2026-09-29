-keep class com.sun.jna.* { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }

# Firebase / Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Flutter framework
-keep class io.flutter.** { *; }

# AndroidX WorkManager (used by messaging/background tasks)
-keep class androidx.work.** { *; }

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# DeepAR SDK — native lib calls Java methods via JNI (playSound/stopSound etc.)
-keep class ai.deepar.** { *; }
-keepclassmembers class ai.deepar.** { *; }
-dontwarn ai.deepar.**

# Payments SDKs (avoid release-only crashes from R8 stripping)
-keep class com.stripe.** { *; }
-dontwarn com.stripe.**
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keep class com.cashfree.** { *; }
-dontwarn com.cashfree.**

# Keep service entry points and annotations
-keepattributes *Annotation*

# Suppress warnings for optional / compile-time only dependencies that may be referenced by transitive libs
-dontwarn com.google.android.play.core.**
-dontwarn com.google.devtools.build.android.desugar.runtime.**
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.sun.jna.**
-dontwarn java.awt.**
-dontwarn javax.lang.model.**
-dontwarn autovalue.shaded.**

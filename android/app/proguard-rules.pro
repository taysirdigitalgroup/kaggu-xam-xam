# AdMob / Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# just_audio
-keep class com.ryanheise.** { *; }
-keep class androidx.media.** { *; }

# Dio / OkHttp
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Crypto
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**

# General
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

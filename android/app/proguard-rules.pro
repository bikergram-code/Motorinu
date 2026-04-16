# ──────────────────────────────────────────────────────────────────────────────
#  Motorinu ProGuard/R8 Regeln
# ──────────────────────────────────────────────────────────────────────────────

# Stripe
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivity$g
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Args
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter$Error
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningActivityStarter
-dontwarn com.stripe.android.pushProvisioning.PushProvisioningEphemeralKeyProvider
-keep class com.stripe.** { *; }

# Vosk speech recognition (JNA)
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.** { public *; }
-dontwarn java.awt.**

# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase / FCM
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Supabase / GoTrue / Realtime (Kotlin coroutines + reflection)
-keepattributes Signature,InnerClasses,EnclosingMethod,Exceptions
-keepattributes *Annotation*
-keep class kotlinx.serialization.** { *; }
-keep class kotlinx.coroutines.** { *; }
-keepclassmembers class kotlinx.serialization.** { *; }

# Mapbox + MapLibre
-keep class com.mapbox.** { *; }
-keep class org.maplibre.** { *; }
-dontwarn com.mapbox.**
-dontwarn org.maplibre.**

# LiveKit / WebRTC
-keep class io.livekit.** { *; }
-keep class org.webrtc.** { *; }
-dontwarn io.livekit.**
-dontwarn org.webrtc.**

# Google ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.odml.** { *; }
-dontwarn com.google.mlkit.**

# Android Auto / AAOS
-keep class androidx.car.app.** { *; }
-keep class androidx.car.** { *; }
-dontwarn androidx.car.app.**

# media_kit (libmpv)
-keep class com.alexmercerind.** { *; }
-keep class media_kit_** { *; }
-dontwarn com.alexmercerind.**

# OkHttp / Retrofit (falls verwendet)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Generelle Flutter-Plugin-Schutzregel
-keep class * implements io.flutter.plugin.common.MethodChannel$MethodCallHandler { *; }
-keep class * extends io.flutter.plugin.common.EventChannel$StreamHandler { *; }

# JSON / GSON (falls verwendet)
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Play Core (Deferred Components — verhindert R8-Fehler bei google_mlkit)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Apache Tika / javax.xml.stream — transitive dep (file_picker / video_compress)
# R8 kann diese Klassen im normalen Android SDK nicht finden
-dontwarn javax.xml.stream.**
-dontwarn javax.xml.stream.XMLStreamException
-dontwarn javax.xml.stream.XMLOutputFactory
-dontwarn javax.xml.stream.XMLEventFactory
-dontwarn javax.xml.stream.XMLInputFactory
-dontwarn org.apache.tika.**
-dontwarn org.apache.commons.**

# Stripe PushProvisioning (weitere veraltete Klassen)
-dontwarn com.google.android.datatransport.**
-dontwarn com.google.common.reflect.**

# Globale Warnung-Unterdrueckung als Safety Net — falls R8 full mode
# doch irgendwo noch aktiv ist (z.B. via Plugin-Override)
-ignorewarnings

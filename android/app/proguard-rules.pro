# --- MediaPipe Tasks GenAI (LLM Inference) ---
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**

# AutoValue: referenciado por los Builder de opciones de MediaPipe.
-dontwarn com.google.auto.value.**
-keep class com.google.auto.value.** { *; }

# Protobuf (usado por los settings del modelo LLM).
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# Clases JNI generadas (no renombrar; el código nativo las busca por nombre).
-keepclasseswithmembernames class * {
    native <methods>;
}

# NanoHTTPD (servidor OpenAI local).
-keep class fi.iki.elonen.** { *; }
-dontwarn fi.iki.elonen.**

# Misc que a veces arrastran las libs de Google.
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

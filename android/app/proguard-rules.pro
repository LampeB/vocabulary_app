# Vosk / JNA — the native bridge resolves Java fields BY NAME at runtime
# (com.sun.jna.Pointer.peer etc.). R8 renaming them crashes the app with
# "UnsatisfiedLinkError: Can't obtain peer field ID" the moment a model
# loads (field crash log 2026-07-08, hands-free quiz start).
-keep class com.sun.jna.** { *; }
-keep class org.vosk.** { *; }
-dontwarn java.awt.*

# flutter_local_notifications — gson TypeToken generics are resolved via
# reflection; R8 stripping the Signature attribute crashes the boot
# receiver with "RuntimeException: Missing type parameter" (same crash
# log, entries at boot).
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

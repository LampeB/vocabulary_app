# flutter_local_notifications — gson TypeToken generics are resolved via
# reflection; R8 stripping the Signature attribute crashes the boot
# receiver with "RuntimeException: Missing type parameter" (same crash
# log, entries at boot).
-keepattributes Signature
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

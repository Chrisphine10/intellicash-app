# Flutter release (R8) keep rules.
# The Flutter Gradle plugin already injects engine rules; these are defensive
# keeps for plugins that use reflection / platform channels.

# Flutter engine + embedding
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# sqflite
-keep class com.tekartik.sqflite.** { *; }

# flutter_secure_storage (uses Android Keystore)
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Keep annotations and generic signatures (reflection-friendly)
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

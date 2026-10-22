# Flutter / plugins
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**
# Play Core (deferred components) referenced by the Flutter embedding
-dontwarn com.google.android.play.core.**
# Google Sign-In / credentials
-keep class com.google.android.gms.** { *; }
# Keep annotations & generic signatures used by reflection-based plugins
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod

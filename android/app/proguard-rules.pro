# Flutter-specific rules
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.util.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keep class com.google.android.play.** { *; }
-keepclassmembers class com.google.android.play.** { *; }
-dontwarn com.google.android.play.**

# Firebase-specific rules
-dontwarn com.google.firebase.messaging.**
-keepattributes *Annotation*
-keepclassmembers class * {
    @com.google.firebase.annotations.PublicApi <methods>;
}
-keepclassmembers class * {
    @com.google.firebase.annotations.PublicApi <fields>;
}

# Prevent obfuscation of Google Play services classes
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Preserve your own classes
-keep class com.quiz_commercial2024.** { *; }

# General rules to avoid stripping essential classes
-keep class * extends android.app.Application { *; }
-keepclassmembers enum * { *; }
-keepclassmembers class ** {
    native <methods>;
}
-dontwarn javax.annotation.**


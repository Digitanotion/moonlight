# SLF4J + Pusher keep/silence (safe)
-dontwarn org.slf4j.**
-keep class org.slf4j.** { *; }

# Pusher client classes (defensive)
-dontwarn com.pusher.**
-keep class com.pusher.** { *; }

# Tenjin SDK
-keep class com.tenjin.** { *; }
-keep public class com.google.android.gms.ads.identifier.** { *; }
-keep public class com.google.android.gms.common.** { *; }
-keep public class com.android.installreferrer.** { *; }
-keepattributes *Annotation*
# SLF4J + Pusher keep/silence (safe)
-dontwarn org.slf4j.**
-keep class org.slf4j.** { *; }

# Pusher client classes (defensive)
-dontwarn com.pusher.**
-keep class com.pusher.** { *; }

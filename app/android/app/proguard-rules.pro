# Flutter's engine resolves these reflectively.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_local_notifications deserialises scheduled notifications with Gson,
# so its model classes must survive shrinking or reminders silently stop firing
# after a reboot.
-keep class com.dexterous.** { *; }
-keepattributes *Annotation*
-keepattributes Signature

# The Flutter embedding references Play Core's deferred-component API, which is
# only present when an app actually splits itself into dynamic features. This
# app does not, so R8 sees the references as dangling. Silencing them is the
# documented resolution, not a workaround.
-dontwarn com.google.android.play.core.**

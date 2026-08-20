# ML Kit's text recognizer dispatches over every script the plugin supports, so
# R8 sees references to recognizers this app never bundles: the OCR decision is
# Latin only (ticket 017).
#
# One line per unused script rather than a `vision.text.**` wildcard — a wildcard
# would also silence missing classes of the Latin recognizer, which is the one
# whose absence has to be loud.
# The recognizer reaches its own task and handler machinery reflectively, so R8
# renaming it leaves the native call returning null — release fails while debug
# works (ticket 034). Keeping the plugin packages too: they are the Dart-facing
# entry point and equally reflective.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.odml.** { *; }
-keep class com.google_mlkit_commons.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }

-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

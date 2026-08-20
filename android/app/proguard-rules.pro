# ML Kit's text recognizer dispatches over every script the plugin supports, so
# R8 sees references to recognizers this app never bundles: the OCR decision is
# Latin only (ticket 017).
#
# One line per unused script rather than a `vision.text.**` wildcard — a wildcard
# would also silence missing classes of the Latin recognizer, which is the one
# whose absence has to be loud.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# R8 rules for the release build.
#
# Keep this file SMALL. Every broad `-keep class x.** { *; }` switches off renaming (and
# shrinking) for that whole package. Google Play's "DEX code optimisation" check counts how
# much of the DEX is renamed; blanket keeps for Firebase, Play Services and Flutter held it at
# 19% (Play wants at least 25%). Flutter, the Firebase/Play Services libraries and the Flutter
# plugins ship their own consumer rules inside their AARs, so none of them needs a rule here.
# Add a rule only after a release build fails or crashes without it, and keep it narrow.

# Readable Java/Kotlin stack traces. Play and Crashlytics map the renamed frames back using
# the mapping file; the source file attribute is hidden behind a constant name.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# flutter_local_notifications stores its notification objects as JSON with Gson, which reads
# generic types and fields by reflection.
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# Missing-class warnings that R8 reports as errors for optional classes the libraries reference.
-dontwarn javax.annotation.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**

# Play Core (deferred components): Flutter references it but this app does not use it.
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

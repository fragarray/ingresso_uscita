# Regole ProGuard per ottimizzazione release Android

# Keep Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep models (per serializzazione JSON)
-keep class com.fragarray.ingresso_uscita.models.** { *; }

# Mantieni stacktrace leggibili
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Ottimizzazioni generali
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

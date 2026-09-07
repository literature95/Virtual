# Flutter 混淆规则
# 保持 Flutter 引擎类不被混淆
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# ObjectBox
-keep class io.objectbox.** { *; }
-dontwarn io.objectbox.**

# QuickJS
-keep class com.fastdev.quickjs.** { *; }
-dontwarn com.fastdev.quickjs.**

# 序列化模型
-keep class app.bitbear.tav.** { *; }

# mobile_scanner
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# audio_session
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# webview_flutter
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# Google Play Core (deferred components - not used but referenced by Flutter engine)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
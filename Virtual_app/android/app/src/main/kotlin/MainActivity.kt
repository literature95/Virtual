package app.bitbear.virtual

import android.os.Handler
import android.os.Looper
import android.os.StatFs
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 内置模型（GGUF）安装桥。
 *
 * APK 里以 stored（不压缩）方式携带 `assets/models` 下的 .gguf 文件（见 app/build.gradle
 * 的 androidResources.noCompress）。首次使用时把它流式复制到应用私有目录，
 * 之后按「文件存在且大小正确」幂等跳过。
 *
 * 之所以放在原生侧而不是 Dart 的 rootBundle：单文件约 532MB，
 * `rootBundle.load()` 会把整份数据读进 Dart 堆，移动端极易 OOM；
 * 这里用 256KB 缓冲流式拷贝，内存占用恒定。
 */
class MainActivity : AudioServiceActivity() {
    companion object {
        private const val CHANNEL = "app.bitbear.virtual/model_asset"
        private const val BUFFER_SIZE = 256 * 1024
        /** 复制前要求的最小剩余空间倍数（留出解压/写入余量） */
        private const val FREE_SPACE_FACTOR = 1.3
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledPath" -> {
                    val targetName = call.argument<String>("targetName")
                    val expectedBytes = call.argument<Number>("expectedBytes")?.toLong() ?: 0L
                    if (targetName == null) {
                        result.error("bad_args", "targetName 不能为空", null)
                    } else {
                        result.success(installedPath(targetName, expectedBytes))
                    }
                }
                "ensureInstalled" -> {
                    val assetPath = call.argument<String>("assetPath")
                    val targetName = call.argument<String>("targetName")
                    val expectedBytes = call.argument<Number>("expectedBytes")?.toLong() ?: 0L
                    if (assetPath == null || targetName == null) {
                        result.error("bad_args", "assetPath / targetName 不能为空", null)
                        return@setMethodCallHandler
                    }
                    // 拷贝是耗时 IO，放工作线程；结果与进度回调切回主线程（Flutter 要求）
                    Thread {
                        try {
                            val path = copyAsset(
                                assetPath = assetPath,
                                targetName = targetName,
                                expectedBytes = expectedBytes,
                            ) { progress ->
                                mainHandler.post { channel.invokeMethod("onProgress", progress) }
                            }
                            mainHandler.post { result.success(path) }
                        } catch (t: Throwable) {
                            val msg = t.message ?: t.toString()
                            mainHandler.post { result.error("install_failed", msg, null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    /** 模型落地目录：应用专属外部目录（无需权限），不可用时退回内部 files 目录 */
    private fun modelDir(): File {
        val base = getExternalFilesDir(null) ?: filesDir
        return File(base, "models").apply { if (!exists()) mkdirs() }
    }

    /** 已安装且大小正确则返回绝对路径，否则 null */
    private fun installedPath(targetName: String, expectedBytes: Long): String? {
        val f = File(modelDir(), targetName)
        return if (f.exists() && f.length() == expectedBytes) f.absolutePath else null
    }

    private fun copyAsset(
        assetPath: String,
        targetName: String,
        expectedBytes: Long,
        onProgress: (Double) -> Unit,
    ): String {
        val dir = modelDir()
        val target = File(dir, targetName)

        // 幂等：已存在且大小正确直接返回，不重复复制
        if (target.exists() && target.length() == expectedBytes) {
            onProgress(1.0)
            return target.absolutePath
        }
        // 大小对不上（上次中断/包更新）时先删掉，避免半截文件被误用
        if (target.exists()) target.delete()

        if (expectedBytes > 0) {
            val needed = (expectedBytes * FREE_SPACE_FACTOR).toLong()
            val available = StatFs(dir.absolutePath).availableBytes
            if (available < needed) {
                throw IllegalIOException(
                    "剩余空间不足：需要约 ${needed / 1024 / 1024}MB，" +
                        "当前可用 ${available / 1024 / 1024}MB"
                )
            }
        }

        val tmp = File(dir, "$targetName.partial")
        if (tmp.exists()) tmp.delete()

        val total = assets.open(assetPath).use { input ->
            var pkgSize = -1L
            try {
                // 未压缩（stored）时可直接拿到长度，用于精确进度；失败则退回 expectedBytes
                pkgSize = assets.openFd(assetPath).use { it.length }
            } catch (_: Throwable) {
                // noCompress 未生效或资产被压缩，忽略
            }
            val size = if (pkgSize > 0) pkgSize else expectedBytes

            var copied = 0L
            var lastReported = -1
            File(tmp.absolutePath).outputStream().use { output ->
                val buf = ByteArray(BUFFER_SIZE)
                while (true) {
                    val n = input.read(buf)
                    if (n <= 0) break
                    output.write(buf, 0, n)
                    copied += n
                    if (size > 0) {
                        val pct = ((copied * 100) / size).toInt()
                        if (pct != lastReported) {
                            lastReported = pct
                            onProgress(copied.toDouble() / size.toDouble())
                        }
                    }
                }
                output.flush()
            }
            copied
        }

        if (expectedBytes > 0 && total != expectedBytes) {
            tmp.delete()
            throw IllegalIOException(
                "模型复制不完整：期望 $expectedBytes 字节，实际 $total 字节"
            )
        }
        if (!tmp.renameTo(target)) {
            tmp.delete()
            throw IllegalIOException("无法把临时文件重命名为 ${target.absolutePath}")
        }
        onProgress(1.0)
        return target.absolutePath
    }

    private class IllegalIOException(message: String) : Exception(message)
}

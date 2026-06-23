package com.example.linux_container

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val NATIVE_PATHS = "linux_container/native_paths"
    private val FOREGROUND = "linux_container/foreground"
    private val MEDIAPIPE = "xtr/mediapipe"
    private val MEDIAPIPE_STREAM = "xtr/mediapipe/stream"
    private val REQUEST_IMPORT = 4711

    private var pendingImport: MethodChannel.Result? = null
    private var mpSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Canal existente: ruta de las libs nativas de proot.
        MethodChannel(messenger, NATIVE_PATHS)
            .setMethodCallHandler { call, result ->
                if (call.method == "getNativeLibraryDir") {
                    result.success(applicationContext.applicationInfo.nativeLibraryDir)
                } else {
                    result.notImplemented()
                }
            }

        // Canal existente: control del foreground service del agente.
        MethodChannel(messenger, FOREGROUND)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val i = Intent(this, AgentForegroundService::class.java)
                        i.action = AgentForegroundService.ACTION_START
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(i)
                        } else {
                            startService(i)
                        }
                        result.success(true)
                    }
                    "stop" -> {
                        val i = Intent(this, AgentForegroundService::class.java)
                        i.action = AgentForegroundService.ACTION_STOP
                        startService(i)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // Canal MediaPipe: motor LLM on-device + servidor OpenAI local + importador.
        MethodChannel(messenger, MEDIAPIPE)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "load" -> {
                        val path = call.argument<String>("path")
                        val gpu = call.argument<Boolean>("gpu") ?: true
                        if (path == null) {
                            result.error("ARG", "Falta 'path'", null)
                        } else {
                            Thread {
                                val err = MediaPipeEngine.load(applicationContext, path, gpu)
                                runOnUiThread {
                                    if (err == null) result.success(true)
                                    else result.error("LOAD", err, null)
                                }
                            }.start()
                        }
                    }
                    "generate" -> {
                        val prompt = call.argument<String>("prompt")
                        if (prompt == null) {
                            result.error("ARG", "Falta 'prompt'", null)
                        } else {
                            Thread { runGenerate(prompt, result) }.start()
                        }
                    }
                    "unload" -> {
                        MediaPipeEngine.close()
                        result.success(true)
                    }
                    "importModel" -> {
                        if (pendingImport != null) {
                            result.error("BUSY", "Importación en curso", null)
                        } else {
                            pendingImport = result
                            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "*/*"
                            }
                            try {
                                startActivityForResult(intent, REQUEST_IMPORT)
                            } catch (e: Exception) {
                                pendingImport = null
                                result.error("PICK", e.message, null)
                            }
                        }
                    }
                    "serverStart" -> {
                        val port = call.argument<Int>("port") ?: 8090
                        val path = call.argument<String>("path")
                        val gpu = call.argument<Boolean>("gpu") ?: true
                        Thread {
                            var err: String? = null
                            if (path != null && !MediaPipeEngine.isLoaded) {
                                err = MediaPipeEngine.load(applicationContext, path, gpu)
                            }
                            if (err == null && !MediaPipeEngine.isLoaded) {
                                err = "El modelo no está cargado."
                            }
                            if (err == null) {
                                err = MediaPipeServer.start(port)
                            }
                            val e = err
                            runOnUiThread {
                                if (e == null) result.success(true)
                                else result.error("SERVER", e, null)
                            }
                        }.start()
                    }
                    "serverStop" -> {
                        MediaPipeServer.stop()
                        result.success(true)
                    }
                    "serverStatus" -> {
                        result.success(
                            mapOf(
                                "running" to MediaPipeServer.isRunning,
                                "port" to MediaPipeServer.port,
                                "modelLoaded" to MediaPipeEngine.isLoaded,
                                "modelPath" to (MediaPipeEngine.loadedPath ?: "")
                            )
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        // Canal de eventos: streaming de tokens + estadísticas (pantalla de prueba).
        EventChannel(messenger, MEDIAPIPE_STREAM)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    mpSink = events
                }

                override fun onCancel(arguments: Any?) {
                    mpSink = null
                }
            })
    }

    private fun runGenerate(prompt: String, result: MethodChannel.Result) {
        val sb = StringBuilder()
        val startNs = System.nanoTime()
        var firstNs = 0L
        val err = MediaPipeEngine.generate(prompt) { token, done ->
            if (firstNs == 0L) firstNs = System.nanoTime()
            if (token.isNotEmpty()) sb.append(token)
            runOnUiThread {
                mpSink?.success(mapOf("partial" to token, "done" to done))
                if (done) {
                    val genSecs = (System.nanoTime() - firstNs) / 1e9
                    val ttftSecs = (firstNs - startNs) / 1e9
                    val toks = MediaPipeEngine.sizeInTokens(sb.toString())
                    val tps = if (genSecs > 0) toks / genSecs else 0.0
                    mpSink?.success(
                        mapOf(
                            "stats" to true,
                            "tps" to tps,
                            "tokens" to toks,
                            "ttft" to ttftSecs
                        )
                    )
                }
            }
        }
        runOnUiThread {
            if (err == null) result.success(true)
            else result.error("GEN", err, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQUEST_IMPORT) return
        val res = pendingImport
        pendingImport = null
        if (res == null) return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            res.success(null)
            return
        }
        Thread {
            try {
                val name = queryName(uri) ?: "model.task"
                val dir = File(getExternalFilesDir(null), "models")
                if (!dir.exists()) dir.mkdirs()
                val dest = File(dir, name)
                contentResolver.openInputStream(uri).use { input ->
                    dest.outputStream().use { output ->
                        input!!.copyTo(output, 1024 * 1024)
                    }
                }
                runOnUiThread { res.success(dest.absolutePath) }
            } catch (e: Exception) {
                runOnUiThread { res.error("COPY", e.message, null) }
            }
        }.start()
    }

    private fun queryName(uri: Uri): String? {
        var name: String? = null
        try {
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && c.moveToFirst()) {
                    name = c.getString(idx)
                }
            }
        } catch (_: Exception) {
        }
        return name
    }

    override fun onDestroy() {
        MediaPipeServer.stop()
        MediaPipeEngine.close()
        super.onDestroy()
    }
}

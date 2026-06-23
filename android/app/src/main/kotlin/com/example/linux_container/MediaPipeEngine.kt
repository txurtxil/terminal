package com.example.linux_container

import android.content.Context
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import com.google.mediapipe.tasks.genai.llminference.LlmInferenceSession
import java.util.concurrent.CountDownLatch
import java.util.concurrent.locks.ReentrantLock

/**
 * Motor singleton de inferencia on-device (MediaPipe LLM, GPU/CPU).
 * Compartido por la pantalla de prueba y por el servidor OpenAI local,
 * para no cargar el modelo dos veces. Las generaciones se serializan.
 */
object MediaPipeEngine {

    private var llm: LlmInference? = null

    @Volatile
    var loadedPath: String? = null
        private set

    @Volatile
    var loadedGpu: Boolean = true
        private set

    private val genLock = ReentrantLock()

    val isLoaded: Boolean get() = llm != null

    @Synchronized
    fun load(context: Context, modelPath: String, useGpu: Boolean): String? {
        return try {
            if (llm != null && loadedPath == modelPath && loadedGpu == useGpu) {
                return null // ya está cargado igual
            }
            closeInternal()
            val backend =
                if (useGpu) LlmInference.Backend.GPU else LlmInference.Backend.CPU
            val opts = LlmInference.LlmInferenceOptions.builder()
                .setModelPath(modelPath)
                .setMaxTokens(1024)
                .setMaxTopK(64)
                .setPreferredBackend(backend)
                .build()
            llm = LlmInference.createFromOptions(context, opts)
            loadedPath = modelPath
            loadedGpu = useGpu
            null
        } catch (e: Throwable) {
            "Error al cargar el modelo: ${e.message}"
        }
    }

    private fun newSession(temperature: Float, topK: Int, topP: Float): LlmInferenceSession {
        return LlmInferenceSession.createFromOptions(
            llm,
            LlmInferenceSession.LlmInferenceSessionOptions.builder()
                .setTopK(topK)
                .setTopP(topP)
                .setTemperature(temperature)
                .build()
        )
    }

    /**
     * Generación en streaming. Llama a onPartial(token, done) por cada trozo.
     * Bloquea el hilo llamante hasta terminar; está serializada por un lock.
     */
    fun generate(
        prompt: String,
        temperature: Float = 0.8f,
        topK: Int = 40,
        topP: Float = 0.95f,
        onPartial: (String, Boolean) -> Unit
    ): String? {
        if (llm == null) return "Modelo no cargado"
        genLock.lock()
        var session: LlmInferenceSession? = null
        return try {
            session = newSession(temperature, topK, topP)
            val latch = CountDownLatch(1)
            session.addQueryChunk(prompt)
            session.generateResponseAsync { partial, done ->
                onPartial(partial ?: "", done)
                if (done) latch.countDown()
            }
            latch.await()
            null
        } catch (e: Throwable) {
            "Error al generar: ${e.message}"
        } finally {
            try {
                session?.close()
            } catch (_: Throwable) {
            }
            genLock.unlock()
        }
    }

    /** Generación bloqueante que devuelve (error, textoCompleto). */
    fun generateBlocking(
        prompt: String,
        temperature: Float = 0.8f,
        topK: Int = 40,
        topP: Float = 0.95f
    ): Pair<String?, String> {
        val sb = StringBuilder()
        val err = generate(prompt, temperature, topK, topP) { token, _ ->
            if (token.isNotEmpty()) sb.append(token)
        }
        return Pair(err, sb.toString())
    }

    fun sizeInTokens(text: String): Int {
        return try {
            llm?.sizeInTokens(text) ?: 0
        } catch (_: Throwable) {
            0
        }
    }

    @Synchronized
    fun close() {
        closeInternal()
    }

    private fun closeInternal() {
        try {
            llm?.close()
        } catch (_: Throwable) {
        }
        llm = null
        loadedPath = null
    }
}

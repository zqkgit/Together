package com.together.app.core.network

import android.content.Context
import com.jakewharton.retrofit2.converter.kotlinx.serialization.asConverterFactory
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.HttpException
import retrofit2.Retrofit
import java.io.File
import java.util.concurrent.TimeUnit

/**
 * 统一网络入口：注入 token、解析 {code, message, data}、401 处理、上传
 * 对齐 iOS APIClient.swift
 */
object ApiService {

    /** 全局登录态失效事件（UI 层监听后跳登录页） */
    val authExpiredFlow: SharedFlow<Unit> get() = _authExpiredFlow
    private val _authExpiredFlow = MutableSharedFlow<Unit>(replay = 0, extraBufferCapacity = 1)

    /** token 提供者，由 Application 层注入 */
    var tokenProvider: () -> String? = { null }

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        explicitNulls = false
        coerceInputValues = true
    }

    private var retrofit: Retrofit? = null

    private val okClient: OkHttpClient by lazy {
        val logger = HttpLoggingInterceptor { message ->
            NetworkLogger.log(message)
        }.apply {
            level = HttpLoggingInterceptor.Level.BODY
        }

        OkHttpClient.Builder()
            .addInterceptor(AuthInterceptor { tokenProvider() })
            .addInterceptor(logger)
            .connectTimeout(20, TimeUnit.SECONDS)
            .readTimeout(20, TimeUnit.SECONDS)
            .writeTimeout(20, TimeUnit.SECONDS)
            .build()
    }

    private fun retrofit(): Retrofit {
        return retrofit ?: Retrofit.Builder()
            .baseUrl(ApiConfig.baseUrl)
            .client(okClient)
            .addConverterFactory(json.asConverterFactory("application/json".toMediaType()))
            .build().also { retrofit = it }
    }

    /** 通用 Retrofit API 接口 */
    private val api: TogetherApi by lazy { retrofit().create(TogetherApi::class.java) }

    // MARK: - 统一请求方法（返回 data 层 JsonObject）

    suspend fun get(path: String, query: Map<String, Any?> = emptyMap()): JsonObject {
        return execute { api.get(path, cleanQuery(query)) }
    }

    /** 返回 data 层原始 JsonElement（data 为数组时使用，如 /topics） */
    suspend fun getElement(path: String, query: Map<String, Any?> = emptyMap()): JsonElement {
        val response = try {
            api.get(path, cleanQuery(query))
        } catch (e: HttpException) {
            if (e.code() == 401) {
                notifyAuthExpired()
                throw ApiException.Unauthorized()
            }
            throw ApiException.Network("请求失败(${e.code()})")
        } catch (e: Exception) {
            if (e is ApiException) throw e
            throw ApiException.Network(e.message ?: "网络连接失败")
        }
        return when {
            response.code == 0 -> response.data ?: kotlinx.serialization.json.JsonNull
            response.code == 401 -> {
                notifyAuthExpired()
                throw ApiException.Unauthorized(response.message)
            }
            else -> throw ApiException.Business(response.code, response.message)
        }
    }

    suspend fun post(path: String, body: JsonObject = JsonObject(emptyMap())): JsonObject {
        return execute { api.post(path, body) }
    }

    suspend fun post(path: String, body: Map<String, Any?>): JsonObject {
        return execute { api.post(path, toJson(body)) }
    }

    suspend fun put(path: String, body: JsonObject = JsonObject(emptyMap())): JsonObject {
        return execute { api.put(path, body) }
    }

    suspend fun put(path: String, body: Map<String, Any?>): JsonObject {
        return execute { api.put(path, toJson(body)) }
    }

    suspend fun delete(path: String): JsonObject {
        return execute { api.delete(path) }
    }

    // MARK: - 上传

    /** 上传文件（POST /upload，files ≤ 9，folder 白名单） */
    suspend fun upload(files: List<File>, folder: String): JsonObject {
        val parts = files.mapIndexed { index, file ->
            MultipartBody.Part.createFormData(
                "files",
                "img_${System.currentTimeMillis() / 1000}_$index.jpg",
                file.asRequestBody("image/jpeg".toMediaType())
            )
        }
        val folderPart = MultipartBody.Part.createFormData("folder", folder)
        return execute { api.upload(parts, folderPart) }
    }

    // MARK: - 内部

    private suspend fun execute(block: suspend () -> ApiResponse<JsonElement>): JsonObject {
        val response = try {
            block()
        } catch (e: HttpException) {
            if (e.code() == 401) {
                notifyAuthExpired()
                throw ApiException.Unauthorized()
            }
            throw ApiException.Network("请求失败(${e.code()})")
        } catch (e: Exception) {
            if (e is ApiException) throw e
            throw ApiException.Network(e.message ?: "网络连接失败")
        }

        return handleResponse(response)
    }

    private fun handleResponse(response: ApiResponse<JsonElement>): JsonObject {
        return when {
            response.code == 0 -> {
                response.data?.jsonObject ?: JsonObject(emptyMap())
            }
            response.code == 401 -> {
                notifyAuthExpired()
                throw ApiException.Unauthorized(response.message)
            }
            else -> {
                throw ApiException.Business(response.code, response.message)
            }
        }
    }

    private fun notifyAuthExpired() {
        _authExpiredFlow.tryEmit(Unit)
    }

    private fun cleanQuery(query: Map<String, Any?>): Map<String, String> {
        return query.filterValues { it != null && it.toString().isNotEmpty() }
            .mapValues { it.value.toString() }
    }

    /** Map 转 JsonObject（仅支持基本类型） */
    private fun toJson(map: Map<String, Any?>): JsonObject {
        val builder = kotlinx.serialization.json.buildJsonObject {
            map.forEach { (key, value) ->
                when (value) {
                    null -> {}
                    is String -> put(key, kotlinx.serialization.json.JsonPrimitive(value))
                    is Number -> put(key, kotlinx.serialization.json.JsonPrimitive(value))
                    is Boolean -> put(key, kotlinx.serialization.json.JsonPrimitive(value))
                    is List<*> -> put(key, kotlinx.serialization.json.JsonArray(
                        value.mapNotNull { item ->
                            when (item) {
                                is String -> kotlinx.serialization.json.JsonPrimitive(item)
                                is Number -> kotlinx.serialization.json.JsonPrimitive(item)
                                else -> null
                            }
                        }
                    ))
                }
            }
        }
        return builder
    }
}
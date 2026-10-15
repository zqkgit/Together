package com.together.app.core.network

import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import okhttp3.MultipartBody
import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.HTTP
import retrofit2.http.Multipart
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.PUT
import retrofit2.http.Part
import retrofit2.http.Path
import retrofit2.http.QueryMap

/** 通用 Retrofit 接口（path 由调用方拼接） */
interface TogetherApi {

    @GET("{path}")
    suspend fun get(
        @Path(value = "path", encoded = true) path: String,
        @QueryMap query: Map<String, String> = emptyMap()
    ): ApiResponse<JsonElement>

    @POST("{path}")
    suspend fun post(
        @Path(value = "path", encoded = true) path: String,
        @Body body: JsonObject
    ): ApiResponse<JsonElement>

    @PUT("{path}")
    suspend fun put(
        @Path(value = "path", encoded = true) path: String,
        @Body body: JsonObject
    ): ApiResponse<JsonElement>

    @PATCH("{path}")
    suspend fun patch(
        @Path(value = "path", encoded = true) path: String,
        @Body body: JsonObject
    ): ApiResponse<JsonElement>

    @DELETE("{path}")
    suspend fun delete(
        @Path(value = "path", encoded = true) path: String
    ): ApiResponse<JsonElement>

    /** DELETE with body（解绑设备等场景） */
    @HTTP(method = "DELETE", path = "{path}", hasBody = true)
    suspend fun deleteBody(
        @Path(value = "path", encoded = true) path: String,
        @Body body: JsonObject
    ): ApiResponse<JsonElement>

    @Multipart
    @POST("upload")
    suspend fun upload(
        @Part files: List<MultipartBody.Part>,
        @Part folder: MultipartBody.Part
    ): ApiResponse<JsonElement>
}
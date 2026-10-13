package com.together.app.core.network

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull

/**
 * JsonObject 便捷取值工具（对齐 iOS SwiftyJSON 用法）
 * 安全取值：字段不存在或类型不匹配时返回默认值
 */
object JsonHelper {

    // MARK: - 基本类型

    fun JsonObject.str(key: String): String =
        (this[key] as? JsonPrimitive)?.content ?: ""

    fun JsonObject.strOrNull(key: String): String? =
        (this[key] as? JsonPrimitive)?.takeIf { it !is kotlinx.serialization.json.JsonNull }?.content

    fun JsonObject.int(key: String): Int =
        (this[key] as? JsonPrimitive)?.intOrNull ?: 0

    fun JsonObject.intOrNull(key: String): Int? =
        (this[key] as? JsonPrimitive)?.intOrNull

    fun JsonObject.long(key: String): Long =
        (this[key] as? JsonPrimitive)?.longOrNull ?: 0L

    fun JsonObject.double(key: String): Double =
        (this[key] as? JsonPrimitive)?.doubleOrNull ?: 0.0

    fun JsonObject.doubleOrNull(key: String): Double? =
        (this[key] as? JsonPrimitive)?.doubleOrNull

    fun JsonObject.bool(key: String): Boolean =
        (this[key] as? JsonPrimitive)?.booleanOrNull ?: false

    fun JsonObject.boolOrNull(key: String): Boolean? =
        (this[key] as? JsonPrimitive)?.booleanOrNull

    // MARK: - 对象 / 数组

    fun JsonObject.obj(key: String): JsonObject =
        (this[key] as? JsonObject) ?: JsonObject(emptyMap())

    fun JsonObject.objOrNull(key: String): JsonObject? =
        this[key] as? JsonObject

    fun JsonObject.array(key: String): JsonArray =
        (this[key] as? JsonArray) ?: JsonArray(emptyList())

    fun JsonObject.arrayOrNull(key: String): JsonArray? =
        this[key] as? JsonArray

    /** 列表字段便捷 map */
    fun <T> JsonObject.listOf(key: String, transform: (JsonObject) -> T): List<T> {
        val arr = (this[key] as? JsonArray) ?: return emptyList()
        return arr.mapNotNull { element ->
            (element as? JsonObject)?.let(transform)
        }
    }

    /** 字符串数组 */
    fun JsonObject.strList(key: String): List<String> {
        val arr = (this[key] as? JsonArray) ?: return emptyList()
        return arr.mapNotNull { (it as? JsonPrimitive)?.content }
    }

    // MARK: - 解码为 data class

    inline fun <reified T> decode(from: JsonObject): T? {
        return try {
            ApiJson.decodeFromJsonElement<T>(from)
        } catch (e: Exception) {
            null
        }
    }

    inline fun <reified T> decodeList(from: JsonArray): List<T> {
        return from.mapNotNull { element ->
            try {
                ApiJson.decodeFromJsonElement<T>(element)
            } catch (e: Exception) {
                null
            }
        }
    }

    inline fun <reified T> JsonObject.decodeList(key: String): List<T> {
        val arr = (this[key] as? JsonArray) ?: return emptyList()
        return decodeList<T>(arr)
    }

    /** 列表接口统一结构 { total, page, page_size, list: [...] } */
    inline fun <reified T> JsonObject.decodePageList(key: String = "list"): List<T> {
        return decodeList<T>(key)
    }
}

/** 全局 Json 实例（供 decodeFromJsonElement 使用） */
val ApiJson = kotlinx.serialization.json.Json {
    ignoreUnknownKeys = true
    isLenient = true
    explicitNulls = false
    coerceInputValues = true
}
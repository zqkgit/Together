package com.together.app.core.network

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.longOrNull

/**
 * JsonObject / JsonElement 便捷取值工具（基于 kotlinx.serialization）
 * 对齐 iOS SwiftyJSON 用法：安全取值，字段缺失或类型不匹配返回默认值
 */
object JsonHelper {

    // MARK: - 基本类型（JsonObject 扩展）

    fun JsonObject.str(key: String): String =
        (this[key] as? JsonPrimitive)?.content ?: ""

    fun JsonObject.strOrNull(key: String): String? =
        (this[key] as? JsonPrimitive)?.content

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

    /** 取子对象，不存在返回空 JsonObject */
    fun JsonObject.obj(key: String): JsonObject =
        (this[key] as? JsonObject) ?: JsonObject(emptyMap())

    fun JsonObject.objOrNull(key: String): JsonObject? =
        this[key] as? JsonObject

    /** 取数组，不存在返回空数组 */
    fun JsonObject.array(key: String): JsonArray =
        (this[key] as? JsonArray) ?: JsonArray(emptyList())

    fun JsonObject.arrayOrNull(key: String): JsonArray? =
        this[key] as? JsonArray

    /** 列表字段便捷 map */
    fun <T> JsonObject.listOf(key: String, transform: (JsonObject) -> T): List<T> {
        val arr = (this[key] as? JsonArray) ?: return emptyList()
        return arr.mapNotNull { (it as? JsonObject)?.let(transform) }
    }

    /** 字符串数组 */
    fun JsonObject.strList(key: String): List<String> {
        val arr = (this[key] as? JsonArray) ?: return emptyList()
        return arr.mapNotNull { (it as? JsonPrimitive)?.content }
    }

    // MARK: - 解码为 data class（kotlinx.serialization）

    /** 将 JsonObject 解码为 data class T，失败返回 null */
    inline fun <reified T> JsonObject.decode(): T? = try {
        ApiJson.decodeFromJsonElement<T>(this)
    } catch (e: Exception) { null }

    /** 将 JsonElement 解码为 data class T（自动处理 JsonObject / JsonNull），失败返回 null */
    inline fun <reified T> JsonElement.decode(): T? = try {
        ApiJson.decodeFromJsonElement<T>(this)
    } catch (e: Exception) { null }

    /** 从 JsonObject 指定 key 解码列表，默认 key = "list" */
    inline fun <reified T> JsonObject.decodeList(key: String = "list"): List<T> {
        val arr = (this[key] as? JsonArray) ?: return emptyList()
        return decodeArray<T>(arr)
    }

    /** 将 JsonElement 解码列表：JsonArray 直接解码，JsonObject 从 "list" 字段取 */
    inline fun <reified T> JsonElement.decodeList(): List<T> = when (this) {
        is JsonArray -> decodeArray<T>(this)
        is JsonObject -> decodeList<T>("list")
        else -> emptyList()
    }

    /** 将 JsonArray 解码为列表，跳过失败元素 */
    inline fun <reified T> decodeArray(arr: JsonArray): List<T> =
        arr.mapNotNull { el -> try { ApiJson.decodeFromJsonElement<T>(el) } catch (_: Exception) { null } }

    /** 列表接口统一结构 { total, page, page_size, list: [...] } */
    inline fun <reified T> JsonObject.decodePageList(key: String = "list"): List<T> =
        decodeList<T>(key)
}

/** 全局 Json 实例（供 decodeFromJsonElement 使用） */
val ApiJson = kotlinx.serialization.json.Json {
    ignoreUnknownKeys = true
    isLenient = true
    explicitNulls = false
    coerceInputValues = true
}
package com.together.app.services

import com.together.app.core.model.CourseItem
import com.together.app.core.model.StudioItem
import com.together.app.core.model.TeacherItem
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decodeList
import com.together.app.core.network.JsonHelper.int
import com.together.app.core.network.JsonHelper.intOrNull
import com.together.app.core.network.JsonHelper.strOrNull
import kotlinx.serialization.Serializable

/**
 * 搜索相关接口（课程 / 工作室 / 老师 / 热门词 / 标签）
 * 对齐 iOS SearchService.swift
 */
object SearchService {

    // MARK: - 综合搜索

    @Serializable
    data class SearchResult(
        val courses: List<CourseItem> = emptyList(),
        val studios: List<StudioItem> = emptyList(),
        val teachers: List<TeacherItem> = emptyList()
    )

    /** 综合搜索（三路并行，任一失败不阻塞） */
    suspend fun search(keyword: String): SearchResult {
        val result = SearchResult()
        val courses = runCatching { searchCourses(keyword, 1).first }.getOrDefault(emptyList())
        val studios = runCatching { searchStudios(keyword, 1).first }.getOrDefault(emptyList())
        val teachers = runCatching { searchTeachers(keyword, 1).first }.getOrDefault(emptyList())
        return result.copy(courses = courses, studios = studios, teachers = teachers)
    }

    // MARK: - 分类搜索

    /** 搜索课程（分页）→ (items, hasMore) */
    suspend fun searchCourses(keyword: String, page: Int, tagId: String? = null): Pair<List<CourseItem>, Boolean> {
        val params = mutableMapOf<String, Any?>("keyword" to keyword, "page" to page, "page_size" to 10)
        tagId?.takeIf { it.isNotEmpty() }?.let { params["tag_id"] = it }
        val json = ApiService.get("/courses", params)
        val items = json.decodeList<CourseItem>("list")
        val total = json.int("total")
        return items to (page * 10 < total)
    }

    /** 搜索工作室（分页）→ (items, hasMore) */
    suspend fun searchStudios(keyword: String, page: Int): Pair<List<StudioItem>, Boolean> {
        val params = mapOf("keyword" to keyword, "page" to page, "page_size" to 10)
        val json = ApiService.get("/studios", params)
        val items = json.decodeList<StudioItem>("list")
        val total = json.int("total")
        return items to (page * 10 < total)
    }

    /** 搜索老师（分页）→ (items, hasMore) */
    suspend fun searchTeachers(keyword: String, page: Int): Pair<List<TeacherItem>, Boolean> {
        val params = mapOf("keyword" to keyword, "page" to page, "page_size" to 10)
        val json = ApiService.get("/teachers", params)
        val items = json.decodeList<TeacherItem>("list")
        val total = json.int("total")
        return items to (page * 10 < total)
    }

    // MARK: - 热门词 / 标签

    /** 热门搜索词 */
    suspend fun fetchHotKeywords(): List<String> {
        val json = ApiService.get("/search/hot-keywords")
        return json.decodeList<String>("list")
    }

    /** 课程标签列表 */
    suspend fun fetchTags(): List<TagItem> {
        val json = ApiService.get("/courses/tags")
        return json.decodeList<TagItem>("list")
    }

    /**
     * 公共标签库（对齐 iOS TagService.fetchTags）
     * scope: 1=工作室 / 2=老师 / 3=通用，用于认证表单的营业类型等选项
     */
    suspend fun fetchScopedTags(scope: Int): List<ScopedTag> {
        val element = ApiService.getElement("/tags", mapOf("scope" to scope))
        val array = element as? kotlinx.serialization.json.JsonArray
            ?: return emptyList()
        return array.mapNotNull { item ->
            val obj = item as? kotlinx.serialization.json.JsonObject ?: return@mapNotNull null
            val name = obj.strOrNull("name") ?: return@mapNotNull null
            if (name.isEmpty()) return@mapNotNull null
            ScopedTag(
                tagId = obj.strOrNull("tag_id") ?: "",
                name = name,
                scope = obj.intOrNull("scope") ?: scope,
                sort = obj.intOrNull("sort") ?: 0
            )
        }.sortedBy { it.sort }
    }

    @Serializable
    data class ScopedTag(
        val tagId: String = "",
        val name: String = "",
        val scope: Int = 0,
        val sort: Int = 0
    )

    @Serializable
    data class TagItem(
        val id: String? = null,
        val name: String? = null,
        val icon: String? = null
    )

    /** 标签名缓存（tagId → tagName），避免列表页重复请求 */
    private val tagNameCache = mutableMapOf<String, String>()

    /** 获取标签名（优先走缓存） */
    suspend fun tagName(tagId: String): String {
        tagNameCache[tagId]?.let { return it }
        val tags = runCatching { fetchTags() }.getOrDefault(emptyList())
        tags.forEach { tag ->
            tag.id?.let { id -> tag.name?.let { name -> tagNameCache[id] = name } }
        }
        return tagNameCache[tagId] ?: ""
    }
}
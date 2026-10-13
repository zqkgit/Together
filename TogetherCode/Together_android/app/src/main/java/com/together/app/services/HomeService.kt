package com.together.app.services

import com.together.app.core.model.AnnouncementItem
import com.together.app.core.model.ChildItem
import com.together.app.core.model.CourseItem
import com.together.app.core.model.PostItem
import com.together.app.core.model.StudioItem
import com.together.app.core.model.TeacherItem
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decodeList
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

/**
 * 首页数据聚合服务：孩子 / 公告 / 精选课程 / 推荐工作室 / 推荐老师 并行拉取
 * 对齐 iOS HomeService.swift
 */
object HomeService {

    data class HomeData(
        var children: List<ChildItem> = emptyList(),
        var courses: List<CourseItem> = emptyList(),
        var announcements: List<AnnouncementItem> = emptyList(),
        var studios: List<StudioItem> = emptyList(),
        var teachers: List<TeacherItem> = emptyList(),
        var posts: List<PostItem> = emptyList()
    )

    /** 并行拉取首页全部数据，任一失败不影响其他模块 */
    suspend fun fetchHome(): HomeData = coroutineScope {
        val data = HomeData()

        val childrenJob = async {
            try { data.children = ApiService.get("/children").decodeList<ChildItem>() } catch (_: Exception) {}
        }
        val coursesJob = async {
            try {
                data.courses = ApiService.get("/courses", mapOf("page" to 1, "page_size" to 6))
                    .decodeList<CourseItem>()
            } catch (_: Exception) {}
        }
        val announcementsJob = async {
            try {
                data.announcements = ApiService.get("/announcements", mapOf("page" to 1, "page_size" to 3))
                    .decodeList<AnnouncementItem>()
            } catch (_: Exception) {}
        }
        val studiosJob = async {
            try {
                data.studios = ApiService.get("/studios", mapOf("page" to 1, "page_size" to 3))
                    .decodeList<StudioItem>()
            } catch (_: Exception) {}
        }
        val teachersJob = async {
            try {
                data.teachers = ApiService.get("/teachers", mapOf("page" to 1, "page_size" to 3))
                    .decodeList<TeacherItem>()
            } catch (_: Exception) {}
        }
        val postsJob = async {
            try {
                data.posts = ApiService.get("/posts", mapOf("page" to 1, "page_size" to 3, "author_role" to 2, "type" to 1))
                    .decodeList<PostItem>()
            } catch (_: Exception) {}
        }

        childrenJob.await(); coursesJob.await(); announcementsJob.await()
        studiosJob.await(); teachersJob.await(); postsJob.await()

        data
    }
}
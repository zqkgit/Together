package com.together.app.services

import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.decode
import com.together.app.core.network.JsonHelper.decodeList
import com.together.app.core.network.JsonHelper.int
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 老师端服务：工作台 / 点名消课 / 课表 / 请假补课（对齐 iOS TeacherService + PostService 老师部分）
 * 口径：App 侧 /v1/teacher/ 前缀
 */
object TeacherService {

    // MARK: - 工作台

    @Serializable
    data class WorkbenchStats(
        @SerialName("today_pending") val todayPending: Int? = null,
        @SerialName("active_students") val activeStudents: Int? = null,
        @SerialName("attendance_rate") val attendanceRate: Int? = null
    )

    @Serializable
    data class WorkbenchStudent(
        @SerialName("child_id") val childId: String = "",
        @SerialName("nickname") val nickname: String? = null,
        @SerialName("avatar") val avatar: String? = null,
        @SerialName("leave") val leave: Boolean? = null,
        @SerialName("consumed") val consumed: Boolean? = null,
        @SerialName("consumed_source") val consumedSource: Int? = null,
        @SerialName("remaining_lessons") val remainingLessons: Int? = null
    ) {
        val name: String get() = nickname?.takeIf { it.isNotEmpty() } ?: "宝宝"
        val isLeave: Boolean get() = leave ?: false
        val isConsumed: Boolean get() = consumed ?: false
        val remaining: Int get() = remainingLessons ?: 0
        /** 1=老师发帖自动消课 / 2=老师点名消课 */
        val consumeSource: Int get() = consumedSource ?: 0
    }

    @Serializable
    data class ClassRef(
        @SerialName("class_id") val classId: String = "",
        @SerialName("name") val name: String? = null,
        @SerialName("enrolled") val enrolled: Int? = null
    )

    @Serializable
    data class CourseRef(
        @SerialName("course_id") val courseId: String = "",
        @SerialName("title") val title: String? = null,
        @SerialName("duration_min") val durationMin: Int? = null
    )

    @Serializable
    data class WorkbenchSchedule(
        @SerialName("schedule_id") val scheduleId: String = "",
        @SerialName("start_time") val startTime: String? = null,
        @SerialName("end_time") val endTime: String? = null,
        @SerialName("location") val location: String? = null,
        @SerialName("is_makeup") val isMakeup: Boolean? = null,
        @SerialName("consume_status") val consumeStatus: String? = null,
        @SerialName("class") val classRef: ClassRef? = null,
        @SerialName("course") val course: CourseRef? = null,
        @SerialName("students") val students: List<WorkbenchStudent>? = null
    ) {
        val statusText: String
            get() = when (consumeStatus) {
                "completed" -> "已消课"
                "partial" -> "部分消课"
                else -> "待消课"
            }
        val isCompleted: Boolean get() = consumeStatus == "completed"
    }

    @Serializable
    data class Workbench(
        val stats: WorkbenchStats? = null,
        val today: List<WorkbenchSchedule>? = null
    )

    /** 老师工作台聚合（今日课程 + 学员点名态 + 统计） */
    suspend fun fetchWorkbench(): Workbench {
        return ApiService.get("/teacher/workbench").decode<Workbench>() ?: Workbench()
    }

    // MARK: - 点名消课

    /** 一键点名消课（status=1 出勤消课；已请假/已消课学员后端会拦截） */
    suspend fun submitAttendance(scheduleId: String, childIds: List<String>, note: String? = null) {
        // note 走 body，ApiService.toJson 不支持 List<Map>，手动构建
        val body = kotlinx.serialization.json.buildJsonObject {
            put("students", kotlinx.serialization.json.JsonArray(
                childIds.map { childId ->
                    kotlinx.serialization.json.buildJsonObject {
                        put("child_id", kotlinx.serialization.json.JsonPrimitive(childId))
                        put("status", kotlinx.serialization.json.JsonPrimitive(1))
                    }
                }
            ))
            if (!note.isNullOrBlank()) {
                put("note", kotlinx.serialization.json.JsonPrimitive(note))
            }
        }
        ApiService.post("/teacher/schedules/$scheduleId/attendance", body)
    }

    /** 撤销点名消课（只撤老师点名 source=2 的记录，自动还原课时） */
    suspend fun undoAttendance(scheduleId: String, childIds: List<String>) {
        ApiService.post(
            "/teacher/schedules/$scheduleId/attendance/undo",
            mapOf("child_ids" to childIds)
        )
    }

    /** 课表详情：班级花名册 + 该排课已消课回显 */
    suspend fun fetchClassStudents(classId: String, scheduleId: String = ""): List<WorkbenchStudent> {
        return ApiService.get(
            "/teacher/classes/$classId/students",
            mapOf("schedule_id" to scheduleId)
        ).decodeList("list")
    }

    // MARK: - 课表

    @Serializable
    data class TimetableItem(
        @SerialName("schedule_id") val scheduleId: String = "",
        @SerialName("studio_name") val studioName: String? = null,
        @SerialName("lesson_date") val lessonDate: String? = null,
        @SerialName("start_time") val startTime: String? = null,
        @SerialName("end_time") val endTime: String? = null,
        @SerialName("location") val location: String? = null,
        @SerialName("consume_status") val consumeStatus: String? = null,
        @SerialName("student_count") val studentCount: Int? = null,
        @SerialName("leave_count") val leaveCount: Int? = null,
        @SerialName("consumed_count") val consumedCount: Int? = null,
        @SerialName("status") val status: Int? = null,
        @SerialName("class") val classRef: ClassRef? = null,
        @SerialName("course") val course: CourseRef? = null
    ) {
        val consumeText: String
            get() = when (consumeStatus) {
                "completed" -> "已消课"
                "partial" -> "部分消课"
                else -> "待消课"
            }
    }

    /** 老师排课（课次）；date=YYYY-MM-DD 查当天，week=该周任意日期查整周 */
    suspend fun fetchTimetable(date: String? = null, week: String? = null): List<TimetableItem> {
        val params = mutableMapOf<String, Any>()
        date?.let { if (it.isNotEmpty()) params["date"] = it }
        week?.let { if (it.isNotEmpty()) params["week"] = it }
        return ApiService.get("/teacher/timetable", params).decodeList()
    }

    // MARK: - 老师我的页

    @Serializable
    data class MineStudio(
        @SerialName("studio_id") val studioId: String? = null,
        @SerialName("name") val name: String? = null
    )

    @Serializable
    data class MineProfile(
        @SerialName("teacher_id") val teacherId: String? = null,
        @SerialName("real_name") val realName: String? = null,
        @SerialName("nickname") val nickname: String? = null,
        @SerialName("avatar") val avatar: String? = null,
        @SerialName("subjects") val subjects: List<String>? = null,
        @SerialName("years") val years: Int? = null,
        @SerialName("intro") val intro: String? = null,
        @SerialName("cert_status") val certStatus: Int? = null,
        @SerialName("studio") val studio: MineStudio? = null
    ) {
        val name: String
            get() = realName?.takeIf { it.isNotEmpty() } ?: nickname ?: "老师"
        val subjectText: String
            get() = subjects?.takeIf { it.isNotEmpty() }?.joinToString("/") ?: "未设置科目"
        val yearsText: String get() = "教龄${years ?: 0}年"
        /** 副标题：工作室 · 科目 · 教龄（对齐 iOS subtitle） */
        val subtitle: String
            get() {
                val parts = mutableListOf<String>()
                studio?.name?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
                if (subjectText != "未设置科目") parts.add(subjectText)
                parts.add(yearsText)
                return parts.joinToString(" · ")
            }
    }

    @Serializable
    data class MineStats(
        @SerialName("active_students") val activeStudents: Int? = null,
        @SerialName("total_lessons") val totalLessons: Int? = null,
        @SerialName("post_count") val postCount: Int? = null
    )

    @Serializable
    data class MineData(
        val profile: MineProfile? = null,
        val stats: MineStats? = null
    )

    /** 老师「我的」页：资料 + 统计 */
    suspend fun fetchMine(): MineData {
        return ApiService.get("/teacher/mine").decode<MineData>() ?: MineData()
    }

    // MARK: - 我教的课程

    @Serializable
    data class CourseClassItem(
        @SerialName("class_id") val classId: String? = null,
        @SerialName("name") val name: String? = null,
        @SerialName("student_count") val studentCount: Int? = null
    )

    @Serializable
    data class CourseItem(
        @SerialName("course_id") val courseId: String? = null,
        @SerialName("studio_id") val studioId: String? = null,
        @SerialName("studio_name") val studioName: String? = null,
        @SerialName("title") val title: String? = null,
        @SerialName("total_lessons") val totalLessons: Int? = null,
        @SerialName("consumed_lessons") val consumedLessons: Int? = null,
        @SerialName("progress") val progress: Int? = null,
        @SerialName("student_count") val studentCount: Int? = null,
        @SerialName("classes") val classes: List<CourseClassItem>? = null
    )

    /** 我教的课程（按课程聚合班级 + 进度） */
    suspend fun fetchCourses(): List<CourseItem> {
        val json = ApiService.get("/teacher/courses")
        return json.decodeList<CourseItem>("list")
    }

    // MARK: - 我的学生

    @Serializable
    data class StudentCourse(
        @SerialName("course_id") val courseId: String? = null,
        @SerialName("title") val title: String? = null,
        @SerialName("class_id") val classId: String? = null,
        @SerialName("class_name") val className: String? = null,
        @SerialName("remaining_lessons") val remainingLessons: Int? = null,
        @SerialName("total_lessons") val totalLessons: Int? = null
    )

    @Serializable
    data class StudentRow(
        @SerialName("child_id") val childId: String? = null,
        @SerialName("nickname") val nickname: String? = null,
        @SerialName("avatar") val avatar: String? = null,
        @SerialName("birthday") val birthday: String? = null,
        @SerialName("courses") val courses: List<StudentCourse>? = null,
        @SerialName("today_scheduled") val todayScheduled: Boolean? = null,
        @SerialName("leaving") val leaving: Boolean? = null
    ) {
        val name: String get() = nickname?.takeIf { it.isNotEmpty() } ?: "宝宝"
        val isLeaving: Boolean get() = leaving ?: false
        val primaryCourse: StudentCourse? get() = courses?.firstOrNull()
        /** 任一门课剩余课时 ≤ 2 → 课时不足 */
        val lowLessons: Boolean
            get() = courses?.any { (it.remainingLessons ?: 0) <= 2 } ?: false
    }

    @Serializable
    data class StudentClassSummary(
        @SerialName("class_id") val classId: String? = null,
        @SerialName("name") val name: String? = null,
        @SerialName("studio_id") val studioId: String? = null,
        @SerialName("studio_name") val studioName: String? = null
    )

    @Serializable
    data class StudentStudioSummary(
        @SerialName("studio_id") val studioId: String? = null,
        @SerialName("name") val name: String? = null
    )

    @Serializable
    data class StudentListData(
        val total: Int? = null,
        val studios: List<StudentStudioSummary>? = null,
        val classes: List<StudentClassSummary>? = null,
        val list: List<StudentRow>? = null
    )

    /** 我的学生：学生聚合 + 工作室/班级列表 */
    suspend fun fetchStudents(studioId: String? = null, classId: String? = null): StudentListData {
        val params = mutableMapOf<String, Any>()
        studioId?.let { params["studio_id"] = it }
        classId?.let { params["class_id"] = it }
        return ApiService.get("/teacher/students", params).decode<StudentListData>()
            ?: StudentListData()
    }

    // MARK: - 请假 / 补课

    @Serializable
    data class LeaveChild(
        @SerialName("child_id") val childId: String? = null,
        @SerialName("nickname") val nickname: String? = null
    )

    @Serializable
    data class LeaveCourse(
        @SerialName("course_id") val courseId: String? = null,
        @SerialName("title") val title: String? = null
    )

    @Serializable
    data class LeaveClass(
        @SerialName("class_id") val classId: String? = null,
        @SerialName("name") val name: String? = null,
        @SerialName("course") val course: LeaveCourse? = null
    )

    @Serializable
    data class LeaveSchedule(
        @SerialName("lesson_date") val lessonDate: String? = null,
        @SerialName("start_time") val startTime: String? = null,
        @SerialName("end_time") val endTime: String? = null,
        @SerialName("location") val location: String? = null
    )

    @Serializable
    data class LeaveItem(
        @SerialName("leave_id") val leaveId: String? = null,
        @SerialName("reason") val reason: String? = null,
        @SerialName("status") val status: Int? = null,
        @SerialName("studio_id") val studioId: String? = null,
        @SerialName("studio_name") val studioName: String? = null,
        @SerialName("child") val child: LeaveChild? = null,
        @SerialName("class") val classRef: LeaveClass? = null,
        @SerialName("schedule") val schedule: LeaveSchedule? = null,
        @SerialName("makeup_status") val makeupStatus: Int? = null,
        @SerialName("makeup_schedule_id") val makeupScheduleId: String? = null,
        @SerialName("makeup_schedule") val makeupSchedule: LeaveSchedule? = null
    ) {
        /** 卡片副标题：工作室·课程·班级·日期时间 */
        val infoText: String
            get() = listOfNotNull(
                studioName?.takeIf { it.isNotEmpty() },
                classRef?.course?.title?.takeIf { it.isNotEmpty() },
                classRef?.name?.takeIf { it.isNotEmpty() },
                schedule?.lessonDate?.takeIf { it.isNotEmpty() },
                schedule?.startTime?.takeIf { it.isNotEmpty() }
            ).joinToString("·")

        /** 是否有已安排的补课（待补） */
        val hasPendingMakeup: Boolean
            get() = (makeupStatus ?: 0) == 0 && makeupScheduleId != null

        /** 补课状态行文案 */
        val makeupText: String?
            get() = when (makeupStatus) {
                1 -> "补课已完成 · 课时已消耗"
                2 -> "已放弃补课"
                0 -> {
                    val ms = makeupSchedule
                    if (ms != null) {
                        val parts = mutableListOf("补课：${ms.lessonDate ?: ""} ${ms.startTime ?: ""}-${ms.endTime ?: ""}")
                        ms.location?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
                        parts.joinToString(" · ")
                    } else {
                        "未安排补课"
                    }
                }
                else -> null
            }

        /** 是否需要「安排补课」入口 */
        val canArrangeMakeup: Boolean
            get() = !hasPendingMakeup && (makeupStatus ?: 0) != 1
    }

    @Serializable
    data class MakeupCandidate(
        @SerialName("schedule_id") val scheduleId: String? = null,
        @SerialName("lesson_date") val lessonDate: String? = null,
        @SerialName("start_time") val startTime: String? = null,
        @SerialName("end_time") val endTime: String? = null,
        @SerialName("location") val location: String? = null,
        @SerialName("remark") val remark: String? = null
    ) {
        val displayText: String
            get() {
                val parts = mutableListOf("${lessonDate ?: ""} ${startTime ?: ""}-${endTime ?: ""}")
                location?.takeIf { it.isNotEmpty() }?.let { parts.add(it) }
                return parts.joinToString(" · ")
            }
    }

    /** 待处理请假（status=0） */
    suspend fun fetchPendingLeaves(studioId: String? = null): List<LeaveItem> {
        val params = mutableMapOf<String, Any>("status" to 0)
        studioId?.let { params["studio_id"] = it }
        return ApiService.get("/teacher/leaves", params).decodeList("list")
    }

    /** 已同意请假（status=1，用于补课管理） */
    suspend fun fetchApprovedLeaves(studioId: String? = null): List<LeaveItem> {
        val params = mutableMapOf<String, Any>("status" to 1)
        studioId?.let { params["studio_id"] = it }
        return ApiService.get("/teacher/leaves", params).decodeList("list")
    }

    /** 补课候选课次（同班级、原课次之后、未消课） */
    suspend fun fetchMakeupCandidates(leaveId: String): List<MakeupCandidate> {
        return ApiService.get("/teacher/leaves/$leaveId/makeup-candidates").decodeList("list")
    }

    /** 安排补课 / 放弃补课 */
    suspend fun updateMakeup(leaveId: String, makeupScheduleId: String? = null, abandon: Boolean = false) {
        val params = mutableMapOf<String, Any>()
        if (abandon) {
            params["action"] = "abandon"
        } else {
            makeupScheduleId?.let { params["makeup_schedule_id"] = it }
        }
        ApiService.put("/teacher/leaves/$leaveId/makeup", params)
    }

    /** 审批请假：action=agree 同意保留课时 / reject 婉拒 */
    suspend fun reviewLeave(leaveId: String, action: String) {
        ApiService.put("/teacher/leaves/$leaveId", mapOf("action" to action))
    }

    // MARK: - 评价

    @Serializable
    data class ReviewUser(
        @SerialName("user_id") val userId: String? = null,
        @SerialName("nickname") val nickname: String? = null,
        @SerialName("avatar") val avatar: String? = null
    )

    @Serializable
    data class ReviewCourse(
        @SerialName("course_id") val courseId: String? = null,
        @SerialName("title") val title: String? = null
    )

    @Serializable
    data class ReviewItem(
        @SerialName("review_id") val reviewId: String? = null,
        @SerialName("rating") val rating: Int? = null,
        @SerialName("content") val content: String? = null,
        @SerialName("created_at") val createdAt: String? = null,
        @SerialName("user") val user: ReviewUser? = null,
        @SerialName("course") val course: ReviewCourse? = null
    ) {
        val starsText: String
            get() {
                val r = (rating ?: 0).coerceIn(0, 5)
                return "★".repeat(r) + "☆".repeat(5 - r)
            }
        val timeText: String
            get() = createdAt?.takeIf { it.length >= 10 }?.substring(0, 10) ?: ""
    }

    @Serializable
    data class ReviewData(
        val total: Int? = null,
        val average: Double? = null,
        @SerialName("rating_distribution") val ratingDistribution: Map<String, Int>? = null,
        val list: List<ReviewItem>? = null
    )

    /** 老师收到的评价 */
    suspend fun fetchReviews(): ReviewData {
        return ApiService.get("/teacher/reviews").decode<ReviewData>()
            ?: ReviewData()
    }
}
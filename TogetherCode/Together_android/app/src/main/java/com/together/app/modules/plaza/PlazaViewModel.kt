package com.together.app.modules.plaza

import android.app.Application
import android.content.Context
import android.location.LocationManager
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.core.model.ChildItem
import com.together.app.core.model.CommentItem
import com.together.app.core.model.PostItem
import com.together.app.core.model.PostLocation
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.strList
import com.together.app.services.ChildService
import com.together.app.services.PostService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.io.File

/**
 * 广场模块 ViewModel（对齐 iOS PlazaViewController / PostDetailViewController / PostCreate 系列）
 * 三组状态：广场流 / 帖子详情+评论 / 发帖表单
 */
class PlazaViewModel(app: Application) : AndroidViewModel(app) {

    companion object {
        /** 详情页帖子缓存（路由只传 postId，复杂对象走伴生缓存） */
        var navPost: PostItem? = null
        /** 编辑帖子缓存（详情页 → 发帖页） */
        var navEditPost: PostItem? = null
    }

    // MARK: - 广场流

    data class PlazaState(
        val sort: String = "latest",       // latest / hot / near
        val topic: String = "",            // 话题筛选（空 = 全部）
        val topics: List<String> = emptyList(),
        val posts: List<PostItem> = emptyList(),
        val hasMore: Boolean = true,
        val loading: Boolean = false,
        val refreshing: Boolean = false,
        val error: String? = null,
        val lat: Double? = null,
        val lng: Double? = null,
        val locationDenied: Boolean = false  // 附近定位失败退化提示
    )

    private val _plazaState = MutableStateFlow(PlazaState())
    val plazaState: StateFlow<PlazaState> = _plazaState

    private var page = 1

    /** 加载话题列表（页面首次进入） */
    fun loadTopics() {
        viewModelScope.launch {
            try {
                val topics = PostService.fetchTopics()
                if (topics.isNotEmpty()) {
                    _plazaState.value = _plazaState.value.copy(topics = topics)
                }
            } catch (_: Exception) { }
        }
    }

    /** 切换排序（near 需定位，失败退化 latest） */
    fun changeSort(sort: String) {
        if (sort == "near") {
            val loc = getLastKnownLocation()
            if (loc != null) {
                _plazaState.value = _plazaState.value.copy(sort = "near", lat = loc.first, lng = loc.second, locationDenied = false)
            } else {
                // 定位失败退化为最新
                _plazaState.value = _plazaState.value.copy(sort = "latest", locationDenied = true)
            }
        } else {
            _plazaState.value = _plazaState.value.copy(sort = sort, locationDenied = false)
        }
        refresh()
    }

    /** 切换话题筛选 */
    fun changeTopic(topic: String) {
        _plazaState.value = _plazaState.value.copy(topic = topic)
        refresh()
    }

    /** 权限授予后重试附近排序 */
    fun onLocationPermissionGranted() {
        changeSort("near")
    }

    fun refresh() {
        page = 1
        _plazaState.value = _plazaState.value.copy(refreshing = true, error = null)
        loadPlaza()
    }

    fun loadMore() {
        val s = _plazaState.value
        if (s.loading || !s.hasMore) return
        page += 1
        loadPlaza()
    }

    private fun loadPlaza() {
        val s = _plazaState.value
        _plazaState.value = s.copy(loading = true)
        viewModelScope.launch {
            try {
                val (items, hasMore) = PostService.fetchPlaza(
                    page = page, sort = s.sort, topic = s.topic, lat = s.lat, lng = s.lng
                )
                val cur = _plazaState.value
                _plazaState.value = cur.copy(
                    posts = if (page == 1) items else cur.posts + items,
                    hasMore = hasMore,
                    loading = false,
                    refreshing = false,
                    error = null
                )
            } catch (e: Exception) {
                val cur = _plazaState.value
                _plazaState.value = cur.copy(loading = false, refreshing = false, error = e.message ?: "加载失败")
            }
        }
    }

    /** 系统定位（getLastKnownLocation，需权限已授予） */
    private fun getLastKnownLocation(): Pair<Double, Double>? {
        return try {
            val lm = getApplication<Application>().getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val loc = lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                ?: lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                ?: lm.getLastKnownLocation(LocationManager.PASSIVE_PROVIDER)
            loc?.let { Pair(it.latitude, it.longitude) }
        } catch (e: SecurityException) {
            null
        } catch (_: Exception) {
            null
        }
    }

    /** 发帖页获取当前位置（位置选择用） */
    fun getCurrentLocationForCreate(onResult: (Double, Double) -> Unit) {
        val loc = getLastKnownLocation()
        if (loc != null) onResult(loc.first, loc.second)
    }

    // MARK: - 帖子详情 + 评论

    /** 评论展示行：根(0) / 一级回复(1) / 二级回复(2) */
    data class CommentRow(
        val comment: CommentItem,
        val level: Int,
        val replyToName: String?
    )

    data class DetailState(
        val post: PostItem? = null,
        val comments: List<CommentItem> = emptyList(),
        val commentRows: List<CommentRow> = emptyList(),
        val loading: Boolean = true,
        val error: String? = null,
        val replyingTo: CommentItem? = null,
        val replyingLevel: Int = 0,
        val deleted: Boolean = false  // 帖子已删除（UI 返回）
    )

    private val _detailState = MutableStateFlow(DetailState())
    val detailState: StateFlow<DetailState> = _detailState

    fun loadDetail(postId: String) {
        _detailState.value = _detailState.value.copy(loading = true, error = null)
        viewModelScope.launch {
            try {
                val post = PostService.fetchDetail(postId)
                _detailState.value = _detailState.value.copy(post = post, loading = false, error = null)
            } catch (e: Exception) {
                _detailState.value = _detailState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    fun loadComments(postId: String) {
        viewModelScope.launch {
            try {
                val (list, _) = PostService.fetchComments(postId, page = 1)
                _detailState.value = _detailState.value.copy(comments = list)
                rebuildCommentRows()
            } catch (_: Exception) { }
        }
    }

    /**
     * 平铺评论 → 树展开，UI 封顶两级（根 0 / 一级 1 / 其余一律 2）
     * 一级以下任意深度的子孙都降级为二级展示；回复按时间正序跟在父评论后
     */
    private fun rebuildCommentRows() {
        val comments = _detailState.value.comments
        val byParent = comments.groupBy { it.parentId ?: "0" }
        fun childrenOf(parentId: String) =
            (byParent[parentId] ?: emptyList()).sortedBy { it.createdAt ?: "" }

        val rows = mutableListOf<CommentRow>()
        val roots = (byParent["0"] ?: emptyList()).sortedByDescending { it.createdAt ?: "" }
        for (root in roots) {
            rows.add(CommentRow(root, 0, null))
            for (first in childrenOf(root.commentId)) {
                rows.add(CommentRow(first, 1, null))
                // first 的子孙（任意深度）→ 一律 level 2，回复对象 = 其直接父作者
                val queue = ArrayDeque(childrenOf(first.commentId))
                val visited = mutableSetOf<String>()
                while (queue.isNotEmpty()) {
                    val node = queue.removeFirst()
                    if (!visited.add(node.commentId)) continue
                    val parent = comments.firstOrNull { it.commentId == node.parentId }
                    rows.add(CommentRow(node, 2, parent?.authorName))
                    queue.addAll(childrenOf(node.commentId))
                }
            }
        }
        _detailState.value = _detailState.value.copy(commentRows = rows)
    }

    fun toggleLike(postId: String) {
        val post = _detailState.value.post ?: return
        val target = !(post.isLiked ?: false)
        viewModelScope.launch {
            try {
                PostService.toggleLike(postId, post.isLiked ?: false)
                val updated = post.copy(
                    isLiked = target,
                    likeCount = maxOf(0, (post.likeCount ?: 0) + if (target) 1 else -1)
                )
                _detailState.value = _detailState.value.copy(post = updated)
            } catch (_: Exception) { }
        }
    }

    fun toggleFavorite(postId: String) {
        val post = _detailState.value.post ?: return
        val target = !(post.isFavorite ?: false)
        viewModelScope.launch {
            try {
                PostService.toggleFavorite(postId, post.isFavorite ?: false)
                _detailState.value = _detailState.value.copy(post = post.copy(isFavorite = target))
            } catch (_: Exception) { }
        }
    }

    fun toggleFollow() {
        val post = _detailState.value.post ?: return
        val authorId = post.author?.userId ?: return
        val target = !(post.isFollowing ?: false)
        viewModelScope.launch {
            try {
                PostService.toggleFollow(authorId, post.isFollowing ?: false)
                _detailState.value = _detailState.value.copy(post = post.copy(isFollowing = target))
            } catch (_: Exception) { }
        }
    }

    fun toggleCommentLike(postId: String, commentId: String) {
        val rows = _detailState.value.commentRows
        val row = rows.firstOrNull { it.comment.commentId == commentId } ?: return
        val target = !(row.comment.isLiked ?: false)
        viewModelScope.launch {
            try {
                PostService.toggleCommentLike(postId, commentId, row.comment.isLiked ?: false)
                val cur = _detailState.value
                val newComments = cur.comments.map { c ->
                    if (c.commentId == commentId) c.copy(
                        isLiked = target,
                        likeCount = maxOf(0, (c.likeCount ?: 0) + if (target) 1 else -1)
                    ) else c
                }
                _detailState.value = cur.copy(comments = newComments)
                rebuildCommentRows()
            } catch (_: Exception) { }
        }
    }

    fun deleteComment(commentId: String) {
        viewModelScope.launch {
            try {
                PostService.deleteComment(commentId)
                val cur = _detailState.value
                val newComments = cur.comments.filterNot { it.commentId == commentId }
                val post = cur.post
                _detailState.value = cur.copy(
                    comments = newComments,
                    post = post?.copy(commentCount = maxOf(0, (post.commentCount ?: 0) - 1))
                )
                rebuildCommentRows()
            } catch (_: Exception) { }
        }
    }

    /** 撤销某学生的发帖消课（仅作者可操作） */
    fun undoStudent(postId: String, childId: String) {
        viewModelScope.launch {
            try {
                PostService.undoPostStudentConsumption(postId, listOf(childId))
                loadDetail(postId)
            } catch (_: Exception) { }
        }
    }

    fun startReply(row: CommentRow) {
        _detailState.value = _detailState.value.copy(replyingTo = row.comment, replyingLevel = row.level)
    }

    fun cancelReply() {
        _detailState.value = _detailState.value.copy(replyingTo = null, replyingLevel = 0)
    }

    /** 发送评论（层级规则：二级回复挂到其父级，封顶两级） */
    fun sendComment(postId: String, text: String) {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        val state = _detailState.value
        val parentId: String? = if (state.replyingLevel == 2) {
            val pid = state.replyingTo?.parentId
            if (pid != null && pid != "0") pid else state.replyingTo?.commentId
        } else {
            state.replyingTo?.commentId
        }
        viewModelScope.launch {
            try {
                val comment = PostService.postComment(postId, trimmed, parentId)
                if (comment != null) {
                    val cur = _detailState.value
                    val post = cur.post
                    _detailState.value = cur.copy(
                        comments = listOf(comment) + cur.comments,
                        post = post?.copy(commentCount = (post.commentCount ?: 0) + 1),
                        replyingTo = null,
                        replyingLevel = 0
                    )
                    rebuildCommentRows()
                }
            } catch (_: Exception) { }
        }
    }

    fun deletePost(postId: String) {
        viewModelScope.launch {
            try {
                PostService.deletePost(postId)
                _detailState.value = _detailState.value.copy(deleted = true)
            } catch (_: Exception) { }
        }
    }

    // MARK: - 发帖表单（家长 / 老师通用）

    /** 图片项：已有 URL（编辑回显）/ 新选 Uri */
    sealed class PostImage {
        data class Existing(val url: String) : PostImage()
        data class New(val uri: Uri) : PostImage()
    }

    data class CreateState(
        val isEditing: Boolean = false,
        val editingPostId: String? = null,
        val editingRole: Int = 1,          // 1 家长 / 2 老师
        val postType: Int = 1,             // 1 动态 / 2 孩子作品
        val content: String = "",
        val images: List<PostImage> = emptyList(),
        val topic: String = "",
        val topics: List<String> = emptyList(),
        val visibility: Int = 2,           // 2 公开 / 1 仅好友
        val location: PostLocation? = null,
        // 家长
        val childList: List<ChildItem> = emptyList(),
        val selectedChildId: String? = null,
        val selectedCourseId: String? = null,
        // 老师
        val teacherClasses: List<PostService.TeacherClassItem> = emptyList(),
        val classStudents: List<PostService.TeacherStudentItem> = emptyList(),
        val selectedClass: PostService.TeacherClassItem? = null,
        val selectedStudentIds: Set<String> = emptySet(),
        val consumeEnabled: Boolean = false,
        val publishing: Boolean = false,
        val error: String? = null,
        val success: Boolean = false
    )

    private val _createState = MutableStateFlow(CreateState())
    val createState: StateFlow<CreateState> = _createState

    // 编辑回显待应用选择
    private var pendingEditChildId: String? = null
    private var pendingEditCourseId: String? = null
    private var pendingEditClassId: String? = null
    private var pendingEditChildIds: List<String> = emptyList()

    /** 新建发帖初始化 */
    fun initCreate(role: Int, postType: Int) {
        pendingEditChildId = null
        pendingEditCourseId = null
        pendingEditClassId = null
        pendingEditChildIds = emptyList()
        _createState.value = CreateState(editingRole = role, postType = postType)
        loadFormData()
    }

    /** 编辑帖子初始化（回显基础字段，孩子/班级在 loadFormData 后应用） */
    fun initEdit(post: PostItem) {
        pendingEditChildId = post.child?.childId
        pendingEditCourseId = post.course?.courseId
        pendingEditClassId = post.classId
        pendingEditChildIds = post.studentList.map { it.childId }
        // 工作室(role 3)帖子走 /posts 链路，按家长(role 1)编辑
        val effectiveRole = (post.author?.role ?: 1).let { if (it == 3) 1 else it }
        _createState.value = CreateState(
            isEditing = true,
            editingPostId = post.postId,
            editingRole = effectiveRole,
            postType = post.type,
            content = post.bodyText,
            images = post.imageList.map { PostImage.Existing(it) },
            topic = post.safeTopic ?: "",
            visibility = post.visibility ?: 2,
            location = post.location
        )
        loadFormData()
    }

    /** 加载表单数据：家长=孩子列表 / 老师=班级列表 + 话题 */
    private fun loadFormData() {
        viewModelScope.launch {
            val role = _createState.value.editingRole
            // 话题
            try {
                val topics = PostService.fetchTopics()
                val fallback = if (topics.isNotEmpty()) topics else listOf("成长记录", "作品秀", "育儿经", "探店")
                _createState.value = _createState.value.copy(topics = fallback)
            } catch (_: Exception) {
                _createState.value = _createState.value.copy(topics = listOf("成长记录", "作品秀", "育儿经", "探店"))
            }
            // 孩子 / 班级
            try {
                if (role == 1) {
                    val children = ChildService.fetchChildren()
                    val cur = _createState.value
                    // 仅孩子作品(postType=2)自动选第一个孩子；动态不关联孩子
                    val selectedChild = if (cur.postType == 2) {
                        pendingEditChildId ?: children.firstOrNull()?.childId
                    } else {
                        pendingEditChildId
                    }
                    _createState.value = cur.copy(
                        childList = children,
                        selectedChildId = selectedChild
                    )
                    applyPendingEditSelection()
                } else {
                    val classes = PostService.fetchTeacherClasses()
                    _createState.value = _createState.value.copy(teacherClasses = classes)
                    applyPendingEditSelection()
                }
            } catch (e: Exception) {
                _createState.value = _createState.value.copy(error = e.message ?: "加载失败")
            }
        }
    }

    /** 编辑模式：孩子/班级列表就绪后应用原帖选择 */
    private fun applyPendingEditSelection() {
        val cur = _createState.value
        if (cur.editingRole == 1) {
            // 家长：回显孩子+课程
            val childId = pendingEditChildId ?: return
            if (cur.childList.none { it.childId == childId }) return
            _createState.value = cur.copy(selectedChildId = childId, selectedCourseId = pendingEditCourseId)
        } else {
            // 老师：优先 class_id 精确匹配，匹配不到按 course_id 兜底
            val classes = cur.teacherClasses
            var target = pendingEditClassId?.let { id -> classes.firstOrNull { it.classId == id } }
            if (target == null) {
                target = pendingEditCourseId?.let { cid ->
                    classes.firstOrNull { it.course?.courseId == cid }
                }
            }
            if (target == null) return
            _createState.value = cur.copy(selectedClass = target)
            loadClassStudents(target.classId, retainEditStudents = true)
        }
    }

    // MARK: - 表单操作

    fun updateContent(text: String) {
        _createState.value = _createState.value.copy(content = text)
    }

    fun addImages(uris: List<Uri>) {
        val cur = _createState.value
        val remaining = 9 - cur.images.size
        if (remaining <= 0) return
        _createState.value = cur.copy(images = cur.images + uris.take(remaining).map { PostImage.New(it) })
    }

    fun removeImage(index: Int) {
        val cur = _createState.value
        if (index !in cur.images.indices) return
        _createState.value = cur.copy(images = cur.images.filterIndexed { i, _ -> i != index })
    }

    fun selectTopic(topic: String) {
        _createState.value = _createState.value.copy(topic = topic)
    }

    fun selectVisibility(visibility: Int) {
        _createState.value = _createState.value.copy(visibility = visibility)
    }

    fun setLocation(lat: Double, lng: Double, name: String) {
        _createState.value = _createState.value.copy(location = PostLocation(latitude = lat, longitude = lng, name = name))
    }

    fun clearLocation() {
        _createState.value = _createState.value.copy(location = null)
    }

    fun clearError() {
        _createState.value = _createState.value.copy(error = null)
    }

    // MARK: - 家长表单

    fun selectChild(childId: String) {
        _createState.value = _createState.value.copy(selectedChildId = childId, selectedCourseId = null)
    }

    fun selectCourse(courseId: String?) {
        _createState.value = _createState.value.copy(selectedCourseId = courseId)
    }

    /** 孩子有效课程（排除已退款/已过期） */
    fun activeBalances(): List<com.together.app.core.model.ChildBalance> {
        val cur = _createState.value
        val child = cur.childList.firstOrNull { it.childId == cur.selectedChildId } ?: return emptyList()
        return (child.balances ?: emptyList()).filter { it.status == 1 || it.status == 2 }
    }

    // MARK: - 老师表单

    fun selectClass(classItem: PostService.TeacherClassItem) {
        _createState.value = _createState.value.copy(selectedClass = classItem, selectedStudentIds = emptySet())
        loadClassStudents(classItem.classId, retainEditStudents = false)
    }

    private fun loadClassStudents(classId: String, retainEditStudents: Boolean) {
        viewModelScope.launch {
            try {
                val students = PostService.fetchTeacherClassStudents(classId)
                val cur = _createState.value
                val selected = if (retainEditStudents) {
                    pendingEditChildIds.toSet()
                } else {
                    emptySet()
                }
                _createState.value = cur.copy(classStudents = students, selectedStudentIds = selected)
            } catch (e: Exception) {
                _createState.value = _createState.value.copy(error = e.message ?: "加载学生失败")
            }
        }
    }

    fun toggleStudent(childId: String) {
        val cur = _createState.value
        val selected = if (childId in cur.selectedStudentIds) {
            cur.selectedStudentIds - childId
        } else {
            cur.selectedStudentIds + childId
        }
        _createState.value = cur.copy(selectedStudentIds = selected)
    }

    fun toggleConsume(on: Boolean) {
        _createState.value = _createState.value.copy(consumeEnabled = on)
    }

    // MARK: - 发布

    fun publish() {
        val cur = _createState.value
        // 校验
        if (cur.images.isEmpty() && !cur.isEditing) {
            _createState.value = cur.copy(error = "请至少上传一张作品图片")
            return
        }
        // 仅孩子作品(postType=2)需关联孩子；动态不关联孩子
        if (cur.editingRole == 1 && cur.postType == 2 && cur.selectedChildId == null) {
            _createState.value = cur.copy(error = "请选择关联孩子")
            return
        }
        if (cur.editingRole == 2 && cur.consumeEnabled) {
            if (cur.selectedClass == null) {
                _createState.value = cur.copy(error = "请先选择课程班级")
                return
            }
            if (cur.selectedStudentIds.isEmpty()) {
                _createState.value = cur.copy(error = "请选择上课学生")
                return
            }
        }
        _createState.value = cur.copy(publishing = true, error = null)
        viewModelScope.launch {
            try {
                // 上传新选图片
                val newUris = cur.images.filterIsInstance<PostImage.New>().map { it.uri }
                val uploadedUrls = if (newUris.isNotEmpty()) {
                    val files = newUris.map { uriToFile(it) }
                    val json = ApiService.upload(files, "post")
                    json.strList("urls")
                } else {
                    emptyList()
                }
                // 合并图片 URL：已有 + 新上传
                var uploadIdx = 0
                val imageUrls = cur.images.map { img ->
                    when (img) {
                        is PostImage.Existing -> img.url
                        is PostImage.New -> {
                            val url = uploadedUrls.getOrNull(uploadIdx) ?: ""
                            uploadIdx++
                            url
                        }
                    }
                }.filter { it.isNotEmpty() }

                val content = cur.content.trim()
                val topic = cur.topic
                val visibility = cur.visibility
                val loc = cur.location

                if (cur.isEditing) {
                    val postId = cur.editingPostId ?: return@launch
                    if (cur.editingRole == 2) {
                        PostService.updateTeacherPost(
                            postId = postId, content = content,
                            images = imageUrls, topic = topic, visibility = visibility,
                            latitude = loc?.latitude, longitude = loc?.longitude,
                            locationName = loc?.name, clearLocation = loc == null
                        )
                    } else {
                        PostService.updatePost(
                            postId = postId, content = content, images = imageUrls,
                            childId = cur.selectedChildId ?: "", courseId = cur.selectedCourseId,
                            topic = topic, visibility = visibility,
                            latitude = loc?.latitude, longitude = loc?.longitude,
                            locationName = loc?.name, clearLocation = loc == null
                        )
                    }
                } else {
                    if (cur.editingRole == 2) {
                        // 老师：动态不关联班级学生；孩子作品关联学生+可选消课
                        if (cur.postType == 1) {
                            PostService.createTeacherPost(
                                content = content, images = imageUrls,
                                topic = topic, visibility = visibility, type = 1,
                                latitude = loc?.latitude, longitude = loc?.longitude,
                                locationName = loc?.name
                            )
                        } else {
                            val students = cur.selectedStudentIds.map {
                                mapOf("child_id" to it, "count" to 1)
                            }
                            PostService.createTeacherPost(
                                content = content, images = imageUrls,
                                courseId = cur.selectedClass?.course?.courseId,
                                classId = cur.selectedClass?.classId,
                                students = students, consume = cur.consumeEnabled,
                                topic = topic, visibility = visibility, type = 2,
                                latitude = loc?.latitude, longitude = loc?.longitude,
                                locationName = loc?.name
                            )
                        }
                    } else {
                        // 家长：关联课程=孩子作品(2)；纯分享=动态(1)
                        PostService.createPost(
                            content = content, images = imageUrls,
                            childId = cur.selectedChildId ?: "",
                            courseId = cur.selectedCourseId,
                            topic = topic, visibility = visibility,
                            type = if (cur.selectedCourseId != null) 2 else 1,
                            latitude = loc?.latitude, longitude = loc?.longitude,
                            locationName = loc?.name
                        )
                    }
                }
                _createState.value = _createState.value.copy(publishing = false, success = true)
            } catch (e: Exception) {
                _createState.value = _createState.value.copy(publishing = false, error = e.message ?: "发布失败")
            }
        }
    }

    /** Uri → 缓存文件（对齐 ChildViewModel.uriToFile） */
    private fun uriToFile(uri: Uri): File {
        val context = getApplication<Application>()
        val input = context.contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("无法读取图片")
        val file = File(context.cacheDir, "post_${System.currentTimeMillis()}.jpg")
        input.use { i ->
            file.outputStream().use { output -> i.copyTo(output) }
        }
        return file
    }
}
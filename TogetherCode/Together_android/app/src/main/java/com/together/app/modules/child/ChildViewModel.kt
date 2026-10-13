package com.together.app.modules.child

import android.app.Application
import android.net.Uri
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.together.app.core.model.ChildBalance
import com.together.app.core.model.ChildItem
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.strList
import com.together.app.services.ChildService
import com.together.app.services.ChildService.ChildGrowthEvent
import com.together.app.services.ChildService.ChildWorkItem
import com.together.app.services.ChildService.LessonLogItem
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import java.io.File

/**
 * 孩子模块 ViewModel（对齐 iOS Child 各 ViewController 的状态管理）
 *
 * 覆盖四个页面的状态：
 * - 我的孩子列表（MyChildrenScreen）
 * - 添加孩子（AddChildScreen）
 * - 孩子主页（ChildHomeScreen：作品 + 课程聚合 + 成长动态）
 * - 课时明细（ChildBalanceScreen：课时余额 + 消课记录）
 */
class ChildViewModel(app: Application) : AndroidViewModel(app) {

    companion object {
        /** 页面间传递孩子对象（Navigation Compose 不支持复杂对象参数） */
        var navChild: ChildItem? = null
    }

    // MARK: - 孩子课程聚合（同课程课包合并，对齐 iOS ChildCourseAggregate）

    data class ChildCourseAggregate(
        val courseId: String,
        val courseTitle: String,
        val studioName: String?,
        val total: Int,
        val consumed: Int,
        val remaining: Int,
        val isRefunded: Boolean
    )

    // MARK: - 孩子列表（MyChildrenScreen）

    data class ListState(
        val loading: Boolean = true,
        val children: List<ChildItem> = emptyList(),
        val error: String? = null
    )

    private val _listState = MutableStateFlow(ListState())
    val listState: StateFlow<ListState> = _listState

    fun loadChildren() {
        viewModelScope.launch {
            _listState.value = _listState.value.copy(loading = true, error = null)
            try {
                val list = ChildService.fetchChildren()
                _listState.value = _listState.value.copy(loading = false, children = list)
            } catch (e: Exception) {
                _listState.value = _listState.value.copy(loading = false, error = e.message ?: "加载失败")
            }
        }
    }

    // MARK: - 添加孩子（AddChildScreen）

    data class AddState(
        val saving: Boolean = false,
        val error: String? = null
    )

    private val _addState = MutableStateFlow(AddState())
    val addState: StateFlow<AddState> = _addState

    /**
     * 添加孩子
     * @param customAvatarUri 相册自定义头像（非空时先上传 OSS 再用 URL 作为 avatar）
     */
    fun addChild(
        nickname: String,
        avatar: String?,
        birthday: String,
        gender: Int,
        interests: List<String>,
        customAvatarUri: Uri? = null,
        onSuccess: () -> Unit = {}
    ) {
        viewModelScope.launch {
            _addState.value = _addState.value.copy(saving = true, error = null)
            try {
                val finalAvatar = if (customAvatarUri != null) {
                    val file = uriToFile(customAvatarUri)
                    val json = ApiService.upload(listOf(file), "avatar")
                    json.strList("urls").firstOrNull() ?: avatar
                } else {
                    avatar
                }
                ChildService.createChild(nickname, finalAvatar, birthday, gender, interests)
                _addState.value = _addState.value.copy(saving = false)
                onSuccess()
            } catch (e: Exception) {
                _addState.value = _addState.value.copy(saving = false, error = e.message ?: "保存失败")
            }
        }
    }

    /** Uri → 缓存文件（对齐 OrderViewModel.uriToFile） */
    private fun uriToFile(uri: Uri): File {
        val context = getApplication<Application>()
        val input = context.contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("无法读取图片")
        val file = File(context.cacheDir, "avatar_${System.currentTimeMillis()}.jpg")
        input.use { input ->
            file.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        return file
    }

    fun clearAddError() {
        _addState.value = _addState.value.copy(error = null)
    }

    // MARK: - 孩子主页（ChildHomeScreen）

    data class HomeState(
        val loadingWorks: Boolean = true,
        val loadingGrowth: Boolean = true,
        val works: List<ChildWorkItem> = emptyList(),
        val dynamics: List<ChildGrowthEvent> = emptyList(),
        val worksError: String? = null,
        val growthError: String? = null
    )

    private val _homeState = MutableStateFlow(HomeState())
    val homeState: StateFlow<HomeState> = _homeState

    fun loadChildHome(childId: String) {
        viewModelScope.launch {
            _homeState.value = HomeState()
            val worksDeferred = async { ChildService.fetchChildWorks(childId) }
            val growthDeferred = async { ChildService.fetchChildGrowth(childId) }
            try {
                val works = worksDeferred.await()
                _homeState.value = _homeState.value.copy(loadingWorks = false, works = works)
            } catch (e: Exception) {
                _homeState.value = _homeState.value.copy(loadingWorks = false, worksError = e.message ?: "加载失败")
            }
            try {
                val growth = growthDeferred.await()
                _homeState.value = _homeState.value.copy(loadingGrowth = false, dynamics = growth)
            } catch (e: Exception) {
                _homeState.value = _homeState.value.copy(loadingGrowth = false, growthError = e.message ?: "加载失败")
            }
        }
    }

    /** 课程聚合：同课程课包合并（status=4 已退款不计入统计，仅标记） */
    fun aggregateCourses(child: ChildItem): List<ChildCourseAggregate> {
        val map = linkedMapOf<String, ChildCourseAggregate>()
        for (balance in child.balances ?: emptyList()) {
            val key = balance.courseId ?: balance.courseTitle ?: continue
            val existing = map[key]
            if (balance.status == 4) {
                // 已退款：仅标记退款，不累加课时
                map[key] = (existing ?: ChildCourseAggregate(
                    courseId = balance.courseId ?: "",
                    courseTitle = balance.courseTitle ?: "未命名课程",
                    studioName = balance.studioName,
                    total = 0, consumed = 0, remaining = 0, isRefunded = true
                )).copy(isRefunded = true)
            } else {
                val base = existing ?: ChildCourseAggregate(
                    courseId = balance.courseId ?: "",
                    courseTitle = balance.courseTitle ?: "未命名课程",
                    studioName = balance.studioName,
                    total = 0, consumed = 0, remaining = 0, isRefunded = false
                )
                map[key] = base.copy(
                    total = base.total + balance.totalLessons,
                    consumed = base.consumed + balance.consumedLessons,
                    remaining = base.remaining + balance.remainingLessons,
                    isRefunded = false
                )
            }
        }
        return map.values
            .filter { it.total > 0 || it.isRefunded }
            .sortedBy { it.courseTitle }
    }

    // MARK: - 课时明细（ChildBalanceScreen）

    data class BalanceState(
        val loadingBalances: Boolean = true,
        val loadingLogs: Boolean = false,
        val balances: List<ChildBalance> = emptyList(),
        val logs: List<LessonLogItem> = emptyList(),
        val balancesError: String? = null,
        val logsError: String? = null
    )

    private val _balanceState = MutableStateFlow(BalanceState())
    val balanceState: StateFlow<BalanceState> = _balanceState

    fun loadBalances(childId: String) {
        viewModelScope.launch {
            _balanceState.value = _balanceState.value.copy(loadingBalances = true, balancesError = null)
            try {
                val list = ChildService.fetchChildBalances(childId)
                _balanceState.value = _balanceState.value.copy(loadingBalances = false, balances = list)
            } catch (e: Exception) {
                _balanceState.value = _balanceState.value.copy(loadingBalances = false, balancesError = e.message ?: "加载失败")
            }
        }
    }

    fun loadLogs(childId: String) {
        viewModelScope.launch {
            _balanceState.value = _balanceState.value.copy(loadingLogs = true, logsError = null)
            try {
                val list = ChildService.fetchLessonLogs(childId)
                _balanceState.value = _balanceState.value.copy(loadingLogs = false, logs = list)
            } catch (e: Exception) {
                _balanceState.value = _balanceState.value.copy(loadingLogs = false, logsError = e.message ?: "加载失败")
            }
        }
    }
}
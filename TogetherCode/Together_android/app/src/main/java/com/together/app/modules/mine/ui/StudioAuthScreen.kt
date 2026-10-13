package com.together.app.modules.mine.ui

import android.app.Application
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import com.together.app.core.network.ApiService
import com.together.app.core.network.JsonHelper.str
import com.together.app.core.network.JsonHelper.strList
import com.together.app.core.network.JsonHelper.strOrNull
import com.together.app.services.AuthService
import com.together.app.services.SearchService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject

// MARK: - ViewModel

/**
 * 工作室入驻认证 ViewModel（对齐 iOS StudioAuthViewController）
 */
class StudioAuthViewModel(app: Application) : AndroidViewModel(app) {

    /** 标签加载状态 */
    enum class TagState { Loading, Success, Empty, Error }

    data class State(
        val showPending: Boolean = false,
        val rejectReason: String? = null,
        // 标签
        val tagState: TagState = TagState.Loading,
        val tagOptions: List<String> = emptyList(),
        // 基本信息
        val name: String = "",
        val city: String = "",
        val address: String = "",
        val contact: String = "",
        val phone: String = "",
        val businessTags: Set<String> = emptySet(),
        val intro: String = "",
        // 资质场地
        val license: String = "",
        val permit: String = "暂无",
        val photoUris: List<Uri> = emptyList(),
        val submitting: Boolean = false
    )

    private val _state = MutableStateFlow(State())
    val state: StateFlow<State> = _state.asStateFlow()

    private val _toast = MutableStateFlow<String?>(null)
    val toast: StateFlow<String?> = _toast.asStateFlow()

    private val _submitted = MutableStateFlow(false)
    val submitted: StateFlow<Boolean> = _submitted.asStateFlow()

    companion object {
        private const val MAX_PHOTOS = 6
        val PERMIT_OPTIONS = listOf("有", "暂无")
    }

    fun clearToast() { _toast.value = null }

    /** 初始化：根据缓存状态决定显示表单还是审核中 */
    fun initFromCache() {
        val (status, reason, apply) = AuthNavCache.consume()
        if (status == "pending") {
            _state.value = _state.value.copy(showPending = true)
            return
        }
        if (status == "rejected") {
            _state.value = _state.value.copy(rejectReason = reason)
        }
        loadTags(apply)
    }

    /** 加载营业类型标签（对齐 iOS loadStudioTagsThenShowForm） */
    fun loadTags(apply: JsonObject? = null) {
        _state.value = _state.value.copy(tagState = TagState.Loading)
        viewModelScope.launch {
            try {
                val tags = SearchService.fetchScopedTags(scope = 1)
                if (tags.isEmpty()) {
                    _state.value = _state.value.copy(tagState = TagState.Empty)
                } else {
                    _state.value = _state.value.copy(
                        tagState = TagState.Success,
                        tagOptions = tags.map { it.name }
                    )
                    // 被驳回时回显上次提交数据
                    if (apply != null) applyPreviousData(apply)
                }
            } catch (_: Exception) {
                _state.value = _state.value.copy(tagState = TagState.Error)
            }
        }
    }

    private fun applyPreviousData(apply: JsonObject) {
        val bizTags = apply.strList("business_tags").ifEmpty {
            apply.strOrNull("business_type")?.let { listOf(it) } ?: emptyList()
        }.toSet()
        _state.value = _state.value.copy(
            name = apply.strOrNull("name") ?: "",
            city = apply.strOrNull("city") ?: "",
            address = apply.strOrNull("address") ?: "",
            contact = apply.strOrNull("contact_name") ?: "",
            phone = apply.strOrNull("phone") ?: "",
            businessTags = bizTags,
            intro = apply.strOrNull("intro") ?: "",
            license = apply.strOrNull("license") ?: "",
            permit = apply.strOrNull("permit")?.takeIf { it.isNotEmpty() } ?: "暂无"
        )
    }

    // MARK: - 字段更新

    fun updateName(v: String) { _state.value = _state.value.copy(name = v) }
    fun updateCity(v: String) { _state.value = _state.value.copy(city = v) }
    fun updateAddress(v: String) { _state.value = _state.value.copy(address = v) }
    fun updateContact(v: String) { _state.value = _state.value.copy(contact = v) }
    fun updatePhone(v: String) { _state.value = _state.value.copy(phone = v) }
    fun updateIntro(v: String) { _state.value = _state.value.copy(intro = v) }
    fun updateLicense(v: String) { _state.value = _state.value.copy(license = v) }
    fun toggleBusinessTag(v: String) {
        val cur = _state.value.businessTags
        _state.value = _state.value.copy(businessTags = if (v in cur) cur - v else cur + v)
    }
    fun selectPermit(v: String) { _state.value = _state.value.copy(permit = v) }

    fun addPhotos(uris: List<Uri>) {
        val cur = _state.value.photoUris
        val remain = MAX_PHOTOS - cur.size
        _state.value = _state.value.copy(photoUris = cur + uris.take(remain))
    }
    fun removePhoto(index: Int) {
        _state.value = _state.value.copy(
            photoUris = _state.value.photoUris.filterIndexed { i, _ -> i != index }
        )
    }

    // MARK: - 提交

    fun submit() {
        val s = _state.value
        if (s.submitting) return
        if (s.name.isBlank()) { _toast.value = "请填写工作室名称"; return }
        if (s.phone.isBlank() || s.phone.length < 11) { _toast.value = "请填写正确的联系手机号"; return }
        if (s.businessTags.isEmpty()) { _toast.value = "请选择营业类型（至少 1 项）"; return }
        if (s.license.isBlank()) { _toast.value = "请填写营业执照号"; return }
        if (s.photoUris.isEmpty()) { _toast.value = "请至少上传 1 张场地照片"; return }

        viewModelScope.launch {
            _state.value = s.copy(submitting = true)
            try {
                val photoUrls = uploadPhotos(s.photoUris)
                val selectedBizTags = s.tagOptions.filter { it in s.businessTags }
                val payload = buildMap<String, Any?> {
                    put("name", s.name.trim())
                    put("city", s.city.trim())
                    put("address", s.address.trim())
                    put("contact_name", s.contact.trim())
                    put("phone", s.phone.trim())
                    put("business_type", selectedBizTags.firstOrNull() ?: "")
                    put("business_tags", selectedBizTags)
                    put("license", s.license.trim())
                    put("permit", s.permit)
                    put("intro", s.intro.trim())
                    put("photos", photoUrls)
                    photoUrls.firstOrNull()?.let { put("cover", it) }
                }
                val json = AuthService.submitRoleApply("studio", payload)
                val newStatus = json.str("status")
                if (newStatus == "pending") {
                    _state.value = _state.value.copy(showPending = true, submitting = false)
                } else {
                    _toast.value = "提交成功"
                    _submitted.value = true
                    _state.value = _state.value.copy(submitting = false)
                }
            } catch (e: Exception) {
                _toast.value = e.message ?: "提交失败"
                _state.value = _state.value.copy(submitting = false)
            }
        }
    }

    private suspend fun uploadPhotos(uris: List<Uri>): List<String> {
        if (uris.isEmpty()) return emptyList()
        val context = getApplication<Application>()
        val files = uris.map { authUriToFile(context, it) }
        return try {
            val json = ApiService.upload(files, "studio")
            files.forEach { it.delete() }
            json.strList("urls")
        } catch (e: Exception) {
            files.forEach { it.delete() }
            throw e
        }
    }
}

// MARK: - 工作室入驻认证页面

/**
 * 工作室入驻认证页（对齐 iOS StudioAuthViewController）
 */
@Composable
fun StudioAuthScreen(
    onBack: () -> Unit,
    viewModel: StudioAuthViewModel = viewModel()
) {
    val state by viewModel.state.collectAsState()
    val toast by viewModel.toast.collectAsState()
    val submitted by viewModel.submitted.collectAsState()
    val context = LocalContext.current

    LaunchedEffect(Unit) { viewModel.initFromCache() }

    LaunchedEffect(toast) {
        if (toast != null) {
            android.widget.Toast.makeText(context, toast, android.widget.Toast.LENGTH_SHORT).show()
            viewModel.clearToast()
        }
    }

    LaunchedEffect(submitted) {
        if (submitted) onBack()
    }

    // 图片选择器（最多 6 张）
    val imagePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(maxItems = 6)
    ) { uris ->
        if (uris.isNotEmpty()) viewModel.addPhotos(uris)
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "工作室入驻", onBack = onBack)

        if (state.showPending) {
            AuthPendingView(
                title = "入驻审核中",
                desc = "已提交至艺启平台，由平台运营审核（1–3 个工作日）。结果会通知联系人，审核通过后即可进入工作室端。",
                onDone = onBack
            )
        } else {
            when (state.tagState) {
                StudioAuthViewModel.TagState.Loading -> {
                    Column(
                        modifier = Modifier.fillMaxSize(),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        androidx.compose.material3.CircularProgressIndicator(color = AppColors.Brand)
                    }
                }
                StudioAuthViewModel.TagState.Empty -> {
                    TagRetryView(
                        empty = true,
                        onRetry = { viewModel.loadTags() }
                    )
                }
                StudioAuthViewModel.TagState.Error -> {
                    TagRetryView(
                        empty = false,
                        onRetry = { viewModel.loadTags() }
                    )
                }
                StudioAuthViewModel.TagState.Success -> {
                    StudioAuthForm(
                        viewModel = viewModel,
                        state = state,
                        onAddPhoto = {
                            val remain = 6 - state.photoUris.size
                            if (remain > 0) {
                                imagePicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                            } else {
                                android.widget.Toast.makeText(context, "最多上传 6 张", android.widget.Toast.LENGTH_SHORT).show()
                            }
                        }
                    )
                }
            }
        }
    }
}

// MARK: - 标签加载失败/为空兜底

@Composable
private fun TagRetryView(empty: Boolean, onRetry: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize().padding(horizontal = AppDimens.L),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            imageVector = if (empty) Icons.Filled.Store else Icons.Filled.WifiOff,
            contentDescription = null,
            tint = AppColors.Muted,
            modifier = Modifier.size(46.dp)
        )
        Spacer(Modifier.height(AppDimens.L))
        Text(
            text = if (empty) "暂未配置营业类型标签" else "营业类型加载失败",
            color = AppColors.Ink,
            fontSize = 16.sp
        )
        Spacer(Modifier.height(AppDimens.S))
        Text(
            text = if (empty) "请联系平台在「标签管理 · 工作室」中添加标签后重试"
                  else "网络异常，请检查网络后重新加载",
            color = AppColors.Sub,
            fontSize = 13.sp
        )
        Spacer(Modifier.height(AppDimens.Xl))
        AuthSubmitButton(
            text = "重新加载",
            enabled = true,
            onClick = onRetry
        )
    }
}

// MARK: - 表单

@Composable
private fun StudioAuthForm(
    viewModel: StudioAuthViewModel,
    state: StudioAuthViewModel.State,
    onAddPhoto: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
    ) {
        // 驳回提示条
        state.rejectReason?.let { reason ->
            if (reason.isNotEmpty()) {
                Spacer(Modifier.height(AppDimens.L))
                AuthRejectBar(reason = reason)
            }
        }

        Spacer(Modifier.height(AppDimens.L))

        // 说明卡
        AuthHeroCard(
            icon = Icons.Filled.Store,
            title = "工作室需资质审核",
            desc = "提交营业执照与办学资质，由艺启平台审核（1–3 个工作日）。通过后开启经营后台：课程管理、学员、订单与结算。"
        )

        Spacer(Modifier.height(AppDimens.L))

        // 卡 1 · 基本信息
        AuthFormCard {
            AuthFieldRow("工作室名称", state.name, "如：青苗艺术工坊", viewModel::updateName)
            Spacer(Modifier.height(AppDimens.L))
            AuthFieldRow("所在城市 / 区域", state.city, "如：杭州 · 西湖区", viewModel::updateCity)
            Spacer(Modifier.height(AppDimens.L))
            AuthFieldRow("详细地址", state.address, "街道门牌", viewModel::updateAddress)
            Spacer(Modifier.height(AppDimens.L))
            AuthFieldRow("联系人", state.contact, "如：王校长", viewModel::updateContact)
            Spacer(Modifier.height(AppDimens.L))
            AuthFieldRow(
                "联系手机号", state.phone, "用于审核与经营通知",
                viewModel::updatePhone,
                keyboardType = KeyboardType.Phone
            )
            Spacer(Modifier.height(AppDimens.L))

            // 营业类型（多选，来自标签库）
            FieldLabel("营业类型（可多选）")
            Spacer(Modifier.height(AppDimens.S))
            SelectableTagFlow(
                options = state.tagOptions,
                selected = state.businessTags,
                onToggle = viewModel::toggleBusinessTag
            )
            Spacer(Modifier.height(AppDimens.L))

            // 工作室简介
            FieldLabel("工作室简介")
            Spacer(Modifier.height(AppDimens.S))
            AuthIntroField(
                value = state.intro,
                onValueChange = viewModel::updateIntro,
                placeholder = "介绍你的工作室特色..."
            )
        }

        Spacer(Modifier.height(AppDimens.L))

        // 卡 2 · 资质与场地
        AuthFormCard {
            AuthFieldRow("营业执照号", state.license, "统一社会信用代码", viewModel::updateLicense)
            Spacer(Modifier.height(AppDimens.L))

            // 是否有办学许可（单选）
            FieldLabel("是否有办学许可")
            Spacer(Modifier.height(AppDimens.S))
            SelectableTagFlow(
                options = StudioAuthViewModel.PERMIT_OPTIONS,
                selected = setOf(state.permit),
                onToggle = viewModel::selectPermit
            )
            Spacer(Modifier.height(AppDimens.L))

            // 场地照片
            FieldLabel("教学场地照片")
            Spacer(Modifier.height(2.dp))
            FieldLabel("最多 6 张，展示教室、教学环境，审核更易通过")
            Spacer(Modifier.height(AppDimens.S))
            PhotoGridField(
                uris = state.photoUris,
                maxCount = 6,
                onAdd = onAddPhoto,
                onRemove = viewModel::removePhoto
            )
        }

        Spacer(Modifier.height(AppDimens.Xl))
        Spacer(Modifier.height(60.dp))

        // 提交按钮
        AuthSubmitButton(
            text = if (state.submitting) "提交中..." else "提交入驻申请",
            enabled = !state.submitting,
            onClick = viewModel::submit
        )
        Spacer(Modifier.height(AppDimens.L))
    }
}
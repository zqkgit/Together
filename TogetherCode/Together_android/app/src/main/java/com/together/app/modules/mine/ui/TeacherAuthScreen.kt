package com.together.app.modules.mine.ui

import android.app.Application
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.School
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
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
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject

// MARK: - ViewModel

/**
 * 老师认证 ViewModel（对齐 iOS TeacherAuthViewController）
 */
class TeacherAuthViewModel(app: Application) : AndroidViewModel(app) {

    data class State(
        val showPending: Boolean = false,
        val rejectReason: String? = null,
        val name: String = "",
        val exp: String? = null,           // 单选：1–3 年 / 3–5 年 / 5 年以上
        val skills: Set<String> = emptySet(), // 多选
        val intro: String = "",
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
        val EXP_OPTIONS = listOf("1–3 年", "3–5 年", "5 年以上")
        val SKILL_OPTIONS = listOf("水彩", "硬笔书法", "国画", "黏土", "素描", "油画")
        private const val MAX_PHOTOS = 9
    }

    fun clearToast() { _toast.value = null }

    /** 初始化：根据缓存状态决定显示表单还是审核中 */
    fun initFromCache() {
        val (status, reason, apply) = AuthNavCache.consume()
        if (status == "pending") {
            _state.value = _state.value.copy(showPending = true)
            return
        }
        // 被驳回：回显上次提交数据 + 驳回原因
        if (status == "rejected") {
            _state.value = _state.value.copy(rejectReason = reason)
            if (apply != null) applyPreviousData(apply)
        }
    }

    private fun applyPreviousData(apply: JsonObject) {
        val name = apply.strOrNull("real_name") ?: ""
        val years = apply.strOrNull("years") ?: ""
        val exp = when {
            years.isEmpty() -> null
            years.toIntOrNull()?.let { it <= 3 } == true -> "1–3 年"
            years.toIntOrNull()?.let { it <= 5 } == true -> "3–5 年"
            else -> "5 年以上"
        }
        val subjects = apply.strOrNull("subjects")
            ?.takeIf { it.isNotEmpty() }
            ?.split(",")
            ?.toSet()
            ?: apply.strList("subjects").toSet()
        val intro = apply.strOrNull("intro") ?: ""
        _state.value = _state.value.copy(
            name = name, exp = exp, skills = subjects, intro = intro
        )
    }

    fun updateName(v: String) { _state.value = _state.value.copy(name = v) }
    fun selectExp(v: String) {
        val cur = _state.value.exp
        _state.value = _state.value.copy(exp = if (cur == v) null else v)
    }
    fun toggleSkill(v: String) {
        val cur = _state.value.skills
        _state.value = _state.value.copy(skills = if (v in cur) cur - v else cur + v)
    }
    fun updateIntro(v: String) { _state.value = _state.value.copy(intro = v) }
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

    fun submit() {
        val s = _state.value
        if (s.submitting) return
        if (s.name.isBlank()) { _toast.value = "请填写真实姓名"; return }
        if (s.exp == null) { _toast.value = "请选择教龄"; return }
        if (s.skills.isEmpty()) { _toast.value = "请选择擅长方向"; return }

        viewModelScope.launch {
            _state.value = s.copy(submitting = true)
            try {
                // 上传证书图片
                val portfolioUrls = uploadPhotos(s.photoUris)

                // 教龄 → 年数
                val expMap = mapOf("1–3 年" to 2, "3–5 年" to 4, "5 年以上" to 6)
                val years = expMap[s.exp] ?: 2

                val payload = buildMap<String, Any?> {
                    put("real_name", s.name.trim())
                    put("years", years)
                    put("subjects", s.skills.toList())
                    put("intro", s.intro.trim())
                    put("portfolio", portfolioUrls)
                }
                val json = AuthService.submitRoleApply("teacher", payload)
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
            val json = ApiService.upload(files, "cert")
            files.forEach { it.delete() }
            json.strList("urls")
        } catch (e: Exception) {
            files.forEach { it.delete() }
            throw e
        }
    }
}

// MARK: - 老师认证页面

/**
 * 老师认证页（对齐 iOS TeacherAuthViewController）
 */
@Composable
fun TeacherAuthScreen(
    onBack: () -> Unit,
    viewModel: TeacherAuthViewModel = viewModel()
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

    // 图片选择器（最多 9 张）
    val imagePicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(maxItems = 9)
    ) { uris ->
        if (uris.isNotEmpty()) viewModel.addPhotos(uris)
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "老师认证", onBack = onBack)

        if (state.showPending) {
            AuthPendingView(
                title = "认证审核中",
                desc = "已提交至艺启平台，预计 1–2 个工作日内完成审核。结果会通过消息通知你。",
                onDone = onBack
            )
        } else {
            TeacherAuthForm(
                viewModel = viewModel,
                state = state,
                onAddPhoto = {
                    val remain = 9 - state.photoUris.size
                    if (remain > 0) {
                        imagePicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    } else {
                        android.widget.Toast.makeText(context, "最多上传 9 张", android.widget.Toast.LENGTH_SHORT).show()
                    }
                }
            )
        }
    }
}

// MARK: - 表单

@Composable
private fun TeacherAuthForm(
    viewModel: TeacherAuthViewModel,
    state: TeacherAuthViewModel.State,
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
            icon = Icons.Filled.School,
            title = "老师身份需认证",
            desc = "提交教学资料后，由艺启平台审核（1–2 个工作日）。审核通过即可使用老师端：发作品、消课，并可申请与工作室合作。"
        )

        Spacer(Modifier.height(AppDimens.L))

        // 信息卡
        AuthFormCard {
            // 真实姓名
            AuthFieldRow(
                title = "真实姓名",
                value = state.name,
                placeholder = "如：陈晓",
                onValueChange = viewModel::updateName
            )
            Spacer(Modifier.height(AppDimens.L))

            // 教龄（单选）
            FieldLabel("教龄")
            Spacer(Modifier.height(AppDimens.S))
            SelectableTagFlow(
                options = TeacherAuthViewModel.EXP_OPTIONS,
                selected = state.exp?.let { setOf(it) } ?: emptySet(),
                onToggle = viewModel::selectExp
            )
            Spacer(Modifier.height(AppDimens.L))

            // 擅长方向（多选）
            FieldLabel("擅长方向（可多选）")
            Spacer(Modifier.height(AppDimens.S))
            SelectableTagFlow(
                options = TeacherAuthViewModel.SKILL_OPTIONS,
                selected = state.skills,
                onToggle = viewModel::toggleSkill
            )
            Spacer(Modifier.height(AppDimens.L))

            // 资质证书 / 作品集
            FieldLabel("资质证书 / 作品集")
            Spacer(Modifier.height(2.dp))
            FieldLabel("最多 9 张，审核通过后展示在老师主页")
            Spacer(Modifier.height(AppDimens.S))
            PhotoGridField(
                uris = state.photoUris,
                maxCount = 9,
                onAdd = onAddPhoto,
                onRemove = viewModel::removePhoto
            )
            Spacer(Modifier.height(AppDimens.L))

            // 一句话简介
            FieldLabel("一句话简介")
            Spacer(Modifier.height(AppDimens.S))
            AuthIntroField(
                value = state.intro,
                onValueChange = viewModel::updateIntro,
                placeholder = "用一句话介绍你的教学理念..."
            )
        }

        Spacer(Modifier.height(AppDimens.Xl))
        Spacer(Modifier.height(60.dp))

        // 提交按钮
        AuthSubmitButton(
            text = if (state.submitting) "提交中..." else "提交认证申请",
            enabled = !state.submitting,
            onClick = viewModel::submit
        )
        Spacer(Modifier.height(AppDimens.L))
    }
}
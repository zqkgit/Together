package com.together.app.modules.plaza.ui

import android.app.Application
import android.location.Geocoder
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.content.Context
import android.os.Bundle
import android.os.Looper
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.together.app.core.component.TogetherTopBar
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt

/** 地点搜索结果项 */
data class LocationPoint(
    val name: String,
    val address: String,
    val latitude: Double,
    val longitude: Double
)

/**
 * 位置搜索 ViewModel（完全使用 Android 原生 Geocoder，免费无 Key）
 * 对齐 iOS LocationSearchViewController
 */
class LocationSearchViewModel(app: Application) : AndroidViewModel(app) {

    data class UiState(
        val keyword: String = "",
        val currentPoint: LocationPoint? = null,
        val nearby: List<LocationPoint> = emptyList(),
        val nearbyLoading: Boolean = true,
        val results: List<LocationPoint> = emptyList(),
        val searching: Boolean = false
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    private val geocoder = Geocoder(app)
    private var currentCoord: Pair<Double, Double>? = null

    init {
        loadInitial()
    }

    /** 关键词防抖搜索（300ms，对齐 iOS scheduleSearch） */
    @OptIn(FlowPreview::class)
    private val keywordFlow = MutableStateFlow("")

    init {
        viewModelScope.launch {
            keywordFlow
                .debounce(300)
                .filter { it.isNotBlank() }
                .distinctUntilChanged()
                .collect { kw -> performSearch(kw) }
        }
    }

    fun onKeywordChanged(text: String) {
        _uiState.value = _uiState.value.copy(keyword = text)
        keywordFlow.value = text
        if (text.isBlank()) {
            _uiState.value = _uiState.value.copy(results = emptyList(), searching = false)
        }
    }

    /** 初始加载：当前位置 + 附近地点 */
    private fun loadInitial() {
        viewModelScope.launch {
            // 快路径：缓存位置；慢路径：主动请求一次定位（8s 超时，模拟器 geo fix 后可获取）
            val coord = withContext(Dispatchers.IO) {
                getLastKnownLocation() ?: requestFreshLocation()
            }
            if (coord == null) {
                _uiState.value = _uiState.value.copy(nearbyLoading = false, currentPoint = null)
                return@launch
            }
            currentCoord = coord
            // 反地理编码出当前位置名
            val point = withContext(Dispatchers.IO) { reverseGeocode(coord.first, coord.second) }
            _uiState.value = _uiState.value.copy(currentPoint = point)
            // 附近地点（分类关键词检索）
            fetchNearby(coord.first, coord.second)
        }
    }

    /** 关键词搜索（Geocoder.getFromLocationName，免费） */
    private suspend fun performSearch(keyword: String) {
        _uiState.value = _uiState.value.copy(searching = true, results = emptyList())
        val addresses = withContext(Dispatchers.IO) {
            try {
                @Suppress("DEPRECATION")
                geocoder.getFromLocationName(keyword, 15) ?: emptyList()
            } catch (_: Exception) {
                emptyList()
            }
        }
        val points = addresses.mapNotNull { a ->
            val name = a.featureName ?: a.getAddressLine(0) ?: return@mapNotNull null
            val addr = a.getAddressLine(0) ?: ""
            if (a.hasLatitude() && a.hasLongitude()) {
                LocationPoint(name = name, address = addr, latitude = a.latitude, longitude = a.longitude)
            } else null
        }
        _uiState.value = _uiState.value.copy(searching = false, results = points)
    }

    /** 附近地点：分类关键词 + 边界框检索（对齐 iOS fetchNearbyByKeyword 兜底策略） */
    private fun fetchNearby(lat: Double, lng: Double) {
        viewModelScope.launch {
            val delta = 0.03 // 约 3km
            val queries = listOf("美食", "咖啡", "便利店", "超市", "学校", "公园")
            val all = withContext(Dispatchers.IO) {
                queries.flatMap { q ->
                    try {
                        @Suppress("DEPRECATION")
                        geocoder.getFromLocationName(q, 5, lat - delta, lng - delta, lat + delta, lng + delta)
                            ?: emptyList()
                    } catch (_: Exception) {
                        emptyList()
                    }
                }
            }
            val points = all.mapNotNull { a ->
                val name = a.featureName ?: return@mapNotNull null
                if (name.isBlank()) return@mapNotNull null
                if (!a.hasLatitude() || !a.hasLongitude()) return@mapNotNull null
                LocationPoint(
                    name = name,
                    address = a.getAddressLine(0) ?: "",
                    latitude = a.latitude,
                    longitude = a.longitude
                )
            }
            // 同名去重 + 按距离排序，取前 20
            val seen = mutableSetOf<String>()
            val deduped = points.filter { seen.add(it.name) }
                .sortedBy { distanceKm(it.latitude, it.longitude, lat, lng) }
                .take(20)
            _uiState.value = _uiState.value.copy(nearby = deduped, nearbyLoading = false)
        }
    }

    /** 反地理编码（Geocoder.getFromLocation，免费） */
    private fun reverseGeocode(lat: Double, lng: Double): LocationPoint? {
        return try {
            @Suppress("DEPRECATION")
            val addresses = geocoder.getFromLocation(lat, lng, 1)
            val a = addresses?.firstOrNull()
            val name = a?.featureName?.takeIf { it.isNotBlank() }
                ?: a?.getAddressLine(0)?.takeIf { it.isNotBlank() }
                ?: "当前位置"
            LocationPoint(name = name, address = a?.getAddressLine(0) ?: "", latitude = lat, longitude = lng)
        } catch (_: Exception) {
            LocationPoint(name = "当前位置", address = "", latitude = lat, longitude = lng)
        }
    }

    @Suppress("DEPRECATION")
    private fun getLastKnownLocation(): Pair<Double, Double>? {
        return try {
            val lm = getApplication<Application>().getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val loc = lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                ?: lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                ?: lm.getLastKnownLocation(LocationManager.PASSIVE_PROVIDER)
            loc?.let { Pair(it.latitude, it.longitude) }
        } catch (_: Exception) {
            null
        }
    }

    /** 主动请求一次定位（requestSingleUpdate，8s 超时兜底，模拟器 geo fix 后可获取） */
    @Suppress("DEPRECATION", "MissingPermission")
    private suspend fun requestFreshLocation(): Pair<Double, Double>? {
        val lm = getApplication<Application>().getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER)
        for (provider in providers) {
            if (!lm.isProviderEnabled(provider)) continue
            val result = withTimeoutOrNull(8000) {
                suspendCancellableCoroutine<Pair<Double, Double>?> { cont ->
                    val listener = object : LocationListener {
                        override fun onLocationChanged(location: Location) {
                            if (cont.isActive) cont.resume(Pair(location.latitude, location.longitude))
                        }
                        override fun onStatusChanged(p: String?, status: Int, extras: Bundle?) {}
                        override fun onProviderEnabled(p: String) {}
                        override fun onProviderDisabled(p: String) {
                            if (cont.isActive) cont.resume(null)
                        }
                    }
                    try {
                        lm.requestSingleUpdate(provider, listener, Looper.getMainLooper())
                    } catch (e: Exception) {
                        if (cont.isActive) cont.resume(null)
                    }
                    cont.invokeOnCancellation {
                        try { lm.removeUpdates(listener) } catch (_: Exception) {}
                    }
                }
            }
            if (result != null) return result
        }
        return null
    }

    /** Haversine 距离（km） */
    private fun distanceKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
        val r = 6371.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLng = Math.toRadians(lng2 - lng1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2)
        return r * 2 * asin(sqrt(a))
    }
}

/**
 * 位置搜索页（对齐 iOS LocationSearchViewController 半屏卡片）
 * 搜索地点 + 当前位置 + 附近地点，全部使用 Android 原生 Geocoder，免费无 Key
 */
@Composable
fun LocationSearchScreen(
    viewModel: LocationSearchViewModel = viewModel(),
    onBack: () -> Unit = {},
    onSelect: (Double, Double, String) -> Unit = { _, _, _ -> }
) {
    val state by viewModel.uiState.collectAsState()
    val isSearchMode = state.keyword.isNotBlank()

    fun selectPoint(p: LocationPoint) {
        onSelect(p.latitude, p.longitude, p.name)
        onBack()
    }

    Column(modifier = Modifier.fillMaxSize().background(AppColors.Bg)) {
        TogetherTopBar(title = "选择位置", onBack = onBack)

        // 搜索框
        SearchField(
            keyword = state.keyword,
            onKeywordChanged = viewModel::onKeywordChanged
        )

        Spacer(modifier = Modifier.height(AppDimens.M))

        if (isSearchMode) {
            // 搜索模式：结果列表
            when {
                state.searching -> LoadingRow("搜索中...")
                state.results.isEmpty() -> EmptyRow("未找到相关地点，换个关键词试试")
                else -> {
                    LazyColumn(
                        contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = AppDimens.L),
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        items(state.results, key = { "${it.latitude},${it.longitude}" }) { point ->
                            LocationPointCell(point) { selectPoint(point) }
                        }
                    }
                }
            }
        } else {
            // 默认模式：当前位置 + 附近地点
            LazyColumn(
                contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = AppDimens.L),
                verticalArrangement = Arrangement.spacedBy(2.dp)
            ) {
                // 当前位置
                state.currentPoint?.let { current ->
                    item(key = "current") {
                        SectionHeader("当前位置")
                        LocationPointCell(current, isCurrent = true) { selectPoint(current) }
                    }
                }

                // 附近地点
                item(key = "nearby_header") {
                    SectionHeader("附近地点")
                }
                when {
                    state.nearbyLoading -> item(key = "nearby_loading") { LoadingRow("正在获取附近地点...") }
                    state.nearby.isEmpty() -> item(key = "nearby_empty") { EmptyRow("附近未找到地点，可搜索关键词") }
                    else -> {
                        items(state.nearby, key = { "${it.latitude},${it.longitude}" }) { point ->
                            LocationPointCell(point) { selectPoint(point) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SearchField(keyword: String, onKeywordChanged: (String) -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L)
            .clip(RoundedCornerShape(22.dp))
            .background(AppColors.Surface)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(Icons.Default.Search, contentDescription = null, tint = AppColors.Muted, modifier = Modifier.size(18.dp))
        Spacer(modifier = Modifier.width(8.dp))
        Box(modifier = Modifier.weight(1f)) {
            BasicTextField(
                value = keyword,
                onValueChange = onKeywordChanged,
                textStyle = TextStyle(fontSize = 15.sp, color = AppColors.Ink),
                cursorBrush = SolidColor(AppColors.Brand),
                singleLine = true,
                decorationBox = { inner ->
                    if (keyword.isEmpty()) {
                        Text("搜索地点", fontSize = 15.sp, color = AppColors.Muted)
                    }
                    inner()
                }
            )
        }
        if (keyword.isNotEmpty()) {
            Spacer(modifier = Modifier.width(8.dp))
            Icon(
                Icons.Default.Close,
                contentDescription = "清除",
                tint = AppColors.Muted,
                modifier = Modifier
                    .size(18.dp)
                    .clickable { onKeywordChanged("") }
            )
        }
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title,
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        color = AppColors.Sub,
        modifier = Modifier.padding(horizontal = AppDimens.L, vertical = AppDimens.S)
    )
}

@Composable
private fun LocationPointCell(
    point: LocationPoint,
    isCurrent: Boolean = false,
    onClick: () -> Unit = {}
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = AppDimens.L, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            Icons.Default.LocationOn,
            contentDescription = null,
            tint = if (isCurrent) AppColors.Brand else AppColors.Muted,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                if (isCurrent) "${point.name}（当前位置）" else point.name,
                fontSize = 15.sp,
                color = AppColors.Ink,
                fontWeight = if (isCurrent) FontWeight.Medium else FontWeight.Normal,
                maxLines = 1
            )
            if (point.address.isNotBlank()) {
                Spacer(modifier = Modifier.height(2.dp))
                Text(point.address, fontSize = 12.sp, color = AppColors.Muted, maxLines = 1)
            }
        }
    }
}

@Composable
private fun LoadingRow(text: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp, color = AppColors.Brand)
        Spacer(modifier = Modifier.width(8.dp))
        Text(text, fontSize = 14.sp, color = AppColors.Sub)
    }
}

@Composable
private fun EmptyRow(text: String) {
    Box(
        modifier = Modifier.fillMaxWidth().padding(vertical = 32.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(text, fontSize = 14.sp, color = AppColors.Muted)
    }
}
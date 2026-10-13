package com.together.app.core.component

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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.together.app.core.design.AppColors
import com.together.app.core.design.AppDimens

// MARK: - 顶栏

@Composable
fun TogetherTopBar(
    title: String,
    onBack: (() -> Unit)? = null,
    actions: @Composable () -> Unit = {}
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(AppDimens.TopBarHeight)
            .background(AppColors.Surface)
            .padding(horizontal = AppDimens.S),
        verticalAlignment = Alignment.CenterVertically
    ) {
        if (onBack != null) {
            IconButton(onClick = onBack) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "返回",
                    tint = AppColors.Ink
                )
            }
        } else {
            Spacer(modifier = Modifier.width(AppDimens.M))
        }
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge,
            color = AppColors.Ink,
            modifier = Modifier.weight(1f)
        )
        actions()
    }
}

// MARK: - 卡片

@Composable
fun TogetherCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable () -> Unit
) {
    val base = modifier
        .clip(RoundedCornerShape(AppDimens.RadiusCard))
        .background(AppColors.Surface)
    val final = if (onClick != null) base.clickable { onClick() } else base
    Box(modifier = final) {
        Box(modifier = Modifier.padding(AppDimens.CardInner)) {
            content()
        }
    }
}

// MARK: - 按钮

@Composable
fun TogetherButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    style: ButtonStyle = ButtonStyle.Primary
) {
    val bgColor = when {
        !enabled -> AppColors.Muted
        style == ButtonStyle.Primary -> AppColors.Brand
        style == ButtonStyle.Secondary -> AppColors.BrandSoft
        style == ButtonStyle.Danger -> AppColors.Danger
        style == ButtonStyle.Wechat -> AppColors.Wechat
    }
    val textColor = when {
        !enabled -> AppColors.Surface
        style == ButtonStyle.Secondary -> AppColors.BrandDark
        else -> Color.White
    }
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(AppDimens.RadiusButton))
            .background(bgColor)
            .clickable(enabled) { onClick() }
            .padding(horizontal = AppDimens.Xl, vertical = AppDimens.M),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            color = textColor,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold
        )
    }
}

enum class ButtonStyle { Primary, Secondary, Danger, Wechat }

// MARK: - 标签

@Composable
fun TogetherTag(
    text: String,
    modifier: Modifier = Modifier,
    color: Color = AppColors.Brand,
    bgColor: Color = AppColors.BrandSoft
) {
    Text(
        text = text,
        color = color,
        fontSize = 11.sp,
        fontWeight = FontWeight.Medium,
        modifier = modifier
            .clip(RoundedCornerShape(AppDimens.RadiusTag))
            .background(bgColor)
            .padding(horizontal = AppDimens.S, vertical = AppDimens.Xs)
    )
}

@Composable
fun StatusTag(status: Int, statusText: String) {
    val (color, bg) = AppColors.statusColors(status)
    TogetherTag(text = statusText, color = color, bgColor = bg)
}

// MARK: - 头像

@Composable
fun TogetherAvatar(
    url: String?,
    name: String,
    modifier: Modifier = Modifier,
    size: androidx.compose.ui.unit.Dp = AppDimens.AvatarM
) {
    if (!url.isNullOrBlank()) {
        AsyncImage(
            model = resolveImageUrl(url),
            contentDescription = name,
            modifier = modifier
                .size(size)
                .clip(RoundedCornerShape(AppDimens.RadiusAvatar))
        )
    } else {
        // 昵称首字占位头像
        val (main, _) = AppColors.colorPairForSeed(name)
        Box(
            modifier = modifier
                .size(size)
                .clip(RoundedCornerShape(AppDimens.RadiusAvatar))
                .background(main),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = name.firstOrNull()?.toString() ?: "?",
                color = Color.White,
                fontSize = (size.value / 2.2).sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

// MARK: - 空状态 / 加载 / 错误

@Composable
fun EmptyStateView(
    message: String = "暂无数据",
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(
            text = "🍃",
            fontSize = 40.sp
        )
        Spacer(modifier = Modifier.height(AppDimens.M))
        Text(
            text = message,
            color = AppColors.Muted,
            fontSize = 14.sp
        )
    }
}

@Composable
fun LoadingView(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        CircularProgressIndicator(color = AppColors.Brand)
    }
}

@Composable
fun ErrorView(
    message: String,
    onRetry: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Text(text = "⚠️", fontSize = 40.sp)
        Spacer(modifier = Modifier.height(AppDimens.M))
        Text(
            text = message,
            color = AppColors.Danger,
            fontSize = 14.sp
        )
        if (onRetry != null) {
            Spacer(modifier = Modifier.height(AppDimens.M))
            TogetherButton(text = "重试", onClick = onRetry, style = ButtonStyle.Secondary)
        }
    }
}

// MARK: - 区块标题

@Composable
fun SectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    trailing: @Composable () -> Unit = {}
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = AppDimens.L, vertical = AppDimens.S),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleLarge,
            color = AppColors.Ink,
            modifier = Modifier.weight(1f)
        )
        trailing()
    }
}

// MARK: - 价格文本

@Composable
fun PriceText(
    price: Double,
    modifier: Modifier = Modifier,
    fontSize: Int = 18,
    color: Color = AppColors.Clay
) {
    Row(modifier = modifier, verticalAlignment = Alignment.Bottom) {
        Text(
            text = "¥",
            color = color,
            fontSize = (fontSize * 0.6).sp,
            fontWeight = FontWeight.Bold
        )
        Text(
            text = formatPrice(price),
            color = color,
            fontSize = fontSize.sp,
            fontWeight = FontWeight.Bold
        )
    }
}

fun formatPrice(price: Double): String {
    return if (price == price.toLong().toDouble()) {
        price.toLong().toString()
    } else {
        String.format("%.1f", price)
    }
}

// MARK: - 图片 URL 解析

fun resolveImageUrl(url: String?): String {
    if (url.isNullOrBlank()) return ""
    return if (url.startsWith("http")) url else com.together.app.core.network.ApiConfig.imageBaseUrl + url
}

// MARK: - 搜索栏

@Composable
fun SearchBar(
    placeholder: String = "搜索",
    value: String = "",
    onValueChange: (String) -> Unit = {},
    onSearch: () -> Unit = {},
    modifier: Modifier = Modifier
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(AppDimens.RadiusInput)),
        placeholder = {
            Text(placeholder, color = AppColors.Muted, fontSize = 14.sp)
        },
        leadingIcon = {
            Icon(Icons.Default.Search, contentDescription = null, tint = AppColors.Muted)
        },
        singleLine = true,
        shape = RoundedCornerShape(AppDimens.RadiusInput),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = AppColors.Brand,
            unfocusedBorderColor = AppColors.Line,
            focusedContainerColor = AppColors.SurfaceAlt,
            unfocusedContainerColor = AppColors.SurfaceAlt,
            cursorColor = AppColors.Brand
        )
    )
}

// MARK: - 信息行

@Composable
fun InfoRow(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
    valueColor: Color = AppColors.Ink
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = AppDimens.S),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            color = AppColors.Sub,
            fontSize = 14.sp
        )
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = value,
            color = valueColor,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis
        )
    }
}

// MARK: - 分隔线

@Composable
fun TogetherDivider(modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(0.5.dp)
            .background(AppColors.Line)
    )
}
package com.together.app.core.design

import androidx.compose.ui.graphics.Color

/**
 * 艺启 · 设计 Token 颜色（对齐 YIQI 设计系统 v2「温暖手作」）
 * 对齐 iOS Theme.Color
 */
object AppColors {
    val Bg = Color(0xFFFAF7F1)
    val Surface = Color(0xFFFFFFFF)
    val SurfaceAlt = Color(0xFFF4EFE6)
    val Line = Color(0xFFE6DFD3)
    val Ink = Color(0xFF2B2621)
    val Sub = Color(0xFF726A60)
    val Muted = Color(0xFF9C948A)

    val Brand = Color(0xFF14A640)
    val BrandDark = Color(0xFF0B7E2D)
    val BrandLight = Color(0xFF4A7A5E)
    val BrandSoft = Color(0xFFE4F7EA)

    val Wood = Color(0xFFA87A3E)
    val WoodSoft = Color(0xFFF4EFE6)
    val Clay = Color(0xFFC15F2C)

    val Success = Color(0xFF12963F)
    val SuccessTint = Color(0xFFE4F7EA)
    val Warn = Color(0xFFC77B2A)
    val WarnTint = Color(0xFFFBEEDC)
    val Danger = Color(0xFFB03A2B)
    val DangerTint = Color(0xFFFAE8E4)
    val Info = Color(0xFF3A6B96)
    val InfoTint = Color(0xFFE7EFF7)

    /** 微信绿 */
    val Wechat = Color(0xFF07C160)

    /** 老师回复标签紫 */
    val Violet = Color(0xFF7C3AED)
    val VioletTint = Color(0xFFF5F3FF)

    // MARK: - 随机色板（柔和色板，主色 + 浅色成对）

    private data class ColorPair(val main: Color, val soft: Color)

    private val palette = listOf(
        ColorPair(Color(0xFF14A640), Color(0xFFE4F7EA)), // 品牌绿
        ColorPair(Color(0xFF3A6B96), Color(0xFFE7EFF7)), // 蓝
        ColorPair(Color(0xFF7C3AED), Color(0xFFF5F3FF)), // 紫
        ColorPair(Color(0xFFC15F2C), Color(0xFFFAEDE5)), // 陶橙
        ColorPair(Color(0xFFA87A3E), Color(0xFFF6EEDF)), // 木色
        ColorPair(Color(0xFFB03A2B), Color(0xFFFAE8E4)), // 砖红
        ColorPair(Color(0xFF3D8B5F), Color(0xFFE9F1EA)), // 草绿
        ColorPair(Color(0xFF9B59B6), Color(0xFFF3ECF9)), // 紫罗兰
        ColorPair(Color(0xFF2E86AB), Color(0xFFE4F0F6)), // 湖蓝
        ColorPair(Color(0xFFD98E32), Color(0xFFFBF1E0)), // 琥珀
        ColorPair(Color(0xFF5B6B8C), Color(0xFFECEFF4)), // 靛灰
        ColorPair(Color(0xFFC0507B), Color(0xFFFAEAF1))  // 玫红
    )

    /** 随机返回一个柔和主色 */
    fun random(): Color = palette.random().main

    /** 随机主色 + 对应浅色 */
    fun randomPair(): Pair<Color, Color> {
        val p = palette.random()
        return p.main to p.soft
    }

    /** 按字符串稳定取色（同一字符串永远同一颜色，适合头像/昵称底色） */
    fun colorForSeed(seed: String): Color {
        val index = (seed.hashCode().let { if (it == Int.MIN_VALUE) 0 else kotlin.math.abs(it) }) % palette.size
        return palette[index].main
    }

    /** 按字符串稳定取色（主色 + 浅色） */
    fun colorPairForSeed(seed: String): Pair<Color, Color> {
        val index = (seed.hashCode().let { if (it == Int.MIN_VALUE) 0 else kotlin.math.abs(it) }) % palette.size
        val p = palette[index]
        return p.main to p.soft
    }

    // MARK: - 状态色映射

    /** 订单/退款状态 → (文字色, 底色) */
    fun statusColors(status: Int): Pair<Color, Color> = when (status) {
        0 -> Warn to WarnTint       // 待确认
        1 -> Info to InfoTint       // 待付款/待确认
        2 -> Brand to BrandSoft     // 已确认/进行中
        3 -> Success to SuccessTint // 已完成
        4 -> Muted to SurfaceAlt    // 已取消
        5 -> Danger to DangerTint   // 已退款/已驳回
        else -> Sub to SurfaceAlt
    }
}
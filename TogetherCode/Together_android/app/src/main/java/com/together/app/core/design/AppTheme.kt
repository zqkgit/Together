package com.together.app.core.design

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColors = lightColorScheme(
    primary = AppColors.Brand,
    onPrimary = AppColors.Surface,
    secondary = AppColors.Wood,
    background = AppColors.Bg,
    onBackground = AppColors.Ink,
    surface = AppColors.Surface,
    onSurface = AppColors.Ink,
    surfaceVariant = AppColors.SurfaceAlt,
    onSurfaceVariant = AppColors.Sub,
    outline = AppColors.Line,
    error = AppColors.Danger
)

private val DarkColors = darkColorScheme(
    primary = AppColors.BrandLight,
    onPrimary = AppColors.Surface,
    secondary = AppColors.Wood,
    background = AppColors.Ink,
    onBackground = AppColors.Surface,
    surface = AppColors.Ink,
    onSurface = AppColors.Surface,
    surfaceVariant = AppColors.Sub,
    onSurfaceVariant = AppColors.SurfaceAlt,
    outline = AppColors.Muted,
    error = AppColors.Danger
)

@Composable
fun TogetherTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        typography = AppTypography,
        content = content
    )
}

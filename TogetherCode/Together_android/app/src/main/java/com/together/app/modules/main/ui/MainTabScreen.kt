package com.together.app.modules.main.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.together.app.modules.home.ui.HomeScreen
import com.together.app.modules.message.ui.MessageScreen
import com.together.app.modules.mine.ui.MineScreen
import com.together.app.modules.plaza.ui.PlazaScreen

private enum class ParentTab(val label: String) {
    Home("首页"),
    Plaza("广场"),
    Message("消息"),
    Mine("我的")
}

@Composable
fun MainTabScreen() {
    var selectedTab by remember { mutableStateOf(ParentTab.Home) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                ParentTab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = selectedTab == tab,
                        onClick = { selectedTab = tab },
                        label = { Text(tab.label) },
                        icon = {
                            Icon(
                                imageVector = when (tab) {
                                    ParentTab.Home -> Icons.Filled.Home
                                    ParentTab.Plaza -> Icons.Filled.Explore
                                    ParentTab.Message -> Icons.Filled.Email
                                    ParentTab.Mine -> Icons.Filled.Person
                                },
                                contentDescription = tab.label
                            )
                        }
                    )
                }
            }
        }
    ) { padding ->
        val modifier = Modifier.padding(padding)
        when (selectedTab) {
            ParentTab.Home -> androidx.compose.foundation.layout.Box(modifier) { HomeScreen() }
            ParentTab.Plaza -> androidx.compose.foundation.layout.Box(modifier) { PlazaScreen() }
            ParentTab.Message -> androidx.compose.foundation.layout.Box(modifier) { MessageScreen() }
            ParentTab.Mine -> androidx.compose.foundation.layout.Box(modifier) { MineScreen() }
        }
    }
}

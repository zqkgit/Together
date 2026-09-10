<script setup lang="ts">
import {
  Calendar,
  CreditCard,
  DocumentChecked,
  House,
  Menu,
  OfficeBuilding
} from "@element-plus/icons-vue";
import { useRoute, useRouter } from "vue-router";
import { useAppStore } from "../stores/app";

const route = useRoute();
const router = useRouter();
const appStore = useAppStore();

const menus = [
  { path: "/dashboard", title: "经营看板", icon: House },
  { path: "/studios", title: "工作室管理", icon: OfficeBuilding },
  { path: "/reviews", title: "认证审核", icon: DocumentChecked },
  { path: "/settlements", title: "结算分账", icon: CreditCard }
];

function handleSelect(path: string) {
  router.push(path);
}
</script>

<template>
  <el-container class="admin-shell">
    <el-aside :width="appStore.asideWidth" class="admin-aside">
      <div class="brand">
        <div class="brand-mark">Y</div>
        <div v-if="!appStore.collapsed" class="brand-copy">
          <strong>艺启后台</strong>
          <span>Together Admin</span>
        </div>
      </div>

      <el-menu
        :default-active="route.path"
        class="menu"
        :collapse="appStore.collapsed"
        @select="handleSelect"
      >
        <el-menu-item
          v-for="item in menus"
          :key="item.path"
          :index="item.path"
        >
          <el-icon><component :is="item.icon" /></el-icon>
          <template #title>{{ item.title }}</template>
        </el-menu-item>
      </el-menu>
    </el-aside>

    <el-container>
      <el-header class="admin-header">
        <div class="header-left">
          <el-button text @click="appStore.toggleCollapsed()">
            <el-icon><Menu /></el-icon>
          </el-button>
          <div>
            <div class="page-title">{{ route.meta.title }}</div>
            <div class="page-subtitle">工作室经营与平台治理一体化控制台</div>
          </div>
        </div>

        <div class="header-right">
          <el-tag type="success" effect="plain">测试环境</el-tag>
          <el-button text>
            <el-icon><Calendar /></el-icon>
            2026-09
          </el-button>
          <el-avatar size="small">运</el-avatar>
          <span class="user-name">{{ appStore.userName }}</span>
        </div>
      </el-header>

      <el-main class="admin-main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

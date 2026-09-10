<script setup lang="ts">
import {
  Calendar,
  Finished,
  Coin,
  Collection,
  CreditCard,
  DocumentChecked,
  House,
  Menu,
  OfficeBuilding,
  Setting,
  SwitchButton,
  Tickets,
  User
} from "@element-plus/icons-vue";
import { computed } from "vue";
import { useRoute, useRouter } from "vue-router";
import { ElMessageBox } from "element-plus";
import { useAppStore } from "../stores/app";
import { useAuthStore } from "../stores/auth";

const route = useRoute();
const router = useRouter();
const appStore = useAppStore();
const authStore = useAuthStore();

const platformMenus = [
  { path: "/dashboard", title: "经营看板", icon: House },
  { path: "/studios", title: "工作室管理", icon: OfficeBuilding },
  { path: "/reviews", title: "认证审核", icon: DocumentChecked },
  { path: "/teacher-reviews", title: "老师认证", icon: User },
  { path: "/tags", title: "标签管理", icon: Collection },
  { path: "/settlements", title: "结算分账", icon: CreditCard }
];

const studioMenus = [
  { path: "/studio-home", title: "经营概览", icon: House },
  { path: "/studio-courses", title: "课程管理", icon: Tickets },
  { path: "/studio-classes", title: "班级管理", icon: OfficeBuilding },
  { path: "/studio-teachers", title: "教师管理", icon: User },
  { path: "/studio-schedules", title: "排课管理", icon: Calendar },
  { path: "/studio-students", title: "学员管理", icon: User },
  { path: "/studio-orders", title: "订单管理", icon: Coin },
  { path: "/studio-refunds", title: "退款管理", icon: CreditCard },
  { path: "/studio-leaves", title: "请假审批", icon: Finished },
  { path: "/studio-settings", title: "工作室设置", icon: Setting }
];

const menus = computed(() =>
  authStore.account?.scope === "studio" ? studioMenus : platformMenus
);

function handleSelect(path: string) {
  router.push(path);
}

async function handleLogout() {
  try {
    await ElMessageBox.confirm("确定要退出登录吗？", "退出登录", {
      confirmButtonText: "退出",
      cancelButtonText: "取消",
      type: "warning"
    });
  } catch {
    return;
  }
  await authStore.logout();
  router.push("/login");
}
</script>

<template>
  <el-container class="admin-shell">
    <el-aside :width="appStore.asideWidth" class="admin-aside">
      <div class="brand">
        <div class="brand-mark">艺</div>
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
          <el-avatar size="small" class="header-avatar">{{ authStore.displayName.slice(0, 1) }}</el-avatar>
          <div class="user-block">
            <span class="user-name">{{ authStore.displayName }}</span>
            <span class="user-scope">{{ authStore.scopeLabel }}</span>
          </div>
          <el-button text @click="handleLogout">
            <el-icon><SwitchButton /></el-icon>
            退出
          </el-button>
        </div>
      </el-header>

      <el-main class="admin-main">
        <router-view />
      </el-main>
    </el-container>
  </el-container>
</template>

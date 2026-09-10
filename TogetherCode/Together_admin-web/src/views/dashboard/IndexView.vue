<script setup lang="ts">
import { onMounted, ref } from "vue";
import { fetchDashboardOverview, type DashboardOverview } from "../../services/admin";

const loading = ref(false);
const overview = ref<DashboardOverview>({
  statCards: [],
  timeline: [],
  todos: []
});

async function loadData() {
  loading.value = true;
  try {
    overview.value = await fetchDashboardOverview();
  } finally {
    loading.value = false;
  }
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <div v-loading="loading" class="stats-grid">
      <el-card v-for="item in overview.statCards" :key="item.label" shadow="hover">
        <div class="stat-label">{{ item.label }}</div>
        <div class="stat-value">{{ item.value }}</div>
        <div class="stat-trend">{{ item.trend }}</div>
      </el-card>
    </div>

    <div class="panel-grid panel-grid-2">
      <el-card shadow="never">
        <template #header>
          <div class="panel-header">
            <span>本周重点</span>
            <el-tag effect="plain">MVP 联调期</el-tag>
          </div>
        </template>
        <el-timeline>
          <el-timeline-item
            v-for="item in overview.timeline"
            :key="`${item.timestamp}-${item.content}`"
            :timestamp="item.timestamp"
          >
            {{ item.content }}
          </el-timeline-item>
        </el-timeline>
      </el-card>

      <el-card shadow="never">
        <template #header>
          <div class="panel-header">
            <span>待办清单</span>
            <el-button text>查看全部</el-button>
          </div>
        </template>
        <el-space direction="vertical" fill>
          <div v-for="item in overview.todos" :key="item" class="todo-row">
            <span class="todo-dot"></span>
            <span>{{ item }}</span>
          </div>
        </el-space>
      </el-card>
    </div>
  </div>
</template>

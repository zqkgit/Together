<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { fetchDashboardOverview, type DashboardOverview } from "../../services/admin";

const loading = ref(false);
const overview = ref<DashboardOverview>({
  statCards: [],
  summary: {
    studio_total: 0,
    studio_new_month: 0,
    student_total: 0,
    student_active: 0,
    course_total: 0,
    order_month: 0,
    gmv_month: 0,
    gmv_month_text: "¥ 0"
  },
  trend30d: [],
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

const summaryItems = computed(() => [
  { label: "工作室总数", value: overview.value.summary.studio_total },
  { label: "本月新增", value: overview.value.summary.studio_new_month },
  { label: "学员总数", value: overview.value.summary.student_total },
  { label: "在学学员", value: overview.value.summary.student_active },
  { label: "在售课程", value: overview.value.summary.course_total },
  { label: "本月订单", value: overview.value.summary.order_month }
]);

const maxGmv = computed(() =>
  Math.max(1, ...overview.value.trend30d.map((item) => item.gmv))
);

function formatGmv(value: number): string {
  if (value >= 10000) return `${(value / 100).toFixed(0)} 元`;
  return `¥ ${(value / 100).toFixed(0)}`;
}
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

    <el-card v-loading="loading" shadow="never" class="summary-card">
      <div class="summary-grid">
        <div v-for="item in summaryItems" :key="item.label" class="summary-item">
          <div class="summary-value">{{ item.value }}</div>
          <div class="summary-label">{{ item.label }}</div>
        </div>
      </div>
    </el-card>

    <div class="panel-grid panel-grid-2">
      <el-card v-loading="loading" shadow="never">
        <template #header>
          <div class="panel-header">
            <span>近 30 天 GMV 趋势</span>
            <el-tag effect="plain">单位：元</el-tag>
          </div>
        </template>
        <div class="trend-chart">
          <div
            v-for="item in overview.trend30d"
            :key="item.date"
            class="trend-bar-wrap"
            :title="`${item.date} · ${formatGmv(item.gmv)}`"
          >
            <div
              class="trend-bar"
              :class="{ zero: item.gmv === 0 }"
              :style="{ height: `${Math.max(2, (item.gmv / maxGmv) * 100)}%` }"
            ></div>
            <div class="trend-day">{{ item.date.slice(8) }}</div>
          </div>
        </div>
      </el-card>

      <el-card v-loading="loading" shadow="never">
        <template #header>
          <div class="panel-header">
            <span>待办清单</span>
            <el-tag effect="plain">需关注</el-tag>
          </div>
        </template>
        <el-space direction="vertical" fill>
          <div v-for="item in overview.todos" :key="item.label" class="todo-row">
            <span class="todo-dot"></span>
            <span class="todo-label">{{ item.label }}</span>
            <el-badge :value="item.count" class="todo-count" />
          </div>
          <div v-if="overview.todos.length === 0" class="empty-tip">暂无待办，一切正常</div>
        </el-space>
      </el-card>
    </div>
  </div>
</template>

<style scoped>
.summary-card {
  border-radius: 16px;
}

.summary-grid {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  gap: 12px;
}

.summary-item {
  text-align: center;
  padding: 8px 4px;
}

.summary-value {
  font-size: 24px;
  font-weight: 700;
  color: #2f5d45;
}

.summary-label {
  margin-top: 4px;
  font-size: 12px;
  color: #726a60;
}

.trend-chart {
  display: flex;
  align-items: flex-end;
  gap: 3px;
  height: 180px;
  padding-top: 8px;
}

.trend-bar-wrap {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
  gap: 4px;
}

.trend-bar {
  width: 100%;
  max-width: 18px;
  border-radius: 3px 3px 0 0;
  background: linear-gradient(180deg, #2f5d45 0%, #4a7d5e 100%);
  transition: height 0.3s ease;
}

.trend-bar.zero {
  background: #e6dfd3;
}

.trend-bar-wrap:hover .trend-bar {
  background: #a87a3e;
}

.trend-day {
  font-size: 10px;
  color: #9c9385;
}

.todo-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 12px 0;
  border-bottom: 1px solid #eee7dd;
}

.todo-row:last-child {
  border-bottom: none;
}

.todo-label {
  font-size: 14px;
  color: #2b2621;
}

.todo-count {
  margin-left: auto;
}

.empty-tip {
  padding: 24px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
}

@media (max-width: 1200px) {
  .summary-grid {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}

@media (max-width: 768px) {
  .summary-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}
</style>

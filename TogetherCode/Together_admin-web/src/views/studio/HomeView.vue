<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { fetchStudioOverview, type StudioOverview } from "../../services/studio";

const router = useRouter();
const loading = ref(false);
const overview = ref<StudioOverview>({
  statCards: [],
  summary: {
    order_total: 0,
    gmv_total: 0,
    gmv_total_text: "¥ 0",
    order_month: 0,
    gmv_month: 0,
    gmv_month_text: "¥ 0",
    student_active: 0,
    course_total: 0,
    course_online: 0,
    class_total: 0
  },
  trend30d: [],
  todos: { refunds: [], leaves: [] }
});

async function loadData() {
  loading.value = true;
  try {
    overview.value = await fetchStudioOverview();
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    loading.value = false;
  }
}

onMounted(loadData);

const summaryItems = computed(() => [
  { label: "累计订单", value: overview.value.summary.order_total },
  { label: "累计 GMV", value: overview.value.summary.gmv_total_text },
  { label: "本月订单", value: overview.value.summary.order_month },
  { label: "本月 GMV", value: overview.value.summary.gmv_month_text },
  { label: "班级总数", value: overview.value.summary.class_total },
  { label: "课程总数", value: overview.value.summary.course_total }
]);

const maxGmv = computed(() =>
  Math.max(1, ...overview.value.trend30d.map((item) => item.gmv))
);

const pendingCount = computed(
  () => overview.value.todos.refunds.length + overview.value.todos.leaves.length
);

function formatGmv(value: number): string {
  if (value >= 10000) return `${(value / 100).toFixed(0)} 元`;
  return `¥ ${(value / 100).toFixed(0)}`;
}

function formatFen(value: number): string {
  return `¥ ${(value / 100).toFixed(2)}`;
}

function goRefunds() {
  router.push("/studio-refunds");
}

function goLeaves() {
  router.push("/studio-leaves");
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
            <span>待办事项</span>
            <el-tag v-if="pendingCount > 0" type="warning" effect="light">
              {{ pendingCount }} 项待处理
            </el-tag>
            <el-tag v-else effect="plain">一切正常</el-tag>
          </div>
        </template>

        <template v-if="overview.todos.refunds.length > 0 || overview.todos.leaves.length > 0">
          <div class="todo-group-title">待审核退款（{{ overview.todos.refunds.length }}）</div>
          <div
            v-for="item in overview.todos.refunds"
            :key="item.refund_id"
            class="todo-row clickable"
            @click="goRefunds"
          >
            <span class="todo-dot refund-dot"></span>
            <div class="todo-main">
              <div class="todo-label">{{ item.child_nickname }} · {{ item.course_title }}</div>
              <div class="todo-sub">申请退款 {{ formatFen(item.amount) }} · {{ item.created_at.slice(0, 10) }}</div>
            </div>
            <el-tag type="warning" effect="light" size="small">待审核</el-tag>
          </div>

          <div class="todo-group-title">待处理请假（{{ overview.todos.leaves.length }}）</div>
          <div
            v-for="item in overview.todos.leaves"
            :key="item.leave_id"
            class="todo-row clickable"
            @click="goLeaves"
          >
            <span class="todo-dot leave-dot"></span>
            <div class="todo-main">
              <div class="todo-label">{{ item.child_nickname }} · {{ item.class_name }}</div>
              <div class="todo-sub">申请于 {{ item.created_at.slice(0, 10) }}</div>
            </div>
            <el-tag type="warning" effect="light" size="small">待审批</el-tag>
          </div>
        </template>
        <div v-else class="empty-tip">暂无待办，一切正常</div>
      </el-card>
    </div>
  </div>
</template>

<style scoped>
.stats-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 14px;
}

.stat-label {
  font-size: 13px;
  color: #726a60;
}

.stat-value {
  margin-top: 8px;
  font-size: 28px;
  font-weight: 700;
  color: #2b2621;
}

.stat-trend {
  margin-top: 6px;
  font-size: 12px;
  color: #9c9385;
}

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
  font-size: 22px;
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

.todo-group-title {
  font-size: 13px;
  font-weight: 600;
  color: #726a60;
  margin: 4px 0 2px;
}

.todo-row {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 0;
  border-bottom: 1px solid #eee7dd;
}

.todo-row:last-child {
  border-bottom: none;
}

.todo-row.clickable {
  cursor: pointer;
}

.todo-row.clickable:hover {
  background: #faf7f1;
  padding-left: 6px;
  border-radius: 8px;
  transition: all 0.2s ease;
}

.todo-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.refund-dot {
  background: #c15f2c;
}

.leave-dot {
  background: #a87a3e;
}

.todo-main {
  flex: 1;
  min-width: 0;
}

.todo-label {
  font-size: 14px;
  color: #2b2621;
}

.todo-sub {
  font-size: 12px;
  color: #9c9385;
  margin-top: 2px;
}

.empty-tip {
  padding: 32px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
}

@media (max-width: 1200px) {
  .stats-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

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

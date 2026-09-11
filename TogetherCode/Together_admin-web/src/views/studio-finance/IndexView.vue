<script setup lang="ts">
import { onMounted, ref } from "vue";
import { Refresh } from "@element-plus/icons-vue";
import { fetchStudioFinance, type StudioFinanceData } from "../../services/studio";

const loading = ref(false);
const data = ref<StudioFinanceData | null>(null);
const startDate = ref("");
const endDate = ref("");

function fenToYuan(fen: number): string {
  return (fen / 100).toFixed(2);
}

const statusMeta: Record<number, { text: string; type: "warning" | "success" | "info" }> = {
  0: { text: "待支付", type: "warning" },
  1: { text: "已支付", type: "success" },
  2: { text: "已取消", type: "info" },
  3: { text: "已退款", type: "info" }
};

async function loadData() {
  loading.value = true;
  try {
    data.value = await fetchStudioFinance({
      start_date: startDate.value || undefined,
      end_date: endDate.value || undefined
    });
  } catch {
    // 拦截器统一提示
  } finally {
    loading.value = false;
  }
}

function onReset() {
  startDate.value = "";
  endDate.value = "";
  loadData();
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-card shadow="never">
      <template #header>
        <div class="panel-header">
          <div class="filter-row">
            <el-date-picker
              v-model="startDate"
              type="date"
              value-format="YYYY-MM-DD"
              placeholder="开始日期"
              style="width: 150px"
            />
            <span class="muted">至</span>
            <el-date-picker
              v-model="endDate"
              type="date"
              value-format="YYYY-MM-DD"
              placeholder="结束日期"
              style="width: 150px"
            />
            <el-button type="primary" @click="loadData">查询</el-button>
          </div>
          <el-button :icon="Refresh" circle @click="onReset" />
        </div>
      </template>

      <template v-if="data">
        <div class="stat-grid">
          <div class="stat-card">
            <div class="stat-label">累计营收（GMV）</div>
            <div class="stat-value">¥{{ fenToYuan(data.summary.gmv_total) }}</div>
            <div class="stat-sub">区间：¥{{ fenToYuan(data.summary.gmv_period) }}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">累计退款</div>
            <div class="stat-value danger">¥{{ fenToYuan(data.summary.refund_total) }}</div>
            <div class="stat-sub">区间：¥{{ fenToYuan(data.summary.refund_period) }}</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">分销支出</div>
            <div class="stat-value">¥{{ fenToYuan(data.summary.distribution_total) }}</div>
            <div class="stat-sub">分享返利扣减</div>
          </div>
          <div class="stat-card">
            <div class="stat-label">净营收</div>
            <div class="stat-value primary">¥{{ fenToYuan(data.summary.net_total) }}</div>
            <div class="stat-sub">区间：¥{{ fenToYuan(data.summary.net_period) }}</div>
          </div>
        </div>
      </template>
    </el-card>

    <el-card v-loading="loading" shadow="never">
      <template #header>
        <span class="panel-title">区间订单明细（{{ data?.period.start_date }} ~ {{ data?.period.end_date }}）</span>
      </template>
      <el-table :data="data?.orders || []">
        <el-table-column prop="order_no" label="订单号" min-width="180" />
        <el-table-column label="金额" width="130">
          <template #default="{ row }">¥{{ fenToYuan(row.total_amount) }}</template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status]?.type" size="small">{{ statusMeta[row.status]?.text }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="paid_at" label="支付时间" width="170" />
      </el-table>
    </el-card>
  </div>
</template>

<style scoped>
.stat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 16px;
}
.stat-card {
  padding: 16px 20px;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 8px;
  background: var(--el-bg-color);
}
.stat-label {
  font-size: 13px;
  color: var(--el-text-color-secondary);
}
.stat-value {
  font-size: 24px;
  font-weight: 700;
  margin: 6px 0 2px;
}
.stat-value.danger {
  color: var(--el-color-danger);
}
.stat-value.primary {
  color: var(--el-color-primary);
}
.stat-sub {
  font-size: 12px;
  color: var(--el-text-color-secondary);
}
</style>

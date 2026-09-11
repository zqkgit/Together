<script setup lang="ts">
import { onMounted, ref } from "vue";
import { Refresh } from "@element-plus/icons-vue";
import { fetchStudioReport, type StudioReportData } from "../../services/studio";

const loading = ref(false);
const data = ref<StudioReportData | null>(null);

function fenToYuan(fen: number): string {
  return (fen / 100).toFixed(2);
}

async function loadData() {
  loading.value = true;
  try {
    data.value = await fetchStudioReport();
  } catch {
    // 拦截器统一提示
  } finally {
    loading.value = false;
  }
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack" v-loading="loading">
    <template v-if="data">
      <div class="section-title">营收</div>
      <div class="stat-grid">
        <div class="stat-card">
          <div class="stat-label">本月实收</div>
          <div class="stat-value primary">¥{{ fenToYuan(data.revenue.month_gmv) }}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">累计实收</div>
          <div class="stat-value">¥{{ fenToYuan(data.revenue.total_gmv) }}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">本月退款</div>
          <div class="stat-value danger">¥{{ fenToYuan(data.revenue.month_refund) }}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">累计退款</div>
          <div class="stat-value danger">¥{{ fenToYuan(data.revenue.total_refund) }}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">净营收</div>
          <div class="stat-value primary">¥{{ fenToYuan(data.revenue.net_total) }}</div>
        </div>
      </div>

      <div class="section-title">课时</div>
      <div class="stat-grid">
        <div class="stat-card">
          <div class="stat-label">已售课时</div>
          <div class="stat-value">{{ data.lessons.sold }}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">已消课时</div>
          <div class="stat-value">{{ data.lessons.consumed }}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">剩余课时</div>
          <div class="stat-value primary">{{ data.lessons.remaining }}</div>
        </div>
      </div>

      <div class="section-title">学员</div>
      <div class="stat-grid">
        <div class="stat-card">
          <div class="stat-label">学员总数</div>
          <div class="stat-value">{{ data.students.total }}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">在学学员</div>
          <div class="stat-value primary">{{ data.students.active }}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">本月新增</div>
          <div class="stat-value">{{ data.students.month_new }}</div>
        </div>
      </div>

      <div class="section-title">运营规模</div>
      <div class="stat-grid">
        <div class="stat-card">
          <div class="stat-label">课程数</div>
          <div class="stat-value">{{ data.operations.courses }}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">班级数</div>
          <div class="stat-value">{{ data.operations.classes }}</div>
        </div>
        <div class="stat-card">
          <div class="stat-label">在职老师</div>
          <div class="stat-value">{{ data.operations.teachers }}</div>
        </div>
      </div>

      <div class="section-title">近期退款流水（最近 10 笔）</div>
      <el-card shadow="never">
        <el-table :data="data.recent_refunds">
          <el-table-column prop="refund_id" label="退款单 ID" width="190" />
          <el-table-column label="金额" width="130">
            <template #default="{ row }">¥{{ fenToYuan(row.amount) }}</template>
          </el-table-column>
          <el-table-column label="状态" width="100">
            <template #default="{ row }">
              <el-tag :type="row.status === 3 ? 'success' : 'info'" size="small">
                {{ row.status === 3 ? "已退款" : "已驳回" }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="reviewed_at" label="处理时间" width="170" />
        </el-table>
        <el-empty v-if="!data.recent_refunds.length" description="暂无退款流水" :image-size="64" />
      </el-card>
    </template>

    <div style="text-align: center; margin-top: 16px">
      <el-button :icon="Refresh" @click="loadData">刷新</el-button>
    </div>
  </div>
</template>

<style scoped>
.section-title {
  font-size: 14px;
  font-weight: 700;
  color: #2f5d45;
  margin: 20px 0 12px;
}
.stat-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 14px;
}
.stat-card {
  padding: 14px 18px;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 8px;
}
.stat-label {
  font-size: 13px;
  color: var(--el-text-color-secondary);
}
.stat-value {
  font-size: 22px;
  font-weight: 700;
  margin-top: 4px;
}
.stat-value.primary {
  color: var(--el-color-primary);
}
.stat-value.danger {
  color: var(--el-color-danger);
}
</style>

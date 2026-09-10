<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { ElMessageBox } from "element-plus";
import { fetchSettlements, type SettlementsData } from "../../services/admin";

const loading = ref(false);
const settlements = ref<SettlementsData>({
  summary: {
    pendingNetAmount: "",
    pendingNetTrend: "",
    retryCount: 0,
    retryHint: ""
  },
  list: []
});

const summary = computed(() => settlements.value.summary);
const summaryCards = computed(() => [
  { label: "待结算净额", value: summary.value.pendingNetAmount, trend: summary.value.pendingNetTrend },
  { label: "异常重打笔数", value: String(summary.value.retryCount), trend: summary.value.retryHint },
  { label: "结算单总数", value: String(settlements.value.list.length), trend: "本月已生成" }
]);

const detailVisible = ref(false);
const detailRow = ref<(typeof settlements.value.list)[number] | null>(null);

async function loadData() {
  loading.value = true;
  try {
    settlements.value = await fetchSettlements();
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    loading.value = false;
  }
}

function openDetail(row: (typeof settlements.value.list)[number]) {
  detailRow.value = row;
  detailVisible.value = true;
}

async function handleGenerate() {
  await ElMessageBox.alert(
    "结算单生成流程（月初批量生成 → 初审 → 打款）将在下一阶段上线，当前可查看既有结算单数据。",
    "功能开发中",
    { confirmButtonText: "知道了", type: "info" }
  );
}

async function handlePayout() {
  await ElMessageBox.alert(
    "打款操作（对公转账 + 回执回填）需要接入结算单生成闭环后开放，当前为只读查看。",
    "功能开发中",
    { confirmButtonText: "知道了", type: "info" }
  );
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <div class="stats-grid">
      <el-card v-for="card in summaryCards" :key="card.label" v-loading="loading" shadow="hover">
        <div class="stat-label">{{ card.label }}</div>
        <div class="stat-value">{{ card.value }}</div>
        <div class="stat-trend">{{ card.trend }}</div>
      </el-card>
    </div>

    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <span>月结算单</span>
          <el-button type="primary" plain @click="handleGenerate">生成结算单</el-button>
        </div>
      </template>

      <el-table :data="settlements.list" row-key="id">
        <el-table-column prop="studio" label="工作室" min-width="220">
          <template #default="{ row }">
            <span class="cell-strong">{{ row.studio }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="period" label="结算周期" min-width="180" />
        <el-table-column prop="income" label="收入" min-width="130" align="right">
          <template #default="{ row }">
            <span class="amount-income">{{ row.income }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="refund" label="退款" min-width="130" align="right">
          <template #default="{ row }">
            <span class="amount-refund">{{ row.refund }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="payable" label="应付金额" min-width="140" align="right">
          <template #default="{ row }">
            <span class="amount-payable">{{ row.payable }}</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="120" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openDetail(row)">详情</el-button>
            <el-button text @click="handlePayout">打款</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 结算单详情 -->
    <el-dialog v-model="detailVisible" title="结算单详情" width="480px">
      <template v-if="detailRow">
        <el-descriptions :column="1" border>
          <el-descriptions-item label="工作室">{{ detailRow.studio }}</el-descriptions-item>
          <el-descriptions-item label="结算周期">{{ detailRow.period }}</el-descriptions-item>
          <el-descriptions-item label="周期收入">{{ detailRow.income }}</el-descriptions-item>
          <el-descriptions-item label="周期退款">{{ detailRow.refund }}</el-descriptions-item>
          <el-descriptions-item label="应付金额">
            <span class="amount-payable">{{ detailRow.payable }}</span>
          </el-descriptions-item>
        </el-descriptions>
        <div class="payout-tip">
          应付金额 =（周期收入 − 周期退款）×（1 − 平台抽成率），按工作室结算费率计算。
        </div>
      </template>
      <template #footer>
        <el-button @click="detailVisible = false">关闭</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.cell-strong {
  font-weight: 600;
  color: #2b2621;
}

.amount-income {
  color: #2f5d45;
  font-weight: 600;
}

.amount-refund {
  color: #c15f2c;
}

.amount-payable {
  color: #2b2621;
  font-weight: 700;
}

.payout-tip {
  margin-top: 14px;
  padding: 12px 14px;
  background: #f4efe6;
  border-radius: 10px;
  font-size: 12px;
  color: #726a60;
  line-height: 1.6;
}
</style>

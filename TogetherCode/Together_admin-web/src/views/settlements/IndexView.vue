<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Refresh } from "@element-plus/icons-vue";
import {
  fetchSettlements,
  generateSettlements,
  payoutSettlement,
  type SettlementItem
} from "../../services/admin";

const loading = ref(false);
const settlements = ref<{ summary: {
  pendingNetAmount: string;
  pendingNetTrend: string;
  retryCount: number;
  retryHint: string;
  pendingCount: number;
}; list: SettlementItem[] }>({
  summary: {
    pendingNetAmount: "",
    pendingNetTrend: "",
    retryCount: 0,
    retryHint: "",
    pendingCount: 0
  },
  list: []
});

const summary = computed(() => settlements.value.summary);
const summaryCards = computed(() => [
  { label: "待结算净额", value: summary.value.pendingNetAmount, trend: summary.value.pendingNetTrend },
  { label: "待打款笔数", value: String(summary.value.pendingCount), trend: "状态为待结算" },
  { label: "异常重打笔数", value: String(summary.value.retryCount), trend: summary.value.retryHint }
]);

const detailVisible = ref(false);
const detailRow = ref<SettlementItem | null>(null);

const statusMeta: Record<number, { text: string; type: "info" | "success" | "danger" | "warning" }> = {
  0: { text: "待结算", type: "warning" },
  1: { text: "已打款", type: "success" },
  2: { text: "已作废", type: "info" },
  3: { text: "异常待复核", type: "danger" }
};

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

function openDetail(row: SettlementItem) {
  detailRow.value = row;
  detailVisible.value = true;
}

const generating = ref(false);

async function handleGenerate() {
  try {
    await ElMessageBox.confirm(
      "将为全部已认证工作室生成「本月」结算单；同一周期已存在的不重复生成。确认继续？",
      "生成结算单",
      { confirmButtonText: "生成", cancelButtonText: "取消", type: "warning" }
    );
  } catch {
    return;
  }

  generating.value = true;
  try {
    const result = await generateSettlements();
    const createdText = result.created.length
      ? result.created.map((item) => `${item.studio}：应付 ${item.payable}`).join("；")
      : "";
    const skippedText = result.skipped.length
      ? `跳过已存在 ${result.skipped.length} 张`
      : "";
    ElMessage.success(result.message);
    if (createdText) {
      ElMessageBox.alert(`已生成结算单：\n${createdText}\n\n${skippedText}`, "生成完成", {
        confirmButtonText: "知道了",
        type: "success"
      });
    }
    loadData();
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    generating.value = false;
  }
}

const payingId = ref("");

async function handlePayout(row: SettlementItem) {
  if (Number(row.status) !== 0) {
    ElMessage.warning(`该结算单状态为「${row.status_text}」，仅待结算状态可打款`);
    return;
  }

  try {
    await ElMessageBox.confirm(
      `确认向「${row.studio}」打款 ${row.payable}？\n打款后结算单将标记为已打款并生成打款单号。`,
      "确认打款",
      { confirmButtonText: "确认打款", cancelButtonText: "取消", type: "warning" }
    );
  } catch {
    return;
  }

  payingId.value = row.id;
  try {
    const updated = await payoutSettlement(row.id);
    ElMessage.success(`打款成功：${updated.pay_no}`);
    loadData();
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    payingId.value = "";
  }
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
          <div class="toolbar-right">
            <el-button :icon="Refresh" @click="loadData">刷新</el-button>
            <el-button type="primary" plain :loading="generating" @click="handleGenerate">
              生成结算单
            </el-button>
          </div>
        </div>
      </template>

      <el-table :data="settlements.list" row-key="id">
        <el-table-column prop="studio" label="工作室" min-width="180">
          <template #default="{ row }">
            <span class="cell-strong">{{ row.studio }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="period" label="结算周期" min-width="170" />
        <el-table-column prop="income" label="收入" min-width="110" align="right">
          <template #default="{ row }">
            <span class="amount-income">{{ row.income }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="refund" label="退款" min-width="110" align="right">
          <template #default="{ row }">
            <span class="amount-refund">{{ row.refund }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="payable" label="应付金额" min-width="120" align="right">
          <template #default="{ row }">
            <span class="amount-payable">{{ row.payable }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status]?.type || 'info'" effect="light">
              {{ statusMeta[row.status]?.text || row.status_text || row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openDetail(row)">详情</el-button>
            <el-button
              text
              type="success"
              :loading="payingId === row.id"
              :disabled="Number(row.status) !== 0"
              @click="handlePayout(row)"
            >
              打款
            </el-button>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && settlements.list.length === 0" class="empty-tip">
        暂无结算单，点击右上角「生成结算单」为认证工作室生成当月结算
      </div>
    </el-card>

    <!-- 结算单详情 -->
    <el-dialog v-model="detailVisible" title="结算单详情" width="480px">
      <template v-if="detailRow">
        <el-descriptions :column="1" border>
          <el-descriptions-item label="工作室">{{ detailRow.studio }}</el-descriptions-item>
          <el-descriptions-item label="结算周期">{{ detailRow.period }}</el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="statusMeta[detailRow.status]?.type || 'info'" effect="light">
              {{ detailRow.status_text }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="周期收入">{{ detailRow.income }}</el-descriptions-item>
          <el-descriptions-item label="周期退款">{{ detailRow.refund }}</el-descriptions-item>
          <el-descriptions-item label="分销扣减">{{ detailRow.distribution }}</el-descriptions-item>
          <el-descriptions-item label="净额">{{ detailRow.net_amount }}</el-descriptions-item>
          <el-descriptions-item :label="`平台抽成（${(detailRow.fee_rate * 100).toFixed(0)}%）`">
            {{ detailRow.fee_amount }}
          </el-descriptions-item>
          <el-descriptions-item label="应付金额">
            <span class="amount-payable">{{ detailRow.payable }}</span>
          </el-descriptions-item>
          <el-descriptions-item v-if="detailRow.pay_no" label="打款单号">{{ detailRow.pay_no }}</el-descriptions-item>
          <el-descriptions-item v-if="detailRow.paid_at" label="打款时间">{{ detailRow.paid_at }}</el-descriptions-item>
        </el-descriptions>
        <div class="payout-tip">
          应付金额 =（周期收入 − 周期退款 − 分销扣减）×（1 − 工作室结算费率）；异常结算单需平台复核后重打。
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

.toolbar-right {
  display: flex;
  align-items: center;
  gap: 10px;
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

.empty-tip {
  padding: 32px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
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

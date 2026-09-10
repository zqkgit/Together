<script setup lang="ts">
import { onMounted, ref } from "vue";
import { Refresh } from "@element-plus/icons-vue";
import { fetchStudioOrders, type OrderItem } from "../../../services/studio";

const loading = ref(false);
const status = ref<number | "">("");
const orders = ref<OrderItem[]>([]);

const statusMeta: Record<number, { text: string; type: "info" | "success" | "danger" | "warning" }> = {
  0: { text: "待支付", type: "warning" },
  1: { text: "已支付", type: "success" },
  2: { text: "已取消", type: "info" },
  3: { text: "已退款", type: "danger" }
};

function formatFen(value: number): string {
  return `¥ ${(value / 100).toFixed(2)}`;
}

async function loadData() {
  loading.value = true;
  try {
    orders.value = (await fetchStudioOrders({ status: status.value })).list;
  } catch {
    // 忽略
  } finally {
    loading.value = false;
  }
}

// 详情
const detailVisible = ref(false);
const detail = ref<OrderItem | null>(null);

function openDetail(row: OrderItem) {
  detail.value = row;
  detailVisible.value = true;
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <span>订单列表</span>
          <div class="toolbar-right">
            <el-select v-model="status" placeholder="订单状态" clearable style="width: 130px" @change="loadData">
              <el-option label="待支付" :value="0" />
              <el-option label="已支付" :value="1" />
              <el-option label="已退款" :value="3" />
            </el-select>
            <el-button :icon="Refresh" @click="loadData">刷新</el-button>
          </div>
        </div>
      </template>

      <el-table :data="orders" row-key="order_id">
        <el-table-column prop="order_no" label="订单号" min-width="170" />
        <el-table-column label="学员 / 课程" min-width="200">
          <template #default="{ row }">
            <div class="cell-strong">{{ row.child?.nickname || "-" }}</div>
            <div class="cell-sub">{{ row.course?.title || "-" }}</div>
          </template>
        </el-table-column>
        <el-table-column label="课时包" min-width="140">
          <template #default="{ row }">{{ row.package?.name || "-" }}（{{ row.package?.lessons || 0 }}节）</template>
        </el-table-column>
        <el-table-column label="实付金额" width="120" align="right">
          <template #default="{ row }">
            <span class="amount-cell">{{ formatFen(row.paid_amount) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="课时" width="130" align="center">
          <template #default="{ row }">
            <span class="cell-sub">剩 {{ row.remaining_lessons }} / 共 {{ row.total_lessons }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status]?.type || 'info'" effect="light">
              {{ statusMeta[row.status]?.text || row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openDetail(row)">详情</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && orders.length === 0" class="empty-tip">暂无订单</div>
    </el-card>

    <!-- 订单详情 -->
    <el-drawer v-model="detailVisible" title="订单详情" size="500px">
      <template v-if="detail">
        <el-descriptions :column="1" border size="small">
          <el-descriptions-item label="订单号">{{ detail.order_no }}</el-descriptions-item>
          <el-descriptions-item label="学员">
            {{ detail.child?.nickname || "-" }}（{{ detail.child?.birthday || "未填生日" }}）
          </el-descriptions-item>
          <el-descriptions-item label="课程">{{ detail.course?.title || "-" }}</el-descriptions-item>
          <el-descriptions-item label="课时包">{{ detail.package?.name || "-" }}（{{ detail.package?.lessons || 0 }}节）</el-descriptions-item>
          <el-descriptions-item label="订单金额">{{ formatFen(detail.total_amount) }}</el-descriptions-item>
          <el-descriptions-item label="实付金额">
            <span class="amount-cell">{{ formatFen(detail.paid_amount) }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="已退款">{{ formatFen(detail.refund_amount) }}</el-descriptions-item>
          <el-descriptions-item label="支付渠道">{{ detail.pay_channel || "模拟支付" }}</el-descriptions-item>
          <el-descriptions-item label="支付时间">{{ detail.paid_at || "-" }}</el-descriptions-item>
          <el-descriptions-item label="下单时间">{{ detail.created_at }}</el-descriptions-item>
        </el-descriptions>

        <div class="block-title">课时账本</div>
        <el-descriptions v-if="detail.balance" :column="1" border size="small">
          <el-descriptions-item label="总课时">{{ detail.balance.total_lessons }}</el-descriptions-item>
          <el-descriptions-item label="已消耗">{{ detail.balance.consumed_lessons }}</el-descriptions-item>
          <el-descriptions-item label="已退款课时">{{ detail.balance.refunded_lessons }}</el-descriptions-item>
          <el-descriptions-item label="剩余课时">
            <span class="cell-strong">{{ detail.balance.remaining_lessons }}</span>
          </el-descriptions-item>
        </el-descriptions>
      </template>
    </el-drawer>
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

.cell-sub {
  font-size: 12px;
  color: #9c9385;
}

.amount-cell {
  font-weight: 700;
  color: #2f5d45;
}

.empty-tip {
  padding: 32px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
}

.block-title {
  margin: 18px 0 10px;
  font-size: 14px;
  font-weight: 600;
  color: #2b2621;
}
</style>

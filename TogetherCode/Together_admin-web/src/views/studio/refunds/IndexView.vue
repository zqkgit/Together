<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Refresh, Download } from "@element-plus/icons-vue";
import { fmtTime } from "../../../utils/format";
import { exportCsv } from "../../../utils/exportCsv";
import { fetchStudioRefunds, reviewStudioRefund, type RefundItem } from "../../../services/studio";

const loading = ref(false);
const status = ref<number | "">("");
const refunds = ref<RefundItem[]>([]);

const statusMeta: Record<number, { text: string; type: "warning" | "success" | "danger" }> = {
  0: { text: "待审核", type: "warning" },
  1: { text: "待打款", type: "warning" },
  2: { text: "已驳回", type: "danger" },
  3: { text: "已打款", type: "success" }
};

function formatFen(value: number): string {
  return `¥ ${(value / 100).toFixed(2)}`;
}

async function loadData() {
  loading.value = true;
  try {
    refunds.value = (await fetchStudioRefunds({ status: status.value })).list;
  } catch {
    // 忽略
  } finally {
    loading.value = false;
  }
}

// 审核
const reviewVisible = ref(false);
const reviewType = ref<"approve" | "reject">("approve");
const reviewId = ref("");
const reviewReason = ref("");
const reviewing = ref(false);

// 确认打款：待打款（1）→ 已打款（3），此时才扣减课时并通知家长到账
const confirming = ref(false);
async function confirmPaid(row: RefundItem) {
  try {
    await ElMessageBox.confirm(
      `确认该笔 ¥ ${(row.amount / 100).toFixed(2)} 退款已打款？确认后扣减课时并通知家长到账。`,
      "确认打款",
      { type: "warning", confirmButtonText: "确认打款", cancelButtonText: "取消" }
    );
  } catch {
    return; // 取消
  }
  confirming.value = true;
  try {
    await reviewStudioRefund(row.refund_id, { action: "confirm" });
    ElMessage.success("已确认打款，退款到账");
    loadData();
  } catch {
    // 拦截器已提示
  } finally {
    confirming.value = false;
  }
}

function openReview(row: RefundItem, type: "approve" | "reject") {
  reviewType.value = type;
  reviewId.value = row.refund_id;
  reviewReason.value = "";
  reviewVisible.value = true;
}

async function submitReview() {
  if (reviewType.value === "reject" && !reviewReason.value.trim()) {
    ElMessage.warning("驳回必须填写原因");
    return;
  }
  reviewing.value = true;
  try {
    await reviewStudioRefund(reviewId.value, {
      action: reviewType.value,
      reason: reviewReason.value.trim() || undefined
    });
    ElMessage.success(reviewType.value === "approve" ? "已通过退款申请" : "已驳回退款申请");
    reviewVisible.value = false;
    loadData();
  } catch {
    // 忽略
  } finally {
    reviewing.value = false;
  }
}

onMounted(loadData);

// 导出 CSV（全量，按当前状态筛选）
const exporting = ref(false);
async function exportRefunds() {
  exporting.value = true;
  try {
    const res: any = await fetchStudioRefunds({ status: status.value });
    const list: any[] = Array.isArray(res.list) ? res.list : [];
    exportCsv("退款单", [
      { key: "refund_id", label: "退款单号" },
      { key: "status", label: "状态" },
      { key: "order", label: "订单号" },
      { key: "course", label: "课程" },
      { key: "child", label: "学员" },
      { key: "parent", label: "家长" },
      { key: "requested_lessons", label: "申请课时" },
      { key: "amount", label: "退款金额(分)" },
      { key: "reason", label: "申请原因" },
      { key: "created_at", label: "申请时间" },
      { key: "reviewed_at", label: "审核时间" }
    ], list.map((r: any) => ({
      ...r,
      status: statusMeta[r.status]?.text ?? r.status,
      order: r.order?.order_no ?? "-",
      course: r.order?.course?.title ?? "-",
      child: r.order?.child?.nickname ?? "-",
      parent: r.order?.user?.nickname ?? "-",
      created_at: r.created_at ? fmtTime(r.created_at) : "-",
      reviewed_at: r.reviewed_at ? fmtTime(r.reviewed_at) : "-"
    })));
  } catch {
    // 拦截器已提示
  } finally {
    exporting.value = false;
  }
}
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <span>退款审核</span>
          <div class="toolbar-right">
            <el-select v-model="status" placeholder="退款状态" clearable style="width: 130px" @change="loadData">
              <el-option label="待审核" :value="0" />
              <el-option label="待打款" :value="1" />
              <el-option label="已打款" :value="3" />
              <el-option label="已驳回" :value="2" />
            </el-select>
            <el-button :icon="Refresh" @click="loadData">刷新</el-button>
            <el-button type="primary" plain :icon="Download" :loading="exporting" @click="exportRefunds">导出 CSV</el-button>
          </div>
        </div>
      </template>

      <el-table :data="refunds" row-key="refund_id">
        <el-table-column label="学员 / 课程" min-width="190">
          <template #default="{ row }">
            <div class="cell-strong">{{ row.order?.child?.nickname || "-" }}</div>
            <div class="cell-sub">{{ row.order?.course?.title || "-" }}</div>
          </template>
        </el-table-column>
        <el-table-column label="申请人" min-width="150">
          <template #default="{ row }">{{ row.order?.user?.nickname || "-" }}</template>
        </el-table-column>
        <el-table-column label="申请课时" width="100" align="center">
          <template #default="{ row }">{{ row.requested_lessons }} 节</template>
        </el-table-column>
        <el-table-column label="可退课时" width="100" align="center">
          <template #default="{ row }">{{ row.refundable_lessons }} 节</template>
        </el-table-column>
        <el-table-column label="退款金额" width="120" align="right">
          <template #default="{ row }">
            <span class="amount-cell">{{ formatFen(row.amount) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="reason" label="申请原因" min-width="150" show-overflow-tooltip />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status].type" effect="light">
              {{ statusMeta[row.status].text }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="170" fixed="right">
          <template #default="{ row }">
            <template v-if="row.status === 0">
              <el-button text type="success" @click="openReview(row, 'approve')">通过</el-button>
              <el-button text type="danger" @click="openReview(row, 'reject')">驳回</el-button>
            </template>
            <template v-else-if="row.status === 1">
              <el-button text type="success" :loading="confirming" @click="confirmPaid(row)">确认打款</el-button>
              <el-button text type="danger" @click="openReview(row, 'reject')">驳回</el-button>
            </template>
            <span v-else class="cell-sub">已处理</span>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && refunds.length === 0" class="empty-tip">暂无退款申请</div>
    </el-card>

    <!-- 审核对话框 -->
    <el-dialog
      v-model="reviewVisible"
      :title="reviewType === 'approve' ? '通过退款申请' : '驳回退款申请'"
      width="440px"
    >
      <el-alert
        :type="reviewType === 'approve' ? 'success' : 'warning'"
        :closable="false"
        show-icon
        :title="
          reviewType === 'approve'
            ? '通过后进入待打款，确认打款时才扣减课时并通知家长到账。'
            : '驳回后家长可重新发起退款申请。'
        "
        class="review-alert"
      />
      <el-input
        v-model="reviewReason"
        type="textarea"
        :rows="3"
        maxlength="255"
        show-word-limit
        :placeholder="reviewType === 'reject' ? '请填写驳回原因（必填）' : '审核备注（选填）'"
      />
      <template #footer>
        <el-button @click="reviewVisible = false">取消</el-button>
        <el-button
          :type="reviewType === 'approve' ? 'success' : 'danger'"
          :loading="reviewing"
          @click="submitReview"
        >
          {{ reviewType === "approve" ? "确认通过" : "确认驳回" }}
        </el-button>
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

.cell-sub {
  font-size: 12px;
  color: #9c9385;
}

.amount-cell {
  font-weight: 700;
  color: #c15f2c;
}

.empty-tip {
  padding: 32px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
}

.review-alert {
  margin-bottom: 14px;
}
</style>

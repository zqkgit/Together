<script setup lang="ts">
import { computed, onMounted, reactive, ref } from "vue";
import { ElMessage } from "element-plus";
import { Refresh, Download } from "@element-plus/icons-vue";
import type { UploadRequestOptions } from "element-plus";
import { fmtTime } from "../../../utils/format";
import { exportCsv } from "../../../utils/exportCsv";
import {
  fetchStudioRefunds,
  reviewStudioRefund,
  uploadStudioImages,
  type RefundItem,
  type PayMethod
} from "../../../services/studio";

const loading = ref(false);
const status = ref<number | "">("");
const refunds = ref<RefundItem[]>([]);

const statusMeta: Record<number, { text: string; type: "warning" | "success" | "danger" }> = {
  0: { text: "待审核", type: "warning" },
  1: { text: "待家长确认", type: "warning" },
  2: { text: "已驳回", type: "danger" },
  3: { text: "已退款", type: "success" }
};

// 线下退款方式（平台不经手资金，工作室线下退回后登记并上传打款凭证）
const PAY_METHODS: Array<{ value: PayMethod; label: string; online: boolean }> = [
  { value: "wechat", label: "微信转账", online: true },
  { value: "alipay", label: "支付宝转账", online: true },
  { value: "bank", label: "银行转账", online: true },
  { value: "qrcode", label: "收款码转账", online: true },
  { value: "cash", label: "现金", online: false },
  { value: "other", label: "其他", online: true }
];
const payMethodText = (m: string | null | undefined) =>
  PAY_METHODS.find((p) => p.value === m)?.label || m || "-";
const isOnline = (m: string | null | undefined) =>
  PAY_METHODS.find((p) => p.value === m)?.online ?? true;

function formatFen(value: number): string {
  return `¥ ${(value / 100).toFixed(2)}`;
}

async function loadData() {
  loading.value = true;
  try {
    refunds.value = (await fetchStudioRefunds({ status: status.value === "" ? undefined : status.value })).list;
  } catch {
    // 忽略
  } finally {
    loading.value = false;
  }
}

// 审核（通过 = 已线下退款并传凭证；驳回 = 填原因）
const reviewVisible = ref(false);
const reviewType = ref<"approve" | "reject">("approve");
const reviewId = ref("");
const reviewing = ref(false);
const reviewForm = reactive<{ refund_method: PayMethod; voucher_images: string[]; reason: string }>({
  refund_method: "wechat",
  voucher_images: [],
  reason: ""
});

// 通过时按当前剩余课时锁定的实退方案（申请后可能已消课，实退课时/金额自动调减）
const reviewPreview = reactive<{
  requested: number;
  remaining: number;
  approved: number;
  amount: number;
  reduced: boolean;
}>({ requested: 0, remaining: 0, approved: 0, amount: 0, reduced: false });

const needVoucher = computed(
  () => reviewType.value === "approve" && isOnline(reviewForm.refund_method) && reviewForm.voucher_images.length === 0
);

function openReview(row: RefundItem, type: "approve" | "reject") {
  reviewType.value = type;
  reviewId.value = row.refund_id;
  reviewForm.refund_method = "wechat";
  reviewForm.voucher_images = [];
  reviewForm.reason = "";
  const requested = Number(row.requested_lessons || 0);
  const remaining = Number(row.order?.balance?.remaining_lessons ?? requested);
  const approved = Math.max(0, Math.min(requested, remaining));
  reviewPreview.requested = requested;
  reviewPreview.remaining = remaining;
  reviewPreview.approved = approved;
  reviewPreview.amount = approved * Number(row.unit_price || 0);
  reviewPreview.reduced = approved < requested;
  reviewVisible.value = true;
}

async function uploadVoucher(options: UploadRequestOptions) {
  const file = options.file as File;
  try {
    const urls = await uploadStudioImages([file], "refund");
    reviewForm.voucher_images.push(...urls);
  } catch {
    // 拦截器已提示
  }
}

async function submitReview() {
  if (reviewType.value === "reject") {
    if (!reviewForm.reason.trim()) {
      ElMessage.warning("驳回必须填写原因");
      return;
    }
  } else {
    if (isOnline(reviewForm.refund_method) && reviewForm.voucher_images.length === 0) {
      ElMessage.warning("线上退款请上传打款凭证");
      return;
    }
  }
  reviewing.value = true;
  try {
    await reviewStudioRefund(reviewId.value, {
      action: reviewType.value,
      reason: reviewForm.reason.trim() || undefined,
      ...(reviewType.value === "approve"
        ? {
            refund_method: reviewForm.refund_method,
            voucher_images: isOnline(reviewForm.refund_method) ? reviewForm.voucher_images : reviewForm.voucher_images
          }
        : {})
    });
    ElMessage.success(
      reviewType.value === "approve" ? "已登记退款打款，等待家长确认收到" : "已驳回退款申请"
    );
    reviewVisible.value = false;
    loadData();
  } catch {
    // 拦截器已提示
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
    const res: any = await fetchStudioRefunds({ status: status.value === "" ? undefined : status.value });
    const list: any[] = Array.isArray(res.list) ? res.list : [];
    exportCsv("退款单", [
      { key: "refund_id", label: "退款单号" },
      { key: "status", label: "状态" },
      { key: "order", label: "订单号" },
      { key: "course", label: "课程" },
      { key: "child", label: "学员" },
      { key: "parent", label: "家长" },
      { key: "requested_lessons", label: "申请课时" },
      { key: "approved_lessons", label: "实退课时" },
      { key: "amount", label: "退款金额(分)" },
      { key: "refund_method", label: "退款方式" },
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
      refund_method: r.refund_method ? payMethodText(r.refund_method) : "-",
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
              <el-option label="待家长确认" :value="1" />
              <el-option label="已退款" :value="3" />
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
        <el-table-column label="申请/实退" width="104" align="center">
          <template #default="{ row }">
            <div>{{ row.requested_lessons }} 节</div>
            <div v-if="row.approved_lessons != null && row.approved_lessons < row.requested_lessons" class="cell-less">
              实退 {{ row.approved_lessons }} 节
            </div>
          </template>
        </el-table-column>
        <el-table-column label="可退课时" width="100" align="center">
          <template #default="{ row }">{{ row.refundable_lessons }} 节</template>
        </el-table-column>
        <el-table-column label="退款金额" width="120" align="right">
          <template #default="{ row }">
            <span class="amount-cell">{{ formatFen(row.amount) }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="reason" label="申请原因" min-width="140" show-overflow-tooltip />
        <el-table-column label="退款凭证" width="110" align="center">
          <template #default="{ row }">
            <div v-if="(row.voucher_images || []).length" class="voucher-cell">
              <el-image
                v-for="(img, idx) in (row.voucher_images || []).slice(0, 3)"
                :key="img"
                :src="img"
                :preview-src-list="row.voucher_images"
                :initial-index="idx"
                fit="cover"
                class="voucher-thumb"
              />
              <span v-if="(row.voucher_images || []).length > 3" class="cell-sub">
                +{{ row.voucher_images.length - 3 }}
              </span>
            </div>
            <span v-else-if="row.status === 1 && row.refund_method === 'cash'" class="cell-sub">现金</span>
            <span v-else class="cell-sub">-</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="104">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status].type" effect="light">
              {{ statusMeta[row.status].text }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <template v-if="row.status === 0">
              <el-button text type="success" @click="openReview(row, 'approve')">通过</el-button>
              <el-button text type="danger" @click="openReview(row, 'reject')">驳回</el-button>
            </template>
            <template v-else-if="row.status === 1">
              <span class="cell-sub">等待家长确认</span>
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
      :title="reviewType === 'approve' ? '通过退款 · 登记线下打款' : '驳回退款申请'"
      width="480px"
    >
      <!-- 通过：退款方式 + 打款凭证 -->
      <template v-if="reviewType === 'approve'">
        <el-alert
          type="success"
          :closable="false"
          show-icon
          title="通过即表示你已在线下把钱退给家长。选择退款方式并上传打款凭证后，退款单进入「待家长确认」；家长在 App 确认收到后才扣减课时、订单转已退款。"
          class="review-alert"
        />
        <el-alert
          v-if="reviewPreview.reduced"
          type="warning"
          :closable="false"
          show-icon
          class="review-alert"
          :title="`申请退 ${reviewPreview.requested} 节，当前仅剩 ${reviewPreview.remaining} 节（期间已上课 ${reviewPreview.requested - reviewPreview.approved} 节），本次实退 ${reviewPreview.approved} 节，退款金额自动调减为 ${formatFen(reviewPreview.amount)}`"
        />
        <div class="refund-summary">
          <div class="rs-row"><span>申请课时</span><b>{{ reviewPreview.requested }} 节</b></div>
          <div class="rs-row"><span>当前剩余</span><b>{{ reviewPreview.remaining }} 节</b></div>
          <div class="rs-row rs-highlight"><span>本次实退</span><b>{{ reviewPreview.approved }} 节</b></div>
          <div class="rs-row rs-amount"><span>退款金额</span><b>{{ formatFen(reviewPreview.amount) }}</b></div>
        </div>
        <el-form label-position="top">
          <el-form-item label="退款方式（线下结算，平台不经手资金）">
            <el-radio-group v-model="reviewForm.refund_method">
              <el-radio v-for="m in PAY_METHODS" :key="m.value" :value="m.value">{{ m.label }}</el-radio>
            </el-radio-group>
          </el-form-item>

          <el-alert
            v-if="!isOnline(reviewForm.refund_method)"
            type="success"
            :closable="false"
            show-icon
            title="现金退款可直接登记，无需上传凭证"
            class="review-alert"
          />

          <el-form-item v-if="isOnline(reviewForm.refund_method)" label="打款凭证截图（必填，可多张）">
            <div class="voucher-upload">
              <div v-for="(img, idx) in reviewForm.voucher_images" :key="img" class="voucher-item">
                <el-image
                  :src="img"
                  :preview-src-list="reviewForm.voucher_images"
                  :initial-index="idx"
                  fit="cover"
                  class="voucher-img"
                />
                <el-button
                  class="voucher-del"
                  type="danger"
                  circle
                  size="small"
                  @click="reviewForm.voucher_images.splice(idx, 1)"
                >×</el-button>
              </div>
              <el-upload
                v-if="reviewForm.voucher_images.length < 9"
                :show-file-list="false"
                accept="image/*"
                multiple
                :http-request="uploadVoucher"
              >
                <div class="voucher-add">+</div>
              </el-upload>
            </div>
          </el-form-item>

          <el-form-item label="备注（可选）">
            <el-input
              v-model="reviewForm.reason"
              type="textarea"
              :rows="2"
              maxlength="100"
              show-word-limit
              placeholder="例如：已原路退回，凭证见上图"
            />
          </el-form-item>
        </el-form>
      </template>

      <!-- 驳回：原因 -->
      <template v-else>
        <el-alert
          type="warning"
          :closable="false"
          show-icon
          title="驳回后家长可重新发起退款申请。"
          class="review-alert"
        />
        <el-input
          v-model="reviewForm.reason"
          type="textarea"
          :rows="4"
          maxlength="255"
          show-word-limit
          placeholder="请填写驳回原因（必填）"
        />
      </template>

      <template #footer>
        <el-button @click="reviewVisible = false">取消</el-button>
        <el-button
          :type="reviewType === 'approve' ? 'success' : 'danger'"
          :loading="reviewing"
          :disabled="reviewType === 'approve' && needVoucher"
          @click="submitReview"
        >
          {{ reviewType === 'approve' ? '确认通过并提交凭证' : '确认驳回' }}
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
.refund-summary {
  background: #f7f8fa;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  padding: 10px 14px;
  margin: 0 0 14px;
}
.rs-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 13px;
  color: #6b7280;
  line-height: 26px;
}
.rs-row b {
  color: #1f2937;
  font-weight: 600;
}
.rs-highlight b {
  color: #2f7d57;
}
.rs-amount {
  border-top: 1px dashed #e5e7eb;
  margin-top: 4px;
  padding-top: 6px;
}
.rs-amount b {
  color: #e11d48;
  font-size: 16px;
}
.cell-less {
  color: #d97706;
  font-size: 12px;
  margin-top: 2px;
}

.voucher-cell {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
}

.voucher-thumb {
  width: 36px;
  height: 36px;
  border-radius: 6px;
  border: 1px solid #eee5d8;
}

.voucher-upload {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.voucher-item {
  position: relative;
  width: 72px;
  height: 72px;
}

.voucher-add {
  width: 72px;
  height: 72px;
  border: 1px dashed #c9bda8;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 26px;
  color: #b3a892;
  background: #faf7f1;
}

.voucher-img {
  width: 72px;
  height: 72px;
  border-radius: 8px;
  border: 1px solid #eee5d8;
}

.voucher-del {
  position: absolute;
  top: -8px;
  right: -8px;
  width: 20px;
  height: 20px;
  min-height: 20px;
  padding: 0;
}
</style>

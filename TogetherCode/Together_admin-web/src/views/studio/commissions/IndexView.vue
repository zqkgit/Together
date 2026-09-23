<script setup lang="ts">
import { computed, onMounted, reactive, ref } from "vue";
import { ElMessage } from "element-plus";
import { Refresh } from "@element-plus/icons-vue";
import type { UploadRequestOptions } from "element-plus";
import { fmtTime } from "../../../utils/format";
import {
  fetchStudioCommissions,
  reviewStudioCommission,
  uploadStudioImages,
  type WithdrawalItem,
  type PayMethod
} from "../../../services/studio";

const loading = ref(false);
const status = ref<number | "">("");
const rows = ref<WithdrawalItem[]>([]);

const statusMeta: Record<number, { text: string; type: "warning" | "success" | "danger" }> = {
  0: { text: "待审核", type: "warning" },
  1: { text: "待推广人确认", type: "warning" },
  2: { text: "已驳回", type: "danger" },
  3: { text: "已完成", type: "success" }
};

// 线下打款方式（平台不经手资金，工作室线下打款后登记并上传打款凭证）
const PAY_METHODS: Array<{ value: PayMethod; label: string; online: boolean }> = [
  { value: "wechat", label: "微信转账", online: true },
  { value: "alipay", label: "支付宝转账", online: true },
  { value: "bank", label: "银行转账", online: true },
  { value: "qrcode", label: "收款码转账", online: true },
  { value: "cash", label: "现金", online: false },
  { value: "other", label: "其他", online: true }
];
const isOnline = (m: string | null | undefined) =>
  PAY_METHODS.find((p) => p.value === m)?.online ?? true;

async function loadData() {
  loading.value = true;
  try {
    rows.value = (await fetchStudioCommissions({ status: status.value === "" ? undefined : status.value })).list;
  } catch {
    // 拦截器已提示
  } finally {
    loading.value = false;
  }
}

// 审核（通过 = 已线下打款并传凭证；驳回 = 填原因）
const reviewVisible = ref(false);
const reviewType = ref<"approve" | "reject">("approve");
const reviewId = ref("");
const reviewing = ref(false);
const reviewForm = reactive<{ method: PayMethod; voucher_images: string[]; reject_reason: string }>({
  method: "wechat",
  voucher_images: [],
  reject_reason: ""
});

const needVoucher = computed(
  () => reviewType.value === "approve" && isOnline(reviewForm.method) && reviewForm.voucher_images.length === 0
);

function openReview(row: WithdrawalItem, type: "approve" | "reject") {
  reviewType.value = type;
  reviewId.value = row.withdraw_id;
  reviewForm.method = "wechat";
  reviewForm.voucher_images = [];
  reviewForm.reject_reason = "";
  reviewVisible.value = true;
}

async function uploadVoucher(options: UploadRequestOptions) {
  const file = options.file as File;
  try {
    const urls = await uploadStudioImages([file], "voucher");
    reviewForm.voucher_images.push(...urls);
  } catch {
    // 拦截器已提示
  }
}

async function submitReview() {
  if (reviewType.value === "reject") {
    if (!reviewForm.reject_reason.trim()) {
      ElMessage.warning("驳回必须填写原因");
      return;
    }
  } else if (isOnline(reviewForm.method) && reviewForm.voucher_images.length === 0) {
    ElMessage.warning("线上打款请上传打款凭证");
    return;
  }
  reviewing.value = true;
  try {
    await reviewStudioCommission(
      reviewId.value,
      reviewType.value === "approve"
        ? {
            action: "approve",
            method: reviewForm.method,
            voucher_images: isOnline(reviewForm.method) ? reviewForm.voucher_images : reviewForm.voucher_images
          }
        : { action: "reject", reject_reason: reviewForm.reject_reason.trim() }
    );
    ElMessage.success(
      reviewType.value === "approve" ? "已登记打款，等待推广人确认到账" : "已驳回领取申请"
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
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <span>佣金领取审核</span>
          <div class="toolbar-right">
            <el-select v-model="status" placeholder="状态" clearable style="width: 140px" @change="loadData">
              <el-option label="待审核" :value="0" />
              <el-option label="待推广人确认" :value="1" />
              <el-option label="已完成" :value="3" />
              <el-option label="已驳回" :value="2" />
            </el-select>
            <el-button :icon="Refresh" @click="loadData">刷新</el-button>
          </div>
        </div>
      </template>

      <el-table :data="rows" row-key="withdraw_id">
        <el-table-column type="expand">
          <template #default="{ row }">
            <div class="detail-wrap">
              <div class="detail-title">佣金明细（{{ row.commissions.length }} 笔）</div>
              <div v-for="c in row.commissions" :key="c.commission_id" class="detail-row">
                <span class="dr-order">订单 {{ c.order_id }}</span>
                <span class="dr-rate">费率 {{ Number(c.rate).toFixed(0) }}%</span>
                <span class="dr-status">{{ c.status_text }}</span>
                <span class="dr-amount">¥ {{ Number(c.amount).toFixed(2) }}</span>
                <span class="dr-time">{{ fmtTime(c.created_at) }}</span>
              </div>
              <div class="steps-wrap">
                <div
                  v-for="(s, i) in row.steps"
                  :key="i"
                  class="step-item"
                  :class="{ done: s.done, current: s.current && !s.done }"
                >
                  <span class="step-dot">{{ s.done ? "✓" : i + 1 }}</span>
                  <span class="step-title">{{ s.title }}</span>
                </div>
              </div>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="推广人" min-width="170">
          <template #default="{ row }">
            <div class="cell-strong">{{ row.user?.nickname || "-" }}</div>
            <div class="cell-sub">{{ row.user?.phone || "-" }}</div>
          </template>
        </el-table-column>
        <el-table-column label="笔数" width="80" align="center">
          <template #default="{ row }">{{ row.commissions.length }} 笔</template>
        </el-table-column>
        <el-table-column label="领取金额" width="120" align="right">
          <template #default="{ row }">
            <span class="amount-cell">{{ row.amount_text }}</span>
          </template>
        </el-table-column>
        <el-table-column label="打款方式" width="110" align="center">
          <template #default="{ row }">{{ row.method ? row.method_text : "-" }}</template>
        </el-table-column>
        <el-table-column label="打款凭证" width="110" align="center">
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
            <span v-else-if="row.status >= 1 && row.method === 'cash'" class="cell-sub">现金</span>
            <span v-else class="cell-sub">-</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="120">
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
              <span class="cell-sub">等待推广人确认</span>
            </template>
            <span v-else class="cell-sub">已处理</span>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && rows.length === 0" class="empty-tip">暂无佣金领取申请</div>
    </el-card>

    <!-- 审核对话框 -->
    <el-dialog
      v-model="reviewVisible"
      :title="reviewType === 'approve' ? '通过领取 · 登记线下打款' : '驳回领取申请'"
      width="480px"
    >
      <template v-if="reviewType === 'approve'">
        <el-alert
          type="success"
          :closable="false"
          show-icon
          title="通过即表示你已在线下把佣金打给推广人。选择打款方式并上传凭证后，领取单进入「待推广人确认」；推广人在 App 确认到账后才标记完成。"
          class="review-alert"
        />
        <el-form label-position="top">
          <el-form-item label="打款方式（线下结算，平台不经手资金）">
            <el-radio-group v-model="reviewForm.method">
              <el-radio v-for="m in PAY_METHODS" :key="m.value" :value="m.value">{{ m.label }}</el-radio>
            </el-radio-group>
          </el-form-item>

          <el-alert
            v-if="!isOnline(reviewForm.method)"
            type="success"
            :closable="false"
            show-icon
            title="现金打款可直接登记，无需上传凭证"
            class="review-alert"
          />

          <el-form-item v-if="isOnline(reviewForm.method)" label="打款凭证截图（必填，可多张）">
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
        </el-form>
      </template>

      <template v-else>
        <el-alert
          type="warning"
          :closable="false"
          show-icon
          title="驳回后对应佣金退回「待申请」，推广人可重新发起领取。"
          class="review-alert"
        />
        <el-input
          v-model="reviewForm.reject_reason"
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

.detail-wrap {
  padding: 6px 20px 14px 48px;
}
.detail-title {
  font-size: 13px;
  font-weight: 600;
  color: #2b2621;
  margin-bottom: 8px;
}
.detail-row {
  display: flex;
  align-items: center;
  gap: 16px;
  font-size: 12px;
  color: #6b655b;
  line-height: 26px;
}
.dr-order {
  color: #9c9385;
}
.dr-amount {
  margin-left: auto;
  font-weight: 600;
  color: #c15f2c;
}
.dr-time {
  color: #b3a892;
}
.steps-wrap {
  display: flex;
  align-items: center;
  margin-top: 14px;
}
.step-item {
  display: flex;
  align-items: center;
  gap: 6px;
  flex: 1;
}
.step-dot {
  width: 22px;
  height: 22px;
  border-radius: 50%;
  background: #e7e0d3;
  color: #9c9385;
  font-size: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}
.step-title {
  font-size: 12px;
  color: #9c9385;
}
.step-item.done .step-dot {
  background: #2f7d57;
  color: #fff;
}
.step-item.done .step-title {
  color: #2f7d57;
}
.step-item.current .step-dot {
  background: #fff;
  border: 1.5px solid #2f7d57;
  color: #2f7d57;
}
.step-item.current .step-title {
  color: #2f7d57;
  font-weight: 600;
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

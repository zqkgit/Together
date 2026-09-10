<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Search, Refresh } from "@element-plus/icons-vue";
import {
  fetchReviews,
  fetchReviewDetail,
  handleReview,
  type ReviewItem,
  type ReviewDetail,
  type ReviewStatus
} from "../../services/admin";

const loading = ref(false);
const detailLoading = ref(false);
const total = ref(0);
const page = ref(1);
const size = ref(10);
const status = ref<ReviewStatus | "">(0);
const keyword = ref("");
const reviews = ref<ReviewItem[]>([]);

// 详情
const drawerOpen = ref(false);
const detail = ref<ReviewDetail | null>(null);

// 审核操作
const actionVisible = ref(false);
const actionType = ref<"approve" | "reject">("approve");
const actionId = ref("");
const actionReason = ref("");
const actionSubmitting = ref(false);

const statusMeta: Record<ReviewStatus, { text: string; type: "warning" | "success" | "danger" }> = {
  0: { text: "待审核", type: "warning" },
  1: { text: "已通过", type: "success" },
  2: { text: "已驳回", type: "danger" }
};

async function loadData() {
  loading.value = true;
  try {
    const response = await fetchReviews({
      status: status.value,
      page: page.value,
      size: size.value,
      keyword: keyword.value.trim() || undefined
    });
    total.value = response.total;
    reviews.value = response.list;
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    loading.value = false;
  }
}

function handleSearch() {
  page.value = 1;
  loadData();
}

function handleTabChange(value: string | number) {
  status.value = value as ReviewStatus | "";
  page.value = 1;
  loadData();
}

function handlePageChange(next: number) {
  page.value = next;
  loadData();
}

async function openDetail(row: ReviewItem) {
  drawerOpen.value = true;
  detailLoading.value = true;
  detail.value = null;
  try {
    detail.value = await fetchReviewDetail(row.id);
  } catch {
    drawerOpen.value = false;
  } finally {
    detailLoading.value = false;
  }
}

function openReject(row: ReviewItem) {
  actionType.value = "reject";
  actionId.value = row.id;
  actionReason.value = "";
  actionVisible.value = true;
}

async function submitAction() {
  if (actionType.value === "reject" && !actionReason.value.trim()) {
    ElMessage.warning("驳回必须填写原因");
    return;
  }
  actionSubmitting.value = true;
  try {
    await handleReview(actionId.value, {
      action: actionType.value,
      reason: actionReason.value.trim() || undefined
    });
    ElMessage.success(actionType.value === "approve" ? "已通过该入驻申请" : "已驳回该入驻申请");
    actionVisible.value = false;
    drawerOpen.value = false;
    loadData();
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    actionSubmitting.value = false;
  }
}

async function handleQuickReview(row: ReviewItem, action: "approve" | "reject") {
  if (action === "reject") {
    openReject(row);
    return;
  }
  try {
    await ElMessageBox.confirm(
      `确认通过「${row.name}」的入驻申请？通过后其工作室即开始营业，可正常收单。`,
      "通过申请",
      {
        confirmButtonText: "确认通过",
        cancelButtonText: "取消",
        type: "success"
      }
    );
  } catch {
    return;
  }
  actionSubmitting.value = true;
  try {
    await handleReview(row.id, { action: "approve" });
    ElMessage.success("已通过该入驻申请");
    loadData();
  } catch {
    // 忽略
  } finally {
    actionSubmitting.value = false;
  }
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <el-radio-group
            :model-value="status"
            size="small"
            @change="handleTabChange"
          >
            <el-radio-button :value="''">全部</el-radio-button>
            <el-radio-button :value="0">待审核</el-radio-button>
            <el-radio-button :value="1">已通过</el-radio-button>
            <el-radio-button :value="2">已驳回</el-radio-button>
          </el-radio-group>

          <div class="toolbar-right">
            <el-input
              v-model="keyword"
              placeholder="搜索工作室名称"
              clearable
              style="width: 220px"
              :prefix-icon="Search"
              @keyup.enter="handleSearch"
              @clear="handleSearch"
            />
            <el-button :icon="Refresh" @click="handleSearch">查询</el-button>
          </div>
        </div>
      </template>

      <el-table :data="reviews" row-key="id">
        <el-table-column prop="name" label="工作室名称" min-width="200">
          <template #default="{ row }">
            <span class="cell-strong">{{ row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="type" label="类型" width="120" />
        <el-table-column label="申请人" min-width="180">
          <template #default="{ row }">
            <div>{{ row.applicant }}</div>
            <div class="cell-sub">{{ row.applicant_phone }}</div>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status as ReviewStatus].type" effect="light">
              {{ statusMeta[row.status as ReviewStatus].text }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="submittedAt" label="提交时间" width="180" />
        <el-table-column label="操作" width="230" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openDetail(row)">查看</el-button>
            <template v-if="row.status === 0">
              <el-button
                text
                type="success"
                :disabled="actionSubmitting"
                @click="handleQuickReview(row, 'approve')"
              >
                通过
              </el-button>
              <el-button
                text
                type="danger"
                :disabled="actionSubmitting"
                @click="openReject(row)"
              >
                驳回
              </el-button>
            </template>
            <span v-else class="cell-sub">已处理</span>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-row">
        <el-pagination
          v-model:current-page="page"
          :page-size="size"
          :total="total"
          layout="total, prev, pager, next"
          background
          @current-change="handlePageChange"
        />
      </div>
    </el-card>

    <!-- 申请详情抽屉 -->
    <el-drawer v-model="drawerOpen" title="入驻申请详情" size="460px">
      <div v-loading="detailLoading" class="detail-body">
        <template v-if="detail">
          <div class="detail-hero">
            <div class="detail-name">{{ detail.name }}</div>
            <el-tag :type="statusMeta[detail.status].type" effect="light">
              {{ statusMeta[detail.status].text }}
            </el-tag>
            <div class="detail-sub">申请版本 v{{ detail.version }}</div>
          </div>

          <el-descriptions :column="1" border size="small">
            <el-descriptions-item label="申请人">
              {{ detail.applicant?.nickname || "-" }}
              <span class="cell-sub">（{{ detail.applicant?.phone || "-" }}）</span>
            </el-descriptions-item>
            <el-descriptions-item label="经营地址">{{ detail.address || "-" }}</el-descriptions-item>
            <el-descriptions-item label="联系电话">{{ detail.phone || "-" }}</el-descriptions-item>
            <el-descriptions-item label="机构简介">
              <div class="intro-text">{{ detail.intro || "-" }}</div>
            </el-descriptions-item>
            <el-descriptions-item label="营业执照">
              <span v-if="detail.license" class="link-text">{{ detail.license }}</span>
              <span v-else>-</span>
            </el-descriptions-item>
            <el-descriptions-item label="办学许可">
              <span v-if="detail.permit" class="link-text">{{ detail.permit }}</span>
              <span v-else>-</span>
            </el-descriptions-item>
            <el-descriptions-item label="提交时间">{{ detail.submitted_at }}</el-descriptions-item>
            <el-descriptions-item label="审核时间">{{ detail.reviewed_at || "-" }}</el-descriptions-item>
            <el-descriptions-item v-if="detail.review_reason" label="审核备注">
              {{ detail.review_reason }}
            </el-descriptions-item>
          </el-descriptions>

          <div v-if="detail.photos && detail.photos.length" class="photo-block">
            <div class="photo-title">资质 / 环境照片</div>
            <div class="photo-grid">
              <el-image
                v-for="(photo, index) in detail.photos"
                :key="index"
                :src="photo"
                :preview-src-list="detail.photos"
                fit="cover"
                class="photo-item"
              />
            </div>
          </div>

          <div v-if="detail.status === 0" class="detail-actions">
            <el-button
              type="success"
              :loading="actionSubmitting"
              @click="handleQuickReview(detail as unknown as ReviewItem, 'approve')"
            >
              通过申请
            </el-button>
            <el-button type="danger" :loading="actionSubmitting" @click="openReject(detail as unknown as ReviewItem)">
              驳回申请
            </el-button>
          </div>
        </template>
      </div>
    </el-drawer>

    <!-- 审核对话框 -->
    <el-dialog
      v-model="actionVisible"
      :title="actionType === 'approve' ? '通过入驻申请' : '驳回入驻申请'"
      width="440px"
    >
      <el-alert
        v-if="actionType === 'approve'"
        type="success"
        :closable="false"
        show-icon
        title="通过后工作室即刻营业，可发布课程并收单。"
        class="action-alert"
      />
      <el-alert
        v-else
        type="warning"
        :closable="false"
        show-icon
        title="驳回后将通知申请人，可在补充资料后重新提交。"
        class="action-alert"
      />
      <el-input
        v-model="actionReason"
        type="textarea"
        :rows="3"
        maxlength="255"
        show-word-limit
        :placeholder="
          actionType === 'reject' ? '请填写驳回原因（必填），将展示给申请人' : '审核备注（选填）'
        "
      />
      <template #footer>
        <el-button @click="actionVisible = false">取消</el-button>
        <el-button
          :type="actionType === 'approve' ? 'success' : 'danger'"
          :loading="actionSubmitting"
          @click="submitAction"
        >
          {{ actionType === "approve" ? "确认通过" : "确认驳回" }}
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
  gap: 12px;
  flex-wrap: wrap;
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

.pagination-row {
  display: flex;
  justify-content: flex-end;
  padding-top: 16px;
}

.detail-body {
  min-height: 200px;
}

.detail-hero {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 20px;
}

.detail-name {
  font-size: 20px;
  font-weight: 700;
  color: #2b2621;
  font-family: "Noto Serif SC", "Songti SC", serif;
}

.detail-sub {
  font-size: 12px;
  color: #9c9385;
}

.intro-text {
  line-height: 1.6;
  color: #2b2621;
  white-space: pre-wrap;
}

.link-text {
  color: #2f5d45;
}

.photo-block {
  margin-top: 20px;
}

.photo-title {
  font-size: 14px;
  font-weight: 600;
  color: #2b2621;
  margin-bottom: 10px;
}

.photo-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
}

.photo-item {
  width: 100%;
  aspect-ratio: 1;
  border-radius: 8px;
  border: 1px solid #e6dfd3;
}

.detail-actions {
  margin-top: 24px;
  display: flex;
  gap: 12px;
}

.action-alert {
  margin-bottom: 14px;
}
</style>

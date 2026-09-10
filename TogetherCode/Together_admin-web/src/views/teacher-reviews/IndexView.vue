<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { Refresh } from "@element-plus/icons-vue";
import {
  fetchTeacherCertifications,
  reviewTeacherCertification,
  type TeacherCertItem
} from "../../services/admin";

const loading = ref(false);
const status = ref<number | "">(0);
const list = ref<TeacherCertItem[]>([]);

const statusMeta: Record<number, { text: string; type: "warning" | "success" | "danger" }> = {
  0: { text: "待审核", type: "warning" },
  1: { text: "已通过", type: "success" },
  2: { text: "已驳回", type: "danger" }
};

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchTeacherCertifications({ status: status.value });
    list.value = data.list;
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    loading.value = false;
  }
}

function onStatusChange(value: string | number) {
  status.value = value as number | "";
  loadData();
}

// 审核
const reviewVisible = ref(false);
const reviewType = ref<"approve" | "reject">("approve");
const reviewRow = ref<TeacherCertItem | null>(null);
const reviewReason = ref("");
const reviewing = ref(false);

function openReview(row: TeacherCertItem, type: "approve" | "reject") {
  reviewType.value = type;
  reviewRow.value = row;
  reviewReason.value = "";
  reviewVisible.value = true;
}

async function submitReview() {
  if (!reviewRow.value) return;
  if (reviewType.value === "reject" && !reviewReason.value.trim()) {
    ElMessage.warning("驳回必须填写原因");
    return;
  }
  reviewing.value = true;
  try {
    await reviewTeacherCertification(reviewRow.value.id, {
      action: reviewType.value,
      reason: reviewReason.value.trim() || undefined
    });
    ElMessage.success(reviewType.value === "approve" ? "已通过老师认证" : "已驳回申请");
    reviewVisible.value = false;
    loadData();
  } catch {
    // 错误提示由拦截器统一处理
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
          <div class="filter-row">
            <el-radio-group :model-value="status" size="small" @change="onStatusChange">
              <el-radio-button :value="0">待审核</el-radio-button>
              <el-radio-button :value="1">已通过</el-radio-button>
              <el-radio-button :value="2">已驳回</el-radio-button>
              <el-radio-button :value="''">全部</el-radio-button>
            </el-radio-group>
          </div>
          <el-button :icon="Refresh" @click="loadData">刷新</el-button>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        show-icon
        title="老师认证流程：用户（默认家长角色）在 App 端申请成为老师 → 平台审核通过后获得老师档案与老师角色 → 再向工作室申请合作（工作室侧审批）。"
        class="flow-alert"
      />

      <el-table :data="list" row-key="id">
        <el-table-column label="申请人" min-width="150">
          <template #default="{ row }">
            <span class="cell-strong">{{ row.real_name }}</span>
            <div class="cell-sub">{{ row.phone }}</div>
          </template>
        </el-table-column>
        <el-table-column label="擅长方向" min-width="160">
          <template #default="{ row }">
            <el-tag
              v-for="subject in row.subjects"
              :key="subject"
              size="small"
              effect="plain"
              class="subject-tag"
            >
              {{ subject }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="years" label="教龄" width="80" align="center">
          <template #default="{ row }">{{ row.years }} 年</template>
        </el-table-column>
        <el-table-column prop="intro" label="简介" min-width="180" show-overflow-tooltip />
        <el-table-column label="证书编号" width="130">
          <template #default="{ row }">{{ row.cert_no || "-" }}</template>
        </el-table-column>
        <el-table-column label="申请时间" width="110">
          <template #default="{ row }">{{ row.submitted_at.slice(0, 10) }}</template>
        </el-table-column>
        <el-table-column label="状态" width="100">
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
            <span v-else class="cell-sub">{{ row.review_reason || "已处理" }}</span>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && list.length === 0" class="empty-tip">
        暂无老师认证申请（用户可在 App 端申请成为老师）
      </div>
    </el-card>

    <!-- 审核对话框 -->
    <el-dialog
      v-model="reviewVisible"
      :title="reviewType === 'approve' ? `通过认证 · ${reviewRow?.real_name || ''}` : `驳回认证 · ${reviewRow?.real_name || ''}`"
      width="440px"
    >
      <el-alert
        :type="reviewType === 'approve' ? 'success' : 'warning'"
        :closable="false"
        show-icon
        :title="
          reviewType === 'approve'
            ? '通过后该用户获得老师档案与老师角色，可在 App 端向工作室申请合作。'
            : '驳回后用户可修改资料后重新申请。'
        "
        class="review-alert"
      />
      <el-input
        v-model="reviewReason"
        type="textarea"
        :rows="3"
        maxlength="255"
        show-word-limit
        :placeholder="reviewType === 'reject' ? '请填写驳回原因（必填）' : '备注（选填）'"
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
  gap: 12px;
  flex-wrap: wrap;
}

.flow-alert {
  margin-bottom: 14px;
}

.cell-strong {
  font-weight: 600;
  color: #2b2621;
}

.cell-sub {
  font-size: 12px;
  color: #9c9385;
}

.subject-tag {
  margin-right: 4px;
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

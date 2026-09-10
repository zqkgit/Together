<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Refresh } from "@element-plus/icons-vue";
import {
  fetchStudioTeachers,
  reviewTeacherApplication,
  releaseTeacher,
  type TeacherApplicationItem,
  type TeacherStaffItem
} from "../../../services/studio";

const loading = ref(false);
const activeTab = ref("applications");
const status = ref<number | "">(0);
const applications = ref<TeacherApplicationItem[]>([]);
const staff = ref<TeacherStaffItem[]>([]);

const statusMeta: Record<number, { text: string; type: "warning" | "success" | "danger" }> = {
  0: { text: "待处理", type: "warning" },
  1: { text: "已通过", type: "success" },
  2: { text: "已驳回", type: "danger" }
};

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchStudioTeachers({
      status: activeTab.value === "applications" ? status.value : ""
    });
    applications.value = data.applications;
    staff.value = data.staff;
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    loading.value = false;
  }
}

function onTabChange() {
  status.value = 0;
  loadData();
}

// 审批
const reviewVisible = ref(false);
const reviewType = ref<"approve" | "reject">("approve");
const reviewRow = ref<TeacherApplicationItem | null>(null);
const reviewReason = ref("");
const reviewing = ref(false);

function openReview(row: TeacherApplicationItem, type: "approve" | "reject") {
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
    await reviewTeacherApplication(reviewRow.value.id, {
      action: reviewType.value,
      reason: reviewReason.value.trim() || undefined
    });
    ElMessage.success(reviewType.value === "approve" ? "已通过，老师加入工作室" : "已驳回申请");
    reviewVisible.value = false;
    loadData();
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    reviewing.value = false;
  }
}

onMounted(loadData);

// 解除合作
async function onRelease(row: TeacherStaffItem) {
  try {
    await ElMessageBox.confirm(
      `解除与「${row.real_name}」的合作关系？解除后老师不再出现在本工作室在职列表，但其档案与其他工作室绑定关系不受影响。`,
      "解除合作",
      { type: "warning", confirmButtonText: "确认解除", cancelButtonText: "取消" }
    );
    await releaseTeacher(row.teacher_id);
    ElMessage.success("已解除合作");
    loadData();
  } catch (error) {
    if (error === "cancel" || error === "close") return;
    // 其他错误由拦截器统一处理
  }
}
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <el-radio-group :model-value="activeTab" @change="(v: string | number) => { activeTab = v as string; onTabChange(); }">
            <el-radio-button value="applications">合作申请（{{ applications.length }}）</el-radio-button>
            <el-radio-button value="staff">在职老师（{{ staff.length }}）</el-radio-button>
          </el-radio-group>
          <el-button :icon="Refresh" @click="loadData">刷新</el-button>
        </div>
      </template>

      <!-- 合作申请 -->
      <template v-if="activeTab === 'applications'">
        <div class="filter-row">
          <el-radio-group :model-value="status" size="small" @change="(v: string | number) => { status = v as number; loadData(); }">
            <el-radio-button :value="0">待处理</el-radio-button>
            <el-radio-button :value="1">已通过</el-radio-button>
            <el-radio-button :value="2">已驳回</el-radio-button>
            <el-radio-button :value="''">全部</el-radio-button>
          </el-radio-group>
        </div>

        <el-table :data="applications" row-key="id">
          <el-table-column label="老师" min-width="150">
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
          <el-table-column label="证书" width="130">
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
        <div v-if="!loading && applications.length === 0" class="empty-tip">
          暂无老师合作申请
        </div>
      </template>

      <!-- 在职老师 -->
      <template v-else>
        <el-table :data="staff" row-key="teacher_id">
          <el-table-column label="老师" min-width="150">
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
          <el-table-column label="证书" width="140">
            <template #default="{ row }">
              <el-tag :type="row.cert_status === 1 ? 'success' : 'info'" effect="light" size="small">
                {{ row.cert_status === 1 ? "已认证" : "未认证" }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column prop="rating" label="评分" width="80" align="center">
            <template #default="{ row }">{{ Number(row.rating).toFixed(1) }}</template>
          </el-table-column>
          <el-table-column prop="student_count" label="学员数" width="80" align="center" />
          <el-table-column label="加入时间" width="110">
            <template #default="{ row }">
              <span v-if="row.bound_at" class="cell-sub">{{ row.bound_at.slice(0, 10) }}</span>
              <span v-else class="cell-sub">-</span>
            </template>
          </el-table-column>
          <el-table-column label="操作" width="120" fixed="right">
            <template #default="{ row }">
              <el-button text type="danger" @click="onRelease(row)">解除合作</el-button>
            </template>
          </el-table-column>
        </el-table>
        <div v-if="!loading && staff.length === 0" class="empty-tip">暂无在职老师</div>
      </template>
    </el-card>

    <!-- 审批对话框 -->
    <el-dialog
      v-model="reviewVisible"
      :title="reviewType === 'approve' ? `通过申请 · ${reviewRow?.real_name || ''}` : `驳回申请 · ${reviewRow?.real_name || ''}`"
      width="440px"
    >
      <el-alert
        :type="reviewType === 'approve' ? 'success' : 'warning'"
        :closable="false"
        show-icon
        :title="
          reviewType === 'approve'
            ? '通过后老师加入本工作室，可被指派到班级与排课，并获得老师端 App 权限。'
            : '驳回后老师可重新提交申请。'
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

.filter-row {
  margin-bottom: 12px;
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

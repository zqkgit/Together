<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { Refresh } from "@element-plus/icons-vue";
import {
  fetchStudioLeaves,
  fetchStudioSchedules,
  reviewLeave,
  handleLeaveMakeup,
  type LeaveItem,
  type ScheduleItem
} from "../../../services/studio";
import { useAuthStore } from "../../../stores/auth";

const authStore = useAuthStore();
const studioId = computed(() => authStore.account?.studio_id || "");

const loading = ref(false);
const status = ref<number | "">(0);
const leaves = ref<LeaveItem[]>([]);

const statusMeta: Record<number, { text: string; type: "warning" | "success" | "danger" | "info" }> = {
  0: { text: "待处理", type: "warning" },
  1: { text: "已同意", type: "success" },
  2: { text: "已驳回", type: "danger" },
  3: { text: "已取消", type: "info" }
};

const makeupMeta: Record<number, string> = {
  0: "未安排补课",
  1: "待补课",
  2: "已补课",
  3: "已放弃补课"
};

async function loadData() {
  loading.value = true;
  try {
    leaves.value = (
      await fetchStudioLeaves({ studio_id: studioId.value, status: status.value })
    ).list;
  } catch {
    // 忽略
  } finally {
    loading.value = false;
  }
}

// 审批
const reviewVisible = ref(false);
const reviewType = ref<"agree" | "reject">("agree");
const reviewId = ref("");
const reviewNote = ref("");
const reviewing = ref(false);

function openReview(row: LeaveItem, type: "agree" | "reject") {
  reviewType.value = type;
  reviewId.value = row.leave_id;
  reviewNote.value = "";
  reviewVisible.value = true;
}

async function submitReview() {
  reviewing.value = true;
  try {
    await reviewLeave(reviewId.value, {
      action: reviewType.value,
      note: reviewNote.value.trim() || undefined
    });
    ElMessage.success(reviewType.value === "agree" ? "已同意请假" : "已驳回请假");
    reviewVisible.value = false;
    loadData();
  } catch {
    // 忽略
  } finally {
    reviewing.value = false;
  }
}

// 补课
const makeupVisible = ref(false);
const makeupLeave = ref<LeaveItem | null>(null);
const makeupOptions = ref<ScheduleItem[]>([]);
const makeupScheduleId = ref("");
const makeupSubmitting = ref(false);
const makeupLoading = ref(false);

async function openMakeup(row: LeaveItem) {
  makeupVisible.value = true;
  makeupLoading.value = true;
  makeupLeave.value = row;
  makeupScheduleId.value = "";
  makeupOptions.value = [];
  try {
    // 拉未来 6 周排课，过滤同班级且未消课
    const weekStart = new Date();
    const start = getMonday(weekStart);
    const results: ScheduleItem[] = [];
    for (let i = 0; i < 6; i += 1) {
      const week = addDays(start, i * 7);
      const data = await fetchStudioSchedules({ studio_id: studioId.value, week });
      results.push(...data.list);
    }
    const seen = new Set<string>();
    makeupOptions.value = results.filter((item) => {
      if (String(item.class_id) !== String(row.class_id)) return false;
      if (seen.has(item.schedule_id)) return false;
      seen.add(item.schedule_id);
      return true;
    });
  } catch {
    // 忽略
  } finally {
    makeupLoading.value = false;
  }
}

function getMonday(date: Date): string {
  const d = new Date(date);
  const day = d.getDay() || 7;
  d.setDate(d.getDate() - day + 1);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${dd}`;
}

function addDays(dateStr: string, days: number): string {
  const d = new Date(`${dateStr}T00:00:00`);
  d.setDate(d.getDate() + days);
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${dd}`;
}

async function submitMakeup() {
  if (!makeupScheduleId.value) {
    ElMessage.warning("请选择补课节次");
    return;
  }
  makeupSubmitting.value = true;
  try {
    await handleLeaveMakeup(makeupLeave.value!.leave_id, {
      action: "assign",
      makeup_schedule_id: makeupScheduleId.value
    });
    ElMessage.success("补课节次已绑定");
    makeupVisible.value = false;
    loadData();
  } catch {
    // 忽略
  } finally {
    makeupSubmitting.value = false;
  }
}

async function abandonMakeup(row: LeaveItem) {
  try {
    await handleLeaveMakeup(row.leave_id, { action: "abandon" });
    ElMessage.success("已放弃补课");
    loadData();
  } catch {
    // 忽略
  }
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <span>请假审批</span>
          <div class="toolbar-right">
            <el-radio-group :model-value="status" size="small" @change="(v: string | number) => { status = v as number; loadData(); }">
              <el-radio-button :value="0">待处理</el-radio-button>
              <el-radio-button :value="1">已同意</el-radio-button>
              <el-radio-button :value="2">已驳回</el-radio-button>
              <el-radio-button :value="''">全部</el-radio-button>
            </el-radio-group>
            <el-button :icon="Refresh" @click="loadData">刷新</el-button>
          </div>
        </div>
      </template>

      <el-table :data="leaves" row-key="leave_id">
        <el-table-column label="学员 / 班级" min-width="170">
          <template #default="{ row }">
            <div class="cell-strong">{{ row.child?.nickname || "-" }}</div>
            <div class="cell-sub">{{ row.classItem?.name || "-" }}</div>
          </template>
        </el-table-column>
        <el-table-column label="原上课时间" min-width="170">
          <template #default="{ row }">
            <div>{{ row.schedule?.lesson_date || "-" }} {{ row.schedule?.start_time || "" }}</div>
            <div class="cell-sub">{{ row.schedule?.location || "" }}</div>
          </template>
        </el-table-column>
        <el-table-column prop="reason" label="请假原因" min-width="140" show-overflow-tooltip />
        <el-table-column label="补课状态" width="120">
          <template #default="{ row }">
            <span class="cell-sub">{{ makeupMeta[row.makeup_status] || "-" }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status].type" effect="light">
              {{ statusMeta[row.status].text }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <template v-if="row.status === 0">
              <el-button text type="success" @click="openReview(row, 'agree')">同意</el-button>
              <el-button text type="danger" @click="openReview(row, 'reject')">驳回</el-button>
            </template>
            <template v-else-if="row.status === 1 && row.makeup_status === 0">
              <el-button text type="primary" @click="openMakeup(row)">安排补课</el-button>
            </template>
            <template v-else-if="row.status === 1 && row.makeup_status === 1">
              <span class="cell-sub">{{ row.makeupSchedule?.lesson_date || "待补课" }}</span>
              <el-button text type="warning" @click="abandonMakeup(row)">放弃</el-button>
            </template>
            <span v-else class="cell-sub">已处理</span>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && leaves.length === 0" class="empty-tip">暂无请假记录</div>
    </el-card>

    <!-- 审批对话框 -->
    <el-dialog
      v-model="reviewVisible"
      :title="reviewType === 'agree' ? '同意请假' : '驳回请假'"
      width="440px"
    >
      <el-input
        v-model="reviewNote"
        type="textarea"
        :rows="3"
        maxlength="255"
        show-word-limit
        placeholder="审批备注（选填）"
      />
      <template #footer>
        <el-button @click="reviewVisible = false">取消</el-button>
        <el-button
          :type="reviewType === 'agree' ? 'success' : 'danger'"
          :loading="reviewing"
          @click="submitReview"
        >
          {{ reviewType === "agree" ? "确认同意" : "确认驳回" }}
        </el-button>
      </template>
    </el-dialog>

    <!-- 补课绑定 -->
    <el-dialog v-model="makeupVisible" title="安排补课" width="560px">
      <div v-loading="makeupLoading">
        <el-alert
          type="info"
          :closable="false"
          show-icon
          title="选择一节该班级未来未消课的排课作为补课节次。"
          class="makeup-alert"
        />
        <el-table v-if="makeupOptions.length" :data="makeupOptions" size="small" highlight-current-row @current-change="(row: ScheduleItem | null) => (makeupScheduleId = row?.schedule_id || '')">
          <el-table-column prop="lesson_date" label="日期" width="110" />
          <el-table-column label="时间" width="120">
            <template #default="{ row }">{{ row.start_time }}-{{ row.end_time }}</template>
          </el-table-column>
          <el-table-column label="班级" min-width="130">
            <template #default="{ row }">{{ row.class?.name || "-" }}</template>
          </el-table-column>
        </el-table>
        <div v-if="!makeupLoading && makeupOptions.length === 0" class="empty-tip">
          未来 6 周暂无该班级可补课的排课
        </div>
      </div>
      <template #footer>
        <el-button @click="makeupVisible = false">取消</el-button>
        <el-button type="primary" :loading="makeupSubmitting" :disabled="!makeupScheduleId" @click="submitMakeup">
          确认绑定
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

.empty-tip {
  padding: 32px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
}

.makeup-alert {
  margin-bottom: 12px;
}
</style>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { Refresh, Search } from "@element-plus/icons-vue";
import {
  fetchStudioStudents,
  fetchStudentLessonLogs,
  fetchStudioClasses,
  type StudentItem,
  type StudentLessonLogItem,
  type ClassItem
} from "../../../services/studio";
import { useAuthStore } from "../../../stores/auth";

const authStore = useAuthStore();
const studioId = computed(() => authStore.account?.studio_id || "");

const loading = ref(false);
const q = ref("");
const status = ref("");
const classFilter = ref("");
const classOptions = ref<ClassItem[]>([]);
const students = ref<StudentItem[]>([]);

// 详情
const drawerOpen = ref(false);
const current = ref<StudentItem | null>(null);

// 课时流水
const logsLoading = ref(false);
const logs = ref<StudentLessonLogItem[]>([]);
const logCourseFilter = ref("");

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchStudioStudents({
      studio_id: studioId.value,
      q: q.value.trim() || undefined,
      status: status.value || undefined,
      class_id: classFilter.value || undefined
    });
    students.value = data.list;
  } catch {
    // 忽略
  } finally {
    loading.value = false;
  }
}

function openDetail(row: StudentItem) {
  current.value = row;
  logCourseFilter.value = "";
  drawerOpen.value = true;
  loadLogs(row.child_id);
}

async function loadLogs(childId: string, courseId?: string) {
  logsLoading.value = true;
  try {
    const data = await fetchStudentLessonLogs(childId, {
      course_id: courseId || undefined
    });
    logs.value = data.list;
  } catch {
    // 忽略
  } finally {
    logsLoading.value = false;
  }
}

function changeLogCourse() {
  if (current.value) {
    loadLogs(current.value.child_id, logCourseFilter.value || undefined);
  }
}

function sourceText(source: number): string {
  const map: Record<number, string> = {
    1: "出勤打卡",
    2: "排课消课",
    3: "手动消课",
    4: "退款扣减"
  };
  return map[source] || "其他";
}

function genderText(gender: string): string {
  const map: Record<string, string> = { male: "男", female: "女", other: "其他" };
  return map[gender] || "-";
}

onMounted(async () => {
  try {
    const data = await fetchStudioClasses({ studio_id: studioId.value });
    classOptions.value = data.list;
  } catch {
    // 忽略
  }
  loadData();
});
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <div class="toolbar-left">
            <el-select v-model="classFilter" placeholder="全部班级" clearable style="width: 160px" @change="loadData">
              <el-option v-for="c in classOptions" :key="c.class_id" :label="c.name" :value="c.class_id" />
            </el-select>
            <el-input
              v-model="q"
              placeholder="搜索学员昵称"
              clearable
              style="width: 200px"
              :prefix-icon="Search"
              @keyup.enter="loadData"
              @clear="loadData"
            />
            <el-select v-model="status" placeholder="课时状态" clearable style="width: 130px" @change="loadData">
              <el-option label="有剩余课时" value="active" />
              <el-option label="课时耗尽" value="empty" />
            </el-select>
            <el-button :icon="Refresh" @click="loadData">查询</el-button>
          </div>
        </div>
      </template>

      <el-table :data="students" row-key="child_id">
        <el-table-column prop="nickname" label="学员" min-width="160">
          <template #default="{ row }">
            <span class="cell-strong">{{ row.nickname }}</span>
            <div class="cell-sub">
              {{ genderText(row.gender) }} · {{ row.birthday || "未填生日" }}
            </div>
          </template>
        </el-table-column>
        <el-table-column label="总剩余课时" width="140" align="center">
          <template #default="{ row }">
            <span :class="{ 'zero-cell': row.total_remaining_lessons === 0 }">
              {{ row.total_remaining_lessons }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="120">
          <template #default="{ row }">
            <el-tag :type="row.status === 'active' ? 'success' : 'info'" effect="light">
              {{ row.status === "active" ? "在学" : "课时耗尽" }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="家长 / 报名时间" min-width="200">
          <template #default="{ row }">
            <div class="cell-strong">
              {{ row.balances?.[0]?.parent?.nickname || "-" }}
              <span class="cell-sub">{{ row.balances?.[0]?.parent?.phone || "" }}</span>
            </div>
            <div class="cell-sub">
              报名：{{ (row.balances?.map((b) => b.order_created_at).filter(Boolean).sort().shift() || "").slice(0, 10) || "-" }}
            </div>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="140" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openDetail(row)">详情</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && students.length === 0" class="empty-tip">暂无学员</div>
    </el-card>

    <!-- 学员详情 -->
    <el-drawer v-model="drawerOpen" :title="`学员详情 · ${current?.nickname || ''}`" size="520px">
      <template v-if="current">
        <div class="student-info-card">
          <div class="info-row">
            <span class="info-label">家长</span>
            <span>{{ current.balances?.[0]?.parent?.nickname || "-" }}
              <span class="cell-sub">{{ current.balances?.[0]?.parent?.phone || "" }}</span>
            </span>
          </div>
          <div class="info-row">
            <span class="info-label">学员</span>
            <span>{{ current.nickname }} · {{ genderText(current.gender) }} · {{ current.birthday || "未填生日" }}</span>
          </div>
          <div class="info-row">
            <span class="info-label">报名时间</span>
            <span>{{ (current.balances?.map((b) => b.order_created_at).filter(Boolean).sort().shift() || "").slice(0, 10) || "-" }}</span>
          </div>
        </div>
        <el-table :data="current.balances" size="small">
          <el-table-column prop="course_title" label="课程" min-width="140" />
          <el-table-column prop="remaining_lessons" label="剩余" width="70" align="center" />
          <el-table-column prop="consumed_lessons" label="已消耗" width="80" align="center" />
          <el-table-column label="有效期" min-width="120">
            <template #default="{ row }">{{ row.valid_from || "-" }} ~ {{ row.valid_to || "-" }}</template>
          </el-table-column>
        </el-table>

        <div class="log-section">
          <div class="log-head">
            <div class="log-title">课时流水</div>
            <el-select
              v-model="logCourseFilter"
              placeholder="全部课程"
              clearable
              size="small"
              style="width: 160px"
              @change="changeLogCourse"
            >
              <el-option
                v-for="b in current.balances"
                :key="b.course_id"
                :label="b.course_title"
                :value="b.course_id"
              />
            </el-select>
          </div>
          <el-table v-loading="logsLoading" :data="logs" size="small" empty-text="暂无消课记录">
            <el-table-column label="日期" width="100">
              <template #default="{ row }">
                {{ row.lesson_date || "-" }}
                <div v-if="row.start_time" class="cell-sub">{{ row.start_time }}~{{ row.end_time }}</div>
              </template>
            </el-table-column>
            <el-table-column prop="course_title" label="课程" min-width="130" />
            <el-table-column label="变动" width="80" align="center">
              <template #default="{ row }">
                <span class="consume-delta">{{ row.delta }} 节</span>
              </template>
            </el-table-column>
            <el-table-column label="剩余" width="70" align="center">
              <template #default="{ row }">{{ row.balance_after }}</template>
            </el-table-column>
            <el-table-column label="来源" width="100">
              <template #default="{ row }">{{ sourceText(row.source) }}</template>
            </el-table-column>
            <el-table-column prop="note" label="备注" min-width="100" show-overflow-tooltip>
              <template #default="{ row }">{{ row.note || "-" }}</template>
            </el-table-column>
          </el-table>
        </div>
      </template>
    </el-drawer>

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

.toolbar-left {
  display: flex;
  align-items: center;
  gap: 10px;
}

.student-info-card {
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 8px;
  padding: 12px 16px;
  margin-bottom: 14px;
}

.info-row {
  display: flex;
  gap: 12px;
  line-height: 26px;
  font-size: 13px;
}

.info-label {
  color: #8a8378;
  width: 64px;
  flex-shrink: 0;
}

.cell-strong {
  font-weight: 600;
  color: #2b2621;
}

.cell-sub {
  font-size: 12px;
  color: #9c9385;
}

.zero-cell {
  color: #c15f2c;
  font-weight: 600;
}

.empty-tip {
  padding: 32px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
}

.consume-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 14px 0;
  font-size: 14px;
  color: #2b2621;
}

.log-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}

.log-section {
  margin-top: 20px;
}

.log-title {
  font-weight: 600;
  color: #2b2621;
  margin-bottom: 10px;
}

.consume-delta {
  color: #c15f2c;
  font-weight: 600;
}
</style>

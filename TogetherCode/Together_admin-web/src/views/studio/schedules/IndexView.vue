<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { Plus } from "@element-plus/icons-vue";
import {
  fetchStudioSchedules,
  fetchStudioClasses,
  createStudioSchedule,
  fetchClassStudents,
  submitScheduleAttendance,
  type ScheduleItem,
  type ClassStudent
} from "../../../services/studio";
import { useAuthStore } from "../../../stores/auth";

const authStore = useAuthStore();
const studioId = computed(() => authStore.account?.studio_id || "");

const loading = ref(false);
const schedules = ref<ScheduleItem[]>([]);
const weekStart = ref(getMonday(new Date()));

const WEEK_LABELS = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"];

function getMonday(date: Date): string {
  const d = new Date(date);
  const day = d.getDay() || 7;
  d.setDate(d.getDate() - day + 1);
  return formatDate(d);
}

function formatDate(date: Date): string {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, "0");
  const d = String(date.getDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

function addDays(dateStr: string, days: number): string {
  const d = new Date(`${dateStr}T00:00:00`);
  d.setDate(d.getDate() + days);
  return formatDate(d);
}

const weekDays = computed(() =>
  Array.from({ length: 7 }, (_, i) => {
    const date = addDays(weekStart.value, i);
    const today = formatDate(new Date());
    return { date, label: WEEK_LABELS[i], isToday: date === today };
  })
);

const weekRangeText = computed(() => `${weekStart.value} ~ ${addDays(weekStart.value, 6)}`);

function prevWeek() {
  weekStart.value = addDays(weekStart.value, -7);
  loadData();
}

function nextWeek() {
  weekStart.value = addDays(weekStart.value, 7);
  loadData();
}

function thisWeek() {
  weekStart.value = getMonday(new Date());
  loadData();
}

function schedulesOf(date: string): ScheduleItem[] {
  return schedules.value.filter((item) => item.lesson_date === date);
}

async function loadData() {
  loading.value = true;
  try {
    schedules.value = (
      await fetchStudioSchedules({ studio_id: studioId.value, week: weekStart.value })
    ).list;
  } catch {
    // 忽略
  } finally {
    loading.value = false;
  }
}

// ============ 新增排课 ============
const createVisible = ref(false);
const submitting = ref(false);
const classes = ref<{ class_id: string; name: string }[]>([]);
const form = ref({
  studio_id: "",
  class_id: "",
  lesson_date: "",
  start_time: "18:30",
  end_time: "20:00",
  location: "",
  remark: ""
});

async function openCreate(date?: string) {
  form.value = {
    studio_id: studioId.value,
    class_id: "",
    lesson_date: date || weekDays.value.find((d) => d.isToday)?.date || weekStart.value,
    start_time: "18:30",
    end_time: "20:00",
    location: "",
    remark: ""
  };
  try {
    classes.value = (await fetchStudioClasses({ studio_id: studioId.value })).list;
  } catch {
    classes.value = [];
  }
  createVisible.value = true;
}

async function submitCreate() {
  if (!form.value.class_id) {
    ElMessage.warning("请选择班级");
    return;
  }
  if (!form.value.lesson_date) {
    ElMessage.warning("请选择上课日期");
    return;
  }
  submitting.value = true;
  try {
    await createStudioSchedule({
      studio_id: studioId.value,
      class_id: form.value.class_id,
      lesson_date: form.value.lesson_date,
      start_time: form.value.start_time,
      end_time: form.value.end_time,
      location: form.value.location || undefined,
      remark: form.value.remark || undefined
    });
    ElMessage.success("排课成功");
    createVisible.value = false;
    loadData();
  } catch {
    // 忽略
  } finally {
    submitting.value = false;
  }
}

// ============ 出勤消课 ============
const attendanceVisible = ref(false);
const attendanceSchedule = ref<ScheduleItem | null>(null);
const attendanceStudents = ref<ClassStudent[]>([]);
const attendanceSelections = ref<Record<string, number>>({});
const attendanceLoading = ref(false);
const attendanceSubmitting = ref(false);
const attendanceNote = ref("");

async function openAttendance(row: ScheduleItem) {
  attendanceVisible.value = true;
  attendanceLoading.value = true;
  attendanceSchedule.value = row;
  attendanceStudents.value = [];
  attendanceSelections.value = {};
  attendanceNote.value = "";
  try {
    const data = await fetchClassStudents(row.class_id);
    attendanceStudents.value = data.students;
  } catch {
    attendanceVisible.value = false;
  } finally {
    attendanceLoading.value = false;
  }
}

async function submitAttendance() {
  const selected = attendanceStudents.value.filter((s) => attendanceSelections.value[s.child_id]);
  if (selected.length === 0) {
    ElMessage.warning("请选择出勤学员");
    return;
  }
  attendanceSubmitting.value = true;
  try {
    await submitScheduleAttendance(
      attendanceSchedule.value!.schedule_id,
      selected.map((s) => ({
        child_id: s.child_id,
        order_id: s.order_id,
        status: attendanceSelections.value[s.child_id]
      })),
      attendanceNote.value.trim() || undefined
    );
    ElMessage.success(`已提交 ${selected.length} 名学员出勤并消课`);
    attendanceVisible.value = false;
    loadData();
  } catch {
    // 忽略
  } finally {
    attendanceSubmitting.value = false;
  }
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <div class="toolbar-left">
            <el-button-group>
              <el-button @click="prevWeek">上一周</el-button>
              <el-button @click="thisWeek">本周</el-button>
              <el-button @click="nextWeek">下一周</el-button>
            </el-button-group>
            <span class="week-range">{{ weekRangeText }}</span>
          </div>
          <el-button type="primary" :icon="Plus" @click="openCreate()">新增排课</el-button>
        </div>
      </template>

      <div class="week-grid">
        <div v-for="day in weekDays" :key="day.date" class="day-column">
          <div class="day-head" :class="{ today: day.isToday }">
            <span class="day-label">{{ day.label }}</span>
            <span class="day-date">{{ day.date.slice(5) }}</span>
          </div>
          <div class="day-body">
            <div
              v-for="item in schedulesOf(day.date)"
              :key="item.schedule_id"
              class="schedule-card"
            >
              <div class="schedule-time">{{ item.start_time }}-{{ item.end_time }}</div>
              <div class="schedule-title">{{ item.class?.name || "-" }}</div>
              <div class="schedule-sub">{{ item.course?.title || "" }}</div>
              <div class="schedule-actions">
                <el-button text size="small" type="primary" @click="openAttendance(item)">
                  出勤消课
                </el-button>
              </div>
            </div>
            <div v-if="schedulesOf(day.date).length === 0" class="day-empty">无排课</div>
          </div>
        </div>
      </div>
    </el-card>

    <!-- 新增排课 -->
    <el-dialog v-model="createVisible" title="新增排课" width="500px">
      <el-form label-width="100px">
        <el-form-item label="班级" required>
          <el-select v-model="form.class_id" style="width: 100%" placeholder="选择班级">
            <el-option
              v-for="item in classes"
              :key="item.class_id"
              :label="item.name"
              :value="item.class_id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="上课日期" required>
          <el-date-picker v-model="form.lesson_date" type="date" value-format="YYYY-MM-DD" style="width: 180px" />
        </el-form-item>
        <el-form-item label="时间" required>
          <el-time-select v-model="form.start_time" start="08:00" step="00:30" end="21:00" style="width: 130px" />
          ~
          <el-time-select v-model="form.end_time" start="08:00" step="00:30" end="22:00" style="width: 130px" />
        </el-form-item>
        <el-form-item label="上课地点">
          <el-input v-model="form.location" placeholder="如：3 号教室" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="form.remark" type="textarea" :rows="2" maxlength="255" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitCreate">确认排课</el-button>
      </template>
    </el-dialog>

    <!-- 出勤消课 -->
    <el-dialog
      v-model="attendanceVisible"
      :title="`出勤消课 · ${attendanceSchedule?.class?.name || ''}（${attendanceSchedule?.lesson_date || ''}）`"
      width="560px"
    >
      <div v-loading="attendanceLoading">
        <div v-if="attendanceStudents.length === 0 && !attendanceLoading" class="empty-tip">
          该班级暂无学员，无法消课
        </div>
        <el-table :data="attendanceStudents" size="small">
          <el-table-column prop="nickname" label="学员" min-width="110" />
          <el-table-column prop="remaining_lessons" label="剩余课时" width="90" align="center" />
          <el-table-column label="出勤状态" width="200">
            <template #default="{ row }">
              <el-radio-group
                v-model="attendanceSelections[row.child_id]"
                size="small"
                @change="attendanceSelections[row.child_id] = $event"
              >
                <el-radio-button :value="1">正常</el-radio-button>
                <el-radio-button :value="2">迟到</el-radio-button>
                <el-radio-button :value="3">请假</el-radio-button>
              </el-radio-group>
            </template>
          </el-table-column>
        </el-table>
        <el-input
          v-model="attendanceNote"
          class="note-input"
          placeholder="备注（选填）"
          maxlength="255"
        />
      </div>
      <template #footer>
        <el-button @click="attendanceVisible = false">取消</el-button>
        <el-button type="primary" :loading="attendanceSubmitting" @click="submitAttendance">
          提交出勤并消课
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

.toolbar-left {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.week-range {
  font-size: 13px;
  color: #726a60;
}

.week-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 10px;
}

.day-column {
  background: #faf7f1;
  border: 1px solid #eee7dd;
  border-radius: 12px;
  overflow: hidden;
  min-height: 200px;
}

.day-head {
  padding: 10px 12px;
  background: #f4efe6;
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.day-head.today {
  background: #2f5d45;
  color: #f5f0e6;
}

.day-label {
  font-size: 13px;
  font-weight: 600;
}

.day-date {
  font-size: 11px;
  color: #9c9385;
}

.day-head.today .day-date {
  color: #d8e4d2;
}

.day-body {
  padding: 8px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.schedule-card {
  background: #fff;
  border: 1px solid #e6dfd3;
  border-radius: 10px;
  padding: 10px;
}

.schedule-time {
  font-size: 12px;
  font-weight: 700;
  color: #2f5d45;
}

.schedule-title {
  font-size: 13px;
  font-weight: 600;
  color: #2b2621;
  margin-top: 4px;
}

.schedule-sub {
  font-size: 11px;
  color: #9c9385;
  margin-top: 2px;
}

.schedule-actions {
  margin-top: 6px;
}

.day-empty {
  padding: 24px 0;
  text-align: center;
  font-size: 12px;
  color: #c9c0b0;
}

.empty-tip {
  padding: 24px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
}

.note-input {
  margin-top: 12px;
}

@media (max-width: 1200px) {
  .week-grid {
    grid-template-columns: repeat(4, 1fr);
  }
}

@media (max-width: 800px) {
  .week-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}
</style>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { Plus } from "@element-plus/icons-vue";
import {
  fetchStudioSchedules,
  fetchStudioClasses,
  createStudioSchedule,
  batchCreateStudioSchedules,
  fetchStudioTeachers,
  fetchClassStudents,
  submitScheduleAttendance,
  type ScheduleItem,
  type ClassStudent,
  type TeacherStaffItem
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
const classes = ref<{ class_id: string; name: string; teacher_id: string | null; schedule_rule: { weekday: number[]; time: string } | null }[]>([]);
const teachers = ref<TeacherStaffItem[]>([]);
const form = ref({
  studio_id: "",
  class_id: "",
  teacher_id: "",
  teacher_name: "",
  lesson_date: "",
  start_time: "18:30",
  end_time: "20:00",
  location: "",
  remark: ""
});

function applyClassTeacher(target: "form" | "batch") {
  const model = target === "form" ? form.value : batchForm.value;
  const cls = classes.value.find((c) => c.class_id === model.class_id);
  const teacher = teachers.value.find((t) => t.teacher_id === cls?.teacher_id);
  // 排课老师固定为班级授课老师，不可更换
  model.teacher_id = teacher?.teacher_id || cls?.teacher_id || "";
  model.teacher_name = teacher?.real_name || "";
  // 自动带入班级上课时段
  const ruleTime = cls?.schedule_rule?.time;
  if (ruleTime && ruleTime.includes("-")) {
    const [start, end] = ruleTime.split("-");
    if (start && end) {
      model.start_time = start.trim();
      model.end_time = end.trim();
    }
  }
}

async function openCreate(date?: string) {
  form.value = {
    studio_id: studioId.value,
    class_id: "",
    teacher_id: "",
    teacher_name: "",
    lesson_date: date || weekDays.value.find((d) => d.isToday)?.date || weekStart.value,
    start_time: "18:30",
    end_time: "20:00",
    location: "",
    remark: ""
  };
  try {
    const [classData, teacherData] = await Promise.all([
      fetchStudioClasses({ studio_id: studioId.value }),
      fetchStudioTeachers()
    ]);
    classes.value = classData.list;
    teachers.value = teacherData.staff;
  } catch {
    classes.value = [];
    teachers.value = [];
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

// ============ 批量排课 ============
const batchVisible = ref(false);
const batchSubmitting = ref(false);
const batchForm = ref({
  class_id: "",
  teacher_id: "",
  teacher_name: "",
  start_time: "18:30",
  end_time: "20:00",
  location: "",
  remark: "",
  mode: "dates" as "dates" | "weekly",
  dates: [] as string[],
  weekdays: [] as number[],
  start_date: "",
  end_date: ""
});

const WEEK_OPTIONS = [
  { value: 1, label: "周一" },
  { value: 2, label: "周二" },
  { value: 3, label: "周三" },
  { value: 4, label: "周四" },
  { value: 5, label: "周五" },
  { value: 6, label: "周六" },
  { value: 7, label: "周日" }
];

async function openBatch() {
  batchForm.value = {
    class_id: "",
    teacher_id: "",
    teacher_name: "",
    start_time: "18:30",
    end_time: "20:00",
    location: "",
    remark: "",
    mode: "dates",
    dates: [],
    weekdays: [],
    start_date: "",
    end_date: ""
  };
  try {
    const [classData, teacherData] = await Promise.all([
      fetchStudioClasses({ studio_id: studioId.value }),
      fetchStudioTeachers()
    ]);
    classes.value = classData.list;
    teachers.value = teacherData.staff;
  } catch {
    classes.value = [];
    teachers.value = [];
  }
  batchVisible.value = true;
}

async function submitBatch() {
  if (!batchForm.value.class_id) {
    ElMessage.warning("请选择班级");
    return;
  }
  const payload: Record<string, unknown> = {
    studio_id: studioId.value,
    class_id: batchForm.value.class_id,
    start_time: batchForm.value.start_time,
    end_time: batchForm.value.end_time,
    location: batchForm.value.location || undefined,
    remark: batchForm.value.remark || undefined
  };
  if (batchForm.value.mode === "dates") {
    if (!batchForm.value.dates.length) {
      ElMessage.warning("请选择上课日期");
      return;
    }
    payload.dates = batchForm.value.dates;
  } else {
    if (!batchForm.value.weekdays.length) {
      ElMessage.warning("请选择每周几上课");
      return;
    }
    if (!batchForm.value.start_date || !batchForm.value.end_date) {
      ElMessage.warning("请选择起止日期");
      return;
    }
    payload.weekdays = batchForm.value.weekdays;
    payload.start_date = batchForm.value.start_date;
    payload.end_date = batchForm.value.end_date;
  }
  batchSubmitting.value = true;
  try {
    const result = await batchCreateStudioSchedules(payload as never);
    ElMessage.success(
      result.created > 0
        ? `已生成 ${result.created} 条排课${result.skipped > 0 ? `，跳过 ${result.skipped} 条冲突` : ""}`
        : "没有可生成的排课（日期冲突或已存在）"
    );
    batchVisible.value = false;
    loadData();
  } catch {
    // 忽略
  } finally {
    batchSubmitting.value = false;
  }
}

// ============ 出勤消课 ============
const attendanceVisible = ref(false);
const attendanceSchedule = ref<ScheduleItem | null>(null);
const attendanceStudents = ref<ClassStudent[]>([]);
const attendanceSelections = ref<Record<string, number | undefined>>({});
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
    const data = await fetchClassStudents(row.class_id, row.schedule_id);
    attendanceStudents.value = data.list;
    // 回显：不做预置，已消课学生默认保持已消；老师按需勾选「消课」或点「撤销消课」
    attendanceSelections.value = {};
  } catch {
    attendanceVisible.value = false;
  } finally {
    attendanceLoading.value = false;
  }
}

async function submitAttendance() {
  const selected = attendanceStudents.value.filter((s) => [1, 4].includes(attendanceSelections.value[s.child_id]));
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
    ElMessage.success(`已处理 ${selected.length} 名学员消课`);
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
          <div class="toolbar-actions">
            <el-button :icon="Plus" @click="openCreate()">新增排课</el-button>
            <el-button type="primary" :icon="Plus" @click="openBatch()">批量排课</el-button>
          </div>
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
              <div class="schedule-teacher" v-if="item.teacher">
                老师：{{ item.teacher.real_name }}
              </div>
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
          <el-select v-model="form.class_id" style="width: 100%" placeholder="选择班级" @change="applyClassTeacher('form')">
            <el-option
              v-for="item in classes"
              :key="item.class_id"
              :label="item.name"
              :value="item.class_id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="授课老师">
          <el-input
            v-model="form.teacher_name"
            placeholder="选择班级后自动带出（不可更换）"
            disabled
            style="width: 100%"
          />
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

    <!-- 批量排课 -->
    <el-dialog v-model="batchVisible" title="批量排课" width="560px">
      <el-form label-width="100px">
        <el-form-item label="班级" required>
          <el-select v-model="batchForm.class_id" style="width: 100%" placeholder="选择班级" @change="applyClassTeacher('batch')">
            <el-option
              v-for="item in classes"
              :key="item.class_id"
              :label="item.name"
              :value="item.class_id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="授课老师">
          <el-input
            v-model="batchForm.teacher_name"
            placeholder="选择班级后自动带出（不可更换）"
            disabled
            style="width: 100%"
          />
        </el-form-item>
        <el-form-item label="时间" required>
          <el-time-select v-model="batchForm.start_time" start="08:00" step="00:30" end="21:00" style="width: 130px" />
          ~
          <el-time-select v-model="batchForm.end_time" start="08:00" step="00:30" end="22:00" style="width: 130px" />
        </el-form-item>
        <el-form-item label="排课方式" required>
          <el-radio-group v-model="batchForm.mode">
            <el-radio-button value="dates">选择日期</el-radio-button>
            <el-radio-button value="weekly">每周固定</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item v-if="batchForm.mode === 'dates'" label="上课日期" required>
          <el-date-picker
            v-model="batchForm.dates"
            type="dates"
            value-format="YYYY-MM-DD"
            style="width: 100%"
            placeholder="可多选日期"
          />
        </el-form-item>
        <template v-else>
          <el-form-item label="每周" required>
            <el-checkbox-group v-model="batchForm.weekdays">
              <el-checkbox v-for="w in WEEK_OPTIONS" :key="w.value" :value="w.value">
                {{ w.label }}
              </el-checkbox>
            </el-checkbox-group>
          </el-form-item>
          <el-form-item label="起止日期" required>
            <el-date-picker
              v-model="batchForm.start_date"
              type="date"
              value-format="YYYY-MM-DD"
              style="width: 160px"
              placeholder="开始"
            />
            ~
            <el-date-picker
              v-model="batchForm.end_date"
              type="date"
              value-format="YYYY-MM-DD"
              style="width: 160px"
              placeholder="结束"
            />
          </el-form-item>
        </template>
        <el-form-item label="上课地点">
          <el-input v-model="batchForm.location" placeholder="如：3 号教室" />
        </el-form-item>
        <el-form-item label="备注">
          <el-input v-model="batchForm.remark" type="textarea" :rows="2" maxlength="255" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="batchVisible = false">取消</el-button>
        <el-button type="primary" :loading="batchSubmitting" @click="submitBatch">
          生成排课
        </el-button>
      </template>
    </el-dialog>

    <!-- 出勤消课 -->
    <el-dialog
      v-model="attendanceVisible"
      :title="`出勤消课 · ${attendanceSchedule?.class?.name || ''}（${attendanceSchedule?.lesson_date || ''}）`"
      width="660px"
    >
      <div v-loading="attendanceLoading">
        <div v-if="attendanceStudents.length === 0 && !attendanceLoading" class="empty-tip">
          该班级暂无学员，无法消课
        </div>
        <el-table :data="attendanceStudents" size="small">
          <el-table-column prop="nickname" label="学员" min-width="110" />
          <el-table-column label="请假" width="110" align="center">
            <template #default="{ row }">
              <el-tag v-if="row.leave_status === 2" type="warning" size="small" effect="light">已请假</el-tag>
              <el-tag v-else-if="row.leave_status === 1" type="danger" size="small" effect="light">待审批</el-tag>
              <el-tag v-else-if="row.leave_status === 3" type="info" size="small" effect="light">已婉拒</el-tag>
              <span v-else>-</span>
            </template>
          </el-table-column>
          <el-table-column prop="remaining_lessons" label="剩余课时" width="90" align="center" />
          <el-table-column label="状态" width="100" align="center">
            <template #default="{ row }">
              <el-tag :type="row.consumed ? 'success' : 'info'" size="small" effect="light">
                {{ row.consumed ? "已消课" : "未消课" }}
              </el-tag>
            </template>
          </el-table-column>
          <el-table-column label="消课操作" width="190" align="center">
            <template #default="{ row }">
              <template v-if="attendanceSelections[row.child_id] === 4">
                <el-button link type="primary" size="small" @click="attendanceSelections[row.child_id] = undefined">
                  恢复
                </el-button>
                <span class="op-tag">将撤销</span>
              </template>
              <template v-else-if="row.consumed">
                <el-button link type="danger" size="small" @click="attendanceSelections[row.child_id] = 4">
                  撤销消课
                </el-button>
              </template>
              <template v-else>
                <el-checkbox
                  :model-value="attendanceSelections[row.child_id] === 1"
                  :disabled="row.leave_status === 2"
                  @change="attendanceSelections[row.child_id] = $event ? 1 : undefined"
                >
                  {{ row.leave_status === 2 ? "已请假不消" : "消课" }}
                </el-checkbox>
              </template>
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

.op-tag {
  font-size: 12px;
  color: #b76e2a;
  margin-left: 6px;
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

.schedule-teacher {
  font-size: 11px;
  color: #2f5d45;
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

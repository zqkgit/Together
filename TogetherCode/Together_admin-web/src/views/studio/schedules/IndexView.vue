<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { ElMessageBox } from "element-plus";
import { Plus } from "@element-plus/icons-vue";
import {
  fetchStudioSchedules,
  fetchStudioClasses,
  createStudioSchedule,
  updateStudioSchedule,
  deleteStudioSchedule,
  batchCreateStudioSchedules,
  fetchStudioTeachers,
  fetchStudioCourses,
  fetchClassStudents,
  submitScheduleAttendance,
  reviewStudioLeave,
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
const classes = ref<{ class_id: string; course_id: string; name: string; teacher_id: string | null; schedule_rule: { weekday: number[]; time: string } | null }[]>([]);
const teachers = ref<TeacherStaffItem[]>([]);
const courseLessonsMap = ref<Record<string, { lesson_no: number; title: string }[]>>({});
const form = ref({
  studio_id: "",
  class_id: "",
  teacher_id: "",
  teacher_name: "",
  lesson_date: "",
  start_time: "18:30",
  end_time: "20:00",
  location: "",
  lesson_no: 1,
  remark: ""
});

function applyClassTeacher(target: "form" | "batch") {
  const model = target === "form" ? form.value : batchForm.value;
  const cls = classes.value.find((c) => c.class_id === model.class_id);
  const teacher = teachers.value.find((t) => t.teacher_id === cls?.teacher_id);
  // 排课老师固定为班级授课老师，不可更换
  model.teacher_id = teacher?.teacher_id || cls?.teacher_id || "";
  model.teacher_name = teacher?.real_name || "";
  // 默认第 1 节课，自动带出对应课时标题
  model.lesson_no = 1;
  model.remark = courseLessonsMap.value[cls?.course_id || ""]?.[0]?.title || "";
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

// 模拟后端 expandDates：根据 weekdays + start_date + class end_date 计算展开日期数
function expandWeeklyDates(weekdays: number[], startDate: string, endDate: string): string[] {
  const dates: string[] = [];
  const wdSet = new Set(weekdays.map(w => Number(w)));
  const cursor = new Date(`${startDate}T00:00:00`);
  const end = new Date(`${endDate}T00:00:00`);
  while (cursor <= end) {
    let wd = cursor.getDay(); // 0=周日
    if (wd === 0) wd = 7;
    if (wdSet.has(wd)) {
      dates.push(formatDate(cursor));
    }
    cursor.setDate(cursor.getDate() + 1);
  }
  return dates;
}

// 当前班级课程的总课次数（无课时标题时按课时数兜底）
function currentLessonCount(classId: string): number {
  const cls = classes.value.find((c) => c.class_id === classId);
  const lessons = courseLessonsMap.value[cls?.course_id || ""];
  if (lessons?.length) return lessons.length;
  // 列表课程没带 lessons 时用班级课程时长兜底：默认 24
  return 24;
}

// 当前班级已排课的课次集合（用于排课时过滤已排课次）
function scheduledLessonNos(classId: string): Set<number> {
  const set = new Set<number>();
  for (const s of schedules.value) {
    if (s.class_id === classId && s.remark) {
      const m = s.remark.match(/^第(\d+)课/);
      if (m) set.add(Number(m[1]));
    }
  }
  return set;
}

function lessonTitleOf(classId: string, no: number): string {
  const cls = classes.value.find((c) => c.class_id === classId);
  return courseLessonsMap.value[cls?.course_id || ""]?.find((l) => l.lesson_no === no)?.title || "";
}

function onLessonNoChange(target: "form" | "batch") {
  const model = target === "form" ? form.value : batchForm.value;
  const cls = classes.value.find((c) => c.class_id === model.class_id);
  const title = courseLessonsMap.value[cls?.course_id || ""]?.find((l) => l.lesson_no === model.lesson_no)?.title;
  if (title) {
    model.remark = title;
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
    lesson_no: 1,
    remark: ""
  };
  try {
    const [classData, teacherData, courseData] = await Promise.all([
      fetchStudioClasses({ studio_id: studioId.value }),
      fetchStudioTeachers(),
      fetchStudioCourses({ studio_id: studioId.value })
    ]);
    classes.value = classData.list;
    teachers.value = teacherData.staff;
    courseLessonsMap.value = Object.fromEntries(
      courseData.map((c) => [c.course_id, (c.lessons || []).sort((a, b) => a.lesson_no - b.lesson_no)])
    );
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

// ============ 编辑排课 ============
const editVisible = ref(false);
const editSubmitting = ref(false);
const editForm = ref({
  schedule_id: "",
  class_name: "",
  course_title: "",
  teacher_id: "",
  teacher_name: "",
  lesson_date: "",
  start_time: "18:30",
  end_time: "20:00",
  location: "",
  remark: "",
  started: false,
  consumed: false
});

async function openEdit(item: ScheduleItem) {
  const now = new Date();
  const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
  const isStarted = item.lesson_date < today || (item.lesson_date === today && item.start_time <= `${String(now.getHours()).padStart(2, "0")}:${String(now.getMinutes()).padStart(2, "0")}`);
  editForm.value = {
    schedule_id: item.schedule_id,
    class_name: item.class?.name || "-",
    course_title: item.course?.title || "",
    teacher_id: item.teacher_id || "",
    teacher_name: item.teacher?.real_name || "",
    lesson_date: item.lesson_date,
    start_time: item.start_time,
    end_time: item.end_time,
    location: item.location || "",
    remark: item.remark || "",
    started: isStarted,
    consumed: item.status !== 0
  };
  // 加载老师列表供选择
  try {
    const data = await fetchStudioTeachers();
    teachers.value = data.staff;
  } catch {
    teachers.value = [];
  }
  editVisible.value = true;
}

async function submitEdit() {
  if (!editForm.value.lesson_date) {
    ElMessage.warning("请选择上课日期");
    return;
  }
  editSubmitting.value = true;
  try {
    await updateStudioSchedule(editForm.value.schedule_id, {
      lesson_date: editForm.value.lesson_date,
      start_time: editForm.value.start_time,
      end_time: editForm.value.end_time,
      location: editForm.value.location || undefined,
      teacher_id: editForm.value.teacher_id || undefined,
      remark: editForm.value.remark || undefined
    });
    ElMessage.success("排课已更新");
    editVisible.value = false;
    loadData();
  } catch {
    // 拦截器已提示
  } finally {
    editSubmitting.value = false;
  }
}

async function handleDelete(item: ScheduleItem) {
  if (item.status !== 0) {
    ElMessage.warning("已消课排课不允许删除");
    return;
  }
  try {
    await ElMessageBox.confirm(
      `确认删除 ${item.lesson_date} ${item.start_time || ""}-${item.end_time || ""} 的排课？`,
      "删除排课",
      { confirmButtonText: "删除", cancelButtonText: "取消", type: "warning" }
    );
  } catch {
    return;
  }
  try {
    await deleteStudioSchedule(item.schedule_id);
    ElMessage.success("排课已删除");
    loadData();
  } catch {
    // 拦截器已提示
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
  lesson_no: 1,
  mode: "dates" as "dates" | "weekly",
  dates: [] as string[],
  weekdays: [] as number[],
  start_date: ""
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
    lesson_no: 1,
    mode: "dates",
    dates: [],
    weekdays: [],
    start_date: ""
  };
  try {
    const [classData, teacherData, courseData] = await Promise.all([
      fetchStudioClasses({ studio_id: studioId.value }),
      fetchStudioTeachers(),
      fetchStudioCourses({ studio_id: studioId.value })
    ]);
    classes.value = classData.list;
    teachers.value = teacherData.staff;
    courseLessonsMap.value = Object.fromEntries(
      courseData.map((c) => [c.course_id, (c.lessons || []).sort((a, b) => a.lesson_no - b.lesson_no)])
    );
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
  const maxLessons = currentLessonCount(batchForm.value.class_id);
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
    if (batchForm.value.dates.length > maxLessons) {
      ElMessage.warning(`所选日期数（${batchForm.value.dates.length}）超过课程总课时数（${maxLessons}）`);
      return;
    }
    payload.dates = batchForm.value.dates;
  } else {
    if (!batchForm.value.weekdays.length) {
      ElMessage.warning("请选择每周几上课");
      return;
    }
    if (!batchForm.value.start_date) {
      ElMessage.warning("请选择开始日期");
      return;
    }
    // weekly �模式：展开日期数校验
    const cls = classes.value.find((c) => c.class_id === batchForm.value.class_id);
    if (cls?.end_date) {
      const expandedDates = expandWeeklyDates(batchForm.value.weekdays, batchForm.value.start_date, String(cls.end_date).slice(0, 10));
      if (expandedDates.length > maxLessons) {
        ElMessage.warning(`每周固定展开日期数（${expandedDates.length}）超过课程总课时数（${maxLessons}）`);
        return;
      }
    }
    payload.weekdays = batchForm.value.weekdays;
    payload.start_date = batchForm.value.start_date;
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

// 请假审批弹框
const leaveReviewVisible = ref(false);
const leaveReviewStudent = ref<ClassStudent | null>(null);
const leaveReviewNote = ref("");
const leaveReviewSubmitting = ref(false);

function openLeaveReview(student: ClassStudent) {
  leaveReviewStudent.value = student;
  leaveReviewNote.value = "";
  leaveReviewVisible.value = true;
}

async function doLeaveReview(agree: boolean) {
  if (!leaveReviewStudent.value?.leave_id) return;
  leaveReviewSubmitting.value = true;
  try {
    await reviewStudioLeave(leaveReviewStudent.value.leave_id, {
      agree,
      note: leaveReviewNote.value.trim() || undefined
    });
    ElMessage.success(agree ? "已同意请假" : "已婉拒请假");
    leaveReviewVisible.value = false;
    // 刷新学生名单（请假状态变化）
    const data = await fetchClassStudents(
      attendanceSchedule.value!.class_id,
      attendanceSchedule.value!.schedule_id
    );
    attendanceStudents.value = data.list;
  } catch {
    // 拦截器提示
  } finally {
    leaveReviewSubmitting.value = false;
  }
}

async function submitAttendance() {
  const selected = attendanceStudents.value.filter((s) => {
    const v = attendanceSelections.value[s.child_id];
    return v === 1 || v === 4;
  });
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
        status: attendanceSelections.value[s.child_id]!
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
                <el-button text size="small" type="primary" @click="openEdit(item)">
                  编辑
                </el-button>
                <el-button v-if="item.status === 0" text size="small" type="danger" @click="handleDelete(item)">
                  删除
                </el-button>
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
        <el-form-item label="课次" required>
          <el-select
            v-model="form.lesson_no"
            style="width: 100%"
            placeholder="选择第几节课"
            :disabled="!form.class_id"
            @change="onLessonNoChange('form')"
          >
            <el-option
              v-for="i in currentLessonCount(form.class_id)"
              :key="i"
              :label="`第${i}课${lessonTitleOf(form.class_id, i) ? ' · ' + lessonTitleOf(form.class_id, i) : ''}`"
              :value="i"
              :disabled="scheduledLessonNos(form.class_id).has(i)"
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
        <el-form-item label="课时标题">
          <el-input v-model="form.remark" type="textarea" :rows="2" maxlength="255" placeholder="如：水彩第一课·认识三原色（家长端每节课显示此标题，不填显示第N课）" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitCreate">确认排课</el-button>
      </template>
    </el-dialog>

    <!-- 编辑排课 -->
    <el-dialog v-model="editVisible" title="编辑排课" width="500px">
      <el-alert v-if="editForm.consumed" type="warning" :closable="false" style="margin-bottom: 12px">已消课排课不可编辑</el-alert>
      <el-alert v-else-if="editForm.started" type="info" :closable="false" style="margin-bottom: 12px">已开始的排课仅可修改地点和课时标题</el-alert>
      <el-form label-width="100px">
        <el-form-item label="班级">
          <el-input :model-value="editForm.class_name" disabled style="width: 100%" />
        </el-form-item>
        <el-form-item label="课程">
          <el-input :model-value="editForm.course_title" disabled style="width: 100%" />
        </el-form-item>
        <el-form-item label="授课老师">
          <el-select v-model="editForm.teacher_id" style="width: 100%" placeholder="选择老师" clearable :disabled="editForm.consumed || editForm.started">
            <el-option
              v-for="t in teachers"
              :key="t.teacher_id"
              :label="t.real_name"
              :value="t.teacher_id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="上课日期" required>
          <el-date-picker v-model="editForm.lesson_date" type="date" value-format="YYYY-MM-DD" style="width: 180px" :disabled="editForm.consumed || editForm.started" />
        </el-form-item>
        <el-form-item label="时间" required>
          <el-time-select v-model="editForm.start_time" start="08:00" step="00:30" end="21:00" style="width: 130px" :disabled="editForm.consumed || editForm.started" />
          ~
          <el-time-select v-model="editForm.end_time" start="08:00" step="00:30" end="22:00" style="width: 130px" :disabled="editForm.consumed || editForm.started" />
        </el-form-item>
        <el-form-item label="上课地点">
          <el-input v-model="editForm.location" placeholder="如：3 号教室" :disabled="editForm.consumed" />
        </el-form-item>
        <el-form-item label="课时标题">
          <el-input v-model="editForm.remark" type="textarea" :rows="2" maxlength="255" placeholder="如：水彩第一课·认识三原色（家长端每节课显示此标题，不填显示第N课）" :disabled="editForm.consumed" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editVisible = false">取消</el-button>
        <el-button type="primary" :loading="editSubmitting" :disabled="editForm.consumed" @click="submitEdit">保存修改</el-button>
      </template>
    </el-dialog>

    <!-- 请假审批 -->
    <el-dialog v-model="leaveReviewVisible" title="请假审批" width="440px">
      <div v-if="leaveReviewStudent" class="leave-review-info">
        <div class="leave-review-row">
          <span class="cell-sub">课程</span>
          <span class="cell-strong">{{ attendanceSchedule?.course?.title || "-" }}</span>
        </div>
        <div class="leave-review-row">
          <span class="cell-sub">班级</span>
          <span>{{ attendanceSchedule?.class?.name || "-" }}</span>
        </div>
        <div class="leave-review-row">
          <span class="cell-sub">学员</span>
          <span class="cell-strong">{{ leaveReviewStudent.nickname }}</span>
        </div>
        <div class="leave-review-row">
          <span class="cell-sub">上课日期</span>
          <span>{{ attendanceSchedule?.lesson_date }} {{ attendanceSchedule?.start_time }}-{{ attendanceSchedule?.end_time }}</span>
        </div>
        <div class="leave-review-row leave-review-reason">
          <span class="cell-sub">请假原因</span>
          <span>{{ leaveReviewStudent.leave_reason || "未填写" }}</span>
        </div>
        <el-input
          v-model="leaveReviewNote"
          type="textarea"
          :rows="2"
          maxlength="255"
          placeholder="审批备注（选填）"
          class="note-input"
        />
        <div class="leave-review-hint">同意后该学员此节课保留课时，出勤状态记为请假。</div>
      </div>
      <template #footer>
        <el-button :loading="leaveReviewSubmitting" @click="leaveReviewVisible = false">取消</el-button>
        <el-button
          type="danger"
          plain
          :loading="leaveReviewSubmitting"
          @click="doLeaveReview(false)"
        >
          婉拒
        </el-button>
        <el-button type="primary" :loading="leaveReviewSubmitting" @click="doLeaveReview(true)">
          同意请假
        </el-button>
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
        <el-form-item label="课次" required>
          <el-select
            v-model="batchForm.lesson_no"
            style="width: 100%"
            placeholder="选择第几节课"
            :disabled="!batchForm.class_id"
            @change="onLessonNoChange('batch')"
          >
            <el-option
              v-for="i in currentLessonCount(batchForm.class_id)"
              :key="i"
              :label="`第${i}课${lessonTitleOf(batchForm.class_id, i) ? ' · ' + lessonTitleOf(batchForm.class_id, i) : ''}`"
              :value="i"
              :disabled="scheduledLessonNos(batchForm.class_id).has(i)"
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
          <el-form-item label="开始日期" required>
            <el-date-picker
              v-model="batchForm.start_date"
              type="date"
              value-format="YYYY-MM-DD"
              style="width: 180px"
              placeholder="从哪天开始"
            />
            <span style="margin-left: 8px; color: #909399; font-size: 12px">结束日期取班级开课结束日期</span>
          </el-form-item>
        </template>
        <el-form-item label="上课地点">
          <el-input v-model="batchForm.location" placeholder="如：3 号教室" />
        </el-form-item>
        <el-form-item label="课时标题">
          <el-input v-model="batchForm.remark" type="textarea" :rows="2" maxlength="255" placeholder="批量排课的课时标题（家长端每节课显示此标题，不填显示第N课）" />
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
              <el-tag
                v-else-if="row.leave_status === 1"
                type="danger"
                size="small"
                effect="light"
                class="review-tag"
                @click="openLeaveReview(row)"
              >
                待审批
              </el-tag>
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

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { Plus, Refresh, Search } from "@element-plus/icons-vue";
import {
  fetchStudioClasses,
  fetchStudioCourses,
  createStudioClass,
  fetchClassStudents,
  type ClassItem,
  type ClassStudent
} from "../../../services/studio";
import { useAuthStore } from "../../../stores/auth";

const authStore = useAuthStore();
const studioId = computed(() => authStore.account?.studio_id || "");

const loading = ref(false);
const q = ref("");
const classes = ref<ClassItem[]>([]);
const courses = ref<{ course_id: string; title: string }[]>([]);

// 新建班级
const createVisible = ref(false);
const submitting = ref(false);
const form = ref({
  studio_id: "",
  course_id: "",
  name: "",
  weekday: 1,
  time: "18:30-20:00",
  start_date: "",
  end_date: "",
  capacity: 12
});

// 学生名单
const studentsVisible = ref(false);
const studentsLoading = ref(false);
const currentClass = ref<ClassItem | null>(null);
const students = ref<ClassStudent[]>([]);

const WEEKDAYS = [
  { value: 1, label: "周一" },
  { value: 2, label: "周二" },
  { value: 3, label: "周三" },
  { value: 4, label: "周四" },
  { value: 5, label: "周五" },
  { value: 6, label: "周六" },
  { value: 7, label: "周日" }
];

function weekdayText(rule: ClassItem["schedule_rule"]): string {
  if (!rule || !rule.weekday || !rule.time) return "-";
  const days = rule.weekday.map((d) => WEEKDAYS.find((w) => w.value === d)?.label || String(d)).join("、");
  return `${days} ${rule.time}`;
}

async function loadData() {
  loading.value = true;
  try {
    classes.value = (await fetchStudioClasses({ studio_id: studioId.value, q: q.value.trim() || undefined })).list;
  } catch {
    // 忽略
  } finally {
    loading.value = false;
  }
}

async function openCreate() {
  form.value = {
    studio_id: studioId.value,
    course_id: "",
    name: "",
    weekday: 1,
    time: "18:30-20:00",
    start_date: "",
    end_date: "",
    capacity: 12
  };
  try {
    courses.value = await fetchStudioCourses({ status: 1 });
  } catch {
    courses.value = [];
  }
  createVisible.value = true;
}

async function submitCreate() {
  if (!form.value.course_id) {
    ElMessage.warning("请选择所属课程");
    return;
  }
  if (!form.value.name.trim()) {
    ElMessage.warning("请填写班级名称");
    return;
  }
  submitting.value = true;
  try {
    await createStudioClass({
      studio_id: studioId.value,
      course_id: form.value.course_id,
      name: form.value.name.trim(),
      schedule_rule: { weekday: [form.value.weekday], time: form.value.time },
      start_date: form.value.start_date || undefined,
      end_date: form.value.end_date || undefined,
      capacity: form.value.capacity
    });
    ElMessage.success("班级创建成功");
    createVisible.value = false;
    loadData();
  } catch {
    // 忽略
  } finally {
    submitting.value = false;
  }
}

async function openStudents(row: ClassItem) {
  studentsVisible.value = true;
  studentsLoading.value = true;
  currentClass.value = row;
  students.value = [];
  try {
    const data = await fetchClassStudents(row.class_id);
    currentClass.value = data.class;
    students.value = data.students;
  } catch {
    studentsVisible.value = false;
  } finally {
    studentsLoading.value = false;
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
            <el-input
              v-model="q"
              placeholder="搜索班级名称"
              clearable
              style="width: 200px"
              :prefix-icon="Search"
              @keyup.enter="loadData"
              @clear="loadData"
            />
            <el-button :icon="Refresh" @click="loadData">查询</el-button>
          </div>
          <el-button type="primary" :icon="Plus" @click="openCreate">新建班级</el-button>
        </div>
      </template>

      <el-table :data="classes" row-key="class_id">
        <el-table-column prop="name" label="班级名称" min-width="180">
          <template #default="{ row }">
            <span class="cell-strong">{{ row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column label="所属课程" min-width="200">
          <template #default="{ row }">{{ row.course?.title || "-" }}</template>
        </el-table-column>
        <el-table-column label="上课时间" min-width="160">
          <template #default="{ row }">{{ weekdayText(row.schedule_rule) }}</template>
        </el-table-column>
        <el-table-column label="容量" width="140">
          <template #default="{ row }">
            <span :class="{ 'full-cell': row.enrolled >= row.capacity }">
              {{ row.enrolled }} / {{ row.capacity }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="160" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openStudents(row)">学生名单</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && classes.length === 0" class="empty-tip">暂无班级，点击右上角「新建班级」创建</div>
    </el-card>

    <!-- 新建班级 -->
    <el-dialog v-model="createVisible" title="新建班级" width="520px">
      <el-form label-width="100px">
        <el-form-item label="所属课程" required>
          <el-select v-model="form.course_id" style="width: 100%" placeholder="选择课程">
            <el-option
              v-for="course in courses"
              :key="course.course_id"
              :label="course.title"
              :value="course.course_id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="班级名称" required>
          <el-input v-model="form.name" placeholder="如：启蒙绘画周六班" />
        </el-form-item>
        <el-form-item label="上课日" required>
          <el-select v-model="form.weekday" style="width: 140px">
            <el-option
              v-for="day in WEEKDAYS"
              :key="day.value"
              :label="day.label"
              :value="day.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="上课时段" required>
          <el-input v-model="form.time" placeholder="18:30-20:00" style="width: 180px" />
        </el-form-item>
        <el-form-item label="开班日期">
          <el-date-picker v-model="form.start_date" type="date" value-format="YYYY-MM-DD" style="width: 180px" />
        </el-form-item>
        <el-form-item label="结课日期">
          <el-date-picker v-model="form.end_date" type="date" value-format="YYYY-MM-DD" style="width: 180px" />
        </el-form-item>
        <el-form-item label="班级容量">
          <el-input-number v-model="form.capacity" :min="1" :max="200" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitCreate">创建班级</el-button>
      </template>
    </el-dialog>

    <!-- 学生名单 -->
    <el-drawer v-model="studentsVisible" :title="`学生名单 · ${currentClass?.name || ''}`" size="480px">
      <div v-loading="studentsLoading">
        <el-table :data="students" size="small">
          <el-table-column prop="nickname" label="学员" min-width="120" />
          <el-table-column prop="remaining_lessons" label="剩余课时" width="90" align="center" />
          <el-table-column prop="consumed_lessons" label="已消耗" width="80" align="center" />
        </el-table>
        <div v-if="!studentsLoading && students.length === 0" class="empty-tip">该班级暂无学员</div>
      </div>
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

.cell-strong {
  font-weight: 600;
  color: #2b2621;
}

.full-cell {
  color: #c15f2c;
  font-weight: 600;
}

.empty-tip {
  padding: 32px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
}
</style>

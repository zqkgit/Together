<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { Plus, Refresh, Search } from "@element-plus/icons-vue";
import {
  fetchStudioClasses,
  fetchStudioCourses,
  fetchStudioTeachers,
  createStudioClass,
  updateStudioClass,
  fetchClassStudents,
  type ClassItem,
  type ClassStudent,
  type TeacherStaffItem
} from "../../../services/studio";
import { useAuthStore } from "../../../stores/auth";

const authStore = useAuthStore();
const studioId = computed(() => authStore.account?.studio_id || "");

const loading = ref(false);
const q = ref("");
const classes = ref<ClassItem[]>([]);
const courses = ref<{ course_id: string; title: string }[]>([]);
const teachers = ref<TeacherStaffItem[]>([]);

// 新建班级
const createVisible = ref(false);
const submitting = ref(false);
const editingId = ref("");
const form = ref({
  studio_id: "",
  course_id: "",
  teacher_id: "",
  name: "",
  start_time: "18:30",
  end_time: "20:00",
  capacity: 12
});

// 学生名单
const studentsVisible = ref(false);
const studentsLoading = ref(false);
const currentClass = ref<ClassItem | null>(null);
const students = ref<ClassStudent[]>([]);

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
  editingId.value = "";
  form.value = {
    studio_id: studioId.value,
    course_id: "",
    teacher_id: "",
    name: "",
    start_time: "18:30",
    end_time: "20:00",
    capacity: 12
  };
  try {
    const [courseData, teacherData] = await Promise.all([
      fetchStudioCourses({ studio_id: studioId.value, status: 1 }),
      fetchStudioTeachers()
    ]);
    courses.value = courseData;
    teachers.value = teacherData.staff;
  } catch {
    courses.value = [];
    teachers.value = [];
  }
  createVisible.value = true;
}

async function submitCreate() {
  if (!form.value.course_id) {
    ElMessage.warning("请选择所属课程");
    return;
  }
  if (!form.value.teacher_id) {
    ElMessage.warning("请选择授课老师");
    return;
  }
  if (!form.value.name.trim()) {
    ElMessage.warning("请填写班级名称");
    return;
  }
  submitting.value = true;
  try {
    if (editingId.value) {
      await updateStudioClass(editingId.value, {
        studio_id: studioId.value,
        teacher_id: form.value.teacher_id,
        name: form.value.name.trim(),
        time: `${form.value.start_time}-${form.value.end_time}`,
        capacity: form.value.capacity
      });
      ElMessage.success("班级已更新");
    } else {
      await createStudioClass({
        studio_id: studioId.value,
        course_id: form.value.course_id,
        teacher_id: form.value.teacher_id,
        name: form.value.name.trim(),
        schedule_rule: { weekday: [], time: `${form.value.start_time}-${form.value.end_time}` },
        capacity: form.value.capacity
      });
      ElMessage.success("班级创建成功");
    }
    createVisible.value = false;
    loadData();
  } catch {
    // 忽略
  } finally {
    submitting.value = false;
  }
}

async function openEdit(row: ClassItem) {
  editingId.value = row.class_id;
  const ruleTime = row.schedule_rule?.time || "";
  const [start, end] = ruleTime.includes("-") ? ruleTime.split("-") : ["18:30", "20:00"];
  form.value = {
    studio_id: studioId.value,
    course_id: row.course_id,
    teacher_id: row.teacher_id || "",
    name: row.name,
    start_time: start.trim(),
    end_time: end.trim(),
    capacity: row.capacity || 12
  };
  try {
    teachers.value = (await fetchStudioTeachers()).staff;
  } catch {
    teachers.value = [];
  }
  createVisible.value = true;
}

async function openStudents(row: ClassItem) {
  studentsVisible.value = true;
  studentsLoading.value = true;
  currentClass.value = row;
  students.value = [];
  try {
    const data = await fetchClassStudents(row.class_id);
    currentClass.value = data.class;
    students.value = data.list;
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
        <el-table-column label="授课老师" min-width="140">
          <template #default="{ row }">
            <span v-if="row.teacher?.real_name">{{ row.teacher.real_name }}</span>
            <span v-else class="cell-muted">未指定</span>
          </template>
        </el-table-column>
        <el-table-column label="上课时段" min-width="140">
          <template #default="{ row }">
            <span v-if="row.schedule_rule?.time">{{ row.schedule_rule.time }}</span>
            <span v-else class="cell-muted">未设置</span>
          </template>
        </el-table-column>
        <el-table-column label="容量" width="140">
          <template #default="{ row }">
            <span :class="{ 'full-cell': row.enrolled >= row.capacity }">
              {{ row.enrolled }} / {{ row.capacity }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button text type="primary" @click="openStudents(row)">学生名单</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && classes.length === 0" class="empty-tip">暂无班级，点击右上角「新建班级」创建</div>
    </el-card>

    <!-- 新建/编辑班级 -->
    <el-dialog v-model="createVisible" :title="editingId ? '编辑班级' : '新建班级'" width="520px">
      <el-form label-width="100px">
        <el-form-item label="所属课程" required>
          <el-select v-model="form.course_id" style="width: 100%" placeholder="选择课程" :disabled="!!editingId">
            <el-option
              v-for="course in courses"
              :key="course.course_id"
              :label="course.title"
              :value="course.course_id"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="授课老师" required>
          <el-select v-model="form.teacher_id" style="width: 100%" placeholder="选择授课老师">
            <el-option
              v-for="teacher in teachers"
              :key="teacher.teacher_id"
              :label="teacher.real_name"
              :value="teacher.teacher_id"
            >
              <span>{{ teacher.real_name }}</span>
              <span class="cell-muted">（{{ teacher.subjects?.[0] || "综合" }} · {{ teacher.years || 0 }}年）</span>
            </el-option>
          </el-select>
          <div v-if="teachers.length === 0" class="cell-muted">暂无可授课老师，请先在「老师管理」中通过合作申请</div>
        </el-form-item>
        <el-form-item label="班级名称" required>
          <el-input v-model="form.name" placeholder="如：启蒙绘画周六班" />
        </el-form-item>
        <el-form-item label="上课时间" required>
          <el-time-select v-model="form.start_time" start="08:00" step="00:30" end="21:00" style="width: 130px" />
          ~
          <el-time-select v-model="form.end_time" start="08:00" step="00:30" end="22:00" style="width: 130px" />
        </el-form-item>
        <el-form-item label="班级容量">
          <el-input-number v-model="form.capacity" :min="1" :max="200" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitCreate">{{ editingId ? "保存修改" : "创建班级" }}</el-button>
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

.cell-muted {
  color: #9c9385;
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

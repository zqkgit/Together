<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { Plus, Refresh, Search } from "@element-plus/icons-vue";
import {
  COURSE_CATEGORIES,
  fetchStudioCourses,
  createCourse,
  updateCourse,
  type CourseItem,
  type CoursePayload
} from "../../../services/studio";
import { useAuthStore } from "../../../stores/auth";

const authStore = useAuthStore();
const loading = ref(false);
const q = ref("");
const category = ref<number | "">("");
const status = ref<number | "">("");
const courses = ref<CourseItem[]>([]);

// 编辑对话框
const editorVisible = ref(false);
const editorMode = ref<"create" | "edit">("create");
const editingId = ref("");
const submitting = ref(false);
const form = ref<CoursePayload>({
  studio_id: "",
  title: "",
  category: 1,
  age_min: 3,
  age_max: 12,
  total_lessons: 24,
  duration_min: 90,
  price: 2880,
  class_size: 8,
  distribute_rate: 0.1,
  validity_days: 180,
  status: 1,
  lessons: []
});

const categoryLabel = (value: number) =>
  COURSE_CATEGORIES.find((item) => item.value === value)?.label || String(value);

const statusMeta: Record<number, { text: string; type: "success" | "info" | "warning" }> = {
  0: { text: "草稿", type: "info" },
  1: { text: "上架中", type: "success" },
  2: { text: "已下架", type: "warning" }
};

function formatPrice(price: number): string {
  return `¥ ${(price / 100).toFixed(2)}`;
}

async function loadData() {
  loading.value = true;
  try {
    courses.value = await fetchStudioCourses({
      studio_id: authStore.account?.studio_id || undefined,
      q: q.value.trim() || undefined,
      category: category.value,
      status: status.value
    });
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    loading.value = false;
  }
}

function handleSearch() {
  loadData();
}

function openCreate() {
  editorMode.value = "create";
  editingId.value = "";
  form.value = {
    studio_id: authStore.account?.studio_id || "",
    title: "",
    category: 1,
    age_min: 3,
    age_max: 12,
    total_lessons: 24,
    duration_min: 90,
    price: 2880,
    class_size: 8,
    distribute_rate: 0.1,
    validity_days: 180,
    status: 1,
    lessons: Array.from({ length: 24 }, (_, i) => ({ lesson_no: i + 1, title: "" }))
  };
  editorVisible.value = true;
}

async function openEdit(row: CourseItem) {
  editorMode.value = "edit";
  editingId.value = row.course_id;
  form.value = {
    studio_id: authStore.account?.studio_id || "",
    title: row.title,
    intro: row.intro || "",
    category: row.category,
    age_min: row.age_min,
    age_max: row.age_max,
    total_lessons: row.total_lessons,
    duration_min: row.duration_min,
    price: row.price,
    class_size: row.class_size,
    distribute_rate: row.distribute_rate,
    validity_days: row.validity_days,
    status: row.status,
    lessons: row.lessons?.length
      ? row.lessons.map((l) => ({ lesson_no: l.lesson_no, title: l.title }))
      : Array.from({ length: row.total_lessons }, (_, i) => ({ lesson_no: i + 1, title: "" }))
  };
  editorVisible.value = true;
}

// 课时数变化 → 重建课时标题输入列表（保留已填内容）
function syncLessonsCount() {
  const total = Math.max(1, Number(form.value.total_lessons) || 1);
  const next: { lesson_no: number; title: string }[] = [];
  for (let i = 1; i <= total; i += 1) {
    const existing = form.value.lessons?.find((l) => l.lesson_no === i);
    next.push({ lesson_no: i, title: existing?.title ?? "" });
  }
  form.value.lessons = next;
}

function validateForm(): boolean {
  if (!form.value.title.trim()) {
    ElMessage.warning("请填写课程名称");
    return false;
  }
  if (!form.value.total_lessons || form.value.total_lessons < 1) {
    ElMessage.warning("课时数必须大于 0");
    return false;
  }
  // 课时标题必填：课程详情 / 排课 / 学习页都要展示课时标题
  const emptyLesson = (form.value.lessons || []).find(
    (l) => !l.title || !String(l.title).trim()
  );
  if (emptyLesson) {
    ElMessage.warning(`请填写第 ${emptyLesson.lesson_no} 课的课时标题`);
    return false;
  }
  if (!form.value.price || form.value.price < 1) {
    ElMessage.warning("参考价格必须大于 0");
    return false;
  }
  return true;
}

async function submitCourse() {
  if (!validateForm()) return;
  submitting.value = true;
  try {
    const payload: CoursePayload = {
      studio_id: form.value.studio_id,
      title: form.value.title,
      intro: form.value.intro,
      category: form.value.category,
      age_min: form.value.age_min,
      age_max: form.value.age_max,
      total_lessons: form.value.total_lessons,
      duration_min: form.value.duration_min,
      price: form.value.price,
      class_size: form.value.class_size,
      distribute_rate: form.value.distribute_rate,
      validity_days: form.value.validity_days,
      status: form.value.status,
      lessons: (form.value.lessons || [])
        .filter((l) => l.title && l.title.trim())
        .map((l) => ({ lesson_no: l.lesson_no, title: l.title.trim() }))
    };
    if (editorMode.value === "create") {
      await createCourse(payload);
      ElMessage.success("课程创建成功");
    } else {
      await updateCourse(editingId.value, payload);
      ElMessage.success("课程已更新");
    }
    editorVisible.value = false;
    loadData();
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    submitting.value = false;
  }
}

async function toggleStatus(row: CourseItem) {
  try {
    await updateCourse(row.course_id, {
      studio_id: authStore.account?.studio_id || "",
      title: row.title,
      intro: row.intro || "",
      category: row.category,
      age_min: row.age_min,
      age_max: row.age_max,
      total_lessons: row.total_lessons,
      duration_min: row.duration_min,
      price: row.price,
      class_size: row.class_size,
      distribute_rate: row.distribute_rate,
      validity_days: row.validity_days,
      status: row.status === 1 ? 2 : 1
    });
    ElMessage.success(row.status === 1 ? "课程已下架" : "课程已上架");
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
          <div class="toolbar-left">
            <el-input
              v-model="q"
              placeholder="搜索课程名称"
              clearable
              style="width: 200px"
              :prefix-icon="Search"
              @keyup.enter="handleSearch"
              @clear="handleSearch"
            />
            <el-select v-model="category" placeholder="分类" clearable style="width: 130px" @change="handleSearch">
              <el-option
                v-for="item in COURSE_CATEGORIES"
                :key="item.value"
                :label="item.label"
                :value="item.value"
              />
            </el-select>
            <el-select v-model="status" placeholder="状态" clearable style="width: 120px" @change="handleSearch">
              <el-option label="草稿" :value="0" />
              <el-option label="上架中" :value="1" />
              <el-option label="已下架" :value="2" />
            </el-select>
            <el-button :icon="Refresh" @click="handleSearch">查询</el-button>
          </div>
          <el-button type="primary" :icon="Plus" @click="openCreate">新增课程</el-button>
        </div>
      </template>

      <el-table :data="courses" row-key="course_id">
        <el-table-column prop="title" label="课程名称" min-width="200">
          <template #default="{ row }">
            <span class="cell-strong">{{ row.title }}</span>
            <div class="cell-sub">{{ categoryLabel(row.category) }} · {{ row.age_min }}-{{ row.age_max }}岁</div>
          </template>
        </el-table-column>
        <el-table-column label="课时数" min-width="120">
          <template #default="{ row }">
            <span class="cell-strong">{{ row.total_lessons }} 节</span>
            <div class="cell-sub">{{ formatPrice(row.price) }}</div>
          </template>
        </el-table-column>
        <el-table-column prop="duration_min" label="时长" width="90">
          <template #default="{ row }">{{ row.duration_min }} 分钟</template>
        </el-table-column>
        <el-table-column prop="sales" label="已售" width="80" align="center" />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status].type" effect="light">
              {{ statusMeta[row.status].text }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button
              text
              :type="row.status === 1 ? 'warning' : 'success'"
              @click="toggleStatus(row)"
            >
              {{ row.status === 1 ? "下架" : "上架" }}
            </el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>

    <!-- 新增/编辑课程 -->
    <el-dialog
      v-model="editorVisible"
      :title="editorMode === 'create' ? '新增课程' : '编辑课程'"
      width="640px"
      destroy-on-close
    >
      <el-form :model="form" label-width="100px">
        <el-form-item label="课程名称" required>
          <el-input v-model="form.title" placeholder="如：创意启蒙绘画班" />
        </el-form-item>
        <el-form-item label="分类" required>
          <el-select v-model="form.category" style="width: 200px">
            <el-option
              v-for="item in COURSE_CATEGORIES"
              :key="item.value"
              :label="item.label"
              :value="item.value"
            />
          </el-select>
        </el-form-item>
        <el-form-item label="适龄范围">
          <el-input-number v-model="form.age_min" :min="1" :max="18" /> ~
          <el-input-number v-model="form.age_max" :min="1" :max="18" />
        </el-form-item>
        <el-form-item label="课时数" required>
          <el-input-number v-model="form.total_lessons" :min="1" :max="200" @change="syncLessonsCount" />
        </el-form-item>
        <el-form-item label="课时标题" required>
          <div class="lesson-list">
            <div
              v-for="(lesson, idx) in form.lessons || []"
              :key="lesson.lesson_no"
              class="lesson-row"
            >
              <span class="lesson-no">第{{ lesson.lesson_no }}课</span>
              <el-input
                v-model="lesson.title"
                maxlength="120"
                placeholder="请填写该节课的标题（课程详情/排课/学习页展示）"
              />
              <span v-if="idx === 0" class="cell-sub">排课时自动带出</span>
            </div>
          </div>
        </el-form-item>
        <el-form-item label="单课时长" required>
          <el-input-number v-model="form.duration_min" :min="15" :step="15" />
          <span class="cell-sub">分钟</span>
        </el-form-item>
        <el-form-item label="参考价格" required>
          <el-input-number v-model="form.price" :min="1" :step="100" />
          <span class="cell-sub">分（如 288000 = ¥2880）</span>
        </el-form-item>
        <el-form-item label="班级容量">
          <el-input-number v-model="form.class_size" :min="1" :max="50" />
        </el-form-item>
        <el-form-item label="分销比例">
          <el-input-number v-model="form.distribute_rate" :min="0.05" :max="0.15" :step="0.01" />
          <span class="cell-sub">（5% - 15%）</span>
        </el-form-item>
        <el-form-item label="有效期">
          <el-input-number v-model="form.validity_days" :min="1" :max="3650" />
          <span class="cell-sub">天</span>
        </el-form-item>
        <el-form-item label="课程介绍">
          <el-input
            v-model="form.intro"
            type="textarea"
            :rows="3"
            maxlength="500"
            show-word-limit
            placeholder="介绍课程内容、适合人群、上课安排等（APP 课程详情页展示）"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editorVisible = false">取消</el-button>
        <el-button type="primary" :loading="submitting" @click="submitCourse">
          {{ editorMode === "create" ? "创建课程" : "保存修改" }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.lesson-list {
  width: 100%;
  max-height: 240px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 8px;
}
.lesson-row {
  display: flex;
  align-items: center;
  gap: 8px;
}
.lesson-no {
  flex-shrink: 0;
  width: 64px;
  font-size: 13px;
  color: var(--el-text-color-secondary);
}
.lesson-row .el-input {
  flex: 1;
}
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
  flex-wrap: wrap;
}

.cell-strong {
  font-weight: 600;
  color: #2b2621;
}

.cell-sub {
  font-size: 12px;
  color: #9c9385;
}
</style>

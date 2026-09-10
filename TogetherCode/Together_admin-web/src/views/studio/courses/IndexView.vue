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
  packages: [{ name: "标准包", lessons: 24, price: 2880, original_price: null }]
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
    packages: [{ name: "标准包", lessons: 24, price: 2880, original_price: null }]
  };
  editorVisible.value = true;
}

async function openEdit(row: CourseItem) {
  editorMode.value = "edit";
  editingId.value = row.course_id;
  form.value = {
    studio_id: authStore.account?.studio_id || "",
    title: row.title,
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
    packages: row.packages.map((pkg) => ({
      name: pkg.name,
      lessons: pkg.lessons,
      price: pkg.price,
      original_price: pkg.original_price
    }))
  };
  editorVisible.value = true;
}

function addPackage() {
  form.value.packages.push({ name: "", lessons: 1, price: 0, original_price: null });
}

function removePackage(index: number) {
  if (form.value.packages.length <= 1) {
    ElMessage.warning("至少保留一个课时包");
    return;
  }
  form.value.packages.splice(index, 1);
}

function validateForm(): boolean {
  if (!form.value.title.trim()) {
    ElMessage.warning("请填写课程名称");
    return false;
  }
  for (const pkg of form.value.packages) {
    if (!pkg.name.trim()) {
      ElMessage.warning("课时包名称不能为空");
      return false;
    }
    if (!pkg.lessons || pkg.lessons < 1) {
      ElMessage.warning("课时包节数必须大于 0");
      return false;
    }
    if (!pkg.price || pkg.price < 1) {
      ElMessage.warning("课时包价格必须大于 0");
      return false;
    }
  }
  return true;
}

async function submitCourse() {
  if (!validateForm()) return;
  submitting.value = true;
  try {
    if (editorMode.value === "create") {
      await createCourse(form.value);
      ElMessage.success("课程创建成功");
    } else {
      await updateCourse(editingId.value, form.value);
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
      category: row.category,
      age_min: row.age_min,
      age_max: row.age_max,
      total_lessons: row.total_lessons,
      duration_min: row.duration_min,
      price: row.price,
      class_size: row.class_size,
      distribute_rate: row.distribute_rate,
      validity_days: row.validity_days,
      status: row.status === 1 ? 2 : 1,
      packages: row.packages.map((pkg) => ({
        name: pkg.name,
        lessons: pkg.lessons,
        price: pkg.price,
        original_price: pkg.original_price
      }))
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
        <el-table-column label="课时包" min-width="180">
          <template #default="{ row }">
            <div v-for="pkg in row.packages" :key="pkg.package_id || pkg.name" class="cell-sub">
              {{ pkg.name }}（{{ pkg.lessons }}节 · {{ formatPrice(pkg.price) }}）
            </div>
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
          <el-input-number v-model="form.total_lessons" :min="1" :max="200" />
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
        <el-form-item label="课时包" required>
          <div class="package-list">
            <div v-for="(pkg, index) in form.packages" :key="index" class="package-row">
              <el-input v-model="pkg.name" placeholder="包名" style="width: 120px" />
              <el-input-number v-model="pkg.lessons" :min="1" :max="500" placeholder="节数" />
              <el-input-number v-model="pkg.price" :min="1" :step="100" placeholder="价格(分)" />
              <el-button text type="danger" @click="removePackage(index)">移除</el-button>
            </div>
            <el-button text type="primary" :icon="Plus" @click="addPackage">添加课时包</el-button>
          </div>
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

.package-list {
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.package-row {
  display: flex;
  align-items: center;
  gap: 8px;
}
</style>

<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Plus, Refresh, Search } from "@element-plus/icons-vue";
import {
  fetchTopics,
  createTopic,
  updateTopic,
  deleteTopic,
  type TopicItem
} from "../../services/admin";

const loading = ref(false);
const keyword = ref("");
const list = ref<TopicItem[]>([]);

async function loadData() {
  loading.value = true;
  try {
    list.value = await fetchTopics({ q: keyword.value.trim() });
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    loading.value = false;
  }
}

function onSearch() {
  loadData();
}

// 新增 / 编辑
const editVisible = ref(false);
const editMode = ref<"create" | "update">("create");
const editRow = ref<TopicItem | null>(null);
const form = ref({ name: "", sort: 0 });
const saving = ref(false);

function openCreate() {
  editMode.value = "create";
  editRow.value = null;
  form.value = { name: "", sort: 0 };
  editVisible.value = true;
}

function openEdit(row: TopicItem) {
  editMode.value = "update";
  editRow.value = row;
  form.value = { name: row.name, sort: row.sort };
  editVisible.value = true;
}

async function submitForm() {
  if (!form.value.name.trim()) {
    ElMessage.warning("请填写话题名称");
    return;
  }
  saving.value = true;
  try {
    if (editMode.value === "create") {
      await createTopic({ name: form.value.name.trim(), sort: form.value.sort });
      ElMessage.success("话题已创建");
    } else if (editRow.value) {
      await updateTopic(editRow.value.topic_id, {
        name: form.value.name.trim(),
        sort: form.value.sort
      });
      ElMessage.success("话题已更新");
    }
    editVisible.value = false;
    loadData();
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    saving.value = false;
  }
}

async function onToggleStatus(row: TopicItem) {
  try {
    if (row.status === 1) {
      await ElMessageBox.confirm(
        `下架后「${row.name}」不再出现在 App 发帖可选话题，是否下架？`,
        "下架话题",
        { type: "warning", confirmButtonText: "下架", cancelButtonText: "取消" }
      );
      await updateTopic(row.topic_id, { status: 0 });
      ElMessage.success("话题已下架");
    } else {
      await updateTopic(row.topic_id, { status: 1 });
      ElMessage.success("话题已上架");
    }
    loadData();
  } catch (error) {
    if (error === "cancel" || error === "close") return;
    // 其他错误由拦截器统一处理
  }
}

async function onDelete(row: TopicItem) {
  try {
    await ElMessageBox.confirm(`删除话题「${row.name}」？已下架的话题将直接删除。`, "删除话题", {
      type: "warning",
      confirmButtonText: "删除",
      cancelButtonText: "取消"
    });
    await deleteTopic(row.topic_id);
    ElMessage.success("话题已删除");
    loadData();
  } catch (error) {
    if (error === "cancel" || error === "close") return;
    // 其他错误由拦截器统一处理
  }
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <div class="filter-row">
            <el-input
              v-model="keyword"
              placeholder="搜索话题名称"
              clearable
              size="small"
              style="width: 240px"
              @keyup.enter="onSearch"
              @clear="loadData"
            >
              <template #prefix>
                <el-icon><Search /></el-icon>
              </template>
            </el-input>
          </div>
          <div>
            <el-button :icon="Refresh" @click="loadData">刷新</el-button>
            <el-button type="primary" :icon="Plus" @click="openCreate">新增话题</el-button>
          </div>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        show-icon
        title="话题库：App 发帖时选择的话题（GET /v1/topics 仅返回上架话题）。下架后新帖不再可选，已发帖保留原话题。"
        class="flow-alert"
      />

      <el-table :data="list" row-key="topic_id">
        <el-table-column label="话题名称" min-width="180">
          <template #default="{ row }">
            <span class="cell-strong">#{{ row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="sort" label="排序" width="90" align="center" />
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'info'" effect="light" size="small">
              {{ row.status === 1 ? "上架中" : "已下架" }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="210" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button :text="true" :type="row.status === 1 ? 'warning' : 'success'" @click="onToggleStatus(row)">
              {{ row.status === 1 ? "下架" : "上架" }}
            </el-button>
            <el-button text type="danger" @click="onDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && list.length === 0" class="empty-tip">暂无话题，点击右上角新增</div>
    </el-card>

    <!-- 新增/编辑对话框 -->
    <el-dialog v-model="editVisible" :title="editMode === 'create' ? '新增话题' : '编辑话题'" width="440px">
      <el-form label-width="90px">
        <el-form-item label="话题名称" required>
          <el-input v-model="form.name" maxlength="40" show-word-limit placeholder="如：成长记录" />
        </el-form-item>
        <el-form-item label="排序">
          <el-input-number v-model="form.sort" :min="0" :max="999" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submitForm">
          {{ editMode === "create" ? "创建" : "保存" }}
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

.flow-alert {
  margin-bottom: 14px;
}

.cell-strong {
  font-weight: 600;
  color: #2b2621;
}

.empty-tip {
  padding: 32px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
}
</style>

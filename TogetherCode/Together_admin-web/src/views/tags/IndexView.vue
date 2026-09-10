<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Plus, Refresh } from "@element-plus/icons-vue";
import {
  fetchTags,
  createTag,
  updateTag,
  deleteTag,
  type TagItem
} from "../../services/admin";

const loading = ref(false);
const activeScope = ref<number | "">("");
const list = ref<TagItem[]>([]);

const scopeMeta: Record<number, { text: string; type: "primary" | "success" | "info" }> = {
  1: { text: "工作室", type: "primary" },
  2: { text: "老师", type: "success" },
  3: { text: "通用", type: "info" }
};

async function loadData() {
  loading.value = true;
  try {
    list.value = await fetchTags({ scope: activeScope.value });
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    loading.value = false;
  }
}

function onScopeChange(value: string | number) {
  activeScope.value = value as number | "";
  loadData();
}

// 新增 / 编辑
const editVisible = ref(false);
const editMode = ref<"create" | "update">("create");
const editRow = ref<TagItem | null>(null);
const form = ref({ name: "", scope: 3, sort: 0 });
const saving = ref(false);

function openCreate() {
  editMode.value = "create";
  editRow.value = null;
  form.value = { name: "", scope: activeScope.value === "" ? 3 : Number(activeScope.value), sort: 0 };
  editVisible.value = true;
}

function openEdit(row: TagItem) {
  editMode.value = "update";
  editRow.value = row;
  form.value = { name: row.name, scope: row.scope, sort: row.sort };
  editVisible.value = true;
}

async function submitForm() {
  if (!form.value.name.trim()) {
    ElMessage.warning("请填写标签名称");
    return;
  }
  saving.value = true;
  try {
    if (editMode.value === "create") {
      await createTag({ name: form.value.name.trim(), scope: Number(form.value.scope), sort: form.value.sort });
      ElMessage.success("标签已创建");
    } else if (editRow.value) {
      await updateTag(editRow.value.tag_id, {
        name: form.value.name.trim(),
        scope: Number(form.value.scope),
        sort: form.value.sort
      });
      ElMessage.success("标签已更新");
    }
    editVisible.value = false;
    loadData();
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    saving.value = false;
  }
}

async function onToggleStatus(row: TagItem) {
  try {
    if (row.status === 1) {
      await ElMessageBox.confirm(
        `停用后「${row.name}」不再出现在申请表单可选列表，是否停用？`,
        "停用标签",
        { type: "warning", confirmButtonText: "停用", cancelButtonText: "取消" }
      );
      await updateTag(row.tag_id, { status: 0 });
      ElMessage.success("标签已停用");
    } else {
      await updateTag(row.tag_id, { status: 1 });
      ElMessage.success("标签已启用");
    }
    loadData();
  } catch (error) {
    if (error === "cancel" || error === "close") return;
    // 其他错误由拦截器统一处理
  }
}

async function onDelete(row: TagItem) {
  try {
    await ElMessageBox.confirm(`删除标签「${row.name}」？已停用的标签将直接删除。`, "删除标签", {
      type: "warning",
      confirmButtonText: "删除",
      cancelButtonText: "取消"
    });
    await deleteTag(row.tag_id);
    ElMessage.success("标签已删除");
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
            <el-radio-group :model-value="activeScope" size="small" @change="onScopeChange">
              <el-radio-button :value="''">全部</el-radio-button>
              <el-radio-button :value="1">工作室</el-radio-button>
              <el-radio-button :value="2">老师</el-radio-button>
              <el-radio-button :value="3">通用</el-radio-button>
            </el-radio-group>
          </div>
          <div>
            <el-button :icon="Refresh" @click="loadData">刷新</el-button>
            <el-button type="primary" :icon="Plus" @click="openCreate">新增标签</el-button>
          </div>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        show-icon
        title="兴趣标签库：工作室申请 / 老师申请时可选。应用端（App / Web）通过公共接口读取启用中的标签（GET /v1/tags?scope=1|2|3）。"
        class="flow-alert"
      />

      <el-table :data="list" row-key="tag_id">
        <el-table-column label="标签名称" min-width="160">
          <template #default="{ row }">
            <span class="cell-strong">{{ row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column label="使用场景" width="110">
          <template #default="{ row }">
            <el-tag :type="scopeMeta[row.scope].type" effect="light" size="small">
              {{ scopeMeta[row.scope].text }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="sort" label="排序" width="80" align="center" />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'info'" effect="light" size="small">
              {{ row.status === 1 ? "启用中" : "已停用" }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="190" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openEdit(row)">编辑</el-button>
            <el-button :text="true" :type="row.status === 1 ? 'warning' : 'success'" @click="onToggleStatus(row)">
              {{ row.status === 1 ? "停用" : "启用" }}
            </el-button>
            <el-button text type="danger" @click="onDelete(row)">删除</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && list.length === 0" class="empty-tip">暂无标签，点击右上角新增</div>
    </el-card>

    <!-- 新增/编辑对话框 -->
    <el-dialog
      v-model="editVisible"
      :title="editMode === 'create' ? '新增标签' : '编辑标签'"
      width="440px"
    >
      <el-form label-width="90px">
        <el-form-item label="标签名称" required>
          <el-input v-model="form.name" maxlength="40" show-word-limit placeholder="如：创意绘画" />
        </el-form-item>
        <el-form-item label="使用场景">
          <el-radio-group v-model="form.scope">
            <el-radio-button :value="1">工作室</el-radio-button>
            <el-radio-button :value="2">老师</el-radio-button>
            <el-radio-button :value="3">通用</el-radio-button>
          </el-radio-group>
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

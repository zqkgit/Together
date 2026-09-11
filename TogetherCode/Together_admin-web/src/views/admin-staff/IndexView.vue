<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Plus, Refresh, Search } from "@element-plus/icons-vue";
import { fetchAdminStaff, createAdminStaff, toggleStaffStatus, type StaffItem } from "../../services/admin";
import { useAuthStore } from "../../stores/auth";

const auth = useAuthStore();
const loading = ref(false);
const list = ref<StaffItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);
const keyword = ref("");

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchAdminStaff({ q: keyword.value.trim() || undefined, page: page.value, page_size: pageSize.value });
    list.value = data.list;
    total.value = data.total;
  } catch {
    // 拦截器统一提示
  } finally {
    loading.value = false;
  }
}

function onFilter() {
  page.value = 1;
  loadData();
}

function onReset() {
  keyword.value = "";
  page.value = 1;
  loadData();
}

// 新增
const createVisible = ref(false);
const saving = ref(false);
const form = ref({ username: "", password: "", name: "" });

function openCreate() {
  form.value = { username: "", password: "", name: "" };
  createVisible.value = true;
}

async function submit() {
  if (!form.value.username.trim() || !form.value.password) {
    ElMessage.warning("请填写账号和密码");
    return;
  }
  if (form.value.password.length < 6) {
    ElMessage.warning("密码至少 6 位");
    return;
  }
  saving.value = true;
  try {
    await createAdminStaff({
      username: form.value.username.trim(),
      password: form.value.password,
      name: form.value.name.trim() || undefined
    });
    ElMessage.success("员工账号已创建");
    createVisible.value = false;
    loadData();
  } catch {
    // 拦截器统一提示
  } finally {
    saving.value = false;
  }
}

async function onToggle(row: StaffItem) {
  const next = row.status === 1 ? 0 : 1;
  try {
    await ElMessageBox.confirm(
      next === 0 ? `停用后「${row.username}」将无法登录后台，确认停用？` : `确认启用「${row.username}」？`,
      next === 0 ? "停用账号" : "启用账号",
      { type: "warning", confirmButtonText: "确认", cancelButtonText: "取消" }
    );
    await toggleStaffStatus(row.admin_id, next as 0 | 1);
    ElMessage.success(next === 0 ? "账号已停用" : "账号已启用");
    loadData();
  } catch (error) {
    if (error === "cancel" || error === "close") return;
  }
}

const roleMeta: Record<string, { text: string; type: "primary" | "success" | "warning" | "info" }> = {
  platform_super: { text: "超级管理员", type: "danger" },
  platform_ops: { text: "平台运营", type: "primary" }
};

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <div class="filter-row">
            <el-input v-model="keyword" placeholder="按账号搜索" clearable style="width: 200px" @keyup.enter="onFilter" @clear="onFilter">
              <template #append>
                <el-button :icon="Search" @click="onFilter" />
              </template>
            </el-input>
          </div>
          <div>
            <el-button :icon="Refresh" circle @click="onReset" />
            <el-button type="primary" :icon="Plus" @click="openCreate">新增员工</el-button>
          </div>
        </div>
      </template>

      <el-table :data="list">
        <el-table-column prop="username" label="账号" min-width="160" />
        <el-table-column label="角色" width="130">
          <template #default="{ row }">
            <el-tag :type="roleMeta[row.role]?.type || 'info'" size="small">{{ roleMeta[row.role]?.text || row.role }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'info'" size="small">{{ row.status === 1 ? "正常" : "已停用" }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="创建时间" width="170" />
        <el-table-column label="操作" width="130" fixed="right">
          <template #default="{ row }">
            <template v-if="row.username !== auth.account?.username">
              <el-button :type="row.status === 1 ? 'danger' : 'success'" link @click="onToggle(row)">
                {{ row.status === 1 ? "停用" : "启用" }}
              </el-button>
            </template>
            <span v-else class="muted">当前登录</span>
          </template>
        </el-table-column>
      </el-table>

      <el-pagination
        v-model:current-page="page"
        v-model:page-size="pageSize"
        :total="total"
        layout="total, prev, pager, next, sizes"
        :page-sizes="[10, 20, 50]"
        class="pager"
        @change="loadData"
      />
    </el-card>

    <el-dialog v-model="createVisible" title="新增平台员工" width="440px">
      <el-form label-width="80px">
        <el-form-item label="登录账号" required>
          <el-input v-model="form.username" placeholder="字母数字，将用于后台登录" maxlength="32" />
        </el-form-item>
        <el-form-item label="密码" required>
          <el-input v-model="form.password" type="password" show-password placeholder="至少 6 位" />
        </el-form-item>
        <el-form-item label="姓名">
          <el-input v-model="form.name" placeholder="员工姓名（可选）" maxlength="20" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submit">创建</el-button>
      </template>
    </el-dialog>
  </div>
</template>

<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Refresh, Search } from "@element-plus/icons-vue";
import { fetchAdminPosts, moderatePost, type AdminPostItem } from "../../services/admin";

const loading = ref(false);
const list = ref<AdminPostItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);
const filterStatus = ref<number | "">("");
const keyword = ref("");

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchAdminPosts({
      status: filterStatus.value,
      q: keyword.value.trim() || undefined,
      page: page.value,
      page_size: pageSize.value
    });
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
  filterStatus.value = "";
  keyword.value = "";
  page.value = 1;
  loadData();
}

async function onModerate(row: AdminPostItem, status: 0 | 1) {
  const actionText = status === 0 ? "下架" : "恢复";
  try {
    await ElMessageBox.confirm(
      status === 0
        ? `确认下架该帖子？下架后 App 端不再展示。`
        : `确认恢复该帖子？恢复后 App 端可正常展示。`,
      `${actionText}帖子`,
      { type: status === 0 ? "warning" : "info", confirmButtonText: actionText, cancelButtonText: "取消" }
    );
    await moderatePost(row.post_id, status);
    ElMessage.success(status === 0 ? "帖子已下架" : "帖子已恢复");
    loadData();
  } catch (error) {
    if (error === "cancel" || error === "close") return;
    // 其他错误由拦截器统一提示
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
              placeholder="按内容关键词搜索"
              clearable
              style="width: 220px"
              @keyup.enter="onFilter"
              @clear="onFilter"
            >
              <template #append>
                <el-button :icon="Search" @click="onFilter" />
              </template>
            </el-input>
            <el-radio-group v-model="filterStatus" size="small" @change="onFilter">
              <el-radio-button :value="''">全部</el-radio-button>
              <el-radio-button :value="1">正常</el-radio-button>
              <el-radio-button :value="0">已下架</el-radio-button>
            </el-radio-group>
          </div>
          <div>
            <el-button :icon="Refresh" circle @click="onReset" />
          </div>
        </div>
      </template>

      <el-table :data="list">
        <el-table-column label="作者" width="130">
          <template #default="{ row }">{{ row.author?.nickname || row.author?.phone || "-" }}</template>
        </el-table-column>
        <el-table-column prop="content" label="内容" min-width="260" show-overflow-tooltip />
        <el-table-column label="关联课程" width="150">
          <template #default="{ row }">
            <el-tag v-if="row.course" size="small" type="primary">{{ row.course.title }}</el-tag>
            <span v-else class="muted">纯分享</span>
          </template>
        </el-table-column>
        <el-table-column label="互动" width="130">
          <template #default="{ row }">
            <span class="muted">👍 {{ row.like_count }} · 💬 {{ row.comment_count }} · 🔗 {{ row.share_count }}</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'danger'" size="small">
              {{ row.status === 1 ? "正常" : "已下架" }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="发布时间" width="170" />
        <el-table-column label="操作" width="110" fixed="right">
          <template #default="{ row }">
            <el-button v-if="row.status === 1" link type="danger" @click="onModerate(row, 0)">下架</el-button>
            <el-button v-else link type="success" @click="onModerate(row, 1)">恢复</el-button>
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
  </div>
</template>

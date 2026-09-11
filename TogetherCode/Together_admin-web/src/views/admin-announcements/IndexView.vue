<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Plus, Refresh } from "@element-plus/icons-vue";
import { fetchAnnouncements, createAnnouncement, toggleAnnouncement, type AnnouncementItem } from "../../services/admin";

const loading = ref(false);
const list = ref<AnnouncementItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);
const filterType = ref<number | "">("");
const filterStatus = ref<number | "">("");

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchAnnouncements({
      type: filterType.value,
      status: filterStatus.value,
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
  filterType.value = "";
  filterStatus.value = "";
  page.value = 1;
  loadData();
}

// 发布弹窗
const publishVisible = ref(false);
const saving = ref(false);
const form = ref({ title: "", content: "", type: 1 as 1 | 2, link: "", imageText: "", status: 1 });

function openPublish() {
  form.value = { title: "", content: "", type: 1, link: "", imageText: "", status: 1 };
  publishVisible.value = true;
}

async function submit() {
  if (!form.value.title.trim()) {
    ElMessage.warning("请填写标题");
    return;
  }
  saving.value = true;
  try {
    await createAnnouncement({
      title: form.value.title.trim(),
      content: form.value.content.trim() || undefined,
      type: form.value.type,
      link: form.value.link.trim() || undefined,
      image: form.value.imageText.trim()
        ? form.value.imageText.split("\n").map((s) => s.trim()).filter(Boolean)
        : undefined,
      status: form.value.status
    });
    ElMessage.success("公告已发布");
    publishVisible.value = false;
    loadData();
  } catch {
    // 拦截器统一提示
  } finally {
    saving.value = false;
  }
}

async function onToggle(row: AnnouncementItem) {
  const next = row.status === 1 ? 0 : 1;
  try {
    await ElMessageBox.confirm(
      next === 0 ? `确认下架「${row.title}」？` : `确认重新上架「${row.title}」？`,
      next === 0 ? "下架公告" : "上架公告",
      { type: "warning", confirmButtonText: "确认", cancelButtonText: "取消" }
    );
    await toggleAnnouncement(row.announcement_id, next as 0 | 1);
    ElMessage.success(next === 0 ? "公告已下架" : "公告已上架");
    loadData();
  } catch (error) {
    if (error === "cancel" || error === "close") return;
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
            <el-radio-group v-model="filterType" size="small" @change="onFilter">
              <el-radio-button :value="''">全部</el-radio-button>
              <el-radio-button :value="1">公告</el-radio-button>
              <el-radio-button :value="2">Banner</el-radio-button>
            </el-radio-group>
            <el-radio-group v-model="filterStatus" size="small" @change="onFilter">
              <el-radio-button :value="''">全部状态</el-radio-button>
              <el-radio-button :value="1">展示中</el-radio-button>
              <el-radio-button :value="0">已下架</el-radio-button>
            </el-radio-group>
          </div>
          <div>
            <el-button :icon="Refresh" circle @click="onReset" />
            <el-button type="primary" :icon="Plus" @click="openPublish">发布</el-button>
          </div>
        </div>
      </template>

      <el-table :data="list">
        <el-table-column label="类型" width="90">
          <template #default="{ row }">
            <el-tag :type="row.type === 1 ? 'primary' : 'warning'" size="small">{{ row.type === 1 ? "公告" : "Banner" }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="title" label="标题" min-width="200" show-overflow-tooltip />
        <el-table-column prop="content" label="内容" min-width="200" show-overflow-tooltip />
        <el-table-column label="状态" width="90">
          <template #default="{ row }">
            <el-tag :type="row.status === 1 ? 'success' : 'info'" size="small">{{ row.status === 1 ? "展示中" : "已下架" }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="创建时间" width="170" />
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button :type="row.status === 1 ? 'danger' : 'success'" link @click="onToggle(row)">
              {{ row.status === 1 ? "下架" : "上架" }}
            </el-button>
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

    <el-dialog v-model="publishVisible" title="发布公告 / Banner" width="560px">
      <el-form label-width="80px">
        <el-form-item label="类型">
          <el-radio-group v-model="form.type">
            <el-radio-button :value="1">公告</el-radio-button>
            <el-radio-button :value="2">Banner</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="标题" required>
          <el-input v-model="form.title" placeholder="公告标题" maxlength="60" />
        </el-form-item>
        <el-form-item label="内容">
          <el-input v-model="form.content" type="textarea" :rows="3" placeholder="公告正文（Banner 可留空）" />
        </el-form-item>
        <el-form-item label="跳转链接">
          <el-input v-model="form.link" placeholder="https://…（可选）" />
        </el-form-item>
        <el-form-item label="图片">
          <el-input
            v-model="form.imageText"
            type="textarea"
            :rows="2"
            placeholder="Banner 图片 URL，每行一个（可选）"
          />
        </el-form-item>
        <el-form-item label="发布状态">
          <el-switch v-model="form.status" :active-value="1" :inactive-value="0" active-text="立即展示" inactive-text="存为草稿" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="publishVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submit">发布</el-button>
      </template>
    </el-dialog>
  </div>
</template>

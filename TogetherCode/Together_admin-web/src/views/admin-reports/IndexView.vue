<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Refresh } from "@element-plus/icons-vue";
import { fetchReports, handleReport, type ReportItem } from "../../services/admin";

const loading = ref(false);
const list = ref<ReportItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);
const filterStatus = ref<number | "">("");
const filterType = ref("");

const typeMeta: Record<string, { text: string; type: "primary" | "warning" | "info" }> = {
  post: { text: "帖子", type: "primary" },
  course: { text: "课程", type: "warning" },
  studio: { text: "工作室", type: "info" },
  comment: { text: "评论", type: "info" }
};

const statusMeta: Record<number, { text: string; type: "warning" | "success" | "danger" }> = {
  0: { text: "待处理", type: "warning" },
  1: { text: "已处理", type: "success" },
  2: { text: "已驳回", type: "danger" }
};

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchReports({
      status: filterStatus.value,
      target_type: filterType.value || undefined,
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
  filterType.value = "";
  page.value = 1;
  loadData();
}

async function onHandle(row: ReportItem, status: 1 | 2) {
  const actionText = status === 1 ? "确认违规" : "驳回";
  try {
    const { value } = await ElMessageBox.prompt(`请填写处置备注（可选）：`, `${actionText}举报`, {
      confirmButtonText: actionText,
      cancelButtonText: "取消",
      inputPlaceholder: "例如：确认违规，内容已下架",
      inputValidator: () => true
    });
    await handleReport(row.report_id, { status, handle_note: value?.trim() || undefined });
    ElMessage.success(status === 1 ? "举报已处理" : "举报已驳回");
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
            <el-select v-model="filterType" placeholder="举报对象" clearable style="width: 140px" @change="onFilter">
              <el-option label="帖子" value="post" />
              <el-option label="课程" value="course" />
              <el-option label="工作室" value="studio" />
              <el-option label="评论" value="comment" />
            </el-select>
            <el-radio-group v-model="filterStatus" size="small" @change="onFilter">
              <el-radio-button :value="''">全部</el-radio-button>
              <el-radio-button :value="0">待处理</el-radio-button>
              <el-radio-button :value="1">已处理</el-radio-button>
              <el-radio-button :value="2">已驳回</el-radio-button>
            </el-radio-group>
          </div>
          <div>
            <el-button :icon="Refresh" circle @click="onReset" />
          </div>
        </div>
      </template>

      <el-table :data="list">
        <el-table-column label="举报对象" width="110">
          <template #default="{ row }">
            <el-tag :type="typeMeta[row.target_type]?.type || 'info'" size="small">
              {{ typeMeta[row.target_type]?.text || row.target_type }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="target_id" label="目标 ID" width="180" show-overflow-tooltip />
        <el-table-column label="举报人" width="140">
          <template #default="{ row }">{{ row.reporter?.nickname || row.reporter?.phone || "-" }}</template>
        </el-table-column>
        <el-table-column prop="reason" label="举报原因" width="120" />
        <el-table-column prop="detail" label="补充说明" min-width="180" show-overflow-tooltip />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status]?.type" size="small">{{ statusMeta[row.status]?.text }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="举报时间" width="170" />
        <el-table-column label="操作" width="170" fixed="right">
          <template #default="{ row }">
            <template v-if="row.status === 0">
              <el-button link type="danger" @click="onHandle(row, 1)">确认违规</el-button>
              <el-button link type="info" @click="onHandle(row, 2)">驳回</el-button>
            </template>
            <span v-else class="muted">{{ row.handle_note || "-" }}</span>
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

<script setup lang="ts">
import { timeFormatter } from "../../utils/format";
import { onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Refresh } from "@element-plus/icons-vue";
import { fetchCourseReviews, auditCourseReview, type CourseReviewItem } from "../../services/admin";

const loading = ref(false);
const list = ref<CourseReviewItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);
const filterStatus = ref<number | "">("");
const filterRating = ref<number | "">("");

const statusMeta: Record<number, { text: string; type: "warning" | "success" | "danger" | "info" }> = {
  0: { text: "待审核", type: "warning" },
  1: { text: "已通过", type: "success" },
  2: { text: "已驳回", type: "danger" }
};

function stars(rating: number) {
  return "★".repeat(rating) + "☆".repeat(5 - rating);
}

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchCourseReviews({
      status: filterStatus.value,
      rating: filterRating.value,
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
  filterRating.value = "";
  page.value = 1;
  loadData();
}

async function onAudit(row: CourseReviewItem, action: "approve" | "reject") {
  try {
    let reason: string | undefined;
    if (action === "reject") {
      const { value } = await ElMessageBox.prompt(`请填写驳回原因（将展示给家长）：`, `驳回评价`, {
        confirmButtonText: "确认驳回",
        cancelButtonText: "取消",
        inputPlaceholder: "例如：内容含联系方式，不符合平台规范",
        inputValidator: (v: string) => (v.trim() ? true : "请填写驳回原因")
      });
      reason = value?.trim();
    }
    await auditCourseReview(row.review_id, { action, reason });
    ElMessage.success(action === "approve" ? "评价已通过" : "评价已驳回");
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
            <el-radio-group v-model="filterStatus" size="small" @change="onFilter">
              <el-radio-button :value="''">全部</el-radio-button>
              <el-radio-button :value="0">待审核</el-radio-button>
              <el-radio-button :value="1">已通过</el-radio-button>
              <el-radio-button :value="2">已驳回</el-radio-button>
            </el-radio-group>
            <el-select v-model="filterRating" placeholder="评分" clearable style="width: 100px" @change="onFilter">
              <el-option label="5星" :value="5" />
              <el-option label="4星" :value="4" />
              <el-option label="3星" :value="3" />
              <el-option label="2星" :value="2" />
              <el-option label="1星" :value="1" />
            </el-select>
          </div>
          <div>
            <el-button :icon="Refresh" circle @click="onReset" />
          </div>
        </div>
      </template>

      <el-table :data="list">
        <el-table-column label="评分" width="100">
          <template #default="{ row }">
            <span class="stars">{{ stars(row.rating) }}</span>
          </template>
        </el-table-column>
        <el-table-column label="家长" width="130">
          <template #default="{ row }">{{ row.user?.nickname || "-" }}</template>
        </el-table-column>
        <el-table-column label="课程" min-width="180" show-overflow-tooltip>
          <template #default="{ row }">
            <div class="course-cell">
              <el-image
                v-if="row.course?.cover"
                :src="row.course.cover"
                fit="cover"
                class="cover"
                :preview-src-list="[row.course.cover]"
                preview-teleported
              >
                <template #error><div class="cover cover-fallback" /></template>
              </el-image>
              <span>{{ row.course?.title || "-" }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="工作室" width="140" show-overflow-tooltip>
          <template #default="{ row }">{{ row.course?.studio_name || "-" }}</template>
        </el-table-column>
        <el-table-column prop="content" label="评价内容" min-width="220" show-overflow-tooltip />
        <el-table-column label="图片" width="100">
          <template #default="{ row }">
            <el-image
              v-if="row.images?.length"
              :src="row.images[0]"
              fit="cover"
              class="cover"
              :preview-src-list="row.images"
              preview-teleported
            />
            <span v-else class="muted">-</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status]?.type" size="small">{{ statusMeta[row.status]?.text }}</el-tag>
            <div v-if="row.status === 2 && row.reject_reason" class="reject-reason">{{ row.reject_reason }}</div>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" :formatter="timeFormatter" label="评价时间" width="170" />
        <el-table-column label="操作" width="140" fixed="right">
          <template #default="{ row }">
            <template v-if="row.status === 0">
              <el-button link type="success" @click="onAudit(row, 'approve')">通过</el-button>
              <el-button link type="danger" @click="onAudit(row, 'reject')">驳回</el-button>
            </template>
            <span v-else class="muted">已处理</span>
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

<style scoped>
.course-cell {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}
.cover {
  width: 36px;
  height: 36px;
  border-radius: 6px;
  flex-shrink: 0;
}
.cover-fallback {
  background: #f3f4f6;
}
.stars {
  color: #f59e0b;
  letter-spacing: 1px;
}
.reject-reason {
  color: #f56c6c;
  font-size: 12px;
  margin-top: 2px;
  max-width: 120px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>

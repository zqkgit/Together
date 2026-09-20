<script setup lang="ts">
import { timeFormatter } from "../../utils/format";
import { onMounted, reactive, ref } from "vue";
import { ElMessage } from "element-plus";
import { Refresh } from "@element-plus/icons-vue";
import { fetchStudioReviews, replyStudioReview, type StudioReviewItem } from "../../services/studio";

const loading = ref(false);
const list = ref<StudioReviewItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);
const filterRating = ref<number | "">("");
const filterReplied = ref("");

// 回复弹框
const dialogVisible = ref(false);
const replying = ref(false);
const currentRow = ref<StudioReviewItem | null>(null);
const replyForm = reactive<{ role: "studio" | "teacher"; teacher_id: string; content: string }>({
  role: "studio",
  teacher_id: "",
  content: ""
});
const teacherOptions = ref<Array<{ teacher_id: string; real_name: string }>>([]);

function stars(rating: number) {
  return "★".repeat(rating) + "☆".repeat(5 - rating);
}

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchStudioReviews({
      rating: filterRating.value,
      replied: filterReplied.value || undefined,
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
  filterRating.value = "";
  filterReplied.value = "";
  page.value = 1;
  loadData();
}

function openReply(row: StudioReviewItem) {
  currentRow.value = row;
  replyForm.role = "studio";
  replyForm.teacher_id = row.course?.teacher_name ? "" : "";
  replyForm.content = "";
  dialogVisible.value = true;
}

async function submitReply() {
  if (!currentRow.value) return;
  if (!replyForm.content.trim()) {
    ElMessage.warning("请填写回复内容");
    return;
  }
  if (replyForm.role === "teacher" && !replyForm.teacher_id) {
    ElMessage.warning("请选择授课老师");
    return;
  }
  replying.value = true;
  try {
    await replyStudioReview(currentRow.value.review_id, {
      role: replyForm.role,
      teacher_id: replyForm.role === "teacher" ? replyForm.teacher_id : undefined,
      content: replyForm.content.trim()
    });
    ElMessage.success("回复成功");
    dialogVisible.value = false;
    loadData();
  } catch {
    // 拦截器已提示
  } finally {
    replying.value = false;
  }
}

onMounted(async () => {
  loadData();
  // 拉取合作老师列表（用于老师名义回复）
  try {
    const { fetchStudioTeachers } = await import("../../services/studio");
    const res = await fetchStudioTeachers({});
    teacherOptions.value = (res.staff || []).map((t) => ({ teacher_id: t.teacher_id, real_name: t.real_name }));
  } catch {
    // 忽略
  }
});
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <div class="filter-row">
            <el-radio-group v-model="filterReplied" size="small" @change="onFilter">
              <el-radio-button :value="''">全部</el-radio-button>
              <el-radio-button value="0">未回复</el-radio-button>
              <el-radio-button value="1">已回复</el-radio-button>
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
        <el-table-column label="家长" width="120">
          <template #default="{ row }">{{ row.user?.nickname || "-" }}</template>
        </el-table-column>
        <el-table-column label="课程" min-width="160" show-overflow-tooltip>
          <template #default="{ row }">
            <div class="course-cell">
              <el-image v-if="row.course?.cover" :src="row.course.cover" fit="cover" class="cover" :preview-src-list="[row.course.cover]" preview-teleported>
                <template #error><div class="cover cover-fallback" /></template>
              </el-image>
              <span>{{ row.course?.title || "-" }}</span>
            </div>
          </template>
        </el-table-column>
        <el-table-column label="授课老师" width="110">
          <template #default="{ row }">{{ row.course?.teacher_name || "-" }}</template>
        </el-table-column>
        <el-table-column prop="content" label="评价内容" min-width="180" show-overflow-tooltip />
        <el-table-column label="回复" min-width="200">
          <template #default="{ row }">
            <div v-if="row.reply_content" class="reply-line">
              <span class="reply-tag studio">工作室</span>
              <span class="reply-text">{{ row.reply_content }}</span>
            </div>
            <div v-if="row.teacher_reply_content" class="reply-line">
              <span class="reply-tag teacher">老师</span>
              <span class="reply-text">{{ row.teacher_reply_content }}</span>
            </div>
            <span v-if="!row.reply_content && !row.teacher_reply_content" class="muted">未回复</span>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" :formatter="timeFormatter" label="评价时间" width="170" />
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openReply(row)">回复</el-button>
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

    <el-dialog v-model="dialogVisible" title="回复评价" width="480px" :close-on-click-modal="false">
      <el-form label-width="80px">
        <el-form-item label="回复身份">
          <el-radio-group v-model="replyForm.role">
            <el-radio value="studio">以工作室名义</el-radio>
            <el-radio value="teacher">以老师名义</el-radio>
          </el-radio-group>
        </el-form-item>
        <el-form-item v-if="replyForm.role === 'teacher'" label="授课老师">
          <el-select v-model="replyForm.teacher_id" placeholder="请选择老师" style="width: 100%">
            <el-option v-for="t in teacherOptions" :key="t.teacher_id" :label="t.real_name" :value="t.teacher_id" />
          </el-select>
        </el-form-item>
        <el-form-item label="回复内容">
          <el-input
            v-model="replyForm.content"
            type="textarea"
            :rows="4"
            maxlength="500"
            show-word-limit
            placeholder="回复将公开展示给家长…"
          />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="dialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="replying" @click="submitReply">回复</el-button>
      </template>
    </el-dialog>
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
.reply-line {
  display: flex;
  gap: 6px;
  align-items: flex-start;
  line-height: 1.5;
  margin-bottom: 2px;
}
.reply-tag {
  flex-shrink: 0;
  font-size: 11px;
  padding: 0 6px;
  border-radius: 4px;
  line-height: 18px;
  margin-top: 1px;
}
.reply-tag.studio {
  color: #2563eb;
  background: #eff6ff;
}
.reply-tag.teacher {
  color: #7c3aed;
  background: #f5f3ff;
}
.reply-text {
  color: #4b5563;
  font-size: 13px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { Refresh, Search } from "@element-plus/icons-vue";
import {
  fetchStudioStudents,
  consumeStudentLessons,
  type StudentItem,
  type StudentBalance
} from "../../../services/studio";
import { useAuthStore } from "../../../stores/auth";

const authStore = useAuthStore();
const studioId = computed(() => authStore.account?.studio_id || "");

const loading = ref(false);
const q = ref("");
const status = ref("");
const students = ref<StudentItem[]>([]);

// 详情
const drawerOpen = ref(false);
const current = ref<StudentItem | null>(null);

// 手动消课
const consumeVisible = ref(false);
const consumeBalance = ref<StudentBalance | null>(null);
const consumeCount = ref(1);
const consumeNote = ref("");
const consuming = ref(false);

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchStudioStudents({
      studio_id: studioId.value,
      q: q.value.trim() || undefined,
      status: status.value || undefined
    });
    students.value = data.list;
  } catch {
    // 忽略
  } finally {
    loading.value = false;
  }
}

function openDetail(row: StudentItem) {
  current.value = row;
  drawerOpen.value = true;
}

function genderText(gender: string): string {
  const map: Record<string, string> = { male: "男", female: "女", other: "其他" };
  return map[gender] || "-";
}

function openConsume(balance: StudentBalance) {
  consumeBalance.value = balance;
  consumeCount.value = 1;
  consumeNote.value = "";
  consumeVisible.value = true;
}

async function submitConsume() {
  if (!consumeBalance.value || !current.value) return;
  if (consumeCount.value > consumeBalance.value.remaining_lessons) {
    ElMessage.warning(`剩余课时不足（仅剩 ${consumeBalance.value.remaining_lessons} 节）`);
    return;
  }
  consuming.value = true;
  try {
    await consumeStudentLessons(current.value.child_id, {
      order_id: consumeBalance.value.order_id,
      count: consumeCount.value,
      note: consumeNote.value.trim() || undefined
    });
    ElMessage.success(`已消耗 ${consumeCount.value} 课时`);
    consumeVisible.value = false;
    loadData();
    if (current.value) {
      const updated = students.value.find((s) => s.child_id === current.value!.child_id);
      if (updated) current.value = updated;
    }
  } catch {
    // 忽略
  } finally {
    consuming.value = false;
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
              placeholder="搜索学员昵称"
              clearable
              style="width: 200px"
              :prefix-icon="Search"
              @keyup.enter="loadData"
              @clear="loadData"
            />
            <el-select v-model="status" placeholder="课时状态" clearable style="width: 130px" @change="loadData">
              <el-option label="有剩余课时" value="active" />
              <el-option label="课时耗尽" value="empty" />
            </el-select>
            <el-button :icon="Refresh" @click="loadData">查询</el-button>
          </div>
        </div>
      </template>

      <el-table :data="students" row-key="child_id">
        <el-table-column prop="nickname" label="学员" min-width="160">
          <template #default="{ row }">
            <span class="cell-strong">{{ row.nickname }}</span>
            <div class="cell-sub">
              {{ genderText(row.gender) }} · {{ row.birthday || "未填生日" }}
            </div>
          </template>
        </el-table-column>
        <el-table-column label="总剩余课时" width="140" align="center">
          <template #default="{ row }">
            <span :class="{ 'zero-cell': row.total_remaining_lessons === 0 }">
              {{ row.total_remaining_lessons }}
            </span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="120">
          <template #default="{ row }">
            <el-tag :type="row.status === 'active' ? 'success' : 'info'" effect="light">
              {{ row.status === "active" ? "在学" : "课时耗尽" }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="课时明细" min-width="220">
          <template #default="{ row }">
            <div v-for="b in row.balances" :key="b.balance_id" class="cell-sub">
              {{ b.course_title }}：剩 {{ b.remaining_lessons }}/{{ b.total_lessons }} 节
            </div>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="140" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openDetail(row)">详情</el-button>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && students.length === 0" class="empty-tip">暂无学员</div>
    </el-card>

    <!-- 学员详情 -->
    <el-drawer v-model="drawerOpen" :title="`学员详情 · ${current?.nickname || ''}`" size="520px">
      <template v-if="current">
        <el-table :data="current.balances" size="small">
          <el-table-column prop="course_title" label="课程" min-width="140" />
          <el-table-column prop="remaining_lessons" label="剩余" width="70" align="center" />
          <el-table-column prop="consumed_lessons" label="已消耗" width="80" align="center" />
          <el-table-column label="有效期" min-width="120">
            <template #default="{ row }">{{ row.valid_from || "-" }} ~ {{ row.valid_to || "-" }}</template>
          </el-table-column>
          <el-table-column label="操作" width="110" fixed="right">
            <template #default="{ row }">
              <el-button
                text
                type="primary"
                size="small"
                :disabled="row.remaining_lessons <= 0"
                @click="openConsume(row)"
              >
                消课
              </el-button>
            </template>
          </el-table-column>
        </el-table>
      </template>
    </el-drawer>

    <!-- 手动消课 -->
    <el-dialog v-model="consumeVisible" title="手动消课" width="420px">
      <el-descriptions :column="1" border size="small">
        <el-descriptions-item label="课程">{{ consumeBalance?.course_title }}</el-descriptions-item>
        <el-descriptions-item label="剩余课时">
          <span class="cell-strong">{{ consumeBalance?.remaining_lessons }} 节</span>
        </el-descriptions-item>
      </el-descriptions>
      <div class="consume-row">
        <span>本次消耗</span>
        <el-input-number v-model="consumeCount" :min="1" :max="consumeBalance?.remaining_lessons || 1" />
        <span>节</span>
      </div>
      <el-input v-model="consumeNote" placeholder="消课备注（选填）" maxlength="255" />
      <template #footer>
        <el-button @click="consumeVisible = false">取消</el-button>
        <el-button type="primary" :loading="consuming" @click="submitConsume">确认消课</el-button>
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
}

.cell-strong {
  font-weight: 600;
  color: #2b2621;
}

.cell-sub {
  font-size: 12px;
  color: #9c9385;
}

.zero-cell {
  color: #c15f2c;
  font-weight: 600;
}

.empty-tip {
  padding: 32px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
}

.consume-row {
  display: flex;
  align-items: center;
  gap: 10px;
  margin: 14px 0;
  font-size: 14px;
  color: #2b2621;
}
</style>

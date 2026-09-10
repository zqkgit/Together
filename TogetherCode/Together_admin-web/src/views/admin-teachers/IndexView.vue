<script setup lang="ts">
import { onMounted, ref } from "vue";
import { Refresh, Search } from "@element-plus/icons-vue";
import { fetchTeacherProfiles, type TeacherProfileItem } from "../../services/admin";
import CertPanel from "./CertPanel.vue";

const activeTab = ref("list");

const loading = ref(false);
const q = ref("");
const certStatus = ref<number | "">("");
const list = ref<TeacherProfileItem[]>([]);

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchTeacherProfiles({
      q: q.value.trim() || undefined,
      cert_status: certStatus.value
    });
    list.value = data.list;
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    loading.value = false;
  }
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-tabs v-model="activeTab" class="page-tabs">
      <el-tab-pane label="老师管理" name="list">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <div class="toolbar-left">
            <el-input
              v-model="q"
              placeholder="搜索姓名 / 手机号"
              clearable
              style="width: 200px"
              :prefix-icon="Search"
              @keyup.enter="loadData"
              @clear="loadData"
            />
            <el-select
              :model-value="certStatus"
              placeholder="认证状态"
              clearable
              style="width: 130px"
              @change="(v: string | number | undefined) => { certStatus = (v === undefined || v === null || v === '' ? '' : Number(v)); loadData(); }"
            >
              <el-option label="已认证" :value="1" />
              <el-option label="未认证" :value="0" />
            </el-select>
            <el-button :icon="Refresh" @click="loadData">查询</el-button>
          </div>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        show-icon
        title="已通过平台认证的老师档案。认证申请在同页「认证申请」Tab 审核，通过后此处生成档案；绑定工作室后可在档案中看到归属。"
        class="flow-alert"
      />

      <el-table :data="list" row-key="teacher_id">
        <el-table-column label="老师" min-width="150">
          <template #default="{ row }">
            <span class="cell-strong">{{ row.real_name }}</span>
            <div class="cell-sub">{{ row.phone }}</div>
          </template>
        </el-table-column>
        <el-table-column label="擅长方向" min-width="160">
          <template #default="{ row }">
            <el-tag
              v-for="subject in row.subjects"
              :key="subject"
              size="small"
              effect="plain"
              class="subject-tag"
            >
              {{ subject }}
            </el-tag>
            <span v-if="!row.subjects.length" class="cell-sub">-</span>
          </template>
        </el-table-column>
        <el-table-column prop="years" label="教龄" width="80" align="center">
          <template #default="{ row }">{{ row.years }} 年</template>
        </el-table-column>
        <el-table-column label="认证状态" width="110">
          <template #default="{ row }">
            <el-tag :type="row.cert_status === 1 ? 'success' : 'info'" effect="light" size="small">
              {{ row.cert_status === 1 ? "已认证" : "未认证" }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="绑定工作室" min-width="160">
          <template #default="{ row }">
            <template v-if="row.studios && row.studios.length">
              <el-tag
                v-for="s in row.studios"
                :key="s.studio_id"
                size="small"
                effect="plain"
                type="primary"
                class="subject-tag"
              >
                {{ s.name }}
              </el-tag>
            </template>
            <span v-else class="cell-sub">未绑定</span>
          </template>
        </el-table-column>
        <el-table-column prop="rating" label="评分" width="70" align="center">
          <template #default="{ row }">{{ Number(row.rating).toFixed(1) }}</template>
        </el-table-column>
        <el-table-column prop="student_count" label="学员数" width="70" align="center" />
        <el-table-column prop="work_count" label="作品数" width="70" align="center" />
        <el-table-column prop="intro" label="简介" min-width="160" show-overflow-tooltip>
          <template #default="{ row }">{{ row.intro || "-" }}</template>
        </el-table-column>
        <el-table-column label="认证时间" width="110">
          <template #default="{ row }">{{ row.created_at.slice(0, 10) }}</template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && list.length === 0" class="empty-tip">暂无老师档案</div>
    </el-card>
      </el-tab-pane>
      <el-tab-pane label="认证申请" name="cert">
        <CertPanel />
      </el-tab-pane>
    </el-tabs>
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

.page-tabs {
  margin-bottom: 4px;
}

.toolbar-left {
  display: flex;
  align-items: center;
  gap: 10px;
}

.flow-alert {
  margin-bottom: 14px;
}

.cell-strong {
  font-weight: 600;
  color: #2b2621;
}

.cell-sub {
  font-size: 12px;
  color: #9c9385;
}

.subject-tag {
  margin-right: 4px;
}

.empty-tip {
  padding: 32px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
}
</style>

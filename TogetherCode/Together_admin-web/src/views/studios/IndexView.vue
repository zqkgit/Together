<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Refresh, Search } from "@element-plus/icons-vue";
import {
  fetchStudios,
  fetchStudioDetail,
  banStudio,
  unbanStudio,
  type StudioItem,
  type StudioDetail
} from "../../services/admin";

const loading = ref(false);
const detailLoading = ref(false);
const total = ref(0);
const page = ref(1);
const size = ref(10);
const keyword = ref("");
const studios = ref<StudioItem[]>([]);

// 详情
const drawerOpen = ref(false);
const detail = ref<StudioDetail | null>(null);

// 封禁
const banVisible = ref(false);
const banReason = ref("");
const banSubmitting = ref(false);
const banTarget = ref<StudioItem | null>(null);

const statusMeta: Record<number, { text: string; type: "warning" | "success" | "danger" }> = {
  0: { text: "待审核", type: "warning" },
  1: { text: "营业中", type: "success" },
  2: { text: "已封禁", type: "danger" }
};

async function loadData() {
  loading.value = true;
  try {
    const response = await fetchStudios({
      page: page.value,
      size: size.value,
      keyword: keyword.value.trim() || undefined
    });
    total.value = response.total;
    studios.value = response.list;
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    loading.value = false;
  }
}

function handleSearch() {
  page.value = 1;
  loadData();
}

function handlePageChange(next: number) {
  page.value = next;
  loadData();
}

async function openDetail(row: StudioItem) {
  drawerOpen.value = true;
  detailLoading.value = true;
  detail.value = null;
  try {
    detail.value = await fetchStudioDetail(row.id);
  } catch {
    drawerOpen.value = false;
  } finally {
    detailLoading.value = false;
  }
}

function openBan(row: StudioItem) {
  banTarget.value = row;
  banReason.value = "";
  banVisible.value = true;
}

async function submitBan() {
  if (!banReason.value.trim()) {
    ElMessage.warning("封禁必须填写原因");
    return;
  }
  if (!banTarget.value) return;
  banSubmitting.value = true;
  try {
    const updated = await banStudio(banTarget.value.id, banReason.value.trim());
    ElMessage.success(`已封禁「${updated.name}」`);
    banVisible.value = false;
    drawerOpen.value = false;
    loadData();
  } catch {
    // 错误提示由拦截器统一处理
  } finally {
    banSubmitting.value = false;
  }
}

async function handleUnban(row: StudioItem) {
  try {
    await ElMessageBox.confirm(
      `确认解除「${row.name}」的封禁？解封后其课程将恢复在售，可正常收单。`,
      "解除封禁",
      {
        confirmButtonText: "确认解封",
        cancelButtonText: "取消",
        type: "warning"
      }
    );
  } catch {
    return;
  }
  try {
    const updated = await unbanStudio(row.id);
    ElMessage.success(`已解除「${updated.name}」封禁`);
    drawerOpen.value = false;
    loadData();
  } catch {
    // 忽略
  }
}

async function handleBanFromDrawer() {
  if (!detail.value) return;
  const row: StudioItem = {
    id: detail.value.studio_id,
    name: detail.value.name,
    city: detail.value.address || "-",
    status: statusMeta[detail.value.status].text,
    status_code: detail.value.status,
    owner: detail.value.owner?.nickname || "-",
    owner_phone: detail.value.owner?.phone || "-",
    courses: detail.value.stats.courses,
    created_at: ""
  };
  openBan(row);
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <span>工作室列表</span>
          <div class="toolbar-right">
            <el-input
              v-model="keyword"
              placeholder="搜索工作室名称 / 地址"
              clearable
              style="width: 240px"
              :prefix-icon="Search"
              @keyup.enter="handleSearch"
              @clear="handleSearch"
            />
            <el-button :icon="Refresh" @click="handleSearch">查询</el-button>
          </div>
        </div>
      </template>

      <el-table :data="studios" row-key="id">
        <el-table-column prop="name" label="工作室" min-width="200">
          <template #default="{ row }">
            <span class="cell-strong">{{ row.name }}</span>
          </template>
        </el-table-column>
        <el-table-column prop="city" label="城市" min-width="140" />
        <el-table-column label="负责人" min-width="180">
          <template #default="{ row }">
            <div>{{ row.owner }}</div>
            <div class="cell-sub">{{ row.owner_phone }}</div>
          </template>
        </el-table-column>
        <el-table-column prop="courses" label="课程数" width="100" align="center" />
        <el-table-column label="状态" width="110">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status_code].type" effect="light">
              {{ statusMeta[row.status_code].text }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="200" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" @click="openDetail(row)">详情</el-button>
            <template v-if="row.status_code === 1">
              <el-button text type="danger" @click="openBan(row)">封禁</el-button>
            </template>
            <el-button
              v-else-if="row.status_code === 2"
              text
              type="success"
              @click="handleUnban(row)"
            >
              解封
            </el-button>
            <span v-else class="cell-sub">待审核</span>
          </template>
        </el-table-column>
      </el-table>

      <div class="pagination-row">
        <el-pagination
          v-model:current-page="page"
          :page-size="size"
          :total="total"
          layout="total, prev, pager, next"
          background
          @current-change="handlePageChange"
        />
      </div>
    </el-card>

    <!-- 工作室详情抽屉 -->
    <el-drawer v-model="drawerOpen" title="工作室详情" size="480px">
      <div v-loading="detailLoading" class="detail-body">
        <template v-if="detail">
          <div class="detail-hero">
            <div class="detail-name">{{ detail.name }}</div>
            <el-tag :type="statusMeta[detail.status].type" effect="light">
              {{ statusMeta[detail.status].text }}
            </el-tag>
            <div v-if="detail.ban_reason" class="ban-tip">
              封禁原因：{{ detail.ban_reason }}
            </div>
          </div>

          <!-- 经营数据 -->
          <div class="stat-grid">
            <div class="stat-cell">
              <div class="stat-num">{{ detail.stats.orders }}</div>
              <div class="stat-cap">订单数</div>
            </div>
            <div class="stat-cell">
              <div class="stat-num stat-gmv">{{ detail.stats.gmv }}</div>
              <div class="stat-cap">累计 GMV</div>
            </div>
            <div class="stat-cell">
              <div class="stat-num">{{ detail.stats.students }}</div>
              <div class="stat-cap">学员数</div>
            </div>
            <div class="stat-cell">
              <div class="stat-num">{{ detail.stats.courses }}</div>
              <div class="stat-cap">课程数</div>
            </div>
          </div>

          <el-descriptions :column="1" border size="small">
            <el-descriptions-item label="负责人">
              {{ detail.owner?.nickname || "-" }}
              <span class="cell-sub">（{{ detail.owner?.phone || "-" }}）</span>
            </el-descriptions-item>
            <el-descriptions-item label="经营地址">{{ detail.address || "-" }}</el-descriptions-item>
            <el-descriptions-item label="联系电话">{{ detail.phone || "-" }}</el-descriptions-item>
            <el-descriptions-item label="营业时间">{{ detail.hours || "-" }}</el-descriptions-item>
            <el-descriptions-item label="机构简介">
              <div class="intro-text">{{ detail.intro || "-" }}</div>
            </el-descriptions-item>
            <el-descriptions-item label="结算费率">{{ (detail.settle_rate * 100).toFixed(0) }}%</el-descriptions-item>
            <el-descriptions-item label="营业执照">
              <span v-if="detail.license" class="link-text">{{ detail.license }}</span>
              <span v-else>-</span>
            </el-descriptions-item>
            <el-descriptions-item v-if="detail.latest_application" label="最新申请">
              v{{ detail.latest_application.version }} ·
              {{ statusMeta[detail.latest_application.status].text }}
              <span class="cell-sub">（{{ detail.latest_application.submitted_at }}）</span>
            </el-descriptions-item>
          </el-descriptions>

          <div class="detail-actions">
            <el-button v-if="detail.status === 1" type="danger" @click="handleBanFromDrawer">
              封禁该工作室
            </el-button>
            <el-button
              v-else-if="detail.status === 2"
              type="success"
              @click="handleUnban({ id: detail.studio_id, name: detail.name } as StudioItem)"
            >
              解除封禁
            </el-button>
          </div>
        </template>
      </div>
    </el-drawer>

    <!-- 封禁对话框 -->
    <el-dialog v-model="banVisible" title="封禁工作室" width="460px">
      <el-alert
        type="error"
        :closable="false"
        show-icon
        title="封禁后该工作室课程全部下架、停收新单，存量订单履约不受影响。"
        class="ban-alert"
      />
      <el-input
        v-model="banReason"
        type="textarea"
        :rows="3"
        maxlength="255"
        show-word-limit
        placeholder="请填写封禁原因（必填），将记录在案并展示给工作室"
      />
      <template #footer>
        <el-button @click="banVisible = false">取消</el-button>
        <el-button type="danger" :loading="banSubmitting" @click="submitBan">
          确认封禁
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

.toolbar-right {
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

.pagination-row {
  display: flex;
  justify-content: flex-end;
  padding-top: 16px;
}

.detail-body {
  min-height: 200px;
}

.detail-hero {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-bottom: 18px;
}

.detail-name {
  font-size: 20px;
  font-weight: 700;
  color: #2b2621;
  font-family: "Noto Serif SC", "Songti SC", serif;
}

.ban-tip {
  padding: 10px 12px;
  background: #fdeee9;
  border-radius: 8px;
  font-size: 13px;
  color: #c15f2c;
}

.stat-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 10px;
  margin-bottom: 18px;
}

.stat-cell {
  background: #faf7f1;
  border: 1px solid #eee7dd;
  border-radius: 10px;
  padding: 12px 8px;
  text-align: center;
}

.stat-num {
  font-size: 20px;
  font-weight: 700;
  color: #2f5d45;
}

.stat-gmv {
  font-size: 16px;
}

.stat-cap {
  margin-top: 4px;
  font-size: 12px;
  color: #726a60;
}

.intro-text {
  line-height: 1.6;
  color: #2b2621;
  white-space: pre-wrap;
}

.link-text {
  color: #2f5d45;
}

.detail-actions {
  margin-top: 24px;
}

.ban-alert {
  margin-bottom: 14px;
}
</style>

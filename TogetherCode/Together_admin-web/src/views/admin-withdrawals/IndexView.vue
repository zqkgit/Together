<script setup lang="ts">
import { timeFormatter } from "../../utils/format";
import { onMounted, ref } from "vue";
import { Refresh, Download } from "@element-plus/icons-vue";
import { exportCsv } from "../../utils/exportCsv";
import { fetchWithdrawals, fetchWithdrawalsExport, type WithdrawalItem } from "../../services/admin";

const loading = ref(false);
const list = ref<WithdrawalItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);
const filterStatus = ref<number | "">("");

const statusMeta: Record<number, { text: string; type: "warning" | "success" | "danger" }> = {
  0: { text: "待工作室审核", type: "warning" },
  1: { text: "待推广人确认", type: "warning" },
  2: { text: "已驳回", type: "danger" },
  3: { text: "已完成", type: "success" }
};

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchWithdrawals({
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
  filterStatus.value = "";
  page.value = 1;
  loadData();
}

// 导出 CSV（全量，按当前筛选）
const exporting = ref(false);
async function exportWithdrawals() {
  exporting.value = true;
  try {
    const res: any = await fetchWithdrawalsExport({ status: filterStatus.value || undefined });
    const rows: any[] = Array.isArray(res.list) ? res.list : [];
    exportCsv("佣金领取单", [
      { key: "withdraw_id", label: "领取单号" },
      { key: "studio", label: "工作室" },
      { key: "user", label: "推广人" },
      { key: "phone", label: "手机号" },
      { key: "amount", label: "领取金额(元)" },
      { key: "method", label: "打款方式" },
      { key: "status_text", label: "状态" },
      { key: "created_at", label: "申请时间" },
      { key: "processed_at", label: "打款时间" },
      { key: "confirmed_at", label: "确认时间" }
    ], rows.map((r: any) => ({
      ...r,
      studio: r.studio?.name ?? "-",
      user: r.user?.nickname ?? "-",
      phone: r.user?.phone ?? "-",
      method: r.method_text ?? r.method ?? "-",
      created_at: r.created_at ? timeFormatter(null, null, r.created_at) : "-",
      processed_at: r.processed_at ? timeFormatter(null, null, r.processed_at) : "-",
      confirmed_at: r.confirmed_at ? timeFormatter(null, null, r.confirmed_at) : "-"
    })));
  } catch {
    // 拦截器统一提示
  } finally {
    exporting.value = false;
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
              <el-radio-button :value="0">待工作室审核</el-radio-button>
              <el-radio-button :value="1">待推广人确认</el-radio-button>
              <el-radio-button :value="3">已完成</el-radio-button>
              <el-radio-button :value="2">已驳回</el-radio-button>
            </el-radio-group>
          </div>
          <div>
            <el-button :icon="Refresh" circle @click="onReset" />
            <el-button type="primary" plain :icon="Download" :loading="exporting" @click="exportWithdrawals">导出 CSV</el-button>
          </div>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        show-icon
        title="佣金（分销返利）由各工作室在线下审核并打款给推广人，上传打款凭证后由推广人在 App 确认到账。平台不经手任何资金，本页仅作只读监督与数据导出。"
        style="margin-bottom: 16px"
      />

      <el-table :data="list">
        <el-table-column label="工作室" min-width="140">
          <template #default="{ row }">{{ row.studio?.name || "-" }}</template>
        </el-table-column>
        <el-table-column label="推广人" width="130">
          <template #default="{ row }">{{ row.user?.nickname || "-" }}</template>
        </el-table-column>
        <el-table-column label="手机号" width="130">
          <template #default="{ row }">{{ row.user?.phone || "-" }}</template>
        </el-table-column>
        <el-table-column label="金额" width="110">
          <template #default="{ row }"><b>¥{{ Number(row.amount).toFixed(2) }}</b></template>
        </el-table-column>
        <el-table-column label="打款方式" width="110">
          <template #default="{ row }">{{ row.method ? row.method_text : "-" }}</template>
        </el-table-column>
        <el-table-column label="打款凭证" width="100" align="center">
          <template #default="{ row }">
            <div v-if="(row.voucher_images || []).length" class="voucher-cell">
              <el-image
                v-for="(img, idx) in (row.voucher_images || []).slice(0, 3)"
                :key="img"
                :src="img"
                :preview-src-list="row.voucher_images"
                :initial-index="idx"
                fit="cover"
                class="voucher-thumb"
              />
              <span v-if="(row.voucher_images || []).length > 3" class="muted">+{{ row.voucher_images.length - 3 }}</span>
            </div>
            <span v-else-if="row.method === 'cash'" class="muted">现金</span>
            <span v-else class="muted">-</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="120">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status]?.type" size="small">{{ row.status_text }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" :formatter="timeFormatter" label="申请时间" width="170" />
        <el-table-column prop="confirmed_at" :formatter="timeFormatter" label="确认时间" width="170" />
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
.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}
.muted {
  font-size: 12px;
  color: #9c9385;
}
.voucher-cell {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
}
.voucher-thumb {
  width: 34px;
  height: 34px;
  border-radius: 6px;
  border: 1px solid #eee5d8;
}
.pager {
  margin-top: 16px;
  justify-content: flex-end;
}
</style>

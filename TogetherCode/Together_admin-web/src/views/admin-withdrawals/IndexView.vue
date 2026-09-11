<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage, ElMessageBox } from "element-plus";
import { Refresh } from "@element-plus/icons-vue";
import { fetchWithdrawals, reviewWithdrawal, type WithdrawalItem } from "../../services/admin";

const loading = ref(false);
const list = ref<WithdrawalItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);
const filterStatus = ref<number | "">("");

const statusMeta: Record<number, { text: string; type: "warning" | "primary" | "success" | "danger" }> = {
  1: { text: "待审核", type: "warning" },
  2: { text: "处理中", type: "primary" },
  3: { text: "已打款", type: "success" },
  4: { text: "已驳回", type: "danger" }
};

const methodMeta: Record<string, { text: string; type: "primary" | "success" | "warning" }> = {
  wechat: { text: "微信", type: "success" },
  alipay: { text: "支付宝", type: "primary" },
  bank: { text: "银行卡", type: "warning" }
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

async function onReview(row: WithdrawalItem, action: "approve" | "reject") {
  const actionText = action === "approve" ? "通过并打款" : "驳回";
  try {
    await ElMessageBox.confirm(
      action === "approve"
        ? `确认对 ${row.user?.nickname || row.user?.phone || "该用户"} 的提现 ¥${row.amount.toFixed(2)} 通过打款？`
        : `确认驳回该笔提现？驳回后 ¥${row.amount.toFixed(2)} 将退回用户余额。`,
      `${actionText}`,
      { type: action === "approve" ? "success" : "warning", confirmButtonText: actionText, cancelButtonText: "取消" }
    );
    await reviewWithdrawal(row.withdraw_id, { action });
    ElMessage.success(action === "approve" ? "已通过并标记打款" : "已驳回，金额退回余额");
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
              <el-radio-button :value="1">待审核</el-radio-button>
              <el-radio-button :value="2">处理中</el-radio-button>
              <el-radio-button :value="3">已打款</el-radio-button>
              <el-radio-button :value="4">已驳回</el-radio-button>
            </el-radio-group>
          </div>
          <div>
            <el-button :icon="Refresh" circle @click="onReset" />
          </div>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        show-icon
        title="用户在 App 端申请提现后，平台在此审核。通过则标记打款；驳回则金额自动退回用户余额。"
        style="margin-bottom: 16px"
      />

      <el-table :data="list">
        <el-table-column label="用户" width="150">
          <template #default="{ row }">{{ row.user?.nickname || row.user?.phone || "-" }}</template>
        </el-table-column>
        <el-table-column label="手机号" width="130">
          <template #default="{ row }">{{ row.user?.phone || "-" }}</template>
        </el-table-column>
        <el-table-column label="金额" width="110">
          <template #default="{ row }"><b>¥{{ row.amount.toFixed(2) }}</b></template>
        </el-table-column>
        <el-table-column label="收款方式" width="110">
          <template #default="{ row }">
            <el-tag :type="methodMeta[row.method]?.type || 'info'" size="small">{{ methodMeta[row.method]?.text || row.method }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="account" label="收款账号" min-width="160" show-overflow-tooltip />
        <el-table-column label="状态" width="100">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status]?.type" size="small">{{ row.status_text }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="created_at" label="申请时间" width="170" />
        <el-table-column label="操作" width="150" fixed="right">
          <template #default="{ row }">
            <template v-if="row.status === 1">
              <el-button link type="success" @click="onReview(row, 'approve')">通过</el-button>
              <el-button link type="danger" @click="onReview(row, 'reject')">驳回</el-button>
            </template>
            <span v-else class="muted">{{ row.reviewed_at || "-" }}</span>
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

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { fetchSettlements, type SettlementsData } from "../../services/admin";

const loading = ref(false);
const settlements = ref<SettlementsData>({
  summary: {
    pendingNetAmount: "",
    pendingNetTrend: "",
    retryCount: 0,
    retryHint: ""
  },
  list: []
});

const summary = computed(() => settlements.value.summary);

async function loadData() {
  loading.value = true;
  try {
    settlements.value = await fetchSettlements();
  } finally {
    loading.value = false;
  }
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <div class="panel-grid panel-grid-2">
      <el-card v-loading="loading" shadow="hover">
        <div class="stat-label">本月待结算净额</div>
        <div class="stat-value">{{ summary.pendingNetAmount }}</div>
        <div class="stat-trend">{{ summary.pendingNetTrend }}</div>
      </el-card>

      <el-card v-loading="loading" shadow="hover">
        <div class="stat-label">异常重打笔数</div>
        <div class="stat-value">{{ summary.retryCount }}</div>
        <div class="stat-trend">{{ summary.retryHint }}</div>
      </el-card>
    </div>

    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <span>月结算单</span>
          <el-button type="primary">生成结算单</el-button>
        </div>
      </template>

      <el-table :data="settlements.list">
        <el-table-column prop="studio" label="工作室" min-width="220" />
        <el-table-column prop="period" label="结算周期" width="140" />
        <el-table-column prop="income" label="收入" width="140" />
        <el-table-column prop="refund" label="退款" width="140" />
        <el-table-column prop="payable" label="应付金额" width="140" />
        <el-table-column label="操作" width="180">
          <template #default>
            <el-button text type="primary">详情</el-button>
            <el-button text>打款</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

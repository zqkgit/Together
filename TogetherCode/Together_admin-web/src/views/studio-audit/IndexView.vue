<script setup lang="ts">
import { onMounted, ref } from "vue";
import { Refresh } from "@element-plus/icons-vue";
import { fetchStudioAudit, type AuditItem } from "../../services/studio";

const loading = ref(false);
const list = ref<AuditItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);
const filterAction = ref("");

const actionMeta: Record<string, { text: string; type: "primary" | "success" | "warning" | "danger" | "info" }> = {
  "studio.profile": { text: "修改资料", type: "info" },
  "course.create": { text: "新建课程", type: "primary" },
  "course.update": { text: "编辑课程", type: "primary" },
  "class.create": { text: "新建班级", type: "primary" },
  "class.update": { text: "编辑班级", type: "primary" },
  "schedule.create": { text: "新建排课", type: "primary" },
  "schedule.update": { text: "编辑排课", type: "primary" },
  "student.create": { text: "新增学员", type: "success" },
  "order.create": { text: "创建订单", type: "success" },
  "refund.review": { text: "审核退款", type: "warning" },
  "studio.refund.review": { text: "审核退款", type: "warning" },
  "teacher.bind": { text: "绑定老师", type: "primary" },
  "teacher.unbind": { text: "解绑老师", type: "danger" },
  "studio.account.upsert": { text: "维护结算账户", type: "warning" },
  "studio.staff.create": { text: "新增员工", type: "primary" },
  "studio.staff.enable": { text: "启用员工", type: "success" },
  "studio.staff.disable": { text: "停用员工", type: "danger" }
};

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchStudioAudit({
      page: page.value,
      page_size: pageSize.value,
      action: filterAction.value || undefined
    });
    list.value = data.list;
    total.value = data.total;
  } catch {
    // 拦截器统一提示
  } finally {
    loading.value = false;
  }
}

function onReset() {
  filterAction.value = "";
  page.value = 1;
  loadData();
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <div class="filter-row">
            <el-select v-model="filterAction" placeholder="按操作类型筛选" clearable style="width: 200px" @change="loadData">
              <el-option v-for="(meta, key) in actionMeta" :key="key" :label="meta.text" :value="key" />
            </el-select>
          </div>
          <div>
            <el-button :icon="Refresh" circle @click="onReset" />
          </div>
        </div>
      </template>

      <el-table :data="list">
        <el-table-column prop="actor_name" label="操作人" width="130" />
        <el-table-column label="操作" width="140">
          <template #default="{ row }">
            <el-tag :type="actionMeta[row.action]?.type || 'info'" size="small">{{ actionMeta[row.action]?.text || row.action }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="target_type" label="对象类型" width="110" />
        <el-table-column prop="target_id" label="对象 ID" width="170" show-overflow-tooltip />
        <el-table-column prop="detail" label="操作详情" min-width="180" show-overflow-tooltip />
        <el-table-column prop="ip" label="IP" width="130" />
        <el-table-column prop="created_at" label="时间" width="170" />
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

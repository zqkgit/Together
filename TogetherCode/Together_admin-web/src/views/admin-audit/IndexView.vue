<script setup lang="ts">
import { timeFormatter } from "../../utils/format";
import { onMounted, ref } from "vue";
import { Refresh } from "@element-plus/icons-vue";
import { fetchAdminAudit, type AuditItem } from "../../services/admin";

const loading = ref(false);
const list = ref<AuditItem[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);
const filterAction = ref("");
const filterTarget = ref("");

const targetMeta: Record<string, string> = {
  studio: "工作室",
  teacher_application: "老师认证",
  course_review: "课程评价",
  settlement: "结算单",
  report: "举报",
  post: "帖子",
  announcement: "公告",
  admin_account: "员工账号",
  withdrawal: "提现",
  refund: "退款"
};

const actionMeta: Record<string, { text: string; type: "primary" | "success" | "warning" | "danger" | "info" }> = {
  "studio.ban": { text: "封禁工作室", type: "danger" },
  "studio.unban": { text: "解封工作室", type: "success" },
  "studio.review": { text: "审核工作室", type: "warning" },
  "teacher_application.approve": { text: "通过老师认证", type: "success" },
  "teacher_application.reject": { text: "驳回老师认证", type: "danger" },
  "course_review.approve": { text: "通过评价审核", type: "success" },
  "course_review.reject": { text: "驳回评价审核", type: "danger" },
  "settlement.generate": { text: "生成结算", type: "primary" },
  "settlement.payout": { text: "结算打款", type: "primary" },
  "settlement.reprocess": { text: "结算重打", type: "danger" },
  "report.handle": { text: "处置举报", type: "warning" },
  "post.moderate": { text: "内容下架", type: "danger" },
  "post.restore": { text: "内容恢复", type: "success" },
  "platform.config": { text: "修改配置", type: "info" },
  "announcement.create": { text: "发布公告", type: "primary" },
  "announcement.publish": { text: "公告上架", type: "success" },
  "announcement.off": { text: "公告下架", type: "info" },
  "staff.create": { text: "新增员工", type: "primary" },
  "staff.enable": { text: "启用员工", type: "success" },
  "staff.disable": { text: "停用员工", type: "danger" },
  "withdrawal.approve": { text: "通过提现", type: "success" },
  "withdrawal.reject": { text: "驳回提现", type: "danger" }
};



async function loadData() {
  loading.value = true;
  try {
    const data = await fetchAdminAudit({
      page: page.value,
      page_size: pageSize.value,
      action: filterAction.value || undefined,
      target_type: filterTarget.value || undefined
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
  filterTarget.value = "";
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
            <el-select v-model="filterAction" placeholder="按操作类型筛选" clearable style="width: 190px" @change="loadData">
              <el-option v-for="(meta, key) in actionMeta" :key="key" :label="meta.text" :value="key" />
            </el-select>
            <el-select v-model="filterTarget" placeholder="按对象类型筛选" clearable style="width: 150px" @change="loadData">
              <el-option v-for="(text, key) in targetMeta" :key="key" :label="text" :value="key" />
            </el-select>
          </div>
          <div>
            <el-button :icon="Refresh" circle @click="onReset" />
          </div>
        </div>
      </template>

      <el-table :data="list">
        <el-table-column prop="actor_name" label="操作人" width="130" />
        <el-table-column label="操作" width="150">
          <template #default="{ row }">
            <el-tag :type="actionMeta[row.action]?.type || 'info'" size="small">{{ actionMeta[row.action]?.text || row.action }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="对象" width="100">
          <template #default="{ row }">{{ targetMeta[row.target_type] || row.target_type || "-" }}</template>
        </el-table-column>
        <el-table-column prop="target_id" label="对象 ID" width="170" show-overflow-tooltip />
        <el-table-column prop="ip" label="IP" width="130" />
        <el-table-column prop="created_at" :formatter="timeFormatter" label="时间" width="170" />
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

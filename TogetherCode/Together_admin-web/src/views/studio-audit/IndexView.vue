<script setup lang="ts">
import { timeFormatter } from "../../utils/format";
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
  "schedule.batch_create": { text: "批量排课", type: "primary" },
  "schedule.delete": { text: "删除排课", type: "danger" },
  "schedule.attendance": { text: "消课签到", type: "success" },
  "student.create": { text: "新增学员", type: "success" },
  "student.consume": { text: "手动消课", type: "warning" },
  "order.create": { text: "创建订单", type: "success" },
  "order.payment_confirm": { text: "确认收款", type: "success" },
  "order.payment_reject": { text: "驳回凭证", type: "danger" },
  "order.cancel": { text: "取消订单", type: "danger" },
  "refund.review": { text: "审核退款", type: "warning" },
  "studio.refund.review": { text: "审核退款", type: "warning" },
  "studio.refund.confirm": { text: "确认打款", type: "success" },
  "teacher.review": { text: "审核老师", type: "warning" },
  "teacher.bind": { text: "绑定老师", type: "primary" },
  "teacher.unbind": { text: "解绑老师", type: "danger" },
  "leave.review": { text: "审批请假", type: "warning" },
  "leave.makeup": { text: "绑定补课", type: "primary" },
  "studio.account.upsert": { text: "维护结算账户", type: "warning" },
  "studio.staff.create": { text: "新增员工", type: "primary" },
  "studio.staff.enable": { text: "启用员工", type: "success" },
  "studio.staff.disable": { text: "停用员工", type: "danger" },
  "commission.approve": { text: "审批领取单", type: "success" },
  "commission.reject": { text: "驳回领取单", type: "danger" },
  "commission.set_rate": { text: "设置返利比例", type: "warning" },
  // 平台端操作（工作室审计日志中可能出现）
  "studio.ban": { text: "封禁工作室", type: "danger" },
  "studio.unban": { text: "解封工作室", type: "success" },
  "teacher_application.approve": { text: "通过老师申请", type: "success" },
  "teacher_application.reject": { text: "驳回老师申请", type: "danger" },
  "course_review.approve": { text: "通过评价审核", type: "success" },
  "course_review.reject": { text: "驳回评价审核", type: "danger" }
};

// 对象类型中文映射
const targetTypeMeta: Record<string, string> = {
  studio: "工作室",
  course: "课程",
  class: "班级",
  schedule: "排课",
  order: "订单",
  refund: "退款单",
  teacher: "老师",
  teacher_application: "老师申请",
  leave: "请假",
  studio_account: "结算账户",
  admin_account: "员工账号",
  student_order: "学员订单",
  withdrawal: "领取单",
  announcement: "公告",
  report: "举报",
  post: "帖子",
  settlement: "结算单",
  course_review: "课程评价"
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
        <el-table-column prop="actor_name" label="操作人" width="100" />
        <el-table-column label="操作" width="130">
          <template #default="{ row }">
            <el-tag :type="actionMeta[row.action]?.type || 'info'" size="small">{{ actionMeta[row.action]?.text || row.action }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column label="对象" width="100">
          <template #default="{ row }">{{ targetTypeMeta[row.target_type] || row.target_type || "-" }}</template>
        </el-table-column>
        <el-table-column prop="target_id" label="对象 ID" width="160" show-overflow-tooltip />
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

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { fetchStudioProfile, type StudioProfileInfo } from "../../services/studio";
import { useAuthStore } from "../../stores/auth";

const authStore = useAuthStore();
const loading = ref(false);
const profile = ref<StudioProfileInfo | null>(null);

const greeting = computed(() => {
  const hour = new Date().getHours();
  if (hour < 12) return "上午好";
  if (hour < 18) return "下午好";
  return "晚上好";
});

const todoModules = [
  { label: "课程管理", desc: "发布 / 编辑课程，管理课时包与上下架" },
  { label: "班级与排课", desc: "创建班级，周课表排课，冲突检测" },
  { label: "学员管理", desc: "学员档案、课时余额、手动消课" },
  { label: "订单与退款", desc: "订单查询、退款审核工作流" },
  { label: "请假审批", desc: "家长请假申请审批与补课绑定" },
  { label: "财务对账", desc: "营收 / 退款报表，结算单导出" }
];

onMounted(async () => {
  loading.value = true;
  try {
    profile.value = await fetchStudioProfile();
  } catch {
    // 后端未就绪时保持 null，页面仍可展示
  } finally {
    loading.value = false;
  }
});
</script>

<template>
  <div class="page-stack">
    <el-card shadow="never" class="welcome-card">
      <div class="welcome-row">
        <div class="welcome-copy">
          <h2>{{ greeting }}，{{ profile?.name || authStore.scopeLabel || "工作室" }}</h2>
          <p>这里是「艺启」工作室经营后台，正在搭建中。以下模块即将上线：</p>
        </div>
        <el-tag v-if="loading" type="info" effect="plain">加载中…</el-tag>
        <el-tag v-else type="success" effect="plain">已认证机构</el-tag>
      </div>
    </el-card>

    <div class="module-grid">
      <el-card
        v-for="mod in todoModules"
        :key="mod.label"
        shadow="hover"
        class="module-card"
      >
        <div class="module-icon">{{ mod.label.slice(0, 1) }}</div>
        <div class="module-name">{{ mod.label }}</div>
        <div class="module-desc">{{ mod.desc }}</div>
        <el-tag size="small" type="info" effect="plain">即将上线</el-tag>
      </el-card>
    </div>
  </div>
</template>

<style scoped>
.welcome-card {
  border-radius: 16px;
}

.welcome-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  flex-wrap: wrap;
}

.welcome-copy h2 {
  margin: 0 0 8px;
  font-family: "Noto Serif SC", "Songti SC", serif;
  font-size: 22px;
  color: #2b2621;
}

.welcome-copy p {
  margin: 0;
  font-size: 14px;
  color: #726a60;
}

.module-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 16px;
}

.module-card {
  border-radius: 16px;
}

.module-icon {
  width: 40px;
  height: 40px;
  border-radius: 12px;
  background: #f5ebdc;
  color: #a87a3e;
  display: grid;
  place-items: center;
  font-size: 18px;
  font-weight: 700;
  margin-bottom: 14px;
}

.module-name {
  font-size: 15px;
  font-weight: 600;
  color: #2b2621;
  margin-bottom: 6px;
}

.module-desc {
  font-size: 13px;
  color: #726a60;
  line-height: 1.6;
  margin-bottom: 12px;
}

@media (max-width: 900px) {
  .module-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 600px) {
  .module-grid {
    grid-template-columns: 1fr;
  }
}
</style>

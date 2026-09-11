<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { fetchPlatformConfig, updatePlatformConfig, type PlatformConfigData } from "../../services/admin";

const loading = ref(false);
const saving = ref(false);
const configs = ref<Record<string, string | number>>({});
const metaMap = ref<Record<string, string>>({});

async function loadData() {
  loading.value = true;
  try {
    const data: PlatformConfigData = await fetchPlatformConfig();
    configs.value = { ...data.configs };
    metaMap.value = {};
    data.list.forEach((item) => {
      metaMap.value[item.config_key] = item.description;
    });
  } catch {
    // 拦截器统一提示
  } finally {
    loading.value = false;
  }
}

const keys = ref<string[]>([]);

async function addKey() {
  const key = prompt("新增配置项 key（如 withdraw_min_amount）：");
  if (!key || !key.trim()) return;
  if (key in configs.value) {
    ElMessage.warning("该配置项已存在");
    return;
  }
  configs.value = { ...configs.value, [key.trim()]: "" };
  keys.value = Object.keys(configs.value);
}

function removeKey(key: string) {
  const next = { ...configs.value };
  delete next[key];
  configs.value = next;
  keys.value = Object.keys(configs.value);
}

async function save() {
  saving.value = true;
  try {
    const normalized: Record<string, string | number> = {};
    for (const [k, v] of Object.entries(configs.value)) {
      normalized[k] = typeof v === "string" && v.trim() !== "" && !Number.isNaN(Number(v)) ? Number(v) : v;
    }
    const result = await updatePlatformConfig(normalized);
    ElMessage.success(`已保存 ${result.updated.length} 项配置`);
    loadData();
  } catch {
    // 拦截器统一提示
  } finally {
    saving.value = false;
  }
}

onMounted(async () => {
  await loadData();
  keys.value = Object.keys(configs.value);
});
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <span class="panel-title">平台配置</span>
          <div>
            <el-button @click="addKey">+ 新增配置项</el-button>
            <el-button type="primary" :loading="saving" @click="save">保存全部</el-button>
          </div>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        show-icon
        title="配置以整包方式保存：新增的 key 会被保存，删除的 key 会被移除。数值型配置将自动转为数字存储。"
        style="margin-bottom: 16px"
      />

      <div class="config-list">
        <div v-for="key in keys" :key="key" class="config-row">
          <div class="config-meta">
            <div class="config-key">{{ key }}</div>
            <div class="config-desc">{{ metaMap[key] || "自定义配置项" }}</div>
          </div>
          <el-input v-model="configs[key]" placeholder="配置值" style="max-width: 420px" />
          <el-button link type="danger" @click="removeKey(key)">删除</el-button>
        </div>
        <el-empty v-if="!keys.length" description="暂无配置项，点击右上角新增" :image-size="72" />
      </div>
    </el-card>
  </div>
</template>

<style scoped>
.config-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}
.config-row {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 12px 16px;
  border: 1px solid var(--el-border-color-lighter);
  border-radius: 8px;
}
.config-meta {
  flex: 1;
  min-width: 160px;
}
.config-key {
  font-weight: 600;
  font-family: monospace;
}
.config-desc {
  font-size: 12px;
  color: var(--el-text-color-secondary);
}
</style>

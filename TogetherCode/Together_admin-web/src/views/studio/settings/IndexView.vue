<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { fetchStudioProfile, updateStudioProfile, type StudioProfileInfo } from "../../../services/studio";

const loading = ref(false);
const saving = ref(false);
const profile = ref<StudioProfileInfo | null>(null);
const form = ref({
  name: "",
  intro: "",
  address: "",
  phone: "",
  hours: "",
  type_tags: "",
  license: "",
  permit: ""
});

async function loadData() {
  loading.value = true;
  try {
    profile.value = await fetchStudioProfile();
    const p = profile.value;
    form.value = {
      name: p.name || "",
      intro: p.intro || "",
      address: p.address || "",
      phone: p.phone || "",
      hours: p.hours || "",
      type_tags: (p.type_tags || []).join("、"),
      license: p.license || "",
      permit: p.permit || ""
    };
  } catch {
    // 忽略
  } finally {
    loading.value = false;
  }
}

async function save() {
  if (!form.value.name.trim()) {
    ElMessage.warning("机构名称不能为空");
    return;
  }
  saving.value = true;
  try {
    profile.value = await updateStudioProfile({
      name: form.value.name.trim(),
      intro: form.value.intro.trim() || undefined,
      address: form.value.address.trim() || undefined,
      phone: form.value.phone.trim() || undefined,
      hours: form.value.hours.trim() || undefined,
      type_tags: form.value.type_tags
        ? form.value.type_tags.split(/[、,，]/).map((s) => s.trim()).filter(Boolean)
        : [],
      license: form.value.license.trim() || undefined,
      permit: form.value.permit.trim() || undefined
    });
    ElMessage.success("工作室资料已保存");
  } catch {
    // 忽略
  } finally {
    saving.value = false;
  }
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <span>工作室设置</span>
          <el-button type="primary" :loading="saving" @click="save">保存修改</el-button>
        </div>
      </template>

      <div v-if="profile" class="profile-top">
        <el-descriptions :column="2" border>
          <el-descriptions-item label="机构名称">
            <span class="cell-strong">{{ profile.name }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="结算费率">{{ (profile.settle_rate * 100).toFixed(0) }}%</el-descriptions-item>
          <el-descriptions-item label="认证状态">
            <el-tag :type="profile.status === 1 ? 'success' : 'warning'" effect="light">
              {{ profile.status === 1 ? "已认证" : "待认证" }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="负责人">{{ profile.owner?.nickname || "-" }}</el-descriptions-item>
        </el-descriptions>
      </div>

      <el-form v-if="profile" label-width="100px" class="profile-form">
        <el-form-item label="机构名称" required>
          <el-input v-model="form.name" maxlength="120" />
        </el-form-item>
        <el-form-item label="机构简介">
          <el-input v-model="form.intro" type="textarea" :rows="3" maxlength="500" show-word-limit />
        </el-form-item>
        <el-form-item label="经营地址">
          <el-input v-model="form.address" maxlength="255" />
        </el-form-item>
        <el-form-item label="联系电话">
          <el-input v-model="form.phone" maxlength="20" />
        </el-form-item>
        <el-form-item label="营业时间">
          <el-input v-model="form.hours" placeholder="如：周一至周日 09:00-21:00" maxlength="120" />
        </el-form-item>
        <el-form-item label="课程类型">
          <el-input v-model="form.type_tags" placeholder="多个用顿号分隔，如：美术、书法" />
        </el-form-item>
        <el-form-item label="营业执照">
          <el-input v-model="form.license" placeholder="执照编号或图片链接" />
        </el-form-item>
        <el-form-item label="办学许可">
          <el-input v-model="form.permit" placeholder="许可编号或图片链接" />
        </el-form-item>
      </el-form>
    </el-card>
  </div>
</template>

<style scoped>
.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.cell-strong {
  font-weight: 600;
  color: #2b2621;
}

.profile-top {
  margin-bottom: 24px;
}

.profile-form {
  max-width: 720px;
}
</style>

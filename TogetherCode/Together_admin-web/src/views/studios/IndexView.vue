<script setup lang="ts">
import { onMounted, ref } from "vue";
import { fetchStudios, type StudioItem } from "../../services/admin";

const loading = ref(false);
const studios = ref<StudioItem[]>([]);

async function loadData() {
  loading.value = true;
  try {
    studios.value = await fetchStudios();
  } finally {
    loading.value = false;
  }
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <span>工作室列表</span>
          <el-button type="primary">新增工作室</el-button>
        </div>
      </template>

      <el-table :data="studios">
        <el-table-column prop="name" label="工作室" min-width="220" />
        <el-table-column prop="city" label="城市" width="120" />
        <el-table-column prop="courses" label="课程数" width="120" />
        <el-table-column label="状态" width="140">
          <template #default="{ row }">
            <el-tag :type="row.status === '营业中' ? 'success' : 'warning'">
              {{ row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="180">
          <template #default>
            <el-button text type="primary">查看</el-button>
            <el-button text>编辑</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

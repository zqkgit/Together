<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { fetchReviews, type ReviewItem } from "../../services/admin";

const loading = ref(false);
const total = ref(0);
const reviews = ref<ReviewItem[]>([]);

const totalText = computed(() => `待处理 ${total.value}`);

async function loadData() {
  loading.value = true;
  try {
    const response = await fetchReviews();
    total.value = response.total;
    reviews.value = response.list;
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
          <span>认证审核队列</span>
          <el-tag effect="plain" type="warning">{{ totalText }}</el-tag>
        </div>
      </template>

      <el-table :data="reviews">
        <el-table-column prop="name" label="名称" min-width="180" />
        <el-table-column prop="type" label="类型" width="140" />
        <el-table-column prop="studio" label="所属工作室" min-width="180" />
        <el-table-column prop="submittedAt" label="提交时间" width="180" />
        <el-table-column label="操作" width="180">
          <template #default>
            <el-button text type="success">通过</el-button>
            <el-button text type="danger">驳回</el-button>
          </template>
        </el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

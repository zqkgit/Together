<script setup lang="ts">
import { onMounted, ref } from "vue";
import { ElMessage } from "element-plus";
import { Plus, Refresh } from "@element-plus/icons-vue";
import { fetchStudioAccounts, upsertStudioAccount, type StudioAccountItem } from "../../services/studio";

const loading = ref(false);
const list = ref<StudioAccountItem[]>([]);
const total = ref(0);

async function loadData() {
  loading.value = true;
  try {
    const data = await fetchStudioAccounts();
    list.value = data.list;
    total.value = data.total;
  } catch {
    // 拦截器统一提示
  } finally {
    loading.value = false;
  }
}

const accountTypeMeta: Record<string, { text: string; type: "primary" | "success" | "warning" }> = {
  bank: { text: "银行卡", type: "primary" },
  wechat: { text: "微信", type: "success" },
  alipay: { text: "支付宝", type: "warning" }
};

// 编辑弹窗
const editVisible = ref(false);
const saving = ref(false);
const form = ref<{ account_id?: string; account_type: StudioAccountItem["account_type"]; account_name: string; account_no: string; bank_name: string }>({
  account_type: "bank",
  account_name: "",
  account_no: "",
  bank_name: ""
});

function openCreate() {
  form.value = { account_type: "bank", account_name: "", account_no: "", bank_name: "" };
  editVisible.value = true;
}

function openEdit(row: StudioAccountItem) {
  form.value = {
    account_id: row.account_id,
    account_type: row.account_type,
    account_name: row.account_name,
    account_no: row.account_no,
    bank_name: row.bank_name || ""
  };
  editVisible.value = true;
}

async function submit() {
  if (!form.value.account_name.trim() || !form.value.account_no.trim()) {
    ElMessage.warning("请填写账户名与账号");
    return;
  }
  if (form.value.account_type === "bank" && !form.value.bank_name.trim()) {
    ElMessage.warning("请填写开户行");
    return;
  }
  saving.value = true;
  try {
    await upsertStudioAccount({
      account_id: form.value.account_id,
      account_type: form.value.account_type,
      account_name: form.value.account_name.trim(),
      account_no: form.value.account_no.trim(),
      bank_name: form.value.account_type === "bank" ? form.value.bank_name.trim() : undefined
    });
    ElMessage.success(form.value.account_id ? "账户已更新" : "账户已绑定");
    editVisible.value = false;
    loadData();
  } catch {
    // 拦截器统一提示
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
          <span class="panel-title">结算账户（{{ total }}）</span>
          <div>
            <el-button :icon="Refresh" circle @click="loadData" />
            <el-button type="primary" :icon="Plus" @click="openCreate">绑定账户</el-button>
          </div>
        </div>
      </template>

      <el-alert
        type="info"
        :closable="false"
        show-icon
        title="结算账户用于接收平台打款。首个绑定的账户自动设为默认收款账户；默认账户可编辑替换。"
        style="margin-bottom: 16px"
      />

      <el-table :data="list">
        <el-table-column label="账户类型" width="110">
          <template #default="{ row }">
            <el-tag :type="accountTypeMeta[row.account_type]?.type" size="small">{{ accountTypeMeta[row.account_type]?.text }}</el-tag>
          </template>
        </el-table-column>
        <el-table-column prop="account_name" label="账户名" min-width="160" />
        <el-table-column prop="account_no" label="账号" min-width="200" />
        <el-table-column prop="bank_name" label="开户行" min-width="140">
          <template #default="{ row }">{{ row.bank_name || "-" }}</template>
        </el-table-column>
        <el-table-column label="默认账户" width="100">
          <template #default="{ row }">
            <el-tag v-if="row.is_default === 1" type="success" size="small">默认</el-tag>
            <span v-else class="muted">-</span>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="100" fixed="right">
          <template #default="{ row }">
            <el-button link type="primary" @click="openEdit(row)">编辑</el-button>
          </template>
        </el-table-column>
      </el-table>

      <el-empty v-if="!total && !loading" description="尚未绑定结算账户" />
    </el-card>

    <el-dialog v-model="editVisible" :title="form.account_id ? '编辑结算账户' : '绑定结算账户'" width="480px">
      <el-form label-width="90px">
        <el-form-item label="账户类型">
          <el-radio-group v-model="form.account_type">
            <el-radio-button value="bank">银行卡</el-radio-button>
            <el-radio-button value="wechat">微信</el-radio-button>
            <el-radio-button value="alipay">支付宝</el-radio-button>
          </el-radio-group>
        </el-form-item>
        <el-form-item label="账户名" required>
          <el-input v-model="form.account_name" placeholder="持卡人 / 收款方姓名" />
        </el-form-item>
        <el-form-item label="账号" required>
          <el-input v-model="form.account_no" placeholder="卡号 / 收款账号" />
        </el-form-item>
        <el-form-item v-if="form.account_type === 'bank'" label="开户行" required>
          <el-input v-model="form.bank_name" placeholder="如：中国工商银行" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="editVisible = false">取消</el-button>
        <el-button type="primary" :loading="saving" @click="submit">保存</el-button>
      </template>
    </el-dialog>
  </div>
</template>

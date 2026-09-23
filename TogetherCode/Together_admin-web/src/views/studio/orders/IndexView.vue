<script setup lang="ts">
import { fmtTime } from "../../../utils/format";
import { exportCsv } from "../../../utils/exportCsv";
import { computed, onMounted, reactive, ref } from "vue";
import { Refresh, Download, Plus } from "@element-plus/icons-vue";
import { ElMessage, ElMessageBox, type UploadRequestOptions } from "element-plus";
import { useAuthStore } from "../../../stores/auth";
import {
  fetchStudioOrders,
  fetchStudioOrderDetail,
  fetchStudioOrderContacts,
  fetchStudioCourses,
  fetchStudioClasses,
  createStudioOrder,
  confirmStudioPayment,
  rejectStudioPayment,
  cancelStudioOrder,
  uploadStudioImages,
  type OrderItem,
  type OrderContact,
  type PayMethod
} from "../../../services/studio";
import type { CourseItem, ClassItem } from "../../../services/studio";

const authStore = useAuthStore();
const studioId = computed(() => authStore.account?.studio_id || "");

const loading = ref(false);
const status = ref<number | "">("");
const keyword = ref("");
const orders = ref<OrderItem[]>([]);

// 订单状态：0 待收款 / 1 已收款 / 2 已取消 / 3 已退款
const statusMeta: Record<number, { text: string; type: "info" | "success" | "danger" | "warning" }> = {
  0: { text: "待收款", type: "warning" },
  1: { text: "已收款", type: "success" },
  2: { text: "已取消", type: "info" },
  3: { text: "已退款", type: "danger" }
};

const sourceMeta: Record<number, { text: string; type: "info" | "primary" }> = {
  0: { text: "家长报名", type: "primary" },
  1: { text: "工作室建单", type: "info" }
};

const PAY_METHODS: Array<{ value: PayMethod; label: string; online: boolean }> = [
  { value: "cash", label: "现金", online: false },
  { value: "wechat", label: "微信转账", online: true },
  { value: "alipay", label: "支付宝转账", online: true },
  { value: "bank", label: "银行转账", online: true },
  { value: "qrcode", label: "收款码转账", online: true },
  { value: "other", label: "其他", online: true }
];

const payMethodText = (m: string | null | undefined) => PAY_METHODS.find((p) => p.value === m)?.label || m || "-";
const isOnline = (m: string | null | undefined) => PAY_METHODS.find((p) => p.value === m)?.online ?? true;

const paymentStatusMeta: Record<number, { text: string; type: "info" | "success" | "danger" | "warning" }> = {
  0: { text: "待确认", type: "warning" },
  1: { text: "已确认", type: "success" },
  2: { text: "已驳回", type: "danger" }
};

function fen2yuan(fen: number): string {
  return `¥ ${((Number(fen) || 0) / 100).toFixed(2)}`;
}

async function loadData() {
  loading.value = true;
  try {
    orders.value = (
      await fetchStudioOrders({
        status: status.value,
        q: keyword.value.trim() || undefined,
        page: 1,
        page_size: 200
      })
    ).list;
  } catch {
    // 拦截器已提示
  } finally {
    loading.value = false;
  }
}

// 待收款单上的待确认凭证（家长上传、线上方式）
function pendingPayment(row: OrderItem) {
  return (row.payments || []).find((p) => Number(p.status) === 0) || null;
}

// ============ 详情抽屉 ============
const detailVisible = ref(false);
const detailLoading = ref(false);
const detail = ref<OrderItem | null>(null);

async function openDetail(row: OrderItem) {
  detailVisible.value = true;
  detailLoading.value = true;
  detail.value = row;
  try {
    detail.value = await fetchStudioOrderDetail(row.order_id);
  } catch {
    // 保留列表数据
  } finally {
    detailLoading.value = false;
  }
}

async function refreshDetail() {
  if (!detail.value) return;
  await loadData();
  try {
    detail.value = await fetchStudioOrderDetail(detail.value.order_id);
  } catch {
    // 忽略
  }
}

// ============ 确认收款 ============
const confirmVisible = ref(false);
const confirmSaving = ref(false);
const confirmForm = reactive<{ order_id: string; pay_method: PayMethod; voucher_images: string[]; note: string }>({
  order_id: "",
  pay_method: "wechat",
  voucher_images: [],
  note: ""
});
const confirmExisting = ref<ReturnType<typeof pendingPayment>>(null);

function openConfirm(row: OrderItem) {
  const pending = pendingPayment(row);
  confirmExisting.value = pending;
  confirmForm.order_id = row.order_id;
  confirmForm.pay_method = (pending?.pay_method as PayMethod) || "cash";
  confirmForm.voucher_images = pending?.voucher_images ? [...pending.voucher_images] : [];
  confirmForm.note = "";
  confirmVisible.value = true;
}

async function uploadVoucher(options: UploadRequestOptions, target: "confirm" | "create") {
  const file = options.file as File;
  try {
    const urls = await uploadStudioImages([file], "voucher");
    if (target === "confirm") confirmForm.voucher_images.push(...urls);
    else createForm.voucher_images.push(...urls);
  } catch {
    // 拦截器已提示
  }
}

const confirmNeedImage = computed(() => isOnline(confirmForm.pay_method) && confirmForm.voucher_images.length === 0);

async function submitConfirm() {
  if (isOnline(confirmForm.pay_method) && confirmForm.voucher_images.length === 0) {
    ElMessage.warning("线上转账请上传付款凭证截图；现金可直接确认");
    return;
  }
  confirmSaving.value = true;
  try {
    await confirmStudioPayment(confirmForm.order_id, {
      pay_method: confirmForm.pay_method,
      voucher_images: isOnline(confirmForm.pay_method) ? confirmForm.voucher_images : [],
      note: confirmForm.note || undefined
    });
    ElMessage.success("已确认收款，课时已发放");
    confirmVisible.value = false;
    if (detailVisible.value) await refreshDetail();
    else await loadData();
  } catch {
    // 拦截器已提示
  } finally {
    confirmSaving.value = false;
  }
}

// ============ 驳回凭证 ============
async function rejectPayment(row: OrderItem) {
  let reason = "";
  try {
    const r = await ElMessageBox.prompt("请填写驳回原因（家长会看到，便于其重新上传）", "驳回付款凭证", {
      confirmButtonText: "确认驳回",
      cancelButtonText: "取消",
      inputType: "textarea",
      inputPlaceholder: "例如：截图不清晰、未查到到账",
      inputValidator: (v) => (v && v.trim() ? true : "请填写驳回原因")
    });
    reason = r.value || "";
  } catch {
    return; // 取消
  }
  try {
    await rejectStudioPayment(row.order_id, { reason: reason.trim() });
    ElMessage.success("已驳回，订单仍为待收款");
    if (detailVisible.value) await refreshDetail();
    else await loadData();
  } catch {
    // 拦截器已提示
  }
}

// ============ 手动取消 ============
async function cancelOrder(row: OrderItem) {
  try {
    await ElMessageBox.confirm("取消后该待收款单作废、不发放课时，家长端同步显示已取消。确定取消？", "取消订单", {
      confirmButtonText: "确认取消订单",
      cancelButtonText: "再想想",
      type: "warning"
    });
  } catch {
    return;
  }
  try {
    await cancelStudioOrder(row.order_id);
    ElMessage.success("订单已取消");
    if (detailVisible.value) await refreshDetail();
    else await loadData();
  } catch {
    // 拦截器已提示
  }
}

// ============ 手动建单 ============
const createVisible = ref(false);
const createSaving = ref(false);
const contactsLoading = ref(false);
const contacts = ref<OrderContact[]>([]);
const courses = ref<CourseItem[]>([]);
const classes = ref<ClassItem[]>([]);
const createForm = reactive({
  child_id: "",
  course_id: "",
  class_id: "",
  amount_yuan: "" as string | number,
  confirm: 1 as 0 | 1,
  pay_method: "cash" as PayMethod,
  voucher_images: [] as string[],
  note: "",
  remark: ""
});

const createClasses = computed(() => classes.value.filter((c) => c.course_id === createForm.course_id));
const createNeedImage = computed(
  () => createForm.confirm === 1 && isOnline(createForm.pay_method) && createForm.voucher_images.length === 0
);

async function openCreate() {
  createVisible.value = true;
  Object.assign(createForm, {
    child_id: "",
    course_id: "",
    class_id: "",
    amount_yuan: "",
    confirm: 1,
    pay_method: "cash",
    voucher_images: [],
    note: "",
    remark: ""
  });
  contacts.value = [];
  courses.value = [];
  classes.value = [];
  await searchContacts("");
}

async function searchContacts(q: string) {
  contactsLoading.value = true;
  try {
    const data = await fetchStudioOrderContacts({ q: q || undefined, page: 1, page_size: 30 });
    contacts.value = data.list;
  } catch {
    // 忽略
  } finally {
    contactsLoading.value = false;
  }
}

async function onPickCourse(courseId: string) {
  createForm.class_id = "";
  const course = courses.value.find((c) => c.course_id === courseId);
  if (course && !createForm.amount_yuan) {
    createForm.amount_yuan = ((Number(course.price) || 0) / 100).toFixed(2);
  }
}

async function ensureBaseData() {
  if (!courses.value.length) {
    courses.value = await fetchStudioCourses({ studio_id: studioId.value, status: 1 });
  }
  if (!classes.value.length) {
    classes.value = (await fetchStudioClasses({ studio_id: studioId.value })).list;
  }
}

async function submitCreate() {
  if (!createForm.child_id) return ElMessage.warning("请选择学员");
  if (!createForm.course_id) return ElMessage.warning("请选择课程");
  const amountFen = Math.round(Number(createForm.amount_yuan || 0) * 100);
  if (!amountFen || amountFen <= 0) return ElMessage.warning("请填写正确的收款金额");
  if (createForm.confirm === 1 && isOnline(createForm.pay_method) && createForm.voucher_images.length === 0) {
    return ElMessage.warning("线上转账请上传付款凭证；现金可直接登记");
  }
  createSaving.value = true;
  try {
    await createStudioOrder({
      child_id: createForm.child_id,
      course_id: createForm.course_id,
      class_id: createForm.class_id || undefined,
      total_amount: amountFen,
      confirm: createForm.confirm,
      pay_method: createForm.confirm === 1 ? createForm.pay_method : undefined,
      voucher_images: createForm.confirm === 1 && isOnline(createForm.pay_method) ? createForm.voucher_images : [],
      note: createForm.note || undefined,
      remark: createForm.remark || undefined
    });
    ElMessage.success(createForm.confirm === 1 ? "已建单并确认收款，课时已发放" : "已创建待收款单");
    createVisible.value = false;
    await loadData();
  } catch {
    // 拦截器已提示
  } finally {
    createSaving.value = false;
  }
}

// ============ 导出 CSV ============
const exporting = ref(false);
async function exportOrders() {
  exporting.value = true;
  try {
    const res = await fetchStudioOrders({
      status: status.value,
      q: keyword.value.trim() || undefined,
      page: 1,
      page_size: 1000
    });
    exportCsv(
      "工作室订单",
      [
        { key: "order_no", label: "订单号" },
        { key: "status", label: "状态" },
        { key: "source", label: "来源" },
        { key: "child", label: "学员" },
        { key: "parent_phone", label: "家长手机" },
        { key: "course", label: "课程" },
        { key: "class_name", label: "班级" },
        { key: "total_lessons", label: "课时数" },
        { key: "remaining_lessons", label: "剩余课时" },
        { key: "total_amount", label: "订单金额(分)" },
        { key: "paid_amount", label: "实收金额(分)" },
        { key: "pay_method", label: "收款方式" },
        { key: "paid_at", label: "收款时间" },
        { key: "created_at", label: "下单时间" }
      ],
      res.list.map((o) => ({
        ...o,
        status: statusMeta[o.status]?.text ?? o.status,
        source: sourceMeta[o.source]?.text ?? "-",
        child: o.child?.nickname ?? "-",
        parent_phone: o.user?.phone ?? "-",
        course: o.course?.title ?? "-",
        class_name: o.class?.name ?? "-",
        pay_method: o.status === 1 ? payMethodText(o.pay_method) : "-",
        paid_at: o.paid_at ? fmtTime(o.paid_at) : "-",
        created_at: fmtTime(o.created_at)
      }))
    );
  } catch {
    // 拦截器已提示
  } finally {
    exporting.value = false;
  }
}

onMounted(loadData);
</script>

<template>
  <div class="page-stack">
    <el-card v-loading="loading" shadow="never">
      <template #header>
        <div class="panel-header">
          <span>订单与收款</span>
          <div class="toolbar-right">
            <el-radio-group v-model="status" size="small" @change="loadData">
              <el-radio-button :value="''">全部</el-radio-button>
              <el-radio-button :value="0">待收款</el-radio-button>
              <el-radio-button :value="1">已收款</el-radio-button>
              <el-radio-button :value="2">已取消</el-radio-button>
              <el-radio-button :value="3">已退款</el-radio-button>
            </el-radio-group>
            <el-input
              v-model="keyword"
              placeholder="学员 / 手机 / 订单号"
              clearable
              style="width: 190px"
              @keyup.enter="loadData"
              @clear="loadData"
            />
            <el-button :icon="Refresh" @click="loadData">刷新</el-button>
            <el-button type="primary" plain :icon="Download" :loading="exporting" @click="exportOrders">
              导出
            </el-button>
            <el-button type="primary" :icon="Plus" @click="openCreate">手动建单</el-button>
          </div>
        </div>
      </template>

      <el-table :data="orders" row-key="order_id">
        <el-table-column label="学员 / 课程" min-width="210">
          <template #default="{ row }">
            <div class="cell-strong">{{ row.child?.nickname || "-" }}</div>
            <div class="cell-sub">{{ row.course?.title || "-" }} · {{ row.class?.name || "未分班" }}</div>
          </template>
        </el-table-column>
        <el-table-column label="家长手机" width="120">
          <template #default="{ row }">{{ row.user?.phone || "-" }}</template>
        </el-table-column>
        <el-table-column label="来源" width="104" align="center">
          <template #default="{ row }">
            <el-tag :type="sourceMeta[row.source]?.type || 'info'" effect="plain" size="small">
              {{ sourceMeta[row.source]?.text || "-" }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="金额 / 方式" width="150" align="right">
          <template #default="{ row }">
            <div class="amount-cell">{{ fen2yuan(row.total_amount) }}</div>
            <div class="cell-sub">{{ row.status === 1 ? payMethodText(row.pay_method) : "线下结算" }}</div>
          </template>
        </el-table-column>
        <el-table-column label="课时" width="110" align="center">
          <template #default="{ row }">
            <span class="cell-sub">剩 {{ row.remaining_lessons }} / 共 {{ row.total_lessons }}</span>
          </template>
        </el-table-column>
        <el-table-column label="凭证" width="100" align="center">
          <template #default="{ row }">
            <el-tag v-if="pendingPayment(row)" type="warning" size="small">待确认</el-tag>
            <el-tag v-else-if="(row.payments || []).some((p: any) => p.status === 2)" type="danger" size="small">
              已驳回
            </el-tag>
            <span v-else class="cell-sub">-</span>
          </template>
        </el-table-column>
        <el-table-column label="状态" width="92" align="center">
          <template #default="{ row }">
            <el-tag :type="statusMeta[row.status]?.type || 'info'" effect="light" size="small">
              {{ statusMeta[row.status]?.text || row.status }}
            </el-tag>
          </template>
        </el-table-column>
        <el-table-column label="操作" width="210" fixed="right">
          <template #default="{ row }">
            <el-button text type="primary" size="small" @click="openDetail(row)">详情</el-button>
            <template v-if="row.status === 0">
              <el-button text type="success" size="small" @click="openConfirm(row)">确认收款</el-button>
              <el-dropdown trigger="click" @command="(cmd: string) => cmd === 'reject' ? rejectPayment(row) : cancelOrder(row)">
                <el-button text type="info" size="small">更多<i class="el-icon-arrow-down" /></el-button>
                <template #dropdown>
                  <el-dropdown-menu>
                    <el-dropdown-item v-if="pendingPayment(row)" command="reject">驳回凭证</el-dropdown-item>
                    <el-dropdown-item command="cancel">取消订单</el-dropdown-item>
                  </el-dropdown-menu>
                </template>
              </el-dropdown>
            </template>
          </template>
        </el-table-column>
      </el-table>
      <div v-if="!loading && orders.length === 0" class="empty-tip">暂无订单</div>
    </el-card>

    <!-- 订单详情 -->
    <el-drawer v-model="detailVisible" title="订单详情" size="520px">
      <div v-loading="detailLoading" v-if="detail" class="detail-wrap">
        <el-descriptions :column="1" border size="small">
          <el-descriptions-item label="订单号">{{ detail.order_no }}</el-descriptions-item>
          <el-descriptions-item label="状态">
            <el-tag :type="statusMeta[detail.status]?.type" size="small">
              {{ statusMeta[detail.status]?.text }}
            </el-tag>
            <el-tag class="ml8" :type="sourceMeta[detail.source]?.type" effect="plain" size="small">
              {{ sourceMeta[detail.source]?.text }}
            </el-tag>
          </el-descriptions-item>
          <el-descriptions-item label="学员">
            {{ detail.child?.nickname || "-" }}（{{ detail.child?.birthday || "未填生日" }}）
          </el-descriptions-item>
          <el-descriptions-item label="家长手机">{{ detail.user?.phone || "-" }}</el-descriptions-item>
          <el-descriptions-item label="课程 / 班级">
            {{ detail.course?.title || "-" }} · {{ detail.class?.name || "未分班" }}
          </el-descriptions-item>
          <el-descriptions-item label="订单金额">{{ fen2yuan(detail.total_amount) }}</el-descriptions-item>
          <el-descriptions-item label="实收金额">
            <span class="amount-cell">{{ fen2yuan(detail.paid_amount) }}</span>
            <span v-if="detail.status === 1" class="cell-sub ml8">{{ payMethodText(detail.pay_method) }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="收款时间">{{ detail.paid_at ? fmtTime(detail.paid_at) : "-" }}</el-descriptions-item>
          <el-descriptions-item label="下单时间">{{ fmtTime(detail.created_at) }}</el-descriptions-item>
          <el-descriptions-item v-if="detail.remark" label="工作室备注">{{ detail.remark }}</el-descriptions-item>
        </el-descriptions>

        <div class="block-title">付款记录（线下结算凭证）</div>
        <el-empty v-if="!(detail.payments || []).length" description="暂无付款记录" :image-size="70" />
        <div v-for="p in detail.payments || []" :key="p.payment_id" class="pay-card">
          <div class="pay-head">
            <span class="cell-strong">{{ payMethodText(p.pay_method) }} · {{ fen2yuan(p.amount) }}</span>
            <el-tag :type="paymentStatusMeta[p.status]?.type" size="small">
              {{ paymentStatusMeta[p.status]?.text }}
            </el-tag>
          </div>
          <div class="cell-sub">
            {{ p.upload_by === 1 ? "工作室代登记" : "家长上传" }} · {{ fmtTime(p.created_at) }}
          </div>
          <div v-if="p.payer_note" class="pay-note">备注：{{ p.payer_note }}</div>
          <div v-if="p.reject_reason" class="pay-reject">驳回原因：{{ p.reject_reason }}</div>
          <div v-if="(p.voucher_images || []).length" class="voucher-list">
            <el-image
              v-for="(img, idx) in p.voucher_images"
              :key="idx"
              :src="img"
              :preview-src-list="p.voucher_images"
              :initial-index="idx"
              fit="cover"
              class="voucher-img"
            />
          </div>
        </div>

        <div class="block-title">课时账本</div>
        <el-descriptions v-if="detail.balance" :column="2" border size="small">
          <el-descriptions-item label="总课时">{{ detail.balance.total_lessons }}</el-descriptions-item>
          <el-descriptions-item label="剩余课时">
            <span class="cell-strong">{{ detail.balance.remaining_lessons }}</span>
          </el-descriptions-item>
          <el-descriptions-item label="已消耗">{{ detail.balance.consumed_lessons }}</el-descriptions-item>
          <el-descriptions-item label="已退课时">{{ detail.balance.refunded_lessons }}</el-descriptions-item>
          <el-descriptions-item label="生效日">{{ detail.balance.valid_from || "-" }}</el-descriptions-item>
          <el-descriptions-item label="有效期至">{{ detail.balance.valid_to || "-" }}</el-descriptions-item>
        </el-descriptions>
        <el-empty v-else description="确认收款后发放课时" :image-size="70" />

        <div v-if="detail.status === 0" class="detail-actions">
          <el-button type="success" plain @click="openConfirm(detail)">确认收款 / 登记</el-button>
          <el-button v-if="pendingPayment(detail)" type="danger" plain @click="rejectPayment(detail)">
            驳回凭证
          </el-button>
          <el-button type="info" plain @click="cancelOrder(detail)">取消订单</el-button>
        </div>
      </div>
    </el-drawer>

    <!-- 确认收款 -->
    <el-dialog v-model="confirmVisible" title="确认收款" width="460px">
      <el-form label-position="top">
        <el-form-item label="收款方式（线下结算，平台不经手资金）">
          <el-radio-group v-model="confirmForm.pay_method">
            <el-radio v-for="m in PAY_METHODS" :key="m.value" :value="m.value">{{ m.label }}</el-radio>
          </el-radio-group>
        </el-form-item>

        <el-alert
          v-if="confirmForm.pay_method === 'cash'"
          type="success"
          :closable="false"
          show-icon
          title="现金收款可直接登记，无需上传凭证"
          class="mb12"
        />

        <el-form-item v-if="isOnline(confirmForm.pay_method)" label="付款凭证截图">
          <div class="voucher-upload">
            <div v-for="(img, idx) in confirmForm.voucher_images" :key="img" class="voucher-item">
              <el-image :src="img" :preview-src-list="confirmForm.voucher_images" :initial-index="idx" fit="cover"
                class="voucher-img" />
              <el-button class="voucher-del" type="danger" circle size="small" @click="confirmForm.voucher_images.splice(idx, 1)">×</el-button>
            </div>
            <el-upload
              :show-file-list="false"
              accept="image/*"
              multiple
              :http-request="(opt: any) => uploadVoucher(opt, 'confirm')"
            >
              <div class="voucher-add">+</div>
            </el-upload>
          </div>
          <div v-if="confirmExisting && confirmForm.voucher_images.length" class="cell-sub">
            已含家长上传的待确认凭证，可直接确认
          </div>
        </el-form-item>

        <el-form-item label="备注（可选）">
          <el-input v-model="confirmForm.note" type="textarea" :rows="2" maxlength="100" show-word-limit
            placeholder="例如：已核对线下到账" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="confirmVisible = false">取消</el-button>
        <el-button type="success" :loading="confirmSaving" :disabled="confirmNeedImage" @click="submitConfirm">
          确认收款并发放课时
        </el-button>
      </template>
    </el-dialog>

    <!-- 手动建单 -->
    <el-dialog v-model="createVisible" title="手动建单（老学员续费 / 线下报名）" width="520px">
      <el-form label-position="top" v-loading="contactsLoading">
        <el-form-item label="学员（仅本工作室联系人库；新学员请由家长在 App 自助报名）">
          <el-select
            v-model="createForm.child_id"
            filterable
            remote
            :remote-method="searchContacts"
            placeholder="输入学员昵称 / 家长手机搜索"
            style="width: 100%"
            @visible-change="(v: boolean) => v && ensureBaseData()"
          >
            <el-option
              v-for="c in contacts"
              :key="c.child_id"
              :value="c.child_id"
              :label="`${c.nickname}（${c.parent.phone}）`"
            >
              <div class="opt-line">
                <span>{{ c.nickname }}</span>
                <span class="cell-sub">{{ c.parent.phone }} · 剩余 {{ c.total_remaining_lessons }} 节</span>
              </div>
            </el-option>
          </el-select>
        </el-form-item>

        <el-form-item label="课程">
          <el-select v-model="createForm.course_id" placeholder="选择课程" style="width: 100%" @change="onPickCourse">
            <el-option
              v-for="c in courses"
              :key="c.course_id"
              :value="c.course_id"
              :label="`${c.title}（${c.total_lessons}节）`"
            />
          </el-select>
        </el-form-item>

        <el-form-item label="班级（可选）">
          <el-select v-model="createForm.class_id" placeholder="选择班级（可后补）" clearable style="width: 100%">
            <el-option v-for="cl in createClasses" :key="cl.class_id" :value="cl.class_id"
              :label="`${cl.name}（${cl.enrolled}/${cl.capacity}）`" />
          </el-select>
        </el-form-item>

        <el-form-item label="收款金额（元，可按实际改价）">
          <el-input v-model="createForm.amount_yuan" type="number" placeholder="0.00">
            <template #prepend>¥</template>
          </el-input>
        </el-form-item>

        <el-form-item label="是否当场确认收款">
          <el-switch
            v-model="createForm.confirm"
            :active-value="1"
            :inactive-value="0"
            active-text="确认收款并发课时"
            inactive-text="仅建待收款单"
          />
        </el-form-item>

        <template v-if="createForm.confirm === 1">
          <el-form-item label="收款方式">
            <el-radio-group v-model="createForm.pay_method">
              <el-radio v-for="m in PAY_METHODS" :key="m.value" :value="m.value">{{ m.label }}</el-radio>
            </el-radio-group>
          </el-form-item>
          <el-form-item v-if="isOnline(createForm.pay_method)" label="付款凭证截图">
            <div class="voucher-upload">
              <div v-for="(img, idx) in createForm.voucher_images" :key="img" class="voucher-item">
                <el-image :src="img" :preview-src-list="createForm.voucher_images" :initial-index="idx" fit="cover"
                  class="voucher-img" />
                <el-button class="voucher-del" type="danger" circle size="small"
                  @click="createForm.voucher_images.splice(idx, 1)">×</el-button>
              </div>
              <el-upload :show-file-list="false" accept="image/*" multiple
                :http-request="(opt: any) => uploadVoucher(opt, 'create')">
                <div class="voucher-add">+</div>
              </el-upload>
            </div>
          </el-form-item>
        </template>

        <el-form-item label="工作室备注（可选）">
          <el-input v-model="createForm.remark" maxlength="50" show-word-limit placeholder="如：老学员续费、线下优惠" />
        </el-form-item>
      </el-form>
      <template #footer>
        <el-button @click="createVisible = false">取消</el-button>
        <el-button type="primary" :loading="createSaving" :disabled="createNeedImage" @click="submitCreate">
          {{ createForm.confirm === 1 ? "建单并确认收款" : "创建待收款单" }}
        </el-button>
      </template>
    </el-dialog>
  </div>
</template>

<style scoped>
.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 10px;
}
.toolbar-right {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-wrap: wrap;
}
.cell-strong {
  font-weight: 600;
  color: #2b2621;
}
.cell-sub {
  font-size: 12px;
  color: #9c9385;
}
.ml8 {
  margin-left: 8px;
}
.mb12 {
  margin-bottom: 12px;
}
.amount-cell {
  font-weight: 700;
  color: #2f5d45;
}
.empty-tip {
  padding: 32px 0;
  text-align: center;
  color: #9c9385;
  font-size: 13px;
}
.block-title {
  margin: 18px 0 10px;
  font-size: 14px;
  font-weight: 600;
  color: #2b2621;
}
.detail-wrap {
  padding: 0 4px;
}
.detail-actions {
  margin-top: 20px;
  display: flex;
  gap: 10px;
  flex-wrap: wrap;
}
.pay-card {
  border: 1px solid #eee5d8;
  border-radius: 10px;
  padding: 12px;
  margin-bottom: 10px;
  background: #fdfbf7;
}
.pay-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 4px;
}
.pay-note {
  font-size: 13px;
  color: #5b5347;
  margin-top: 6px;
}
.pay-reject {
  font-size: 13px;
  color: #c4563f;
  margin-top: 6px;
}
.voucher-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}
.voucher-img {
  width: 72px;
  height: 72px;
  border-radius: 8px;
  border: 1px solid #eee5d8;
}
.voucher-upload {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}
.voucher-item {
  position: relative;
  width: 72px;
  height: 72px;
}
.voucher-del {
  position: absolute;
  top: -8px;
  right: -8px;
  width: 20px;
  height: 20px;
  min-height: 20px;
  padding: 0;
}
.voucher-add {
  width: 72px;
  height: 72px;
  border: 1px dashed #c9bda8;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 26px;
  color: #b3a892;
  background: #faf7f1;
}
.opt-line {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
}
</style>

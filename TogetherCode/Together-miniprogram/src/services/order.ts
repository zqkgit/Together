import { request } from "./request";
import { fenToYuan } from "./course";

export { fenToYuan };

// 订单状态（对齐后端 orders.status：0 待收款 / 1 待确认收款 / 2 已收款 / 3 退款审核中 / 4 待家长确认退款 / 5 已退款 / 6 已取消）
export const ORDER_STATUS_TEXT: Record<number, string> = {
  0: "待付款",
  1: "待确认",
  2: "已报名",
  3: "退款审核中",
  4: "待确认退款",
  5: "已退款",
  6: "已取消",
};

// 订单层退款聚合状态：0 无 / 1 退款中 / 2 已退款 / 3 已驳回
export const REFUND_STATUS_TEXT: Record<number, string> = {
  1: "退款中",
  2: "已退款",
  3: "退款已驳回",
};

export interface PaymentItem {
  payment_id?: string;
  payment_no?: string;
  channel?: string;
  pay_method?: string;
  pay_method_text?: string;
  amount?: number;
  status?: number;
  status_text?: string;
  voucher_images?: string[];
  payer_note?: string;
  /** 0 = 家长上传，1 = 工作室代登记 */
  upload_by?: number;
  reject_reason?: string;
  paid_at?: string;
  created_at?: string;
}

export interface OrderItem {
  order_id: string;
  order_no: string;
  status: number;
  status_text: string;
  total_amount: number;
  paid_amount: number;
  total_lessons: number;
  consumed_lessons?: number;
  remaining_lessons?: number;
  refunded_lessons?: number;
  created_at: string;
  course: { course_id: string; title: string; cover: string | null } | null;
  child: { child_id: string; nickname: string } | null;
  studio: { studio_id: string; name: string } | null;
  class_id?: string | null;
  // 退款聚合状态：0 无 / 1 退款中 / 2 已退款 / 3 已驳回
  refund_status?: number;
  refund_status_text?: string;
  /** 当前应跳转的退款单 id（多笔退款时指向最新有效单，避免取到最早的驳回单） */
  current_refund_id?: string | null;
  can_apply_refund?: boolean;
  refunds?: Array<{ refund_id: string; amount: number; status: number }>;
  balance?: { remaining_lessons: number; valid_to: string | null };
  // 线下付款相关
  pay_method?: string | null;
  pay_method_text?: string | null;
  paid_at?: string | null;
  payments?: PaymentItem[];
}

export function createOrder(payload: {
  child_id: string;
  course_id: string;
  class_id: string;
  distribution_code?: string;
  remark?: string;
}): Promise<OrderItem> {
  return request({ url: "/orders", method: "POST", data: payload });
}

export function listOrders(params: { status?: number | ""; page?: number; page_size?: number } = {}): Promise<{
  total: number;
  list: OrderItem[];
}> {
  const query = Object.keys(params)
    .filter((k) => params[k] !== undefined && params[k] !== "")
    .map((k) => `${k}=${encodeURIComponent(params[k])}`)
    .join("&");
  return request({ url: `/orders?${query}`, method: "GET" });
}

export function getOrderDetail(id: string): Promise<OrderItem> {
  return request({ url: `/orders/${id}`, method: "GET" });
}

/** 提交线下付款凭证（平台不经手资金；家长线下向机构付款后上传，机构核对确认后发课时） */
export function submitPaymentVoucher(
  orderId: string,
  payload: { pay_method: string; voucher_images: string[]; note?: string }
): Promise<OrderItem> {
  return request({ url: `/orders/${orderId}/payment-voucher`, method: "POST", data: payload });
}

/** 取消待收款订单（机构尚未确认收款，可取消） */
export function cancelOrder(orderId: string): Promise<OrderItem> {
  return request({ url: `/orders/${orderId}/cancel`, method: "POST" });
}

export interface RefundItem {
  refund_id: string;
  order_id: string;
  course_title: string;
  course_cover: string | null;
  studio_name: string | null;
  child_name: string;
  requested_lessons: number;
  /** 机构审核锁定的实退课时（申请后若已消课，可能少于申请课时；null=尚未审核） */
  approved_lessons?: number | null;
  amount: number;
  amount_text: string;
  status: number;
  status_text: string;
  reason: string | null;
  /** 线下退款方式 / 文案 */
  refund_method?: string | null;
  refund_method_text?: string | null;
  /** 机构上传的线下打款凭证 */
  voucher_images?: string[];
  reject_reason?: string | null;
  /** status=1 待家长确认时为 true */
  can_confirm?: boolean;
  confirmed_at?: string | null;
  created_at: string;
}

export interface RefundDetail extends RefundItem {
  order_no: string | null;
  total_lessons: number;
  consumed_lessons: number;
  refunded_lessons: number;
  balance_remaining: number;
  valid_to: string | null;
  refundable_lessons: number;
  unit_price: number;
  unit_price_text: string;
  reviewed_at: string | null;
  refunded_at: string | null;
  steps: Array<{ key: string; title: string; time: string | null; done: boolean; current: boolean }>;
}

/** 我的退款列表（status 可选：0 申请中 / 2 已驳回 / 3 已通过） */
export function getRefunds(status?: number): Promise<{ total: number; list: RefundItem[] }> {
  const q = status !== undefined ? `?status=${status}` : "";
  return request({ url: `/orders/refunds${q}`, method: "GET" });
}

/** 退款详情 */
export function getRefundDetail(id: string): Promise<RefundDetail> {
  return request({ url: `/orders/refunds/${id}`, method: "GET" });
}

/** 家长确认已在线下收到退款（status=1 待确认 → 3 已退款，并扣减课时）；返回最新详情 */
export function confirmRefundReceived(id: string): Promise<RefundDetail> {
  return request({ url: `/orders/refunds/${id}/confirm`, method: "POST" });
}
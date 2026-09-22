import { request } from "./request";
import { fenToYuan } from "./course";

export { fenToYuan };

export interface OrderItem {
  order_id: string;
  order_no: string;
  status: number;
  status_text: string;
  total_amount: number;
  paid_amount: number;
  total_lessons: number;
  created_at: string;
  course: { course_id: string; title: string; cover: string | null } | null;
  child: { child_id: string; nickname: string } | null;
  studio: { studio_id: string; name: string } | null;
  class_id?: string | null;
  // 订单层退款聚合状态：0 无 / 1 退款中 / 2 已退款 / 3 已驳回
  refund_status?: number;
  refund_status_text?: string;
  can_apply_refund?: boolean;
  pay_expire_at?: string;
  refunds?: Array<{ refund_id: string; amount: number; status: number }>;
  balance?: { remaining_lessons: number; valid_to: string | null };
}

// 支付倒计时文案（待支付订单）：剩余不足 1 小时显示 mm:ss，否则 HH:mm:ss；已超时显示取消文案
export function payCountdownText(order: OrderItem, now: number): string {
  if (order.status !== 0 || !order.pay_expire_at) {
    return "待支付";
  }
  const remain = new Date(order.pay_expire_at).getTime() - now;
  if (remain <= 0) {
    return "支付超时 · 订单已取消";
  }
  const total = Math.floor(remain / 1000);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const pad = (n: number) => String(n).padStart(2, "0");
  return h > 0
    ? `支付剩余 ${pad(h)}:${pad(m)}:${pad(s)}`
    : `支付剩余 ${pad(m)}:${pad(s)}`;
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

export function payOrder(id: string, channel = "wechat_mini"): Promise<OrderItem> {
  return request({ url: `/orders/${id}/pay`, method: "POST", data: { channel } });
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

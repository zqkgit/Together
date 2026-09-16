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
  refunds?: Array<{ refund_id: string; amount: number; status: number }>;
  balance?: { remaining_lessons: number; valid_to: string | null };
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
  amount: number;
  amount_text: string;
  status: number;
  status_text: string;
  reason: string | null;
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

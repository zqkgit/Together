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
  balance?: { remaining_lessons: number; valid_to: string | null };
}

export function createOrder(payload: {
  child_id: string;
  course_id: string;
  package_id: string;
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

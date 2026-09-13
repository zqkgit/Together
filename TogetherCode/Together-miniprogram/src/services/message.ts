import { request } from "./request";

export interface NotificationItem {
  notification_id: string;
  type: string;
  title: string;
  content: string;
  is_read: boolean;
  ref_type?: string | null;
  ref_id?: string | null;
  created_at: string;
}

export interface NotificationPage {
  total: number;
  page: number;
  size: number;
  unread_total: number;
  list: NotificationItem[];
}

export function getNotifications(params: { page?: number; page_size?: number } = {}): Promise<NotificationPage> {
  const q = `page=${params.page || 1}&page_size=${params.page_size || 20}`;
  return request({ url: `/messages/notifications?${q}`, method: "GET" });
}

export function markNotificationRead(id: string): Promise<void> {
  return request({ url: `/messages/notifications/${id}/read`, method: "PUT" });
}

export function markAllNotificationsRead(): Promise<void> {
  return request({ url: "/messages/notifications/read-all", method: "PUT" });
}

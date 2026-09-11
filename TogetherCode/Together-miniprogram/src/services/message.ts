import { request } from "./request";

export interface NotificationItem {
  notification_id: string;
  type: string;
  title: string;
  content: string;
  read: boolean;
  created_at: string;
}

export function getNotifications(params: { page?: number; page_size?: number } = {}): Promise<{
  total: number;
  list: NotificationItem[];
}> {
  const q = `page=${params.page || 1}&page_size=${params.page_size || 20}`;
  return request({ url: `/messages/notifications?${q}`, method: "GET" });
}

export function markNotificationRead(id: string): Promise<void> {
  return request({ url: `/messages/notifications/${id}/read`, method: "PUT" });
}

export function markAllNotificationsRead(): Promise<void> {
  return request({ url: "/messages/notifications/read-all", method: "PUT" });
}

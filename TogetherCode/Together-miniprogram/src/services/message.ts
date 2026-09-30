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

// ── 会话 & 聊天 ──

export interface ConversationPeer {
  user_id: string;
  nickname: string;
  avatar: string | null;
  role: number | null;
}

export interface ConversationItem {
  conversation_id: string;
  peer: ConversationPeer | null;
  last_message: {
    message_id: string;
    sender_id: string;
    type: number;
    content: string;
    created_at: string;
  } | null;
  unread_count: number;
  updated_at: string;
}

export interface ChatMessage {
  message_id: string;
  conversation_id: string;
  sender_id?: string;
  type: number; // 1=文本 2=图片
  content: string;
  read_at?: string | null;
  created_at: string;
  sender?: {
    user_id: string;
    nickname: string;
    avatar: string | null;
    role: number | null;
  };
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

// ── 会话 API ──

/** 发起私聊（幂等：已有会话直接返回） */
export function createConversation(peerUserId: string, childId?: string): Promise<{ data: ConversationItem }> {
  const params: Record<string, string> = { peer_user_id: peerUserId };
  if (childId) params.child_id = childId;
  return request({ url: "/messages/conversations", method: "POST", data: params });
}

/** 会话列表 */
export function getConversations(params: { page?: number; size?: number } = {}): Promise<{ total: number; unread_total: number; list: ConversationItem[] }> {
  const q = `page=${params.page || 1}&size=${params.size || 20}`;
  return request({ url: `/messages/conversations?${q}`, method: "GET" });
}

/** 会话消息列表 */
export function getConversationMessages(
  conversationId: string,
  params: { page?: number; size?: number } = {}
): Promise<{ total: number; list: ChatMessage[] }> {
  const q = `page=${params.page || 1}&size=${params.size || 30}`;
  return request({ url: `/messages/conversations/${conversationId}/messages?${q}`, method: "GET" });
}

/** 发送消息（type 1=文本 2=图片） */
export function sendMessage(conversationId: string, content: string, type: number = 1): Promise<{ data: ChatMessage }> {
  return request({ url: `/messages/conversations/${conversationId}/messages`, method: "POST", data: { content, type } });
}

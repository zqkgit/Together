import { request } from "./request";

export interface AnnouncementItem {
  announcement_id: string;
  title: string;
  content: string | null;
  type: number;
  image: string[];
  link: string | null;
  publish_at: string | null;
  created_at: string;
}

export interface AnnouncementPage {
  total: number;
  page: number;
  page_size: number;
  list: AnnouncementItem[];
}

/** 公告列表（仅已发布） */
export function getAnnouncements(page = 1, pageSize = 15): Promise<AnnouncementPage> {
  return request<any>({ url: `/announcements?page=${page}&page_size=${pageSize}`, method: "GET" });
}

/** 公告详情 */
export function getAnnouncementDetail(id: string): Promise<AnnouncementItem> {
  return request({ url: `/announcements/${id}`, method: "GET" });
}

import { request } from "./request";

export interface StudioItem {
  studio_id: string;
  name: string;
  cover: string | null;
  type_tags: string[];
  intro: string | null;
  address: string | null;
  course_count: number;
  teacher_count: number;
  rating: number;
}

export interface TeacherItem {
  teacher_id: string;
  user_id: string;
  nickname: string;
  avatar: string | null;
  real_name: string | null;
  subjects: string[];
  years: number | null;
  intro: string | null;
  rating: number;
  work_count: number;
  studios: Array<{ studio_id: string; name: string | null }>;
}

export interface PageResult<T> {
  total: number;
  page: number;
  page_size: number;
  list: T[];
}

/** 公开工作室列表（只含审核通过） */
export function getPublicStudios(params: { page?: number; page_size?: number; keyword?: string } = {}): Promise<PageResult<StudioItem>> {
  const q = Object.keys(params)
    .filter((k) => params[k] !== undefined && params[k] !== "")
    .map((k) => `${k}=${encodeURIComponent(String(params[k]))}`)
    .join("&");
  return request<any>({ url: `/studios?${q}`, method: "GET" });
}

/** 公开已认证老师列表 */
export function getPublicTeachers(params: { page?: number; page_size?: number; keyword?: string } = {}): Promise<PageResult<TeacherItem>> {
  const q = Object.keys(params)
    .filter((k) => params[k] !== undefined && params[k] !== "")
    .map((k) => `${k}=${encodeURIComponent(String(params[k]))}`)
    .join("&");
  return request<any>({ url: `/teachers?${q}`, method: "GET" });
}

export interface AnnouncementItem {
  id: string;
  title: string;
  content?: string;
}

/** 平台公告（已发布） */
export function getAnnouncements(params: { page?: number; page_size?: number } = {}): Promise<PageResult<AnnouncementItem>> {
  const q = Object.keys(params)
    .filter((k) => params[k] !== undefined && params[k] !== "")
    .map((k) => `${k}=${encodeURIComponent(String(params[k]))}`)
    .join("&");
  return request<any>({ url: `/announcements?${q}`, method: "GET" });
}

import { request } from "./request";

export interface BalanceItem {
  balance_id: string;
  child_id: string;
  course_id: string;
  course_title: string;
  course_cover: string | null;
  studio_name: string;
  total_lessons: number;
  consumed_lessons: number;
  refunded_lessons: number;
  remaining_lessons: number;
  valid_from: string | null;
  valid_to: string | null;
  status: number;
  status_text: string;
}

export interface BalanceChild {
  child_id: string;
  nickname: string;
  birthday: string | null;
  gender: number | null;
  total_packages: number;
  balances: BalanceItem[];
}

export interface LessonLogItem {
  log_id: string;
  child_id: string;
  child_name: string;
  course_id: string;
  course_title: string;
  studio_name: string;
  lesson_date: string | null;
  start_time: string | null;
  end_time: string | null;
  is_makeup: boolean;
  source: number;
  type: number;
  delta: number;
  balance_after: number;
  note: string;
  created_at: string;
}

export function listBalances(): Promise<BalanceChild[]> {
  return request<any>({ url: "/parent/balances", method: "GET" }).then((d) => d?.children || d || []);
}

export function listLessonLogs(params: { child_id?: string; page?: number; page_size?: number } = {}): Promise<{
  total: number;
  list: LessonLogItem[];
}> {
  const q = Object.keys(params)
    .filter((k) => params[k] !== undefined && params[k] !== "")
    .map((k) => `${k}=${encodeURIComponent(String(params[k]))}`)
    .join("&");
  return request({ url: `/parent/lesson-logs?${q}`, method: "GET" });
}

export function listChildSchedules(params: { child_id?: string; start_date?: string; end_date?: string } = {}): Promise<any[]> {
  const q = Object.keys(params)
    .filter((k) => params[k] !== undefined && params[k] !== "")
    .map((k) => `${k}=${encodeURIComponent(String(params[k]))}`)
    .join("&");
  return request<any>({ url: `/parent/schedules?${q}`, method: "GET" }).then((d) => d?.list || d || []);
}

export interface CalendarEvent {
  schedule_id: string;
  studio_id: string;
  course_id: string;
  class_id: string;
  course_title: string;
  duration_min: number | null;
  class_name: string;
  teacher_name: string;
  studio_name: string;
  lesson_date: string;
  start_time: string | null;
  end_time: string | null;
  location: string | null;
  is_makeup: boolean;
  status: number;
  children?: Array<{ child_id: string; nickname: string }>;
}

export interface ChildCalendar {
  month: string;
  date_count: number;
  list: Array<{ date: string; events: CalendarEvent[] }>;
}

/** 课程日历：按月聚合（month=YYYY-MM，child_id 可选，不传=全部孩子） */
export function getChildCalendar(params: { month?: string; child_id?: string } = {}): Promise<ChildCalendar> {
  const q = Object.keys(params)
    .filter((k) => params[k] !== undefined && params[k] !== "")
    .map((k) => `${k}=${encodeURIComponent(String(params[k]))}`)
    .join("&");
  return request<any>({ url: `/parent/calendar?${q}`, method: "GET" });
}

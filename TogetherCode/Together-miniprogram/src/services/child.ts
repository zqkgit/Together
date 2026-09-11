import { request } from "./request";

export interface ChildItem {
  child_id: string;
  nickname: string;
  avatar: string | null;
  birthday: string | null;
  gender: number | null;
}

export async function listChildren(): Promise<ChildItem[]> {
  const data = await request<any>({ url: "/children", method: "GET" });
  return data?.list || data || [];
}

export function createChild(payload: { nickname: string; birthday?: string; gender?: number; avatar?: string }): Promise<ChildItem> {
  return request({ url: "/children", method: "POST", data: payload });
}

export interface GrowthTimelineItem {
  event_id: string;
  event_type?: string; // "post" 为作品，缺省为课时记录
  child_id: string;
  course_id: string | null;
  course_title: string | null;
  studio_name: string | null;
  post_id: string | null;
  source: number;
  source_label: string;
  type: number;
  type_label: string;
  delta: number;
  balance_after: number | null;
  note: string | null;
  schedule: {
    schedule_id: string;
    lesson_date: string | null;
    start_time: string | null;
    end_time: string | null;
    location: string | null;
  } | null;
  post: { post_id: string; content: string | null; images: string[] } | null;
  created_at: string;
}

export interface ChildGrowth {
  child: ChildItem;
  overview: {
    total_courses: number;
    active_courses: number;
    studio_count: number;
    total_lessons: number;
    consumed_lessons: number;
    refunded_lessons: number;
    remaining_lessons: number;
    work_count: number;
    timeline_count: number;
  };
  assessments: unknown[];
  balances: unknown[];
  timeline: GrowthTimelineItem[];
}

export interface ChildWorks {
  child: ChildItem;
  total: number;
  list: Array<{
    post_id: string;
    type: number;
    images: string[];
    content: string | null;
    course_title: string | null;
    like_count: number;
    comment_count: number;
    created_at: string;
  }>;
}

/** 孩子成长档案（概览 + 时间线） */
export function getChildGrowth(childId: string): Promise<ChildGrowth> {
  return request({ url: `/children/${childId}/growth`, method: "GET" });
}

/** 孩子作品墙 */
export function getChildWorks(childId: string): Promise<ChildWorks> {
  return request({ url: `/children/${childId}/works`, method: "GET" });
}

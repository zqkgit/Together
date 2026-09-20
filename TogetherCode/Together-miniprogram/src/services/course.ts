import { request } from "./request";

export interface CoursePackage {
  package_id: string;
  name: string;
  lessons: number;
  price: number;
  original_price: number;
  status: number;
}

export interface CourseItem {
  course_id: string;
  title: string;
  cover: string | null;
  category: number;
  age_min: number | null;
  age_max: number | null;
  total_lessons: number;
  duration_min: number;
  price: number;
  class_size: number;
  rating: number;
  sales: number;
  distribute_rate: number;
  validity_days: number | null;
  status: number;
  studio: { studio_id: string; name: string; address: string; phone: string } | null;
  teacher: { teacher_id: string; real_name: string; intro: string | null; rating: number } | null;
  packages: CoursePackage[];
  lessons?: Array<{ lesson_no: number; title: string }>;
  classes?: Array<{
    class_id: string;
    name: string;
    capacity: number;
    enrolled: number;
    start_date: string;
    end_date: string;
    time: string | null;
    teacher_name: string | null;
  }>;
}

export function fenToYuan(fen: number): string {
  return (fen / 100).toFixed(2);
}

export function listCourses(params: {
  page?: number;
  page_size?: number;
  keyword?: string;
  tag?: string;
  category?: number;
} = {}): Promise<{ total: number; list: CourseItem[] }> {
  const query = Object.keys(params)
    .filter((k) => params[k] !== undefined && params[k] !== "")
    .map((k) => `${k}=${encodeURIComponent(params[k])}`)
    .join("&");
  return request({ url: `/courses?${query}`, method: "GET" });
}

export function getCourseDetail(id: string): Promise<CourseItem> {
  return request({ url: `/courses/${id}`, method: "GET" });
}

// MARK: - 我的课程（已报名）

export interface MyCourseItem {
  child_id: string;
  child_name: string;
  course_id: string;
  course_title: string;
  course_cover: string | null;
  studio_name: string;
  teacher_name: string;
  total_lessons: number;
  consumed_lessons: number;
  remaining_lessons: number;
  percent: number;
  status: number;
  status_text: string;
  next_lesson: {
    schedule_id: string;
    lesson_date: string;
    start_time: string;
    end_time: string;
  } | null;
}

export interface CourseScheduleItem {
  schedule_id: string;
  class_id: string;
  lesson_no: number;
  lesson_title: string;
  lesson_date: string;
  start_time: string;
  end_time: string;
  /** 0 待上 / 1 已上 / 2 今天 */
  status: number;
  /** 0 无 / 1 待处理 / 2 已同意 / 3 已婉拒 / 4 已取消 */
  leave_status: number;
}

export interface CourseScheduleSummary {
  child_id: string;
  child_name: string;
  course_id: string;
  course_title: string;
  course_cover: string | null;
  class_id: string;
  studio_name: string;
  teacher_name: string;
  total_lessons: number;
  consumed_lessons: number;
  remaining_lessons: number;
  scheduled_count?: number;
  pending_lessons?: number;
  list: CourseScheduleItem[];
}

export function listMyCourses(childId?: string): Promise<{
  children: Array<{ child_id: string; child_name: string }>;
  list: MyCourseItem[];
}> {
  const query = childId ? `?child_id=${encodeURIComponent(childId)}` : "";
  return request({ url: `/parent/my-courses${query}`, method: "GET" });
}

export function getCourseSchedules(params: {
  child_id: string;
  course_id: string;
}): Promise<CourseScheduleSummary> {
  const query = `?child_id=${encodeURIComponent(params.child_id)}&course_id=${encodeURIComponent(params.course_id)}`;
  return request({ url: `/parent/course-schedules${query}`, method: "GET" });
}

// MARK: - 请假（家长端）

export interface MyLeaveItem {
  leave_id: string;
  schedule_id: string;
  child_id: string;
  /** 0 待审批 / 1 已同意 / 2 已婉拒 / 3 已取消 */
  status: number;
}

export function listMyLeaves(): Promise<{ list: MyLeaveItem[] }> {
  return request({ url: "/leave?page=1&page_size=50", method: "GET" });
}

export function submitLeave(params: {
  class_id: string;
  child_id: string;
  schedule_id?: string;
  reason: string;
}): Promise<any> {
  return request({ url: "/leave", method: "POST", data: params });
}

export function cancelLeave(leaveId: string): Promise<any> {
  return request({ url: `/leave/${leaveId}/cancel`, method: "PUT", data: {} });
}

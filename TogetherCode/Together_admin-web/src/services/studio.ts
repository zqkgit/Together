import request from "../utils/request";
import type { PagedList, AuditItem, StaffItem } from "./admin";

// ============ 通用 ============

export interface Paged<T> {
  total: number;
  list: T[];
}

// ============ 教师管理 ============

export interface TeacherApplicationItem {
  id: string;
  user_id: string;
  real_name: string;
  subjects: string[];
  years: number;
  intro: string | null;
  cert_no: string | null;
  portfolio: string[];
  status: number;
  submitted_at: string;
  reviewed_at: string | null;
  review_reason: string | null;
  phone: string;
  nickname: string;
  avatar: string | null;
}

export interface TeacherStaffItem {
  binding_id: string;
  teacher_id: string;
  user_id: string;
  real_name: string;
  subjects: string[];
  years: number;
  intro: string | null;
  cert_no: string | null;
  cert_status: number;
  rating: number;
  student_count: number;
  phone: string;
  nickname: string;
  avatar: string | null;
  bound_at: string;
}

export async function fetchStudioTeachers(params: {
  status?: number | "";
} = {}): Promise<{ applications: TeacherApplicationItem[]; staff: TeacherStaffItem[] }> {
  const response = await request.get("/studio/teachers", { params });
  return response.data;
}

export async function reviewTeacherApplication(
  id: string,
  payload: { action: "approve" | "reject"; reason?: string }
): Promise<{ id: string; status: number; action: string; teacher_id?: string }> {
  const response = await request.put(`/studio/teachers/${id}`, payload);
  return response.data;
}

export async function releaseTeacher(
  teacherId: string
): Promise<{ binding_id: string; teacher_id: string; studio_id: string; status: number; action: string }> {
  const response = await request.delete(`/studio/teachers/${teacherId}`);
  return response.data;
}

export interface StudentLessonLogItem {
  log_id: string;
  course_id: string;
  course_title: string;
  order_id: string;
  schedule_id: string | null;
  lesson_date: string | null;
  start_time: string | null;
  end_time: string | null;
  is_makeup: boolean;
  source: number;
  type: number;
  delta: number;
  balance_after: number;
  note: string | null;
  created_at: string;
}

export async function fetchStudentLessonLogs(
  childId: string,
  params: { limit?: number } = {}
): Promise<{ child_id: string; nickname: string; total: number; list: StudentLessonLogItem[] }> {
  const response = await request.get(`/studio/students/${childId}/logs`, { params });
  return response.data;
}

// ============ 经营概览 ============

export interface StudioOverview {
  statCards: Array<{ label: string; value: string; trend: string }>;
  summary: {
    order_total: number;
    gmv_total: number;
    gmv_total_text: string;
    order_month: number;
    gmv_month: number;
    gmv_month_text: string;
    student_active: number;
    course_total: number;
    course_online: number;
    class_total: number;
  };
  trend30d: Array<{ date: string; gmv: number }>;
  todos: {
    refunds: Array<{
      refund_id: string;
      child_nickname: string;
      course_title: string;
      amount: number;
      created_at: string;
    }>;
    leaves: Array<{
      leave_id: string;
      child_nickname: string;
      class_name: string;
      lesson_date: string | null;
      created_at: string;
    }>;
  };
}

export async function fetchStudioOverview(): Promise<StudioOverview> {
  const response = await request.get("/studio/overview");
  return response.data;
}

// ============ 工作室资料 ============

export interface StudioProfileInfo {
  studio_id: string;
  user_id: string;
  name: string;
  cover: string | null;
  type_tags: string[];
  intro: string | null;
  address: string | null;
  lng: number | null;
  lat: number | null;
  phone: string | null;
  hours: string | null;
  license: string | null;
  legal_id: string | null;
  permit: string | null;
  photos: string[];
  settle_rate: number;
  plan_tier: number;
  status: number;
  banned_at: string | null;
  ban_reason: string | null;
  owner: {
    user_id: string;
    phone: string;
    nickname: string;
    avatar: string | null;
    city: string | null;
  } | null;
}

export async function fetchStudioProfile(): Promise<StudioProfileInfo> {
  const response = await request.get("/studio/profile");
  return response.data;
}

export async function updateStudioProfile(payload: Record<string, unknown>): Promise<StudioProfileInfo> {
  const response = await request.put("/studio/profile", payload);
  return response.data;
}

// ============ 课程管理 ============

export const COURSE_CATEGORIES = [
  { value: 1, label: "美术绘画" },
  { value: 2, label: "综合材料" },
  { value: 3, label: "亲子手作" },
  { value: 4, label: "书法" },
  { value: 5, label: "其他" }
];

export interface CoursePackage {
  package_id?: string;
  name: string;
  lessons: number;
  price: number;
  original_price: number | null;
  status?: number;
}

export interface CourseItem {
  course_id: string;
  title: string;
  cover: string | null;
  category: number;
  age_min: number;
  age_max: number;
  total_lessons: number;
  duration_min: number;
  price: number;
  class_size: number;
  rating: number;
  sales: number;
  distribute_rate: number;
  validity_days: number;
  status: number;
  studio: { studio_id: string; name: string; address: string; phone: string } | null;
  teacher: { teacher_id: string; real_name: string; intro: string; rating: number } | null;
  packages: CoursePackage[];
}

export interface CoursePayload {
  studio_id: string;
  teacher_id?: string;
  title: string;
  cover?: string;
  category: number;
  age_min?: number;
  age_max?: number;
  total_lessons: number;
  duration_min: number;
  price: number;
  class_size?: number;
  distribute_rate?: number;
  validity_days?: number;
  status?: number;
  packages: CoursePackage[];
}

export async function fetchStudioCourses(params: {
  studio_id?: string;
  q?: string;
  category?: number | "";
  status?: number | "";
} = {}): Promise<CourseItem[]> {
  const response = await request.get("/studio/courses", { params });
  return response.data.list;
}

export async function fetchCourseDetail(id: string): Promise<CourseItem> {
  const response = await request.get(`/studio/courses/${id}`);
  return response.data;
}

export async function createCourse(payload: CoursePayload): Promise<CourseItem> {
  const response = await request.post("/studio/courses", payload);
  return response.data;
}

export async function updateCourse(id: string, payload: CoursePayload): Promise<CourseItem> {
  const response = await request.put(`/studio/courses/${id}`, payload);
  return response.data;
}

// ============ 班级管理 ============

export interface ClassItem {
  class_id: string;
  course_id: string;
  teacher_id: string | null;
  name: string;
  schedule_rule: { weekday: number[]; time: string } | null;
  start_date: string | null;
  end_date: string | null;
  capacity: number;
  enrolled: number;
  course: {
    course_id: string;
    title: string;
    duration_min: number;
    class_size: number;
  } | null;
  teacher: { teacher_id: string; real_name: string; rating: number } | null;
}

export async function fetchStudioClasses(params: {
  studio_id: string;
  q?: string;
}): Promise<Paged<ClassItem>> {
  const response = await request.get("/studio/classes", { params });
  return response.data;
}

export async function createStudioClass(payload: {
  studio_id: string;
  course_id: string;
  name: string;
  schedule_rule: { weekday: number[]; time: string };
  start_date?: string;
  end_date?: string;
  capacity?: number;
}): Promise<ClassItem> {
  const response = await request.post("/studio/classes", payload);
  return response.data;
}

export interface ClassStudent {
  child_id: string;
  nickname: string;
  birthday: string | null;
  gender: string;
  balance_id: string;
  order_id: string;
  remaining_lessons: number;
  consumed_lessons: number;
  last_attended_at: string | null;
}

export async function fetchClassStudents(classId: string): Promise<{ class: ClassItem; students: ClassStudent[] }> {
  const response = await request.get(`/studio/classes/${classId}/students`);
  return response.data;
}

// ============ 排课管理 ============

export interface ScheduleItem {
  schedule_id: string;
  studio_id: string;
  class_id: string;
  course_id: string;
  teacher_id: string | null;
  lesson_date: string;
  start_time: string;
  end_time: string;
  location: string | null;
  is_makeup: boolean;
  makeup_from: string | null;
  status: number;
  remark: string | null;
  class: { class_id: string; name: string; capacity: number; enrolled: number } | null;
  course: { course_id: string; title: string } | null;
  teacher: { teacher_id: string; real_name: string } | null;
}

export async function fetchStudioSchedules(params: {
  studio_id: string;
  week?: string;
  class_id?: string;
}): Promise<Paged<ScheduleItem>> {
  const response = await request.get("/studio/schedules", { params });
  return response.data;
}

export async function createStudioSchedule(payload: {
  studio_id: string;
  class_id: string;
  teacher_id?: string;
  lesson_date: string;
  start_time: string;
  end_time: string;
  location?: string;
  is_makeup?: boolean;
  makeup_from?: string;
  remark?: string;
}): Promise<ScheduleItem> {
  const response = await request.post("/studio/schedules", payload);
  return response.data;
}

export interface AttendanceStudent {
  child_id: string;
  order_id: string;
  status: number; // 1 正常 2 迟到 3 请假
  count?: number;
  note?: string;
}

export async function submitScheduleAttendance(
  scheduleId: string,
  students: AttendanceStudent[],
  note?: string
): Promise<ScheduleItem> {
  const response = await request.post(`/studio/schedules/${scheduleId}/attendance`, { students, note });
  return response.data;
}

// ============ 学员管理 ============

export interface StudentBalance {
  balance_id: string;
  order_id: string;
  course_id: string;
  course_title: string;
  total_lessons: number;
  consumed_lessons: number;
  refunded_lessons: number;
  remaining_lessons: number;
  valid_from: string | null;
  valid_to: string | null;
  status: number;
}

export interface StudentItem {
  child_id: string;
  nickname: string;
  birthday: string | null;
  gender: string;
  total_remaining_lessons: number;
  status: "active" | "empty";
  balances: StudentBalance[];
}

export async function fetchStudioStudents(params: {
  studio_id: string;
  q?: string;
  status?: string;
}): Promise<Paged<StudentItem>> {
  const response = await request.get("/studio/students", { params });
  return response.data;
}

export async function consumeStudentLessons(
  childId: string,
  payload: { order_id: string; count?: number; note?: string }
): Promise<unknown> {
  const response = await request.post(`/studio/students/${childId}/consume`, payload);
  return response.data;
}

// ============ 订单管理 ============

export interface OrderItem {
  order_id: string;
  order_no: string;
  status: number;
  total_lessons: number;
  consumed_lessons: number;
  refunded_lessons: number;
  remaining_lessons: number;
  total_amount: number;
  paid_amount: number;
  refund_amount: number;
  pay_channel: string;
  paid_at: string | null;
  created_at: string;
  child: { child_id: string; nickname: string; birthday: string | null } | null;
  course: { course_id: string; title: string; cover: string | null } | null;
  package: { package_id: string; name: string; lessons: number } | null;
  items: Array<{
    item_id: string;
    course_title: string;
    package_name: string;
    lessons: number;
    unit_price: number;
    total_price: number;
  }>;
  balance: {
    balance_id: string;
    total_lessons: number;
    consumed_lessons: number;
    refunded_lessons: number;
    remaining_lessons: number;
    valid_from: string | null;
    valid_to: string | null;
    status: number;
  } | null;
}

export async function fetchStudioOrders(params: { status?: number | "" } = {}): Promise<Paged<OrderItem>> {
  const response = await request.get("/studio/orders", { params });
  return response.data;
}

export async function fetchStudioOrderDetail(id: string): Promise<OrderItem> {
  const response = await request.get(`/studio/orders/${id}`);
  return response.data;
}

// ============ 退款管理 ============

export interface RefundItem {
  refund_id: string;
  order_id: string;
  user_id: string;
  requested_lessons: number;
  refundable_lessons: number;
  unit_price: number;
  amount: number;
  reason: string;
  status: number;
  reviewed_by: string | null;
  reviewed_at: string | null;
  refunded_at: string | null;
  created_at: string;
  order: {
    order_id: string;
    order_no: string;
    status: number;
    total_lessons: number;
    consumed_lessons: number;
    refunded_lessons: number;
    paid_amount: number;
    refund_amount: number;
    paid_at: string | null;
    child: { child_id: string; nickname: string } | null;
    course: { course_id: string; title: string; cover: string | null } | null;
    user: { user_id: string; nickname: string; phone: string } | null;
    balance: {
      balance_id: string;
      total_lessons: number;
      consumed_lessons: number;
      refunded_lessons: number;
      remaining_lessons: number;
      valid_from: string | null;
      valid_to: string | null;
      status: number;
    } | null;
  } | null;
}

export async function fetchStudioRefunds(params: { status?: number | "" } = {}): Promise<Paged<RefundItem>> {
  const response = await request.get("/studio/refunds", { params });
  return response.data;
}

export async function reviewStudioRefund(
  id: string,
  payload: { action: "approve" | "reject"; reason?: string }
): Promise<RefundItem> {
  const response = await request.put(`/studio/refunds/${id}`, payload);
  return response.data;
}

// ============ 请假审批 ============

export interface LeaveItem {
  leave_id: string;
  class_id: string;
  child_id: string;
  schedule_id: string | null;
  reason: string;
  status: number;
  makeup_status: number;
  makeup_schedule_id: string | null;
  handled_at: string | null;
  created_at: string;
  classItem: { class_id: string; name: string } | null;
  course: { course_id: string; title: string } | null;
  child: { child_id: string; nickname: string; birthday: string | null } | null;
  parent: { user_id: string; phone: string; nickname: string } | null;
  schedule: { schedule_id: string; lesson_date: string; start_time: string; end_time: string; location: string | null } | null;
  makeupSchedule: { schedule_id: string; lesson_date: string; start_time: string; end_time: string; location: string | null } | null;
}

export async function fetchStudioLeaves(params: {
  studio_id: string;
  status?: number | "";
}): Promise<Paged<LeaveItem>> {
  const response = await request.get("/studio/leaves", { params });
  return response.data;
}

export async function reviewLeave(
  id: string,
  payload: { action: "agree" | "reject"; note?: string }
): Promise<LeaveItem> {
  const response = await request.put(`/studio/leaves/${id}`, payload);
  return response.data;
}

export async function handleLeaveMakeup(
  id: string,
  payload: { action: "assign" | "abandon"; makeup_schedule_id?: string }
): Promise<LeaveItem> {
  const response = await request.put(`/studio/leaves/${id}/makeup`, payload);
  return response.data;
}

// ============ 工作室治理（财务对账 / 结算账户 / 操作审计 / 员工账号） ============

export interface StudioFinanceData {
  period: { start_date: string; end_date: string };
  summary: {
    gmv_total: number;
    gmv_period: number;
    refund_total: number;
    refund_period: number;
    distribution_total: number;
    net_total: number;
    net_period: number;
  };
  orders: Array<{
    order_id: string;
    order_no: string;
    total_amount: number;
    status: number;
    paid_at: string | null;
  }>;
}

export async function fetchStudioFinance(params: { start_date?: string; end_date?: string } = {}): Promise<StudioFinanceData> {
  const response = await request.get("/studio/finance", { params });
  return response.data;
}

export interface StudioAccountItem {
  account_id: string;
  account_type: "bank" | "wechat" | "alipay";
  account_name: string;
  account_no: string;
  bank_name: string | null;
  is_default: number;
  status: number;
}

export async function fetchStudioAccounts(): Promise<PagedList<StudioAccountItem>> {
  const response = await request.get("/studio/accounts");
  return response.data;
}

export async function upsertStudioAccount(payload: {
  account_id?: string;
  account_type: "bank" | "wechat" | "alipay";
  account_name: string;
  account_no: string;
  bank_name?: string;
  is_default?: number;
}): Promise<StudioAccountItem> {
  const response = await request.post("/studio/accounts", payload);
  return response.data;
}

export async function fetchStudioAudit(params: { page?: number; page_size?: number; action?: string } = {}): Promise<PagedList<AuditItem>> {
  const response = await request.get("/studio/audit", { params });
  return response.data;
}

export async function fetchStudioStaff(params: { q?: string } = {}): Promise<PagedList<StaffItem>> {
  const response = await request.get("/studio/staff", { params });
  return response.data;
}

export async function createStudioStaff(payload: { username: string; password: string; name?: string }): Promise<StaffItem> {
  const response = await request.post("/studio/staff", payload);
  return response.data;
}

export async function toggleStudioStaffStatus(id: string, status: 0 | 1): Promise<{ admin_id: string; status: number }> {
  const response = await request.put(`/studio/staff/${id}`, { status });
  return response.data;
}

// ============ 经营报表 ============

export interface StudioReportData {
  revenue: { month_gmv: number; total_gmv: number; month_refund: number; total_refund: number; net_total: number };
  lessons: { sold: number; consumed: number; remaining: number };
  students: { total: number; active: number; month_new: number };
  operations: { courses: number; classes: number; teachers: number };
  recent_refunds: Array<{ refund_id: string; amount: number; status: number; reviewed_at: string | null }>;
}

export async function fetchStudioReport(): Promise<StudioReportData> {
  const response = await request.get("/studio/reports");
  return response.data;
}

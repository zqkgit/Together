import request from "../utils/request";

export interface AdminAccountInfo {
  admin_id: string;
  user_id: string | null;
  username: string;
  role: string;
  scope: string;
  studio_id: string | null;
  studio: { studio_id: string; name: string } | null;
  user: { user_id: string; phone: string; nickname: string; avatar: string | null } | null;
}

export interface LoginResult {
  access_token: string;
  refresh_token: string;
  account: AdminAccountInfo;
}

export async function loginAdmin(username: string, password: string): Promise<LoginResult> {
  const response = await request.post("/admin/auth/login", { username, password });
  return response.data;
}

export async function loginStudio(username: string, password: string): Promise<LoginResult> {
  const response = await request.post("/studio/auth/login", { username, password });
  return response.data;
}

export async function logoutAdmin(): Promise<void> {
  await request.post("/admin/auth/logout");
}

export async function logoutStudio(): Promise<void> {
  await request.post("/studio/auth/logout");
}

export interface DashboardOverview {
  statCards: Array<{ label: string; value: string; trend: string }>;
  summary: {
    studio_total: number;
    studio_new_month: number;
    student_total: number;
    student_active: number;
    course_total: number;
    order_month: number;
    gmv_month: number;
    gmv_month_text: string;
  };
  trend30d: Array<{ date: string; gmv: number }>;
  todos: Array<{ label: string; count: number }>;
}

export interface StudioItem {
  id: string;
  name: string;
  city: string;
  status: string;
  status_code: number;
  owner: string;
  owner_phone: string;
  courses: number;
  created_at: string;
}

export interface StudioDetail {
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
  stats: {
    orders: number;
    gmv_raw: number;
    gmv: string;
    students: number;
    courses: number;
  };
  owner: {
    user_id: string;
    phone: string;
    nickname: string;
    avatar: string | null;
    city: string | null;
  } | null;
  latest_application: {
    id: string;
    version: number;
    status: number;
    submitted_at: string;
    reviewed_at: string | null;
    review_reason: string | null;
  } | null;
  operator?: {
    admin_id: string;
    username: string;
    role: string;
  } | null;
}

export interface StudioListParams {
  page?: number;
  size?: number;
  keyword?: string;
}

export type ReviewStatus = 0 | 1 | 2;

export interface ReviewItem {
  id: string;
  name: string;
  type: string;
  applicant: string;
  applicant_phone: string;
  status: ReviewStatus;
  submittedAt: string;
}

export interface ReviewDetail {
  id: string;
  user_id: string;
  version: number;
  name: string;
  cover: string | null;
  intro: string | null;
  address: string | null;
  phone: string | null;
  license: string | null;
  permit: string | null;
  photos: string[];
  status: ReviewStatus;
  submitted_at: string;
  reviewed_at: string | null;
  review_reason: string | null;
  applicant: {
    user_id: string;
    phone: string;
    nickname: string;
    avatar: string | null;
    city: string | null;
  } | null;
}

export interface ReviewListParams {
  status?: ReviewStatus | "";
  page?: number;
  size?: number;
  keyword?: string;
}

export interface SettlementItem {
  id: string;
  settlement_id: string;
  studio_id: string;
  studio: string;
  period: string;
  period_start: string;
  period_end: string;
  income: string;
  refund: string;
  distribution: string;
  net_amount: string;
  fee_rate: number;
  fee_amount: string;
  payable: string;
  payable_amount: number;
  status: number;
  status_text: string;
  pay_no: string | null;
  paid_at: string | null;
  created_at: string;
}

export interface SettlementsData {
  summary: {
    pendingNetAmount: string;
    pendingNetTrend: string;
    retryCount: number;
    retryHint: string;
    pendingCount: number;
  };
  list: SettlementItem[];
}

export interface GenerateSettlementsResult {
  created: Array<{ studio_id: string; studio: string; income: string; refund: string; payable: string }>;
  skipped: Array<{ studio_id: string; studio: string }>;
  period: { period_start: string; period_end: string };
  message: string;
}

export async function fetchDashboardOverview(): Promise<DashboardOverview> {
  const response = await request.get("/admin/dashboard/overview");
  return response.data;
}

export async function fetchStudios(params: StudioListParams = {}): Promise<{
  total: number;
  page: number;
  size: number;
  list: StudioItem[];
}> {
  const response = await request.get("/admin/studios", { params });
  return response.data;
}

export async function fetchStudioDetail(id: string): Promise<StudioDetail> {
  const response = await request.get(`/admin/studios/${id}`);
  return response.data;
}

export async function banStudio(id: string, reason: string): Promise<StudioDetail> {
  const response = await request.put(`/admin/studios/${id}/ban`, { reason });
  return response.data;
}

export async function unbanStudio(id: string): Promise<StudioDetail> {
  const response = await request.put(`/admin/studios/${id}/unban`);
  return response.data;
}

export async function fetchReviews(params: ReviewListParams = {}): Promise<{
  total: number;
  page: number;
  size: number;
  list: ReviewItem[];
}> {
  const response = await request.get("/admin/reviews", { params });
  return response.data;
}

export async function fetchReviewDetail(id: string): Promise<ReviewDetail> {
  const response = await request.get(`/admin/reviews/${id}`);
  return response.data;
}

export async function handleReview(
  id: string,
  payload: { action: "approve" | "reject"; reason?: string }
): Promise<ReviewDetail> {
  const response = await request.put(`/admin/reviews/${id}`, payload);
  return response.data;
}

export async function fetchSettlements(): Promise<SettlementsData> {
  const response = await request.get("/admin/settlements");
  return response.data;
}

export async function generateSettlements(period?: {
  period_start?: string;
  period_end?: string;
}): Promise<GenerateSettlementsResult> {
  const response = await request.post("/admin/settlements/generate", period || {});
  return response.data;
}

export async function payoutSettlement(id: string): Promise<SettlementItem> {
  const response = await request.post(`/admin/settlements/${id}/payout`);
  return response.data;
}

// ============ 平台老师认证审核 ============

export interface TeacherCertItem {
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

export async function fetchTeacherCertifications(
  params: { status?: number | "" } = {}
): Promise<{ total: number; list: TeacherCertItem[] }> {
  const response = await request.get("/admin/teacher-applications", { params });
  return response.data;
}

export async function reviewTeacherCertification(
  id: string,
  payload: { action: "approve" | "reject"; reason?: string }
): Promise<{ id: string; status: number; action: string; teacher_id?: string }> {
  const response = await request.put(`/admin/teacher-applications/${id}`, payload);
  return response.data;
}

// ============ 平台老师管理（已认证档案） ============

export interface TeacherProfileItem {
  teacher_id: string;
  user_id: string;
  real_name: string;
  phone: string;
  nickname: string;
  avatar: string | null;
  subjects: string[];
  years: number;
  intro: string | null;
  cert_no: string | null;
  cert_status: number;
  studio_id: string | null;
  studio_name: string | null;
  studios: Array<{ studio_id: string; name: string | null; bound_at: string }>;
  rating: number;
  student_count: number;
  work_count: number;
  created_at: string;
}

export async function fetchTeacherProfiles(
  params: { cert_status?: number | ""; q?: string } = {}
): Promise<{ total: number; list: TeacherProfileItem[] }> {
  const response = await request.get("/admin/teachers", { params });
  return response.data;
}

// ============ 标签管理 ============

export interface TagItem {
  tag_id: string;
  name: string;
  scope: number;
  sort: number;
  status: number;
}

export async function fetchTags(params: { scope?: number | ""; q?: string } = {}): Promise<TagItem[]> {
  const response = await request.get("/admin/tags", { params });
  return response.data;
}

export async function createTag(payload: { name: string; scope: number; sort?: number }): Promise<TagItem> {
  const response = await request.post("/admin/tags", payload);
  return response.data;
}

export async function updateTag(
  id: string,
  payload: { name?: string; scope?: number; sort?: number; status?: number }
): Promise<TagItem> {
  const response = await request.put(`/admin/tags/${id}`, payload);
  return response.data;
}

export async function deleteTag(id: string): Promise<{ tag_id: string; status?: number; deleted?: boolean }> {
  const response = await request.delete(`/admin/tags/${id}`);
  return response.data;
}

// ============ 平台治理（举报处置 / 内容管理 / 配置 / 公告 / 员工 / 审计） ============

export interface PagedList<T> {
  total: number;
  page: number;
  page_size: number;
  list: T[];
}

export interface ReportItem {
  report_id: string;
  reporter: { user_id: string; nickname: string; phone: string } | null;
  target_type: string;
  target_id: string;
  reason: string;
  detail: string | null;
  images: string[];
  status: number;
  status_text: string;
  handle_note: string | null;
  handled_at: string | null;
  created_at: string;
}

export async function fetchReports(params: { status?: number | ""; target_type?: string } = {}): Promise<PagedList<ReportItem>> {
  const response = await request.get("/admin/reports", { params });
  return response.data;
}

export async function handleReport(id: string, payload: { status: 1 | 2; handle_note?: string }): Promise<ReportItem> {
  const response = await request.put(`/admin/reports/${id}`, payload);
  return response.data;
}

export interface AdminPostItem {
  post_id: string;
  author: { user_id: string; nickname: string; phone: string } | null;
  course: { course_id: string; title: string } | null;
  content: string;
  images: string[];
  like_count: number;
  comment_count: number;
  share_count: number;
  status: number;
  visibility: number;
  created_at: string;
}

export async function fetchAdminPosts(params: { status?: number | ""; q?: string } = {}): Promise<PagedList<AdminPostItem>> {
  const response = await request.get("/admin/posts", { params });
  return response.data;
}

export async function moderatePost(id: string, status: 0 | 1): Promise<{ post_id: string; status: number }> {
  const response = await request.put(`/admin/posts/${id}/moderate`, { status });
  return response.data;
}

export interface PlatformConfigData {
  configs: Record<string, string | number>;
  list: Array<{ config_key: string; description: string }>;
}

export async function fetchPlatformConfig(): Promise<PlatformConfigData> {
  const response = await request.get("/admin/config");
  return response.data;
}

export async function updatePlatformConfig(configs: Record<string, string | number>): Promise<{ updated: string[] }> {
  const response = await request.put("/admin/config", configs);
  return response.data;
}

export interface AnnouncementItem {
  announcement_id: string;
  title: string;
  content: string | null;
  type: number;
  image: string[];
  link: string | null;
  status: number;
  publish_at: string | null;
  expire_at: string | null;
  created_at: string;
}

export async function fetchAnnouncements(params: { status?: number | ""; type?: number | "" } = {}): Promise<PagedList<AnnouncementItem>> {
  const response = await request.get("/admin/announcements", { params });
  return response.data;
}

export async function createAnnouncement(payload: {
  title: string;
  content?: string;
  type: 1 | 2;
  image?: string[];
  link?: string;
  status?: number;
  publish_at?: string;
  expire_at?: string;
}): Promise<AnnouncementItem> {
  const response = await request.post("/admin/announcements", payload);
  return response.data;
}

export async function toggleAnnouncement(id: string, status: 0 | 1): Promise<{ announcement_id: string; status: number }> {
  const response = await request.put(`/admin/announcements/${id}`, { status });
  return response.data;
}

export interface StaffItem {
  admin_id: string;
  username: string;
  role: string;
  status: number;
  created_at: string;
}

export async function fetchAdminStaff(params: { q?: string } = {}): Promise<PagedList<StaffItem>> {
  const response = await request.get("/admin/staff", { params });
  return response.data;
}

export async function createAdminStaff(payload: { username: string; password: string; name?: string }): Promise<StaffItem> {
  const response = await request.post("/admin/staff", payload);
  return response.data;
}

export async function toggleStaffStatus(id: string, status: 0 | 1): Promise<{ admin_id: string; status: number }> {
  const response = await request.put(`/admin/staff/${id}`, { status });
  return response.data;
}

export interface AuditItem {
  log_id: string;
  actor_name: string;
  role: string;
  action: string;
  target_type: string | null;
  target_id: string | null;
  detail: string | null;
  ip: string | null;
  created_at: string;
}

export async function fetchAdminAudit(params: { page?: number; page_size?: number; action?: string; actor_name?: string } = {}): Promise<PagedList<AuditItem>> {
  const response = await request.get("/admin/audit", { params });
  return response.data;
}

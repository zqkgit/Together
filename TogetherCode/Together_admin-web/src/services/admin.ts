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

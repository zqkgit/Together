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
  courses: number;
}

export interface ReviewItem {
  id: string;
  name: string;
  type: string;
  studio: string;
  submittedAt: string;
}

export interface SettlementsData {
  summary: {
    pendingNetAmount: string;
    pendingNetTrend: string;
    retryCount: number;
    retryHint: string;
  };
  list: Array<{
    id: string;
    studio: string;
    period: string;
    income: string;
    refund: string;
    payable: string;
  }>;
}

export async function fetchDashboardOverview(): Promise<DashboardOverview> {
  const response = await request.get("/admin/dashboard/overview");
  return response.data;
}

export async function fetchStudios(): Promise<StudioItem[]> {
  const response = await request.get("/admin/studios");
  return response.data;
}

export async function fetchReviews(): Promise<{ total: number; list: ReviewItem[] }> {
  const response = await request.get("/admin/reviews");
  return response.data;
}

export async function fetchSettlements(): Promise<SettlementsData> {
  const response = await request.get("/admin/settlements");
  return response.data;
}

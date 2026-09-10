import request from "../utils/request";

export interface DashboardOverview {
  statCards: Array<{ label: string; value: string; trend: string }>;
  timeline: Array<{ timestamp: string; content: string }>;
  todos: string[];
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

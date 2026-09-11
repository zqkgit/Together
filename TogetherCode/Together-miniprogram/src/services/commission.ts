import { request } from "./request";

export interface CommissionSummary {
  total_commission: number;
  available_balance: number;
  pending_amount: number;
  withdrawn_amount: number;
}

export interface CommissionRecord {
  record_id: string;
  amount: number;
  type: string;
  status: number;
  source: string;
  created_at: string;
}

export function getCommissionSummary(): Promise<CommissionSummary> {
  return request({ url: "/distribution/commission/summary", method: "GET" });
}

export function getCommissionRecords(params: { page?: number; page_size?: number } = {}): Promise<{
  total: number;
  list: CommissionRecord[];
}> {
  const q = `page=${params.page || 1}&page_size=${params.page_size || 20}`;
  return request({ url: `/distribution/commission/records?${q}`, method: "GET" });
}

export function withdrawCommission(amount: number): Promise<any> {
  return request({ url: "/distribution/commission/withdraw", method: "POST", data: { amount } });
}

export function createDistributionLink(course_id: string): Promise<any> {
  return request({ url: "/distribution/link", method: "POST", data: { course_id } });
}

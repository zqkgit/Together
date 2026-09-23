import { request } from "./request";

// MARK: - 收益总览（含按工作室分组）
export interface CommissionStats {
  total_commission: number;
  receivable_commission: number;
  applying_commission: number;
  settled_commission: number;
}

export interface StudioGroup {
  studio_id: string;
  name: string | null;
  cover: string | null;
  receivable: number;
  applying: number;
  settled: number;
  total: number;
}

export interface CommissionSummary {
  stats: CommissionStats;
  studios: StudioGroup[];
}

// MARK: - 佣金明细（可按工作室过滤）
export interface CourseBrief {
  course_id: string;
  title: string | null;
  cover: string | null;
}

export interface StudioBrief {
  studio_id: string;
  name: string | null;
  cover: string | null;
}

export interface CommissionRecord {
  commission_id: string;
  order_id: string | null;
  amount: number;
  rate: number;
  status: number;
  status_text: string | null;
  created_at: string | null;
  studio: StudioBrief | null;
  course: CourseBrief | null;
}

// MARK: - 领取单
export interface CommissionWithdrawal {
  withdraw_id: string;
  studio: StudioBrief | null;
  amount: number;
  amount_text: string | null;
  method: string | null;
  method_text: string | null;
  account: string | null;
  /** 0 待工作室审核 / 1 待推广人确认 / 2 已驳回 / 3 已完成 */
  status: number;
  status_text: string | null;
  voucher_images: string[] | null;
  reject_reason: string | null;
  created_at: string | null;
  processed_at: string | null;
  confirmed_at: string | null;
  can_confirm: boolean | null;
  commissions: WithdrawalCommission[] | null;
  steps: WithdrawalStep[] | null;
}

export interface WithdrawalCommission {
  commission_id: string;
  order_id: string | null;
  amount: number;
  rate: number;
  status: number | null;
  status_text: string | null;
  created_at: string | null;
}

export interface WithdrawalStep {
  title: string | null;
  done: boolean | null;
  current: boolean | null;
}

// MARK: - 下收款方式
export const PAY_METHODS = [
  { value: "wechat", label: "微信转账" },
  { value: "alipay", label: "支付宝转账" },
  { value: "bank", label: "银行转账" },
  { value: "qrcode", label: "收款码" },
  { value: "cash", label: "现金" },
  { value: "other", label: "其他" },
] as const;

// MARK: - API

/** 收益总览（含按工作室分组） */
export function getCommissionSummary(): Promise<CommissionSummary> {
  return request({ url: "/distribution/commission/summary", method: "GET" });
}

/** 佣金明细（可按工作室过滤，前端再按课程分组） */
export function getCommissionRecords(params: {
  studio_id?: string;
  page?: number;
  page_size?: number;
} = {}): Promise<{ total: number; list: CommissionRecord[] }> {
  const q = Object.entries(params)
    .filter(([, v]) => v !== undefined)
    .map(([k, v]) => `${k}=${v}`)
    .join("&");
  return request({ url: `/distribution/commission/records?${q}`, method: "GET" });
}

/** 发起领取：一次领取某工作室全部「待申请」佣金 */
export function requestWithdraw(studioId: string, method: string): Promise<CommissionWithdrawal> {
  return request({
    url: "/distribution/commission/withdraw",
    method: "POST",
    data: { studio_id: studioId, method },
  });
}

/** 领取单列表（分页） */
export function getWithdrawals(params: {
  page?: number;
  page_size?: number;
} = {}): Promise<{ total: number; list: CommissionWithdrawal[] }> {
  const q = Object.entries(params)
    .filter(([, v]) => v !== undefined)
    .map(([k, v]) => `${k}=${v}`)
    .join("&");
  return request({ url: `/distribution/commission/withdrawals?${q}`, method: "GET" });
}

/** 题取单详情 */
export function getWithdrawalDetail(id: string): Promise<CommissionWithdrawal> {
  return request({ url: `/distribution/commission/withdrawals/${id}`, method: "GET" });
}

/** 推广人确认已在线下收到佣金 */
export function confirmWithdrawal(id: string): Promise<CommissionWithdrawal> {
  return request({ url: `/distribution/commission/withdrawals/${id}/confirm`, method: "POST" });
}

/** 创建分销链接 */
export function createDistributionLink(course_id: string): Promise<any> {
  return request({ url: "/distribution/link", method: "POST", data: { course_id } });
}

// MARK: - 工具函数

export function yuan(value: number | null | undefined): string {
  return `¥${(value ?? 0).toFixed(2)}`;
}

export function fmtTime(iso: string | null | undefined): string {
  if (!iso) return "";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "";
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  const hh = String(d.getHours()).padStart(2, "0");
  const mi = String(d.getMinutes()).padStart(2, "0");
  return `${mm}-${dd} ${hh}:${mi}`;
}

export function fmtFull(iso: string | null | undefined): string {
  if (!iso) return "-";
  const d = new Date(iso);
  if (isNaN(d.getTime())) return "-";
  const y = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  const hh = String(d.getHours()).padStart(2, "0");
  const mi = String(d.getMinutes()).padStart(2, "0");
  return `${y}-${mm}-${dd} ${hh}:${mi}`;
}
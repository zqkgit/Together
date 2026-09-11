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

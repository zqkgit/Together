import request from "../utils/request";

export interface StudioProfileInfo {
  studio_id: string;
  user_id: string;
  name: string;
  cover: string | null;
  type_tags: string[];
  intro: string | null;
  address: string | null;
  phone: string | null;
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

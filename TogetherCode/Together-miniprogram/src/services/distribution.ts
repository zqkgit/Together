import { request } from "./request";

export interface DistributionLink {
  link_id: string;
  code: string;
  share_url: string;
  course: { course_id: string; title: string };
  post_id: string | null;
}

/**
 * 生成分销分享码：发帖人/分享人分享课程时调用
 * - 帖子分享：post_id + course_id（帖子必须本人发布且挂了该课程）
 * - 课程直达分享：仅 course_id
 */
export function createDistributionLink(payload: { course_id: string; post_id?: string }): Promise<DistributionLink> {
  return request({ url: "/distribution/link", method: "POST", data: payload });
}

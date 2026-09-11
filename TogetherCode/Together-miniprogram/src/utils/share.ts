/**
 * 分享归因工具：所有分享链路统一从这里构造 / 解析
 * 规则：分享链接统一带 dist=分享码，落地页解析后随下单提交归因
 */
import Taro from "@tarojs/taro";
import { getAccount } from "../services/request";

const DIST_KEY = "dist";

/** 从当前页面路由参数中解析分享码 */
export function getDistFromParams(): string {
  const params = Taro.getCurrentInstance().router?.params || {};
  return String(params[DIST_KEY] || params.distribution_code || "");
}

/** 构造带分享归因的课程详情路径（分享卡片用） */
export function buildCourseSharePath(courseId: string, distCode: string): string {
  return `/pages/course-detail/index?id=${courseId}&dist=${distCode}`;
}

/** 构造带分享归因的帖子详情路径（分享卡片用） */
export function buildPostSharePath(postId: string, distCode: string): string {
  return `/pages/post-detail/index?id=${postId}&dist=${distCode}`;
}

/** 分享者标识（当前登录用户） */
export function getShareUid(): string {
  const account = getAccount();
  return account?.user?.user_id ? String(account.user.user_id) : "";
}

/** 分享卡片默认图：可用课程/帖子封面或占位图 */
export function buildShareImage(cover: string | null): string {
  return cover || "";
}

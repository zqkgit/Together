import { request } from "./request";

export interface ReviewItem {
  review_id: string;
  rating: number;
  content: string | null;
  images: string[];
  nickname: string;
  avatar: string | null;
  reply_content: string | null;
  reply_at: string | null;
  teacher_reply_content: string | null;
  teacher_reply_at: string | null;
  created_at: string;
}

export interface CourseReviews {
  total: number;
  page: number;
  page_size: number;
  average: number;
  rating_count: number;
  rating_distribution: Record<string, number>;
  list: ReviewItem[];
}

/** 课程评价列表（公开） */
export function getCourseReviews(courseId: string, page = 1): Promise<CourseReviews> {
  return request<any>({ url: `/courses/${courseId}/reviews?page=${page}&page_size=10`, method: "GET" });
}

/** 提交课程评价（登录，需购买过） */
export function postCourseReview(courseId: string, data: { rating: number; content?: string; images?: string[] }): Promise<any> {
  return request({ url: `/courses/${courseId}/reviews`, method: "POST", data });
}

export interface FavoriteItem {
  target_id: string;
  title: string;
  cover: string | null;
  subtitle: string;
  rating?: number;
}

export interface FavoritePage {
  total: number;
  page: number;
  page_size: number;
  target_type: string;
  list: FavoriteItem[];
}

/** 收藏 / 取消收藏 */
export function addFavorite(targetType: string, targetId: string): Promise<any> {
  return request({ url: "/favorites", method: "POST", data: { target_type: targetType, target_id: targetId } });
}

export function removeFavorite(targetType: string, targetId: string): Promise<any> {
  return request({ url: `/favorites?target_type=${targetType}&target_id=${targetId}`, method: "DELETE" });
}

/** 已收藏 id 列表 */
export function getFavoriteIds(targetType: string): Promise<string[]> {
  return request<any>({ url: `/favorites/ids?target_type=${targetType}`, method: "GET" }).then((d) => d?.ids || []);
}

/** 我的收藏列表 */
export function getFavorites(targetType: string, page = 1): Promise<FavoritePage> {
  return request<any>({ url: `/favorites?target_type=${targetType}&page=${page}&page_size=10`, method: "GET" });
}

export interface MyReviewItem {
  review_id: string;
  rating: number;
  content: string | null;
  images: string[];
  reply_content: string | null;
  reply_at: string | null;
  status: number; // 0 待审核 / 1 通过 / 2 驳回
  reject_reason: string | null;
  course: { course_id: string; title: string; cover: string | null } | null;
  created_at: string;
}

export interface MyReviewsPage {
  total: number;
  page: number;
  page_size: number;
  list: MyReviewItem[];
}

/** 我的评价列表 */
export function getMyReviews(page = 1): Promise<MyReviewsPage> {
  return request<any>({ url: `/reviews/mine?page=${page}&page_size=10`, method: "GET" });
}

/** 编辑我的评价（待审核/驳回可改） */
export function updateMyReview(
  reviewId: string,
  data: { rating: number; content?: string; images?: string[] }
): Promise<any> {
  return request({ url: `/reviews/${reviewId}`, method: "PUT", data });
}

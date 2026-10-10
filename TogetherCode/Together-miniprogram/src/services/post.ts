import { request } from "./request";

export interface PostAuthor {
  user_id: string;
  nickname: string;
  avatar: string | null;
  role?: string;
}

export interface PostCourse {
  course_id: string;
  title: string;
  cover: string | null;
  price?: number;
  price_text?: string;
  studio_name?: string;
}

export interface PostItem {
  post_id: string;
  type: number;
  author_role?: number;
  author_role_text?: string;
  content: string;
  images: string[];
  like_count: number;
  comment_count: number;
  share_count: number;
  is_liked: boolean;
  is_favorite?: boolean;
  is_following?: boolean;
  is_mine?: boolean;
  created_at: string;
  author: PostAuthor;
  course?: PostCourse | null;
  child?: { child_id: string; nickname: string } | null;
  students?: Array<{ child_id: string; nickname: string; avatar?: string | null; deducted?: boolean }>;
  location?: { name: string; lat: number; lng: number } | null;
  distance_text?: string;
}

export interface PostComment {
  comment_id: string;
  content: string;
  created_at: string;
  parent_id?: string | null;
  like_count?: number;
  is_liked?: boolean;
  author?: { user_id: string; nickname: string; avatar: string | null };
}

export function getPlazaPosts(params: { page?: number; page_size?: number; sort?: string } = {}): Promise<PostItem[]> {
  const parts = [`page=${params.page || 1}`, `page_size=${params.page_size || 10}`];
  if (params.sort) parts.push(`sort=${params.sort}`);
  return request<any>({ url: `/posts/plaza?${parts.join("&")}`, method: "GET" }).then((d) => d?.list || d || []);
}

/** 我的帖子（需登录） */
export function getMyPosts(params: { page?: number; page_size?: number } = {}): Promise<PostItem[]> {
  const q = `page=${params.page || 1}&page_size=${params.page_size || 10}`;
  return request<any>({ url: `/posts/mine?${q}`, method: "GET" }).then((d) => d?.list || d || []);
}

/** 孩子动态（收藏与动态）：我孩子相关的帖子（家长帖 + 老师关联帖），参数为 size */
export function getChildFeed(params: { page?: number; size?: number } = {}): Promise<PostItem[]> {
  const q = `page=${params.page || 1}&size=${params.size || 20}`;
  return request<any>({ url: `/posts/child-feed?${q}`, method: "GET" }).then((d) => d?.list || d || []);
}

export function getPostDetail(id: string): Promise<PostItem> {
  return request({ url: `/posts/${id}`, method: "GET" });
}

export function likePost(id: string): Promise<void> {
  return request({ url: `/posts/${id}/like`, method: "POST" });
}

export function unlikePost(id: string): Promise<void> {
  return request({ url: `/posts/${id}/like`, method: "DELETE" });
}

export function postComment(id: string, content: string): Promise<void> {
  return request({ url: `/posts/${id}/comments`, method: "POST", data: { content } });
}

export function getPostComments(id: string): Promise<PostComment[]> {
  return request<any>({ url: `/posts/${id}/comments`, method: "GET" }).then((d) => d?.list || d || []);
}

export function sharePost(id: string): Promise<{ share_path: string }> {
  return request({ url: `/posts/${id}/share`, method: "POST" });
}

export function createPost(payload: {
  content: string;
  images?: string[];
  type?: number;
  course_id?: string;
  child_id?: string;
  visibility?: number;
  topic?: string;
  latitude?: number;
  longitude?: number;
  location_name?: string;
}): Promise<PostItem> {
  return request({ url: "/posts", method: "POST", data: payload });
}

/** 获取发帖话题列表 */
export function fetchTopics(): Promise<string[]> {
  return request<any>({ url: "/topics", method: "GET" }).then((d) => {
    if (Array.isArray(d)) return d.map((item: any) => item.name || item);
    return [];
  });
}

/** 删除帖子 */
export function deletePost(id: string): Promise<void> {
  return request({ url: `/posts/${id}`, method: "DELETE" });
}

/** 评论点赞 */
export function likeComment(postId: string, commentId: string): Promise<void> {
  return request({ url: `/posts/${postId}/comments/${commentId}/like`, method: "POST" });
}

/** 评论取消点赞 */
export function unlikeComment(postId: string, commentId: string): Promise<void> {
  return request({ url: `/posts/${postId}/comments/${commentId}/like`, method: "DELETE" });
}

/** 删除评论 */
export function deleteComment(commentId: string): Promise<void> {
  return request({ url: `/comments/${commentId}`, method: "DELETE" });
}

/** 回复评论（parent_id 可选，不传为根评论） */
export function replyComment(postId: string, content: string, parentId?: string): Promise<PostComment> {
  return request({ url: `/posts/${postId}/comments`, method: "POST", data: { content, parent_id: parentId || null } });
}

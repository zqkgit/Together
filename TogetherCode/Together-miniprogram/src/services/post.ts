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
  created_at: string;
  author: PostAuthor;
  course?: PostCourse | null;
  child?: { child_id: string; nickname: string } | null;
  students?: Array<{ child_id: string; nickname: string }>;
}

export interface PostComment {
  comment_id: string;
  content: string;
  created_at: string;
  author?: { user_id: string; nickname: string; avatar: string | null };
}

export function getPlazaPosts(params: { page?: number; page_size?: number } = {}): Promise<PostItem[]> {
  const q = `page=${params.page || 1}&page_size=${params.page_size || 10}`;
  return request<any>({ url: `/posts/plaza?${q}`, method: "GET" }).then((d) => d?.list || d || []);
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
}): Promise<PostItem> {
  return request({ url: "/posts", method: "POST", data: payload });
}

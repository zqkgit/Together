import { request } from "./request";

export interface TeacherHomepage {
  user: {
    user_id: string;
    nickname: string;
    avatar: string | null;
    city: string | null;
  } | null;
  profile: {
    teacher_id: string;
    real_name: string | null;
    subjects: string[];
    years: number | null;
    intro: string | null;
    portfolio: string[];
    rating: number;
    student_count: number;
    work_count: number;
    fans: number;
  };
  studios: Array<{
    studio_id: string;
    name: string;
    cover: string | null;
    address: string | null;
    plan_tier: number;
  }>;
  works: {
    total: number;
    page: number;
    size: number;
    list: Array<{
      post_id: string;
      type: number;
      images: string[];
      content: string;
      like_count: number;
      comment_count: number;
      created_at: string;
    }>;
  };
}

export interface StudioHomepage {
  studio: {
    studio_id: string;
    name: string;
    cover: string | null;
    type_tags: string[];
    intro: string | null;
    address: string | null;
    phone: string | null;
    hours: string | null;
    photos: string[];
    plan_tier: number;
  };
  courses: {
    total: number;
    page: number;
    size: number;
    list: Array<{
      course_id: string;
      title: string;
      cover: string | null;
      price: number;
      original_price: number;
      age_min: number | null;
      age_max: number | null;
      lesson_count: number;
      status: number;
    }>;
  };
  teachers: Array<{
    teacher_id: string;
    user_id: string | null;
    nickname: string;
    avatar: string | null;
    real_name: string | null;
    subjects: string[];
    years: number | null;
    rating: number;
  }>;
}

/** 老师主页：id 传 teacher_id 或 user_id 均可 */
export function getTeacherHomepage(id: string): Promise<TeacherHomepage> {
  return request({ url: `/profile/teacher/${id}/homepage`, method: "GET" });
}

/** 工作室主页 */
export function getStudioHomepage(id: string): Promise<StudioHomepage> {
  return request({ url: `/profile/studio/${id}/homepage`, method: "GET" });
}

import { request } from "./request";

export interface CoursePackage {
  package_id: string;
  name: string;
  lessons: number;
  price: number;
  original_price: number;
  status: number;
}

export interface CourseItem {
  course_id: string;
  title: string;
  cover: string | null;
  category: number;
  age_min: number | null;
  age_max: number | null;
  total_lessons: number;
  duration_min: number;
  price: number;
  class_size: number;
  rating: number;
  sales: number;
  distribute_rate: number;
  validity_days: number | null;
  status: number;
  studio: { studio_id: string; name: string; address: string; phone: string } | null;
  teacher: { teacher_id: string; real_name: string; intro: string | null; rating: number } | null;
  packages: CoursePackage[];
  classes?: Array<{ class_id: string; name: string; capacity: number; enrolled: number; start_date: string; end_date: string }>;
}

export function fenToYuan(fen: number): string {
  return (fen / 100).toFixed(2);
}

export function listCourses(params: {
  page?: number;
  page_size?: number;
  keyword?: string;
  tag?: string;
  category?: number;
} = {}): Promise<{ total: number; list: CourseItem[] }> {
  const query = Object.keys(params)
    .filter((k) => params[k] !== undefined && params[k] !== "")
    .map((k) => `${k}=${encodeURIComponent(params[k])}`)
    .join("&");
  return request({ url: `/courses?${query}`, method: "GET" });
}

export function getCourseDetail(id: string): Promise<CourseItem> {
  return request({ url: `/courses/${id}`, method: "GET" });
}

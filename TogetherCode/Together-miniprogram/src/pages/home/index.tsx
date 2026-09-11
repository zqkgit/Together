import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image, ScrollView } from "@tarojs/components";
import { request } from "../../services/request";
import { getPublicStudios, getPublicTeachers, type StudioItem, type TeacherItem } from "../../services/explore";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

interface CourseItem {
  course_id: string;
  title: string;
  cover: string | null;
  price_text: string;
  original_price_text: string;
  studio_name: string;
  tags: string[];
}

interface AnnouncementItem {
  id: string;
  title: string;
}

export default function HomePage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [courses, setCourses] = useState<CourseItem[]>([]);
  const [announcements, setAnnouncements] = useState<AnnouncementItem[]>([]);
  const [studios, setStudios] = useState<StudioItem[]>([]);
  const [teachers, setTeachers] = useState<TeacherItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isLoggedIn) {
      Taro.switchTab({ url: "/pages/mine/index" });
      return;
    }
    loadData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isLoggedIn]);

  const loadData = async () => {
    setLoading(true);
    try {
      const [courseData, annoData, studioData, teacherData] = await Promise.all([
        request<any>({ url: "/courses?page=1&page_size=6", method: "GET" }),
        request<any>({ url: "/announcements?page=1&page_size=3", method: "GET" }).catch(() => ({ list: [] })),
        getPublicStudios({ page: 1, page_size: 3 }).catch(() => ({ list: [] })),
        getPublicTeachers({ page: 1, page_size: 3 }).catch(() => ({ list: [] }))
      ]);
      setCourses(courseData?.list || courseData || []);
      setAnnouncements(annoData?.list || []);
      setStudios(studioData?.list || []);
      setTeachers(teacherData?.list || []);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const goCourse = (id: string) => {
    Taro.navigateTo({ url: `/pages/course-detail/index?id=${id}` });
  };

  const goStudio = (id: string) => {
    Taro.navigateTo({ url: `/pages/studio-homepage/index?id=${id}` });
  };

  const goTeacher = (id: string) => {
    Taro.navigateTo({ url: `/pages/teacher-homepage/index?id=${id}` });
  };

  return (
    <View className="home">
      <View className="home-banner">
        <View className="banner-title">艺启 · 儿童艺术教育</View>
        <View className="banner-sub">绘画 / 书法 / 舞蹈 / 音乐</View>
      </View>

      {announcements.length > 0 && (
        <View className="card notice-card">
          <Text className="notice-label">公告</Text>
          <Text className="notice-text">{announcements[0].title}</Text>
        </View>
      )}

      <View className="section-head">
        <Text className="section-title">精选课程</Text>
        <Text className="section-more" onClick={() => Taro.switchTab({ url: "/pages/courses/index" })}>
          更多
        </Text>
      </View>

      {loading ? (
        <View className="empty-tip">加载中...</View>
      ) : (
        <View className="course-grid">
          {courses.map((item) => (
            <View key={item.course_id} className="course-card" onClick={() => goCourse(item.course_id)}>
              <Image className="course-cover" src={item.cover || ""} mode="aspectFill" />
              <View className="course-body">
                <View className="course-name">{item.title}</View>
                <View className="course-studio">{item.studio_name}</View>
                <View className="course-price">
                  <Text className="price-now">{item.price_text}</Text>
                  {item.original_price_text && (
                    <Text className="price-original">{item.original_price_text}</Text>
                  )}
                </View>
              </View>
            </View>
          ))}
        </View>
      )}

      {courses.length === 0 && !loading && <View className="empty-tip">暂无课程</View>}

      {studios.length > 0 && (
        <View className="home-section">
          <View className="section-head">
            <Text className="section-title">推荐工作室</Text>
            <Text className="section-more" onClick={() => Taro.navigateTo({ url: "/pages/studios/index?tab=studios" })}>
              更多
            </Text>
          </View>
          <ScrollView scrollX className="entity-scroll">
            {studios.map((s) => (
              <View key={s.studio_id} className="entity-card" onClick={() => goStudio(s.studio_id)}>
                <Image className="entity-cover" src={s.cover || ""} mode="aspectFill" />
                <View className="entity-name">{s.name}</View>
                <View className="entity-meta">
                  ⭐ {s.rating || "—"} · {s.course_count} 门课
                </View>
              </View>
            ))}
          </ScrollView>
        </View>
      )}

      {teachers.length > 0 && (
        <View className="home-section">
          <View className="section-head">
            <Text className="section-title">推荐老师</Text>
            <Text className="section-more" onClick={() => Taro.navigateTo({ url: "/pages/studios/index?tab=teachers" })}>
              更多
            </Text>
          </View>
          <ScrollView scrollX className="entity-scroll">
            {teachers.map((t) => (
              <View key={t.teacher_id} className="entity-card" onClick={() => goTeacher(t.user_id)}>
                <Image className="entity-cover" src={t.avatar || ""} mode="aspectFill" />
                <View className="entity-name">{t.nickname}</View>
                <View className="entity-meta">
                  ⭐ {t.rating || "—"} · {(t.subjects || []).slice(0, 2).join(" / ") || "老师"}
                </View>
              </View>
            ))}
          </ScrollView>
        </View>
      )}
    </View>
  );
}

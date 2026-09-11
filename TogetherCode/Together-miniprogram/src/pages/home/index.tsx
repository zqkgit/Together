import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image, ScrollView } from "@tarojs/components";
import { request } from "../../services/request";
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
      const [courseData, annoData] = await Promise.all([
        request<any>({ url: "/courses?page=1&page_size=6", method: "GET" }),
        request<any>({ url: "/announcements?page=1&page_size=3", method: "GET" }).catch(() => ({ list: [] }))
      ]);
      setCourses(courseData?.list || courseData || []);
      setAnnouncements(annoData?.list || []);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const goCourse = (id: string) => {
    Taro.navigateTo({ url: `/pages/course-detail/index?id=${id}` });
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
    </View>
  );
}

import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image, ScrollView } from "@tarojs/components";
import { listMyCourses, type MyCourseItem } from "../../services/course";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

export default function MyCoursesPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [children, setChildren] = useState<Array<{ child_id: string; child_name: string }>>([]);
  const [activeChild, setActiveChild] = useState("");
  const [list, setList] = useState<MyCourseItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Taro.setNavigationBarTitle({ title: "我的课程" });
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    load();
  }, [isLoggedIn]);

  const load = async (childId?: string) => {
    setLoading(true);
    try {
      const data = await listMyCourses(childId);
      if (!childId && data.children && data.children.length > 0) {
        setActiveChild(data.children[0].child_id);
      }
      setChildren(data.children || []);
      setList(data.list || []);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const switchChild = (id: string) => {
    if (id === activeChild) return;
    setActiveChild(id);
    load(id);
  };

  const goStudy = (item: MyCourseItem) => {
    Taro.navigateTo({
      url: `/pages/course-study/index?child_id=${item.child_id}&course_id=${item.course_id}&course_title=${encodeURIComponent(item.course_title || "")}`
    });
  };

  const coverUrl = (cover: string | null) => cover || "https://placehold.co/400x300/eae4d8/8a8378?text=Course";

  return (
    <View className="my-courses">
      {children.length > 1 && (
        <ScrollView scrollX className="child-scroll" showScrollbar={false}>
          <View className="child-row">
            {children.map((c) => (
              <View
                key={c.child_id}
                className={`child-chip ${activeChild === c.child_id ? "child-active" : ""}`}
                onClick={() => switchChild(c.child_id)}
              >
                <Text>{c.child_name}</Text>
              </View>
            ))}
          </View>
        </ScrollView>
      )}

      {loading ? (
        <View className="state-tip">加载中...</View>
      ) : list.length === 0 ? (
        <View className="state-tip">还没有报名课程，去逛逛吧</View>
      ) : (
        <View className="course-list">
          {list.map((item) => (
            <View key={`${item.child_id}-${item.course_id}`} className="course-card" onClick={() => goStudy(item)}>
              <Image className="course-cover" src={coverUrl(item.course_cover)} mode="aspectFill" />
              <View className="course-body">
                <Text className="course-name" numberOfLines={1}>{item.course_title || "未命名课程"}</Text>
                <Text className="course-sub" numberOfLines={1}>
                  {item.studio_name || ""}{item.teacher_name && item.teacher_name !== "-" ? `·${item.teacher_name}` : ""}
                </Text>
                <View className="progress-row">
                  <Text className="progress-text">已学 {item.consumed_lessons}/{item.total_lessons} 节</Text>
                  <Text className="progress-text">{item.status_text || ""}</Text>
                </View>
                <View className="progress-track">
                  <View
                    className="progress-fill"
                    style={{ width: `${Math.min(100, Math.max(0, item.percent || 0))}%` }}
                  />
                </View>
                <Text className="next-lesson" numberOfLines={1}>
                  {item.next_lesson
                    ? `下一课 ${item.next_lesson.lesson_date} ${item.next_lesson.start_time || ""}`
                    : "暂无排课"}
                </Text>
              </View>
            </View>
          ))}
        </View>
      )}
    </View>
  );
}

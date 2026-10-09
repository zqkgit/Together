import React, { useEffect, useState } from "react";
import Taro, { usePullDownRefresh } from "@tarojs/taro";
import { View, Text, ScrollView } from "@tarojs/components";
import { listMyCourses, type MyCourseItem } from "../../services/course";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

/** 周几中文映射 */
const WEEK_LABELS = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];

function weekdayText(date: string): string {
  if (!date) return "";
  const d = new Date(date + "T00:00:00");
  return WEEK_LABELS[d.getDay()] || "";
}

export default function MyCoursesPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [children, setChildren] = useState<Array<{ child_id: string; child_name: string }>>([]);
  const [activeChild, setActiveChild] = useState<string | null>(null); // null = 全部
  const [allItems, setAllItems] = useState<MyCourseItem[]>([]);
  const [filteredItems, setFilteredItems] = useState<MyCourseItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    loadData();
  }, [isLoggedIn]);

  // 下拉刷新（对齐 iOS BrandRefreshHeader / 广场页）
  usePullDownRefresh(() => {
    loadData();
  });

  const loadData = async () => {
    setLoading(true);
    try {
      const data = await listMyCourses();
      setChildren(data.children || []);
      setAllItems(data.list || []);
      // 默认选中"全部"
      setActiveChild(null);
      applyFilter(null, data.list || []);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
      Taro.stopPullDownRefresh();
    }
  };

  /** 按孩子筛选（null = 全部） */
  const applyFilter = (childId: string | null, items?: MyCourseItem[]) => {
    const source = items ?? allItems;
    if (childId) {
      setFilteredItems(source.filter((it) => it.child_id === childId));
    } else {
      setFilteredItems(source);
    }
  };

  const switchChild = (id: string | null) => {
    setActiveChild(id);
    applyFilter(id);
  };

  const goStudy = (item: MyCourseItem) => {
    Taro.navigateTo({
      url: "/pages/course-study/index?child_id=" + item.child_id + "&course_id=" + item.course_id + "&course_title=" + encodeURIComponent(item.course_title || "")
    });
  };

  /** 下次课文案：对齐 iOS nextLessonText */
  const nextLessonText = (item: MyCourseItem): string => {
    if (!item.next_lesson || !item.next_lesson.lesson_date) return "待开课";
    return weekdayText(item.next_lesson.lesson_date) + " " + (item.next_lesson.start_time || "");
  };

  /** 机构·老师文案：对齐 iOS studioTeacherText */
  const studioTeacherText = (item: MyCourseItem): string => {
    const studio = item.studio_name;
    const teacher = item.teacher_name;
    if (studio && teacher && teacher !== "-") return studio + "·" + teacher;
    return studio || "未知机构";
  };

  /** 是否多孩子模式（显示孩子名称标签） */
  const isMultiChild = children.length > 1;

  const emptyText = (() => {
    if (activeChild) {
      const c = children.find((ch) => ch.child_id === activeChild);
      return (c?.child_name || "孩子") + "还没有报名课程";
    }
    return "还没有报名课程";
  })();

  return (
    <View className="my-courses">
      {/* 孩子筛选条：对齐 iOS TagChipRow */}
      {isMultiChild && (
        <ScrollView scrollX className="child-scroll" showScrollbar={false}>
          <View className="child-row">
            <View
              className={"child-chip" + (activeChild === null ? " child-active" : "")}
              onClick={() => switchChild(null)}
            >
              <Text>全部</Text>
            </View>
            {children.map((c) => (
              <View
                key={c.child_id}
                className={"child-chip" + (activeChild === c.child_id ? " child-active" : "")}
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
      ) : filteredItems.length === 0 ? (
        <View className="state-tip">{emptyText}</View>
      ) : (
        <View className="course-list">
          {filteredItems.map((item) => {
            const percent = Math.min(100, Math.max(0, item.percent || 0));
            return (
              <View
                key={item.child_id + "-" + item.course_id}
                className="course-card"
                onClick={() => goStudy(item)}
              >
                {/* 行1：课程名 + 节数 */}
                <View className="card-row1">
                  <Text className="course-title" numberOfLines={1}>{item.course_title || "未命名课程"}</Text>
                  <Text className="course-count">{item.consumed_lessons}/{item.total_lessons}节</Text>
                </View>

                {/* 行2：孩子标签 + 工作室·老师标签 */}
                <View className="card-row2">
                  <Text className="studio-tag">{studioTeacherText(item)}</Text>
                  {isMultiChild && item.child_name && (
                    <Text className="child-tag">{item.child_name}</Text>
                  )}
                </View>

                {/* 行3：下次课 */}
                <Text className="next-lesson" numberOfLines={1}>{nextLessonText(item)}</Text>

                {/* 行4：进度条 + 百分比 */}
                <View className="progress-row">
                  <View className="progress-track">
                    <View className="progress-fill" style={{ width: percent + "%" }} />
                  </View>
                  <Text className="progress-pct">已学{percent}%</Text>
                </View>
              </View>
            );
          })}
        </View>
      )}
    </View>
  );
}
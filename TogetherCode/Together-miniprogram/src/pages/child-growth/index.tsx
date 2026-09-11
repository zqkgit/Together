import React, { useEffect, useState } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getChildGrowth, getChildWorks, type ChildGrowth, type ChildWorks } from "../../services/child";
import "./index.scss";

const TAB_TIMELINE = "timeline";
const TAB_WORKS = "works";

export default function ChildGrowthPage() {
  const router = useRouter();
  const childId = router.params.id || "";
  const childName = router.params.nickname || "孩子";
  const [growth, setGrowth] = useState<ChildGrowth | null>(null);
  const [works, setWorks] = useState<ChildWorks | null>(null);
  const [tab, setTab] = useState(TAB_TIMELINE);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (childId) {
      loadGrowth();
      loadWorks();
    }
  }, [childId]);

  const loadGrowth = async () => {
    try {
      setGrowth(await getChildGrowth(childId));
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const loadWorks = async () => {
    try {
      setWorks(await getChildWorks(childId));
    } catch {
      // 忽略
    }
  };

  const goPost = (postId: string) => {
    Taro.navigateTo({ url: `/pages/post-detail/index?id=${postId}` });
  };

  const renderTimelineItem = (item: ChildGrowth["timeline"][number], index: number) => {
    const isPost = item.event_type === "post";
    if (isPost) {
      return (
        <View key={`${item.event_id}-${index}`} className="tl-item" onClick={() => item.post_id && goPost(item.post_id)}>
          <View className="tl-dot tl-dot-post" />
          <View className="tl-body">
            <View className="tl-head">
              <Text className="tl-title">作品</Text>
              {item.course_title && <Text className="tl-course">{item.course_title}</Text>}
            </View>
            {item.post?.images?.[0] && (
              <Image className="tl-img" src={item.post.images[0]} mode="aspectFill" />
            )}
            {item.post?.content && <View className="tl-note">{item.post.content}</View>}
            <View className="tl-time">{String(item.created_at || "").slice(0, 16)}</View>
          </View>
        </View>
      );
    }

    // 课时记录：delta 正负号区分到账(+) / 消耗(-)
    const deltaText = item.delta > 0 ? `+${item.delta} 课时` : item.delta < 0 ? `${item.delta} 课时` : "课时记录";
    const typeColor = item.delta > 0 ? "green" : item.delta < 0 ? "blue" : "grey";

    return (
      <View key={`${item.event_id}-${index}`} className="tl-item">
        <View className={`tl-dot tl-dot-${typeColor}`} />
        <View className="tl-body">
          <View className="tl-head">
            <Text className={`tl-title tl-title-${typeColor}`}>{deltaText || typeLabel}</Text>
            {item.course_title && <Text className="tl-course">{item.course_title}</Text>}
          </View>
          {item.studio_name && <View className="tl-studio">{item.studio_name}</View>}
          {item.schedule?.lesson_date && (
            <View className="tl-schedule">
              {item.schedule.lesson_date}
              {item.schedule.start_time ? ` ${String(item.schedule.start_time).slice(0, 5)}` : ""}
              {item.schedule.location ? ` · ${item.schedule.location}` : ""}
            </View>
          )}
          {item.note && <View className="tl-note">{item.note}</View>}
          {item.balance_after != null && <View className="tl-balance">剩余 {item.balance_after} 课时</View>}
          <View className="tl-time">{String(item.created_at || "").slice(0, 16)}</View>
        </View>
      </View>
    );
  };

  if (loading) {
    return <View className="empty-tip">加载中...</View>;
  }
  if (!growth) {
    return <View className="empty-tip">档案不存在</View>;
  }

  const o = growth.overview;

  return (
    <View className="growth-page">
      <View className="hero">
        <View className="hero-avatar">{(growth.child?.nickname || childName)?.[0]}</View>
        <View className="hero-name">{growth.child?.nickname || childName}</View>
        <View className="hero-meta">
          <Text>在学 {o.active_courses} 门</Text>
          <Text>·</Text>
          <Text>累计 {o.consumed_lessons} 课时</Text>
          <Text>·</Text>
          <Text>剩余 {o.remaining_lessons} 课时</Text>
        </View>
      </View>

      <View className="stats-card card">
        <View className="stat">
          <Text className="stat-num">{o.active_courses}</Text>
          <Text className="stat-label">在学课程</Text>
        </View>
        <View className="stat">
          <Text className="stat-num">{o.total_lessons}</Text>
          <Text className="stat-label">累计课时</Text>
        </View>
        <View className="stat">
          <Text className="stat-num">{o.consumed_lessons}</Text>
          <Text className="stat-label">已消课时</Text>
        </View>
        <View className="stat">
          <Text className="stat-num">{o.work_count}</Text>
          <Text className="stat-label">作品</Text>
        </View>
      </View>

      <View className="tabs">
        <View
          className={`tab ${tab === TAB_TIMELINE ? "tab-active" : ""}`}
          onClick={() => setTab(TAB_TIMELINE)}
        >
          成长时间线
        </View>
        <View
          className={`tab ${tab === TAB_WORKS ? "tab-active" : ""}`}
          onClick={() => setTab(TAB_WORKS)}
        >
          作品墙（{o.work_count}）
        </View>
      </View>

      {tab === TAB_TIMELINE ? (
        <View className="card timeline">
          {growth.timeline.length === 0 ? (
            <View className="empty-tip">还没有成长记录</View>
          ) : (
            growth.timeline.map((item, index) => renderTimelineItem(item, index))
          )}
        </View>
      ) : (
        <View className="card">
          {(!works || works.list.length === 0) ? (
            <View className="empty-tip">还没有作品</View>
          ) : (
            <View className="work-grid">
              {works.list.map((w) => (
                <View key={w.post_id} className="work-item" onClick={() => goPost(w.post_id)}>
                  {w.images?.[0] ? (
                    <Image className="work-img" src={w.images[0]} mode="aspectFill" />
                  ) : (
                    <View className="work-text">{String(w.content || "").slice(0, 6)}</View>
                  )}
                </View>
              ))}
            </View>
          )}
        </View>
      )}
    </View>
  );
}

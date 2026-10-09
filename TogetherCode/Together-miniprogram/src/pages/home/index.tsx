import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image, ScrollView, Input } from "@tarojs/components";
import { request } from "../../services/request";
import { getPublicStudios, type StudioItem } from "../../services/explore";
import { listChildren, type ChildItem } from "../../services/child";
import { listBalances, type BalanceChild } from "../../services/balance";
import { getPlazaPosts, type PostItem } from "../../services/post";
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
  const user = useAuthStore((s) => s.user);
  const [courses, setCourses] = useState<CourseItem[]>([]);
  const [announcements, setAnnouncements] = useState<AnnouncementItem[]>([]);
  const [studios, setStudios] = useState<StudioItem[]>([]);
  const [children, setChildren] = useState<ChildItem[]>([]);
  const [balanceChildren, setBalanceChildren] = useState<BalanceChild[]>([]);
  const [posts, setPosts] = useState<PostItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchKeyword, setSearchKeyword] = useState("");

  useEffect(() => {
    if (!isLoggedIn) return;
    loadData();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isLoggedIn]);

  const loadData = async () => {
    setLoading(true);
    try {
      const [courseData, annoData, studioData, childrenData, balanceData, postData] = await Promise.all([
        request<any>({ url: "/courses?page=1&page_size=10", method: "GET" }),
        request<any>({ url: "/announcements?page=1&page_size=3", method: "GET" }).catch(() => ({ list: [] })),
        getPublicStudios({ page: 1, page_size: 6 }).catch(() => ({ list: [] })),
        listChildren().catch(() => []),
        listBalances().catch(() => []),
        getPlazaPosts({ page: 1, page_size: 5 }).catch(() => [])
      ]);
      setCourses(courseData?.list || courseData || []);
      setAnnouncements(annoData?.list || []);
      setStudios(studioData?.list || []);
      setChildren(childrenData || []);
      setBalanceChildren(balanceData || []);
      setPosts(postData || []);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const goSearch = () => {
    if (searchKeyword.trim()) {
      Taro.navigateTo({ url: `/pages/studios/index?keyword=${encodeURIComponent(searchKeyword.trim())}` });
    }
  };

  const goCourse = (id: string) => {
    Taro.navigateTo({ url: `/pages/course-detail/index?id=${id}` });
  };

  const goStudio = (id: string) => {
    Taro.navigateTo({ url: `/pages/studio-homepage/index?id=${id}` });
  };

  const goPost = (id: string) => {
    Taro.navigateTo({ url: `/pages/post-detail/index?id=${id}` });
  };

  const goChildDetail = (childId: string) => {
    Taro.navigateTo({ url: `/pages/child-balance/index?child_id=${childId}` });
  };

  const goChildrenList = () => {
    Taro.navigateTo({ url: "/pages/children/index" });
  };

  /** 获取孩子的剩余课时摘要 */
  const getChildSummary = (childId: string) => {
    const bc = balanceChildren.find((b) => b.child_id === childId);
    if (!bc || bc.balances.length === 0) return "暂无课程";
    const total = bc.balances.reduce((sum, b) => sum + b.remaining_lessons, 0);
    return `${total} 节课待上`;
  };

  const greeting = () => {
    const h = new Date().getHours();
    if (h < 12) return "早上好";
    if (h < 18) return "下午好";
    return "晚上好";
  };

  return (
    <View className="home">
      {/* 搜索栏 */}
      <View className="home-search">
        <View className="search-bar" onClick={goSearch}>
          <Text className="search-icon">🔍</Text>
          <Input
            className="search-input"
            placeholder="搜索课程、工作室、老师"
            placeholderClass="search-placeholder"
            value={searchKeyword}
            onInput={(e) => setSearchKeyword(e.detail.value)}
            onConfirm={goSearch}
            confirmType="search"
          />
        </View>
      </View>

      {/* Hero 区：问候 + 孩子进度卡 */}
      <View className="home-hero">
        <View className="hero-greeting">
          <Text className="greeting-text">{greeting()}，{user?.nickname || "家长"}</Text>
          <Text className="greeting-sub">让每一次创作，都被看见</Text>
        </View>

        {children.length > 0 ? (
          <ScrollView scrollX className="hero-children" style={{ width: '100%' }}>
            <View className="hero-children-inner">
              {children.map((child) => (
                <View
                  key={child.child_id}
                  className="child-card"
                  onClick={() => goChildDetail(child.child_id)}
                >
                  <Image
                    className="child-avatar"
                    src={child.avatar || ""}
                    mode="aspectFill"
                  />
                  <View className="child-info">
                    <Text className="child-name">{child.nickname}</Text>
                    <Text className="child-summary">{getChildSummary(child.child_id)}</Text>
                  </View>
                </View>
              ))}
              <View className="child-card child-card-add" onClick={goChildrenList}>
                <Text className="add-icon">+</Text>
                <Text className="add-text">管理孩子</Text>
              </View>
            </View>
          </ScrollView>
        ) : (
          <View className="hero-no-child" onClick={goChildrenList}>
            <Text className="no-child-text">添加孩子，开始记录成长</Text>
            <Text className="no-child-arrow">›</Text>
          </View>
        )}
      </View>

      {/* 公告条 */}
      {announcements.length > 0 && (
        <View
          className="card notice-card"
          onClick={() => Taro.navigateTo({ url: "/pages/announcements/index" })}
        >
          <Text className="notice-label">公告</Text>
          <Text className="notice-text">{announcements[0].title}</Text>
          <Text className="notice-arrow">›</Text>
        </View>
      )}

      {/* 为你推荐（课程横滑） */}
      <View className="home-section">
        <View className="section-head">
          <Text className="section-title">为你推荐</Text>
          <Text
            className="section-more"
            onClick={() => Taro.navigateTo({ url: "/pages/courses/index" })}
          >
            更多
          </Text>
        </View>
        {loading ? (
          <View className="empty-tip">加载中...</View>
        ) : (
          <ScrollView scrollX className="course-scroll">
            {courses.map((item) => (
              <View
                key={item.course_id}
                className="course-card"
                onClick={() => goCourse(item.course_id)}
              >
                <Image className="course-cover" src={item.cover || ""} mode="aspectFill" />
                <View className="course-body">
                  <Text className="course-name">{item.title}</Text>
                  <Text className="course-studio">{item.studio_name}</Text>
                  <View className="course-price">
                    <Text className="price-now">{item.price_text}</Text>
                    {item.original_price_text && (
                      <Text className="price-original">{item.original_price_text}</Text>
                    )}
                  </View>
                </View>
              </View>
            ))}
          </ScrollView>
        )}
        {courses.length === 0 && !loading && <View className="empty-tip">暂无课程</View>}
      </View>

      {/* 附近热门工作室 */}
      {studios.length > 0 && (
        <View className="home-section">
          <View className="section-head">
            <Text className="section-title">附近热门工作室</Text>
            <Text
              className="section-more"
              onClick={() => Taro.navigateTo({ url: "/pages/studios/index?tab=studios" })}
            >
              更多
            </Text>
          </View>
          <ScrollView scrollX className="entity-scroll">
            {studios.map((s) => (
              <View key={s.studio_id} className="entity-card" onClick={() => goStudio(s.studio_id)}>
                <Image className="entity-cover" src={s.cover || ""} mode="aspectFill" />
                <Text className="entity-name">{s.name}</Text>
                <Text className="entity-meta">
                  ⭐ {s.rating || "—"} · {s.course_count} 门课
                </Text>
              </View>
            ))}
          </ScrollView>
        </View>
      )}

      {/* 老师动态 */}
      {posts.length > 0 && (
        <View className="home-section">
          <View className="section-head">
            <Text className="section-title">老师动态</Text>
            <Text
              className="section-more"
              onClick={() => Taro.switchTab({ url: "/pages/plaza/index" })}
            >
              更多
            </Text>
          </View>
          <View className="post-list">
            {posts.map((post) => (
              <View
                key={post.post_id}
                className="post-card card"
                onClick={() => goPost(post.post_id)}
              >
                <View className="post-header">
                  <Image
                    className="post-avatar"
                    src={post.author?.avatar || ""}
                    mode="aspectFill"
                  />
                  <View className="post-author-info">
                    <Text className="post-author-name">{post.author?.nickname || "老师"}</Text>
                    <Text className="post-author-role">
                      {post.author_role_text || "老师"}
                    </Text>
                  </View>
                </View>
                <Text className="post-content">
                  {post.content.length > 60
                    ? post.content.slice(0, 60) + "..."
                    : post.content}
                </Text>
                {post.images && post.images.length > 0 && (
                  <View className="post-images">
                    <Image
                      className="post-image"
                      src={post.images[0]}
                      mode="aspectFill"
                    />
                    {post.images.length > 1 && (
                      <View className="post-image-more">+{post.images.length - 1}</View>
                    )}
                  </View>
                )}
                <View className="post-footer">
                  <Text className="post-stat">❤️ {post.like_count}</Text>
                  <Text className="post-stat">💬 {post.comment_count}</Text>
                  <Text className="post-time">
                    {formatTime(post.created_at)}
                  </Text>
                </View>
              </View>
            ))}
          </View>
        </View>
      )}


    </View>
  );
}

/** 简单的时间格式化 */
function formatTime(dateStr: string): string {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  const now = new Date();
  const diff = now.getTime() - d.getTime();
  const min = Math.floor(diff / 60000);
  if (min < 1) return "刚刚";
  if (min < 60) return `${min}分钟前`;
  const hour = Math.floor(min / 60);
  if (hour < 24) return `${hour}小时前`;
  const day = Math.floor(hour / 24);
  if (day < 30) return `${day}天前`;
  return `${d.getMonth() + 1}月${d.getDate()}日`;
}
import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { request } from "../../services/request";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

interface PostItem {
  post_id: string;
  author: { nickname: string; avatar: string | null; role: string } | null;
  content: string;
  images: string[];
  like_count: number;
  comment_count: number;
  course_title: string | null;
  created_at: string;
}

export default function PlazaPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [posts, setPosts] = useState<PostItem[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);

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
      const data = await request<any>({ url: `/posts/plaza?page=${page}&page_size=10`, method: "GET" });
      const list = data?.list || [];
      setPosts((prev) => (page === 1 ? list : [...prev, ...list]));
      setTotal(data?.total || list.length);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (page > 1) loadData();
  }, [page]);

  const onReachBottom = () => {
    if (posts.length < total) setPage(page + 1);
  };

  const goDetail = (id: string) => {
    Taro.navigateTo({ url: `/pages/post-detail/index?id=${id}` });
  };

  const goCreate = () => {
    Taro.navigateTo({ url: "/pages/post-create/index" });
  };

  return (
    <View className="plaza">
      <View className="plaza-head">
        <Text className="plaza-title">广场</Text>
        <View className="create-btn" onClick={goCreate}>发帖</View>
      </View>

      <View className="post-list">
        {posts.map((post) => (
          <View key={post.post_id} className="post-card card" onClick={() => goDetail(post.post_id)}>
            <View className="post-author">
              <Image className="author-avatar" src={post.author?.avatar || ""} mode="aspectFill" />
              <View className="author-info">
                <View className="author-name">
                  {post.author?.nickname || "用户"}
                  {post.author?.role === "teacher" && <Text className="role-tag">老师</Text>}
                </View>
                <View className="post-time">{post.created_at?.slice(0, 16).replace("T", " ")}</View>
              </View>
            </View>

            <View className="post-content">{post.content}</View>

            {post.images && post.images.length > 0 && (
              <View className="post-images">
                {post.images.slice(0, 3).map((img, i) => (
                  <Image key={i} className="post-img" src={img} mode="aspectFill" />
                ))}
              </View>
            )}

            {post.course_title && (
              <View className="post-course">
                <Text className="course-badge">课程</Text>
                <Text className="course-name">{post.course_title}</Text>
              </View>
            )}

            <View className="post-actions">
              <Text>♥ {post.like_count}</Text>
              <Text>评论 {post.comment_count}</Text>
            </View>
          </View>
        ))}
      </View>

      {loading && <View className="empty-tip">加载中...</View>}
      {posts.length === 0 && !loading && <View className="empty-tip">还没有帖子，来发第一帖吧</View>}
    </View>
  );
}

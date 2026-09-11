import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getMyPosts, type PostItem } from "../../services/post";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

export default function MyPostsPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [list, setList] = useState<PostItem[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    load(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const load = async (p: number) => {
    setLoading(true);
    try {
      const data = await getMyPosts({ page: p, page_size: 10 });
      const arr = data || [];
      setList((prev) => (p === 1 ? arr : [...prev, ...arr]));
      setTotal(arr.length < 10 ? p * 10 : 999);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const loadMore = () => {
    if (loading || list.length >= total) return;
    const next = page + 1;
    setPage(next);
    load(next);
  };

  const goDetail = (id: string) => {
    Taro.navigateTo({ url: `/pages/post-detail/index?id=${id}` });
  };

  const goCreate = () => {
    Taro.navigateTo({ url: "/pages/post-create/index" });
  };

  if (!isLoggedIn) {
    return (
      <View className="my-posts">
        <View className="empty-tip">请先登录</View>
        <View className="go-login" onClick={() => Taro.navigateTo({ url: "/pages/login/index" })}>
          去登录
        </View>
      </View>
    );
  }

  return (
    <View className="my-posts">
      <View className="head-actions">
        <Text className="count-tip">共 {list.length} 条动态</Text>
        <Text className="create-btn" onClick={goCreate}>+ 发帖</Text>
      </View>

      <View className="post-list">
        {list.map((p) => (
          <View key={p.post_id} className="card post-card" onClick={() => goDetail(p.post_id)}>
            <View className="post-top">
              <Image className="post-cover" src={(p.images || [])[0] || ""} mode="aspectFill" />
              <View className="post-body">
                <View className="post-content">{p.content || "（无文字）"}</View>
                {p.course?.title && <View className="post-course">📚 {p.course.title}</View>}
                <View className="post-meta">
                  <Text>{p.like_count} 赞</Text>
                  <Text>{p.comment_count} 评论</Text>
                  <Text>{p.share_count} 分享</Text>
                </View>
              </View>
            </View>
          </View>
        ))}

        {list.length === 0 && !loading && (
          <View className="empty-box">
            <View className="empty-tip">还没有发过帖子</View>
            <View className="empty-btn" onClick={goCreate}>去发第一条</View>
          </View>
        )}
        {loading && <View className="empty-tip">加载中...</View>}
        {!loading && list.length > 0 && list.length >= total && <View className="empty-tip">没有更多了</View>}
        {!loading && list.length > 0 && list.length < total && (
          <View className="load-more" onClick={loadMore}>加载更多</View>
        )}
      </View>
    </View>
  );
}

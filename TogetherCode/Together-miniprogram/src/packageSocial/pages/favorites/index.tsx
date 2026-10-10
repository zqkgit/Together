import React, { useState } from "react";
import Taro, { useDidShow, useReachBottom, usePullDownRefresh } from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getFavorites, type FavoriteItem } from "../../../services/interaction";
import { getChildFeed, type PostItem } from "../../../services/post";
import "./index.scss";

const PAGE_SIZE = 20;

type TabKey = "favorites" | "childFeed";
const TABS: Array<{ key: TabKey; label: string }> = [
  { key: "favorites", label: "收藏作品" },
  { key: "childFeed", label: "孩子动态" }
];

/** 话题色系（对齐 iOS WorkCardView.palette），无封面时做渐变占位 */
function palette(topic?: string | null): [string, string] {
  switch (topic) {
    case "水彩": return ["#7FB5C8", "#4A7C9B"];
    case "黏土": return ["#E0A878", "#C15F2C"];
    case "书法": return ["#8B8B8B", "#4A4A4A"];
    case "素描": return ["#C9C4BC", "#8A8478"];
    case "国画": return ["#A8BDA0", "#6E8A66"];
    default: return ["#E4F7EA", "#14A640"];
  }
}

function formatTime(dateStr?: string | null): string {
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

export default function FavoritesPage() {
  const [tab, setTab] = useState<TabKey>("favorites");

  // 收藏作品（两列网格）
  const [favList, setFavList] = useState<FavoriteItem[]>([]);
  const [favPage, setFavPage] = useState(1);
  const [favHasMore, setFavHasMore] = useState(true);
  const [favLoading, setFavLoading] = useState(false);
  const [favLoaded, setFavLoaded] = useState(false);

  // 孩子动态（竖排卡片）
  const [feedList, setFeedList] = useState<PostItem[]>([]);
  const [feedPage, setFeedPage] = useState(1);
  const [feedHasMore, setFeedHasMore] = useState(true);
  const [feedLoading, setFeedLoading] = useState(false);
  const [feedLoaded, setFeedLoaded] = useState(false);

  const loadFav = async (reset: boolean) => {
    if (favLoading) return;
    setFavLoading(true);
    try {
      const p = reset ? 1 : favPage + 1;
      const res = await getFavorites("post", p, PAGE_SIZE);
      const arr = res?.list || [];
      setFavList((prev) => (reset ? arr : [...prev, ...arr]));
      setFavPage(p);
      setFavHasMore(p * PAGE_SIZE < (res?.total || 0));
      setFavLoaded(true);
    } catch {
      // 拦截器已提示
    } finally {
      setFavLoading(false);
      Taro.stopPullDownRefresh();
    }
  };

  const loadFeed = async (reset: boolean) => {
    if (feedLoading) return;
    setFeedLoading(true);
    try {
      const p = reset ? 1 : feedPage + 1;
      const arr = await getChildFeed({ page: p, size: PAGE_SIZE });
      setFeedList((prev) => (reset ? arr : [...prev, ...arr]));
      setFeedPage(p);
      setFeedHasMore(arr.length >= PAGE_SIZE);
      setFeedLoaded(true);
    } catch {
      // 拦截器已提示
    } finally {
      setFeedLoading(false);
      Taro.stopPullDownRefresh();
    }
  };

  // 每次页面显示（首次进入 / 从详情返回）都刷新当前段，保证收藏/动态最新
  useDidShow(() => {
    if (tab === "favorites") loadFav(true);
    else loadFeed(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  });

  const switchTab = (key: TabKey) => {
    if (key === tab) return;
    setTab(key);
    if (key === "favorites" && !favLoaded && !favLoading) loadFav(true);
    if (key === "childFeed" && !feedLoaded && !feedLoading) loadFeed(true);
  };

  usePullDownRefresh(() => {
    if (tab === "favorites") loadFav(true);
    else loadFeed(true);
  });

  useReachBottom(() => {
    if (tab === "favorites") {
      if (favHasMore && !favLoading) loadFav(false);
    } else if (feedHasMore && !feedLoading) {
      loadFeed(false);
    }
  });

  const goPost = (id: string) => {
    Taro.navigateTo({ url: `/packageSocial/pages/post-detail/index?id=${id}` });
  };

  const isFav = tab === "favorites";
  const loading = isFav ? favLoading : feedLoading;
  const hasMore = isFav ? favHasMore : feedHasMore;
  const listEmpty = isFav ? favList.length === 0 : feedList.length === 0;
  const loaded = isFav ? favLoaded : feedLoaded;

  return (
    <View className="fav-page">
      {/* 分段栏：收藏作品 | 孩子动态 */}
      <View className="fav-segment">
        {TABS.map((t) => (
          <View
            key={t.key}
            className={`seg-item ${tab === t.key ? "active" : ""}`}
            onClick={() => switchTab(t.key)}
          >
            <Text className="seg-label">{t.label}</Text>
            {tab === t.key && <View className="seg-indicator" />}
          </View>
        ))}
      </View>

      {/* 收藏作品：两列网格 */}
      {isFav &&
        (favList.length > 0 ? (
          <View className="fav-grid">
            <View className="fav-col">
              {favList
                .filter((_, i) => i % 2 === 0)
                .map((it) => <FavWorkCard key={it.target_id} item={it} onTap={() => goPost(it.target_id)} />)}
            </View>
            <View className="fav-col">
              {favList
                .filter((_, i) => i % 2 === 1)
                .map((it) => <FavWorkCard key={it.target_id} item={it} onTap={() => goPost(it.target_id)} />)}
            </View>
          </View>
        ) : loaded && !favLoading ? (
          <View className="empty-tip">还没有收藏的作品</View>
        ) : null)}

      {/* 孩子动态：竖排卡片（复用首页老师动态样式） */}
      {!isFav &&
        (feedList.length > 0 ? (
          <View className="feed-list">
            {feedList.map((p) => (
              <FeedCard key={p.post_id} post={p} onTap={() => goPost(p.post_id)} />
            ))}
          </View>
        ) : loaded && !feedLoading ? (
          <View className="empty-tip">暂无孩子动态</View>
        ) : null)}

      {loading && <View className="loading-tip">加载中...</View>}
      {!loading && !hasMore && !listEmpty && <View className="loading-tip">没有更多了</View>}
    </View>
  );
}

/** 收藏作品卡片（对齐 iOS FavoriteWorkCell：封面 + 标题 + 作者 + 点赞） */
function FavWorkCard({ item, onTap }: { item: FavoriteItem; onTap: () => void }) {
  const colors = palette(item.topic);
  const authorName = item.author?.nickname || "匿名";
  const likeRaw = (item.subtitle || "").split("赞")[0].trim();
  const likeCount = /^\d+$/.test(likeRaw) ? likeRaw : "";

  return (
    <View className="fav-work-card" onClick={onTap}>
      <View className="fav-cover">
        {item.cover ? (
          <Image className="fav-cover-img" src={item.cover} mode="aspectFill" />
        ) : (
          <View
            className="fav-cover-ph"
            style={{ background: `linear-gradient(135deg, ${colors[0]}, ${colors[1]})` }}
          />
        )}
      </View>
      <View className="fav-info">
        <Text className="fav-title">{item.title || "作品分享"}</Text>
        <View className="fav-meta">
          <Text className="fav-author">{authorName}</Text>
          {likeCount && <Text className="fav-like">♥ {likeCount}</Text>}
        </View>
      </View>
    </View>
  );
}

/** 孩子动态卡片（与首页老师动态 post-card 同款） */
function FeedCard({ post, onTap }: { post: PostItem; onTap: () => void }) {
  return (
    <View className="feed-card card" onClick={onTap}>
      <View className="feed-header">
        <Image className="feed-avatar" src={post.author?.avatar || ""} mode="aspectFill" />
        <View className="feed-author-info">
          <Text className="feed-author-name">{post.author?.nickname || "用户"}</Text>
          <Text className="feed-author-role">{post.author_role_text || ""}</Text>
        </View>
      </View>
      {post.content ? (
        <Text className="feed-content">
          {post.content.length > 60 ? post.content.slice(0, 60) + "..." : post.content}
        </Text>
      ) : null}
      {post.images && post.images.length > 0 && (
        <View className="feed-images">
          <Image className="feed-image" src={post.images[0]} mode="aspectFill" />
          {post.images.length > 1 && <View className="feed-image-more">+{post.images.length - 1}</View>}
        </View>
      )}
      <View className="feed-footer">
        <Text className="feed-stat">❤️ {post.like_count}</Text>
        <Text className="feed-stat">💬 {post.comment_count}</Text>
        <Text className="feed-time">{formatTime(post.created_at)}</Text>
      </View>
    </View>
  );
}

import React, { useEffect, useState, useCallback } from "react";
import Taro, { useReachBottom, usePullDownRefresh } from "@tarojs/taro";
import { View, Text, Image, ScrollView } from "@tarojs/components";
import { getPlazaPosts, type PostItem } from "../../services/post";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

const PAGE_SIZE = 20;
const SORT_OPTIONS = ["latest", "hot", "near"] as const;
const SORT_LABELS = ["最新", "热门", "附近"];

export default function PlazaPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [posts, setPosts] = useState<PostItem[]>([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(false);
  const [sortIndex, setSortIndex] = useState(0);

  useEffect(() => {
    if (!isLoggedIn) return;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isLoggedIn]);

  useEffect(() => {
    reload();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sortIndex]);

  const reload = async () => {
    if (loading) return;
    setLoading(true);
    try {
      const sort = SORT_OPTIONS[sortIndex];
      if (sort === "near") {
        // 小程序获取位置
        try {
          const loc = await Taro.getLocation({ type: "gcj02" });
          const list = await getPlazaPosts({ page: 1, page_size: PAGE_SIZE, sort: "near" });
          setPosts(list);
          setPage(1);
          setHasMore(list.length >= PAGE_SIZE);
        } catch {
          Taro.showToast({ title: "未授权定位，已按最新展示", icon: "none" });
          setSortIndex(0);
          return;
        }
      } else {
        const list = await getPlazaPosts({ page: 1, page_size: PAGE_SIZE, sort });
        setPosts(list);
        setPage(1);
        setHasMore(list.length >= PAGE_SIZE);
      }
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
      Taro.stopPullDownRefresh();
    }
  };

  const loadMore = async () => {
    if (loading || !hasMore) return;
    setLoading(true);
    try {
      const sort = SORT_OPTIONS[sortIndex];
      const nextPage = page + 1;
      const list = await getPlazaPosts({ page: nextPage, page_size: PAGE_SIZE, sort });
      setPosts((prev) => [...prev, ...list]);
      setPage(nextPage);
      setHasMore(list.length >= PAGE_SIZE);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  usePullDownRefresh(() => {
    reload();
  });

  useReachBottom(() => {
    loadMore();
  });

  const onSortChange = (index: number) => {
    if (index === sortIndex) return;
    setSortIndex(index);
  };

  const goDetail = (id: string) => {
    Taro.navigateTo({ url: `/packageSocial/pages/post-detail/index?id=${id}` });
  };

  /** 话题色系（对齐 iOS WorkCardView.palette） */
  const palette = (topic?: string): [string, string] => {
    switch (topic) {
      case "水彩": return ["#7FB5C8", "#4A7C9B"];
      case "黏土": return ["#E0A878", "#C15F2C"];
      case "书法": return ["#8B8B8B", "#4A4A4A"];
      case "素描": return ["#C9C4BC", "#8A8478"];
      case "国画": return ["#A8BDA0", "#6E8A66"];
      default: return ["#E4F7EA", "#14A640"];
    }
  };

  return (
    <View className="plaza">
      {/* 排序 chips */}
      <View className="sort-chips">
        {SORT_LABELS.map((label, i) => (
          <View
            key={label}
            className={`sort-chip ${i === sortIndex ? "active" : ""}`}
            onClick={() => onSortChange(i)}
          >
            <Text>{label}</Text>
          </View>
        ))}
      </View>

      {/* 双列瀑布流 */}
      {posts.length > 0 ? (
        <View className="waterfall">
          <View className="waterfall-col">
            {posts.filter((_, i) => i % 2 === 0).map((post) => (
              <WorkCard key={post.post_id} post={post} palette={palette} onTap={() => goDetail(post.post_id)} />
            ))}
          </View>
          <View className="waterfall-col">
            {posts.filter((_, i) => i % 2 === 1).map((post) => (
              <WorkCard key={post.post_id} post={post} palette={palette} onTap={() => goDetail(post.post_id)} />
            ))}
          </View>
        </View>
      ) : !loading ? (
        <View className="empty-tip">暂无作品</View>
      ) : null}

      {loading && <View className="loading-tip">加载中...</View>}
      {!hasMore && posts.length > 0 && <View className="loading-tip">没有更多了</View>}
    </View>
  );
}

/** 作品卡片组件（对齐 iOS WorkCardView） */
function WorkCard({ post, palette, onTap }: {
  post: PostItem;
  palette: (topic?: string) => [string, string];
  onTap: () => void;
}) {
  const [colors] = useState(() => palette(undefined));
  const title = post.content || "作品分享";
  const authorName = post.author?.nickname || "用户";
  const courseTitle = post.course?.title;

  return (
    <View className="work-card" onClick={onTap}>
      {/* 作品图 3:4 */}
      <View className="work-cover">
        {post.images && post.images.length > 0 ? (
          <Image className="work-cover-img" src={post.images[0]} mode="aspectFill" />
        ) : (
          <View className="work-cover-placeholder" style={{ background: `linear-gradient(135deg, ${colors[0]}, ${colors[1]})` }} />
        )}
      </View>

      {/* 信息区 */}
      <View className="work-info">
        <Text className="work-title">{title}</Text>
        <View className="work-meta">
          <Text className="work-author">{authorName}</Text>
          <Text className="work-likes">♥ {post.like_count}</Text>
        </View>
        {courseTitle && (
          <Text className="work-course">关联课程·{courseTitle}</Text>
        )}
      </View>
    </View>
  );
}
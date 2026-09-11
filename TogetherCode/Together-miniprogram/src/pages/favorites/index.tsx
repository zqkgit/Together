import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getFavorites, type FavoriteItem } from "../../services/interaction";
import "./index.scss";

type Tab = "course" | "teacher" | "studio";

const TABS: Array<{ key: Tab; label: string }> = [
  { key: "course", label: "课程" },
  { key: "teacher", label: "老师" },
  { key: "studio", label: "工作室" }
];

export default function FavoritesPage() {
  const [tab, setTab] = useState<Tab>("course");
  const [list, setList] = useState<FavoriteItem[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    setPage(1);
    setList([]);
    load(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab]);

  const load = async (p: number) => {
    setLoading(true);
    try {
      const res = await getFavorites(tab, p);
      setList((prev) => (p === 1 ? res.list : [...prev, ...res.list]));
      setTotal(res.total);
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

  const go = (item: FavoriteItem) => {
    if (tab === "course") {
      Taro.navigateTo({ url: `/pages/course-detail/index?id=${item.target_id}` });
    } else if (tab === "teacher") {
      Taro.navigateTo({ url: `/pages/teacher-homepage/index?id=${item.target_id}` });
    } else {
      Taro.navigateTo({ url: `/pages/studio-homepage/index?id=${item.target_id}` });
    }
  };

  return (
    <View className="favorites-page">
      <View className="tab-bar">
        {TABS.map((t) => (
          <View
            key={t.key}
            className={`tab-item ${tab === t.key ? "active" : ""}`}
            onClick={() => setTab(t.key)}
          >
            {t.label}
          </View>
        ))}
      </View>

      <View className="list">
        {list.map((item) => (
          <View key={item.target_id} className="item card" onClick={() => go(item)}>
            <Image
              className={`item-cover ${tab === "teacher" ? "item-round" : ""}`}
              src={item.cover || ""}
              mode="aspectFill"
            />
            <View className="item-body">
              <View className="item-title">{item.title}</View>
              {item.rating !== undefined && item.rating > 0 && (
                <View className="item-sub">⭐ {item.rating}</View>
              )}
              <View className="item-sub">{item.subtitle}</View>
            </View>
            <Text className="item-arrow">›</Text>
          </View>
        ))}
        {list.length === 0 && !loading && <View className="empty-tip">还没有收藏，去逛逛吧</View>}
        {loading && <View className="empty-tip">加载中...</View>}
        {!loading && list.length > 0 && list.length >= total && <View className="empty-tip">没有更多了</View>}
        {!loading && list.length > 0 && list.length < total && (
          <View className="load-more" onClick={loadMore}>加载更多</View>
        )}
      </View>
    </View>
  );
}

import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text } from "@tarojs/components";
import { getAnnouncements, type AnnouncementItem } from "../../services/announcement";
import "./index.scss";

export default function AnnouncementsPage() {
  const [list, setList] = useState<AnnouncementItem[]>([]);
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
      const data = await getAnnouncements(p, 15);
      setList((prev) => (p === 1 ? data.list : [...prev, ...data.list]));
      setTotal(data.total);
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
    Taro.navigateTo({ url: `/pages/announcement-detail/index?id=${id}` });
  };

  return (
    <View className="announcements">
      <View className="list">
        {list.map((a) => (
          <View key={a.announcement_id} className="card item" onClick={() => goDetail(a.announcement_id)}>
            <View className="item-title">{a.title}</View>
            <View className="item-time">{String(a.publish_at || a.created_at || "").slice(0, 10)}</View>
          </View>
        ))}
        {list.length === 0 && !loading && <View className="empty-tip">暂无公告</View>}
        {loading && <View className="empty-tip">加载中...</View>}
        {!loading && list.length > 0 && list.length >= total && <View className="empty-tip">没有更多了</View>}
        {!loading && list.length > 0 && list.length < total && (
          <View className="load-more" onClick={loadMore}>加载更多</View>
        )}
      </View>
    </View>
  );
}

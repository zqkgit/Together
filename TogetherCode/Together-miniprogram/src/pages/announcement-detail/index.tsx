import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getAnnouncementDetail, type AnnouncementItem } from "../../services/announcement";
import "./index.scss";

export default function AnnouncementDetailPage() {
  const [detail, setDetail] = useState<AnnouncementItem | null>(null);

  useEffect(() => {
    const id = Taro.getCurrentInstance().router?.params?.id;
    if (id) load(id);
  }, []);

  const load = async (id: string) => {
    try {
      setDetail(await getAnnouncementDetail(id));
    } catch {
      // 拦截器已提示
    }
  };

  if (!detail) {
    return <View className="announcement-detail"><View className="empty-tip">加载中...</View></View>;
  }

  return (
    <View className="announcement-detail">
      <View className="detail-title">{detail.title}</View>
      <View className="detail-time">{String(detail.publish_at || detail.created_at || "").slice(0, 16)}</View>
      {detail.image && detail.image.length > 0 && (
        <Image className="detail-image" src={detail.image[0]} mode="widthFix" />
      )}
      <View className="detail-content">
        {String(detail.content || "").split("\n").map((line, i) =>
          line.trim() ? <Text key={i} className="detail-line">{line}</Text> : <View key={i} className="detail-gap" />
        )}
      </View>
    </View>
  );
}

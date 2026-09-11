import React, { useEffect, useState } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getTeacherHomepage, type TeacherHomepage } from "../../services/profile";
import { fenToYuan } from "../../services/course";
import "./index.scss";

export default function TeacherHomepagePage() {
  const router = useRouter();
  const id = router.params.id || "";
  const [data, setData] = useState<TeacherHomepage | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (id) load();
  }, [id]);

  const load = async () => {
    setLoading(true);
    try {
      setData(await getTeacherHomepage(id));
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const goStudio = (studioId: string) => {
    Taro.navigateTo({ url: `/pages/studio-homepage/index?id=${studioId}` });
  };

  const goWork = (postId: string) => {
    Taro.navigateTo({ url: `/pages/post-detail/index?id=${postId}` });
  };

  if (loading) {
    return <View className="empty-tip">加载中...</View>;
  }
  if (!data) {
    return <View className="empty-tip">老师不存在或未认证</View>;
  }

  const { user, profile, studios, works } = data;

  return (
    <View className="teacher-page">
      <View className="hero">
        <Image className="hero-avatar" src={user?.avatar || ""} mode="aspectFill" />
        <View className="hero-name">{profile.real_name || user?.nickname || "艺启老师"}</View>
        <View className="hero-tags">
          {(profile.subjects || []).map((s) => (
            <Text key={s} className="hero-tag">{s}</Text>
          ))}
          {profile.years > 0 && <Text className="hero-tag">教龄 {profile.years} 年</Text>}
        </View>
        {user?.city && <View className="hero-city">{user.city}</View>}
      </View>

      <View className="stats-card card">
        <View className="stat">
          <Text className="stat-num">{profile.rating > 0 ? profile.rating.toFixed(1) : "—"}</Text>
          <Text className="stat-label">评分</Text>
        </View>
        <View className="stat">
          <Text className="stat-num">{profile.student_count}</Text>
          <Text className="stat-label">学员</Text>
        </View>
        <View className="stat">
          <Text className="stat-num">{profile.work_count}</Text>
          <Text className="stat-label">作品</Text>
        </View>
        <View className="stat">
          <Text className="stat-num">{profile.fans}</Text>
          <Text className="stat-label">粉丝</Text>
        </View>
      </View>

      {profile.intro && (
        <View className="card">
          <View className="section-label">老师简介</View>
          <View className="intro-text">{profile.intro}</View>
        </View>
      )}

      {studios.length > 0 && (
        <View className="card">
          <View className="section-label">合作工作室</View>
          {studios.map((s) => (
            <View key={s.studio_id} className="studio-row" onClick={() => goStudio(s.studio_id)}>
              <Image className="studio-cover" src={s.cover || ""} mode="aspectFill" />
              <View className="studio-info">
                <View className="studio-name">{s.name}</View>
                <View className="studio-addr">{s.address || ""}</View>
              </View>
              <Text className="studio-arrow">›</Text>
            </View>
          ))}
        </View>
      )}

      {works.list.length > 0 && (
        <View className="card">
          <View className="section-label">作品墙（{works.total}）</View>
          <View className="work-grid">
            {works.list.map((w) => (
              <View key={w.post_id} className="work-item" onClick={() => goWork(w.post_id)}>
                {w.images?.[0] ? (
                  <Image className="work-img" src={w.images[0]} mode="aspectFill" />
                ) : (
                  <View className="work-text">{String(w.content || "").slice(0, 8)}</View>
                )}
              </View>
            ))}
          </View>
        </View>
      )}
    </View>
  );
}

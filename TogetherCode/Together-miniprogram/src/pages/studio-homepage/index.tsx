import React, { useEffect, useState } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getStudioHomepage, type StudioHomepage } from "../../services/profile";
import { fenToYuan } from "../../services/course";
import "./index.scss";

export default function StudioHomepagePage() {
  const router = useRouter();
  const id = router.params.id || "";
  const [data, setData] = useState<StudioHomepage | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (id) load();
  }, [id]);

  const load = async () => {
    setLoading(true);
    try {
      setData(await getStudioHomepage(id));
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const goCourse = (courseId: string) => {
    Taro.navigateTo({ url: `/pages/course-detail/index?id=${courseId}` });
  };

  const goTeacher = (userId: string) => {
    Taro.navigateTo({ url: `/pages/teacher-homepage/index?id=${userId}` });
  };

  if (loading) {
    return <View className="empty-tip">加载中...</View>;
  }
  if (!data) {
    return <View className="empty-tip">工作室不存在或已关闭</View>;
  }

  const { studio, courses, teachers } = data;

  return (
    <View className="studio-page">
      {studio.cover ? (
        <Image className="studio-cover-hero" src={studio.cover} mode="aspectFill" />
      ) : (
        <View className="studio-cover-hero studio-cover-placeholder">{studio.name?.[0] || "艺"}</View>
      )}

      <View className="studio-header card">
        <View className="studio-name">{studio.name}</View>
        {studio.type_tags && studio.type_tags.length > 0 && (
          <View className="studio-tags">
            {studio.type_tags.map((t) => (
              <Text key={t} className="studio-tag">{t}</Text>
            ))}
          </View>
        )}
        {studio.address && <View className="studio-line">📍 {studio.address}</View>}
        {studio.hours && <View className="studio-line">🕘 {studio.hours}</View>}
        {studio.phone && <View className="studio-line">📞 {studio.phone}</View>}
      </View>

      {studio.intro && (
        <View className="card">
          <View className="section-label">工作室简介</View>
          <View className="intro-text">{studio.intro}</View>
        </View>
      )}

      {courses.list.length > 0 && (
        <View className="card">
          <View className="section-label">在售课程（{courses.total}）</View>
          {courses.list.map((c) => (
            <View key={c.course_id} className="course-row" onClick={() => goCourse(c.course_id)}>
              <Image className="course-cover" src={c.cover || ""} mode="aspectFill" />
              <View className="course-info">
                <View className="course-title">{c.title}</View>
                <View className="course-meta">
                  {c.age_min != null && c.age_max != null
                    ? `${c.age_min}-${c.age_max} 岁`
                    : "全龄段"}
                  {c.lesson_count > 0 ? ` · ${c.lesson_count} 课时` : ""}
                </View>
                <View className="course-price">¥{fenToYuan(c.price)}</View>
              </View>
              <Text className="course-arrow">›</Text>
            </View>
          ))}
        </View>
      )}

      {teachers.length > 0 && (
        <View className="card">
          <View className="section-label">授课老师（{teachers.length}）</View>
          {teachers.map((t) => (
            <View
              key={t.teacher_id}
              className="teacher-row"
              onClick={() => t.user_id && goTeacher(t.user_id)}
            >
              <Image className="teacher-avatar" src={t.avatar || ""} mode="aspectFill" />
              <View className="teacher-info">
                <View className="teacher-name">
                  {t.nickname || t.real_name}
                  {t.rating > 0 && <Text className="teacher-rating"> {t.rating.toFixed(1)}</Text>}
                </View>
                <View className="teacher-subjects">{(t.subjects || []).join(" / ") || "艺术老师"}</View>
              </View>
              <Text className="teacher-arrow">›</Text>
            </View>
          ))}
        </View>
      )}
    </View>
  );
}

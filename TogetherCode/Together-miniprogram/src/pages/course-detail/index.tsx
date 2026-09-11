import React, { useEffect, useState } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Image, Button } from "@tarojs/components";
import { getCourseDetail, fenToYuan, type CoursePackage } from "../../services/course";
import "./index.scss";

export default function CourseDetailPage() {
  const router = useRouter();
  const id = router.params.id || "";
  const [course, setCourse] = useState<any>(null);
  const [pkg, setPkg] = useState<CoursePackage | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (id) loadData();
  }, [id]);

  const loadData = async () => {
    setLoading(true);
    try {
      const data = await getCourseDetail(id);
      setCourse(data);
      const available = (data.packages || []).filter((p: CoursePackage) => Number(p.status) === 1);
      if (available.length > 0) setPkg(available[0]);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const goBuy = () => {
    if (!pkg) return;
    Taro.navigateTo({
      url: `/pages/order-confirm/index?course_id=${course.course_id}&package_id=${pkg.package_id}`
    });
  };

  return (
    <View className="detail">
      {loading ? (
        <View className="empty-tip">加载中...</View>
      ) : course ? (
        <>
          <Image className="detail-cover" src={course.cover || ""} mode="aspectFill" />
          <View className="card detail-body">
            <View className="detail-price">
              <Text className="price-now">¥{pkg ? fenToYuan(pkg.price) : fenToYuan(course.price)}</Text>
              {pkg && pkg.original_price > 0 && (
                <Text className="price-original">¥{fenToYuan(pkg.original_price)}</Text>
              )}
            </View>
            <View className="detail-title">{course.title}</View>
            <View className="detail-meta">
              <Text>{course.age_min && course.age_max ? `${course.age_min}-${course.age_max} 岁` : "全龄段"}</Text>
              <Text>·</Text>
              <Text>{course.total_lessons} 课时</Text>
              <Text>·</Text>
              <Text>{course.duration_min} 分钟/课</Text>
            </View>
            {course.studio && (
              <View className="studio-row">
                <Text className="studio-name">{course.studio.name}</Text>
                <Text className="studio-addr">{course.studio.address}</Text>
              </View>
            )}
          </View>

          {course.packages && course.packages.length > 0 && (
            <View className="card">
              <View className="section-label">课时包</View>
              {course.packages
                .filter((p: CoursePackage) => Number(p.status) === 1)
                .map((p: CoursePackage) => (
                  <View
                    key={p.package_id}
                    className={`pkg-row ${pkg?.package_id === p.package_id ? "pkg-active" : ""}`}
                    onClick={() => setPkg(p)}
                  >
                    <View className="pkg-info">
                      <View className="pkg-name">{p.name}</View>
                      <View className="pkg-lessons">{p.lessons} 课时</View>
                    </View>
                    <View className="pkg-price">¥{fenToYuan(p.price)}</View>
                  </View>
                ))}
            </View>
          )}

          {course.teacher && (
            <View className="card">
              <View className="section-label">授课老师</View>
              <View className="teacher-row">
                <View className="teacher-name">{course.teacher.real_name}</View>
                {course.teacher.rating > 0 && <View className="teacher-rating">评分 {course.teacher.rating}</View>}
              </View>
              {course.teacher.intro && <View className="teacher-intro">{course.teacher.intro}</View>}
            </View>
          )}

          <View className="buy-bar">
            <View className="buy-price">
              <Text className="buy-price-now">¥{pkg ? fenToYuan(pkg.price) : fenToYuan(course.price)}</Text>
            </View>
            <Button className="btn-primary buy-btn" disabled={!pkg} onClick={goBuy}>
              立即报名
            </Button>
          </View>
        </>
      ) : (
        <View className="empty-tip">课程不存在或已下架</View>
      )}
    </View>
  );
}

import React, { useEffect, useState } from "react";
import Taro, { useRouter, useShareAppMessage } from "@tarojs/taro";
import { View, Text, Image, Button, Input, Textarea } from "@tarojs/components";
import { getCourseDetail, fenToYuan, type CoursePackage } from "../../services/course";
import { createDistributionLink } from "../../services/distribution";
import { getDistFromParams, buildCourseSharePath, getShareUid } from "../../utils/share";
import { getCourseReviews, postCourseReview, getFavoriteIds, addFavorite, removeFavorite, type CourseReviews } from "../../services/interaction";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

export default function CourseDetailPage() {
  const router = useRouter();
  const id = router.params.id || "";
  const distCode = getDistFromParams();
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [course, setCourse] = useState<any>(null);
  const [pkg, setPkg] = useState<CoursePackage | null>(null);
  const [loading, setLoading] = useState(true);
  // 分享码：登录用户分享本课程时生成，用于分享卡片归因
  const [shareLink, setShareLink] = useState<{ code: string; share_url: string } | null>(null);
  // 收藏
  const [isFavorite, setIsFavorite] = useState(false);
  // 评价
  const [reviews, setReviews] = useState<CourseReviews | null>(null);
  const [reviewPage, setReviewPage] = useState(1);
  const [showReviewForm, setShowReviewForm] = useState(false);
  const [reviewRating, setReviewRating] = useState(5);
  const [reviewContent, setReviewContent] = useState("");
  const [submitting, setSubmitting] = useState(false);

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
      prefetchShareCode(data);
      loadReviews(1);
      if (isLoggedIn) loadFavoriteState();
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const loadFavoriteState = async () => {
    try {
      const ids = await getFavoriteIds("course");
      setIsFavorite(ids.includes(id));
    } catch {
      // 忽略
    }
  };

  const toggleFavorite = async () => {
    if (!isLoggedIn) {
      Taro.showToast({ title: "请先登录", icon: "none" });
      return;
    }
    try {
      if (isFavorite) {
        await removeFavorite("course", id);
        setIsFavorite(false);
        Taro.showToast({ title: "已取消收藏", icon: "none" });
      } else {
        await addFavorite("course", id);
        setIsFavorite(true);
        Taro.showToast({ title: "已收藏", icon: "success" });
      }
    } catch {
      // 拦截器已提示
    }
  };

  const loadReviews = async (p: number) => {
    try {
      const data = await getCourseReviews(id, p);
      setReviews(data);
      setReviewPage(p);
    } catch {
      // 忽略
    }
  };

  const submitReview = async () => {
    if (!isLoggedIn) {
      Taro.showToast({ title: "请先登录", icon: "none" });
      return;
    }
    if (!reviewContent.trim()) {
      Taro.showToast({ title: "写点评价内容吧", icon: "none" });
      return;
    }
    setSubmitting(true);
    try {
      await postCourseReview(id, { rating: reviewRating, content: reviewContent.trim() });
      Taro.showToast({ title: "评价成功", icon: "success" });
      setShowReviewForm(false);
      setReviewContent("");
      setReviewRating(5);
      loadReviews(1);
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  // 预取分享码：当前登录用户分享本课程时生成；游客不生成
  const prefetchShareCode = async (data: any) => {
    if (!getShareUid() || !data?.course_id) return;
    try {
      const link = await createDistributionLink({ course_id: data.course_id });
      setShareLink(link);
    } catch {
      // 未登录/失败则跳过，不影响浏览
    }
  };

  // 微信分享卡片（右上角/转发按钮触发）
  useShareAppMessage(() => {
    return {
      title: `${course?.title || "艺启课程"}${pkg ? ` · ${pkg.lessons}课时 ¥${fenToYuan(pkg.price)}` : ""}`,
      path: buildCourseSharePath(id, shareLink?.code || ""),
      imageUrl: course?.cover || ""
    };
  });

  const goBuy = () => {
    if (!pkg) return;
    const base = `/pages/order-confirm/index?course_id=${course.course_id}&package_id=${pkg.package_id}`;
    // 透传分享归因：被分享者进入课程详情 → 报名 → 下单归因到分享人
    const dist = distCode || shareLink?.code;
    Taro.navigateTo({
      url: dist ? `${base}&dist=${dist}` : base
    });
  };

  const goTeacher = () => {
    if (!course?.teacher?.teacher_id) return;
    Taro.navigateTo({ url: `/pages/teacher-homepage/index?id=${course.teacher.teacher_id}` });
  };

  const goStudio = () => {
    if (!course?.studio?.studio_id) return;
    Taro.navigateTo({ url: `/pages/studio-homepage/index?id=${course.studio.studio_id}` });
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
            <View className="detail-title-row">
              <View className="detail-title">{course.title}</View>
              <View
                className={`fav-btn ${isFavorite ? "fav-active" : ""}`}
                onClick={toggleFavorite}
              >
                {isFavorite ? "♥ 已收藏" : "♡ 收藏"}
              </View>
            </View>
            <View className="detail-meta">
              <Text>{course.age_min && course.age_max ? `${course.age_min}-${course.age_max} 岁` : "全龄段"}</Text>
              <Text>·</Text>
              <Text>{course.total_lessons} 课时</Text>
              <Text>·</Text>
              <Text>{course.duration_min} 分钟/课</Text>
            </View>
            {course.studio && (
              <View className="studio-row" onClick={goStudio}>
                <Text className="studio-name">{course.studio.name}</Text>
                <Text className="studio-addr">{course.studio.address}</Text>
                <Text className="studio-arrow">›</Text>
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
            <View className="card" onClick={goTeacher}>
              <View className="section-label">授课老师</View>
              <View className="teacher-row">
                <View className="teacher-name">{course.teacher.real_name}</View>
                {course.teacher.rating > 0 && <View className="teacher-rating">评分 {course.teacher.rating}</View>}
                <Text className="studio-arrow">›</Text>
              </View>
              {course.teacher.intro && <View className="teacher-intro">{course.teacher.intro}</View>}
            </View>
          )}

          <View className="card">
            <View className="section-label">课程评价</View>
            {reviews && reviews.rating_count > 0 && (
              <View className="review-summary">
                <View className="review-avg">
                  <Text className="review-avg-num">{reviews.average}</Text>
                  <Text className="review-avg-sub">{reviews.rating_count} 条评价</Text>
                </View>
                <View className="review-bars">
                  {[5, 4, 3, 2, 1].map((star) => (
                    <View key={star} className="review-bar-row">
                      <Text className="review-bar-label">{star}★</Text>
                      <View className="review-bar-track">
                        <View
                          className="review-bar-fill"
                          style={{
                            width: `${reviews.rating_count ? Math.round(((reviews.rating_distribution[String(star)] || 0) / reviews.rating_count) * 100) : 0}%`
                          }}
                        />
                      </View>
                    </View>
                  ))}
                </View>
              </View>
            )}
            {reviews?.list?.length > 0 ? (
              <View className="review-list">
                {reviews.list.map((r) => (
                  <View key={r.review_id} className="review-item">
                    <View className="review-head">
                      <Text className="review-nick">{r.nickname}</Text>
                      <Text className="review-stars">{"★".repeat(r.rating)}{"☆".repeat(5 - r.rating)}</Text>
                      <Text className="review-time">{String(r.created_at || "").slice(0, 10)}</Text>
                    </View>
                    {r.content && <View className="review-content">{r.content}</View>}
                  </View>
                ))}
                {reviews.total > reviews.list.length && (
                  <View className="review-more" onClick={() => loadReviews(reviewPage + 1)}>
                    加载更多评价
                  </View>
                )}
              </View>
            ) : (
              <View className="empty-tip">暂无评价，购买后来说两句吧</View>
            )}
            <View
              className="review-write-btn"
              onClick={() => {
                if (!isLoggedIn) {
                  Taro.showToast({ title: "请先登录", icon: "none" });
                  return;
                }
                setShowReviewForm(!showReviewForm);
              }}
            >
              {showReviewForm ? "收起" : "写评价"}
            </View>
            {showReviewForm && (
              <View className="review-form">
                <View className="star-pick">
                  {[1, 2, 3, 4, 5].map((star) => (
                    <Text
                      key={star}
                      className={`star-pick-item ${star <= reviewRating ? "on" : ""}`}
                      onClick={() => setReviewRating(star)}
                    >
                      ★
                    </Text>
                  ))}
                </View>
                <Textarea
                  className="review-input"
                  placeholder="说说课程感受（购买后评价）"
                  value={reviewContent}
                  onInput={(e) => setReviewContent(e.detail.value)}
                  maxlength={500}
                />
                <Button className="btn-primary review-submit" disabled={submitting} onClick={submitReview}>
                  提交评价
                </Button>
              </View>
            )}
          </View>

          <View className="buy-bar">
            <View className="buy-price">
              <Text className="buy-price-now">¥{pkg ? fenToYuan(pkg.price) : fenToYuan(course.price)}</Text>
            </View>
            <View
              className="buy-share-btn"
              onClick={() =>
                Taro.navigateTo({
                  url: `/pages/poster/index?type=course&id=${course.course_id}&code=${shareLink?.code || ""}`
                })
              }
            >
              海报
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

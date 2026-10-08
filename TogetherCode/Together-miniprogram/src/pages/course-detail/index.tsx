import { useEffect, useState } from "react";
import Taro, { useRouter, useShareAppMessage } from "@tarojs/taro";
import { View, Text, Image, Button, Textarea, ScrollView } from "@tarojs/components";
import { getCourseDetail, fenToYuan } from "../../services/course";
import { createDistributionLink } from "../../services/distribution";
import { uploadImages } from "../../services/upload";
import { getDistFromParams, buildCourseSharePath, getShareUid } from "../../utils/share";
import { getCourseReviews, postCourseReview, type CourseReviews, type ReviewItem } from "../../services/interaction";
import { createConversation } from "../../services/message";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

export default function CourseDetailPage() {
  const router = useRouter();
  const id = router.params.id || "";
  const distCode = getDistFromParams();
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [course, setCourse] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  // 分享码
  const [shareLink, setShareLink] = useState<{ code: string; share_url: string } | null>(null);
  // 评价
  const [reviews, setReviews] = useState<CourseReviews | null>(null);
  const [showReviewForm, setShowReviewForm] = useState(false);
  const [reviewRating, setReviewRating] = useState(5);
  const [reviewContent, setReviewContent] = useState("");
  const [reviewImages, setReviewImages] = useState<string[]>([]);
  const [reviewUploading, setReviewUploading] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (id) loadData();
  }, [id]);

  const loadData = async () => {
    setLoading(true);
    try {
      const data = await getCourseDetail(id);
      setCourse(data);
      prefetchShareCode(data);
      loadReviews();
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const loadReviews = async () => {
    try {
      const data = await getCourseReviews(id, 1);
      setReviews(data);
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
      await postCourseReview(id, {
        rating: reviewRating,
        content: reviewContent.trim(),
        images: reviewImages.length ? reviewImages : undefined
      });
      Taro.showToast({ title: "已提交，等待平台审核", icon: "success" });
      setShowReviewForm(false);
      setReviewContent("");
      setReviewRating(5);
      setReviewImages([]);
      loadReviews();
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  const chooseReviewImages = async () => {
    if (reviewUploading) return;
    const remain = 3 - reviewImages.length;
    if (remain <= 0) {
      Taro.showToast({ title: "最多 3 张图片", icon: "none" });
      return;
    }
    try {
      const res = await Taro.chooseImage({
        count: remain,
        sizeType: ["compressed"],
        sourceType: ["album", "camera"]
      });
      const paths = res.tempFilePaths || [];
      if (!paths.length) return;
      setReviewUploading(true);
      Taro.showLoading({ title: "上传中..." });
      const urls = await uploadImages(paths, "work");
      setReviewImages((prev) => [...prev, ...urls].slice(0, 3));
    } catch (e) {
      const message = (e as Error).message || "";
      if (message) Taro.showToast({ title: message, icon: "none" });
    } finally {
      Taro.hideLoading();
      setReviewUploading(false);
    }
  };

  const prefetchShareCode = async (data: any) => {
    if (!getShareUid() || !data?.course_id) return;
    try {
      const link = await createDistributionLink({ course_id: data.course_id });
      setShareLink(link);
    } catch {
      // 未登录/失败则跳过
    }
  };

  useShareAppMessage(() => {
    return {
      title: `${course?.title || "艺启课程"}${course?.total_lessons ? ` · ${course.total_lessons}课时 ¥${fenToYuan(course.price)}` : ""}`,
      path: buildCourseSharePath(id, shareLink?.code || ""),
      imageUrl: course?.cover || ""
    };
  });

  const goBuy = () => {
    if (!course) return;
    const base = `/pages/order-confirm/index?course_id=${course.course_id}`;
    const dist = distCode || shareLink?.code;
    Taro.navigateTo({
      url: dist ? `${base}&dist=${dist}` : base
    });
  };

  const goChat = async () => {
    if (!isLoggedIn) {
      Taro.showToast({ title: "请先登录", icon: "none" });
      return;
    }
    const userId = course?.studio?.user_id;
    if (!userId) {
      Taro.showToast({ title: "该课程暂无工作室信息", icon: "none" });
      return;
    }
    try {
      Taro.showLoading({ title: "加载中..." });
      const res = await createConversation(userId);
      Taro.hideLoading();
      const peerName = encodeURIComponent(course?.studio?.name || "工作室");
      Taro.navigateTo({
        url: `/pages/chat/index?conversation_id=${res.data.conversation_id}&peer_name=${peerName}`
      });
    } catch {
      Taro.hideLoading();
      Taro.showToast({ title: "创建会话失败", icon: "none" });
    }
  };

  // 标签行：年龄 · 班型
  const tagTexts: string[] = [];
  if (course?.age_min && course?.age_max && course.age_max > course.age_min) {
    tagTexts.push(`${course.age_min}-${course.age_max}岁`);
  } else if (course?.age_min) {
    tagTexts.push(`${course.age_min}岁+`);
  }
  if (course?.class_size && course.class_size > 0) {
    tagTexts.push(`小班${course.class_size}人`);
  }

  // 副标题：机构 · 总课时
  const subtitleParts: string[] = [];
  if (course?.studio?.name) subtitleParts.push(course.studio.name);
  if (course?.total_lessons && course.total_lessons > 0) subtitleParts.push(`${course.total_lessons} 课时`);
  const subtitleText = subtitleParts.join(" · ");

  // 价格文案
  const priceText = course?.price > 0 ? `¥${fenToYuan(course.price)}` : "价格咨询";
  const bottomPriceText = course?.price > 0 && course?.total_lessons > 0
    ? `${priceText}/${course.total_lessons}节`
    : priceText;

  // 评价前2条
  const previewReviews = reviews?.list?.slice(0, 2) || [];
  const hasMoreReviews = (reviews?.list?.length || 0) > 2;

  return (
    <View className="course-detail">
      {loading ? (
        <View className="cd-empty">加载中...</View>
      ) : course ? (
        <>
          <ScrollView className="cd-scroll" scrollY>
            {/* 封面 */}
            <View className="cd-cover-wrap">
              <Image
                className="cd-cover"
                src={course.cover || ""}
                mode="aspectFill"
              />
            </View>

            {/* 信息卡：标签行 + 标题 + 副标题 */}
            <View className="cd-card cd-info-card">
              {tagTexts.length > 0 && (
                <View className="cd-tags">
                  {tagTexts.map((t) => (
                    <View className="cd-tag" key={t}>
                      <Text className="cd-tag-text">{t}</Text>
                    </View>
                  ))}
                </View>
              )}
              <View className="cd-title">{course.title || "课程"}</View>
              {subtitleText && <View className="cd-subtitle">{subtitleText}</View>}
            </View>

            {/* 机构与老师卡 */}
            {(course.studio || (course.teacher && course.teacher.real_name)) && (
              <View className="cd-card cd-institution-card">
                {course.studio && (
                  <View className="cd-inst-row" onClick={() => {
                    if (course.studio?.studio_id) {
                      Taro.navigateTo({ url: `/pages/studio-homepage/index?id=${course.studio.studio_id}` });
                    }
                  }}>
                    <View className="cd-inst-icon cd-inst-icon--studio">🏛</View>
                    <View className="cd-inst-info">
                      <Text className="cd-inst-name">{course.studio.name || "未知机构"}</Text>
                      <Text className="cd-inst-sub">
                        {[
                          course.rating > 0 ? `评分 ${course.rating.toFixed(1)}` : "",
                          course.sales > 0 ? `${course.sales} 人学过` : "",
                          course.studio.address || ""
                        ].filter(Boolean).join(" · ")}
                      </Text>
                    </View>
                  </View>
                )}
                {course.teacher && course.teacher.real_name && (
                  <View className="cd-inst-row" onClick={() => {
                    if (course.teacher?.teacher_id) {
                      Taro.navigateTo({ url: `/pages/teacher-homepage/index?id=${course.teacher.teacher_id}` });
                    }
                  }}>
                    <View className="cd-inst-icon cd-inst-icon--teacher">👤</View>
                    <View className="cd-inst-info">
                      <Text className="cd-inst-name">{course.teacher.real_name}</Text>
                      <Text className="cd-inst-sub">
                        {course.teacher.intro || (course.teacher.rating > 0 ? `评分 ${course.teacher.rating.toFixed(1)}` : "")}
                      </Text>
                    </View>
                  </View>
                )}
              </View>
            )}

            {/* 课程介绍 */}
            {course.intro && (
              <View className="cd-card cd-intro-card">
                <View className="cd-section-title">课程介绍</View>
                <View className="cd-intro-text">{course.intro}</View>
              </View>
            )}

            {/* 课时安排 */}
            {course.lessons && course.lessons.length > 0 && (
              <View className="cd-card cd-lessons-card">
                <View className="cd-section-title">课时安排</View>
                <View className="cd-lesson-list">
                  {course.lessons
                    .slice()
                    .sort((a: any, b: any) => (a.lesson_no || 0) - (b.lesson_no || 0))
                    .map((l: any) => (
                      <View className="cd-lesson-row" key={l.lesson_no || l.lesson_id}>
                        <View className="cd-lesson-dot" />
                        <Text className="cd-lesson-title">
                          {l.lesson_no}. {l.title}
                        </Text>
                      </View>
                    ))}
                </View>
              </View>
            )}

            {/* 家长评价 */}
            <View className="cd-card cd-reviews-card">
              <View className="cd-reviews-header">
                <View className="cd-reviews-title-row">
                  <Text className="cd-section-title" style={{ marginBottom: 0 }}>家长评价</Text>
                  <Text className="cd-reviews-count">{reviews?.rating_count || 0} 条</Text>
                </View>
                {isLoggedIn && (
                  <View
                    className="cd-review-write-btn"
                    onClick={() => setShowReviewForm(!showReviewForm)}
                  >
                    {showReviewForm ? "收起" : "写评价"}
                  </View>
                )}
              </View>

              {/* 评分分布 */}
              {reviews && reviews.rating_count > 0 && (
                <View className="cd-review-dist">
                  {[5, 4, 3, 2, 1].map((star) => {
                    const count = reviews.rating_distribution[String(star)] || 0;
                    const ratio = reviews.rating_count ? Math.round((count / reviews.rating_count) * 100) : 0;
                    return (
                      <View className="cd-dist-row" key={star}>
                        <Text className="cd-dist-label">{star}★</Text>
                        <View className="cd-dist-track">
                          <View className="cd-dist-fill" style={{ width: `${ratio}%` }} />
                        </View>
                        <Text className="cd-dist-num">{count}</Text>
                      </View>
                    );
                  })}
                </View>
              )}

              {/* 评价列表（最多2条） */}
              {previewReviews.length > 0 ? (
                <View className="cd-review-list">
                  {previewReviews.map((r: ReviewItem) => (
                    <View key={r.review_id} className="cd-review-item">
                      <View className="cd-review-head">
                        <Image
                          className="cd-review-avatar"
                          src={r.avatar || ""}
                          mode="aspectFill"
                        />
                        <View className="cd-review-user">
                          <Text className="cd-review-nick">{r.nickname || "艺启家长"}</Text>
                          <Text className="cd-review-time">{String(r.created_at || "").slice(0, 10)}</Text>
                        </View>
                      </View>
                      {r.content && <View className="cd-review-content">{r.content}</View>}
                      {r.reply_content && (
                        <View className="cd-review-reply">
                          <Text className="cd-reply-tag cd-reply-tag--studio">工作室</Text>
                          <Text className="cd-reply-text">{r.reply_content}</Text>
                        </View>
                      )}
                      {r.teacher_reply_content && (
                        <View className="cd-review-reply">
                          <Text className="cd-reply-tag cd-reply-tag--teacher">老师</Text>
                          <Text className="cd-reply-text">{r.teacher_reply_content}</Text>
                        </View>
                      )}
                    </View>
                  ))}
                  {hasMoreReviews && (
                    <View
                      className="cd-review-more"
                      onClick={() => Taro.navigateTo({ url: `/pages/course-reviews/index?course_id=${id}` })}
                    >
                      查看全部 {reviews?.total || reviews?.list?.length || 0} 条评价 ›
                    </View>
                  )}
                </View>
              ) : (
                <View className="cd-review-empty">暂无评价，快来写下第一条吧</View>
              )}

              {/* 写评价表单 */}
              {showReviewForm && (
                <View className="cd-review-form">
                  <View className="cd-star-pick">
                    {[1, 2, 3, 4, 5].map((star) => (
                      <Text
                        key={star}
                        className={`cd-star-item ${star <= reviewRating ? "on" : ""}`}
                        onClick={() => setReviewRating(star)}
                      >
                        ★
                      </Text>
                    ))}
                  </View>
                  <Textarea
                    className="cd-review-input"
                    placeholder="说说课程感受"
                    value={reviewContent}
                    onInput={(e) => setReviewContent(e.detail.value)}
                    maxlength={500}
                  />
                  <View className="cd-review-img-picker">
                    {reviewImages.map((img, i) => (
                      <View key={img + i} className="cd-review-picked">
                        <Image className="cd-review-picked-img" src={img} mode="aspectFill" />
                        <Text
                          className="cd-review-picked-del"
                          onClick={() => setReviewImages((prev) => prev.filter((_, idx) => idx !== i))}
                        >
                          ×
                        </Text>
                      </View>
                    ))}
                    {reviewImages.length < 3 && (
                      <View className="cd-review-add" onClick={chooseReviewImages}>
                        {reviewUploading ? "上传中..." : "+"}
                      </View>
                    )}
                  </View>
                  <Button
                    className="btn-primary cd-review-submit"
                    disabled={submitting || reviewUploading}
                    onClick={submitReview}
                  >
                    提交评价
                  </Button>
                </View>
              )}
            </View>

            {/* 底部留白 */}
            <View style={{ height: "140rpx" }} />
          </ScrollView>

          {/* 底部报名栏 */}
          <View className="cd-bottom-bar">
            <View className="cd-bottom-price">
              <Text className="cd-bottom-price-text">{bottomPriceText}</Text>
            </View>
            <View className="cd-bottom-chat" onClick={goChat}>
              咨询工作室
            </View>
            <View className="cd-bottom-enroll" onClick={goBuy}>
              我要报名
            </View>
          </View>
        </>
      ) : (
        <View className="cd-empty">课程不存在或已下架</View>
      )}
    </View>
  );
}
import { useEffect, useState } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Image, ScrollView } from "@tarojs/components";
import { getCourseReviews, type CourseReviews, type ReviewItem } from "../../../services/interaction";
import "./index.scss";

export default function CourseReviewsPage() {
  const router = useRouter();
  const courseId = router.params.course_id || "";
  const [reviews, setReviews] = useState<ReviewItem[]>([]);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (courseId) loadReviews(true);
  }, [courseId]);

  const loadReviews = async (reset: boolean) => {
    const targetPage = reset ? 1 : page + 1;
    try {
      const data: CourseReviews = await getCourseReviews(courseId, targetPage);
      if (reset) {
        setReviews(data.list || []);
        setPage(1);
      } else {
        setReviews((prev) => [...prev, ...(data.list || [])]);
        setPage(targetPage);
      }
      setHasMore((data.list || []).length >= 10);
    } catch {
      // 忽略
    } finally {
      setLoading(false);
    }
  };

  const onScrollToLower = () => {
    if (hasMore && !loading) loadReviews(false);
  };

  return (
    <View className="course-reviews">
      <ScrollView
        className="cr-scroll"
        scrollY
        refresherEnabled
        refresherTriggered={loading}
        onRefresherRefresh={() => loadReviews(true)}
        onScrollToLower={onScrollToLower}
      >
        {loading && reviews.length === 0 ? (
          <View className="cr-empty">加载中...</View>
        ) : reviews.length === 0 ? (
          <View className="cr-empty">暂无评价</View>
        ) : (
          reviews.map((r) => (
            <View key={r.review_id} className="cr-item">
              <View className="cr-head">
                <Image className="cr-avatar" src={r.avatar || ""} mode="aspectFill" />
                <View className="cr-user">
                  <Text className="cr-nick">{r.nickname || "艺启家长"}</Text>
                  <Text className="cr-time">{String(r.created_at || "").slice(0, 10)}</Text>
                </View>
                <Text className="cr-stars">{"★".repeat(r.rating)}{"☆".repeat(5 - r.rating)}</Text>
              </View>
              {r.content && <View className="cr-content">{r.content}</View>}
              {Array.isArray(r.images) && r.images.length > 0 && (
                <View className="cr-images">
                  {r.images.map((img, i) => (
                    <Image
                      key={img + i}
                      className="cr-img"
                      src={img}
                      mode="aspectFill"
                      onClick={() => Taro.previewImage({ urls: r.images, current: img })}
                    />
                  ))}
                </View>
              )}
              {r.reply_content && (
                <View className="cr-reply">
                  <Text className="cr-reply-tag cr-reply-tag--studio">工作室</Text>
                  <Text className="cr-reply-text">{r.reply_content}</Text>
                </View>
              )}
              {r.teacher_reply_content && (
                <View className="cr-reply">
                  <Text className="cr-reply-tag cr-reply-tag--teacher">老师</Text>
                  <Text className="cr-reply-text">{r.teacher_reply_content}</Text>
                </View>
              )}
            </View>
          ))
        )}
        {hasMore && reviews.length > 0 && (
          <View className="cr-loading">加载更多...</View>
        )}
        <View style={{ height: "40rpx" }} />
      </ScrollView>
    </View>
  );
}
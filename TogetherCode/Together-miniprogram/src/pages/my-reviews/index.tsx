import { useEffect, useState } from "react";
import Taro, { useReachBottom } from "@tarojs/taro";
import { View, Text, Image, Button, Textarea } from "@tarojs/components";
import { getMyReviews, updateMyReview, type MyReviewItem } from "../../services/interaction";
import "./index.scss";

const STATUS_META: Record<number, { text: string; cls: string }> = {
  0: { text: "待审核", cls: "pending" },
  1: { text: "已通过", cls: "approved" },
  2: { text: "已驳回", cls: "rejected" }
};

const fmt = (t: string | null) => {
  if (!t) return "";
  const d = new Date(t);
  if (Number.isNaN(d.getTime())) return String(t).slice(0, 16).replace("T", " ");
  const p = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
};

export default function MyReviewsPage() {
  const [list, setList] = useState<MyReviewItem[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);

  // 编辑弹层
  const [editing, setEditing] = useState<MyReviewItem | null>(null);
  const [editRating, setEditRating] = useState(5);
  const [editContent, setEditContent] = useState("");
  const [saving, setSaving] = useState(false);

  const load = async (p: number) => {
    setLoading(true);
    try {
      const res = await getMyReviews(p);
      setList((prev) => (p === 1 ? res.list : [...prev, ...res.list]));
      setTotal(res.total);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const loadMore = () => {
    if (loading || list.length >= total) return;
    const next = page + 1;
    setPage(next);
    load(next);
  };

  useReachBottom(() => {
    loadMore();
  });

  const openEdit = (item: MyReviewItem) => {
    setEditing(item);
    setEditRating(item.rating);
    setEditContent(item.content || "");
  };

  const closeEdit = () => {
    if (saving) return;
    setEditing(null);
  };

  const submitEdit = async () => {
    if (!editing) return;
    if (!editContent.trim()) {
      Taro.showToast({ title: "写点评价内容吧", icon: "none" });
      return;
    }
    setSaving(true);
    try {
      await updateMyReview(editing.review_id, {
        rating: editRating,
        content: editContent.trim()
      });
      Taro.showToast({ title: "已提交，等待审核", icon: "success" });
      setEditing(null);
      load(1);
    } catch {
      // 拦截器已提示
    } finally {
      setSaving(false);
    }
  };

  const goCourse = (item: MyReviewItem) => {
    if (!item.course) return;
    Taro.navigateTo({ url: `/pages/course-detail/index?id=${item.course.course_id}` });
  };

  return (
    <View className="my-reviews-page">
      <View className="page-nav">
        <View className="nav-back" onClick={() => Taro.navigateBack()}>‹</View>
        <Text className="nav-title">我的评价</Text>
        <View className="nav-right" />
      </View>

      <View className="review-list">
        {list.map((item) => {
          const st = STATUS_META[item.status] || STATUS_META[1];
          return (
            <View key={item.review_id} className="review-card" onClick={() => goCourse(item)}>
              <View className="card-top">
                <Image
                  className="course-cover"
                  src={item.course?.cover || ""}
                  mode="aspectFill"
                />
                <View className="card-main">
                  <View className="course-title">{item.course?.title || "课程"}</View>
                  <View className="stars">
                    {"★".repeat(item.rating)}
                    <Text className="stars-dim">{"★".repeat(5 - item.rating)}</Text>
                  </View>
                </View>
                <Text className={`status ${st.cls}`}>{st.text}</Text>
              </View>

              {item.content && <Text className="review-content">{item.content}</Text>}

              {item.images && item.images.length > 0 && (
                <View className="thumb-row">
                  {item.images.slice(0, 3).map((u, i) => (
                    <Image key={i} className="thumb" src={u} mode="aspectFill" />
                  ))}
                </View>
              )}

              {item.reply_content && (
                <View className="reply-box">
                  <Text className="reply-label">工作室回复：</Text>
                  <Text className="reply-text">{item.reply_content}</Text>
                </View>
              )}
              {item.teacher_reply_content && (
                <View className="reply-box teacher">
                  <Text className="reply-label">老师回复：</Text>
                  <Text className="reply-text">{item.teacher_reply_content}</Text>
                </View>
              )}

              {item.status === 2 && item.reject_reason && (
                <View className="reject-box">驳回原因：{item.reject_reason}</View>
              )}

              <View className="card-foot">
                <Text className="time">{fmt(item.created_at)}</Text>
                {(item.status === 0 || item.status === 2) && (
                  <Button className="edit-btn" size="mini" onClick={(e) => { e.stopPropagation(); openEdit(item); }}>
                    编辑
                  </Button>
                )}
              </View>
            </View>
          );
        })}

        {!loading && list.length === 0 && (
          <View className="empty">还没有评价，去课程详情评价吧～</View>
        )}
        {loading && <View className="loading">加载中…</View>}
        {!loading && list.length >= total && list.length > 0 && (
          <View className="loading">— 没有更多了 —</View>
        )}
      </View>

      {editing && (
        <View className="mask" onClick={closeEdit}>
          <View className="edit-sheet" onClick={(e) => e.stopPropagation()}>
            <View className="sheet-title">编辑评价</View>
            <View className="star-picker">
              {[1, 2, 3, 4, 5].map((n) => (
                <Text
                  key={n}
                  className={`pick-star ${n <= editRating ? "on" : ""}`}
                  onClick={() => setEditRating(n)}
                >
                  ★
                </Text>
              ))}
            </View>
            <Textarea
              className="edit-textarea"
              value={editContent}
              maxlength={500}
              placeholder="说说这门课怎么样…"
              onInput={(e) => setEditContent(e.detail.value)}
            />
            <View className="sheet-btns">
              <Button className="btn-cancel" size="mini" onClick={closeEdit}>取消</Button>
              <Button className="btn-save" size="mini" loading={saving} onClick={submitEdit}>提交</Button>
            </View>
          </View>
        </View>
      )}
    </View>
  );
}

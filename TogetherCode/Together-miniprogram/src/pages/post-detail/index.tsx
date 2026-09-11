import React, { useEffect, useState } from "react";
import Taro, { useShareAppMessage } from "@tarojs/taro";
import { View, Text, Image, Input, Textarea } from "@tarojs/components";
import { getPostDetail, getPostComments, likePost, unlikePost, postComment, sharePost, type PostItem, type PostComment } from "../../services/post";
import { createDistributionLink } from "../../services/distribution";
import { addFavorite, removeFavorite, getFavoriteIds } from "../../services/interaction";
import { useAuthStore } from "../../store/auth";
import { buildPostSharePath, getDistFromParams, getShareUid } from "../../utils/share";
import "./index.scss";

export default function PostDetailPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  // 外部分享码：他人分享本帖子进入时携带，优先于本人的码透传下单归因
  const distFromShare = getDistFromParams();
  const [post, setPost] = useState<PostItem | null>(null);
  const [comments, setComments] = useState<PostComment[]>([]);
  const [commentText, setCommentText] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [sharing, setSharing] = useState(false);
  const [isFav, setIsFav] = useState(false);
  // 分销分享码：帖子挂了课程时生成，分享卡片带码 → 被分享者下单归因到发帖人
  const [shareCode, setShareCode] = useState("");

  useEffect(() => {
    const id = Taro.getCurrentInstance().router?.params?.id;
    if (id) {
      load(id);
      loadComments(id);
    }
  }, []);

  const load = async (id: string) => {
    try {
      const data = await getPostDetail(id);
      setPost(data);
      prefetchShareCode(data);
      if (isLoggedIn) {
        try {
          const ids = await getFavoriteIds("post");
          setIsFav(ids.includes(data.post_id));
        } catch {
          // 忽略
        }
      }
    } catch {
      // 拦截器已提示
    }
  };

  // 预取分享码：登录用户查看本人/他帖，帖子挂课程则生成分享码（仅本人帖子可生成，后端校验）
  const prefetchShareCode = async (data: PostItem) => {
    if (!getShareUid() || !data.course?.course_id) return;
    try {
      const link = await createDistributionLink({ course_id: data.course.course_id, post_id: data.post_id });
      setShareCode(link.code);
    } catch {
      // 非本人帖子或失败：不生成，分享卡片无归因码（仍可分享）
    }
  };

  // 微信分享卡片：转发按钮/右上角菜单触发
  useShareAppMessage(() => {
    return {
      title: post?.content?.slice(0, 30) || "艺启 · 看看这个帖子",
      path: buildPostSharePath(post?.post_id || "", shareCode),
      imageUrl: post?.images?.[0] || post?.course?.cover || ""
    };
  });

  const loadComments = async (id: string) => {
    try {
      const data = await getPostComments(id);
      setComments(data);
    } catch {
      // 忽略
    }
  };

  const toggleFav = async () => {
    if (!post || !isLoggedIn) {
      Taro.showToast({ title: "请先登录", icon: "none" });
      return;
    }
    try {
      if (isFav) {
        await removeFavorite("post", post.post_id);
        setIsFav(false);
        Taro.showToast({ title: "已取消收藏", icon: "none" });
      } else {
        await addFavorite("post", post.post_id);
        setIsFav(true);
        Taro.showToast({ title: "已收藏", icon: "success" });
      }
    } catch {
      // 拦截器已提示
    }
  };

  const toggleLike = async () => {
    if (!post || !isLoggedIn) {
      Taro.navigateTo({ url: "/pages/login/index" });
      return;
    }
    const next = !post.is_liked;
    setPost({ ...post, is_liked: next, like_count: post.like_count + (next ? 1 : -1) });
    try {
      if (next) await likePost(post.post_id);
      else await unlikePost(post.post_id);
    } catch {
      // 回滚
      setPost((p) => (p ? { ...p, is_liked: !next, like_count: p.like_count + (next ? -1 : 1) } : p));
    }
  };

  const submitComment = async () => {
    if (!post || !commentText.trim()) return;
    if (!isLoggedIn) {
      Taro.navigateTo({ url: "/pages/login/index" });
      return;
    }
    setSubmitting(true);
    try {
      await postComment(post.post_id, commentText.trim());
      setCommentText("");
      setPost((p) => (p ? { ...p, comment_count: p.comment_count + 1 } : p));
      loadComments(post.post_id);
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  const onShare = async () => {
    if (!post || sharing) return;
    if (!isLoggedIn) {
      Taro.navigateTo({ url: "/pages/login/index" });
      return;
    }
    setSharing(true);
    try {
      // 1) 记录分享次数；2) 帖子挂课程时确保分享码已生成（含返利归因）
      await sharePost(post.post_id);
      setPost((p) => (p ? { ...p, share_count: p.share_count + 1 } : p));
      if (post.course?.course_id) {
        try {
          const link = await createDistributionLink({ course_id: post.course.course_id, post_id: post.post_id });
          setShareCode(link.code);
        } catch {
          // 非本人帖子：仅计数，无归因码
        }
      }
      Taro.showToast({ title: "分享成功", icon: "success" });
    } catch {
      // 拦截器已提示
    } finally {
      setSharing(false);
    }
  };

  const goCourse = () => {
    if (!post?.course?.course_id) return;
    // 帖子挂了课程：点击课程卡跳课程详情时带上分销码（被分享者报名 → 返利给发帖人）
    // 优先透传外部分享码（他人分享进入），其次本人预取码
    const dist = distFromShare || shareCode;
    const base = `/pages/course-detail/index?id=${post.course.course_id}`;
    Taro.navigateTo({ url: dist ? `${base}&dist=${dist}` : base });
  };

  // 作者为老师时，点击头像/名字进入老师主页
  const goAuthor = () => {
    if (!post?.author?.user_id) return;
    if (Number(post.author.role) === 2) {
      Taro.navigateTo({ url: `/pages/teacher-homepage/index?id=${post.author.user_id}` });
    }
  };

  if (!post) {
    return <View className="empty-tip">加载中...</View>;
  }

  return (
    <View className="post-detail">
      <View className="card post-card">
        <View className={`post-author ${Number(post.author?.role) === 2 ? "clickable" : ""}`} onClick={goAuthor}>
          <Image className="author-avatar" src={post.author?.avatar || ""} mode="aspectFill" />
          <View className="author-info">
            <View className="author-name">
              {post.author?.nickname || "用户"}
              {post.author_role_text && <Text className="role-tag">{post.author_role_text}</Text>}
            </View>
            <View className="post-time">{String(post.created_at || "").slice(0, 16)}</View>
          </View>
          {Number(post.author?.role) === 2 && <Text className="author-arrow">›</Text>}
        </View>

        {post.content && <View className="post-content">{post.content}</View>}

        {post.images && post.images.length > 0 && (
          <View className="post-images">
            {post.images.map((img, i) => (
              <Image key={i} className={`post-image ${post.images!.length === 1 ? "single" : ""}`} src={img} mode="aspectFill" />
            ))}
          </View>
        )}

        {post.course && (
          <View className="course-link" onClick={goCourse}>
            <Image className="course-cover" src={post.course.cover || ""} mode="aspectFill" />
            <View className="course-body">
              <View className="course-title">{post.course.title}</View>
              {post.course.studio_name && <View className="course-studio">{post.course.studio_name}</View>}
            </View>
            <View className="course-arrow">去报名 ›</View>
          </View>
        )}

        <View className="post-stats">
          <View className={`stat ${isFav ? "fav" : ""}`} onClick={toggleFav}>
            {isFav ? "♥" : "♡"} 收藏
          </View>
          <View className={`stat ${post.is_liked ? "liked" : ""}`} onClick={toggleLike}>
            {post.is_liked ? "♥" : "♡"} {post.like_count}
          </View>
          <View className="stat">评论 {post.comment_count}</View>
          <View className="stat" onClick={onShare}>{sharing ? "分享中" : `分享 ${post.share_count}`}</View>
          <View
            className="stat poster-stat"
            onClick={() =>
              Taro.navigateTo({
                url: `/pages/poster/index?type=post&id=${post.post_id}&code=${distFromShare || shareCode}`
              })
            }
          >
            海报
          </View>
        </View>
      </View>

      <View className="comment-head">
        <Text>评论 {post.comment_count}</Text>
      </View>
      {comments.length === 0 ? (
        <View className="empty-tip comment-empty">还没有评论</View>
      ) : (
        comments.map((c) => (
          <View key={c.comment_id} className="card comment-item">
            <View className="comment-author">{c.author?.nickname || "用户"}</View>
            <View className="comment-content">{c.content}</View>
            <View className="comment-time">{String(c.created_at || "").slice(0, 16)}</View>
          </View>
        ))
      )}

      <View className="comment-bar">
        <Input
          className="comment-input"
          placeholder="友善评论一下..."
          value={commentText}
          onInput={(e) => setCommentText(e.detail.value)}
          confirmType="send"
          onConfirm={submitComment}
        />
        <View className={`btn-primary comment-send ${submitting ? "disabled" : ""}`} onClick={submitComment}>
          发送
        </View>
      </View>
    </View>
  );
}

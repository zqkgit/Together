import React, { useEffect, useState } from "react";
import Taro, { useShareAppMessage } from "@tarojs/taro";
import { View, Text, Image, Input, Textarea } from "@tarojs/components";
import {
  getPostDetail, getPostComments, likePost, unlikePost,
  postComment, sharePost, deletePost,
  likeComment, unlikeComment, deleteComment, replyComment,
  type PostItem, type PostComment
} from "../../../services/post";
import { addFavorite, removeFavorite, getFavoriteIds, followUser, unfollowUser } from "../../../services/interaction";
import { createDistributionLink } from "../../../services/distribution";
import { useAuthStore } from "../../../store/auth";
import { buildPostSharePath, getDistFromParams, getShareUid } from "../../../utils/share";
import "./index.scss";

/** 评论行（组织后的展示结构，对齐 iOS CommentRow） */
interface CommentRow {
  comment: PostComment;
  level: number;       // 0=根评论, 1=一级回复, 2=二级回复
  replyToName?: string; // level=2 时显示"回复 @xxx："
}

/** 将扁平评论列表组织为树形展示行（封顶两级，对齐 iOS） */
function buildCommentRows(comments: PostComment[]): CommentRow[] {
  const byParent: Record<string, PostComment[]> = {};
  comments.forEach((c) => {
    const pid = c.parent_id || "0";
    if (!byParent[pid]) byParent[pid] = [];
    byParent[pid].push(c);
  });

  const sortByTime = (a: PostComment, b: PostComment) =>
    (a.created_at || "").localeCompare(b.created_at || "");

  const rows: CommentRow[] = [];
  const roots = (byParent["0"] || []).sort(sortByTime);
  for (const root of roots) {
    rows.push({ comment: root, level: 0 });
    const firstLevel = (byParent[root.comment_id] || []).sort(sortByTime);
    for (const first of firstLevel) {
      rows.push({ comment: first, level: 1 });
      // first 的所有子孙（任意深度）→ 一律 level 2
      const queue = [...(byParent[first.comment_id] || []).sort(sortByTime)];
      const visited = new Set<string>();
      while (queue.length > 0) {
        const node = queue.shift()!;
        if (visited.has(node.comment_id)) continue;
        visited.add(node.comment_id);
        const parent = comments.find((c) => c.comment_id === node.parent_id);
        rows.push({ comment: node, level: 2, replyToName: parent?.author?.nickname });
        queue.push(...(byParent[node.comment_id] || []).sort(sortByTime));
      }
    }
  }
  return rows;
}

function formatTime(dateStr: string): string {
  if (!dateStr) return "";
  const d = new Date(dateStr);
  const now = new Date();
  const diff = now.getTime() - d.getTime();
  const min = Math.floor(diff / 60000);
  if (min < 1) return "刚刚";
  if (min < 60) return `${min}分钟前`;
  const hour = Math.floor(min / 60);
  if (hour < 24) return `${hour}小时前`;
  const day = Math.floor(hour / 24);
  if (day < 30) return `${day}天前`;
  return `${d.getMonth() + 1}月${d.getDate()}日`;
}

export default function PostDetailPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const user = useAuthStore((s) => s.user);
  const distFromShare = getDistFromParams();

  const [post, setPost] = useState<PostItem | null>(null);
  const [comments, setComments] = useState<PostComment[]>([]);
  const [commentRows, setCommentRows] = useState<CommentRow[]>([]);
  const [commentText, setCommentText] = useState("");
  const [replyTo, setReplyTo] = useState<CommentRow | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [isFav, setIsFav] = useState(false);
  const [isFollowing, setIsFollowing] = useState(false);
  const [shareCode, setShareCode] = useState("");
  const [previewIndex, setPreviewIndex] = useState(-1);

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
      setIsFollowing(!!data.is_following);
      prefetchShareCode(data);
      if (isLoggedIn) {
        try {
          const ids = await getFavoriteIds("post");
          setIsFav(ids.includes(data.post_id));
        } catch { /* ignore */ }
      }
    } catch { /* interceptor handles */ }
  };

  const prefetchShareCode = async (data: PostItem) => {
    if (!getShareUid() || !data.course?.course_id) return;
    try {
      const link = await createDistributionLink({ course_id: data.course.course_id, post_id: data.post_id });
      setShareCode(link.code);
    } catch { /* non-own post */ }
  };

  useShareAppMessage(() => ({
    title: post?.content?.slice(0, 30) || "艺启 · 看看这个帖子",
    path: buildPostSharePath(post?.post_id || "", shareCode),
    imageUrl: post?.images?.[0] || post?.course?.cover || ""
  }));

  const loadComments = async (id: string) => {
    try {
      const data = await getPostComments(id);
      setComments(data);
      setCommentRows(buildCommentRows(data));
    } catch { /* ignore */ }
  };

  // ── 交互 ──

  const toggleLike = async () => {
    if (!post || !isLoggedIn) { Taro.navigateTo({ url: "/pages/login/index" }); return; }
    const next = !post.is_liked;
    setPost({ ...post, is_liked: next, like_count: Math.max(0, post.like_count + (next ? 1 : -1)) });
    try { next ? await likePost(post.post_id) : await unlikePost(post.post_id); }
    catch { setPost((p) => p ? { ...p, is_liked: !next, like_count: Math.max(0, p.like_count + (next ? -1 : 1)) } : p); }
  };

  const toggleFav = async () => {
    if (!post || !isLoggedIn) { Taro.showToast({ title: "请先登录", icon: "none" }); return; }
    try {
      if (isFav) { await removeFavorite("post", post.post_id); setIsFav(false); Taro.showToast({ title: "已取消收藏", icon: "none" }); }
      else { await addFavorite("post", post.post_id); setIsFav(true); Taro.showToast({ title: "已收藏", icon: "success" }); }
    } catch { /* interceptor handles */ }
  };

  const toggleFollow = async () => {
    if (!post?.author?.user_id || !isLoggedIn) return;
    const next = !isFollowing;
    try {
      next ? await followUser(post.author.user_id) : await unfollowUser(post.author.user_id);
      setIsFollowing(next);
      Taro.showToast({ title: next ? "已关注" : "已取消关注", icon: "none" });
    } catch { /* interceptor handles */ }
  };

  const startReply = (row: CommentRow) => {
    setReplyTo(row);
    setCommentText("");
  };

  const cancelReply = () => {
    setReplyTo(null);
    setCommentText("");
  };

  const submitComment = async () => {
    if (!post || !commentText.trim() || !isLoggedIn) return;
    setSubmitting(true);
    try {
      // 层级规则：回复根评论(0)→一级；一级回复(1)→二级；二级回复(2)→挂到其父级
      let parentId: string | undefined;
      if (replyTo) {
        if (replyTo.level === 2) {
          parentId = replyTo.comment.parent_id || replyTo.comment.comment_id;
        } else {
          parentId = replyTo.comment.comment_id;
        }
      }
      const newComment = await replyComment(post.post_id, commentText.trim(), parentId);
      setComments((prev) => [newComment, ...prev]);
      setCommentRows(buildCommentRows([newComment, ...comments]));
      setPost((p) => p ? { ...p, comment_count: p.comment_count + 1 } : p);
      setCommentText("");
      setReplyTo(null);
      Taro.showToast({ title: "评论成功", icon: "success" });
    } catch { /* interceptor handles */ }
    finally { setSubmitting(false); }
  };

  const toggleCommentLike = async (row: CommentRow, index: number) => {
    if (!post || !isLoggedIn) return;
    const c = row.comment;
    const next = !(c.is_liked || false);
    // 乐观更新
    const updated = { ...c, is_liked: next, like_count: Math.max(0, (c.like_count || 0) + (next ? 1 : -1)) };
    const newComments = [...comments];
    const idx = newComments.findIndex((x) => x.comment_id === c.comment_id);
    if (idx >= 0) newComments[idx] = updated;
    setComments(newComments);
    setCommentRows(buildCommentRows(newComments));
    try { next ? await likeComment(post.post_id, c.comment_id) : await unlikeComment(post.post_id, c.comment_id); }
    catch { /* rollback */ loadComments(post.post_id); }
  };

  const onDeleteComment = async (commentId: string) => {
    const res = await Taro.showModal({ title: "删除评论", content: "确定删除这条评论吗？" });
    if (!res.confirm || !post) return;
    try {
      await deleteComment(commentId);
      const newComments = comments.filter((c) => c.comment_id !== commentId);
      setComments(newComments);
      setCommentRows(buildCommentRows(newComments));
      setPost((p) => p ? { ...p, comment_count: Math.max(0, p.comment_count - 1) } : p);
    } catch { /* interceptor handles */ }
  };

  const onDeletePost = async () => {
    if (!post) return;
    const res = await Taro.showModal({ title: "删除作品", content: "删除后不可恢复，确定删除吗？" });
    if (!res.confirm) return;
    try {
      await deletePost(post.post_id);
      Taro.showToast({ title: "删除成功", icon: "success" });
      setTimeout(() => Taro.navigateBack(), 800);
    } catch { /* interceptor handles */ }
  };

  /** 右上角更多菜单（对齐 iOS ellipsis → ActionSheet） */
  const handleMore = async () => {
    const res = await Taro.showActionSheet({ itemList: ["删除作品"] });
    if (res.tapIndex === 0) {
      onDeletePost();
    }
  };

  const goCourse = () => {
    if (!post?.course?.course_id) return;
    const dist = distFromShare || shareCode;
    const base = `/packageCourses/pages/course-detail/index?id=${post.course.course_id}`;
    Taro.navigateTo({ url: dist ? `${base}&dist=${dist}` : base });
  };

  const goAuthor = () => {
    if (!post?.author?.user_id) return;
    if (Number(post.author.role) === 2) {
      Taro.navigateTo({ url: `/packageSocial/pages/teacher-homepage/index?id=${post.author.user_id}` });
    }
  };

  const previewImage = (index: number) => {
    if (!post?.images?.length) return;
    Taro.previewImage({ urls: post.images, current: post.images[index] });
  };

  if (!post) return <View className="empty-tip">加载中...</View>;

  const isOwnPost = post.is_mine || user?.user_id === post.author?.user_id;

  return (
    <View className="post-detail">
      {/* 自己的帖子：右上角更多按钮（对齐 iOS 导航栏 ellipsis） */}
      {isOwnPost && (
        <View className="more-float-btn" onClick={handleMore}>⋯</View>
      )}

      {/* 图片画廊 */}
      {post.images && post.images.length > 0 && (
        <View className="gallery">
          {post.images.map((img, i) => (
            <Image
              key={i}
              className="gallery-img"
              src={img}
              mode="aspectFill"
              onClick={() => previewImage(i)}
            />
          ))}
        </View>
      )}

      {/* 作者行 */}
      <View className={`author-row ${Number(post.author?.role) === 2 ? "clickable" : ""}`} onClick={goAuthor}>
        <Image className="author-avatar" src={post.author?.avatar || ""} mode="aspectFill" />
        <View className="author-info">
          <View className="author-name">
            {post.author?.nickname || "用户"}
            {post.author_role_text && <Text className="role-tag">{post.author_role_text}</Text>}
          </View>
          <Text className="author-time">{formatTime(post.created_at)}</Text>
        </View>
        {!isOwnPost && Number(post.author?.role) === 2 && (
          <View
            className={`follow-btn ${isFollowing ? "following" : ""}`}
            onClick={(e) => { e.stopPropagation(); toggleFollow(); }}
          >
            {isFollowing ? "已关注" : "关注"}
          </View>
        )}
      </View>

      {/* 正文 */}
      {post.content && <View className="post-content">{post.content}</View>}

      {/* 关联课程卡（对齐 iOS PostCourseCell：标题+价格+去报名按钮） */}
      {post.course && post.course.title && (
        <View className="course-card" onClick={goCourse}>
          <View className="course-info">
            <Text className="course-title">{post.course.title}</Text>
            <Text className="course-price">
              {post.course.price && post.course.price > 0
                ? `¥${(post.course.price / 100).toFixed(2)} 元`
                : "价格咨询"}
            </Text>
          </View>
          <View className="course-enroll-btn">去报名</View>
        </View>
      )}

      {/* 学员列表（对齐 iOS PostStudentCell：卡片+已关联学生标题+行） */}
      {post.students && post.students.length > 0 && (
        <View className="students-card">
          <Text className="students-title">已关联学生</Text>
          {post.students.map((s) => (
            <View key={s.child_id} className="student-row">
              <Image className="student-avatar" src={s.avatar || ""} mode="aspectFill" />
              <Text className="student-name">{s.nickname || "宝宝"}</Text>
              <Text className={`student-status ${s.deducted ? "consumed" : ""}`}>
                {s.deducted ? "已消课" : "未消课"}
              </Text>
            </View>
          ))}
        </View>
      )}

      {/* 位置 */}
      {post.location && (
        <View className="location-row">
          <Text className="location-icon">📍</Text>
          <Text className="location-name">{post.location.name}</Text>
          {post.distance_text && <Text className="location-dist">{post.distance_text}</Text>}
        </View>
      )}

      {/* 评论区 */}
      <View className="comment-section">
        <View className="comment-header">
          <Text className="comment-title">评论({post.comment_count})</Text>
        </View>

        {commentRows.length === 0 ? (
          <View className="comment-empty">还没有评论</View>
        ) : (
          commentRows.map((row, i) => {
            const isOwn = user?.user_id === row.comment.author?.user_id;
            return (
              <View key={row.comment.comment_id} className={`comment-item level-${row.level}`}>
                <Image className="comment-avatar" src={row.comment.author?.avatar || ""} mode="aspectFill" />
                <View className="comment-body">
                  <View className="comment-top">
                    <Text className="comment-name">{row.comment.author?.nickname || "用户"}</Text>
                    <Text className="comment-time">{formatTime(row.comment.created_at)}</Text>
                  </View>
                  <Text className="comment-text">
                    {row.level === 2 && row.replyToName ? `回复 @${row.replyToName}：` : ""}{row.comment.content}
                  </Text>
                  <View className="comment-actions">
                    <View className="comment-action" onClick={() => toggleCommentLike(row, i)}>
                      <Text className={row.comment.is_liked ? "liked" : ""}>
                        {row.comment.is_liked ? "♥" : "♡"} {row.comment.like_count || 0}
                      </Text>
                    </View>
                    {!isOwn && (
                      <View className="comment-action" onClick={() => startReply(row)}>
                        回复
                      </View>
                    )}
                    {isOwn && (
                      <View className="comment-action delete" onClick={() => onDeleteComment(row.comment.comment_id)}>
                        删除
                      </View>
                    )}
                  </View>
                </View>
              </View>
            );
          })
        )}
      </View>

      {/* 底部操作栏（对齐 iOS PostBottomBar） */}
      <View className="bottom-bar">
        <View className="input-capsule" onClick={() => setReplyTo(null)}>
          <Text className="input-placeholder">
            {replyTo ? `回复 @${replyTo.comment.author?.nickname}` : "说点什么..."}
          </Text>
        </View>
        <View className={`bar-btn ${post.is_liked ? "liked" : ""}`} onClick={toggleLike}>
          <Text>{post.is_liked ? "♥" : "♡"}</Text>
          <Text className="bar-count">{post.like_count}</Text>
        </View>
        <View className={`bar-btn ${isFav ? "fav" : ""}`} onClick={toggleFav}>
          <Text>{isFav ? "★" : "☆"}</Text>
        </View>
      </View>

      {/* 评论输入弹层 */}
      {(replyTo || commentText) && (
        <View className="comment-input-overlay">
          <View className="comment-input-bar">
            {replyTo && (
              <View className="reply-hint">
                <Text>回复 @{replyTo.comment.author?.nickname}</Text>
                <Text className="reply-cancel" onClick={cancelReply}>取消</Text>
              </View>
            )}
            <View className="input-row">
              <Input
                className="comment-input"
                placeholder="友善评论一下..."
                value={commentText}
                onInput={(e) => setCommentText(e.detail.value)}
                confirmType="send"
                onConfirm={submitComment}
                focus={!!replyTo}
              />
              <View className={`btn-primary comment-send ${submitting ? "disabled" : ""}`} onClick={submitComment}>
                发送
              </View>
            </View>
          </View>
        </View>
      )}
    </View>
  );
}
const { Op } = require("sequelize");
const { sequelize, Post, PostLike, PostComment, User, Child, Course } = require("../models");
const { generateId } = require("../utils/id");
const { createNotification } = require("./messageService");

const AUTHOR_ROLE_TEXT = {
  1: "家长",
  2: "老师",
  3: "工作室"
};

function normalizeAuthor(author) {
  if (!author) return null;
  return {
    user_id: String(author.user_id),
    nickname: author.nickname || "艺启用户",
    avatar: author.avatar || null,
    role: author.current_role !== undefined ? Number(author.current_role) : null
  };
}

function normalizePostItem(post, viewerUserId = null) {
  const item = {
    post_id: String(post.post_id),
    author: normalizeAuthor(post.author),
    author_role: post.author_role,
    author_role_text: AUTHOR_ROLE_TEXT[post.author_role] || "用户",
    type: post.type,
    child_id: post.child_id ? String(post.child_id) : null,
    child: post.child
      ? {
          child_id: String(post.child.child_id),
          nickname: post.child.nickname,
          avatar: post.child.avatar || null
        }
      : null,
    course_id: post.course_id ? String(post.course_id) : null,
    course: post.course
      ? {
          course_id: String(post.course.course_id),
          title: post.course.title,
          studio_id: post.course.studio_id ? String(post.course.studio_id) : null
        }
      : null,
    content: post.content,
    images: post.images || [],
    visibility: post.visibility,
    status: post.status,
    like_count: Number(post.like_count || 0),
    comment_count: Number(post.comment_count || 0),
    share_count: Number(post.share_count || 0),
    created_at: post.created_at
  };

  if (viewerUserId && post.liked_by_viewer !== undefined) {
    item.is_liked = !!post.liked_by_viewer;
  } else if (viewerUserId && post.likes) {
    item.is_liked = post.likes.some((like) => String(like.user_id) === String(viewerUserId));
  }

  return item;
}

function postInclude(viewerUserId = null) {
  return [
    {
      model: User,
      as: "author",
      attributes: ["user_id", "nickname", "avatar", "current_role"]
    },
    {
      model: Child,
      as: "child",
      attributes: ["child_id", "nickname", "avatar"]
    },
    {
      model: Course,
      as: "course",
      attributes: ["course_id", "title", "studio_id"]
    },
    ...(viewerUserId
      ? [
          {
            model: PostLike,
            as: "likes",
            where: { user_id: viewerUserId },
            required: false
          }
        ]
      : [])
  ];
}

const PUBLIC_WHERE = { status: 1, visibility: 2 };

/**
 * 帖子详情（公开帖子或本人帖子）
 */
async function getPostDetail(postId, viewerUserId = null) {
  const post = await Post.findOne({
    where: { post_id: postId },
    include: postInclude(viewerUserId)
  });

  if (!post) {
    return null;
  }

  // 非公开帖：仅作者本人可见
  if (Number(post.visibility) !== 2 && String(post.author_id) !== String(viewerUserId)) {
    return null;
  }

  return normalizePostItem(post, viewerUserId);
}

/**
 * 点赞（幂等）：已赞直接返回，未赞新增并计数 +1
 */
async function likePost(userId, postId) {
  return sequelize.transaction(async (transaction) => {
    const post = await Post.findByPk(postId, {
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!post || Number(post.status) !== 1) {
      return null;
    }

    const existing = await PostLike.findOne({
      where: { post_id: postId, user_id: userId },
      transaction
    });

    if (existing) {
      return { post_id: String(postId), liked: true };
    }

    await PostLike.create(
      {
        like_id: generateId(),
        post_id: postId,
        user_id: userId
      },
      { transaction }
    );

    await post.update({ like_count: Number(post.like_count || 0) + 1 }, { transaction });

    // 通知作者（自己给自己点赞不通知）
    if (String(post.author_id) !== String(userId)) {
      createNotification({
        userId: post.author_id,
        type: "like",
        title: "收到新的赞",
        content: "有人赞了你的动态",
        refType: "post",
        refId: postId
      }).catch(() => {});
    }

    return { post_id: String(postId), liked: true };
  });
}

/**
 * 取消赞（幂等）：已取消直接返回，未取消则删除并计数 -1
 */
async function unlikePost(userId, postId) {
  return sequelize.transaction(async (transaction) => {
    const post = await Post.findByPk(postId, {
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!post) {
      return null;
    }

    const existing = await PostLike.findOne({
      where: { post_id: postId, user_id: userId },
      transaction
    });

    if (!existing) {
      return { post_id: String(postId), liked: false };
    }

    await existing.destroy({ transaction });
    await post.update(
      { like_count: Math.max(0, Number(post.like_count || 0) - 1) },
      { transaction }
    );

    return { post_id: String(postId), liked: false };
  });
}

function normalizeComment(row) {
  return {
    comment_id: String(row.comment_id),
    post_id: String(row.post_id),
    user: row.user
      ? {
          user_id: String(row.user.user_id),
          nickname: row.user.nickname || "艺启用户",
          avatar: row.user.avatar || null
        }
      : null,
    content: row.content,
    created_at: row.created_at
  };
}

/**
 * 评论列表（分页，仅正常评论）
 */
async function listPostComments(postId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.size) || 20, 50);

  const { rows, count } = await PostComment.findAndCountAll({
    where: { post_id: postId, status: 1 },
    include: [
      {
        model: User,
        as: "user",
        attributes: ["user_id", "nickname", "avatar"]
      }
    ],
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  return {
    total: count,
    page,
    size,
    list: rows.map(normalizeComment)
  };
}

/**
 * 发布评论
 */
async function addPostComment(userId, postId, content) {
  return sequelize.transaction(async (transaction) => {
    const post = await Post.findByPk(postId, {
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!post || Number(post.status) !== 1) {
      return null;
    }

    const comment = await PostComment.create(
      {
        comment_id: generateId(),
        post_id: postId,
        user_id: userId,
        content,
        status: 1
      },
      { transaction }
    );

    await post.update({ comment_count: Number(post.comment_count || 0) + 1 }, { transaction });

    // 通知作者（评论自己的帖子不通知）
    if (String(post.author_id) !== String(userId)) {
      createNotification({
        userId: post.author_id,
        type: "comment",
        title: "收到新的评论",
        content: `评论：${String(content).slice(0, 50)}`,
        refType: "post",
        refId: postId
      }).catch(() => {});
    }

    const row = await PostComment.findByPk(comment.comment_id, {
      transaction,
      include: [
        {
          model: User,
          as: "user",
          attributes: ["user_id", "nickname", "avatar"]
        }
      ]
    });

    return normalizeComment(row);
  });
}

/**
 * 分享帖子（分享到小程序）：计数 +1，返回分享路径
 */
async function sharePost(postId) {
  return sequelize.transaction(async (transaction) => {
    const post = await Post.findByPk(postId, {
      transaction,
      lock: transaction.LOCK.UPDATE
    });
    if (!post || Number(post.status) !== 1) {
      return { error: { status: 404, code: 40460, message: "帖子不存在或已下架" } };
    }
    await post.update({ share_count: Number(post.share_count || 0) + 1 }, { transaction });
    return {
      data: {
        post_id: String(postId),
        share_count: Number(post.share_count || 0) + 1,
        share_path: `/pages/post-detail?id=${postId}`
      }
    };
  });
}

/**
 * 删除自己的评论（软删，计数 -1）
 */
async function deletePostComment(userId, commentId) {
  return sequelize.transaction(async (transaction) => {
    const comment = await PostComment.findOne({
      where: { comment_id: commentId, user_id: userId, status: 1 },
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!comment) {
      return null;
    }

    await comment.update({ status: 0 }, { transaction });

    const post = await Post.findByPk(comment.post_id, {
      transaction,
      lock: transaction.LOCK.UPDATE
    });
    if (post) {
      await post.update(
        { comment_count: Math.max(0, Number(post.comment_count || 0) - 1) },
        { transaction }
      );
    }

    return { comment_id: String(commentId), deleted: true };
  });
}

/**
 * 信息流：公开帖子（后续接入关注关系后按关注过滤）
 */
async function listFeed(viewerUserId = null, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.size) || 20, 50);

  const { rows, count } = await Post.findAndCountAll({
    where: PUBLIC_WHERE,
    include: postInclude(viewerUserId),
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  return {
    total: count,
    page,
    size,
    list: rows.map((row) => normalizePostItem(row, viewerUserId))
  };
}

/**
 * 广场：公开帖子，支持 latest / hot 排序
 */
async function listPlaza(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.size) || 20, 50);
  const sort = query.sort === "hot" ? "hot" : "latest";

  const order =
    sort === "hot"
      ? [
          ["like_count", "DESC"],
          ["comment_count", "DESC"],
          ["created_at", "DESC"]
        ]
      : [["created_at", "DESC"]];

  const { rows, count } = await Post.findAndCountAll({
    where: PUBLIC_WHERE,
    include: postInclude(),
    order,
    offset: (page - 1) * size,
    limit: size
  });

  return {
    total: count,
    page,
    size,
    sort,
    list: rows.map((row) => normalizePostItem(row))
  };
}

/**
 * 家长发帖（author_role=1，不关联学员消课）
 * type: 1 图文动态 / 2 作品分享
 */
async function createParentPost(userId, payload) {
  const content = String(payload.content || "").trim();
  const images = Array.isArray(payload.images) ? payload.images.slice(0, 9) : [];

  if (!content && !images.length) {
    return { error: { status: 400, code: 40060, message: "内容或图片至少填一项" } };
  }

  const type = [1, 2].includes(Number(payload.type)) ? Number(payload.type) : 1;

  const created = await Post.create({
    post_id: generateId(),
    author_id: userId,
    author_role: 1,
    type,
    child_id: payload.child_id || null,
    course_id: payload.course_id || null,
    images,
    content: content || null,
    visibility: payload.visibility !== undefined ? Number(payload.visibility) : 2,
    status: 1
  });

  const post = await Post.findByPk(created.post_id, {
    include: [
      {
        model: User,
        as: "author",
        attributes: ["user_id", "nickname", "avatar", "current_role"]
      },
      {
        model: Child,
        as: "child",
        attributes: ["child_id", "nickname", "avatar"]
      }
    ]
  });

  return { data: normalizePostItem(post) };
}

module.exports = {
  getPostDetail,
  likePost,
  unlikePost,
  listPostComments,
  addPostComment,
  deletePostComment,
  sharePost,
  listFeed,
  listPlaza,
  createParentPost
};

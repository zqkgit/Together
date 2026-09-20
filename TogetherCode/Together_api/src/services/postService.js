const { Op } = require("sequelize");
const { sequelize, Post, PostLike, PostComment, PostCommentLike, User, Child, Course, Favorite, PostStudent, LessonLog, ChildCourseBalance, Order } = require("../models");
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

/**
 * 从发帖 payload 提取选填位置（经纬度 + 地点名）。
 * 经纬度范围非法或缺失时整体忽略，不报错，保证选填语义。
 */
function pickLocation(payload) {
  const lat = Number(payload.latitude);
  const lng = Number(payload.longitude);
  const valid =
    Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180;
  if (!valid) {
    return { latitude: null, longitude: null, location_name: null };
  }
  const name = String(payload.location_name || "").trim().slice(0, 128) || null;
  return { latitude: lat, longitude: lng, location_name: name };
}

/**
 * 解析 viewer 经纬度（来自 query.lat / query.lng），用于距离排序与距离回传。
 * 非法坐标返回 null（调用方退化为最新/热门排序）。
 */
function getGeoContext(query) {
  const lat = Number(query.lat);
  const lng = Number(query.lng);
  if (
    Number.isFinite(lat) &&
    Number.isFinite(lng) &&
    lat >= -90 &&
    lat <= 90 &&
    lng >= -180 &&
    lng <= 180
  ) {
    return { lat, lng };
  }
  return null;
}

/** haversine 距离（公里），地球半径 6371km；lat/lng 已校验为有限浮点，可安全内联 */
function haversineDistance(lat, lng) {
  const latN = Number(lat);
  const lngN = Number(lng);
  return sequelize.literal(
    `6371 * ACOS(COS(RADIANS(${latN})) * COS(RADIANS(latitude)) * COS(RADIANS(longitude) - RADIANS(${lngN})) + SIN(RADIANS(${latN})) * SIN(RADIANS(latitude)))`
  );
}

function normalizePostItem(post, viewerUserId = null, favoritePostIds = null) {
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
    class_id: post.class_id ? String(post.class_id) : null,
    course: post.course
      ? {
          course_id: String(post.course.course_id),
          title: post.course.title,
          studio_id: post.course.studio_id ? String(post.course.studio_id) : null,
          price: post.course.price !== undefined && post.course.price !== null ? Number(post.course.price) : null
        }
      : null,
    content: post.content,
    images: post.images || [],
    topic: post.topic || null,
    visibility: post.visibility,
    status: post.status,
    // 选填位置；无坐标时为 null
    location:
      post.latitude !== null && post.latitude !== undefined && post.longitude !== null && post.longitude !== undefined
        ? {
            latitude: Number(post.latitude),
            longitude: Number(post.longitude),
            name: post.location_name || null
          }
        : null,
    // 仅当请求携带 viewer 经纬度（haversine 计算）时存在；无坐标帖为 null
    distance_km:
      post.dataValues && post.dataValues.distance_km !== undefined
        ? post.dataValues.distance_km === null || post.dataValues.distance_km === undefined
          ? null
          : Number(post.dataValues.distance_km)
        : undefined,
    students: Array.isArray(post.students)
      ? post.students.map((s) => ({
          child_id: String(s.child_id),
          nickname: s.child?.nickname || null,
          avatar: s.child?.avatar || null,
          deducted: !!s.deducted
        }))
      : [],
    like_count: Number(post.like_count || 0),
    comment_count: Number(post.comment_count || 0),
    share_count: Number(post.share_count || 0),
    created_at: post.created_at
  };

  // 当前查看者是否作者本人（编辑/删除入口判断，避免依赖客户端本地 userId）
  if (viewerUserId) {
    item.is_mine = String(post.author_id) === String(viewerUserId);
  }

  if (viewerUserId && post.liked_by_viewer !== undefined) {
    item.is_liked = !!post.liked_by_viewer;
  } else if (viewerUserId && post.likes) {
    item.is_liked = post.likes.some((like) => String(like.user_id) === String(viewerUserId));
  }

  if (viewerUserId) {
    item.is_favorite = favoritePostIds ? favoritePostIds.has(String(post.post_id)) : false;
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
      attributes: ["course_id", "title", "studio_id", "price"]
    },
    {
      model: PostStudent,
      as: "students",
      required: false,
      include: [
        {
          model: Child,
          as: "child",
          attributes: ["child_id", "nickname", "avatar"]
        }
      ]
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

  // 收藏状态：当前用户是否已收藏该帖
  let favoritePostIds = null;
  if (viewerUserId) {
    const favs = await Favorite.findAll({
      where: { user_id: viewerUserId, target_type: "post" },
      attributes: ["target_id"]
    });
    favoritePostIds = new Set(favs.map((f) => String(f.target_id)));
  }

  const item = normalizePostItem(post, viewerUserId, favoritePostIds);

  // 关注状态：当前用户是否已关注作者
  if (viewerUserId && post.author_id) {
    const { isFollowing } = require("./followService");
    item.is_following = await isFollowing(viewerUserId, post.author_id);
  }

  return item;
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

function normalizeComment(row, likedCommentIds = null) {
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
    parent_id: row.parent_id ? String(row.parent_id) : "0",
    like_count: Number(row.like_count || 0),
    is_liked: likedCommentIds ? likedCommentIds.has(String(row.comment_id)) : false,
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

  // 当前用户点赞过的评论集合
  let likedCommentIds = null;
  const viewerUserId = query.viewerUserId;
  if (viewerUserId && rows.length) {
    const likes = await PostCommentLike.findAll({
      where: {
        user_id: viewerUserId,
        comment_id: { [Op.in]: rows.map((r) => r.comment_id) }
      },
      attributes: ["comment_id"]
    });
    likedCommentIds = new Set(likes.map((l) => String(l.comment_id)));
  }

  return {
    total: count,
    page,
    size,
    list: rows.map((r) => normalizeComment(r, likedCommentIds))
  };
}

/**
 * 发布评论
 */
async function addPostComment(userId, postId, content, parentId = 0) {
  return sequelize.transaction(async (transaction) => {
    const post = await Post.findByPk(postId, {
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!post || Number(post.status) !== 1) {
      return null;
    }

    // 回复场景：被回复的评论必须存在且属于同一帖子
    if (parentId) {
      const parent = await PostComment.findOne({
        where: { comment_id: parentId, post_id: postId, status: 1 },
        transaction
      });
      if (!parent) {
        return null;
      }
      // 不能回复自己的评论
      if (String(parent.user_id) === String(userId)) {
        const err = new Error("不能回复自己的评论");
        err.code = 40063;
        throw err;
      }
    }

    const comment = await PostComment.create(
      {
        comment_id: generateId(),
        post_id: postId,
        user_id: userId,
        content,
        parent_id: parentId,
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
 * 评论点赞（幂等）：已赞直接返回，未赞新增并计数 +1
 */
async function likeComment(userId, commentId) {
  return sequelize.transaction(async (transaction) => {
    const comment = await PostComment.findByPk(commentId, { transaction, lock: transaction.LOCK.UPDATE });
    if (!comment || Number(comment.status) !== 1) {
      return null;
    }
    const existed = await PostCommentLike.findOne({
      where: { comment_id: commentId, user_id: userId },
      transaction
    });
    if (existed) {
      return { liked: true };
    }
    await PostCommentLike.create({ comment_id: commentId, user_id: userId }, { transaction });
    await comment.update({ like_count: Number(comment.like_count || 0) + 1 }, { transaction });
    return { liked: true, like_count: Number(comment.like_count || 0) + 1 };
  });
}

/**
 * 取消评论点赞（幂等）
 */
async function unlikeComment(userId, commentId) {
  return sequelize.transaction(async (transaction) => {
    const comment = await PostComment.findByPk(commentId, { transaction, lock: transaction.LOCK.UPDATE });
    if (!comment) {
      return null;
    }
    const removed = await PostCommentLike.destroy({
      where: { comment_id: commentId, user_id: userId },
      transaction
    });
    if (removed > 0) {
      await comment.update({ like_count: Math.max(0, Number(comment.like_count || 0) - 1) }, { transaction });
    }
    return { liked: false, like_count: Math.max(0, Number(comment.like_count || 0)) };
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

    // 删除后：子回复提升一级（挂到被删评论的父级），避免孤儿评论
    await PostComment.update(
      { parent_id: comment.parent_id },
      { where: { parent_id: commentId, status: 1 }, transaction }
    );

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
  const geo = getGeoContext(query);
  const sort = query.sort === "near" && geo ? "near" : "latest";

  const order =
    sort === "near"
      ? [[sequelize.literal("distance_km"), "ASC"]]
      : [["created_at", "DESC"]];

  const where = { ...PUBLIC_WHERE };
  if (sort === "near") where.latitude = { [Op.ne]: null };

  const findOptions = {
    where,
    include: postInclude(viewerUserId),
    order,
    offset: (page - 1) * size,
    limit: size
  };
  if (geo) {
    findOptions.attributes = { include: [[haversineDistance(geo.lat, geo.lng), "distance_km"]] };
  }

  const { rows, count } = await Post.findAndCountAll(findOptions);

  return {
    total: count,
    page,
    size,
    sort,
    list: rows.map((row) => normalizePostItem(row, viewerUserId))
  };
}

/**
 * 广场：公开帖子，支持 latest / hot 排序
 */
async function listPlaza(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.size) || 20, 50);
  const geo = getGeoContext(query);
  const sort = query.sort === "hot" ? "hot" : query.sort === "near" && geo ? "near" : "latest";
  const topic = String(query.topic || "").trim();

  const order =
    sort === "near"
      ? [[sequelize.literal("distance_km"), "ASC"]]
      : sort === "hot"
      ? [
          ["like_count", "DESC"],
          ["comment_count", "DESC"],
          ["created_at", "DESC"]
        ]
      : [["created_at", "DESC"]];

  const where = { ...PUBLIC_WHERE };
  if (topic) where.topic = topic;
  // 附近模式仅列带位置的帖
  if (sort === "near") where.latitude = { [Op.ne]: null };

  const findOptions = {
    where,
    include: postInclude(),
    order,
    offset: (page - 1) * size,
    limit: size
  };
  if (geo) {
    findOptions.attributes = { include: [[haversineDistance(geo.lat, geo.lng), "distance_km"]] };
  }

  const { rows, count } = await Post.findAndCountAll(findOptions);

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

/**
 * 我的帖子（作品管理）：当前用户发布的全部帖子（含待审核/被隐藏），按时间倒序
 * status: all / public(visibility=2) / private(visibility=1)
 * 返回 counts{all,public,private} 供分类标签计数
 */
async function listMyPosts(userId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.size) || 20, 50);
  const status = String(query.status || "all");

  const where = { author_id: userId };
  if (status === "public") where.visibility = 2;
  else if (status === "private") where.visibility = 1;

  const [count, allCount, publicCount, privateCount] = await Promise.all([
    Post.count({ where }),
    Post.count({ where: { author_id: userId } }),
    Post.count({ where: { author_id: userId, visibility: 2 } }),
    Post.count({ where: { author_id: userId, visibility: 1 } })
  ]);

  const { rows } = await Post.findAndCountAll({
    where,
    include: postInclude(userId),
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  return {
    total: count,
    counts: { all: allCount, public: publicCount, private: privateCount },
    page,
    size,
    list: rows.map((row) => normalizePostItem(row, userId))
  };
}

/**
 * 孩子动态（收藏与动态）：我孩子相关的帖子（家长帖关联我的孩子 + 老师帖关联我的孩子），按时间倒序
 */
async function listChildFeed(userId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.size) || 20, 50);

  const children = await Child.findAll({
    where: { parent_user_id: userId },
    attributes: ["child_id"],
    raw: true
  });
  const childIds = children.map((c) => String(c.child_id));
  if (!childIds.length) {
    return { total: 0, page, size, list: [] };
  }

  // 老师帖：PostStudent 关联我的孩子
  const studentPosts = await PostStudent.findAll({
    where: { child_id: { [Op.in]: childIds } },
    attributes: ["post_id"],
    raw: true
  });
  const studentPostIds = studentPosts.map((s) => String(s.post_id));

  const where = {
    [Op.or]: [
      { child_id: { [Op.in]: childIds } },
      ...(studentPostIds.length ? [{ post_id: { [Op.in]: studentPostIds } }] : [])
    ]
  };

  const { rows, count } = await Post.findAndCountAll({
    where,
    include: postInclude(userId),
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  return {
    total: count,
    page,
    size,
    list: rows.map((row) => normalizePostItem(row, userId))
  };
}

async function createParentPost(userId, payload) {
  const content = String(payload.content || "").trim();
  const images = Array.isArray(payload.images) ? payload.images.slice(0, 9) : [];

  // 作品帖必须至少一张图（平台内容规范）
  if (!images.length) {
    return { error: { status: 400, code: 40060, message: "请至少上传一张作品图片" } };
  }

  const type = payload.course_id
    ? 2 // 关联课程 = 孩子作品
    : ([1, 2].includes(Number(payload.type)) ? Number(payload.type) : 1);
  const topic = String(payload.topic || "").trim().slice(0, 32) || null;

  const created = await Post.create({
    post_id: generateId(),
    author_id: userId,
    author_role: 1,
    type,
    child_id: payload.child_id || null,
    course_id: payload.course_id || null,
    images,
    topic,
    content: content || null,
    visibility: payload.visibility !== undefined ? Number(payload.visibility) : 2,
    status: 1,
    ...pickLocation(payload)
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

/// 家长编辑自己的作品帖：仅作者本人可操作（content/images/topic/visibility/child/course）
async function updatePost(userId, postId, payload) {
  const post = await Post.findByPk(postId);
  if (!post) return null;
  if (String(post.author_id) !== String(userId)) {
    return { error: { status: 403, code: 40003, message: "只能编辑自己的帖子" } };
  }

  const updates = {};
  if (payload.content !== undefined) updates.content = String(payload.content).trim() || null;
  // 编辑时可不传 images：保留原图；传了则必须至少一张
  if (payload.images !== undefined) {
    const images = Array.isArray(payload.images) ? payload.images.slice(0, 9) : [];
    if (!images.length) {
      return { error: { status: 400, code: 40060, message: "请至少上传一张作品图片" } };
    }
    updates.images = images;
  }
  if (payload.topic !== undefined) updates.topic = payload.topic ? String(payload.topic).trim().slice(0, 32) : null;
  if (payload.visibility !== undefined) updates.visibility = Number(payload.visibility);
  if (payload.child_id !== undefined) updates.child_id = payload.child_id || null;
  if (payload.course_id !== undefined) updates.course_id = payload.course_id || null;
  // 位置（选填）：clear_location=true 显式清除；否则仅当传了 location 字段才更新，缺省保留原值
  if (payload.clear_location) {
    updates.latitude = null;
    updates.longitude = null;
    updates.location_name = null;
  } else if (
    payload.latitude !== undefined ||
    payload.longitude !== undefined ||
    payload.location_name !== undefined
  ) {
    const loc = pickLocation(payload);
    updates.latitude = loc.latitude;
    updates.longitude = loc.longitude;
    updates.location_name = loc.location_name;
  }
  await post.update(updates);

  const fresh = await Post.findByPk(postId, {
    include: [
      { model: User, as: "author", attributes: ["user_id", "nickname", "avatar", "current_role"] },
      { model: Child, as: "child", attributes: ["child_id", "nickname", "avatar"] },
      { model: Course, as: "course", attributes: ["course_id", "title", "studio_id", "price"] },
      { model: PostStudent, as: "students", include: [{ model: Child, as: "child", attributes: ["child_id", "nickname", "avatar"] }] }
    ]
  });
  return { data: normalizePostItem(fresh, userId) };
}

/// 删除帖子（家长/老师统一入口，仅作者本人）
/// 老师帖：发帖消课（source=1）自动退课时；同时清理关联学生/评论/点赞/收藏
async function deletePost(userId, postId) {
  const post = await Post.findByPk(postId);
  if (!post) return null;
  if (String(post.author_id) !== String(userId)) {
    return { error: { status: 403, code: 40003, message: "只能删除自己的帖子" } };
  }
  // 仅老师发的孩子作品不可删除（老师孩子作品关联消课记录）；家长可删除自己孩子的作品
  if (Number(post.type) === 2 && Number(post.author_role) === 2) {
    return { error: { status: 400, code: 40062, message: "老师的孩子作品不支持删除" } };
  }

  await sequelize.transaction(async (transaction) => {
    // 1. 发帖消课（source=1）→ 退课时
    const logs = await LessonLog.findAll({ where: { post_id: postId }, transaction });
    for (const log of logs) {
      if (Number(log.source) === 1) {
        const delta = Math.abs(Number(log.delta || 1));
        const order = await Order.findByPk(log.order_id, {
          transaction,
          lock: transaction.LOCK.UPDATE
        });
        const balance = await ChildCourseBalance.findOne({
          where: { order_id: log.order_id, course_id: log.course_id, status: { [Op.in]: [1, 2] } },
          transaction,
          lock: transaction.LOCK.UPDATE
        });
        if (order && balance) {
          const remainingAfter = Number(balance.remaining_lessons || 0) + delta;
          await order.update(
            { consumed_lessons: Math.max(Number(order.consumed_lessons || 0) - delta, 0) },
            { transaction }
          );
          if (Number(order.status) === 2 && remainingAfter > 0) {
            await order.update({ status: 1 }, { transaction });
          }
          await balance.update(
            {
              consumed_lessons: Math.max(Number(balance.consumed_lessons || 0) - delta, 0),
              remaining_lessons: remainingAfter
            },
            { transaction }
          );
        }
      }
      await log.destroy({ transaction });
    }
    // 2. 清理关联数据
    await PostStudent.destroy({ where: { post_id: postId }, transaction });
    await PostComment.destroy({ where: { post_id: postId }, transaction });
    await PostLike.destroy({ where: { post_id: postId }, transaction });
    await Favorite.destroy({ where: { target_type: "post", target_id: postId }, transaction });
    // 3. 删帖
    await post.destroy({ transaction });
  });

  return { data: { post_id: String(postId) } };
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
  listMyPosts,
  listChildFeed,
  createParentPost,
  updatePost,
  deletePost,
  likeComment,
  unlikeComment
};

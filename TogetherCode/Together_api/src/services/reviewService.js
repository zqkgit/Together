/**
 * 课程评价：家长购买后评分 + 文字
 * 规则：
 *  - 仅购买过该课程（有已支付订单）的家长可评；一课程一用户一评
 *  - 状态机：0 待审核（平台审核）→ 1 通过（公开）/ 2 驳回（带原因）
 *  - 待审核/驳回状态可编辑；通过后仅支持工作室回复
 *  - teacher_id / studio_id 冗余自课程，支撑老师/工作室口碑聚合
 */
const { Op } = require("sequelize");
const {
  CourseReview,
  User,
  Order,
  Course,
  StudioProfile,
  TeacherProfile
} = require("../models");

const REVIEW_STATUS = { PENDING: 0, APPROVED: 1, REJECTED: 2 };

/** 校验家长是否购买过该课程（任意订单含该课程且已支付/已消课） */
async function hasPaidCourse(userId, courseId) {
  const count = await Order.count({
    where: {
      user_id: userId,
      course_id: courseId,
      status: { [Op.in]: [1, 2] } // 1 已支付 / 2 已完成
    }
  });
  return count > 0;
}

/** 提交课程评价（进入待审核） */
async function createCourseReview(userId, payload) {
  const courseId = String(payload.course_id).trim();
  const rating = Number(payload.rating);
  if (!courseId) return { error: { status: 400, code: 40074, message: "course_id is required" } };
  if (![1, 2, 3, 4, 5].includes(rating)) {
    return { error: { status: 400, code: 40075, message: "rating must be 1-5" } };
  }

  const course = await Course.findByPk(courseId);
  if (!course || Number(course.status) !== 1) {
    return { error: { status: 404, code: 40474, message: "课程不存在或已下架" } };
  }

  if (!(await hasPaidCourse(userId, courseId))) {
    return { error: { status: 403, code: 40374, message: "仅购买过该课程的家长可评价" } };
  }

  const existed = await CourseReview.findOne({ where: { course_id: courseId, user_id: userId } });
  if (existed) {
    return { error: { status: 409, code: 40974, message: "您已评价过该课程" } };
  }

  const review = await CourseReview.create({
    course_id: courseId,
    teacher_id: course.teacher_id || null,
    studio_id: course.studio_id || null,
    user_id: userId,
    order_id: payload.order_id || null,
    child_id: payload.child_id || null,
    rating,
    content: String(payload.content || "").trim() || null,
    images: Array.isArray(payload.images) ? payload.images.slice(0, 9) : null,
    status: REVIEW_STATUS.PENDING
  });

  return { review_id: String(review.review_id), status: REVIEW_STATUS.PENDING };
}

/** 编辑我的评价（仅待审核 / 驳回状态可改，改后回到待审核） */
async function updateCourseReview(userId, reviewId, payload) {
  const review = await CourseReview.findOne({ where: { review_id: reviewId, user_id: userId } });
  if (!review) {
    return { error: { status: 404, code: 40475, message: "评价不存在" } };
  }
  if (Number(review.status) === REVIEW_STATUS.APPROVED) {
    return { error: { status: 409, code: 40975, message: "评价已通过审核，不可编辑" } };
  }

  const rating = Number(payload.rating);
  if (rating && ![1, 2, 3, 4, 5].includes(rating)) {
    return { error: { status: 400, code: 40075, message: "rating must be 1-5" } };
  }

  const updates = {};
  if (rating) updates.rating = rating;
  if (payload.content !== undefined) {
    updates.content = String(payload.content || "").trim() || null;
  }
  if (Array.isArray(payload.images)) updates.images = payload.images.slice(0, 9);
  // 编辑后回到待审核
  updates.status = REVIEW_STATUS.PENDING;
  updates.reject_reason = null;

  await review.update(updates);
  return { review_id: String(review.review_id), status: REVIEW_STATUS.PENDING };
}

/** 课程评价列表（默认公开仅 status=1；显式传 status 可查全量） */
async function listCourseReviews(courseId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.page_size) || 10, 30);
  const where = { course_id: courseId };
  const status = Number(query.status);
  if ([0, 1, 2].includes(status)) {
    where.status = status;
  } else {
    where.status = REVIEW_STATUS.APPROVED;
  }

  const { count, rows } = await CourseReview.findAndCountAll({
    where,
    include: [{ model: User, as: "user", attributes: ["user_id", "nickname", "avatar"] }],
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  // 评分分布（仅已通过）
  const dist = await CourseReview.findAll({
    where: { course_id: courseId, status: REVIEW_STATUS.APPROVED },
    attributes: ["rating"],
    raw: true
  });
  const ratingCount = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  let sum = 0;
  dist.forEach((r) => {
    const key = String(r.rating);
    if (ratingCount[key] !== undefined) {
      ratingCount[key] += 1;
      sum += Number(r.rating);
    }
  });
  const avg = dist.length ? Number((sum / dist.length).toFixed(1)) : 0;

  return {
    total: count,
    page,
    page_size: size,
    average: avg,
    rating_count: dist.length,
    rating_distribution: ratingCount,
    list: rows.map((r) => formatReview(r))
  };
}

/** 我的评价列表 */
async function listMyReviews(userId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.page_size) || 10, 30);
  const where = { user_id: userId };
  const status = Number(query.status);
  if ([0, 1, 2].includes(status)) where.status = status;

  const { count, rows } = await CourseReview.findAndCountAll({
    where,
    include: [
      { model: Course, as: "course", attributes: ["course_id", "title", "cover", "studio_id", "teacher_id"] },
      { model: User, as: "user", attributes: ["user_id", "nickname", "avatar"] }
    ],
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  return {
    total: count,
    page,
    page_size: size,
    list: rows.map((r) => ({
      ...formatReview(r),
      course: r.course
        ? {
            course_id: String(r.course.course_id),
            title: r.course.title,
            cover: r.course.cover || null
          }
        : null
    }))
  };
}

/** 管理端评价列表（状态 / 课程 / 工作室 / 评分筛选） */
async function listAdminCourseReviews(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.page_size) || 10, 50);
  const where = {};
  const status = Number(query.status);
  if (
    query.status !== "" &&
    query.status !== undefined &&
    query.status !== null &&
    [0, 1, 2].includes(status)
  ) {
    where.status = status;
  }
  if (query.course_id) where.course_id = query.course_id;
  if (query.studio_id) where.studio_id = query.studio_id;
  if (query.rating !== "" && query.rating !== undefined && query.rating !== null) {
    where.rating = Number(query.rating);
  }

  const { count, rows } = await CourseReview.findAndCountAll({
    where,
    include: [
      { model: User, as: "user", attributes: ["user_id", "nickname", "avatar"] },
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "title", "cover"],
        include: [{ model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] }]
      },
      { model: TeacherProfile, as: "teacher", attributes: ["teacher_id", "real_name"] }
    ],
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  return {
    total: count,
    page,
    page_size: size,
    list: rows.map((r) => ({
      ...formatReview(r),
      course: r.course
        ? {
            course_id: String(r.course.course_id),
            title: r.course.title,
            cover: r.course.cover || null,
            studio_name: r.course.studio?.name || null,
            studio_id: r.course.studio_id
          }
        : null,
      teacher_name: r.teacher?.real_name || null
    }))
  };
}

/** 管理端审核：approve 通过 / reject 驳回 */
async function auditCourseReview(reviewId, action, reason) {
  const review = await CourseReview.findByPk(reviewId);
  if (!review) {
    return { error: { status: 404, code: 40475, message: "评价不存在" } };
  }
  if (Number(review.status) !== REVIEW_STATUS.PENDING) {
    return { error: { status: 409, code: 40976, message: "该评价已处理过" } };
  }

  const nextStatus = action === "approve" ? REVIEW_STATUS.APPROVED : REVIEW_STATUS.REJECTED;
  const rejectReason =
    nextStatus === REVIEW_STATUS.REJECTED ? String(reason || "").slice(0, 255) || "内容不符合平台规范" : null;
  await review.update({ status: nextStatus, reject_reason: rejectReason });

  return {
    review_id: String(review.review_id),
    status: nextStatus,
    reject_reason: rejectReason
  };
}

/** 工作室回复评价（归属校验在 controller 层） */
async function replyCourseReview(reviewId, actor, payload = {}) {
  const { role = "studio", content } = payload;
  if (!["studio", "teacher"].includes(role)) {
    return { error: { status: 400, code: 40078, message: "回复身份不合法" } };
  }
  const review = await CourseReview.findByPk(reviewId, {
    include: [{ model: Course, as: "course", attributes: ["course_id", "teacher_id"] }]
  });
  if (!review) {
    return { error: { status: 404, code: 40475, message: "评价不存在" } };
  }
  if (Number(review.status) !== REVIEW_STATUS.APPROVED) {
    return { error: { status: 409, code: 40977, message: "仅已通过的评价可回复" } };
  }
  // 归属校验：工作室回复须为本工作室课程；老师回复须为该课程授课老师
  if (role === "studio") {
    if (!actor.studioId || String(review.studio_id) !== String(actor.studioId)) {
      return { error: { status: 403, code: 40375, message: "无权回复该评价" } };
    }
  } else {
    if (!actor.teacherId || String(review.course?.teacher_id) !== String(actor.teacherId)) {
      return { error: { status: 403, code: 40376, message: "仅该课程授课老师可回复" } };
    }
  }
  const text = String(content || "").trim();
  if (!text) {
    return { error: { status: 400, code: 40076, message: "回复内容不能为空" } };
  }
  if (text.length > 500) {
    return { error: { status: 400, code: 40077, message: "回复内容不能超过500字" } };
  }

  const update =
    role === "studio"
      ? { reply_content: text, reply_at: new Date() }
      : { teacher_reply_content: text, teacher_reply_at: new Date() };
  await review.update(update);
  return {
    review_id: String(review.review_id),
    role,
    reply_content: role === "studio" ? text : review.teacher_reply_content,
    reply_at: role === "studio" ? review.reply_at : review.teacher_reply_at
  };
}

/** 工作室评价列表（web 工作室后台）：本工作室课程的评价，可回复 */
async function listStudioCourseReviews(studioId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.page_size) || 10, 50);
  const where = { studio_id: studioId, status: REVIEW_STATUS.APPROVED };
  if (query.rating !== "" && query.rating !== undefined && query.rating !== null) {
    where.rating = Number(query.rating);
  }
  if (query.replied === "1") {
    where[Op.or] = [{ reply_content: { [Op.ne]: null } }, { teacher_reply_content: { [Op.ne]: null } }];
  } else if (query.replied === "0") {
    where[Op.and] = [
      { reply_content: null },
      { teacher_reply_content: null }
    ];
  }

  const { count, rows } = await CourseReview.findAndCountAll({
    where,
    include: [
      { model: User, as: "user", attributes: ["user_id", "nickname", "avatar"] },
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "title", "cover"],
        include: [{ model: TeacherProfile, as: "teacher", attributes: ["teacher_id", "real_name"] }]
      }
    ],
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  return {
    total: count,
    page,
    page_size: size,
    list: rows.map((r) => ({
      ...formatReview(r),
      course: r.course
        ? {
            course_id: String(r.course.course_id),
            title: r.course.title,
            cover: r.course.cover || null,
            teacher_name: r.course.teacher?.real_name || null
          }
        : null
    }))
  };
}

/** 课程平均分（课程详情页展示用） */
async function getCourseAverageRating(courseId) {
  const reviews = await CourseReview.findAll({
    where: { course_id: courseId, status: REVIEW_STATUS.APPROVED },
    attributes: ["rating"],
    raw: true
  });
  if (!reviews.length) return 0;
  const sum = reviews.reduce((acc, r) => acc + Number(r.rating), 0);
  return Number((sum / reviews.length).toFixed(1));
}

/** 工作室口碑汇总（详情页展示：均分 + 分档 + 数量） */
async function getStudioRatingSummary(studioId) {
  const reviews = await CourseReview.findAll({
    where: { studio_id: studioId, status: REVIEW_STATUS.APPROVED },
    attributes: ["rating"],
    raw: true
  });
  const dist = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  let sum = 0;
  reviews.forEach((r) => {
    const key = String(r.rating);
    if (dist[key] !== undefined) {
      dist[key] += 1;
      sum += Number(r.rating);
    }
  });
  return {
    average: reviews.length ? Number((sum / reviews.length).toFixed(1)) : 0,
    total: reviews.length,
    distribution: dist
  };
}

function formatReview(r) {
  return {
    review_id: String(r.review_id),
    rating: Number(r.rating),
    content: r.content,
    images: r.images || [],
    reply_content: r.reply_content,
    reply_at: r.reply_at,
    teacher_reply_content: r.teacher_reply_content,
    teacher_reply_at: r.teacher_reply_at,
    status: Number(r.status),
    reject_reason: r.reject_reason,
    user: r.user
      ? {
          user_id: String(r.user.user_id),
          nickname: r.user.nickname || "家长",
          avatar: r.user.avatar || null
        }
      : null,
    created_at: r.created_at
  };
}

module.exports = {
  REVIEW_STATUS,
  createCourseReview,
  updateCourseReview,
  listCourseReviews,
  listMyReviews,
  listAdminCourseReviews,
  auditCourseReview,
  replyCourseReview,
  listStudioCourseReviews,
  getCourseAverageRating,
  getStudioRatingSummary,
  hasPaidCourse
};

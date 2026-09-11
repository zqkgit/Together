/**
 * 课程评价：家长购买后评分 + 文字
 * 规则：仅购买过该课程（有已支付订单）的家长可评；一课程一用户一评
 */
const { Op } = require("sequelize");
const { CourseReview, User, Order, Course, TeacherProfile, TeacherStudioBinding } = require("../models");

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

/** 提交课程评价 */
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
    user_id: userId,
    rating,
    content: String(payload.content || "").trim() || null,
    images: Array.isArray(payload.images) ? payload.images : null,
    status: 1
  });

  return { review_id: String(review.review_id) };
}

/** 课程评价列表（公开） */
async function listCourseReviews(courseId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.page_size) || 10, 30);
  const where = { course_id: courseId, status: 1 };

  const { count, rows } = await CourseReview.findAndCountAll({
    where,
    include: [{ model: User, as: "user", attributes: ["user_id", "nickname", "avatar"] }],
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  // 评分分布
  const dist = await CourseReview.findAll({
    where: { course_id: courseId, status: 1 },
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
    list: rows.map((r) => ({
      review_id: String(r.review_id),
      rating: Number(r.rating),
      content: r.content,
      images: r.images || [],
      nickname: r.user?.nickname || "家长",
      avatar: r.user?.avatar || null,
      created_at: r.created_at
    }))
  };
}

/** 课程平均分（课程详情页展示用） */
async function getCourseAverageRating(courseId) {
  const reviews = await CourseReview.findAll({
    where: { course_id: courseId, status: 1 },
    attributes: ["rating"],
    raw: true
  });
  if (!reviews.length) return 0;
  const sum = reviews.reduce((acc, r) => acc + Number(r.rating), 0);
  return Number((sum / reviews.length).toFixed(1));
}

module.exports = {
  createCourseReview,
  listCourseReviews,
  getCourseAverageRating,
  hasPaidCourse
};

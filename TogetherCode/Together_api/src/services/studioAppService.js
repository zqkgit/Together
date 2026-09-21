const { Op } = require("sequelize");
const {
  StudioProfile,
  TeacherStudioBinding,
  Course,
  ChildCourseBalance,
  Order,
  Refund,
  User
} = require("../models");

/**
 * 工作室 App 端「我的」：机构资料 + 经营统计
 * 与 Web 端 /studio/profile、/studio/overview 同源（studio_profiles.user_id ↔ 登录用户）
 */
async function getStudioMine(userId) {
  const studio = await StudioProfile.findOne({
    where: { user_id: userId },
    include: [
      {
        model: User,
        as: "owner",
        attributes: ["user_id", "phone", "nickname", "avatar", "city"]
      }
    ]
  });

  if (!studio) {
    return null;
  }

  const studioId = studio.studio_id;

  const [activeStudents, onlineCourses, courseTotal, teachers, pendingRefunds] = await Promise.all([
    // 在读学员：该工作室订单对应、仍有剩余课时的去重学员数（与经营概览口径一致）
    ChildCourseBalance.count({
      distinct: true,
      col: "child_id",
      where: { remaining_lessons: { [Op.gt]: 0 } },
      include: [{ model: Order, as: "order", where: { studio_id: studioId }, required: true }]
    }),
    // 在售课程
    Course.count({ where: { studio_id: studioId, status: 1 } }),
    Course.count({ where: { studio_id: studioId } }),
    // 入驻教师：在职绑定
    TeacherStudioBinding.count({ where: { studio_id: studioId, status: 1 } }),
    // 待处理退款
    Refund.count({
      where: { status: 0 },
      include: [{ model: Order, as: "order", where: { studio_id: studioId }, required: true }]
    })
  ]);

  const createdAt = studio.created_at ? new Date(studio.created_at) : null;
  let years = 0;
  let months = 0;
  if (createdAt && !Number.isNaN(createdAt.getTime())) {
    const now = new Date();
    let monthDiff =
      (now.getFullYear() - createdAt.getFullYear()) * 12 + (now.getMonth() - createdAt.getMonth());
    if (now.getDate() < createdAt.getDate()) {
      monthDiff -= 1;
    }
    monthDiff = Math.max(0, monthDiff);
    years = Math.floor(monthDiff / 12);
    months = monthDiff % 12;
  }

  const typeTags = Array.isArray(studio.type_tags) ? studio.type_tags : [];

  return {
    profile: {
      studio_id: String(studio.studio_id),
      user_id: String(studio.user_id),
      name: studio.name || "未命名工作室",
      cover: studio.cover || null,
      avatar: studio.owner?.avatar || null,
      intro: studio.intro || "",
      city: studio.city || "",
      address: studio.address || "",
      business_type: studio.business_type || "",
      type_tags: typeTags,
      phone: studio.phone || studio.owner?.phone || "",
      hours: studio.hours || "",
      // 工作室状态 1 = 正常运营（入驻审核通过即视为平台认证机构）
      cert_status: Number(studio.status) === 1 ? 1 : 0,
      status: Number(studio.status || 0),
      joined_at: studio.created_at || null,
      years,
      months
    },
    stats: {
      active_students: activeStudents,
      online_courses: onlineCourses,
      course_total: courseTotal,
      teachers,
      pending_refunds: pendingRefunds
    }
  };
}

module.exports = {
  getStudioMine
};

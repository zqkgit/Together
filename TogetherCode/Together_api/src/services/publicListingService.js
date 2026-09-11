/**
 * 公开列表：家长端首页/找画室/找老师
 * 只暴露审核通过（工作室 status=1 / 老师 cert_status=1）的实体
 */
const { Op } = require("sequelize");
const {
  StudioProfile,
  TeacherProfile,
  User,
  Course,
  TeacherStudioBinding
} = require("../models");

/** 公开工作室列表（含课程数/老师数/平均评分） */
async function listPublicStudios(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.page_size) || 10, 30);
  const where = { status: 1 };
  if (query.keyword && String(query.keyword).trim()) {
    const kw = String(query.keyword).trim();
    where[Op.or] = [
      { name: { [Op.like]: `%${kw}%` } },
      { address: { [Op.like]: `%${kw}%` } }
    ];
  }

  const { count, rows } = await StudioProfile.findAndCountAll({
    where,
    offset: (page - 1) * size,
    limit: size,
    order: [["created_at", "DESC"]]
  });

  const studioIds = rows.map((r) => r.studio_id);
  const courseCount = {};
  const teacherCount = {};
  const ratingSum = {};

  if (studioIds.length) {
    const courses = await Course.findAll({
      where: { studio_id: { [Op.in]: studioIds }, status: 1 },
      attributes: ["studio_id"],
      raw: true
    });
    courses.forEach((c) => {
      courseCount[c.studio_id] = (courseCount[c.studio_id] || 0) + 1;
    });

    const bindings = await TeacherStudioBinding.findAll({
      where: { studio_id: { [Op.in]: studioIds }, status: 1 },
      include: [{ model: TeacherProfile, as: "teacher", attributes: ["teacher_id", "rating"] }]
    });
    bindings.forEach((b) => {
      if (!b.teacher) return;
      teacherCount[b.studio_id] = (teacherCount[b.studio_id] || 0) + 1;
      ratingSum[b.studio_id] = (ratingSum[b.studio_id] || 0) + Number(b.teacher.rating || 0);
    });
  }

  return {
    total: count,
    page,
    page_size: size,
    list: rows.map((s) => ({
      studio_id: String(s.studio_id),
      name: s.name,
      cover: s.cover || null,
      type_tags: s.type_tags || [],
      intro: s.intro || null,
      address: s.address || null,
      course_count: courseCount[s.studio_id] || 0,
      teacher_count: teacherCount[s.studio_id] || 0,
      rating: teacherCount[s.studio_id]
        ? Number((ratingSum[s.studio_id] / teacherCount[s.studio_id]).toFixed(1))
        : 0
    }))
  };
}

/** 公开已认证老师列表 */
async function listPublicTeachers(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.page_size) || 10, 30);
  const where = { cert_status: 1 };
  if (query.keyword && String(query.keyword).trim()) {
    const kw = String(query.keyword).trim();
    where[Op.or] = [
      { real_name: { [Op.like]: `%${kw}%` } },
      { "$user.nickname$": { [Op.like]: `%${kw}%` } }
    ];
  }

  const { count, rows } = await TeacherProfile.findAndCountAll({
    where,
    include: [
      { model: User, as: "user", attributes: ["user_id", "nickname", "avatar"] },
      {
        model: TeacherStudioBinding,
        as: "bindings",
        where: { status: 1 },
        required: false,
        include: [{ model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] }]
      }
    ],
    offset: (page - 1) * size,
    limit: size,
    order: [["rating", "DESC"]]
  });

  return {
    total: count,
    page,
    page_size: size,
    list: rows.map((t) => ({
      teacher_id: String(t.teacher_id),
      user_id: String(t.user_id),
      nickname: t.user?.nickname || t.real_name || "老师",
      avatar: t.user?.avatar || null,
      real_name: t.real_name || null,
      subjects: t.subjects || [],
      years: t.years,
      intro: t.intro,
      rating: Number(t.rating || 0),
      work_count: Number(t.work_count || 0),
      studios: (t.bindings || []).map((b) => ({
        studio_id: String(b.studio_id),
        name: b.studio ? b.studio.name : null
      }))
    }))
  };
}

module.exports = {
  listPublicStudios,
  listPublicTeachers
};

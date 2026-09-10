const { Op } = require("sequelize");
const {
  TeacherProfile,
  User,
  StudioProfile,
  TeacherStudioBinding
} = require("../models");

/**
 * 平台侧：老师档案管理（已认证老师列表）
 * 筛选：cert_status（0 未认证 / 1 已认证）、q（姓名/手机模糊）、studio_id
 */
async function listPlatformTeachers(query = {}) {
  const where = {};

  if (query.cert_status !== undefined && query.cert_status !== null && query.cert_status !== "") {
    where.cert_status = Number(query.cert_status);
  }

  const userWhere = {};
  if (query.q) {
    const keyword = query.q.trim();
    where[Op.or] = [
      { real_name: { [Op.like]: `%${keyword}%` } },
      { "$user.phone$": { [Op.like]: `%${keyword}%` } },
      { "$user.nickname$": { [Op.like]: `%${keyword}%` } }
    ];
  }

  const bindingWhere = query.studio_id ? { studio_id: query.studio_id } : {};

  const rows = await TeacherProfile.findAll({
    where,
    include: [
      {
        model: User,
        as: "user",
        attributes: ["user_id", "phone", "nickname", "avatar"],
        where: userWhere
      },
      {
        model: TeacherStudioBinding,
        as: "bindings",
        where: { ...bindingWhere, status: 1 },
        required: !!query.studio_id,
        include: [
          {
            model: StudioProfile,
            as: "studio",
            attributes: ["studio_id", "name"],
            required: false
          }
        ]
      }
    ],
    order: [["created_at", "DESC"]],
    limit: Math.min(Number(query.limit) || 50, 200),
    offset: Number(query.offset) || 0
  });

  return {
    total: rows.length,
    list: rows.map((item) => ({
      teacher_id: String(item.teacher_id),
      user_id: String(item.user_id),
      real_name: item.real_name,
      phone: item.user ? item.user.phone : "-",
      nickname: item.user ? item.user.nickname : item.real_name,
      avatar: item.user ? item.user.avatar : null,
      subjects: item.subjects || [],
      years: item.years,
      intro: item.intro,
      cert_no: item.cert_no,
      cert_status: Number(item.cert_status),
      studio_id: item.studio_id ? String(item.studio_id) : null,
      studio_name: item.studio ? item.studio.name : null,
      studios: (item.bindings || [])
        .filter((binding) => Number(binding.status) === 1)
        .map((binding) => ({
          studio_id: String(binding.studio_id),
          name: binding.studio ? binding.studio.name : null,
          bound_at: binding.bound_at
        })),
      rating: Number(item.rating),
      student_count: Number(item.student_count),
      work_count: Number(item.work_count),
      created_at: item.created_at
    }))
  };
}

module.exports = {
  listPlatformTeachers
};

const { sequelize, TeacherApplication, TeacherProfile, UserRole, User } = require("../models");
const { generateId } = require("../utils/id");

const TEACHER_ROLE = 2;

/**
 * 平台老师认证申请管理。
 * 申请来源：用户（默认家长角色）申请成为老师，studio_id 为空 → 平台审核。
 * 通过后创建 TeacherProfile（不绑定工作室）并开通老师角色；老师再向工作室申请合作。
 */
async function getTeacherApplications(query = {}) {
  const where = { studio_id: null };
  if (query.status !== undefined && query.status !== null && query.status !== "") {
    where.status = Number(query.status);
  }

  const rows = await TeacherApplication.findAll({
    where,
    include: [
      {
        model: User,
        as: "user",
        attributes: ["user_id", "phone", "nickname", "avatar"]
      }
    ],
    order: [["submitted_at", "DESC"]]
  });

  return {
    total: rows.length,
    list: rows.map((item) => ({
      id: String(item.id),
      user_id: String(item.user_id),
      real_name: item.real_name,
      subjects: item.subjects || [],
      years: item.years,
      intro: item.intro,
      cert_no: item.cert_no,
      portfolio: item.portfolio || [],
      status: Number(item.status),
      submitted_at: item.submitted_at,
      reviewed_at: item.reviewed_at,
      review_reason: item.review_reason,
      phone: item.user?.phone || "-",
      nickname: item.user?.nickname || item.real_name,
      avatar: item.user?.avatar || null
    }))
  };
}

/**
 * 平台审核老师认证申请：
 * - approve：创建 TeacherProfile（studio_id 为空，等待工作室合作绑定）+ 开通老师角色
 * - reject：驳回并记录原因
 */
async function reviewTeacherApplication(applicationId, payload, operator = {}) {
  return sequelize.transaction(async (transaction) => {
    const application = await TeacherApplication.findOne({
      where: { id: applicationId, studio_id: null },
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!application) {
      return { error: { status: 404, message: "老师认证申请不存在" } };
    }

    if (Number(application.status) !== 0) {
      return { error: { status: 400, message: "该申请已处理" } };
    }

    if (payload.action === "reject") {
      if (!payload.reason || !payload.reason.trim()) {
        return { error: { status: 400, message: "驳回必须填写原因" } };
      }

      await application.update(
        {
          status: 2,
          reviewed_at: new Date(),
          review_reason: payload.reason.trim()
        },
        { transaction }
      );

      return {
        data: { id: String(application.id), status: 2, action: "reject" },
        message: "已驳回申请"
      };
    }

    // 已有档案（重复申请）则不重复创建
    let profile = await TeacherProfile.findOne({
      where: { user_id: application.user_id },
      transaction
    });

    if (!profile) {
      profile = await TeacherProfile.create(
        {
          teacher_id: generateId(),
          user_id: application.user_id,
          real_name: application.real_name,
          subjects: application.subjects || [],
          years: application.years,
          intro: application.intro,
          cert_no: application.cert_no,
          portfolio: application.portfolio || [],
          studio_id: null,
          cert_status: 1
        },
        { transaction }
      );
    } else {
      await profile.update(
        {
          cert_status: 1,
          real_name: application.real_name || profile.real_name,
          subjects: application.subjects || profile.subjects,
          years: application.years || profile.years
        },
        { transaction }
      );
    }

    const [roleRow] = await UserRole.findOrCreate({
      where: { user_id: application.user_id, role: TEACHER_ROLE },
      defaults: {
        id: generateId(),
        user_id: application.user_id,
        role: TEACHER_ROLE,
        ref_id: profile.teacher_id,
        verified: true
      },
      transaction
    });
    if (!roleRow.verified || String(roleRow.ref_id || "") !== String(profile.teacher_id)) {
      await roleRow.update(
        {
          ref_id: profile.teacher_id,
          verified: true
        },
        { transaction }
      );
    }

    await application.update(
      {
        status: 1,
        reviewed_at: new Date()
      },
      { transaction }
    );

    return {
      data: {
        id: String(application.id),
        status: 1,
        action: "approve",
        teacher_id: String(profile.teacher_id)
      },
      message: "已通过老师认证"
    };
  });
}

module.exports = {
  getTeacherApplications,
  reviewTeacherApplication
};

const { Op } = require("sequelize");
const { sequelize, TeacherApplication, TeacherProfile, UserRole, User, StudioProfile } = require("../models");
const { generateId } = require("../utils/id");

/**
 * 工作室教师管理：
 * - applications：本工作室收到的老师合作申请（TeacherApplication）
 * - staff：本工作室在职老师（TeacherProfile）
 */
async function getStudioTeachers(studioId, query = {}) {
  const applicationWhere = { studio_id: studioId };
  if (query.status !== undefined && query.status !== null && query.status !== "") {
    applicationWhere.status = Number(query.status);
  }

  const [applications, staff] = await Promise.all([
    TeacherApplication.findAll({
      where: applicationWhere,
      include: [
        {
          model: User,
          as: "user",
          attributes: ["user_id", "phone", "nickname", "avatar"]
        },
        {
          model: StudioProfile,
          as: "studio",
          attributes: ["studio_id", "name"]
        }
      ],
      order: [["submitted_at", "DESC"]]
    }),
    TeacherProfile.findAll({
      where: { studio_id: studioId },
      include: [
        {
          model: User,
          as: "user",
          attributes: ["user_id", "phone", "nickname", "avatar"]
        }
      ],
      order: [["created_at", "DESC"]]
    })
  ]);

  return {
    applications: (applications || []).map((item) => ({
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
    })),
    staff: (staff || []).map((item) => ({
      teacher_id: String(item.teacher_id),
      user_id: String(item.user_id),
      real_name: item.real_name,
      subjects: item.subjects || [],
      years: item.years,
      intro: item.intro,
      cert_no: item.cert_no,
      cert_status: Number(item.cert_status),
      rating: Number(item.rating),
      student_count: Number(item.student_count),
      phone: item.user?.phone || "-",
      nickname: item.user?.nickname || item.real_name,
      avatar: item.user?.avatar || null
    }))
  };
}

const TEACHER_ROLE = 2;

/**
 * 审批老师合作申请：
 * - approve：申请转通过，创建/更新 TeacherProfile（绑定本工作室），并给申请人开通老师角色（role=2）
 * - reject：驳回并记录原因
 */
async function reviewTeacherApplication(studioId, applicationId, payload, operator = {}) {
  return sequelize.transaction(async (transaction) => {
    const application = await TeacherApplication.findOne({
      where: { id: applicationId, studio_id: studioId },
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!application) {
      return { error: { status: 404, message: "老师申请不存在" } };
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

    // approve：要求申请人已通过平台老师认证（存在 TeacherProfile 档案）
    let profile = await TeacherProfile.findOne({
      where: { user_id: application.user_id },
      transaction
    });

    if (!profile) {
      return {
        error: {
          status: 400,
          message: "该老师尚未通过平台老师认证，请先在 App 端完成老师认证申请"
        }
      };
    }

    await profile.update(
      {
        real_name: application.real_name || profile.real_name,
        subjects: application.subjects || profile.subjects,
        years: application.years || profile.years,
        intro: application.intro || profile.intro,
        studio_id: studioId,
        cert_status: 1
      },
      { transaction }
    );

    // 开通老师角色（App 端 role=2 登录可用老师接口）
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
      message: "已通过并加入工作室"
    };
  });
}

module.exports = {
  getStudioTeachers,
  reviewTeacherApplication
};

const { Op } = require("sequelize");
const {
  sequelize,
  TeacherApplication,
  TeacherProfile,
  TeacherStudioBinding,
  UserRole,
  User,
  StudioProfile
} = require("../models");
const { generateId } = require("../utils/id");
const { createNotification } = require("./messageService");

/**
 * 工作室教师管理：
 * - applications：本工作室收到的老师合作申请（TeacherApplication）
 * - staff：本工作室在职老师（TeacherProfile 经 TeacherStudioBinding 绑定）
 */
async function getStudioTeachers(studioId, query = {}) {
  const applicationWhere = { studio_id: studioId };
  if (query.status !== undefined && query.status !== null && query.status !== "") {
    applicationWhere.status = Number(query.status);
  }

  const [applications, bindings] = await Promise.all([
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
    TeacherStudioBinding.findAll({
      where: { studio_id: studioId, status: 1 },
      include: [
        {
          model: TeacherProfile,
          as: "teacher",
          required: true,
          include: [
            {
              model: User,
              as: "user",
              attributes: ["user_id", "phone", "nickname", "avatar"]
            }
          ]
        }
      ],
      order: [["bound_at", "DESC"]]
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
    staff: (bindings || []).map((item) => {
      const teacher = item.teacher;
      return {
        binding_id: String(item.binding_id),
        teacher_id: String(teacher.teacher_id),
        user_id: String(teacher.user_id),
        real_name: teacher.real_name,
        subjects: teacher.subjects || [],
        years: teacher.years,
        intro: teacher.intro,
        cert_no: teacher.cert_no,
        cert_status: Number(teacher.cert_status),
        rating: Number(teacher.rating),
        student_count: Number(teacher.student_count),
        bound_at: item.bound_at,
        phone: teacher.user?.phone || "-",
        nickname: teacher.user?.nickname || teacher.real_name,
        avatar: teacher.user?.avatar || null
      };
    })
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
    const profile = await TeacherProfile.findOne({
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

    // 老师档案信息仅由平台认证 / 老师本人维护，工作室审批只建立绑定，不修改档案字段

    // 建立/恢复工作室绑定（一对多：一个老师可绑定多个工作室）
    const [binding] = await TeacherStudioBinding.findOrCreate({
      where: { teacher_id: profile.teacher_id, studio_id: studioId },
      defaults: {
        binding_id: generateId(),
        teacher_id: profile.teacher_id,
        studio_id: studioId,
        status: 1,
        bound_at: new Date()
      },
      transaction
    });
    if (Number(binding.status) !== 1) {
      await binding.update({ status: 1, released_at: null, bound_at: new Date() }, { transaction });
    }
    // 首次绑定工作室时同步主工作室字段
    if (!profile.studio_id) {
      await profile.update({ studio_id: studioId }, { transaction });
    }

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

/**
 * 取消与老师的合作关系：
 * - 将 teacher_studio_bindings 置为已解除（status=0 + released_at）
 * - 若该工作室是老师的主工作室（teacher_profiles.studio_id），同步清空主工作室字段
 * - 老师档案保留，仍可与其他工作室保持绑定
 */
async function releaseTeacher(studioId, teacherId, payload = {}) {
  return sequelize.transaction(async (transaction) => {
    const binding = await TeacherStudioBinding.findOne({
      where: { teacher_id: teacherId, studio_id: studioId, status: 1 },
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!binding) {
      return { error: { status: 404, message: "该老师与本工作室没有生效的合作关系" } };
    }

    await binding.update(
      {
        status: 0,
        released_at: new Date()
      },
      { transaction }
    );

    const profile = await TeacherProfile.findOne({
      where: { teacher_id: teacherId },
      transaction
    });
    if (profile && profile.studio_id && String(profile.studio_id) === String(studioId)) {
      await profile.update({ studio_id: null }, { transaction });
    }

    return {
      data: {
        binding_id: String(binding.binding_id),
        teacher_id: String(teacherId),
        studio_id: String(studioId),
        status: 0,
        action: "release"
      },
      message: "已解除合作"
    };
  });
}

/**
 * 工作室主动邀请老师合作（POST /studio/invite-teacher）
 * 前置：老师必须先通过平台老师认证（存在 TeacherProfile），工作室侧不修改老师档案。
 */
async function inviteTeacher(studioId, payload = {}) {
  const phone = String(payload.phone || "").trim();
  if (!phone) {
    return { error: { status: 400, code: 40090, message: "phone 不能为空" } };
  }

  const user = await User.findOne({ where: { phone } });
  if (!user) {
    return { error: { status: 404, code: 40490, message: "该手机号用户不存在" } };
  }

  const profile = await TeacherProfile.findOne({ where: { user_id: user.user_id } });
  if (!profile) {
    return {
      error: {
        status: 400,
        code: 40091,
        message: "该老师尚未通过平台老师认证，请先完成老师认证"
      }
    };
  }

  return sequelize.transaction(async (transaction) => {
    const [binding, created] = await TeacherStudioBinding.findOrCreate({
      where: { teacher_id: profile.teacher_id, studio_id: studioId },
      defaults: {
        binding_id: generateId(),
        teacher_id: profile.teacher_id,
        studio_id: studioId,
        status: 1,
        bound_at: new Date()
      },
      transaction
    });

    if (!created && Number(binding.status) !== 1) {
      await binding.update({ status: 1, released_at: null, bound_at: new Date() }, { transaction });
    }
    if (!profile.studio_id) {
      await profile.update({ studio_id: studioId }, { transaction });
    }

    const studio = await StudioProfile.findByPk(studioId, {
      attributes: ["studio_id", "name"]
    });

    // 通知老师：被邀请合作
    createNotification({
      userId: user.user_id,
      type: "invite",
      title: "工作室邀请你合作",
      content: `你已被「${studio?.name || "工作室"}」邀请为合作老师`,
      refType: "studio",
      refId: studioId
    }).catch(() => {});

    return {
      data: {
        binding_id: String(binding.binding_id),
        teacher: {
          teacher_id: String(profile.teacher_id),
          user_id: String(profile.user_id),
          real_name: profile.real_name
        },
        studio: studio ? { studio_id: String(studio.studio_id), name: studio.name } : null,
        status: binding.status
      },
      message: created ? "已邀请并建立合作" : "该老师已在合作中"
    };
  });
}

module.exports = {
  getStudioTeachers,
  reviewTeacherApplication,
  releaseTeacher,
  inviteTeacher
};

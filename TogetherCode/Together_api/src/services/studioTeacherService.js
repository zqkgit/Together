const { Op } = require("sequelize");
const dayjs = require("dayjs");
const {
  sequelize,
  TeacherApplication,
  TeacherProfile,
  TeacherStudioBinding,
  UserRole,
  User,
  StudioProfile,
  Course,
  LessonLog,
  Schedule,
  Child
} = require("../models");
const { generateId } = require("../utils/id");
const { createNotification } = require("./messageService");

/**
 * 重新统计工作室「在职合作老师」数量并写回 studio_profiles.teacher_count。
 * 师资数量不再由入驻表单自填，而是按 teacher_studio_bindings 实际绑定数统计。
 */
async function recomputeStudioTeacherCount(studioId, transaction) {
  const [{ total } = { total: 0 }] = await sequelize.query(
    `SELECT COUNT(*) AS total FROM teacher_studio_bindings WHERE studio_id = ? AND status = 1`,
    { replacements: [studioId], type: sequelize.QueryTypes.SELECT, transaction }
  );
  await StudioProfile.update(
    { teacher_count: Number(total) || 0 },
    { where: { studio_id: studioId }, transaction }
  );
}

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
      const studio = await StudioProfile.findByPk(studioId);
      await createNotification({
        userId: application.user_id,
        type: "invite",
        title: "合作申请未通过",
        content: `你向「${studio?.name || "工作室"}」提交的合作申请未通过：${payload.reason.trim()}`,
        refType: "studio",
        refId: studioId
      });

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
    // 合作老师数随绑定变化重新统计
    await recomputeStudioTeacherCount(studioId, transaction);

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
    const studioName = (await StudioProfile.findByPk(studioId))?.name || "工作室";
    await createNotification({
      userId: application.user_id,
      type: "invite",
      title: "合作申请已通过",
      content: `你已成功加入「${studioName}」，可以开始排课与教学了。`,
      refType: "studio",
      refId: studioId
    });

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
    // 合作老师数随解绑变化重新统计
    await recomputeStudioTeacherCount(studioId, transaction);

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
    // 合作老师数随绑定变化重新统计
    await recomputeStudioTeacherCount(studioId, transaction);

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

/**
 * 老师维度的经营统计（App 端「老师管理」用）
 * - students：该老师在**本工作室**带课课程下、有课时账本的学员去重数
 * - month_lessons：本月消课节数，归属老师 = schedule.teacher_id（排课消课）→ 回退 course.teacher_id（手动消课）
 * 注意：课时流水没有 teacher_id 字段，只能按「排课老师优先、课程老师兜底」归属，此处为该业务的既定口径。
 */
async function loadTeacherAggregates(studioId, teacherIds = []) {
  const ids = teacherIds.map((id) => String(id)).filter(Boolean);
  if (!ids.length) {
    return { byTeacher: {}, lessonByTeacher: {}, lessonByCourse: {} };
  }

  const monthStart = dayjs().startOf("month").format("YYYY-MM-DD 00:00:00");
  const monthEnd = dayjs().endOf("month").format("YYYY-MM-DD 23:59:59");

  const [studentRows, lessonRows] = await Promise.all([
    sequelize.query(
      `SELECT c.teacher_id AS teacher_id, COUNT(DISTINCT b.child_id) AS students
         FROM child_course_balances b
         JOIN orders o ON o.order_id = b.order_id AND o.studio_id = :studioId
         JOIN courses c ON c.course_id = b.course_id
        WHERE c.studio_id = :studioId AND c.teacher_id IS NOT NULL
        GROUP BY c.teacher_id`,
      { replacements: { studioId }, type: sequelize.QueryTypes.SELECT }
    ),
    sequelize.query(
      `SELECT COALESCE(s.teacher_id, c.teacher_id) AS teacher_id,
              ll.course_id AS course_id,
              SUM(-ll.delta) AS lessons
         FROM lesson_logs ll
         JOIN courses c ON c.course_id = ll.course_id
    LEFT JOIN schedules s ON s.schedule_id = ll.schedule_id
        WHERE c.studio_id = :studioId
          AND ll.delta < 0
          AND ll.created_at BETWEEN :monthStart AND :monthEnd
        GROUP BY teacher_id, ll.course_id`,
      {
        replacements: { studioId, monthStart, monthEnd },
        type: sequelize.QueryTypes.SELECT
      }
    )
  ]);

  const byTeacher = {};
  const lessonByTeacher = {};
  const lessonByCourse = {};
  for (const row of studentRows) {
    byTeacher[String(row.teacher_id)] = Number(row.students) || 0;
  }
  for (const row of lessonRows) {
    const teacherId = row.teacher_id == null ? "" : String(row.teacher_id);
    const lessons = Number(row.lessons) || 0;
    lessonByTeacher[teacherId] = (lessonByTeacher[teacherId] || 0) + lessons;
    const courseId = String(row.course_id);
    lessonByCourse[courseId] = (lessonByCourse[courseId] || 0) + lessons;
  }
  return { byTeacher, lessonByTeacher, lessonByCourse };
}

/**
 * 工作室 App 端「老师管理」列表
 * summary 恒按工作室全量统计（不受 q 影响），对齐设计稿顶部口径
 */
async function getStudioTeacherRoster(studioId, query = {}) {
  const bindings = await TeacherStudioBinding.findAll({
    where: { studio_id: studioId, status: 1 },
    include: [
      {
        model: TeacherProfile,
        as: "teacher",
        required: true,
        include: [
          { model: User, as: "user", attributes: ["user_id", "phone", "nickname", "avatar"] }
        ]
      }
    ],
    order: [["bound_at", "ASC"]]
  });

  const teacherIds = bindings.map((item) => String(item.teacher?.teacher_id || "")).filter(Boolean);
  const [aggregates, courseCounts, pendingApplications, totalStudents] = await Promise.all([
    loadTeacherAggregates(studioId, teacherIds),
    Course.findAll({
      where: { studio_id: studioId, teacher_id: { [Op.in]: teacherIds.length ? teacherIds : ["0"] } },
      attributes: ["course_id", "teacher_id"],
      raw: true
    }),
    TeacherApplication.count({ where: { studio_id: studioId, status: 0 } }),
    sequelize.query(
      `SELECT COUNT(DISTINCT b.child_id) AS students
         FROM child_course_balances b
         JOIN orders o ON o.order_id = b.order_id
        WHERE o.studio_id = :studioId`,
      { replacements: { studioId }, type: sequelize.QueryTypes.SELECT }
    )
  ]);

  const courseCountByTeacher = {};
  for (const course of courseCounts) {
    const key = String(course.teacher_id);
    courseCountByTeacher[key] = (courseCountByTeacher[key] || 0) + 1;
  }

  let list = bindings.map((item) => {
    const teacher = item.teacher;
    const teacherId = String(teacher.teacher_id);
    return {
      binding_id: String(item.binding_id),
      teacher_id: teacherId,
      user_id: String(teacher.user_id),
      real_name: teacher.real_name,
      nickname: teacher.user?.nickname || teacher.real_name,
      avatar: teacher.user?.avatar || null,
      phone: teacher.user?.phone || "-",
      subjects: teacher.subjects || [],
      years: teacher.years == null ? null : Number(teacher.years),
      intro: teacher.intro,
      cert_no: teacher.cert_no,
      cert_status: Number(teacher.cert_status || 0),
      rating: Number(teacher.rating || 5),
      bound_at: item.bound_at,
      course_count: courseCountByTeacher[teacherId] || 0,
      student_count: aggregates.byTeacher[teacherId] || 0,
      month_lessons: aggregates.lessonByTeacher[teacherId] || 0
    };
  });

  if (query.q) {
    const keyword = String(query.q).trim().toLowerCase();
    list = list.filter((item) => {
      const haystack = [item.real_name, item.nickname, ...(item.subjects || [])]
        .filter(Boolean)
        .join(" ")
        .toLowerCase();
      return haystack.includes(keyword);
    });
  }

  // 活跃老师（本月消课多）在前，其余按加入时间
  list.sort((a, b) => {
    if (b.month_lessons !== a.month_lessons) return b.month_lessons - a.month_lessons;
    return new Date(a.bound_at || 0) - new Date(b.bound_at || 0);
  });

  // 页头「本月消课」= 在职老师合计（与卡片求和一致；不能把非本室老师/无主课程的消课算进来）
  const monthLessons = list.reduce((sum, item) => sum + item.month_lessons, 0);

  return {
    summary: {
      total_teachers: bindings.length,
      total_students: Number(totalStudents?.[0]?.students || 0),
      month_lessons: monthLessons,
      pending_applications: pendingApplications
    },
    total: list.length,
    list
  };
}

/**
 * 工作室 App 端「老师详情」：档案 + 本工作室带课 + 最近消课流水
 */
async function getStudioTeacherDetail(studioId, teacherId) {
  const binding = await TeacherStudioBinding.findOne({
    where: { studio_id: studioId, teacher_id: teacherId, status: 1 },
    include: [
      {
        model: TeacherProfile,
        as: "teacher",
        required: true,
        include: [
          { model: User, as: "user", attributes: ["user_id", "phone", "nickname", "avatar"] }
        ]
      }
    ]
  });

  if (!binding || !binding.teacher) {
    return null;
  }

  const teacher = binding.teacher;
  const courses = await Course.findAll({
    where: { studio_id: studioId, teacher_id: teacher.teacher_id },
    attributes: ["course_id", "title", "cover", "status", "total_lessons", "price"],
    order: [["created_at", "DESC"]]
  });

  const aggregates = await loadTeacherAggregates(studioId, [String(teacher.teacher_id)]);
  const courseIds = courses.map((course) => String(course.course_id));

  // 最近消课流水（按同一归属口径过滤：排课老师优先、课程老师兜底）
  const rawLogs = courseIds.length
    ? await LessonLog.findAll({
        where: { course_id: { [Op.in]: courseIds }, delta: { [Op.lt]: 0 } },
        include: [
          { model: Child, as: "child", attributes: ["child_id", "nickname"] },
          { model: Course, as: "course", attributes: ["course_id", "title"] },
          { model: Schedule, as: "schedule", attributes: ["schedule_id", "teacher_id"] }
        ],
        order: [["created_at", "DESC"]],
        limit: 60
      })
    : [];

  const teacherIdStr = String(teacher.teacher_id);
  const logs = rawLogs
    .filter((log) => {
      const bySchedule = log.schedule?.teacher_id ? String(log.schedule.teacher_id) : null;
      // 排课上有老师 → 以排课老师为准；没有排课（手动消课）→ 归课程老师，即本老师
      return bySchedule ? bySchedule === teacherIdStr : true;
    })
    .slice(0, 20)
    .map((log) => ({
      log_id: String(log.log_id),
      created_at: log.created_at,
      child_id: String(log.child_id),
      child_name: log.child?.nickname || "-",
      course_id: String(log.course_id),
      course_title: log.course?.title || "-",
      delta: Number(log.delta || 0),
      balance_after: Number(log.balance_after || 0),
      note: log.note
    }));

  return {
    teacher: {
      teacher_id: teacherIdStr,
      user_id: String(teacher.user_id),
      binding_id: String(binding.binding_id),
      real_name: teacher.real_name,
      nickname: teacher.user?.nickname || teacher.real_name,
      avatar: teacher.user?.avatar || null,
      phone: teacher.user?.phone || "-",
      subjects: teacher.subjects || [],
      years: teacher.years == null ? null : Number(teacher.years),
      intro: teacher.intro,
      cert_no: teacher.cert_no,
      cert_status: Number(teacher.cert_status || 0),
      rating: Number(teacher.rating || 5),
      bound_at: binding.bound_at,
      studio_id: String(studioId),
      course_count: courses.length,
      student_count: aggregates.byTeacher[teacherIdStr] || 0,
      month_lessons: aggregates.lessonByTeacher[teacherIdStr] || 0
    },
    courses: courses.map((course) => ({
      course_id: String(course.course_id),
      title: course.title,
      cover: course.cover,
      status: Number(course.status || 0),
      total_lessons: Number(course.total_lessons || 0),
      price: Number(course.price || 0),
      student_count: 0,
      month_lessons: aggregates.lessonByCourse[String(course.course_id)] || 0
    })),
    logs
  };
}

/**
 * 工作室 App 端「老师合作申请」列表（status：0 待审 / 1 通过 / 2 驳回；不传或 all 为全部）
 */
async function getStudioTeacherApplications(studioId, status) {
  const where = { studio_id: studioId };
  const normalized = status === undefined || status === null || status === "" || status === "all"
    ? null
    : Number(status);
  if (normalized !== null && !Number.isNaN(normalized)) {
    where.status = normalized;
  }

  const [rows, grouped] = await Promise.all([
    TeacherApplication.findAll({
      where,
      include: [
        {
          model: User,
          as: "user",
          attributes: ["user_id", "phone", "nickname", "avatar"]
        }
      ],
      order: [["submitted_at", "DESC"]]
    }),
    TeacherApplication.findAll({
      where: { studio_id: studioId },
      attributes: ["status", [sequelize.fn("COUNT", sequelize.col("id")), "total"]],
      group: ["status"],
      raw: true
    })
  ]);

  const summary = { pending: 0, approved: 0, rejected: 0, total: 0 };
  for (const row of grouped) {
    const count = Number(row.total) || 0;
    summary.total += count;
    if (Number(row.status) === 0) summary.pending = count;
    if (Number(row.status) === 1) summary.approved = count;
    if (Number(row.status) === 2) summary.rejected = count;
  }

  return {
    summary,
    total: rows.length,
    list: rows.map((item) => ({
      id: String(item.id),
      user_id: String(item.user_id),
      real_name: item.real_name,
      nickname: item.user?.nickname || item.real_name,
      avatar: item.user?.avatar || null,
      phone: item.user?.phone || "-",
      subjects: item.subjects || [],
      years: item.years == null ? null : Number(item.years),
      intro: item.intro,
      cert_no: item.cert_no,
      portfolio: item.portfolio || [],
      status: Number(item.status || 0),
      submitted_at: item.submitted_at,
      reviewed_at: item.reviewed_at,
      review_reason: item.review_reason
    }))
  };
}

module.exports = {
  getStudioTeachers,
  reviewTeacherApplication,
  releaseTeacher,
  inviteTeacher,
  getStudioTeacherRoster,
  getStudioTeacherDetail,
  getStudioTeacherApplications
};

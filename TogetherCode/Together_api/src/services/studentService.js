const { Op } = require("sequelize");
const {
  sequelize,
  Child,
  ChildCourseBalance,
  Order,
  Course,
  LessonLog,
  StudioProfile,
  Schedule,
  Attendance,
  Class,
  TeacherProfile,
  LeaveRequest,
  User
} = require("../models");
const { generateId } = require("../utils/id");
const { createNotification } = require("./messageService");

// 待续费阈值：剩余课时 ≤ 3 视为需要续费（App 学员管理「待续费」口径）
const RENEW_THRESHOLD = 3;

function computeOrderStatus(order, remainingAfter) {
  const refundedLessons = Number(order.refunded_lessons || 0);
  const consumedLessons = Number(order.consumed_lessons || 0);
  const totalLessons = Number(order.total_lessons || 0);
  const consumedAndRefunded = consumedLessons + refundedLessons;

  if (remainingAfter <= 0 || consumedAndRefunded >= totalLessons) {
    return 2;
  }

  if (refundedLessons > 0) {
    return 3;
  }

  return 1;
}

/**
 * 工作室学员行（Web / App 共用底层）
 * 取该工作室有课时余额的学员，保留原始 balances 明细，两端各自裁剪字段
 * @param {number|string} studioId 工作室 id
 * @param {object} query { q 昵称模糊, class_id 班级过滤 }
 */
async function loadStudioStudentRows(studioId, query = {}) {
  if (!studioId) {
    return [];
  }

  const where = {};
  if (query.q) {
    where.nickname = {
      [Op.like]: `%${String(query.q).trim()}%`
    };
  }

  let balanceWhere;
  if (query.class_id) {
    const classItem = await Class.findByPk(query.class_id, {
      attributes: ["class_id", "course_id"]
    });
    if (!classItem) {
      return [];
    }
    balanceWhere = {
      [Op.or]: [
        { class_id: query.class_id },
        { class_id: null, course_id: classItem.course_id }
      ]
    };
  }

  const children = await Child.findAll({
    where,
    include: [
      {
        model: ChildCourseBalance,
        as: "balances",
        required: true,
        where: balanceWhere,
        include: [
          {
            model: Order,
            as: "order",
            required: true,
            where: {
              studio_id: studioId
            },
            include: [
              {
                model: User,
                as: "user",
                attributes: ["user_id", "phone", "nickname"]
              }
            ]
          },
          {
            model: Course,
            as: "course",
            attributes: ["course_id", "title", "cover"]
          }
        ]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  return children.map((child) => {
    const balances = (child.balances || []).map((balance) => ({
      balance_id: String(balance.balance_id),
      order_id: String(balance.order_id),
      course_id: String(balance.course_id),
      course_title: balance.course?.title || "-",
      course_cover: balance.course?.cover || null,
      total_lessons: balance.total_lessons,
      consumed_lessons: balance.consumed_lessons,
      refunded_lessons: balance.refunded_lessons,
      remaining_lessons: balance.remaining_lessons,
      valid_from: balance.valid_from,
      parent: balance.order?.user
        ? {
            user_id: String(balance.order.user.user_id),
            phone: balance.order.user.phone,
            nickname: balance.order.user.nickname
          }
        : null,
      order_created_at: balance.order ? balance.order.created_at : null,
      order_paid_at: balance.order ? balance.order.paid_at : null,
      valid_to: balance.valid_to,
      status: balance.status
    }));

    const totalRemaining = balances.reduce((sum, item) => sum + Number(item.remaining_lessons || 0), 0);
    const totalLessons = balances.reduce((sum, item) => sum + Number(item.total_lessons || 0), 0);
    const consumedLessons = balances.reduce((sum, item) => sum + Number(item.consumed_lessons || 0), 0);
    // 报名时间：本工作室最早一笔订单的支付时间（无支付时间时退化为下单时间）
    const enrolledAt =
      balances
        .map((item) => item.order_paid_at || item.order_created_at)
        .filter(Boolean)
        .map((value) => new Date(value))
        .filter((value) => !Number.isNaN(value.getTime()))
        .sort((a, b) => a - b)[0] || null;

    return {
      child_id: String(child.child_id),
      nickname: child.nickname,
      avatar: child.avatar || null,
      birthday: child.birthday,
      gender: child.gender,
      total_remaining_lessons: totalRemaining,
      total_lessons: totalLessons,
      consumed_lessons: consumedLessons,
      enrolled_at: enrolledAt,
      status: totalRemaining > 0 ? "active" : "empty",
      balances
    };
  });
}

/**
 * 工作室后台（Web）学员列表
 * query: { studio_id 必填, q 昵称模糊, class_id 班级过滤, status active|empty|all 课时状态 }
 */
async function listStudioStudents(query = {}) {
  const rows = await loadStudioStudentRows(query.studio_id, query);

  let list = rows;
  if (query.status && query.status !== "all") {
    list = list.filter((item) => item.status === query.status);
  }

  return {
    total: list.length,
    list
  };
}

// ---------- 工作室 App 端「学员管理」 ----------

/** 生日 → 周岁（整数，取不到返回 null） */
function computeAge(birthday) {
  if (!birthday) {
    return null;
  }
  const birth = new Date(birthday);
  if (Number.isNaN(birth.getTime())) {
    return null;
  }
  const now = new Date();
  let age = now.getFullYear() - birth.getFullYear();
  const monthDiff = now.getMonth() - birth.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < birth.getDate())) {
    age -= 1;
  }
  return age >= 0 ? age : null;
}

/** 手机号打码（家长无昵称时的兜底展示） */
function maskPhone(phone) {
  const value = String(phone || "").trim();
  if (value.length < 7) {
    return value;
  }
  return `${value.slice(0, 3)}****${value.slice(-4)}`;
}

/** 主推课程：最近一笔订单对应的课程；报多门时由前端拼「等 N 门」 */
function pickLatestBalance(balances = []) {
  const time = (item) => (item.order_created_at ? new Date(item.order_created_at).getTime() : 0);
  return (
    [...balances].sort((a, b) => {
      const diff = time(b) - time(a);
      // 同一订单时间（一次买多门）时用 balance_id 兜底，保证每次结果稳定
      return diff !== 0 ? diff : String(b.balance_id).localeCompare(String(a.balance_id));
    })[0] || null
  );
}

/**
 * 学员行 → App 列表/详情通用结构
 * renew：剩余课时 ≤ RENEW_THRESHOLD（含耗尽）；is_new：本月首次报名
 */
function decorateStudentForApp(row) {
  const remaining = Number(row.total_remaining_lessons || 0);
  const latest = pickLatestBalance(row.balances);
  const enrolledAt = row.enrolled_at ? new Date(row.enrolled_at) : null;
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const isNew = Boolean(enrolledAt && enrolledAt >= monthStart);
  const parent = latest?.parent || null;

  return {
    child_id: row.child_id,
    nickname: row.nickname,
    avatar: row.avatar,
    gender: row.gender,
    age: computeAge(row.birthday),
    birthday: row.birthday,
    course_title: latest?.course_title || "",
    course_count: (row.balances || []).length,
    parent_name: (parent?.nickname || "").trim() || maskPhone(parent?.phone),
    parent_phone: parent?.phone || "",
    remaining_lessons: remaining,
    total_lessons: Number(row.total_lessons || 0),
    consumed_lessons: Number(row.consumed_lessons || 0),
    renew: remaining <= RENEW_THRESHOLD,
    is_new: isNew,
    enrolled_at: row.enrolled_at,
    status: remaining <= RENEW_THRESHOLD ? "renew" : "active"
  };
}

/**
 * 工作室 App「学员管理」列表
 * summary 恒按工作室全量学员统计（不受筛选/搜索影响），与设计稿「全部/待续费/本月新增」口径一致
 * @param {object} query { filter all|renew|new, q 昵称/家长模糊, class_id 班级过滤 }
 */
async function listStudioStudentsForApp(studioId, query = {}) {
  // 全量拉取（不把搜索词下推到 SQL），以便 chips 统计口径稳定
  const rows = await loadStudioStudentRows(studioId, { class_id: query.class_id });
  const items = rows.map(decorateStudentForApp);

  const summary = {
    all: items.length,
    renew: items.filter((item) => item.renew).length,
    new: items.filter((item) => item.is_new).length
  };

  let list = items;
  const filter = query.filter || "all";
  if (filter === "renew") {
    list = list.filter((item) => item.renew);
  } else if (filter === "new") {
    list = list.filter((item) => item.is_new);
  }

  const keyword = String(query.q || "").trim();
  if (keyword) {
    list = list.filter(
      (item) => (item.nickname || "").includes(keyword) || (item.parent_name || "").includes(keyword)
    );
  }

  return { summary, total: list.length, list };
}

/**
 * 工作室 App「学员详情」：学员信息 + 各课程课时余额 + 课时流水
 * 学员不属于本工作室时返回 null
 */
async function getStudioStudentDetailForApp(childId, studioId) {
  const rows = await loadStudioStudentRows(studioId, {});
  const row = rows.find((item) => String(item.child_id) === String(childId));
  if (!row) {
    return null;
  }

  const logs = await listStudentLessonLogs(childId, studioId, { limit: 50 });

  return {
    student: decorateStudentForApp(row),
    balances: (row.balances || []).map((balance) => ({
      balance_id: balance.balance_id,
      order_id: balance.order_id,
      course_id: balance.course_id,
      course_title: balance.course_title,
      course_cover: balance.course_cover,
      total_lessons: Number(balance.total_lessons || 0),
      consumed_lessons: Number(balance.consumed_lessons || 0),
      remaining_lessons: Number(balance.remaining_lessons || 0),
      valid_from: balance.valid_from,
      valid_to: balance.valid_to,
      order_created_at: balance.order_created_at
    })),
    logs: logs ? logs.list : []
  };
}

async function loadOrderContext(childId, orderId, transaction) {
  const order = await Order.findOne({
    where: {
      order_id: orderId,
      child_id: childId
    },
    include: [
      {
        model: StudioProfile,
        as: "studio",
        attributes: ["studio_id", "name"]
      },
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "title"]
      },
      {
        model: Child,
        as: "child",
        attributes: ["child_id", "nickname", "birthday", "parent_user_id"]
      }
    ],
    transaction,
    lock: transaction.LOCK.UPDATE
  });

  if (!order) {
    return null;
  }

  const balance = await ChildCourseBalance.findOne({
    where: { order_id: order.order_id },
    transaction,
    lock: transaction.LOCK.UPDATE
  });

  if (!balance) {
    throw new Error("Course balance not found");
  }

  return {
    order,
    balance
  };
}

// 所有消课入口最终都走这条账本函数，保证订单、余额、lesson_log 三处始终同事务更新。
async function applyLessonConsumptionWithTransaction(childId, payload, options = {}, transaction) {
  const count = Number(payload.count || 1);

  const context = await loadOrderContext(childId, payload.order_id, transaction);
  if (!context) {
    return null;
  }

  const { order, balance } = context;
  if (![1, 3].includes(Number(order.status))) {
    throw new Error("Order is not available for lesson consumption");
  }

  const remaining = Number(balance.remaining_lessons || 0);
  if (count > remaining) {
    throw new Error("Consumed lessons exceed remaining lessons");
  }

  const nextConsumed = Number(order.consumed_lessons || 0) + count;
  const remainingAfter = remaining - count;
  const nextOrderStatus = computeOrderStatus(
    {
      ...order.toJSON(),
      consumed_lessons: nextConsumed
    },
    remainingAfter
  );

  await order.update(
    {
      consumed_lessons: nextConsumed,
      status: nextOrderStatus,
      completed_at: remainingAfter === 0 ? new Date() : order.completed_at
    },
    { transaction }
  );

  await balance.update(
    {
      consumed_lessons: Number(balance.consumed_lessons || 0) + count,
      remaining_lessons: remainingAfter,
      status: remainingAfter === 0 ? 2 : 1
    },
    { transaction }
  );

  await LessonLog.create(
    {
      log_id: generateId(),
      child_id: order.child_id,
      course_id: order.course_id,
      order_id: order.order_id,
      post_id: options.postId || null,
      schedule_id: options.scheduleId || null,
      source: options.source || 3,
      type: options.type || 2,
      delta: -count,
      balance_after: remainingAfter,
      note: payload.note || options.defaultNote || "工作室后台手动消课"
    },
    { transaction }
  );

  if (options.attendanceStatus) {
    await Attendance.upsert(
      {
        attendance_id: options.attendanceId || generateId(),
        schedule_id: options.scheduleId,
        child_id: order.child_id,
        order_id: order.order_id,
        status: options.attendanceStatus,
        note: payload.note || options.defaultNote || null
      },
      { transaction }
    );

    // 闭环：出勤签到 → 通知家长（老师发帖场景已有 growth 通知，此处跳过避免重复）
    if (Number(options.attendanceStatus) === 1 && !options.postId && order.child?.parent_user_id) {
      createNotification({
        userId: order.child.parent_user_id,
        type: "attendance",
        title: "上课签到",
        content: `${order.child.nickname || "孩子"}已完成《${order.course?.title || "课程"}》${count} 课时，剩余 ${remainingAfter} 课时。`,
        refType: null,
        refId: null
      }).catch(() => {});
    }
  }

  return {
    child_id: String(order.child_id),
    order_id: String(order.order_id),
    studio: {
      studio_id: String(order.studio.studio_id),
      name: order.studio.name
    },
    child: {
      child_id: String(order.child.child_id),
      nickname: order.child.nickname,
      birthday: order.child.birthday
    },
    course: {
      course_id: String(order.course.course_id),
      title: order.course.title
    },
    consumed_count: count,
    remaining_lessons: remainingAfter,
    order_status: nextOrderStatus,
    schedule_id: options.scheduleId ? String(options.scheduleId) : null
  };
}

async function applyLessonConsumption(childId, payload, options = {}) {
  if (options.transaction) {
    return applyLessonConsumptionWithTransaction(childId, payload, options, options.transaction);
  }

  return sequelize.transaction(async (transaction) => {
    return applyLessonConsumptionWithTransaction(childId, payload, options, transaction);
  });
}

/**
 * 撤销出勤消课：请假切换时恢复课时与余额，删除该排课的消课流水
 */
async function reverseLessonConsumption(childId, payload, options = {}) {
  const { transaction, scheduleId } = options;
  if (!scheduleId) {
    return null;
  }

  const log = await LessonLog.findOne({
    where: {
      schedule_id: scheduleId,
      child_id: childId,
      source: 2
    },
    transaction,
    lock: transaction.LOCK.UPDATE
  });
  if (!log) {
    return null;
  }

  const context = await loadOrderContext(childId, log.order_id, transaction);
  if (!context) {
    return null;
  }
  const { order, balance } = context;

  const count = 1;
  const remaining = Number(balance.remaining_lessons || 0);
  const consumed = Number(balance.consumed_lessons || 0);

  await balance.update(
    {
      consumed_lessons: Math.max(0, consumed - count),
      remaining_lessons: remaining + count,
      status: 1
    },
    { transaction }
  );

  const nextConsumed = Math.max(0, Number(order.consumed_lessons || 0) - count);
  const remainingAfter = remaining + count;
  const nextOrderStatus = computeOrderStatus(
    {
      ...order.toJSON(),
      consumed_lessons: nextConsumed
    },
    remainingAfter
  );
  await order.update(
    {
      consumed_lessons: nextConsumed,
      status: nextOrderStatus,
      completed_at: null
    },
    { transaction }
  );

  await log.destroy({ transaction });

  return {
    child_id: String(order.child_id),
    order_id: String(order.order_id),
    remaining_lessons: remainingAfter,
    schedule_id: String(scheduleId)
  };
}

async function consumeStudentLessons(childId, payload) {
  return applyLessonConsumption(childId, payload, {
    source: 3,
    type: 2,
    defaultNote: "工作室后台手动消课"
  });
}

async function listClassStudents(classId, query = {}) {
  const classItem = await Class.findByPk(classId, {
    include: [
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "studio_id", "title", "duration_min"]
      },
      {
        model: TeacherProfile,
        as: "teacher",
        attributes: ["teacher_id", "real_name"]
      }
    ]
  });

  if (!classItem) {
    return null;
  }

  const balances = await ChildCourseBalance.findAll({
    where: {
      // 优先按班级精确匹配（报名绑定班级）；存量无班级记录回退到课程级
      [Op.or]: [
        { class_id: String(classItem.class_id) },
        { class_id: null, course_id: classItem.course_id }
      ],
      status: {
        [Op.in]: [1, 2]
      }
    },
    include: [
      {
        model: Child,
        as: "child",
        attributes: ["child_id", "nickname", "birthday", "gender"]
      },
      {
        model: Order,
        as: "order",
        required: true,
        where: {
          studio_id: classItem.course.studio_id
        },
        attributes: ["order_id", "status"]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  // 已消课学生 + 出勤状态 + 请假状态（该排课，用于 web 出勤弹窗回显，避免重复提交）
  let consumedSet = new Set();
  const attendanceMap = new Map();
  const leaveMap = new Map();
  if (query.schedule_id) {
    const logs = await LessonLog.findAll({
      where: {
        schedule_id: query.schedule_id,
        source: 2
      },
      attributes: ["child_id"]
    });
    consumedSet = new Set(logs.map((item) => String(item.child_id)));

    const attendances = await Attendance.findAll({
      where: {
        schedule_id: query.schedule_id
      },
      attributes: ["child_id", "status"]
    });
    attendances.forEach((item) => {
      attendanceMap.set(String(item.child_id), Number(item.status));
    });

    // 请假状态：0无 1待处理 2已同意 3已婉拒（映射 LeaveRequest.status 0→1 1→2 2→3）
    const leaves = await LeaveRequest.findAll({
      where: {
        schedule_id: query.schedule_id,
        status: { [Op.in]: [0, 1, 2] }
      },
      attributes: ["leave_id", "child_id", "status", "reason"]
    });
    leaves.forEach((item) => {
      leaveMap.set(String(item.child_id), {
        leave_status: Number(item.status) + 1,
        leave_id: String(item.leave_id),
        leave_reason: item.reason || null
      });
    });
  }

  // 按孩子去重：同一孩子多份权益（历史重复报名/测试数据）只保留最新一条，避免花名册重复
  const seen = new Set();
  const deduped = [];
  for (const balance of balances) {
    const key = String(balance.child.child_id);
    if (seen.has(key)) continue;
    seen.add(key);
    deduped.push(balance);
  }

  return {
    class: normalizeClassPayload(classItem),
    total: deduped.length,
    list: deduped.map((balance) => ({
      child_id: String(balance.child.child_id),
      nickname: balance.child.nickname,
      birthday: balance.child.birthday,
      gender: balance.child.gender,
      order_id: String(balance.order_id),
      remaining_lessons: balance.remaining_lessons,
      consumed_lessons: balance.consumed_lessons,
      refunded_lessons: balance.refunded_lessons,
      total_lessons: balance.total_lessons,
      balance_status: balance.status,
      order_status: balance.order.status,
      consumed: consumedSet.has(String(balance.child.child_id)),
      attendance_status: attendanceMap.get(String(balance.child.child_id)) || null,
      leave_status: leaveMap.get(String(balance.child.child_id))?.leave_status || 0,
      leave_id: leaveMap.get(String(balance.child.child_id))?.leave_id || null,
      leave_reason: leaveMap.get(String(balance.child.child_id))?.leave_reason || null
    }))
  };
}

function normalizeClassPayload(classItem) {
  return {
    class_id: String(classItem.class_id),
    course_id: String(classItem.course_id),
    teacher_id: classItem.teacher_id ? String(classItem.teacher_id) : null,
    name: classItem.name,
    schedule_rule: classItem.schedule_rule,
    start_date: classItem.start_date,
    end_date: classItem.end_date,
    capacity: classItem.capacity,
    enrolled: classItem.enrolled,
    course: classItem.course
      ? {
          course_id: String(classItem.course.course_id),
          title: classItem.course.title,
          duration_min: classItem.course.duration_min
        }
      : null,
    teacher: classItem.teacher
      ? {
          teacher_id: String(classItem.teacher.teacher_id),
          real_name: classItem.teacher.real_name
        }
      : null
  };
}

// 补课排课出勤消课成功后：标记对应请假单补课已完成 + 通知家长
async function markMakeupCompleted(schedule, childId, transaction) {
  if (!schedule.is_makeup) return null;
  const leave = await LeaveRequest.findOne({
    where: {
      child_id: childId,
      makeup_schedule_id: schedule.schedule_id,
      status: 1,
      makeup_status: 0
    },
    transaction,
    lock: transaction.LOCK.UPDATE
  });
  if (!leave) return null;

  await leave.update({ makeup_status: 1 }, { transaction });

  if (leave.parent_user_id) {
    createNotification({
      userId: leave.parent_user_id,
      type: "leave",
      title: "补课已完成",
      content: `${schedule.lesson_date || ""} ${schedule.start_time || ""}-${schedule.end_time || ""} 的补课已完成，课时已消耗`,
      refType: "leave",
      refId: leave.leave_id
    }).catch(() => {});
  }
  return leave;
}

// 补课排课撤销出勤：请假单补课状态改回「已安排未完成」
async function resetMakeupStatus(schedule, childId, transaction) {
  if (!schedule.is_makeup) return null;
  const leave = await LeaveRequest.findOne({
    where: {
      child_id: childId,
      makeup_schedule_id: schedule.schedule_id,
      status: 1,
      makeup_status: 1
    },
    transaction,
    lock: transaction.LOCK.UPDATE
  });
  if (!leave) return null;
  await leave.update({ makeup_status: 0 }, { transaction });
  return leave;
}

async function attendSchedule(scheduleId, payload) {
  return sequelize.transaction(async (transaction) => {
    const schedule = await Schedule.findByPk(scheduleId, {
      include: [
        {
          model: Class,
          as: "classItem",
          attributes: ["class_id", "name", "course_id"]
        }
      ],
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!schedule) {
      return null;
    }

    const results = [];
    for (const item of payload.students) {
      const status = Number(item.status);
      // 出勤/消课动作：1 消课 / 3 请假（撤销消课+记考勤，兼容旧）/ 4 撤销消课（不记考勤）
      if (![1, 3, 4].includes(status)) {
        throw new Error("Invalid attendance status");
      }

      // 班级归属强校验：消课/请假扣课时必须落在排课所属班级+课程的有效订单上（防跨班消课）
      if (status === 1 || status === 3) {
        let order = null;
        if (item.order_id) {
          order = await Order.findByPk(item.order_id, {
            transaction,
            lock: transaction.LOCK.UPDATE
          });
          if (
            !order ||
            String(order.class_id || "") !== String(schedule.class_id || "") ||
            String(order.course_id || "") !== String(schedule.course_id || "")
          ) {
            throw new Error("Student order does not belong to this class");
          }
        } else {
          order = await Order.findOne({
            where: {
              child_id: item.child_id,
              class_id: schedule.class_id,
              course_id: schedule.course_id,
              status: [1, 3]
            },
            transaction,
            lock: transaction.LOCK.UPDATE
          });
          if (!order) {
            throw new Error("Student has no active order in this class");
          }
          item.order_id = order.order_id;
        }
      }

      const existingAttendance = await Attendance.findOne({
        where: {
          schedule_id: schedule.schedule_id,
          child_id: item.child_id
        },
        transaction,
        lock: transaction.LOCK.UPDATE
      });

      const existingConsumption = await LessonLog.findOne({
        where: {
          schedule_id: schedule.schedule_id,
          child_id: item.child_id,
          source: 2
        },
        transaction,
        lock: transaction.LOCK.UPDATE
      });

      if (status === 1) {
        // 正常出勤：未消课才消课；已消课幂等跳过
        if (!existingConsumption) {
          const consumed = await applyLessonConsumption(item.child_id, item, {
            transaction,
            scheduleId: schedule.schedule_id,
            source: 2,
            type: schedule.is_makeup ? 3 : 1,
            attendanceStatus: 1,
            attendanceId: existingAttendance?.attendance_id,
            defaultNote: item.note || payload.note || (schedule.is_makeup ? "按补课排课出勤消课" : "按排课出勤消课")
          });
          if (!consumed) {
            throw new Error("Student order not found");
          }

          // 补课排课出勤 → 标记对应请假单补课已完成 + 通知家长
          await markMakeupCompleted(schedule, item.child_id, transaction);

          results.push({
            child_id: String(item.child_id),
            order_id: String(item.order_id),
            attendance_status: 1,
            remaining_lessons: consumed.remaining_lessons,
            reverted: false
          });
        } else {
          results.push({
            child_id: String(item.child_id),
            order_id: String(item.order_id),
            attendance_status: 1,
            remaining_lessons: null,
            reverted: false
          });
        }

        await Attendance.upsert(
          {
            attendance_id: existingAttendance?.attendance_id || generateId(),
            schedule_id: schedule.schedule_id,
            child_id: item.child_id,
            order_id: item.order_id,
            status: 1,
            note: item.note || payload.note || null
          },
          { transaction }
        );
        continue;
      }

      // 撤销消课（仅消课管理，不记考勤）
      if (status === 4) {
        let reverted = false;
        if (existingConsumption) {
          const revertedResult = await reverseLessonConsumption(item.child_id, item, {
            transaction,
            scheduleId: schedule.schedule_id
          });
          reverted = Boolean(revertedResult);
          // 补课排课撤销出勤 → 对应请假单补课状态改回「已安排未完成」
          if (reverted && schedule.is_makeup) {
            await resetMakeupStatus(schedule, item.child_id, transaction);
          }
        }
        results.push({
          child_id: String(item.child_id),
          order_id: String(item.order_id),
          attendance_status: null,
          remaining_lessons: null,
          reverted
        });
        continue;
      }

      // 请假：已消课则撤销消课（恢复课时），再记请假出勤
      let reverted = false;
      if (existingConsumption) {
        const revertedResult = await reverseLessonConsumption(item.child_id, item, {
          transaction,
          scheduleId: schedule.schedule_id
        });
        reverted = Boolean(revertedResult);
      }

      await Attendance.upsert(
        {
          attendance_id: existingAttendance?.attendance_id || generateId(),
          schedule_id: schedule.schedule_id,
          child_id: item.child_id,
          order_id: item.order_id,
          status: 3,
          note: item.note || payload.note || null
        },
        { transaction }
      );

      results.push({
        child_id: String(item.child_id),
        order_id: String(item.order_id),
        attendance_status: 3,
        remaining_lessons: null,
        reverted
      });
    }

    return {
      schedule_id: String(schedule.schedule_id),
      class_id: String(schedule.class_id),
      processed_count: results.length,
      list: results
    };
  });
}

/**
 * 工作室侧：学员课时流水（消课记录）
 * 校验该学员属于本工作室（存在本工作室订单/余额），返回 lesson_logs 明细
 */
async function listStudentLessonLogs(childId, studioId, query = {}) {
  const child = await Child.findOne({
    where: { child_id: childId },
    include: [
      {
        model: ChildCourseBalance,
        as: "balances",
        required: true,
        where: query.class_id ? { class_id: query.class_id } : undefined,
        include: [
          {
            model: Order,
            as: "order",
            required: true,
            where: { studio_id: studioId },
            attributes: ["order_id", "status"]
          }
        ]
      }
    ]
  });

  if (!child) {
    return null;
  }

  const rows = await LessonLog.findAll({
    where: {
      child_id: childId,
      ...(query.course_id ? { course_id: query.course_id } : {})
    },
    include: [
      { model: Course, as: "course", attributes: ["course_id", "title"] },
      {
        model: Schedule,
        as: "schedule",
        attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location", "is_makeup"]
      },
      {
        model: Order,
        as: "order",
        attributes: ["order_id", "studio_id"],
        include: [{ model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] }]
      }
    ],
    order: [["created_at", "DESC"]],
    limit: Math.min(Number(query.limit) || 50, 200),
    offset: Number(query.offset) || 0
  });

  return {
    child_id: String(child.child_id),
    nickname: child.nickname,
    birthday: child.birthday,
    total: rows.length,
    list: rows.map((item) => ({
      log_id: String(item.log_id),
      course_id: String(item.course_id),
      course_title: item.course ? item.course.title : "-",
      order_id: String(item.order_id),
      schedule_id: item.schedule_id ? String(item.schedule_id) : null,
      lesson_date: item.schedule ? item.schedule.lesson_date : null,
      start_time: item.schedule ? item.schedule.start_time : null,
      end_time: item.schedule ? item.schedule.end_time : null,
      is_makeup: item.schedule ? Boolean(item.schedule.is_makeup) : false,
      source: Number(item.source),
      type: Number(item.type),
      delta: Number(item.delta),
      balance_after: Number(item.balance_after),
      note: item.note,
      created_at: item.created_at
    }))
  };
}

module.exports = {
  listStudioStudents,
  listStudioStudentsForApp,
  getStudioStudentDetailForApp,
  consumeStudentLessons,
  listClassStudents,
  attendSchedule,
  applyLessonConsumption,
  resetMakeupStatus,
  listStudentLessonLogs
};

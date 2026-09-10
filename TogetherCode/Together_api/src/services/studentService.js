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
  TeacherProfile
} = require("../models");
const { generateId } = require("../utils/id");

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

async function listStudioStudents(query = {}) {
  const where = {};
  if (query.q) {
    where.nickname = {
      [Op.like]: `%${query.q.trim()}%`
    };
  }

  const children = await Child.findAll({
    where,
    include: [
      {
        model: ChildCourseBalance,
        as: "balances",
        required: true,
        include: [
          {
            model: Order,
            as: "order",
            required: true,
            where: {
              studio_id: query.studio_id
            }
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

  let list = children.map((child) => {
    const balances = (child.balances || []).map((balance) => ({
      balance_id: String(balance.balance_id),
      order_id: String(balance.order_id),
      course_id: String(balance.course_id),
      course_title: balance.course?.title || "-",
      total_lessons: balance.total_lessons,
      consumed_lessons: balance.consumed_lessons,
      refunded_lessons: balance.refunded_lessons,
      remaining_lessons: balance.remaining_lessons,
      valid_from: balance.valid_from,
      valid_to: balance.valid_to,
      status: balance.status
    }));

    const totalRemaining = balances.reduce((sum, item) => sum + Number(item.remaining_lessons || 0), 0);

    return {
      child_id: String(child.child_id),
      nickname: child.nickname,
      birthday: child.birthday,
      gender: child.gender,
      total_remaining_lessons: totalRemaining,
      status: totalRemaining > 0 ? "active" : "empty",
      balances
    };
  });

  if (query.status && query.status !== "all") {
    list = list.filter((item) => item.status === query.status);
  }

  return {
    total: list.length,
    list
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
        attributes: ["child_id", "nickname", "birthday"]
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
      course_id: classItem.course_id,
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

  return {
    class: normalizeClassPayload(classItem),
    total: balances.length,
    list: balances.map((balance) => ({
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
      order_status: balance.order.status
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

      if (existingConsumption) {
        throw new Error("Attendance already consumed for this student");
      }

      if (status === 1) {
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

        results.push({
          child_id: String(item.child_id),
          order_id: String(item.order_id),
          attendance_status: 1,
          remaining_lessons: consumed.remaining_lessons
        });
        continue;
      }

      if (existingAttendance && Number(existingAttendance.status) === 1) {
        throw new Error("Attendance already consumed and cannot be changed");
      }

      await Attendance.upsert(
        {
          attendance_id: existingAttendance?.attendance_id || generateId(),
          schedule_id: schedule.schedule_id,
          child_id: item.child_id,
          order_id: item.order_id,
          status,
          note: item.note || payload.note || null
        },
        { transaction }
      );

      results.push({
        child_id: String(item.child_id),
        order_id: String(item.order_id),
        attendance_status: status,
        remaining_lessons: null
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
      child_id: childId
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
  consumeStudentLessons,
  listClassStudents,
  attendSchedule,
  applyLessonConsumption,
  listStudentLessonLogs
};

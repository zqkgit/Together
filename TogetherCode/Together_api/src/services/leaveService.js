const { Op } = require("sequelize");
const {
  sequelize,
  LeaveRequest,
  Class,
  Child,
  User,
  Schedule,
  Course,
  ChildCourseBalance,
  Order,
  Attendance,
  LessonLog,
  TeacherProfile
} = require("../models");
const { generateId } = require("../utils/id");
const { createNotification } = require("./messageService");

function normalizeLeaveItem(item) {
  return {
    leave_id: String(item.leave_id),
    class_id: String(item.class_id),
    child_id: String(item.child_id),
    parent_user_id: String(item.parent_user_id),
    schedule_id: item.schedule_id ? String(item.schedule_id) : null,
    reason: item.reason,
    status: item.status,
    handled_at: item.handled_at,
    makeup_status: item.makeup_status,
    makeup_schedule_id: item.makeup_schedule_id ? String(item.makeup_schedule_id) : null,
    child: item.child
      ? {
          child_id: String(item.child.child_id),
          nickname: item.child.nickname,
          birthday: item.child.birthday
        }
      : null,
    parent: item.parent
      ? {
          user_id: String(item.parent.user_id),
          phone: item.parent.phone,
          nickname: item.parent.nickname
        }
      : null,
    class: item.classItem
      ? {
          class_id: String(item.classItem.class_id),
          name: item.classItem.name
        }
      : null,
    schedule: item.schedule
      ? {
          schedule_id: String(item.schedule.schedule_id),
          lesson_date: item.schedule.lesson_date,
          start_time: item.schedule.start_time,
          end_time: item.schedule.end_time,
          location: item.schedule.location
        }
      : null,
    makeup_schedule: item.makeupSchedule
      ? {
          schedule_id: String(item.makeupSchedule.schedule_id),
          lesson_date: item.makeupSchedule.lesson_date,
          start_time: item.makeupSchedule.start_time,
          end_time: item.makeupSchedule.end_time,
          location: item.makeupSchedule.location
        }
      : null
  };
}

// 请假、审批、补课三个动作都依赖同一份班级上下文，统一收口能避免各处重复校验。
async function ensureClassContext(classId, transaction) {
  const classItem = await Class.findByPk(classId, {
    include: [
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "studio_id", "title"]
      }
    ],
    transaction
  });

  if (!classItem) {
    throw new Error("Class not found");
  }

  return classItem;
}

async function ensureChildOwnership(childId, parentUserId, transaction) {
  const child = await Child.findOne({
    where: {
      child_id: childId,
      parent_user_id: parentUserId
    },
    transaction
  });

  if (!child) {
    throw new Error("Child not found");
  }

  return child;
}

async function ensureScheduleBelongsToClass(scheduleId, classId, transaction) {
  if (!scheduleId) {
    return null;
  }

  const schedule = await Schedule.findByPk(scheduleId, { transaction });
  if (!schedule) {
    throw new Error("Schedule not found");
  }
  if (String(schedule.class_id) !== String(classId)) {
    throw new Error("Schedule does not belong to class");
  }

  return schedule;
}

async function ensureEnrollment(childId, classItem, transaction) {
  const balance = await ChildCourseBalance.findOne({
    where: {
      child_id: childId,
      course_id: classItem.course_id,
      status: {
        [Op.in]: [1, 2]
      }
    },
    include: [
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
    order: [["created_at", "DESC"]],
    transaction,
    lock: transaction ? transaction.LOCK.UPDATE : undefined
  });

  if (!balance) {
    throw new Error("Student is not enrolled in class course");
  }

  return balance;
}

async function submitLeaveRequest(parentUserId, payload) {
  return sequelize.transaction(async (transaction) => {
    const classItem = await ensureClassContext(payload.class_id, transaction);
    await ensureChildOwnership(payload.child_id, parentUserId, transaction);
    await ensureEnrollment(payload.child_id, classItem, transaction);
    await ensureScheduleBelongsToClass(payload.schedule_id, payload.class_id, transaction);

    const duplicateWhere = {
      class_id: payload.class_id,
      child_id: payload.child_id,
      parent_user_id: parentUserId,
      status: {
        [Op.in]: [0, 1]
      }
    };

    if (payload.schedule_id) {
      duplicateWhere.schedule_id = payload.schedule_id;
    }

    const duplicate = await LeaveRequest.findOne({
      where: duplicateWhere,
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (duplicate) {
      throw new Error("Leave request already exists");
    }

    const leave = await LeaveRequest.create(
      {
        leave_id: generateId(),
        class_id: payload.class_id,
        child_id: payload.child_id,
        parent_user_id: parentUserId,
        schedule_id: payload.schedule_id || null,
        reason: payload.reason,
        status: 0,
        makeup_status: 0,
        makeup_schedule_id: null
      },
      { transaction }
    );

    const row = await LeaveRequest.findByPk(leave.leave_id, {
      transaction,
      include: [
        { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
        { model: User, as: "parent", attributes: ["user_id", "phone", "nickname"] },
        { model: Class, as: "classItem", attributes: ["class_id", "name"] },
        {
          model: Schedule,
          as: "schedule",
          attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
        }
      ]
    });

    return normalizeLeaveItem(row);
  });
}

async function listMyLeaveRequests(parentUserId, query = {}) {
  const where = {
    parent_user_id: parentUserId
  };

  if (query.status !== undefined && query.status !== null && query.status !== "") {
    where.status = Number(query.status);
  }

  const rows = await LeaveRequest.findAll({
    where,
    include: [
      { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
      { model: User, as: "parent", attributes: ["user_id", "phone", "nickname"] },
      { model: Class, as: "classItem", attributes: ["class_id", "name"] },
      {
        model: Schedule,
        as: "schedule",
        attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
      },
      {
        model: Schedule,
        as: "makeupSchedule",
        attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  return {
    total: rows.length,
    list: rows.map(normalizeLeaveItem)
  };
}

async function listStudioLeaveRequests(query = {}) {
  const where = {};

  if (query.status !== undefined && query.status !== null && query.status !== "") {
    where.status = Number(query.status);
  }
  if (query.child_id) {
    where.child_id = query.child_id;
  }
  if (query.class_id) {
    where.class_id = query.class_id;
  }

  const rows = await LeaveRequest.findAll({
    where,
    include: [
      {
        model: Class,
        as: "classItem",
        required: true,
        attributes: ["class_id", "name"],
        include: [
          {
            model: Course,
            as: "course",
            required: true,
            where: {
              studio_id: query.studio_id
            },
            attributes: ["course_id", "title", "studio_id"]
          }
        ]
      },
      { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
      { model: User, as: "parent", attributes: ["user_id", "phone", "nickname"] },
      {
        model: Schedule,
        as: "schedule",
        attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
      },
      {
        model: Schedule,
        as: "makeupSchedule",
        attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  return {
    total: rows.length,
    list: rows.map(normalizeLeaveItem)
  };
}

async function reviewLeaveRequest(leaveId, payload) {
  return sequelize.transaction(async (transaction) => {
    const leave = await LeaveRequest.findByPk(leaveId, {
      include: [
        {
          model: Class,
          as: "classItem",
          attributes: ["class_id", "name", "course_id"],
          include: [
            {
              model: Course,
              as: "course",
              attributes: ["course_id", "studio_id", "title"]
            }
          ]
        },
        { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
        { model: User, as: "parent", attributes: ["user_id", "phone", "nickname"] },
        {
          model: Schedule,
          as: "schedule",
          attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
        },
        {
          model: Schedule,
          as: "makeupSchedule",
          attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
        }
      ],
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!leave) {
      return null;
    }

    if (Number(leave.status) !== 0) {
      throw new Error("Leave request already handled");
    }

    if (payload.action === "agree") {
      if (leave.schedule_id) {
        // 已经发生过正常/补课扣课的节次不能再回头审批请假，否则账本会出现倒挂。
        const existingLog = await LessonLog.findOne({
          where: {
            schedule_id: leave.schedule_id,
            child_id: leave.child_id,
            source: 2
          },
          transaction,
          lock: transaction.LOCK.UPDATE
        });

        if (existingLog) {
          throw new Error("Attendance already consumed, leave cannot be approved");
        }

        const enrollment = await ensureEnrollment(leave.child_id, leave.classItem, transaction);
        const existingAttendance = await Attendance.findOne({
          where: {
            schedule_id: leave.schedule_id,
            child_id: leave.child_id
          },
          transaction,
          lock: transaction.LOCK.UPDATE
        });

        await Attendance.upsert(
          {
            attendance_id: existingAttendance?.attendance_id || generateId(),
            schedule_id: leave.schedule_id,
            child_id: leave.child_id,
            order_id: enrollment.order_id,
            status: 2,
            note: payload.note || "请假已批准，保留课时"
          },
          { transaction }
        );
      }

      await leave.update(
        {
          status: 1,
          handled_at: new Date(),
          makeup_status: 0
        },
        { transaction }
      );

      // 通知家长：请假已通过
      if (leave.parent?.user_id) {
        createNotification({
          userId: leave.parent.user_id,
          type: "leave",
          title: "请假已通过",
          content: `${leave.child?.nickname || "孩子"} ${leave.schedule?.lesson_date || ""} 的请假申请已通过`,
          refType: "leave",
          refId: leave.leave_id
        }).catch(() => {});
      }
    } else {
      await leave.update(
        {
          status: 2,
          handled_at: new Date(),
          makeup_status: 2
        },
        { transaction }
      );

      // 通知家长：请假被拒绝
      if (leave.parent?.user_id) {
        createNotification({
          userId: leave.parent.user_id,
          type: "leave",
          title: "请假未通过",
          content: `${leave.child?.nickname || "孩子"} ${leave.schedule?.lesson_date || ""} 的请假申请未通过${payload.note ? `：${payload.note}` : ""}`,
          refType: "leave",
          refId: leave.leave_id
        }).catch(() => {});
      }
    }

    return normalizeLeaveItem(leave);
  });
}

async function bindMakeupSchedule(leaveId, payload) {
  return sequelize.transaction(async (transaction) => {
    const leave = await LeaveRequest.findByPk(leaveId, {
      include: [
        {
          model: Class,
          as: "classItem",
          attributes: ["class_id", "name", "course_id"],
          include: [
            {
              model: Course,
              as: "course",
              attributes: ["course_id", "studio_id", "title"]
            }
          ]
        },
        { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
        { model: User, as: "parent", attributes: ["user_id", "phone", "nickname"] },
        {
          model: Schedule,
          as: "schedule",
          attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
        },
        {
          model: Schedule,
          as: "makeupSchedule",
          attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
        }
      ],
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!leave) {
      return null;
    }

    if (Number(leave.status) !== 1) {
      throw new Error("Leave request is not approved");
    }

    if (payload.action === "abandon") {
      // 已经完成补课的请假单不能再改成放弃，否则会和已发生的补课消课记录冲突。
      if (Number(leave.makeup_status) === 1) {
        throw new Error("Leave request makeup already completed");
      }

      await leave.update(
        {
          makeup_status: 2,
          makeup_schedule_id: null
        },
        { transaction }
      );
      return normalizeLeaveItem(leave);
    }

    // 已完成补课的请假单不允许再次改期，避免一张请假单被重复消课。
    if (Number(leave.makeup_status) === 1) {
      throw new Error("Leave request makeup already completed");
    }

    const makeupSchedule = await Schedule.findByPk(payload.makeup_schedule_id, {
      include: [
        {
          model: Class,
          as: "classItem",
          attributes: ["class_id", "course_id"]
        }
      ],
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!makeupSchedule) {
      throw new Error("Makeup schedule not found");
    }

    if (Number(makeupSchedule.status) === 2) {
      throw new Error("Makeup schedule is canceled");
    }

    if (String(makeupSchedule.class_id) !== String(leave.class_id)) {
      throw new Error("Makeup schedule does not belong to class");
    }

    if (String(makeupSchedule.course_id) !== String(leave.classItem.course_id)) {
      throw new Error("Makeup schedule does not belong to leave course");
    }

    if (!leave.schedule_id) {
      throw new Error("Leave request is missing source schedule");
    }

    // 补课节次必须是“原请假节次之后”的一次课，避免把补课倒挂到历史时间点。
    if (leave.schedule?.lesson_date && makeupSchedule.lesson_date < leave.schedule.lesson_date) {
      throw new Error("Makeup schedule must be later than leave schedule");
    }

    if (!makeupSchedule.is_makeup || String(makeupSchedule.makeup_from || "") !== String(leave.schedule_id)) {
      await makeupSchedule.update(
        {
          is_makeup: true,
          makeup_from: leave.schedule_id
        },
        { transaction }
      );
    }

    const duplicate = await LeaveRequest.findOne({
      where: {
        leave_id: {
          [Op.ne]: leave.leave_id
        },
        child_id: leave.child_id,
        makeup_schedule_id: payload.makeup_schedule_id,
        status: 1,
        makeup_status: {
          [Op.in]: [0, 1]
        }
      },
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (duplicate) {
      throw new Error("Makeup schedule already assigned to this student");
    }

    // assign 同时覆盖旧绑定，这样“改期”不需要额外的解除动作。
    await leave.update(
      {
        makeup_schedule_id: payload.makeup_schedule_id,
        makeup_status: 0
      },
      { transaction }
    );

    leave.makeupSchedule = makeupSchedule;
    return normalizeLeaveItem(leave);
  });
}

/**
 * 家长取消待审请假（status 0 → 3 已取消）
 * 仅本人 + 待审核状态可取消
 */
async function cancelMyLeaveRequest(parentUserId, leaveId) {
  return sequelize.transaction(async (transaction) => {
    const leave = await LeaveRequest.findOne({
      where: { leave_id: leaveId, parent_user_id: parentUserId },
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!leave) {
      throw new Error("Leave request not found");
    }

    if (Number(leave.status) !== 0) {
      throw new Error("Leave request already handled");
    }

    await leave.update(
      {
        status: 3,
        handled_at: new Date()
      },
      { transaction }
    );

    const row = await LeaveRequest.findByPk(leave.leave_id, {
      transaction,
      include: [
        { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
        { model: User, as: "parent", attributes: ["user_id", "phone", "nickname"] },
        { model: Class, as: "classItem", attributes: ["class_id", "name", "teacher_id"] },
        {
          model: Schedule,
          as: "schedule",
          attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
        },
        {
          model: Schedule,
          as: "makeupSchedule",
          attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
        }
      ]
    });

    // 通知老师：家长取消了请假
    if (row?.classItem?.teacher_id) {
      const teacherProfile = await TeacherProfile.findOne({
        where: { teacher_id: row.classItem.teacher_id }
      });
      if (teacherProfile?.user_id) {
        createNotification({
          userId: teacherProfile.user_id,
          type: "leave",
          title: "请假已取消",
          content: `${row.parent?.nickname || "家长"} 取消了 ${row.child?.nickname || "孩子"} ${row.schedule?.lesson_date || ""} 的请假申请`,
          refType: "leave",
          refId: leave.leave_id
        }).catch(() => {});
      }
    }

    return normalizeLeaveItem(row);
  });
}

module.exports = {
  submitLeaveRequest,
  listMyLeaveRequests,
  listStudioLeaveRequests,
  reviewLeaveRequest,
  bindMakeupSchedule,
  cancelMyLeaveRequest
};

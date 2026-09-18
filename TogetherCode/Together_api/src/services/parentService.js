const { Op } = require("sequelize");
const {
  Child,
  ChildCourseBalance,
  Course,
  Order,
  StudioProfile,
  LessonLog,
  Schedule,
  Class: ClassModel,
  TeacherProfile,
  Attendance,
  LeaveRequest
} = require("../models");

// 订单状态：1 支付成功（与 orderService 一致）
const PAID_STATUS = 1;

// 课时余额状态：1 使用中 / 2 已用完 / 3 已过期 / 4 已退款
const BALANCE_STATUS_TEXT = {
  1: "使用中",
  2: "已用完",
  3: "已过期",
  4: "已退款"
};

function getWeekRange(week) {
  if (week) {
    const parts = String(week).slice(0, 10).split("-").map((value) => Number(value));
    if (parts.length === 3 && parts.every((value) => Number.isInteger(value))) {
      const [year, month, dayOfMonth] = parts;
      const input = new Date(Date.UTC(year, month - 1, dayOfMonth));
      const weekday = input.getUTCDay() || 7;
      input.setUTCDate(input.getUTCDate() - weekday + 1);
      const sunday = new Date(input);
      sunday.setUTCDate(input.getUTCDate() + 6);
      return {
        start: input.toISOString().slice(0, 10),
        end: sunday.toISOString().slice(0, 10)
      };
    }
  }

  const now = new Date();
  const local = new Date(now.getTime() + 8 * 60 * 60 * 1000);
  const day = local.getUTCDay() || 7;
  local.setUTCDate(local.getUTCDate() - day + 1);
  const start = local.toISOString().slice(0, 10);
  local.setUTCDate(local.getUTCDate() + 6);
  const end = local.toISOString().slice(0, 10);
  return { start, end };
}

/**
 * 校验孩子归属，返回孩子（家长视角）
 */
async function ensureChildOwnership(childId, parentUserId) {
  const child = await Child.findOne({
    where: { child_id: childId, parent_user_id: parentUserId }
  });
  return child;
}

function normalizeBalance(item) {
  return {
    balance_id: String(item.balance_id),
    child_id: String(item.child_id),
    course_id: String(item.course_id),
    order_id: String(item.order_id),
    course_title: item.course ? item.course.title : "-",
    course_cover: item.course ? item.course.cover : null,
    studio_name: item.order?.studio ? item.order.studio.name : null,
    total_lessons: Number(item.total_lessons),
    consumed_lessons: Number(item.consumed_lessons),
    refunded_lessons: Number(item.refunded_lessons),
    remaining_lessons: Number(item.remaining_lessons),
    valid_from: item.valid_from,
    valid_to: item.valid_to,
    status: Number(item.status),
    status_text: BALANCE_STATUS_TEXT[Number(item.status)] || "未知"
  };
}

/**
 * 家长端：课时余额（课包）
 * - 不传 child_id：返回该家长所有孩子的课包，按孩子分组
 * - 传 child_id：仅返回该孩子的课包
 */
async function getMyBalances(userId, query = {}) {
  const childWhere = { parent_user_id: userId };
  if (query.child_id) {
    childWhere.child_id = query.child_id;
  }

  const children = await Child.findAll({
    where: childWhere,
    attributes: ["child_id", "nickname", "birthday", "gender"],
    order: [["created_at", "ASC"]]
  });

  if (children.length === 0) {
    return { children: [] };
  }

  const balances = await ChildCourseBalance.findAll({
    where: {
      child_id: {
        [Op.in]: children.map((item) => item.child_id)
      }
    },
    include: [
      { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
      {
        model: Order,
        as: "order",
        attributes: ["order_id", "order_no", "studio_id", "status"],
        include: [{ model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] }]
      }
    ],
    order: [
      ["child_id", "ASC"],
      ["created_at", "DESC"]
    ]
  });

  const grouped = children.map((child) => ({
    child_id: String(child.child_id),
    nickname: child.nickname,
    birthday: child.birthday,
    gender: Number(child.gender),
    total_packages: balances.filter((item) => String(item.child_id) === String(child.child_id)).length,
    balances: balances
      .filter((item) => String(item.child_id) === String(child.child_id))
      .map(normalizeBalance)
  }));

  return { children: grouped };
}

/**
 * 家长端：消课记录（上课流水）
 * - 不传 child_id：该家长全部孩子
 * - 传 child_id：仅该孩子
 */
async function getMyLessonLogs(userId, query = {}) {
  const childWhere = { parent_user_id: userId };
  if (query.child_id) {
    childWhere.child_id = query.child_id;
  }

  const children = await Child.findAll({
    where: childWhere,
    attributes: ["child_id"]
  });

  if (children.length === 0) {
    return { total: 0, list: [] };
  }

  const where = {
    child_id: {
      [Op.in]: children.map((item) => item.child_id)
    }
  };

  const rows = await LessonLog.findAll({
    where,
    include: [
      { model: Child, as: "child", attributes: ["child_id", "nickname"] },
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
    total: rows.length,
    list: rows.map((item) => ({
      log_id: String(item.log_id),
      child_id: String(item.child_id),
      child_name: item.child ? item.child.nickname : "-",
      course_id: String(item.course_id),
      course_title: item.course ? item.course.title : "-",
      studio_name: item.order?.studio ? item.order.studio.name : null,
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


/**
 * 家长端：孩子每节课的签到记录
 * status: 1 出勤（消课） / 2 请假（保留课时）
 */
async function getChildAttendance(userId, query = {}) {
  const childWhere = { parent_user_id: userId };
  if (query.child_id) childWhere.child_id = query.child_id;

  const children = await Child.findAll({
    where: childWhere,
    attributes: ["child_id", "nickname"]
  });
  if (children.length === 0) {
    return { total: 0, list: [] };
  }

  const rows = await Attendance.findAll({
    where: {
      child_id: { [Op.in]: children.map((c) => c.child_id) }
    },
    include: [
      {
        model: Schedule,
        as: "schedule",
        attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location", "is_makeup"],
        include: [
          { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
          { model: ClassModel, as: "classItem", attributes: ["class_id", "name"] },
          { model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] }
        ]
      }
    ],
    order: [["created_at", "DESC"]],
    limit: Math.min(Number(query.limit) || 100, 200),
    offset: Number(query.offset) || 0
  });

  const childMap = {};
  children.forEach((c) => (childMap[c.child_id] = c));

  return {
    total: rows.length,
    list: rows.map((a) => {
      const st = Number(a.status);
      const schedule = a.schedule;
      return {
        attendance_id: String(a.attendance_id),
        child_id: String(a.child_id),
        child_name: childMap[a.child_id] ? childMap[a.child_id].nickname : "-",
        schedule_id: schedule ? String(schedule.schedule_id) : null,
        lesson_date: schedule ? schedule.lesson_date : null,
        start_time: schedule ? schedule.start_time : null,
        end_time: schedule ? schedule.end_time : null,
        is_makeup: schedule ? Boolean(schedule.is_makeup) : false,
        location: schedule ? schedule.location : null,
        course_title: schedule?.course ? schedule.course.title : "-",
        course_cover: schedule?.course ? schedule.course.cover : null,
        class_name: schedule?.classItem ? schedule.classItem.name : "-",
        studio_name: schedule?.studio ? schedule.studio.name : null,
        status: st,
        status_text: st === 1 ? "出勤" : st === 2 ? "请假" : "未知",
        consumed: st === 1,
        note: a.note,
        created_at: a.created_at
      };
    })
  };
}


function normalizeTimetableItem(item) {
  return {
    schedule_id: String(item.schedule_id),
    studio_id: String(item.studio_id),
    course_id: String(item.course_id),
    class_id: String(item.class_id),
    course_title: item.course ? item.course.title : "-",
    duration_min: item.course ? item.course.duration_min : null,
    class_name: item.classItem ? item.classItem.name : "-",
    teacher_name: item.teacher ? item.teacher.real_name : "-",
    studio_name: item.studio ? item.studio.name : "-",
    lesson_date: item.lesson_date,
    start_time: item.start_time,
    end_time: item.end_time,
    location: item.location,
    is_makeup: Boolean(item.is_makeup),
    status: Number(item.status)
  };
}

/**
 * 家长端：孩子课表
 * 孩子已购课程（余额 status 1/2）对应课程的本周排课
 */
async function getChildTimetable(userId, query = {}) {
  const child = await ensureChildOwnership(query.child_id, userId);
  if (!child) {
    return { error: { status: 404, message: "孩子不存在" } };
  }

  const balances = await ChildCourseBalance.findAll({
    where: {
      child_id: query.child_id,
      status: {
        [Op.in]: [1, 2]
      }
    },
    attributes: ["course_id"]
  });

  const courseIds = balances.map((item) => item.course_id);
  if (courseIds.length === 0) {
    return { error: { status: 400, message: "该孩子暂无已购课程" } };
  }

  const range = getWeekRange(query.week);
  const schedules = await Schedule.findAll({
    where: {
      course_id: {
        [Op.in]: courseIds
      },
      lesson_date: {
        [Op.between]: [range.start, range.end]
      }
    },
    include: [
      { model: ClassModel, as: "classItem", attributes: ["class_id", "name"] },
      { model: Course, as: "course", attributes: ["course_id", "title", "duration_min"] },
      { model: TeacherProfile, as: "teacher", attributes: ["teacher_id", "real_name"] },
      { model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] }
    ],
    order: [
      ["lesson_date", "ASC"],
      ["start_time", "ASC"]
    ]
  });

  return {
    child_id: String(child.child_id),
    child_name: child.nickname,
    week: range,
    list: schedules.map(normalizeTimetableItem)
  };
}

/**
 * 家长端：课程日历（按月聚合，多孩子叠加）
 * month 格式 YYYY-MM；不传默认当月；child_id 可选（指定孩子）
 */
async function getChildCalendar(userId, query = {}) {
  const monthStr = String(query.month || "").trim();
  let year;
  let month;

  if (/^\d{4}-\d{2}$/.test(monthStr)) {
    [year, month] = monthStr.split("-").map((value) => Number(value));
  } else {
    const now = new Date();
    year = now.getFullYear();
    month = now.getMonth() + 1;
  }

  const startDate = `${year}-${String(month).padStart(2, "0")}-01`;
  const endDate = `${year}-${String(month).padStart(2, "0")}-${new Date(year, month, 0).getDate()}`;

  const children = query.child_id
    ? [await ensureChildOwnership(query.child_id, userId)]
    : await Child.findAll({ where: { parent_user_id: userId } });

  const validChildren = (children || []).filter(Boolean);
  if (!validChildren.length) {
    return { error: { status: 400, message: "请先添加孩子" } };
  }

  const childIds = validChildren.map((child) => child.child_id);
  const balances = await ChildCourseBalance.findAll({
    where: {
      child_id: { [Op.in]: childIds },
      status: { [Op.in]: [1, 2] }
    },
    attributes: ["child_id", "course_id"]
  });

  const courseIds = [...new Set(balances.map((item) => item.course_id))];
  const schedules = courseIds.length
    ? await Schedule.findAll({
        where: {
          course_id: { [Op.in]: courseIds },
          lesson_date: { [Op.between]: [startDate, endDate] }
        },
        include: [
          { model: ClassModel, as: "classItem", attributes: ["class_id", "name"] },
          { model: Course, as: "course", attributes: ["course_id", "title", "duration_min"] },
          { model: TeacherProfile, as: "teacher", attributes: ["teacher_id", "real_name"] },
          { model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] }
        ],
        order: [
          ["lesson_date", "ASC"],
          ["start_time", "ASC"]
        ]
      })
    : [];

  // 按日期聚合；每个孩子只保留其已购课程的排课
  const balanceCourseMap = new Map();
  balances.forEach((item) => {
    const key = `${item.child_id}:${item.course_id}`;
    balanceCourseMap.set(key, true);
  });

  const dateMap = new Map();
  for (const schedule of schedules) {
    const covered = validChildren.some((child) =>
      balanceCourseMap.has(`${child.child_id}:${schedule.course_id}`)
    );
    if (!covered) continue;

    const date = schedule.lesson_date;
    if (!dateMap.has(date)) {
      dateMap.set(date, []);
    }
    dateMap.get(date).push({
      ...normalizeTimetableItem(schedule),
      children: validChildren
        .filter((child) => balanceCourseMap.has(`${child.child_id}:${schedule.course_id}`))
        .map((child) => ({
          child_id: String(child.child_id),
          nickname: child.nickname
        }))
    });
  }

  return {
    month: `${year}-${String(month).padStart(2, "0")}`,
    date_count: dateMap.size,
    list: Array.from(dateMap.entries()).map(([date, events]) => ({
      date,
      events
    }))
  };
}

module.exports = {
  getMyBalances,
  getMyLessonLogs,
  getChildAttendance,
  getChildTimetable,
  getChildCalendar,
  getMyCourses,
  getCourseSchedules
};

/**
 * 家长端：我的课程（孩子已购课程聚合，含进度 + 下一节课）
 * 支持传 child_id（单孩子）或不传（全部孩子 + children 筛选数组）
 */
async function getMyCourses(userId, query = {}) {
  const rawChildId = String(query.child_id || "").trim();
  let children;
  if (rawChildId) {
    const child = await ensureChildOwnership(rawChildId, userId);
    if (!child) {
      return { error: { status: 404, message: "孩子不存在" } };
    }
    children = [child];
  } else {
    children = await Child.findAll({
      where: { parent_user_id: userId },
      order: [["created_at", "ASC"]]
    });
    if (!children.length) {
      return { children: [], list: [] };
    }
  }

  const now = new Date();
  const local = new Date(now.getTime() + 8 * 60 * 60 * 1000);
  const todayStr = local.toISOString().slice(0, 10);

  const list = [];
  for (const child of children) {
    const balances = await ChildCourseBalance.findAll({
      where: {
        child_id: child.child_id,
        status: { [Op.in]: [1, 2] }
      },
      include: [
        { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
        {
          model: Order,
          as: "order",
          attributes: ["order_id", "studio_id"],
          include: [{ model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] }]
        }
      ],
      order: [["created_at", "ASC"]]
    });

    const courseIds = balances.map((item) => item.course_id);
    let schedules = [];
    if (courseIds.length) {
      schedules = await Schedule.findAll({
        where: { course_id: { [Op.in]: courseIds } },
        include: [
          { model: TeacherProfile, as: "teacher", attributes: ["teacher_id", "real_name"] },
          { model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] }
        ],
        order: [
          ["lesson_date", "ASC"],
          ["start_time", "ASC"]
        ]
      });
    }

    const scheduleByCourse = {};
    schedules.forEach((item) => {
      const key = String(item.course_id);
      if (!scheduleByCourse[key]) scheduleByCourse[key] = [];
      scheduleByCourse[key].push(item);
    });

    const childList = balances.map((item) => {
      const sc = scheduleByCourse[String(item.course_id)] || [];
      const teacherItem = sc.find((s) => s.teacher) || sc[0];
      const future = sc.find((s) => String(s.lesson_date) >= todayStr);
      const total = Number(item.total_lessons);
      const consumed = Number(item.consumed_lessons);
      return {
        child_id: String(child.child_id),
        child_name: child.nickname,
        course_id: String(item.course_id),
        course_title: item.course ? item.course.title : "-",
        course_cover: item.course ? item.course.cover : null,
        studio_name: item.order?.studio ? item.order.studio.name : null,
        teacher_name: teacherItem?.teacher ? teacherItem.teacher.real_name : null,
        total_lessons: total,
        consumed_lessons: consumed,
        remaining_lessons: Number(item.remaining_lessons),
        percent: total > 0 ? Math.round((consumed / total) * 100) : 0,
        status: Number(item.status),
        status_text: BALANCE_STATUS_TEXT[Number(item.status)] || "未知",
        next_lesson: future
          ? {
              schedule_id: String(future.schedule_id),
              lesson_date: future.lesson_date,
              start_time: future.start_time,
              end_time: future.end_time
            }
          : null
      };
    });
    list.push(...childList);
  }

  return {
    children: children.map((c) => ({
      child_id: String(c.child_id),
      child_name: c.nickname
    })),
    list
  };
}

/**
 * 家长端：课时进度（课程详情下的排课 + 出勤状态）
 * 需 child_id + course_id
 */
async function getCourseSchedules(userId, query = {}) {
  const child = await ensureChildOwnership(query.child_id, userId);
  if (!child) {
    return { error: { status: 404, message: "孩子不存在" } };
  }
  const courseId = String(query.course_id || "").trim();
  if (!courseId) {
    return { error: { status: 400, message: "缺少 course_id" } };
  }

  const balance = await ChildCourseBalance.findOne({
    where: {
      child_id: child.child_id,
      course_id: courseId,
      status: { [Op.in]: [1, 2] }
    },
    include: [{ model: Course, as: "course", attributes: ["course_id", "title", "cover"] }]
  });
  if (!balance) {
    return { error: { status: 404, message: "未找到该课程课包" } };
  }

  const schedules = await Schedule.findAll({
    where: { course_id: courseId },
    include: [
      { model: TeacherProfile, as: "teacher", attributes: ["teacher_id", "real_name"] },
      { model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] },
      {
        model: Attendance,
        as: "attendanceRecords",
        attributes: ["attendance_id", "child_id", "status"]
      }
    ],
    order: [
      ["lesson_date", "ASC"],
      ["start_time", "ASC"]
    ]
  });

  const now = new Date();
  const local = new Date(now.getTime() + 8 * 60 * 60 * 1000);
  const todayStr = local.toISOString().slice(0, 10);

  const teacherItem = schedules.find((s) => s.teacher) || null;
  const studioItem = schedules.find((s) => s.studio) || null;

  // 该生在此课程下已有的请假（按 schedule 聚合：0 无 / 1 待处理 / 2 已同意 / 3 已婉拒）
  const scheduleIds = schedules.map((s) => String(s.schedule_id));
  const leaveMap = new Map();
  if (scheduleIds.length > 0) {
    const leaves = await LeaveRequest.findAll({
      where: {
        child_id: child.child_id,
        schedule_id: { [Op.in]: scheduleIds },
        // 已取消(3)不算请假，撤销后可重新请假
        status: { [Op.ne]: 3 }
      },
      attributes: ["schedule_id", "status", "makeup_status"],
      order: [["created_at", "DESC"]]
    });
    for (const leave of leaves) {
      const key = String(leave.schedule_id);
      // 同一节次多条取最新一条
      if (!leaveMap.has(key)) {
        leaveMap.set(key, Number(leave.status) === 1 ? 2 : Number(leave.status) === 2 ? 3 : 1);
      }
    }
  }

  const list = schedules.map((schedule, index) => {
    const attendance = (schedule.attendanceRecords || []).find(
      (a) => String(a.child_id) === String(child.child_id)
    );
    const attended = attendance && Number(attendance.status) === 1;
    const isToday = String(schedule.lesson_date) === todayStr;
    // 0 待上 / 1 已上 / 2 今天（未出勤）
    const status = attended ? 1 : isToday ? 2 : 0;
    const lessonNo = index + 1;
    return {
      schedule_id: String(schedule.schedule_id),
      class_id: schedule.class_id ? String(schedule.class_id) : null,
      lesson_no: lessonNo,
      lesson_title:
        schedule.remark && String(schedule.remark).trim()
          ? String(schedule.remark).trim()
          : `第${lessonNo}课`,
      lesson_date: schedule.lesson_date,
      start_time: schedule.start_time,
      end_time: schedule.end_time,
      status,
      // 请假状态：0 无 / 1 待处理 / 2 已同意 / 3 已婉拒
      leave_status: leaveMap.get(String(schedule.schedule_id)) || 0
    };
  });

  return {
    child_id: String(child.child_id),
    child_name: child.nickname,
    course_id: courseId,
    course_title: balance.course ? balance.course.title : "-",
    course_cover: balance.course ? balance.course.cover : null,
    // 班级：优先课包绑定班级，回退到该课程排课绑定的班级
    class_id: balance.class_id
      ? String(balance.class_id)
      : schedules.find((s) => s.class_id)
        ? String(schedules.find((s) => s.class_id).class_id)
        : null,
    studio_name: studioItem?.studio ? studioItem.studio.name : null,
    teacher_name: teacherItem?.teacher ? teacherItem.teacher.real_name : null,
    total_lessons: Number(balance.total_lessons),
    consumed_lessons: Number(balance.consumed_lessons),
    remaining_lessons: Number(balance.remaining_lessons),
    list
  };
}

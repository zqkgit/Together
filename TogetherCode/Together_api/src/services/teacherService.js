const { Op } = require("sequelize");
const {
  sequelize,
  TeacherProfile,
  StudioProfile,
  User,
  Class,
  Course,
  Schedule,
  ChildCourseBalance,
  Order,
  Child,
  LeaveRequest,
  Post,
  PostStudent,
  LessonLog,
  Attendance,
  CourseReview
} = require("../models");
const { createNotification } = require("./messageService");
const { applyLessonConsumption, attendSchedule, resetMakeupStatus } = require("./studentService");
const { reviewLeaveRequest, bindMakeupSchedule } = require("./leaveService");

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

function normalizeTeacher(teacher) {
  return {
    teacher_id: String(teacher.teacher_id),
    user_id: String(teacher.user_id),
    real_name: teacher.real_name,
    studio_id: teacher.studio_id ? String(teacher.studio_id) : null,
    subjects: teacher.subjects,
    years: teacher.years,
    intro: teacher.intro,
    cert_status: teacher.cert_status,
    rating: Number(teacher.rating),
    student_count: teacher.student_count,
    work_count: teacher.work_count,
    fans: teacher.fans,
    user: teacher.user
      ? {
          user_id: String(teacher.user.user_id),
          nickname: teacher.user.nickname,
          avatar: teacher.user.avatar,
          phone: teacher.user.phone
        }
      : null
  };
}

function normalizeClassItem(item) {
  return {
    class_id: String(item.class_id),
    course_id: String(item.course_id),
    teacher_id: item.teacher_id ? String(item.teacher_id) : null,
    name: item.name,
    capacity: item.capacity,
    enrolled: item.enrolled,
    start_date: item.start_date,
    end_date: item.end_date,
    course: item.course
      ? {
          course_id: String(item.course.course_id),
          title: item.course.title,
          duration_min: item.course.duration_min,
          class_size: item.course.class_size
        }
      : null
  };
}

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
          nickname: item.parent.nickname,
          phone: item.parent.phone
        }
      : null,
    class: item.classItem
      ? {
          class_id: String(item.classItem.class_id),
          name: item.classItem.name,
          course: item.classItem.course
            ? {
                course_id: String(item.classItem.course.course_id),
                title: item.classItem.course.title
              }
            : null
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

function normalizePost(post, students = []) {
  const hasLocation =
    post.latitude !== null && post.latitude !== undefined && post.longitude !== null && post.longitude !== undefined;
  return {
    post_id: String(post.post_id),
    author_id: String(post.author_id),
    author_role: post.author_role,
    type: post.type,
    child_id: post.child_id ? String(post.child_id) : null,
    course_id: post.course_id ? String(post.course_id) : null,
    content: post.content,
    images: post.images || [],
    visibility: post.visibility,
    status: post.status,
    created_at: post.created_at,
    updated_at: post.updated_at,
    location: hasLocation
      ? { latitude: Number(post.latitude), longitude: Number(post.longitude), name: post.location_name || null }
      : null,
    students
  };
}

/**
 * 从发帖 payload 提取选填位置（经纬度 + 地点名）。
 * 经纬度范围非法或缺失时整体忽略，保证选填语义。
 */
function pickLocation(payload) {
  const lat = Number(payload.latitude);
  const lng = Number(payload.longitude);
  const valid =
    Number.isFinite(lat) && Number.isFinite(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  if (!valid) {
    return { latitude: null, longitude: null, location_name: null };
  }
  const name = String(payload.location_name || "").trim().slice(0, 128) || null;
  return { latitude: lat, longitude: lng, location_name: name };
}

async function ensureTeacherProfile(userId, transaction) {
  const teacher = await TeacherProfile.findOne({
    where: { user_id: userId },
    include: [
      {
        model: User,
        as: "user",
        attributes: ["user_id", "nickname", "avatar", "phone"]
      }
    ],
    transaction
  });

  if (!teacher) {
    throw new Error("Teacher profile not found");
  }

  return teacher;
}

async function ensureTeacherClass(classId, teacherId, transaction) {
  const classItem = await Class.findByPk(classId, {
    include: [
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "studio_id", "title", "duration_min", "class_size"]
      }
    ],
    transaction
  });

  if (!classItem) {
    throw new Error("Class not found");
  }

  if (String(classItem.teacher_id || "") !== String(teacherId)) {
    throw new Error("Class does not belong to teacher");
  }

  return classItem;
}

async function ensureTeacherSchedule(scheduleId, teacherId, transaction) {
  const schedule = await Schedule.findByPk(scheduleId, {
    include: [
      {
        model: Class,
        as: "classItem",
        attributes: ["class_id", "teacher_id", "name"]
      },
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "studio_id", "title", "duration_min"]
      }
    ],
    transaction
  });

  if (!schedule) {
    throw new Error("Schedule not found");
  }

  const ownerTeacherId = schedule.teacher_id || schedule.classItem?.teacher_id;
  if (String(ownerTeacherId || "") !== String(teacherId)) {
    throw new Error("Schedule does not belong to teacher");
  }

  if (Number(schedule.status) === 2) {
    throw new Error("Schedule is canceled");
  }

  return schedule;
}

async function findRosterByCourse(courseId, studioId, transaction) {
  const balances = await ChildCourseBalance.findAll({
    where: {
      course_id: courseId,
      status: {
        [Op.in]: [1, 2]
      }
    },
    include: [
      {
        model: Child,
        as: "child",
        attributes: ["child_id", "nickname", "birthday", "gender", "avatar"]
      },
      {
        model: Order,
        as: "order",
        required: true,
        where: {
          studio_id: studioId,
          status: { [Op.in]: [2, 3, 4] }
        },
        attributes: ["order_id", "status", "created_at"]
      }
    ],
    order: [["created_at", "DESC"]],
    transaction
  });

  const rosterMap = new Map();
  for (const balance of balances) {
    const childId = String(balance.child_id);
    if (!rosterMap.has(childId)) {
      rosterMap.set(childId, balance);
    }
  }

  return Array.from(rosterMap.values());
}

async function buildLeaveMap({ classId, scheduleId, childIds }, transaction) {
  if (!scheduleId || !childIds.length) {
    return new Map();
  }

  const rows = await LeaveRequest.findAll({
    where: {
      class_id: classId,
      child_id: {
        [Op.in]: childIds
      },
      status: 1,
      [Op.or]: [{ schedule_id: scheduleId }, { schedule_id: null }]
    },
    transaction
  });

  const leaveMap = new Map();
  rows.forEach((item) => {
    leaveMap.set(String(item.child_id), {
      leave_id: String(item.leave_id),
      schedule_id: item.schedule_id ? String(item.schedule_id) : null,
      reason: item.reason,
      status: item.status,
      makeup_status: item.makeup_status
    });
  });

  return leaveMap;
}

async function resolvePostContext(teacher, payload, transaction) {
  let classItem = null;
  let schedule = null;

  if (payload.class_id) {
    classItem = await ensureTeacherClass(payload.class_id, teacher.teacher_id, transaction);
  }

  if (payload.schedule_id) {
    schedule = await ensureTeacherSchedule(payload.schedule_id, teacher.teacher_id, transaction);
    if (classItem && String(schedule.class_id) !== String(classItem.class_id)) {
      throw new Error("Schedule does not belong to class");
    }
    classItem = classItem || (await ensureTeacherClass(schedule.class_id, teacher.teacher_id, transaction));
  } else if (classItem && payload.consume === true) {
    // 同步消课未指定课次：自动匹配该班级今天的排课；没有则取最近一次
    const today = localToday();
    schedule = await Schedule.findOne({
      where: { class_id: classItem.class_id, lesson_date: today },
      order: [["start_time", "ASC"]],
      transaction
    });
    if (!schedule) {
      schedule = await Schedule.findOne({
        where: { class_id: classItem.class_id },
        order: [["lesson_date", "DESC"], ["start_time", "DESC"]],
        transaction
      });
    }
  }

  const courseId = schedule?.course_id || classItem?.course_id || payload.course_id;
  if (!courseId) {
    // 纯分享帖：不带课程/班级/排课
    return { course: null, classItem: null, schedule: null };
  }

  const course = await Course.findByPk(courseId, { transaction });
  if (!course) {
    throw new Error("Course not found");
  }

  if (teacher.studio_id && String(course.studio_id) !== String(teacher.studio_id)) {
    throw new Error("Course does not belong to teacher studio");
  }

  if (payload.course_id && String(course.course_id) !== String(payload.course_id)) {
    throw new Error("Course does not match class or schedule");
  }

  return {
    course,
    classItem,
    schedule
  };
}

async function consumeStudentsForPost(post, teacher, payload, transaction) {
  const students = Array.isArray(payload.students) ? payload.students : [];
  if (!students.length) {
    return [];
  }

  const { course, classItem, schedule } = await resolvePostContext(
    teacher,
    {
      course_id: post.course_id,
      class_id: payload.class_id,
      schedule_id: payload.schedule_id,
      consume: payload.consume
    },
    transaction
  );

  if (!course) {
    throw new Error("Course context required for consumption");
  }

  const dedupedStudents = [];
  const seen = new Set();
  students.forEach((item) => {
    const childId = String(item.child_id);
    if (!seen.has(childId)) {
      seen.add(childId);
      dedupedStudents.push(item);
    }
  });

  const roster = await findRosterByCourse(course.course_id, course.studio_id, transaction);
  const rosterMap = new Map(roster.map((item) => [String(item.child_id), item]));
  const leaveMap = await buildLeaveMap({
    classId: classItem?.class_id,
    scheduleId: schedule?.schedule_id || payload.schedule_id,
    childIds: dedupedStudents.map((item) => item.child_id)
  }, transaction);

  const consumedList = [];

  // 发帖关联学生（家长可见/推送）与"同步消课"（扣课时）是两回事：
  // consume=false（默认）只关联学生，不扣课时；consume=true 时才走扣课时流程
  const consume = payload.consume === true;

  for (const item of dedupedStudents) {
    const rosterItem = rosterMap.get(String(item.child_id));
    if (!rosterItem) {
      throw new Error("Student is not enrolled in teacher course");
    }

    const existingPostStudent = await PostStudent.findOne({
      where: {
        post_id: post.post_id,
        child_id: item.child_id
      },
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!consume) {
      // 仅关联：记录到 post_students（deducted=false），不扣课时、不校验请假
      if (existingPostStudent) {
        await existingPostStudent.update({ order_id: rosterItem.order_id, deducted: false }, { transaction });
      } else {
        await PostStudent.create(
          {
            post_id: post.post_id,
            child_id: item.child_id,
            order_id: rosterItem.order_id,
            deducted: false
          },
          { transaction }
        );
      }
      consumedList.push({
        child_id: String(item.child_id),
        order_id: String(rosterItem.order_id),
        consumed_count: 0,
        remaining_lessons: Number(rosterItem.remaining_lessons)
      });
      continue;
    }

    if (existingPostStudent?.deducted) {
      throw new Error("Student already consumed for this post");
    }

    if (leaveMap.has(String(item.child_id))) {
      throw new Error("Approved leave student cannot be consumed");
    }

    const consumed = await applyLessonConsumption(
      item.child_id,
      {
        order_id: String(rosterItem.order_id),
        count: item.count || 1,
        note: item.note || payload.note || "老师发帖自动消课"
      },
      {
        transaction,
        postId: post.post_id,
        scheduleId: schedule?.schedule_id || null,
        source: 1,
        type: schedule?.is_makeup ? 3 : 1,
        defaultNote: "老师发帖自动消课"
      }
    );

    if (!consumed) {
      throw new Error("Student order not found");
    }

    if (existingPostStudent) {
      await existingPostStudent.update(
        {
          order_id: consumed.order_id,
          deducted: true
        },
        { transaction }
      );
    } else {
      await PostStudent.create(
        {
          post_id: post.post_id,
          child_id: item.child_id,
          order_id: consumed.order_id,
          deducted: true
        },
        { transaction }
      );
    }

    consumedList.push({
      child_id: String(item.child_id),
      order_id: String(consumed.order_id),
      consumed_count: Number(item.count || 1),
      remaining_lessons: consumed.remaining_lessons
    });
  }

  return consumedList;
}

async function listTeacherClasses(userId) {
  const teacher = await ensureTeacherProfile(userId);
  const rows = await Class.findAll({
    where: {
      teacher_id: teacher.teacher_id
    },
    include: [
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "studio_id", "title", "duration_min", "class_size"]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  return {
    teacher: normalizeTeacher(teacher),
    total: rows.length,
    list: rows.map(normalizeClassItem)
  };
}

async function listTeacherCourses(userId) {
  const teacher = await ensureTeacherProfile(userId);
  const classes = await Class.findAll({
    where: { teacher_id: teacher.teacher_id },
    include: [
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "studio_id", "title", "total_lessons", "duration_min"]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  // 按课程聚合班级
  const courseMap = new Map();
  for (const cls of classes) {
    if (!cls.course) continue;
    const cid = String(cls.course.course_id);
    if (!courseMap.has(cid)) {
      courseMap.set(cid, { course: cls.course, classes: [] });
    }
    courseMap.get(cid).classes.push(cls);
  }

  const list = [];
  const studios = await StudioProfile.findAll({ attributes: ["studio_id", "name"] });
  const studioMap = new Map(studios.map((st) => [String(st.studio_id), st.name]));
  for (const { course, classes: clsList } of courseMap.values()) {
    // 课程级在读学生（有效权益去重）
    const roster = await findRosterByCourse(course.course_id, course.studio_id);
    const courseStudentCount = new Set(roster.map((b) => String(b.child_id))).size;

    // 已消课节数（帖子消课 + 排课消课）
    const logs = await LessonLog.findAll({
      where: { course_id: course.course_id, source: { [Op.in]: [1, 2] } },
      attributes: ["delta"]
    });
    const consumed = logs.reduce((sum, l) => sum + Math.abs(Number(l.delta || 0)), 0);
    const total = Number(course.total_lessons || 0);
    const progress = total > 0 ? Math.min(Math.round((consumed / total) * 100), 100) : 0;

    // 每班学生数：优先按 class_id 绑定，回退课程花名册（兼容历史未绑班数据）
    const classItems = [];
    for (const cls of clsList) {
      const bound = await ChildCourseBalance.findAll({
        where: { class_id: cls.class_id, status: { [Op.in]: [1, 2] } },
        attributes: ["child_id"]
      });
      let count = new Set(bound.map((b) => String(b.child_id))).size;
      if (count === 0) count = courseStudentCount;
      classItems.push({
        class_id: String(cls.class_id),
        name: cls.name,
        student_count: count
      });
    }

    list.push({
      course_id: String(course.course_id),
      studio_name: studioMap.get(String(course.studio_id)) || null,
      title: course.title,
      total_lessons: total,
      consumed_lessons: consumed,
      progress,
      student_count: courseStudentCount,
      classes: classItems
    });
  }

  return { total: list.length, list };
}

async function listTeacherStudents(userId, query = {}) {
  const teacher = await ensureTeacherProfile(userId);
  const classes = await Class.findAll({
    where: { teacher_id: teacher.teacher_id },
    include: [
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "studio_id", "title", "total_lessons"]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  // 班级列表（筛选用，带工作室名区分多工作室同名班）
  const classStudios = await StudioProfile.findAll({ attributes: ["studio_id", "name"] });
  const classStudioMap = new Map(classStudios.map((st) => [String(st.studio_id), st.name]));
  const classSummary = classes.map((c) => ({
    class_id: String(c.class_id),
    name: c.name,
    studio_name: (c.course && classStudioMap.get(String(c.course.studio_id))) || null
  }));

  // 聚合学生（按课程花名册，child 去重；每 child 聚合其有效权益课程）
  // 按班级切换时只聚合该班学生（每班学生少，按班请求更轻）；班级列表始终全量供筛选
  const targetClasses = query.class_id
    ? classes.filter((c) => String(c.class_id) === String(query.class_id))
    : classes;
  const childMap = new Map();
  for (const cls of targetClasses) {
    if (!cls.course) continue;
    const roster = await findRosterByCourse(cls.course.course_id, cls.course.studio_id);
    for (const balance of roster) {
      const childId = String(balance.child_id);
      if (!childMap.has(childId)) {
        childMap.set(childId, {
          child_id: childId,
          nickname: balance.child?.nickname || "宝宝",
          avatar: balance.child?.avatar || null,
          birthday: balance.child?.birthday || null,
          courses: []
        });
      }
      const entry = childMap.get(childId);
      // 同一课程多个 balance 取剩余最大；不同课程各一条
      const existing = entry.courses.find((c) => String(c.course_id) === String(cls.course.course_id));
      const remaining = Number(balance.remaining_lessons || 0);
      if (!existing) {
        entry.courses.push({
          course_id: String(cls.course.course_id),
          title: cls.course.title,
          class_id: String(cls.class_id),
          class_name: cls.name,
          remaining_lessons: remaining,
          total_lessons: Number(cls.course.total_lessons || 0)
        });
      } else {
        existing.remaining_lessons = Math.max(existing.remaining_lessons, remaining);
      }
    }
  }

  // 今日是否有排课 / 是否请假中（pending）
  const today = localToday();
  const childIds = [...childMap.keys()];
  const todaySet = new Set();
  const leavingSet = new Set();
  if (childIds.length > 0) {
    const todaySchedules = await Schedule.findAll({
      where: { teacher_id: teacher.teacher_id, lesson_date: today },
      include: [
        { model: Course, as: "course", attributes: ["course_id", "studio_id"] }
      ],
      attributes: ["schedule_id", "course_id"]
    });
    for (const s of todaySchedules) {
      if (!s.course) continue;
      const roster = await findRosterByCourse(s.course_id, s.course.studio_id);
      roster.forEach((b) => todaySet.add(String(b.child_id)));
    }
    // 请假中：仅统计该老师名下班级的待处理请假（与顶部请假卡同口径）
    const teacherClassIds = classes.map((c) => String(c.class_id));
    const leaves = await LeaveRequest.findAll({
      where: {
        child_id: { [Op.in]: childIds },
        status: 0,
        class_id: { [Op.in]: teacherClassIds }
      },
      attributes: ["child_id"]
    });
    leaves.forEach((l) => leavingSet.add(String(l.child_id)));
  }

  const list = [...childMap.values()].map((item) => ({
    ...item,
    today_scheduled: todaySet.has(item.child_id),
    leaving: leavingSet.has(item.child_id)
  }));

  return {
    total: list.length,
    classes: classSummary,
    list
  };
}

async function getTeacherClassStudents(userId, classId, query = {}) {
  const teacher = await ensureTeacherProfile(userId);
  const classItem = await ensureTeacherClass(classId, teacher.teacher_id);
  const roster = await findRosterByCourse(classItem.course_id, classItem.course.studio_id);
  const childIds = roster.map((item) => item.child_id);
  const leaveMap = await buildLeaveMap({
    classId: classItem.class_id,
    scheduleId: query.schedule_id,
    childIds
  });

  // 已消课学生（该排课点名消课，供课表详情回显）
  let consumedSet = new Set();
  if (query.schedule_id) {
    const logs = await LessonLog.findAll({
      where: {
        schedule_id: query.schedule_id,
        source: { [Op.in]: [1, 2] }
      },
      attributes: ["child_id"]
    });
    consumedSet = new Set(logs.map((item) => String(item.child_id)));
  }

  return {
    class: normalizeClassItem(classItem),
    total: roster.length,
    list: roster.map((balance) => ({
      child_id: String(balance.child.child_id),
      nickname: balance.child.nickname,
      birthday: balance.child.birthday,
      gender: balance.child.gender,
      avatar: balance.child.avatar,
      order_id: String(balance.order_id),
      remaining_lessons: balance.remaining_lessons,
      consumed_lessons: balance.consumed_lessons,
      refunded_lessons: balance.refunded_lessons,
      total_lessons: balance.total_lessons,
      balance_status: balance.status,
      order_status: balance.order.status,
      leave: leaveMap.get(String(balance.child.child_id)) || null,
      selectable: !leaveMap.has(String(balance.child.child_id)),
      consumed: consumedSet.has(String(balance.child.child_id))
    }))
  };
}

async function listTeacherTimetable(userId, query = {}) {
  const teacher = await ensureTeacherProfile(userId);
  let where = {
    teacher_id: teacher.teacher_id
  };

  if (query.date) {
    where = {
      ...where,
      lesson_date: query.date
    };
  } else {
    const range = getWeekRange(query.week);
    where = {
      ...where,
      lesson_date: {
        [Op.between]: [range.start, range.end]
      }
    };
  }

  const schedules = await Schedule.findAll({
    where,
    include: [
      {
        model: Class,
        as: "classItem",
        attributes: ["class_id", "name", "capacity", "enrolled", "teacher_id"]
      },
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "studio_id", "title", "duration_min"]
      }
    ],
    order: [
      ["lesson_date", "ASC"],
      ["start_time", "ASC"]
    ]
  });

  const studioRows = await StudioProfile.findAll({ attributes: ["studio_id", "name"] });
  const studioMap = new Map(studioRows.map((st) => [String(st.studio_id), st.name]));
  const scheduleIds = schedules.map((item) => item.schedule_id);
  const scheduleLogs = scheduleIds.length
    ? await LessonLog.findAll({
        where: {
          schedule_id: {
            [Op.in]: scheduleIds
          },
          source: {
            [Op.in]: [1, 2]
          }
        },
        attributes: ["schedule_id", "child_id"]
      })
    : [];

  const consumedMap = new Map();
  scheduleLogs.forEach((item) => {
    const key = String(item.schedule_id);
    if (!consumedMap.has(key)) {
      consumedMap.set(key, new Set());
    }
    consumedMap.get(key).add(String(item.child_id));
  });

  const leaveRows = scheduleIds.length
    ? await LeaveRequest.findAll({
        where: {
          schedule_id: {
            [Op.in]: scheduleIds
          },
          status: 1
        },
        attributes: ["schedule_id", "child_id"]
      })
    : [];

  const leaveCountMap = new Map();
  leaveRows.forEach((item) => {
    const key = String(item.schedule_id);
    leaveCountMap.set(key, (leaveCountMap.get(key) || 0) + 1);
  });

  const courseRosterCache = new Map();
  const list = [];

  for (const schedule of schedules) {
    const courseKey = String(schedule.course_id);
    if (!courseRosterCache.has(courseKey)) {
      const roster = await findRosterByCourse(schedule.course_id, schedule.course.studio_id);
      courseRosterCache.set(courseKey, roster.length);
    }

    const consumedCount = consumedMap.get(String(schedule.schedule_id))?.size || 0;
    const leaveCount = leaveCountMap.get(String(schedule.schedule_id)) || 0;
    const studentCount = courseRosterCache.get(courseKey) || 0;

    let consumeStatus = "pending";
    if (studentCount > 0 && consumedCount >= Math.max(studentCount - leaveCount, 0)) {
      consumeStatus = "completed";
    } else if (consumedCount > 0) {
      consumeStatus = "partial";
    }

    list.push({
      schedule_id: String(schedule.schedule_id),
      class_id: String(schedule.class_id),
      course_id: String(schedule.course_id),
      studio_name: (schedule.course && studioMap.get(String(schedule.course.studio_id))) || null,
      lesson_date: schedule.lesson_date,
      start_time: schedule.start_time,
      end_time: schedule.end_time,
      location: schedule.location,
      is_makeup: Boolean(schedule.is_makeup),
      remark: schedule.remark,
      consume_status: consumeStatus,
      student_count: studentCount,
      leave_count: leaveCount,
      consumed_count: consumedCount,
      class: schedule.classItem
        ? {
            class_id: String(schedule.classItem.class_id),
            name: schedule.classItem.name,
            enrolled: schedule.classItem.enrolled
          }
        : null,
      course: schedule.course
        ? {
            course_id: String(schedule.course.course_id),
            title: schedule.course.title,
            duration_min: schedule.course.duration_min
          }
        : null
    });
  }

  return {
    teacher: normalizeTeacher(teacher),
    total: list.length,
    list
  };
}

async function listTeacherLeaves(userId, query = {}) {
  const teacher = await ensureTeacherProfile(userId);
  const where = {};

  if (query.status !== undefined && query.status !== null && query.status !== "") {
    where.status = Number(query.status);
  }
  if (query.class_id) {
    where.class_id = query.class_id;
  }
  if (query.schedule_id) {
    where.schedule_id = query.schedule_id;
  }

  const classIncludeWhere = { teacher_id: teacher.teacher_id };
  const courseInclude = { model: Course, as: "course", attributes: ["course_id", "title", "studio_id"] };
  if (query.studio_id) {
    courseInclude.where = { studio_id: query.studio_id };
  }

  const rows = await LeaveRequest.findAll({
    where,
    include: [
      {
        model: Class,
        as: "classItem",
        required: true,
        where: classIncludeWhere,
        attributes: ["class_id", "name"],
        include: [courseInclude]
      },
      { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
      { model: User, as: "parent", attributes: ["user_id", "nickname", "phone"] },
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

  const studioRows = await StudioProfile.findAll({ attributes: ["studio_id", "name"] });
  const studioMap = new Map(studioRows.map((st) => [String(st.studio_id), st.name]));
  return {
    total: rows.length,
    list: rows.map((row) => {
      const item = normalizeLeaveItem(row);
      const studioId = row.classItem?.course?.studio_id;
      item.studio_id = studioId ? String(studioId) : null;
      item.studio_name = studioId ? studioMap.get(String(studioId)) || null : null;
      return item;
    })
  };
}

async function reviewTeacherLeave(userId, leaveId, payload) {
  const teacher = await ensureTeacherProfile(userId);
  const leave = await LeaveRequest.findByPk(leaveId, {
    include: [
      {
        model: Class,
        as: "classItem",
        attributes: ["class_id", "teacher_id"]
      }
    ]
  });

  if (!leave) {
    return null;
  }

  if (String(leave.classItem?.teacher_id || "") !== String(teacher.teacher_id)) {
    throw new Error("Leave request does not belong to teacher");
  }

  return reviewLeaveRequest(leaveId, payload);
}

/**
 * 老师安排 / 放弃补课：仅本人带班班级的已同意请假单可操作
 * payload.makeup_schedule_id = 安排补课；payload.action = "abandon" = 放弃补课
 */
async function arrangeTeacherMakeup(userId, leaveId, payload) {
  const teacher = await ensureTeacherProfile(userId);
  const leave = await LeaveRequest.findByPk(leaveId, {
    include: [
      {
        model: Class,
        as: "classItem",
        attributes: ["class_id", "teacher_id"]
      }
    ]
  });

  if (!leave) {
    return null;
  }

  if (String(leave.classItem?.teacher_id || "") !== String(teacher.teacher_id)) {
    throw new Error("Leave request does not belong to teacher");
  }

  return bindMakeupSchedule(leaveId, payload);
}

/**
 * 补课候选课次：同班级、在原请假课次之后、未被用作补课且未消课的排课
 */
async function listTeacherMakeupCandidates(userId, leaveId) {
  const teacher = await ensureTeacherProfile(userId);
  const leave = await LeaveRequest.findByPk(leaveId, {
    include: [
      { model: Class, as: "classItem", attributes: ["class_id", "teacher_id"] },
      {
        model: Schedule,
        as: "schedule",
        attributes: ["schedule_id", "lesson_date", "start_time", "end_time"]
      }
    ]
  });

  if (!leave) {
    return null;
  }

  if (String(leave.classItem?.teacher_id || "") !== String(teacher.teacher_id)) {
    throw new Error("Leave request does not belong to teacher");
  }

  const leaveDate = leave.schedule?.lesson_date || "";
  const leaveStart = leave.schedule?.start_time || "";
  const afterWhere = leaveDate
    ? {
        [Op.or]: [
          { lesson_date: { [Op.gt]: leaveDate } },
          { lesson_date: leaveDate, start_time: { [Op.gt]: leaveStart } }
        ]
      }
    : {};

  const rows = await Schedule.findAll({
    where: {
      class_id: leave.class_id,
      is_makeup: { [Op.ne]: true },
      ...afterWhere
    },
    order: [
      ["lesson_date", "ASC"],
      ["start_time", "ASC"]
    ]
  });

  const scheduleIds = rows.map((s) => s.schedule_id);
  const consumedRows = scheduleIds.length
    ? await Attendance.findAll({
        where: { schedule_id: { [Op.in]: scheduleIds }, status: 1 },
        attributes: ["schedule_id"]
      })
    : [];
  const consumedSet = new Set(consumedRows.map((c) => String(c.schedule_id)));

  return rows
    .filter((s) => !consumedSet.has(String(s.schedule_id)))
    .map((s) => ({
      schedule_id: String(s.schedule_id),
      lesson_date: s.lesson_date,
      start_time: s.start_time,
      end_time: s.end_time,
      location: s.location,
      remark: s.remark
    }));
}

async function createTeacherPost(userId, payload) {
  return sequelize.transaction(async (transaction) => {
    const teacher = await ensureTeacherProfile(userId, transaction);
    // 1 动态（纯分享，不关联课程） / 2 孩子作品（关联课程班级，可消课）
    const type = [1, 2].includes(Number(payload.type)) ? Number(payload.type) : 1;
    let course = null;
    let classItem = null;
    if (type === 2) {
      const ctx = await resolvePostContext(teacher, payload, transaction);
      course = ctx.course;
      classItem = ctx.classItem;
      if (!course) {
        return { error: { status: 400, code: 40061, message: "孩子作品请选择课程班级" } };
      }
    }

    const images = Array.isArray(payload.images) ? payload.images.slice(0, 9) : [];
    // 作品帖必须至少一张图（平台内容规范，与家长发帖一致）
    if (!images.length) {
      return { error: { status: 400, code: 40060, message: "请至少上传一张作品图片" } };
    }

    const post = await Post.create(
      {
        author_id: userId,
        author_role: 2,
        type,
        course_id: course ? course.course_id : null,
        class_id: classItem ? String(classItem.class_id) : null,
        images,
        content: payload.content || null,
        visibility: payload.visibility !== undefined ? Number(payload.visibility) : 2,
        status: 1,
        ...pickLocation(payload)
      },
      { transaction }
    );

    // 仅孩子作品允许发帖消课
    const students = type === 2
      ? await consumeStudentsForPost(post, teacher, payload, transaction)
      : [];

    // 闭环：老师发帖标记并消课 → 通知被标记学生的家长（成长记录）
    if (students.length) {
      const children = await Child.findAll({
        where: { child_id: { [Op.in]: students.map((s) => s.child_id) } },
        attributes: ["child_id", "nickname", "parent_user_id"],
        transaction
      });
      const parentSeen = new Set();
      for (const c of children) {
        if (!c.parent_user_id || parentSeen.has(String(c.parent_user_id))) continue;
        parentSeen.add(String(c.parent_user_id));
        createNotification({
          userId: c.parent_user_id,
          type: "growth",
          title: "孩子的课堂动态",
          content: `老师分享了${c.nickname || "孩子"}的课堂动态，点击查看`,
          refType: "post",
          refId: post.post_id
        }).catch(() => {});
      }
    }

    return normalizePost(post, students);
  });
}

async function markTeacherPostStudents(userId, postId, payload) {
  return sequelize.transaction(async (transaction) => {
    const teacher = await ensureTeacherProfile(userId, transaction);
    const post = await Post.findByPk(postId, {
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!post) {
      return null;
    }

    if (String(post.author_id) !== String(userId) || Number(post.author_role) !== 2) {
      throw new Error("Post does not belong to teacher");
    }

    const students = await consumeStudentsForPost(post, teacher, payload, transaction);

    // 闭环：老师发帖标记并消课 → 通知被标记学生的家长（成长记录）
    if (students.length) {
      const children = await Child.findAll({
        where: { child_id: { [Op.in]: students.map((s) => s.child_id) } },
        attributes: ["child_id", "nickname", "parent_user_id"],
        transaction
      });
      const parentSeen = new Set();
      for (const c of children) {
        if (!c.parent_user_id || parentSeen.has(String(c.parent_user_id))) continue;
        parentSeen.add(String(c.parent_user_id));
        createNotification({
          userId: c.parent_user_id,
          type: "growth",
          title: "孩子的课堂动态",
          content: `老师分享了${c.nickname || "孩子"}的课堂动态，点击查看`,
          refType: "post",
          refId: post.post_id
        }).catch(() => {});
      }
    }

    return normalizePost(post, students);
  });
}

/// 老师编辑自己的作品帖：仅作者本人可操作（改 content/images/topic/visibility；学生关联与消课不动，撤销走 undo）
async function updateTeacherPost(userId, postId, payload) {
  const post = await Post.findByPk(postId);
  if (!post) return null;
  if (String(post.author_id) !== String(userId) || Number(post.author_role) !== 2) {
    return { error: { status: 403, code: 40003, message: "只能编辑自己的帖子" } };
  }

  const updates = {};
  if (payload.content !== undefined) updates.content = String(payload.content).trim() || null;
  // 编辑时可不传 images：保留原图；传了则必须至少一张
  if (payload.images !== undefined) {
    const images = Array.isArray(payload.images) ? payload.images.slice(0, 9) : [];
    if (!images.length) {
      return { error: { status: 400, code: 40060, message: "请至少上传一张作品图片" } };
    }
    updates.images = images;
  }
  if (payload.topic !== undefined) updates.topic = payload.topic ? String(payload.topic).trim().slice(0, 32) : null;
  if (payload.visibility !== undefined) updates.visibility = Number(payload.visibility);
  // 位置（选填）：clear_location=true 显式清除；否则仅当传了 location 字段才更新，缺省保留原值
  if (payload.clear_location) {
    updates.latitude = null;
    updates.longitude = null;
    updates.location_name = null;
  } else if (
    payload.latitude !== undefined ||
    payload.longitude !== undefined ||
    payload.location_name !== undefined
  ) {
    const loc = pickLocation(payload);
    updates.latitude = loc.latitude;
    updates.longitude = loc.longitude;
    updates.location_name = loc.location_name;
  }
  await post.update(updates);

  const fresh = await Post.findByPk(postId, {
    include: [
      { model: User, as: "author", attributes: ["user_id", "nickname", "avatar", "current_role"] },
      { model: Child, as: "child", attributes: ["child_id", "nickname", "avatar"] },
      { model: Course, as: "course", attributes: ["course_id", "title", "studio_id", "price"] },
      { model: PostStudent, as: "students", include: [{ model: Child, as: "child", attributes: ["child_id", "nickname", "avatar"] }] }
    ]
  });
  return { data: normalizePost(fresh) };
}

// ===== 老师工作台 =====

function localToday() {
  const now = new Date(Date.now() + 8 * 60 * 60 * 1000);
  return now.toISOString().slice(0, 10);
}

async function getTeacherWorkbench(userId) {
  const teacher = await ensureTeacherProfile(userId);
  const today = localToday();

  // 今日排课（按开始时间升序）
  const schedules = await Schedule.findAll({
    where: { teacher_id: teacher.teacher_id, lesson_date: today },
    include: [
      { model: Class, as: "classItem", attributes: ["class_id", "name", "enrolled"] },
      { model: Course, as: "course", attributes: ["course_id", "studio_id", "title", "duration_min"] }
    ],
    order: [["start_time", "ASC"]]
  });

  const todayList = [];
  let todayPending = 0;

  for (const schedule of schedules) {
    const roster = await findRosterByCourse(schedule.course_id, schedule.course.studio_id);

    const leaveRows = await LeaveRequest.findAll({
      where: { schedule_id: schedule.schedule_id, status: 1 },
      attributes: ["child_id"]
    });
    const logRows = await LessonLog.findAll({
      where: { schedule_id: schedule.schedule_id, source: { [Op.in]: [1, 2] } },
      attributes: ["child_id", "source"]
    });

    const leaveSet = new Set(leaveRows.map((r) => String(r.child_id)));
    const consumedSet = new Set(logRows.map((r) => String(r.child_id)));
    const sourceByChild = new Map(logRows.map((r) => [String(r.child_id), Number(r.source)]));

    const students = roster.map((balance) => ({
      child_id: String(balance.child_id),
      nickname: balance.child?.nickname || "宝宝",
      avatar: balance.child?.avatar || null,
      leave: leaveSet.has(String(balance.child_id)),
      consumed: consumedSet.has(String(balance.child_id)),
      consumed_source: sourceByChild.get(String(balance.child_id)) || 0,
      remaining_lessons: Number(balance.remaining_lessons || 0)
    }));

    const consumedCount = roster.filter((r) => consumedSet.has(String(r.child_id))).length;
    const leaveCount = roster.filter((r) => leaveSet.has(String(r.child_id))).length;
    const expectCount = Math.max(roster.length - leaveCount, 0);

    let consumeStatus = "pending";
    if (roster.length > 0 && consumedCount >= expectCount) {
      consumeStatus = "completed";
    } else if (consumedCount > 0) {
      consumeStatus = "partial";
    }
    if (consumeStatus !== "completed") {
      todayPending += 1;
    }

    todayList.push({
      schedule_id: String(schedule.schedule_id),
      start_time: schedule.start_time,
      end_time: schedule.end_time,
      location: schedule.location,
      is_makeup: Boolean(schedule.is_makeup),
      consume_status: consumeStatus,
      class: schedule.classItem
        ? { class_id: String(schedule.classItem.class_id), name: schedule.classItem.name }
        : null,
      course: schedule.course
        ? { course_id: String(schedule.course.course_id), title: schedule.course.title }
        : null,
      students
    });
  }

  // 在读学生：老师名下班级对应课程的有效在读学生数（有效权益去重，兼容历史未绑班级数据）
  const teacherClassRows = await Class.findAll({
    where: { teacher_id: teacher.teacher_id },
    attributes: ["class_id", "course_id"]
  });
  const teacherCourseIds = teacherClassRows.map((c) => String(c.course_id));
  let activeStudents = 0;
  if (teacherCourseIds.length > 0) {
    const activeBalances = await ChildCourseBalance.findAll({
      where: {
        course_id: { [Op.in]: teacherCourseIds },
        status: { [Op.in]: [1, 2] }
      },
      attributes: ["child_id"]
    });
    activeStudents = new Set(activeBalances.map((b) => String(b.child_id))).size;
  }

  // 本月出勤率：本月已消课人次 / 本月应到人次
  const monthStart = `${today.slice(0, 8)}01`;
  const monthSchedules = await Schedule.findAll({
    where: {
      teacher_id: teacher.teacher_id,
      lesson_date: { [Op.gte]: monthStart }
    },
    attributes: ["schedule_id", "course_id", "studio_id"]
  });

  let expected = 0;
  let attended = 0;
  for (const ms of monthSchedules) {
    const roster = await findRosterByCourse(ms.course_id, ms.studio_id);
    const leaves = await LeaveRequest.count({
      where: { schedule_id: ms.schedule_id, status: 1 }
    });
    expected += Math.max(roster.length - leaves, 0);
    const logs = await LessonLog.count({
      where: { schedule_id: ms.schedule_id, source: { [Op.in]: [1, 2] } }
    });
    attended += Math.min(logs, roster.length);
  }
  const attendanceRate = expected > 0 ? Math.round((attended / expected) * 100) : 0;

  return {
    stats: {
      today_pending: todayPending,
      active_students: activeStudents,
      attendance_rate: attendanceRate
    },
    today: todayList
  };
}

async function getTeacherMine(userId) {
  const teacher = await ensureTeacherProfile(userId);
  const teacherDetail = await TeacherProfile.findByPk(teacher.teacher_id, {
    include: [
      { model: User, as: "user", attributes: ["user_id", "nickname", "avatar"] },
      { model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] }
    ]
  });

  // 在读学生：老师名下班级对应课程的有效在读学生数（有效权益去重，与工作台口径一致）
  const teacherClassRows = await Class.findAll({
    where: { teacher_id: teacher.teacher_id },
    attributes: ["class_id", "course_id"]
  });
  const teacherCourseIds = teacherClassRows.map((c) => String(c.course_id));
  let activeStudents = 0;
  if (teacherCourseIds.length > 0) {
    const activeBalances = await ChildCourseBalance.findAll({
      where: {
        course_id: { [Op.in]: teacherCourseIds },
        status: { [Op.in]: [1, 2] }
      },
      attributes: ["child_id"]
    });
    activeStudents = new Set(activeBalances.map((b) => String(b.child_id))).size;
  }

  // 累计课时：帖子消课（source=1）+ 排课消课（source=2）
  const postLogs = await LessonLog.findAll({
    where: { source: 1 },
    include: [
      { model: Post, as: "post", where: { author_id: userId }, attributes: [] }
    ],
    attributes: ["delta"]
  });
  const scheduleLogs = await LessonLog.findAll({
    where: { source: 2 },
    include: [
      {
        model: Schedule,
        as: "schedule",
        where: { teacher_id: teacher.teacher_id },
        attributes: []
      }
    ],
    attributes: ["delta"]
  });
  const totalLessons = [...postLogs, ...scheduleLogs].reduce(
    (sum, log) => sum + Math.abs(Number(log.delta || 0)),
    0
  );

  // 我的作品：老师发帖数
  const postCount = await Post.count({ where: { author_id: userId } });

  return {
    profile: {
      teacher_id: String(teacherDetail.teacher_id),
      real_name: teacherDetail.real_name || "",
      nickname: teacherDetail.user?.nickname || "老师",
      avatar: teacherDetail.user?.avatar || null,
      subjects: Array.isArray(teacherDetail.subjects) ? teacherDetail.subjects : [],
      years: Number(teacherDetail.years || 0),
      intro: teacherDetail.intro || "",
      cert_status: Number(teacherDetail.cert_status || 0),
      studio: teacherDetail.studio
        ? { studio_id: String(teacherDetail.studio.studio_id), name: teacherDetail.studio.name }
        : null
    },
    stats: {
      active_students: activeStudents,
      total_lessons: totalLessons,
      post_count: postCount
    }
  };
}

async function teacherAttendSchedule(userId, scheduleId, payload) {
  const teacher = await ensureTeacherProfile(userId);
  const schedule = await Schedule.findByPk(scheduleId, {
    include: [
      { model: Course, as: "course", attributes: ["course_id", "studio_id"] }
    ]
  });
  if (!schedule || String(schedule.teacher_id) !== String(teacher.teacher_id)) {
    throw new Error("Schedule does not belong to teacher");
  }

  // 老师端只传 child_id + status：order_id 从课程花名册自动补齐
  const roster = await findRosterByCourse(schedule.course_id, schedule.course.studio_id);
  const rosterMap = new Map(roster.map((b) => [String(b.child_id), b]));
  const students = (payload.students || []).map((item) => {
    const balance = rosterMap.get(String(item.child_id));
    if (!balance) {
      throw new Error("Student is not enrolled in class course");
    }
    return {
      child_id: String(item.child_id),
      order_id: String(balance.order_id),
      status: Number(item.status ?? 1),
      note: item.note || null
    };
  });

  return attendSchedule(scheduleId, { students, note: payload.note });
}

async function teacherUndoAttendance(userId, scheduleId, childIds) {
  const teacher = await ensureTeacherProfile(userId);
  const schedule = await Schedule.findByPk(scheduleId, { attributes: ["schedule_id", "teacher_id", "is_makeup"] });
  if (!schedule || String(schedule.teacher_id) !== String(teacher.teacher_id)) {
    throw new Error("Schedule does not belong to teacher");
  }

  const ids = Array.isArray(childIds) ? childIds : [childIds];
  if (!ids.length) {
    throw new Error("child_ids is required");
  }

  return sequelize.transaction(async (transaction) => {
    const results = [];
    for (const childId of ids) {
      const log = await LessonLog.findOne({
        where: {
          schedule_id: scheduleId,
          child_id: childId,
          source: { [Op.in]: [1, 2] }
        },
        transaction,
        lock: transaction.LOCK.UPDATE
      });
      if (!log) {
        results.push({ child_id: String(childId), undone: false, reason: "无点名消课记录" });
        continue;
      }

      const delta = Math.abs(Number(log.delta || 1));
      const order = await Order.findByPk(log.order_id, { transaction, lock: transaction.LOCK.UPDATE });
      const balance = await ChildCourseBalance.findOne({
        where: { order_id: log.order_id, course_id: log.course_id, status: { [Op.in]: [1, 2] } },
        transaction,
        lock: transaction.LOCK.UPDATE
      });
      if (!order || !balance) {
        results.push({ child_id: String(childId), undone: false, reason: "订单或课时包不存在" });
        continue;
      }

      const remainingAfter = Number(balance.remaining_lessons || 0) + delta;
      await order.update(
        {
          consumed_lessons: Math.max(Number(order.consumed_lessons || 0) - delta, 0)
        },
        { transaction }
      );
      // 已完成订单（课时恰好用完）撤销后恢复为已支付
      if (Number(order.status) === 2 && remainingAfter > 0) {
        await order.update({ status: 1 }, { transaction });
      }
      await balance.update(
        {
          consumed_lessons: Math.max(Number(balance.consumed_lessons || 0) - delta, 0),
          remaining_lessons: remainingAfter
        },
        { transaction }
      );
      await Attendance.destroy({
        where: { schedule_id: scheduleId, child_id: childId },
        transaction
      });
      // 老师发帖消课（source=1）：同步解除帖子与该学生的关联（与帖子侧撤销一致）
      if (Number(log.source) === 1 && log.post_id) {
        await PostStudent.destroy({
          where: { post_id: log.post_id, child_id: childId, deducted: 1 },
          transaction
        });
      }
      await log.destroy({ transaction });

      // 补课排课撤销出勤 → 对应请假单补课状态回退为待补
      if (schedule.is_makeup) {
        await resetMakeupStatus(schedule, childId, transaction);
      }

      results.push({ child_id: String(childId), undone: true, remaining_lessons: remainingAfter });
    }

    return {
      schedule_id: String(scheduleId),
      processed_count: results.filter((r) => r.undone).length,
      list: results
    };
  });
}

async function undoTeacherPostConsumption(userId, postId, childIds) {
  const post = await Post.findOne({ where: { post_id: postId, author_id: userId } });
  if (!post) {
    throw new Error("Post not found");
  }

  const ids = Array.isArray(childIds) ? childIds : [childIds];
  if (!ids.length) {
    throw new Error("child_ids is required");
  }

  return sequelize.transaction(async (transaction) => {
    const results = [];
    for (const childId of ids) {
      const log = await LessonLog.findOne({
        where: { post_id: postId, child_id: childId, source: 1 },
        transaction,
        lock: transaction.LOCK.UPDATE
      });
      if (!log) {
        results.push({ child_id: String(childId), undone: false, reason: "该学生未在本帖消课" });
        continue;
      }

      const delta = Math.abs(Number(log.delta || 1));
      const order = await Order.findByPk(log.order_id, { transaction, lock: transaction.LOCK.UPDATE });
      const balance = await ChildCourseBalance.findOne({
        where: { order_id: log.order_id, course_id: log.course_id, status: { [Op.in]: [1, 2] } },
        transaction,
        lock: transaction.LOCK.UPDATE
      });
      if (!order || !balance) {
        results.push({ child_id: String(childId), undone: false, reason: "订单或课时包不存在" });
        continue;
      }

      const remainingAfter = Number(balance.remaining_lessons || 0) + delta;
      await order.update(
        { consumed_lessons: Math.max(Number(order.consumed_lessons || 0) - delta, 0) },
        { transaction }
      );
      if (Number(order.status) === 2 && remainingAfter > 0) {
        await order.update({ status: 1 }, { transaction });
      }
      await balance.update(
        {
          consumed_lessons: Math.max(Number(balance.consumed_lessons || 0) - delta, 0),
          remaining_lessons: remainingAfter
        },
        { transaction }
      );
      // 撤销后该学生不再与帖子关联（删除关联记录，详情接口不再返回该学生）
      await PostStudent.destroy({
        where: { post_id: postId, child_id: childId, deducted: 1 },
        transaction
      });
      await log.destroy({ transaction });

      results.push({ child_id: String(childId), undone: true, remaining_lessons: remainingAfter });
    }

    return {
      post_id: String(postId),
      processed_count: results.filter((r) => r.undone).length,
      list: results
    };
  });
}

async function listTeacherReviews(userId, query = {}) {
  const teacher = await ensureTeacherProfile(userId);
  // 老师名下班级 → 课程
  const classes = await Class.findAll({
    where: { teacher_id: teacher.teacher_id },
    include: [{ model: Course, as: "course", attributes: ["course_id"] }]
  });
  const courseIds = [...new Set(
    classes.map((c) => c.course && String(c.course.course_id)).filter(Boolean)
  )];
  if (courseIds.length === 0) {
    return { total: 0, average: 0, rating_distribution: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }, list: [] };
  }

  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.page_size) || 10, 30);
  const where = { course_id: { [Op.in]: courseIds }, status: 1 };

  const { count, rows } = await CourseReview.findAndCountAll({
    where,
    include: [
      { model: User, as: "user", attributes: ["user_id", "nickname", "avatar"] },
      { model: Course, as: "course", attributes: ["course_id", "title"] }
    ],
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  // 评分分布
  const dist = await CourseReview.findAll({
    where,
    attributes: ["rating"],
    raw: true
  });
  const ratingCount = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
  let sum = 0;
  dist.forEach((r) => {
    const key = String(r.rating);
    if (ratingCount[key] !== undefined) {
      ratingCount[key] += 1;
      sum += Number(r.rating);
    }
  });

  return {
    total: count,
    average: count ? Number((sum / count).toFixed(1)) : 0,
    rating_distribution: ratingCount,
    list: rows.map((r) => ({
      review_id: String(r.review_id),
      rating: r.rating,
      content: r.content,
      created_at: r.created_at,
      user: r.user
        ? {
            user_id: String(r.user.user_id),
            nickname: r.user.nickname,
            avatar: r.user.avatar
          }
        : null,
      course: r.course
        ? {
            course_id: String(r.course.course_id),
            title: r.course.title
          }
        : null
    }))
  };
}

module.exports = {
  listTeacherClasses,
  listTeacherCourses,
  listTeacherStudents,
  getTeacherClassStudents,
  listTeacherTimetable,
  listTeacherLeaves,
  listTeacherReviews,
  reviewTeacherLeave,
  arrangeTeacherMakeup,
  listTeacherMakeupCandidates,
  createTeacherPost,
  updateTeacherPost,
  markTeacherPostStudents,
  getTeacherWorkbench,
  getTeacherMine,
  teacherAttendSchedule,
  teacherUndoAttendance,
  undoTeacherPostConsumption
};

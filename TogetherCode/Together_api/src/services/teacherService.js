const { Op } = require("sequelize");
const {
  sequelize,
  TeacherProfile,
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
  TeacherStudioBinding
} = require("../models");
const { applyLessonConsumption } = require("./studentService");
const { reviewLeaveRequest } = require("./leaveService");

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
    studio_ids: (teacher.bindings || []).map((item) => String(item.studio_id)),
    studio_names: (teacher.bindings || []).map((item) => (item.studio ? item.studio.name : null)),
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
      : null
  };
}

function normalizePost(post, students = []) {
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
    students
  };
}

async function ensureTeacherProfile(userId, transaction) {
  const teacher = await TeacherProfile.findOne({
    where: { user_id: userId },
    include: [
      {
        model: User,
        as: "user",
        attributes: ["user_id", "nickname", "avatar", "phone"]
      },
      {
        model: TeacherStudioBinding,
        as: "bindings",
        where: { status: 1 },
        required: false,
        include: [
          {
            model: require("../models").StudioProfile,
            as: "studio",
            attributes: ["studio_id", "name"]
          }
        ]
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
          studio_id: studioId
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
  }

  const courseId = schedule?.course_id || classItem?.course_id || payload.course_id;
  const course = await Course.findByPk(courseId, { transaction });
  if (!course) {
    throw new Error("Course not found");
  }

  const binding = await TeacherStudioBinding.findOne({
    where: { teacher_id: teacher.teacher_id, studio_id: course.studio_id, status: 1 },
    transaction
  });
  if (!binding) {
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
      schedule_id: payload.schedule_id
    },
    transaction
  );

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
      selectable: !leaveMap.has(String(balance.child.child_id))
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

  const rows = await LeaveRequest.findAll({
    where,
    include: [
      {
        model: Class,
        as: "classItem",
        required: true,
        where: {
          teacher_id: teacher.teacher_id
        },
        attributes: ["class_id", "name"]
      },
      { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
      { model: User, as: "parent", attributes: ["user_id", "nickname", "phone"] },
      {
        model: Schedule,
        as: "schedule",
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

async function createTeacherPost(userId, payload) {
  return sequelize.transaction(async (transaction) => {
    const teacher = await ensureTeacherProfile(userId, transaction);
    const { course } = await resolvePostContext(teacher, payload, transaction);

    const post = await Post.create(
      {
        author_id: userId,
        author_role: 2,
        type: Number(payload.type || 1),
        course_id: course.course_id,
        images: payload.images || [],
        content: payload.content || null,
        visibility: payload.visibility !== undefined ? Number(payload.visibility) : 2,
        status: 1
      },
      { transaction }
    );

    const students = await consumeStudentsForPost(post, teacher, payload, transaction);
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
    return normalizePost(post, students);
  });
}

module.exports = {
  listTeacherClasses,
  getTeacherClassStudents,
  listTeacherTimetable,
  listTeacherLeaves,
  reviewTeacherLeave,
  createTeacherPost,
  markTeacherPostStudents
};

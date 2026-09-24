const { Op } = require("sequelize");
const { sequelize, Class, Course, TeacherProfile, Schedule, StudioProfile, TeacherStudioBinding } = require("../models");
const { generateId } = require("../utils/id");

function normalizeClassItem(classItem) {
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
          duration_min: classItem.course.duration_min,
          class_size: classItem.course.class_size
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

function normalizeScheduleItem(item) {
  return {
    schedule_id: String(item.schedule_id),
    studio_id: String(item.studio_id),
    class_id: String(item.class_id),
    course_id: String(item.course_id),
    teacher_id: item.teacher_id ? String(item.teacher_id) : null,
    lesson_date: item.lesson_date,
    start_time: item.start_time,
    end_time: item.end_time,
    location: item.location,
    is_makeup: Boolean(item.is_makeup),
    makeup_from: item.makeup_from ? String(item.makeup_from) : null,
    status: item.status,
    remark: item.remark,
    class: item.classItem
      ? {
          class_id: String(item.classItem.class_id),
          name: item.classItem.name,
          capacity: item.classItem.capacity,
          enrolled: item.classItem.enrolled
        }
      : null,
    course: item.course
      ? {
          course_id: String(item.course.course_id),
          title: item.course.title,
          duration_min: item.course.duration_min
        }
      : null,
    teacher: item.teacher
      ? {
          teacher_id: String(item.teacher.teacher_id),
          real_name: item.teacher.real_name
        }
      : null
  };
}

function parseTimeToMinutes(time) {
  const [hour, minute] = String(time || "")
    .split(":")
    .map((value) => Number(value));

  return hour * 60 + minute;
}

/** 判断排课是否已开始（当前时间 >= 上课日期+开始时间） */
function isScheduleStarted(schedule) {
  const now = new Date(Date.now() + 8 * 60 * 60 * 1000); // UTC+8
  const today = now.toISOString().slice(0, 10);
  if (schedule.lesson_date < today) return true;
  if (schedule.lesson_date > today) return false;
  return parseTimeToMinutes(schedule.start_time) <= (now.getUTCHours() * 60 + now.getUTCMinutes());
}

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

async function ensureStudio(studioId, transaction) {
  const studio = await StudioProfile.findByPk(studioId, { transaction });
  if (!studio) {
    throw new Error("Studio not found");
  }
  return studio;
}

async function ensureCourse(courseId, studioId, transaction) {
  const course = await Course.findByPk(courseId, { transaction });
  if (!course) {
    throw new Error("Course not found");
  }
  if (String(course.studio_id) !== String(studioId)) {
    throw new Error("Course does not belong to studio");
  }
  return course;
}

async function ensureTeacher(teacherId, studioId, transaction) {
  if (!teacherId) {
    return null;
  }

  const teacher = await TeacherProfile.findByPk(teacherId, { transaction });
  if (!teacher) {
    throw new Error("Teacher not found");
  }
  const binding = await TeacherStudioBinding.findOne({
    where: { teacher_id: teacherId, studio_id: studioId, status: 1 },
    transaction
  });
  if (!binding) {
    throw new Error("Teacher does not belong to studio");
  }
  return teacher;
}

async function listStudioClasses(query = {}) {
  const where = {};
  if (query.course_id) {
    where.course_id = query.course_id;
  }
  if (query.teacher_id) {
    where.teacher_id = query.teacher_id;
  }
  if (query.q) {
    where.name = {
      [Op.like]: `%${query.q.trim()}%`
    };
  }

  const rows = await Class.findAll({
    where,
    include: [
      {
        model: Course,
        as: "course",
        required: true,
        where: {
          studio_id: query.studio_id
        },
        attributes: ["course_id", "title", "duration_min", "class_size"]
      },
      {
        model: TeacherProfile,
        as: "teacher",
        attributes: ["teacher_id", "real_name"]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  return {
    total: rows.length,
    list: rows.map(normalizeClassItem)
  };
}

async function createStudioClass(payload) {
  return sequelize.transaction(async (transaction) => {
    await ensureStudio(payload.studio_id, transaction);
    const course = await ensureCourse(payload.course_id, payload.studio_id, transaction);
    await ensureTeacher(payload.teacher_id, payload.studio_id, transaction);

    const classItem = await Class.create(
      {
        class_id: generateId(),
        course_id: payload.course_id,
        teacher_id: payload.teacher_id || null,
        name: payload.name,
        schedule_rule: payload.schedule_rule || null,
        start_date: payload.start_date || null,
        end_date: payload.end_date || null,
        capacity: Number(payload.capacity || course.class_size || 12),
        enrolled: Number(payload.enrolled || 0)
      },
      { transaction }
    );

    const row = await Class.findByPk(classItem.class_id, {
      transaction,
      include: [
        {
          model: Course,
          as: "course",
          attributes: ["course_id", "title", "duration_min", "class_size"]
        },
        {
          model: TeacherProfile,
          as: "teacher",
          attributes: ["teacher_id", "real_name"]
        }
      ]
    });

    return normalizeClassItem(row);
  });
}

async function updateStudioClass(classId, payload) {
  return sequelize.transaction(async (transaction) => {
    const classItem = await Class.findByPk(classId, {
      transaction,
      include: [{ model: Course, as: "course", attributes: ["course_id", "studio_id"] }]
    });
    if (!classItem) {
      throw new Error("Class not found");
    }
    if (payload.studio_id && String(classItem.course.studio_id) !== String(payload.studio_id)) {
      throw new Error("Class does not belong to studio");
    }

    const updates = {};
    if (payload.name !== undefined) {
      updates.name = String(payload.name).trim();
    }
    if (payload.teacher_id !== undefined) {
      await ensureTeacher(payload.teacher_id, String(classItem.course.studio_id), transaction);
      updates.teacher_id = payload.teacher_id;
    }
    if (payload.capacity !== undefined) {
      updates.capacity = Number(payload.capacity);
    }
    if (payload.time !== undefined) {
      const rule = classItem.schedule_rule || {};
      updates.schedule_rule = { weekday: Array.isArray(rule.weekday) ? rule.weekday : [], time: String(payload.time) };
    }

    if (Object.keys(updates).length) {
      await classItem.update(updates, { transaction });
    }

    // 班级换老师时，同步更新该班级下所有未消课排课的老师
    let updatedSchedules = 0;
    if (updates.teacher_id && String(classItem.teacher_id) !== String(updates.teacher_id)) {
      const [count] = await Schedule.update(
        { teacher_id: updates.teacher_id },
        { where: { class_id: classId, status: 0 }, transaction }
      );
      updatedSchedules = count;
    }

    const row = await Class.findByPk(classItem.class_id, {
      transaction,
      include: [
        {
          model: Course,
          as: "course",
          attributes: ["course_id", "title", "duration_min", "class_size"]
        },
        {
          model: TeacherProfile,
          as: "teacher",
          attributes: ["teacher_id", "real_name"]
        }
      ]
    });

    const result = normalizeClassItem(row);
    if (updatedSchedules > 0) {
      result.updated_schedules = updatedSchedules;
    }
    return result;
  });
}

async function createStudioSchedule(payload) {
  return sequelize.transaction(async (transaction) => {
    await ensureStudio(payload.studio_id, transaction);
    const classItem = await Class.findByPk(payload.class_id, {
      transaction,
      include: [
        {
          model: Course,
          as: "course",
          attributes: ["course_id", "studio_id", "title", "duration_min"]
        }
      ]
    });

    if (!classItem || !classItem.teacher_id) {
      throw new Error("请先为班级指定授课老师");
    }
    if (!classItem.course || String(classItem.course.studio_id) !== String(payload.studio_id)) {
      throw new Error("Class does not belong to studio");
    }

    // 排课老师固定为班级授课老师，不可更换
    const teacherId = String(classItem.teacher_id);
    await ensureTeacher(teacherId, payload.studio_id, transaction);

    if (payload.makeup_from) {
      const sourceSchedule = await Schedule.findByPk(payload.makeup_from, { transaction });
      if (!sourceSchedule) {
        throw new Error("Makeup source schedule not found");
      }
    }

    const startMinutes = parseTimeToMinutes(payload.start_time);
    const endMinutes = parseTimeToMinutes(payload.end_time);
    if (endMinutes <= startMinutes) {
      throw new Error("Schedule end time must be greater than start time");
    }

    const conflictWhere = {
      studio_id: payload.studio_id,
      lesson_date: payload.lesson_date,
      [Op.or]: []
    };

    if (teacherId) {
      conflictWhere[Op.or].push({ teacher_id: teacherId });
    }
    conflictWhere[Op.or].push({ class_id: payload.class_id });

    const existing = await Schedule.findAll({
      where: conflictWhere,
      transaction
    });

    const conflicts = existing.filter((item) => {
      const itemStart = parseTimeToMinutes(item.start_time);
      const itemEnd = parseTimeToMinutes(item.end_time);
      return startMinutes < itemEnd && endMinutes > itemStart;
    });

    if (conflicts.length) {
      throw new Error("Schedule conflict detected");
    }

    const schedule = await Schedule.create(
      {
        schedule_id: generateId(),
        studio_id: payload.studio_id,
        class_id: payload.class_id,
        course_id: classItem.course_id,
        teacher_id: teacherId,
        lesson_date: payload.lesson_date,
        start_time: payload.start_time,
        end_time: payload.end_time,
        location: payload.location || null,
        is_makeup: Boolean(payload.is_makeup || payload.makeup_from),
        makeup_from: payload.makeup_from || null,
        status: payload.status !== undefined ? Number(payload.status) : 0,
        remark: payload.remark || null
      },
      { transaction }
    );

    const row = await Schedule.findByPk(schedule.schedule_id, {
      transaction,
      include: [
        {
          model: Class,
          as: "classItem",
          attributes: ["class_id", "name", "capacity", "enrolled"]
        },
        {
          model: Course,
          as: "course",
          attributes: ["course_id", "title", "duration_min"]
        },
        {
          model: TeacherProfile,
          as: "teacher",
          attributes: ["teacher_id", "real_name"]
        }
      ]
    });

    return normalizeScheduleItem(row);
  });
}

/// 编辑排课：可修改日期/时间/地点/课时标题/老师；已消课排课不允许换老师
async function updateStudioSchedule(scheduleId, payload) {
  return sequelize.transaction(async (transaction) => {
    const schedule = await Schedule.findByPk(scheduleId, {
      transaction,
      include: [
        { model: Class, as: "classItem", attributes: ["class_id", "name", "capacity", "enrolled"] },
        { model: Course, as: "course", attributes: ["course_id", "studio_id", "title", "duration_min"] },
        { model: TeacherProfile, as: "teacher", attributes: ["teacher_id", "real_name"] }
      ]
    });
    if (!schedule) {
      return null;
    }

    // 已消课排课不允许编辑
    if (Number(schedule.status) !== 0) {
      throw new Error("已消课排课不允许编辑");
    }

    const updates = {};
    const started = isScheduleStarted(schedule);

    if (payload.lesson_date !== undefined) {
      if (started) {
        throw new Error("已开始的排课不允许修改上课日期");
      }
      updates.lesson_date = payload.lesson_date;
    }
    if (payload.start_time !== undefined) {
      if (started) {
        throw new Error("已开始的排课不允许修改上课时间");
      }
      updates.start_time = payload.start_time;
    }
    if (payload.end_time !== undefined) {
      if (started) {
        throw new Error("已开始的排课不允许修改上课时间");
      }
      updates.end_time = payload.end_time;
    }
    if (payload.location !== undefined) {
      updates.location = payload.location || null;
    }
    if (payload.remark !== undefined) {
      updates.remark = payload.remark || null;
    }
    if (payload.teacher_id !== undefined) {
      if (started) {
        throw new Error("已开始的排课不允许更换老师");
      }
      await ensureTeacher(payload.teacher_id, String(schedule.studio_id), transaction);
      updates.teacher_id = payload.teacher_id;
    }

    if (Object.keys(updates).length === 0) {
      return normalizeScheduleItem(schedule);
    }

    // 时间冲突检测（日期或时间有变更时）
    const newDate = updates.lesson_date || schedule.lesson_date;
    const newStart = updates.start_time || schedule.start_time;
    const newEnd = updates.end_time || schedule.end_time;
    const newTeacherId = updates.teacher_id || schedule.teacher_id;

    if (updates.lesson_date || updates.start_time || updates.end_time || updates.teacher_id) {
      const startMinutes = parseTimeToMinutes(newStart);
      const endMinutes = parseTimeToMinutes(newEnd);
      if (endMinutes <= startMinutes) {
        throw new Error("结束时间必须晚于开始时间");
      }

      const conflictWhere = {
        studio_id: schedule.studio_id,
        lesson_date: newDate,
        schedule_id: { [Op.ne]: scheduleId },
        [Op.or]: []
      };
      if (newTeacherId) {
        conflictWhere[Op.or].push({ teacher_id: newTeacherId });
      }
      conflictWhere[Op.or].push({ class_id: schedule.class_id });

      const existing = await Schedule.findAll({ where: conflictWhere, transaction });
      const conflicts = existing.filter((item) => {
        const itemStart = parseTimeToMinutes(item.start_time);
        const itemEnd = parseTimeToMinutes(item.end_time);
        return startMinutes < itemEnd && endMinutes > itemStart;
      });
      if (conflicts.length) {
        throw new Error("Schedule conflict detected");
      }
    }

    await schedule.update(updates, { transaction });

    const row = await Schedule.findByPk(scheduleId, {
      transaction,
      include: [
        { model: Class, as: "classItem", attributes: ["class_id", "name", "capacity", "enrolled"] },
        { model: Course, as: "course", attributes: ["course_id", "title", "duration_min"] },
        { model: TeacherProfile, as: "teacher", attributes: ["teacher_id", "real_name"] }
      ]
    });

    return normalizeScheduleItem(row);
  });
}

async function deleteStudioSchedule(scheduleId) {
  const schedule = await Schedule.findByPk(scheduleId);
  if (!schedule) {
    return null;
  }
  // 已消课排课不允许删除
  if (Number(schedule.status) !== 0) {
    throw new Error("已消课排课不允许删除");
  }
  // 已开始的排课不允许删除
  if (isScheduleStarted(schedule)) {
    throw new Error("已开始的排课不允许删除");
  }
  await schedule.destroy();
  return { schedule_id: String(scheduleId), deleted: true };
}

async function listStudioSchedules(query = {}) {  const range = getWeekRange(query.week);
  const where = {
    studio_id: query.studio_id,
    lesson_date: {
      [Op.between]: [range.start, range.end]
    }
  };

  if (query.teacher_id) {
    where.teacher_id = query.teacher_id;
  }
  if (query.class_id) {
    where.class_id = query.class_id;
  }

  const rows = await Schedule.findAll({
    where,
    include: [
      {
        model: Class,
        as: "classItem",
        attributes: ["class_id", "name", "capacity", "enrolled"]
      },
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "title", "duration_min"]
      },
      {
        model: TeacherProfile,
        as: "teacher",
        attributes: ["teacher_id", "real_name"]
      }
    ],
    order: [
      ["lesson_date", "ASC"],
      ["start_time", "ASC"]
    ]
  });

  const list = rows.map(normalizeScheduleItem);
  const conflicts = [];

  for (let i = 0; i < list.length; i += 1) {
    for (let j = i + 1; j < list.length; j += 1) {
      const current = list[i];
      const next = list[j];
      if (current.lesson_date !== next.lesson_date) {
        continue;
      }

      const overlap =
        parseTimeToMinutes(current.start_time) < parseTimeToMinutes(next.end_time) &&
        parseTimeToMinutes(current.end_time) > parseTimeToMinutes(next.start_time);

      if (!overlap) {
        continue;
      }

      if (current.teacher_id && current.teacher_id === next.teacher_id) {
        conflicts.push({
          type: "teacher",
          lesson_date: current.lesson_date,
          teacher_id: current.teacher_id,
          schedule_ids: [current.schedule_id, next.schedule_id]
        });
      } else if (current.class_id === next.class_id) {
        conflicts.push({
          type: "class",
          lesson_date: current.lesson_date,
          class_id: current.class_id,
          schedule_ids: [current.schedule_id, next.schedule_id]
        });
      }
    }
  }

  return {
    week_start: range.start,
    week_end: range.end,
    total: list.length,
    list,
    conflicts
  };
}

/**
 * 老师 App 端新增排课（POST /v1/schedules）
 * 身份从 token 推导：老师 → 班级所属工作室 → 校验合作绑定 + 班级归属，复用工作室排课核心（冲突检测等）。
 */
async function createTeacherSchedule(userId, payload) {
  const teacher = await TeacherProfile.findOne({ where: { user_id: userId } });
  if (!teacher) {
    throw new Error("Teacher profile not found");
  }

  const classItem = await Class.findByPk(payload.class_id, {
    include: [
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "studio_id", "title", "duration_min"]
      }
    ]
  });
  if (!classItem || !classItem.course) {
    throw new Error("Class not found");
  }
  const studioId = String(classItem.course.studio_id);

  // 老师必须与该工作室存在有效合作绑定
  const binding = await TeacherStudioBinding.findOne({
    where: { teacher_id: teacher.teacher_id, studio_id: studioId, status: 1 }
  });
  if (!binding) {
    throw new Error("Teacher does not belong to studio");
  }

  // 班级授课老师必须是当前老师（未指定授课老师的班级允许其合作老师排课）
  if (classItem.teacher_id && String(classItem.teacher_id) !== String(teacher.teacher_id)) {
    throw new Error("Class does not belong to teacher");
  }

  return createStudioSchedule({
    ...payload,
    studio_id: studioId,
    teacher_id: teacher.teacher_id
  });
}

function expandDates(payload, classItem) {
  const dates = [];
  if (Array.isArray(payload.dates) && payload.dates.length) {
    for (const raw of payload.dates) {
      const d = String(raw || "").trim();
      if (/^\d{4}-\d{2}-\d{2}$/.test(d) && !dates.includes(d)) {
        dates.push(d);
      }
    }
  } else if (Array.isArray(payload.weekdays) && payload.weekdays.length) {
    const weekdays = new Set(payload.weekdays.map((w) => Number(w)));
    // start_date 必须由前端传入；end_date 自动取班级的开课结束日期
    const startDate = payload.start_date;
    const endDate = payload.end_date || (classItem && classItem.end_date ? String(classItem.end_date).slice(0, 10) : null);
    if (!startDate) {
      throw new Error("每周固定排课需要选择开始日期");
    }
    if (!endDate) {
      throw new Error("班级未设置开课结束日期，请先在班级管理中设置");
    }
    const start = new Date(`${startDate}T00:00:00`);
    const end = new Date(`${endDate}T00:00:00`);
    const cursor = new Date(start);
    while (cursor <= end) {
      let wd = cursor.getDay(); // 0=周日
      if (wd === 0) wd = 7;
      if (weekdays.has(wd)) {
        const y = cursor.getFullYear();
        const m = String(cursor.getMonth() + 1).padStart(2, "0");
        const d = String(cursor.getDate()).padStart(2, "0");
        dates.push(`${y}-${m}-${d}`);
      }
      cursor.setDate(cursor.getDate() + 1);
    }
  }
  return dates;
}

/**
 * 批量排课：按日期数组 或 每周几+起止日期 一次生成多条排课。
 * 冲突/已存在的日期自动跳过，不中断整批。
 */
async function batchCreateStudioSchedules(payload) {
  // 先查班级信息供 expandDates 使用
  const classItem = await Class.findByPk(payload.class_id, {
    include: [{ model: Course, as: "course" }]
  });
  const dates = expandDates(payload, classItem);
  if (!dates.length) {
    throw new Error("No valid dates provided");
  }

  // 批量排课日期数不能超过课程总课时数
  if (classItem && classItem.course && classItem.course.total_lessons) {
    const totalLessons = Number(classItem.course.total_lessons);
    if (dates.length > totalLessons) {
      throw new Error(`排课日期数（${dates.length}）超过课程总课时数（${totalLessons}）`);
    }
  }

  const startMinutes = parseTimeToMinutes(payload.start_time);
  const endMinutes = parseTimeToMinutes(payload.end_time);
  if (endMinutes <= startMinutes) {
    throw new Error("Schedule end time must be greater than start time");
  }

  return sequelize.transaction(async (transaction) => {
    await ensureStudio(payload.studio_id, transaction);
    if (!classItem || !classItem.teacher_id) {
      throw new Error("请先为班级指定授课老师");
    }
    if (!classItem.course || String(classItem.course.studio_id) !== String(payload.studio_id)) {
      throw new Error("Class does not belong to studio");
    }

    // 排课老师固定为班级授课老师，不可更换
    const teacherId = String(classItem.teacher_id);
    await ensureTeacher(teacherId, payload.studio_id, transaction);

    const created = [];
    const skipped = [];
    for (const lessonDate of dates) {
      // 同一班级/老师 同日同时段冲突检测
      const conflictWhere = {
        studio_id: payload.studio_id,
        lesson_date: lessonDate,
        [Op.or]: []
      };
      if (teacherId) {
        conflictWhere[Op.or].push({ teacher_id: teacherId });
      }
      conflictWhere[Op.or].push({ class_id: payload.class_id });

      const existing = await Schedule.findAll({ where: conflictWhere, transaction });
      const hasConflict = existing.some((item) => {
        const itemStart = parseTimeToMinutes(item.start_time);
        const itemEnd = parseTimeToMinutes(item.end_time);
        return startMinutes < itemEnd && endMinutes > itemStart;
      });
      if (hasConflict) {
        skipped.push(lessonDate);
        continue;
      }

      const schedule = await Schedule.create(
        {
          schedule_id: generateId(),
          studio_id: payload.studio_id,
          class_id: payload.class_id,
          course_id: classItem.course_id,
          teacher_id: teacherId,
          lesson_date: lessonDate,
          start_time: payload.start_time,
          end_time: payload.end_time,
          location: payload.location || null,
          is_makeup: false,
          makeup_from: null,
          status: 0,
          remark: payload.remark || null
        },
        { transaction }
      );
      created.push(String(schedule.schedule_id));
    }

    return {
      total: dates.length,
      created: created.length,
      skipped: skipped.length,
      skipped_dates: skipped
    };
  });
}

module.exports = {
  listStudioClasses,
  createStudioClass,
  updateStudioClass,
  createStudioSchedule,
  updateStudioSchedule,
  batchCreateStudioSchedules,
  listStudioSchedules,
  createTeacherSchedule,
  deleteStudioSchedule
};

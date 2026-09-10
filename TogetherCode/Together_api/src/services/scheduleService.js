const { Op } = require("sequelize");
const { sequelize, Class, Course, TeacherProfile, Schedule, StudioProfile } = require("../models");
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
  if (teacher.studio_id && String(teacher.studio_id) !== String(studioId)) {
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

    if (!classItem) {
      throw new Error("Class not found");
    }
    if (!classItem.course || String(classItem.course.studio_id) !== String(payload.studio_id)) {
      throw new Error("Class does not belong to studio");
    }

    const teacherId = payload.teacher_id || classItem.teacher_id || null;
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

async function listStudioSchedules(query = {}) {
  const range = getWeekRange(query.week);
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

module.exports = {
  listStudioClasses,
  createStudioClass,
  createStudioSchedule,
  listStudioSchedules
};

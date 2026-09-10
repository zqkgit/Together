const { Op } = require("sequelize");
const {
  sequelize,
  Course,
  CoursePackage,
  Class,
  StudioProfile,
  TeacherProfile
} = require("../models");
const { generateId } = require("../utils/id");

function normalizeCourseItem(course) {
  return {
    course_id: String(course.course_id),
    title: course.title,
    cover: course.cover,
    category: course.category,
    age_min: course.age_min,
    age_max: course.age_max,
    total_lessons: course.total_lessons,
    duration_min: course.duration_min,
    price: course.price,
    class_size: course.class_size,
    rating: Number(course.rating),
    sales: course.sales,
    distribute_rate: Number(course.distribute_rate),
    validity_days: course.validity_days,
    status: course.status,
    studio: course.studio
      ? {
          studio_id: String(course.studio.studio_id),
          name: course.studio.name,
          address: course.studio.address,
          phone: course.studio.phone
        }
      : null,
    teacher: course.teacher
      ? {
          teacher_id: String(course.teacher.teacher_id),
          real_name: course.teacher.real_name,
          intro: course.teacher.intro,
          rating: Number(course.teacher.rating)
        }
      : null,
    packages: (course.packages || []).map((item) => ({
      package_id: String(item.package_id),
      name: item.name,
      lessons: item.lessons,
      price: item.price,
      original_price: item.original_price,
      status: item.status
    }))
  };
}

async function ensureStudio(studioId, transaction) {
  const studio = await StudioProfile.findByPk(studioId, { transaction });
  if (!studio) {
    throw new Error("Studio not found");
  }
  return studio;
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

async function listCourses(params = {}) {
  const where = {};

  if (params.status !== undefined && params.status !== null && params.status !== "") {
    where.status = Number(params.status);
  } else {
    where.status = 1;
  }

  if (params.q) {
    where.title = { [Op.like]: `%${params.q.trim()}%` };
  }

  if (params.category) {
    where.category = Number(params.category);
  }

  if (params.age) {
    const age = Number(params.age);
    where[Op.and] = [
      { age_min: { [Op.lte]: age } },
      { age_max: { [Op.gte]: age } }
    ];
  }

  if (params.studio_id) {
    where.studio_id = params.studio_id;
  }

  let order = [["created_at", "DESC"]];
  if (params.sort === "sales") {
    order = [["sales", "DESC"], ["created_at", "DESC"]];
  } else if (params.sort === "price_asc") {
    order = [["price", "ASC"], ["created_at", "DESC"]];
  } else if (params.sort === "price_desc") {
    order = [["price", "DESC"], ["created_at", "DESC"]];
  }

  const rows = await Course.findAll({
    where,
    include: [
      { model: StudioProfile, as: "studio", attributes: ["studio_id", "name", "address", "phone"] },
      { model: TeacherProfile, as: "teacher", attributes: ["teacher_id", "real_name", "intro", "rating"] },
      {
        model: CoursePackage,
        as: "packages",
        where: { status: 1 },
        required: false,
        attributes: ["package_id", "name", "lessons", "price", "original_price", "status"]
      }
    ],
    order
  });

  return {
    total: rows.length,
    list: rows.map(normalizeCourseItem)
  };
}

async function listStudioCourses(params = {}) {
  const where = {};

  if (params.studio_id) {
    where.studio_id = params.studio_id;
  }

  if (params.status !== undefined && params.status !== null && params.status !== "") {
    where.status = Number(params.status);
  }

  if (params.q) {
    where.title = { [Op.like]: `%${params.q.trim()}%` };
  }

  const rows = await Course.findAll({
    where,
    include: [
      { model: StudioProfile, as: "studio", attributes: ["studio_id", "name", "address", "phone"] },
      { model: TeacherProfile, as: "teacher", attributes: ["teacher_id", "real_name", "intro", "rating"] },
      {
        model: CoursePackage,
        as: "packages",
        required: false,
        attributes: ["package_id", "name", "lessons", "price", "original_price", "status"]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  return {
    total: rows.length,
    list: rows.map(normalizeCourseItem)
  };
}

async function getCourseDetail(courseId, options = {}) {
  const row = await Course.findByPk(courseId, {
    transaction: options.transaction,
    include: [
      { model: StudioProfile, as: "studio", attributes: ["studio_id", "name", "address", "phone", "intro"] },
      { model: TeacherProfile, as: "teacher", attributes: ["teacher_id", "real_name", "intro", "rating", "subjects"] },
      {
        model: CoursePackage,
        as: "packages",
        attributes: ["package_id", "name", "lessons", "price", "original_price", "status"]
      },
      {
        model: Class,
        as: "classes",
        attributes: ["class_id", "name", "capacity", "enrolled", "start_date", "end_date"]
      }
    ]
  });

  if (!row) {
    return null;
  }

  const payload = normalizeCourseItem(row);
  payload.classes = (row.classes || []).map((item) => ({
    class_id: String(item.class_id),
    name: item.name,
    capacity: item.capacity,
    enrolled: item.enrolled,
    start_date: item.start_date,
    end_date: item.end_date
  }));

  return payload;
}

async function createCourse(payload) {
  return sequelize.transaction(async (transaction) => {
    await ensureStudio(payload.studio_id, transaction);
    await ensureTeacher(payload.teacher_id, payload.studio_id, transaction);

    const course = await Course.create(
      {
        course_id: generateId(),
        studio_id: payload.studio_id,
        teacher_id: payload.teacher_id || null,
        title: payload.title,
        cover: payload.cover || null,
        category: Number(payload.category),
        age_min: payload.age_min || null,
        age_max: payload.age_max || null,
        total_lessons: Number(payload.total_lessons),
        duration_min: Number(payload.duration_min),
        price: Number(payload.price),
        class_size: Number(payload.class_size || 12),
        distribute_rate: payload.distribute_rate ? Number(payload.distribute_rate) : 0.08,
        validity_days: payload.validity_days || null,
        status: payload.status !== undefined ? Number(payload.status) : 0
      },
      { transaction }
    );

    await CoursePackage.bulkCreate(
      payload.packages.map((item) => ({
        package_id: generateId(),
        course_id: course.course_id,
        name: item.name,
        lessons: Number(item.lessons),
        price: Number(item.price),
        original_price: item.original_price ? Number(item.original_price) : null,
        status: item.status !== undefined ? Number(item.status) : 1
      })),
      { transaction }
    );

    return getCourseDetail(course.course_id, { transaction });
  });
}

async function updateCourse(courseId, payload) {
  return sequelize.transaction(async (transaction) => {
    const course = await Course.findByPk(courseId, { transaction });
    if (!course) {
      return null;
    }

    await ensureStudio(payload.studio_id, transaction);
    await ensureTeacher(payload.teacher_id, payload.studio_id, transaction);

    await course.update(
      {
        studio_id: payload.studio_id,
        teacher_id: payload.teacher_id || null,
        title: payload.title,
        cover: payload.cover || null,
        category: Number(payload.category),
        age_min: payload.age_min || null,
        age_max: payload.age_max || null,
        total_lessons: Number(payload.total_lessons),
        duration_min: Number(payload.duration_min),
        price: Number(payload.price),
        class_size: Number(payload.class_size || 12),
        distribute_rate: payload.distribute_rate ? Number(payload.distribute_rate) : Number(course.distribute_rate),
        validity_days: payload.validity_days || null,
        status: payload.status !== undefined ? Number(payload.status) : Number(course.status)
      },
      { transaction }
    );

    await CoursePackage.destroy({
      where: { course_id: course.course_id },
      transaction
    });

    await CoursePackage.bulkCreate(
      payload.packages.map((item) => ({
        package_id: generateId(),
        course_id: course.course_id,
        name: item.name,
        lessons: Number(item.lessons),
        price: Number(item.price),
        original_price: item.original_price ? Number(item.original_price) : null,
        status: item.status !== undefined ? Number(item.status) : 1
      })),
      { transaction }
    );

    return getCourseDetail(course.course_id, { transaction });
  });
}

module.exports = {
  listCourses,
  listStudioCourses,
  getCourseDetail,
  createCourse,
  updateCourse
};

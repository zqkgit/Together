const { Op } = require("sequelize");
const {
  sequelize,
  Course,
  CoursePackage,
  CourseLesson,
  Class,
  StudioProfile,
  TeacherProfile,
  TeacherStudioBinding
} = require("../models");
const { generateId } = require("../utils/id");

function normalizeCourseItem(course) {
  return {
    course_id: String(course.course_id),
    title: course.title,
    cover: course.cover,
    intro: course.intro,
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
    })),
    lessons: (course.lessons || [])
      .slice()
      .sort((a, b) => Number(a.lesson_no) - Number(b.lesson_no))
      .map((item) => ({
        lesson_no: Number(item.lesson_no),
        title: item.title
      }))
  };
}

// 课时标题行：按 total_lessons 补全为完整课时（每课一行）。
// 传了 lessons 时逐课取标题（空标题兜底「第N课」），保证课时列表与课时数一致，供详情/排课展示。
function buildLessonRows(payload, courseId) {
  const total = Number(payload.total_lessons) || 0;
  const rows = [];
  const byNo = {};
  if (Array.isArray(payload.lessons)) {
    payload.lessons.forEach((item, index) => {
      if (!item) return;
      const no = Number(item.lesson_no) || index + 1;
      byNo[no] = String(item.title || "").trim();
    });
  }
  for (let no = 1; no <= total; no += 1) {
    rows.push({
      lesson_id: generateId(),
      course_id: courseId,
      lesson_no: no,
      title: byNo[no] || `第${no}课`
    });
  }
  return rows;
}

async function ensureStudio(studioId, transaction) {  const studio = await StudioProfile.findByPk(studioId, { transaction });
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

  // 校验老师与工作室存在生效绑定（支持一对多绑定）
  const binding = await TeacherStudioBinding.findOne({
    where: { teacher_id: teacherId, studio_id: studioId, status: 1 },
    transaction
  });
  if (!binding) {
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

  const kw = (params.keyword || params.q || "").trim();
  if (kw) {
    where.title = { [Op.like]: `%${kw}%` };
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

  const kw = (params.keyword || params.q || "").trim();
  if (kw) {
    where.title = { [Op.like]: `%${kw}%` };
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
      },
      {
        model: CourseLesson,
        as: "lessons",
        required: false,
        attributes: ["lesson_no", "title"],
        order: [["lesson_no", "ASC"]]
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
        model: CourseLesson,
        as: "lessons",
        attributes: ["lesson_id", "lesson_no", "title"],
        order: [["lesson_no", "ASC"]]
      },
      {
        model: Class,
        as: "classes",
        attributes: ["class_id", "name", "capacity", "enrolled", "start_date", "end_date", "schedule_rule"],
        include: [
          {
            model: TeacherProfile,
            as: "teacher",
            attributes: ["teacher_id", "real_name"]
          }
        ]
      }
    ]
  });

  if (!row) {
    return null;
  }

  const payload = normalizeCourseItem(row);
  payload.lessons = (row.lessons || [])
    .slice()
    .sort((a, b) => Number(a.lesson_no) - Number(b.lesson_no))
    .map((item) => ({
      lesson_no: Number(item.lesson_no),
      title: item.title
    }));
  payload.classes = (row.classes || []).map((item) => ({
    class_id: String(item.class_id),
    name: item.name,
    capacity: item.capacity,
    enrolled: item.enrolled,
    start_date: item.start_date,
    end_date: item.end_date,
    time: item.schedule_rule?.time || null,
    teacher_name: item.teacher?.real_name || null
  }));

  return payload;
}

async function createCourse(payload) {
  return sequelize.transaction(async (transaction) => {
    await ensureStudio(payload.studio_id, transaction);
    await ensureTeacher(payload.teacher_id, payload.studio_id, transaction);

    // 退款/课程有效期：未传时取工作室默认（工作室设置，默认 7 天）
    let validityDays = payload.validity_days;
    if (!validityDays) {
      const studio = await StudioProfile.findByPk(payload.studio_id, { transaction });
      validityDays = studio?.default_validity_days || 7;
    }

    const course = await Course.create(
      {
        course_id: generateId(),
        studio_id: payload.studio_id,
        teacher_id: payload.teacher_id || null,
        title: payload.title,
        cover: payload.cover || null,
        intro: payload.intro || null,
        category: Number(payload.category),
        age_min: payload.age_min || null,
        age_max: payload.age_max || null,
        total_lessons: Number(payload.total_lessons),
        duration_min: Number(payload.duration_min),
        price: Number(payload.price),
        class_size: Number(payload.class_size || 12),
        distribute_rate: payload.distribute_rate ? Number(payload.distribute_rate) : 0.08,
        validity_days: Number(validityDays) || null,
        status: payload.status !== undefined ? Number(payload.status) : 0
      },
      { transaction }
    );

    // 课时包兼容：传了才创建（新流程课程固定课时，不再维护课时包）
    if (Array.isArray(payload.packages) && payload.packages.length > 0) {
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
    }

    // 课时标题：lessons: [{lesson_no, title}]，缺省时按 total_lessons 生成「第N课」
    const lessonRows = buildLessonRows(payload, course.course_id);
    if (lessonRows.length > 0) {
      await CourseLesson.bulkCreate(lessonRows, { transaction });
    }

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
        intro: payload.intro || null,
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

    // 课时包兼容：不传则不重建（保持旧课时包数据）
    if (Array.isArray(payload.packages)) {
      await CoursePackage.destroy({
        where: { course_id: course.course_id },
        transaction
      });

      if (payload.packages.length > 0) {
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
      }
    }

    // 课时标题：显式传了 lessons 才重建（避免 toggleStatus 等轻量更新覆盖标题）
    if (Array.isArray(payload.lessons)) {
      await CourseLesson.destroy({
        where: { course_id: course.course_id },
        transaction
      });
      const lessonRows = buildLessonRows(payload, course.course_id);
      if (lessonRows.length > 0) {
        await CourseLesson.bulkCreate(lessonRows, { transaction });
      }
    }

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

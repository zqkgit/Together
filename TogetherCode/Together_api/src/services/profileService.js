const { Op } = require("sequelize");
const {
  User,
  Child,
  TeacherProfile,
  StudioProfile,
  TeacherStudioBinding,
  Course,
  Post,
  PostLike,
  PostComment,
  CourseReview,
  Class
} = require("../models");

function publicUser(user) {
  if (!user) return null;
  return {
    user_id: String(user.user_id),
    nickname: user.nickname || "艺启用户",
    avatar: user.avatar || null,
    city: user.city || null,
    role: user.current_role !== undefined ? Number(user.current_role) : null
  };
}

/**
 * 用户公开档案（App 主页/他人档案）
 * 按角色附带档案摘要与统计
 */
async function getUserProfile(userId) {
  const user = await User.findByPk(userId);
  if (!user) {
    return null;
  }

  const profile = { ...publicUser(user) };

  if (Number(user.current_role) === 2) {
    const teacher = await TeacherProfile.findOne({
      where: { user_id: userId },
      attributes: ["real_name", "subjects", "years", "intro", "rating", "student_count", "work_count", "fans"]
    });
    profile.teacher = teacher
      ? {
          real_name: teacher.real_name || null,
          subjects: teacher.subjects || [],
          years: teacher.years || null,
          intro: teacher.intro || null,
          rating: Number(teacher.rating || 0),
          student_count: Number(teacher.student_count || 0),
          work_count: Number(teacher.work_count || 0),
          fans: Number(teacher.fans || 0)
        }
      : null;
  } else if (Number(user.current_role) === 3) {
    const studio = await StudioProfile.findOne({
      where: { user_id: userId, status: 1 },
      attributes: ["name", "cover", "intro", "address"]
    });
    profile.studio = studio
      ? {
          studio_id: String(studio.studio_id),
          name: studio.name || null,
          cover: studio.cover || null,
          intro: studio.intro || null,
          address: studio.address || null
        }
      : null;
  } else {
    // 家长：孩子数
    const childCount = await Child.count({ where: { parent_user_id: userId } });
    profile.parent = { child_count: childCount };
  }

  return profile;
}

/**
 * 老师主页：档案详情 + 绑定工作室 + 在售课程 + 近期作品
 */
async function getTeacherHomepage(userId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.size) || 10, 30);

  const teacher = await TeacherProfile.findOne({
    where: {
      [Op.or]: [{ user_id: userId }, { teacher_id: userId }],
      cert_status: 1
    },
    include: [{ model: User, as: "user", attributes: ["user_id", "nickname", "avatar", "city"] }]
  });

  if (!teacher) {
    return null;
  }

  const bindings = await TeacherStudioBinding.findAll({
    where: { teacher_id: teacher.teacher_id, status: 1 },
    include: [
      {
        model: StudioProfile,
        as: "studio",
        attributes: ["studio_id", "name", "cover", "address", "plan_tier"]
      }
    ]
  });

  // 老师在售课程
  const courses = await Course.findAll({
    where: { teacher_id: teacher.teacher_id, status: 1 },
    attributes: ["course_id", "title", "cover", "price", "age_min", "age_max", "total_lessons", "rating", "sales", "studio_id"],
    order: [["sales", "DESC"]],
    limit: 20
  });

  const works = await Post.findAndCountAll({
    where: {
      author_id: teacher.user?.user_id || userId,
      author_role: 2,
      status: 1,
      visibility: 2
    },
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  return {
    user: teacher.user
      ? {
          user_id: String(teacher.user.user_id),
          nickname: teacher.user.nickname || "艺启老师",
          avatar: teacher.user.avatar || null,
          city: teacher.user.city || null
        }
      : null,
    profile: {
      teacher_id: String(teacher.teacher_id),
      real_name: teacher.real_name || null,
      subjects: teacher.subjects || [],
      years: teacher.years || null,
      intro: teacher.intro || null,
      portfolio: teacher.portfolio || [],
      rating: Number(teacher.rating || 0),
      student_count: Number(teacher.student_count || 0),
      work_count: Number(teacher.work_count || 0),
      fans: Number(teacher.fans || 0)
    },
    studios: bindings.map((binding) => ({
      studio_id: String(binding.studio.studio_id),
      name: binding.studio.name,
      cover: binding.studio.cover,
      address: binding.studio.address,
      plan_tier: binding.studio.plan_tier
    })),
    courses: courses.map((c) => ({
      course_id: String(c.course_id),
      title: c.title,
      cover: c.cover,
      price: Number(c.price || 0),
      age_min: c.age_min,
      age_max: c.age_max,
      total_lessons: c.total_lessons,
      rating: Number(c.rating || 0),
      sales: Number(c.sales || 0),
      studio_id: String(c.studio_id)
    })),
    works: {
      total: works.count,
      page,
      size,
      list: works.rows.map((post) => ({
        post_id: String(post.post_id),
        type: post.type,
        images: post.images || [],
        content: post.content,
        like_count: Number(post.like_count || 0),
        comment_count: Number(post.comment_count || 0),
        created_at: post.created_at
      }))
    }
  };
}

/**
 * 工作室主页：档案 + 在售课程 + 在职老师
 */
async function getStudioHomepage(studioId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.size) || 10, 30);

  const studio = await StudioProfile.findOne({
    where: { studio_id: studioId, status: 1 }
  });

  if (!studio) {
    return null;
  }

  const courses = await Course.findAndCountAll({
    where: { studio_id: studioId, status: 1 },
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  const teachers = await TeacherStudioBinding.findAll({
    where: { studio_id: studioId, status: 1 },
    include: [
      {
        model: TeacherProfile,
        as: "teacher",
        include: [{ model: User, as: "user", attributes: ["user_id", "nickname", "avatar"] }]
      }
    ]
  });

  // 计算工作室评分（老师平均分）
  const teacherList = teachers
    .map((binding) => binding.teacher)
    .filter(Boolean);
  const rating = teacherList.length
    ? Number((teacherList.reduce((sum, t) => sum + Number(t.rating || 0), 0) / teacherList.length).toFixed(1))
    : 0;

  return {
    studio: {
      studio_id: String(studio.studio_id),
      name: studio.name,
      cover: studio.cover || null,
      type_tags: studio.type_tags || [],
      intro: studio.intro || null,
      address: studio.address || null,
      phone: studio.phone || null,
      hours: studio.hours || null,
      photos: studio.photos || [],
      plan_tier: studio.plan_tier,
      rating,
      course_count: courses.count,
      teacher_count: teacherList.length
    },
    courses: {
      total: courses.count,
      page,
      size,
      list: courses.rows.map((course) => ({
        course_id: String(course.course_id),
        title: course.title,
        cover: course.cover || null,
        price: course.price,
        original_price: course.original_price,
        age_min: course.age_min,
        age_max: course.age_max,
        lesson_count: course.lesson_count,
        status: course.status
      }))
    },
    teachers: teacherList.map((teacher) => ({
        teacher_id: String(teacher.teacher_id),
        user_id: teacher.user ? String(teacher.user.user_id) : null,
        nickname: teacher.user?.nickname || teacher.real_name || "老师",
        avatar: teacher.user?.avatar || null,
        real_name: teacher.real_name || null,
        subjects: teacher.subjects || [],
        years: teacher.years || null,
        rating: Number(teacher.rating || 0)
      }))
  };
}

/**
 * 老师公开评价列表（无需登录）
 */
async function getTeacherReviews(teacherId, query = {}) {
  const teacher = await TeacherProfile.findOne({
    where: {
      [Op.or]: [{ user_id: teacherId }, { teacher_id: teacherId }],
      cert_status: 1
    }
  });
  if (!teacher) return null;

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
  const size = Math.min(Number(query.size) || 10, 30);
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
        ? { user_id: String(r.user.user_id), nickname: r.user.nickname, avatar: r.user.avatar }
        : null,
      course: r.course
        ? { course_id: String(r.course.course_id), title: r.course.title }
        : null
    }))
  };
}

module.exports = {
  getUserProfile,
  getTeacherHomepage,
  getStudioHomepage,
  getTeacherReviews
};

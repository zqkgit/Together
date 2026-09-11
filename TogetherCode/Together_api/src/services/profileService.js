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
  PostComment
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
 * 老师主页：档案详情 + 绑定工作室 + 近期作品
 */
async function getTeacherHomepage(userId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.size) || 10, 30);

  const teacher = await TeacherProfile.findOne({
    where: { user_id: userId, cert_status: 1 },
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

  const works = await Post.findAndCountAll({
    where: {
      author_id: userId,
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
      plan_tier: studio.plan_tier
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
    teachers: teachers
      .map((binding) => binding.teacher)
      .filter(Boolean)
      .map((teacher) => ({
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

module.exports = {
  getUserProfile,
  getTeacherHomepage,
  getStudioHomepage
};

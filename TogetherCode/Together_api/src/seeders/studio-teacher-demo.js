/**
 * 工作室「老师管理」演示数据补齐（幂等，可重复执行）
 *
 * 背景：演示账号（13800000000）的主理工作室「兰亭书画」在职老师 3 位，但课程 / 学员 / 消课分布不均，
 *      导致 App 的「老师管理」页数字空洞（某老师 0 学员 0 消课），无法验证页面。
 *      本脚本按需补齐：
 *      1) 无主课程指派给缺课老师，必要时新开课程
 *      2) 为学员偏少的老师补充学员（订单 + 课时账本）
 *      3) 按老师造本月消课流水（不动「待续费」判定：每条账本保留 ≥ 4 节剩余）
 *      4) 造 2 条待审的老师合作申请（便于验证 App 内审批）
 *
 * 执行：npm run db:seed:teacher（或 node src/seeders/studio-teacher-demo.js）
 * 注意：会写入测试账号与演示数据，生产环境请勿执行。
 */
const bcrypt = require("bcryptjs");
const dayjs = require("dayjs");
const { Op } = require("sequelize");
const {
  sequelize,
  User,
  UserRole,
  Child,
  StudioProfile,
  TeacherProfile,
  TeacherStudioBinding,
  Course,
  CoursePackage,
  Order,
  OrderItem,
  Payment,
  ChildCourseBalance,
  LessonLog,
  TeacherApplication
} = require("../models");
const { generateId } = require("../utils/id");

const OWNER_PHONE = "13800000000";
const PASSWORD = "123456";
/** 造消课时为每条账本保留的最小剩余课时（避免把学员打成「待续费」） */
const MIN_REMAINING_KEEP = 4;

/** 各老师的目标月消课节数（受可用课时限制，取不到就按可用量） */
const TARGET_MONTH_LESSONS = {
  苏晚: 22,
  林墨: 18,
  王老师: 16
};

/**
 * 演示新增的合作老师（让「老师管理」有 3 位老师，对齐设计稿的三张卡片）
 * 每位老师自带 1 门在售课程 + 2 名学员
 */
const EXTRA_TEACHERS = [
  {
    phone: "13900000031",
    nickname: "王老师",
    real_name: "王老师",
    subjects: ["水彩", "硬笔书法"],
    years: 5,
    intro: "水彩 / 硬笔书法方向，教龄 5 年，擅长低龄启蒙",
    course: { title: "水彩进阶小班课", total_lessons: 24, price: 268000 },
    students: [
      { phone: "13900000032", nickname: "米粒妈妈", child: "米粒", gender: 2, birthday: "2018-07-09", monthsAgo: 7, remaining: 20 },
      { phone: "13900000033", nickname: "小树妈妈", child: "小树", gender: 1, birthday: "2019-11-02", monthsAgo: 3, remaining: 16 }
    ]
  }
];

/** 学员偏少的老师补充的学员（含手机号、孩子昵称、剩余课时） */
const EXTRA_STUDENTS = {
  林墨: [
    { phone: "13900000034", nickname: "石头爸爸", child: "石头", gender: 1, birthday: "2017-09-20", monthsAgo: 8, remaining: 20 },
    { phone: "13900000035", nickname: "妞妞妈妈", child: "妞妞", gender: 2, birthday: "2018-12-05", monthsAgo: 4, remaining: 16 }
  ]
};

async function ensureUser(data) {
  const [user] = await User.findOrCreate({ where: { phone: data.phone }, defaults: data });
  return user;
}

async function ensureUserRole(userId, role, refId = null) {
  await UserRole.findOrCreate({
    where: { user_id: userId, role },
    defaults: { id: generateId(), user_id: userId, role, ref_id: refId, verified: true }
  });
}

async function ensureChild(data) {
  const [child] = await Child.findOrCreate({
    where: { parent_user_id: data.parent_user_id, nickname: data.nickname },
    defaults: data
  });
  return child;
}

/** 重新统计工作室在职老师数（与 studioTeacherService.recomputeStudioTeacherCount 同口径） */
async function recomputeTeacherCount(studioId) {
  const [row] = await sequelize.query(
    "SELECT COUNT(*) AS total FROM teacher_studio_bindings WHERE studio_id = ? AND status = 1",
    { replacements: [studioId], type: sequelize.QueryTypes.SELECT }
  );
  await StudioProfile.update(
    { teacher_count: Number(row?.total) || 0 },
    { where: { studio_id: studioId } }
  );
}

/**
 * 造一位演示合作老师：用户 + 老师档案 + 老师角色 + 工作室绑定 + 在售课程（幂等键：手机号）
 */
async function ensureExtraTeacher({ studio, seed, passwordHash }) {
  const user = await ensureUser({
    user_id: generateId(),
    phone: seed.phone,
    nickname: seed.nickname,
    password_hash: passwordHash,
    city: "杭州",
    current_role: 2,
    terms_agreed_at: new Date()
  });

  const [profile] = await TeacherProfile.findOrCreate({
    where: { user_id: user.user_id },
    defaults: {
      teacher_id: generateId(),
      user_id: user.user_id,
      real_name: seed.real_name,
      subjects: seed.subjects,
      years: seed.years,
      intro: seed.intro,
      cert_no: `TC-2026-${seed.phone.slice(-4)}`,
      cert_status: 1,
      rating: 4.9,
      student_count: 0,
      studio_id: studio.studio_id
    }
  });

  await UserRole.findOrCreate({
    where: { user_id: user.user_id, role: 2 },
    defaults: {
      id: generateId(),
      user_id: user.user_id,
      role: 2,
      ref_id: profile.teacher_id,
      verified: true
    }
  });

  await TeacherStudioBinding.findOrCreate({
    where: { teacher_id: profile.teacher_id, studio_id: studio.studio_id },
    defaults: {
      binding_id: generateId(),
      teacher_id: profile.teacher_id,
      studio_id: studio.studio_id,
      status: 1,
      bound_at: new Date()
    }
  });

  const [course] = await Course.findOrCreate({
    where: { studio_id: studio.studio_id, title: seed.course.title },
    defaults: {
      course_id: generateId(),
      studio_id: studio.studio_id,
      teacher_id: profile.teacher_id,
      title: seed.course.title,
      category: 1,
      age_min: 5,
      age_max: 12,
      total_lessons: seed.course.total_lessons,
      duration_min: 90,
      price: seed.course.price,
      class_size: 8,
      rating: 4.9,
      sales: 0,
      distribute_rate: 0.08,
      validity_days: 180,
      status: 1,
      cover: null
    }
  });
  if (String(course.teacher_id || "") !== String(profile.teacher_id)) {
    await course.update({ teacher_id: profile.teacher_id });
  }
  await ensurePackage(course);

  return { user, profile, course };
}

/** 课程课时包（幂等键：课程 + 包名） */
async function ensurePackage(course) {
  const [pkg] = await CoursePackage.findOrCreate({
    where: { course_id: course.course_id, name: `${course.total_lessons} 课时包` },
    defaults: {
      package_id: generateId(),
      course_id: course.course_id,
      name: `${course.total_lessons} 课时包`,
      lessons: course.total_lessons,
      price: course.price,
      original_price: Math.round(Number(course.price) * 1.12),
      status: 1
    }
  });
  return pkg;
}

/** 一笔已支付订单（含订单项 / 支付记录 / 课时账本），幂等键 = 学员 + 课程 + 课时包 */
async function ensurePaidOrder({ user, child, studio, course, coursePackage, paidAt, remainingLessons }) {
  const [order, created] = await Order.findOrCreate({
    where: {
      user_id: user.user_id,
      child_id: child.child_id,
      course_id: course.course_id,
      package_id: coursePackage.package_id
    },
    defaults: {
      order_id: generateId(),
      order_no: `TG${generateId()}`,
      user_id: user.user_id,
      child_id: child.child_id,
      studio_id: studio.studio_id,
      course_id: course.course_id,
      package_id: coursePackage.package_id,
      total_lessons: coursePackage.lessons,
      consumed_lessons: Math.max(0, coursePackage.lessons - remainingLessons),
      refunded_lessons: 0,
      total_amount: coursePackage.price,
      paid_amount: coursePackage.price,
      refund_amount: 0,
      pay_channel: "wechat_mini",
      paid_at: paidAt,
      status: 1
    }
  });

  if (!created) {
    return order;
  }

  await OrderItem.findOrCreate({
    where: { order_id: order.order_id, package_id: coursePackage.package_id },
    defaults: {
      item_id: generateId(),
      order_id: order.order_id,
      course_id: course.course_id,
      package_id: coursePackage.package_id,
      course_title: course.title,
      package_name: coursePackage.name,
      lessons: coursePackage.lessons,
      quantity: 1,
      unit_price: coursePackage.price,
      total_price: coursePackage.price
    }
  });

  await Payment.findOrCreate({
    where: { order_id: order.order_id, status: 1 },
    defaults: {
      payment_id: generateId(),
      order_id: order.order_id,
      payment_no: `PM${generateId()}`,
      channel: "wechat_mini",
      amount: coursePackage.price,
      paid_at: paidAt,
      status: 1,
      trade_no: `TRADE${generateId()}`
    }
  });

  await ChildCourseBalance.findOrCreate({
    where: { order_id: order.order_id },
    defaults: {
      balance_id: generateId(),
      child_id: child.child_id,
      course_id: course.course_id,
      order_id: order.order_id,
      total_lessons: coursePackage.lessons,
      consumed_lessons: Number(order.consumed_lessons || 0),
      refunded_lessons: 0,
      remaining_lessons: remainingLessons,
      valid_from: dayjs(paidAt).format("YYYY-MM-DD"),
      valid_to: null,
      status: 1,
      class_id: null
    }
  });

  return order;
}

/**
 * 造一条消课流水（幂等键：学员 + 课程 + 备注）
 * 同步扣减课时账本与订单的已核销课时，保证「学员管理」页剩余课时与流水自洽
 */
async function ensureConsumption({ balance, order, child, course, consumedAt, note }) {
  const existing = await LessonLog.findOne({
    where: { child_id: child.child_id, course_id: course.course_id, note }
  });
  if (existing) {
    return false;
  }

  const remainingAfter = Number(balance.remaining_lessons) - 1;
  if (remainingAfter < MIN_REMAINING_KEEP) {
    return false;
  }

  await balance.update({
    consumed_lessons: Number(balance.consumed_lessons || 0) + 1,
    remaining_lessons: remainingAfter
  });
  await order.update({ consumed_lessons: Number(order.consumed_lessons || 0) + 1 });

  const log = await LessonLog.create({
    log_id: generateId(),
    child_id: child.child_id,
    course_id: course.course_id,
    order_id: order.order_id,
    schedule_id: null,
    source: 2,
    type: 1,
    delta: -1,
    balance_after: remainingAfter,
    note,
    created_at: consumedAt
  });
  // 显式回填发生时间：把消课均匀摊到本月，便于验证「月消课」口径
  await LessonLog.update(
    { created_at: consumedAt },
    { where: { log_id: log.log_id }, silent: true }
  );

  return true;
}

/** 该老师在本工作室带课课程下、仍可造消课的账本（保留 MIN_REMAINING_KEEP） */
async function loadConsumableBalances(studioId, courseIds) {
  if (!courseIds.length) {
    return [];
  }
  const rows = await ChildCourseBalance.findAll({
    where: { course_id: courseIds, remaining_lessons: { [Op.gt]: MIN_REMAINING_KEEP } },
    include: [
      {
        model: Order,
        as: "order",
        required: true,
        where: { studio_id: studioId }
      },
      { model: Child, as: "child", attributes: ["child_id", "nickname"] }
    ]
  });
  return rows;
}

/**
 * 回滚本脚本造过的演示消课（--reset 时调用）：
 * 逐条把课时账本 / 订单的核销数还原，并删除流水，保证可反复重跑而不污染学员剩余课时
 */
async function resetDemoConsumptions() {
  const logs = await LessonLog.findAll({
    where: { note: { [Op.like]: "演示数据·课堂消课%" }, delta: { [Op.lt]: 0 } }
  });
  for (const log of logs) {
    const balance = await ChildCourseBalance.findOne({ where: { order_id: log.order_id } });
    if (balance) {
      await balance.update({
        remaining_lessons: Number(balance.remaining_lessons) + 1,
        consumed_lessons: Math.max(0, Number(balance.consumed_lessons) - 1)
      });
    }
    const order = await Order.findByPk(log.order_id);
    if (order) {
      await order.update({ consumed_lessons: Math.max(0, Number(order.consumed_lessons) - 1) });
    }
    await log.destroy();
  }
  return logs.length;
}

async function main() {
  const now = dayjs();
  const passwordHash = bcrypt.hashSync(PASSWORD, 10);

  // --reset：先回滚上次造的演示消课，再重造，保证「本月消课 / 剩余课时」可复现
  if (process.argv.includes("--reset")) {
    const removed = await resetDemoConsumptions();
    console.log(`已回滚演示消课流水 ${removed} 条`);
  }

  // ---------- 0. 定位主理工作室 ----------
  const owner = await User.findOne({ where: { phone: OWNER_PHONE } });
  if (!owner) {
    throw new Error(`演示主理人账号不存在：${OWNER_PHONE}`);
  }
  const studio = await StudioProfile.findOne({ where: { user_id: owner.user_id } });
  if (!studio) {
    throw new Error("主理人尚未创建工作室（先跑 db:seed:demo / 走一次入驻）");
  }
  const studioId = studio.studio_id;

  // ---------- 1. 演示合作老师：补齐到 3 位（对齐设计稿三张卡片） ----------
  for (const seed of EXTRA_TEACHERS) {
    await ensureExtraTeacher({ studio, seed, passwordHash });
  }
  await recomputeTeacherCount(studioId);

  const bindings = await TeacherStudioBinding.findAll({
    where: { studio_id: studioId, status: 1 },
    include: [
      {
        model: TeacherProfile,
        as: "teacher",
        required: true,
        include: [{ model: User, as: "user", attributes: ["user_id", "phone", "nickname"] }]
      }
    ]
  });
  if (!bindings.length) {
    throw new Error("该工作室没有在职老师，先跑 db:seed:overview");
  }

  // 各老师需要补充的学员（原有老师 + 演示老师自带学员合并）
  const studentSeeds = { ...EXTRA_STUDENTS };
  for (const seed of EXTRA_TEACHERS) {
    studentSeeds[seed.real_name] = seed.students || [];
  }

  const report = { studio: studio.name, teachers: [] };

  for (const binding of bindings) {
    const teacher = binding.teacher;
    const teacherName = teacher.real_name;

    // ---------- 2. 课程：优先把无主课程指派给该老师 ----------
    let courses = await Course.findAll({
      where: { studio_id: studioId, teacher_id: teacher.teacher_id }
    });

    if (courses.length === 0) {
      const [orphan] = await Course.findAll({
        where: { studio_id: studioId, teacher_id: null },
        limit: 1
      });
      if (orphan) {
        await orphan.update({ teacher_id: teacher.teacher_id, status: 1 });
        courses = [orphan];
      }
    }

    if (courses.length === 0) {
      const subjects = Array.isArray(teacher.subjects) && teacher.subjects.length
        ? teacher.subjects
        : ["综合绘画"];
      const [course] = await Course.findOrCreate({
        where: { studio_id: studioId, title: `${subjects[0]}小班课` },
        defaults: {
          course_id: generateId(),
          studio_id: studioId,
          teacher_id: teacher.teacher_id,
          title: `${subjects[0]}小班课`,
          category: 1,
          age_min: 5,
          age_max: 12,
          total_lessons: 24,
          duration_min: 90,
          price: 288000,
          class_size: 8,
          rating: 4.8,
          sales: 0,
          distribute_rate: 0.08,
          validity_days: 180,
          status: 1,
          cover: null
        }
      });
      courses = [course];
    }

    for (const course of courses) {
      await ensurePackage(course);
    }

    // ---------- 3. 学员：偏少的老师补学员（订单 + 课时账本） ----------
    const extraSeed = studentSeeds[teacherName] || [];
    for (const seed of extraSeed) {
      const user = await ensureUser({
        user_id: generateId(),
        phone: seed.phone,
        nickname: seed.nickname,
        password_hash: passwordHash,
        city: "杭州",
        current_role: 1,
        terms_agreed_at: new Date()
      });
      await ensureUserRole(user.user_id, 1, null);
      const child = await ensureChild({
        child_id: generateId(),
        parent_user_id: user.user_id,
        nickname: seed.child,
        birthday: seed.birthday,
        gender: seed.gender
      });
      const course = courses[0];
      const pkg = await ensurePackage(course);
      await ensurePaidOrder({
        user,
        child,
        studio,
        course,
        coursePackage: pkg,
        paidAt: now.subtract(seed.monthsAgo, "month").toDate(),
        remainingLessons: seed.remaining
      });
    }

    // ---------- 4. 本月消课（受可用课时限制；备注带序号保证幂等） ----------
    const target = TARGET_MONTH_LESSONS[teacherName] || 10;
    const courseIds = courses.map((course) => course.course_id);
    const balances = await loadConsumableBalances(studioId, courseIds);
    const notePrefix = `演示数据·课堂消课（${teacherName}）`;
    const already = await LessonLog.count({
      where: { course_id: courseIds.length ? courseIds : ["0"], note: { [Op.like]: `${notePrefix}%` } }
    });

    let consumed = 0;
    let seq = already;
    let round = 0;
    const daysInMonthSoFar = Math.max(1, now.date());
    const usable = [...balances];
    while (consumed < Math.max(0, target - already) && round < 300) {
      let progressed = false;
      for (const balance of usable) {
        if (consumed >= Math.max(0, target - already)) break;
        const course = courses.find((item) => String(item.course_id) === String(balance.course_id));
        if (!course) continue;
        const day = ((already + consumed) % daysInMonthSoFar) + 1;
        const consumedAt = now.startOf("month").add(day - 1, "day").hour(10).minute(30).second(0).toDate();
        const created = await ensureConsumption({
          balance,
          order: balance.order,
          child: balance.child,
          course,
          consumedAt,
          note: `${notePrefix}#${seq + 1}`
        });
        if (created) {
          consumed += 1;
          seq += 1;
          progressed = true;
        } else {
          // 该账本已到保留线：从可用列表里摘掉
          balance.setDataValue("remaining_lessons", MIN_REMAINING_KEEP);
        }
      }
      usable.splice(
        0,
        usable.length,
        ...usable.filter((item) => Number(item.remaining_lessons) > MIN_REMAINING_KEEP)
      );
      if (!progressed) break;
      round += 1;
    }

    report.teachers.push({
      teacher: teacherName,
      courses: courses.map((course) => course.title),
      extra_students: extraSeed.length,
      month_lessons_before: already,
      month_lessons_created: consumed
    });
  }

  // ---------- 5. 待审合作申请（2 条，便于验证 App 内审批） ----------
  const boundTeacherIds = bindings.map((item) => item.teacher.teacher_id);
  const candidates = await TeacherProfile.findAll({
    where: { teacher_id: { [Op.notIn]: boundTeacherIds } },
    include: [{ model: User, as: "user", attributes: ["user_id", "phone", "nickname"] }],
    limit: 4
  });
  let pendingCreated = 0;
  for (const profile of candidates.slice(0, 2)) {
    const [application, created] = await TeacherApplication.findOrCreate({
      where: { studio_id: studioId, user_id: profile.user_id },
      defaults: {
        id: generateId(),
        studio_id: studioId,
        user_id: profile.user_id,
        real_name: profile.real_name,
        subjects: profile.subjects || [],
        years: profile.years,
        intro: profile.intro,
        cert_no: profile.cert_no,
        portfolio: profile.portfolio || [],
        status: 0,
        submitted_at: now.subtract(2, "day").toDate()
      }
    });
    // 历史申请若已处理，重置为待审以便演示
    if (!created && Number(application.status) !== 0) {
      await application.update({
        status: 0,
        submitted_at: now.subtract(2, "day").toDate(),
        reviewed_at: null,
        review_reason: null
      });
      pendingCreated += 1;
    } else if (created) {
      pendingCreated += 1;
    }
  }
  report.pending_applications = pendingCreated;

  console.log("Studio teacher demo seed completed:", JSON.stringify(report, null, 2));
  await sequelize.close();
}

main().catch(async (error) => {
  console.error("Studio teacher demo seed failed:", error);
  await sequelize.close().catch(() => {});
  process.exit(1);
});

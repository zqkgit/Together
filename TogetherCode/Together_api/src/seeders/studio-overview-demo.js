/**
 * 工作室「经营概览」演示数据补齐（幂等，可重复执行）
 *
 * 背景：演示账号（13800000000）的主理工作室是运行时注册的，bootstrap-demo 不会为它造经营数据，
 *      导致 App 的「经营概览」页全为 0，无法验证页面。本脚本按需为该工作室补齐：
 *      课程 / 入驻教师 / 学员订单 / 在读课时 / 待审核退款 / 待结算结算单 / 钱包余额 / 分销返利。
 *
 * 执行：npm run db:seed:overview（或 node src/seeders/studio-overview-demo.js）
 */
const bcrypt = require("bcryptjs");
const dayjs = require("dayjs");
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
  Refund,
  ChildCourseBalance,
  LessonLog,
  Settlement,
  Wallet,
  DistributionLink,
  CommissionRecord
} = require("../models");
const { generateId } = require("../utils/id");

const OWNER_PHONE = "13800000000";
const PASSWORD = "123456";

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

async function ensureCourse(data) {
  const [course] = await Course.findOrCreate({
    where: { studio_id: data.studio_id, title: data.title },
    defaults: data
  });
  return course;
}

/** 一笔已支付订单（含订单项 / 支付记录 / 课时账本），幂等键 = 学员 + 课程 + 课时包 */
async function ensurePaidOrder({ user, child, studio, course, coursePackage, paidAt }) {
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
      consumed_lessons: 0,
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
      consumed_lessons: 0,
      refunded_lessons: 0,
      remaining_lessons: coursePackage.lessons,
      valid_from: dayjs(paidAt).format("YYYY-MM-DD"),
      valid_to: null,
      status: 1
    }
  });

  await LessonLog.findOrCreate({
    where: { order_id: order.order_id, source: 0, type: 1 },
    defaults: {
      log_id: generateId(),
      child_id: child.child_id,
      course_id: course.course_id,
      order_id: order.order_id,
      source: 0,
      type: 1,
      delta: coursePackage.lessons,
      balance_after: coursePackage.lessons,
      note: "订单支付成功，课时到账"
    }
  });

  return order;
}

async function main() {
  await sequelize.authenticate();
  const passwordHash = bcrypt.hashSync(PASSWORD, 10);
  const now = dayjs();

  const owner = await User.findOne({ where: { phone: OWNER_PHONE } });
  if (!owner) {
    throw new Error(`演示账号 ${OWNER_PHONE} 不存在，请先注册/登录一次`);
  }
  const studio = await StudioProfile.findOne({ where: { user_id: owner.user_id } });
  if (!studio) {
    throw new Error(`账号 ${OWNER_PHONE} 尚未开通工作室，无法补造经营数据`);
  }
  const studioId = studio.studio_id;

  // ---------- 1. 课程 ----------
  const courses = [];
  courses.push(await ensureCourse({
    course_id: generateId(),
    studio_id: studioId,
    title: "创意启蒙绘画班",
    category: 1,
    age_min: 4,
    age_max: 6,
    total_lessons: 12,
    duration_min: 90,
    price: 168000,
    class_size: 10,
    rating: 4.9,
    sales: 26,
    distribute_rate: 0.08,
    validity_days: 180,
    status: 1,
    cover: null
  }));
  courses.push(await ensureCourse({
    course_id: generateId(),
    studio_id: studioId,
    title: "水墨书法研修班",
    category: 2,
    age_min: 7,
    age_max: 12,
    total_lessons: 24,
    duration_min: 120,
    price: 198000,
    class_size: 12,
    rating: 4.8,
    sales: 18,
    distribute_rate: 0.1,
    validity_days: 240,
    status: 1,
    cover: null
  }));
  // 下架课程：用于验证「在售课程」口径
  courses.push(await ensureCourse({
    course_id: generateId(),
    studio_id: studioId,
    title: "黏土动物园主题营",
    category: 3,
    age_min: 5,
    age_max: 9,
    total_lessons: 8,
    duration_min: 90,
    price: 236000,
    class_size: 8,
    rating: 4.7,
    sales: 12,
    distribute_rate: 0.08,
    validity_days: 90,
    status: 0,
    cover: null
  }));

  const packages = [];
  for (const course of courses) {
    const [pkg] = await CoursePackage.findOrCreate({
      where: { course_id: course.course_id, name: `${course.total_lessons} 课时包` },
      defaults: {
        package_id: generateId(),
        course_id: course.course_id,
        name: `${course.total_lessons} 课时包`,
        lessons: course.total_lessons,
        price: course.price,
        original_price: Math.round(course.price * 1.12),
        status: 1
      }
    });
    packages.push(pkg);
  }

  // ---------- 2. 入驻教师 ----------
  const teacherSeed = [
    { phone: "13900000001", nickname: "林墨", real_name: "林墨", subjects: ["书法", "国画"], years: 9 },
    { phone: "13900000002", nickname: "苏晚", real_name: "苏晚", subjects: ["手工", "黏土"], years: 6 }
  ];
  const teachers = [];
  for (const seed of teacherSeed) {
    const user = await ensureUser({
      user_id: generateId(),
      phone: seed.phone,
      nickname: seed.nickname,
      password_hash: passwordHash,
      city: "杭州",
      current_role: 2,
      terms_agreed_at: new Date()
    });
    const [teacher] = await TeacherProfile.findOrCreate({
      where: { user_id: user.user_id },
      defaults: {
        teacher_id: generateId(),
        user_id: user.user_id,
        real_name: seed.real_name,
        subjects: seed.subjects,
        years: seed.years,
        intro: `${seed.subjects.join("、")}方向，教龄 ${seed.years} 年`,
        cert_no: `TC-2026-${seed.phone.slice(-4)}`,
        studio_id: studioId,
        cert_status: 1,
        rating: 4.8,
        student_count: 0,
        work_count: 0,
        fans: 0
      }
    });
    await ensureUserRole(user.user_id, 2, teacher.teacher_id);
    await TeacherStudioBinding.findOrCreate({
      where: { teacher_id: teacher.teacher_id, studio_id: studioId },
      defaults: { binding_id: generateId(), teacher_id: teacher.teacher_id, studio_id: studioId, status: 1 }
    });
    teachers.push(teacher);
  }

  // ---------- 3. 学员与订单 ----------
  const studentSeed = [
    { phone: "13900000011", nickname: "小满妈妈", child: "小满", gender: 2 },
    { phone: "13900000012", nickname: "阿哲爸爸", child: "阿哲", gender: 1 },
    { phone: "13900000013", nickname: "朵朵妈妈", child: "朵朵", gender: 2 }
  ];
  const students = [];
  for (const seed of studentSeed) {
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
      birthday: "2018-06-01",
      gender: seed.gender
    });
    students.push({ user, child });
  }

  // 每位学员购买两门在售课程；其中前两位学员的订单落在今天（用于「今日招生」）
  const orders = [];
  for (let i = 0; i < students.length; i += 1) {
    const { user, child } = students[i];
    const paidAt = i < 2 ? now.subtract(i, "hour").toDate() : now.subtract(i + 2, "day").toDate();
    for (const index of [0, 1]) {
      orders.push(await ensurePaidOrder({
        user,
        child,
        studio,
        course: courses[index],
        coursePackage: packages[index],
        paidAt
      }));
    }
  }

  // ---------- 4. 待审核退款（2 笔） ----------
  for (const order of orders.slice(0, 2)) {
    await Refund.findOrCreate({
      where: { order_id: order.order_id, status: 0 },
      defaults: {
        refund_id: generateId(),
        order_id: order.order_id,
        user_id: order.user_id,
        requested_lessons: 4,
        refundable_lessons: order.total_lessons,
        unit_price: Math.floor(order.total_amount / order.total_lessons),
        amount: Math.floor(order.total_amount / order.total_lessons) * 4,
        reason: "孩子时间冲突，申请退剩余课时",
        status: 0
      }
    });
  }

  // ---------- 5. 分销返利（本月） ----------
  const [link] = await DistributionLink.findOrCreate({
    where: { code: "DEMO-STUDIO-OVERVIEW" },
    defaults: {
      link_id: generateId(),
      parent_user_id: owner.user_id,
      course_id: courses[0].course_id,
      post_id: null,
      code: "DEMO-STUDIO-OVERVIEW",
      status: 1
    }
  });
  for (const order of orders.slice(2, 4)) {
    await CommissionRecord.findOrCreate({
      where: { link_id: link.link_id, order_id: order.order_id },
      defaults: {
        commission_id: generateId(),
        link_id: link.link_id,
        order_id: order.order_id,
        parent_user_id: owner.user_id,
        rate: 0.08,
        amount: Math.round(Number(order.paid_amount) * 0.08) / 100,
        status: 1
      }
    });
  }

  // ---------- 6. 待结算结算单（结算中金额） ----------
  const periodStart = now.startOf("month").format("YYYY-MM-DD");
  const periodEnd = now.endOf("month").format("YYYY-MM-DD");
  await Settlement.findOrCreate({
    where: { studio_id: studioId, period_start: periodStart, period_end: periodEnd },
    defaults: {
      settlement_id: generateId(),
      studio_id: studioId,
      period_start: periodStart,
      period_end: periodEnd,
      income: orders.reduce((sum, o) => sum + Number(o.paid_amount || 0), 0),
      refund: 0,
      distribution: 0,
      net_amount: orders.reduce((sum, o) => sum + Number(o.paid_amount || 0), 0),
      fee_rate: Number(studio.settle_rate || 0.1),
      fee_amount: 0,
      payable_amount: Math.round(
        orders.reduce((sum, o) => sum + Number(o.paid_amount || 0), 0) *
          (1 - Number(studio.settle_rate || 0.1))
      ),
      status: 0
    }
  });

  // ---------- 7. 主理人钱包（可提现） ----------
  const [wallet] = await Wallet.findOrCreate({
    where: { user_id: owner.user_id },
    defaults: { user_id: owner.user_id, balance: 0, frozen: 0, withdrawn: 0, debt: 0 }
  });
  if (Number(wallet.balance) < 1000) {
    await wallet.update({ balance: 12300 });
  }

  const summary = {
    studio: studio.name,
    courses: courses.length,
    onlineCourses: courses.filter((c) => Number(c.status) === 1).length,
    teachers: teachers.length,
    students: students.length,
    orders: orders.length,
    monthIncomeFen: orders.reduce((sum, o) => sum + Number(o.paid_amount || 0), 0)
  };
  console.log("Studio overview demo seed completed:", JSON.stringify(summary, null, 2));
  await sequelize.close();
}

main().catch(async (error) => {
  console.error("Studio overview demo seed failed:", error);
  await sequelize.close().catch(() => {});
  process.exit(1);
});

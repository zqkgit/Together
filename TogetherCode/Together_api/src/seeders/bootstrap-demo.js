const bcrypt = require("bcryptjs");
const {
  sequelize,
  User,
  UserRole,
  Child,
  AdminAccount,
  StudioProfile,
  TeacherProfile,
  StudioApplication,
  TeacherApplication,
  Settlement,
  Course,
  CoursePackage,
  Class,
  Schedule,
  Order,
  OrderItem,
  Payment,
  Refund,
  ChildCourseBalance,
  LessonLog
} = require("../models");
const { generateId } = require("../utils/id");

async function ensureUser(data) {
  const [user] = await User.findOrCreate({
    where: { phone: data.phone },
    defaults: data
  });

  return user;
}

async function ensureUserRole(userId, role, refId = null, verified = true) {
  await UserRole.findOrCreate({
    where: { user_id: userId, role },
    defaults: {
      id: generateId(),
      user_id: userId,
      role,
      ref_id: refId,
      verified
    }
  });
}

async function ensureChild(data) {
  const [child] = await Child.findOrCreate({
    where: {
      parent_user_id: data.parent_user_id,
      nickname: data.nickname
    },
    defaults: data
  });

  return child;
}

async function ensureTeacherProfile(data) {
  const [teacher] = await TeacherProfile.findOrCreate({
    where: { user_id: data.user_id },
    defaults: data
  });

  return teacher;
}

async function ensureCourse(data) {
  const [course] = await Course.findOrCreate({
    where: { studio_id: data.studio_id, title: data.title },
    defaults: data
  });

  return course;
}

async function ensureCoursePackage(courseId, data) {
  await CoursePackage.findOrCreate({
    where: { course_id: courseId, name: data.name },
    defaults: {
      package_id: generateId(),
      course_id: courseId,
      ...data
    }
  });
}

async function ensureClass(courseId, teacherId, data) {
  const [classItem] = await Class.findOrCreate({
    where: { course_id: courseId, name: data.name },
    defaults: {
      class_id: generateId(),
      course_id: courseId,
      teacher_id: teacherId,
      ...data
    }
  });

  return classItem;
}

async function ensureSchedule(studioId, classId, courseId, teacherId, data) {
  await Schedule.findOrCreate({
    where: {
      class_id: classId,
      lesson_date: data.lesson_date,
      start_time: data.start_time
    },
    defaults: {
      schedule_id: generateId(),
      studio_id: studioId,
      class_id: classId,
      course_id: courseId,
      teacher_id: teacherId,
      ...data
    }
  });
}

async function ensurePaidOrder({ user, child, studio, course, coursePackage, refundLessons = 0 }) {
  const [order] = await Order.findOrCreate({
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
      refunded_lessons: refundLessons,
      total_amount: coursePackage.price,
      paid_amount: coursePackage.price,
      refund_amount: refundLessons > 0 ? Math.floor(coursePackage.price / coursePackage.lessons) * refundLessons : 0,
      pay_channel: "wechat_mini",
      paid_at: new Date(),
      status: refundLessons > 0 ? 3 : 1
    }
  });

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
      paid_at: new Date(),
      status: 1,
      trade_no: `TRADE${generateId()}`
    }
  });

  const remainingLessons = coursePackage.lessons - refundLessons;
  await ChildCourseBalance.findOrCreate({
    where: { order_id: order.order_id },
    defaults: {
      balance_id: generateId(),
      child_id: child.child_id,
      course_id: course.course_id,
      order_id: order.order_id,
      total_lessons: coursePackage.lessons,
      consumed_lessons: 0,
      refunded_lessons: refundLessons,
      remaining_lessons: remainingLessons,
      valid_from: new Date().toISOString().slice(0, 10),
      valid_to: null,
      status: remainingLessons > 0 ? 1 : 2
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

  if (refundLessons > 0) {
    const refundAmount = Math.floor(coursePackage.price / coursePackage.lessons) * refundLessons;

    await Refund.findOrCreate({
      where: { order_id: order.order_id, status: 3 },
      defaults: {
        refund_id: generateId(),
        order_id: order.order_id,
        user_id: user.user_id,
        requested_lessons: refundLessons,
        refundable_lessons: coursePackage.lessons,
        unit_price: Math.floor(coursePackage.price / coursePackage.lessons),
        amount: refundAmount,
        reason: "演示退款",
        reviewed_at: new Date(),
        refunded_at: new Date(),
        status: 3
      }
    });

    await LessonLog.findOrCreate({
      where: { order_id: order.order_id, source: 4, type: 3 },
      defaults: {
        log_id: generateId(),
        child_id: child.child_id,
        course_id: course.course_id,
        order_id: order.order_id,
        source: 4,
        type: 3,
        delta: -refundLessons,
        balance_after: remainingLessons,
        note: "订单退款扣减剩余课时"
      }
    });
  }

  return order;
}

async function main() {
  await sequelize.authenticate();

  const passwordHash = bcrypt.hashSync("123456", 10);

  const parentUser = await ensureUser({
    user_id: generateId(),
    phone: "13800000000",
    nickname: "演示家长",
    password_hash: passwordHash,
    city: "杭州",
    current_role: 1,
    terms_agreed_at: new Date()
  });
  await ensureUserRole(parentUser.user_id, 1, null, true);
  const child1 = await ensureChild({
    child_id: generateId(),
    parent_user_id: parentUser.user_id,
    nickname: "可可",
    birthday: "2019-05-18",
    gender: 2
  });

  const platformUser = await ensureUser({
    user_id: generateId(),
    phone: "13800000001",
    nickname: "平台运营",
    password_hash: passwordHash,
    city: "上海",
    current_role: 3,
    terms_agreed_at: new Date()
  });

  await AdminAccount.findOrCreate({
    where: { username: "platform_admin" },
    defaults: {
      admin_id: generateId(),
      user_id: platformUser.user_id,
      username: "platform_admin",
      password_hash: passwordHash,
      role: "platform_super",
      status: 1
    }
  });

  const studioOwner1 = await ensureUser({
    user_id: generateId(),
    phone: "13800000002",
    nickname: "朝阳艺启主理人",
    password_hash: passwordHash,
    city: "北京",
    current_role: 3,
    terms_agreed_at: new Date()
  });

  const studioOwner2 = await ensureUser({
    user_id: generateId(),
    phone: "13800000003",
    nickname: "画布成长主理人",
    password_hash: passwordHash,
    city: "深圳",
    current_role: 3,
    terms_agreed_at: new Date()
  });

  const [studio1] = await StudioProfile.findOrCreate({
    where: { user_id: studioOwner1.user_id },
    defaults: {
      studio_id: generateId(),
      user_id: studioOwner1.user_id,
      name: "朝阳艺启工作室",
      intro: "儿童艺术启蒙与综合创作课程",
      address: "北京市朝阳区望京 SOHO",
      phone: "010-12345678",
      settle_rate: 0.12,
      plan_tier: 2,
      status: 1
    }
  });

  const [studio2] = await StudioProfile.findOrCreate({
    where: { user_id: studioOwner2.user_id },
    defaults: {
      studio_id: generateId(),
      user_id: studioOwner2.user_id,
      name: "画布成长空间",
      intro: "综合艺术与儿童表达课程",
      address: "深圳市南山区科技园",
      phone: "0755-12345678",
      settle_rate: 0.1,
      plan_tier: 1,
      status: 1
    }
  });

  await ensureUserRole(studioOwner1.user_id, 3, studio1.studio_id, true);
  await ensureUserRole(studioOwner2.user_id, 3, studio2.studio_id, true);

  const teacherUser1 = await ensureUser({
    user_id: generateId(),
    phone: "13800000004",
    nickname: "陈老师",
    password_hash: passwordHash,
    city: "北京",
    current_role: 2,
    terms_agreed_at: new Date()
  });

  const teacherUser2 = await ensureUser({
    user_id: generateId(),
    phone: "13800000005",
    nickname: "苏老师",
    password_hash: passwordHash,
    city: "深圳",
    current_role: 2,
    terms_agreed_at: new Date()
  });

  const teacher1 = await ensureTeacherProfile({
    teacher_id: generateId(),
    user_id: teacherUser1.user_id,
    real_name: "陈艺文",
    subjects: ["创意绘画", "综合材料"],
    years: 8,
    intro: "擅长 4-9 岁儿童艺术启蒙",
    cert_no: "TC-2026-1001",
    studio_id: studio1.studio_id,
    cert_status: 1,
    rating: 4.9,
    student_count: 86,
    work_count: 312,
    fans: 560
  });

  const teacher2 = await ensureTeacherProfile({
    teacher_id: generateId(),
    user_id: teacherUser2.user_id,
    real_name: "苏清",
    subjects: ["水彩", "手工"],
    years: 5,
    intro: "擅长儿童表达与主题创作",
    cert_no: "TC-2026-1002",
    studio_id: studio2.studio_id,
    cert_status: 1,
    rating: 4.8,
    student_count: 63,
    work_count: 208,
    fans: 420
  });

  await ensureUserRole(teacherUser1.user_id, 2, teacher1.teacher_id, true);
  await ensureUserRole(teacherUser2.user_id, 2, teacher2.teacher_id, true);

  await AdminAccount.findOrCreate({
    where: { username: "studio_owner_1" },
    defaults: {
      admin_id: generateId(),
      user_id: studioOwner1.user_id,
      username: "studio_owner_1",
      password_hash: passwordHash,
      role: "studio_owner",
      studio_id: studio1.studio_id,
      status: 1
    }
  });

  await StudioApplication.findOrCreate({
    where: { user_id: studioOwner1.user_id, version: 1 },
    defaults: {
      id: generateId(),
      user_id: studioOwner1.user_id,
      name: "木色少儿美术",
      intro: "少儿创意美术与材料表达课程",
      address: "杭州市西湖区文三路",
      phone: "0571-12345678",
      version: 1,
      status: 0
    }
  });

  await TeacherApplication.findOrCreate({
    where: { user_id: studioOwner2.user_id, version: 1 },
    defaults: {
      id: generateId(),
      user_id: studioOwner2.user_id,
      studio_id: studio2.studio_id,
      real_name: "李老师",
      subjects: ["美术", "手工"],
      years: 6,
      intro: "擅长儿童创意绘画",
      cert_no: "T-2026-001",
      version: 1,
      status: 0
    }
  });

  await Settlement.findOrCreate({
    where: {
      studio_id: studio1.studio_id,
      period_start: "2026-09-01",
      period_end: "2026-09-30"
    },
    defaults: {
      settlement_id: generateId(),
      studio_id: studio1.studio_id,
      period_start: "2026-09-01",
      period_end: "2026-09-30",
      income: 8820000,
      refund: 320000,
      distribution: 548800,
      net_amount: 7951200,
      fee_rate: 0.12,
      fee_amount: 954144,
      payable_amount: 6997056,
      status: 0
    }
  });

  await Settlement.findOrCreate({
    where: {
      studio_id: studio2.studio_id,
      period_start: "2026-09-01",
      period_end: "2026-09-30"
    },
    defaults: {
      settlement_id: generateId(),
      studio_id: studio2.studio_id,
      period_start: "2026-09-01",
      period_end: "2026-09-30",
      income: 4360000,
      refund: 160000,
      distribution: 378000,
      net_amount: 3822000,
      fee_rate: 0.1,
      fee_amount: 382200,
      payable_amount: 3439800,
      status: 3
    }
  });

  const course1 = await ensureCourse({
    course_id: generateId(),
    studio_id: studio1.studio_id,
    teacher_id: teacher1.teacher_id,
    title: "创意启蒙绘画班",
    category: 1,
    age_min: 4,
    age_max: 6,
    total_lessons: 12,
    duration_min: 90,
    price: 168000,
    class_size: 10,
    rating: 4.9,
    sales: 128,
    distribute_rate: 0.08,
    validity_days: 180,
    status: 1,
    cover: "https://example.com/course-creative-art.jpg"
  });

  const course2 = await ensureCourse({
    course_id: generateId(),
    studio_id: studio2.studio_id,
    teacher_id: teacher2.teacher_id,
    title: "综合材料创作营",
    category: 2,
    age_min: 7,
    age_max: 10,
    total_lessons: 8,
    duration_min: 120,
    price: 236000,
    class_size: 12,
    rating: 4.8,
    sales: 76,
    distribute_rate: 0.1,
    validity_days: 120,
    status: 1,
    cover: "https://example.com/course-mixed-media.jpg"
  });

  const course3 = await ensureCourse({
    course_id: generateId(),
    studio_id: studio1.studio_id,
    teacher_id: teacher1.teacher_id,
    title: "周末亲子手作课",
    category: 3,
    age_min: 5,
    age_max: 8,
    total_lessons: 6,
    duration_min: 90,
    price: 98000,
    class_size: 8,
    rating: 4.7,
    sales: 42,
    distribute_rate: 0.08,
    validity_days: 90,
    status: 0,
    cover: "https://example.com/course-parent-kids.jpg"
  });

  await ensureCoursePackage(course1.course_id, {
    name: "12 课时包",
    lessons: 12,
    price: 168000,
    original_price: 188000,
    status: 1
  });
  await ensureCoursePackage(course1.course_id, {
    name: "24 课时包",
    lessons: 24,
    price: 318000,
    original_price: 376000,
    status: 1
  });
  await ensureCoursePackage(course2.course_id, {
    name: "8 课时包",
    lessons: 8,
    price: 236000,
    original_price: 256000,
    status: 1
  });
  await ensureCoursePackage(course3.course_id, {
    name: "6 课时体验包",
    lessons: 6,
    price: 98000,
    original_price: 108000,
    status: 1
  });

  const class1 = await ensureClass(course1.course_id, teacher1.teacher_id, {
    name: "周二晚班",
    schedule_rule: { weekday: [2], time: "18:30-20:00" },
    start_date: "2026-09-16",
    end_date: "2026-12-16",
    capacity: 10,
    enrolled: 8
  });
  const class2 = await ensureClass(course2.course_id, teacher2.teacher_id, {
    name: "周六上午班",
    schedule_rule: { weekday: [6], time: "10:00-12:00" },
    start_date: "2026-09-20",
    end_date: "2026-11-15",
    capacity: 12,
    enrolled: 9
  });

  await ensureSchedule(studio1.studio_id, class1.class_id, course1.course_id, teacher1.teacher_id, {
    lesson_date: "2026-09-16",
    start_time: "18:30",
    end_time: "20:00",
    location: "A101 教室",
    status: 0,
    remark: "演示排课"
  });
  await ensureSchedule(studio1.studio_id, class1.class_id, course1.course_id, teacher1.teacher_id, {
    lesson_date: "2026-09-23",
    start_time: "18:30",
    end_time: "20:00",
    location: "A101 教室",
    status: 0,
    remark: "演示排课"
  });
  await ensureSchedule(studio2.studio_id, class2.class_id, course2.course_id, teacher2.teacher_id, {
    lesson_date: "2026-09-20",
    start_time: "10:00",
    end_time: "12:00",
    location: "B201 教室",
    status: 0,
    remark: "演示排课"
  });

  const course1Package = await CoursePackage.findOne({
    where: { course_id: course1.course_id, name: "12 课时包" }
  });
  const course2Package = await CoursePackage.findOne({
    where: { course_id: course2.course_id, name: "8 课时包" }
  });

  await ensurePaidOrder({
    user: parentUser,
    child: child1,
    studio: studio1,
    course: course1,
    coursePackage: course1Package,
    refundLessons: 0
  });

  await ensurePaidOrder({
    user: parentUser,
    child: child1,
    studio: studio2,
    course: course2,
    coursePackage: course2Package,
    refundLessons: 2
  });

  console.log("Demo seed completed");
  await sequelize.close();
}

main().catch(async (error) => {
  console.error("Demo seed failed:", error);
  await sequelize.close().catch(() => {});
  process.exit(1);
});

const { Op } = require("sequelize");
const {
  sequelize,
  Child,
  Course,
  CoursePackage,
  Order,
  OrderItem,
  Payment,
  Refund,
  ChildCourseBalance,
  LessonLog,
  StudioProfile
} = require("../models");
const { generateId } = require("../utils/id");

function formatOrder(order) {
  return {
    order_id: String(order.order_id),
    order_no: order.order_no,
    status: order.status,
    total_lessons: order.total_lessons,
    consumed_lessons: order.consumed_lessons,
    refunded_lessons: order.refunded_lessons,
    remaining_lessons: Math.max(
      Number(order.total_lessons) - Number(order.consumed_lessons) - Number(order.refunded_lessons),
      0
    ),
    total_amount: order.total_amount,
    paid_amount: order.paid_amount,
    refund_amount: order.refund_amount,
    pay_channel: order.pay_channel,
    paid_at: order.paid_at,
    created_at: order.created_at,
    child: order.child
      ? {
          child_id: String(order.child.child_id),
          nickname: order.child.nickname,
          birthday: order.child.birthday
        }
      : null,
    studio: order.studio
      ? {
          studio_id: String(order.studio.studio_id),
          name: order.studio.name
        }
      : null,
    course: order.course
      ? {
          course_id: String(order.course.course_id),
          title: order.course.title,
          cover: order.course.cover
        }
      : null,
    package: order.coursePackage
      ? {
          package_id: String(order.coursePackage.package_id),
          name: order.coursePackage.name,
          lessons: order.coursePackage.lessons
        }
      : null,
    items: (order.items || []).map((item) => ({
      item_id: String(item.item_id),
      course_title: item.course_title,
      package_name: item.package_name,
      lessons: item.lessons,
      unit_price: item.unit_price,
      total_price: item.total_price
    })),
    payments: (order.payments || []).map((item) => ({
      payment_id: String(item.payment_id),
      payment_no: item.payment_no,
      channel: item.channel,
      amount: item.amount,
      status: item.status,
      paid_at: item.paid_at
    })),
    refunds: (order.refunds || []).map((item) => ({
      refund_id: String(item.refund_id),
      amount: item.amount,
      requested_lessons: item.requested_lessons,
      refundable_lessons: item.refundable_lessons,
      status: item.status,
      reason: item.reason,
      created_at: item.created_at
    })),
    balance: order.balance
      ? {
          balance_id: String(order.balance.balance_id),
          total_lessons: order.balance.total_lessons,
          consumed_lessons: order.balance.consumed_lessons,
          refunded_lessons: order.balance.refunded_lessons,
          remaining_lessons: order.balance.remaining_lessons,
          valid_from: order.balance.valid_from,
          valid_to: order.balance.valid_to,
          status: order.balance.status
        }
      : null
  };
}

async function getOrderWithDetails(orderId, options = {}) {
  return Order.findByPk(orderId, {
    transaction: options.transaction,
    include: [
      { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
      { model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] },
      { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
      { model: CoursePackage, as: "coursePackage", attributes: ["package_id", "name", "lessons"] },
      { model: OrderItem, as: "items", attributes: ["item_id", "course_title", "package_name", "lessons", "unit_price", "total_price"] },
      { model: Payment, as: "payments", attributes: ["payment_id", "payment_no", "channel", "amount", "status", "paid_at"] },
      { model: Refund, as: "refunds", attributes: ["refund_id", "amount", "requested_lessons", "refundable_lessons", "status", "reason", "created_at"] },
      { model: ChildCourseBalance, as: "balance", attributes: ["balance_id", "total_lessons", "consumed_lessons", "refunded_lessons", "remaining_lessons", "valid_from", "valid_to", "status"] }
    ]
  });
}

async function ensureChildBelongsToUser(childId, userId, transaction) {
  const child = await Child.findOne({
    where: {
      child_id: childId,
      parent_user_id: userId
    },
    transaction
  });

  if (!child) {
    throw new Error("Child not found");
  }

  return child;
}

async function ensureCoursePackage(courseId, packageId, transaction) {
  const course = await Course.findByPk(courseId, { transaction });
  if (!course || Number(course.status) !== 1) {
    throw new Error("Course not available");
  }

  const coursePackage = await CoursePackage.findOne({
    where: {
      package_id: packageId,
      course_id: courseId,
      status: 1
    },
    transaction
  });

  if (!coursePackage) {
    throw new Error("Course package not found");
  }

  return { course, coursePackage };
}

async function createOrder(userId, payload) {
  return sequelize.transaction(async (transaction) => {
    const child = await ensureChildBelongsToUser(payload.child_id, userId, transaction);
    const { course, coursePackage } = await ensureCoursePackage(payload.course_id, payload.package_id, transaction);

    const order = await Order.create(
      {
        order_id: generateId(),
        order_no: `TG${generateId()}`,
        user_id: userId,
        child_id: child.child_id,
        studio_id: course.studio_id,
        course_id: course.course_id,
        package_id: coursePackage.package_id,
        total_lessons: coursePackage.lessons,
        total_amount: coursePackage.price,
        remark: payload.remark || null,
        status: 0
      },
      { transaction }
    );

    await OrderItem.create(
      {
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
      },
      { transaction }
    );

    const detail = await getOrderWithDetails(order.order_id, { transaction });
    return formatOrder(detail);
  });
}

function computeValidTo(validityDays) {
  if (!validityDays) {
    return null;
  }

  const now = new Date();
  now.setDate(now.getDate() + Number(validityDays));
  return now.toISOString().slice(0, 10);
}

async function payOrder(userId, orderId, payload) {
  return sequelize.transaction(async (transaction) => {
    const order = await Order.findOne({
      where: {
        order_id: orderId,
        user_id: userId
      },
      include: [
        { model: Course, as: "course", attributes: ["course_id", "validity_days"] }
      ],
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!order) {
      return null;
    }

    if (Number(order.status) !== 0) {
      throw new Error("Order already paid or unavailable");
    }

    const paidAt = new Date();
    await Payment.create(
      {
        payment_id: generateId(),
        order_id: order.order_id,
        payment_no: `PM${generateId()}`,
        channel: payload.channel || "wechat_mini",
        amount: order.total_amount,
        paid_at: paidAt,
        status: 1,
        trade_no: `TRADE${generateId()}`
      },
      { transaction }
    );

    await order.update(
      {
        paid_amount: order.total_amount,
        pay_channel: payload.channel || "wechat_mini",
        paid_at: paidAt,
        status: 1
      },
      { transaction }
    );

    await ChildCourseBalance.create(
      {
        balance_id: generateId(),
        child_id: order.child_id,
        course_id: order.course_id,
        order_id: order.order_id,
        total_lessons: order.total_lessons,
        consumed_lessons: 0,
        refunded_lessons: 0,
        remaining_lessons: order.total_lessons,
        valid_from: paidAt.toISOString().slice(0, 10),
        valid_to: computeValidTo(order.course?.validity_days),
        status: 1
      },
      { transaction }
    );

    await LessonLog.create(
      {
        log_id: generateId(),
        child_id: order.child_id,
        course_id: order.course_id,
        order_id: order.order_id,
        source: 0,
        type: 1,
        delta: order.total_lessons,
        balance_after: order.total_lessons,
        note: "订单支付成功，课时到账"
      },
      { transaction }
    );

    const detail = await getOrderWithDetails(order.order_id, { transaction });
    return formatOrder(detail);
  });
}

async function listOrders(userId, query = {}) {
  const where = { user_id: userId };
  if (query.status !== undefined && query.status !== "") {
    where.status = Number(query.status);
  }

  const rows = await Order.findAll({
    where,
    include: [
      { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
      { model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] },
      { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
      { model: CoursePackage, as: "coursePackage", attributes: ["package_id", "name", "lessons"] },
      { model: OrderItem, as: "items", attributes: ["item_id", "course_title", "package_name", "lessons", "unit_price", "total_price"] },
      { model: Payment, as: "payments", attributes: ["payment_id", "payment_no", "channel", "amount", "status", "paid_at"] },
      { model: Refund, as: "refunds", attributes: ["refund_id", "amount", "requested_lessons", "refundable_lessons", "status", "reason", "created_at"] },
      { model: ChildCourseBalance, as: "balance", attributes: ["balance_id", "total_lessons", "consumed_lessons", "refunded_lessons", "remaining_lessons", "valid_from", "valid_to", "status"] }
    ],
    order: [["created_at", "DESC"]]
  });

  return {
    total: rows.length,
    list: rows.map(formatOrder)
  };
}

async function getOrderDetail(userId, orderId) {
  const row = await getOrderWithDetails(orderId);
  if (!row || String(row.user_id) !== String(userId)) {
    return null;
  }

  return formatOrder(row);
}

async function createRefund(userId, orderId, payload) {
  return sequelize.transaction(async (transaction) => {
    const order = await Order.findOne({
      where: {
        order_id: orderId,
        user_id: userId
      },
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!order) {
      return null;
    }

    if (![1, 3].includes(Number(order.status))) {
      throw new Error("Order is not refundable");
    }

    const existingPending = await Refund.findOne({
      where: {
        order_id: order.order_id,
        status: {
          [Op.in]: [0, 1]
        }
      },
      transaction
    });

    if (existingPending) {
      throw new Error("Refund is already in progress");
    }

    const balance = await ChildCourseBalance.findOne({
      where: { order_id: order.order_id },
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!balance) {
      throw new Error("Course balance not found");
    }

    const remainingLessons = Number(balance.remaining_lessons);
    const requestedLessons = Number(payload.lessons);
    if (requestedLessons > remainingLessons) {
      throw new Error("Refund lessons exceed remaining lessons");
    }

    const unitPrice = Math.floor(Number(order.paid_amount) / Number(order.total_lessons));
    const refundAmount = unitPrice * requestedLessons;

    const refund = await Refund.create(
      {
        refund_id: generateId(),
        order_id: order.order_id,
        user_id: userId,
        requested_lessons: requestedLessons,
        refundable_lessons: remainingLessons,
        unit_price: unitPrice,
        amount: refundAmount,
        reason: payload.reason || null,
        status: 0
      },
      { transaction }
    );

    return {
      refund_id: String(refund.refund_id),
      order_id: String(order.order_id),
      amount: refund.amount,
      requested_lessons: refund.requested_lessons,
      refundable_lessons: refund.refundable_lessons,
      status: refund.status
    };
  });
}

module.exports = {
  createOrder,
  payOrder,
  listOrders,
  getOrderDetail,
  createRefund,
  formatOrder,
  getOrderWithDetails
};

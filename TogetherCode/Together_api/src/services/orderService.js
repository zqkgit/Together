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
const { resolveDistributionCode, settleCommissionForOrder } = require("./commissionService");
const { createNotification } = require("./messageService");

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

    // 分销归因：带分享码下单时，记录分享来源，支付成功后按工作室返利比例结算
    let distributionLinkId = null;
    if (payload.distribution_code) {
      const link = await resolveDistributionCode(payload.distribution_code, transaction);
      if (link && String(link.parent_user_id) !== String(userId)) {
        distributionLinkId = link.link_id;
      }
    }

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
        distribution_link_id: distributionLinkId,
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
        { model: Course, as: "course", attributes: ["course_id", "title", "validity_days"] }
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

    // 分销结算：带分享码下单的订单，支付成功后按工作室返利比例给分享人结算佣金
    await settleCommissionForOrder(order, { transaction, settleImmediately: true });

    // 闭环：支付成功 → 通知家长（课时到账）
    createNotification({
      userId,
      type: "order",
      title: "支付成功",
      content: `《${order.course?.title || "课程"}》${order.total_lessons} 课时已到账，可在「我的订单」查看。`,
      refType: "order",
      refId: order.order_id
    }).catch(() => {});

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


const REFUND_STATUS_TEXT = { 0: "申请中", 1: "打款中", 2: "已驳回", 3: "已退款到账" };

function refundStatusText(status) {
  return REFUND_STATUS_TEXT[Number(status)] || "未知";
}

/** 家长端：我的退款列表 */
async function listMyRefunds(userId, query = {}) {
  const where = { user_id: userId };
  if (query.status !== undefined && query.status !== "") {
    where.status = Number(query.status);
  }

  const rows = await Refund.findAll({
    where,
    include: [
      {
        model: Order,
        as: "order",
        required: true,
        include: [
          { model: Child, as: "child", attributes: ["child_id", "nickname"] },
          { model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] },
          { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
          { model: ChildCourseBalance, as: "balance", attributes: ["balance_id", "total_lessons", "consumed_lessons", "refunded_lessons", "remaining_lessons"] }
        ]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  return {
    total: rows.length,
    list: rows.map((r) => ({
      refund_id: String(r.refund_id),
      order_id: String(r.order_id),
      course_title: r.order?.course ? r.order.course.title : "-",
      course_cover: r.order?.course ? r.order.course.cover : null,
      studio_name: r.order?.studio ? r.order.studio.name : null,
      child_name: r.order?.child ? r.order.child.nickname : "-",
      requested_lessons: Number(r.requested_lessons),
      amount: Number(r.amount),
      amount_text: `¥${(Number(r.amount) / 100).toFixed(2)}`,
      status: Number(r.status),
      status_text: refundStatusText(r.status),
      reason: r.reason,
      created_at: r.created_at
    }))
  };
}

/** 家长端：退款详情（状态流转） */
async function getRefundDetail(userId, refundId) {
  const row = await Refund.findOne({
    where: { refund_id: refundId, user_id: userId },
    include: [
      {
        model: Order,
        as: "order",
        required: true,
        include: [
          { model: Child, as: "child", attributes: ["child_id", "nickname"] },
          { model: StudioProfile, as: "studio", attributes: ["studio_id", "name"] },
          { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
          { model: ChildCourseBalance, as: "balance", attributes: ["balance_id", "total_lessons", "consumed_lessons", "refunded_lessons", "remaining_lessons", "valid_to"] }
        ]
      }
    ]
  });
  if (!row) return null;

  const status = Number(row.status);
  const order = row.order;
  return {
    refund_id: String(row.refund_id),
    order_id: String(row.order_id),
    order_no: order ? order.order_no : null,
    course_title: order?.course ? order.course.title : "-",
    course_cover: order?.course ? order.course.cover : null,
    studio_name: order?.studio ? order.studio.name : null,
    child_name: order?.child ? order.child.nickname : "-",
    total_lessons: order ? Number(order.total_lessons) : 0,
    consumed_lessons: order ? Number(order.consumed_lessons) : 0,
    refunded_lessons: order ? Number(order.refunded_lessons) : 0,
    balance_remaining: order?.balance ? Number(order.balance.remaining_lessons) : 0,
    valid_to: order?.balance ? order.balance.valid_to : null,
    requested_lessons: Number(row.requested_lessons),
    refundable_lessons: Number(row.refundable_lessons),
    unit_price: Number(row.unit_price),
    unit_price_text: `¥${(Number(row.unit_price) / 100).toFixed(2)}/课时`,
    amount: Number(row.amount),
    amount_text: `¥${(Number(row.amount) / 100).toFixed(2)}`,
    reason: row.reason,
    status: status,
    status_text: refundStatusText(status),
    created_at: row.created_at,
    reviewed_at: row.reviewed_at,
    refunded_at: row.refunded_at,
    steps: [
      { key: "submit", title: "提交申请", time: row.created_at, done: true },
      { key: "review", title: "工作室审核", time: row.reviewed_at, done: row.reviewed_at != null, current: status === 0 },
      { key: "result", title: status === 2 ? "已驳回" : "已通过并退款", time: status === 2 ? row.reviewed_at : row.refunded_at, done: status === 2 || status === 3, current: status === 2 || status === 3 }
    ]
  };
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
  listMyRefunds,
  getRefundDetail,
  formatOrder,
  getOrderWithDetails
};

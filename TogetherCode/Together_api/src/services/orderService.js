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
  StudioProfile,
  Class,
  User
} = require("../models");
const { generateId } = require("../utils/id");
const { resolveDistributionCode, settleCommissionForOrder } = require("./commissionService");
const { createNotification } = require("./messageService");

// 订单状态机：见 utils/orderStatus（0待收款 1待确认收款 2已收款 3退款审核中 4待家长确认退款 5已退款 6已取消）
const { ORDER_STATUS, ORDER_STATUS_TEXT } = require("../utils/orderStatus");
// 线下支付方式（平台不碰资金，仅作文字/凭证记录，不跳转支付、不展示收款码）
const {
  PAY_METHODS,
  PAY_METHOD_TEXT,
  ONLINE_PAY_METHODS,
  payMethodText,
  isOnlinePayMethod
} = require("../utils/payMethods");
// 收款凭证（Payment）状态：0 待工作室确认 / 1 已确认 / 2 已驳回
const PAYMENT_STATUS_TEXT = { 0: "待确认", 1: "已确认", 2: "已驳回" };

function formatOrder(order) {
  const refundList = (order.refunds || []).map((item) => ({
    refund_id: String(item.refund_id),
    amount: item.amount,
    requested_lessons: item.requested_lessons,
    refundable_lessons: item.refundable_lessons,
    status: item.status,
    status_text: REFUND_STATUS_TEXT[Number(item.status)] || "未知",
    reason: item.reason,
    created_at: item.created_at
  }));
  // 订单层退款聚合状态：0 无 / 1 退款中 / 2 已退款 / 3 已驳回
  const activeRefund = refundList.find((r) => r.status === 0 || r.status === 1);
  const refundedRefund = refundList.find((r) => r.status === 3);
  const rejectedRefund = refundList.find((r) => r.status === 2);
  let refund_status = 0;
  let refund_status_text = "无";
  if (activeRefund) {
    refund_status = 1;
    refund_status_text = "退款中";
  } else if (refundedRefund) {
    refund_status = 2;
    refund_status_text = "已退款";
  } else if (rejectedRefund) {
    refund_status = 3;
    refund_status_text = "已驳回";
  }

  return {
    order_id: String(order.order_id),
    order_no: order.order_no,
    status: order.status,
    status_text: ORDER_STATUS_TEXT[Number(order.status)] || "未知",
    // 订单来源：0 家长自助报名 1 工作室手动建单
    source: Number(order.source || 0),
    source_text: Number(order.source) === 1 ? "工作室建单" : "家长报名",
    class_id: order.class_id ? String(order.class_id) : null,
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
    refund_status: refund_status,
    refund_status_text: refund_status_text,
    pay_channel: order.pay_channel,
    pay_method: order.pay_channel || null,
    pay_method_text: payMethodText(order.pay_channel),
    confirmed_by: order.confirmed_by ? String(order.confirmed_by) : null,
    paid_at: order.paid_at,
    created_at: order.created_at,
    child: order.child
      ? {
          child_id: String(order.child.child_id),
          nickname: order.child.nickname,
          birthday: order.child.birthday
        }
      : null,
    user: order.user
      ? {
          user_id: String(order.user.user_id),
          nickname: order.user.nickname,
          phone: order.user.phone,
          avatar: order.user.avatar || null
        }
      : null,
    class: order.class
      ? {
          class_id: String(order.class.class_id),
          name: order.class.name
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
          cover: order.course.cover,
          validity_days: order.course.validity_days
        }
      : null,
    pay_expire_at: payExpireAt(order),
    refund_expire_at: refundExpireAt(order),
    can_apply_refund: canApplyRefund(order, refund_status, activeRefund),
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
      pay_method: item.pay_method || item.channel || null,
      pay_method_text: payMethodText(item.pay_method || item.channel),
      amount: item.amount,
      status: item.status,
      status_text: PAYMENT_STATUS_TEXT[Number(item.status)] || "未知",
      voucher_images: Array.isArray(item.voucher_images) ? item.voucher_images : [],
      payer_note: item.payer_note || null,
      upload_by: Number(item.upload_by || 0),
      reject_reason: item.reject_reason || null,
      paid_at: item.paid_at,
      created_at: item.created_at
    })),
    refunds: refundList,
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
      { model: User, as: "user", attributes: ["user_id", "nickname", "phone", "avatar"] },
      { model: Class, as: "class", attributes: ["class_id", "name"] },
      { model: StudioProfile, as: "studio", attributes: ["studio_id", "name", "payment_expire_hours"] },
      { model: Course, as: "course", attributes: ["course_id", "title", "cover", "validity_days"] },
      { model: CoursePackage, as: "coursePackage", attributes: ["package_id", "name", "lessons"] },
      { model: OrderItem, as: "items", attributes: ["item_id", "course_title", "package_name", "lessons", "unit_price", "total_price"] },
      { model: Payment, as: "payments", attributes: ["payment_id", "payment_no", "channel", "pay_method", "amount", "status", "paid_at", "voucher_images", "payer_note", "upload_by", "confirm_by", "reject_reason", "created_at"] },
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

async function ensureCourse(courseId, transaction) {
  const course = await Course.findByPk(courseId, { transaction });
  if (!course || Number(course.status) !== 1) {
    throw new Error("Course not available");
  }
  return course;
}

async function createOrder(userId, payload) {
  return sequelize.transaction(async (transaction) => {
    const child = await ensureChildBelongsToUser(payload.child_id, userId, transaction);
    // 课程固定课时与价格：一个课程一个课时包（不再选择课时包）
    const course = await ensureCourse(payload.course_id, transaction);

    // 防重复报名：同一孩子同一课程已有有效权益（报名中/已支付）则拒绝下单
    const existingBalance = await ChildCourseBalance.findOne({
      where: {
        child_id: child.child_id,
        course_id: course.course_id,
        status: { [Op.in]: [1, 2] }
      },
      transaction
    });
    if (existingBalance) {
      throw new Error("该孩子已报名此课程，请勿重复报名");
    }
    // 已有待收款订单也拦截，避免重复生成多份权益
    const pendingOrder = await Order.findOne({
      where: {
        user_id: userId,
        child_id: child.child_id,
        course_id: course.course_id,
        status: 0
      },
      transaction
    });
    if (pendingOrder) {
      throw new Error("该孩子已有此课程的待收款订单，请先完成线下付款或取消");
    }

    // 报名必须选择班级：校验班级属于该课程，且未满员
    let classId = null;
    if (payload.class_id) {
      const classItem = await Class.findByPk(payload.class_id, { transaction });
      if (!classItem || String(classItem.course_id) !== String(course.course_id)) {
        throw new Error("Class does not belong to course");
      }
      if (Number(classItem.enrolled) >= Number(classItem.capacity)) {
        throw new Error("班级已满员，请选择其他班级");
      }
      classId = String(classItem.class_id);
    }

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
        class_id: classId,
        package_id: payload.package_id || null,
        total_lessons: course.total_lessons,
        total_amount: course.price,
        remark: payload.remark || null,
        distribution_link_id: distributionLinkId,
        source: 0,
        status: 0
      },
      { transaction }
    );

    await OrderItem.create(
      {
        item_id: generateId(),
        order_id: order.order_id,
        course_id: course.course_id,
        class_id: classId,
        package_id: payload.package_id || null,
        course_title: course.title,
        package_name: null,
        lessons: course.total_lessons,
        quantity: 1,
        unit_price: course.price,
        total_price: course.price
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

/**
 * 工作室确认全款到账后发放课时（原"在线支付成功"履约逻辑，改为线下收款确认时触发）。
 * 入口可为 0 待收款（工作室当场登记 / 手动建单）或 1 待确认收款（核对家长上传的凭证后确认）；
 * 确认后订单进入「已收款」status=2。调用方需先做归属与凭证校验。
 * 佣金此时只记「待申请」，不入推广人钱包。
 */
async function grantOrderLessons(order, { transaction, payMethod = null, operatorId = null, notify = true } = {}) {
  if (!order) {
    throw new Error("Order not found");
  }
  // 0 待收款 = 工作室当场登记；1 待确认收款 = 核对家长凭证
  if (
    Number(order.status) !== ORDER_STATUS.PENDING_PAYMENT &&
    Number(order.status) !== ORDER_STATUS.PAYMENT_REVIEW
  ) {
    throw new Error("订单不是待收款 / 待确认收款状态");
  }

  const paidAt = new Date();
  const method = payMethod || order.pay_channel || "offline";

  await order.update(
    {
      paid_amount: order.total_amount,
      pay_channel: method,
      paid_at: paidAt,
      confirmed_by: operatorId || null,
      status: ORDER_STATUS.PAID
    },
    { transaction }
  );

  const course =
    order.course ||
    (await Course.findByPk(order.course_id, { transaction, attributes: ["course_id", "title", "validity_days"] }));

  await ChildCourseBalance.create(
    {
      balance_id: generateId(),
      child_id: order.child_id,
      course_id: order.course_id,
      class_id: order.class_id ? String(order.class_id) : null,
      order_id: order.order_id,
      total_lessons: order.total_lessons,
      consumed_lessons: 0,
      refunded_lessons: 0,
      remaining_lessons: order.total_lessons,
      valid_from: paidAt.toISOString().slice(0, 10),
      valid_to: computeValidTo(course?.validity_days),
      status: 1
    },
    { transaction }
  );

  // 报名成功：班级在学人数 +1
  if (order.class_id) {
    await Class.increment("enrolled", { by: 1, where: { class_id: order.class_id }, transaction });
  }

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
      note: "工作室确认收款，课时到账"
    },
    { transaction }
  );

  // 佣金记为待申请（工作室后续线下打款、推广人确认后才到账）
  await settleCommissionForOrder(order, { transaction });

  if (notify) {
    createNotification({
      userId: order.user_id,
      type: "order",
      title: "收款已确认，课时到账",
      content: `《${course?.title || "课程"}》${order.total_lessons} 课时已到账，可在「我的订单」查看。`,
      refType: "order",
      refId: order.order_id
    }).catch(() => {});
  }

  return getOrderWithDetails(order.order_id, { transaction });
}

/**
 * 家长端：为订单上传线下付款凭证（线上转账必传凭证；现金一般由工作室直接登记）。
 * 首次传凭证：订单 0 待收款 → 1 待确认收款；
 * 凭证被工作室驳回（payment.status=2）后重传：订单保持 1，覆盖原凭证。
 */
async function submitPaymentVoucher(userId, orderId, payload) {
  return sequelize.transaction(async (transaction) => {
    const order = await Order.findOne({
      where: { order_id: orderId, user_id: userId },
      include: [
        { model: Course, as: "course", attributes: ["course_id", "title"] },
        { model: StudioProfile, as: "studio", attributes: ["studio_id", "name", "user_id"] }
      ],
      transaction,
      lock: transaction.LOCK.UPDATE
    });
    if (!order) {
      return null;
    }

    // 首次传凭证：订单为 0 待收款；驳回后重传：订单为 1 待确认收款且当前凭证被驳回
    let isResubmit = false;
    const currentOrderStatus = Number(order.status);
    if (currentOrderStatus === ORDER_STATUS.PAYMENT_REVIEW) {
      const rejected = await Payment.findOne({
        where: { order_id: orderId, status: 2 },
        transaction
      });
      if (!rejected) {
        throw new Error("凭证已提交，正在等待工作室核对");
      }
      isResubmit = true;
    } else if (currentOrderStatus !== ORDER_STATUS.PENDING_PAYMENT) {
      throw new Error("订单当前状态无法上传凭证");
    }

    const method = payload.pay_method;
    if (!PAY_METHODS.includes(method)) {
      throw new Error("请选择支付方式");
    }
    const images = Array.isArray(payload.voucher_images)
      ? payload.voucher_images.map((v) => String(v || "").trim()).filter(Boolean)
      : [];
    if (isOnlinePayMethod(method) && images.length === 0) {
      throw new Error("线上转账请上传付款凭证截图");
    }
    const note = payload.note ? String(payload.note).slice(0, 255) : null;

    const existing = await Payment.findOne({
      where: { order_id: orderId, status: { [Op.in]: [0, 2] } },
      transaction,
      order: [["created_at", "DESC"]]
    });

    if (existing) {
      await existing.update(
        {
          channel: method,
          pay_method: method,
          amount: order.total_amount,
          voucher_images: images,
          payer_note: note,
          upload_by: 0,
          status: 0,
          reject_reason: null,
          paid_at: null,
          confirm_by: null
        },
        { transaction }
      );
    } else {
      await Payment.create(
        {
          payment_id: generateId(),
          order_id: orderId,
          payment_no: `PM${generateId()}`,
          channel: method,
          pay_method: method,
          amount: order.total_amount,
          voucher_images: images,
          payer_note: note,
          upload_by: 0,
          status: 0
        },
        { transaction }
      );
    }

    // 首次传凭证：订单进入「待确认收款」（驳回重传时订单已在该状态）
    if (!isResubmit) {
      await order.update({ status: ORDER_STATUS.PAYMENT_REVIEW }, { transaction });
    }

    // 通知工作室核对（studio.user_id 为工作室主体账号）
    if (order.studio?.user_id) {
      createNotification({
        userId: order.studio.user_id,
        type: "order",
        title: "新的付款凭证待核对",
        content: `家长已提交「${order.course?.title || "课程"}」的${payMethodText(method)}付款凭证，请核对到账后确认收款。`.slice(0, 120),
        refType: "order",
        refId: order.order_id
      }).catch(() => {});
    }

    const detail = await getOrderWithDetails(orderId, { transaction });
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
      { model: User, as: "user", attributes: ["user_id", "nickname", "phone", "avatar"] },
      { model: Class, as: "class", attributes: ["class_id", "name"] },
      { model: StudioProfile, as: "studio", attributes: ["studio_id", "name", "payment_expire_hours"] },
      { model: Course, as: "course", attributes: ["course_id", "title", "cover", "validity_days"] },
      { model: CoursePackage, as: "coursePackage", attributes: ["package_id", "name", "lessons"] },
      { model: OrderItem, as: "items", attributes: ["item_id", "course_title", "package_name", "lessons", "unit_price", "total_price"] },
      { model: Payment, as: "payments", attributes: ["payment_id", "payment_no", "channel", "pay_method", "amount", "status", "paid_at", "voucher_images", "payer_note", "upload_by", "confirm_by", "reject_reason", "created_at"] },
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



/** 家长端：取消待收款订单（status 0 待收款 -> 6 已取消） */
async function cancelOrder(userId, orderId) {
  return sequelize.transaction(async (transaction) => {
    const order = await Order.findOne({
      where: { order_id: orderId, user_id: userId },
      transaction,
      lock: transaction.LOCK.UPDATE
    });
    if (!order) {
      return null;
    }
    if (Number(order.status) !== ORDER_STATUS.PENDING_PAYMENT) {
      throw new Error("订单已提交凭证或已处理，无法取消");
    }
    await order.update({ status: ORDER_STATUS.CANCELLED, completed_at: new Date() }, { transaction });
    return getOrderWithDetails(orderId, { transaction });
  });
}

// 退款状态：0 待审核 / 1 待家长确认（工作室已退款传凭证）/ 2 已驳回 / 3 已退款（家长确认收到）
const REFUND_STATUS_TEXT = { 0: "待审核", 1: "待家长确认", 2: "已驳回", 3: "已退款" };

// 支付截止时间：待收款订单 = 订单创建时间 + 工作室支付超时小时数（默认 24h）
function payExpireAt(order) {
  if (Number(order.status) !== ORDER_STATUS.PENDING_PAYMENT || !order.created_at) {
    return null;
  }
  const hours = Number(order.studio?.payment_expire_hours || 24);
  const expireAt = new Date(order.created_at);
  expireAt.setHours(expireAt.getHours() + hours);
  return expireAt.toISOString();
}

// 退款有效期：订单创建时间 + 课程有效期天数（课程创建时快照工作室默认，默认 7 天）
function refundExpireAt(order) {
  const days = Number(order.course?.validity_days || 0);
  if (!days || !order.created_at) {
    return null;
  }
  const expireAt = new Date(order.created_at);
  expireAt.setDate(expireAt.getDate() + days);
  return expireAt.toISOString();
}

// 是否可申请退款：仅已收款(status=2) + 无进行中/已退款 + 有余课 + 未超过退款有效期（已驳回可再次申请）
function canApplyRefund(order, refundStatus, activeRefund) {
  if (Number(order.status) !== ORDER_STATUS.PAID) {
    return false;
  }
  if (activeRefund || [1, 2].includes(Number(refundStatus))) {
    return false;
  }
  const remaining = Number(order.balance?.remaining_lessons ?? 0);
  if (remaining <= 0) {
    return false;
  }
  const expireAt = refundExpireAt(order);
  if (expireAt) {
    return new Date(expireAt) > new Date();
  }
  return true;
}

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
          { model: StudioProfile, as: "studio", attributes: ["studio_id", "name", "payment_expire_hours"] },
          { model: Course, as: "course", attributes: ["course_id", "title", "cover", "validity_days"] },
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
      approved_lessons: r.approved_lessons != null ? Number(r.approved_lessons) : null,
      amount: Number(r.amount),
      amount_text: `¥${(Number(r.amount) / 100).toFixed(2)}`,
      status: Number(r.status),
      status_text: refundStatusText(r.status),
      refund_method: r.refund_method || null,
      refund_method_text: r.refund_method ? payMethodText(r.refund_method) : null,
      can_confirm: Number(r.status) === 1,
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
          { model: StudioProfile, as: "studio", attributes: ["studio_id", "name", "payment_expire_hours"] },
          { model: Course, as: "course", attributes: ["course_id", "title", "cover", "validity_days"] },
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
    approved_lessons: row.approved_lessons != null ? Number(row.approved_lessons) : null,
    refundable_lessons: Number(row.refundable_lessons),
    unit_price: Number(row.unit_price),
    unit_price_text: `¥${(Number(row.unit_price) / 100).toFixed(2)}/课时`,
    amount: Number(row.amount),
    amount_text: `¥${(Number(row.amount) / 100).toFixed(2)}`,
    reason: row.reason,
    status: status,
    status_text: refundStatusText(status),
    refund_method: row.refund_method || null,
    refund_method_text: row.refund_method ? payMethodText(row.refund_method) : null,
    voucher_images: Array.isArray(row.voucher_images) ? row.voucher_images : [],
    reject_reason: row.reject_reason || null,
    can_confirm: status === 1,
    created_at: row.created_at,
    reviewed_at: row.reviewed_at,
    refunded_at: row.refunded_at,
    confirmed_at: row.confirmed_at || null,
    steps: [
      { key: "submit", title: "提交申请", time: row.created_at, done: true },
      { key: "review", title: "机构审核并退款", time: row.reviewed_at, done: row.reviewed_at != null && status !== 2, current: status === 0 },
      { key: "confirm", title: status === 2 ? "已驳回" : "确认收到退款", time: status === 2 ? row.reviewed_at : row.confirmed_at || row.refunded_at, done: status === 2 || status === 3, current: status === 1 }
    ]
  };
}

// 线下资金模式：待收款单不再自动取消（待收款不发课时、不占名额，挂着无副作用），
// 统一由工作室在后台手动取消；原 autoCancelExpiredOrders 定时任务已从 server.js 移除。

async function createRefund(userId, orderId, payload) {
  return sequelize.transaction(async (transaction) => {
    const order = await Order.findOne({
      where: {
        order_id: orderId,
        user_id: userId
      },
      include: [{ model: Course, as: "course", attributes: ["course_id", "validity_days"] }],
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!order) {
      return null;
    }

    if (Number(order.status) !== ORDER_STATUS.PAID) {
      throw new Error("订单不是已收款状态，无法申请退款");
    }

    // 退款有效期：订单创建时间 + 课程有效期天数，超过不可申请
    const expireAt = refundExpireAt(order);
    if (expireAt && new Date(expireAt) <= new Date()) {
      throw new Error("Refund window expired");
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

    // 订单进入「退款审核中」
    await order.update({ status: ORDER_STATUS.REFUND_REVIEW }, { transaction });

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

/**
 * 家长端：确认收到退款。退款单 待家长确认（1）→ 已退款（3）。
 * 工作室通过退款时已线下退回并上传打款凭证；家长确认到账后，才扣减课时、
 * 累计订单退款、写入消课流水、订单转已退款，并通知工作室。
 */
async function confirmRefundReceived(userId, refundId) {
  const tx = await sequelize.transaction();
  let amount = 0;
  try {
    const refund = await Refund.findOne({
      where: { refund_id: refundId, user_id: userId },
      include: [
        {
          model: Order,
          as: "order",
          required: true,
          include: [
            { model: Child, as: "child", attributes: ["child_id", "nickname"] },
            { model: Course, as: "course", attributes: ["course_id", "title"] },
            { model: StudioProfile, as: "studio", attributes: ["studio_id", "name", "user_id"] },
            { model: ChildCourseBalance, as: "balance", attributes: ["balance_id", "remaining_lessons"] }
          ]
        }
      ],
      transaction: tx,
      lock: tx.LOCK.UPDATE
    });

    if (!refund) {
      throw Object.assign(new Error("Refund not found"), { notFound: true });
    }
    if (Number(refund.status) !== 1) {
      throw new Error("Refund not awaiting your confirm");
    }

    const order = refund.order;
    const balance = await ChildCourseBalance.findOne({
      where: { order_id: refund.order_id },
      transaction: tx,
      lock: tx.LOCK.UPDATE
    });
    if (!order || !balance) {
      throw new Error("Refund order balance not found");
    }

    // 按审核锁定的实退课时扣减（申请后可能已消课，approved_lessons 可能少于申请）
    const approvedLessons = Number(
      refund.approved_lessons != null ? refund.approved_lessons : refund.requested_lessons || 0
    );
    const remainingLessons = Number(balance.remaining_lessons || 0);
    if (approvedLessons <= 0) {
      throw new Error("Refund has no approved lessons");
    }
    if (approvedLessons > remainingLessons) {
      throw new Error("Refund lessons exceed current remaining lessons");
    }
    const remainingAfter = remainingLessons - approvedLessons;
    const now = new Date();
    amount = Number(refund.amount || 0);

    await refund.update(
      { status: 3, refunded_at: now, confirmed_at: now },
      { transaction: tx }
    );
    await order.update(
      {
        refunded_lessons: Number(order.refunded_lessons || 0) + approvedLessons,
        refund_amount: Number(order.refund_amount || 0) + amount,
        status: ORDER_STATUS.REFUNDED
      },
      { transaction: tx }
    );
    await balance.update(
      {
        refunded_lessons: Number(balance.refunded_lessons || 0) + approvedLessons,
        remaining_lessons: remainingAfter,
        status: remainingAfter === 0 ? 2 : 1
      },
      { transaction: tx }
    );
    await LessonLog.create(
      {
        log_id: generateId(),
        child_id: order.child_id,
        course_id: order.course_id,
        order_id: order.order_id,
        source: 4,
        type: 3,
        delta: -approvedLessons,
        balance_after: remainingAfter,
        note: "家长确认收到退款，扣减剩余课时"
      },
      { transaction: tx }
    );

    await tx.commit();
  } catch (error) {
    await tx.rollback().catch(() => {});
    if (error.notFound) return null;
    throw error;
  }

  // 通知工作室：家长已确认收到
  try {
    const ownerRefund = await Refund.findByPk(refundId, {
      include: [
        { model: Order, as: "order", include: [{ model: StudioProfile, as: "studio", attributes: ["studio_id", "user_id"] }] }
      ]
    });
    const studioOwnerId = ownerRefund?.order?.studio?.user_id;
    if (studioOwnerId) {
      createNotification({
        userId: studioOwnerId,
        type: "refund",
        title: "家长已确认收到退款",
        content: `退款 ¥${(amount / 100).toFixed(2)} 家长已确认收到，课时已扣减。`.slice(0, 120),
        refType: "refund",
        refId: refundId
      }).catch(() => {});
    }
  } catch (_) {}

  return getRefundDetail(userId, refundId);
}

module.exports = {
  createOrder,
  grantOrderLessons,
  submitPaymentVoucher,
  cancelOrder,
  listOrders,
  getOrderDetail,
  createRefund,
  listMyRefunds,
  getRefundDetail,
  confirmRefundReceived,
  formatOrder,
  getOrderWithDetails,
  PAY_METHODS,
  PAY_METHOD_TEXT,
  ONLINE_PAY_METHODS,
  PAYMENT_STATUS_TEXT,
  payMethodText,
  isOnlinePayMethod
};

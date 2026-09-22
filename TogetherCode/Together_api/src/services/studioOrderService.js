const { Op } = require("sequelize");
const {
  sequelize,
  Order,
  Child,
  Course,
  CoursePackage,
  OrderItem,
  Payment,
  Refund,
  ChildCourseBalance,
  StudioProfile,
  User,
  LessonLog,
  Class
} = require("../models");
const {
  formatOrder,
  getOrderWithDetails,
  grantOrderLessons,
  PAY_METHODS,
  isOnlinePayMethod
} = require("./orderService");
const { createNotification } = require("./messageService");
const { generateId } = require("../utils/id");

function formatStudioRefund(refund) {
  return {
    refund_id: String(refund.refund_id),
    order_id: String(refund.order_id),
    user_id: String(refund.user_id),
    requested_lessons: refund.requested_lessons,
    approved_lessons: refund.approved_lessons != null ? Number(refund.approved_lessons) : null,
    refundable_lessons: refund.refundable_lessons,
    unit_price: refund.unit_price,
    amount: refund.amount,
    reason: refund.reason,
    status: refund.status,
    refund_method: refund.refund_method || null,
    voucher_images: Array.isArray(refund.voucher_images) ? refund.voucher_images : [],
    reject_reason: refund.reject_reason || null,
    reviewed_by: refund.reviewed_by ? String(refund.reviewed_by) : null,
    reviewed_at: refund.reviewed_at,
    refunded_at: refund.refunded_at,
    confirmed_at: refund.confirmed_at || null,
    created_at: refund.created_at,
    order: refund.order
      ? {
          order_id: String(refund.order.order_id),
          order_no: refund.order.order_no,
          status: refund.order.status,
          total_lessons: refund.order.total_lessons,
          consumed_lessons: refund.order.consumed_lessons,
          refunded_lessons: refund.order.refunded_lessons,
          paid_amount: refund.order.paid_amount,
          refund_amount: refund.order.refund_amount,
          paid_at: refund.order.paid_at,
          child: refund.order.child
            ? {
                child_id: String(refund.order.child.child_id),
                nickname: refund.order.child.nickname,
                avatar: refund.order.child.avatar,
                birthday: refund.order.child.birthday
              }
            : null,
          course: refund.order.course
            ? {
                course_id: String(refund.order.course.course_id),
                title: refund.order.course.title,
                cover: refund.order.course.cover
              }
            : null,
          user: refund.order.user
            ? {
                user_id: String(refund.order.user.user_id),
                nickname: refund.order.user.nickname,
                avatar: refund.order.user.avatar,
                phone: refund.order.user.phone
              }
            : null,
          balance: refund.order.balance
            ? {
                balance_id: String(refund.order.balance.balance_id),
                total_lessons: refund.order.balance.total_lessons,
                consumed_lessons: refund.order.balance.consumed_lessons,
                refunded_lessons: refund.order.balance.refunded_lessons,
                remaining_lessons: refund.order.balance.remaining_lessons,
                valid_from: refund.order.balance.valid_from,
                valid_to: refund.order.balance.valid_to,
                status: refund.order.balance.status
              }
            : null
        }
      : null
  };
}

async function listStudioOrders(studioId, query = {}) {
  const where = { studio_id: studioId };
  if (query.status !== undefined && query.status !== null && query.status !== "") {
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
      { model: User, as: "user", attributes: ["user_id", "nickname", "phone"] },
      { model: Class, as: "class", attributes: ["class_id", "name"] },
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

async function getStudioOrderDetail(studioId, orderId) {
  const row = await getOrderWithDetails(orderId);
  if (!row || String(row.studio_id) !== String(studioId)) {
    return null;
  }

  return formatOrder(row);
}

async function listStudioRefunds(studioId, query = {}) {
  const where = {};
  if (query.status !== undefined && query.status !== null && query.status !== "") {
    where.status = Number(query.status);
  }

  const rows = await Refund.findAll({
    where,
    include: [
      {
        model: Order,
        as: "order",
        required: true,
        where: {
          studio_id: studioId
        },
        include: [
          { model: Child, as: "child", attributes: ["child_id", "nickname", "avatar", "birthday"] },
          { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
          { model: ChildCourseBalance, as: "balance", attributes: ["balance_id", "total_lessons", "consumed_lessons", "refunded_lessons", "remaining_lessons", "valid_from", "valid_to", "status"] },
          { model: User, as: "user", attributes: ["user_id", "nickname", "avatar", "phone"] }
        ]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  return {
    total: rows.length,
    list: rows.map(formatStudioRefund)
  };
}

async function reviewStudioRefund(studioId, refundId, payload, operator = {}) {
  const action = payload.action;
  return sequelize.transaction(async (transaction) => {
    const refund = await Refund.findByPk(refundId, {
      include: [
        {
          model: Order,
          as: "order",
          required: true,
          where: {
            studio_id: studioId
          },
          include: [
            { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
            { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
            { model: User, as: "user", attributes: ["user_id", "nickname", "phone"] },
            { model: ChildCourseBalance, as: "balance", attributes: ["balance_id", "total_lessons", "consumed_lessons", "refunded_lessons", "remaining_lessons", "valid_from", "valid_to", "status"] }
          ]
        }
      ],
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!refund) {
      return null;
    }

    const currentStatus = Number(refund.status);

    // 驳回：申请中（0）或待打款（1）均可驳回；已驳回/已打款不可再操作
    if (action === "reject") {
      if (currentStatus !== 0 && currentStatus !== 1) {
        throw new Error("Refund already handled");
      }
      await refund.update(
        {
          status: 2,
          reviewed_by: operator.adminId || null,
          reviewed_at: new Date(),
          reason: payload.reason || refund.reason
        },
        { transaction }
      );

      const latest = await Refund.findByPk(refund.refund_id, {
        include: [
          {
            model: Order,
            as: "order",
            required: true,
            where: { studio_id: studioId },
            include: [
              { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
              { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
              { model: User, as: "user", attributes: ["user_id", "nickname", "phone"] },
              { model: ChildCourseBalance, as: "balance", attributes: ["balance_id", "total_lessons", "consumed_lessons", "refunded_lessons", "remaining_lessons", "valid_from", "valid_to", "status"] }
            ]
          }
        ],
        transaction
      });

      // 通知家长：退款已驳回（待打款阶段驳回时课时未扣，无需回补）
      const parent = refund.order?.user;
      if (parent?.user_id) {
        createNotification({
          userId: parent.user_id,
          type: "refund",
          title: "退款申请已驳回",
          content: `「${refund.order.course?.title || "课程"}」退款 ¥${(Number(refund.amount) / 100).toFixed(2)} 未通过：${payload.reason || "剩余课时与申请不符"}`
            .slice(0, 120),
          refType: "refund",
          refId: refund.refund_id
        }).catch(() => {});
      }

      return formatStudioRefund(latest);
    }

    // 审核通过：仅申请中（0）可进入待打款（1），此时只锁定审核结论，不扣课时、不打款
    if (currentStatus !== 0) {
      throw new Error("Refund already handled");
    }

    const order = await Order.findByPk(refund.order_id, {
      transaction,
      lock: transaction.LOCK.UPDATE
    });
    const balance = await ChildCourseBalance.findOne({
      where: { order_id: refund.order_id },
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!order || !balance) {
      throw new Error("Refund order balance not found");
    }

    const remainingLessons = Number(balance.remaining_lessons || 0);
    const requestedLessons = Number(refund.requested_lessons || 0);
    const unitPrice = Number(refund.unit_price || 0);
    // 申请后可能又消课：实退课时以当前剩余为准，金额随实退课时自动调减
    const approvedLessons = Math.max(0, Math.min(requestedLessons, remainingLessons));
    if (approvedLessons <= 0) {
      throw new Error("该订单当前没有可退课时，请驳回该退款申请");
    }
    const approvedAmount = approvedLessons * unitPrice;

    // 线下资金模式：通过即代表工作室已线下退款给家长，必须登记退款方式；
    // 线上方式须上传打款凭证（现金可免图）。通过后进入「待家长确认」，此时不扣课时，
    // 需家长在 App 确认收到后才按实退课时扣减、订单转已退款。
    const refundMethod = String(payload.refund_method || "").trim();
    if (!PAY_METHODS.includes(refundMethod)) {
      throw new Error("请选择退款方式");
    }
    const refundVouchers = normalizeImages(payload.voucher_images);
    if (isOnlinePayMethod(refundMethod) && refundVouchers.length === 0) {
      throw new Error("线上退款请上传打款凭证");
    }

    await refund.update(
      {
        status: 1,
        approved_lessons: approvedLessons,
        amount: approvedAmount,
        refund_method: refundMethod,
        voucher_images: refundVouchers,
        reviewed_by: operator.adminId || null,
        reviewed_at: new Date(),
        reason: payload.reason || refund.reason
      },
      { transaction }
    );

    const latest = await Refund.findByPk(refund.refund_id, {
      include: [
        {
          model: Order,
          as: "order",
          required: true,
          where: { studio_id: studioId },
          include: [
            { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
            { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
            { model: User, as: "user", attributes: ["user_id", "nickname", "phone"] },
            { model: ChildCourseBalance, as: "balance", attributes: ["balance_id", "total_lessons", "consumed_lessons", "refunded_lessons", "remaining_lessons", "valid_from", "valid_to", "status"] }
          ]
        }
      ],
      transaction
    });

    // 通知家长：审核通过，进入打款
    const parent = refund.order?.user;
    if (parent?.user_id) {
      createNotification({
        userId: parent.user_id,
        type: "refund",
        title: "退款已退回，待你确认",
        content: (
          (approvedLessons < requestedLessons
            ? `你申请退${requestedLessons}节，期间已上课${requestedLessons - approvedLessons}节，本次实退${approvedLessons}节、¥${(approvedAmount / 100).toFixed(2)}，已线下退回。`
            : `「${refund.order.course?.title || "课程"}」退款 ¥${(approvedAmount / 100).toFixed(2)} 已审核通过并线下退回。`) +
          "请在订单中确认是否收到。"
        ).slice(0, 120),
        refType: "refund",
        refId: refund.refund_id
      }).catch(() => {});
    }

    return formatStudioRefund(latest);
  });
}

/**
 * 确认退款已打款：待打款（1）→ 已打款（3）。
 * 此时才扣减课时、累计订单退款、写入消课流水，并通知家长到账。
 */
async function confirmRefundPaid(studioId, refundId, operator = {}) {
  return sequelize.transaction(async (transaction) => {
    const refund = await Refund.findByPk(refundId, {
      include: [
        {
          model: Order,
          as: "order",
          required: true,
          where: {
            studio_id: studioId
          },
          include: [
            { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
            { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
            { model: User, as: "user", attributes: ["user_id", "nickname", "phone"] },
            { model: ChildCourseBalance, as: "balance", attributes: ["balance_id", "total_lessons", "consumed_lessons", "refunded_lessons", "remaining_lessons", "valid_from", "valid_to", "status"] }
          ]
        }
      ],
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!refund) {
      return null;
    }

    if (Number(refund.status) !== 1) {
      throw new Error("Refund not awaiting payout");
    }

    const order = await Order.findByPk(refund.order_id, {
      transaction,
      lock: transaction.LOCK.UPDATE
    });
    const balance = await ChildCourseBalance.findOne({
      where: { order_id: refund.order_id },
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!order || !balance) {
      throw new Error("Refund order balance not found");
    }

    const remainingLessons = Number(balance.remaining_lessons || 0);
    const requestedLessons = Number(refund.requested_lessons || 0);
    const remainingAfter = remainingLessons - requestedLessons;

    await refund.update(
      {
        status: 3,
        reviewed_by: operator.adminId || null,
        reviewed_at: new Date(),
        refunded_at: new Date(),
        reason: refund.reason
      },
      { transaction }
    );

    await order.update(
      {
        refunded_lessons: Number(order.refunded_lessons || 0) + requestedLessons,
        refund_amount: Number(order.refund_amount || 0) + Number(refund.amount || 0),
        status: 3 // 确认打款后订单进入已退款终态（与 web 状态体系一致：3=已退款）
      },
      { transaction }
    );

    await balance.update(
      {
        refunded_lessons: Number(balance.refunded_lessons || 0) + requestedLessons,
        remaining_lessons: remainingAfter,
        status: remainingAfter === 0 ? 2 : 1
      },
      { transaction }
    );

    await LessonLog.create(
      {
        log_id: generateId(),
        child_id: order.child_id,
        course_id: order.course_id,
        order_id: order.order_id,
        source: 4,
        type: 3,
        delta: -requestedLessons,
        balance_after: remainingAfter,
        note: "工作室确认退款打款，扣减剩余课时"
      },
      { transaction }
    );

    const latest = await Refund.findByPk(refund.refund_id, {
      include: [
        {
          model: Order,
          as: "order",
          required: true,
          where: { studio_id: studioId },
          include: [
            { model: Child, as: "child", attributes: ["child_id", "nickname", "birthday"] },
            { model: Course, as: "course", attributes: ["course_id", "title", "cover"] },
            { model: User, as: "user", attributes: ["user_id", "nickname", "phone"] },
            { model: ChildCourseBalance, as: "balance", attributes: ["balance_id", "total_lessons", "consumed_lessons", "refunded_lessons", "remaining_lessons", "valid_from", "valid_to", "status"] }
          ]
        }
      ],
      transaction
    });

    // 通知家长：退款已到账
    const parent = refund.order?.user;
    if (parent?.user_id) {
      createNotification({
        userId: parent.user_id,
        type: "refund",
        title: "退款已到账",
        content: `「${refund.order.course?.title || "课程"}」退款 ¥${(Number(refund.amount) / 100).toFixed(2)} 已打款到账。`
          .slice(0, 120),
        refType: "refund",
        refId: refund.refund_id
      }).catch(() => {});
    }

    return formatStudioRefund(latest);
  });
}


function normalizeImages(value) {
  if (!Array.isArray(value)) return [];
  return value.map((v) => String(v || "").trim()).filter(Boolean);
}

/**
 * 工作室「联系人库」：在本工作室下过订单（含待收款/历史）的孩子，供手动建单选择。
 * 全新孩子（无任何本工作室订单）选不到，须由家长在 App 自助报名。
 * 支持按孩子昵称 / 家长昵称 / 家长手机号搜索。
 */
async function listOrderContacts(studioId, query = {}) {
  const orders = await Order.findAll({
    where: { studio_id: studioId },
    attributes: ["child_id", "user_id", "created_at"],
    include: [
      { model: Child, as: "child", attributes: ["child_id", "nickname", "avatar", "birthday", "gender", "parent_user_id"] },
      { model: User, as: "user", attributes: ["user_id", "phone", "nickname", "avatar"] },
      { model: Course, as: "course", attributes: ["course_id", "title"] },
      {
        model: ChildCourseBalance,
        as: "balance",
        attributes: ["balance_id", "remaining_lessons", "status"]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  const map = new Map();
  for (const o of orders) {
    const c = o.child;
    if (!c) continue;
    const cid = String(c.child_id);
    if (!map.has(cid)) {
      map.set(cid, {
        child_id: cid,
        nickname: c.nickname,
        avatar: c.avatar || null,
        birthday: c.birthday,
        gender: c.gender,
        parent: o.user
          ? {
              user_id: String(o.user.user_id),
              phone: o.user.phone,
              nickname: o.user.nickname,
              avatar: o.user.avatar || null
            }
          : null,
        courses: [],
        total_remaining_lessons: 0
      });
    }
    const rec = map.get(cid);
    if (o.course && !rec.courses.some((x) => String(x.course_id) === String(o.course.course_id))) {
      rec.courses.push({ course_id: String(o.course.course_id), title: o.course.title });
    }
    if (o.balance) {
      rec.total_remaining_lessons += Number(o.balance.remaining_lessons || 0);
    }
  }

  let list = [...map.values()];
  const kw = String(query.q || "").trim();
  if (kw) {
    list = list.filter(
      (r) =>
        (r.nickname || "").includes(kw) ||
        (r.parent?.nickname || "").includes(kw) ||
        (r.parent?.phone || "").includes(kw)
    );
  }
  return { total: list.length, list };
}

/**
 * 工作室后台手动建单（老学员续费 / 线下现金报名）。
 * payload: { child_id, course_id, class_id?, total_amount(分), remark?,
 *            confirm?:1 当场确认收款, pay_method?, voucher_images?, note? }
 * 当场确认时：现金可免凭证直接发课时；线上转账必须有凭证。
 */
async function createStudioOrder(studioId, payload, operator = {}) {
  return sequelize.transaction(async (transaction) => {
    const child = await Child.findByPk(payload.child_id, { transaction });
    if (!child) {
      throw new Error("孩子不存在");
    }
    // 孩子必须已在本工作室联系人库（有历史订单）
    const contactOrder = await Order.findOne({
      where: { studio_id: studioId, child_id: child.child_id },
      transaction
    });
    if (!contactOrder) {
      throw new Error("该孩子不在本工作室联系人库，新学员请由家长在 App 自助报名");
    }

    const course = await Course.findByPk(payload.course_id, { transaction });
    if (!course || String(course.studio_id) !== String(studioId)) {
      throw new Error("课程不存在或不属于本工作室");
    }
    if (Number(course.status) !== 1) {
      throw new Error("课程未上架，无法建单");
    }

    let classId = null;
    if (payload.class_id) {
      const cls = await Class.findByPk(payload.class_id, { transaction });
      if (!cls || String(cls.course_id) !== String(course.course_id)) {
        throw new Error("班级不属于该课程");
      }
      if (Number(cls.enrolled) >= Number(cls.capacity)) {
        throw new Error("班级已满员");
      }
      classId = String(cls.class_id);
    }

    const existingBalance = await ChildCourseBalance.findOne({
      where: { child_id: child.child_id, course_id: course.course_id, status: { [Op.in]: [1, 2] } },
      transaction
    });
    if (existingBalance) {
      throw new Error("该孩子已报名此课程，请勿重复建单");
    }
    const pending = await Order.findOne({
      where: { studio_id: studioId, child_id: child.child_id, course_id: course.course_id, status: 0 },
      transaction
    });
    if (pending) {
      throw new Error("该孩子已有此课程的待收款订单");
    }

    const amount = Math.round(Number(payload.total_amount));
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new Error("请填写正确的收款金额");
    }
    const parentUserId = child.parent_user_id || contactOrder.user_id;

    const order = await Order.create(
      {
        order_id: generateId(),
        order_no: `TG${generateId()}`,
        user_id: parentUserId,
        child_id: child.child_id,
        studio_id: studioId,
        course_id: course.course_id,
        class_id: classId,
        package_id: null,
        total_lessons: course.total_lessons,
        total_amount: amount,
        remark: payload.remark ? String(payload.remark).slice(0, 255) : null,
        distribution_link_id: null,
        source: 1,
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
        package_id: null,
        course_title: course.title,
        package_name: null,
        lessons: course.total_lessons,
        quantity: 1,
        unit_price: amount,
        total_price: amount
      },
      { transaction }
    );

    // 当场确认收款（线下现金/已转账）：现金免凭证，线上必传凭证，确认后立即发课时
    if (Number(payload.confirm) === 1 || Number(payload.status) === 1) {
      const method = payload.pay_method || "cash";
      if (!PAY_METHODS.includes(method)) {
        throw new Error("支付方式不正确");
      }
      const images = normalizeImages(payload.voucher_images);
      if (isOnlinePayMethod(method) && images.length === 0) {
        throw new Error("线上转账请上传付款凭证；现金可直接登记");
      }
      await Payment.create(
        {
          payment_id: generateId(),
          order_id: order.order_id,
          payment_no: `PM${generateId()}`,
          channel: method,
          pay_method: method,
          amount: amount,
          voucher_images: images,
          payer_note: payload.note ? String(payload.note).slice(0, 255) : null,
          upload_by: 1,
          status: 1,
          paid_at: new Date(),
          confirm_by: operator.adminId || null
        },
        { transaction }
      );
      const locked = await Order.findByPk(order.order_id, { transaction, lock: transaction.LOCK.UPDATE });
      await grantOrderLessons(locked, {
        transaction,
        payMethod: method,
        operatorId: operator.adminId || null
      });
    }

    const detail = await getOrderWithDetails(order.order_id, { transaction });
    return formatOrder(detail);
  });
}

/**
 * 工作室确认收款：确认家长上传的凭证，或工作室直接登记收款（现金/线下）。
 * 线上转账必须存在凭证（家长已传或本次代传）；确认全款后发课时。
 */
async function confirmStudioPayment(studioId, orderId, payload, operator = {}) {
  return sequelize.transaction(async (transaction) => {
    const order = await Order.findOne({
      where: { order_id: orderId, studio_id: studioId },
      include: [{ model: Course, as: "course", attributes: ["course_id", "title", "validity_days"] }],
      transaction,
      lock: transaction.LOCK.UPDATE
    });
    if (!order) {
      return null;
    }
    if (Number(order.status) !== 0) {
      throw new Error("订单不是待收款状态");
    }

    const method = payload.pay_method;
    if (!PAY_METHODS.includes(method)) {
      throw new Error("请选择支付方式");
    }
    const images = normalizeImages(payload.voucher_images);

    const prior = await Payment.findOne({
      where: { order_id: orderId, status: 0 },
      transaction,
      order: [["created_at", "DESC"]]
    });
    const priorImages = prior && Array.isArray(prior.voucher_images) ? prior.voucher_images : [];
    if (isOnlinePayMethod(method) && images.length === 0 && priorImages.length === 0) {
      throw new Error("线上转账须有付款凭证（家长上传或工作室代传）；现金可直接登记");
    }

    const finalImages = images.length ? images : priorImages;
    const pending = await Payment.findOne({
      where: { order_id: orderId, status: { [Op.in]: [0, 2] } },
      transaction,
      order: [["created_at", "DESC"]]
    });

    if (pending) {
      await pending.update(
        {
          channel: method,
          pay_method: method,
          amount: order.total_amount,
          voucher_images: finalImages,
          payer_note: pending.payer_note || (payload.note ? String(payload.note).slice(0, 255) : null),
          upload_by: pending.upload_by ?? 0,
          status: 1,
          paid_at: new Date(),
          confirm_by: operator.adminId || null,
          reject_reason: null
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
          voucher_images: finalImages,
          payer_note: payload.note ? String(payload.note).slice(0, 255) : null,
          upload_by: 1,
          status: 1,
          paid_at: new Date(),
          confirm_by: operator.adminId || null
        },
        { transaction }
      );
    }

    await grantOrderLessons(order, { transaction, payMethod: method, operatorId: operator.adminId || null });
    return formatOrder(await getOrderWithDetails(orderId, { transaction }));
  });
}

/** 工作室驳回家长上传的付款凭证：订单仍保持待收款，通知家长重新处理 */
async function rejectStudioPayment(studioId, orderId, payload, operator = {}) {
  return sequelize.transaction(async (transaction) => {
    const order = await Order.findOne({
      where: { order_id: orderId, studio_id: studioId },
      include: [
        { model: Course, as: "course", attributes: ["course_id", "title"] },
        { model: User, as: "user", attributes: ["user_id"] }
      ],
      transaction,
      lock: transaction.LOCK.UPDATE
    });
    if (!order) {
      return null;
    }
    if (Number(order.status) !== 0) {
      throw new Error("订单不是待收款状态");
    }
    const payment = await Payment.findOne({
      where: { order_id: orderId, status: 0 },
      transaction,
      order: [["created_at", "DESC"]]
    });
    if (!payment) {
      throw new Error("没有待审核的付款凭证");
    }
    const reason = payload.reason ? String(payload.reason).slice(0, 255) : "凭证无效，请重新上传";
    await payment.update(
      { status: 2, reject_reason: reason, confirm_by: operator.adminId || null },
      { transaction }
    );
    if (order.user?.user_id) {
      createNotification({
        userId: order.user.user_id,
        type: "order",
        title: "付款凭证未通过核对",
        content: `「${order.course?.title || "课程"}」的付款凭证未通过核对：${reason}，请重新付款或上传凭证。`.slice(0, 120),
        refType: "order",
        refId: orderId
      }).catch(() => {});
    }
    return formatOrder(await getOrderWithDetails(orderId, { transaction }));
  });
}

/** 工作室手动取消待收款订单（0 -> 2） */
async function cancelStudioOrder(studioId, orderId) {
  return sequelize.transaction(async (transaction) => {
    const order = await Order.findOne({
      where: { order_id: orderId, studio_id: studioId },
      transaction,
      lock: transaction.LOCK.UPDATE
    });
    if (!order) {
      return null;
    }
    if (Number(order.status) !== 0) {
      throw new Error("仅待收款订单可取消");
    }
    await order.update({ status: 2, completed_at: new Date() }, { transaction });
    return formatOrder(await getOrderWithDetails(orderId, { transaction }));
  });
}

module.exports = {
  listStudioOrders,
  getStudioOrderDetail,
  listStudioRefunds,
  reviewStudioRefund,
  confirmRefundPaid,
  listOrderContacts,
  createStudioOrder,
  confirmStudioPayment,
  rejectStudioPayment,
  cancelStudioOrder
};

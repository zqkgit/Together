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
  LessonLog
} = require("../models");
const { formatOrder, getOrderWithDetails } = require("./orderService");
const { createNotification } = require("./messageService");
const { generateId } = require("../utils/id");

function formatStudioRefund(refund) {
  return {
    refund_id: String(refund.refund_id),
    order_id: String(refund.order_id),
    user_id: String(refund.user_id),
    requested_lessons: refund.requested_lessons,
    refundable_lessons: refund.refundable_lessons,
    unit_price: refund.unit_price,
    amount: refund.amount,
    reason: refund.reason,
    status: refund.status,
    reviewed_by: refund.reviewed_by ? String(refund.reviewed_by) : null,
    reviewed_at: refund.reviewed_at,
    refunded_at: refund.refunded_at,
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
    if (requestedLessons > remainingLessons) {
      throw new Error("Refund lessons exceed current remaining lessons");
    }

    await refund.update(
      {
        status: 1,
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
        title: "退款审核已通过",
        content: `「${refund.order.course?.title || "课程"}」退款 ¥${(Number(refund.amount) / 100).toFixed(2)} 已通过审核，正在打款处理中。`
          .slice(0, 120),
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

module.exports = {
  listStudioOrders,
  getStudioOrderDetail,
  listStudioRefunds,
  reviewStudioRefund,
  confirmRefundPaid
};

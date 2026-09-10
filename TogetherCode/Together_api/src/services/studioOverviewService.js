const { Op } = require("sequelize");
const dayjs = require("dayjs");
const {
  sequelize,
  Order,
  Course,
  Class: ClassModel,
  Child,
  ChildCourseBalance,
  Refund,
  LeaveRequest
} = require("../models");
const { formatFen } = require("../utils/amount");

// 订单状态：0 待支付 / 1 支付成功 / 3 已退款（与 seeder、orderService 一致）
const PAID_STATUS = { [Op.ne]: 0 };

/**
 * 工作室经营概览：核心统计 + 近 30 天 GMV 趋势 + 待办（退款审核 / 请假审批）
 */
async function getStudioOverview(studioId) {
  const now = dayjs();
  const monthStart = now.startOf("month").toDate();
  const monthEnd = now.endOf("month").toDate();
  const daysAgo30 = now.subtract(29, "day").startOf("day").toDate();

  const [
    orderMonthCount,
    monthGmv,
    orderTotal,
    gmvTotal,
    activeStudentCount,
    courseTotal,
    courseOnline,
    classTotal,
    pendingRefundCount,
    pendingLeaveCount,
    trendRows,
    pendingRefunds,
    pendingLeaves
  ] = await Promise.all([
    Order.count({
      where: { studio_id: studioId, status: PAID_STATUS, paid_at: { [Op.between]: [monthStart, monthEnd] } }
    }),
    Order.sum("paid_amount", {
      where: { studio_id: studioId, status: PAID_STATUS, paid_at: { [Op.between]: [monthStart, monthEnd] } }
    }),
    Order.count({ where: { studio_id: studioId, status: PAID_STATUS } }),
    Order.sum("paid_amount", { where: { studio_id: studioId, status: PAID_STATUS } }),
    // 在学学员：该工作室订单对应、仍有剩余课时的学员数
    ChildCourseBalance.count({
      distinct: true,
      col: "child_id",
      where: { remaining_lessons: { [Op.gt]: 0 } },
      include: [{ model: Order, as: "order", where: { studio_id: studioId }, required: true }]
    }),
    Course.count({ where: { studio_id: studioId } }),
    Course.count({ where: { studio_id: studioId, status: 1 } }),
    // 班级：通过课程归属工作室
    ClassModel.count({
      include: [{ model: Course, as: "course", where: { studio_id: studioId }, required: true }]
    }),
    Refund.count({
      where: { status: 0 },
      include: [{ model: Order, as: "order", where: { studio_id: studioId }, required: true }]
    }),
    LeaveRequest.count({
      where: { status: 0 },
      include: [
        {
          model: ClassModel,
          as: "classItem",
          required: true,
          include: [{ model: Course, as: "course", where: { studio_id: studioId }, required: true }]
        }
      ]
    }),
    Order.findAll({
      attributes: [
        [sequelize.fn("DATE", sequelize.col("paid_at")), "date"],
        [sequelize.fn("SUM", sequelize.col("paid_amount")), "gmv"]
      ],
      where: { studio_id: studioId, status: PAID_STATUS, paid_at: { [Op.gte]: daysAgo30 } },
      group: [sequelize.fn("DATE", sequelize.col("paid_at"))],
      order: [[sequelize.fn("DATE", sequelize.col("paid_at")), "ASC"]],
      raw: true
    }),
    Refund.findAll({
      where: { status: 0 },
      include: [
        {
          model: Order,
          as: "order",
          required: true,
          where: { studio_id: studioId },
          include: [
            { model: Child, as: "child" },
            { model: Course, as: "course" }
          ]
        }
      ],
      order: [["created_at", "DESC"]],
      limit: 5,
      raw: true,
      nest: true
    }),
    LeaveRequest.findAll({
      where: { status: 0 },
      include: [
        {
          model: ClassModel,
          as: "classItem",
          required: true,
          include: [{ model: Course, as: "course", where: { studio_id: studioId }, required: true }]
        },
        { model: Child, as: "child" }
      ],
      order: [["created_at", "DESC"]],
      limit: 5,
      raw: true,
      nest: true
    })
  ]);

  // 近 30 天 GMV 趋势（补全无订单日期为 0）
  const trendMap = {};
  (trendRows || []).forEach((row) => {
    trendMap[row.date] = Number(row.gmv || 0);
  });
  const trend30d = [];
  for (let i = 29; i >= 0; i -= 1) {
    const key = now.subtract(i, "day").format("YYYY-MM-DD");
    trend30d.push({ date: key, gmv: trendMap[key] || 0 });
  }

  const refundTodos = (pendingRefunds || []).map((item) => ({
    refund_id: String(item.refund_id),
    child_nickname: item.order?.child?.nickname || "-",
    course_title: item.order?.course?.title || "-",
    amount: Number(item.amount || 0),
    created_at: item.created_at
  }));
  const leaveTodos = (pendingLeaves || []).map((item) => ({
    leave_id: String(item.leave_id),
    child_nickname: item.child?.nickname || "-",
    class_name: item.classItem?.name || "-",
    lesson_date: item.classItem?.schedule_rule?.time || null,
    created_at: item.created_at
  }));

  return {
    statCards: [
      { label: "本月 GMV", value: formatFen(monthGmv || 0), trend: `${orderMonthCount} 笔支付订单` },
      { label: "在学学员", value: String(activeStudentCount), trend: "剩余课时 > 0" },
      { label: "在售课程", value: String(courseOnline), trend: `共 ${courseTotal} 门课程` },
      {
        label: "待办事项",
        value: String((pendingRefundCount || 0) + (pendingLeaveCount || 0)),
        trend: `退款 ${pendingRefundCount || 0} · 请假 ${pendingLeaveCount || 0}`
      }
    ],
    summary: {
      order_total: orderTotal || 0,
      gmv_total: gmvTotal || 0,
      gmv_total_text: formatFen(gmvTotal || 0),
      order_month: orderMonthCount,
      gmv_month: monthGmv || 0,
      gmv_month_text: formatFen(monthGmv || 0),
      student_active: activeStudentCount,
      course_total: courseTotal,
      course_online: courseOnline,
      class_total: classTotal
    },
    trend30d,
    todos: {
      refunds: refundTodos,
      leaves: leaveTodos
    }
  };
}

module.exports = {
  getStudioOverview
};

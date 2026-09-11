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

/**
 * 数据报表（GET /studio/reports）：
 * 营收（本月/累计 GMV、退款）、课时（售出/已消/剩余）、学员（总数/在学/本月新增）、经营（课程/班级/老师）。
 */
async function getStudioReports(studioId) {
  const now = dayjs();
  const monthStart = now.startOf("month").toDate();
  const monthEnd = now.endOf("month").toDate();
  const monthAgo = now.subtract(1, "month").toDate();

  const [monthGmv, gmvTotal, monthRefund, refundTotal, lessonSold, lessonConsumed, studentTotal, activeStudents, monthNewStudents, courseTotal, classTotal, teacherCount, refundRows] =
    await Promise.all([
      // 本月实收
      Order.sum("paid_amount", {
        where: { studio_id: studioId, status: PAID_STATUS, paid_at: { [Op.between]: [monthStart, monthEnd] } }
      }),
      // 累计实收
      Order.sum("paid_amount", { where: { studio_id: studioId, status: PAID_STATUS } }),
      // 本月退款（原始 SQL：sum+include 会被 Sequelize 带出非聚合列，only_full_group_by 下报错）
      sequelize.query(
        `SELECT COALESCE(SUM(r.amount),0) AS total FROM refunds r JOIN orders o ON o.order_id = r.order_id
         WHERE o.studio_id = ? AND r.status IN (2,3) AND r.reviewed_at BETWEEN ? AND ?`,
        { replacements: [studioId, monthStart, monthEnd], type: sequelize.QueryTypes.SELECT }
      ),
      // 累计退款
      sequelize.query(
        `SELECT COALESCE(SUM(r.amount),0) AS total FROM refunds r JOIN orders o ON o.order_id = r.order_id
         WHERE o.studio_id = ? AND r.status IN (2,3)`,
        { replacements: [studioId], type: sequelize.QueryTypes.SELECT }
      ),
      // 总售出课时
      Order.sum("total_lessons", { where: { studio_id: studioId, status: PAID_STATUS } }),
      // 已消课时（统一账本 lesson_logs 汇总）
      sequelize.query(
        `SELECT COALESCE(SUM(ABS(delta)),0) AS total FROM lesson_logs WHERE order_id IN
         (SELECT order_id FROM orders WHERE studio_id = ? AND status <> 0) AND type IN (2,3,4)`,
        { replacements: [studioId], type: sequelize.QueryTypes.SELECT }
      ),
      // 学员总数（去重）
      Order.count({ distinct: true, col: "child_id", where: { studio_id: studioId, status: PAID_STATUS } }),
      // 在学学员（剩余课时 > 0）
      ChildCourseBalance.count({
        distinct: true,
        col: "child_id",
        where: { remaining_lessons: { [Op.gt]: 0 } },
        include: [{ model: Order, as: "order", where: { studio_id: studioId }, required: true }]
      }),
      // 本月新增学员
      Order.count({
        distinct: true,
        col: "child_id",
        where: { studio_id: studioId, status: PAID_STATUS, paid_at: { [Op.between]: [monthStart, monthEnd] } }
      }),
      Course.count({ where: { studio_id: studioId } }),
      ClassModel.count({
        include: [{ model: Course, as: "course", where: { studio_id: studioId }, required: true }]
      }),
      // 在职老师
      sequelize.query(
        `SELECT COUNT(*) AS total FROM teacher_studio_bindings WHERE studio_id = ? AND status = 1`,
        { replacements: [studioId], type: sequelize.QueryTypes.SELECT }
      ),
      // 近期退款流水
      Refund.findAll({
        where: { status: { [Op.in]: [2, 3] } },
        include: [
          { model: Order, as: "order", where: { studio_id: studioId }, required: true, attributes: ["order_id", "order_no"] }
        ],
        order: [["reviewed_at", "DESC"]],
        limit: 10
      })
    ]);

  const consumedTotal = Number(lessonConsumed?.[0]?.total || 0);
  const teacherTotal = Number(teacherCount?.[0]?.total || 0);
  const monthRefundTotal = Number(monthRefund?.[0]?.total || 0);
  const refundTotalAmount = Number(refundTotal?.[0]?.total || 0);

  return {
    data: {
      revenue: {
        month_gmv: Number(monthGmv || 0),
        total_gmv: Number(gmvTotal || 0),
        month_refund: monthRefundTotal,
        total_refund: refundTotalAmount,
        net_total: Number((Number(gmvTotal || 0) - refundTotalAmount).toFixed(2))
      },
      lessons: {
        sold: Number(lessonSold || 0),
        consumed: consumedTotal,
        remaining: Math.max(Number(lessonSold || 0) - consumedTotal, 0)
      },
      students: {
        total: studentTotal,
        active: activeStudents,
        month_new: monthNewStudents
      },
      operations: {
        courses: courseTotal,
        classes: classTotal,
        teachers: teacherTotal
      },
      recent_refunds: refundRows.map((item) => ({
        refund_id: String(item.refund_id),
        amount: Number(item.amount),
        status: item.status,
        reviewed_at: item.reviewed_at
      }))
    }
  };
}

module.exports = {
  getStudioOverview,
  getStudioReports
};

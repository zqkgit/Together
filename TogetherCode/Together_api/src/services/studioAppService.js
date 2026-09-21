const { Op } = require("sequelize");
const dayjs = require("dayjs");
const {
  sequelize,
  StudioProfile,
  TeacherStudioBinding,
  Course,
  ChildCourseBalance,
  Order,
  Refund,
  Settlement,
  Wallet,
  User
} = require("../models");

// 订单状态：0 待支付 / 1 支付成功 / 3 已退款
const PAID_STATUS = { [Op.ne]: 0 };

/**
 * 工作室 App 端「我的」：机构资料 + 经营统计
 * 与 Web 端 /studio/profile、/studio/overview 同源（studio_profiles.user_id ↔ 登录用户）
 */
async function getStudioMine(userId) {
  const studio = await StudioProfile.findOne({
    where: { user_id: userId },
    include: [
      {
        model: User,
        as: "owner",
        attributes: ["user_id", "phone", "nickname", "avatar", "city"]
      }
    ]
  });

  if (!studio) {
    return null;
  }

  const studioId = studio.studio_id;

  const [activeStudents, onlineCourses, courseTotal, teachers, pendingRefunds] = await Promise.all([
    // 在读学员：该工作室订单对应、仍有剩余课时的去重学员数（与经营概览口径一致）
    ChildCourseBalance.count({
      distinct: true,
      col: "child_id",
      where: { remaining_lessons: { [Op.gt]: 0 } },
      include: [{ model: Order, as: "order", where: { studio_id: studioId }, required: true }]
    }),
    // 在售课程
    Course.count({ where: { studio_id: studioId, status: 1 } }),
    Course.count({ where: { studio_id: studioId } }),
    // 入驻教师：在职绑定
    TeacherStudioBinding.count({ where: { studio_id: studioId, status: 1 } }),
    // 待处理退款
    Refund.count({
      where: { status: 0 },
      include: [{ model: Order, as: "order", where: { studio_id: studioId }, required: true }]
    })
  ]);

  const createdAt = studio.created_at ? new Date(studio.created_at) : null;
  let years = 0;
  let months = 0;
  if (createdAt && !Number.isNaN(createdAt.getTime())) {
    const now = new Date();
    let monthDiff =
      (now.getFullYear() - createdAt.getFullYear()) * 12 + (now.getMonth() - createdAt.getMonth());
    if (now.getDate() < createdAt.getDate()) {
      monthDiff -= 1;
    }
    monthDiff = Math.max(0, monthDiff);
    years = Math.floor(monthDiff / 12);
    months = monthDiff % 12;
  }

  const typeTags = Array.isArray(studio.type_tags) ? studio.type_tags : [];

  return {
    profile: {
      studio_id: String(studio.studio_id),
      user_id: String(studio.user_id),
      name: studio.name || "未命名工作室",
      cover: studio.cover || null,
      avatar: studio.owner?.avatar || null,
      intro: studio.intro || "",
      city: studio.city || "",
      address: studio.address || "",
      business_type: studio.business_type || "",
      type_tags: typeTags,
      phone: studio.phone || studio.owner?.phone || "",
      hours: studio.hours || "",
      // 工作室状态 1 = 正常运营（入驻审核通过即视为平台认证机构）
      cert_status: Number(studio.status) === 1 ? 1 : 0,
      status: Number(studio.status || 0),
      joined_at: studio.created_at || null,
      years,
      months
    },
    stats: {
      active_students: activeStudents,
      online_courses: onlineCourses,
      course_total: courseTotal,
      teachers,
      pending_refunds: pendingRefunds
    }
  };
}

/**
 * 工作室 App 端「经营概览」：营收卡 + 三项统计 + 待办 + 机构动态
 *
 * 金额口径（统一返回「分」，由端上格式化）：
 *  - month_income  本月营收   = 本月已支付订单 paid_amount 合计
 *  - withdrawable  可提现     = 主理人钱包可用余额（wallets.balance，库中为元）
 *  - distribution  分销返利   = 本月 commission_records 合计（库中为元）
 *  - settling      结算中     = status=0（平台待打款）结算单 payable_amount 合计
 */
async function getStudioOverviewForApp(userId) {
  const studio = await StudioProfile.findOne({ where: { user_id: userId } });
  if (!studio) {
    return null;
  }
  const studioId = studio.studio_id;

  const now = dayjs();
  const monthStart = now.startOf("month").toDate();
  const monthEnd = now.endOf("month").toDate();
  const todayStart = now.startOf("day").toDate();
  // 周一为一周开始（中国习惯）
  const weekStart = now.subtract((now.day() + 6) % 7, "day").startOf("day").toDate();

  const [
    monthIncome,
    wallet,
    monthDistributionRow,
    settlingRow,
    activeStudents,
    onlineCourses,
    teachers,
    pendingRefunds,
    lastSettlement,
    todayEnrolled,
    weekEnrolled,
    weekIncome,
    weekDistributionRow,
    latestCourse
  ] = await Promise.all([
    // 本月营收
    Order.sum("paid_amount", { where: { studio_id: studioId, status: PAID_STATUS, paid_at: { [Op.between]: [monthStart, monthEnd] } } }),
    // 可提现（主理人钱包）
    Wallet.findByPk(userId),
    // 本月分销返利（单位元 → 稍后 ×100 转分）
    sequelize.query(
      `SELECT COALESCE(SUM(c.amount),0) AS total FROM commission_records c
         JOIN distribution_links l ON l.link_id = c.link_id
         JOIN courses cu ON cu.course_id = l.course_id
         WHERE cu.studio_id = ? AND c.created_at BETWEEN ? AND ?`,
      { replacements: [studioId, monthStart, monthEnd], type: sequelize.QueryTypes.SELECT }
    ),
    // 结算中：平台待打款的结算单
    Settlement.findAll({
      attributes: [[sequelize.fn("COALESCE", sequelize.fn("SUM", sequelize.col("payable_amount")), 0), "total"]],
      where: { studio_id: studioId, status: 0 },
      raw: true
    }),
    // 在读学员：仍有剩余课时的去重学员（与「我的」页同口径）
    ChildCourseBalance.count({
      distinct: true,
      col: "child_id",
      where: { remaining_lessons: { [Op.gt]: 0 } },
      include: [{ model: Order, as: "order", where: { studio_id: studioId }, required: true }]
    }),
    Course.count({ where: { studio_id: studioId, status: 1 } }),
    TeacherStudioBinding.count({ where: { studio_id: studioId, status: 1 } }),
    Refund.count({
      where: { status: 0 },
      include: [{ model: Order, as: "order", where: { studio_id: studioId }, required: true }]
    }),
    // 最近一张结算单（用于界定「已结算到哪个周期」）
    Settlement.findOne({
      where: { studio_id: studioId, status: { [Op.ne]: 2 } },
      order: [["period_end", "DESC"]]
    }),
    // 今日招生（去重学员）
    Order.count({
      distinct: true,
      col: "child_id",
      where: { studio_id: studioId, status: PAID_STATUS, paid_at: { [Op.gte]: todayStart } }
    }),
    Order.count({
      distinct: true,
      col: "child_id",
      where: { studio_id: studioId, status: PAID_STATUS, paid_at: { [Op.gte]: weekStart } }
    }),
    Order.sum("paid_amount", { where: { studio_id: studioId, status: PAID_STATUS, paid_at: { [Op.gte]: weekStart } } }),
    sequelize.query(
      `SELECT COALESCE(SUM(c.amount),0) AS total FROM commission_records c
         JOIN distribution_links l ON l.link_id = c.link_id
         JOIN courses cu ON cu.course_id = l.course_id
         WHERE cu.studio_id = ? AND c.created_at >= ?`,
      { replacements: [studioId, weekStart], type: sequelize.QueryTypes.SELECT }
    ),
    // 最近上架的课程（用于机构动态播报文案）
    Course.findOne({
      where: { studio_id: studioId, status: 1 },
      order: [["created_at", "DESC"]]
    })
  ]);

  const monthDistribution = Math.round(Number(monthDistributionRow?.[0]?.total || 0) * 100);
  const weekDistribution = Math.round(Number(weekDistributionRow?.[0]?.total || 0) * 100);
  const settling = Number(settlingRow?.[0]?.total || 0);
  const withdrawable = Math.round(Number(wallet?.balance || 0) * 100);
  const weekIncomeValue = Number(weekIncome || 0);

  // 待结算订单 = 已支付未退款、且款项尚未打款到工作室的订单：
  // 优先取「待打款（status=0）」结算单覆盖周期内的订单；无待打款单时退化为最近周期之后的新单。
  const pendingSettlement = await Settlement.findOne({
    where: { studio_id: studioId, status: 0 },
    order: [["period_end", "DESC"]]
  });
  let settleWhere = { studio_id: studioId, status: 1 };
  if (pendingSettlement) {
    settleWhere = {
      ...settleWhere,
      paid_at: {
        [Op.between]: [
          new Date(`${pendingSettlement.period_start}T00:00:00`),
          new Date(`${pendingSettlement.period_end}T23:59:59`)
        ]
      }
    };
  } else if (lastSettlement?.period_end) {
    settleWhere = {
      ...settleWhere,
      paid_at: { [Op.gt]: new Date(`${lastSettlement.period_end}T23:59:59`) }
    };
  }
  const [pendingSettleOrders, pendingSettleAmount] = await Promise.all([
    Order.count({ where: settleWhere }),
    Order.sum("paid_amount", { where: settleWhere })
  ]);

  // 机构动态播报：优先「新课上线」口径，其次本周新增报名；均附分销员贡献占比
  const distributionRatio = weekIncomeValue > 0 ? Math.round((weekDistribution / weekIncomeValue) * 100) : 0;
  let headline = `本周新增报名 ${weekEnrolled} 人，分销员贡献占比 ${distributionRatio}%。`;
  if (latestCourse?.created_at) {
    const onlineDays = Math.max(dayjs().diff(dayjs(latestCourse.created_at), "day"), 1);
    if (onlineDays <= 7) {
      headline = `本周《${latestCourse.title}》新课上线 ${onlineDays} 天，累计报名 ${Number(latestCourse.sales || 0)} 人，分销员贡献占比 ${distributionRatio}%。`;
    }
  }

  return {
    revenue: {
      month_income: Number(monthIncome || 0),
      withdrawable,
      distribution: monthDistribution,
      settling
    },
    stats: {
      active_students: activeStudents,
      online_courses: onlineCourses,
      teachers
    },
    todos: {
      pending_refunds: pendingRefunds,
      pending_settle_orders: pendingSettleOrders,
      pending_settle_amount: Number(pendingSettleAmount || 0)
    },
    dynamic: {
      studio_name: studio.name || "我的工作室",
      today_enrolled: todayEnrolled,
      weekly_enrolled: weekEnrolled,
      weekly_income: weekIncomeValue,
      distribution_ratio: distributionRatio,
      headline
    }
  };
}

module.exports = {
  getStudioMine,
  getStudioOverviewForApp
};

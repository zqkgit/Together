const { Op } = require("sequelize");
const dayjs = require("dayjs");
const {
  sequelize,
  StudioProfile,
  StudioApplication,
  Settlement,
  User,
  UserRole,
  Order,
  Course,
  Child,
  ChildCourseBalance
} = require("../models");
const { generateId } = require("../utils/id");
const { formatFen } = require("../utils/amount");

// 订单状态：0 待支付 / 1 支付成功 / 3 已退款（与 seeder、orderService 一致）
const PAID_STATUS = { [Op.ne]: 0 };

function normalizePage(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(100, Math.max(1, Number(query.size) || 20));
  return { page, size, offset: (page - 1) * size };
}

// ============ 平台看板（P2） ============

async function getDashboardOverview() {
  const now = dayjs();
  const monthStart = now.startOf("month").toDate();
  const monthEnd = now.endOf("month").toDate();
  const daysAgo30 = now.subtract(29, "day").startOf("day").toDate();

  const [
    studioPending,
    studioTotal,
    studioNewMonth,
    childTotal,
    activeStudentCount,
    courseTotal,
    orderMonthCount,
    monthGmv,
    settlementRows,
    trendRows
  ] = await Promise.all([
    StudioApplication.count({ where: { status: 0 } }),
    StudioProfile.count(),
    StudioProfile.count({ where: { created_at: { [Op.between]: [monthStart, monthEnd] } } }),
    Child.count(),
    ChildCourseBalance.count({
      distinct: true,
      col: "child_id",
      where: { remaining_lessons: { [Op.gt]: 0 } }
    }),
    Course.count({ where: { status: 1 } }),
    Order.count({
      where: { status: PAID_STATUS, paid_at: { [Op.between]: [monthStart, monthEnd] } }
    }),
    Order.sum("paid_amount", {
      where: { status: PAID_STATUS, paid_at: { [Op.between]: [monthStart, monthEnd] } }
    }),
    Settlement.findAll(),
    Order.findAll({
      attributes: [
        [sequelize.fn("DATE", sequelize.col("paid_at")), "date"],
        [sequelize.fn("SUM", sequelize.col("paid_amount")), "gmv"]
      ],
      where: { status: PAID_STATUS, paid_at: { [Op.gte]: daysAgo30 } },
      group: [sequelize.fn("DATE", sequelize.col("paid_at"))],
      order: [[sequelize.fn("DATE", sequelize.col("paid_at")), "ASC"]],
      raw: true
    })
  ]);

  const totalPendingPayable = settlementRows
    .filter((item) => Number(item.status) !== 2)
    .reduce((sum, item) => sum + Number(item.payable_amount || 0), 0);
  const abnormalCount = settlementRows.filter((item) => Number(item.status) === 3).length;
  const pendingPayoutCount = settlementRows.filter((item) => Number(item.status) === 0).length;

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

  return {
    statCards: [
      { label: "本月 GMV", value: formatFen(monthGmv || 0), trend: `${orderMonthCount} 笔支付订单` },
      { label: "待审核工作室", value: String(studioPending), trend: "实时" },
      { label: "异常结算单", value: String(abnormalCount), trend: "需复核" },
      { label: "待结算金额", value: formatFen(totalPendingPayable), trend: `${pendingPayoutCount} 张待打款` }
    ],
    summary: {
      studio_total: studioTotal,
      studio_new_month: studioNewMonth,
      student_total: childTotal,
      student_active: activeStudentCount,
      course_total: courseTotal,
      order_month: orderMonthCount,
      gmv_month: monthGmv || 0,
      gmv_month_text: formatFen(monthGmv || 0)
    },
    trend30d,
    todos: [
      { label: "待审核工作室", count: studioPending },
      { label: "待打款结算单", count: pendingPayoutCount },
      { label: "异常结算单", count: abnormalCount }
    ]
  };
}

// ============ 工作室列表（P1） ============

async function getStudios(query = {}) {
  const { page, size, offset } = normalizePage(query);
  const keyword = String(query.keyword || "").trim();

  const where = {};
  if (keyword) {
    where[Op.or] = [
      { name: { [Op.like]: `%${keyword}%` } },
      { address: { [Op.like]: `%${keyword}%` } }
    ];
  }

  const [courseRows, { rows, count }] = await Promise.all([
    Course.findAll({
      attributes: ["studio_id", [sequelize.fn("COUNT", sequelize.col("course_id")), "cnt"]],
      group: ["studio_id"],
      raw: true
    }),
    StudioProfile.findAndCountAll({
      where,
      include: [
        {
          model: User,
          as: "owner",
          attributes: ["user_id", "phone", "nickname"]
        }
      ],
      order: [["created_at", "DESC"]],
      limit: size,
      offset
    })
  ]);

  const courseMap = {};
  (courseRows || []).forEach((row) => {
    courseMap[String(row.studio_id)] = Number(row.cnt || 0);
  });

  const statusText = (code) => {
    const n = Number(code);
    if (n === 1) return "营业中";
    if (n === 2) return "已封禁";
    return "待审核";
  };

  return {
    total: count,
    page,
    size,
    list: rows.map((item) => ({
      id: String(item.studio_id),
      name: item.name,
      city: item.address || "-",
      status: statusText(item.status),
      status_code: Number(item.status),
      owner: item.owner?.nickname || "-",
      owner_phone: item.owner?.phone || "-",
      courses: courseMap[String(item.studio_id)] || 0,
      created_at: item.created_at
    }))
  };
}

async function getStudioDetail(studioId, transaction = null) {
  const studio = await StudioProfile.findByPk(studioId, {
    include: [
      {
        model: User,
        as: "owner",
        attributes: ["user_id", "phone", "nickname", "avatar", "city"]
      }
    ],
    transaction
  });

  if (!studio) {
    return null;
  }

  const [latestApplication, orderCount, gmv, studentCount, courseCount] = await Promise.all([
    StudioApplication.findOne({
      include: [
        {
          model: User,
          as: "user",
          attributes: ["user_id", "phone", "nickname", "avatar", "city"]
        }
      ],
      where: { user_id: studio.user_id },
      order: [["version", "DESC"], ["created_at", "DESC"]],
      transaction
    }),
    Order.count({ where: { studio_id: studioId, status: PAID_STATUS }, transaction }),
    Order.sum("paid_amount", { where: { studio_id: studioId, status: PAID_STATUS }, transaction }),
    Order.count({
      distinct: true,
      col: "child_id",
      where: { studio_id: studioId, status: PAID_STATUS },
      transaction
    }),
    Course.count({ where: { studio_id: studioId }, transaction })
  ]);

  return {
    studio_id: String(studio.studio_id),
    user_id: String(studio.user_id),
    name: studio.name,
    cover: studio.cover,
    type_tags: studio.type_tags || [],
    intro: studio.intro,
    address: studio.address,
    lng: studio.lng,
    lat: studio.lat,
    phone: studio.phone,
    hours: studio.hours,
    license: studio.license,
    legal_id: studio.legal_id,
    permit: studio.permit,
    photos: studio.photos || [],
    settle_rate: Number(studio.settle_rate),
    plan_tier: studio.plan_tier,
    status: studio.status,
    banned_at: studio.banned_at,
    ban_reason: studio.ban_reason,
    stats: {
      orders: orderCount,
      gmv_raw: gmv || 0,
      gmv: formatFen(gmv || 0),
      students: studentCount,
      courses: courseCount
    },
    owner: studio.owner
      ? {
          user_id: String(studio.owner.user_id),
          phone: studio.owner.phone,
          nickname: studio.owner.nickname,
          avatar: studio.owner.avatar,
          city: studio.owner.city
        }
      : null,
    latest_application: latestApplication
      ? {
          id: String(latestApplication.id),
          version: latestApplication.version,
          status: latestApplication.status,
          submitted_at: latestApplication.submitted_at,
          reviewed_at: latestApplication.reviewed_at,
          review_reason: latestApplication.review_reason
        }
      : null
  };
}

// ============ 入驻审核（P1） ============

async function getReviews(query = {}) {
  const { page, size, offset } = normalizePage(query);
  const keyword = String(query.keyword || "").trim();
  const status = query.status === undefined || query.status === "" ? null : Number(query.status);

  const where = {};
  if (status !== null && !Number.isNaN(status)) {
    where.status = status;
  }
  if (keyword) {
    where.name = { [Op.like]: `%${keyword}%` };
  }

  const { rows, count } = await StudioApplication.findAndCountAll({
    where,
    include: [
      {
        model: User,
        as: "user",
        attributes: ["user_id", "phone", "nickname"]
      }
    ],
    order: [["submitted_at", "DESC"]],
    limit: size,
    offset
  });

  return {
    total: count,
    page,
    size,
    list: rows.map((item) => ({
      id: String(item.id),
      name: item.name,
      type: "工作室入驻",
      applicant: item.user?.nickname || "-",
      applicant_phone: item.user?.phone || "-",
      status: item.status,
      submittedAt: new Date(item.submitted_at).toLocaleString("zh-CN", { hour12: false })
    }))
  };
}

async function getStudioReviewDetail(reviewId, transaction = null) {
  const row = await StudioApplication.findByPk(reviewId, {
    include: [
      {
        model: User,
        as: "user",
        attributes: ["user_id", "phone", "nickname", "avatar", "city"]
      }
    ],
    transaction
  });

  if (!row) {
    return null;
  }

  return {
    id: String(row.id),
    user_id: String(row.user_id),
    version: row.version,
    name: row.name,
    cover: row.cover,
    intro: row.intro,
    address: row.address,
    phone: row.phone,
    license: row.license,
    permit: row.permit,
    photos: row.photos || [],
    status: row.status,
    submitted_at: row.submitted_at,
    reviewed_at: row.reviewed_at,
    review_reason: row.review_reason,
    applicant: row.user
      ? {
          user_id: String(row.user.user_id),
          phone: row.user.phone,
          nickname: row.user.nickname,
          avatar: row.user.avatar,
          city: row.user.city
        }
      : null
  };
}

async function reviewStudioApplication(reviewId, payload, operator = {}) {
  return sequelize.transaction(async (transaction) => {
    const application = await StudioApplication.findByPk(reviewId, {
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!application) {
      return null;
    }

    if (Number(application.status) !== 0) {
      throw new Error("Studio application already handled");
    }

    const reviewedAt = new Date();
    if (payload.action === "approve") {
      let studio = await StudioProfile.findOne({
        where: { user_id: application.user_id },
        transaction,
        lock: transaction.LOCK.UPDATE
      });

      const studioPayload = {
        name: application.name,
        cover: application.cover || null,
        intro: application.intro || null,
        address: application.address || null,
        phone: application.phone || null,
        license: application.license || null,
        permit: application.permit || null,
        photos: application.photos || [],
        status: 1,
        banned_at: null,
        ban_reason: null
      };

      if (!studio) {
        studio = await StudioProfile.create(
          {
            studio_id: generateId(),
            user_id: application.user_id,
            ...studioPayload
          },
          { transaction }
        );
      } else {
        await studio.update(studioPayload, { transaction });
      }

      // 同步用户「工作室」身份：认证通过后 verified=true，App 端可切换工作室身份
      let role = await UserRole.findOne({
        where: { user_id: application.user_id, role: 3 },
        transaction,
        lock: transaction.LOCK.UPDATE
      });
      if (!role) {
        await UserRole.create(
          {
            user_id: application.user_id,
            role: 3,
            ref_id: studio.studio_id,
            verified: true
          },
          { transaction }
        );
      } else {
        await role.update(
          { ref_id: studio.studio_id, verified: true },
          { transaction }
        );
      }

      await application.update(
        {
          status: 1,
          reviewed_at: reviewedAt,
          review_reason: payload.reason || null
        },
        { transaction }
      );
    } else {
      await application.update(
        {
          status: 2,
          reviewed_at: reviewedAt,
          review_reason: payload.reason || "已驳回"
        },
        { transaction }
      );
    }

    const detail = await getStudioReviewDetail(application.id, transaction);
    return {
      ...detail,
      operator: formatOperator(operator)
    };
  });
}

// ============ 封禁 / 解封（P1 生命周期管理） ============

function formatOperator(operator = {}) {
  return operator.adminId
    ? {
        admin_id: operator.adminId,
        username: operator.username,
        role: operator.role
      }
    : null;
}

async function banStudio(studioId, payload, operator = {}) {
  return sequelize.transaction(async (transaction) => {
    const studio = await StudioProfile.findByPk(studioId, {
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!studio) {
      return null;
    }
    if (Number(studio.status) === 2) {
      throw new Error("Studio already banned");
    }

    await studio.update(
      {
        status: 2,
        banned_at: new Date(),
        ban_reason: payload.reason || null
      },
      { transaction }
    );

    // 封禁联动：在售课程全部下架，停收新单
    await Course.update(
      { status: 2 },
      { where: { studio_id: studioId, status: 1 }, transaction }
    );

    const detail = await getStudioDetail(studioId, transaction);
    return { ...detail, operator: formatOperator(operator) };
  });
}

async function unbanStudio(studioId, operator = {}) {
  return sequelize.transaction(async (transaction) => {
    const studio = await StudioProfile.findByPk(studioId, {
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!studio) {
      return null;
    }
    if (Number(studio.status) !== 2) {
      throw new Error("Studio is not banned");
    }

    await studio.update(
      {
        status: 1,
        banned_at: null,
        ban_reason: null
      },
      { transaction }
    );

    // 解封联动：本工作室因封禁下架的课程恢复在售
    await Course.update(
      { status: 1 },
      { where: { studio_id: studioId, status: 2 }, transaction }
    );

    const detail = await getStudioDetail(studioId, transaction);
    return { ...detail, operator: formatOperator(operator) };
  });
}

// ============ 结算（P4） ============

async function getSettlements() {
  const rows = await Settlement.findAll({
    include: [
      {
        model: StudioProfile,
        as: "studio",
        attributes: ["name"]
      }
    ],
    order: [["period_start", "DESC"]]
  });

  const pendingNetAmount = rows
    .filter((item) => Number(item.status) !== 2)
    .reduce((sum, item) => sum + Number(item.payable_amount || 0), 0);
  const retryCount = rows.filter((item) => Number(item.status) === 3).length;

  return {
    summary: {
      pendingNetAmount: formatFen(pendingNetAmount),
      pendingNetTrend: `${rows.length} 张结算单`,
      retryCount,
      retryHint: retryCount > 0 ? "需平台复核" : "当前无异常"
    },
    list: rows.map((item) => ({
      id: String(item.settlement_id),
      studio: item.studio?.name || "-",
      period: `${item.period_start} ~ ${item.period_end}`,
      income: formatFen(item.income),
      refund: formatFen(item.refund),
      payable: formatFen(item.payable_amount)
    }))
  };
}

module.exports = {
  getDashboardOverview,
  getStudios,
  getStudioDetail,
  getReviews,
  getStudioReviewDetail,
  reviewStudioApplication,
  banStudio,
  unbanStudio,
  getSettlements
};

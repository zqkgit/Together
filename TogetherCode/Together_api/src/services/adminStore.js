const { Op, fn, col, QueryTypes } = require("sequelize");
const {
  StudioProfile,
  StudioApplication,
  Settlement,
  User,
  Order,
  Course,
  Child
} = require("../models");
const { sequelize } = require("../models");
const { generateId } = require("../utils/id");
const { formatFen } = require("../utils/amount");

async function getDashboardOverview() {
  const monthStart = new Date();
  monthStart.setDate(1);
  monthStart.setHours(0, 0, 0, 0);
  const dayStart30 = new Date();
  dayStart30.setDate(dayStart30.getDate() - 29);
  dayStart30.setHours(0, 0, 0, 0);

  const [studioPending, refundCount, settlementRows, studioCount, studioNewMonth, courseTotal, childTotal, orderMonth, studentActive, gmvMonth] =
    await Promise.all([
      StudioApplication.count({ where: { status: 0 } }),
      Settlement.count({ where: { refund: { [Op.gt]: 0 } } }),
      Settlement.findAll(),
      StudioProfile.count(),
      StudioProfile.count({ where: { created_at: { [Op.gte]: monthStart } } }),
      Course.count(),
      Child.count(),
      Order.count({ where: { status: { [Op.ne]: 0 }, created_at: { [Op.gte]: monthStart } } }),
      Order.count({
        where: { status: { [Op.ne]: 0 }, child_id: { [Op.ne]: null } },
        distinct: true,
        col: "child_id"
      }),
      Order.findOne({
        where: { status: { [Op.ne]: 0 }, created_at: { [Op.gte]: monthStart } },
        attributes: [[fn("COALESCE", fn("SUM", col("total_amount")), 0), "gmv"]],
        raw: true
      })
    ]);

  const totalIncome = settlementRows.reduce((sum, item) => sum + Number(item.income || 0), 0);
  const totalPendingPayable = settlementRows
    .filter((item) => Number(item.status) !== 2)
    .reduce((sum, item) => sum + Number(item.payable_amount || 0), 0);
  const abnormalCount = settlementRows.filter((item) => Number(item.status) === 3).length;

  // 近 30 天 GMV 趋势（有效订单按天聚合）
  const trendRows = await sequelize.query(
    `SELECT DATE_FORMAT(created_at, '%Y-%m-%d') AS date, COALESCE(SUM(total_amount), 0) AS gmv
     FROM orders WHERE status <> 0 AND created_at >= :start
     GROUP BY DATE_FORMAT(created_at, '%Y-%m-%d') ORDER BY date`,
    {
      replacements: { start: dayStart30 },
      type: QueryTypes.SELECT
    }
  );
  const trendMap = new Map(trendRows.map((r) => [r.date, Number(r.gmv)]));
  const trend30d = [];
  for (let i = 29; i >= 0; i--) {
    const d = new Date(dayStart30);
    d.setDate(dayStart30.getDate() + i);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    trend30d.push({ date: key, gmv: trendMap.get(key) || 0 });
  }

  const monthGmv = Number(gmvMonth?.gmv || 0);

  return {
    statCards: [
      { label: "本月 GMV", value: formatFen(totalIncome), trend: `${studioCount} 家工作室` },
      { label: "待审核工作室", value: String(studioPending), trend: "实时" },
      { label: "异常结算单", value: String(abnormalCount), trend: "需复核" },
      { label: "待结算金额", value: formatFen(totalPendingPayable), trend: `${refundCount} 笔含退款` }
    ],
    summary: {
      studio_total: studioCount,
      studio_new_month: studioNewMonth,
      student_total: childTotal,
      student_active: studentActive,
      course_total: courseTotal,
      order_month: orderMonth,
      gmv_month: monthGmv,
      gmv_month_text: formatFen(monthGmv)
    },
    trend30d,
    timeline: [
      { timestamp: "今日", content: "认证申请、结算状态与工作室数据均来自数据库" },
      { timestamp: "本周", content: "完成后台接口模型化与 Docker 化运行" }
    ],
    todos: [
      { label: "待审核工作室", count: studioPending },
      { label: "异常结算单", count: abnormalCount }
    ]
  };
}

async function getStudios(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(100, Math.max(1, Number(query.size) || 10));
  const where = {};
  if (query.keyword) {
    where[Op.or] = [{ name: { [Op.like]: `%${query.keyword}%` } }, { address: { [Op.like]: `%${query.keyword}%` } }];
  }

  const { count, rows } = await StudioProfile.findAndCountAll({
    where,
    include: [
      {
        model: User,
        as: "owner",
        attributes: ["user_id", "phone", "nickname"]
      }
    ],
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  return {
    total: count,
    page,
    size,
    list: rows.map((item) => ({
      id: String(item.studio_id),
      name: item.name,
      city: item.address || "-",
      status: Number(item.status) === 1 ? "营业中" : Number(item.status) === 0 ? "待审核" : "异常",
      status_code: Number(item.status),
      owner: item.owner?.nickname || "-",
      owner_phone: item.owner?.phone || "-",
      courses: 0,
      created_at: item.created_at
    }))
  };
}

async function getReviews() {
  const rows = await StudioApplication.findAll({
    where: { status: 0 },
    include: [
      {
        model: User,
        as: "user",
        attributes: ["user_id", "phone", "nickname"]
      }
    ],
    order: [["submitted_at", "DESC"]]
  });

  return {
    total: rows.length,
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

async function getStudioDetail(studioId) {
  const studio = await StudioProfile.findByPk(studioId, {
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

  // 经营统计：订单数 / 累计 GMV / 学员数（报名去重）/ 课程数
  const [orderCount, gmvAgg, courseCount, studentAgg] = await Promise.all([
    Order.count({ where: { studio_id: studioId } }),
    Order.findOne({
      where: { studio_id: studioId },
      attributes: [[fn("COALESCE", fn("SUM", col("total_amount")), 0), "gmv"]],
      raw: true
    }),
    Course.count({ where: { studio_id: studioId } }),
    Order.count({
      where: { studio_id: studioId, child_id: { [Op.ne]: null } },
      distinct: true,
      col: "child_id"
    })
  ]);

  const latestApplication = await StudioApplication.findOne({
    include: [
      {
        model: User,
        as: "user",
        attributes: ["user_id", "phone", "nickname", "avatar", "city"]
      }
    ],
    where: {
      user_id: studio.user_id
    },
    order: [["version", "DESC"], ["created_at", "DESC"]]
  });

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
      gmv: Number(gmvAgg?.gmv || 0),
      students: studentAgg,
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

async function getStudioReviewDetail(reviewId) {
  const row = await StudioApplication.findByPk(reviewId, {
    include: [
      {
        model: User,
        as: "user",
        attributes: ["user_id", "phone", "nickname", "avatar", "city"]
      }
    ]
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

    const detail = await getStudioReviewDetail(application.id);
    return {
      ...detail,
      operator: operator.adminId
        ? {
            admin_id: operator.adminId,
            username: operator.username,
            role: operator.role
          }
        : null
    };
  });
}

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

async function banStudio(studioId, payload = {}, operator = {}) {
  const studio = await StudioProfile.findByPk(studioId);
  if (!studio) {
    return null;
  }

  await studio.update({
    banned_at: new Date(),
    ban_reason: payload.reason || null
  });

  return {
    studio_id: String(studio.studio_id),
    status: studio.status,
    banned_at: studio.banned_at,
    ban_reason: studio.ban_reason,
    operator: operator.adminId
      ? {
          admin_id: operator.adminId,
          username: operator.username,
          role: operator.role
        }
      : null
  };
}

async function unbanStudio(studioId, operator = {}) {
  const studio = await StudioProfile.findByPk(studioId);
  if (!studio) {
    return null;
  }

  await studio.update({
    banned_at: null,
    ban_reason: null
  });

  return {
    studio_id: String(studio.studio_id),
    status: studio.status,
    banned_at: null,
    ban_reason: null,
    operator: operator.adminId
      ? {
          admin_id: operator.adminId,
          username: operator.username,
          role: operator.role
        }
      : null
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

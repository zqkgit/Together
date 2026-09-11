const { Op } = require("sequelize");
const {
  StudioProfile,
  StudioApplication,
  Settlement,
  User
} = require("../models");
const { generateId } = require("../utils/id");
const { formatFen } = require("../utils/amount");

async function getDashboardOverview() {
  const [studioPending, refundCount, settlementRows, studioCount] = await Promise.all([
    StudioApplication.count({ where: { status: 0 } }),
    Settlement.count({ where: { refund: { [Op.gt]: 0 } } }),
    Settlement.findAll(),
    StudioProfile.count()
  ]);

  const totalIncome = settlementRows.reduce((sum, item) => sum + Number(item.income || 0), 0);
  const totalPendingPayable = settlementRows
    .filter((item) => Number(item.status) !== 2)
    .reduce((sum, item) => sum + Number(item.payable_amount || 0), 0);
  const abnormalCount = settlementRows.filter((item) => Number(item.status) === 3).length;

  return {
    statCards: [
      { label: "本月 GMV", value: formatFen(totalIncome), trend: `${studioCount} 家工作室` },
      { label: "待审核工作室", value: String(studioPending), trend: "实时" },
      { label: "异常结算单", value: String(abnormalCount), trend: "需复核" },
      { label: "待结算金额", value: formatFen(totalPendingPayable), trend: `${refundCount} 笔含退款` }
    ],
    timeline: [
      { timestamp: "今日", content: "认证申请、结算状态与工作室数据均来自数据库" },
      { timestamp: "本周", content: "完成后台接口模型化与 Docker 化运行" }
    ],
    todos: [
      "继续落 courses / orders / refunds 真实表",
      "补后台登录与 RBAC",
      "接入工作室审核操作流",
      "生成结算单批处理任务"
    ]
  };
}

async function getStudios() {
  const rows = await StudioProfile.findAll({
    include: [
      {
        model: User,
        as: "owner",
        attributes: ["user_id", "phone", "nickname"]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  return rows.map((item) => ({
    id: String(item.studio_id),
    name: item.name,
    city: item.address || "-",
    status: Number(item.status) === 1 ? "营业中" : Number(item.status) === 0 ? "待审核" : "异常",
    owner: item.owner?.nickname || "-",
    owner_phone: item.owner?.phone || "-",
    courses: 0
  }));
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

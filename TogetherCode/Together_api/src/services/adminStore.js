const { Op } = require("sequelize");
const {
  StudioProfile,
  TeacherApplication,
  StudioApplication,
  Settlement
} = require("../models");
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
    order: [["created_at", "DESC"]]
  });

  return rows.map((item) => ({
    id: String(item.studio_id),
    name: item.name,
    city: item.address || "-",
    status: Number(item.status) === 1 ? "营业中" : Number(item.status) === 0 ? "待审核" : "异常",
    courses: 0
  }));
}

async function getReviews() {
  const [teacherRows, studioRows] = await Promise.all([
    TeacherApplication.findAll({
      where: { status: 0 },
      order: [["submitted_at", "DESC"]]
    }),
    StudioApplication.findAll({
      where: { status: 0 },
      order: [["submitted_at", "DESC"]]
    })
  ]);

  const teacherList = teacherRows.map((item) => ({
    id: `teacher_${item.id}`,
    name: item.real_name,
    type: "老师认证",
    studio: item.studio_id ? String(item.studio_id) : "-",
    submittedAt: item.submitted_at
  }));

  const studioList = studioRows.map((item) => ({
    id: `studio_${item.id}`,
    name: item.name,
    type: "工作室入驻",
    studio: "-",
    submittedAt: item.submitted_at
  }));

  const list = [...teacherList, ...studioList].sort((a, b) => {
    return new Date(b.submittedAt).getTime() - new Date(a.submittedAt).getTime();
  });

  return {
    total: list.length,
    list: list.map((item) => ({
      ...item,
      submittedAt: new Date(item.submittedAt).toLocaleString("zh-CN", { hour12: false })
    }))
  };
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

module.exports = {
  getDashboardOverview,
  getStudios,
  getReviews,
  getSettlements
};

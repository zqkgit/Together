const { Op } = require("sequelize");
const dayjs = require("dayjs");
const {
  sequelize,
  Settlement,
  StudioProfile,
  Order,
  Refund,
  Course
} = require("../models");
const { generateId } = require("../utils/id");
const { formatFen } = require("../utils/amount");

// 订单状态：0 待支付 / 1 支付成功 / 3 已退款
const PAID_STATUS = { [Op.ne]: 0 };

const SETTLEMENT_STATUS = {
  0: "待结算",
  1: "已打款",
  2: "已作废",
  3: "异常待复核"
};

function normalizeSettlement(row) {
  return {
    id: String(row.settlement_id),
    settlement_id: String(row.settlement_id),
    studio_id: String(row.studio_id),
    studio: row.studio?.name || "-",
    period: `${row.period_start} ~ ${row.period_end}`,
    period_start: row.period_start,
    period_end: row.period_end,
    income: formatFen(row.income),
    refund: formatFen(row.refund),
    distribution: formatFen(row.distribution),
    net_amount: formatFen(row.net_amount),
    fee_rate: Number(row.fee_rate),
    fee_amount: formatFen(row.fee_amount),
    payable: formatFen(row.payable_amount),
    payable_amount: Number(row.payable_amount || 0),
    status: Number(row.status),
    status_text: SETTLEMENT_STATUS[Number(row.status)] || String(row.status),
    pay_no: row.pay_no,
    paid_at: row.paid_at,
    created_at: row.created_at
  };
}

/**
 * 结算单列表（含汇总）
 */
async function getSettlements() {
  const rows = await Settlement.findAll({
    include: [
      {
        model: StudioProfile,
        as: "studio",
        attributes: ["name"]
      }
    ],
    order: [["period_start", "DESC"], ["created_at", "DESC"]]
  });

  const pendingNetAmount = rows
    .filter((item) => Number(item.status) !== 2)
    .reduce((sum, item) => sum + Number(item.payable_amount || 0), 0);
  const retryCount = rows.filter((item) => Number(item.status) === 3).length;
  const pendingCount = rows.filter((item) => Number(item.status) === 0).length;

  return {
    summary: {
      pendingNetAmount: formatFen(pendingNetAmount),
      pendingNetTrend: `${rows.length} 张结算单`,
      retryCount,
      retryHint: retryCount > 0 ? "需平台复核" : "当前无异常",
      pendingCount
    },
    list: rows.map(normalizeSettlement)
  };
}

/**
 * 为所有认证工作室生成指定周期（默认本月）的结算单。
 * 口径：income - refund - distribution = net；payable = net × (1 - fee_rate)
 * 同一工作室同一周期已存在则跳过（不重复生成）。
 */
async function generateSettlements(operator = {}, period = {}) {
  const start = period.period_start || dayjs().startOf("month").format("YYYY-MM-DD");
  const end = period.period_end || dayjs().endOf("month").format("YYYY-MM-DD");
  const startDate = `${start}T00:00:00`;
  const endDate = `${end}T23:59:59`;

  const studios = await StudioProfile.findAll({ where: { status: 1 } });
  if (studios.length === 0) {
    return { created: [], skipped: [], message: "暂无认证工作室" };
  }

  const created = [];
  const skipped = [];

  for (const studio of studios) {
    const existing = await Settlement.findOne({
      where: { studio_id: studio.studio_id, period_start: start, period_end: end }
    });
    if (existing) {
      skipped.push({ studio_id: String(studio.studio_id), studio: studio.name });
      continue;
    }

    // 周期内已支付订单（含退款订单，退款单独扣减）
    const orders = await Order.findAll({
      where: {
        studio_id: studio.studio_id,
        status: PAID_STATUS,
        paid_at: { [Op.between]: [startDate, endDate] }
      },
      attributes: ["paid_amount"],
      include: [
        {
          model: Course,
          as: "course",
          required: false,
          attributes: ["distribute_rate"]
        }
      ]
    });

    const income = orders.reduce((sum, item) => sum + Number(item.paid_amount || 0), 0);
    const distribution = orders.reduce(
      (sum, item) => sum + Number(item.paid_amount || 0) * Number(item.course?.distribute_rate || 0),
      0
    );

    // 周期内已完成的退款
    const refund = await Refund.sum("amount", {
      where: {
        status: 3,
        created_at: { [Op.between]: [startDate, endDate] },
        "$order.studio_id$": studio.studio_id
      },
      include: [{ model: Order, as: "order", attributes: [] }]
    });

    const netAmount = income - (refund || 0) - Math.round(distribution);
    const feeRate = Number(studio.settle_rate || 0.1);
    const feeAmount = Math.round(netAmount * feeRate);
    const payable = netAmount - feeAmount;

    const row = await Settlement.create({
      settlement_id: generateId(),
      studio_id: studio.studio_id,
      period_start: start,
      period_end: end,
      income,
      refund: refund || 0,
      distribution: Math.round(distribution),
      net_amount: netAmount,
      fee_rate: feeRate,
      fee_amount: feeAmount,
      payable_amount: payable,
      status: 0
    });

    created.push({
      studio_id: String(studio.studio_id),
      studio: studio.name,
      income: formatFen(income),
      refund: formatFen(refund || 0),
      payable: formatFen(payable),
      payable_amount: payable
    });
  }

  return {
    created,
    skipped,
    period: { period_start: start, period_end: end },
    message: `生成 ${created.length} 张结算单${skipped.length ? `，跳过已存在 ${skipped.length} 张` : ""}`
  };
}

/**
 * 结算单打款：status 0 -> 1，记录打款单号与操作人。
 */
async function payoutSettlement(id, operator = {}) {
  return sequelize.transaction(async (transaction) => {
    const row = await Settlement.findByPk(id, {
      include: [{ model: StudioProfile, as: "studio", attributes: ["name"] }],
      transaction,
      lock: transaction.LOCK.UPDATE
    });

    if (!row) {
      return { error: { status: 404, message: "结算单不存在" } };
    }

    if (Number(row.status) !== 0) {
      return { error: { status: 400, message: "仅待结算状态的结算单可打款" } };
    }

    const payNo = `PY${dayjs().format("YYYYMMDDHHmmss")}${String(row.settlement_id).slice(-6)}`;
    await row.update(
      {
        status: 1,
        pay_no: payNo,
        operator_id: operator.adminId || null,
        paid_at: new Date()
      },
      { transaction }
    );

    const latest = await Settlement.findByPk(id, {
      include: [{ model: StudioProfile, as: "studio", attributes: ["name"] }],
      transaction
    });
    return { data: normalizeSettlement(latest) };
  });
}

module.exports = {
  getSettlements,
  generateSettlements,
  payoutSettlement
};

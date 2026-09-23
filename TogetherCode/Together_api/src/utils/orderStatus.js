/**
 * 订单状态机（平台不碰资金：收款 / 退款均线下进行，靠「方式 + 凭证 + 对方手动确认」流转）
 * 状态按业务流转顺序连续编号 0-6。
 *
 * 0 待收款        报名生成，等待家长线下付款并上传凭证（不发课时、不占名额）
 * 1 待确认收款    家长已上传凭证，等待工作室核对
 *                  · 子状态「付款凭证被驳回」：payment.status=2 + reject_reason，
 *                    家长重新上传后仍在状态 1（不单独占主状态）
 * 2 已收款        工作室确认到账，发放课时
 * 3 退款审核中    家长申请退款，等待工作室审核
 *                  · 工作室驳回退款申请 → 订单回到 2
 * 4 待家长确认退款 工作室审核通过、已线下打款并传凭证，等待家长确认
 *                  · 子状态「打款被驳回」：家长反馈未收到 / 金额不符，工作室重新打款后仍在状态 4
 * 5 已退款        家长确认收到退款（终态）
 * 6 已取消        工作室手动取消（终态；待收款 / 待确认收款阶段可取消）
 */
const ORDER_STATUS = {
  PENDING_PAYMENT: 0,
  PAYMENT_REVIEW: 1,
  PAID: 2,
  REFUND_REVIEW: 3,
  REFUND_CONFIRM: 4,
  REFUNDED: 5,
  CANCELLED: 6
};

const ORDER_STATUS_TEXT = {
  0: "待收款",
  1: "待确认收款",
  2: "已收款",
  3: "退款审核中",
  4: "待家长确认退款",
  5: "已退款",
  6: "已取消"
};

/**
 * 「曾确认收款」状态集（gross 口径，用于 GMV / 成交订单 / 学员数统计）：
 * 已收款、退款审核中、待家长确认退款、已退款；排除待收款、待确认收款（钱未确认）、已取消。
 * 已退款订单仍计入 gross GMV，由退款统计另行抵减。
 */
const SETTLED_ORDER_STATUSES = [
  ORDER_STATUS.PAID,
  ORDER_STATUS.REFUND_REVIEW,
  ORDER_STATUS.REFUND_CONFIRM,
  ORDER_STATUS.REFUNDED
];

module.exports = {
  ORDER_STATUS,
  ORDER_STATUS_TEXT,
  SETTLED_ORDER_STATUSES
};

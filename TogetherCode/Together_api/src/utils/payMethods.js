// 支付/打款方式统一口径（订单收款、退款、佣金打款共用）
const PAY_METHODS = ["cash", "wechat", "alipay", "bank", "qrcode", "other"];

const PAY_METHOD_TEXT = {
  cash: "现金",
  wechat: "微信转账",
  alipay: "支付宝转账",
  bank: "银行转账",
  qrcode: "机构收款码",
  other: "其他"
};

// 线上转账类必须上传凭证；现金可由工作室直接登记、免凭证
const ONLINE_PAY_METHODS = ["wechat", "alipay", "bank", "qrcode"];

function payMethodText(method) {
  return PAY_METHOD_TEXT[method] || (method ? String(method) : "");
}

function isOnlinePayMethod(method) {
  return ONLINE_PAY_METHODS.includes(method);
}

module.exports = {
  PAY_METHODS,
  PAY_METHOD_TEXT,
  ONLINE_PAY_METHODS,
  payMethodText,
  isOnlinePayMethod
};

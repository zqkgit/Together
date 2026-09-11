const { ok, fail } = require("../utils/response");
const { sequelize } = require("../models");
const { verifyPayCallback } = require("../services/wxService");
const { handlePayCallbackByOrderNo } = require("../services/orderService");

/**
 * POST /v1/pay/callback/wx · 微信支付回调（微信服务器调用，无登录态）
 * 验签通过 → 按商户订单号完成支付（幂等）。
 */
async function postWxPayCallback(req, res) {
  const raw = typeof req.body === "string" ? req.body : req.rawBody || "";

  const result = verifyPayCallback(raw);
  if (result.notConfigured) {
    return fail(res, 503, 50381, "微信支付未配置（请配置 WX_PAY_MCH_ID / WX_PAY_KEY）");
  }
  if (result.error) {
    return fail(res, result.error.status, result.error.code, result.error.message);
  }

  const { out_trade_no: orderNo, transaction_id: tradeNo, result_code: resultCode } = result;
  if (String(resultCode || "SUCCESS") !== "SUCCESS") {
    return fail(res, 400, 40085, "支付结果非成功");
  }
  if (!orderNo) {
    return fail(res, 400, 40086, "缺少商户订单号 out_trade_no");
  }

  try {
    const handled = await sequelize.transaction((transaction) =>
      handlePayCallbackByOrderNo(orderNo, { channel: "wechat", tradeNo, transaction })
    );
    if (handled.error) {
      return fail(res, handled.error.status, handled.error.code, handled.error.message);
    }
    // 微信要求返回成功应答 XML
    res.type("application/xml");
    return res.send("<xml><return_code><![CDATA[SUCCESS]]></return_code><return_msg><![CDATA[OK]]></return_msg></xml>");
  } catch (error) {
    res.type("application/xml");
    return res.status(500).send("<xml><return_code><![CDATA[FAIL]]></return_code><return_msg><![CDATA[处理失败]]></return_msg></xml>");
  }
}

module.exports = { postWxPayCallback };

const { ok, fail } = require("../utils/response");
const {
  createOrder,
  submitPaymentVoucher,
  cancelOrder,
  listOrders,
  getOrderDetail,
  createRefund,
  listMyRefunds,
  getRefundDetail
} = require("../services/orderService");

async function postOrder(req, res) {
  try {
    const data = await createOrder(req.user.userId, req.body);
    return ok(res, data, "order created");
  } catch (error) {
    const status = /not found|not available|重复|已报名|待收款/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40020 : 50000, error.message || "Internal server error");
  }
}

// 家长为待收款订单上传线下付款凭证（不发起任何在线支付）
async function postPaymentVoucher(req, res) {
  try {
    const data = await submitPaymentVoucher(req.user.userId, req.params.id, req.body || {});
    if (!data) {
      return fail(res, 404, 40420, "Order not found");
    }
    return ok(res, data, "payment voucher submitted");
  } catch (error) {
    const status = /不是待收款|支付方式|凭证|请选择/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40021 : 50000, error.message || "Internal server error");
  }
}

async function getOrders(req, res) {
  try {
    const data = await listOrders(req.user.userId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getOrder(req, res) {
  try {
    const data = await getOrderDetail(req.user.userId, req.params.id);
    if (!data) {
      return fail(res, 404, 40420, "Order not found");
    }

    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postOrderRefund(req, res) {
  try {
    const data = await createRefund(req.user.userId, req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40420, "Order not found");
    }

    return ok(res, data, "refund requested");
  } catch (error) {
    const status = /not refundable|in progress|exceed|not found|expired/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40022 : 50000, error.message || "Internal server error");
  }
}

async function getRefunds(req, res) {
  try {
    const data = await listMyRefunds(req.user.userId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getRefund(req, res) {
  try {
    const data = await getRefundDetail(req.user.userId, req.params.refundId);
    if (!data) {
      return fail(res, 404, 40430, "Refund not found");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postOrderCancel(req, res) {
  try {
    const data = await cancelOrder(req.user.userId, req.params.id);
    if (!data) {
      return fail(res, 404, 40400, "Order not found");
    }
    return ok(res, data, "order cancelled");
  } catch (error) {
    const status = /already paid|unavailable|待收款/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40021 : 50000, error.message || "Internal server error");
  }
}

module.exports = {
  postOrder,
  postPaymentVoucher,
  postOrderCancel,
  getOrders,
  getOrder,
  postOrderRefund,
  getRefunds,
  getRefund
};

const { ok, fail } = require("../utils/response");
const { createOrder, payOrder, listOrders, getOrderDetail, createRefund } = require("../services/orderService");

async function postOrder(req, res) {
  try {
    const data = await createOrder(req.user.userId, req.body);
    return ok(res, data, "order created");
  } catch (error) {
    const status = /not found|not available/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40020 : 50000, error.message || "Internal server error");
  }
}

async function postOrderPay(req, res) {
  try {
    const data = await payOrder(req.user.userId, req.params.id, req.body || {});
    if (!data) {
      return fail(res, 404, 40420, "Order not found");
    }

    return ok(res, data, "order paid");
  } catch (error) {
    const status = /already paid|unavailable/i.test(error.message) ? 400 : 500;
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
    const status = /not refundable|in progress|exceed|not found/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40022 : 50000, error.message || "Internal server error");
  }
}

module.exports = {
  postOrder,
  postOrderPay,
  getOrders,
  getOrder,
  postOrderRefund
};

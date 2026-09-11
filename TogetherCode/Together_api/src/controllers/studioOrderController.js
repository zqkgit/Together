const { ok, fail } = require("../utils/response");
const {
  listStudioOrders,
  getStudioOrderDetail,
  listStudioRefunds,
  reviewStudioRefund
} = require("../services/studioOrderService");
const { recordAudit } = require("../utils/audit");

async function getStudioOrders(req, res) {
  try {
    const data = await listStudioOrders(req.admin.studioId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getStudioOrder(req, res) {
  try {
    const data = await getStudioOrderDetail(req.admin.studioId, req.params.id);
    if (!data) {
      return fail(res, 404, 40490, "Order not found");
    }

    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getStudioRefunds(req, res) {
  try {
    const data = await listStudioRefunds(req.admin.studioId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putStudioRefund(req, res) {
  try {
    const data = await reviewStudioRefund(req.admin.studioId, req.params.id, req.body, req.admin);
    if (!data) {
      return fail(res, 404, 40491, "Refund not found");
    }
    await recordAudit({
      actor: req.admin,
      role: req.admin.role,
      studioId: req.admin.studioId,
      action: "studio.refund.review",
      targetType: "refund",
      targetId: req.params.id,
      detail: req.body,
      ip: req.ip
    });
    return ok(res, data, "refund handled");
  } catch (error) {
    const status = /already handled|exceed|not found/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40090 : 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getStudioOrders,
  getStudioOrder,
  getStudioRefunds,
  putStudioRefund
};

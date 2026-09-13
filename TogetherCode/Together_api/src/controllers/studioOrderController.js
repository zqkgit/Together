const { ok, fail } = require("../utils/response");
const {
  listStudioOrders,
  getStudioOrderDetail,
  listStudioRefunds,
  reviewStudioRefund
} = require("../services/studioOrderService");

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

    return ok(res, data, "refund handled");
  } catch (error) {
    const status = /already handled|exceed|not found/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40090 : 50000, error.message || "Internal server error");
  }
}

module.exports = {
  exportStudioOrders,
  exportStudioRefunds,
  getStudioOrders,
  getStudioOrder,
  getStudioRefunds,
  putStudioRefund
};

// 导出：订单全量（复用列表查询，去分页包装）
async function exportStudioOrders(req, res) {
  try {
    const data = await listStudioOrders(req.admin.studioId, req.query);
    return ok(res, { list: data.list });
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 导出：退款单全量
async function exportStudioRefunds(req, res) {
  try {
    const data = await listStudioRefunds(req.admin.studioId, req.query);
    return ok(res, { list: data.list });
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

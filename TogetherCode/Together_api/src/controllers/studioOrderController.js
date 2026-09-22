const { ok, fail } = require("../utils/response");
const {
  listStudioOrders,
  getStudioOrderDetail,
  listStudioRefunds,
  reviewStudioRefund,
  confirmRefundPaid,
  listOrderContacts,
  createStudioOrder,
  confirmStudioPayment,
  rejectStudioPayment,
  cancelStudioOrder
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
    const isConfirm = req.body.action === "confirm";
    const data = isConfirm
      ? await confirmRefundPaid(req.admin.studioId, req.params.id, req.admin)
      : await reviewStudioRefund(req.admin.studioId, req.params.id, req.body, req.admin);
    if (!data) {
      return fail(res, 404, 40491, "Refund not found");
    }

    return ok(res, data, isConfirm ? "refund paid" : "refund handled");
  } catch (error) {
    const status = /already handled|exceed|not found|awaiting|请选择|凭证|退款方式|驳回|原因|必填/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40090 : 50000, error.message || "Internal server error");
  }
}

// 手动建单联系人库：本工作室在读 / 历史订单孩子（支持昵称/手机搜索）
async function getStudioOrderContacts(req, res) {
  try {
    const data = await listOrderContacts(req.admin.studioId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 工作室手动建单（老学员续费 / 线下现金报名，可当场确认收款发课时）
async function postStudioOrder(req, res) {
  try {
    const data = await createStudioOrder(req.admin.studioId, req.body, req.admin);
    return ok(res, data, "order created");
  } catch (error) {
    const status = /不存在|不属于|联系人库|重复|待收款|满员|金额|凭证|支付方式|未上架/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40090 : 50000, error.message || "Internal server error");
  }
}

// 工作室确认收款（确认家长凭证 / 直接登记现金收款），确认后发课时
async function postStudioPaymentConfirm(req, res) {
  try {
    const data = await confirmStudioPayment(req.admin.studioId, req.params.id, req.body || {}, req.admin);
    if (!data) {
      return fail(res, 404, 40490, "Order not found");
    }
    return ok(res, data, "payment confirmed");
  } catch (error) {
    const status = /不是待收款|支付方式|凭证|请选择|现金/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40090 : 50000, error.message || "Internal server error");
  }
}

// 工作室驳回家长上传的付款凭证（订单仍待收款）
async function postStudioPaymentReject(req, res) {
  try {
    const data = await rejectStudioPayment(req.admin.studioId, req.params.id, req.body || {}, req.admin);
    if (!data) {
      return fail(res, 404, 40490, "Order not found");
    }
    return ok(res, data, "payment voucher rejected");
  } catch (error) {
    const status = /不是待收款|凭证|没有待审核/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40090 : 50000, error.message || "Internal server error");
  }
}

// 工作室手动取消待收款订单
async function postStudioOrderCancel(req, res) {
  try {
    const data = await cancelStudioOrder(req.admin.studioId, req.params.id);
    if (!data) {
      return fail(res, 404, 40490, "Order not found");
    }
    return ok(res, data, "order cancelled");
  } catch (error) {
    const status = /待收款|仅待收款/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40090 : 50000, error.message || "Internal server error");
  }
}

module.exports = {
  exportStudioOrders,
  exportStudioRefunds,
  getStudioOrders,
  getStudioOrder,
  getStudioRefunds,
  putStudioRefund,
  getStudioOrderContacts,
  postStudioOrder,
  postStudioPaymentConfirm,
  postStudioPaymentReject,
  postStudioOrderCancel
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

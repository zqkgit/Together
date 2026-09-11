const { ok, fail } = require("../utils/response");
const {
  getStudioFinance,
  listStudioAccounts,
  upsertStudioAccount,
  listStudioAudit,
  createStudioStaff
} = require("../services/studioGovernanceService");
const { recordAudit } = require("../utils/audit");

// GET /studio/finance · 财务对账
async function getFinance(req, res) {
  try {
    return ok(res, await getStudioFinance(req.admin.studioId, req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// GET /studio/accounts · 结算账户列表
async function getAccounts(req, res) {
  try {
    return ok(res, await listStudioAccounts(req.admin.studioId));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// POST /studio/accounts · 绑定 / 更新结算账户
async function postAccount(req, res) {
  try {
    const result = await upsertStudioAccount(req.admin.studioId, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    await recordAudit({
      actor: req.admin,
      role: req.admin.role,
      studioId: req.admin.studioId,
      action: "studio.account.upsert",
      targetType: "studio_account",
      targetId: result.data.account_id,
      ip: req.ip
    });
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// GET /studio/audit · 本店操作审计
async function getAudit(req, res) {
  try {
    return ok(res, await listStudioAudit(req.admin.studioId, req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// POST /studio/staff · 新增员工账号（owner）
async function postStaff(req, res) {
  try {
    const result = await createStudioStaff(req.admin.studioId, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    await recordAudit({
      actor: req.admin,
      role: req.admin.role,
      studioId: req.admin.studioId,
      action: "studio.staff.create",
      targetType: "admin_account",
      targetId: result.data.admin_id,
      ip: req.ip
    });
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getFinance,
  getAccounts,
  postAccount,
  getAudit,
  postStaff
};

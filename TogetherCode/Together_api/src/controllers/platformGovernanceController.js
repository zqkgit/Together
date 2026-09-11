const { ok, fail } = require("../utils/response");
const {
  listReports,
  handleReport,
  moderatePost,
  reprocessSettlement,
  getPlatformConfig,
  updatePlatformConfig,
  listAnnouncements,
  createAnnouncement,
  createPlatformStaff,
  listPlatformAudit
} = require("../services/platformGovernanceService");
const { recordAudit } = require("../utils/audit");

// 举报处置
async function getReportsList(req, res) {
  try {
    return ok(res, await listReports(req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putReportHandle(req, res) {
  try {
    const result = await handleReport(req.params.id, req.admin, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    await recordAudit({
      actor: req.admin,
      role: req.admin.role,
      action: "report.handle",
      targetType: "report",
      targetId: req.params.id,
      detail: { status: result.data.status },
      ip: req.ip
    });
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 内容下架 / 恢复
async function putPostModerate(req, res) {
  try {
    const result = await moderatePost(req.params.id, req.admin, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    await recordAudit({
      actor: req.admin,
      role: req.admin.role,
      action: result.data.status === 0 ? "post.moderate" : "post.restore",
      targetType: "post",
      targetId: req.params.id,
      ip: req.ip
    });
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 结算异常重打
async function postSettlementReprocess(req, res) {
  try {
    const result = await reprocessSettlement(req.params.id, req.admin);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    await recordAudit({
      actor: req.admin,
      role: req.admin.role,
      action: "settlement.reprocess",
      targetType: "settlement",
      targetId: req.params.id,
      ip: req.ip
    });
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 平台配置
async function getConfig(req, res) {
  try {
    return ok(res, await getPlatformConfig());
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putConfig(req, res) {
  try {
    const result = await updatePlatformConfig(req.admin, req.body);
    await recordAudit({
      actor: req.admin,
      role: req.admin.role,
      action: "platform.config",
      detail: { keys: result.data.updated },
      ip: req.ip
    });
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 公告 / Banner
async function getAnnouncementsList(req, res) {
  try {
    return ok(res, await listAnnouncements(req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postAnnouncement(req, res) {
  try {
    const result = await createAnnouncement(req.admin, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    await recordAudit({
      actor: req.admin,
      role: req.admin.role,
      action: "announcement.create",
      targetType: "announcement",
      targetId: result.data.announcement_id,
      ip: req.ip
    });
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 平台员工
async function postStaff(req, res) {
  try {
    const result = await createPlatformStaff(req.admin, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    await recordAudit({
      actor: req.admin,
      role: req.admin.role,
      action: "staff.create",
      targetType: "admin_account",
      targetId: result.data.admin_id,
      ip: req.ip
    });
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 审计日志
async function getAuditList(req, res) {
  try {
    return ok(res, await listPlatformAudit(req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getReportsList,
  putReportHandle,
  putPostModerate,
  postSettlementReprocess,
  getConfig,
  putConfig,
  getAnnouncementsList,
  postAnnouncement,
  postStaff,
  getAuditList
};

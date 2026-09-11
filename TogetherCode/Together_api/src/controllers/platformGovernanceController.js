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
  listPlatformAudit,
  listPosts,
  listPlatformStaff,
  updateAdminStaffStatus,
  updateAnnouncementStatus,
  listWithdrawals,
  reviewWithdrawal
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

// 平台帖子列表（内容管理）
async function getPostsList(req, res) {
  try {
    return ok(res, await listPosts(req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 平台员工列表
async function getStaffList(req, res) {
  try {
    return ok(res, await listPlatformStaff(req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 员工启用 / 停用
async function putStaffStatus(req, res) {
  try {
    const result = await updateAdminStaffStatus(req.params.id, req.admin, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    await recordAudit({
      actor: req.admin,
      role: req.admin.role,
      action: result.data.status === 1 ? "staff.enable" : "staff.disable",
      targetType: "admin_account",
      targetId: req.params.id,
      ip: req.ip
    });
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 公告 / Banner 上下架
async function putAnnouncementStatus(req, res) {
  try {
    const result = await updateAnnouncementStatus(req.params.id, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    await recordAudit({
      actor: req.admin,
      role: req.admin.role,
      action: result.data.status === 1 ? "announcement.publish" : "announcement.off",
      targetType: "announcement",
      targetId: req.params.id,
      ip: req.ip
    });
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 提现单列表（提现审核）
async function getWithdrawalsList(req, res) {
  try {
    return ok(res, await listWithdrawals(req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 提现审核：通过 / 驳回
async function putWithdrawalReview(req, res) {
  try {
    const result = await reviewWithdrawal(req.params.id, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    await recordAudit({
      actor: req.admin,
      role: req.admin.role,
      action: result.data.status === 3 ? "withdrawal.approve" : "withdrawal.reject",
      targetType: "withdrawal",
      targetId: req.params.id,
      detail: { amount: req.body.amount },
      ip: req.ip
    });
    return ok(res, result.data, result.message);
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
  getAuditList,
  getPostsList,
  getStaffList,
  putStaffStatus,
  putAnnouncementStatus,
  getWithdrawalsList,
  putWithdrawalReview
};

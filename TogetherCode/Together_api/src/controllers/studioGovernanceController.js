const { ok, fail } = require("../utils/response");
const {
  getStudioFinance,
  listStudioAccounts,
  upsertStudioAccount,
  listStudioAudit,
  createStudioStaff,
  listStudioStaff,
  updateStudioStaffStatus
} = require("../services/studioGovernanceService");
const {
  getStudioTeachers,
  reviewTeacherApplication,
  releaseTeacher
} = require("../services/studioTeacherService");
const { recordAudit } = require("../utils/audit");

function getStudioId(req) {
  return req.admin.studioId;
}

async function getTeachers(req, res) {
  try {
    const data = await getStudioTeachers(getStudioId(req), req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putTeacherReview(req, res) {
  try {
    const data = await reviewTeacherApplication(getStudioId(req), req.params.id, req.body, {
      adminId: req.admin.adminId
    });
    if (data?.error) {
      return fail(res, data.error.status || 400, 40000, data.error.message);
    }
    await recordAudit({ actor: req.admin, studioId: getStudioId(req), action: "teacher.review", targetType: "teacher_application", targetId: req.params.id, ip: req.ip });
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function deleteTeacherBinding(req, res) {
  try {
    const data = await releaseTeacher(getStudioId(req), req.params.teacherId, req.body);
    if (data?.error) {
      return fail(res, data.error.status || 400, 40000, data.error.message);
    }
    await recordAudit({ actor: req.admin, studioId: getStudioId(req), action: "teacher.unbind", targetType: "teacher", targetId: req.params.teacherId, ip: req.ip });
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getFinance(req, res) {
  try {
    const data = await getStudioFinance(getStudioId(req), req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 导出：区间订单明细（财务流水）
async function exportFinance(req, res) {
  try {
    const data = await getStudioFinance(getStudioId(req), { ...req.query, limit: 20000 });
    return ok(res, { list: data.orders || [], period: data.period });
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getAccounts(req, res) {
  try {
    const data = await listStudioAccounts(getStudioId(req));
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postAccount(req, res) {
  try {
    const data = await upsertStudioAccount(getStudioId(req), req.body);
    if (data?.error) {
      return fail(res, data.error.status || 400, 40000, data.error.message);
    }
    await recordAudit({ actor: req.admin, studioId: getStudioId(req), action: "studio.account.upsert", targetType: "studio_account", targetId: req.params.id, ip: req.ip });
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getAudit(req, res) {
  try {
    const data = await listStudioAudit(getStudioId(req), req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getStaff(req, res) {
  try {
    const data = await listStudioStaff(getStudioId(req), req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postStaff(req, res) {
  try {
    const data = await createStudioStaff(getStudioId(req), req.body);
    if (data?.error) {
      return fail(res, data.error.status || 400, 40000, data.error.message);
    }
    await recordAudit({ actor: req.admin, studioId: getStudioId(req), action: "studio.staff.create", targetType: "admin_account", targetId: data.data?.admin_id, ip: req.ip });
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putStaffStatus(req, res) {
  try {
    const data = await updateStudioStaffStatus(req.params.id, getStudioId(req), { adminId: req.admin.adminId }, req.body);
    if (data?.error) {
      return fail(res, data.error.status || 400, 40000, data.error.message);
    }
    await recordAudit({ actor: req.admin, studioId: getStudioId(req), action: req.body.status === 0 ? "studio.staff.disable" : "studio.staff.enable", targetType: "admin_account", targetId: req.params.id, ip: req.ip });
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  exportFinance,
  getTeachers,
  putTeacherReview,
  deleteTeacherBinding,
  getFinance,
  getAccounts,
  postAccount,
  getAudit,
  getStaff,
  postStaff,
  putStaffStatus
};

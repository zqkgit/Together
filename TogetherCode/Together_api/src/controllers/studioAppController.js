const { ok, fail } = require("../utils/response");
const { StudioProfile } = require("../models");
const { getStudioMine, getStudioOverviewForApp } = require("../services/studioAppService");
const {
  listStudioRefunds,
  reviewStudioRefund,
  confirmRefundPaid
} = require("../services/studioOrderService");
const {
  listStudioCourses,
  getCourseDetail,
  setStudioCourseStatus
} = require("../services/courseService");
const {
  listStudioStudentsForApp,
  getStudioStudentDetailForApp
} = require("../services/studentService");
const {
  getStudioTeacherRoster,
  getStudioTeacherDetail,
  getStudioTeacherApplications,
  reviewTeacherApplication,
  inviteTeacher,
  releaseTeacher
} = require("../services/studioTeacherService");

/**
 * 由登录用户（工作室主体）解析其 studio_id；非工作室主体返回 null
 */
async function resolveStudioId(userId) {
  const studio = await StudioProfile.findOne({
    where: { user_id: userId },
    attributes: ["studio_id"]
  });
  return studio ? studio.studio_id : null;
}

/**
 * GET /v1/studio/mine · 工作室 App 端「我的」
 * 机构资料 + 经营统计（在读学员 / 在售课程 / 入驻教师 / 待退款）
 */
async function getStudioMineHandler(req, res) {
  try {
    const data = await getStudioMine(req.user.userId);
    if (!data) {
      return fail(res, 404, 40480, "Studio not found");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * GET /v1/studio/overview · 工作室 App 端「经营概览」
 * 营收卡（本月营收 / 可提现 / 分销返利 / 结算中）+ 三项统计 + 待办 + 机构动态
 */
async function getStudioOverviewHandler(req, res) {
  try {
    const data = await getStudioOverviewForApp(req.user.userId);
    if (!data) {
      return fail(res, 404, 40480, "Studio not found");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * GET /v1/studio/refunds · 工作室 App 端退款列表（query: status 0申请中/1待打款/2已驳回/3已打款）
 */
async function getStudioRefundsHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const data = await listStudioRefunds(studioId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * PUT /v1/studio/refunds/:id · 退款审核
 * body.action: approve 通过(0→1待打款) / reject 驳回(→2，带 reason) / confirm 确认打款(1→3)
 */
async function putStudioRefundHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const operator = { adminId: req.user.userId };
    const isConfirm = req.body.action === "confirm";
    const data = isConfirm
      ? await confirmRefundPaid(studioId, req.params.id, operator)
      : await reviewStudioRefund(studioId, req.params.id, req.body, operator);
    if (!data) {
      return fail(res, 404, 40491, "Refund not found");
    }
    return ok(res, data, isConfirm ? "refund paid" : "refund handled");
  } catch (error) {
    const status = /already handled|exceed|not found|awaiting payout/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40090 : 50000, error.message || "Internal server error");
  }
}

/**
 * GET /v1/studio/courses · 本工作室课程列表（query: status 0审核中/1在售/2已下架，q/keyword 模糊）
 * studio_id 强制取登录主体，忽略前端传入，避免越权。
 */
async function getStudioCoursesHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const data = await listStudioCourses({
      studio_id: studioId,
      status: req.query.status,
      keyword: req.query.keyword || req.query.q
    });
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * GET /v1/studio/courses/:id · 课程详情（校验归属本工作室，用于编辑回显 / 预览）
 */
async function getStudioCourseHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const data = await getCourseDetail(req.params.id);
    if (!data || !data.studio || String(data.studio.studio_id) !== String(studioId)) {
      return fail(res, 404, 40481, "Course not found");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * PATCH /v1/studio/courses/:id/status · 上架 / 下架（body.status: 1 在售 / 2 已下架）
 */
async function patchStudioCourseStatusHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const data = await setStudioCourseStatus(studioId, req.params.id, req.body.status);
    return ok(res, data, data.status === 1 ? "course on shelf" : "course off shelf");
  } catch (error) {
    const status = error.statusCode || (/not found/i.test(error.message) ? 404 : 500);
    return fail(res, status, status === 404 ? 40481 : 40080, error.message || "Internal server error");
  }
}

/**
 * GET /v1/studio/students · 工作室 App 端「学员管理」列表
 * query: filter all 全部 / renew 待续费(剩余≤3) / new 本月新增；q 昵称/家长模糊
 * 返回 summary（全量口径）+ list
 */
async function getStudioStudentsHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const data = await listStudioStudentsForApp(studioId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * GET /v1/studio/students/:id · 学员详情（信息 + 各课程课时余额 + 课时流水）
 */
async function getStudioStudentDetailHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const data = await getStudioStudentDetailForApp(req.params.id, studioId);
    if (!data) {
      return fail(res, 404, 40430, "Student not found");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * GET /v1/studio/teachers · 在职老师列表（含本工作室口径统计）
 * summary：老师数 / 学员数 / 本月消课 / 待审合作申请
 */
async function getStudioTeachersHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const data = await getStudioTeacherRoster(studioId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * GET /v1/studio/teachers/:id · 老师详情（档案 + 本工作室带课 + 最近消课流水）
 */
async function getStudioTeacherDetailHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const data = await getStudioTeacherDetail(studioId, req.params.id);
    if (!data) {
      return fail(res, 404, 40440, "Teacher not found");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * GET /v1/studio/teachers/applications · 老师合作申请列表（含各状态计数）
 */
async function getStudioTeacherApplicationsHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const data = await getStudioTeacherApplications(studioId, req.query.status);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * PUT /v1/studio/teachers/applications/:id · 审批合作申请
 * body: { action: "approve" | "reject", reason?: string }
 */
async function putStudioTeacherApplicationHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const result = await reviewTeacherApplication(studioId, req.params.id, {
      action: req.body.action,
      reason: req.body.reason
    });
    if (result.error) {
      return fail(res, result.error.status, result.error.status * 100, result.error.message);
    }
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * POST /v1/studio/teachers/invite · 邀请老师（手机号）
 * 前置：对方需已通过平台老师认证，本接口只建立合作绑定
 */
async function postStudioTeacherInviteHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const result = await inviteTeacher(studioId, { phone: req.body.phone });
    if (result.error) {
      return fail(res, result.error.status, result.error.code || result.error.status * 100, result.error.message);
    }
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * DELETE /v1/studio/teachers/:id · 解除与老师的合作（老师档案与其他工作室绑定不受影响）
 */
async function deleteStudioTeacherHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const result = await releaseTeacher(studioId, req.params.id, {});
    if (result.error) {
      return fail(res, result.error.status, result.error.status * 100, result.error.message);
    }
    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getStudioMineHandler,
  getStudioOverviewHandler,
  getStudioStudentsHandler,
  getStudioStudentDetailHandler,
  getStudioTeachersHandler,
  getStudioTeacherDetailHandler,
  getStudioTeacherApplicationsHandler,
  putStudioTeacherApplicationHandler,
  postStudioTeacherInviteHandler,
  deleteStudioTeacherHandler,
  getStudioRefundsHandler,
  putStudioRefundHandler,
  getStudioCoursesHandler,
  getStudioCourseHandler,
  patchStudioCourseStatusHandler
};

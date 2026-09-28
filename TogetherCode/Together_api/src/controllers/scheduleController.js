const { ok, fail } = require("../utils/response");
const {
  listStudioClasses,
  createStudioClass,
  updateStudioClass,
  createStudioSchedule,
  updateStudioSchedule,
  deleteStudioSchedule,
  batchCreateStudioSchedules,
  listStudioSchedules,
  createTeacherSchedule
} = require("../services/scheduleService");
const { listClassStudents, attendSchedule } = require("../services/studentService");
const { recordAudit } = require("../utils/audit");

async function getStudioClasses(req, res) {
  try {
    const data = await listStudioClasses(req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postStudioClass(req, res) {
  try {
    const data = await createStudioClass(req.body);
    await recordAudit({ actor: req.admin, studioId: req.admin.studioId, action: "class.create", targetType: "class", targetId: data?.class_id, ip: req.ip });
    return ok(res, data, "class created");
  } catch (error) {
    const status = /not found|does not belong/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40040 : 50000, error.message || "Internal server error");
  }
}

async function putStudioClass(req, res) {
  try {
    const data = await updateStudioClass(req.params.id, req.body);
    await recordAudit({ actor: req.admin, studioId: req.admin.studioId, action: "class.update", targetType: "class", targetId: req.params.id, ip: req.ip });
    return ok(res, data, "class updated");
  } catch (error) {
    const status = /not found|does not belong/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40040 : 50000, error.message || "Internal server error");
  }
}

async function getClassStudents(req, res) {
  try {
    const data = await listClassStudents(req.params.id, req.query);
    if (!data) {
      return fail(res, 404, 40440, "Class not found");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getStudioSchedules(req, res) {
  try {
    const data = await listStudioSchedules(req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postStudioSchedule(req, res) {
  try {
    const data = await createStudioSchedule(req.body);
    await recordAudit({ actor: req.admin, studioId: req.admin.studioId, action: "schedule.create", targetType: "schedule", targetId: data?.schedule_id, ip: req.ip });
    return ok(res, data, "schedule created");
  } catch (error) {
    const status = /not found|does not belong|conflict|greater than|排课日期数|超过/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40041 : 50000, error.message || "Internal server error");
  }
}

// POST /v1/schedules · 老师 App 端新增排课（身份从 token 推导工作室）
async function postTeacherSchedule(req, res) {
  try {
    const data = await createTeacherSchedule(req.user.userId, req.body);
    return ok(res, data, "schedule created");
  } catch (error) {
    const status = /not found|does not belong|conflict|greater than|排课日期数|超过/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40041 : 50000, error.message || "Internal server error");
  }
}

async function postScheduleAttendance(req, res) {
  try {
    const data = await attendSchedule(req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40441, "Schedule not found");
    }
    await recordAudit({ actor: req.admin, studioId: req.admin.studioId, action: "schedule.attendance", targetType: "schedule", targetId: req.params.id, ip: req.ip });
    return ok(res, data, "attendance submitted");
  } catch (error) {
    const status = /not found|not available|exceed|already/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40042 : 50000, error.message || "Internal server error");
  }
}

// PUT /studio/schedules/:id · 编辑排课
async function putStudioSchedule(req, res) {
  try {
    const data = await updateStudioSchedule(req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40441, "Schedule not found");
    }
    await recordAudit({ actor: req.admin, studioId: req.admin.studioId, action: "schedule.update", targetType: "schedule", targetId: req.params.id, ip: req.ip });
    return ok(res, data, "schedule updated");
  } catch (error) {
    const status = /not found|conflict|not allowed|greater than|已消课|已开始/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40041 : 50000, error.message || "Internal server error");
  }
}

// POST /studio/schedules/batch · 批量排课
async function postStudioScheduleBatch(req, res) {
  try {
    const data = await batchCreateStudioSchedules(req.body);
    await recordAudit({ actor: req.admin, studioId: req.admin.studioId, action: "schedule.batch_create", targetType: "schedule", ip: req.ip });
    return ok(res, data, "schedules created");
  } catch (error) {
    const status = /not found|does not belong|conflict|greater than|排课日期数|超过/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40041 : 50000, error.message || "Internal server error");
  }
}

// DELETE /studio/schedules/:id · 删除排课（仅未消课可删）
async function deleteStudioScheduleHandler(req, res) {
  try {
    const data = await deleteStudioSchedule(req.params.id);
    if (!data) {
      return fail(res, 404, 40442, "Schedule not found");
    }
    await recordAudit({ actor: req.admin, studioId: req.admin.studioId, action: "schedule.delete", targetType: "schedule", targetId: req.params.id, ip: req.ip });
    return ok(res, data, "schedule deleted");
  } catch (error) {
    const status = /not found|not allowed|已消课|已开始/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40042 : 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getStudioClasses,
  postStudioClass,
  putStudioClass,
  getClassStudents,
  getStudioSchedules,
  postStudioSchedule,
  putStudioSchedule,
  deleteStudioScheduleHandler,
  postStudioScheduleBatch,
  postTeacherSchedule,
  postScheduleAttendance
};

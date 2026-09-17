const { ok, fail } = require("../utils/response");
const {
  listTeacherClasses,
  getTeacherClassStudents,
  listTeacherTimetable,
  listTeacherLeaves,
  reviewTeacherLeave,
  createTeacherPost,
  updateTeacherPost,
  markTeacherPostStudents,
  getTeacherWorkbench,
  teacherAttendSchedule,
  teacherUndoAttendance,
  undoTeacherPostConsumption
} = require("../services/teacherService");

async function getTeacherClasses(req, res) {
  try {
    const data = await listTeacherClasses(req.user.userId);
    return ok(res, data);
  } catch (error) {
    const status = /not found/i.test(error.message) ? 404 : 500;
    return fail(res, status, status === 404 ? 40460 : 50000, error.message || "Internal server error");
  }
}

async function getTeacherStudents(req, res) {
  try {
    const data = await getTeacherClassStudents(req.user.userId, req.params.id, req.query);
    return ok(res, data);
  } catch (error) {
    const status = /not found|does not belong/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40060 : 50000, error.message || "Internal server error");
  }
}

async function getTeacherTimetable(req, res) {
  try {
    const data = await listTeacherTimetable(req.user.userId, req.query);
    return ok(res, data);
  } catch (error) {
    const status = /not found/i.test(error.message) ? 404 : 500;
    return fail(res, status, status === 404 ? 40461 : 50000, error.message || "Internal server error");
  }
}

async function getTeacherLeaves(req, res) {
  try {
    const data = await listTeacherLeaves(req.user.userId, req.query);
    return ok(res, data);
  } catch (error) {
    const status = /not found/i.test(error.message) ? 404 : 500;
    return fail(res, status, status === 404 ? 40462 : 50000, error.message || "Internal server error");
  }
}

async function putTeacherLeave(req, res) {
  try {
    const data = await reviewTeacherLeave(req.user.userId, req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40462, "Leave request not found");
    }

    return ok(res, data, "leave handled");
  } catch (error) {
    const status = /does not belong|already handled|already consumed|not found/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40061 : 50000, error.message || "Internal server error");
  }
}

async function postTeacherPost(req, res) {
  try {
    const data = await createTeacherPost(req.user.userId, req.body);
    return ok(res, data, "teacher post created");
  } catch (error) {
    const status = /not found|does not belong|already consumed|approved leave|match|enrolled|required|canceled/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40062 : 50000, error.message || "Internal server error");
  }
}

async function putTeacherPost(req, res) {
  try {
    const result = await updateTeacherPost(req.user.userId, req.params.id, req.body);
    if (!result) {
      return fail(res, 404, 40463, "帖子不存在");
    }
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "编辑成功");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postTeacherPostStudents(req, res) {
  try {
    const data = await markTeacherPostStudents(req.user.userId, req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40463, "Post not found");
    }

    return ok(res, data, "teacher post students marked");
  } catch (error) {
    const status = /not found|does not belong|already consumed|approved leave|match|enrolled|required|canceled/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40063 : 50000, error.message || "Internal server error");
  }
}

async function getTeacherWorkbenchHandler(req, res) {
  try {
    const data = await getTeacherWorkbench(req.user.userId);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postTeacherScheduleAttendance(req, res) {
  try {
    const data = await teacherAttendSchedule(req.user.userId, req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40464, "Schedule not found");
    }
    return ok(res, data, "attendance submitted");
  } catch (error) {
    const status = /does not belong|not found|not available|exceed|already/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40064 : 50000, error.message || "Internal server error");
  }
}

async function postTeacherScheduleAttendanceUndo(req, res) {
  try {
    const data = await teacherUndoAttendance(req.user.userId, req.params.id, req.body.child_ids);
    return ok(res, data, "attendance undone");
  } catch (error) {
    const status = /does not belong|required|not found/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40065 : 50000, error.message || "Internal server error");
  }
}

async function postTeacherPostStudentsUndo(req, res) {
  try {
    const data = await undoTeacherPostConsumption(req.user.userId, req.params.id, req.body.child_ids);
    return ok(res, data, "post consumption undone");
  } catch (error) {
    const status = /required|not found/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40066 : 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getTeacherClasses,
  getTeacherStudents,
  getTeacherTimetable,
  getTeacherLeaves,
  putTeacherLeave,
  postTeacherPost,
  putTeacherPost,
  postTeacherPostStudents,
  getTeacherWorkbenchHandler,
  postTeacherScheduleAttendance,
  postTeacherScheduleAttendanceUndo,
  postTeacherPostStudentsUndo
};

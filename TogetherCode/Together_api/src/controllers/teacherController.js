const { ok, fail } = require("../utils/response");
const {
  listTeacherClasses,
  listTeacherCourses,
  listTeacherStudents,
  getTeacherClassStudents,
  listTeacherTimetable,
  listTeacherLeaves,
  reviewTeacherLeave,
  createTeacherPost,
  updateTeacherPost,
  markTeacherPostStudents,
  getTeacherWorkbench,
  getTeacherMine,
  teacherAttendSchedule,
  teacherUndoAttendance,
  undoTeacherPostConsumption,
  arrangeTeacherMakeup,
  listTeacherMakeupCandidates
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

async function getTeacherCourses(req, res) {
  try {
    const data = await listTeacherCourses(req.user.userId);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
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

async function getTeacherStudentsAll(req, res) {
  try {
    const data = await listTeacherStudents(req.user.userId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
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

// GET /teacher/leaves/:id/makeup-candidates · 补课候选课次
async function getTeacherMakeupCandidates(req, res) {
  try {
    const data = await listTeacherMakeupCandidates(req.user.userId, req.params.id);
    if (data === null) {
      return fail(res, 404, 40464, "Leave request not found");
    }
    return ok(res, { list: data }, "makeup candidates");
  } catch (error) {
    const status = /does not belong|not found/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40065 : 50000, error.message || "Internal server error");
  }
}

// PUT /teacher/leaves/:id/makeup · 老师安排补课 / 放弃补课
async function putTeacherMakeup(req, res) {
  try {
    const data = await arrangeTeacherMakeup(req.user.userId, req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40463, "Leave request not found");
    }

    const isAbandon = req.body.action === "abandon";
    return ok(res, data, isAbandon ? "makeup abandoned" : "makeup arranged");
  } catch (error) {
    const status = /does not belong|not approved|not found|already|missing|completed|canceled|later/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40062 : 50000, error.message || "Internal server error");
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

async function getTeacherMineHandler(req, res) {
  try {
    const data = await getTeacherMine(req.user.userId);
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
  getTeacherCourses,
  getTeacherStudents,
  getTeacherStudentsAll,
  getTeacherTimetable,
  getTeacherLeaves,
  putTeacherLeave,
  putTeacherMakeup,
  getTeacherMakeupCandidates,
  postTeacherPost,
  putTeacherPost,
  postTeacherPostStudents,
  getTeacherWorkbenchHandler,
  getTeacherMineHandler,
  postTeacherScheduleAttendance,
  postTeacherScheduleAttendanceUndo,
  postTeacherPostStudentsUndo
};

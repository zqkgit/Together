const { ok, fail } = require("../utils/response");
const {
  listStudioStudents,
  consumeStudentLessons,
  listStudentLessonLogs
} = require("../services/studentService");

async function getStudentLessonLogs(req, res) {
  try {
    const data = await listStudentLessonLogs(req.params.id, req.admin.studioId, req.query);
    if (!data) {
      return fail(res, 404, 40430, "学员不存在或不属于该工作室");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getStudioStudents(req, res) {
  try {
    // 强制使用登录工作室维度，忽略前端传入的 studio_id
    const data = await listStudioStudents({ ...req.query, studio_id: req.admin.studioId });
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postConsumeLessons(req, res) {
  try {
    const data = await consumeStudentLessons(req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40430, "Student order not found");
    }

    return ok(res, data, "lesson consumed");
  } catch (error) {
    const status = /not available|not found|exceed/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40030 : 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getStudioStudents,
  postConsumeLessons,
  getStudentLessonLogs
};

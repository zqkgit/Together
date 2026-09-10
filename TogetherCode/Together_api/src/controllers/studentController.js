const { ok, fail } = require("../utils/response");
const { listStudioStudents, consumeStudentLessons } = require("../services/studentService");

async function getStudioStudents(req, res) {
  try {
    const data = await listStudioStudents(req.query);
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
  postConsumeLessons
};

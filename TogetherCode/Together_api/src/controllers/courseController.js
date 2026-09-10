const { ok, fail } = require("../utils/response");
const { listCourses, listStudioCourses, getCourseDetail, createCourse, updateCourse } = require("../services/courseService");

async function getCourses(req, res) {
  try {
    const data = await listCourses(req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getStudioCourses(req, res) {
  try {
    const data = await listStudioCourses(req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getCourse(req, res) {
  try {
    const data = await getCourseDetail(req.params.id);
    if (!data) {
      return fail(res, 404, 40410, "Course not found");
    }

    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postCourse(req, res) {
  try {
    const data = await createCourse(req.body);
    return ok(res, data, "course created");
  } catch (error) {
    const status = /not found|does not belong/i.test(error.message) ? 400 : 500;
    const code = status === 400 ? 40010 : 50000;
    return fail(res, status, code, error.message || "Internal server error");
  }
}

async function putCourse(req, res) {
  try {
    const data = await updateCourse(req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40410, "Course not found");
    }

    return ok(res, data, "course updated");
  } catch (error) {
    const status = /not found|does not belong/i.test(error.message) ? 400 : 500;
    const code = status === 400 ? 40010 : 50000;
    return fail(res, status, code, error.message || "Internal server error");
  }
}

module.exports = {
  getCourses,
  getStudioCourses,
  getCourse,
  postCourse,
  putCourse
};

const { ok, fail } = require("../utils/response");
const { recordAudit } = require("../utils/audit");
const {
  getDashboardOverview,
  getStudios,
  getReviews,
  getSettlements,
  getStudioDetail,
  getStudioReviewDetail,
  reviewStudioApplication,
  banStudio,
  unbanStudio
} = require("../services/adminStore");
const { listPlatformTeachers } = require("../services/adminTeacherService");
const { getTeacherApplications, reviewTeacherApplication } = require("../services/teacherApplicationService");
const { listTags, createTag, updateTag, deleteTag } = require("../services/tagService");
const { generateSettlements, payoutSettlement } = require("../services/settlementService");


async function getOverview(_req, res) {
  return ok(res, await getDashboardOverview());
}

async function getStudiosList(_req, res) {
  return ok(res, await getStudios());
}

async function getStudioDetailById(req, res) {
  const data = await getStudioDetail(req.params.id);
  if (!data) {
    return fail(res, 404, 40470, "Studio not found");
  }

  return ok(res, data);
}

async function getReviewsList(_req, res) {
  return ok(res, await getReviews());
}

async function getReviewDetail(req, res) {
  const data = await getStudioReviewDetail(req.params.id);
  if (!data) {
    return fail(res, 404, 40471, "Studio review not found");
  }

  return ok(res, data);
}

async function putReview(req, res) {
  try {
    const data = await reviewStudioApplication(req.params.id, req.body, req.admin);
    if (!data) {
      return fail(res, 404, 40471, "Studio review not found");
    }

    return ok(res, data, "studio review handled");
  } catch (error) {
    const status = /already handled/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40070 : 50000, error.message || "Internal server error");
  }
}

async function putStudioBan(req, res) {
  try {
    const data = await banStudio(req.params.id, req.body, req.admin);
    if (!data) {
      return fail(res, 404, 40470, "Studio not found");
    }
    await recordAudit({
      actor: req.admin,
      action: "studio.ban",
      target_type: "studio",
      target_id: req.params.id,
      detail: { reason: req.body.reason || "" }
    });
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putStudioUnban(req, res) {
  try {
    const data = await unbanStudio(req.params.id, req.admin);
    if (!data) {
      return fail(res, 404, 40470, "Studio not found");
    }
    await recordAudit({
      actor: req.admin,
      action: "studio.unban",
      target_type: "studio",
      target_id: req.params.id
    });
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getSettlementsData(_req, res) {
  return ok(res, await getSettlements());
}

async function postGenerateSettlements(_req, res) {
  try {
    const result = await generateSettlements();
    return ok(res, result);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postPayoutSettlement(req, res) {
  try {
    const result = await payoutSettlement(req.params.id);
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40070, result.error.message);
    }
    return ok(res, result);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getTeacherApplicationsData(req, res) {
  return ok(res, await getTeacherApplications(req.query));
}

async function putTeacherApplicationReview(req, res) {
  try {
    const result = await reviewTeacherApplication(req.params.id, req.body, req.admin);
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40070, result.error.message);
    }
    await recordAudit({
      actor: req.admin,
      action: `teacher_application.${req.body.action || "review"}`,
      target_type: "teacher_application",
      target_id: req.params.id,
      detail: { reason: req.body.reason || "" }
    });
    return ok(res, result);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getTeachersData(req, res) {
  return ok(res, await listPlatformTeachers(req.query));
}

async function getTagsData(req, res) {
  return ok(res, await listTags(req.query));
}

async function postTag(req, res) {
  try {
    const result = await createTag(req.body);
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40000, result.error.message);
    }
    return ok(res, result);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putTag(req, res) {
  try {
    const result = await updateTag(req.params.id, req.body);
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40000, result.error.message);
    }
    return ok(res, result);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function deleteTagItem(req, res) {
  try {
    const result = await deleteTag(req.params.id);
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40000, result.error.message);
    }
    return ok(res, result);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getOverview,
  getStudiosList,
  getStudioDetailById,
  putStudioBan,
  putStudioUnban,
  getReviewsList,
  getReviewDetail,
  putReview,
  getSettlementsData,
  postGenerateSettlements,
  postPayoutSettlement,
  getTeacherApplicationsData,
  putTeacherApplicationReview,
  getTeachersData,
  getTagsData,
  postTag,
  putTag,
  deleteTagItem
};

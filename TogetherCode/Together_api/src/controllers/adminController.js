const { ok } = require("../utils/response");
const {
  getDashboardOverview,
  getStudios,
  getReviews,
  getStudioDetail,
  getStudioReviewDetail,
  reviewStudioApplication,
  banStudio,
  unbanStudio
} = require("../services/adminStore");
const {
  getSettlements,
  generateSettlements,
  payoutSettlement
} = require("../services/settlementService");
const {
  getTeacherApplications,
  reviewTeacherApplication
} = require("../services/teacherApplicationService");
const {
  listTags,
  createTag,
  updateTag,
  deleteTag
} = require("../services/tagService");
const { listPlatformTeachers } = require("../services/adminTeacherService");
const { fail } = require("../utils/response");

async function getOverview(_req, res) {
  return ok(res, await getDashboardOverview());
}

async function getStudiosList(req, res) {
  return ok(res, await getStudios(req.query));
}

async function getStudioDetailById(req, res) {
  const data = await getStudioDetail(req.params.id);
  if (!data) {
    return fail(res, 404, 40470, "Studio not found");
  }

  return ok(res, data);
}

async function getReviewsList(req, res) {
  return ok(res, await getReviews(req.query));
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

    return ok(res, data, "studio banned");
  } catch (error) {
    const status = /already banned/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40071 : 50000, error.message || "Internal server error");
  }
}

async function putStudioUnban(req, res) {
  try {
    const data = await unbanStudio(req.params.id, req.admin);
    if (!data) {
      return fail(res, 404, 40470, "Studio not found");
    }

    return ok(res, data, "studio unbanned");
  } catch (error) {
    const status = /not banned/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40071 : 50000, error.message || "Internal server error");
  }
}

async function getSettlementsData(_req, res) {
  return ok(res, await getSettlements());
}

async function postGenerateSettlements(req, res) {
  try {
    const data = await generateSettlements(req.admin, req.body);
    return ok(res, data, data.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postPayoutSettlement(req, res) {
  try {
    const result = await payoutSettlement(req.params.id, req.admin);
    if (result.error) {
      return fail(res, result.error.status, result.error.status === 404 ? 40472 : 40072, result.error.message);
    }

    return ok(res, result.data, "打款成功");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// ============ 平台老师认证审核 ============

async function getTeacherApplicationsData(req, res) {
  return ok(res, await getTeacherApplications(req.query));
}

async function putTeacherApplicationReview(req, res) {
  try {
    const result = await reviewTeacherApplication(req.params.id, req.body, req.admin);
    if (result.error) {
      return fail(res, result.error.status, result.error.status === 404 ? 40482 : 40082, result.error.message);
    }

    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// ============ 平台老师管理 ============

async function getTeachersData(req, res) {
  try {
    const data = await listPlatformTeachers(req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// ============ 标签管理 ============

async function getTagsData(req, res) {
  return ok(res, await listTags(req.query));
}

async function postTag(req, res) {
  const result = await createTag(req.body);
  if (result.error) {
    return fail(res, result.error.status, result.error.status === 404 ? 40483 : 40083, result.error.message);
  }
  return ok(res, result.data, "标签已创建");
}

async function putTag(req, res) {
  const result = await updateTag(req.params.id, req.body);
  if (result.error) {
    return fail(res, result.error.status, result.error.status === 404 ? 40483 : 40083, result.error.message);
  }
  return ok(res, result.data, "标签已更新");
}

async function deleteTagItem(req, res) {
  const result = await deleteTag(req.params.id);
  if (result.error) {
    return fail(res, result.error.status, result.error.status === 404 ? 40483 : 40083, result.error.message);
  }
  return ok(res, result.data, result.message);
}

module.exports = {
  getOverview,
  getStudiosList,
  getStudioDetailById,
  getReviewsList,
  getReviewDetail,
  putReview,
  putStudioBan,
  putStudioUnban,
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

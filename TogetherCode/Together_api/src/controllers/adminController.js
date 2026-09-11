const { ok, fail } = require("../utils/response");
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
const {
  getSettlements: fetchSettlements,
  generateSettlements,
  payoutSettlement
} = require("../services/settlementService");
const {
  getTeacherApplications,
  reviewTeacherApplication
} = require("../services/teacherApplicationService");
const { listPlatformTeachers } = require("../services/adminTeacherService");
const {
  listTags,
  createTag,
  updateTag,
  deleteTag
} = require("../services/tagService");

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

async function putStudioBan(req, res) {
  try {
    const data = await banStudio(req.params.id, req.body, req.admin);
    if (!data) {
      return fail(res, 404, 40470, "Studio not found");
    }
    return ok(res, data, "工作室已封禁");
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
    return ok(res, data, "工作室已解封");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
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

async function getSettlementsData(_req, res) {
  return ok(res, await fetchSettlements());
}

async function postGenerateSettlements(req, res) {
  try {
    const data = await generateSettlements(req.admin, req.body);
    return ok(res, data, "结算单已生成");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postPayoutSettlement(req, res) {
  try {
    const data = await payoutSettlement(req.params.id, req.admin);
    return ok(res, data, "已发起打款");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getTeacherApplicationsData(req, res) {
  return ok(res, await getTeacherApplications(req.query));
}

async function putTeacherApplicationReview(req, res) {
  try {
    const data = await reviewTeacherApplication(req.params.id, req.body, req.admin);
    if (!data) {
      return fail(res, 404, 40472, "Teacher application not found");
    }
    return ok(res, data, "老师认证已处理");
  } catch (error) {
    const status = /already handled/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40071 : 50000, error.message || "Internal server error");
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
    const data = await createTag(req.body);
    return ok(res, data, "标签已创建");
  } catch (error) {
    const status = /exists/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40072 : 50000, error.message || "Internal server error");
  }
}

async function putTag(req, res) {
  try {
    const data = await updateTag(req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40473, "Tag not found");
    }
    return ok(res, data, "标签已更新");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function deleteTagItem(req, res) {
  try {
    const data = await deleteTag(req.params.id);
    if (!data) {
      return fail(res, 404, 40473, "Tag not found");
    }
    return ok(res, data, "标签已删除");
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

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
const { listTopics, createTopic, updateTopic, deleteTopic } = require("../services/topicService");
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

// 结算单导出（全量）
async function exportSettlementsData(_req, res) {
  try {
    const data = await getSettlements();
    return ok(res, { list: data.list });
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
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

async function getTopicsData(req, res) {
  return ok(res, await listTopics(req.query));
}

async function postTopic(req, res) {
  try {
    const result = await createTopic(req.body);
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40000, result.error.message);
    }
    return ok(res, result);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putTopic(req, res) {
  try {
    const result = await updateTopic(req.params.id, req.body);
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40000, result.error.message);
    }
    return ok(res, result);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function deleteTopicItem(req, res) {
  try {
    const result = await deleteTopic(req.params.id);
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40000, result.error.message);
    }
    return ok(res, result);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

const { listAdminCourseReviews, auditCourseReview } = require("../services/reviewService");

/** 课程评价列表（管理端） */
async function getCourseReviewsList(req, res) {
  try {
    return ok(res, await listAdminCourseReviews(req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 课程评价审核：approve 通过 / reject 驳回 */
async function putCourseReviewAudit(req, res) {
  try {
    const result = await auditCourseReview(req.params.id, req.body.action, req.body.reason);
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40000, result.error.message);
    }
    await recordAudit({
      actor: req.admin,
      action: req.body.action === "approve" ? "course_review.approve" : "course_review.reject",
      target_type: "course_review",
      target_id: req.params.id,
      detail: { reason: req.body.reason || "" }
    });
    return ok(res, result, req.body.action === "approve" ? "评价已通过" : "评价已驳回");
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
  getCourseReviewsList,
  putCourseReviewAudit,
  getSettlementsData,
  exportSettlementsData,
  postGenerateSettlements,
  postPayoutSettlement,
  getTeacherApplicationsData,
  putTeacherApplicationReview,
  getTeachersData,
  getTagsData,
  postTag,
  putTag,
  deleteTagItem,
  getTopicsData,
  postTopic,
  putTopic,
  deleteTopicItem
};

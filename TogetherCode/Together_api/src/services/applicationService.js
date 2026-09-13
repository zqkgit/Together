const { TeacherApplication, TeacherProfile, StudioProfile } = require("../models");
const { generateId } = require("../utils/id");

function assertNoPending(current, message) {
  if (current && Number(current.status) === 0) {
    return { error: { status: 400, code: 40021, message } };
  }
  return null;
}

/**
 * 老师向工作室提交合作申请（工作室审核）。
 * 前置：老师必须已通过平台老师认证（存在 TeacherProfile 且 cert_status=1）。
 * 与 /v1/auth/role/apply（平台认证：老师认证 / 工作室入驻）分工：
 *  - role/apply → teacher/studio 平台认证申请
 *  - 本接口   → 已认证老师向指定工作室申请合作（teacher_applications.studio_id = 目标工作室）
 */
async function applyStudioCooperation(userId, studioId, payload = {}) {
  const studio = await StudioProfile.findByPk(studioId);
  if (!studio || Number(studio.status) !== 1) {
    return { error: { status: 404, code: 40412, message: "工作室不存在或未通过认证" } };
  }

  const profile = await TeacherProfile.findOne({ where: { user_id: userId } });
  if (!profile || Number(profile.cert_status) !== 1) {
    return { error: { status: 400, code: 40023, message: "请先通过平台老师认证，再申请工作室合作" } };
  }

  const existing = await TeacherApplication.findOne({
    where: { user_id: userId, studio_id: studioId, status: 0 }
  });
  const conflict = assertNoPending(existing, "已向该工作室提交过合作申请，请等待处理");
  if (conflict) return conflict;

  const row = await TeacherApplication.create({
    id: generateId(),
    user_id: userId,
    studio_id: studioId,
    real_name: profile.real_name,
    subjects: profile.subjects || [],
    years: profile.years,
    intro: String(payload.intro || profile.intro || "").trim() || null,
    version: 1,
    status: 0,
    submitted_at: new Date()
  });

  return { data: { id: String(row.id), status: 0, studio_id: String(studioId) } };
}

module.exports = {
  applyStudioCooperation
};

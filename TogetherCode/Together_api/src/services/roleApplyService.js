const { Op } = require("sequelize");
const { sequelize, TeacherApplication, StudioApplication, TeacherProfile, StudioProfile } = require("../models");
const { generateId } = require("../utils/id");

const ROLE_META = {
  teacher: {
    model: TeacherApplication,
    profileModel: TeacherProfile,
    required: ["real_name"],
    fields: ["real_name", "subjects", "years", "intro", "cert_no", "portfolio"],
    label: "老师认证"
  },
  studio: {
    model: StudioApplication,
    profileModel: StudioProfile,
    required: ["name"],
    fields: ["name", "cover", "intro", "address", "phone", "license", "permit", "photos"],
    label: "工作室入驻"
  }
};

/**
 * App 端提交老师认证 / 工作室入驻申请
 * 口径：
 * - 已有生效档案（teacher_profiles / studio_profiles）→ 拒绝
 * - 已有待审核申请 → 拒绝（提示等待审核）
 * - 此前被驳回 → 允许重新提交，version + 1 留痕
 */
async function submitRoleApply(userId, { role, payload = {} }) {
  const meta = ROLE_META[role];
  if (!meta) {
    return { error: { status: 400, code: 40000, message: "role 仅支持 teacher / studio" } };
  }

  const missing = meta.required.find((field) => !payload?.[field]?.toString().trim());
  if (missing) {
    return { error: { status: 400, code: 40000, message: `缺少必填字段：${missing}` } };
  }

  // 已生效档案（通过认证/入驻）则无需申请
  const profile = await meta.profileModel.findOne({
    where:
      role === "teacher"
        ? { user_id: userId }
        : { user_id: userId }
  });
  if (profile) {
    const label = role === "teacher" ? "您已通过老师认证" : "您已是入驻工作室";
    return { error: { status: 400, code: 40010, message: label } };
  }

  // 待审核申请拦截
  const pending = await meta.model.findOne({
    where: { user_id: userId, status: 0 }
  });
  if (pending) {
    return {
      error: { status: 400, code: 40011, message: "您已有待审核的申请，请等待平台审核" }
    };
  }

  // 历史最大版本（被驳回后重提，version+1 留痕）
  const latest = await meta.model.findOne({
    where: { user_id: userId },
    order: [["version", "DESC"]]
  });
  const version = latest ? Number(latest.version) + 1 : 1;

  const data = { id: generateId(), user_id: userId, version, status: 0, submitted_at: new Date() };
  for (const field of meta.fields) {
    if (payload[field] !== undefined && payload[field] !== null && payload[field] !== "") {
      data[field] = payload[field];
    }
  }
  if (role === "teacher") {
    data.studio_id = null; // 平台老师认证申请（不绑定工作室）
  }

  const application = await meta.model.create(data);

  return {
    data: {
      id: String(application.id),
      role,
      status: "pending",
      version: Number(application.version),
      submitted_at: application.submitted_at
    }
  };
}

/**
 * App 端查询认证申请状态
 * 返回：unauth（从未申请）/ pending / approved / rejected
 */
async function getRoleApplyStatus(userId, role) {
  const meta = ROLE_META[role];
  if (!meta) {
    return { error: { status: 400, code: 40000, message: "role 仅支持 teacher / studio" } };
  }

  const profile = await meta.profileModel.findOne({ where: { user_id: userId } });
  const latest = await meta.model.findOne({
    where: { user_id: userId },
    order: [["version", "DESC"]]
  });

  // 已生效档案优先
  if (profile) {
    return {
      data: {
        role,
        status: "approved",
        version: latest ? Number(latest.version) : 0,
        reason: null,
        submitted_at: latest ? latest.submitted_at : null,
        reviewed_at: latest ? latest.reviewed_at : null
      }
    };
  }

  if (!latest) {
    return {
      data: {
        role,
        status: "unauth",
        version: 0,
        reason: null,
        submitted_at: null,
        reviewed_at: null
      }
    };
  }

  const statusMap = { 0: "pending", 1: "approved", 2: "rejected" };
  return {
    data: {
      role,
      status: statusMap[Number(latest.status)] || "pending",
      version: Number(latest.version),
      reason: latest.review_reason || null,
      submitted_at: latest.submitted_at,
      reviewed_at: latest.reviewed_at
    }
  };
}

module.exports = {
  submitRoleApply,
  getRoleApplyStatus
};

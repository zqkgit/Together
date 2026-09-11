const { AuditLog } = require("../models");

/**
 * 通用操作审计打点（Web 管理端：平台 / 工作室）。
 * 调用方传入操作人信息，失败不阻断主流程。
 */
async function recordAudit({ actor, role, studioId = null, action, targetType = null, targetId = null, detail = null, ip = null }) {
  try {
    await AuditLog.create({
      actor_id: actor?.admin_id || actor?.adminId || null,
      actor_name: actor?.username || actor?.name || null,
      role: role || actor?.role || "unknown",
      studio_id: studioId || actor?.studio_id || actor?.studioId || null,
      action,
      target_type: targetType,
      target_id: targetId ? String(targetId) : null,
      detail: detail ? (typeof detail === "string" ? detail : JSON.stringify(detail)) : null,
      ip
    });
  } catch (error) {
    // 审计失败不阻断业务
  }
  return null;
}

module.exports = { recordAudit };

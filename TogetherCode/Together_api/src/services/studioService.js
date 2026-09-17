const { StudioProfile, User, LeaveRequest, Class } = require("../models");
const { reviewLeaveRequest } = require("./leaveService");

function normalizeStudioProfile(studio) {
  return {
    studio_id: String(studio.studio_id),
    user_id: String(studio.user_id),
    name: studio.name,
    cover: studio.cover,
    type_tags: studio.type_tags || [],
    intro: studio.intro,
    address: studio.address,
    lng: studio.lng,
    lat: studio.lat,
    phone: studio.phone,
    hours: studio.hours,
    license: studio.license,
    legal_id: studio.legal_id,
    permit: studio.permit,
    photos: studio.photos || [],
    settle_rate: Number(studio.settle_rate),
    plan_tier: studio.plan_tier,
    status: studio.status,
    banned_at: studio.banned_at,
    ban_reason: studio.ban_reason,
    owner: studio.owner
      ? {
          user_id: String(studio.owner.user_id),
          phone: studio.owner.phone,
          nickname: studio.owner.nickname,
          avatar: studio.owner.avatar,
          city: studio.owner.city
        }
      : null
  };
}

async function getStudioProfile(studioId) {
  const studio = await StudioProfile.findByPk(studioId, {
    include: [
      {
        model: User,
        as: "owner",
        attributes: ["user_id", "phone", "nickname", "avatar", "city"]
      }
    ]
  });

  if (!studio) {
    return null;
  }

  return normalizeStudioProfile(studio);
}

async function updateStudioProfile(studioId, payload) {
  const studio = await StudioProfile.findByPk(studioId, {
    include: [
      {
        model: User,
        as: "owner",
        attributes: ["user_id", "phone", "nickname", "avatar", "city"]
      }
    ]
  });

  if (!studio) {
    return null;
  }

  await studio.update(
    {
      name: payload.name ?? studio.name,
      cover: payload.cover ?? studio.cover,
      type_tags: payload.type_tags ?? studio.type_tags,
      intro: payload.intro ?? studio.intro,
      address: payload.address ?? studio.address,
      lng: payload.lng ?? studio.lng,
      lat: payload.lat ?? studio.lat,
      phone: payload.phone ?? studio.phone,
      hours: payload.hours ?? studio.hours,
      license: payload.license ?? studio.license,
      legal_id: payload.legal_id ?? studio.legal_id,
      permit: payload.permit ?? studio.permit,
      photos: payload.photos ?? studio.photos
    }
  );

  return normalizeStudioProfile(studio);
}

module.exports = {
  getStudioProfile,
  updateStudioProfile,
  reviewStudioLeave
};

// 工作室审批请假（出勤消课弹窗内直接处理待审批）
async function reviewStudioLeave(studioId, leaveId, payload) {
  const { Course } = require("../models");
  const leave = await LeaveRequest.findByPk(leaveId, {
    include: [
      {
        model: Class,
        as: "classItem",
        attributes: ["class_id", "course_id"],
        include: [
          {
            model: Course,
            as: "course",
            attributes: ["course_id", "studio_id"]
          }
        ]
      }
    ]
  });

  if (!leave) {
    return null;
  }

  if (String(leave.classItem?.course?.studio_id || "") !== String(studioId)) {
    throw new Error("Leave request does not belong to studio");
  }

  return reviewLeaveRequest(leaveId, {
    action: payload.agree ? "agree" : "reject",
    note: payload.note || undefined
  });
}

const { Child, ChildCourseBalance, Order, Course, StudioProfile } = require("../models");

function formatChildBase(child) {
  return {
    child_id: String(child.child_id),
    nickname: child.nickname,
    avatar: child.avatar,
    birthday: child.birthday,
    gender: child.gender
  };
}

function formatChildBalance(balance) {
  return {
    balance_id: String(balance.balance_id),
    order_id: String(balance.order_id),
    course_id: String(balance.course_id),
    studio_id: balance.order?.studio ? String(balance.order.studio.studio_id) : null,
    studio_name: balance.order?.studio?.name || null,
    course_title: balance.course?.title || "-",
    total_lessons: balance.total_lessons,
    consumed_lessons: balance.consumed_lessons,
    refunded_lessons: balance.refunded_lessons,
    remaining_lessons: balance.remaining_lessons,
    valid_from: balance.valid_from,
    valid_to: balance.valid_to,
    status: balance.status
  };
}

function formatChild(child) {
  const balances = (child.balances || []).map(formatChildBalance);
  const totalRemainingLessons = balances.reduce(
    (sum, item) => sum + Number(item.remaining_lessons || 0),
    0
  );

  return {
    ...formatChildBase(child),
    total_remaining_lessons: totalRemainingLessons,
    status: totalRemainingLessons > 0 ? "active" : "empty",
    balances
  };
}

async function listChildren(parentUserId) {
  const rows = await Child.findAll({
    where: {
      parent_user_id: parentUserId
    },
    include: [
      {
        model: ChildCourseBalance,
        as: "balances",
        required: false,
        include: [
          {
            model: Order,
            as: "order",
            attributes: ["order_id", "studio_id"],
            include: [
              {
                model: StudioProfile,
                as: "studio",
                attributes: ["studio_id", "name"]
              }
            ]
          },
          {
            model: Course,
            as: "course",
            attributes: ["course_id", "title", "cover"]
          }
        ]
      }
    ],
    order: [
      ["created_at", "DESC"],
      [{ model: ChildCourseBalance, as: "balances" }, "created_at", "DESC"]
    ]
  });

  return {
    total: rows.length,
    list: rows.map(formatChild)
  };
}

async function getChildDetail(parentUserId, childId) {
  const row = await Child.findOne({
    where: {
      child_id: childId,
      parent_user_id: parentUserId
    },
    include: [
      {
        model: ChildCourseBalance,
        as: "balances",
        required: false,
        include: [
          {
            model: Order,
            as: "order",
            attributes: ["order_id", "studio_id"],
            include: [
              {
                model: StudioProfile,
                as: "studio",
                attributes: ["studio_id", "name"]
              }
            ]
          },
          {
            model: Course,
            as: "course",
            attributes: ["course_id", "title", "cover"]
          }
        ]
      }
    ],
    order: [[{ model: ChildCourseBalance, as: "balances" }, "created_at", "DESC"]]
  });

  if (!row) {
    return null;
  }

  return formatChild(row);
}

async function createChild(parentUserId, payload) {
  const child = await Child.create({
    parent_user_id: parentUserId,
    nickname: payload.nickname,
    avatar: payload.avatar || null,
    birthday: payload.birthday,
    gender: payload.gender ?? 0
  });

  return formatChild({
    ...child.toJSON(),
    balances: []
  });
}

async function updateChild(parentUserId, childId, payload) {
  const child = await Child.findOne({
    where: {
      child_id: childId,
      parent_user_id: parentUserId
    }
  });

  if (!child) {
    return null;
  }

  await child.update({
    nickname: payload.nickname ?? child.nickname,
    avatar: payload.avatar ?? child.avatar,
    birthday: payload.birthday ?? child.birthday,
    gender: payload.gender ?? child.gender
  });

  return getChildDetail(parentUserId, childId);
}

module.exports = {
  listChildren,
  getChildDetail,
  createChild,
  updateChild
};

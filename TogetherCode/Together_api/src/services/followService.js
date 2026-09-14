const { UserFollow } = require("../models");
const { Op } = require("sequelize");

/**
 * 关注用户（幂等）
 * @returns {Promise<{followed: boolean}>}
 */
async function followUser(followerId, followeeId) {
  if (String(followerId) === String(followeeId)) {
    return { error: { status: 400, code: 40061, message: "不能关注自己" } };
  }
  const existed = await UserFollow.findOne({
    where: { follower_id: followerId, followee_id: followeeId }
  });
  if (existed) {
    return { followed: true };
  }
  await UserFollow.create({ follower_id: followerId, followee_id: followeeId });
  return { followed: true };
}

/**
 * 取消关注（幂等）
 */
async function unfollowUser(followerId, followeeId) {
  const removed = await UserFollow.destroy({
    where: { follower_id: followerId, followee_id: followeeId }
  });
  return { followed: false, removed: removed > 0 };
}

/**
 * 是否已关注
 */
async function isFollowing(followerId, followeeId) {
  if (!followerId || !followeeId) return false;
  const count = await UserFollow.count({
    where: { follower_id: followerId, followee_id: followeeId }
  });
  return count > 0;
}

/**
 * 我的关注列表（用户）
 */
async function listFollowing(userId, page = 1, size = 20) {
  const { rows, count } = await UserFollow.findAndCountAll({
    where: { follower_id: userId },
    include: [{ association: "followee", attributes: ["user_id", "nickname", "avatar", "current_role"] }],
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });
  return {
    total: count,
    page,
    size,
    list: rows.map((row) => {
      const u = row.followee;
      return u
        ? {
            user_id: String(u.user_id),
            nickname: u.nickname || "艺启用户",
            avatar: u.avatar || null,
            role: u.current_role !== undefined ? Number(u.current_role) : null
          }
        : null;
    }).filter(Boolean)
  };
}

/**
 * 我的粉丝列表（用户）
 */
async function listFollowers(userId, page = 1, size = 20) {
  const { rows, count } = await UserFollow.findAndCountAll({
    where: { followee_id: userId },
    include: [{ association: "follower", attributes: ["user_id", "nickname", "avatar", "current_role"] }],
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });
  return {
    total: count,
    page,
    size,
    list: rows.map((row) => {
      const u = row.follower;
      return u
        ? {
            user_id: String(u.user_id),
            nickname: u.nickname || "艺启用户",
            avatar: u.avatar || null,
            role: u.current_role !== undefined ? Number(u.current_role) : null
          }
        : null;
    }).filter(Boolean)
  };
}

module.exports = {
  followUser,
  unfollowUser,
  isFollowing,
  listFollowing,
  listFollowers
};

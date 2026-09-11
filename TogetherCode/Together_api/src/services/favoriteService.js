/**
 * 收藏：课程 / 老师 / 工作室通用
 */
const { Op } = require("sequelize");
const { Favorite, Course, TeacherProfile, StudioProfile, User, Post } = require("../models");

const TARGET_TYPES = ["course", "teacher", "studio", "post"];
const DEFAULT_TARGET = "course";

async function addFavorite(userId, payload) {
  const targetType = TARGET_TYPES.includes(payload.target_type) ? payload.target_type : DEFAULT_TARGET;
  const targetId = String(payload.target_id).trim();
  if (!targetId) return { error: { status: 400, code: 40076, message: "target_id is required" } };

  // 校验目标存在（雪花 id 超 JS 安全整数，必须字符串查询）
  const model =
    targetType === "course" ? Course
    : targetType === "teacher" ? TeacherProfile
    : targetType === "studio" ? StudioProfile
    : Post;
  const exists = await model.findByPk(targetId);
  if (!exists) return { error: { status: 404, code: 40476, message: "收藏对象不存在" } };

  const [favorite, created] = await Favorite.findOrCreate({
    where: { user_id: userId, target_type: targetType, target_id: targetId }
  });
  return { favorite_id: String(favorite.favorite_id), is_new: created };
}

async function removeFavorite(userId, payload) {
  const targetType = TARGET_TYPES.includes(payload.target_type) ? payload.target_type : DEFAULT_TARGET;
  const targetId = String(payload.target_id).trim();
  if (!targetId) return { error: { status: 400, code: 40076, message: "target_id is required" } };

  const deleted = await Favorite.destroy({
    where: { user_id: userId, target_type: targetType, target_id: targetId }
  });
  return { removed: deleted > 0 };
}

/** 已收藏 id 列表（详情页按钮状态） */
async function listFavoriteIds(userId, targetType = DEFAULT_TARGET) {
  const type = TARGET_TYPES.includes(targetType) ? targetType : DEFAULT_TARGET;
  const rows = await Favorite.findAll({
    where: { user_id: userId, target_type: type },
    attributes: ["target_id"],
    raw: true
  });
  return rows.map((r) => String(r.target_id));
}

/** 我的收藏列表（按类型返回实体详情） */
async function listFavorites(userId, query = {}) {
  const targetType = TARGET_TYPES.includes(query.target_type) ? query.target_type : DEFAULT_TARGET;
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.page_size) || 10, 30);

  const { count, rows } = await Favorite.findAndCountAll({
    where: { user_id: userId, target_type: targetType },
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  const ids = rows.map((r) => String(r.target_id));
  let items = [];

  if (ids.length) {
    if (targetType === "course") {
      const courses = await Course.findAll({ where: { course_id: { [Op.in]: ids } } });
      const byId = {};
      courses.forEach((c) => (byId[c.course_id] = c));
      items = rows
        .filter((r) => byId[r.target_id])
        .map((r) => {
          const c = byId[r.target_id];
          return {
            target_id: String(c.course_id),
            title: c.title,
            cover: c.cover || null,
            price: c.price,
            subtitle: `¥${(Number(c.price) / 100).toFixed(2)} 起`
          };
        });
    } else if (targetType === "teacher") {
      const teachers = await TeacherProfile.findAll({
        where: { teacher_id: { [Op.in]: ids } },
        include: [{ model: User, as: "user", attributes: ["user_id", "nickname", "avatar"] }]
      });
      const byId = {};
      teachers.forEach((t) => (byId[t.teacher_id] = t));
      items = rows
        .filter((r) => byId[r.target_id])
        .map((r) => {
          const t = byId[r.target_id];
          return {
            target_id: String(t.teacher_id),
            title: t.user?.nickname || t.real_name || "老师",
            cover: t.user?.avatar || null,
            subtitle: (t.subjects || []).slice(0, 2).join(" / ") || `评分 ${t.rating}`,
            rating: Number(t.rating || 0)
          };
        });
    } else if (targetType === "post") {
      const posts = await Post.findAll({ where: { post_id: { [Op.in]: ids } } });
      const byId = {};
      posts.forEach((p) => (byId[p.post_id] = p));
      items = rows
        .filter((r) => byId[r.target_id])
        .map((r) => {
          const p = byId[r.target_id];
          const imgs = p.images || [];
          return {
            target_id: String(p.post_id),
            title: (p.content || "作品").slice(0, 30),
            cover: imgs[0] || null,
            subtitle: `${p.like_count || 0} 赞 · ${p.comment_count || 0} 评论`
          };
        });
    } else {

      const byId = {};
      studios.forEach((s) => (byId[s.studio_id] = s));
      items = rows
        .filter((r) => byId[r.target_id])
        .map((r) => {
          const s = byId[r.target_id];
          return {
            target_id: String(s.studio_id),
            title: s.name,
            cover: s.cover || null,
            subtitle: s.address || (s.type_tags || []).slice(0, 2).join(" / ")
          };
        });
    }
  }

  return { total: count, page, page_size: size, target_type: targetType, list: items };
}

module.exports = {
  addFavorite,
  removeFavorite,
  listFavoriteIds,
  listFavorites
};

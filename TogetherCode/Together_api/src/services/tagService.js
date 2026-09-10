const { Op } = require("sequelize");
const { Tag } = require("../models");
const { generateId } = require("../utils/id");

const TAG_SCOPE = {
  STUDIO: 1,
  TEACHER: 2,
  COMMON: 3
};

function normalizeTag(row) {
  return {
    tag_id: String(row.tag_id),
    name: row.name,
    scope: Number(row.scope),
    sort: Number(row.sort),
    status: Number(row.status)
  };
}

/**
 * 标签列表（管理端：全部；应用端 onlyActive=true 只返回启用）
 */
async function listTags(query = {}, onlyActive = false) {
  const where = {};
  if (query.scope !== undefined && query.scope !== null && query.scope !== "") {
    where.scope = Number(query.scope);
  }
  if (query.q) {
    where.name = { [Op.like]: `%${query.q.trim()}%` };
  }
  if (onlyActive) {
    where.status = 1;
  }

  const rows = await Tag.findAll({
    where,
    order: [
      ["scope", "ASC"],
      ["sort", "ASC"],
      ["created_at", "DESC"]
    ]
  });

  return rows.map(normalizeTag);
}

async function createTag(payload) {
  const name = (payload.name || "").trim();
  if (!name) {
    return { error: { status: 400, message: "标签名称不能为空" } };
  }
  if (name.length > 40) {
    return { error: { status: 400, message: "标签名称不能超过 40 字" } };
  }

  const scope = Number(payload.scope || TAG_SCOPE.COMMON);
  const duplicate = await Tag.findOne({ where: { name, scope, status: 1 } });
  if (duplicate) {
    return { error: { status: 400, message: "同场景下已存在同名标签" } };
  }

  const row = await Tag.create({
    tag_id: generateId(),
    name,
    scope,
    sort: Number(payload.sort || 0),
    status: 1
  });
  return { data: normalizeTag(row) };
}

async function updateTag(id, payload) {
  const row = await Tag.findByPk(id);
  if (!row) {
    return { error: { status: 404, message: "标签不存在" } };
  }

  const update = {};
  if (payload.name !== undefined) {
    const name = (payload.name || "").trim();
    if (!name) {
      return { error: { status: 400, message: "标签名称不能为空" } };
    }
    if (name.length > 40) {
      return { error: { status: 400, message: "标签名称不能超过 40 字" } };
    }
    update.name = name;
  }
  if (payload.scope !== undefined && payload.scope !== null && payload.scope !== "") {
    update.scope = Number(payload.scope);
  }
  if (payload.sort !== undefined && payload.sort !== null && payload.sort !== "") {
    update.sort = Number(payload.sort);
  }
  if (payload.status !== undefined && payload.status !== null && payload.status !== "") {
    update.status = Number(payload.status);
  }

  if (Object.keys(update).length === 0) {
    return { error: { status: 400, message: "没有可更新的字段" } };
  }

  await row.update(update);
  const latest = await Tag.findByPk(id);
  return { data: normalizeTag(latest) };
}

/**
 * 删除（软删：停用），已停用的直接删除记录
 */
async function deleteTag(id) {
  const row = await Tag.findByPk(id);
  if (!row) {
    return { error: { status: 404, message: "标签不存在" } };
  }

  if (Number(row.status) === 1) {
    await row.update({ status: 0 });
    return { data: { tag_id: String(id), status: 0 }, message: "标签已停用" };
  }

  await row.destroy();
  return { data: { tag_id: String(id), deleted: true }, message: "标签已删除" };
}

module.exports = {
  TAG_SCOPE,
  listTags,
  createTag,
  updateTag,
  deleteTag
};

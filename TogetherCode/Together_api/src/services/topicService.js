const { Op } = require("sequelize");
const { Topic } = require("../models");
const { generateId } = require("../utils/id");

function normalizeTopic(row) {
  return {
    topic_id: String(row.topic_id),
    name: row.name,
    status: Number(row.status),
    sort: Number(row.sort)
  };
}

/**
 * 话题列表（管理端：全部；应用端 onlyActive=true 只返回上架）
 */
async function listTopics(query = {}, onlyActive = false) {
  const where = {};
  if (query.q) {
    where.name = { [Op.like]: `%${query.q.trim()}%` };
  }
  if (onlyActive) {
    where.status = 1;
  }

  const rows = await Topic.findAll({
    where,
    order: [
      ["sort", "ASC"],
      ["created_at", "DESC"]
    ]
  });

  return rows.map(normalizeTopic);
}

async function createTopic(payload) {
  const name = (payload.name || "").trim();
  if (!name) {
    return { error: { status: 400, message: "话题名称不能为空" } };
  }
  if (name.length > 40) {
    return { error: { status: 400, message: "话题名称不能超过 40 字" } };
  }

  const duplicate = await Topic.findOne({ where: { name, status: 1 } });
  if (duplicate) {
    return { error: { status: 400, message: "已存在同名话题" } };
  }

  const row = await Topic.create({
    topic_id: generateId(),
    name,
    sort: Number(payload.sort || 0),
    status: 1
  });
  return { data: normalizeTopic(row) };
}

async function updateTopic(id, payload) {
  const row = await Topic.findByPk(id);
  if (!row) {
    return { error: { status: 404, message: "话题不存在" } };
  }

  const update = {};
  if (payload.name !== undefined) {
    const name = (payload.name || "").trim();
    if (!name) {
      return { error: { status: 400, message: "话题名称不能为空" } };
    }
    if (name.length > 40) {
      return { error: { status: 400, message: "话题名称不能超过 40 字" } };
    }
    update.name = name;
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
  const latest = await Topic.findByPk(id);
  return { data: normalizeTopic(latest) };
}

/**
 * 删除（软删：下架），已下架的直接删除记录
 */
async function deleteTopic(id) {
  const row = await Topic.findByPk(id);
  if (!row) {
    return { error: { status: 404, message: "话题不存在" } };
  }

  if (Number(row.status) === 1) {
    await row.update({ status: 0 });
    return { data: { topic_id: String(id), status: 0 }, message: "话题已下架" };
  }

  await row.destroy();
  return { data: { topic_id: String(id), deleted: true }, message: "话题已删除" };
}

module.exports = {
  listTopics,
  createTopic,
  updateTopic,
  deleteTopic
};

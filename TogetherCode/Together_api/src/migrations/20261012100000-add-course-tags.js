"use strict";

/**
 * 课程标签关联：courses 新增 tags JSON 数组字段（存储 tag_id 列表）
 * - 支持按标签筛选课程（/courses?tag=<tag_id>）
 * - 与 tags 表多对多关系用 JSON 数组实现（轻量方案，无需关联表）
 */
module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn("courses", "tags", {
      type: Sequelize.JSON,
      allowNull: true,
      comment: "课程关联标签ID列表，如 [\"123456\",\"789012\"]"
    });
  },

  down: async (queryInterface) => {
    await queryInterface.removeColumn("courses", "tags");
  }
};
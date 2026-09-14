"use strict";

/**
 * 评论回复：post_comments 增加 parent_id（0 = 顶级评论，否则为被回复评论 id）
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn("post_comments", "parent_id", {
      type: Sequelize.BIGINT,
      allowNull: false,
      defaultValue: 0
    });
    await queryInterface.addIndex("post_comments", ["parent_id"]);
  },

  async down(queryInterface) {
    await queryInterface.removeColumn("post_comments", "parent_id");
  }
};

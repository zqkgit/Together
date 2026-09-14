"use strict";

/**
 * 评论点赞：
 *  - post_comment_likes 评论点赞关系（comment_id + user_id 唯一）
 *  - post_comments.like_count 评论点赞数
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable("post_comment_likes", {
      id: {
        type: Sequelize.BIGINT,
        primaryKey: true,
        allowNull: false
      },
      comment_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      user_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.literal("CURRENT_TIMESTAMP")
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.literal("CURRENT_TIMESTAMP")
      }
    });
    await queryInterface.addIndex("post_comment_likes", ["comment_id"]);
    await queryInterface.addIndex("post_comment_likes", ["comment_id", "user_id"], { unique: true });

    await queryInterface.addColumn("post_comments", "like_count", {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 0
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn("post_comments", "like_count");
    await queryInterface.dropTable("post_comment_likes");
  }
};

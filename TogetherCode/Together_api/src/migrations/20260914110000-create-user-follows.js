"use strict";

/**
 * 用户关注关系：
 *  - user_follows 用户互关（家长/老师互相关注），帖子详情 "+关注" 关注作者
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable("user_follows", {
      id: {
        type: Sequelize.BIGINT,
        primaryKey: true,
        allowNull: false
      },
      follower_id: {
        type: Sequelize.BIGINT,
        allowNull: false,
        comment: "关注者"
      },
      followee_id: {
        type: Sequelize.BIGINT,
        allowNull: false,
        comment: "被关注者"
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
    await queryInterface.addIndex("user_follows", ["follower_id"]);
    await queryInterface.addIndex("user_follows", ["followee_id"]);
    await queryInterface.addIndex("user_follows", ["follower_id", "followee_id"], { unique: true });
  },

  async down(queryInterface) {
    await queryInterface.dropTable("user_follows");
  }
};

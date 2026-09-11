"use strict";

/**
 * 家长端互动补充：
 *  - course_reviews 课程评价（家长购买后评分 + 文字，一课程一用户一评）
 *  - favorites     收藏（课程/老师/工作室通用，target_type + target_id）
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable("course_reviews", {
      review_id: {
        type: Sequelize.BIGINT,
        primaryKey: true,
        allowNull: false
      },
      course_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      user_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      order_id: {
        type: Sequelize.BIGINT,
        allowNull: true
      },
      rating: {
        type: Sequelize.SMALLINT,
        allowNull: false,
        defaultValue: 5
      },
      content: {
        type: Sequelize.TEXT,
        allowNull: true
      },
      images: {
        type: Sequelize.JSON,
        allowNull: true
      },
      status: {
        type: Sequelize.SMALLINT,
        allowNull: false,
        defaultValue: 1
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
    await queryInterface.addIndex("course_reviews", ["course_id"]);
    await queryInterface.addIndex("course_reviews", ["user_id"]);
    await queryInterface.addIndex("course_reviews", ["course_id", "user_id"], { unique: true });

    await queryInterface.createTable("favorites", {
      favorite_id: {
        type: Sequelize.BIGINT,
        primaryKey: true,
        allowNull: false
      },
      user_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      target_type: {
        type: Sequelize.STRING(20),
        allowNull: false
      },
      target_id: {
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
    await queryInterface.addIndex("favorites", ["user_id", "target_type"]);
    await queryInterface.addIndex("favorites", ["user_id", "target_type", "target_id"], { unique: true });
  },

  async down(queryInterface) {
    await queryInterface.dropTable("favorites");
    await queryInterface.dropTable("course_reviews");
  }
};

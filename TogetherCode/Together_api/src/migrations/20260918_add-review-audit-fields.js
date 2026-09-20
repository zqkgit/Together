"use strict";

/**
 * 课程评价审核流增强：
 *  - teacher_id / studio_id 冗余（便于老师/工作室口碑聚合）
 *  - reply_content / reply_at  工作室回复
 *  - status 语义：0 待审核 / 1 通过 / 2 驳回
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn("course_reviews", "teacher_id", {
      type: Sequelize.BIGINT,
      allowNull: true,
      after: "course_id"
    });
    await queryInterface.addColumn("course_reviews", "studio_id", {
      type: Sequelize.BIGINT,
      allowNull: true,
      after: "teacher_id"
    });
    await queryInterface.addColumn("course_reviews", "child_id", {
      type: Sequelize.BIGINT,
      allowNull: true,
      after: "order_id"
    });
    await queryInterface.addColumn("course_reviews", "reply_content", {
      type: Sequelize.TEXT,
      allowNull: true
    });
    await queryInterface.addColumn("course_reviews", "reply_at", {
      type: Sequelize.DATE,
      allowNull: true
    });
    await queryInterface.addColumn("course_reviews", "reject_reason", {
      type: Sequelize.STRING(255),
      allowNull: true
    });
    await queryInterface.addIndex("course_reviews", ["studio_id"]);
    await queryInterface.addIndex("course_reviews", ["teacher_id"]);
    // 存量评价（迁移前提交）视为已通过，保持公开
    await queryInterface.sequelize.query(
      "UPDATE course_reviews SET status = 1 WHERE status IS NULL OR status NOT IN (0,1,2)"
    );
  },

  async down(queryInterface) {
    await queryInterface.removeColumn("course_reviews", "reject_reason");
    await queryInterface.removeColumn("course_reviews", "reply_at");
    await queryInterface.removeColumn("course_reviews", "reply_content");
    await queryInterface.removeColumn("course_reviews", "child_id");
    await queryInterface.removeColumn("course_reviews", "studio_id");
    await queryInterface.removeColumn("course_reviews", "teacher_id");
  }
};

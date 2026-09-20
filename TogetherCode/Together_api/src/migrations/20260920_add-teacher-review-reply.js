"use strict";

/** 课程评价：增加老师回复槽位（与工作室回复 reply_content/reply_at 分开） */
module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn("course_reviews", "teacher_reply_content", {
      type: Sequelize.STRING(500),
      allowNull: true,
      comment: "老师回复内容"
    });
    await queryInterface.addColumn("course_reviews", "teacher_reply_at", {
      type: Sequelize.DATE,
      allowNull: true,
      comment: "老师回复时间"
    });
  },

  down: async (queryInterface) => {
    await queryInterface.removeColumn("course_reviews", "teacher_reply_content");
    await queryInterface.removeColumn("course_reviews", "teacher_reply_at");
  }
};

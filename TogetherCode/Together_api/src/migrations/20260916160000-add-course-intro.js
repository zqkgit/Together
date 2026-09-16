"use strict";

/** 课程增加介绍字段 intro（详情页展示） */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.addColumn(
        "courses",
        "intro",
        {
          type: Sequelize.TEXT,
          allowNull: true
        },
        { transaction }
      );
    });
  },

  async down(queryInterface) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.removeColumn("courses", "intro", { transaction });
    });
  }
};

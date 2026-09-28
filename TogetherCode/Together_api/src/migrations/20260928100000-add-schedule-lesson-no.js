"use strict";

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn("schedules", "lesson_no", {
      type: Sequelize.INTEGER,
      allowNull: true,
      comment: "课次序号，对应课程课时编号"
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn("schedules", "lesson_no");
  }
};
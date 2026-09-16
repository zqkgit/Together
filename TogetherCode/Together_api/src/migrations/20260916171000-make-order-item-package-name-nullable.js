"use strict";

/** 移除课时包概念：order_items.package_name 允许为空 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.changeColumn("order_items", "package_name", {
      type: Sequelize.STRING(40),
      allowNull: true
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.changeColumn("order_items", "package_name", {
      type: Sequelize.STRING(40),
      allowNull: false
    });
  }
};

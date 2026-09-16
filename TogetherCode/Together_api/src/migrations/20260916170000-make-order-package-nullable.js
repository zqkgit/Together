"use strict";

/** 移除课时包概念：orders / order_items 的 package_id 允许为空 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.changeColumn("orders", "package_id", {
      type: Sequelize.BIGINT,
      allowNull: true
    });
    await queryInterface.changeColumn("order_items", "package_id", {
      type: Sequelize.BIGINT,
      allowNull: true
    });
    await queryInterface.changeColumn("order_items", "package_name", {
      type: Sequelize.STRING(40),
      allowNull: true
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.changeColumn("orders", "package_id", {
      type: Sequelize.BIGINT,
      allowNull: false
    });
    await queryInterface.changeColumn("order_items", "package_id", {
      type: Sequelize.BIGINT,
      allowNull: false
    });
  }
};

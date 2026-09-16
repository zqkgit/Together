"use strict";

/** 报名订单绑定班级：orders / order_items / child_course_balances 增加 class_id（可空，兼容存量订单） */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn("orders", "class_id", {
      type: Sequelize.BIGINT,
      allowNull: true
    });
    await queryInterface.addIndex("orders", ["class_id"]);

    await queryInterface.addColumn("order_items", "class_id", {
      type: Sequelize.BIGINT,
      allowNull: true
    });

    await queryInterface.addColumn("child_course_balances", "class_id", {
      type: Sequelize.BIGINT,
      allowNull: true
    });
    await queryInterface.addIndex("child_course_balances", ["class_id"]);
  },

  async down(queryInterface) {
    await queryInterface.removeColumn("orders", "class_id");
    await queryInterface.removeColumn("order_items", "class_id");
    await queryInterface.removeColumn("child_course_balances", "class_id");
  }
};

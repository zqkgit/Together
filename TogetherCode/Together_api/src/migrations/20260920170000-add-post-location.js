"use strict";

/**
 * 帖子位置能力：支持发帖选点（经纬度 + 地点名），
 * 供广场/信息流按距离推荐排序（haversine）。
 * 选填：未选位置时三列均为 NULL。
 */
module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn("posts", "latitude", {
      type: Sequelize.DECIMAL(10, 8),
      allowNull: true,
      comment: "纬度（-90~90），选填"
    });
    await queryInterface.addColumn("posts", "longitude", {
      type: Sequelize.DECIMAL(11, 8),
      allowNull: true,
      comment: "经度（-180~180），选填"
    });
    await queryInterface.addColumn("posts", "location_name", {
      type: Sequelize.STRING(128),
      allowNull: true,
      comment: "地点名（反地理编码），选填"
    });
  },

  down: async (queryInterface) => {
    await queryInterface.removeColumn("posts", "latitude");
    await queryInterface.removeColumn("posts", "longitude");
    await queryInterface.removeColumn("posts", "location_name");
  }
};

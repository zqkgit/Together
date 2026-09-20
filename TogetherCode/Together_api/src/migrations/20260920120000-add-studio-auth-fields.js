"use strict";

/**
 * 工作室入驻认证：补齐 PRD 表单字段
 * - city          所在城市 / 区域
 * - business_type 营业类型（艺术培训 / 书法书院 / 综合美育）
 * - teacher_count 师资数量（专职老师人数）
 * - contact_name  联系人姓名（phone 存手机号）
 * 申请表与档案表同步加列，审核通过时原样落库。
 */
module.exports = {
  up: async (queryInterface, Sequelize) => {
    const spec = {
      city: {
        type: Sequelize.STRING(120),
        allowNull: true,
        comment: "所在城市 / 区域"
      },
      business_type: {
        type: Sequelize.STRING(60),
        allowNull: true,
        comment: "营业类型：艺术培训 / 书法书院 / 综合美育"
      },
      teacher_count: {
        type: Sequelize.SMALLINT,
        allowNull: true,
        comment: "师资数量（专职老师人数）"
      },
      contact_name: {
        type: Sequelize.STRING(60),
        allowNull: true,
        comment: "联系人姓名"
      }
    };
    for (const table of ["studio_applications", "studio_profiles"]) {
      for (const [name, def] of Object.entries(spec)) {
        await queryInterface.addColumn(table, name, def);
      }
    }
  },

  down: async (queryInterface) => {
    for (const name of ["city", "business_type", "teacher_count", "contact_name"]) {
      await queryInterface.removeColumn("studio_applications", name);
      await queryInterface.removeColumn("studio_profiles", name);
    }
  }
};

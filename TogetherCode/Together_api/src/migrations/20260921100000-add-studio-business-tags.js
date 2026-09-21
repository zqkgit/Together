"use strict";

/**
 * 工作室入驻：营业类型由单选改为多选（取自 Web 端标签管理 · 工作室标签 scope=1）
 * - studio_applications 新增 business_tags JSON 数组（多选标签名）
 *   business_type STRING 保留，存第一个标签作为「主营类型」，兼容列表/筛选/旧数据
 * - studio_profiles 已有 type_tags JSON 数组，审核通过时直接写入完整多选，无需加列
 * - 历史数据回填：business_type 非空则 business_tags = [business_type]
 */
module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn("studio_applications", "business_tags", {
      type: Sequelize.JSON,
      allowNull: true,
      comment: "营业类型标签（多选，取自标签库 scope=1）"
    });

    // 回填历史申请单
    await queryInterface.sequelize.query(
      `UPDATE studio_applications
         SET business_tags = JSON_ARRAY(business_type)
       WHERE business_type IS NOT NULL AND business_type <> ''
         AND (business_tags IS NULL OR JSON_LENGTH(business_tags) = 0)`
    );
  },

  down: async (queryInterface) => {
    await queryInterface.removeColumn("studio_applications", "business_tags");
  }
};

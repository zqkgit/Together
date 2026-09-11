"use strict";

/**
 * Web 管理端治理补缺：
 *  - studio_accounts  工作室结算账户（绑定收款信息）
 *  - audit_logs       操作审计（平台 / 工作室统一记录）
 *  - reports          举报（用户举报帖子/评论/工作室/老师）
 *  - platform_configs 平台配置（key-value）
 *  - announcements    平台公告 / Banner
 */

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable("studio_accounts", {
      account_id: { type: Sequelize.BIGINT, primaryKey: true },
      studio_id: { type: Sequelize.BIGINT, allowNull: false },
      account_type: { type: Sequelize.STRING(20), allowNull: false, defaultValue: "bank" },
      account_name: { type: Sequelize.STRING(80), allowNull: false },
      account_no: { type: Sequelize.STRING(64), allowNull: false },
      bank_name: { type: Sequelize.STRING(80), allowNull: true },
      is_default: { type: Sequelize.SMALLINT, allowNull: false, defaultValue: 1 },
      status: { type: Sequelize.SMALLINT, allowNull: false, defaultValue: 1 },
      created_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") },
      updated_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") }
    });
    await queryInterface.addIndex("studio_accounts", ["studio_id"]);

    await queryInterface.createTable("audit_logs", {
      log_id: { type: Sequelize.BIGINT, primaryKey: true },
      actor_id: { type: Sequelize.BIGINT, allowNull: true },
      actor_name: { type: Sequelize.STRING(80), allowNull: true },
      role: { type: Sequelize.STRING(32), allowNull: false },
      studio_id: { type: Sequelize.BIGINT, allowNull: true },
      action: { type: Sequelize.STRING(64), allowNull: false },
      target_type: { type: Sequelize.STRING(32), allowNull: true },
      target_id: { type: Sequelize.STRING(64), allowNull: true },
      detail: { type: Sequelize.TEXT, allowNull: true },
      ip: { type: Sequelize.STRING(64), allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") }
    });
    await queryInterface.addIndex("audit_logs", ["role", "studio_id", "action", "created_at"]);

    await queryInterface.createTable("reports", {
      report_id: { type: Sequelize.BIGINT, primaryKey: true },
      reporter_id: { type: Sequelize.BIGINT, allowNull: false },
      target_type: { type: Sequelize.STRING(20), allowNull: false },
      target_id: { type: Sequelize.STRING(64), allowNull: false },
      reason: { type: Sequelize.STRING(20), allowNull: false },
      detail: { type: Sequelize.STRING(500), allowNull: true },
      images: { type: Sequelize.JSON, allowNull: true },
      status: { type: Sequelize.SMALLINT, allowNull: false, defaultValue: 0 },
      handled_by: { type: Sequelize.BIGINT, allowNull: true },
      handle_note: { type: Sequelize.STRING(255), allowNull: true },
      handled_at: { type: Sequelize.DATE, allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") },
      updated_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") }
    });
    await queryInterface.addIndex("reports", ["target_type", "target_id", "status", "created_at"]);

    await queryInterface.createTable("platform_configs", {
      config_id: { type: Sequelize.BIGINT, primaryKey: true },
      config_key: { type: Sequelize.STRING(64), allowNull: false, unique: true },
      config_value: { type: Sequelize.TEXT, allowNull: true },
      description: { type: Sequelize.STRING(255), allowNull: true },
      updated_by: { type: Sequelize.BIGINT, allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") },
      updated_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") }
    });

    await queryInterface.createTable("announcements", {
      announcement_id: { type: Sequelize.BIGINT, primaryKey: true },
      title: { type: Sequelize.STRING(120), allowNull: false },
      content: { type: Sequelize.TEXT, allowNull: true },
      type: { type: Sequelize.SMALLINT, allowNull: false, defaultValue: 1 },
      image: { type: Sequelize.JSON, allowNull: true },
      link: { type: Sequelize.STRING(255), allowNull: true },
      status: { type: Sequelize.SMALLINT, allowNull: false, defaultValue: 1 },
      publish_at: { type: Sequelize.DATE, allowNull: true },
      expire_at: { type: Sequelize.DATE, allowNull: true },
      created_by: { type: Sequelize.BIGINT, allowNull: true },
      created_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") },
      updated_at: { type: Sequelize.DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") }
    });
    await queryInterface.addIndex("announcements", ["status", "type", "publish_at"]);
  },

  async down(queryInterface) {
    await queryInterface.dropTable("announcements");
    await queryInterface.dropTable("platform_configs");
    await queryInterface.dropTable("reports");
    await queryInterface.dropTable("audit_logs");
    await queryInterface.dropTable("studio_accounts");
  }
};

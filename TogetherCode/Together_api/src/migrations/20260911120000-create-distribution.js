"use strict";

/**
 * 分销返利 / 钱包：
 * - distribution_links 分享带参链接（code 防自购识别）
 * - commission_records 返利明细（按当时 distribute_rate 结算）
 * - wallets 钱包（余额/冻结/累计提现/欠款）
 * - withdrawals 提现申请
 * 同时给 orders 增加 distribution_link_id（订单分销来源）、
 * studio_profiles 增加 distribute_rate（返利比例）、posts 增加 share_count（分享计数）。
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const { BIGINT, DECIMAL, STRING, INTEGER, DATE, TINYINT } = Sequelize;

    await queryInterface.createTable("distribution_links", {
      link_id: { type: BIGINT, primaryKey: true },
      parent_user_id: { type: BIGINT, allowNull: false },
      course_id: { type: BIGINT, allowNull: false },
      post_id: { type: BIGINT, allowNull: true },
      code: { type: STRING(32), allowNull: false, unique: true },
      status: { type: TINYINT, allowNull: false, defaultValue: 1 },
      created_at: { type: DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") }
    });

    await queryInterface.createTable("commission_records", {
      commission_id: { type: BIGINT, primaryKey: true },
      link_id: { type: BIGINT, allowNull: false },
      order_id: { type: BIGINT, allowNull: false },
      parent_user_id: { type: BIGINT, allowNull: false },
      rate: { type: DECIMAL(5, 2), allowNull: false, defaultValue: 0 },
      amount: { type: DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      status: { type: TINYINT, allowNull: false, defaultValue: 1, comment: "1待结算 2已到账" },
      settle_at: { type: DATE, allowNull: true },
      created_at: { type: DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") }
    });

    await queryInterface.createTable("wallets", {
      user_id: { type: BIGINT, primaryKey: true },
      balance: { type: DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      frozen: { type: DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      withdrawn: { type: DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      debt: { type: DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      created_at: { type: DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") },
      updated_at: { type: DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") }
    });

    await queryInterface.createTable("withdrawals", {
      withdraw_id: { type: BIGINT, primaryKey: true },
      user_id: { type: BIGINT, allowNull: false },
      amount: { type: DECIMAL(10, 2), allowNull: false },
      method: { type: STRING(32), allowNull: false, defaultValue: "wechat" },
      account: { type: STRING(128), allowNull: true },
      status: { type: TINYINT, allowNull: false, defaultValue: 1, comment: "1申请 2处理中 3成功 4失败" },
      created_at: { type: DATE, allowNull: false, defaultValue: Sequelize.literal("CURRENT_TIMESTAMP") },
      reviewed_at: { type: DATE, allowNull: true }
    });

    await queryInterface.addColumn("orders", "distribution_link_id", {
      type: BIGINT,
      allowNull: true,
      after: "package_id"
    });

    await queryInterface.addColumn("studio_profiles", "distribute_rate", {
      type: DECIMAL(4, 2),
      allowNull: false,
      defaultValue: 5.0,
      comment: "分销返利比例(5%-15%)"
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn("studio_profiles", "distribute_rate");
    await queryInterface.removeColumn("orders", "distribution_link_id");
    await queryInterface.dropTable("withdrawals");
    await queryInterface.dropTable("wallets");
    await queryInterface.dropTable("commission_records");
    await queryInterface.dropTable("distribution_links");
  }
};

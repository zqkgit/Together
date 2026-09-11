module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable("user_devices", {
      device_id: {
        type: Sequelize.BIGINT,
        primaryKey: true,
        allowNull: false
      },
      user_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      registration_id: {
        type: Sequelize.STRING(128),
        allowNull: false,
        comment: "极光 registration_id"
      },
      platform: {
        type: Sequelize.STRING(20),
        allowNull: false,
        defaultValue: "android",
        comment: "android / ios / h5"
      },
      status: {
        type: Sequelize.SMALLINT,
        allowNull: false,
        defaultValue: 1,
        comment: "1 有效 / 0 失效"
      },
      created_at: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.fn("NOW")
      },
      updated_at: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.fn("NOW")
      }
    });

    await queryInterface.addIndex("user_devices", ["user_id", "status"], {
      name: "idx_user_devices_user"
    });
    await queryInterface.addIndex("user_devices", ["registration_id"], {
      unique: true,
      name: "uk_user_devices_regid"
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable("user_devices");
  }
};

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.addColumn(
        "schedules",
        "is_makeup",
        {
          type: Sequelize.BOOLEAN,
          allowNull: false,
          defaultValue: false
        },
        { transaction }
      );

      await queryInterface.addColumn(
        "schedules",
        "makeup_from",
        {
          type: Sequelize.BIGINT,
          allowNull: true,
          references: {
            model: "schedules",
            key: "schedule_id"
          },
          onUpdate: "CASCADE",
          onDelete: "SET NULL"
        },
        { transaction }
      );

      await queryInterface.createTable(
        "leave_requests",
        {
          leave_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          class_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "classes",
              key: "class_id"
            },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          child_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "children",
              key: "child_id"
            },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          parent_user_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "users",
              key: "user_id"
            },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          schedule_id: {
            type: Sequelize.BIGINT,
            allowNull: true,
            references: {
              model: "schedules",
              key: "schedule_id"
            },
            onUpdate: "CASCADE",
            onDelete: "SET NULL"
          },
          reason: {
            type: Sequelize.STRING(200),
            allowNull: false
          },
          status: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          handled_at: {
            type: Sequelize.DATE,
            allowNull: true
          },
          makeup_status: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          makeup_schedule_id: {
            type: Sequelize.BIGINT,
            allowNull: true,
            references: {
              model: "schedules",
              key: "schedule_id"
            },
            onUpdate: "CASCADE",
            onDelete: "SET NULL"
          },
          created_at: {
            type: Sequelize.DATE,
            allowNull: false,
            defaultValue: Sequelize.literal("CURRENT_TIMESTAMP")
          },
          updated_at: {
            type: Sequelize.DATE,
            allowNull: false,
            defaultValue: Sequelize.literal("CURRENT_TIMESTAMP")
          }
        },
        { transaction }
      );

      await queryInterface.addIndex("leave_requests", ["parent_user_id", "status"], {
        name: "idx_leave_requests_parent_status",
        transaction
      });
      await queryInterface.addIndex("leave_requests", ["class_id", "status"], {
        name: "idx_leave_requests_class_status",
        transaction
      });
      await queryInterface.addIndex("leave_requests", ["schedule_id", "child_id"], {
        name: "idx_leave_requests_schedule_child",
        transaction
      });
    });
  },

  async down(queryInterface) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.dropTable("leave_requests", { transaction });
      await queryInterface.removeColumn("schedules", "makeup_from", { transaction });
      await queryInterface.removeColumn("schedules", "is_makeup", { transaction });
    });
  }
};

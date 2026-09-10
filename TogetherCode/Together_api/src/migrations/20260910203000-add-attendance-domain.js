module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.addColumn(
        "lesson_logs",
        "schedule_id",
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

      await queryInterface.addIndex("lesson_logs", ["schedule_id", "child_id", "created_at"], {
        name: "idx_lesson_logs_schedule_child_created",
        transaction
      });

      await queryInterface.createTable(
        "attendance",
        {
          attendance_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          schedule_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "schedules",
              key: "schedule_id"
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
          order_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "orders",
              key: "order_id"
            },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          status: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          note: {
            type: Sequelize.STRING(255),
            allowNull: true
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

      await queryInterface.addIndex("attendance", ["schedule_id", "child_id"], {
        unique: true,
        name: "uniq_attendance_schedule_child",
        transaction
      });

      await queryInterface.addIndex("attendance", ["schedule_id", "status"], {
        name: "idx_attendance_schedule_status",
        transaction
      });
    });
  },

  async down(queryInterface) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.dropTable("attendance", { transaction });
      await queryInterface.removeIndex("lesson_logs", "idx_lesson_logs_schedule_child_created", { transaction });
      await queryInterface.removeColumn("lesson_logs", "schedule_id", { transaction });
    });
  }
};

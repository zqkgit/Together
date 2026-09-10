module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.createTable(
        "orders",
        {
          order_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          order_no: {
            type: Sequelize.STRING(32),
            allowNull: false,
            unique: true
          },
          user_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "users", key: "user_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          child_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "children", key: "child_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          studio_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "studio_profiles", key: "studio_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          course_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "courses", key: "course_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          package_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "course_packages", key: "package_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          total_lessons: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          consumed_lessons: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          refunded_lessons: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          total_amount: {
            type: Sequelize.INTEGER,
            allowNull: false
          },
          paid_amount: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          refund_amount: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          pay_channel: {
            type: Sequelize.STRING(20),
            allowNull: true
          },
          paid_at: {
            type: Sequelize.DATE,
            allowNull: true
          },
          completed_at: {
            type: Sequelize.DATE,
            allowNull: true
          },
          status: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          remark: {
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

      await queryInterface.addIndex("orders", ["user_id", "status"], {
        name: "idx_orders_user_status",
        transaction
      });
      await queryInterface.addIndex("orders", ["studio_id", "status"], {
        name: "idx_orders_studio_status",
        transaction
      });

      await queryInterface.createTable(
        "order_items",
        {
          item_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          order_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "orders", key: "order_id" },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          course_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "courses", key: "course_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          package_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "course_packages", key: "package_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          course_title: {
            type: Sequelize.STRING(80),
            allowNull: false
          },
          package_name: {
            type: Sequelize.STRING(40),
            allowNull: false
          },
          lessons: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          quantity: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 1
          },
          unit_price: {
            type: Sequelize.INTEGER,
            allowNull: false
          },
          total_price: {
            type: Sequelize.INTEGER,
            allowNull: false
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

      await queryInterface.createTable(
        "payments",
        {
          payment_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          order_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "orders", key: "order_id" },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          payment_no: {
            type: Sequelize.STRING(32),
            allowNull: false,
            unique: true
          },
          channel: {
            type: Sequelize.STRING(20),
            allowNull: false
          },
          amount: {
            type: Sequelize.INTEGER,
            allowNull: false
          },
          paid_at: {
            type: Sequelize.DATE,
            allowNull: true
          },
          status: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          trade_no: {
            type: Sequelize.STRING(64),
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

      await queryInterface.createTable(
        "refunds",
        {
          refund_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          order_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "orders", key: "order_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          user_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "users", key: "user_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          requested_lessons: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          refundable_lessons: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          unit_price: {
            type: Sequelize.INTEGER,
            allowNull: false
          },
          amount: {
            type: Sequelize.INTEGER,
            allowNull: false
          },
          reason: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          reviewed_by: {
            type: Sequelize.BIGINT,
            allowNull: true
          },
          reviewed_at: {
            type: Sequelize.DATE,
            allowNull: true
          },
          refunded_at: {
            type: Sequelize.DATE,
            allowNull: true
          },
          status: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
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

      await queryInterface.addIndex("refunds", ["order_id", "status"], {
        name: "idx_refunds_order_status",
        transaction
      });

      await queryInterface.createTable(
        "child_course_balances",
        {
          balance_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          child_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "children", key: "child_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          course_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "courses", key: "course_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          order_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            unique: true,
            references: { model: "orders", key: "order_id" },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          total_lessons: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          consumed_lessons: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          refunded_lessons: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          remaining_lessons: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          valid_from: {
            type: Sequelize.DATEONLY,
            allowNull: false
          },
          valid_to: {
            type: Sequelize.DATEONLY,
            allowNull: true
          },
          status: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 1
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

      await queryInterface.addIndex("child_course_balances", ["child_id", "course_id", "status"], {
        name: "idx_child_course_balance_lookup",
        transaction
      });

      await queryInterface.createTable(
        "lesson_logs",
        {
          log_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          child_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "children", key: "child_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          course_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "courses", key: "course_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          order_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: { model: "orders", key: "order_id" },
            onUpdate: "CASCADE",
            onDelete: "RESTRICT"
          },
          source: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          type: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          delta: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          balance_after: {
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
          }
        },
        { transaction }
      );

      await queryInterface.addIndex("lesson_logs", ["child_id", "course_id", "created_at"], {
        name: "idx_lesson_logs_child_course_created",
        transaction
      });
    });
  },

  async down(queryInterface) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.dropTable("lesson_logs", { transaction });
      await queryInterface.dropTable("child_course_balances", { transaction });
      await queryInterface.dropTable("refunds", { transaction });
      await queryInterface.dropTable("payments", { transaction });
      await queryInterface.dropTable("order_items", { transaction });
      await queryInterface.dropTable("orders", { transaction });
    });
  }
};

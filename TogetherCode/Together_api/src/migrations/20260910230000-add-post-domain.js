module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.addColumn(
        "lesson_logs",
        "post_id",
        {
          type: Sequelize.BIGINT,
          allowNull: true
        },
        { transaction }
      );

      await queryInterface.addIndex("lesson_logs", ["post_id", "child_id", "created_at"], {
        name: "idx_lesson_logs_post_child_created",
        transaction
      });

      await queryInterface.createTable(
        "posts",
        {
          post_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          author_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "users",
              key: "user_id"
            },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          author_role: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          type: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          child_id: {
            type: Sequelize.BIGINT,
            allowNull: true,
            references: {
              model: "children",
              key: "child_id"
            },
            onUpdate: "CASCADE",
            onDelete: "SET NULL"
          },
          course_id: {
            type: Sequelize.BIGINT,
            allowNull: true,
            references: {
              model: "courses",
              key: "course_id"
            },
            onUpdate: "CASCADE",
            onDelete: "SET NULL"
          },
          images: {
            type: Sequelize.JSON,
            allowNull: true
          },
          content: {
            type: Sequelize.STRING(1000),
            allowNull: true
          },
          visibility: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 2
          },
          like_count: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          comment_count: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          share_count: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
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

      await queryInterface.addIndex("posts", ["author_id", "status"], {
        name: "idx_posts_author_status",
        transaction
      });
      await queryInterface.addIndex("posts", ["course_id", "status"], {
        name: "idx_posts_course_status",
        transaction
      });

      await queryInterface.createTable(
        "post_students",
        {
          id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          post_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "posts",
              key: "post_id"
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
          deducted: {
            type: Sequelize.BOOLEAN,
            allowNull: false,
            defaultValue: false
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

      await queryInterface.addIndex("post_students", ["post_id", "child_id"], {
        unique: true,
        name: "uniq_post_students_post_child",
        transaction
      });
    });
  },

  async down(queryInterface) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.dropTable("post_students", { transaction });
      await queryInterface.dropTable("posts", { transaction });
      await queryInterface.removeIndex("lesson_logs", "idx_lesson_logs_post_child_created", { transaction });
      await queryInterface.removeColumn("lesson_logs", "post_id", { transaction });
    });
  }
};

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.createTable(
        "schedules",
        {
          schedule_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          studio_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "studio_profiles",
              key: "studio_id"
            },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
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
          course_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "courses",
              key: "course_id"
            },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          teacher_id: {
            type: Sequelize.BIGINT,
            allowNull: true,
            references: {
              model: "teacher_profiles",
              key: "teacher_id"
            },
            onUpdate: "CASCADE",
            onDelete: "SET NULL"
          },
          lesson_date: {
            type: Sequelize.DATEONLY,
            allowNull: false
          },
          start_time: {
            type: Sequelize.STRING(5),
            allowNull: false
          },
          end_time: {
            type: Sequelize.STRING(5),
            allowNull: false
          },
          location: {
            type: Sequelize.STRING(120),
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

      await queryInterface.addIndex("schedules", ["studio_id", "lesson_date"], {
        name: "idx_schedules_studio_lesson_date",
        transaction
      });
      await queryInterface.addIndex("schedules", ["teacher_id", "lesson_date"], {
        name: "idx_schedules_teacher_lesson_date",
        transaction
      });
      await queryInterface.addIndex("schedules", ["class_id", "lesson_date"], {
        name: "idx_schedules_class_lesson_date",
        transaction
      });
    });
  },

  async down(queryInterface) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.dropTable("schedules", { transaction });
    });
  }
};

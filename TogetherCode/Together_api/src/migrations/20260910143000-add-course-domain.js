module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.createTable(
        "teacher_profiles",
        {
          teacher_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          user_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            unique: true,
            references: {
              model: "users",
              key: "user_id"
            },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          real_name: {
            type: Sequelize.STRING(40),
            allowNull: false
          },
          subjects: {
            type: Sequelize.JSON,
            allowNull: true
          },
          years: {
            type: Sequelize.SMALLINT,
            allowNull: true
          },
          intro: {
            type: Sequelize.STRING(500),
            allowNull: true
          },
          cert_no: {
            type: Sequelize.STRING(60),
            allowNull: true
          },
          portfolio: {
            type: Sequelize.JSON,
            allowNull: true
          },
          studio_id: {
            type: Sequelize.BIGINT,
            allowNull: true,
            references: {
              model: "studio_profiles",
              key: "studio_id"
            },
            onUpdate: "CASCADE",
            onDelete: "SET NULL"
          },
          cert_status: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          rating: {
            type: Sequelize.DECIMAL(2, 1),
            allowNull: false,
            defaultValue: 5
          },
          student_count: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          work_count: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          fans: {
            type: Sequelize.INTEGER,
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

      await queryInterface.createTable(
        "courses",
        {
          course_id: {
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
          title: {
            type: Sequelize.STRING(80),
            allowNull: false
          },
          cover: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          category: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          age_min: {
            type: Sequelize.SMALLINT,
            allowNull: true
          },
          age_max: {
            type: Sequelize.SMALLINT,
            allowNull: true
          },
          total_lessons: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          duration_min: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          price: {
            type: Sequelize.INTEGER,
            allowNull: false
          },
          class_size: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 12
          },
          rating: {
            type: Sequelize.DECIMAL(2, 1),
            allowNull: false,
            defaultValue: 5
          },
          sales: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          distribute_rate: {
            type: Sequelize.DECIMAL(4, 2),
            allowNull: false,
            defaultValue: 0.08
          },
          validity_days: {
            type: Sequelize.SMALLINT,
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

      await queryInterface.addIndex("courses", ["studio_id", "status"], {
        name: "idx_courses_studio_status",
        transaction
      });
      await queryInterface.addIndex("courses", ["category", "status"], {
        name: "idx_courses_category_status",
        transaction
      });

      await queryInterface.createTable(
        "course_packages",
        {
          package_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
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
          name: {
            type: Sequelize.STRING(40),
            allowNull: false
          },
          lessons: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          price: {
            type: Sequelize.INTEGER,
            allowNull: false
          },
          original_price: {
            type: Sequelize.INTEGER,
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

      await queryInterface.createTable(
        "classes",
        {
          class_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
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
          name: {
            type: Sequelize.STRING(60),
            allowNull: false
          },
          schedule_rule: {
            type: Sequelize.JSON,
            allowNull: true
          },
          start_date: {
            type: Sequelize.DATEONLY,
            allowNull: true
          },
          end_date: {
            type: Sequelize.DATEONLY,
            allowNull: true
          },
          capacity: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 12
          },
          enrolled: {
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
    });
  },

  async down(queryInterface) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.dropTable("classes", { transaction });
      await queryInterface.dropTable("course_packages", { transaction });
      await queryInterface.dropTable("courses", { transaction });
      await queryInterface.dropTable("teacher_profiles", { transaction });
    });
  }
};

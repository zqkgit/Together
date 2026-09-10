module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.createTable(
        "users",
        {
          user_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          phone: {
            type: Sequelize.STRING(20),
            allowNull: true,
            unique: true
          },
          wx_unionid: {
            type: Sequelize.STRING(64),
            allowNull: true,
            unique: true
          },
          password_hash: {
            type: Sequelize.STRING(100),
            allowNull: true
          },
          nickname: {
            type: Sequelize.STRING(40),
            allowNull: true
          },
          avatar: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          city: {
            type: Sequelize.STRING(60),
            allowNull: true
          },
          terms_agreed_at: {
            type: Sequelize.DATE,
            allowNull: true
          },
          current_role: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 1
          },
          status: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 1
          },
          login_fail_count: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          locked_until: {
            type: Sequelize.DATE,
            allowNull: true
          },
          last_login_at: {
            type: Sequelize.DATE,
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
          },
          deleted_at: {
            type: Sequelize.DATE,
            allowNull: true
          }
        },
        { transaction }
      );

      await queryInterface.createTable(
        "user_roles",
        {
          id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          user_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "users",
              key: "user_id"
            },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          role: {
            type: Sequelize.SMALLINT,
            allowNull: false
          },
          ref_id: {
            type: Sequelize.BIGINT,
            allowNull: true
          },
          verified: {
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

      await queryInterface.addIndex("user_roles", ["user_id", "role"], {
        unique: true,
        name: "uniq_user_role",
        transaction
      });

      await queryInterface.createTable(
        "children",
        {
          child_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
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
          nickname: {
            type: Sequelize.STRING(40),
            allowNull: false
          },
          avatar: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          birthday: {
            type: Sequelize.DATEONLY,
            allowNull: false
          },
          gender: {
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

      await queryInterface.createTable(
        "auth_verification_codes",
        {
          id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          phone: {
            type: Sequelize.STRING(20),
            allowNull: false
          },
          code: {
            type: Sequelize.STRING(10),
            allowNull: false
          },
          purpose: {
            type: Sequelize.STRING(20),
            allowNull: false,
            defaultValue: "login"
          },
          expires_at: {
            type: Sequelize.DATE,
            allowNull: false
          },
          consumed_at: {
            type: Sequelize.DATE,
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

      await queryInterface.addIndex("auth_verification_codes", ["phone", "purpose", "created_at"], {
        name: "idx_auth_code_phone_purpose_created",
        transaction
      });

      await queryInterface.createTable(
        "refresh_tokens",
        {
          id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          user_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "users",
              key: "user_id"
            },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          token: {
            type: Sequelize.STRING(128),
            allowNull: false,
            unique: true
          },
          expires_at: {
            type: Sequelize.DATE,
            allowNull: false
          },
          revoked_at: {
            type: Sequelize.DATE,
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
        "studio_profiles",
        {
          studio_id: {
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
            onDelete: "RESTRICT"
          },
          name: {
            type: Sequelize.STRING(120),
            allowNull: false
          },
          cover: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          type_tags: {
            type: Sequelize.JSON,
            allowNull: true
          },
          intro: {
            type: Sequelize.STRING(500),
            allowNull: true
          },
          address: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          lng: {
            type: Sequelize.DECIMAL(10, 6),
            allowNull: true
          },
          lat: {
            type: Sequelize.DECIMAL(10, 6),
            allowNull: true
          },
          phone: {
            type: Sequelize.STRING(20),
            allowNull: true
          },
          hours: {
            type: Sequelize.STRING(120),
            allowNull: true
          },
          license: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          legal_id: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          permit: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          photos: {
            type: Sequelize.JSON,
            allowNull: true
          },
          settle_rate: {
            type: Sequelize.DECIMAL(4, 2),
            allowNull: false,
            defaultValue: 0.1
          },
          plan_tier: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 1
          },
          status: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          banned_at: {
            type: Sequelize.DATE,
            allowNull: true
          },
          ban_reason: {
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

      await queryInterface.createTable(
        "admin_accounts",
        {
          admin_id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          user_id: {
            type: Sequelize.BIGINT,
            allowNull: true,
            references: {
              model: "users",
              key: "user_id"
            },
            onUpdate: "CASCADE",
            onDelete: "SET NULL"
          },
          username: {
            type: Sequelize.STRING(40),
            allowNull: false,
            unique: true
          },
          password_hash: {
            type: Sequelize.STRING(100),
            allowNull: false
          },
          role: {
            type: Sequelize.STRING(32),
            allowNull: false
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
        "teacher_applications",
        {
          id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          user_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "users",
              key: "user_id"
            },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
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
          version: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 1
          },
          status: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          submitted_at: {
            type: Sequelize.DATE,
            allowNull: false,
            defaultValue: Sequelize.literal("CURRENT_TIMESTAMP")
          },
          reviewed_at: {
            type: Sequelize.DATE,
            allowNull: true
          },
          review_reason: {
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

      await queryInterface.createTable(
        "studio_applications",
        {
          id: {
            type: Sequelize.BIGINT,
            primaryKey: true,
            allowNull: false
          },
          user_id: {
            type: Sequelize.BIGINT,
            allowNull: false,
            references: {
              model: "users",
              key: "user_id"
            },
            onUpdate: "CASCADE",
            onDelete: "CASCADE"
          },
          name: {
            type: Sequelize.STRING(120),
            allowNull: false
          },
          cover: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          intro: {
            type: Sequelize.STRING(500),
            allowNull: true
          },
          address: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          phone: {
            type: Sequelize.STRING(20),
            allowNull: true
          },
          license: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          permit: {
            type: Sequelize.STRING(255),
            allowNull: true
          },
          photos: {
            type: Sequelize.JSON,
            allowNull: true
          },
          version: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 1
          },
          status: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          submitted_at: {
            type: Sequelize.DATE,
            allowNull: false,
            defaultValue: Sequelize.literal("CURRENT_TIMESTAMP")
          },
          reviewed_at: {
            type: Sequelize.DATE,
            allowNull: true
          },
          review_reason: {
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

      await queryInterface.createTable(
        "settlements",
        {
          settlement_id: {
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
          period_start: {
            type: Sequelize.DATEONLY,
            allowNull: false
          },
          period_end: {
            type: Sequelize.DATEONLY,
            allowNull: false
          },
          income: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          refund: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          distribution: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          net_amount: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          fee_rate: {
            type: Sequelize.DECIMAL(4, 2),
            allowNull: false,
            defaultValue: 0.1
          },
          fee_amount: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          payable_amount: {
            type: Sequelize.INTEGER,
            allowNull: false,
            defaultValue: 0
          },
          status: {
            type: Sequelize.SMALLINT,
            allowNull: false,
            defaultValue: 0
          },
          pay_no: {
            type: Sequelize.STRING(64),
            allowNull: true
          },
          operator_id: {
            type: Sequelize.BIGINT,
            allowNull: true,
            references: {
              model: "admin_accounts",
              key: "admin_id"
            },
            onUpdate: "CASCADE",
            onDelete: "SET NULL"
          },
          paid_at: {
            type: Sequelize.DATE,
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

      await queryInterface.addIndex("settlements", ["studio_id", "period_start", "period_end"], {
        name: "idx_settlement_studio_period",
        transaction
      });
    });
  },

  async down(queryInterface) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.dropTable("settlements", { transaction });
      await queryInterface.dropTable("studio_applications", { transaction });
      await queryInterface.dropTable("teacher_applications", { transaction });
      await queryInterface.dropTable("admin_accounts", { transaction });
      await queryInterface.dropTable("studio_profiles", { transaction });
      await queryInterface.dropTable("refresh_tokens", { transaction });
      await queryInterface.dropTable("auth_verification_codes", { transaction });
      await queryInterface.dropTable("children", { transaction });
      await queryInterface.dropTable("user_roles", { transaction });
      await queryInterface.dropTable("users", { transaction });
    });
  }
};

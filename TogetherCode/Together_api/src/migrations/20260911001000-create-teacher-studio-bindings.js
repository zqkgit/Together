module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable("teacher_studio_bindings", {
      binding_id: {
        type: Sequelize.BIGINT,
        primaryKey: true,
        allowNull: false
      },
      teacher_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      studio_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      status: {
        type: Sequelize.SMALLINT,
        allowNull: false,
        defaultValue: 1,
        comment: "1 在职绑定 / 0 已解除"
      },
      bound_at: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.fn("NOW")
      },
      released_at: {
        type: Sequelize.DATE,
        allowNull: true
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

    await queryInterface.addIndex("teacher_studio_bindings", ["teacher_id", "studio_id"], {
      unique: true
    });
    await queryInterface.addIndex("teacher_studio_bindings", ["studio_id", "status"]);

    // 数据迁移：现有 teacher_profiles.studio_id 非空的老师建立初始在职绑定
    const rows = await queryInterface.sequelize.query(
      "SELECT teacher_id, studio_id FROM teacher_profiles WHERE studio_id IS NOT NULL",
      { type: queryInterface.sequelize.QueryTypes.SELECT }
    );

    for (const row of rows) {
      const bindingId = BigInt(Date.now()) * BigInt(1000000) + BigInt(Math.floor(Math.random() * 1000000));
      await queryInterface.sequelize.query(
        `INSERT INTO teacher_studio_bindings (binding_id, teacher_id, studio_id, status, bound_at, created_at, updated_at)
         VALUES (:binding_id, :teacher_id, :studio_id, 1, NOW(), NOW(), NOW())`,
        {
          replacements: {
            binding_id: bindingId.toString(),
            teacher_id: row.teacher_id,
            studio_id: row.studio_id
          }
        }
      );
    }
  },

  async down(queryInterface) {
    await queryInterface.dropTable("teacher_studio_bindings");
  }
};

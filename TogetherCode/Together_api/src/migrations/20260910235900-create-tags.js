module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable("tags", {
      tag_id: {
        type: Sequelize.BIGINT,
        primaryKey: true,
        allowNull: false
      },
      name: {
        type: Sequelize.STRING(40),
        allowNull: false
      },
      scope: {
        type: Sequelize.SMALLINT,
        allowNull: false,
        defaultValue: 3,
        comment: "使用场景：1 工作室 / 2 老师 / 3 通用"
      },
      sort: {
        type: Sequelize.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      status: {
        type: Sequelize.SMALLINT,
        allowNull: false,
        defaultValue: 1,
        comment: "1 启用 / 0 停用"
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

    await queryInterface.addIndex("tags", ["scope", "status"]);
  },

  async down(queryInterface) {
    await queryInterface.dropTable("tags");
  }
};

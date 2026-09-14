module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.addColumn(
        "posts",
        "topic",
        {
          type: Sequelize.STRING(32),
          allowNull: true,
          defaultValue: null
        },
        { transaction }
      );
      await queryInterface.addIndex("posts", ["topic", "status", "created_at"], {
        name: "idx_posts_topic_status_created",
        transaction
      });
    });
  },

  async down(queryInterface) {
    await queryInterface.sequelize.transaction(async (transaction) => {
      await queryInterface.removeColumn("posts", "topic", { transaction });
      await queryInterface.removeIndex("posts", "idx_posts_topic_status_created", { transaction });
    });
  }
};

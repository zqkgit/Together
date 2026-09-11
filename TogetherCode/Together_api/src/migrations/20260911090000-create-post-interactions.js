module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable("post_likes", {
      like_id: {
        type: Sequelize.BIGINT,
        primaryKey: true,
        allowNull: false
      },
      post_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      user_id: {
        type: Sequelize.BIGINT,
        allowNull: false
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

    await queryInterface.addIndex("post_likes", ["post_id", "user_id"], {
      unique: true,
      name: "uk_post_likes_post_user"
    });

    await queryInterface.createTable("post_comments", {
      comment_id: {
        type: Sequelize.BIGINT,
        primaryKey: true,
        allowNull: false
      },
      post_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      user_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      content: {
        type: Sequelize.STRING(500),
        allowNull: false
      },
      status: {
        type: Sequelize.SMALLINT,
        allowNull: false,
        defaultValue: 1,
        comment: "1 正常 / 0 已删除"
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

    await queryInterface.addIndex("post_comments", ["post_id", "status"], {
      name: "idx_post_comments_post"
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable("post_comments");
    await queryInterface.dropTable("post_likes");
  }
};

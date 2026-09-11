module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable("conversations", {
      conversation_id: {
        type: Sequelize.BIGINT,
        primaryKey: true,
        allowNull: false
      },
      peer_a: {
        type: Sequelize.BIGINT,
        allowNull: false,
        comment: "参与方A（约定 user_id 小者在前，防重复会话）"
      },
      peer_b: {
        type: Sequelize.BIGINT,
        allowNull: false,
        comment: "参与方B"
      },
      child_id: {
        type: Sequelize.BIGINT,
        allowNull: true,
        comment: "家校会话可选关联孩子"
      },
      last_message_id: {
        type: Sequelize.BIGINT,
        allowNull: true
      },
      unread_a: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      unread_b: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      status: {
        type: Sequelize.SMALLINT,
        allowNull: false,
        defaultValue: 1,
        comment: "1 正常 / 0 关闭"
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

    await queryInterface.addIndex("conversations", ["peer_a", "peer_b", "status"], {
      name: "idx_conversations_peers"
    });

    await queryInterface.createTable("conversation_messages", {
      message_id: {
        type: Sequelize.BIGINT,
        primaryKey: true,
        allowNull: false
      },
      conversation_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      sender_id: {
        type: Sequelize.BIGINT,
        allowNull: false
      },
      type: {
        type: Sequelize.SMALLINT,
        allowNull: false,
        defaultValue: 1,
        comment: "1 文本 / 2 图片"
      },
      content: {
        type: Sequelize.STRING(2000),
        allowNull: false
      },
      read_at: {
        type: Sequelize.DATE,
        allowNull: true
      },
      status: {
        type: Sequelize.SMALLINT,
        allowNull: false,
        defaultValue: 1,
        comment: "1 正常 / 0 撤回"
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

    await queryInterface.addIndex("conversation_messages", ["conversation_id", "created_at"], {
      name: "idx_conv_messages"
    });

    await queryInterface.createTable("notifications", {
      notification_id: {
        type: Sequelize.BIGINT,
        primaryKey: true,
        allowNull: false
      },
      user_id: {
        type: Sequelize.BIGINT,
        allowNull: false,
        comment: "接收方"
      },
      type: {
        type: Sequelize.STRING(30),
        allowNull: false,
        comment: "leave/refund/like/comment/consume/system"
      },
      title: {
        type: Sequelize.STRING(120),
        allowNull: false
      },
      content: {
        type: Sequelize.STRING(500),
        allowNull: false
      },
      ref_type: {
        type: Sequelize.STRING(30),
        allowNull: true
      },
      ref_id: {
        type: Sequelize.STRING(64),
        allowNull: true
      },
      is_read: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false
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

    await queryInterface.addIndex("notifications", ["user_id", "is_read"], {
      name: "idx_notifications_user_read"
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable("notifications");
    await queryInterface.dropTable("conversation_messages");
    await queryInterface.dropTable("conversations");
  }
};

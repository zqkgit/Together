const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Conversation = sequelize.define(
    "Conversation",
    {
      conversation_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      peer_a: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      peer_b: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      child_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      last_message_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      unread_a: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      unread_b: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      }
    },
    {
      tableName: "conversations",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Conversation.associate = (models) => {
    Conversation.belongsTo(models.User, { foreignKey: "peer_a", as: "userA" });
    Conversation.belongsTo(models.User, { foreignKey: "peer_b", as: "userB" });
    Conversation.belongsTo(models.Child, { foreignKey: "child_id", as: "child" });
    Conversation.belongsTo(models.ConversationMessage, {
      foreignKey: "last_message_id",
      as: "lastMessage"
    });
  };

  Conversation.beforeValidate((instance) => {
    if (!instance.conversation_id) {
      instance.conversation_id = generateId();
    }
  });

  return Conversation;
};

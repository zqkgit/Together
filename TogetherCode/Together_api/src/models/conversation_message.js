const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const ConversationMessage = sequelize.define(
    "ConversationMessage",
    {
      message_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      conversation_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      sender_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      type: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      },
      content: {
        type: DataTypes.STRING(2000),
        allowNull: false
      },
      read_at: {
        type: DataTypes.DATE,
        allowNull: true
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      }
    },
    {
      tableName: "conversation_messages",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  ConversationMessage.associate = (models) => {
    ConversationMessage.belongsTo(models.Conversation, {
      foreignKey: "conversation_id",
      as: "conversation"
    });
    ConversationMessage.belongsTo(models.User, { foreignKey: "sender_id", as: "sender" });
  };

  ConversationMessage.beforeValidate((instance) => {
    if (!instance.message_id) {
      instance.message_id = generateId();
    }
  });

  return ConversationMessage;
};

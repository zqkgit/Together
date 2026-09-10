const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const StudioApplication = sequelize.define(
    "StudioApplication",
    {
      id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      name: {
        type: DataTypes.STRING(120),
        allowNull: false
      },
      cover: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      intro: {
        type: DataTypes.STRING(500),
        allowNull: true
      },
      address: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      phone: {
        type: DataTypes.STRING(20),
        allowNull: true
      },
      license: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      permit: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      photos: {
        type: DataTypes.JSON,
        allowNull: true
      },
      version: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 1
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      submitted_at: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW
      },
      reviewed_at: {
        type: DataTypes.DATE,
        allowNull: true
      },
      review_reason: {
        type: DataTypes.STRING(255),
        allowNull: true
      }
    },
    {
      tableName: "studio_applications",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  StudioApplication.associate = (models) => {
    StudioApplication.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
  };

  StudioApplication.beforeValidate((instance) => {
    if (!instance.id) {
      instance.id = generateId();
    }
  });

  return StudioApplication;
};

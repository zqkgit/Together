const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const TeacherApplication = sequelize.define(
    "TeacherApplication",
    {
      id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      studio_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      real_name: {
        type: DataTypes.STRING(40),
        allowNull: false
      },
      subjects: {
        type: DataTypes.JSON,
        allowNull: true
      },
      years: {
        type: DataTypes.SMALLINT,
        allowNull: true
      },
      intro: {
        type: DataTypes.STRING(500),
        allowNull: true
      },
      cert_no: {
        type: DataTypes.STRING(60),
        allowNull: true
      },
      portfolio: {
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
      tableName: "teacher_applications",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  TeacherApplication.associate = (models) => {
    TeacherApplication.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
    TeacherApplication.belongsTo(models.StudioProfile, { foreignKey: "studio_id", as: "studio" });
  };

  TeacherApplication.beforeValidate((instance) => {
    if (!instance.id) {
      instance.id = generateId();
    }
  });

  return TeacherApplication;
};

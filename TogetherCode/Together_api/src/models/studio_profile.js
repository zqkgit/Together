const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const StudioProfile = sequelize.define(
    "StudioProfile",
    {
      studio_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false,
        unique: true
      },
      name: {
        type: DataTypes.STRING(120),
        allowNull: false
      },
      cover: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      type_tags: {
        type: DataTypes.JSON,
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
      lng: {
        type: DataTypes.DECIMAL(10, 6),
        allowNull: true
      },
      lat: {
        type: DataTypes.DECIMAL(10, 6),
        allowNull: true
      },
      phone: {
        type: DataTypes.STRING(20),
        allowNull: true
      },
      hours: {
        type: DataTypes.STRING(120),
        allowNull: true
      },
      license: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      legal_id: {
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
      settle_rate: {
        type: DataTypes.DECIMAL(4, 2),
        allowNull: false,
        defaultValue: 0.1
      },
      distribute_rate: {
        type: DataTypes.DECIMAL(4, 2),
        allowNull: false,
        defaultValue: 5.0
      },
      plan_tier: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      banned_at: {
        type: DataTypes.DATE,
        allowNull: true
      },
      ban_reason: {
        type: DataTypes.STRING(255),
        allowNull: true
      }
    },
    {
      tableName: "studio_profiles",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  StudioProfile.associate = (models) => {
    StudioProfile.belongsTo(models.User, { foreignKey: "user_id", as: "owner" });
    StudioProfile.hasMany(models.AdminAccount, { foreignKey: "studio_id", as: "staffAccounts" });
    StudioProfile.hasMany(models.Settlement, { foreignKey: "studio_id", as: "settlements" });
    StudioProfile.hasMany(models.TeacherApplication, { foreignKey: "studio_id", as: "teacherApplications" });
    StudioProfile.hasMany(models.TeacherProfile, { foreignKey: "studio_id", as: "teachers" });
    StudioProfile.hasMany(models.Course, { foreignKey: "studio_id", as: "courses" });
    StudioProfile.hasMany(models.Schedule, { foreignKey: "studio_id", as: "schedules" });
    StudioProfile.hasMany(models.Order, { foreignKey: "studio_id", as: "orders" });
  };

  StudioProfile.beforeValidate((instance) => {
    if (!instance.studio_id) {
      instance.studio_id = generateId();
    }
  });

  return StudioProfile;
};

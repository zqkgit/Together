const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const User = sequelize.define(
    "User",
    {
      user_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      phone: {
        type: DataTypes.STRING(20),
        unique: true,
        allowNull: true
      },
      wx_unionid: {
        type: DataTypes.STRING(64),
        unique: true,
        allowNull: true
      },
      password_hash: {
        type: DataTypes.STRING(100),
        allowNull: true
      },
      nickname: {
        type: DataTypes.STRING(40),
        allowNull: true
      },
      avatar: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      city: {
        type: DataTypes.STRING(60),
        allowNull: true
      },
      terms_agreed_at: {
        type: DataTypes.DATE,
        allowNull: true
      },
      current_role: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      },
      login_fail_count: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      locked_until: {
        type: DataTypes.DATE,
        allowNull: true
      },
      last_login_at: {
        type: DataTypes.DATE,
        allowNull: true
      }
    },
    {
      tableName: "users",
      createdAt: "created_at",
      updatedAt: "updated_at",
      deletedAt: "deleted_at",
      paranoid: true
    }
  );

  User.associate = (models) => {
    User.hasMany(models.UserRole, { foreignKey: "user_id", as: "roles" });
    User.hasMany(models.Child, { foreignKey: "parent_user_id", as: "children" });
    User.hasMany(models.AuthVerificationCode, { foreignKey: "phone", sourceKey: "phone", as: "codes" });
    User.hasMany(models.RefreshToken, { foreignKey: "user_id", as: "refreshTokens" });
    User.hasMany(models.Order, { foreignKey: "user_id", as: "orders" });
    User.hasMany(models.Refund, { foreignKey: "user_id", as: "refunds" });
    User.hasMany(models.LeaveRequest, { foreignKey: "parent_user_id", as: "leaveRequests" });
    User.hasMany(models.Post, { foreignKey: "author_id", as: "posts" });
    User.hasOne(models.AdminAccount, { foreignKey: "user_id", as: "adminAccount" });
    User.hasOne(models.StudioProfile, { foreignKey: "user_id", as: "studioProfile" });
    User.hasOne(models.TeacherProfile, { foreignKey: "user_id", as: "teacherProfile" });
    User.hasMany(models.TeacherApplication, { foreignKey: "user_id", as: "teacherApplications" });
    User.hasMany(models.StudioApplication, { foreignKey: "user_id", as: "studioApplications" });
  };

  User.beforeValidate((instance) => {
    if (!instance.user_id) {
      instance.user_id = generateId();
    }
  });

  return User;
};

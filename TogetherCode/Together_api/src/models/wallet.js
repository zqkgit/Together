module.exports = (sequelize, DataTypes) => {
  const Wallet = sequelize.define(
    "Wallet",
    {
      user_id: { type: DataTypes.BIGINT, primaryKey: true },
      balance: { type: DataTypes.DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      frozen: { type: DataTypes.DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      withdrawn: { type: DataTypes.DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      debt: { type: DataTypes.DECIMAL(10, 2), allowNull: false, defaultValue: 0 }
    },
    {
      tableName: "wallets",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Wallet.associate = (models) => {
    Wallet.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
  };

  return Wallet;
};

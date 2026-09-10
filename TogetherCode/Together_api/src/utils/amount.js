function formatFen(amount = 0) {
  const yuan = Number(amount || 0) / 100;
  return `¥ ${yuan.toLocaleString("zh-CN", {
    minimumFractionDigits: yuan % 1 === 0 ? 0 : 2,
    maximumFractionDigits: 2
  })}`;
}

module.exports = {
  formatFen
};

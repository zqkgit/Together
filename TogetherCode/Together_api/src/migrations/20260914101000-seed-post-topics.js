module.exports = {
  async up(queryInterface, Sequelize) {
    const seed = [
      { content: "可可今天的拼贴作品很棒！", topic: "水彩", images: ["https://picsum.photos/seed/yiqi-watercolor/600/800"] },
      { content: "小程序验收：推荐课程测试帖", topic: "黏土", images: ["https://picsum.photos/seed/yiqi-clay/600/800"] },
      { content: "周末写生作品分享", topic: "书法", images: ["https://picsum.photos/seed/yiqi-calligraphy/600/800"] },
      { content: "今天在画室和孩子们一起创作，氛围超好", topic: "素描", images: ["https://picsum.photos/seed/yiqi-sketch/600/800"] }
    ];
    for (const s of seed) {
      await queryInterface.sequelize.query(
        "UPDATE posts SET topic = :topic, images = JSON_ARRAY(:img) WHERE content = :content AND topic IS NULL",
        {
          replacements: { topic: s.topic, img: s.images[0], content: s.content },
          type: Sequelize.QueryTypes.UPDATE
        }
      );
    }
  },

  async down() {
    // 种子数据不回滚
  }
};

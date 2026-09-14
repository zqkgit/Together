const express = require("express");
const { requireAuth } = require("../middlewares/auth");
const {
  postFollow,
  deleteFollow,
  getFollowing,
  getFollowers
} = require("../controllers/followController");

const router = express.Router();

router.use(requireAuth);

// 用户关注关系：帖子详情 "+关注" / 个人主页关注
router.get("/following", getFollowing);
router.get("/followers", getFollowers);
router.post("/users/:id/follow", postFollow);
router.delete("/users/:id/follow", deleteFollow);

module.exports = router;

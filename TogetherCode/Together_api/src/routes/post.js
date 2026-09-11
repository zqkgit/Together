const express = require("express");
const { requireAuth, requireAuthOptional } = require("../middlewares/auth");
const {
  getPost,
  putPostLike,
  deletePostLike,
  getPostComments,
  postPostComment,
  deleteComment,
  postPostShare,
  getFeed,
  getPlaza,
  getMyPosts,
  postParentPost
} = require("../controllers/postController");

const router = express.Router();

// 公共帖子浏览（游客可看公开帖子；带 token 时附带互动状态）
router.get("/", getFeed);
router.get("/feed", getFeed);
router.get("/plaza", getPlaza);
// 我的帖子（需登录；放在 /:id 之前避免被当作 postId）
router.get("/mine", requireAuth, getMyPosts);
router.get("/:id", requireAuthOptional, getPost);
router.get("/:id/comments", requireAuthOptional, getPostComments);

// 以下需登录
router.post("/", requireAuth, postParentPost);
router.post("/:id/like", requireAuth, putPostLike);
router.delete("/:id/like", requireAuth, deletePostLike);
router.post("/:id/comments", requireAuth, postPostComment);
router.post("/:id/share", requireAuth, postPostShare);
router.delete("/comments/:id", requireAuth, deleteComment);

module.exports = router;

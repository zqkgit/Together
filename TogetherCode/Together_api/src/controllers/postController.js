const { ok, fail } = require("../utils/response");
const {
  getPostDetail,
  likePost,
  unlikePost,
  listPostComments,
  addPostComment,
  deletePostComment,
  listFeed,
  listPlaza,
  createParentPost
} = require("../services/postService");

async function getPost(req, res) {
  try {
    const data = await getPostDetail(req.params.id, req.user ? req.user.userId : null);
    if (!data) {
      return fail(res, 404, 40460, "帖子不存在或不可见");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putPostLike(req, res) {
  try {
    const data = await likePost(req.user.userId, req.params.id);
    if (!data) {
      return fail(res, 404, 40460, "帖子不存在或不可见");
    }
    return ok(res, data, "已点赞");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function deletePostLike(req, res) {
  try {
    const data = await unlikePost(req.user.userId, req.params.id);
    if (!data) {
      return fail(res, 404, 40460, "帖子不存在");
    }
    return ok(res, data, "已取消点赞");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getPostComments(req, res) {
  try {
    const data = await listPostComments(req.params.id, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postPostComment(req, res) {
  try {
    const content = String(req.body.content || "").trim();
    if (!content) {
      return fail(res, 400, 40061, "评论内容不能为空");
    }
    if (content.length > 500) {
      return fail(res, 400, 40061, "评论不能超过 500 字");
    }
    const data = await addPostComment(req.user.userId, req.params.id, content);
    if (!data) {
      return fail(res, 404, 40460, "帖子不存在或不可见");
    }
    return ok(res, data, "评论成功");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function deleteComment(req, res) {
  try {
    const data = await deletePostComment(req.user.userId, req.params.id);
    if (!data) {
      return fail(res, 404, 40462, "评论不存在或无权删除");
    }
    return ok(res, data, "评论已删除");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getFeed(req, res) {
  try {
    const data = await listFeed(req.user ? req.user.userId : null, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getPlaza(req, res) {
  try {
    const data = await listPlaza(req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postParentPost(req, res) {
  try {
    const result = await createParentPost(req.user.userId, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "发布成功");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getPost,
  putPostLike,
  deletePostLike,
  getPostComments,
  postPostComment,
  deleteComment,
  getFeed,
  getPlaza,
  postParentPost
};

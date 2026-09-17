const { ok, fail } = require("../utils/response");
const {
  getPostDetail,
  likePost,
  unlikePost,
  listPostComments,
  addPostComment,
  deletePostComment,
  likeComment,
  unlikeComment,
  sharePost,
  listFeed,
  listPlaza,
  listMyPosts,
  listChildFeed,
  createParentPost,
  updatePost,
  deletePost: deletePostService
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
    const query = { ...req.query, viewerUserId: req.user?.userId || null };
    const data = await listPostComments(req.params.id, query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 评论点赞（登录，幂等） */
async function putCommentLike(req, res) {
  try {
    const data = await likeComment(req.user.userId, req.params.commentId);
    if (!data) {
      return fail(res, 404, 40460, "评论不存在或已删除");
    }
    return ok(res, data, "已点赞");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 取消评论点赞（登录，幂等） */
async function deleteCommentLike(req, res) {
  try {
    const data = await unlikeComment(req.user.userId, req.params.commentId);
    if (!data) {
      return fail(res, 404, 40460, "评论不存在");
    }
    return ok(res, data, "已取消点赞");
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
    // parent_id 保持字符串（BIGINT 超过 JS 安全整数，数字会丢精度）
    const parentId = req.body.parent_id || 0;
    const data = await addPostComment(req.user.userId, req.params.id, content, parentId);
    if (!data) {
      return fail(res, 404, 40460, "帖子不存在或不可见");
    }
    return ok(res, data, "评论成功");
  } catch (error) {
    if (error.code === 40063) {
      return fail(res, 400, 40063, error.message);
    }
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

// POST /posts/:id/share · 分享到小程序
async function postPostShare(req, res) {
  try {
    const result = await sharePost(req.params.id);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "分享成功");
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

async function getMyPosts(req, res) {
  try {
    const data = await listMyPosts(req.user.userId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 孩子动态：我孩子相关的帖子 */
async function getChildFeed(req, res) {
  try {
    const data = await listChildFeed(req.user.userId, req.query);
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

async function putPost(req, res) {
  try {
    const result = await updatePost(req.user.userId, req.params.id, req.body);
    if (!result) {
      return fail(res, 404, 40400, "帖子不存在");
    }
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "编辑成功");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function deletePost(req, res) {
  try {
    const result = await deletePostService(req.user.userId, req.params.id);
    if (!result) {
      return fail(res, 404, 40400, "帖子不存在");
    }
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "删除成功");
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
  putCommentLike,
  deleteCommentLike,
  deleteComment,
  postPostShare,
  getFeed,
  getPlaza,
  getMyPosts,
  getChildFeed,
  postParentPost,
  putPost,
  deletePost
};

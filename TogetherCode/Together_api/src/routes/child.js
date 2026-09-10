const express = require("express");
const { requireAuth } = require("../middlewares/auth");
const { validateRequest } = require("../middlewares/validate");
const {
  childIdValidators,
  createChildValidators,
  updateChildValidators
} = require("../validators/childValidator");
const {
  getChildren,
  getChild,
  postChild,
  putChild
} = require("../controllers/childController");

const router = express.Router();

router.use(requireAuth);

// 角色归属：家长端接口。
// 已实现接口：我的孩子列表、孩子详情、添加孩子、编辑孩子。
router.get("/", getChildren);
router.get("/:id", childIdValidators, validateRequest, getChild);
router.post("/", createChildValidators, validateRequest, postChild);
router.put("/:id", updateChildValidators, validateRequest, putChild);

module.exports = router;

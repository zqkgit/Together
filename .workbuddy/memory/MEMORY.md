# 艺启 YIQI（Together）· 项目长期记忆

> 儿童艺术教育平台。四端 + 单一 Node 后端。仓库根：`/Users/shide/Desktop/qzCode/Together`
> 最后更新：2026-09-20

## 一、仓库布局（重要：存在新旧两套 iOS 目录）

```
Together/                      # 仓库根（git main，远程 origin/main）
├── 配置清单.md                 # 上线前必填配置（后端/小程序/微信后台三处）
├── TogetherCode/              # 全部工程代码
│   ├── Together_api/          # 后端（唯一业务中心）★
│   ├── Together_ios/          # iOS 工程（CocoaPods + Xcode）
│   │   ├── Together/          # ⚠️ 旧空骨架目录，忽略
│   │   └── Together_ios/      # ✅ 真实源码目录（106 个 .swift）
│   ├── Together-miniprogram/  # 微信小程序（Taro，React 语法）
│   ├── Together_admin-web/    # Web 管理端（Vue3 + Vite + Element Plus）
│   ├── Together_android/      # 仅 README + docs，未启动
│   ├── Together-harmony/      # 仅 README + docs，未启动
│   ├── ios-app-规划.md / ios-app-ui-规划.md / 上线配置清单.md
├── TogetherPr/                # 设计资产与规划文档（HTML 原型 60 屏 + 设计系统）
└── TogetherUI/                # 空
```

## 二、技术栈与端分工

| 端 | 技术栈 | 定位 |
|---|---|---|
| 后端 | Node 18+ / Express 5 / Sequelize / MySQL 8.4 / Redis 7 / ws | 唯一业务中心，`/v1`（App+小程序）、`/admin`（平台）、`/studio`（工作室） |
| iOS | Swift 6 / UIKit+组件化 / CocoaPods / iOS 15+ | **全功能主端**，家长+老师+工作室三角色 |
| 小程序 | Taro + TS（微信原生构建） | 轻量获客端：课程浏览/报名支付/分享落地 |
| Web | Vue3 + Vite + Element Plus + Pinia | B 端：工作室经营后台 + 平台治理 |

- 交易闭环（浏览→支付→课时到账）**iOS 与小程序全等**，共用 `/v1`，仅支付方式不同
- 内容社交（广场/发帖/私聊/成长档案）**只在 iOS**
- B 端经营与治理**只在 Web**
- 分销分享链路：iOS 发帖/课程 → 生成小程序码 → 小程序落地 → 引导下载 iOS

## 三、后端约定

- 启动：`docker compose up -d --build` → `http://localhost:3001/v1/health`（容器内 3000）
- 容器启动自动跑 migration + `db:seed:demo`
- 规模：49 个 model、30 个 route 文件、28 个 migration、36 个 service
- 响应包裹统一 `ok()/fail(res, httpStatus, code, msg)`；错误码如 `40401`=未注册号码
- 路由角色边界：`/admin/*` 平台 admin；`/studio/*` 工作室后台；`/v1/teacher/*` 老师 App；`/v1/children|orders|leave` 家长 App
- 演示账号：家长 `13800000000/123456`、平台 `platform_admin/123456`、工作室 `studio_owner_1/123456`，验证码固定 `123456`
- 接口加密：RSA-OAEP 换会话密钥 + AES-256-GCM；请求头 `X-Enc-Key` / `X-Enc-Nonce` / `X-Enc-Timestamp`（±5min）；上传与 WS 豁免；**四端已全接**，上线只需各端开关置 true
- 密钥文件 `Together_api/config/api_enc_*.pem`，已被 .gitignore 排除，严禁提交

## 四、上线前必填配置（三处）

1. 后端 `.env`：`JWT_SECRET`（必改）、`WX_APP_ID/SECRET`、`WX_PAY_*`、`OSS_*`(5项)、`JPUSH_*`、`API_ENCRYPT_*`、`DB_*`/`REDIS_URL`
2. 小程序 `src/config.ts`：`BASE_URL`、`ENV`、`WX_APP_ID`、`OSS_DOMAIN`、`SUBSCRIBE_TPL_IDS`、`WS_URL`、`API_ENCRYPT_ENABLED`
3. iOS `Together_ios/Together_ios/App/APIConfig.swift`：环境切换、`jpushAppKey`、`umengAppKey`、`apiEncryptEnabled`
4. Web `.env.production`：`VITE_API_BASE_URL`、`VITE_API_ENCRYPT_ENABLED`
5. 微信公众平台：服务器域名白名单（request/uploadFile/downloadFile/socket）、订阅消息模板

## 五、设计系统「温暖手作 v2」

- 底 `#FAF7F1`，主色深松绿 `#2F5D45`，木色记忆点 `#A87A3E`
- 标题 Noto Serif SC，正文/数据 Noto Sans SC
- 大圆角（卡片16/按钮12/pill 9999）+ 双层暖阴影；线性 SVG 图标，**禁用 emoji**
- 设计资产：`TogetherPr/YIQI设计系统v2.md`、`app-prototype.html`（46 屏原型，UAT 基准）
- 设计稿在 Ardot：https://ardot.tencent.com/file/721116261735448

## 六、角色体系与认证/入驻链路（2026-09-20 走查）

- 三角色：1 家长 / 2 老师 / 3 工作室；`user_roles` 表记录"已开通"身份；切换身份 `POST /auth/role/switch` 重发 token
- **入驻/认证提交**：iOS `StudioAuthViewController`（双入口：Mine / Studio 端"我的"）→ `POST /auth/role/apply`（`{role:"studio"|"teacher", payload}`）→ `roleApplyService.submitRoleApply` → 写 `studio_applications`（status: 0 待审/1 通过/2 驳回，`version` 留痕；已生效档案/待审中均拦截重提）
- **状态查询**：`GET /auth/role/apply/:role` 返回 `unauth/pending/approved/rejected`（含 `apply` 数据回显，驳回带 `reason`），驱动 iOS 显示表单/审核中/驳回重提三态
- **平台审核**：`adminStore.reviewStudioApplication`（Web `PUT /admin/.../studio-applications/:id`）→ 写 `studio_profiles` + `user_roles(role:3)` + 发 `cert` 通知；通过后才在切换身份弹窗出现"工作室·切换"
- 状态口径：DB 存整数 0/1/2，对外转字符串（注意 iOS 端、文档与 DB 三者口径要一致）
- 字段对齐：iOS 提交字段与 `ROLE_META.studio.fields` 完全一致（name/city/address/contact_name/phone/business_type/teacher_count/license/permit/intro/photos/cover）
- ⚠️ 已知缺陷：`MineViewController/StudioMineViewController` 在 `getRoleApplyStatus` 返回 `approved` 时无专属分支，会落入 default 重开空白表单而非引导进入工作室端；`uploadPhotosIfNeeded` 失败时静默返回空数组，提交被"请至少上传1张照片"拦截却无真实错误原因

## 七、注意

- git 提交信息统一为 "update"，无常规 commit 规范
- `TogetherCode/Together_api/.DS_Store`、`node_modules` 等已在 .gitignore

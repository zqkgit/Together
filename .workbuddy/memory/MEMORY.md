# 艺启 YIQI（Together）· 项目长期记忆

> 儿童艺术教育平台。四端 + 单一 Node 后端。仓库根：`/Users/shide/Desktop/qzCode/Together`
> 最后更新：2026-09-22

## 一、仓库布局（注意：iOS 有两套目录）

```
Together/
├── 配置清单.md                 # 上线前必填配置（以此为准）
├── TogetherCode/
│   ├── Together_api/          # 后端（唯一业务中心）★
│   ├── Together_ios/Together_ios/   # ✅ iOS 真实源码（外层 Together/ 是旧空骨架，忽略）
│   ├── Together-miniprogram/  # 小程序（Taro + React 语法）
│   ├── Together_admin-web/    # Web 管理端（Vue3 + Vite + Element Plus）
│   └── Together_android/、Together-harmony/  # 仅 README/docs，未启动
├── TogetherPr/                # 设计资产（HTML 原型 + 设计系统）
└── TogetherUI/                # 空
```

| 端 | 技术栈 | 定位 |
|---|---|---|
| 后端 | Node 18+ / Express 5 / Sequelize / MySQL 8.4 / Redis 7 / ws | `/v1`（App+小程序）、`/admin`（平台）、`/studio`（工作室后台） |
| iOS | Swift 6 / UIKit / CocoaPods / iOS 15+ | **全功能主端**，家长+老师+工作室三角色 |
| 小程序 | Taro + TS | 轻量获客：课程浏览/报名支付/分享落地 |
| Web | Vue3 + Vite + Element Plus + Pinia | B 端：工作室经营后台 + 平台治理 |

- 交易闭环（浏览→支付→课时到账）iOS 与小程序共用 `/v1`；**内容社交只在 iOS，B 端经营与治理只在 Web**
- 分销：iOS 发帖/课程 → 小程序码 → 小程序落地 → 引导下载 iOS

## 二、后端约定

- 启动：`docker compose up -d --build` → `http://localhost:3001/v1/health`（容器内 3000）；源码 volume 挂载 + nodemon 自动重启；容器启动跑 migration + `db:seed:demo`
- 响应统一 `ok()/fail(res, httpStatus, code, msg)`
- 路由角色边界：`/admin/*` 平台后台令牌；`/studio/*` 工作室后台令牌；`/v1/teacher/*` 老师 App；`/v1/children|orders|leave` 家长 App；`/v1/studio/*` 工作室 App（JWT）
- 演示账号：家长 `13800000000/123456`（兼老师+工作室 roles=[1,2,3]）、平台 `platform_admin/123456`、工作室后台 `studio_owner_1/123456`；验证码固定 `123456`
- 取 App 端 token：`POST /v1/auth/login-password` → `POST /v1/auth/role/switch {role:3}` 拿新 `access_token`
- 接口加密：RSA-OAEP 换会话密钥 + AES-256-GCM（头 `X-Enc-Key/Nonce/Timestamp`，±5min）；GET 参数、上传、WS 豁免；四端已全接，上线只需开关置 true。密钥 `config/api_enc_*.pem` 已 gitignore，严禁提交
- 上线前必填项见仓库根 `配置清单.md`（后端 `.env`、小程序 `src/config.ts`、iOS `App/APIConfig.swift`、Web `.env.production`、微信公众平台白名单/模板）

## 三、设计系统「温暖手作 v2」

- 底 `#FAF7F1`，主色深松绿 `#2F5D45`，木色 `#A87A3E`；标题 Noto Serif SC，正文 Noto Sans SC
- 大圆角（卡片 16 / 按钮 12）+ 双层暖阴影；线性 SVG 图标，**禁用 emoji**
- 资产：`TogetherPr/YIQI设计系统v2.md`、`app-prototype.html`（UAT 基准）；Ardot https://ardot.tencent.com/file/721116261735448
- iOS `Core/Design/Theme.swift`：`Theme.Color`（bg/surface/surfaceAlt/line/ink/sub/muted/brand/brandDark/brandSoft/wood/clay/warn/danger）、`Theme.Radius`、`Theme.Spacing`（s8/m12/l16/xl24）、`UIFont.appTitle/appHero/appSection/appBody/appLabel`
- ⚠️ `Theme.Spacing.m = 12`（**不是 16**），16pt 边距用 `Spacing.l`
- 设计稿配色与主题色 1:1（`#C77B2A`=warn、`#E8F0EA`=brandSoft、`#9C948A`=muted、`#726A60`=sub、`#22422F`=brandDark）→ 出图前可先采样设计稿像素确认

## 四、角色体系与认证/入驻

- 1 家长 / 2 老师 / 3 工作室；`user_roles` 记"已开通"；`POST /auth/role/switch` 重发 token
- 提交 iOS `StudioAuthViewController` → `POST /auth/role/apply` → `studio_applications`（0 待审/1 通过/2 驳回）；查询 `GET /auth/role/apply/:role` → `unauth/pending/approved/rejected`
- 审核 Web `PUT /admin/reviews/:id` → 写 `studio_profiles` + `user_roles(3)` + `ensureStudioOwnerAccount` 开后台号 + 发 `cert` 通知
- ⚠️ **Web 后台账号独立体系** `admin_accounts`（username + bcrypt），与 C 端 `users`（手机号）**不通用**。App 入驻只写 `user_roles` 不建后台号 → 主理人登不了 Web；已在审核通过时自动开号（username＝主理人手机号、初始密码 `123456`，`adminStore.ensureStudioOwnerAccount` 幂等）；历史工作室用 `npm run db:seed:studio-admin` 补号
- ⚠️ **切换身份弹窗数据源铁律**：`RoleSwitchSheet` 四态完全由调用方传入的 `roles` 决定（组件不查接口）→ 必须传 `/auth/me` 的 `roles`，**不能用角色专属档案接口**（`/v1/teacher/mine`、`/v1/studio/mine` 无 roles）。曾踩坑：`TeacherMineViewController` 写死 `owned = [1, 2]`，已开通工作室的账号恒显「去认证」。三端统一 `mineProfile?.roles ?? (userRole > 1 ? [1, userRole] : [1])`，`showRoleSheet()` 先拉 `/auth/me`
- 三端 `handleNeedAuth` 均有 `status == "approved" → switchRole(role)` 分支

## 五、帖子位置与距离推荐

- `posts` 加 `latitude/longitude/location_name`（选填）；写入走 `postService.createParentPost` / `teacherService.createTeacherPost`（`pickLocation()` 校验范围，非法整体忽略）
- `listPlaza`/`listFeed` 支持 `sort=near` + `lat/lng`：haversine（R=6371km，注入 `distance_km`）升序；无坐标退化 `latest`
- iOS：`Services/LocationManager.swift`、`Plaza/LocationSearchViewController`、`LocationPickerViewController`；`PostItem.distanceText`（<1km 显 Xm）
- ⚠️ **`LocationManager` 崩溃教训**：`locationManagerDidChangeAuthorization` 里禁止包闭包再调 `self?.pending`（与 `didUpdateLocations` 的 `pending?(loc)` 无限递归 → 栈溢出）

## 六、工作室端（App）

- **双令牌体系（关键）**：Web `/studio/*` 用后台令牌（`requireBackofficeAuth`）；App 用 `requireAuth + requireRole`（JWT）。不可混用 → App 独立 `/v1/studio/*`（`routes/studioApp.js` + `controllers/studioAppController.js` + `services/studioAppService.js`）
- **Tab**：概览 / 广场 / ➕发布 / 消息 / 我的；课程/学员/老师管理、退款审核收进「我的」菜单；消息角标取 `items[3]`；push 二级页由 `BaseNavigationController` 自动隐藏 tabbar
- **发布角色门**：`POST /v1/teacher/posts` 受顶部 `requireRole(2)` 约束，**role=3 会 403** → 工作室发布走通用 `POST /v1/posts`
- **「我的」页**：`headerView` 挂 `view` 顶部固定（不进滚动视图），下方 `scrollView.top = headerView.bottom`；统计卡是 header 子视图
- `GET /v1/studio/overview`：`revenue{month_income,withdrawable,distribution,settling}` + `stats{active_students,online_courses,teachers}` + `todos{pending_refunds,pending_payouts,pending_settle_orders,pending_settle_amount}` + `dynamic{...,headline}`
  - ⚠️ **金额单位坑**：接口统一返「分」，但库里 `orders.paid_amount`/`settlements.payable_amount`/`courses.price` 是**分**，`wallets.balance`/`commission_records.amount` 是**元**（×100 对齐）
  - 口径：本月营收＝本月已支付订单合计；可提现＝主理人 `wallets.balance`；分销返利＝本月 `commission_records`；结算中＝`settlements.status=0` 的 payable 合计；`dynamic.headline` 用真实数据拼装，**不要用 `posts` 正文**（会抓到该用户以家长身份发的帖）
  - iOS：固定 `StudioOverviewHeaderView`（标题栏＋营收卡＋三统计卡＋「待办事项 全部 ›」区头）+ 下方 `.plain` tableView；**待办事项页** `StudioTodoViewController`（「全部 ›」push，前两行进 `StudioRefundViewController(initialStatus: 0/1)`，结算行只 toast 交 Web）
- `GET /v1/studio/students`（App 学员管理，2026-09-22 新增）：`summary{all,renew,new}` + `list[]`
  - **summary 恒按工作室全量学员统计**（不受 filter/q 影响），与设计稿「全部/待续费/本月新增」一致；`filter=all|renew|new`，`q` 匹配学员昵称或家长昵称，**在 JS 层过滤**（先全量拉再筛，保证 chips 口径稳定）
  - **待续费**＝总剩余课时 ≤ 3（含耗尽）；**本月新增**＝在本工作室**最早一笔订单的 `paid_at`** 落在本月 —— 必须用 `paid_at` 而非 `created_at`（seeder 回填 paid_at 造历史数据，`created_at` 是插库时间，会把全部人算成本月新增）
  - 行字段：`child_id/nickname/avatar/age/course_title/parent_name/parent_phone/remaining_lessons/total_lessons/consumed_lessons/renew/is_new/enrolled_at`；`course_title` 取**最近一笔订单**对应课程（同时间多门时用 balance_id 兜底排序）
  - 详情 `GET /v1/studio/students/:id` → `student` + `balances[]` + `logs[]`（复用 `listStudentLessonLogs`，limit 50）
  - 底层共用 `loadStudioStudentRows(studioId, query)`（Web `/admin/students` 与 App 都走它，Web 行为不变）
- **演示数据** `api/src/seeders/studio-overview-demo.js`（`npm run db:seed:overview`，幂等）：主理工作室「兰亭书画」是运行时注册的，`bootstrap-demo` 不含它 → 概览全 0，需跑此脚本。含 7 名学员（2 名待续费、3 名本月新增）；`ensurePaidOrder({remainingLessons})` 可造出「已消耗一部分」的账本
- 「我的」菜单共用 `Core/Components/MineMenuCardView.swift`（`MineMenuItem` / `MineMenuRow` / `MineMenuCardView(groups:)`），三端统一

## 七、iOS 编译与视觉验证

- **编译**：`cd TogetherCode/Together_ios && xcodebuild -workspace Together_ios.xcworkspace -scheme Together_ios -destination id=<booted UDID> -configuration Debug -derivedDataPath build build`；产物 `build/Build/Products/Debug-iphonesimulator/Together_ios.app`；BundleId `ymjr.com.Together-ios`；一键脚本 `rebuild.sh`
- 沙箱 xcodebuild 末尾 shell 非 0 常因 keychain 写被拦，**以 `** BUILD SUCCEEDED **` 为准**
- 预览需登录态/角色时，用 `--preview-*` 启动参数临时强切；**验证后必须删净并重新干净编译**（`grep -rn "preview-" Together_ios/` 确认）
- ⚠️ **切角色必须换 token**：`/v1/studio/*` 有 `requireRole(3)`，只改 `TokenManager.userRole` 不够（旧 JWT role 不符 → 403）。预览钩子里先 `AuthService.loginPassword` 再 `switchRole(3)` 存新 token
- 完整流程与踩坑见 skill `ios-simulator-preview-verify`；间距对不上**先 NSLog 打数值**（frame.minY / contentInset.top / sectionHeaderTopPadding），像素扫描只用来复核（@3x 截图 ÷3 = pt；`#FFFFFF` 与页面底 `#FAF7F1` 用 B 通道区分）

## 八、UIKit 布局踩坑清单

详见 skill `ios-simulator-preview-verify`（已收录：SnapKit 跨层级崩溃、`sectionHeaderTopPadding`、cell 高度欠定塌缩、定位别用不等式、自定义初始化器 cell 不能 register、卡片别在 cell 间搬移）。补充两条本文件独有的：

- ⚠️ **两侧 UILabel 抢宽度**：给不可截断的一侧设 `setContentCompressionResistancePriority(.required, for: .horizontal)`，否则右侧数值会被左侧长文本挤成「剩余…」
- ⚠️ **`Theme.Spacing.m = 12`**、16pt 边距用 `Spacing.l`（写错会整体偏移 4pt）

## 九、注意

- git 提交信息统一为 "update"
- 沙箱 Bash 里 `grep` 常返回空 → 改用 Grep 工具；查 MySQL 中文需 `--default-character-set=utf8mb4`
- 仍存缺陷：`uploadPhotosIfNeeded` 失败静默返回空数组 → 提交被"请至少上传1张照片"拦截却无真实原因

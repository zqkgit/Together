# 艺启 YIQI（Together）· 项目长期记忆

> 儿童艺术教育平台。四端 + 单一 Node 后端。仓库根：`/Users/shide/Desktop/qzCode/Together`
> 最后更新：2026-09-21

## 一、仓库布局（注意：iOS 有两套目录）

```
Together/                      # 仓库根（git main，远程 origin/main）
├── 配置清单.md                 # 上线前必填配置
├── TogetherCode/              # 全部工程代码
│   ├── Together_api/          # 后端（唯一业务中心）★
│   ├── Together_ios/          # iOS 工程（CocoaPods + Xcode）
│   │   ├── Together/          # ⚠️ 旧空骨架目录，忽略
│   │   └── Together_ios/      # ✅ 真实源码目录（106 个 .swift）
│   ├── Together-miniprogram/  # 微信小程序（Taro，React 语法）
│   ├── Together_admin-web/    # Web 管理端（Vue3 + Vite + Element Plus）
│   ├── Together_android/      # 仅 README + docs，未启动
│   ├── Together-harmony/      # 仅 README + docs，未启动
├── TogetherPr/                # 设计资产（HTML 原型 60 屏 + 设计系统）
└── TogetherUI/                # 空
```

## 二、技术栈与端分工

| 端 | 技术栈 | 定位 |
|---|---|---|
| 后端 | Node 18+ / Express 5 / Sequelize / MySQL 8.4 / Redis 7 / ws | 唯一业务中心：`/v1`（App+小程序）、`/admin`（平台）、`/studio`（工作室） |
| iOS | Swift 6 / UIKit+组件化 / CocoaPods / iOS 15+ | **全功能主端**，家长+老师+工作室三角色 |
| 小程序 | Taro + TS | 轻量获客端：课程浏览/报名支付/分享落地 |
| Web | Vue3 + Vite + Element Plus + Pinia | B 端：工作室经营后台 + 平台治理 |

- 交易闭环（浏览→支付→课时到账）iOS 与小程序共用 `/v1`，仅支付方式不同；**内容社交只在 iOS，B 端经营与治理只在 Web**
- 分销链路：iOS 发帖/课程 → 生成小程序码 → 小程序落地 → 引导下载 iOS

## 三、后端约定

- 启动：`docker compose up -d --build` → `http://localhost:3001/v1/health`（容器内 3000）；容器启动自动跑 migration + `db:seed:demo`
- 规模：49 model、30 route、28 migration、36 service；响应包裹统一 `ok()/fail(res, httpStatus, code, msg)`
- 路由角色边界：`/admin/*` 平台 admin（后台令牌）；`/studio/*` 工作室后台（后台令牌 scope=studio）；`/v1/teacher/*` 老师 App；`/v1/children|orders|leave` 家长 App；**`/v1/studio/*` 工作室 App（JWT，2026-09-21 新增）**
- 演示账号：家长 `13800000000/123456`（也是老师+工作室，roles=[1,2,3]）、平台 `platform_admin/123456`、工作室后台 `studio_owner_1/123456`，验证码固定 `123456`
- 接口加密：RSA-OAEP 换会话密钥 + AES-256-GCM；头 `X-Enc-Key`/`X-Enc-Nonce`/`X-Enc-Timestamp`（±5min）；上传与 WS 豁免；四端已全接，上线只需开关置 true。密钥 `config/api_enc_*.pem` 已被 gitignore，严禁提交

## 四、上线前必填配置

1. 后端 `.env`：`JWT_SECRET`（必改）、`WX_APP_ID/SECRET`、`WX_PAY_*`、`OSS_*`、`JPUSH_*`、`API_ENCRYPT_*`、`DB_*`/`REDIS_URL`
2. 小程序 `src/config.ts`：`BASE_URL`、`ENV`、`WX_APP_ID`、`OSS_DOMAIN`、`SUBSCRIBE_TPL_IDS`、`WS_URL`、`API_ENCRYPT_ENABLED`
3. iOS `App/APIConfig.swift`：环境切换、`jpushAppKey`、`umengAppKey`、`apiEncryptEnabled`
4. Web `.env.production`：`VITE_API_BASE_URL`、`VITE_API_ENCRYPT_ENABLED`
5. 微信公众平台：服务器域名白名单、订阅消息模板

## 五、设计系统「温暖手作 v2」

- 底 `#FAF7F1`，主色深松绿 `#2F5D45`，木色 `#A87A3E`；标题 Noto Serif SC，正文 Noto Sans SC
- 大圆角（卡片16/按钮12）+ 双层暖阴影；线性 SVG 图标，**禁用 emoji**
- 资产：`TogetherPr/YIQI设计系统v2.md`、`app-prototype.html`（46 屏原型，UAT 基准）；Ardot https://ardot.tencent.com/file/721116261735448
- iOS 主题在 `Core/Design/Theme.swift`（`Theme.Color/Radius/Spacing` + `UIFont.appTitle/appHero/appSection/appBody/appLabel`）

## 六、角色体系与认证/入驻

- 三角色：1 家长 / 2 老师 / 3 工作室；`user_roles` 记录"已开通"身份；`POST /auth/role/switch` 重发 token
- 提交：iOS `StudioAuthViewController` → `POST /auth/role/apply` → `studio_applications`（status 0 待审/1 通过/2 驳回，`version` 留痕）
- 查询：`GET /auth/role/apply/:role` → `unauth/pending/approved/rejected`（含 `apply` 回显、驳回带 `reason`）
- 审核：Web `PUT /admin/reviews/:id`（`{action:"approve"|"reject"}`）→ 写 `studio_profiles` + `user_roles(role:3)` + `ensureStudioOwnerAccount` 开后台号 + 发 `cert` 通知
- ⚠️ **Web 后台账号是独立体系** `admin_accounts`（username + bcrypt，scope 由 role 定：platform∈[platform_super,platform_ops]、studio∈[studio_owner,studio_ops]），与 C 端 `users`（手机号）**不通用**。App 入驻只写 `user_roles`，**不建后台号** → 主理人登不了 Web。已在审核通过时自动开号（username＝主理人注册手机号，初始密码 `123456`，`adminStore.ensureStudioOwnerAccount` 幂等）；历史工作室用 `npm run db:seed:studio-admin` 补号
- ⚠️ **切换身份弹窗数据源铁律**：`RoleSwitchSheet` 的四态（当前/切换/审核中/已驳回/去认证）**完全由调用方传入的 `roles` 决定**，组件自身不查接口。所以必须传 `/auth/me` 的 `roles`，**不能用角色专属档案接口**（`/v1/teacher/mine`、`/v1/studio/mine` 都无 roles 字段）。曾踩坑：`TeacherMineViewController` 写死 `owned = [1, 2]`，已开通工作室的账号恒显示「去认证」。三端现统一为 `mineProfile?.roles ?? (userRole > 1 ? [1, userRole] : [1])`，且 `showRoleSheet()` 先拉 `/auth/me` 再弹窗
- 三端 `handleNeedAuth` 均有 `status == "approved" → switchRole(role)` 分支
- ⚠️ 仍存缺陷：`uploadPhotosIfNeeded` 失败静默返回空数组，提交被"请至少上传1张照片"拦截却无真实原因

## 七、帖子位置与距离推荐

- `posts` 新增 `latitude/longitude/location_name`（选填，NULL）；写入走 `postService.createParentPost` / `teacherService.createTeacherPost`（`pickLocation()` 做范围校验，非法整体忽略）
- 距离排序：`listPlaza` / `listFeed` 支持 `sort=near` + `lat/lng`，haversine（R=6371km，`attributes.include` 注入 `distance_km`）升序；`near` 模式仅列带位置帖，无坐标时退化为 `latest`。返回含 `location{...}` 与 `distance_km`
- iOS：`Services/LocationManager.swift`（授权+取坐标+lastLocation 缓存）、`Modules/Plaza/LocationSearchViewController.swift`（搜索/当前位置/附近地点 + 「在地图上选取」）/`LocationPickerViewController.swift`（地图点选+反地理编码）；`PostItem.distanceText`（<1km 显 Xm）；广场排序 chips（最新/热门/附近）
- **`LocationManager` 崩溃教训**：`locationManagerDidChangeAuthorization` 里**禁止**包闭包再调 `self?.pending`（与 `didUpdateLocations` 的 `pending?(loc)` 形成无限递归 → 栈溢出 EXC_BAD_ACCESS code=2）

## 八、工作室端（App）

- **双令牌体系（关键）**：Web `/studio/*` 用后台令牌（`requireBackofficeAuth("studio")`）；App 用 `requireAuth`+`requireRole`（JWT）。**不可混用** → App 端独立 `/v1/studio/*`（`routes/studioApp.js` + `controllers/studioAppController.js` + `services/studioAppService.js`）
- **Tab 结构**：概览 / 广场 / ➕发布 / 消息 / 我的（与家长老师同构）。课程/学员/老师管理、退款审核收进「我的」页菜单。消息角标取 `items[3]`
- **发布角色门**：`POST /v1/teacher/posts` 受 `routes/teacher.js` 顶部 `router.use(requireAuth, requireRole(2))` 约束，**role=3 会 403**；`POST /v1/posts`（通用动态）无角色门 → 工作室发布走通用链路
- **「我的」页**：`headerView` 挂 `view`（**不进滚动视图**，顶部固定），下方 `scrollView.top = headerView.bottom` 独立滚动；统计卡是 header 的子视图（与家长端同构）。`contentInset.bottom = safeAreaInsets.bottom + 12`
- **「经营概览」** `GET /v1/studio/overview`：
  - 返回 `revenue{month_income,withdrawable,distribution,settling}` + `stats{active_students,online_courses,teachers}` + `todos{pending_refunds,pending_settle_orders,pending_settle_amount}` + `dynamic{studio_name,today_enrolled,weekly_enrolled,weekly_income,distribution_ratio,headline}`
  - ⚠️ **金额单位坑**：接口**统一返回「分」**，但库中单位不一致 —— `orders.paid_amount`、`settlements.payable_amount`、`courses.price` 是**分**；`wallets.balance`、`commission_records.amount` 是**元**（×100 转分）
  - 口径：本月营收＝本月已支付订单合计；可提现＝主理人 `wallets.balance`；分销返利＝本月 `commission_records`（JOIN distribution_links→courses 归属 studio）；结算中＝`settlements.status=0` 的 `payable_amount` 合计；待结算订单＝落在待打款结算单周期内的已支付订单（无则取最近 `period_end` 之后的新单）
  - `dynamic.headline` 是真实数据拼装的经营播报（新课上线天数＋累计报名＋分销占比），**不要用 `posts` 正文**（会抓到该用户以家长身份发的帖）
  - iOS：`Modules/Studio/StudioOverviewViewController.swift`（私有组件 `OverviewStatCard/OverviewTodoRow/OverviewDynamicCard`）；`StudioAmount` 提供 `¥ 86,420` 千分位口径（既有 `Int.fenToYuanText` 无千分位）
  - **演示数据**：`api/src/seeders/studio-overview-demo.js`（`npm run db:seed:overview`，幂等）。演示账号的主理工作室「兰亭书画」是**运行时注册**的，`bootstrap-demo` 不含它 → 概览全 0，需跑此脚本补课程/教师/学员/订单/退款/结算单/钱包
- **「我的」页菜单共用组件** `Core/Components/MineMenuCardView.swift`：`MineMenuItem{icon,title}` + `MineMenuRow: UIControl`（34×34 brandSoft 圆角图标块 + 20pt brand 图标 + 标题 + chevron，行高 60）+ `MineMenuCardView(groups:)`（白卡圆角18+暖阴影，组间 18pt spacer）。三端「我的」统一使用（旧 `MenuCell.swift` 已删）
- **SnapKit 铁律**：被其它视图约束引用的子视图，**必须先 `addSubview` 并完成自身约束，再被引用**；否则 `snp.makeConstraints` 立即激活跨层级约束 → `NSInternalInconsistencyException`
- **切角色必须换 token**：`/v1/studio/*` 有 `requireRole(3)`，只改 `TokenManager.userRole` 不够（旧 JWT 的 role 不符 → 403）。正确做法：启动时调 `AuthService.switchRole(3)` 保存新 token，再 post `.userRoleDidChange` 触发 `setupTabs()` 重建

## 九、注意

- git 提交信息统一为 "update"，无常规 commit 规范
- **iOS 可在本环境直接编译验证**（勿写"未编译"）：`cd TogetherCode/Together_ios && xcodebuild -workspace Together_ios.xcworkspace -scheme Together_ios -destination id=<booted UDID> -configuration Debug -derivedDataPath build build`；产物 `build/Build/Products/Debug-iphonesimulator/Together_ios.app`；BundleId `ymjr.com.Together-ios`；常用模拟器 iPhone 15 Pro UDID `9086EE2C-0737-4ECE-ADD2-3C561031E7CE`；一键脚本 `TogetherCode/Together_ios/rebuild.sh`
- 沙箱 xcodebuild 末尾 `failed` 常因 keychain 写被拦截，代码本身已 `BUILD SUCCEEDED`，勿误判
- 沙箱 `grep` 在 Bash 里常返回空 → 改用 Grep 工具；查 MySQL 中文需 `--default-character-set=utf8mb4`
- 视觉验证：用 `--preview-*` 启动参数临时强切角色，**验证后必须全部删除并重新干净编译**

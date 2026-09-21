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

## 七、帖子位置与距离推荐（2026-09-20 新增，后台先行）

- **背景**：App 需封装"选择地点"功能（发帖选点 + 按距离推荐）。本期先落地后台，App 端后续。
- **数据模型**：`posts` 表新增 `latitude` DECIMAL(10,8)、`longitude` DECIMAL(11,8)、`location_name` VARCHAR(128)，均 NULL（选填）。migration：`20260920170000-add-post-location.js`，容器启动自动跑。
- **写入位置**：`postService.createParentPost` 与 `teacherService.createTeacherPost` 的 `Post.create` 均接 `latitude/longitude/location_name`；`pickLocation()` 做范围校验（lat∈[-90,90]、lng∈[-180,180]），非法则整体忽略为 NULL，保证选填语义。
- **校验**：`teacherValidator.createTeacherPostValidators` 增加 `latitude/longitude`（可选浮点范围）、`location_name`（可选≤128 字符）；家长帖 `POST /v1/posts` 无 validator，body 直接透传。
- **距离排序**：`listPlaza` 与 `listFeed` 支持 `sort=near` + query `lat/lng`；用 haversine（地球半径 6371km，`attributes.include` 注入计算列 `distance_km`）按距离升序；`near` 模式 `WHERE latitude IS NOT NULL` 仅列带位置帖；无经纬度时 `near` 退化为 `latest`。
- **返回**：`normalizePostItem` / `teacherService.normalizePost` 均输出 `location {latitude,longitude,name}`（无坐标 null）与 `distance_km`（仅请求带 viewer 坐标时存在，纯数字 km 或 null）。
- **App 端已完成（2026-09-20 续，与后台闭环）**：
  - 定位封装 `Services/LocationManager.swift`（WhenInUse 授权 + 异步取坐标 + lastLocation 缓存）
  - 选点页 `Modules/Plaza/LocationPickerViewController.swift`（MKMapView 点图落点 + CLGeocoder 反地理编码出地点名）
  - 模型 `HomeModels.swift`：`PostLocation` 结构 + `PostItem.location/distance_km` + `distanceText`（<1km 显 Xm，否则 X.Xkm）
  - 发帖基类 `BasePostCreateViewController`：selectedLocation 属性 + 位置 section（选填，已选可"不显示位置"清除）；Parent/Teacher 发帖页透传位置（含编辑回显）
  - `PostService`：createPost/createTeacherPost/updatePost/updateTeacherPost/fetchPlaza 全加位置参数；fetchPlaza 传 lat/lng
  - 广场 `PlazaViewController`：排序 chips（最新/热门/附近），near 模式先取用户坐标再 reload（未授权 toast 退最新）
  - 展示：`WorkCardView` 作者行拼距离；`PostDetailViewController` 详情新增 location section（有位置才显示）
  - `Info.plist` 加 `NSLocationWhenInUseUsageDescription`；工程用 Xcode 16 PBXFileSystemSynchronizedRootGroup，新 swift 自动纳编无需改 pbxproj
- **选点入口已升级（9-21）**：`BasePostCreateViewController.openLocationPicker()` → present `LocationSearchViewController`（pageSheet 半屏）。该页含「搜索地点」实时检索（MKLocalSearch）、「当前位置」（定位+CLGeocoder 反地理编码，带"当前位置"标签）、「附近地点」、「在地图上选取」二级页（复用 `LocationPickerViewController`）。
- **附近地点**：数据源 `MKLocalPointsOfInterestRequest(center:radius:)`；中国区/模拟器无定位时召回稀疏或空 → section 整块消失。已加兜底 `fetchNearbyByKeyword`（["美食","咖啡","便利店","超市"] 并行 `MKLocalSearch.Request` + `DispatchGroup` 合并 + 去重/3km/距离排序）与空态提示。
- **`LocationManager` 崩溃教训**：`locationManagerDidChangeAuthorization` 里**禁止**包一层闭包再调 `self?.pending`（会与 `didUpdateLocations` 的 `pending?(loc)` 形成无限递归→栈溢出 EXC_BAD_ACCESS code=2）。授权后应直接复用已有 `pending` 调 `startLocating`。

## 八、工作室 App「我的」页与 /v1/studio App 路由（2026-09-21）

- **双令牌体系（关键）**：Web `/studio/*` 用后台令牌（`requireBackofficeAuth("studio")`，scope=studio）；App 端用 `requireAuth`+`requireRole`（JWT access_token，tokenType=user）。**两者不可混用**，故 App 端新增独立 **`/v1/studio/*`** 路由（`routes/studioApp.js` + `controllers/studioAppController.js` + `services/studioAppService.js`，`GET /mine`）。
- 数据口径与 Web 经营概览同源（`studio_profiles.user_id` ↔ 登录用户）：在读学员（ChildCourseBalance 去重 remaining_lessons>0）、在售课程（Course.status=1）、入驻教师（TeacherStudioBinding.status=1）、待退款（Refund.status=0）。
- iOS：`Services/StudioService.swift` + `Modules/Studio/StudioMineHeaderView.swift` + 重写 `Modules/Studio/StudioMineViewController.swift`。菜单第二组对齐原型 4 项：提现 / 分销返利设置 / 收益中心 / 设置。
- **「我的」页顶部必须固定（与家长端同构，2026-09-21 二次修正）**：`headerView` 直接挂 `view`（top/leading/trailing），**不进滚动视图**；下方菜单区 `scrollView.top = headerView.bottom` 独立滚动。**统计卡是 `StudioMineHeaderView` 的子视图**（`top = userRow.bottom + 22`、`leading.trailing inset 16`、`bottom = superview.inset(14)`，header 高度由卡底决定），因此封面与统计卡一起固定。家长端 `MineViewController`/`MineHeaderView` 即此结构（`statCard` 在 header 内）。原「白卡上浮压边」的 `bottomInset` 留白方案已废弃。
- **SnapKit 铁律**：被其它视图约束引用的子视图，**必须先 `addSubview` 并完成自身约束，再被引用**；否则 `snp.makeConstraints` 立即激活跨层级约束 → `NSInternalInconsistencyException`（本次 `StudioMenuRow` 崩溃根因）。
- 无登录态视觉验证：`--preview-studio` 启动参数临时强切工作室角色并默认选中「我的」（改 `TokenManager` / `MainTabBarController.setupTabs` / `refreshData` 走 mock），**验证后必须全部删除并重新干净编译**。

### 工作室 Tab 结构（2026-09-21 定稿）
- 工作室 role=3 的 tab 与家长/老师**同构**：概览 / 广场 / ➕发布 / 消息 / 我的（`MainTabBarController.setupTabs` 的 role==3 分支）。课程管理、学员管理、老师管理、退款审核收进「我的」页菜单，**不再单独占 tab**。
- 消息角标 `handleUnreadChanged` 取 `items[3]`，三套角色 index 3 均为「消息」，一致。
- **发布接口角色门（关键）**：`POST /v1/teacher/posts` 在 `routes/teacher.js` 顶部 `router.use(requireAuth, requireRole(2))`，**role=3 会 403**；`POST /v1/posts`（通用动态）仅 `requireAuth`，无角色门 → 工作室发布走通用链路。`requireRole(...roles)` 支持变参，但 teacher.js 的 `router.use` 覆盖全部老师接口，整体放开风险大，**未改**。

### 「我的」页菜单共用组件（2026-09-21 三端统一）
- **`Core/Components/MineMenuCardView.swift`**：`MineMenuItem{icon,title}` + `MineMenuRow: UIControl`（34×34 brandSoft 圆角图标块 + 20pt brand 图标 + 标题 + chevron，行高 60）+ `MineMenuCardView(groups: [[MineMenuItem]])`（白卡圆角18+暖阴影，组间 18pt spacer，`onSelect` 回调）。**家长 / 老师 / 工作室三端「我的」菜单统一用它**，样式基准即工作室端。
- 老师端 `TeacherMineViewController`、家长端 `MineViewController`、工作室端 `StudioMineViewController` 均改为 `scrollView + MineMenuCardView`；家长端底部开通条 `MineAuthFooterView` 由 `tableFooterView` 改为 contentView 子视图（`updateAuthFooter()` 用 `snp.remakeConstraints` 隐藏时高度归零）。
- 旧 `Core/Components/MenuCell.swift` 已删除（三端不再用 tableView 做菜单）。
- 三端「我的」统一结构：`headerView` 固定 + `scrollView.top = headerView.bottom` + `contentInset.bottom = safeAreaInsets.bottom + 12`。

## 九、注意

- git 提交信息统一为 "update"，无常规 commit 规范
- `TogetherCode/Together_api/.DS_Store`、`node_modules` 等已在 .gitignore
- 沙箱无 docker，后端改动仅做 `node --check` 语法校验；真实验证需本地 `docker compose up -d --build` 起容器（自动跑 migration）
- **iOS 可在本环境直接编译验证（勿再写"未编译"，此前误判）**：`cd TogetherCode/Together_ios && xcodebuild -workspace Together_ios.xcworkspace -scheme Together_ios -destination id=<booted UDID> -configuration Debug -derivedDataPath build build`；产物 `build/Build/Products/Debug-iphonesimulator/Together_ios.app`；BundleId `ymjr.com.Together-ios`；模拟器定位 `xcrun simctl location <UDID> set <lat>,<lng>`；一键脚本 `TogetherCode/Together_ios/rebuild.sh`。Xcode 26.3，常用模拟器 iPhone 15 Pro / iOS 17.2 UDID `9086EE2C-0737-4ECE-ADD2-3C561031E7CE`

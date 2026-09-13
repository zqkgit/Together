# 艺启 iOS App（家长端）基础框架规划

> 工程：`TogetherCode/Together_ios` ｜ 语言：Swift 6 ｜ 部署目标：iOS 15+ ｜ 依赖：CocoaPods

## 一、技术选型

| 项 | 选择 | 说明 |
|---|---|---|
| 语言 | Swift 6 | 当前 Xcode 26 默认，Apple 新 API 全覆盖 |
| 架构 | MVVM + 轻路由 | 视图-模型-绑定分离，页面间跳转集中管理 |
| 网络 | Alamofire 封装 | 统一 baseURL/token/错误码/上传 |
| 构建 | CocoaPods | 全部三方依赖走 pod |
| 环境 | Debug / Staging / Prod 三套 | 默认 Debug → `http://127.0.0.1:3001` |

## 二、三方库清单（Podfile）

| 库 | 用途 |
|---|---|
| Alamofire | 网络请求 |
| SwiftyJSON | JSON 解析 |
| HandyJSON | 模型映射（服务端 snake_case 字段） |
| Kingfisher | 图片加载/缓存（OSS URL 直接可用） |
| SnapKit | 自动布局 |
| MJRefresh | 下拉刷新/上拉加载 |
| MBProgressHUD | 加载/提示 |
| IQKeyboardManagerSwift | 键盘处理 |
| KeychainSwift | token 安全存储 |
| JPush | 极光推送（消息双通道） |
| WechatOpenSDK | 微信分享（返利海报）/ 微信支付 |
| CocoaLumberjack | 日志（可选） |
| JLRoutes | 页面路由（可选） |

支付：微信支付走 WechatOpenSDK；iOS 内购用系统 StoreKit2（不引三方）。

## 三、工程结构

```
Together_ios/
├── Podfile
└── Together/                     # 主 Target
    ├── App/                      # AppDelegate / SceneDelegate / 路由注册 / 环境配置
    ├── Core/
    │   ├── Network/              # APIClient、APIError、TokenInterceptor、Uploader
    │   ├── Storage/              # KeychainToken、UserDefaults、本地缓存
    │   ├── Base/                 # BaseVC、BaseCell、空态/错误态组件
    │   └── Utils/                # 日期/金额/URL/分享码工具
    ├── Services/                 # 业务服务层（按域一个文件）
    │   ├── AuthService           # 登录/角色切换/认证状态
    │   ├── CourseService         # 课程/排课/签到
    │   ├── OrderService          # 订单/支付/退款
    │   ├── PostService           # 帖子/评论/点赞/举报
    │   ├── MessageService        # WS 连接/通知
    │   └── WalletService         # 钱包/提现/返利
    ├── Modules/                  # 业务模块（每模块 Views+ViewModels）
    │   ├── MainTab/              # 底部 5 Tab
    │   ├── Home/                 # 首页（公告横幅/热门课程/热词）
    │   ├── Course/               # 课程列表/详情/搜索
    │   ├── Plaza/                # 广场（帖子流/发帖/详情）
    │   ├── Message/              # 消息列表（WS 实时）
    │   ├── Mine/                 # 我的（孩子/订单/退款/钱包/收藏/成长记录）
    │   └── Teacher/              # 老师工作台（角色切换后，二期）
    ├── Resources/                # 图片/颜色/Assets
    └── Supporting/               # Info.plist / 桥接头
```

## 四、基础框架核心能力（对接现有后端）

1. **网络层**：统一 `/v1` 前缀；请求头注入 `Authorization: Bearer <token>`；统一错误码解析（code≠0 → 提示 message）；401 自动重新登录；上传 `POST /v1/upload`（files ≤9，folder 白名单 common/avatar/course/post/work/studio/cert，OSS 未配时 /uploads 兜底，与小程序一致）
2. **登录态**：家长 `POST /v1/auth/login-password` / 验证码登录 → token 存 Keychain；角色切换 `POST /v1/auth/role/switch`（家长/老师）；认证状态（老师认证/工作室认证/合作绑定）统一查询展示
3. **消息双通道**：WebSocket `GET /v1/messages/ws/token` → 连接 `/ws`（ticket 5 分钟）实时收通知 + 极光 JPush 离线补发；消息类型文案/跳转与小程序对齐（order/course/commission/post/system/like/comment/refund/leave/invite/withdraw/cert/growth/attendance）
4. **分享返利**：课程/帖子生成分享码 → 海报 → 微信分享；下单带 `distribution_code` 自动返利（后端已闭环）
5. **支付**：微信支付（WechatOpenSDK 拉起）+ StoreKit2 内购；支付回调 `POST /v1/orders/:id/pay`
6. **环境切换**：Debug 默认 127.0.0.1:3001，一键切换（截图发真机测试用）

## 五、页面清单（家长端，对照小程序 H5）

**主 Tab 5 个**：首页 / 课程 / 广场 / 消息 / 我的

| 模块 | 页面 |
|---|---|
| 首页 | 公告横幅(可点)、热词搜索、推荐课程/老师、工作室 |
| 课程 | 课程列表/搜索、课程详情、课程海报、班级/排课、下单/支付 |
| 广场 | 帖子流、帖子详情、发帖（选课程→班级→孩子）、评论/点赞/收藏/举报、老师发帖消课 |
| 消息 | 通知列表（类型标签/跳转）、未读数 |
| 我的 | 个人资料、孩子管理（成长记录/课表/签到消课）、订单列表/详情、退款列表/详情、钱包/提现、收藏、我的帖子、设置（角色切换/退出） |
| 二期 | 老师工作台（认证申请、合作申请、班级/排课/学员管理） |

## 六、里程碑

| 阶段 | 内容 | 验收 |
|---|---|---|
| M1 脚手架 | pod init + 工程骨架 + 网络层 + 登录 + 主 Tab 骨架 | 真机/模拟器登录成功进首页 |
| M2 基础业务 | 首页/课程列表/详情/下单支付、孩子管理 | 走通下单支付链路 |
| M3 内容 | 广场发帖/详情/评论/点赞/举报/收藏、分享返利海报 | 发帖→家长通知闭环 |
| M4 消息 | WS + JPush、通知列表/跳转 | 实时收到通知 |
| M5 钱包 | 订单/退款/钱包/提现 | 提现全链路 |
| M6 老师端 | 角色切换后老师工作台（可选） | — |

## 七、待确认

- [ ] 语言 Swift（默认，不用 OC）
- [ ] 部署目标 iOS 15+（默认，覆盖存量 iPhone）
- [ ] 工程目录 `TogetherCode/Together_ios`（默认）
- [ ] 推送先用极光 JPush（与后端 jpush 配置一致）

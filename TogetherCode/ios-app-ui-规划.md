# iOS App UI 样式规划（对齐 YIQI 设计系统 v2「温暖手作」）

> 依据：`TogetherPr/YIQI设计系统v2.md` + `TogetherPr/app-prototype.html`（46 屏高保真原型）
> 工程：`Together_ios`（Swift + UIKit，MVVM）
> 目标：iOS 端从「占位页」升级为符合设计系统的视觉骨架，后续各模块页面直接复用原子组件

---

## 一、设计语言（一句话）

**暖纸感底色 + 深松绿主操作 + 木色/陶土橙记忆点 + 衬线标题 + 大圆角卡片 + 双层暖阴影**

- 任何中性色都不得纯灰/纯白，一律带黄褐 undertone（纸张感）
- 深松绿只用于「操作」与「选中」，大面积交给暖米白
- 木色（画架）+ 陶土橙（颜料）成对出现，是「艺启 = 儿童艺术」的视觉签名
- 衬线只在标题位；数据、正文、标签一律无衬线

---

## 二、Color Token（映射 UIKit）

| Token | HEX | 用途 | iOS 落地 |
|---|---|---|---|
| `bg-cream` | `#FAF7F1` | 页面底色（非纯白！） | `UIColor.bg` |
| `surface` | `#FFFFFF` | 卡片面、顶栏 | `UIColor.surface` |
| `surface-alt` | `#F4EFE6` | 交替面、次级容器 | `UIColor.surfaceAlt` |
| `border` | `#E6DFD3` | 1px whisper 边 | `UIColor.line` |
| `text-primary` | `#2B2621` | 主文字 | `UIColor.ink` |
| `text-secondary` | `#726A60` | 次要文字 | `UIColor.sub` |
| `text-muted` | `#9C948A` | 占位、禁用 | `UIColor.muted` |
| `green-primary` | `#2F5D45` | 主按钮 / 选中态 / tab 选中 pill | `UIColor.brand` |
| `green-dark` | `#22422F` | 深色块 | `UIColor.brandDark` |
| `green-soft` | `#E8F0EA` | 绿 tint（标签底） | `UIColor.brandSoft` |
| `wood` | `#A87A3E` | 第二主色：头像占位、功能图标 | `UIColor.wood` |
| `wood-soft` | `#F4EFE6` | 木色 tint | `UIColor.woodSoft` |
| `clay` | `#C15F2C` | 强调色：Hero 金额、待办 | `UIColor.clay` |
| `success` / `warn` / `danger` / `info` | `#3D8B5F` / `#C77B2A` / `#B03A2B` / `#3A6B96` | 状态色（必须颜色+文字双重编码） | `UIColor.success` 等 |

---

## 三、字体（iOS 落地）

Noto Serif SC / Noto Sans SC 需内嵌字体文件（体积大、版权许可），**首版用系统字体映射**，后续可按需内嵌：

| 用途 | 设计系统 | iOS 映射 |
|---|---|---|
| 屏幕标题 / 品牌名 / 区块主标题 | Noto Serif SC Bold | `PingFangSC-Semibold`（iOS 无衬线中文字体，先用粗体近似；如需衬线感可内嵌 Noto Serif SC） |
| 正文 / 数据 / 标签 | Noto Sans SC | `PingFangSC-Regular / Medium / Semibold` |
| 金额 / 数字 | Noto Sans SC Bold | `PingFangSC-Semibold` + `.monospacedDigit`（数字等宽，防跳变） |

**字号阶梯**（12 / 14 / 17 / 28 / 30 / 34）：
- Hero 34（单屏最重要的数字，clay 色）
- Screen Title 28（导航栏大标题）
- Number 30（KPI 数值）
- Section 17 / 600（卡片标题、列表主行）
- Body 14 / 400（正文、副标题）
- Label 12 / 500（KPI 标签、状态标签）

---

## 四、形状与深度

| 元素 | 圆角 | 边框 | 阴影 |
|---|---|---|---|
| 卡片 | 16 | 1px `border` | 双层暖阴影：`rgba(43,38,33,0.05) 0 4px 16px` + `0 2px 6px` |
| 主按钮 | 12 | 无 | `0 6px 14px rgba(43,38,33,0.12)` |
| 输入框 | 14 | 1px `border` | 无 |
| Tab / 状态标签 | 9999（全 pill） | 未选中 1px | 无 |
| 头像 | 14–20（方角更手作感） | 无 | 木色/绿浅 tint 占位 |
| 图标容器 | 10（36×36） | 无 | tint 底 + 主色描边 |

**间距**：8pt 基准（4/8/12/16/24/32/48）；内容区左右 24；卡片内 16；区块间距 16；tab bar 底部留白 72。

---

## 五、Tab Bar 结构（需决策）

| 项 | 设计图（app-prototype） | 当前 iOS 实现 |
|---|---|---|
| Tab 数 | **4**：首页 / 课程 / 动态 / 我的 | **5**：首页 / 课程 / 广场 / 消息 / 我的 |
| 选中态 | green pill（radius 26）+ 暖白字 | 蓝色系统默认 |
| 图标 | 线性 SVG 20-23px 1.5px 描边 | SF Symbols |
| 消息入口 | 设计图无独立消息 Tab（消息为二级页，从我的/动态进入） | 独立 Tab |

> **建议**：对齐设计图改 4 Tab（首页/课程/动态/我的），消息页作为二级页从「我的 → 消息中心」进入。若保留 5 Tab 也可，但样式需按 v2 重做。**待用户拍板**。

---

## 六、关键页面视觉基线（来自原型）

### 登录页
- 背景：绿-米白渐变（`linear-gradient(170deg,#E9F1E4,#F7FAF4)`）
- 居中：78×78 绿色圆角 Logo（22 radius）+「艺启」衬线标题 + 副标题
- 输入框：白底 + 1px 边 + radius 14；主按钮绿底 + 白色 + radius 12

### 首页（parentHome）
- 顶栏：艺启 + 头像 + 搜索框（placeholder「搜索课程、工作室、作品」）
- 问候：「下午好 林女士」
- 孩子卡片：头像（木/绿 tint）+ 姓名 + 课程标签（水彩·初级）+ 剩余课时/学期进度
- 「为你推荐」区块 + 「附近热门工作室」横向卡 + 「老师动态」

### 课程页（course）
- 封面大图 → 课程信息（水彩 4-8岁 小班6人）→ 工作室卡（⭐4.9 · 1.2km · 632人学过）→ 课程介绍 → 家长评价 → 底部价格栏 `¥1,280 / 16节` + 绿色「立即报名」按钮

### 广场（plaza）
- 搜索 + 顶部推荐 pill tab（水彩 / 黏土 / 书法 / 素描 / 国画）+ 作品瀑布流

### 我的（my）
- 身份卡：「当前身份：家长 ▾」+ 昵称 + 签名
- 统计行：2 我的孩子 / 3 在学课程 / 28 收藏作品（Hero 数字，clay）
- 菜单组（白底 radius 18 分组）：我的孩子 / 我的课程 / 我的订单 / 作品管理 / 收藏与动态 / 收益中心 / 优惠券 / 设置
- 底部：开通老师 / 工作室身份认证入口（绿色卡片）

---

## 七、iOS 落地清单（按序）

| 步骤 | 内容 | 文件 |
|---|---|---|
| 1 | **Design Token 层**：ColorExtension（全部色值）+ FontExtension（字号阶梯）+ Spacing 常量 | `Core/Design/` |
| 2 | **通用组件**：卡片容器、主按钮（绿色/木色/禁用）、pill 标签、输入框样式、列表行 | `Core/Components/` |
| 3 | **导航栏统一**：Screen Title 28 衬线标题、米白底、去默认蓝 | `BaseViewController` 改造 |
| 4 | **Tab Bar 重做**：按 v2 样式（4 或 5 tab，green pill 选中），自绘图标或 SF Symbols 着色 | `MainTabBarController` |
| 5 | **登录页对齐**：渐变背景 + 圆角 Logo + v2 输入/按钮 | `LoginViewController` |
| 6 | **我的页对齐**：身份卡 + 统计 + 菜单组 + 认证入口 | `MineViewController` |
| 7 | 首页 / 课程 / 广场 / 消息页按原型逐屏实现（M2 起） | 各模块 VC |

---

## 八、验收口径

- 全屏底色为 `#FAF7F1`，无纯白整屏
- 主按钮 / 选中态一律 `#2F5D45`，无系统蓝
- 标题衬线（或粗体近似），字号阶梯 12/14/17/28/30/34
- 卡片 16 圆角 + 双层暖阴影，间距 8pt 网格
- 状态一律「颜色 + 文字」双编码，不用 emoji 当功能图标

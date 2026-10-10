export default defineAppConfig({
  pages: [
    // tabBar 页面（必须在主包）
    "pages/home/index",
    "pages/plaza/index",
    "pages/publish/index",
    "pages/messages/index",
    "pages/mine/index",
    // 登录流程（主包入口页）
    "pages/login/index",
    "pages/phone-login/index",
    "pages/verify-code/index"
  ],
  subPackages: [
    {
      root: "packageCourses",
      name: "courses",
      pages: [
        "pages/courses/index",
        "pages/course-detail/index",
        "pages/my-courses/index",
        "pages/course-study/index",
        "pages/course-reviews/index"
      ]
    },
    {
      root: "packageOrder",
      name: "order",
      pages: [
        "pages/order-confirm/index",
        "pages/payment-voucher/index",
        "pages/order-detail/index",
        "pages/orders/index",
        "pages/refund/index",
        "pages/refunds/index",
        "pages/refund-detail/index",
        "pages/poster/index"
      ]
    },
    {
      root: "packageChild",
      name: "child",
      pages: [
        "pages/children/index",
        "pages/child-add/index",
        "pages/child-balance/index",
        "pages/child-growth/index",
        "pages/child-timetable/index"
      ]
    },
    {
      root: "packageSocial",
      name: "social",
      pages: [
        "pages/post-detail/index",
        "pages/post-create/index",
        "pages/favorites/index",
        "pages/my-posts/index",
        "pages/my-reviews/index",
        "pages/following-list/index",
        "pages/studios/index",
        "pages/teacher-homepage/index",
        "pages/studio-homepage/index"
      ]
    },
    {
      root: "packageWallet",
      name: "wallet",
      pages: [
        "pages/wallet/index",
        "pages/studio-commission-detail/index",
        "pages/commission-withdrawals/index",
        "pages/commission-withdrawal-detail/index"
      ]
    },
    {
      root: "packageInfo",
      name: "info",
      pages: [
        "pages/announcements/index",
        "pages/announcement-detail/index",
        "pages/chat/index"
      ]
    }
  ],
  window: {
    backgroundTextStyle: "light",
    navigationBarBackgroundColor: "#14A640",
    navigationBarTitleText: "艺启",
    navigationBarTextStyle: "white",
    backgroundColor: "#f7f4ec"
  },
  tabBar: {
    color: "#9a938a",
    selectedColor: "#14A640",
    backgroundColor: "#ffffff",
    borderStyle: "white",
    // 对齐 iOS 家长端：首页 / 广场 / 发布 / 消息 / 我的
    list: [
      { pagePath: "pages/home/index", text: "首页", iconPath: "assets/tabbar/home.png", selectedIconPath: "assets/tabbar/home-active.png" },
      { pagePath: "pages/plaza/index", text: "广场", iconPath: "assets/tabbar/plaza.png", selectedIconPath: "assets/tabbar/plaza-active.png" },
      { pagePath: "pages/publish/index", text: "发布", iconPath: "assets/tabbar/publish.png", selectedIconPath: "assets/tabbar/publish-active.png" },
      { pagePath: "pages/messages/index", text: "消息", iconPath: "assets/tabbar/message.png", selectedIconPath: "assets/tabbar/message-active.png" },
      { pagePath: "pages/mine/index", text: "我的", iconPath: "assets/tabbar/mine.png", selectedIconPath: "assets/tabbar/mine-active.png" }
    ]
  }
});
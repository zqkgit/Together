export default defineAppConfig({
  pages: [
    "pages/home/index",
    "pages/courses/index",
    "pages/plaza/index",
    "pages/mine/index",
    "pages/login/index",
    "pages/course-detail/index",
    "pages/order-confirm/index",
    "pages/order-pay/index",
    "pages/order-detail/index",
    "pages/orders/index",
    "pages/children/index",
    "pages/child-balance/index",
    "pages/child-growth/index",
    "pages/child-timetable/index",
    "pages/poster/index",
    "pages/studios/index",
    "pages/favorites/index",
    "pages/my-posts/index",
    "pages/teacher-homepage/index",
    "pages/studio-homepage/index",
    "pages/post-detail/index",
    "pages/post-create/index",
    "pages/wallet/index",
    "pages/messages/index",
    "pages/refund/index"
  ],
  window: {
    backgroundTextStyle: "light",
    navigationBarBackgroundColor: "#2f5d45",
    navigationBarTitleText: "艺启",
    navigationBarTextStyle: "white",
    backgroundColor: "#f7f4ec"
  },
  tabBar: {
    color: "#9a938a",
    selectedColor: "#2f5d45",
    backgroundColor: "#ffffff",
    borderStyle: "white",
    // 图标资源：将 81x81px PNG 放入 src/assets/tabbar/ 后生效（iconPath/selectedIconPath）
    list: [
      { pagePath: "pages/home/index", text: "首页", iconPath: "assets/tabbar/home.png", selectedIconPath: "assets/tabbar/home-active.png" },
      { pagePath: "pages/courses/index", text: "课程", iconPath: "assets/tabbar/courses.png", selectedIconPath: "assets/tabbar/courses-active.png" },
      { pagePath: "pages/plaza/index", text: "广场", iconPath: "assets/tabbar/plaza.png", selectedIconPath: "assets/tabbar/plaza-active.png" },
      { pagePath: "pages/mine/index", text: "我的", iconPath: "assets/tabbar/mine.png", selectedIconPath: "assets/tabbar/mine-active.png" }
    ]
  }
});

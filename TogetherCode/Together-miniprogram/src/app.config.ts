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
    list: [
      { pagePath: "pages/home/index", text: "首页" },
      { pagePath: "pages/courses/index", text: "课程" },
      { pagePath: "pages/plaza/index", text: "广场" },
      { pagePath: "pages/mine/index", text: "我的" }
    ]
  }
});

import { createRouter, createWebHistory } from "vue-router";
import AdminLayout from "../layouts/AdminLayout.vue";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: "/",
      component: AdminLayout,
      redirect: "/dashboard",
      children: [
        {
          path: "/dashboard",
          name: "dashboard",
          component: () => import("../views/dashboard/IndexView.vue"),
          meta: { title: "经营看板" }
        },
        {
          path: "/studios",
          name: "studios",
          component: () => import("../views/studios/IndexView.vue"),
          meta: { title: "工作室管理" }
        },
        {
          path: "/reviews",
          name: "reviews",
          component: () => import("../views/reviews/IndexView.vue"),
          meta: { title: "认证审核" }
        },
        {
          path: "/settlements",
          name: "settlements",
          component: () => import("../views/settlements/IndexView.vue"),
          meta: { title: "结算分账" }
        }
      ]
    }
  ]
});

router.afterEach((to) => {
  document.title = `Together Admin - ${String(to.meta.title || "管理端")}`;
});

export default router;

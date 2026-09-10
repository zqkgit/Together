import { createRouter, createWebHistory } from "vue-router";
import AdminLayout from "../layouts/AdminLayout.vue";
import { useAuthStore } from "../stores/auth";

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: "/login",
      name: "login",
      component: () => import("../views/login/IndexView.vue"),
      meta: { title: "登录" }
    },
    {
      path: "/",
      component: AdminLayout,
      redirect: () => {
        const auth = useAuthStore();
        return auth.account?.scope === "studio" ? "/studio-home" : "/dashboard";
      },
      children: [
        {
          path: "/dashboard",
          name: "dashboard",
          component: () => import("../views/dashboard/IndexView.vue"),
          meta: { title: "经营看板", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/studios",
          name: "studios",
          component: () => import("../views/studios/IndexView.vue"),
          meta: { title: "工作室管理", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/reviews",
          name: "reviews",
          component: () => import("../views/reviews/IndexView.vue"),
          meta: { title: "认证审核", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/settlements",
          name: "settlements",
          component: () => import("../views/settlements/IndexView.vue"),
          meta: { title: "结算分账", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/studio-home",
          name: "studio-home",
          component: () => import("../views/studio/HomeView.vue"),
          meta: { title: "经营概览", requiresAuth: true, scopes: ["studio"] }
        }
      ]
    },
    {
      path: "/:pathMatch(.*)*",
      redirect: "/"
    }
  ]
});

router.beforeEach((to) => {
  const auth = useAuthStore();

  if (to.path === "/login") {
    return auth.isLoggedIn ? { path: "/" } : true;
  }

  if (to.meta.requiresAuth && !auth.isLoggedIn) {
    return { path: "/login", query: { redirect: to.fullPath } };
  }

  // 按登录角色隔离：platform 只能进平台页，studio 只能进工作室页
  const scopes = to.meta.scopes as string[] | undefined;
  if (scopes && auth.isLoggedIn) {
    const scope = auth.account?.scope;
    if (!scope || !scopes.includes(scope)) {
      return scope === "studio" ? { path: "/studio-home" } : { path: "/dashboard" };
    }
  }

  return true;
});

router.afterEach((to) => {
  document.title = `${String(to.meta.title || "管理端")} · 艺启后台`;
});

export default router;

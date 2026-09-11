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
          path: "/admin-teachers",
          name: "admin-teachers",
          component: () => import("../views/admin-teachers/IndexView.vue"),
          meta: { title: "老师管理", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/tags",
          name: "tags",
          component: () => import("../views/tags/IndexView.vue"),
          meta: { title: "标签管理", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/settlements",
          name: "settlements",
          component: () => import("../views/settlements/IndexView.vue"),
          meta: { title: "结算分账", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/admin-reports",
          name: "admin-reports",
          component: () => import("../views/admin-reports/IndexView.vue"),
          meta: { title: "举报处置", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/admin-posts",
          name: "admin-posts",
          component: () => import("../views/admin-posts/IndexView.vue"),
          meta: { title: "内容管理", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/admin-config",
          name: "admin-config",
          component: () => import("../views/admin-config/IndexView.vue"),
          meta: { title: "平台配置", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/admin-announcements",
          name: "admin-announcements",
          component: () => import("../views/admin-announcements/IndexView.vue"),
          meta: { title: "公告管理", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/admin-staff",
          name: "admin-staff",
          component: () => import("../views/admin-staff/IndexView.vue"),
          meta: { title: "平台员工", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/admin-audit",
          name: "admin-audit",
          component: () => import("../views/admin-audit/IndexView.vue"),
          meta: { title: "审计日志", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/admin-withdrawals",
          name: "admin-withdrawals",
          component: () => import("../views/admin-withdrawals/IndexView.vue"),
          meta: { title: "提现审核", requiresAuth: true, scopes: ["platform"] }
        },
        {
          path: "/studio-home",
          name: "studio-home",
          component: () => import("../views/studio/HomeView.vue"),
          meta: { title: "经营概览", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-reports",
          name: "studio-reports",
          component: () => import("../views/studio-reports/IndexView.vue"),
          meta: { title: "经营报表", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-courses",
          name: "studio-courses",
          component: () => import("../views/studio/courses/IndexView.vue"),
          meta: { title: "课程管理", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-classes",
          name: "studio-classes",
          component: () => import("../views/studio/classes/IndexView.vue"),
          meta: { title: "班级管理", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-teachers",
          name: "studio-teachers",
          component: () => import("../views/studio/teachers/IndexView.vue"),
          meta: { title: "教师管理", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-schedules",
          name: "studio-schedules",
          component: () => import("../views/studio/schedules/IndexView.vue"),
          meta: { title: "排课管理", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-students",
          name: "studio-students",
          component: () => import("../views/studio/students/IndexView.vue"),
          meta: { title: "学员管理", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-orders",
          name: "studio-orders",
          component: () => import("../views/studio/orders/IndexView.vue"),
          meta: { title: "订单管理", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-refunds",
          name: "studio-refunds",
          component: () => import("../views/studio/refunds/IndexView.vue"),
          meta: { title: "退款管理", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-leaves",
          name: "studio-leaves",
          component: () => import("../views/studio/leaves/IndexView.vue"),
          meta: { title: "请假审批", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-settings",
          name: "studio-settings",
          component: () => import("../views/studio/settings/IndexView.vue"),
          meta: { title: "工作室设置", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-finance",
          name: "studio-finance",
          component: () => import("../views/studio-finance/IndexView.vue"),
          meta: { title: "财务对账", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-accounts",
          name: "studio-accounts",
          component: () => import("../views/studio-accounts/IndexView.vue"),
          meta: { title: "结算账户", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-audit",
          name: "studio-audit",
          component: () => import("../views/studio-audit/IndexView.vue"),
          meta: { title: "操作审计", requiresAuth: true, scopes: ["studio"] }
        },
        {
          path: "/studio-staff",
          name: "studio-staff",
          component: () => import("../views/studio-staff/IndexView.vue"),
          meta: { title: "员工账号", requiresAuth: true, scopes: ["studio"] }
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

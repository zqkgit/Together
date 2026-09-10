import { computed, ref } from "vue";
import { defineStore } from "pinia";
import { loginAdmin, loginStudio, logoutAdmin, logoutStudio } from "../services/admin";

const TOKEN_KEY = "together_admin_access_token";
const REFRESH_KEY = "together_admin_refresh_token";
const ACCOUNT_KEY = "together_admin_account";

export type LoginScope = "platform" | "studio";

export interface AdminAccountInfo {
  admin_id: string;
  user_id: string | null;
  username: string;
  role: string;
  scope: string;
  studio_id: string | null;
  studio: { studio_id: string; name: string } | null;
  user: { user_id: string; phone: string; nickname: string; avatar: string | null } | null;
}

function readAccount(): AdminAccountInfo | null {
  try {
    const raw = localStorage.getItem(ACCOUNT_KEY);
    return raw ? (JSON.parse(raw) as AdminAccountInfo) : null;
  } catch {
    return null;
  }
}

export const useAuthStore = defineStore("auth", () => {
  const token = ref(localStorage.getItem(TOKEN_KEY) || "");
  const refreshToken = ref(localStorage.getItem(REFRESH_KEY) || "");
  const account = ref<AdminAccountInfo | null>(readAccount());

  const isLoggedIn = computed(() => Boolean(token.value));

  const displayName = computed(() => {
    if (account.value?.user?.nickname) return account.value.user.nickname;
    if (account.value?.username) return account.value.username;
    return "管理员";
  });

  const scopeLabel = computed(() => {
    if (!account.value) return "";
    if (account.value.scope === "studio") {
      return account.value.studio?.name || "工作室后台";
    }
    return account.value.role === "platform_super" ? "平台超管" : "平台运营";
  });

  function persist() {
    if (token.value) {
      localStorage.setItem(TOKEN_KEY, token.value);
    } else {
      localStorage.removeItem(TOKEN_KEY);
    }
    if (refreshToken.value) {
      localStorage.setItem(REFRESH_KEY, refreshToken.value);
    } else {
      localStorage.removeItem(REFRESH_KEY);
    }
    if (account.value) {
      localStorage.setItem(ACCOUNT_KEY, JSON.stringify(account.value));
    } else {
      localStorage.removeItem(ACCOUNT_KEY);
    }
  }

  function setSession(payload: {
    access_token: string;
    refresh_token: string;
    account: AdminAccountInfo;
  }) {
    token.value = payload.access_token;
    refreshToken.value = payload.refresh_token;
    account.value = payload.account;
    persist();
  }

  function clearSession() {
    token.value = "";
    refreshToken.value = "";
    account.value = null;
    persist();
  }

  async function login(scope: LoginScope, username: string, password: string) {
    const res =
      scope === "platform"
        ? await loginAdmin(username, password)
        : await loginStudio(username, password);
    setSession(res);
    return res;
  }

  async function logout() {
    try {
      if (account.value?.scope === "platform") {
        await logoutAdmin();
      } else {
        await logoutStudio();
      }
    } catch {
      // 后端登出失败不阻塞本地清理
    } finally {
      clearSession();
    }
  }

  return {
    token,
    refreshToken,
    account,
    isLoggedIn,
    displayName,
    scopeLabel,
    login,
    logout,
    clearSession
  };
});

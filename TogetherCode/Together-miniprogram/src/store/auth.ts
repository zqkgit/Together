import { create } from "zustand";
import { getAccount, saveSession, clearSession } from "../services/request";
import type { AuthUser, SessionData } from "../services/auth";

interface AuthState {
  user: AuthUser | null;
  currentRole: string;
  roles: string[];
  token: string;
  isLoggedIn: boolean;
  setSession: (data: SessionData) => void;
  setUser: (user: AuthUser, currentRole: string, roles: string[]) => void;
  logout: () => void;
  hydrate: () => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  currentRole: "",
  roles: [],
  token: "",
  isLoggedIn: false,

  setSession: (data) => {
    saveSession(data);
    set({
      user: data.user,
      currentRole: data.current_role,
      roles: data.roles,
      token: data.access_token,
      isLoggedIn: true
    });
  },

  setUser: (user, currentRole, roles) => {
    set({ user, currentRole, roles, isLoggedIn: true });
  },

  logout: () => {
    clearSession();
    set({ user: null, currentRole: "", roles: [], token: "", isLoggedIn: false });
  },

  hydrate: () => {
    const account = getAccount();
    const token = account ? true : false;
    set((state) => ({
      user: account?.user || null,
      currentRole: account?.current_role || "",
      roles: account?.roles || [],
      token: token ? state.token || "stored" : "",
      isLoggedIn: !!account
    }));
  }
}));

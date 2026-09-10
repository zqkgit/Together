import axios from "axios";
import { ElMessage } from "element-plus";

const TOKEN_KEY = "together_admin_access_token";

const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:3001",
  timeout: 10000
});

request.interceptors.request.use((config) => {
  const token = localStorage.getItem(TOKEN_KEY);
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

function redirectToLogin() {
  localStorage.removeItem("together_admin_access_token");
  localStorage.removeItem("together_admin_refresh_token");
  localStorage.removeItem("together_admin_account");
  if (!window.location.pathname.startsWith("/login")) {
    window.location.href = "/login";
  }
}

request.interceptors.response.use(
  (response) => response.data,
  (error) => {
    const status = error?.response?.status;
    const body = error?.response?.data || {};
    const message = body.message || error.message || "Request failed";

    if (status === 401) {
      ElMessage.error("登录已过期，请重新登录");
      redirectToLogin();
      return Promise.reject(error);
    }

    ElMessage.error(message);
    return Promise.reject(error);
  }
);

export default request;

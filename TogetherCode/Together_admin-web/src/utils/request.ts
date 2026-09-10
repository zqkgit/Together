import axios from "axios";
import { ElMessage } from "element-plus";

const request = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || "http://127.0.0.1:3001",
  timeout: 10000
});

request.interceptors.response.use(
  (response) => response.data,
  (error) => {
    const message = error?.response?.data?.message || error.message || "Request failed";
    ElMessage.error(message);
    return Promise.reject(error);
  }
);

export default request;

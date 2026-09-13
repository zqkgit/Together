/**
 * 图片上传：Taro.uploadFile → /v1/upload
 * 返回可直接存入 images 数组字段的 URL 列表
 */
import Taro from "@tarojs/taro";
import { APP_CONFIG } from "../config";
import { getToken } from "./request";

export async function uploadImages(paths: string[], folder = "common"): Promise<string[]> {
  const urls: string[] = [];
  const token = getToken();
  const base = APP_CONFIG.BASE_URL.replace(/\/$/, "");

  for (const filePath of paths) {
    const res = await Taro.uploadFile({
      url: `${base}/upload`,
      filePath,
      name: "files",
      formData: { folder },
      header: { Authorization: `Bearer ${token}` }
    });
    const body = typeof res.data === "string" ? JSON.parse(res.data) : res.data;
    if (body?.code === 0 && Array.isArray(body?.data?.urls)) {
      urls.push(...body.data.urls);
    } else {
      throw new Error(body?.message || "图片上传失败");
    }
  }
  return urls;
}

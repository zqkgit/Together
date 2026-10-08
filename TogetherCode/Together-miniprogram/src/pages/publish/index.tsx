import { useEffect } from "react";
import Taro from "@tarojs/taro";

/**
 * 发布跳板页（tabBar 占位）
 * iOS 发布页是 modal 弹出，小程序用 navigateTo 模拟，
 * 此页仅在 tabBar 占位，onShow 立即跳转到真正的发布页。
 */
export default function PublishPage() {
  useEffect(() => {
    Taro.navigateTo({ url: "/pages/post-create/index" });
  }, []);
  return null;
}
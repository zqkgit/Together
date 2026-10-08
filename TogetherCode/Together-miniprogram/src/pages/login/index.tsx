import React, { useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text } from "@tarojs/components";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

export default function LoginPage() {
  const setSession = useAuthStore((s) => s.setSession);
  const [agreed, setAgreed] = useState(false);

  const checkAgree = (): boolean => {
    if (!agreed) {
      Taro.showToast({ title: "请先阅读并同意用户协议与隐私政策", icon: "none" });
      return false;
    }
    return true;
  };

  const goPhoneLogin = () => {
    if (!checkAgree()) return;
    Taro.navigateTo({ url: "/pages/phone-login/index" });
  };

  const handleWxLogin = async () => {
    if (!checkAgree()) return;
    try {
      const { code: wxCode } = await Taro.login();
      const { wxLogin } = await import("../../services/auth");
      const session = await wxLogin({ code: wxCode });
      setSession(session);
      Taro.showToast({ title: "登录成功", icon: "success" });
      setTimeout(() => Taro.switchTab({ url: "/pages/home/index" }), 400);
    } catch (error) {
      const message = (error as Error).message || "";
      if (message.includes("40084") || message.includes("手机号")) {
        Taro.showToast({ title: "请绑定手机号", icon: "none" });
      }
    }
  };

  const toggleAgree = () => setAgreed(!agreed);

  const openProtocol = (type: string) => {
    Taro.showToast({ title: `${type}即将开放`, icon: "none" });
  };

  return (
    <View className="login-page">
      {/* 绿-米白渐变背景 */}
      <View className="login-gradient" />

      {/* Logo 区域 */}
      <View className="login-hero">
        <View className="login-logo">
          <Text className="login-logo-icon">🎨</Text>
        </View>
        <Text className="login-title">艺启</Text>
        <Text className="login-slogan">让每一次创作，都被看见</Text>
      </View>

      {/* 底部按钮区 */}
      <View className="login-bottom">
        {/* 登录/注册 主按钮 */}
        <View className="login-btn-primary" onClick={goPhoneLogin}>
          <Text className="login-btn-primary-text">登录/注册</Text>
        </View>

        {/* 微信一键登录 */}
        <View className="login-btn-wechat" onClick={handleWxLogin}>
          <View className="wechat-icon-wrap">
            <Text className="wechat-icon-text">微</Text>
          </View>
          <Text className="login-btn-wechat-text">微信一键登录</Text>
        </View>

        {/* 协议行 */}
        <View className="agree-row">
          <View className={`agree-check ${agreed ? "agree-checked" : ""}`} onClick={toggleAgree}>
            {agreed && <Text className="agree-check-mark">✓</Text>}
          </View>
          <Text className="agree-text" onClick={toggleAgree}>
            已阅读并同意
          </Text>
          <Text className="agree-link" onClick={() => openProtocol("《用户协议》")}>《用户协议》</Text>
          <Text className="agree-text">与</Text>
          <Text className="agree-link" onClick={() => openProtocol("《隐私政策》")}>《隐私政策》</Text>
        </View>
      </View>
    </View>
  );
}
import React, { useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Input, Button } from "@tarojs/components";
import { sendCode, loginWithCode, wxLogin } from "../../services/auth";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

const isH5 = process.env.TARO_ENV === "h5";

export default function LoginPage() {
  const setSession = useAuthStore((s) => s.setSession);
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [sending, setSending] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [submitting, setSubmitting] = useState(false);

  const doLogin = (session: any) => {
    setSession(session);
    Taro.showToast({ title: "登录成功", icon: "success" });
    setTimeout(() => Taro.switchTab({ url: "/pages/home/index" }), 400);
  };

  const handleWxLogin = async () => {
    setSubmitting(true);
    try {
      const { code: wxCode } = await Taro.login();
      const session = await wxLogin({ code: wxCode });
      doLogin(session);
    } catch (error) {
      const message = (error as Error).message || "";
      if (message.includes("40084") || message.includes("手机号")) {
        Taro.showToast({ title: "请绑定手机号", icon: "none" });
      }
    } finally {
      setSubmitting(false);
    }
  };

  const handleSendCode = async () => {
    if (!/^1\d{10}$/.test(phone)) {
      Taro.showToast({ title: "请输入正确手机号", icon: "none" });
      return;
    }
    setSending(true);
    try {
      await sendCode(phone);
      Taro.showToast({ title: "验证码已发送", icon: "success" });
      let n = 60;
      setCountdown(n);
      const timer = setInterval(() => {
        n -= 1;
        setCountdown(n);
        if (n <= 0) clearInterval(timer);
      }, 1000);
    } catch {
      // 错误已统一提示
    } finally {
      setSending(false);
    }
  };

  const handleCodeLogin = async () => {
    if (!/^1\d{10}$/.test(phone)) {
      Taro.showToast({ title: "请输入正确手机号", icon: "none" });
      return;
    }
    if (!code) {
      Taro.showToast({ title: "请输入验证码", icon: "none" });
      return;
    }
    setSubmitting(true);
    try {
      const session = await loginWithCode(phone, code);
      doLogin(session);
    } catch {
      // 错误已统一提示
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <View className="login-page">
      <View className="login-hero">
        <View className="login-logo">艺</View>
        <View className="login-title">艺启</View>
        <View className="login-slogan">发现孩子的艺术天赋</View>
      </View>

      {isH5 ? (
        <View className="login-form">
          <View className="field">
            <Input
              className="field-input"
              type="number"
              maxlength={11}
              placeholder="请输入手机号"
              value={phone}
              onInput={(e) => setPhone(e.detail.value)}
            />
          </View>
          <View className="field field-code">
            <Input
              className="field-input"
              type="number"
              maxlength={6}
              placeholder="验证码"
              value={code}
              onInput={(e) => setCode(e.detail.value)}
            />
            <Button className="code-btn" size="mini" disabled={countdown > 0 || sending} onClick={handleSendCode}>
              {countdown > 0 ? `${countdown}s` : "获取验证码"}
            </Button>
          </View>
          <Button className="btn-primary login-submit" loading={submitting} onClick={handleCodeLogin}>
            登录 / 注册
          </Button>
          <Text className="login-hint">未注册手机号将自动创建账号</Text>
        </View>
      ) : (
        <View className="login-form">
          <Button className="btn-primary login-submit" loading={submitting} onClick={handleWxLogin}>
            微信一键登录
          </Button>
          <Text className="login-hint">登录即代表同意《用户协议》与《隐私政策》</Text>
        </View>
      )}
    </View>
  );
}

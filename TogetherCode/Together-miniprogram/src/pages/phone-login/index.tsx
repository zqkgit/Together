import React, { useState, useRef, useCallback } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Input } from "@tarojs/components";
import { sendCode, loginWithCode, loginPassword } from "../../services/auth";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

type Mode = "code" | "password";

export default function PhoneLoginPage() {
  const setSession = useAuthStore((s) => s.setSession);
  const [mode, setMode] = useState<Mode>("code");
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [password, setPassword] = useState("");
  const [sending, setSending] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [submitting, setSubmitting] = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const isValidPhone = (p: string) => /^1\d{10}$/.test(p);

  const doLogin = useCallback((session: any) => {
    setSession(session);
    Taro.showToast({ title: "登录成功", icon: "success" });
    setTimeout(() => Taro.switchTab({ url: "/pages/home/index" }), 400);
  }, [setSession]);

  const handleSendCode = async () => {
    if (!isValidPhone(phone)) {
      Taro.showToast({ title: "请输入正确的手机号", icon: "none" });
      return;
    }
    if (countdown > 0 || sending) return;
    setSending(true);
    try {
      await sendCode(phone);
      Taro.showToast({ title: "验证码已发送", icon: "success" });
      let n = 60;
      setCountdown(n);
      timerRef.current = setInterval(() => {
        n -= 1;
        setCountdown(n);
        if (n <= 0 && timerRef.current) clearInterval(timerRef.current);
      }, 1000);
    } catch {
      // 拦截器已提示
    } finally {
      setSending(false);
    }
  };

  const handleLogin = async () => {
    if (!isValidPhone(phone)) {
      Taro.showToast({ title: "请输入正确的手机号", icon: "none" });
      return;
    }
    if (submitting) return;

    if (mode === "code") {
      if (!code || code.length < 4) {
        Taro.showToast({ title: "请输入4位验证码", icon: "none" });
        return;
      }
      setSubmitting(true);
      try {
        const session = await loginWithCode(phone, code);
        doLogin(session);
      } catch {
        // 拦截器已提示
      } finally {
        setSubmitting(false);
      }
    } else {
      if (!password) {
        Taro.showToast({ title: "请输入密码", icon: "none" });
        return;
      }
      setSubmitting(true);
      try {
        const session = await loginPassword(phone, password);
        doLogin(session);
      } catch {
        // 拦截器已提示
      } finally {
        setSubmitting(false);
      }
    }
  };

  const handleRegister = async () => {
    if (!isValidPhone(phone)) {
      Taro.showToast({ title: "请输入正确的手机号", icon: "none" });
      return;
    }
    // 先发送验证码，再跳转验证码页
    setSending(true);
    try {
      await sendCode(phone);
      Taro.showToast({ title: "验证码已发送", icon: "success" });
      setTimeout(() => {
        Taro.navigateTo({ url: `/pages/verify-code/index?phone=${phone}&purpose=register` });
      }, 500);
    } catch {
      // 拦截器已提示
    } finally {
      setSending(false);
    }
  };

  return (
    <View className="phone-login">
      {/* 欢迎语 */}
      <Text className="welcome-title">欢迎来到艺启</Text>
      <Text className="welcome-sub">选择你习惯的登录方式</Text>

      {/* 手机号输入 */}
      <View className="input-box phone-box">
        <Text className="phone-prefix">+86</Text>
        <View className="phone-divider" />
        <Input
          className="field-input"
          type="number"
          maxlength={11}
          placeholder="请输入手机号"
          value={phone}
          onInput={(e) => setPhone(e.detail.value)}
        />
      </View>

      {/* 分段切换 */}
      <View className="segment-row">
        <Text
          className={`segment-btn ${mode === "code" ? "segment-active" : ""}`}
          onClick={() => setMode("code")}
        >
          验证码登录
        </Text>
        <Text
          className={`segment-btn ${mode === "password" ? "segment-active" : ""}`}
          onClick={() => setMode("password")}
        >
          密码登录
        </Text>
      </View>

      {/* 验证码行 */}
      {mode === "code" && (
        <View className="input-box code-box">
          <Input
            className="field-input code-input"
            type="number"
            maxlength={4}
            placeholder="请输入4位验证码"
            value={code}
            onInput={(e) => setCode(e.detail.value)}
          />
          <View className="code-divider" />
          <Text
            className={`send-code-btn ${countdown > 0 || sending ? "send-code-disabled" : ""}`}
            onClick={handleSendCode}
          >
            {countdown > 0 ? `${countdown}s后重发` : "获取验证码"}
          </Text>
        </View>
      )}

      {/* 密码行 */}
      {mode === "password" && (
        <View className="input-box">
          <Input
            className="field-input"
            type="text"
            password
            maxlength={32}
            placeholder="请输入密码"
            value={password}
            onInput={(e) => setPassword(e.detail.value)}
          />
        </View>
      )}

      {/* 登录按钮 */}
      <View
        className={`login-btn ${submitting ? "login-btn-loading" : ""}`}
        onClick={handleLogin}
      >
        <Text className="login-btn-text">登 录</Text>
      </View>

      {/* 注册入口 */}
      <View className="register-row" onClick={handleRegister}>
        <Text className="register-text">还没有账号？</Text>
        <Text className="register-link">立即注册</Text>
      </View>
    </View>
  );
}
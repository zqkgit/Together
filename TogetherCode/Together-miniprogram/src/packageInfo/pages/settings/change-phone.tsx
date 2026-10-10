import React, { useEffect, useState, useRef } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Input } from "@tarojs/components";
import { changePhone, sendSmsCode, getMe } from "../../../services/auth";
import "./form-page.scss";

export default function ChangePhonePage() {
  const [currentPhone, setCurrentPhone] = useState("");
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [countdown, setCountdown] = useState(0);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    loadCurrentPhone();
  }, []);

  const loadCurrentPhone = async () => {
    try {
      const res = await getMe();
      if (res.user?.phone) {
        const p = res.user.phone;
        setCurrentPhone(p.length === 11 ? p.slice(0, 3) + "****" + p.slice(7) : p);
      }
    } catch {
      // 忽略
    }
  };

  const startCountdown = () => {
    setCountdown(60);
    timerRef.current = setInterval(() => {
      setCountdown((prev) => {
        if (prev <= 1) {
          if (timerRef.current) clearInterval(timerRef.current);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
  };

  const handleSendCode = async () => {
    if (!phone || phone.length !== 11) {
      Taro.showToast({ title: "请输入正确的手机号", icon: "none" });
      return;
    }
    if (countdown > 0) return;
    try {
      await sendSmsCode(phone);
      Taro.showToast({ title: "验证码已发送", icon: "success" });
      startCountdown();
    } catch (e: any) {
      Taro.showToast({ title: e?.message || "发送失败", icon: "none" });
    }
  };

  const handleSubmit = async () => {
    if (!phone || phone.length !== 11) {
      Taro.showToast({ title: "请输入正确的手机号", icon: "none" });
      return;
    }
    if (!code) {
      Taro.showToast({ title: "请输入验证码", icon: "none" });
      return;
    }
    try {
      await changePhone(phone, code);
      Taro.showToast({ title: "手机号已更换", icon: "success" });
      setTimeout(() => Taro.navigateBack(), 800);
    } catch (e: any) {
      Taro.showToast({ title: e?.message || "更换失败", icon: "none" });
    }
  };

  return (
    <View className="form-page">
      {currentPhone ? (
        <View className="fp-info-card">
          <Text className="fp-info-label">当前绑定手机号</Text>
          <Text className="fp-info-value">{currentPhone}</Text>
        </View>
      ) : null}

      <Text className="fp-label">新手机号</Text>
      <View className="fp-card fp-card--row">
        <Input className="fp-input fp-input--flex" type="number" value={phone} onInput={(e) => setPhone(e.detail.value)} placeholder="请输入新手机号" maxlength={11} />
      </View>

      <Text className="fp-label">验证码</Text>
      <View className="fp-card fp-card--row">
        <Input className="fp-input fp-input--flex" type="number" value={code} onInput={(e) => setCode(e.detail.value)} placeholder="请输入验证码" maxlength={6} />
        <View className={`fp-code-btn ${countdown > 0 ? "fp-code-btn--disabled" : ""}`} onClick={handleSendCode}>
          <Text className="fp-code-btn-text">{countdown > 0 ? `${countdown}s` : "获取验证码"}</Text>
        </View>
      </View>

      <Text className="fp-hint">新手机号将替换当前登录手机号</Text>

      <View className="fp-btn" onClick={handleSubmit}>
        <Text className="fp-btn-text">确认更换</Text>
      </View>
    </View>
  );
}
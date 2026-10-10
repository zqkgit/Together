import React, { useState, useRef } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Input } from "@tarojs/components";
import { deactivateAccount, sendSmsCode } from "../../../services/auth";
import "./form-page.scss";

export default function DeactivateAccountPage() {
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState("");
  const [countdown, setCountdown] = useState(0);
  const [confirming, setConfirming] = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

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

  const handleDeactivate = async () => {
    if (!code) {
      Taro.showToast({ title: "请输入验证码", icon: "none" });
      return;
    }
    setConfirming(true);
    try {
      await deactivateAccount(code);
      Taro.showToast({ title: "账号已注销", icon: "success" });
      // 清除本地状态，跳转到登录页
      setTimeout(() => {
        Taro.reLaunch({ url: "/pages/login/index" });
      }, 800);
    } catch (e: any) {
      Taro.showToast({ title: e?.message || "注销失败", icon: "none" });
    } finally {
      setConfirming(false);
    }
  };

  return (
    <View className="form-page">
      <View className="fp-warning-card">
        <Text className="fp-warning-title">⚠️ 注销账号须知</Text>
        <Text className="fp-warning-text">• 注销后账号将无法恢复，所有数据将被永久删除</Text>
        <Text className="fp-warning-text">• 未完成的订单和课程将被取消</Text>
        <Text className="fp-warning-text">• 钱包余额及优惠券将清零且不可退回</Text>
        <Text className="fp-warning-text">• 注销后手机号将可重新注册新账号</Text>
      </View>
      <View className="fp-card fp-card--row">
        <Input className="fp-input fp-input--flex" type="number" value={phone} onInput={(e) => setPhone(e.detail.value)} placeholder="请输入绑定手机号" maxlength={11} />
      </View>
      <View className="fp-card fp-card--row">
        <Input className="fp-input fp-input--flex" type="number" value={code} onInput={(e) => setCode(e.detail.value)} placeholder="请输入验证码" maxlength={6} />
        <View className={`fp-code-btn ${countdown > 0 ? "fp-code-btn--disabled" : ""}`} onClick={handleSendCode}>
          <Text className="fp-code-btn-text">{countdown > 0 ? `${countdown}s` : "获取验证码"}</Text>
        </View>
      </View>
      <View className={`fp-btn fp-btn--danger ${confirming ? "fp-btn--disabled" : ""}`} onClick={confirming ? undefined : handleDeactivate}>
        <Text className="fp-btn-text">确认注销账号</Text>
      </View>
    </View>
  );
}
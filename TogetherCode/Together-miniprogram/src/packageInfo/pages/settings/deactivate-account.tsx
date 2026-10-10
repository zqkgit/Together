import React, { useEffect, useState, useRef } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Input } from "@tarojs/components";
import { deactivateAccount, sendSmsCode, getMe } from "../../../services/auth";
import { useAuthStore } from "../../../store/auth";
import "./form-page.scss";

export default function DeactivateAccountPage() {
  const [currentPhone, setCurrentPhone] = useState("");
  const [maskedPhone, setMaskedPhone] = useState("");
  const [code, setCode] = useState("");
  const [countdown, setCountdown] = useState(0);
  const [confirming, setConfirming] = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const logout = useAuthStore((s) => s.logout);

  useEffect(() => {
    loadCurrentPhone();
  }, []);

  const loadCurrentPhone = async () => {
    try {
      const res = await getMe();
      if (res.user?.phone) {
        const p = res.user.phone;
        setCurrentPhone(p);
        setMaskedPhone(p.length === 11 ? p.slice(0, 3) + "****" + p.slice(7) : p);
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
    if (!currentPhone) {
      Taro.showToast({ title: "手机号获取失败，请重试", icon: "none" });
      return;
    }
    if (countdown > 0) return;
    try {
      await sendSmsCode(currentPhone);
      Taro.showToast({ title: "验证码已发送", icon: "success" });
      startCountdown();
    } catch (e: any) {
      Taro.showToast({ title: e?.message || "发送失败", icon: "none" });
    }
  };

  const handleDeactivate = () => {
    if (!code) {
      Taro.showToast({ title: "请输入验证码", icon: "none" });
      return;
    }
    // 二次确认弹窗
    Taro.showModal({
      title: "确认注销",
      content: "注销后账号将无法登录，所有数据将被永久删除，确定要注销吗？",
      confirmText: "确认注销",
      confirmColor: "#E5484D",
      success: async (res) => {
        if (!res.confirm) return;
        setConfirming(true);
        try {
          await deactivateAccount(code);
          Taro.showToast({ title: "账号已注销", icon: "success" });
          logout();
          setTimeout(() => {
            Taro.reLaunch({ url: "/pages/login/index" });
          }, 800);
        } catch (e: any) {
          Taro.showToast({ title: e?.message || "注销失败", icon: "none" });
        } finally {
          setConfirming(false);
        }
      },
    });
  };

  return (
    <View className="form-page">
      <View className="fp-warning-card">
        <Text className="fp-warning-title">注销账号须知</Text>
        <Text className="fp-warning-text">• 注销后账号将无法恢复，所有数据将被永久删除</Text>
        <Text className="fp-warning-text">• 未完成的订单和课程将被取消</Text>
        <Text className="fp-warning-text">• 钱包余额及优惠券将清零且不可退回</Text>
        <Text className="fp-warning-text">• 注销后手机号将可重新注册新账号</Text>
      </View>

      {maskedPhone ? (
        <View className="fp-info-card">
          <Text className="fp-info-label">当前绑定手机号</Text>
          <Text className="fp-info-value">{maskedPhone}</Text>
        </View>
      ) : null}

      <Text className="fp-label">验证码</Text>
      <View className="fp-card fp-card--row">
        <Input className="fp-input fp-input--flex" type="number" value={code} onInput={(e) => setCode(e.detail.value)} placeholder="请输入短信验证码确认" maxlength={6} />
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
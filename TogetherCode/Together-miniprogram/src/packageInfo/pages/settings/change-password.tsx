import React, { useState, useEffect, useRef } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Input } from "@tarojs/components";
import { changePassword, sendSmsCode, getMe } from "../../../services/auth";
import "./form-page.scss";

export default function ChangePasswordPage() {
  const [currentPhone, setCurrentPhone] = useState("");
  const [code, setCode] = useState("");
  const [newPwd, setNewPwd] = useState("");
  const [confirmPwd, setConfirmPwd] = useState("");
  const [showNew, setShowNew] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [saving, setSaving] = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    loadCurrentPhone();
    return () => { if (timerRef.current) clearInterval(timerRef.current); };
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
    if (!currentPhone) {
      Taro.showToast({ title: "手机号获取失败", icon: "none" });
      return;
    }
    if (countdown > 0) return;
    try {
      // 发送验证码到当前绑定手机号
      const rawPhone = currentPhone.replace(/\*/g, "");
      // 需要原始手机号，从 getMe 重新获取
      const res = await getMe();
      const phone = res.user?.phone || "";
      if (!phone) {
        Taro.showToast({ title: "手机号获取失败", icon: "none" });
        return;
      }
      await sendSmsCode(phone);
      Taro.showToast({ title: "验证码已发送", icon: "success" });
      startCountdown();
    } catch (e: any) {
      Taro.showToast({ title: e?.message || "发送失败", icon: "none" });
    }
  };

  const handleSave = async () => {
    if (!code) {
      Taro.showToast({ title: "请输入验证码", icon: "none" });
      return;
    }
    if (!newPwd || !confirmPwd) {
      Taro.showToast({ title: "请填写完整", icon: "none" });
      return;
    }
    if (newPwd !== confirmPwd) {
      Taro.showToast({ title: "两次输入的新密码不一致", icon: "none" });
      return;
    }
    if (newPwd.length < 6 || newPwd.length > 20) {
      Taro.showToast({ title: "新密码长度需为 6-20 位", icon: "none" });
      return;
    }
    setSaving(true);
    try {
      await changePassword(code, newPwd);
      Taro.showToast({ title: "密码已修改", icon: "success" });
      setTimeout(() => Taro.navigateBack(), 800);
    } catch (e: any) {
      Taro.showToast({ title: e?.message || "修改失败", icon: "none" });
    } finally {
      setSaving(false);
    }
  };

  return (
    <View className="form-page">
      {currentPhone ? (
        <View className="fp-info-card">
          <Text className="fp-info-label">当前手机号</Text>
          <Text className="fp-info-value">{currentPhone}</Text>
        </View>
      ) : null}

      <Text className="fp-label">验证码</Text>
      <View className="fp-card fp-card--row">
        <Input className="fp-input fp-input--flex" type="number" value={code} onInput={(e) => setCode(e.detail.value)} placeholder="请输入验证码" maxlength={6} />
        <View className={`fp-code-btn ${countdown > 0 ? "fp-code-btn--disabled" : ""}`} onClick={handleSendCode}>
          <Text className="fp-code-btn-text">{countdown > 0 ? `${countdown}s` : "获取验证码"}</Text>
        </View>
      </View>

      <Text className="fp-label">新密码</Text>
      <View className="fp-card fp-card--row">
        <Input className="fp-input fp-input--flex" type="text" password={!showNew} value={newPwd} onInput={(e) => setNewPwd(e.detail.value)} placeholder="请输入新密码（6-20 位）" maxlength={20} />
        <Text className="fp-eye" onClick={() => setShowNew(!showNew)}>{showNew ? "👁" : "👁‍🗨"}</Text>
      </View>

      <Text className="fp-label">确认新密码</Text>
      <View className="fp-card fp-card--row">
        <Input className="fp-input fp-input--flex" type="text" password={!showConfirm} value={confirmPwd} onInput={(e) => setConfirmPwd(e.detail.value)} placeholder="请再次输入新密码" maxlength={20} />
        <Text className="fp-eye" onClick={() => setShowConfirm(!showConfirm)}>{showConfirm ? "👁" : "👁‍🗨"}</Text>
      </View>

      <Text className="fp-hint">密码长度 6-20 位，建议包含字母、数字和符号</Text>

      <View className={`fp-btn ${saving ? "fp-btn--disabled" : ""}`} onClick={saving ? undefined : handleSave}>
        <Text className="fp-btn-text">确认修改</Text>
      </View>
    </View>
  );
}
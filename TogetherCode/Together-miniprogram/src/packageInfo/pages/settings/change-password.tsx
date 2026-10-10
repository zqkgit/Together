import React, { useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Input } from "@tarojs/components";
import { changePassword } from "../../../services/auth";
import "./form-page.scss";

export default function ChangePasswordPage() {
  const [oldPwd, setOldPwd] = useState("");
  const [newPwd, setNewPwd] = useState("");
  const [confirmPwd, setConfirmPwd] = useState("");
  const [saving, setSaving] = useState(false);

  const handleSave = async () => {
    if (!oldPwd || !newPwd || !confirmPwd) {
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
      await changePassword(oldPwd, newPwd);
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
      <View className="fp-card">
        <Input className="fp-input" type="text" password value={oldPwd} onInput={(e) => setOldPwd(e.detail.value)} placeholder="请输入原密码" />
      </View>
      <View className="fp-card">
        <Input className="fp-input" type="text" password value={newPwd} onInput={(e) => setNewPwd(e.detail.value)} placeholder="请输入新密码（6-20 位）" maxlength={20} />
      </View>
      <View className="fp-card">
        <Input className="fp-input" type="text" password value={confirmPwd} onInput={(e) => setConfirmPwd(e.detail.value)} placeholder="请再次输入新密码" maxlength={20} />
      </View>
      <View className={`fp-btn ${saving ? "fp-btn--disabled" : ""}`} onClick={saving ? undefined : handleSave}>
        <Text className="fp-btn-text">确认修改</Text>
      </View>
    </View>
  );
}
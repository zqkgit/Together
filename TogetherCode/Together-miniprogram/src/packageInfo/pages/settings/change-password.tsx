import React, { useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Input } from "@tarojs/components";
import { changePassword } from "../../../services/auth";
import "./form-page.scss";

export default function ChangePasswordPage() {
  const [oldPwd, setOldPwd] = useState("");
  const [newPwd, setNewPwd] = useState("");
  const [confirmPwd, setConfirmPwd] = useState("");
  const [showOld, setShowOld] = useState(false);
  const [showNew, setShowNew] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
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
    if (oldPwd === newPwd) {
      Taro.showToast({ title: "新密码不能与原密码相同", icon: "none" });
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
      <Text className="fp-label">原密码</Text>
      <View className="fp-card fp-card--row">
        <Input className="fp-input fp-input--flex" type="text" password={!showOld} value={oldPwd} onInput={(e) => setOldPwd(e.detail.value)} placeholder="请输入原密码" />
        <Text className="fp-eye" onClick={() => setShowOld(!showOld)}>{showOld ? "👁" : "👁‍🗨"}</Text>
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
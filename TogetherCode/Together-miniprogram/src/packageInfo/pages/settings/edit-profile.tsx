import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Input, Image } from "@tarojs/components";
import { useAuthStore } from "../../../store/auth";
import { getMe, updateProfile } from "../../../services/auth";
import { uploadImages } from "../../../services/upload";
import "./edit-profile.scss";

export default function EditProfilePage() {
  const user = useAuthStore((s) => s.user);
  const setUser = useAuthStore((s) => s.setUser);
  const [avatar, setAvatar] = useState<string | null>(null);
  const [nickname, setNickname] = useState("");
  const [city, setCity] = useState("");
  const [signature, setSignature] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    loadProfile();
  }, []);

  const loadProfile = async () => {
    try {
      const res = await getMe();
      if (res.user) {
        setAvatar(res.user.avatar);
        setNickname(res.user.nickname || "");
        setCity(res.user.city || "");
      }
    } catch {
      // 忽略
    }
  };

  const pickAvatar = () => {
    Taro.chooseImage({
      count: 1,
      sizeType: ["compressed"],
      sourceType: ["album", "camera"],
      success: async (res) => {
        const tempPath = res.tempFilePaths[0];
        try {
          Taro.showLoading({ title: "上传中..." });
          const urls = await uploadImages([tempPath], "avatar");
          setAvatar(urls[0]);
          Taro.hideLoading();
        } catch {
          Taro.hideLoading();
          Taro.showToast({ title: "上传失败", icon: "none" });
        }
      },
    });
  };

  const handleSave = async () => {
    const name = nickname.trim();
    if (!name) {
      Taro.showToast({ title: "昵称不能为空", icon: "none" });
      return;
    }
    setSaving(true);
    try {
      const res = await updateProfile({
        nickname: name,
        avatar,
        city: city.trim() || null,
        signature: signature.trim() || null,
      });
      if (res.user && user) {
        setUser(res.user, useAuthStore.getState().currentRole, useAuthStore.getState().roles);
      }
      Taro.showToast({ title: "保存成功", icon: "success" });
      setTimeout(() => Taro.navigateBack(), 600);
    } catch (e: any) {
      Taro.showToast({ title: e?.message || "保存失败", icon: "none" });
    } finally {
      setSaving(false);
    }
  };

  return (
    <View className="edit-profile">
      {/* 头像 */}
      <View className="ep-avatar-section" onClick={pickAvatar}>
      {avatar ? (
          <Image className="ep-avatar-img" src={avatar} mode="aspectFill" />
        ) : (
          <View className="ep-avatar-placeholder">
            <Text className="ep-avatar-letter">{(nickname || "艺").charAt(0)}</Text>
          </View>
        )}
        <Text className="ep-avatar-tip">点击更换头像</Text>
      </View>

      {/* 昵称 */}
      <Text className="ep-field-title">昵称</Text>
      <View className="ep-field-card">
        <Input
          className="ep-input"
          value={nickname}
          onInput={(e) => setNickname(e.detail.value)}
          placeholder="请输入昵称"
          maxlength={20}
        />
      </View>

      {/* 城市 */}
      <Text className="ep-field-title">城市</Text>
      <View className="ep-field-card">
        <Input
          className="ep-input"
          value={city}
          onInput={(e) => setCity(e.detail.value)}
          placeholder="请输入所在城市（选填）"
          maxlength={20}
        />
      </View>

      {/* 个性签名 */}
      <Text className="ep-field-title">个性签名</Text>
      <View className="ep-field-card">
        <Input
          className="ep-input"
          value={signature}
          onInput={(e) => {
            const v = e.detail.value;
            if (v.length <= 20) setSignature(v);
          }}
          placeholder="一句话介绍自己（选填）"
          maxlength={20}
        />
        <Text className="ep-signature-count">{signature.length}/20</Text>
      </View>

      {/* 保存 */}
      <View className={`ep-save-btn ${saving ? "ep-save-btn--disabled" : ""}`} onClick={saving ? undefined : handleSave}>
        <Text className="ep-save-text">保存</Text>
      </View>
    </View>
  );
}
import React, { useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Button, Input, Picker, Image } from "@tarojs/components";
import { createChild } from "../../../services/child";
import "./index.scss";

/** 头像 emoji 选项（对齐 iOS） */
const AVATAR_OPTIONS = ["🌻", "🦊", "🐟", "🍀", "🎀"];

/** 兴趣方向选项（对齐 iOS） */
const INTEREST_OPTIONS = ["水彩", "黏土", "书法", "国画", "儿童画", "素描"];

/** 出生年份范围 */
const currentYear = new Date().getFullYear();
const BIRTH_YEARS = Array.from({ length: currentYear - 2010 + 1 }, (_, i) => currentYear - i);

export default function ChildAddPage() {
  const [selectedAvatar, setSelectedAvatar] = useState("🌻");
  const [customAvatarUrl, setCustomAvatarUrl] = useState("");
  const [nickname, setNickname] = useState("");
  const [selectedYear, setSelectedYear] = useState(2019);
  const [selectedGender, setSelectedGender] = useState(2); // 默认女孩
  const [selectedInterests, setSelectedInterests] = useState<Set<string>>(new Set());
  const [submitting, setSubmitting] = useState(false);

  /** 选择相册/拍照（对齐 iOS didTapAlbum） */
  const choosePhoto = () => {
    Taro.chooseImage({
      count: 1,
      sizeType: ["compressed"],
      sourceType: ["album", "camera"],
      success: (res) => {
        setCustomAvatarUrl(res.tempFilePaths[0]);
        setSelectedAvatar("");
      },
    });
  };

  /** 选择 emoji 头像时清除自定义照片 */
  const selectEmoji = (emoji: string) => {
    setSelectedAvatar(emoji);
    setCustomAvatarUrl("");
  };

  const submit = async () => {
    const name = nickname.trim();
    if (!name) {
      Taro.showToast({ title: "请填写孩子昵称", icon: "none" });
      return;
    }
    if (name.length > 20) {
      Taro.showToast({ title: "昵称最多20个字", icon: "none" });
      return;
    }
    setSubmitting(true);
    try {
      await createChild({
        nickname: name,
        avatar: customAvatarUrl || selectedAvatar,
        birthday: selectedYear + "-01-01",
        gender: selectedGender,
        interests: Array.from(selectedInterests),
      });
      Taro.showToast({ title: "添加成功", icon: "success" });
      setTimeout(() => Taro.navigateBack(), 1500);
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  const toggleInterest = (item: string) => {
    const next = new Set(selectedInterests);
    if (next.has(item)) next.delete(item);
    else next.add(item);
    setSelectedInterests(next);
  };

  const yearIndex = BIRTH_YEARS.indexOf(selectedYear);
  const ageFromYear = currentYear - selectedYear;

  return (
    <View className="child-add">
      {/* 头像选择 */}
      <Text className="form-section-title">选一个头像</Text>
      <View className="avatar-row">
        {/* 相册入口（对齐 iOS：第一个位置，camera icon + "相册"文字） */}
        <View
          className={"avatar-item avatar-album" + (customAvatarUrl ? " avatar-item--active" : "")}
          onClick={choosePhoto}
        >
          {customAvatarUrl ? (
            <Image className="avatar-photo" src={customAvatarUrl} mode="aspectFill" />
          ) : (
            <View className="avatar-album-inner">
              <Text className="avatar-album-icon">📷</Text>
              <Text className="avatar-album-label">相册</Text>
            </View>
          )}
        </View>

        {/* 5 个 emoji 选项 */}
        {AVATAR_OPTIONS.map((emoji, i) => (
          <View
            key={i}
            className={"avatar-item" + (selectedAvatar === emoji ? " avatar-item--active" : "")}
            onClick={() => selectEmoji(emoji)}
          >
            <Text className="avatar-emoji">{emoji}</Text>
          </View>
        ))}
      </View>

      {/* 昵称 */}
      <Text className="form-section-title">孩子昵称</Text>
      <View className="form-input-wrap">
        <Input
          className="form-input-field"
          placeholder="如：糖糖"
          value={nickname}
          onInput={(e) => setNickname(e.detail.value)}
        />
      </View>

      {/* 出生年份 */}
      <Text className="form-section-title">出生年份</Text>
      <Picker
        mode="selector"
        range={BIRTH_YEARS.map((y) => String(y) + "年（" + String(currentYear - y) + "岁）")}
        value={yearIndex >= 0 ? yearIndex : 0}
        onChange={(e) => setSelectedYear(BIRTH_YEARS[e.detail.value])}
      >
        <View className="birth-picker">
          <Text className="birth-picker-text">{selectedYear}年（{ageFromYear}岁）</Text>
          <Text className="birth-picker-arrow">▾</Text>
        </View>
      </Picker>

      {/* 性别 */}
      <Text className="form-section-title">性别</Text>
      <View className="gender-row">
        <View
          className={"gender-btn" + (selectedGender === 2 ? " gender-btn--active" : "")}
          onClick={() => setSelectedGender(2)}
        >
          <Text>女孩</Text>
        </View>
        <View
          className={"gender-btn" + (selectedGender === 1 ? " gender-btn--active" : "")}
          onClick={() => setSelectedGender(1)}
        >
          <Text>男孩</Text>
        </View>
      </View>

      {/* 兴趣方向 */}
      <Text className="form-section-title">兴趣方向（可多选）</Text>
      <View className="interest-row">
        {INTEREST_OPTIONS.map((item) => (
          <View
            key={item}
            className={"interest-tag" + (selectedInterests.has(item) ? " interest-tag--active" : "")}
            onClick={() => toggleInterest(item)}
          >
            <Text>{item}</Text>
          </View>
        ))}
      </View>

      {/* 保存按钮 */}
      <View className="form-btns">
        <Button className="btn-primary form-submit" loading={submitting} onClick={submit}>保存</Button>
      </View>
    </View>
  );
}
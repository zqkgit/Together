import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Button, Input } from "@tarojs/components";
import { listChildren, createChild, type ChildItem } from "../../services/child";
import "./index.scss";

export default function ChildrenPage() {
  const [children, setChildren] = useState<ChildItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [nickname, setNickname] = useState("");
  const [birthday, setBirthday] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async () => {
    setLoading(true);
    try {
      const data = await listChildren();
      setChildren(data);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const submit = async () => {
    if (!nickname.trim()) {
      Taro.showToast({ title: "请输入孩子昵称", icon: "none" });
      return;
    }
    setSubmitting(true);
    try {
      await createChild({
        nickname: nickname.trim(),
        birthday: birthday || undefined
      });
      Taro.showToast({ title: "添加成功", icon: "success" });
      setShowForm(false);
      setNickname("");
      setBirthday("");
      loadData();
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  const goBalance = (childId: string) => {
    Taro.navigateTo({ url: `/pages/child-balance/index?id=${childId}` });
  };

  return (
    <View className="children">
      {children.map((child) => (
        <View key={child.child_id} className="card child-card">
          <View className="child-avatar">{child.nickname.slice(0, 1)}</View>
          <View className="child-info">
            <View className="child-name">{child.nickname}</View>
            <View className="child-birth">{child.birthday || "未设置生日"}</View>
          </View>
          <Text className="balance-link" onClick={() => goBalance(child.child_id)}>课时</Text>
        </View>
      ))}

      {children.length === 0 && !loading && (
        <View className="empty-tip">还没有添加学员</View>
      )}

      {showForm ? (
        <View className="card form-card">
          <Input
            className="form-input"
            placeholder="孩子昵称（小名）"
            value={nickname}
            onInput={(e) => setNickname(e.detail.value)}
          />
          <Input
            className="form-input"
            placeholder="生日（如 2020-06-01，可留空）"
            value={birthday}
            onInput={(e) => setBirthday(e.detail.value)}
          />
          <Button className="btn-primary form-submit" loading={submitting} onClick={submit}>保存</Button>
        </View>
      ) : (
        <Button className="btn-plain add-btn" onClick={() => setShowForm(true)}>添加学员</Button>
      )}
    </View>
  );
}

import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text } from "@tarojs/components";
import { getMe } from "../../../services/auth";
import "./account-security.scss";

interface SecurityRow {
  icon: string;
  title: string;
  value?: string;
  danger?: boolean;
  url: string;
}

export default function AccountSecurityPage() {
  const [phone, setPhone] = useState("");
  const [loaded, setLoaded] = useState(false);

  const rows: SecurityRow[] = [
    { icon: "📱", title: "绑定手机号", value: phone || undefined, url: "/packageInfo/pages/settings/change-phone" },
    { icon: "🔒", title: "修改登录密码", url: "/packageInfo/pages/settings/change-password" },
    { icon: "⚠️", title: "注销账号", danger: true, url: "" },
  ];

  useEffect(() => {
    loadSecurityInfo();
  }, []);

  const loadSecurityInfo = async () => {
    try {
      const res = await getMe();
      if (res.user?.phone) {
        const p = res.user.phone;
        setPhone(p.length === 11 ? p.slice(0, 3) + "****" + p.slice(7) : p);
      }
    } catch {
      // 忽略
    } finally {
      setLoaded(true);
    }
  };

  const handleTap = (row: SecurityRow) => {
    if (row.title === "注销账号") {
      Taro.showModal({
        title: "注销账号",
        content: "注销后账号数据将无法恢复，确定要继续吗？",
        confirmText: "继续",
        confirmColor: "#E5484D",
        success: (res) => {
          if (res.confirm) {
            Taro.navigateTo({ url: "/packageInfo/pages/settings/deactivate-account" });
          }
        },
      });
      return;
    }
    Taro.navigateTo({ url: row.url });
  };

  if (!loaded) return null;

  return (
    <View className="account-security">
      <View className="as-group">
        {rows.map((row, i) => (
          <View
            key={row.title}
            className={`as-row ${i < rows.length - 1 ? "as-row--border" : ""}`}
            onClick={() => handleTap(row)}
          >
            <Text className="as-row-icon">{row.icon}</Text>
            <Text className={`as-row-title ${row.danger ? "as-row-title--danger" : ""}`}>{row.title}</Text>
            {row.value && <Text className="as-row-value">{row.value}</Text>}
            <Text className="as-row-chevron">›</Text>
          </View>
        ))}
      </View>
    </View>
  );
}
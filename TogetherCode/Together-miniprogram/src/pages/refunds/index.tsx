import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getRefunds, type RefundItem } from "../../services/order";
import "./index.scss";

type Tab = "all" | "0" | "3" | "2";

const TABS: Array<{ key: Tab; label: string }> = [
  { key: "all", label: "全部" },
  { key: "0", label: "申请中" },
  { key: "3", label: "已通过" },
  { key: "2", label: "已驳回" }
];

export default function RefundsPage() {
  const [tab, setTab] = useState<Tab>("all");
  const [list, setList] = useState<RefundItem[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab]);

  const load = async () => {
    setLoading(true);
    try {
      const status = tab === "all" ? undefined : Number(tab);
      const data = await getRefunds(status);
      setList(data.list);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const goDetail = (id: string) => {
    Taro.navigateTo({ url: `/pages/refund-detail/index?id=${id}` });
  };

  const fmt = (t: string) => {
    if (!t) return "";
    const d = new Date(t);
    if (Number.isNaN(d.getTime())) return String(t).slice(0, 16).replace("T", " ");
    const p = (n: number) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
  };

  return (
    <View className="refunds">
      <View className="tab-bar">
        {TABS.map((t) => (
          <View
            key={t.key}
            className={`tab-item ${tab === t.key ? "active" : ""}`}
            onClick={() => setTab(t.key)}
          >
            {t.label}
          </View>
        ))}
      </View>

      <View className="list">
        {list.map((r) => (
          <View key={r.refund_id} className="card item" onClick={() => goDetail(r.refund_id)}>
            <Image className="item-cover" src={r.course_cover || ""} mode="aspectFill" />
            <View className="item-body">
              <View className="item-title">{r.course_title}</View>
              <View className="item-sub">
                {r.child_name} · {r.studio_name} · {r.requested_lessons} 课时
              </View>
              <View className="item-sub time">{fmt(r.created_at)}</View>
            </View>
            <View className="item-right">
              <View className="item-amount">{r.amount_text}</View>
              <Text className={`status-badge st-${r.status}`}>{r.status_text}</Text>
            </View>
          </View>
        ))}
        {list.length === 0 && !loading && <View className="empty-tip">暂无退款记录</View>}
        {loading && <View className="empty-tip">加载中...</View>}
      </View>
    </View>
  );
}

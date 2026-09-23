import React, { useState } from "react";
import Taro, { useDidShow } from "@tarojs/taro";
import { View, Text, ScrollView } from "@tarojs/components";
import {
  getWithdrawals,
  confirmWithdrawal,
  type CommissionWithdrawal,
  yuan,
  fmtTime,
} from "../../services/commission";
import "./index.scss";

export default function CommissionWithdrawalsPage() {
  const [rows, setRows] = useState<CommissionWithdrawal[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(false);

  const load = async (reset = true) => {
    if (loading) return;
    const p = reset ? 1 : page;
    setLoading(true);
    try {
      const res = await getWithdrawals({ page: p, page_size: 20 });
      if (reset) {
        setRows(res.list);
      } else {
        setRows((prev) => [...prev, ...res.list]);
      }
      setTotal(res.total);
      setPage(p + 1);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  useDidShow(() => {
    load(true);
  });

  const onScrollToLower = () => {
    if (rows.length < total) load(false);
  };

  const goDetail = (id: string) => {
    Taro.navigateTo({ url: `/pages/commission-withdrawal-detail/index?id=${id}` });
  };

  const doConfirm = async (item: CommissionWithdrawal) => {
    const res = await Taro.showModal({
      title: "确认收到佣金",
      content: `请确认你已在线下实际收到「${item.studio?.name || "工作室"}」打款的 ${item.amount_text || yuan(item.amount)}。确认后将标记为已完成。`,
      confirmText: "确认已收到",
      cancelText: "再核对一下",
    });
    if (!res.confirm) return;
    try {
      await confirmWithdrawal(item.withdraw_id);
      Taro.showToast({ title: "已确认，佣金标记为到账", icon: "none" });
      load(true);
    } catch {
      // 拦截器已提示
    }
  };

  return (
    <View className="withdrawals">
      <ScrollView
        scrollY
        className="scroll-area"
        onScrollToLower={onScrollToLower}
      >
        {rows.length === 0 ? (
          <View className="card empty-card">
            <View className="empty-icon">📋</View>
            <View className="empty-text">暂无领取记录</View>
            <View className="empty-sub">分享课程获得佣金后，可在此发起领取</View>
          </View>
        ) : (
          rows.map((item) => (
            <View
              key={item.withdraw_id}
              className="card wd-card"
              onClick={() => goDetail(item.withdraw_id)}
            >
              <View className="wd-top">
                <Text className="wd-studio">{item.studio?.name || "历史提现"}</Text>
                <Text className={`wd-tag tag-${item.status}`}>
                  {item.status_text || ""}
                </Text>
              </View>
              <View className="wd-amount">{item.amount_text || yuan(item.amount)}</View>
              <View className="wd-bottom">
                <Text className="wd-time">{fmtTime(item.created_at)}</Text>
                {item.method_text && (
                  <Text className="wd-method">{item.method_text}</Text>
                )}
              </View>
              {item.can_confirm && (
                <View
                  className="wd-confirm-btn"
                  onClick={(e) => {
                    e.stopPropagation();
                    doConfirm(item);
                  }}
                >
                  确认到账
                </View>
              )}
            </View>
          ))
        )}
      </ScrollView>
    </View>
  );
}
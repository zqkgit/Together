import { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getFollowing, type FollowingUser } from "../../../services/interaction";
import { createConversation } from "../../../services/message";
import { useAuthStore } from "../../../store/auth";
import "./index.scss";

const roleText = (role: number | null) => {
  if (role === 2) return "老师";
  if (role === 3) return "工作室";
  return "家长";
};

export default function FollowingListPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [users, setUsers] = useState<FollowingUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);

  const load = async (p: number = 1) => {
    try {
      const res = await getFollowing(p, 30);
      const list = res.list || [];
      if (p <= 1) {
        setUsers(list);
      } else {
        setUsers((prev) => [...prev, ...list]);
      }
      setHasMore(list.length < res.total);
      setPage(p);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (!isLoggedIn) {
      Taro.redirectTo({ url: "/pages/login/index" });
      return;
    }
    load();
  }, [isLoggedIn]);

  const onUserTap = async (user: FollowingUser) => {
    try {
      Taro.showLoading({ title: "创建会话..." });
      const res = await createConversation(user.user_id);
      Taro.hideLoading();
      const cid = res.data?.conversation_id;
      if (cid) {
        Taro.navigateTo({
          url: `/packageInfo/pages/chat/index?conversation_id=${cid}&peer_name=${encodeURIComponent(user.nickname || "艺启用户")}`,
        });
      } else {
        Taro.showToast({ title: "创建会话失败", icon: "none" });
      }
    } catch {
      Taro.hideLoading();
      Taro.showToast({ title: "创建会话失败", icon: "none" });
    }
  };

  const onScrollBottom = () => {
    if (hasMore && !loading) {
      load(page + 1);
    }
  };

  if (loading) {
    return <View className="following-list"><View className="empty-tip">加载中...</View></View>;
  }

  return (
    <View className="following-list">
      {users.length === 0 ? (
        <View className="empty-tip">暂无关注{"\n"}关注其他用户后可以在这里发起聊天</View>
      ) : (
        <View className="user-list">
          {users.map((u) => (
            <View key={u.user_id} className="user-card" onClick={() => onUserTap(u)}>
              {u.avatar ? (
                <Image className="user-avatar" src={u.avatar} mode="aspectFill" />
              ) : (
                <View className="user-avatar avatar-placeholder">
                  <Text className="avatar-text">{(u.nickname || "用").slice(0, 1)}</Text>
                </View>
              )}
              <View className="user-info">
                <View className="name-row">
                  <Text className="user-name">{u.nickname || "艺启用户"}</Text>
                  <View className="role-badge"><Text className="role-text">{roleText(u.role)}</Text></View>
                </View>
              </View>
              <Text className="arrow">›</Text>
            </View>
          ))}
        </View>
      )}
    </View>
  );
}
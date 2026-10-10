import { useEffect, useRef, useState, useCallback } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Image, Input, ScrollView } from "@tarojs/components";
import {
  createConversation,
  getConversationMessages,
  sendMessage,
  type ChatMessage,
} from "../../../services/message";
import { uploadImages } from "../../../services/upload";
import { useAuthStore } from "../../../store/auth";
import "./index.scss";

/** 聊天时间格式：今天 HH:mm / 昨天 HH:mm / MM-DD HH:mm / yyyy-MM-dd HH:mm（对齐 iOS ChatTimeFormatter） */
function fmtChatTime(val: string): string {
  if (!val) return "";
  const d = new Date(val);
  if (Number.isNaN(d.getTime())) return "";
  const bj = new Date(d.getTime() + 8 * 3600 * 1000);
  const pad = (n: number) => String(n).padStart(2, "0");
  const now = new Date();
  const nowBj = new Date(now.getTime() + 8 * 3600 * 1000);
  const h = `${pad(bj.getUTCHours())}:${pad(bj.getUTCMinutes())}`;
  const todayStr = `${nowBj.getUTCFullYear()}-${pad(nowBj.getUTCMonth() + 1)}-${pad(nowBj.getUTCDate())}`;
  const dateStr = `${bj.getUTCFullYear()}-${pad(bj.getUTCMonth() + 1)}-${pad(bj.getUTCDate())}`;
  if (dateStr === todayStr) return h;
  const yBj = new Date(nowBj.getTime() - 86400000);
  const yStr = `${yBj.getUTCFullYear()}-${pad(yBj.getUTCMonth() + 1)}-${pad(yBj.getUTCDate())}`;
  if (dateStr === yStr) return `昨天 ${h}`;
  if (bj.getUTCFullYear() === nowBj.getUTCFullYear()) {
    return `${pad(bj.getUTCMonth() + 1)}-${pad(bj.getUTCDate())} ${h}`;
  }
  return `${bj.getUTCFullYear()}-${pad(bj.getUTCMonth() + 1)}-${pad(bj.getUTCDate())} ${h}`;
}

/** 判断两条消息是否需要插入时间分隔（间隔 >5min 或跨天） */
function shouldInsertTime(prev: string | null, curr: string): boolean {
  if (!prev) return true;
  const d1 = new Date(prev).getTime();
  const d2 = new Date(curr).getTime();
  if (Number.isNaN(d1) || Number.isNaN(d2)) return true;
  if (d2 - d1 > 5 * 60 * 1000) return true;
  // 跨天判断
  const bj1 = new Date(d1 + 8 * 3600 * 1000);
  const bj2 = new Date(d2 + 8 * 3600 * 1000);
  const pad = (n: number) => String(n).padStart(2, "0");
  const s1 = `${bj1.getUTCFullYear()}-${pad(bj1.getUTCMonth() + 1)}-${pad(bj1.getUTCDate())}`;
  const s2 = `${bj2.getUTCFullYear()}-${pad(bj2.getUTCMonth() + 1)}-${pad(bj2.getUTCDate())}`;
  return s1 !== s2;
}

export default function ChatPage() {
  const router = useRouter();
  const peerUserId = router.params.peer_user_id || "";
  const peerName = decodeURIComponent(router.params.peer_name || "老师");
  const peerAvatar = decodeURIComponent(router.params.peer_avatar || "");
  const conversationIdFromParams = router.params.conversation_id || "";

  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const myUserId = useAuthStore((s) => s.user?.user_id || "");
  const myAvatar = useAuthStore((s) => s.user?.avatar || "");

  const [conversationId, setConversationId] = useState(conversationIdFromParams);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputText, setInputText] = useState("");
  const [sending, setSending] = useState(false);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [scrollTop, setScrollTop] = useState(0);

  // 初始化：获取或创建会话
  useEffect(() => {
    if (!isLoggedIn) {
      Taro.redirectTo({ url: "/pages/login/index" });
      return;
    }
    initConversation();
  }, []);

  const initConversation = async () => {
    try {
      let cid = conversationIdFromParams;
      if (!cid && peerUserId) {
        const res = await createConversation(peerUserId);
        cid = res?.conversation_id;
      }
      if (cid) {
        setConversationId(cid);
        await loadMessages(cid, 1);
      }
    } catch {
      Taro.showToast({ title: "获取会话失败", icon: "none" });
    } finally {
      setLoading(false);
    }
  };

  const loadMessages = async (cid: string, p: number) => {
    try {
      const res = await getConversationMessages(cid, { page: p, size: 30 });
      const list: ChatMessage[] = res.list || [];
      // 服务端按时间倒序，前端展示正序
      const sorted = list.slice().reverse();
      if (p === 1) {
        setMessages(sorted);
        // 首次加载后滚到底部
        setTimeout(() => scrollToBottom(), 100);
      } else {
        setMessages((prev) => [...sorted, ...prev]);
      }
      setPage(p);
      setHasMore(list.length >= 30);
    } catch {
      // 拦截器已提示
    }
  };

  // 加载更早消息（滚动到顶部时触发）
  const loadEarlier = useCallback(async () => {
    if (isLoadingMore || !hasMore || !conversationId) return;
    setIsLoadingMore(true);
    try {
      await loadMessages(conversationId, page + 1);
    } finally {
      setIsLoadingMore(false);
    }
  }, [isLoadingMore, hasMore, conversationId, page]);

  // 滚到底部
  const scrollToBottom = useCallback(() => {
    // 用递增 scrollTop 触发 ScrollView 滚动（小程序不支持 scrollTo API）
    setScrollTop((prev) => prev + 999);
  }, []);

  // 监听全局 WS 消息（由 app.tsx 广播）
  useEffect(() => {
    if (!conversationId) return;
    const handler = (msg: any) => {
      const data = msg?.data || msg;
      const evt = msg?.event || msg?.type;
      if (evt === "message" || evt === "chat_message" || evt === "new_message") {
        const cid = data?.conversation_id;
        if (cid && String(cid) === String(conversationId)) {
          const newMsg: ChatMessage = {
            message_id: data.message_id || String(Date.now()),
            conversation_id: String(cid),
            sender_id: data.sender?.user_id || data.sender_id,
            type: data.type || 1,
            content: data.content,
            created_at: data.created_at || new Date().toISOString(),
            sender: data.sender,
          };
          setMessages((prev) => {
            // 去重：避免和 handleSend 添加的重复
            if (prev.some((m) => m.message_id === newMsg.message_id)) return prev;
            // 多端同步：收到自己发的消息（WS 回显），替换乐观插入的临时消息
            const isSelf = String(newMsg.sender_id) === String(myUserId);
            if (isSelf) {
              const localIdx = prev.findIndex(
                (m) => m.message_id.startsWith("local-") && m.content === newMsg.content && String(m.sender_id) === String(myUserId)
              );
              if (localIdx >= 0) {
                const next = [...prev];
                next[localIdx] = newMsg;
                return next;
              }
            }
            return [...prev, newMsg];
          });
        }
      }
    };
    Taro.eventCenter.on("ws:message", handler);
    return () => {
      Taro.eventCenter.off("ws:message", handler);
    };
  }, [conversationId, myUserId]);

  // 消息列表变化时自动滚到底部（收到新消息 / 发送消息后）
  const prevMsgCountRef = useRef(0);
  useEffect(() => {
    if (messages.length > prevMsgCountRef.current) {
      scrollToBottom();
    }
    prevMsgCountRef.current = messages.length;
  }, [messages.length]);

  // 发送文本消息（乐观插入，对齐 iOS）
  const handleSend = async () => {
    const text = inputText.trim();
    if (!text || !conversationId || sending) return;
    setSending(true);
    setInputText("");

    // 乐观插入：先显示临时消息
    const tempId = `local-${Date.now()}`;
    const optimistic: ChatMessage = {
      message_id: tempId,
      conversation_id: conversationId,
      sender_id: myUserId,
      type: 1,
      content: text,
      read_at: null,
      created_at: new Date().toISOString(),
      sender: { user_id: myUserId, nickname: "", avatar: myAvatar, role: null },
    };
    setMessages((prev) => [...prev, optimistic]);
    scrollToBottom();

    try {
      const msg = await sendMessage(conversationId, text, 1);
      if (msg) {
        // 用服务端真实消息替换临时消息
        setMessages((prev) => {
          const idx = prev.findIndex((m) => m.message_id === tempId);
          if (idx >= 0) {
            const next = [...prev];
            // 去重：如果 WS 已推过同 id，直接移除临时消息
            if (prev.some((m) => m.message_id === msg.message_id && m.message_id !== tempId)) {
              next.splice(idx, 1);
            } else {
              next[idx] = msg;
            }
            return next;
          }
          return prev;
        });
      }
    } catch {
      // 发送失败：移除临时消息、还原输入框
      setMessages((prev) => prev.filter((m) => m.message_id !== tempId));
      setInputText(text);
      Taro.showToast({ title: "发送失败", icon: "none" });
    } finally {
      setSending(false);
    }
  };

  // 选择并发送图片
  const handleChooseImage = async () => {
    if (sending || !conversationId) return;
    try {
      const res = await Taro.chooseImage({ count: 1, sizeType: ["compressed"], sourceType: ["album", "camera"] });
      const tempPath = res.tempFilePaths[0];
      setSending(true);

      // 乐观插入图片占位
      const tempId = `local-img-${Date.now()}`;
      const optimistic: ChatMessage = {
        message_id: tempId,
        conversation_id: conversationId,
        sender_id: myUserId,
        type: 2,
        content: tempPath,
        read_at: null,
        created_at: new Date().toISOString(),
        sender: { user_id: myUserId, nickname: "", avatar: myAvatar, role: null },
      };
      setMessages((prev) => [...prev, optimistic]);
      scrollToBottom();

      // 上传图片
      const urls = await uploadImages([tempPath], "chat");
      const imageUrl = urls[0];
      if (!imageUrl) throw new Error("上传失败");

      // 发送图片消息
      const msg = await sendMessage(conversationId, imageUrl, 2);
      if (msg) {
        setMessages((prev) => {
          const idx = prev.findIndex((m) => m.message_id === tempId);
          if (idx >= 0) {
            const next = [...prev];
            if (prev.some((m) => m.message_id === msg.message_id && m.message_id !== tempId)) {
              next.splice(idx, 1);
            } else {
              next[idx] = msg;
            }
            return next;
          }
          return prev;
        });
      }
    } catch (e: any) {
      Taro.showToast({ title: e?.message || "图片发送失败", icon: "none" });
    } finally {
      setSending(false);
    }
  };

  // 构建展示列表：相邻间隔 >5min 或跨天插入时间行（对齐 iOS rebuildDisplay）
  const displayItems: Array<{ type: "time" | "msg"; value: string; msg?: ChatMessage }> = [];
  let lastTime: string | null = null;
  for (const m of messages) {
    if (shouldInsertTime(lastTime, m.created_at)) {
      displayItems.push({ type: "time", value: fmtChatTime(m.created_at) });
    }
    displayItems.push({ type: "msg", value: m.message_id, msg: m });
    lastTime = m.created_at;
  }

  const isMine = (m: ChatMessage) => {
    const sid = m.sender?.user_id || m.sender_id;
    return sid === myUserId || sid === String(myUserId);
  };

  if (loading) {
    return <View className="chat-page"><View className="chat-empty">加载中...</View></View>;
  }

  return (
    <View className="chat-page">
      <ScrollView
        className="chat-messages"
        scrollY
        enhanced
        scrollTop={scrollTop}
        onScroll={(e) => {
          // 滚到顶部加载更早消息
          if (e.detail.scrollTop < 60 && hasMore && !isLoadingMore) {
            loadEarlier();
          }
        }}
        onScrollToLower={() => {
          // ScrollView 的 onScrollToLower 在 scrollY 模式下可能不触发，用 onScroll 兜底
        }}
      >
        {isLoadingMore && <View className="load-earlier">加载更早消息...</View>}
        {displayItems.length === 0 && (
          <View className="chat-empty">打个招呼，开始聊天吧</View>
        )}
        {displayItems.map((item, idx) =>
          item.type === "time" ? (
            <View key={`t-${idx}`} className="chat-time">{item.value}</View>
          ) : (
            <View
              key={item.value}
              className={`chat-row ${isMine(item.msg!) ? "mine" : "peer"}`}
            >
              {/* 头像 30pt 圆角（对齐 iOS avatarView 30pt） */}
              {isMine(item.msg!) ? (
                <Image
                  className="chat-avatar"
                  src={myAvatar || ""}
                  mode="aspectFill"
                  onError={() => {}}
                />
              ) : (
                <Image
                  className="chat-avatar"
                  src={peerAvatar || item.msg?.sender?.avatar || ""}
                  mode="aspectFill"
                  onError={() => {}}
                />
              )}
              {/* 气泡 */}
              <View className="chat-bubble">
                {item.msg?.type === 2 ? (
                  <Image
                    className="bubble-img"
                    src={item.msg.content}
                    mode="aspectFill"
                    onClick={() => Taro.previewImage({ urls: [item.msg!.content], current: item.msg!.content })}
                  />
                ) : (
                  <Text className="bubble-text">{item.msg?.content}</Text>
                )}
              </View>
            </View>
          )
        )}
      </ScrollView>

      {/* 输入栏（对齐 iOS setupInputBar：photo按钮+圆角输入框+发送按钮） */}
      <View className="chat-input-bar">
        <View className="photo-btn" onClick={handleChooseImage}>
          <Text className="photo-icon">📷</Text>
        </View>
        <Input
          className="chat-input"
          placeholder="发消息…"
          value={inputText}
          onInput={(e) => setInputText(e.detail.value)}
          confirmType="send"
          onConfirm={handleSend}
          adjustPosition
        />
        <View
          className={`chat-send-btn ${!inputText.trim() || sending ? "disabled" : ""}`}
          onClick={handleSend}
        >
          发送
        </View>
      </View>
    </View>
  );
}
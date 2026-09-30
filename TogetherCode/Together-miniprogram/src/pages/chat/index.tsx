import { useEffect, useRef, useState } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Image, Input, ScrollView } from "@tarojs/components";
import {
  createConversation,
  getConversationMessages,
  sendMessage,
  type ConversationItem,
  type ChatMessage,
} from "../../services/message";
import { useAuthStore } from "../../store/auth";
import { connectMessageSocket } from "../../services/push";
import "./index.scss";

/** 格化时间 HH:mm */
function fmtTime(val: string): string {
  if (!val) return "";
  const d = new Date(val);
  if (Number.isNaN(d.getTime())) return String(val).slice(11, 16);
  const bj = new Date(d.getTime() + 8 * 3600 * 1000);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${pad(bj.getUTCHours())}:${pad(bj.getUTCMinutes())}`;
}

/** 日期分隔：今天/昨天/MM-DD */
function fmtDate(val: string): string {
  if (!val) return "";
  const d = new Date(val);
  if (Number.isNaN(d.getTime())) return "";
  const bj = new Date(d.getTime() + 8 * 3600 * 1000);
  const pad = (n: number) => String(n).padStart(2, "0");
  const dateStr = `${bj.getUTCFullYear()}-${pad(bj.getUTCMonth() + 1)}-${pad(bj.getUTCDate())}`;
  const now = new Date();
  const today = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
  if (dateStr === today) return "今天";
  const yesterday = new Date(now.getTime() - 86400000);
  const yStr = `${yesterday.getFullYear()}-${pad(yesterday.getMonth() + 1)}-${pad(yesterday.getDate())}`;
  if (dateStr === yStr) return "昨天";
  return `${pad(bj.getUTCMonth() + 1)}-${pad(bj.getUTCDate())}`;
}

export default function ChatPage() {
  const router = useRouter();
  const peerUserId = router.params.peer_user_id || "";
  const peerName = decodeURIComponent(router.params.peer_name || "老师");
  const conversationIdFromParams = router.params.conversation_id || "";

  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const myUserId = useAuthStore((s) => s.user?.user_id || "");

  const [conversationId, setConversationId] = useState(conversationIdFromParams);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputText, setInputText] = useState("");
  const [sending, setSending] = useState(false);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [hasMore, setHasMore] = useState(true);
  const stopWsRef = useRef<(() => void) | null>(null);
  const scrollRef = useRef<any>(null);

  // 初始化：获取或创建会话
  useEffect(() => {
    if (!isLoggedIn) {
      Taro.redirectTo({ url: "/pages/login/index" });
      return;
    }
    initConversation();
    return () => {
      stopWsRef.current?.();
      stopWsRef.current = null;
    };
  }, []);

  const initConversation = async () => {
    try {
      let cid = conversationIdFromParams;
      if (!cid && peerUserId) {
        const res = await createConversation(peerUserId);
        cid = res.data.conversation_id;
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
      } else {
        setMessages((prev) => [...sorted, ...prev]);
      }
      setPage(p);
      setHasMore(list.length >= 30);
    } catch {
      // 拦截器已提示
    }
  };

  // WS 实时消息
  useEffect(() => {
    if (!conversationId) return;
    const stop = connectMessageSocket((msg: any) => {
      if (msg?.event === "chat_message" || msg?.type === "new_message") {
        const data = msg.data || msg;
        if (data?.conversation_id === conversationId) {
          const newMsg: ChatMessage = {
            message_id: data.message_id || String(Date.now()),
            conversation_id: data.conversation_id,
            sender_id: data.sender_id || data.sender?.user_id,
            type: data.type || 1,
            content: data.content,
            created_at: data.created_at || new Date().toISOString(),
            sender: data.sender,
          };
          setMessages((prev) => [...prev, newMsg]);
        }
      }
    });
    stopWsRef.current = stop || null;
    return () => {
      stopWsRef.current?.();
      stopWsRef.current = null;
    };
  }, [conversationId]);

  const handleSend = async () => {
    const text = inputText.trim();
    if (!text || !conversationId || sending) return;
    setSending(true);
    setInputText("");
    try {
      const res = await sendMessage(conversationId, text, 1);
      const msg = res.data;
      if (msg) {
        setMessages((prev) => [...prev, msg]);
      }
    } catch {
      Taro.showToast({ title: "发送失败", icon: "none" });
    } finally {
      setSending(false);
    }
  };

  // 构建展示列表：插入时间分隔
  const displayItems: Array<{ type: "time" | "msg"; value: string; msg?: ChatMessage }> = [];
  let lastDate = "";
  for (const m of messages) {
    const dateStr = fmtDate(m.created_at);
    if (dateStr && dateStr !== lastDate) {
      displayItems.push({ type: "time", value: dateStr });
      lastDate = dateStr;
    }
    displayItems.push({ type: "msg", value: m.message_id, msg: m });
  }

  const isMine = (m: ChatMessage) => {
    const sid = m.sender_id || m.sender?.user_id;
    return sid === myUserId || sid === String(myUserId);
  };

  if (loading) {
    return <View className="chat-page"><View className="chat-empty">加载中...</View></View>;
  }

  return (
    <View className="chat-page">
      <ScrollView
        ref={scrollRef}
        className="chat-messages"
        scrollY
        scrollTop={99999}
      >
        {displayItems.length === 0 && (
          <View className="chat-empty">暂无消息，发送第一条吧</View>
        )}
        {displayItems.map((item, idx) =>
          item.type === "time" ? (
            <View key={`t-${idx}`} className="chat-time">{item.value}</View>
          ) : (
            <View
              key={item.value}
              className={`chat-bubble ${isMine(item.msg!) ? "mine" : "peer"}`}
            >
              {!isMine(item.msg!) && (
                <Text className="bubble-name">{item.msg?.sender?.nickname || peerName}</Text>
              )}
              {item.msg?.type === 2 ? (
                <Image className="bubble-img" src={item.msg.content} mode="widthFix" onClick={() => Taro.previewImage({ urls: [item.msg!.content], current: item.msg!.content })} />
              ) : (
                <Text className="bubble-text">{item.msg?.content}</Text>
              )}
              <Text className="bubble-time">{fmtTime(item.msg?.created_at || "")}</Text>
            </View>
          )
        )}
      </ScrollView>

      <View className="chat-input-bar">
        <Input
          className="chat-input"
          placeholder="发消息..."
          value={inputText}
          onInput={(e) => setInputText(e.detail.value)}
          confirmType="send"
          onConfirm={handleSend}
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
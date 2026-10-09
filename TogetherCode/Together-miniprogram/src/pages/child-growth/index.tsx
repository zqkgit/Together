import { useEffect, useState, useMemo } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getChildGrowth, getChildWorks, type ChildGrowth, type ChildWorks, type ChildBalance } from "../../services/child";
import "./index.scss";

const TAB_WORKS = "works";
const TAB_COURSES = "courses";
const TAB_DYNAMICS = "dynamics";
type TabType = typeof TAB_WORKS | typeof TAB_COURSES | typeof TAB_DYNAMICS;

/** 课程聚合（同课程课包合并，对齐 iOS ChildCourseAggregate） */
interface ChildCourseAggregate {
  course_id: string;
  course_title: string;
  studio_name: string;
  total: number;
  consumed: number;
  remaining: number;
  isRefunded: boolean;
}

function aggregateCourses(balances?: ChildBalance[]): ChildCourseAggregate[] {
  if (!balances || balances.length === 0) return [];
  const map = new Map<string, ChildCourseAggregate>();
  for (const b of balances) {
    const key = b.course_id || b.course_title || String(Math.random());
    const existing = map.get(key);
    if (existing) {
      if (b.status !== 4) {
        existing.total += b.total_lessons || 0;
        existing.consumed += b.consumed_lessons || 0;
        existing.remaining += b.remaining_lessons || 0;
        existing.isRefunded = false;
      }
    } else {
      const item: ChildCourseAggregate = {
        course_id: b.course_id || "",
        course_title: b.course_title || "未命名课程",
        studio_name: b.studio_name || "艺术工坊",
        total: 0,
        consumed: 0,
        remaining: 0,
        isRefunded: true,
      };
      if (b.status !== 4) {
        item.total += b.total_lessons || 0;
        item.consumed += b.consumed_lessons || 0;
        item.remaining += b.remaining_lessons || 0;
        item.isRefunded = false;
      }
      map.set(key, item);
    }
  }
  return Array.from(map.values())
    .filter(c => c.total > 0 || c.isRefunded)
    .sort((a, b) => a.course_title.localeCompare(b.course_title));
}

/** 出勤率 = Σconsumed / Σtotal * 100% */
function calcAttendance(balances?: ChildBalance[]): string {
  if (!balances || balances.length === 0) return "—";
  let total = 0;
  let consumed = 0;
  for (const b of balances) {
    if (b.status !== 4) {
      total += b.total_lessons || 0;
      consumed += b.consumed_lessons || 0;
    }
  }
  if (total === 0) return "—";
  return Math.round((consumed / total) * 100) + "%";
}

/** 事件类型 emoji（对齐 iOS eventTypeIcon） */
function eventEmoji(type?: string): string {
  switch (type) {
    case "consume": return "📖";
    case "refund": return "💰";
    case "post": return "🎨";
    case "enroll": return "✨";
    default: return "";
  }
}

/** 格式化时间 */
function fmtTime(s?: string | null): string {
  if (!s || s.length < 16) return s || "";
  if (s.endsWith("Z")) {
    try {
      const d = new Date(s);
      const p = (n: number) => String(n).padStart(2, "0");
      return d.getFullYear() + "-" + p(d.getMonth() + 1) + "-" + p(d.getDate()) + " " + p(d.getHours()) + ":" + p(d.getMinutes());
    } catch {
      return s.slice(0, 16);
    }
  }
  return s.slice(0, 16);
}

function genderText(g?: number | null): string {
  if (g === 2) return "女";
  if (g === 1) return "男";
  return "";
}

function ageText(b?: string | null): string {
  if (!b || b.length < 4) return "";
  const year = parseInt(b.slice(0, 4), 10);
  if (isNaN(year)) return "";
  const age = new Date().getFullYear() - year;
  return age >= 0 ? age + "岁" : "";
}

export default function ChildGrowthPage() {
  const router = useRouter();
  const childId = router.params.id || "";
  const [growth, setGrowth] = useState<ChildGrowth | null>(null);
  const [works, setWorks] = useState<ChildWorks | null>(null);
  const [tab, setTab] = useState<TabType>(TAB_WORKS);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (childId) {
      loadGrowth();
      loadWorks();
    }
  }, [childId]);

  const loadGrowth = async () => {
    try { setGrowth(await getChildGrowth(childId)); } catch { /* 拦截器已提示 */ } finally { setLoading(false); }
  };

  const loadWorks = async () => {
    try { setWorks(await getChildWorks(childId)); } catch { /* 忽略 */ }
  };

  const child = growth?.child;
  const overview = growth?.overview;
  const balances = growth?.balances;
  const courses = useMemo(() => aggregateCourses(balances), [balances]);
  const attendance = useMemo(() => {
    // 优先用 overview 的汇总数据计算出勤率
    if (overview && overview.total_lessons > 0) {
      return Math.round((overview.consumed_lessons / overview.total_lessons) * 100) + "%";
    }
    // 兜底从 balances 逐条计算
    return calcAttendance(balances);
  }, [overview, balances]);

  const goPost = (postId: string) => {
    Taro.navigateTo({ url: "/pages/post-detail/index?id=" + postId });
  };

  if (loading) return <View className="empty-tip">加载中...</View>;
  if (!growth) return <View className="empty-tip">档案不存在</View>;

  // 头像：URL 照片 / emoji / 首字
  const isAvatarUrl = !!child?.avatar && child.avatar.startsWith("http");
  const avatarChar = isAvatarUrl ? "" : (child?.avatar || (child?.nickname || "孩")[0]);

  // 头部信息行：性别·年龄·课程名
  const metaParts: string[] = [genderText(child?.gender), ageText(child?.birthday)];
  const firstCourse = balances?.find(b => b.course_title)?.course_title;
  if (firstCourse) metaParts.push(firstCourse);
  const metaText = metaParts.filter(Boolean).join("·");

  const workCount = works?.total ?? overview?.work_count ?? 0;

  return (
    <View className="growth-page">
      {/* ====== 深绿渐变头部（对齐 iOS ChildHeaderView） ====== */}
      <View className="header">
        <View className="header-orb" />
        <View className="header-main">
          <View className="header-avatar">
            {isAvatarUrl ? (
              <Image className="header-avatar-img" src={child!.avatar!} mode="aspectFill" />
            ) : (
              <Text className="header-avatar-text">{avatarChar}</Text>
            )}
          </View>
          <View className="header-info">
            <Text className="header-name">{child?.nickname || "孩子"}</Text>
            {metaText ? <Text className="header-meta">{metaText}</Text> : null}
          </View>
        </View>

        {/* 统计卡（对齐 iOS：半透白底三列 + 白字 + 列间分割线） */}
        <View className="stats-card">
          <View className="stat">
            <Text className="stat-num">{overview?.active_courses ?? 0}</Text>
            <Text className="stat-label">在学课程</Text>
          </View>
          <View className="stat-divider" />
          <View className="stat">
            <Text className="stat-num">{workCount}</Text>
            <Text className="stat-label">作品数</Text>
          </View>
          <View className="stat-divider" />
          <View className="stat">
            <Text className="stat-num">{attendance}</Text>
            <Text className="stat-label">出勤率</Text>
          </View>
        </View>
      </View>

      {/* ====== 三 tab 分段（对齐 iOS UISegmentedControl） ====== */}
      <View className="tabs">
        <View className={"tab" + (tab === TAB_WORKS ? " tab-active" : "")} onClick={() => setTab(TAB_WORKS)}>
          <Text>作品</Text>
        </View>
        <View className={"tab" + (tab === TAB_COURSES ? " tab-active" : "")} onClick={() => setTab(TAB_COURSES)}>
          <Text>课程</Text>
        </View>
        <View className={"tab" + (tab === TAB_DYNAMICS ? " tab-active" : "")} onClick={() => setTab(TAB_DYNAMICS)}>
          <Text>动态</Text>
        </View>
      </View>

      {/* ====== 作品 tab（对齐 iOS ChildWorkCell：2列+标题） ====== */}
      {tab === TAB_WORKS && (
        <View className="tab-content">
          {!works || works.list.length === 0 ? (
            <View className="empty-state">
              <Text className="empty-state-title">还没有作品</Text>
              <Text className="empty-state-sub">老师的课堂作品会自动归入这里</Text>
            </View>
          ) : (
            <View className="work-grid">
              {works.list.map(w => (
                <View key={w.post_id} className="work-item" onClick={() => goPost(w.post_id)}>
                  {w.images?.[0] ? (
                    <Image className="work-img" src={w.images[0]} mode="aspectFill" />
                  ) : (
                    <View className="work-img-ph" />
                  )}
                  <Text className="work-title">{w.content || w.course_title || "作品"}</Text>
                </View>
              ))}
            </View>
          )}
        </View>
      )}

      {/* ====== 课程 tab（对齐 iOS ChildCourseCell：进度条+退款标签） ====== */}
      {tab === TAB_COURSES && (
        <View className="tab-content">
          {courses.length === 0 ? (
            <View className="empty-state">
              <Text className="empty-state-title">还没有课程</Text>
              <Text className="empty-state-sub">报名课程后会在这里显示</Text>
            </View>
          ) : (
            courses.map(c => {
              const total = Math.max(c.total, 1);
              const consumed = Math.min(c.consumed, total);
              const ratio = consumed / total;
              return (
                <View key={c.course_id} className="course-card">
                  <View className="course-top">
                    <Text className={"course-title" + (c.isRefunded ? " course-title--refund" : "")}>{c.course_title}</Text>
                    {c.isRefunded && (
                      <View className="refund-tag"><Text className="refund-tag-text">已退款</Text></View>
                    )}
                  </View>
                  <Text className="course-studio">{c.studio_name}</Text>
                  <View className="course-progress">
                    <View className="progress-track">
                      <View className={"progress-fill" + (c.isRefunded ? " progress-fill--refund" : "")} style={{ width: (ratio * 100) + "%" }} />
                    </View>
                    <Text className="progress-label">{"已上" + consumed + "/" + c.total + "节"}</Text>
                  </View>
                </View>
              );
            })
          )}
        </View>
      )}

      {/* ====== 动态 tab（对齐 iOS ChildDynamicCell：卡片+头像+emoji+课程标签） ====== */}
      {tab === TAB_DYNAMICS && (
        <View className="tab-content">
          {growth.timeline.length === 0 ? (
            <View className="empty-state">
              <Text className="empty-state-title">还没有动态</Text>
              <Text className="empty-state-sub">上课消课记录会展示在这里</Text>
            </View>
          ) : (
            growth.timeline.map((item, idx) => {
              const source = item.studio_name || "成长记录";
              const body = item.note || item.post?.content || "记录了新的成长瞬间";
              const emoji = eventEmoji(item.event_type);
              const time = fmtTime(item.created_at);
              return (
                <View key={item.event_id + "-" + idx} className="dynamic-card">
                  <View className="dynamic-head">
                    <View className="dynamic-avatar">
                      <Text className="dynamic-avatar-text">{source[0]}</Text>
                    </View>
                    <Text className="dynamic-source">{source}</Text>
                    {emoji ? <Text className="dynamic-emoji">{emoji}</Text> : null}
                    {time ? <Text className="dynamic-time">{time}</Text> : null}
                  </View>
                  <Text className="dynamic-body">{body}</Text>
                  {item.course_title ? (
                    <View className="dynamic-course-tag">
                      <Text className="dynamic-course-tag-text">{"关联课程·" + item.course_title}</Text>
                    </View>
                  ) : null}
                </View>
              );
            })
          )}
        </View>
      )}
    </View>
  );
}
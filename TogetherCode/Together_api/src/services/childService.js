const { Op } = require("sequelize");
const {
  Child,
  ChildCourseBalance,
  Order,
  Course,
  StudioProfile,
  Post,
  PostStudent,
  LessonLog,
  Schedule,
  User,
  Attendance,
  LeaveRequest,
  Class
} = require("../models");

function formatChildBase(child) {
  return {
    child_id: String(child.child_id),
    nickname: child.nickname,
    avatar: child.avatar,
    birthday: child.birthday,
    gender: child.gender
  };
}

function formatChildBalance(balance) {
  return {
    balance_id: String(balance.balance_id),
    order_id: String(balance.order_id),
    course_id: String(balance.course_id),
    studio_id: balance.order?.studio ? String(balance.order.studio.studio_id) : null,
    studio_name: balance.order?.studio?.name || null,
    course_title: balance.course?.title || "-",
    total_lessons: balance.total_lessons,
    consumed_lessons: balance.consumed_lessons,
    refunded_lessons: balance.refunded_lessons,
    remaining_lessons: balance.remaining_lessons,
    valid_from: balance.valid_from,
    valid_to: balance.valid_to,
    status: balance.status
  };
}

function formatChild(child) {
  const balances = (child.balances || []).map(formatChildBalance);
  const totalRemainingLessons = balances.reduce(
    (sum, item) => sum + Number(item.remaining_lessons || 0),
    0
  );

  return {
    ...formatChildBase(child),
    total_remaining_lessons: totalRemainingLessons,
    status: totalRemainingLessons > 0 ? "active" : "empty",
    balances
  };
}

async function listChildren(parentUserId) {
  const rows = await Child.findAll({
    where: {
      parent_user_id: parentUserId
    },
    include: [
      {
        model: ChildCourseBalance,
        as: "balances",
        required: false,
        include: [
          {
            model: Order,
            as: "order",
            attributes: ["order_id", "studio_id"],
            include: [
              {
                model: StudioProfile,
                as: "studio",
                attributes: ["studio_id", "name"]
              }
            ]
          },
          {
            model: Course,
            as: "course",
            attributes: ["course_id", "title", "cover"]
          }
        ]
      }
    ],
    order: [
      ["created_at", "DESC"],
      [{ model: ChildCourseBalance, as: "balances" }, "created_at", "DESC"]
    ]
  });

  return {
    total: rows.length,
    list: rows.map(formatChild)
  };
}

async function getChildDetail(parentUserId, childId) {
  const row = await Child.findOne({
    where: {
      child_id: childId,
      parent_user_id: parentUserId
    },
    include: [
      {
        model: ChildCourseBalance,
        as: "balances",
        required: false,
        include: [
          {
            model: Order,
            as: "order",
            attributes: ["order_id", "studio_id"],
            include: [
              {
                model: StudioProfile,
                as: "studio",
                attributes: ["studio_id", "name"]
              }
            ]
          },
          {
            model: Course,
            as: "course",
            attributes: ["course_id", "title", "cover"]
          }
        ]
      }
    ],
    order: [[{ model: ChildCourseBalance, as: "balances" }, "created_at", "DESC"]]
  });

  if (!row) {
    return null;
  }

  return formatChild(row);
}

async function ensureOwnedChild(parentUserId, childId) {
  return Child.findOne({
    where: {
      child_id: childId,
      parent_user_id: parentUserId
    }
  });
}

async function loadChildBalances(childId) {
  return ChildCourseBalance.findAll({
    where: { child_id: childId },
    include: [
      {
        model: Order,
        as: "order",
        attributes: ["order_id", "studio_id"],
        include: [
          {
            model: StudioProfile,
            as: "studio",
            attributes: ["studio_id", "name"]
          }
        ]
      },
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "title", "cover"]
      }
    ],
    order: [["created_at", "DESC"]]
  });
}

function formatWorkPost(post, meta = {}) {
  return {
    post_id: String(post.post_id),
    child_id: meta.child_id ? String(meta.child_id) : post.child_id ? String(post.child_id) : null,
    course_id: post.course_id ? String(post.course_id) : null,
    course_title: post.course?.title || null,
    teacher: post.author
      ? {
          user_id: String(post.author.user_id),
          nickname: post.author.nickname,
          avatar: post.author.avatar
        }
      : null,
    content: post.content,
    images: post.images || [],
    visibility: post.visibility,
    like_count: post.like_count,
    comment_count: post.comment_count,
    created_at: post.created_at,
    teacher_comment: post.content || null
  };
}

async function collectChildPosts(childId) {
  const [relationRows, directPosts] = await Promise.all([
    PostStudent.findAll({
      where: { child_id: childId },
      include: [
        {
          model: Post,
          as: "post",
          required: true,
          include: [
            {
              model: Course,
              as: "course",
              attributes: ["course_id", "title", "cover", "studio_id"],
              include: [
                {
                  model: StudioProfile,
                  as: "studio",
                  attributes: ["studio_id", "name"]
                }
              ]
            },
            {
              model: User,
              as: "author",
              attributes: ["user_id", "nickname", "avatar"]
            }
          ]
        }
      ],
      order: [["created_at", "DESC"]]
    }),
    Post.findAll({
      where: { child_id: childId },
      include: [
        {
          model: Course,
          as: "course",
          attributes: ["course_id", "title", "cover", "studio_id"],
          include: [
            {
              model: StudioProfile,
              as: "studio",
              attributes: ["studio_id", "name"]
            }
          ]
        },
        {
          model: User,
          as: "author",
          attributes: ["user_id", "nickname", "avatar"]
        }
      ],
      order: [["created_at", "DESC"]]
    })
  ]);

  const workMap = new Map();

  relationRows.forEach((row) => {
    if (!row.post || workMap.has(String(row.post.post_id))) {
      return;
    }

    workMap.set(String(row.post.post_id), formatWorkPost(row.post, { child_id: row.child_id }));
  });

  directPosts.forEach((post) => {
    if (workMap.has(String(post.post_id))) {
      return;
    }

    workMap.set(String(post.post_id), formatWorkPost(post));
  });

  const list = Array.from(workMap.values()).sort((a, b) => {
    return new Date(b.created_at).getTime() - new Date(a.created_at).getTime();
  });

  return list;
}

async function listChildWorks(parentUserId, childId) {
  const child = await ensureOwnedChild(parentUserId, childId);
  if (!child) {
    return null;
  }

  const list = await collectChildPosts(childId);

  return {
    child: formatChildBase(child),
    total: list.length,
    list
  };
}

async function listChildPosts(parentUserId, childId) {
  const child = await ensureOwnedChild(parentUserId, childId);
  if (!child) {
    return null;
  }

  const list = await collectChildPosts(childId);

  return {
    child: formatChildBase(child),
    total: list.length,
    list
  };
}

function formatTimelineLog(item) {
  const eventType = Number(item.delta) < 0
    ? Number(item.type) === 3
      ? "refund"
      : "lesson_consumed"
    : "lesson_granted";

  const eventTime = item.schedule?.lesson_date
    ? `${item.schedule.lesson_date} ${item.schedule.start_time || "00:00"}`
    : item.created_at;

  return {
    event_id: `log_${item.log_id}`,
    event_type: eventType,
    child_id: String(item.child_id),
    course_id: String(item.course_id),
    course_title: item.course?.title || null,
    studio_id: item.order?.studio ? String(item.order.studio.studio_id) : null,
    studio_name: item.order?.studio?.name || null,
    order_id: String(item.order_id),
    post_id: item.post_id ? String(item.post_id) : null,
    schedule_id: item.schedule_id ? String(item.schedule_id) : null,
    delta: item.delta,
    balance_after: item.balance_after,
    note: item.note,
    schedule: item.schedule
      ? {
          lesson_date: item.schedule.lesson_date,
          start_time: item.schedule.start_time,
          end_time: item.schedule.end_time,
          location: item.schedule.location
        }
      : null,
    post: item.post
      ? {
          post_id: String(item.post.post_id),
          content: item.post.content,
          images: item.post.images || []
        }
      : null,
    occurred_at: eventTime,
    created_at: item.created_at
  };
}

function formatTimelinePost(post, childId) {
  return {
    event_id: `post_${post.post_id}`,
    event_type: "post",
    child_id: String(childId),
    course_id: post.course_id ? String(post.course_id) : null,
    course_title: post.course?.title || null,
    studio_id: null,
    studio_name: null,
    order_id: null,
    post_id: String(post.post_id),
    schedule_id: null,
    delta: 0,
    balance_after: null,
    note: post.content,
    schedule: null,
    post: {
      post_id: String(post.post_id),
      content: post.content,
      images: post.images || []
    },
    occurred_at: post.created_at,
    created_at: post.created_at
  };
}

async function getChildGrowth(parentUserId, childId) {
  const child = await ensureOwnedChild(parentUserId, childId);
  if (!child) {
    return null;
  }

  const [balances, lessonLogs, works] = await Promise.all([
    loadChildBalances(childId),
    LessonLog.findAll({
      where: { child_id: childId },
      include: [
        {
          model: Course,
          as: "course",
          attributes: ["course_id", "title", "cover"]
        },
        {
          model: Order,
          as: "order",
          attributes: ["order_id", "studio_id"],
          include: [
            {
              model: StudioProfile,
              as: "studio",
              attributes: ["studio_id", "name"]
            }
          ]
        },
        {
          model: Schedule,
          as: "schedule",
          attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
        },
        {
          model: Post,
          as: "post",
          attributes: ["post_id", "content", "images", "created_at"]
        }
      ],
      order: [["created_at", "DESC"]]
    }),
    listChildWorks(parentUserId, childId)
  ]);

  const summary = balances.reduce(
    (acc, balance) => {
      acc.total_lessons += Number(balance.total_lessons || 0);
      acc.consumed_lessons += Number(balance.consumed_lessons || 0);
      acc.refunded_lessons += Number(balance.refunded_lessons || 0);
      acc.remaining_lessons += Number(balance.remaining_lessons || 0);
      acc.course_ids.add(String(balance.course_id));
      if (Number(balance.remaining_lessons || 0) > 0) {
        acc.active_course_ids.add(String(balance.course_id));
      }
      if (balance.order?.studio) {
        acc.studio_ids.add(String(balance.order.studio.studio_id));
      }
      return acc;
    },
    {
      total_lessons: 0,
      consumed_lessons: 0,
      refunded_lessons: 0,
      remaining_lessons: 0,
      course_ids: new Set(),
      active_course_ids: new Set(),
      studio_ids: new Set()
    }
  );

  const timeline = [];
  const existingPostIds = new Set();

  lessonLogs.forEach((item) => {
    timeline.push(formatTimelineLog(item));
    if (item.post_id) {
      existingPostIds.add(String(item.post_id));
    }
  });

  (works?.list || []).forEach((item) => {
    if (existingPostIds.has(String(item.post_id))) {
      return;
    }

    timeline.push(
      formatTimelinePost(
        {
          post_id: item.post_id,
          course_id: item.course_id,
          course: { title: item.course_title },
          content: item.content,
          images: item.images,
          created_at: item.created_at
        },
        childId
      )
    );
  });

  timeline.sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());

  return {
    child: formatChildBase(child),
    overview: {
      total_courses: summary.course_ids.size,
      active_courses: summary.active_course_ids.size,
      studio_count: summary.studio_ids.size,
      total_lessons: summary.total_lessons,
      consumed_lessons: summary.consumed_lessons,
      refunded_lessons: summary.refunded_lessons,
      remaining_lessons: summary.remaining_lessons,
      work_count: works?.total || 0,
      timeline_count: timeline.length
    },
    assessments: [],
    balances: balances.map(formatChildBalance),
    timeline
  };
}

function formatLessonLogItem(item) {
  const typeLabelMap = {
    1: "grant",
    2: "consume",
    3: "refund"
  };

  const sourceLabelMap = {
    1: "order",
    2: "leave",
    3: "teacher_post",
    4: "refund_or_backoffice"
  };

  return {
    log_id: String(item.log_id),
    child_id: String(item.child_id),
    course_id: String(item.course_id),
    course_title: item.course?.title || null,
    studio_id: item.order?.studio ? String(item.order.studio.studio_id) : null,
    studio_name: item.order?.studio?.name || null,
    order_id: String(item.order_id),
    post_id: item.post_id ? String(item.post_id) : null,
    schedule_id: item.schedule_id ? String(item.schedule_id) : null,
    source: item.source,
    source_label: sourceLabelMap[item.source] || "unknown",
    type: item.type,
    type_label: typeLabelMap[item.type] || "unknown",
    delta: item.delta,
    balance_after: item.balance_after,
    note: item.note,
    post: item.post
      ? {
          post_id: String(item.post.post_id),
          content: item.post.content,
          images: item.post.images || []
        }
      : null,
    schedule: item.schedule
      ? {
          schedule_id: String(item.schedule.schedule_id),
          lesson_date: item.schedule.lesson_date,
          start_time: item.schedule.start_time,
          end_time: item.schedule.end_time,
          location: item.schedule.location
        }
      : null,
    created_at: item.created_at
  };
}

async function listChildLessonLogs(parentUserId, childId) {
  const child = await ensureOwnedChild(parentUserId, childId);
  if (!child) {
    return null;
  }

  const rows = await LessonLog.findAll({
    where: { child_id: childId },
    include: [
      {
        model: Course,
        as: "course",
        attributes: ["course_id", "title", "cover"]
      },
      {
        model: Order,
        as: "order",
        attributes: ["order_id", "studio_id"],
        include: [
          {
            model: StudioProfile,
            as: "studio",
            attributes: ["studio_id", "name"]
          }
        ]
      },
      {
        model: Post,
        as: "post",
        attributes: ["post_id", "content", "images", "created_at"]
      },
      {
        model: Schedule,
        as: "schedule",
        attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
      }
    ],
    order: [["created_at", "DESC"]]
  });

  return {
    child: formatChildBase(child),
    total: rows.length,
    list: rows.map(formatLessonLogItem)
  };
}

function resolveMonthRange(month) {
  const now = new Date();
  const safeMonth = month || `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;
  const [year, monthValue] = safeMonth.split("-").map(Number);
  const start = new Date(year, monthValue - 1, 1);
  const end = new Date(year, monthValue, 0);
  const endText = `${end.getFullYear()}-${String(end.getMonth() + 1).padStart(2, "0")}-${String(
    end.getDate()
  ).padStart(2, "0")}`;
  const startText = `${year}-${String(monthValue).padStart(2, "0")}-01`;

  return {
    month: safeMonth,
    startText,
    endText
  };
}

function pushCalendarEvent(map, date, event) {
  if (!date) {
    return;
  }

  if (!map.has(date)) {
    map.set(date, []);
  }

  map.get(date).push(event);
}

async function getChildCalendar(parentUserId, childId, query = {}) {
  const child = await ensureOwnedChild(parentUserId, childId);
  if (!child) {
    return null;
  }

  const { month, startText, endText } = resolveMonthRange(query.month);

  const [attendances, leaves, lessonLogs, posts] = await Promise.all([
    Attendance.findAll({
      where: { child_id: childId },
      include: [
        {
          model: Schedule,
          as: "schedule",
          required: true,
          where: {
            lesson_date: {
              [Op.between]: [startText, endText]
            }
          },
          attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location", "course_id"]
        },
        {
          model: Order,
          as: "order",
          attributes: ["order_id", "studio_id"],
          include: [
            {
              model: StudioProfile,
              as: "studio",
              attributes: ["studio_id", "name"]
            }
          ]
        }
      ],
      order: [[{ model: Schedule, as: "schedule" }, "lesson_date", "ASC"]]
    }),
    LeaveRequest.findAll({
      where: { child_id: childId },
      include: [
        {
          model: Class,
          as: "classItem",
          attributes: ["class_id", "name"]
        },
        {
          model: Schedule,
          as: "schedule",
          required: false,
          where: {
            lesson_date: {
              [Op.between]: [startText, endText]
            }
          },
          attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
        }
      ],
      order: [["created_at", "ASC"]]
    }),
    LessonLog.findAll({
      where: { child_id: childId },
      include: [
        {
          model: Schedule,
          as: "schedule",
          required: true,
          where: {
            lesson_date: {
              [Op.between]: [startText, endText]
            }
          },
          attributes: ["schedule_id", "lesson_date", "start_time", "end_time", "location"]
        },
        {
          model: Course,
          as: "course",
          attributes: ["course_id", "title"]
        }
      ],
      order: [[{ model: Schedule, as: "schedule" }, "lesson_date", "ASC"]]
    })
  ]);

  const childPosts = await collectChildPosts(childId);
  const monthPosts = childPosts.filter((item) => String(item.created_at).slice(0, 7) === month);
  const eventMap = new Map();

  attendances.forEach((item) => {
    pushCalendarEvent(eventMap, item.schedule?.lesson_date, {
      event_id: `attendance_${item.attendance_id}`,
      event_type: "attendance",
      date: item.schedule?.lesson_date,
      status: item.status,
      order_id: String(item.order_id),
      schedule_id: String(item.schedule_id),
      studio_id: item.order?.studio ? String(item.order.studio.studio_id) : null,
      studio_name: item.order?.studio?.name || null,
      time: item.schedule
        ? {
            start_time: item.schedule.start_time,
            end_time: item.schedule.end_time,
            location: item.schedule.location
          }
        : null,
      note: item.note
    });
  });

  leaves.forEach((item) => {
    const date = item.schedule?.lesson_date || String(item.created_at).slice(0, 10);
    if (String(date).slice(0, 7) !== month) {
      return;
    }

    pushCalendarEvent(eventMap, date, {
      event_id: `leave_${item.leave_id}`,
      event_type: "leave",
      date,
      leave_id: String(item.leave_id),
      class_id: String(item.class_id),
      class_name: item.classItem?.name || null,
      schedule_id: item.schedule_id ? String(item.schedule_id) : null,
      status: item.status,
      reason: item.reason,
      time: item.schedule
        ? {
            start_time: item.schedule.start_time,
            end_time: item.schedule.end_time,
            location: item.schedule.location
          }
        : null
    });
  });

  lessonLogs.forEach((item) => {
    pushCalendarEvent(eventMap, item.schedule?.lesson_date, {
      event_id: `lesson_log_${item.log_id}`,
      event_type: "lesson_log",
      date: item.schedule?.lesson_date,
      log_id: String(item.log_id),
      course_id: String(item.course_id),
      course_title: item.course?.title || null,
      schedule_id: item.schedule_id ? String(item.schedule_id) : null,
      delta: item.delta,
      balance_after: item.balance_after,
      note: item.note,
      time: item.schedule
        ? {
            start_time: item.schedule.start_time,
            end_time: item.schedule.end_time,
            location: item.schedule.location
          }
        : null
    });
  });

  monthPosts.forEach((item) => {
    const date = String(item.created_at).slice(0, 10);
    pushCalendarEvent(eventMap, date, {
      event_id: `post_${item.post_id}`,
      event_type: "post",
      date,
      post_id: item.post_id,
      course_id: item.course_id,
      course_title: item.course_title,
      teacher: item.teacher,
      content: item.content,
      images: item.images || []
    });
  });

  const days = Array.from(eventMap.entries())
    .map(([date, events]) => ({
      date,
      event_count: events.length,
      has_course: events.some((item) => ["attendance", "lesson_log", "leave"].includes(item.event_type)),
      events: events.sort((a, b) => {
        const aTime = a.time?.start_time || "";
        const bTime = b.time?.start_time || "";
        return aTime.localeCompare(bTime);
      })
    }))
    .sort((a, b) => a.date.localeCompare(b.date));

  return {
    child: formatChildBase(child),
    month,
    total_days: days.length,
    days
  };
}

async function createChild(parentUserId, payload) {
  const child = await Child.create({
    parent_user_id: parentUserId,
    nickname: payload.nickname,
    avatar: payload.avatar || null,
    birthday: payload.birthday,
    gender: payload.gender ?? 0
  });

  return formatChild({
    ...child.toJSON(),
    balances: []
  });
}

async function updateChild(parentUserId, childId, payload) {
  const child = await Child.findOne({
    where: {
      child_id: childId,
      parent_user_id: parentUserId
    }
  });

  if (!child) {
    return null;
  }

  await child.update({
    nickname: payload.nickname ?? child.nickname,
    avatar: payload.avatar ?? child.avatar,
    birthday: payload.birthday ?? child.birthday,
    gender: payload.gender ?? child.gender
  });

  return getChildDetail(parentUserId, childId);
}

module.exports = {
  listChildren,
  getChildDetail,
  getChildGrowth,
  listChildPosts,
  listChildWorks,
  listChildLessonLogs,
  getChildCalendar,
  createChild,
  updateChild
};

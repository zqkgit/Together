-- 删除 AI 脚本批量造的种子数据（2026-09-28 09:50:49 同批）
-- 保留：兰亭书画（用户本人 09-24 自助操作）、platform_admin、tags、平台配置
-- 严格按外键「子表先于父表」顺序；单事务，失败整体回滚
START TRANSACTION;

-- 层级0：订单/排课/孩子的最末端子表
DELETE FROM payments            WHERE order_id IN ('1790560249151881028','1790560249162109114');
DELETE FROM refunds             WHERE order_id IN ('1790560249151881028','1790560249162109114');
DELETE FROM post_students       WHERE order_id IN ('1790560249151881028','1790560249162109114');
DELETE FROM order_items         WHERE order_id IN ('1790560249151881028','1790560249162109114');
DELETE FROM attendance          WHERE order_id IN ('1790560249151881028','1790560249162109114');
DELETE FROM lesson_logs         WHERE order_id IN ('1790560249151881028','1790560249162109114');
DELETE FROM child_course_balances WHERE order_id IN ('1790560249151881028','1790560249162109114');

-- 层级0：用户/账号的子表（通知、角色、token、申请、结算）
DELETE FROM notifications       WHERE user_id='1790560249097925243';
DELETE FROM user_roles          WHERE user_id IN ('1790560249067375015','1790560249097925243','1790560249099469134','1790560249109167412','1790560249110419191');
DELETE FROM refresh_tokens      WHERE user_id IN ('1790560249067375015','1790560249097925243','1790560249099469134','1790560249109167412','1790560249110419191');
DELETE FROM teacher_applications WHERE user_id='1790560249099469134' AND studio_id='1790560249103102124';
DELETE FROM studio_applications WHERE user_id='1790560249097925243';
DELETE FROM settlements         WHERE studio_id IN ('1790560249100996763','1790560249103102124');

-- 层级1：请假（引用 schedules/classes/children）
DELETE FROM leave_requests      WHERE class_id IN ('1790560249141587487','1790560249143814730');
-- 层级1：排课（引用 classes/courses/studios/teachers；自引用 makeup_from）
DELETE FROM schedules           WHERE studio_id IN ('1790560249100996763','1790560249103102124');
-- 层级1：订单（引用 packages/courses/children/studios/users）
DELETE FROM orders              WHERE order_id IN ('1790560249151881028','1790560249162109114');

-- 层级2：班级、课时包（leaves/schedules 已删；orders/items 已删）
DELETE FROM classes             WHERE class_id IN ('1790560249141587487','1790560249143814730');
DELETE FROM course_packages     WHERE course_id IN ('1790560249129733596','1790560249131664292','1790560249132979293');

-- 层级3：帖子、课程（post_students 已删；packages/classes 等已删）
DELETE FROM posts               WHERE author_id IN ('1790560249067375015','1790560249097925243','1790560249099469134','1790560249109167412','1790560249110419191');
DELETE FROM courses             WHERE course_id IN ('1790560249129733596','1790560249131664292','1790560249132979293');

-- 层级4：孩子、老师（其所有子表已删）
DELETE FROM children            WHERE child_id='1790560249091158232';
DELETE FROM teacher_profiles    WHERE teacher_id IN ('1790560249112557887','1790560249113590983');

-- 层级5：后台账号、工作室（settlements/admin 子表已删）
DELETE FROM admin_accounts      WHERE studio_id IN ('1790560249100996763','1790560249103102124');
DELETE FROM studio_profiles     WHERE studio_id IN ('1790560249100996763','1790560249103102124');

-- 层级6：用户（所有引用方已删）
DELETE FROM users               WHERE user_id IN ('1790560249067375015','1790560249097925243','1790560249099469134','1790560249109167412','1790560249110419191');

-- 校准保留班级 enrolled = 有效账本去重孩子数（status 1在读 / 2冻结）
UPDATE classes cl
   SET enrolled = (
     SELECT COUNT(DISTINCT b.child_id)
       FROM child_course_balances b
      WHERE b.class_id = cl.class_id AND b.status IN (1,2)
   );

COMMIT;

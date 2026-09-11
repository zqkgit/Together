SET NAMES utf8mb4;
INSERT INTO reports (report_id, reporter_id, target_type, target_id, reason, detail, status) VALUES (9000000000000000002, 1789012617377972192, 'post', '1789106205520196485', '不实宣传', '课程介绍与实际上课内容不符', 0);
INSERT INTO announcements (announcement_id, title, content, type, image, status, publish_at) VALUES ('1789120000000000001', '秋季课程上新', '新一季美术课程已上线，欢迎家长预约体验课。', 1, '[]', 1, NOW());
INSERT INTO studio_accounts (account_id, studio_id, account_type, account_name, account_no, bank_name, is_default, status) VALUES ('1789120000000000002', '1789012617401550727', 'bank', '木色少儿美术', '6222020200112233445', '工商银行', 1, 1);

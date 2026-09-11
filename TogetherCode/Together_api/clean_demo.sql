SET FOREIGN_KEY_CHECKS=0;
DELETE FROM reports WHERE report_id='9000000000000000002';
DELETE FROM announcements WHERE announcement_id='1789120000000000001';
DELETE FROM platform_configs WHERE config_key='commission_rate_limit';
DELETE FROM studio_accounts WHERE account_id='1789120000000000002';
DELETE FROM refresh_tokens WHERE user_id IN (SELECT user_id FROM admin_accounts WHERE username='studio_ops_demo');
DELETE FROM admin_accounts WHERE username='studio_ops_demo';
DELETE FROM audit_logs;
SET FOREIGN_KEY_CHECKS=1;

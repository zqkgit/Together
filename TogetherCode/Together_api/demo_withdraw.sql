SET NAMES utf8mb4;
UPDATE wallets SET balance = balance - 80, frozen = frozen + 80 WHERE user_id = 1789012617377972192;
INSERT INTO withdrawals (withdraw_id, user_id, amount, method, account, status) VALUES (9000000000000000011, 1789012617377972192, 50.00, 'wechat', 'wx_share_demo', 1);
INSERT INTO withdrawals (withdraw_id, user_id, amount, method, account, status) VALUES (9000000000000000012, 1789012617377972192, 30.00, 'alipay', 'demo@alipay.com', 1);

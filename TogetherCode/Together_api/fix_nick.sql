SET NAMES utf8mb4;
UPDATE users SET nickname = '演示家长' WHERE user_id = '1789012617377972192';
SELECT HEX(nickname) FROM users WHERE user_id = '1789012617377972192';

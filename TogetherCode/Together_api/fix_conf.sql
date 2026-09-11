SET NAMES utf8mb4;
UPDATE platform_configs SET description = '分销比例上限（百分比）' WHERE config_key = 'commission_rate_limit';
SELECT config_key, HEX(description) FROM platform_configs;

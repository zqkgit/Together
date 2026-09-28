-- MySQL dump 10.13  Distrib 8.4.11, for Linux (aarch64)
--
-- Host: localhost    Database: together
-- ------------------------------------------------------
-- Server version	8.4.11

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `SequelizeMeta`
--

DROP TABLE IF EXISTS `SequelizeMeta`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `SequelizeMeta` (
  `name` varchar(255) COLLATE utf8mb3_unicode_ci NOT NULL,
  PRIMARY KEY (`name`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `SequelizeMeta`
--

LOCK TABLES `SequelizeMeta` WRITE;
/*!40000 ALTER TABLE `SequelizeMeta` DISABLE KEYS */;
INSERT INTO `SequelizeMeta` VALUES ('20260910120000-init-auth-admin-core.js'),('20260910143000-add-course-domain.js'),('20260910180000-add-transaction-domain.js'),('20260910193000-add-schedule-domain.js'),('20260910203000-add-attendance-domain.js'),('20260910213000-add-leave-domain.js'),('20260910230000-add-post-domain.js'),('20260910235900-create-tags.js'),('20260911001000-create-teacher-studio-bindings.js'),('20260911090000-create-post-interactions.js'),('20260911100000-create-messaging.js'),('20260911101000-create-user-devices.js'),('20260911120000-create-distribution.js'),('20260911130000-create-admin-governance.js'),('20260911150000-create-reviews-favorites.js'),('20260914100000-add-topic-to-posts.js'),('20260914101000-seed-post-topics.js'),('20260914110000-create-user-follows.js'),('20260914120000-create-comment-likes.js'),('20260914130000-add-comment-parent.js'),('20260915090000-create-topics.js'),('20260916160000-add-course-intro.js'),('20260916170000-make-order-package-nullable.js'),('20260916171000-make-order-item-package-name-nullable.js'),('20260916180000-add-class-id-to-orders.js'),('20260918_add-review-audit-fields.js'),('20260920_add-teacher-review-reply.js'),('20260920120000-add-studio-auth-fields.js'),('20260920170000-add-post-location.js'),('20260921100000-add-studio-business-tags.js');
/*!40000 ALTER TABLE `SequelizeMeta` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `admin_accounts`
--

DROP TABLE IF EXISTS `admin_accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `admin_accounts` (
  `admin_id` bigint NOT NULL,
  `user_id` bigint DEFAULT NULL,
  `username` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `password_hash` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `role` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `studio_id` bigint DEFAULT NULL,
  `status` smallint NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`admin_id`),
  UNIQUE KEY `username` (`username`),
  KEY `user_id` (`user_id`),
  KEY `studio_id` (`studio_id`),
  CONSTRAINT `admin_accounts_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `admin_accounts_ibfk_2` FOREIGN KEY (`studio_id`) REFERENCES `studio_profiles` (`studio_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `admin_accounts`
--

LOCK TABLES `admin_accounts` WRITE;
/*!40000 ALTER TABLE `admin_accounts` DISABLE KEYS */;
INSERT INTO `admin_accounts` VALUES (1789012617392230845,1789012617389540630,'platform_admin','$2a$10$a5WoOT0CWZnVakupncytG.Ij30u.74Z4LTuWgF.Ndr0FtlZ0mLEVS','platform_super',NULL,1,'2026-09-10 11:56:57','2026-09-10 11:56:57'),(1790214661974489202,1790214033967587427,'18234126896','$2a$10$yE/SwURIu9i3Pp4jFywKAu6T2YITlBAAEI.ihw77fygSFVBk16rMe','studio_owner',1790214661961110965,1,'2026-09-24 09:51:02','2026-09-24 09:51:02'),(1790560249118203683,1790560249097925243,'studio_owner_1','$2a$10$79sjQoe.FE/JP2JQNxq4J.6yfSkSAP.8xFe8jHGTFZvg3gxvmzFDC','studio_owner',1790560249100996763,1,'2026-09-28 09:50:49','2026-09-28 09:50:49');
/*!40000 ALTER TABLE `admin_accounts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `announcements`
--

DROP TABLE IF EXISTS `announcements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `announcements` (
  `announcement_id` bigint NOT NULL,
  `title` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` text COLLATE utf8mb4_unicode_ci,
  `type` smallint NOT NULL DEFAULT '1',
  `image` json DEFAULT NULL,
  `link` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` smallint NOT NULL DEFAULT '1',
  `publish_at` datetime DEFAULT NULL,
  `expire_at` datetime DEFAULT NULL,
  `created_by` bigint DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`announcement_id`),
  KEY `announcements_status_type_publish_at` (`status`,`type`,`publish_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `announcements`
--

LOCK TABLES `announcements` WRITE;
/*!40000 ALTER TABLE `announcements` DISABLE KEYS */;
/*!40000 ALTER TABLE `announcements` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `attendance`
--

DROP TABLE IF EXISTS `attendance`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `attendance` (
  `attendance_id` bigint NOT NULL,
  `schedule_id` bigint NOT NULL,
  `child_id` bigint NOT NULL,
  `order_id` bigint NOT NULL,
  `status` smallint NOT NULL,
  `note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`attendance_id`),
  UNIQUE KEY `uniq_attendance_schedule_child` (`schedule_id`,`child_id`),
  KEY `child_id` (`child_id`),
  KEY `order_id` (`order_id`),
  KEY `idx_attendance_schedule_status` (`schedule_id`,`status`),
  CONSTRAINT `attendance_ibfk_1` FOREIGN KEY (`schedule_id`) REFERENCES `schedules` (`schedule_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `attendance_ibfk_2` FOREIGN KEY (`child_id`) REFERENCES `children` (`child_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `attendance_ibfk_3` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `attendance`
--

LOCK TABLES `attendance` WRITE;
/*!40000 ALTER TABLE `attendance` DISABLE KEYS */;
/*!40000 ALTER TABLE `attendance` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `audit_logs`
--

DROP TABLE IF EXISTS `audit_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `audit_logs` (
  `log_id` bigint NOT NULL,
  `actor_id` bigint DEFAULT NULL,
  `actor_name` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `role` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `studio_id` bigint DEFAULT NULL,
  `action` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_type` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `target_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `detail` text COLLATE utf8mb4_unicode_ci,
  `ip` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`log_id`),
  KEY `audit_logs_role_studio_id_action_created_at` (`role`,`studio_id`,`action`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `audit_logs`
--

LOCK TABLES `audit_logs` WRITE;
/*!40000 ALTER TABLE `audit_logs` DISABLE KEYS */;
INSERT INTO `audit_logs` VALUES (1790214289615905354,1789012617392230845,'platform_admin','platform_super',NULL,'teacher_application.reject',NULL,NULL,'{\"reason\":\"999\"}',NULL,'2026-09-24 09:44:49'),(1790214326727127345,1789012617392230845,'platform_admin','platform_super',NULL,'teacher_application.approve',NULL,NULL,'{\"reason\":\"OK\"}',NULL,'2026-09-24 09:45:26'),(1790215135247571129,1789012617392230845,'platform_admin','platform_super',NULL,'teacher_application.approve',NULL,NULL,'{\"reason\":\"OK\"}',NULL,'2026-09-24 09:58:55');
/*!40000 ALTER TABLE `audit_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `auth_verification_codes`
--

DROP TABLE IF EXISTS `auth_verification_codes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `auth_verification_codes` (
  `id` bigint NOT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `code` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
  `purpose` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'login',
  `expires_at` datetime NOT NULL,
  `consumed_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_auth_code_phone_purpose_created` (`phone`,`purpose`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `auth_verification_codes`
--

LOCK TABLES `auth_verification_codes` WRITE;
/*!40000 ALTER TABLE `auth_verification_codes` DISABLE KEYS */;
INSERT INTO `auth_verification_codes` VALUES (1790214030198269155,'18234126896','1234','register','2026-09-24 09:45:30','2026-09-24 09:40:33','2026-09-24 09:40:30','2026-09-24 09:40:33'),(1790214935464728067,'18234102443','1234','register','2026-09-24 10:00:35',NULL,'2026-09-24 09:55:35','2026-09-24 09:55:35'),(1790214997808984127,'19135626896','1234','register','2026-09-24 10:01:37','2026-09-24 09:56:41','2026-09-24 09:56:37','2026-09-24 09:56:41'),(1790215170983496752,'19135626896','1234','login','2026-09-24 10:04:30','2026-09-24 09:59:35','2026-09-24 09:59:30','2026-09-24 09:59:35'),(1790215193445924226,'18234126896','1234','login','2026-09-24 10:04:53','2026-09-24 10:00:01','2026-09-24 09:59:53','2026-09-24 10:00:01'),(1790235747053590009,'19135626896','1234','login','2026-09-24 15:47:27','2026-09-24 15:42:31','2026-09-24 15:42:27','2026-09-24 15:42:31'),(1790235809241244805,'18234126896','1234','login','2026-09-24 15:48:29','2026-09-24 15:43:34','2026-09-24 15:43:29','2026-09-24 15:43:34'),(1790560966829188476,'18234126896','1234','login','2026-09-28 10:07:46','2026-09-28 10:02:54','2026-09-28 10:02:46','2026-09-28 10:02:54');
/*!40000 ALTER TABLE `auth_verification_codes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `child_course_balances`
--

DROP TABLE IF EXISTS `child_course_balances`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `child_course_balances` (
  `balance_id` bigint NOT NULL,
  `child_id` bigint NOT NULL,
  `course_id` bigint NOT NULL,
  `order_id` bigint NOT NULL,
  `total_lessons` smallint NOT NULL,
  `consumed_lessons` smallint NOT NULL DEFAULT '0',
  `refunded_lessons` smallint NOT NULL DEFAULT '0',
  `remaining_lessons` smallint NOT NULL,
  `valid_from` date NOT NULL,
  `valid_to` date DEFAULT NULL,
  `status` smallint NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `class_id` bigint DEFAULT NULL,
  PRIMARY KEY (`balance_id`),
  UNIQUE KEY `order_id` (`order_id`),
  KEY `course_id` (`course_id`),
  KEY `idx_child_course_balance_lookup` (`child_id`,`course_id`,`status`),
  KEY `child_course_balances_class_id` (`class_id`),
  CONSTRAINT `child_course_balances_ibfk_1` FOREIGN KEY (`child_id`) REFERENCES `children` (`child_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `child_course_balances_ibfk_2` FOREIGN KEY (`course_id`) REFERENCES `courses` (`course_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `child_course_balances_ibfk_3` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `child_course_balances`
--

LOCK TABLES `child_course_balances` WRITE;
/*!40000 ALTER TABLE `child_course_balances` DISABLE KEYS */;
INSERT INTO `child_course_balances` VALUES (1790232222202500073,1790214102352119762,1790215643620388977,1790232199208213617,10,0,10,0,'2026-09-24','2027-03-23',4,'2026-09-24 14:43:42','2026-09-24 15:06:51',1790215848474966381),(1790233645337884370,1790214102352119762,1790215643620388977,1790233628188457446,10,1,0,9,'2026-09-24','2027-03-23',1,'2026-09-24 15:07:25','2026-09-24 16:36:01',1790215848474966381),(1790560249157871900,1790560249091158232,1790560249129733596,1790560249151881028,12,0,0,12,'2026-09-28',NULL,1,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL),(1790560249166546995,1790560249091158232,1790560249131664292,1790560249162109114,8,0,2,6,'2026-09-28',NULL,1,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL);
/*!40000 ALTER TABLE `child_course_balances` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `children`
--

DROP TABLE IF EXISTS `children`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `children` (
  `child_id` bigint NOT NULL,
  `parent_user_id` bigint NOT NULL,
  `nickname` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `avatar` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `birthday` date NOT NULL,
  `gender` smallint NOT NULL DEFAULT '0',
  `interests` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'å…´è¶£æ ‡ç­¾,é€—å·åˆ†éš”',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`child_id`),
  KEY `parent_user_id` (`parent_user_id`),
  CONSTRAINT `children_ibfk_1` FOREIGN KEY (`parent_user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `children`
--

LOCK TABLES `children` WRITE;
/*!40000 ALTER TABLE `children` DISABLE KEYS */;
INSERT INTO `children` VALUES (1790214084899387524,1790214033967587427,'小周','🌻','2018-01-01',2,'水彩,黏土,素描,国画,儿童画,书法','2026-09-24 09:41:24','2026-09-24 09:41:24'),(1790214102352119762,1790214033967587427,'小周周','🌻','2019-01-01',1,'素描,国画,书法,儿童画,黏土,水彩','2026-09-24 09:41:42','2026-09-24 09:41:42'),(1790560249091158232,1790560249067375015,'可可',NULL,'2019-05-18',2,NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49');
/*!40000 ALTER TABLE `children` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `classes`
--

DROP TABLE IF EXISTS `classes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `classes` (
  `class_id` bigint NOT NULL,
  `course_id` bigint NOT NULL,
  `teacher_id` bigint DEFAULT NULL,
  `name` varchar(60) COLLATE utf8mb4_unicode_ci NOT NULL,
  `schedule_rule` json DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `end_date` date DEFAULT NULL,
  `capacity` smallint NOT NULL DEFAULT '12',
  `enrolled` smallint NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`class_id`),
  KEY `course_id` (`course_id`),
  KEY `teacher_id` (`teacher_id`),
  CONSTRAINT `classes_ibfk_1` FOREIGN KEY (`course_id`) REFERENCES `courses` (`course_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `classes_ibfk_2` FOREIGN KEY (`teacher_id`) REFERENCES `teacher_profiles` (`teacher_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `classes`
--

LOCK TABLES `classes` WRITE;
/*!40000 ALTER TABLE `classes` DISABLE KEYS */;
INSERT INTO `classes` VALUES (1790215848474966381,1790215643620388977,1790214326711337702,'创意绘画苹果班','{\"time\": \"18:30-20:00\", \"weekday\": []}',NULL,NULL,12,4,'2026-09-24 10:10:48','2026-09-24 15:48:20'),(1790560249141587487,1790560249129733596,1790560249112557887,'周二晚班','{\"time\": \"18:30-20:00\", \"weekday\": [2]}','2026-09-16','2026-12-16',10,8,'2026-09-28 09:50:49','2026-09-28 09:50:49'),(1790560249143814730,1790560249131664292,1790560249113590983,'周六上午班','{\"time\": \"10:00-12:00\", \"weekday\": [6]}','2026-09-20','2026-11-15',12,9,'2026-09-28 09:50:49','2026-09-28 09:50:49');
/*!40000 ALTER TABLE `classes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `commission_records`
--

DROP TABLE IF EXISTS `commission_records`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `commission_records` (
  `commission_id` bigint NOT NULL,
  `link_id` bigint NOT NULL,
  `order_id` bigint NOT NULL,
  `parent_user_id` bigint NOT NULL,
  `studio_id` bigint DEFAULT NULL,
  `withdrawal_id` bigint DEFAULT NULL,
  `rate` decimal(5,2) NOT NULL DEFAULT '0.00',
  `amount` decimal(10,2) NOT NULL DEFAULT '0.00',
  `status` tinyint NOT NULL DEFAULT '1' COMMENT '1待结算 2已到账',
  `settle_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`commission_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `commission_records`
--

LOCK TABLES `commission_records` WRITE;
/*!40000 ALTER TABLE `commission_records` DISABLE KEYS */;
/*!40000 ALTER TABLE `commission_records` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `conversation_messages`
--

DROP TABLE IF EXISTS `conversation_messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `conversation_messages` (
  `message_id` bigint NOT NULL,
  `conversation_id` bigint NOT NULL,
  `sender_id` bigint NOT NULL,
  `type` smallint NOT NULL DEFAULT '1' COMMENT '1 文本 / 2 图片',
  `content` varchar(2000) COLLATE utf8mb4_unicode_ci NOT NULL,
  `read_at` datetime DEFAULT NULL,
  `status` smallint NOT NULL DEFAULT '1' COMMENT '1 正常 / 0 撤回',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`message_id`),
  KEY `idx_conv_messages` (`conversation_id`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `conversation_messages`
--

LOCK TABLES `conversation_messages` WRITE;
/*!40000 ALTER TABLE `conversation_messages` DISABLE KEYS */;
/*!40000 ALTER TABLE `conversation_messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `conversations`
--

DROP TABLE IF EXISTS `conversations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `conversations` (
  `conversation_id` bigint NOT NULL,
  `peer_a` bigint NOT NULL COMMENT '参与方A（约定 user_id 小者在前，防重复会话）',
  `peer_b` bigint NOT NULL COMMENT '参与方B',
  `child_id` bigint DEFAULT NULL COMMENT '家校会话可选关联孩子',
  `last_message_id` bigint DEFAULT NULL,
  `unread_a` int NOT NULL DEFAULT '0',
  `unread_b` int NOT NULL DEFAULT '0',
  `status` smallint NOT NULL DEFAULT '1' COMMENT '1 正常 / 0 关闭',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`conversation_id`),
  KEY `idx_conversations_peers` (`peer_a`,`peer_b`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `conversations`
--

LOCK TABLES `conversations` WRITE;
/*!40000 ALTER TABLE `conversations` DISABLE KEYS */;
/*!40000 ALTER TABLE `conversations` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `course_lessons`
--

DROP TABLE IF EXISTS `course_lessons`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `course_lessons` (
  `lesson_id` bigint NOT NULL,
  `course_id` bigint NOT NULL,
  `lesson_no` int NOT NULL,
  `title` varchar(120) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`lesson_id`),
  KEY `idx_course` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `course_lessons`
--

LOCK TABLES `course_lessons` WRITE;
/*!40000 ALTER TABLE `course_lessons` DISABLE KEYS */;
INSERT INTO `course_lessons` VALUES (1790231803736157847,1790215643620388977,3,'形状变变变——几何小动物','2026-09-24 14:36:43'),(1790231803736158799,1790215643620388977,5,'手工拼贴——梦幻海底世界','2026-09-24 14:36:43'),(1790231803736207993,1790215643620388977,10,'综合创作——我的快乐童年','2026-09-24 14:36:43'),(1790231803736238757,1790215643620388977,1,'线条魔法——会跳舞的小线条','2026-09-24 14:36:43'),(1790231803736383890,1790215643620388977,4,'肌理创意——指尖树叶森林','2026-09-24 14:36:43'),(1790231803736462672,1790215643620388977,6,'想象创意——会飞的房子','2026-09-24 14:36:43'),(1790231803736623360,1790215643620388977,2,'色彩初识——彩虹小花园','2026-09-24 14:36:43'),(1790231803736641031,1790215643620388977,7,'动物拟人——小动物的一天','2026-09-24 14:36:43'),(1790231803736728728,1790215643620388977,9,'立体创意——纸杯立体小花园','2026-09-24 14:36:43'),(1790231803736787713,1790215643620388977,8,'色彩渐变——星空之夜','2026-09-24 14:36:43');
/*!40000 ALTER TABLE `course_lessons` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `course_packages`
--

DROP TABLE IF EXISTS `course_packages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `course_packages` (
  `package_id` bigint NOT NULL,
  `course_id` bigint NOT NULL,
  `name` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `lessons` smallint NOT NULL,
  `price` int NOT NULL,
  `original_price` int DEFAULT NULL,
  `status` smallint NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`package_id`),
  KEY `course_id` (`course_id`),
  CONSTRAINT `course_packages_ibfk_1` FOREIGN KEY (`course_id`) REFERENCES `courses` (`course_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `course_packages`
--

LOCK TABLES `course_packages` WRITE;
/*!40000 ALTER TABLE `course_packages` DISABLE KEYS */;
INSERT INTO `course_packages` VALUES (1790560249134139935,1790560249129733596,'12 课时包',12,168000,188000,1,'2026-09-28 09:50:49','2026-09-28 09:50:49'),(1790560249136578556,1790560249129733596,'24 课时包',24,318000,376000,1,'2026-09-28 09:50:49','2026-09-28 09:50:49'),(1790560249137151639,1790560249131664292,'8 课时包',8,236000,256000,1,'2026-09-28 09:50:49','2026-09-28 09:50:49'),(1790560249138552405,1790560249132979293,'6 课时体验包',6,98000,108000,1,'2026-09-28 09:50:49','2026-09-28 09:50:49');
/*!40000 ALTER TABLE `course_packages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `course_reviews`
--

DROP TABLE IF EXISTS `course_reviews`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `course_reviews` (
  `review_id` bigint NOT NULL,
  `course_id` bigint NOT NULL,
  `teacher_id` bigint DEFAULT NULL,
  `studio_id` bigint DEFAULT NULL,
  `user_id` bigint NOT NULL,
  `order_id` bigint DEFAULT NULL,
  `child_id` bigint DEFAULT NULL,
  `rating` smallint NOT NULL DEFAULT '5',
  `content` text COLLATE utf8mb4_unicode_ci,
  `images` json DEFAULT NULL,
  `status` smallint NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reply_content` text COLLATE utf8mb4_unicode_ci,
  `reply_at` datetime DEFAULT NULL,
  `reject_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `teacher_reply_content` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '老师回复内容',
  `teacher_reply_at` datetime DEFAULT NULL COMMENT '老师回复时间',
  PRIMARY KEY (`review_id`),
  UNIQUE KEY `course_reviews_course_id_user_id` (`course_id`,`user_id`),
  KEY `course_reviews_course_id` (`course_id`),
  KEY `course_reviews_user_id` (`user_id`),
  KEY `course_reviews_studio_id` (`studio_id`),
  KEY `course_reviews_teacher_id` (`teacher_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `course_reviews`
--

LOCK TABLES `course_reviews` WRITE;
/*!40000 ALTER TABLE `course_reviews` DISABLE KEYS */;
/*!40000 ALTER TABLE `course_reviews` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `courses`
--

DROP TABLE IF EXISTS `courses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `courses` (
  `course_id` bigint NOT NULL,
  `studio_id` bigint NOT NULL,
  `teacher_id` bigint DEFAULT NULL,
  `title` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cover` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `category` smallint NOT NULL,
  `age_min` smallint DEFAULT NULL,
  `age_max` smallint DEFAULT NULL,
  `total_lessons` smallint NOT NULL,
  `duration_min` smallint NOT NULL,
  `price` int NOT NULL,
  `class_size` smallint NOT NULL DEFAULT '12',
  `rating` decimal(2,1) NOT NULL DEFAULT '5.0',
  `sales` int NOT NULL DEFAULT '0',
  `distribute_rate` decimal(4,2) NOT NULL DEFAULT '0.08',
  `validity_days` smallint DEFAULT NULL,
  `status` smallint NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `intro` text COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (`course_id`),
  KEY `teacher_id` (`teacher_id`),
  KEY `idx_courses_studio_status` (`studio_id`,`status`),
  KEY `idx_courses_category_status` (`category`,`status`),
  CONSTRAINT `courses_ibfk_1` FOREIGN KEY (`studio_id`) REFERENCES `studio_profiles` (`studio_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `courses_ibfk_2` FOREIGN KEY (`teacher_id`) REFERENCES `teacher_profiles` (`teacher_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `courses`
--

LOCK TABLES `courses` WRITE;
/*!40000 ALTER TABLE `courses` DISABLE KEYS */;
INSERT INTO `courses` VALUES (1790215643620388977,1790214661961110965,NULL,'创意绘画',NULL,1,3,12,10,90,2880,8,5.0,0,0.10,180,1,'2026-09-24 10:07:23','2026-09-24 14:36:43',NULL),(1790560249129733596,1790560249100996763,1790560249112557887,'创意启蒙绘画班','https://example.com/course-creative-art.jpg',1,4,6,12,90,168000,10,4.9,128,0.08,180,1,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL),(1790560249131664292,1790560249103102124,1790560249113590983,'综合材料创作营','https://example.com/course-mixed-media.jpg',2,7,10,8,120,236000,12,4.8,76,0.10,120,1,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL),(1790560249132979293,1790560249100996763,1790560249112557887,'周末亲子手作课','https://example.com/course-parent-kids.jpg',3,5,8,6,90,98000,8,4.7,42,0.08,90,0,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL);
/*!40000 ALTER TABLE `courses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `distribution_links`
--

DROP TABLE IF EXISTS `distribution_links`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `distribution_links` (
  `link_id` bigint NOT NULL,
  `parent_user_id` bigint NOT NULL,
  `course_id` bigint NOT NULL,
  `post_id` bigint DEFAULT NULL,
  `code` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` tinyint NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`link_id`),
  UNIQUE KEY `code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `distribution_links`
--

LOCK TABLES `distribution_links` WRITE;
/*!40000 ALTER TABLE `distribution_links` DISABLE KEYS */;
/*!40000 ALTER TABLE `distribution_links` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `favorites`
--

DROP TABLE IF EXISTS `favorites`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `favorites` (
  `favorite_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `target_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_id` bigint NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`favorite_id`),
  UNIQUE KEY `favorites_user_id_target_type_target_id` (`user_id`,`target_type`,`target_id`),
  KEY `favorites_user_id_target_type` (`user_id`,`target_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `favorites`
--

LOCK TABLES `favorites` WRITE;
/*!40000 ALTER TABLE `favorites` DISABLE KEYS */;
/*!40000 ALTER TABLE `favorites` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `leave_requests`
--

DROP TABLE IF EXISTS `leave_requests`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `leave_requests` (
  `leave_id` bigint NOT NULL,
  `class_id` bigint NOT NULL,
  `child_id` bigint NOT NULL,
  `parent_user_id` bigint NOT NULL,
  `schedule_id` bigint DEFAULT NULL,
  `reason` varchar(200) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` smallint NOT NULL DEFAULT '0',
  `handled_at` datetime DEFAULT NULL,
  `makeup_status` smallint NOT NULL DEFAULT '0',
  `makeup_schedule_id` bigint DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`leave_id`),
  KEY `child_id` (`child_id`),
  KEY `makeup_schedule_id` (`makeup_schedule_id`),
  KEY `idx_leave_requests_parent_status` (`parent_user_id`,`status`),
  KEY `idx_leave_requests_class_status` (`class_id`,`status`),
  KEY `idx_leave_requests_schedule_child` (`schedule_id`,`child_id`),
  CONSTRAINT `leave_requests_ibfk_1` FOREIGN KEY (`class_id`) REFERENCES `classes` (`class_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `leave_requests_ibfk_2` FOREIGN KEY (`child_id`) REFERENCES `children` (`child_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `leave_requests_ibfk_3` FOREIGN KEY (`parent_user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `leave_requests_ibfk_4` FOREIGN KEY (`schedule_id`) REFERENCES `schedules` (`schedule_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `leave_requests_ibfk_5` FOREIGN KEY (`makeup_schedule_id`) REFERENCES `schedules` (`schedule_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `leave_requests`
--

LOCK TABLES `leave_requests` WRITE;
/*!40000 ALTER TABLE `leave_requests` DISABLE KEYS */;
INSERT INTO `leave_requests` VALUES (1790239066745822425,1790215848474966381,1790214102352119762,1790214033967587427,NULL,'有事',2,'2026-09-24 16:38:42',2,NULL,'2026-09-24 16:37:46','2026-09-24 16:38:42'),(1790239327250210037,1790215848474966381,1790214102352119762,1790214033967587427,NULL,'请假',1,'2026-09-24 16:43:06',2,NULL,'2026-09-24 16:42:07','2026-09-24 16:56:48'),(1790240415536337212,1790215848474966381,1790214102352119762,1790214033967587427,NULL,'请假',1,'2026-09-24 17:00:37',0,NULL,'2026-09-24 17:00:15','2026-09-24 17:01:06');
/*!40000 ALTER TABLE `leave_requests` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `lesson_logs`
--

DROP TABLE IF EXISTS `lesson_logs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `lesson_logs` (
  `log_id` bigint NOT NULL,
  `child_id` bigint NOT NULL,
  `course_id` bigint NOT NULL,
  `order_id` bigint NOT NULL,
  `source` smallint NOT NULL,
  `type` smallint NOT NULL,
  `delta` smallint NOT NULL,
  `balance_after` smallint NOT NULL,
  `note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `schedule_id` bigint DEFAULT NULL,
  `post_id` bigint DEFAULT NULL,
  PRIMARY KEY (`log_id`),
  KEY `course_id` (`course_id`),
  KEY `order_id` (`order_id`),
  KEY `idx_lesson_logs_child_course_created` (`child_id`,`course_id`,`created_at`),
  KEY `idx_lesson_logs_schedule_child_created` (`schedule_id`,`child_id`,`created_at`),
  KEY `idx_lesson_logs_post_child_created` (`post_id`,`child_id`,`created_at`),
  CONSTRAINT `lesson_logs_ibfk_1` FOREIGN KEY (`child_id`) REFERENCES `children` (`child_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `lesson_logs_ibfk_2` FOREIGN KEY (`course_id`) REFERENCES `courses` (`course_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `lesson_logs_ibfk_3` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `lesson_logs_schedule_id_foreign_idx` FOREIGN KEY (`schedule_id`) REFERENCES `schedules` (`schedule_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `lesson_logs`
--

LOCK TABLES `lesson_logs` WRITE;
/*!40000 ALTER TABLE `lesson_logs` DISABLE KEYS */;
INSERT INTO `lesson_logs` VALUES (1790232222205165806,1790214102352119762,1790215643620388977,1790232199208213617,0,1,10,10,'工作室确认收款，课时到账','2026-09-24 14:43:42',NULL,NULL),(1790233611363610984,1790214102352119762,1790215643620388977,1790232199208213617,4,3,-10,0,'家长确认收到退款，扣减剩余课时','2026-09-24 15:06:51',NULL,NULL),(1790233645343216091,1790214102352119762,1790215643620388977,1790233628188457446,0,1,10,10,'工作室确认收款，课时到账','2026-09-24 15:07:25',NULL,NULL),(1790238961837941724,1790214102352119762,1790215643620388977,1790233628188457446,2,1,-1,9,'按排课出勤消课','2026-09-24 16:36:01',NULL,NULL),(1790560249160644617,1790560249091158232,1790560249129733596,1790560249151881028,0,1,12,12,'订单支付成功，课时到账','2026-09-28 09:50:49',NULL,NULL),(1790560249168666550,1790560249091158232,1790560249131664292,1790560249162109114,0,1,8,8,'订单支付成功，课时到账','2026-09-28 09:50:49',NULL,NULL),(1790560249171884993,1790560249091158232,1790560249131664292,1790560249162109114,4,3,-2,6,'订单退款扣减剩余课时','2026-09-28 09:50:49',NULL,NULL);
/*!40000 ALTER TABLE `lesson_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `notifications`
--

DROP TABLE IF EXISTS `notifications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `notifications` (
  `notification_id` bigint NOT NULL,
  `user_id` bigint NOT NULL COMMENT '接收方',
  `type` varchar(30) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'leave/refund/like/comment/consume/system',
  `title` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `content` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ref_type` varchar(30) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ref_id` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_read` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`notification_id`),
  KEY `idx_notifications_user_read` (`user_id`,`is_read`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `notifications`
--

LOCK TABLES `notifications` WRITE;
/*!40000 ALTER TABLE `notifications` DISABLE KEYS */;
INSERT INTO `notifications` VALUES (1790214289595631883,1790214033967587427,'cert','老师认证未通过','你的老师认证申请未通过：999','cert','1790214256818829835',1,'2026-09-24 09:44:49','2026-09-24 09:45:35'),(1790214326721622409,1790214033967587427,'cert','老师认证已通过','恭喜，你的老师认证已通过（周钦凯），现在可以向工作室申请合作了。','cert','1790214305456364052',1,'2026-09-24 09:45:26','2026-09-24 09:45:34'),(1790214561762217665,1790214033967587427,'cert','工作室认证未通过','「兰亭书画」认证申请未通过：驳回','cert','1790214526343655439',0,'2026-09-24 09:49:21','2026-09-24 09:49:21'),(1790214662044206689,1790214033967587427,'cert','工作室认证已通过','恭喜，「兰亭书画」认证已通过，现在可以开展课程与招生了。 Web 管理后台已开通：使用手机号 18234126896 登录「工作室后台」，初始密码 123456，请尽快修改。','cert','1790214574940347630',0,'2026-09-24 09:51:02','2026-09-24 09:51:02'),(1790214787529910242,1790214033967587427,'invite','工作室邀请你合作','你已被「兰亭书画」邀请为合作老师','studio','1790214661961110965',0,'2026-09-24 09:53:07','2026-09-24 09:53:07'),(1790214808290281322,1790214033967587427,'invite','工作室邀请你合作','你已被「兰亭书画」邀请为合作老师','studio','1790214661961110965',0,'2026-09-24 09:53:28','2026-09-24 09:53:28'),(1790215135243123787,1790215001732915922,'cert','老师认证已通过','恭喜，你的老师认证已通过（周末），现在可以向工作室申请合作了。','cert','1790215111514207129',0,'2026-09-24 09:58:55','2026-09-24 09:58:55'),(1790215219761255279,1790215001732915922,'invite','工作室邀请你合作','你已被「兰亭书画」邀请为合作老师','studio','1790214661961110965',0,'2026-09-24 10:00:19','2026-09-24 10:00:19'),(1790216173898784981,1790214033967587427,'order','新的付款凭证待核对','家长已提交「创意绘画」的微信转账付款凭证，请核对到账后确认收款。','order','1790216118354133074',0,'2026-09-24 10:16:13','2026-09-24 10:16:13'),(1790219443143721601,1790214033967587427,'order','付款凭证未通过核对','「创意绘画」的付款凭证未通过核对：驳回一下，请重新付款或上传凭证。','order','1790216118354133074',0,'2026-09-24 11:10:43','2026-09-24 11:10:43'),(1790219938323472323,1790214033967587427,'order','新的付款凭证待核对','家长已提交「创意绘画」的微信转账付款凭证，请核对到账后确认收款。','order','1790219882716151347',0,'2026-09-24 11:18:58','2026-09-24 11:18:58'),(1790219969978128191,1790214033967587427,'order','付款凭证未通过核对','「创意绘画」的付款凭证未通过核对：截图不清晰，请重新付款或上传凭证。','order','1790219882716151347',0,'2026-09-24 11:19:29','2026-09-24 11:19:29'),(1790220080849317212,1790214033967587427,'order','新的付款凭证待核对','家长已提交「创意绘画」的微信转账付款凭证，请核对到账后确认收款。','order','1790219882716151347',0,'2026-09-24 11:21:20','2026-09-24 11:21:20'),(1790220107469115463,1790214033967587427,'order','收款已确认，课时到账','《创意绘画》10 课时已到账，可在「我的订单」查看。','order','1790219882716151347',0,'2026-09-24 11:21:47','2026-09-24 11:21:47'),(1790220270548536434,1790214033967587427,'refund','退款已退回，待你确认','「创意绘画」退款 ¥28.80 已审核通过并线下退回。请在订单中确认是否收到。','refund','1790220207893875832',0,'2026-09-24 11:24:30','2026-09-24 11:24:30'),(1790221891510356048,1790214033967587427,'refund','家长已确认收到退款','退款 ¥28.80 家长已确认收到，课时已扣减。','refund','1790220207893875832',0,'2026-09-24 11:51:31','2026-09-24 11:51:31'),(1790222128450465376,1790214033967587427,'order','收款已确认，课时到账','《创意绘画》10 课时已到账，可在「我的订单」查看。','order','1790222106970428405',0,'2026-09-24 11:55:28','2026-09-24 11:55:28'),(1790226944368757521,1790214033967587427,'refund','退款已退回，待你确认','「创意绘画」退款 ¥28.80 已审核通过并线下退回。请在订单中确认是否收到。','refund','1790226932700588467',0,'2026-09-24 13:15:44','2026-09-24 13:15:44'),(1790226951765781245,1790214033967587427,'refund','家长已确认收到退款','退款 ¥28.80 家长已确认收到，课时已扣减。','refund','1790226932700588467',0,'2026-09-24 13:15:51','2026-09-24 13:15:51'),(1790232222206894588,1790214033967587427,'order','收款已确认，课时到账','《创意绘画》10 课时已到账，可在「我的订单」查看。','order','1790232199208213617',0,'2026-09-24 14:43:42','2026-09-24 14:43:42'),(1790232263129766542,1790214033967587427,'refund','退款申请已驳回','「创意绘画」退款 ¥28.80 未通过：no','refund','1790232236483877298',0,'2026-09-24 14:44:23','2026-09-24 14:44:23'),(1790232332101948451,1790214033967587427,'refund','退款申请已驳回','「创意绘画」退款 ¥28.80 未通过：不行啊，太扯了哈哈哈哈哈哈哈哈啊哈哈哈哈哈哈哈哈哈哈哈哈','refund','1790232305343586116',0,'2026-09-24 14:45:32','2026-09-24 14:45:32'),(1790232407574208049,1790214033967587427,'refund','退款申请已驳回','「创意绘画」退款 ¥28.80 未通过：不可以啊 撒撒撒撒是阿是阿是啊','refund','1790232371577497926',0,'2026-09-24 14:46:47','2026-09-24 14:46:47'),(1790233068441157107,1790214033967587427,'refund','退款申请已驳回','「创意绘画」退款 ¥28.80 未通过：OK','refund','1790233052130168943',0,'2026-09-24 14:57:48','2026-09-24 14:57:48'),(1790233324803820968,1790214033967587427,'refund','退款申请已驳回','「创意绘画」退款 ¥28.80 未通过：驳回原因','refund','1790233306686166105',0,'2026-09-24 15:02:04','2026-09-24 15:02:04'),(1790233360225250092,1790214033967587427,'refund','退款申请已驳回','「创意绘画」退款 ¥28.80 未通过：给i额合法去u额去全额如期人去融合器然后去额UR后期人哈欺辱u求和任丘人去i儿回去如期诶日期二哈U恒瑞切换日u全额换热器让回去i二','refund','1790233345257196390',0,'2026-09-24 15:02:40','2026-09-24 15:02:40'),(1790233391225310644,1790214033967587427,'refund','退款已退回，待你确认','「创意绘画」退款 ¥28.80 已审核通过并线下退回。请在订单中确认是否收到。','refund','1790233373877284540',0,'2026-09-24 15:03:11','2026-09-24 15:03:11'),(1790233611370954374,1790214033967587427,'refund','家长已确认收到退款','退款 ¥28.80 家长已确认收到，课时已扣减。','refund','1790233373877284540',0,'2026-09-24 15:06:51','2026-09-24 15:06:51'),(1790233633156415675,1790214033967587427,'order','新的付款凭证待核对','家长已提交「创意绘画」的现金付款凭证，请核对到账后确认收款。','order','1790233628188457446',0,'2026-09-24 15:07:13','2026-09-24 15:07:13'),(1790233645344507246,1790214033967587427,'order','收款已确认，课时到账','《创意绘画》10 课时已到账，可在「我的订单」查看。','order','1790233628188457446',0,'2026-09-24 15:07:25','2026-09-24 15:07:25'),(1790238961843912001,1790214033967587427,'attendance','上课签到','小周周已完成《创意绘画》1 课时，剩余 9 课时。',NULL,NULL,0,'2026-09-24 16:36:01','2026-09-24 16:36:01'),(1790239122861169597,1790214033967587427,'leave','请假未通过','小周周 2026-10-03 的请假申请未通过','leave','1790239066745822425',0,'2026-09-24 16:38:42','2026-09-24 16:38:42'),(1790239386061455449,1790214033967587427,'leave','请假已通过','小周周 2026-10-03 的请假申请已通过','leave','1790239327250210037',0,'2026-09-24 16:43:06','2026-09-24 16:43:06'),(1790239393135756766,1790214033967587427,'leave','补课已安排','小周周 的请假补课已安排：创意绘画 · 2026-10-10 18:30-20:00（3号教室）','leave','1790239327250210037',0,'2026-09-24 16:43:13','2026-09-24 16:43:13'),(1790239452249899322,1790214033967587427,'leave','补课已安排','小周周 的请假补课已安排：创意绘画 · 2026-10-17 18:30-20:00（3号教室）','leave','1790239327250210037',0,'2026-09-24 16:44:12','2026-09-24 16:44:12'),(1790240011734735318,1790214033967587427,'leave','补课已安排','小周周 的请假补课已安排：创意绘画 · 2026-10-24 18:30-20:00（3号教室）','leave','1790239327250210037',0,'2026-09-24 16:53:31','2026-09-24 16:53:31'),(1790240437758387514,1790214033967587427,'leave','请假已通过','小周周 2026-10-10 的请假申请已通过','leave','1790240415536337212',0,'2026-09-24 17:00:37','2026-09-24 17:00:37'),(1790240466640278290,1790214033967587427,'leave','补课已安排','小周周 的请假补课已安排：创意绘画 · 2026-10-17 18:30-20:00（3号教室）','leave','1790240415536337212',0,'2026-09-24 17:01:06','2026-09-24 17:01:06'),(1790240479235582504,1790214033967587427,'leave','补课已安排','小周周 的请假补课已安排：创意绘画 · 2026-10-17 18:30-20:00（3号教室）','leave','1790240415536337212',0,'2026-09-24 17:01:19','2026-09-24 17:01:19'),(1790562051439936748,1790560249097925243,'cert','工作室认证已通过','恭喜，「木色少儿美术」认证已通过，现在可以开展课程与招生了。 Web 管理后台已开通：使用手机号 studio_owner_1 登录「工作室后台」，初始密码 123456，请尽快修改。','cert','1790560249119126672',0,'2026-09-28 10:20:51','2026-09-28 10:20:51');
/*!40000 ALTER TABLE `notifications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `order_items`
--

DROP TABLE IF EXISTS `order_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `order_items` (
  `item_id` bigint NOT NULL,
  `order_id` bigint NOT NULL,
  `course_id` bigint NOT NULL,
  `package_id` bigint DEFAULT NULL,
  `course_title` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `package_name` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lessons` smallint NOT NULL,
  `quantity` smallint NOT NULL DEFAULT '1',
  `unit_price` int NOT NULL,
  `total_price` int NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `class_id` bigint DEFAULT NULL,
  PRIMARY KEY (`item_id`),
  KEY `order_id` (`order_id`),
  KEY `course_id` (`course_id`),
  KEY `package_id` (`package_id`),
  CONSTRAINT `order_items_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `order_items_ibfk_2` FOREIGN KEY (`course_id`) REFERENCES `courses` (`course_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `order_items_ibfk_3` FOREIGN KEY (`package_id`) REFERENCES `course_packages` (`package_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `order_items`
--

LOCK TABLES `order_items` WRITE;
/*!40000 ALTER TABLE `order_items` DISABLE KEYS */;
INSERT INTO `order_items` VALUES (1790232199212916267,1790232199208213617,1790215643620388977,NULL,'创意绘画',NULL,10,1,2880,2880,'2026-09-24 14:43:19','2026-09-24 14:43:19',1790215848474966381),(1790233628191586641,1790233628188457446,1790215643620388977,NULL,'创意绘画',NULL,10,1,2880,2880,'2026-09-24 15:07:08','2026-09-24 15:07:08',1790215848474966381),(1790236018972362676,1790236018968988165,1790215643620388977,NULL,'创意绘画',NULL,10,1,2880,2880,'2026-09-24 15:46:58','2026-09-24 15:46:58',1790215848474966381),(1790560249154486216,1790560249151881028,1790560249129733596,1790560249134139935,'创意启蒙绘画班','12 课时包',12,1,168000,168000,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL),(1790560249163293542,1790560249162109114,1790560249131664292,1790560249137151639,'综合材料创作营','8 课时包',8,1,236000,236000,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL);
/*!40000 ALTER TABLE `order_items` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `orders`
--

DROP TABLE IF EXISTS `orders`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `orders` (
  `order_id` bigint NOT NULL,
  `order_no` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint NOT NULL,
  `child_id` bigint NOT NULL,
  `studio_id` bigint NOT NULL,
  `course_id` bigint NOT NULL,
  `package_id` bigint DEFAULT NULL,
  `distribution_link_id` bigint DEFAULT NULL,
  `total_lessons` smallint NOT NULL,
  `consumed_lessons` smallint NOT NULL DEFAULT '0',
  `refunded_lessons` smallint NOT NULL DEFAULT '0',
  `total_amount` int NOT NULL,
  `paid_amount` int NOT NULL DEFAULT '0',
  `refund_amount` int NOT NULL DEFAULT '0',
  `pay_channel` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `paid_at` datetime DEFAULT NULL,
  `completed_at` datetime DEFAULT NULL,
  `status` smallint NOT NULL DEFAULT '0',
  `remark` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `class_id` bigint DEFAULT NULL,
  `source` tinyint NOT NULL DEFAULT '0',
  `confirmed_by` bigint DEFAULT NULL,
  PRIMARY KEY (`order_id`),
  UNIQUE KEY `order_no` (`order_no`),
  KEY `child_id` (`child_id`),
  KEY `course_id` (`course_id`),
  KEY `package_id` (`package_id`),
  KEY `idx_orders_user_status` (`user_id`,`status`),
  KEY `idx_orders_studio_status` (`studio_id`,`status`),
  KEY `orders_class_id` (`class_id`),
  CONSTRAINT `orders_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `orders_ibfk_2` FOREIGN KEY (`child_id`) REFERENCES `children` (`child_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `orders_ibfk_3` FOREIGN KEY (`studio_id`) REFERENCES `studio_profiles` (`studio_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `orders_ibfk_4` FOREIGN KEY (`course_id`) REFERENCES `courses` (`course_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `orders_ibfk_5` FOREIGN KEY (`package_id`) REFERENCES `course_packages` (`package_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `orders`
--

LOCK TABLES `orders` WRITE;
/*!40000 ALTER TABLE `orders` DISABLE KEYS */;
INSERT INTO `orders` VALUES (1790232199208213617,'TG1790232199208860032',1790214033967587427,1790214102352119762,1790214661961110965,1790215643620388977,NULL,NULL,10,0,10,2880,2880,2880,'cash','2026-09-24 14:43:42',NULL,5,NULL,'2026-09-24 14:43:19','2026-09-24 15:06:51',1790215848474966381,0,1790214661974489202),(1790233628188457446,'TG1790233628188846918',1790214033967587427,1790214102352119762,1790214661961110965,1790215643620388977,NULL,NULL,10,1,0,2880,2880,0,'cash','2026-09-24 15:07:25',NULL,2,NULL,'2026-09-24 15:07:08','2026-09-24 16:36:01',1790215848474966381,0,1790214661974489202),(1790236018968988165,'TG1790236018968587167',1790214033967587427,1790214084899387524,1790214661961110965,1790215643620388977,NULL,NULL,10,0,0,2880,0,0,NULL,NULL,'2026-09-28 10:28:06',6,NULL,'2026-09-24 15:46:58','2026-09-28 10:28:06',1790215848474966381,0,NULL),(1790560249151881028,'TG1790560249151626486',1790560249067375015,1790560249091158232,1790560249100996763,1790560249129733596,1790560249134139935,NULL,12,0,0,168000,168000,0,'wechat_mini','2026-09-28 09:50:49',NULL,1,NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL,0,NULL),(1790560249162109114,'TG1790560249162728130',1790560249067375015,1790560249091158232,1790560249103102124,1790560249131664292,1790560249137151639,NULL,8,0,2,236000,236000,59000,'wechat_mini','2026-09-28 09:50:49',NULL,3,NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL,0,NULL);
/*!40000 ALTER TABLE `orders` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `payments`
--

DROP TABLE IF EXISTS `payments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `payments` (
  `payment_id` bigint NOT NULL,
  `order_id` bigint NOT NULL,
  `payment_no` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL,
  `channel` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` int NOT NULL,
  `paid_at` datetime DEFAULT NULL,
  `status` smallint NOT NULL DEFAULT '0',
  `trade_no` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `pay_method` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `voucher_images` json DEFAULT NULL,
  `payer_note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `upload_by` tinyint NOT NULL DEFAULT '0',
  `confirm_by` bigint DEFAULT NULL,
  `reject_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  PRIMARY KEY (`payment_id`),
  UNIQUE KEY `payment_no` (`payment_no`),
  KEY `order_id` (`order_id`),
  CONSTRAINT `payments_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `payments`
--

LOCK TABLES `payments` WRITE;
/*!40000 ALTER TABLE `payments` DISABLE KEYS */;
INSERT INTO `payments` VALUES (1790232222197763152,1790232199208213617,'PM1790232222197386192','cash',2880,'2026-09-24 14:43:42',1,NULL,'2026-09-24 14:43:42','2026-09-24 14:43:42','cash','[]','已核对',1,1790214661974489202,NULL),(1790233633154945747,1790233628188457446,'PM1790233633154271608','cash',2880,'2026-09-24 15:07:25',1,NULL,'2026-09-24 15:07:13','2026-09-24 15:07:25','cash','[]',NULL,0,1790214661974489202,NULL),(1790560249156838335,1790560249151881028,'PM1790560249156788048','wechat_mini',168000,'2026-09-28 09:50:49',1,'TRADE1790560249156538913','2026-09-28 09:50:49','2026-09-28 09:50:49',NULL,NULL,NULL,0,NULL,NULL),(1790560249165864438,1790560249162109114,'PM1790560249165390440','wechat_mini',236000,'2026-09-28 09:50:49',1,'TRADE1790560249165334989','2026-09-28 09:50:49','2026-09-28 09:50:49',NULL,NULL,NULL,0,NULL,NULL);
/*!40000 ALTER TABLE `payments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `platform_configs`
--

DROP TABLE IF EXISTS `platform_configs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `platform_configs` (
  `config_id` bigint NOT NULL,
  `config_key` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `config_value` text COLLATE utf8mb4_unicode_ci,
  `description` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `updated_by` bigint DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`config_id`),
  UNIQUE KEY `config_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `platform_configs`
--

LOCK TABLES `platform_configs` WRITE;
/*!40000 ALTER TABLE `platform_configs` DISABLE KEYS */;
INSERT INTO `platform_configs` VALUES (1789140400000000000,'hot_keywords','[\"创意绘画\",\"水彩\",\"书法\",\"周末班\"]','课程搜索热词',NULL,'2026-09-11 23:50:13','2026-09-11 23:50:13');
/*!40000 ALTER TABLE `platform_configs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `post_comment_likes`
--

DROP TABLE IF EXISTS `post_comment_likes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_comment_likes` (
  `id` bigint NOT NULL,
  `comment_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `post_comment_likes_comment_id_user_id` (`comment_id`,`user_id`),
  KEY `post_comment_likes_comment_id` (`comment_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `post_comment_likes`
--

LOCK TABLES `post_comment_likes` WRITE;
/*!40000 ALTER TABLE `post_comment_likes` DISABLE KEYS */;
/*!40000 ALTER TABLE `post_comment_likes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `post_comments`
--

DROP TABLE IF EXISTS `post_comments`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_comments` (
  `comment_id` bigint NOT NULL,
  `post_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `content` varchar(500) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` smallint NOT NULL DEFAULT '1' COMMENT '1 正常 / 0 已删除',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `like_count` int NOT NULL DEFAULT '0',
  `parent_id` bigint NOT NULL DEFAULT '0',
  PRIMARY KEY (`comment_id`),
  KEY `idx_post_comments_post` (`post_id`,`status`),
  KEY `post_comments_parent_id` (`parent_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `post_comments`
--

LOCK TABLES `post_comments` WRITE;
/*!40000 ALTER TABLE `post_comments` DISABLE KEYS */;
/*!40000 ALTER TABLE `post_comments` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `post_likes`
--

DROP TABLE IF EXISTS `post_likes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_likes` (
  `like_id` bigint NOT NULL,
  `post_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`like_id`),
  UNIQUE KEY `uk_post_likes_post_user` (`post_id`,`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `post_likes`
--

LOCK TABLES `post_likes` WRITE;
/*!40000 ALTER TABLE `post_likes` DISABLE KEYS */;
/*!40000 ALTER TABLE `post_likes` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `post_students`
--

DROP TABLE IF EXISTS `post_students`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `post_students` (
  `id` bigint NOT NULL,
  `post_id` bigint NOT NULL,
  `child_id` bigint NOT NULL,
  `order_id` bigint NOT NULL,
  `deducted` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_post_students_post_child` (`post_id`,`child_id`),
  KEY `child_id` (`child_id`),
  KEY `order_id` (`order_id`),
  CONSTRAINT `post_students_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`post_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `post_students_ibfk_2` FOREIGN KEY (`child_id`) REFERENCES `children` (`child_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `post_students_ibfk_3` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `post_students`
--

LOCK TABLES `post_students` WRITE;
/*!40000 ALTER TABLE `post_students` DISABLE KEYS */;
/*!40000 ALTER TABLE `post_students` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `posts`
--

DROP TABLE IF EXISTS `posts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `posts` (
  `post_id` bigint NOT NULL,
  `author_id` bigint NOT NULL,
  `author_role` smallint NOT NULL,
  `type` smallint NOT NULL,
  `child_id` bigint DEFAULT NULL,
  `course_id` bigint DEFAULT NULL,
  `class_id` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `images` json DEFAULT NULL,
  `content` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `visibility` smallint NOT NULL DEFAULT '2',
  `like_count` int NOT NULL DEFAULT '0',
  `comment_count` int NOT NULL DEFAULT '0',
  `share_count` int NOT NULL DEFAULT '0',
  `status` smallint NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `topic` varchar(32) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `latitude` decimal(10,8) DEFAULT NULL COMMENT '纬度（-90~90），选填',
  `longitude` decimal(11,8) DEFAULT NULL COMMENT '经度（-180~180），选填',
  `location_name` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '地点名（反地理编码），选填',
  PRIMARY KEY (`post_id`),
  KEY `child_id` (`child_id`),
  KEY `idx_posts_author_status` (`author_id`,`status`),
  KEY `idx_posts_course_status` (`course_id`,`status`),
  KEY `idx_posts_topic_status_created` (`topic`,`status`,`created_at`),
  CONSTRAINT `posts_ibfk_1` FOREIGN KEY (`author_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `posts_ibfk_2` FOREIGN KEY (`child_id`) REFERENCES `children` (`child_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `posts_ibfk_3` FOREIGN KEY (`course_id`) REFERENCES `courses` (`course_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `posts`
--

LOCK TABLES `posts` WRITE;
/*!40000 ALTER TABLE `posts` DISABLE KEYS */;
INSERT INTO `posts` VALUES (1790214185268244815,1790214033967587427,1,1,1790214102352119762,NULL,NULL,'[\"/uploads/post/20260924/d413a96db2489e7b0380d88a3e14e2cf.jpg\"]','测试一下发帖',2,0,0,0,1,'2026-09-24 09:43:05','2026-09-24 09:43:05','成长记录',37.79508605,112.54125669,'清控创新基地D座'),(1790214425732994574,1790214033967587427,2,1,NULL,NULL,NULL,'[\"/uploads/post/20260924/a78f7a62d15fe98929c9b2c2b930109f.jpg\"]','老师作品测试下呢',2,0,0,0,1,'2026-09-24 09:47:05','2026-09-24 09:47:05',NULL,37.79537000,112.54512000,'神通便利店'),(1790235312292195303,1790214033967587427,1,1,1790214102352119762,NULL,NULL,'[\"/uploads/post/20260924/c94ed38de66eeeb6664b109058b05d5f.jpg\"]','小周周作品第一集',2,0,0,0,1,'2026-09-24 15:35:12','2026-09-24 15:35:12','成长记录',37.79510402,112.54130355,'清控创新基地D座'),(1790235991723897868,1790214033967587427,1,2,1790214102352119762,1790215643620388977,NULL,'[\"/uploads/post/20260924/d96259901ad56224b4f6559ee8029904.jpg\"]','小周周作品第二集',2,0,0,0,1,'2026-09-24 15:46:31','2026-09-24 15:46:31','成长记录',37.79510173,112.54129923,'清控创新基地D座');
/*!40000 ALTER TABLE `posts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `refresh_tokens`
--

DROP TABLE IF EXISTS `refresh_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `refresh_tokens` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `token` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expires_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `token` (`token`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `refresh_tokens_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `refresh_tokens`
--

LOCK TABLES `refresh_tokens` WRITE;
/*!40000 ALTER TABLE `refresh_tokens` DISABLE KEYS */;
INSERT INTO `refresh_tokens` VALUES (1790213955435817967,1789012617389540630,'1789012617392230845.702be70430d07cdbc70d8ddf5f27b99bf59d65341b17d0db','2026-10-24 09:39:15',NULL,'2026-09-24 09:39:15','2026-09-24 09:39:15'),(1790214034047625792,1790214033967587427,'8cd099d5ab6be347d61fefbbfac53409263ecd8ba0191539','2026-10-24 09:40:34',NULL,'2026-09-24 09:40:34','2026-09-24 09:40:34'),(1790214714400209517,1790214033967587427,'1790214661974489202.4c388b4c8235236b96a29c125a5fac38a488933d5288df1b','2026-10-24 09:51:54',NULL,'2026-09-24 09:51:54','2026-09-24 09:51:54'),(1790215001810145876,1790215001732915922,'64d572cb041e2f16d2850559546db8f226cc97fbdc92a7aa','2026-10-24 09:56:41',NULL,'2026-09-24 09:56:41','2026-09-24 09:56:41'),(1790215123012638935,1789012617389540630,'1789012617392230845.5a9382c14f321a4762056df74ee3e93be25c3497562396c6','2026-10-24 09:58:43',NULL,'2026-09-24 09:58:43','2026-09-24 09:58:43'),(1790215175967396791,1790215001732915922,'2643524ec0f9b6003602d00c8833f771704b18b62bda1483','2026-10-24 09:59:35',NULL,'2026-09-24 09:59:35','2026-09-24 09:59:35'),(1790215201341834376,1790214033967587427,'554ab807595ec68720a1b68f4fa4618b433abdd139f958dc','2026-10-24 10:00:01',NULL,'2026-09-24 10:00:01','2026-09-24 10:00:01'),(1790215338820471398,1790214033967587427,'1790214661974489202.b038736bd37237b8ef9af6ddf010439bf2413f9fd5dededa','2026-10-24 10:02:18',NULL,'2026-09-24 10:02:18','2026-09-24 10:02:18'),(1790235751759556185,1790215001732915922,'ace58f6de74cc6e1f376f5809c527cfde718a6ee3179fce9','2026-10-24 15:42:31',NULL,'2026-09-24 15:42:31','2026-09-24 15:42:31'),(1790235814210710729,1790214033967587427,'cac4457873909d34140e8b9c51f8f48d3d9ab3832c10ad4f','2026-10-24 15:43:34',NULL,'2026-09-24 15:43:34','2026-09-24 15:43:34'),(1790560974245903397,1790214033967587427,'c28688d11edc86dc0b92848fa2e961836327e4b50699780c','2026-10-28 10:02:54',NULL,'2026-09-28 10:02:54','2026-09-28 10:02:54'),(1790561028584650630,1790214033967587427,'1790214661974489202.ffbb6bcd1ee1232cd2989fad214b97a05c1f7dc95f1f50b5','2026-10-28 10:03:48',NULL,'2026-09-28 10:03:48','2026-09-28 10:03:48'),(1790561033436814548,1790214033967587427,'1790214661974489202.0016f1b165f2ba84970bf163b8ba171cfc00e9e5ad6bdc69','2026-10-28 10:03:53',NULL,'2026-09-28 10:03:53','2026-09-28 10:03:53'),(1790561154802258479,1789012617389540630,'1789012617392230845.3c558effad886bbec70cc943572aeead0f8640487cbcae8b','2026-10-28 10:05:54',NULL,'2026-09-28 10:05:54','2026-09-28 10:05:54'),(1790561279955211374,1789012617389540630,'1789012617392230845.117eda185bbeae1698a68525e87a5e884e04b4dffb38e576','2026-10-28 10:07:59',NULL,'2026-09-28 10:07:59','2026-09-28 10:07:59'),(1790561805333113206,1789012617389540630,'1789012617392230845.46b06a74915e73dc8df953555f8db0e4b2f4c98d07f64c66','2026-10-28 10:16:45',NULL,'2026-09-28 10:16:45','2026-09-28 10:16:45'),(1790561983730309878,1789012617389540630,'1789012617392230845.d4d1d41df8136046581659e14af360659f1defa1666869b5','2026-10-28 10:19:43',NULL,'2026-09-28 10:19:43','2026-09-28 10:19:43'),(1790562250819764931,1790214033967587427,'1790214661974489202.be0e6778a47bfb041d7d852adf59b716ffed8b189be7a575','2026-10-28 10:24:10',NULL,'2026-09-28 10:24:10','2026-09-28 10:24:10'),(1790562820820146319,1790214033967587427,'1790214661974489202.ca227f3372b40e8a3eb897fc476d22c26ff2c0569a187ff8','2026-10-28 10:33:40',NULL,'2026-09-28 10:33:40','2026-09-28 10:33:40'),(1790563060796731306,1790214033967587427,'1790214661974489202.bd3eb1f4f7d279fcae64a9f60415d86d4a365fb8c35e736d','2026-10-28 10:37:40',NULL,'2026-09-28 10:37:40','2026-09-28 10:37:40'),(1790563175676890326,1790214033967587427,'1790214661974489202.48478de7f2ecc620833de48f42b0e4f8f19d3540edf88e4a','2026-10-28 10:39:35',NULL,'2026-09-28 10:39:35','2026-09-28 10:39:35'),(1790563288648613443,1790214033967587427,'1790214661974489202.9170e1971ecd78e36270c8a5b3d362a27fe1e8f1e08140a6','2026-10-28 10:41:28',NULL,'2026-09-28 10:41:28','2026-09-28 10:41:28');
/*!40000 ALTER TABLE `refresh_tokens` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `refunds`
--

DROP TABLE IF EXISTS `refunds`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `refunds` (
  `refund_id` bigint NOT NULL,
  `order_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `requested_lessons` smallint NOT NULL,
  `approved_lessons` smallint DEFAULT NULL,
  `refundable_lessons` smallint NOT NULL,
  `unit_price` int NOT NULL,
  `amount` int NOT NULL,
  `reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `reviewed_by` bigint DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `refunded_at` datetime DEFAULT NULL,
  `status` smallint NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `refund_method` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `voucher_images` json DEFAULT NULL,
  `reject_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `processed_by` bigint DEFAULT NULL,
  `processed_at` datetime DEFAULT NULL,
  `confirmed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`refund_id`),
  KEY `user_id` (`user_id`),
  KEY `idx_refunds_order_status` (`order_id`,`status`),
  CONSTRAINT `refunds_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders` (`order_id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `refunds_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `refunds`
--

LOCK TABLES `refunds` WRITE;
/*!40000 ALTER TABLE `refunds` DISABLE KEYS */;
INSERT INTO `refunds` VALUES (1790232236483877298,1790232199208213617,1790214033967587427,10,NULL,10,288,2880,'no',1790214661974489202,'2026-09-24 14:44:23',NULL,2,'2026-09-24 14:43:56','2026-09-24 14:44:23',NULL,NULL,NULL,NULL,NULL,NULL),(1790232305343586116,1790232199208213617,1790214033967587427,10,NULL,10,288,2880,'不行啊，太扯了哈哈哈哈哈哈哈哈啊哈哈哈哈哈哈哈哈哈哈哈哈',1790214661974489202,'2026-09-24 14:45:32',NULL,2,'2026-09-24 14:45:05','2026-09-24 14:45:32',NULL,NULL,NULL,NULL,NULL,NULL),(1790232371577497926,1790232199208213617,1790214033967587427,10,NULL,10,288,2880,'不可以啊 撒撒撒撒是阿是阿是啊',1790214661974489202,'2026-09-24 14:46:47',NULL,2,'2026-09-24 14:46:11','2026-09-24 14:46:47',NULL,NULL,NULL,NULL,NULL,NULL),(1790233052130168943,1790232199208213617,1790214033967587427,10,NULL,10,288,2880,'时间安排冲突',1790214661974489202,'2026-09-24 14:57:48',NULL,2,'2026-09-24 14:57:32','2026-09-24 14:57:48',NULL,NULL,'OK',NULL,NULL,NULL),(1790233306686166105,1790232199208213617,1790214033967587427,10,NULL,10,288,2880,'工作室原因',1790214661974489202,'2026-09-24 15:02:04',NULL,2,'2026-09-24 15:01:46','2026-09-24 15:02:04',NULL,NULL,'驳回原因',NULL,NULL,NULL),(1790233345257196390,1790232199208213617,1790214033967587427,10,NULL,10,288,2880,'工作室原因',1790214661974489202,'2026-09-24 15:02:40',NULL,2,'2026-09-24 15:02:25','2026-09-24 15:02:40',NULL,NULL,'给i额合法去u额去全额如期人去融合器然后去额UR后期人哈欺辱u求和任丘人去i儿回去如期诶日期二哈U恒瑞切换日u全额换热器让回去i二',NULL,NULL,NULL),(1790233373877284540,1790232199208213617,1790214033967587427,10,10,10,288,2880,'OK',1790214661974489202,'2026-09-24 15:03:11','2026-09-24 15:06:51',3,'2026-09-24 15:02:53','2026-09-24 15:06:51','cash','[]',NULL,NULL,NULL,'2026-09-24 15:06:51'),(1790560249169395571,1790560249162109114,1790560249067375015,2,NULL,8,29500,59000,'演示退款',NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49',3,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL,NULL,NULL,NULL,NULL,NULL);
/*!40000 ALTER TABLE `refunds` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reports`
--

DROP TABLE IF EXISTS `reports`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `reports` (
  `report_id` bigint NOT NULL,
  `reporter_id` bigint NOT NULL,
  `target_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `target_id` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `reason` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `detail` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `images` json DEFAULT NULL,
  `status` smallint NOT NULL DEFAULT '0',
  `handled_by` bigint DEFAULT NULL,
  `handle_note` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `handled_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`report_id`),
  KEY `reports_target_type_target_id_status_created_at` (`target_type`,`target_id`,`status`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `reports`
--

LOCK TABLES `reports` WRITE;
/*!40000 ALTER TABLE `reports` DISABLE KEYS */;
/*!40000 ALTER TABLE `reports` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `schedules`
--

DROP TABLE IF EXISTS `schedules`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `schedules` (
  `schedule_id` bigint NOT NULL,
  `studio_id` bigint NOT NULL,
  `class_id` bigint NOT NULL,
  `course_id` bigint NOT NULL,
  `teacher_id` bigint DEFAULT NULL,
  `lesson_date` date NOT NULL,
  `start_time` varchar(5) COLLATE utf8mb4_unicode_ci NOT NULL,
  `end_time` varchar(5) COLLATE utf8mb4_unicode_ci NOT NULL,
  `location` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` smallint NOT NULL DEFAULT '0',
  `remark` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_makeup` tinyint(1) NOT NULL DEFAULT '0',
  `makeup_from` bigint DEFAULT NULL,
  PRIMARY KEY (`schedule_id`),
  KEY `course_id` (`course_id`),
  KEY `idx_schedules_studio_lesson_date` (`studio_id`,`lesson_date`),
  KEY `idx_schedules_teacher_lesson_date` (`teacher_id`,`lesson_date`),
  KEY `idx_schedules_class_lesson_date` (`class_id`,`lesson_date`),
  KEY `schedules_makeup_from_foreign_idx` (`makeup_from`),
  CONSTRAINT `schedules_ibfk_1` FOREIGN KEY (`studio_id`) REFERENCES `studio_profiles` (`studio_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `schedules_ibfk_2` FOREIGN KEY (`class_id`) REFERENCES `classes` (`class_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `schedules_ibfk_3` FOREIGN KEY (`course_id`) REFERENCES `courses` (`course_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `schedules_ibfk_4` FOREIGN KEY (`teacher_id`) REFERENCES `teacher_profiles` (`teacher_id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `schedules_makeup_from_foreign_idx` FOREIGN KEY (`makeup_from`) REFERENCES `schedules` (`schedule_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `schedules`
--

LOCK TABLES `schedules` WRITE;
/*!40000 ALTER TABLE `schedules` DISABLE KEYS */;
INSERT INTO `schedules` VALUES (1790560249145243938,1790560249100996763,1790560249141587487,1790560249129733596,1790560249112557887,'2026-09-16','18:30','20:00','A101 教室',0,'演示排课','2026-09-28 09:50:49','2026-09-28 09:50:49',0,NULL),(1790560249147183566,1790560249100996763,1790560249141587487,1790560249129733596,1790560249112557887,'2026-09-23','18:30','20:00','A101 教室',0,'演示排课','2026-09-28 09:50:49','2026-09-28 09:50:49',0,NULL),(1790560249149507039,1790560249103102124,1790560249143814730,1790560249131664292,1790560249113590983,'2026-09-20','10:00','12:00','B201 教室',0,'演示排课','2026-09-28 09:50:49','2026-09-28 09:50:49',0,NULL);
/*!40000 ALTER TABLE `schedules` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `settlements`
--

DROP TABLE IF EXISTS `settlements`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `settlements` (
  `settlement_id` bigint NOT NULL,
  `studio_id` bigint NOT NULL,
  `period_start` date NOT NULL,
  `period_end` date NOT NULL,
  `income` int NOT NULL DEFAULT '0',
  `refund` int NOT NULL DEFAULT '0',
  `distribution` int NOT NULL DEFAULT '0',
  `net_amount` int NOT NULL DEFAULT '0',
  `fee_rate` decimal(4,2) NOT NULL DEFAULT '0.10',
  `fee_amount` int NOT NULL DEFAULT '0',
  `payable_amount` int NOT NULL DEFAULT '0',
  `status` smallint NOT NULL DEFAULT '0',
  `pay_no` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `operator_id` bigint DEFAULT NULL,
  `paid_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`settlement_id`),
  KEY `operator_id` (`operator_id`),
  KEY `idx_settlement_studio_period` (`studio_id`,`period_start`,`period_end`),
  CONSTRAINT `settlements_ibfk_1` FOREIGN KEY (`studio_id`) REFERENCES `studio_profiles` (`studio_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `settlements_ibfk_2` FOREIGN KEY (`operator_id`) REFERENCES `admin_accounts` (`admin_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `settlements`
--

LOCK TABLES `settlements` WRITE;
/*!40000 ALTER TABLE `settlements` DISABLE KEYS */;
INSERT INTO `settlements` VALUES (1790560249123305310,1790560249100996763,'2026-09-01','2026-09-30',8820000,320000,548800,7951200,0.12,954144,6997056,0,NULL,NULL,NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49'),(1790560249127537550,1790560249103102124,'2026-09-01','2026-09-30',4360000,160000,378000,3822000,0.10,382200,3439800,3,NULL,NULL,NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49');
/*!40000 ALTER TABLE `settlements` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `studio_accounts`
--

DROP TABLE IF EXISTS `studio_accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `studio_accounts` (
  `account_id` bigint NOT NULL,
  `studio_id` bigint NOT NULL,
  `account_type` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'bank',
  `account_name` varchar(80) COLLATE utf8mb4_unicode_ci NOT NULL,
  `account_no` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `bank_name` varchar(80) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `is_default` smallint NOT NULL DEFAULT '1',
  `status` smallint NOT NULL DEFAULT '1',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`account_id`),
  KEY `studio_accounts_studio_id` (`studio_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `studio_accounts`
--

LOCK TABLES `studio_accounts` WRITE;
/*!40000 ALTER TABLE `studio_accounts` DISABLE KEYS */;
/*!40000 ALTER TABLE `studio_accounts` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `studio_applications`
--

DROP TABLE IF EXISTS `studio_applications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `studio_applications` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `name` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cover` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `intro` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `license` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `permit` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `photos` json DEFAULT NULL,
  `version` int NOT NULL DEFAULT '1',
  `status` smallint NOT NULL DEFAULT '0',
  `submitted_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reviewed_at` datetime DEFAULT NULL,
  `review_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `city` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '所在城市 / 区域',
  `business_type` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '营业类型：艺术培训 / 书法书院 / 综合美育',
  `teacher_count` smallint DEFAULT NULL COMMENT '师资数量（专职老师人数）',
  `contact_name` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '联系人姓名',
  `business_tags` json DEFAULT NULL COMMENT '营业类型标签（多选，取自标签库 scope=1）',
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `studio_applications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `studio_applications`
--

LOCK TABLES `studio_applications` WRITE;
/*!40000 ALTER TABLE `studio_applications` DISABLE KEYS */;
INSERT INTO `studio_applications` VALUES (1790214526343655439,1790214033967587427,'兰亭书画',NULL,'诗酒趁年华，小生不才，却也懂得此中真意','兰亭御湖城','18234126896','123456789','暂无','[]',1,2,'2026-09-24 09:48:46','2026-09-24 09:49:21','驳回','2026-09-24 09:48:46','2026-09-24 09:49:21','太原晋源','创意绘画',NULL,'周校长','[\"创意绘画\", \"少儿美术\", \"书法\", \"素描\", \"水彩\", \"国画\", \"动漫插画\", \"手工陶艺\"]'),(1790214574940347630,1790214033967587427,'兰亭书画',NULL,'诗酒趁年华，小生不才，却也懂得此中真意','兰亭御湖城','18234126896','123456789','暂无','[]',2,1,'2026-09-24 09:49:34','2026-09-24 09:51:01',NULL,'2026-09-24 09:49:34','2026-09-24 09:51:01','太原晋源','创意绘画',NULL,'周校长','[\"创意绘画\", \"少儿美术\", \"书法\", \"素描\", \"水彩\", \"国画\", \"动漫插画\", \"手工陶艺\"]'),(1790560249119126672,1790560249097925243,'木色少儿美术',NULL,'少儿创意美术与材料表达课程','杭州市西湖区文三路','0571-12345678',NULL,NULL,NULL,1,1,'2026-09-28 09:50:49','2026-09-28 10:20:51',NULL,'2026-09-28 09:50:49','2026-09-28 10:20:51',NULL,NULL,NULL,NULL,'[]');
/*!40000 ALTER TABLE `studio_applications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `studio_profiles`
--

DROP TABLE IF EXISTS `studio_profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `studio_profiles` (
  `studio_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `name` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
  `cover` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type_tags` json DEFAULT NULL,
  `intro` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `address` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `lng` decimal(10,6) DEFAULT NULL,
  `lat` decimal(10,6) DEFAULT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `hours` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `license` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `legal_id` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `permit` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `photos` json DEFAULT NULL,
  `settle_rate` decimal(4,2) NOT NULL DEFAULT '0.10',
  `plan_tier` smallint NOT NULL DEFAULT '1',
  `status` smallint NOT NULL DEFAULT '0',
  `banned_at` datetime DEFAULT NULL,
  `ban_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `distribute_rate` decimal(4,2) NOT NULL DEFAULT '5.00' COMMENT '分销返利比例(5%-15%)',
  `default_validity_days` smallint NOT NULL DEFAULT '7',
  `payment_expire_hours` smallint NOT NULL DEFAULT '24',
  `city` varchar(120) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '所在城市 / 区域',
  `business_type` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '营业类型：艺术培训 / 书法书院 / 综合美育',
  `teacher_count` smallint DEFAULT NULL COMMENT '师资数量（专职老师人数）',
  `contact_name` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT '联系人姓名',
  `subscription_expire_at` datetime DEFAULT NULL,
  PRIMARY KEY (`studio_id`),
  UNIQUE KEY `user_id` (`user_id`),
  CONSTRAINT `studio_profiles_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `studio_profiles`
--

LOCK TABLES `studio_profiles` WRITE;
/*!40000 ALTER TABLE `studio_profiles` DISABLE KEYS */;
INSERT INTO `studio_profiles` VALUES (1790214661961110965,1790214033967587427,'兰亭书画',NULL,'[\"创意绘画\", \"少儿美术\", \"书法\", \"素描\", \"水彩\", \"国画\", \"动漫插画\", \"手工陶艺\"]','诗酒趁年华，小生不才，却也懂得此中真意','兰亭御湖城',NULL,NULL,'18234126896',NULL,'123456789',NULL,'暂无','[]',0.10,1,1,NULL,NULL,'2026-09-24 09:51:01','2026-09-24 10:00:19',5.00,7,24,'太原晋源','创意绘画',2,'周校长',NULL),(1790560249100996763,1790560249097925243,'木色少儿美术',NULL,'[]','少儿创意美术与材料表达课程','杭州市西湖区文三路',NULL,NULL,'0571-12345678',NULL,NULL,NULL,NULL,'[]',0.12,2,1,NULL,NULL,'2026-09-28 09:50:49','2026-09-28 10:20:51',5.00,7,24,NULL,NULL,0,NULL,NULL),(1790560249103102124,1790560249099469134,'画布成长空间',NULL,NULL,'综合艺术与儿童表达课程','深圳市南山区科技园',NULL,NULL,'0755-12345678',NULL,NULL,NULL,NULL,NULL,0.10,1,1,NULL,NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49',5.00,7,24,NULL,NULL,NULL,NULL,NULL);
/*!40000 ALTER TABLE `studio_profiles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tags`
--

DROP TABLE IF EXISTS `tags`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tags` (
  `tag_id` bigint NOT NULL,
  `name` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `scope` smallint NOT NULL DEFAULT '3' COMMENT '使用场景：1 工作室 / 2 老师 / 3 通用',
  `sort` smallint NOT NULL DEFAULT '0',
  `status` smallint NOT NULL DEFAULT '1' COMMENT '1 启用 / 0 停用',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`tag_id`),
  KEY `tags_scope_status` (`scope`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tags`
--

LOCK TABLES `tags` WRITE;
/*!40000 ALTER TABLE `tags` DISABLE KEYS */;
INSERT INTO `tags` VALUES (1789035000000000101,'创意绘画',1,1,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000102,'少儿美术',1,2,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000103,'书法',1,3,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000104,'素描',1,4,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000105,'水彩',1,5,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000106,'国画',1,6,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000107,'动漫插画',1,7,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000108,'手工陶艺',1,8,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000201,'创意美术',2,1,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000202,'综合材料',2,2,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000203,'色彩启蒙',2,3,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000204,'线描速写',2,4,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000205,'油画',2,5,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000206,'儿童绘本创作',2,6,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000301,'亲子艺术',3,1,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000302,'考级辅导',3,2,1,'2026-09-10 17:48:03','2026-09-10 17:48:03'),(1789035000000000303,'竞赛辅导',3,3,1,'2026-09-10 17:48:03','2026-09-10 17:48:03');
/*!40000 ALTER TABLE `tags` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `teacher_applications`
--

DROP TABLE IF EXISTS `teacher_applications`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `teacher_applications` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `studio_id` bigint DEFAULT NULL,
  `real_name` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `subjects` json DEFAULT NULL,
  `years` smallint DEFAULT NULL,
  `intro` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cert_no` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `portfolio` json DEFAULT NULL,
  `version` int NOT NULL DEFAULT '1',
  `status` smallint NOT NULL DEFAULT '0',
  `submitted_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reviewed_at` datetime DEFAULT NULL,
  `review_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `user_id` (`user_id`),
  KEY `studio_id` (`studio_id`),
  CONSTRAINT `teacher_applications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `teacher_applications_ibfk_2` FOREIGN KEY (`studio_id`) REFERENCES `studio_profiles` (`studio_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `teacher_applications`
--

LOCK TABLES `teacher_applications` WRITE;
/*!40000 ALTER TABLE `teacher_applications` DISABLE KEYS */;
INSERT INTO `teacher_applications` VALUES (1790214256818829835,1790214033967587427,NULL,'周钦凯','[\"硬笔书法\", \"黏土\", \"水彩\", \"国画\", \"素描\", \"油画\"]',6,'很好，又是这个时间，有趣的我，又出现了',NULL,'[]',1,2,'2026-09-24 09:44:16','2026-09-24 09:44:49','999','2026-09-24 09:44:16','2026-09-24 09:44:49'),(1790214305456364052,1790214033967587427,NULL,'周钦凯','[\"油画\", \"硬笔书法\", \"黏土\", \"水彩\", \"国画\", \"素描\"]',6,'很好，又是这个时间，有趣的我，又出现了',NULL,'[]',2,1,'2026-09-24 09:45:05','2026-09-24 09:45:26',NULL,'2026-09-24 09:45:05','2026-09-24 09:45:26'),(1790215111514207129,1790215001732915922,NULL,'周末','[\"水彩\"]',4,NULL,NULL,'[]',1,1,'2026-09-24 09:58:31','2026-09-24 09:58:55',NULL,'2026-09-24 09:58:31','2026-09-24 09:58:55'),(1790560249121777333,1790560249099469134,1790560249103102124,'李老师','[\"美术\", \"手工\"]',6,'擅长儿童创意绘画','T-2026-001',NULL,1,0,'2026-09-28 09:50:49',NULL,NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49');
/*!40000 ALTER TABLE `teacher_applications` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `teacher_profiles`
--

DROP TABLE IF EXISTS `teacher_profiles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `teacher_profiles` (
  `teacher_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `real_name` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `subjects` json DEFAULT NULL,
  `years` smallint DEFAULT NULL,
  `intro` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `cert_no` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `portfolio` json DEFAULT NULL,
  `studio_id` bigint DEFAULT NULL,
  `cert_status` smallint NOT NULL DEFAULT '0',
  `rating` decimal(2,1) NOT NULL DEFAULT '5.0',
  `student_count` int NOT NULL DEFAULT '0',
  `work_count` int NOT NULL DEFAULT '0',
  `fans` int NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`teacher_id`),
  UNIQUE KEY `user_id` (`user_id`),
  KEY `studio_id` (`studio_id`),
  CONSTRAINT `teacher_profiles_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `teacher_profiles_ibfk_2` FOREIGN KEY (`studio_id`) REFERENCES `studio_profiles` (`studio_id`) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `teacher_profiles`
--

LOCK TABLES `teacher_profiles` WRITE;
/*!40000 ALTER TABLE `teacher_profiles` DISABLE KEYS */;
INSERT INTO `teacher_profiles` VALUES (1790214326711337702,1790214033967587427,'周钦凯','[\"油画\", \"硬笔书法\", \"黏土\", \"水彩\", \"国画\", \"素描\"]',6,'很好，又是这个时间，有趣的我，又出现了',NULL,'[]',1790214661961110965,1,5.0,0,0,0,'2026-09-24 09:45:26','2026-09-24 09:53:07'),(1790215135238619835,1790215001732915922,'周末','[\"水彩\"]',4,NULL,NULL,'[]',1790214661961110965,1,5.0,0,0,0,'2026-09-24 09:58:55','2026-09-24 10:00:19'),(1790560249112557887,1790560249109167412,'陈艺文','[\"创意绘画\", \"综合材料\"]',8,'擅长 4-9 岁儿童艺术启蒙','TC-2026-1001',NULL,1790560249100996763,1,4.9,86,312,560,'2026-09-28 09:50:49','2026-09-28 09:50:49'),(1790560249113590983,1790560249110419191,'苏清','[\"水彩\", \"手工\"]',5,'擅长儿童表达与主题创作','TC-2026-1002',NULL,1790560249103102124,1,4.8,63,208,420,'2026-09-28 09:50:49','2026-09-28 09:50:49');
/*!40000 ALTER TABLE `teacher_profiles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `teacher_studio_bindings`
--

DROP TABLE IF EXISTS `teacher_studio_bindings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `teacher_studio_bindings` (
  `binding_id` bigint NOT NULL,
  `teacher_id` bigint NOT NULL,
  `studio_id` bigint NOT NULL,
  `status` smallint NOT NULL DEFAULT '1' COMMENT '1 在职绑定 / 0 已解除',
  `bound_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `released_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`binding_id`),
  UNIQUE KEY `teacher_studio_bindings_teacher_id_studio_id` (`teacher_id`,`studio_id`),
  KEY `teacher_studio_bindings_studio_id_status` (`studio_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `teacher_studio_bindings`
--

LOCK TABLES `teacher_studio_bindings` WRITE;
/*!40000 ALTER TABLE `teacher_studio_bindings` DISABLE KEYS */;
INSERT INTO `teacher_studio_bindings` VALUES (1790214787521219780,1790214326711337702,1790214661961110965,1,'2026-09-24 09:53:07',NULL,'2026-09-24 09:53:07','2026-09-24 09:53:07'),(1790215219753682405,1790215135238619835,1790214661961110965,1,'2026-09-24 10:00:19',NULL,'2026-09-24 10:00:19','2026-09-24 10:00:19');
/*!40000 ALTER TABLE `teacher_studio_bindings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `topics`
--

DROP TABLE IF EXISTS `topics`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `topics` (
  `topic_id` bigint NOT NULL,
  `name` varchar(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` smallint NOT NULL DEFAULT '1',
  `sort` smallint NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`topic_id`),
  KEY `topics_status_sort` (`status`,`sort`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `topics`
--

LOCK TABLES `topics` WRITE;
/*!40000 ALTER TABLE `topics` DISABLE KEYS */;
/*!40000 ALTER TABLE `topics` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_devices`
--

DROP TABLE IF EXISTS `user_devices`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_devices` (
  `device_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `registration_id` varchar(128) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT '极光 registration_id',
  `platform` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'android' COMMENT 'android / ios / h5',
  `status` smallint NOT NULL DEFAULT '1' COMMENT '1 有效 / 0 失效',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`device_id`),
  UNIQUE KEY `uk_user_devices_regid` (`registration_id`),
  KEY `idx_user_devices_user` (`user_id`,`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_devices`
--

LOCK TABLES `user_devices` WRITE;
/*!40000 ALTER TABLE `user_devices` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_devices` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_follows`
--

DROP TABLE IF EXISTS `user_follows`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_follows` (
  `id` bigint NOT NULL,
  `follower_id` bigint NOT NULL COMMENT '关注者',
  `followee_id` bigint NOT NULL COMMENT '被关注者',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_follows_follower_id_followee_id` (`follower_id`,`followee_id`),
  KEY `user_follows_follower_id` (`follower_id`),
  KEY `user_follows_followee_id` (`followee_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_follows`
--

LOCK TABLES `user_follows` WRITE;
/*!40000 ALTER TABLE `user_follows` DISABLE KEYS */;
/*!40000 ALTER TABLE `user_follows` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `user_roles`
--

DROP TABLE IF EXISTS `user_roles`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `user_roles` (
  `id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `role` smallint NOT NULL,
  `ref_id` bigint DEFAULT NULL,
  `verified` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_user_role` (`user_id`,`role`),
  CONSTRAINT `user_roles_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `user_roles`
--

LOCK TABLES `user_roles` WRITE;
/*!40000 ALTER TABLE `user_roles` DISABLE KEYS */;
INSERT INTO `user_roles` VALUES (1790214034045924186,1790214033967587427,1,NULL,1,'2026-09-24 09:40:34','2026-09-24 09:40:34'),(1790214326714456431,1790214033967587427,2,1790214326711337702,1,'2026-09-24 09:45:26','2026-09-24 09:45:26'),(1790214661965741171,1790214033967587427,3,1790214661961110965,1,'2026-09-24 09:51:01','2026-09-24 09:51:01'),(1790215001809505227,1790215001732915922,1,NULL,1,'2026-09-24 09:56:41','2026-09-24 09:56:41'),(1790215135239844190,1790215001732915922,2,1790215135238619835,1,'2026-09-24 09:58:55','2026-09-24 09:58:55'),(1790560249088125469,1790560249067375015,1,NULL,1,'2026-09-28 09:50:49','2026-09-28 09:50:49'),(1790560249105443487,1790560249097925243,3,1790560249100996763,1,'2026-09-28 09:50:49','2026-09-28 09:50:49'),(1790560249107830851,1790560249099469134,3,1790560249103102124,1,'2026-09-28 09:50:49','2026-09-28 09:50:49'),(1790560249115633062,1790560249109167412,2,1790560249112557887,1,'2026-09-28 09:50:49','2026-09-28 09:50:49'),(1790560249117878155,1790560249110419191,2,1790560249113590983,1,'2026-09-28 09:50:49','2026-09-28 09:50:49');
/*!40000 ALTER TABLE `user_roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `user_id` bigint NOT NULL,
  `phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `wx_unionid` varchar(64) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `password_hash` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `pay_password_hash` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `nickname` varchar(40) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `avatar` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `city` varchar(60) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `signature` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `terms_agreed_at` datetime DEFAULT NULL,
  `current_role` smallint NOT NULL DEFAULT '1',
  `status` smallint NOT NULL DEFAULT '1',
  `login_fail_count` int NOT NULL DEFAULT '0',
  `locked_until` datetime DEFAULT NULL,
  `last_login_at` datetime DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` datetime DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `phone` (`phone`),
  UNIQUE KEY `wx_unionid` (`wx_unionid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1789012617389540630,'13800000001',NULL,'$2a$10$a5WoOT0CWZnVakupncytG.Ij30u.74Z4LTuWgF.Ndr0FtlZ0mLEVS',NULL,'平台运营',NULL,'上海',NULL,'2026-09-10 11:56:57',3,1,0,NULL,'2026-09-15 17:04:01','2026-09-10 11:56:57','2026-09-15 17:04:01',NULL),(1790214033967587427,'18234126896',NULL,'$2a$10$apkO8ir/SQrrk.Ti6EVklOyTQnB17nSk6/cjDNPXmcY8SSRGGOyoe',NULL,'腾飞是也',NULL,'太原','愿你执着于理想，纯粹于当下','2026-09-24 09:40:34',1,1,0,NULL,'2026-09-28 10:02:54','2026-09-24 09:40:34','2026-09-28 10:25:33',NULL),(1790215001732915922,'19135626896',NULL,'$2a$10$6FX3PjcEDQuz5g6gdrXqp.mt51wwDvFLUk5NmF5I8yyojwcetw9N.',NULL,'腾飞小号',NULL,'太原晋源','今天是九宫格装不下的好看呀~','2026-09-24 09:56:41',2,1,0,NULL,'2026-09-24 15:42:31','2026-09-24 09:56:41','2026-09-24 15:42:31',NULL),(1790560249067375015,'13800000000',NULL,'$2a$10$79sjQoe.FE/JP2JQNxq4J.6yfSkSAP.8xFe8jHGTFZvg3gxvmzFDC',NULL,'演示家长',NULL,'杭州',NULL,'2026-09-28 09:50:49',1,1,0,NULL,NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL),(1790560249097925243,'13800000002',NULL,'$2a$10$79sjQoe.FE/JP2JQNxq4J.6yfSkSAP.8xFe8jHGTFZvg3gxvmzFDC',NULL,'朝阳艺启主理人',NULL,'北京',NULL,'2026-09-28 09:50:49',3,1,0,NULL,NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL),(1790560249099469134,'13800000003',NULL,'$2a$10$79sjQoe.FE/JP2JQNxq4J.6yfSkSAP.8xFe8jHGTFZvg3gxvmzFDC',NULL,'画布成长主理人',NULL,'深圳',NULL,'2026-09-28 09:50:49',3,1,0,NULL,NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL),(1790560249109167412,'13800000004',NULL,'$2a$10$79sjQoe.FE/JP2JQNxq4J.6yfSkSAP.8xFe8jHGTFZvg3gxvmzFDC',NULL,'陈老师',NULL,'北京',NULL,'2026-09-28 09:50:49',2,1,0,NULL,NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL),(1790560249110419191,'13800000005',NULL,'$2a$10$79sjQoe.FE/JP2JQNxq4J.6yfSkSAP.8xFe8jHGTFZvg3gxvmzFDC',NULL,'苏老师',NULL,'深圳',NULL,'2026-09-28 09:50:49',2,1,0,NULL,NULL,'2026-09-28 09:50:49','2026-09-28 09:50:49',NULL);
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `wallets`
--

DROP TABLE IF EXISTS `wallets`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `wallets` (
  `user_id` bigint NOT NULL,
  `balance` decimal(10,2) NOT NULL DEFAULT '0.00',
  `frozen` decimal(10,2) NOT NULL DEFAULT '0.00',
  `withdrawn` decimal(10,2) NOT NULL DEFAULT '0.00',
  `debt` decimal(10,2) NOT NULL DEFAULT '0.00',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `wallets`
--

LOCK TABLES `wallets` WRITE;
/*!40000 ALTER TABLE `wallets` DISABLE KEYS */;
/*!40000 ALTER TABLE `wallets` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `withdrawals`
--

DROP TABLE IF EXISTS `withdrawals`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `withdrawals` (
  `withdraw_id` bigint NOT NULL,
  `user_id` bigint NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `method` varchar(32) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'wechat',
  `account` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `status` tinyint NOT NULL DEFAULT '1' COMMENT '1申请 2处理中 3成功 4失败',
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `reviewed_at` datetime DEFAULT NULL,
  `studio_id` bigint DEFAULT NULL,
  `voucher_images` json DEFAULT NULL,
  `reject_reason` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `processed_by` bigint DEFAULT NULL,
  `processed_at` datetime DEFAULT NULL,
  `confirmed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`withdraw_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `withdrawals`
--

LOCK TABLES `withdrawals` WRITE;
/*!40000 ALTER TABLE `withdrawals` DISABLE KEYS */;
/*!40000 ALTER TABLE `withdrawals` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-09-28 10:42:50

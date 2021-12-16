CREATE TABLE `users` (
 `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
 `name` varchar(300) DEFAULT NULL,
 `start` timestamp NULL DEFAULT NULL,
 `comments` TEXT DEFAULT NULL,
 PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `posts` (
 `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
 `tg_id` int(11) DEFAULT NULL,
 `parent_id` int(11) DEFAULT NULL,
 `dataset_id` int(11) DEFAULT NULL,
 `addon_id` int(11) DEFAULT NULL,
 `date` timestamp NULL DEFAULT NULL,
 `user` int(11) DEFAULT NULL,
 `replyto` int(11) DEFAULT NULL,
 `text` LONGTEXT DEFAULT NULL,
 `photo` TEXT DEFAULT NULL,
 `media` TEXT DEFAULT NULL,
  PRIMARY KEY (`id`),
  FULLTEXT KEY `search` (`text`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `datasets` (
 `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
 `time` TIMESTAMP NULL DEFAULT NULL,
 `name` TEXT DEFAULT NULL,
  PRIMARY KEY (`id`),
  FULLTEXT KEY `search` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE USER `telegram`@`localhost` IDENTIFIED BY 'GDa4i';
GRANT ALL PRIVILEGES ON telegram.* TO `telegram`@`localhost`;

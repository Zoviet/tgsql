# Парсер дампов Telegram в SQL

## Установка и запуск

1. создать папку temp в директории, где запускается скрипт, выставить на нее права на чтения (вкл.файлы)
2. под sudo запустить install.sh - sudo bash install.sh

Подразумевается, что в папке temp расположены html файлы дампа. 

## Структура БД

- Две таблицы: users - пользователи, где поле start - первое появление пользователя в переписке

- posts - посты пользователей, где parent_id - родительский пост поста (в случае форвардинга в переписке), addon_id - уровень вложенности форвардинга - на случай форвардинга форвардного, tg_id - id поста в телеграмме, user - id пользователя

## Примеры выборок

Выбираем по посту c номером 80457 в телеграмм кому в нем отвечает пользователь: если нет прямого указания (replyto), то считаем, что отвечает на предыдущий пост

```
	SELECT DISTINCT users.name as name FROM users JOIN posts ON (posts.replyto=users.id OR (users.id=(SELECT DISTINCT user FROM posts WHERE tg_id=80457-1)));

```

Выбираем наследованные записи поста

```
	SELECT * FROM posts WHERE parent_id=80457 OR tg_id=80457 ORDER by id ASC;

```

Выбираем записи по времени

```
	SELECT posts.*,users.name as name FROM posts JOIN users ON users.id=posts.user WHERE date BETWEEN STR_TO_DATE('01-02-2019', '%Y-%m-%d') AND STR_TO_DATE('01-12-2019', '%Y-%m-%d') ORDER BY name ASC;
	
```

Полнотекстовый поиск по тексту сообщений

```
	SELECT * FROM posts WHERE MATCH(`text`) AGAINST('Fuck');
 
```

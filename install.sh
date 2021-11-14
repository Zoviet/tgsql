#!/bin/bash
seeds_install () {
	echo 'Тестируем соединение с базой данной под root';
	echo 'Введите пароль для root пользователя Mysql или нажмите ENTER, если отдельный пароль не установлен';
	if mysqladmin -u root -p ping 2>/dev/null; then
		echo 'Создаем новую базу данных telegram [ENTER для подтверждения пароля root]';
		mysqladmin -u root -p create telegram;	
		echo 'Создаем пользователя БД telegram и устанавливаем схему БД';
		mysql telegram < seeds.sql;
	else 
		echo 'Не удалось подключиться к Mysql, проверьте пароль root';
		exit;
	fi	
}

read -p "Создана ли папка temp с исходниками для парсинга и с правами 666 [Нажмите ENTER для подтверждения]? " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]
then
   echo 'Создайте папку и попробуйте снова';
   exit;
fi

echo 'Инсталляция БД';
if hash mysql 2>/dev/null; then
	seeds_install;
else
	echo 'Mysql не установлена, устанавливаем';
	apt-get install mysql;
	if hash mysql 2>/dev/null; then
		seeds_install;
	else 
		echo 'Установка Mysql не удалась, установите вручную';
		exit;
	fi	
fi
echo 'Инсталляция LUA';
if hash lua 2>/dev/null; then
	echo 'Lua уже установлена';
	lua -v
else
	echo 'Устанавливаем lua';
	apt-get install lua;
	if hash lua 2>/dev/null; then
		echo 'Успешно установлено';
		lua -v
	else
		echo 'Установка не удалась, проверьте актуальность репозиториев: apt-get update&upgrade и запустите снова';
	fi;
fi;
echo 'Инсталляция Luarocks';
if apt-get install luarocks 2>/dev/null; then
	echo 'LuaRocks успешно установлен';
else
	echo 'Установка не удалась, проверьте актуальность репозиториев: apt-get update&upgrade и запустите снова';
fi;	
echo 'Инсталляция необходимых пакетов:';
luarocks install luasec;
luarocks install lfs;
luarocks install htmlparser;
luarocks install luasql-mysql MYSQL_INCDIR=/usr/include/mysql;
echo 'Запуск парсинга:';
lua parse.lua;



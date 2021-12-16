local luasql = require "luasql.mysql"
local htmlparser = require "htmlparser"
local lfs = require("lfs")

-- настройки

local db = "telegram"
local db_user = "telegram"
local db_password = "GDa4i"
local deep = 30 -- глубина парсинга вложений к сообщениям
htmlparser_looplimit = 10000 -- лимит вложенности дампа для парсинга
local message_table = {}
local env = assert (luasql.mysql())
local con = assert (env:connect(db,db_user,db_password))

-- чтение файла

local function read_file(path, descr)
   local file = io.open(path) or error("Не могу открыть " .. descr .. " file: " .. path)
   local contents = file:read("*a") or error("Не могу прочитать " .. descr .. " from " .. path)
   file:close()
   return contents
end

-- получение строки даты

local function timeset(day,month,year)
	if year then 
		return year..'-'..month..'-'..day
	end
	return nil	
end

-- сохранение в БД

local function save_record(data) 
	local results = {}
	local user_id
	local cur = assert (con:execute("SELECT id FROM users WHERE name =('" ..data["from"].."')"))	
	cur:fetch(results)
	if results[1]==nil then 
		cur = assert (con:execute("INSERT INTO users(name, start) VALUES ('" ..data["from"].."',STR_TO_DATE('"..data["date"].."','%d.%m.%Y %H:%i:%s'))")) 
		cur = assert (con:execute("SELECT LAST_INSERT_ID()"))
		cur:fetch(results)						
	end
	user_id = results[1]
	if (data["parent_id"]) then	
		data["tg_id"] = "NULL"	
		cur = assert (con:execute("SELECT id FROM posts WHERE parent_id=" ..data["parent_id"] .. " AND addon_id=" ..data["addon_id"]))
	else 
		data["parent_id"] = "NULL"	
		cur = assert (con:execute("SELECT id FROM posts WHERE tg_id=" ..data["tg_id"]))
	end 	
	cur:fetch(results)	
	if results[2]==nil then	
		cur = assert (con:execute("INSERT INTO posts(tg_id,parent_id,addon_id,date,user,replyto,text,photo,media,dataset_id) VALUES("..data["tg_id"]..","..data["parent_id"]..","..data["addon_id"]..",STR_TO_DATE('"..data["date"].."','%d.%m.%Y %H:%i:%s'),"..user_id..","..data["replyto"]..",'"..data["text"].."','"..data["photo"].."','"..data["media"].."','"..data["dataset_id"].."')"))
	end	
end

-- получение id датасета| вставка датасета с получением id, пытаемся также получить дату из названия папки

local function get_dataset(dir)
	local results = {}	
	local year,month,day = string.match(dir, ".*(%d%d%d%d).(%d%d).(%d%d).*")
	local times = nil
	times = timeset(day,month,year)
	if not times then 
		day,month,year = string.match(dir, ".*(%d%d).(%d%d).(%d%d%d%d).*")
		times = timeset(day,month,year)
	end
	if not times then times = '2000-01-01' end
	local cursor = assert (con:execute("SELECT id FROM datasets WHERE name =('" ..dir.."')"))	
	cursor:fetch(results)
	if not results[1] then 
		cursor = assert (con:execute("INSERT INTO datasets(name, time) VALUES ('" ..dir.."',STR_TO_DATE('"..times.."','%Y-%m-%d'))")) 
		cursor = assert (con:execute("SELECT LAST_INSERT_ID()"))
		cursor:fetch(results)						
	end
	return results[1]
end

-- сохранение вложенных сообщений

local function check_addons(parent_id,dataset_id)
	local index = 1
	while index<deep and message_table[index] do		  
		message_table[index]["dataset_id"] = dataset_id
		message_table[index]["parent_id"] = parent_id
		message_table[index]["addon_id"] = index
		save_record(message_table[index])
		index = index + 1
	end
end

-- сохранение основного сообщения

local function save_sql(dataset_id) 
	local main_record = table.maxn(message_table)
	if (main_record) then				
		check_addons(main_record,dataset_id)				
		message_table[main_record]["dataset_id"] = dataset_id
		message_table[main_record]["tg_id"] = main_record
		save_record(message_table[main_record])
	end
end

-- сброс таблицы сообщения

local function reset_table(id)
	message_table[id]={}
	message_table[id]['date'] = os.date("%d.%m.%Y %H:%m:%S")
	message_table[id]['from'] = "NULL"
	message_table[id]['addon_id'] = "NULL"
	message_table[id]['replyto'] = "NULL"
	message_table[id]['text'] = "NULL"
	message_table[id]['photo'] = "NULL"
	message_table[id]['media'] = "NULL"
	message_table[id]['parent_id'] = nil
end

-- парсинг элементов сообщения

local function parse_nodes(nodes,id) 
	reset_table(id)
	for k,v in pairs(nodes) do	
		if v.nodes then		
			for i,ii in pairs(v.nodes) do		
				if ii.classes[1]=="pull_right" then message_table[id]['date'] = ii.attributes["title"] end
				if ii.classes[1]=="from_name" then 
					message_table[id]['from'] = ii:getcontent() 
					message_table[id]['from'] = string.gsub(message_table[id]['from'], "%s+", "")
				end
				if ii.classes[1]=="reply_to" then 				
					local a = ii.nodes[1].attributes["href"]			
					message_table[id]["replyto"] = string.match (a, "[#go_to_message]+(%d+)") --string.gsub(a,"#go_to_message",'' )
				end
				if ii.classes[1]=="text" then message_table[id]['text'] = ii:getcontent() end
				if ii.classes[1]=="media_wrap" then 
					local a = ii.nodes[1]
					if a.classes[1] == "photo_wrap" then			
						if a.attributes["href"] then message_table[id]["photo"] = a.attributes["href"] end
					end
					if a.classes[1] == "media" then			
						if a.attributes["href"] then message_table[id]["media"] = a.attributes["href"] end				
					end
				end
				if ii.classes[1]=="forwarded" then 									
					if (id>deep) then id=0 end
					parse_nodes(ii.parent.nodes,id+1)				
				end
			end
		end
	end
	return id;
end 

-- парсинг сообщения

local function parse_message(message,dataset_id)
	message_table = {}
	local id = message.attributes['id']		
	if not string.find(id,"-") then
		id = string.gsub(id, "message", "")	
		id = tonumber(id)			
		if (id) then	
			parse_nodes(message.nodes,id)
			save_sql(dataset_id)
		else 
			print ('Ошибка получения id сообщения из файла')
		end
	end	
	return nil
end

-- проход файлов

local function dirs(dir)
	local dataset_id = get_dataset(dir)	
	for entry in lfs.dir(dir) do
		local mode = lfs.attributes(dir.."/" .. entry, "mode")
		if mode == "file" and string.find(entry,".+\.html$") then			
			print('Обрабатывается файл: '..dir.."/"..entry)			
			local content = read_file(dir.."/" .. entry, entry)
			local root = htmlparser.parse(content)
			local messages = root:select(".message")
			for _, message in ipairs(messages) do		
				parse_message(message,dataset_id)
			end
		else		
			if (mode == "directory") and not (entry == ".") and not (entry == "..")  then
				dirs(dir.."/" .. entry) 	
			end
		end  
	end
end

-- печать DOM-дерева выбранного элемента

local function p(n)
  local space = string.rep("  ", n.level)
  local s = space .. n.name
  for k,v in pairs(n.attributes) do
    s = s .. " " .. k .. "=[[" .. v .. "]]"
  end
  print(s)
  for i,v in ipairs(n.nodes) do
    p(v)
  end
end

dirs("./temp")

con:close()
env:close()

local json = require 'cjson'
local now = os.time()
local function no_debug() end

-- This is script which checks system activity and shut it down
-- for max_inactive timeout. Just call it from cron. Once a minute
-- for example. This script stores its previous state in status_path
-- file. The state is an JSON object with next fields:
-- 	active : boolean - was system active on last check
-- 	last_active : number - date of last active status
-- 	last_check : number - date of last status check
-- 	port : number - the number of active port
-- 	torrent : string - the name of active torrent

local max_inactive = 1800
local status_path = '/tmp/activity.json'
local service_ports = { 22, 8200, 1900, 5001, 2869, 80, 433 }
-- Comment this to enable debug output
print = no_debug

-- Check is there is active transmission torrents
-- there are rpc api should be enabled on localhost and
-- transmission-remote installed.
-- return true, active_torrent_name, active_torrent_object
-- return nil
local function ask_transmission()
	cmd='transmission-remote localhost --debug -l 2>&1'
	local f = assert(io.popen(cmd, 'r'))
	local s = assert(f:read('*a'))
	f:close()
    local r='got%s+response%s+%(len%s+%d+%):%s+%-%-%-%-%-%-%-%-%s*' ..
            '(%{.*%})%s*%-%-%-%-%-%-%-%-'
	local sj = s:match(r)

	local j = json.decode(sj)
	for _, t in ipairs(j.arguments.torrents) do
		if t.leftUntilDone ~= 0 and t.status ~= 0 then
			return true, t.name, t
		end
	end
end

-- Check is there is active inbound connections on specified ports
-- port could be any type (table as array - too)
-- return true, active_port
-- return nil
local function ask_connections(port, ...)
	if not port then
		return false
	end
	if type (port) == 'table' then
		local active, p = ask_connections(unpack(port))
		if active then
			return active, p
		end
		return ask_connections(...)
	end
	local cmd=string.format("ss -lH state established '( sport = :%s )'",
        tostring(port))
	local f=assert(io.popen(cmd))
	local str=assert(f:read('*a'))
	f:close()
	if str:gsub('%s', '') ~= '' then
		return true, port
	end
	return ask_connections(...)
end

-- Shutdown machine in when it is inactive too long
local function action(status)
	if status.active or not status.last_active then
		return
	end
	if status.active ~= status.prev_active then
		return
	end
	if now - status.last_active < max_inactive then
		return
	end
	print ("Shutdown")
	os.execute("shutdown now Powering off due to inactivity")
end

-- Actually reads json object from path
-- return table
local function read_status(fpath)
	local file = io.open(fpath, "r")
	local str, status = nil, {}
	if file then
		str = file:read('*a')
		file:close()
	end
	if str then
		status = json.decode(str)
	end
	return status
end

-- Actually serialize status into the path as json
-- return table
local function write_status(fpath, status)
	local file = io.open(fpath, "w")
	local str = json.encode(status or {})
	file:write (str)
	file:close()
	print ("Written status", str)
end

-- Read old status object, form new status object and
-- write it back
local function put_status(active, port, torrent)
	local status = {}
	local prev_active
	if active then
		if port then
			print ('There is active connection on port', port)
		elseif torrent then
			print ('There is downloading torrent', torrent)
		end
		status = {
			active = true,
			port = port,
			torrent = torrent,
			last_active = now,
			last_check = now,
		}
	else
		status = read_status(status_path)
		prev_active = status.active
		status.active = false
		status.last_check = now
	end
	write_status(status_path, status)
	status.prev_active = status.active
	return status
end

-- Main function
local function check_activity()
	local active, port, torrent = ask_connections(service_ports)
	if not active then
		active, torrent = ask_transmission()
	end
	local status = put_status(active, port, torrent)
	action(status)
end

check_activity()

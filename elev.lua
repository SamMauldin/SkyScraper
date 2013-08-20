function centerPrint(sText)
	local w, h = term.getSize()
	local x, y = term.getCursorPos()
	x = math.max(math.floor((w / 2) - (#sText / 2)), 0)
	term.setCursorPos(x, y)
	term.write(sText)
end

function clear()
	term.clear()
	term.setCursorPos(1, 1)
end

function nextLine(n)
	n = n or 1
	local x, y = term.getCursorPos()
	term.setCursorPos(x, y + n)
end

-- Update
	local url = "https://raw.github.com/Sxw1212/SkyScraper/master/"
	local res = http.get(url .. "elev.lua")
	if res then
		local fh = fs.open("/startup", "w")
		fh.write(res.readAll())
		fh.close()
	else
		clear()
		centerPrint("SkyScraper")
		nextLine()
		centerPrint("Warning: Updater failed")
		sleep(1)
	end
	local res = http.get(url .. "goroutine.lua")
	if res then
		local fh = fs.open("/goroutine", "w")
		fh.write(res.readAll())
		fh.close()
	else
		clear()
		centerPrint("SkyScraper")
		nextLine()
		centerPrint("Warning: Updater failed")
		sleep(1)
	end
	
-- System test
	os.loadAPI("goroutine")

	clear()
	centerPrint("SkyScraper")
	nextLine()
	centerPrint("Elevator starting. Please wait")
	nextLine()
	centerPrint("Running System Test...")
	
	if peripheral.getType("bottom") ~= "rednet_cable" then
		nextLine()
		centerPrint("Error: No cable on bottom")
		error()
	end
	if peripheral.getType("back") ~= "modem" then
		nextLine()
		centerPrint("Error: No modem on back")
		error()
	end
	
	sleep(0.25)
	
	nextLine()
	centerPrint("System test completed, starting...")
	
	sleep(0.25)
	clear()

-- Vars
	PORT = 50101
	PREFIX = "SKYSCRAPER:"
	MODEM = peripheral.wrap("back")
	ELEVATORS = {}
	FLOORS = {"Call Elevator"}
	STAT = "CLEAR"
	SELECTED = 1
	REFRESHQUEUE = true
	MODEM.open(PORT)

-- Helper functions
	
	function refresh()
		if REFRESHQUEUE then
			REFRESHQUEUE = false
			os.queueEvent("refresh")
		end
	end
	
	function table.copy(t)
		local t2 = {}
		for k,v in pairs(t) do
			t2[k] = v
		end
		return t2
	end
	function send(msg)
		MODEM.transmit(PORT, PORT, PREFIX .. textutils.serialize(msg))
	end
	
	function recv()
		while true do
			local _, _, _, _, msg = os.pullEvent("modem_message")
			if msg:sub(1, #PREFIX) == PREFIX then
				local trans = msg:sub((#PREFIX)+1)
				return textutils.unserialize(trans)
			end
		end
	end
	
	function menuCompat()
		-- Somebody help me, I have no idea how else to do this
		local smenu = table.copy(ELEVATORS)
		table.sort(smenu, function (a,b) return (a.y > b.y) end)
		
		local sorted = {}
		local len = #smenu
		for i = 1, len do
			sorted[i] = smenu[i].name
		end
		sorted[len+1] = "Call Elevator"
		FLOORS = sorted
	end
	
	function addFloor(data)
		local contains = false
		for k, v in pairs(ELEVATORS) do
			if v.y == data.y then
				contains = true
				ELEVATORS[k].name = data.name
			end
		end
		if not contains then
			table.insert(ELEVATORS, data)
		end
		menuCompat()
	end
	
	function runmenu()
		local function render()
			clear()
			term.setCursorPos(1, 1)
			centerPrint("SkyScraper")
			nextLine()
			for k, v in pairs(FLOORS) do
				local val = v
				if SELECTED == k then
					val = "[" .. val .. "]"
				end
				centerPrint(val)
				nextLine()
			end
		end
		render()
		while true do
			local e, k = os.pullEvent("key")
			if k == keys.up then
				if SELECTED ~= 1 then
					SELECTED = SELECTED - 1
				end
			elseif k == keys.down then
				if FLOORS[SELECTED + 1] then
					SELECTED = SELECTED + 1
				end
			elseif k == keys.enter then
				local sel = FLOORS[SELECTED]
				SELECTED = 1
				return sec
			end
			render()
		end
	end

-- Config
	if not fs.exists("/sky.cfg") then
		centerPrint("SkyScraper configuration")
		term.setCursorPos(1, 2)
		local cfg = {}
		write("Y-Level: ")
		cfg.y = tonumber(read())
		write("Floor name: ")
		cfg.name = read()
		centerPrint("Saving...")
		sleep(0.25)
		
		local fh = fs.open("/sky.cfg", "w")
		fh.write(textutils.serialize(cfg))
		fh.close()
		
		nextLine()
		centerPrint("Done!")
		sleep(0.25)
		clear()
	end
	local fh = fs.open("/sky.cfg", "r")
	cfg = textutils.unserialize(fh.readAll())
	fh.close()
	if cfg.y and cfg.name then
		centerPrint("SkyScraper configuration")
		nextLine()
		centerPrint("Loaded from file!")
		sleep(0.25)
		clear()
		cfg.y = tonumber(cfg.y)
	else
		fs.delete("/sky.cfg")
		os.reboot()
	end

-- Announce
	send({ "DISCOVER", cfg })

-- Handlers
	
	function msgHandler()
		while true do
			local msg = recv()
			if msg[1] == "CALL" then
				if STAT ~= "COMING" then
					STAT = "BUSY"
					rs.setBundledOutput("bottom", colors.lime)
					sleep(1)
					rs.setBundledOutput("bottom", 0)
					refresh()
				end
			elseif msg[1] == "SENDING" then
				STAT = "BUSY"
				
				if tostring(msg[2]) == tostring(cfg.y) then
					STAT = "COMING"
					rs.setBundledOutput("bottom", colors.purple)
				end
				refresh()
			elseif msg[1] == "DISCOVER" then
				addFloor(msg[2])
				send({ "HELLO", cfg })
				refresh()
			elseif msg[1] == "HELLO" then
				addFloor(msg[2])
				refresh()
			elseif msg[1] == "CLEAR" then
				STAT = "CLEAR"
				refresh()
				rs.setBundledOutput("bottom", 0)
			elseif msg[1] == "RESET" then
				os.reboot()
			end
		end
	end
	
	function menu()
		if STAT == "CLEAR" then
			local x, y = term.getSize()
			local floor = runmenu()
			if floor == "Call Elevator" then
				send({ "CALL", cfg })
				STAT = "COMING"
				rs.setBundledOutput("bottom", colors.purple)
			else
				for k, v in pairs(ELEVATORS) do
					if v.name == floor then
						send({ "SENDING", v.y, cfg})
					end
				end
				STAT = "BUSY"
				rs.setBundledOutput("bottom", colors.lime)
			end
			refresh()
		elseif STAT == "BUSY" then
			clear()
			nextLine(7)
			centerPrint("Elevator busy, please wait")
			os.pullEvent("AReallyLongEventThatYou'dBetterNotCallOrElse...")
		elseif STAT == "COMING" then
			clear()
			nextLine(7)
			centerPrint("Elevator coming, please wait")
			while true do
				os.pullEvent("redstone")
				if colors.test(rs.getBundledInput("bottom"), colors.white) then
					STAT = "CLEAR"
					send({ "CLEAR", cfg })
					rs.setBundledOutput("bottom", 0)
					refresh()
				end
			end
		end
	end
	
	function main()
		goroutine.spawn("msgHandler", msgHandler)
		goroutine.assignEvent("msgHandler", "modem_message")
		while true do
			goroutine.spawn("menu", menu)
			
			goroutine.assignEvent("menu", "key")
			goroutine.assignEvent("menu", "redstone")
			
			os.pullEvent("refresh")
			sleep(0.1)
			REFRESHQUEUE = true
			
			goroutine.kill("menu")
		end
	end
	
	goroutine.run(main)

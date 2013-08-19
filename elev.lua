local function newmenu(tList,x,y,height)
        local function maxlen(t)
                local len=0
                for i=1,#t do
                        local curlen=string.len(type(t[i])=='table' and t[i][1] or t[i])
                        if curlen>len then len=curlen end
                end
                return len
        end
       
        local max=maxlen(tList)
        x=x or 1
        y=y or 1
        y=y-1
        height=height or #tList
        height=height+1
        local selected=1
        local scrolled=0
        local function render()
                for num,item in ipairs(tList) do
                        if num>scrolled and num<scrolled+height then
                                term.setCursorPos(x,y+num-scrolled)
                                local current=(type(item)=='table' and item[1] or item)
                                write((num==selected and '[' or ' ')..current..(num==selected and ']' or ' ')..(max-#current>0 and string.rep(' ',max-#current) or ''))
                        end
                end
        end
        while true do
                render()
                local evts={os.pullEvent('key')}
                if evts[1]=="key" and evts[2]==200 and selected>1 then
                        if selected-1<=scrolled then scrolled=scrolled-1 end
                        selected=selected-1
                elseif evts[1]=="key" and evts[2]==208 and selected<#tList then
                        selected=selected+1
                        if selected>=height+scrolled then scrolled=scrolled+1 end
                elseif evts[1]=="key" and evts[2]==28 or evts[2]==156 then
                        return (type(tList[selected])=='table' and tList[selected][2](tList[selected][1]) or tList[selected])
                end
        end
end

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
	local PORT = 50101
	local PREFIX = "SKYSCRAPER:"
	local MODEM = peripheral.wrap("back")
	local ELEVATORS = {}
	local FLOORS = {"Call Elevator"}
	local STAT = "CLEAR"
	MODEM.open(PORT)

-- Helper functions
	
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
		local menu = table.copy(ELEVATORS)
		table.sort(menu, function (a,b) return (a.y > b.y) end)
		
		local sorted = {}
		for k,v in pairs(menu) do
			table.insert(sorted, 1, v.floor)
		end
		table.insert(sorted, 1, "Call Elevator")
		FLOORS = sorted
		return FLOORS
	end
	
	function addFloor(data)
		table.insert(ELEVATORS, data)
		menuCompat()
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
				STAT = "BUSY"
				rs.setBundledOutput("bottom", colors.lime)
				sleep(0.25)
				rs.setBundledOutput("bottom", 0)
				os.queueEvent("refresh")
			elseif msg[1] == "SENDING" then
				STAT = "BUSY"
				
				if msg[2] == cfg.floor then
					STAT = "COMING"
					rs.setBundledOutput("bottom", colors.purple)
				end
				os.queueEvent("refresh")
			elseif msg[1] == "DISCOVER" then
				addFloor(msg[2])
				send({ "HELLO", cfg })
				os.queueEvent("refresh")
			elseif msg[1] == "HELLO" then
				addFloor(msg[2])
				os.queueEvent("refresh")
			elseif msg[1] == "CLEAR" then
				STAT = "CLEAR"
				os.queueEvent("refresh")
			elseif msg[1] == "RESET" then
				ELEVATORS = {}
				FLOORS = {"Call Elevator"}
				STAT = "CLEAR"
				os.queueEvent("refresh")
			end
		end
	end
	
	function menu()
		if STAT == "CLEAR" then
			local x, y = term.getSize()
			local floor = newmenu(FLOORS, 2, 2, y-1)
			if floor == "Call Elevator" then
				send({ "CALL", cfg })
				STAT = "COMING"
				rs.setBundledOutput("bottom", colors.purple)
			else
				send({ "SENDING", floor, cfg})
				STAT = "BUSY"
			end
			os.queueEvent("refresh")
		elseif STAT == "BUSY" then
			nextLine(7)
			centerPrint("Elevator busy, please wait")
			os.pullEvent("AReallyLongEventThatYou'dBetterNotCallOrElse...")
		elseif STAT == "COMING" then
			nextLine(7)
			centerPrint("Elevator coming, please wait")
			while true do
				os.pullEvent("redstone")
				if colors.test(rs.getBundledInput("bottom"), colors.white) then
					STAT = "CLEAR"
					send({ "CLEAR", cfg })
					rs.setBundledOutput("bottom", 0)
					os.queueEvent("refresh")
				end
			end
		end
	end
	
	function main()
		goroutine.spawn("msgHandler", msgHandler)
		goroutine.assignEvent("msgHandler", "modem_message")
		while true do
			clear()
			centerPrint("SkyScraper - " .. STAT)
			
			goroutine.spawn("menu", menu)
			
			goroutine.assignEvent("menu", "key")
			goroutine.assignEvent("menu", "redstone")
			
			os.pullEvent("refresh")
			
			goroutine.kill("menu")
		end
	end
	
	goroutine.run(main)

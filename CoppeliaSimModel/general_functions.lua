-- Robot fleet MAS: General functions
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

print = function(...)                       -- Prints in console
	if(console) then
		sim.auxiliaryConsolePrint(console, ...)
	end -- if
end -- print()

println = function(...)                     -- Prints in console and start a new line
	if(console) then
		sim.auxiliaryConsolePrint(console, ... .. "\n")
	end -- if
end -- println()

function defaultFloor()						-- Returns the floor to its original dimentions
	sim.setShapeBB(floorPhysicalHandle, defaultPhysicalFloorSize)
	sim.setObjectPosition(floorPhysicalHandle, -1, defaultPhysicalFloorPosition)
end -- defaultFloor

function set_insert(list, element)			-- adds the element to the list if its not in it, returns if added
	local j = 1
	local f = false
	while j <= #list and not f do			-- goes through the whole list
		if list[j] == element then
			f = true						-- stops if the element is already in the list
		else
			j = j + 1
		end -- if
	end -- while
	if not f then table.insert(list, element) end 	-- if the element is not in the list, insert it at the end
	return not f
end -- function set_insert

function round(num, numDecimalPlaces)		-- rounds the input number
	local input = type(num)
	if input == "number" then
		local mult = 10 ^ (numDecimalPlaces or 0)
		return math.floor(num * mult + 0.5) / mult
	else									-- the input value is not a number
		return input
	end -- if
end -- round()

function sign(number)						-- Returns the sign of the given number
	if number > 0 then
		return 1
	elseif number < 0 then
		return -1
	else
		return 0
	end -- if
end -- sign()

function random_sign()						-- Returns a random sign value
	local i = math.random(10)
	if i > 5 then
		return 1
	else
		return -1
	end -- if
end -- random_sign()

function random_percent()					-- Returns a random percentage
	local i = math.random(100)
	i = i/100
	return i
end -- random_percent()

function deadlock_control(Time, lock_limit)	-- Stops the simulation if a deadlock is detected
	local abort = false
	
	local stopped = true
	for i, t in ipairs(taxis) do
		stopped = stopped and (t.L1:at("CHECK") or t.L1:at("OBS"))
	end -- for
	
	if stopped then
		if locked then
			if Time - lock_init > lock_limit then
				abort = true
			else
			end -- if
		else
			locked = true
			lock_init = Time
			println(string.format("All taxis are locked. Time: %s", lock_init))	-- monitoring
		end -- if
	else
		locked = false
	end -- if
	
	return abort
end -- deadlock_control()

function CPLEX_data_extraction()			-- Prints the data required to run the optimization model in CPLEX
-- Assignments: tasks to perform in the format <seq, ini, fin>
	-- seq: sequence number (id)
	-- ini: starting port number (from the ports' list)
	-- fin: destinaiton port number (from the ports' list)
-- AgentsStart: port number of the port where agents start (unify them in just one)
-- p: number of ports
-- n: number of tasks to perform
-- Weigths: minimum distance to travel when going from one port to another
	local assignments = {}
	local agentsStart = nil
	local weights = {}
	

	println(string.format("Assignments =				// List of tasks to perform"))
	println("{")
	for i, t in ipairs(plan) do	-- for each task in the plan
		local pos = t.pos	-- {x, y, name}
		local ini = Map.patch[pos.x][pos.y].port.num
		local fin = nil
		
		if type(t.dest) == "string" then			-- When the destination is a port name
			local gates = {}
			for j, p in ipairs(Map.port) do
				if p.name == t.dest then
					fin = j
				end -- if
			end -- for
		elseif t.dest.x and t.dest.y then			-- When the destination is a set of coordinates
			local point = Map.patch[t.dest.x][t.dest.y]	-- get the destination patch
			if point.port then						-- When the passenger gives a port as destination
				fin = point.port.num
			else									-- If is not a port
				println(string.format("main:CPLEX_data_extraction| Destination is not a port: %s.", t.dest))	-- monitoring
			end -- if
		elseif t.dest[1] and t.dest[1].x and t.dest[1].y then	-- When the destination is a list of nodes
			println(string.format("main:CPLEX_data_extraction| Destination is not a single port: %s.", t.dest))	-- monitoring
		else
			println(string.format("main:CPLEX_data_extraction| Destination is not a port: %s.", t.dest))	-- monitoring
		end -- if
		println(string.format("	< %s, %s, %s >", i, ini, fin))
	end -- for
	println("};")
	println("")
	
	local start = nil
	for i, c in ipairs(execs_start) do
		agentsStart = Map.patch[c.x][c.y].gate
		start = agentsStart.num
	end -- for
	println(string.format("AgentsPort = %s;				// Agents' starting port", start))
	println("")
	
	local ports = #Map.port
	println(string.format("p = %s;					// Number of ports", ports))
	println("")
	
	local tasks = #plan
	println(string.format("n = %s;					// Number of tasks to perform", tasks))
	println("")
	
	println(string.format("Weights =					// Lenght of the arc from each node to every node"))
	println("[")
	
	local lNum = 1
	for m, pos in ipairs(Map.port) do
		local poss = {}
		if pos.patch.x and pos.patch.y then						-- If the position has coordinates
			local point = pos.patch					-- get the position patch
			if point.port then						-- If the position is a port
				poss = point.port.gate				-- Save the gates from that port
				
				if lNum == 1 then
					print("	[ ")
				else
					println(",")
					print("	[ ")
				end -- if
				
				local cNum = 1
				for n, dest in ipairs(Map.port) do
					if not(agentsStart.name == dest.name) then
					
						local dests = {}
						if dest.patch.x and dest.patch.y then		-- If the destination has coordinates
							local point = dest.patch				-- get the destination patch
							if point.port then						-- When the passenger gives a port as destination
								dests = point.port.gate				-- Save the gates from that port
							else									-- If is not a port
								println("main:CPLEX_data_extraction| The destination is not a port.")	-- monitoring
							end -- if
						else
							println("main:CPLEX_data_extraction| The destination does not have coordinates.")	-- monitoring
						end -- if

						local cost = -1								-- initial cost (invalid)
						for i, p in ipairs(poss) do					-- poss contains a list of starting gates
							for j, d in ipairs(dests) do			-- dests contains a list of destination gates
								local path = Map:minpath(p, d)		-- The path from every starting gate to every destination gate is computed
								if path[1] == p then
									if 0 > cost or cost > (#path - 1) then	-- The shortest path is chosen
										cost = #path - 1
									end -- if
								end -- if
							end -- for
						end -- for
						if cost < 0 then
							cost = math.huge
						end -- if
						
						if cNum == 1 then
							print(string.format("%s", cost))
						else
							print(string.format(",	%s", cost))
						end -- if
						cNum = cNum + 1
					else
						if cNum == 1 then
							print(string.format("0", cost))
						else
							print(string.format(",	0", cost))
						end -- if
						cNum = cNum + 1
					end -- if
				end -- for
				print(" ]")
			else									-- If is not a port
				println("main:CPLEX_data_extraction| The position is not a port.")	-- monitoring
			end -- if
		else
			println("main:CPLEX_data_extraction| The position does not have coordinates.")	-- monitoring
		end -- if
		
		lNum = lNum + 1
	end -- for
	
	println("")
	println("];")
end -- CPLEX_data_extraction()

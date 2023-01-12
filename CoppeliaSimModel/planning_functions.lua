-- Robot fleet MAS: Planning and replication functions
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

require "planned_tasks_1"
require "planned_tasks_2"
require "planned_tasks_3"
require "planned_tasks_CPLEX"

function generate_starting_conditions(amountM, amountV, timeRange, timeDistM, timeDistV, duration, posList, wander, talk)	-- generates agents initial conditions
	-- amountM:		amount of vehicles (mean)						number
	-- amountV:		amount of vehicles (variability)				number
	-- timeRange:	time range for the vehicles to appear			{number, number}
	-- timeDistM:	time distancing between vehicles (mean)			number
	-- timeDistV:	time distancing between vehicles (variability)	number
	-- duration:	how long the vehicles will remain active		number
	-- posList:		list of starting positions						{ports or names}
	-- wander:		behavior while idle								boolean
	-- talk:		can communicate or not							boolean
	local Conditions = {}
	local amount = round(amountM + amountV * random_percent() * random_sign(), 0)	-- maximum number of vehicles to generate
	local timeStart = timeRange[1]
	local timeEnd = timeRange[2]
	local T0 = timeStart + timeDistV * random_percent()		-- starting time for the first vehicle
	local n = 0
	local m = 0
	local port = {}
	local gates = {}
	local pos = {}
	local itemP = nil
	local itemG = {}
	
	local time_available = true
	while #Conditions < amount and time_available do
		if T0 < timeEnd then
			local condition = {}
			Tf = T0 + duration
			n = math.random(#posList)
			local n0 = n
			local lastP = false
			local found = false
			while not found and not lastP do
				itemP = posList[n]
				if type(itemP) == "string" then						-- positions item contains a port names
					port = Map:get_port(itemP)
				else												-- positions item contains a port
					port = itemP
				end -- if
				gates = port.gate
				m = math.random(#gates)
				local m0 = m
				local lastG = false
				
				while not found and not lastG do
					pos = gates[m]
					if pos.service[1] == nil then
						found = true
						pos.service[1] = 0
					else
						m = m + 1
						if m > #gates then
							m = 1
						end -- if
						lastG = (m0 == m)
					end -- if
				end -- while
				
				if lastG then
					n = n + 1
					if n > #posList then
						n = 1
					end -- if
					lastP = (n0 == n)
				end -- if
			end -- while
			
			if found then
				condition = {Ti = T0, Tf = Tf, x = pos.x, y = pos.y, wander = wander, talk = talk}
				table.insert(Conditions, condition)
				T0 = T0 + timeDistM + timeDistV * random_percent() * random_sign()
			else
				time_available = false
				println(string.format("main:generate_starting_conditions| Could not generate all requested vehicles"))	-- monitoring
			end -- if
		else
			time_available = false
			println(string.format("main:generate_starting_conditions| Could not generate all requested vehicles"))	-- monitoring
		end -- if
	end -- while

	println(string.format("Conditions generated:	%s", #Conditions))	-- monitoring
	for i, c in ipairs(Conditions) do
		println(string.format("Agent	%s	x:	%s	y:	%s	From time:	%s	To time: %s	Wanders:	%s	Talks:	%s", i, c.x, c.y, round(c.Ti,0), round(c.Tf,0), c.wander, c.talk))	-- monitoring
	end -- for
	
	return Conditions
end -- generate_starting_conditions()

function add_starting_location(loc)					-- adds a location for the agents to start
	local found = false
	local j = 1
	if #execs_start > 0 then
		local start = {}
		while j <= #execs_start and not found do
			start = execs_start[j]
			if start.Ti > loc.Ti then
				found = true
			else
				j = j + 1
			end -- if
		end -- while
	end -- if
	table.insert(execs_start, j, loc)
end -- add_starting_location()

function print_tasks(list)							-- Prints the tasks in the list in the format they are introduced in the system
	for i, l in ipairs(list) do
		print(string.format("local pos%s = {x = %s, y = %s, name = \"%s\"};	", i, l.pos.x, l.pos.y, l.pos.name))
		print(string.format("local task%s = {Ti = %s, Tf = %s, pos = pos%s, dest = \"%s\", priority = %s};	", i, l.Ti, l.Tf, i, l.dest, l.priority))
		println(string.format("add_task_to_plan(task%s)", i))
	end -- for
end -- print_tasks()

function generate_tasks(amountM, amountV, timeRange, timeDistM, timeDistV, duration, posList, destList, sequence, priority)	-- generates tasks to perform
	-- amountM:		amount of tasks (mean)						number
	-- amountV:		amount of tasks (variability)				number
	-- timeRange:	time range for the tasks to appear			{number, number}
	-- timeDistM:	time distancing between tasks (mean)		number
	-- timeDistV:	time distancing between tasks (variability)	number
	-- duration:	how long the task will remain active		number
	-- posList:		list of starting positions					{ports or names}
	-- destList:	list of destinations						{ports or names}
	-- sequence:	follow port sequencing or not				boolean
	-- priority:	priority value								number
	local Tasks = {}
	local amount = round(amountM + amountV * random_percent() * random_sign(), 0)	-- maximum number of tasks to generate
	local timeStart = timeRange[1]
	local timeEnd = timeRange[2]
	local T0 = timeStart + timeDistV * random_percent()		-- starting time for the first task
	local n = 0
	local Tf = math.huge
	local port = {}
	local pos = {}
	local dest = nil
	local itemP = nil
	local itemD = nil
	local destListN = {}
	
	local time_available = true
	while #Tasks < amount and time_available do
		if T0 < timeEnd then
			local task = {}
			Tf = T0 + duration
			
			n = math.random(#posList)
			itemP = posList[n]
			if type(itemP) == "string" then						-- positions item contains a port names
				if sequence then								-- port sequence must be followed
					port = Map:get_starting_port(itemP)
				else
					port = Map:get_port(itemP)
				end -- if
			else												-- positions item contains a port
				port = itemP
			end -- if
			pos = {x = port.patch.x, y = port.patch.y, name = port.name}
			
			if sequence then									-- port sequence must be followed
				n = math.random(#port.dest)
				dest = port.dest[n]
				local p = Map:get_port(dest)
				dest = p.name
				task = {Ti = T0, Tf = Tf, pos = pos, dest = dest, priority = priority}
			else
				n = math.random(#destList)
				itemD = destList[n]
				if type(itemD) == "string" then					-- destinations item contains a port name
					dest = itemD
				else											-- destinations item contains a port
					dest = itemD.name[1]
				end -- if
				task = {Ti = T0, Tf = Tf, pos = pos, dest = dest, priority = priority}
			end -- if
			table.insert(Tasks, task)
			T0 = T0 + timeDistM + timeDistV * random_percent() * random_sign()
		else
			time_available = false
			println(string.format("main:generate_tasks| Could not generate all requested tasks"))	-- monitoring
		end -- if
	end -- while
	
	return Tasks
end -- generate_tasks()

function add_task_to_plan(task)						-- adds a task to the plan keeping the time order
	local found = false
	local j = 1
	if #plan > 0 then
		local planned = {}
		while j <= #plan and not found do
			planned = plan[j]
			if planned.Ti > task.Ti then	-- planned[j].Ti > startTime
				found = true
			else
				j = j + 1
			end -- if
		end -- while
	end -- if
	table.insert(plan, j, task)
end -- add_task_to_plan()

function set_layout(layout)							-- establishes the environment layout
	if layout == "workshop" then
		local scenario = string.format("%s/Workshop.txt", folder)
		print(Map:upload(scenario))
	elseif layout == "warehouse" then
		local scenario = string.format("%s/Warehouse.txt", folder)
		print(Map:upload(scenario))
	end -- if
end -- set_layout()

function set_starting_positions(layout)				-- establishes all agents starting positions
	if layout == "workshop" then
		local loc1 = {Ti = 0, x = 36, y = 11};	add_starting_location(loc1)
		local loc2 = {Ti = 0, x = 6, y = 80};	add_starting_location(loc2)
		local loc3 = {Ti = 0, x = 17, y = 66};	add_starting_location(loc3)
		local loc4 = {Ti = 0, x = 45, y = 57};	add_starting_location(loc4)
		local loc5 = {Ti = 0, x = 30, y = 26};	add_starting_location(loc5)
	elseif layout == "warehouse" then
		local loc1 = {Ti = 0, x = 3, y = 28};	add_starting_location(loc1)
		local loc2 = {Ti = 0, x = 3, y = 27};	add_starting_location(loc2)
		local loc3 = {Ti = 0, x = 3, y = 26};	add_starting_location(loc3)
		local loc4 = {Ti = 0, x = 3, y = 25};	add_starting_location(loc4)
		local loc5 = {Ti = 0, x = 3, y = 24};	add_starting_location(loc5)
		local loc6 = {Ti = 0, x = 3, y = 23};	add_starting_location(loc6)
		local loc7 = {Ti = 0, x = 3, y = 22};	add_starting_location(loc7)
		local loc8 = {Ti = 0, x = 3, y = 21};	add_starting_location(loc8)
		local loc9 = {Ti = 0, x = 3, y = 20};	add_starting_location(loc9)
		local loc10 = {Ti = 0, x = 3, y = 19};	add_starting_location(loc10)
		local loc11 = {Ti = 0, x = 3, y = 18};	add_starting_location(loc11)
	end -- if
end -- set_starting_positions()

function set_planned_tasks(layout)					-- establishes all planned tasks
	if layout == "workshop" then
		local Tf = math.huge
		local port = Map:get_starting_port("L");	local pos = {x = port.patch.x, y = port.patch.y, name = port.name}
		local task1 = {Ti = 5, Tf = Tf, pos = pos, dest = port.dest[1], priority = port.priority};	add_task_to_plan(task1)

		port = Map:get_starting_port("C");	pos = {x = port.patch.x, y = port.patch.y, name = port.name}
		local task2 = {Ti = 618, Tf = Tf, pos = pos, dest = port.dest[1], priority = port.priority};	add_task_to_plan(task2)

		port = Map:get_starting_port("J");	pos = {x = port.patch.x, y = port.patch.y, name = port.name}
		local task3 = {Ti = 1248, Tf = Tf, pos = pos, dest = port.dest[1], priority = port.priority};	add_task_to_plan(task3)
		local task5 = {Ti = 2482, Tf = Tf, pos = pos, dest = port.dest[1], priority = port.priority};	add_task_to_plan(task5)
		local task9 = {Ti = 4993, Tf = Tf, pos = pos, dest = port.dest[1], priority = port.priority};	add_task_to_plan(task9)

		port = Map:get_starting_port("G");	pos = {x = port.patch.x, y = port.patch.y, name = port.name}
		local task4 = {Ti = 1865, Tf = Tf, pos = pos, dest = port.dest[1], priority = port.priority};	add_task_to_plan(task4)

		port = Map:get_starting_port("A");	pos = {x = port.patch.x, y = port.patch.y, name = port.name}
		local task6 = {Ti = 3094, Tf = Tf, pos = pos, dest = port.dest[1], priority = port.priority};	add_task_to_plan(task6)

		port = Map:get_starting_port("K");	pos = {x = port.patch.x, y = port.patch.y, name = port.name}
		local task7 = {Ti = 3739, Tf = Tf, pos = pos, dest = port.dest[1], priority = port.priority};	add_task_to_plan(task7)

		port = Map:get_starting_port("I");	pos = {x = port.patch.x, y = port.patch.y, name = port.name}
		local task8 = {Ti = 4298, Tf = Tf, pos = pos, dest = port.dest[1], priority = port.priority};	add_task_to_plan(task8)

		port = Map:get_starting_port("B");	pos = {x = port.patch.x, y = port.patch.y, name = port.name}
		local task10 = {Ti = 5554, Tf = Tf, pos = pos, dest = port.dest[1], priority = port.priority};	add_task_to_plan(task10)
		
	elseif layout == "warehouse" then
		set_planned_tasks_1()
		set_planned_tasks_2()
		set_planned_tasks_3()
		--set_planned_tasks_CPLEX()
	end -- if
end -- set_planned_tasks()


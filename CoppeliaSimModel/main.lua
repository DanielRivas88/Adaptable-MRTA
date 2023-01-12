-- Robot fleet MAS: Main code
-- (C) 2020-2022 Daniel Rivas Alonso & Lluís Ribas-Xirgo, UAB

-- External scripts
			  require "config"				-- Scene configuration file
			  require "general_functions"	-- General functions' definition
			  require "planning_functions"	-- Planning and replication functions' definition
			  require "results_functions"	-- Results and statistics generation functions' definition
Comm		= require "ACL"					-- Agents Communication Language
Map			= require "ScenarioMap"			-- Environment Map
Taxi		= require "TaxiAgent"			-- Taxi agent
Passenger	= require "PassAgent"			-- Passenger agent
    
-- General
console = sim.auxiliaryConsoleOpen("Model's console", 500, 0x10)
dt = sim.getSimulationTimeStep()            -- Time increment at each simulation step
simTime = 0 								-- Simulation time
calcTime = 0								-- Calculations time
int_exec = true
first = true

tag = string.format("%s_E%sT%sA%s", layout, number_of_taxis, passengersMax, passengersActive)
filename = string.format("%s/runs/%s.txt", folder, tag)

-- Floor resizing and restoration
floorDummieHandle = sim.getObject(":/ResizableFloor*")
floorPhysicalHandle = sim.getObjectChild(floorDummieHandle, 0)
defaultPhysicalFloorSize = sim.getShapeBB(floorPhysicalHandle)
defaultPhysicalFloorPosition = sim.getObjectPosition(floorPhysicalHandle, -1)

-- Functions
function cmonitor() 
	for i, p in ipairs(passengers)  do p:cmonitor() end
	for i, t in ipairs(taxis)       do t:cmonitor() end
end -- cmonitor

function create_taxi(simTime, map, comm, wander, talk)	-- creates a new taxi
	local t = nil
	local x = 0
	local y = 0
	local w = 0
	if #execs_start > 0 then
		x, y, w = map:agent_starting_patch(execs_start)
	else
		x, y, w = map:rnd_free_patch_for_taxi()	-- returns a position and orientation for the taxi
	end -- if
	if w > 0 then
		t = Taxi:new(comm, map, x, y, w, x_scale, y_scale, simTime,
					 r_width, r_long, r_height, ang_vel, speed, 
					 safe_dist, block_deadline, pick_deadline, 
					 drop_deadline, wander, talk)
	end -- if
	return t
end -- create_taxi()

function create_taxis(simTime, number_of_taxis, map, comm, wander, talk)	-- returns a list containing the specified number of taxis
	local tl = {}							-- taxi list
	local i = 0
	local ok = true
	while i < number_of_taxis and ok do		-- repeat until the taxi amount is reached
		local t = create_taxi(simTime, map, comm, wander, talk)
		if t then 
			table.insert(tl, t)				-- add the created taxi instance to the taxi list
			i = i + 1
		else 
			ok = false
			println("Cannot place all the required taxis")	-- monitoring
			errormsg = "Cannot place all the required taxis"
		end -- if
	end -- while
	return tl
end -- create_taxis()

function add_tasks(simTime, map, taxis, comm, act)	-- adds tasks to the environment
	if #plan > 0 then	-- there is at least one planned task
		while plan[1] and simTime >= plan[1].Ti do
			local planned = table.remove(plan, 1)
			local pos = planned.pos
			local dest = planned.dest
			local completion_time = planned.Tf
			local priority = planned.priority
			local p = Passenger:new(comm, map, pos, dest, simTime, o_width, o_long, o_height, cfp_deadline, auctions_limit, 
							primary_deadline, secondary_deadline, pick_deadline, load_time, unload_time, completion_time, priority)
			table.insert(passengers, p)
		end -- while	-- if
	end -- if
	
	if dynamism == "none" then						-- Does not add unplanned tasks
		-- do_nothing()
	elseif dynamism == "constant_amount" then		-- Adds all tasks needed to keep the number of active tasks constant
		while act > #passengers - passengers_arrived do -- create new passengers
			local port = {}
			if port_sequence then
				port = map:rnd_starting_port()		-- get a starting port
			else
				port = map:rnd_port()				-- get any port
			end -- if
			
			if port.patch then						-- there is a port available: create a passenger and add it to the map
				local x = port.patch.x
				local y = port.patch.y
				local pos = {x = x, y = y, name = port.name}
				local dest = nil
				
				if port_sequence then
					dest = port.dest[1]
				else
					if port_distinction == "coords" then
						while x == pos.x and y == pos.y do
							port = map:rnd_port()	-- get a port
							x = port.patch.x
							y = port.patch.y
						end -- while
					elseif port_distinction == "name" then
						while port.name == pos.name do
							port = map:rnd_port()	-- get a port
						end -- while
					elseif port_distinction == "none" then
						port = map:rnd_port()		-- get a port
					elseif port_distinction == "same" then
						-- do_nothing()
					else
						port = map:rnd_port()		-- get a port
					end -- if
					dest = port.name
				end -- if
				
				local completion_time = simTime + task_max_duration
				local priority = 1
				
				local p = Passenger:new(comm, map, pos, dest, simTime, o_width, o_long, o_height, cfp_deadline, auctions_limit,
							primary_deadline, secondary_deadline, pick_deadline, load_time, unload_time, completion_time, priority)
				table.insert(passengers, p)
			else 									-- no more free patches
				println("Cannot place all the required active passengers")	-- monitoring
				errormsg = "Cannot place all the required active passengers"
				passengersActive = #map.port
				act = #map.port
			end -- if
		end -- while
	elseif dynamism == "uniform_distribution" then	-- Randomly adds new tasks while the number Max is not reached
		if #passengers < passengersMax then			-- create new passengers
			if math.random() * 100 < prob_of_passengers then
				local port = map:rnd_port()			-- get a port
				if port.patch then					-- there is a port available: create a passanger and add it to the map
					local x = port.patch.x
					local y = port.patch.y
					local pos = {x = x, y = y, name = port.name}
					
					if port_distinction == "coords" then
						while x == pos.x and y == pos.y do
							port = map:rnd_port()	-- get a port
							x = port.patch.x
							y = port.patch.y
						end -- while
					elseif port_distinction == "name" then
						while port.name == pos.name do
							port = map:rnd_port()	-- get a port
						end -- while
					elseif port_distinction == "none" then
						port = map:rnd_port()		-- get a port
					elseif port_distinction == "same" then
						-- do_nothing()
					else
						port = map:rnd_port()		-- get a port
					end -- if
					local dest = port.name
					
					local completion_time = simTime + task_max_duration
					local priority = 1
					
					local p = Passenger:new(comm, map, pos, dest, simTime,
								o_width, o_long, o_height, cfp_deadline, 
								auctions_limit, primary_deadline, 
								secondary_deadline, pick_deadline, 
								load_time, unload_time, completion_time, priority)
					table.insert(passengers, p)
				else 								-- no more free ports
					println("Cannot place another active passenger right now")	-- monitoring
					errormsg = "Cannot place another active passenger right now"
				end -- if
			end -- if
		end -- if
	end -- if
end -- add_tasks()

function init()
	-- Delete physical elements from previous run
	local max_x = #Map.patch
	local i = 0
	while i < max_x do				
		i = i + 1
		local j = 0
		local max_y = #Map.patch[i]
		while j < max_y do			
			j = j + 1
			local p = Map.patch[i][j]
			if p.block then
				sim.removeObject(p.block)			-- remove all blocks' objects
			end -- if
		end -- while
	end -- while
	for j, p in ipairs(passengers) do
		local baseHandle = p.passHandle
		if baseHandle then
			local objectList = sim.getObjectsInTree(baseHandle)
			for i = 1, #objectList, 1 do
				sim.removeObject(objectList[i])		-- remove all passengers' objects
			end -- for
		end -- if
	end -- for
	for j, t in ipairs(taxis) do
		local baseHandle = t.carHandle
		if baseHandle then
			local objectList=sim.getObjectsInTree(baseHandle)
			for i=1,#objectList,1 do
				sim.removeObject(objectList[i])		-- remove all taxis' objects
			end -- for
		end -- if
	end -- for
	for j, o in ipairs(obstacles) do
		local baseHandle = o.carHandle
		if baseHandle then
			local objectList=sim.getObjectsInTree(baseHandle)
			for i=1,#objectList,1 do
				sim.removeObject(objectList[i])		-- remove all obstacles' objects
			end -- for
		end -- if
	end -- for
	
	-- Restart variables from previous run
	Map.patch = {}
	Map.port = {}
	taxis = {}
	obstacles = {}
	passengers = {}
	tasksCompletion = {}
	executorsOccupation = {}
	execs_start = {}
	plan = {}
	passengers_arrived = 0
	Taxi.__id = 0
	Passenger.__id = 0
	showSolution = true
	start = false
	startingSimTime = sim.getSimulationTime()
	startingSysTime = sim.getSystemTime()
	simTime = 0
	calcTime = 0
	
	set_layout(layout)				-- Establish the environment layout
	set_starting_positions(layout)	-- Establish agents starting positions
	set_planned_tasks(layout)		-- Establish planned tasks
	
	--CPLEX_data_extraction()
	
	if passengersMax > #plan then
		if dynamism == "none" then
			passengersMax = #plan
			println(string.format("main:init()| Max amount of passengers adjusted to amount of planned tasks: %s", passengersMax))	-- monitoring
		end -- if
	end -- if
	
	-- create the taxis
	taxis = create_taxis(simTime, number_of_taxis, Map, Comm, Wander, true)
	
	-- create obstacling vehicles
	obstacles = create_taxis(simTime, number_of_obstacles, Map, Comm, Wander, false)
end -- init()

function read_environment(simTime, first)
	for i, p in ipairs(passengers)	do p:read_environment(simTime, first) end
	for i, t in ipairs(taxis)		do t:read_environment(simTime, first) end
	for i, o in ipairs(obstacles)	do o:read_environment(simTime, first) end
end -- read_environment()

function read_inputs(first)
	for i, p in ipairs(passengers)	do p:read_inputs(first) end
	for i, t in ipairs(taxis)		do t:read_inputs(first) end
	for i, o in ipairs(obstacles)	do o:read_inputs(first) end
end -- read_inputs()

function step()
	for i, p in ipairs(passengers)  do p:step() end
	for i, t in ipairs(taxis)       do t:step() end
	for i, o in ipairs(obstacles)	do o:step() end
end -- step()

function write_outputs()
	for i, p in ipairs(passengers)  do p:write_outputs() end
	for i, t in ipairs(taxis)       do t:write_outputs() end
	for i, o in ipairs(obstacles)   do o:write_outputs() end
end -- write_outputs()

function write_environment(simTime)
	add_tasks(simTime, Map, taxis, Comm, passengersActive)
	
	for i, p in ipairs(passengers)  do p:write_environment() end
	for i, t in ipairs(taxis)       do t:write_environment() end
	for i, o in ipairs(obstacles)   do o:write_environment() end
	
	if showMap.changed then
		--Map:show_test()
		showMap.changed = false
	end -- if
end -- write_environment()

function update(first)
	local update_event = false
	
	for i, p in ipairs(passengers)  do
		local up = p:update(first)
		update_event = up or update_event
	end
	for i, t in ipairs(taxis) do
		local up = t:update(first)
		update_event = up or update_event
	end
	for i, o in ipairs(obstacles) do
		local up = o:update(first)
		update_event = up or update_event
	end
	
	return	update_event
end -- update()


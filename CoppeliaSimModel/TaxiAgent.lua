-- Robot fleet MAS: Executor Agent
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

local EFSSM = require "EFSSM"
local Communications = require "L4"
local Planner = require "L3"
local Wanderer = require "L2"
local Traffic = require "L1"
local Physical = require "L0"
local Drivers = require "Drivers"
local Sonar = require "SonarReader"

local Taxi = {						-- Taxi agent object
	__id = 0						-- ID number counter
	,
	tostring = function(self)		-- Returns the taxi tag (id)
		return "Taxi_"..self.__id
	end -- tostring()
	,
	create_vehicle = function(self, width, long, height, x, y, w, talk)	-- Creates a physical representation of the vehicle
		self.carHandle = sim.createPureShape(0, 8, {width / 4, long / 4, height / 4}, 1, nil)	-- Car handle
		sim.setObjectPosition(self.carHandle, -1, {x, y, height / 2})
		sim.setObjectOrientation(self.carHandle, -1, {0, 0, math.rad(w)})
		sim.setObjectSpecialProperty(self.carHandle, sim.objectspecialproperty_collidable + sim.objectspecialproperty_measurable
									+ sim.objectspecialproperty_detectable_all + sim.objectspecialproperty_renderable)
		if showTaxi.body then
			sim.setShapeColor(self.carHandle, nil, sim.colorcomponent_transparency, {0})
		else
			sim.setShapeColor(self.carHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 0})
		end -- if
		
		if showTaxi.body then
			self.carSkin = {}
			self.carSkin.body = sim.createPureShape(2, 16, {width, long, height}, 0, nil)	-- Car body skin handle
			sim.setObjectParent(self.carSkin.body, self.carHandle, false)
			
			self.carSkin.mid = sim.createPureShape(0, 16, {width, long / 4, height}, 0, nil)	-- Car middle skin handle
			sim.setObjectPosition(self.carSkin.mid, -1, {0, long / 8, 0})
			sim.setObjectParent(self.carSkin.mid, self.carHandle, false)
			
			self.carSkin.front = sim.createPureShape(0, 16, {width / 2, long / 4, height}, 0, nil)	-- Car front skin handle
			sim.setObjectPosition(self.carSkin.front, -1, {0, long * 3 / 8, 0})
			sim.setObjectParent(self.carSkin.front, self.carHandle, false)
			
			if talk then
				sim.setShapeColor(self.carSkin.body, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 0})
				sim.setShapeColor(self.carSkin.mid, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 0})
				sim.setShapeColor(self.carSkin.front, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 0})
			else
				sim.setShapeColor(self.carSkin.body, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				sim.setShapeColor(self.carSkin.mid, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				sim.setShapeColor(self.carSkin.front, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
			end -- if
			
			self.carSkin.left = sim.createPureShape(2, 16, {width / 2, long / 2, height}, 0, nil)	-- Car left skin handle
			sim.setShapeColor(self.carSkin.left, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 1})
			sim.setObjectPosition(self.carSkin.left, -1, {-width / 4, long / 4, -0.01})
			sim.setObjectParent(self.carSkin.left, self.carHandle, false)
			
			self.carSkin.right = sim.createPureShape(2, 16, {width / 2, long / 2, height}, 0, nil)	-- Car right skin handle
			sim.setShapeColor(self.carSkin.right, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 1})
			sim.setObjectPosition(self.carSkin.right, -1, {width / 4, long / 4, -0.01})
			sim.setObjectParent(self.carSkin.right, self.carHandle, false)
			
			self.carSkin.platform = sim.createPureShape(2, 16, {width / 2, long / 2, 0}, 0, nil)	-- Car platform skin handle
			sim.setShapeColor(self.carSkin.platform, nil, sim_colorcomponent_ambient_diffuse, {0.5, 0.5, 0.5})
			sim.setObjectPosition(self.carSkin.platform, -1, {0, 0, height/2 + 0.01})
			sim.setObjectParent(self.carSkin.platform, self.carHandle, false)
		end -- if
		
		-- States color monitoring
		if showTaxi.state.L4 or showTaxi.state.L3 or showTaxi.state.L2 or showTaxi.state.L1 or showTaxi.state.L0 then
			self.pollHandle = sim.createPureShape(2, 18, {o_width / 4, o_long / 4, 5 * o_height / 2}, 0, nil)	-- Poll handle
			sim.setObjectPosition(self.pollHandle, -1, {-width / 4, -long / 4, height / 2 + o_height})
			sim.setShapeColor(self.pollHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 0})
			sim.setObjectParent(self.pollHandle, self.carHandle, false)
		end -- if
		if showTaxi.state.L4 then
			self.L4.stateHandle = sim.createPureShape(2, 18, {o_width / 2, o_long / 2, o_height / 2}, 0, nil)	-- Color band handle
			sim.setObjectPosition(self.L4.stateHandle, -1, {0, 0, o_height + 0.01})
			sim.setShapeColor(self.L4.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
			sim.setObjectParent(self.L4.stateHandle, self.pollHandle, false)
		end -- if
		if showTaxi.state.L3 then
			self.L3.stateHandle = sim.createPureShape(2, 18, {o_width / 2, o_long / 2, o_height / 2}, 0, nil)	-- Color band handle
			sim.setObjectPosition(self.L3.stateHandle, -1, {0, 0, 0.01 + o_height / 2})
			sim.setShapeColor(self.L3.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
			sim.setObjectParent(self.L3.stateHandle, self.pollHandle, false)
		end -- if
		if showTaxi.state.L2 then
			self.L2.stateHandle = sim.createPureShape(2, 18, {o_width / 2, o_long / 2, o_height / 2}, 0, nil)	-- Color band handle
			sim.setObjectPosition(self.L2.stateHandle, -1, {0, 0, 0.01})
			sim.setShapeColor(self.L2.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
			sim.setObjectParent(self.L2.stateHandle, self.pollHandle, false)
		end -- if
		if showTaxi.state.L1 then
			self.L1.stateHandle = sim.createPureShape(2, 18, {o_width / 2, o_long / 2, o_height / 2}, 0, nil)	-- Color band handle
			sim.setObjectPosition(self.L1.stateHandle, -1, {0, 0,  0.01 - o_height / 2})
			sim.setShapeColor(self.L1.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
			sim.setObjectParent(self.L1.stateHandle, self.pollHandle, false)
		end -- if
		if showTaxi.state.L0 then
			self.L0.stateHandle = sim.createPureShape(2, 18, {o_width / 2, o_long / 2, o_height / 2}, 0, nil)	-- Color band handle
			sim.setObjectPosition(self.L0.stateHandle, -1, {0, 0, 0.01 - o_height})
			sim.setShapeColor(self.L0.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
			sim.setObjectParent(self.L0.stateHandle, self.pollHandle, false)
		end -- if
		
		local sensorType = sim.proximitysensor_cylinder_subtype	--sim.proximitysensor_ray_subtype
		local subType = sim.objectspecialproperty_detectable_ultrasonic -- sim.objectspecialproperty_measurable
		
		local options = nil
		if showTaxi.body then
			options = 7
		else
			options = 0
		end -- if
-- 0, explicitely handled, visible volume; 6, explicitely handled, invisible volume
-- 1, not explicitely handled, visible volume; 7, not explicitely handled, invisible volume
		
		local intParams = {}
		intParams[1] = 0			-- 1 [irrelevant] face count (volume description)
		intParams[2] = 0			-- 1 [irrelevant] face count far (volume description)
		intParams[3] = 0			-- 1 [irrelevant] subdivisions (volume description)
		intParams[4] = 0			-- 1 [irrelevant] subdivisions far (volume description)
		intParams[5] = 0			-- 1 [irrelevant] randomized detection, sample count per reading
		intParams[6] = 0			-- 1 [irrelevant] randomized detection, individual ray detection count for triggering
		intParams[7] = 0;	intParams[8] = 0	-- [0] reserved

		local floatParams = {}
		floatParams[1]  = 0.01--0	-- offset (volume description)
		floatParams[2]  = 2.0		--  range (volume description)
		floatParams[3]  = 0.1--0	-- x size (volume description)
		floatParams[4]  = 0.1--0	-- y size (volume description)
		floatParams[5]  = 0.1--0	-- x size far (volume description)
		floatParams[6]  = 0.1--0	-- y size far (volume description)
		floatParams[7]  = 0.0		-- inside gap (volume description)
		floatParams[8]  = 0.1--0	-- radius (volume description)
		floatParams[9]  = 0.1--0	-- radius far (volume description)
		floatParams[10] = 0.0		-- [irrelevant]	angle (volume description)
		floatParams[11] = 0.0		-- [irrelevant]	threshold angle for limited angle detection (see bit 6 above)
		floatParams[12] = 0.0		-- [irrelevant]	smallest detection distance (see bit 8 above)
		floatParams[13] = 0.005 	-- sensing point size
		floatParams[14] = 0.0;	floatParams[15] = 0.0	-- [0.0] reserved

		local color = nil
		self.sensorHandle = sim.createProximitySensor(sensorType, subType, options, intParams, floatParams, color)
		sim.setObjectPosition(self.sensorHandle, self.carHandle, {0, long/4, 0})
		sim.setObjectOrientation(self.sensorHandle, self.carHandle, {-math.pi/2, 0, 0})
		sim.setObjectParent(self.sensorHandle, self.carHandle, true)
	end -- create_vehicle()
	,
	new = function(self, comm, map, x, y, w, x_scale, y_scale, simTime,
					width, long, height, ang_vel, speed, safe_dist, 
					block_deadline, pick_deadline, drop_deadline, wander, talk)	-- Creates a new taxi instance
		
		local o = EFSSM:new()
		self.__id = self.__id + 1; o.__id = self.__id	-- Asigns and updates ID number
		for k in pairs(self) do o[k] = self[k] end
		
		-- Registring instance parameters
		local W = ang_vel or 30
		local V = speed or 0.25
		local Dsafe = safe_dist or (3 * V)
		local Tb = block_deadline or math.huge
		local vW = width or 0.75
		local vL = long or 0.75
		local vH = height or 0.5
		local pick_dl = pick_deadline or math.huge
		local drop_dl = drop_deadline or math.huge
		
		-- Constants
		o.comm = comm; o.comm.setup(o)	-- gives communication capacities and sets them up
		
		-- Environmental inputs
		
		-- Communication inputs
		
		-- Variables
		local patch = map.patch[x][y]
		local x_pos = x * x_scale
		local y_pos = y * y_scale
		local pos = {x_pos, y_pos}	-- Vehicle position
		
		local dir = 0
		if		w == 1 then			-- 'V' (increasing along X)
			dir = -90
		elseif	w == 2 then			-- '<' (decreasing along Y)
			dir = 180
		elseif	w == 3 then			-- "A" (decreasing along X)
			dir = 90
		elseif	w == 4 then			-- '>' (increasing along Y)
			dir = 0
		end -- if
		
		-- Communication outputs
		o.M = {}					-- Output messages list
		
		-- Environmental outputs
		
		-- Controllers
		o.L4 = Communications:new(pick_dl, drop_dl, talk)
		o.L3 = Planner:new(map)
		o.L2 = Wanderer:new(map, patch)
		o.L1 = Traffic:new(o.__id, patch, dir, Tb)
		o.L0 = Physical:new(W, V, Dsafe, Tb, dir, pos)
		o.DV = Drivers:new()
		o.SR = Sonar:new()
		
		-- Statistics
		o.count = {}
		o.data = {}
		
		-- Results recording
		o.res			= {}		-- results record structure
		o.res.e_id		= o.__id	-- executor id
		o.res.completed	= 0			-- amount of tasks completed
		o.res.lost		= 0			-- number of assignments lost
		o.res.posI		= pos		-- starting position
		o.res.posF		= {}

		o.res.initT		= simTime	-- activation time
		o.res.finT		= nil		-- deactivation time

		o.res.activeT	= nil		-- time while active
		o.res.busyT		= 0			-- time while assigned
		o.res.totalCost	= 0			-- total distance traveled by the executor
		o.res.c_range = 0			-- difference between most costly completed task and less costly one
		o.res.o_reroutes = 0		-- reroute requests due to obstacle detection
		o.res.s_reroutes = 0		-- reroute requests due to lack of service from a node
		o.res.reroutes = 0			-- total amount of reroute requests

		o.res.assign	= {}		-- structure for assigned tasks data
			-- id
			-- completed
			-- starting position (x,y)
			-- final position (x,y)
			-- starting time
			-- final time
			-- estimated cost
			-- distance traveled to pick
			-- distance traveled to drop
			-- distance traveled to complete
			-- real to estimated cost difference	-- o.res.c_diff = nil

		o.res.in_msgs	= {}		-- received messages
		o.res.out_msgs	= {}		-- sent messages
		
		-- Physical vehicle
		o:create_vehicle(vW, vL, vH, x_pos, y_pos, dir, talk)
		
		return o
	end -- new()
	,
	reset = function(self)			-- Resets the agent
		self.M = {}
				
		self.L4:reset(self)
		self.L3:reset(self)
		self.L2:reset(self)
		self.L1:reset(self)
		self.L0:reset(self)
		self.DV:reset(self)
		self.SR:reset(self)
	end -- reset()
	,
	get_pos = function(self)					-- Returns the vehicle position
		local p = sim.getObjectPosition(self.carHandle, -1)
		return p
	end -- get_pos()
	,
	get_ori = function(self)					-- Returns the vehicle position
		local ori = sim.getObjectOrientation(self.carHandle, -1)
		return ori
	end -- get_ori()
	,
	get_travel_dist = function(self)			-- Returns the traveled distance
		local d = self.L0.traveled.curr
		return d
	end -- get_travel_dist()
	,
	get_reroutes = function(self)				-- Returns the reroute requests' count
		local b = self.L1.block_reroute
		local s = self.L1.service_reroute
		return b, s
	end -- get_reroutes()
	,
	read_environment = function(self, simTime)	-- registers the environmental signals
		local pos = self:get_pos()
		local o = self:get_ori()
		local ori = round(math.deg(o[3]), 0)
		local sonarDist = self.SR:get_distance(self)
		local ping = self.SR:get_ping(self)
		
		local L4_event = self.L4:read_environment(self, simTime)
		local L3_event = self.L3:read_environment(self)
		local L2_event = self.L2:read_environment(self)
		local L1_event = self.L1:read_environment(self, simTime)
		local L0_event = self.L0:read_environment(self, simTime, pos, ori, sonarDist)
		local DV_event = self.DV:read_environment(self, simTime, ping)
		local SR_event = self.SR:read_environment(self)
	end -- read_environment()
	,
	read_inputs = function(self, first)			-- registers the input signals
		local L4cmd = self.L4:get_L4cmd()
		local L3ans = self.L3:get_L3ans()
		local L3cmd = self.L3:get_L3cmd()
		local L2ans = self.L2:get_L2ans()
		local L2cmd = self.L2:get_L2cmd()
		local L1ans = self.L1:get_L1ans()
		local L1cmd = self.L1:get_L1cmd()
		local L0ans = self.L0:get_L0ans()
		local sonarEcho = self.DV:get_echo()
		
		local L4_event = self.L4:read_inputs(self, L3ans, first)
		local L3_event = self.L3:read_inputs(self, L4cmd, L2ans, first)
		local L2_event = self.L2:read_inputs(self, L3cmd, L1ans, first)
		local L1_event = self.L1:read_inputs(self, L2cmd, L0ans, first)
		local L0_event = self.L0:read_inputs(self, L1cmd, first)
		local DV_event = self.DV:read_inputs(self, first)
		local SR_event = self.SR:read_inputs(self, sonarEcho, first)
	end -- read_inputs()
	,
	monitor = function(self)		-- Monitors the state machines constantly
		self.L4:monitor(self)
		self.L3:monitor(self)
		self.L2:monitor(self)
		self.L1:monitor(self)
		self.L0:monitor(self)
		self.DV:monitor(self)
		self.SR:monitor(self)
	end -- monitor()
	,
	cmonitor = function(self)		-- calls monitor() at certain events
		--self.L4:cmonitor(self)
		--self.L3:cmonitor(self)
		--self.L2:cmonitor(self)
		--self.L1:cmonitor(self)
		--self.L0:cmonitor(self)
		--self.DV:cmonitor(self)
		--self.SR:cmonitor(self)
	end -- cmonitor()
	,
	write_outputs = function(self)	-- Sends the communication outputs
		local L4_event = self.L4:write_outputs(self)
		local L3_event = self.L3:write_outputs(self)
		local L2_event = self.L2:write_outputs(self)
		local L1_event = self.L1:write_outputs(self)
		local L0_event = self.L0:write_outputs(self)
		local DV_event = self.DV:write_outputs(self)
		local SR_event = self.SR:write_outputs(self)
		
		self.M = self.L4:get_L4msgs()
		for i, e in ipairs(self.M) do
			if e then	-- e: {rcvr = {msg.sender}, perf = "text", cont = "text"}	-- message elements
				local p = string.format("%s_out", e.perf)
				local m = self.res.out_msgs[p]
				if m == nil then m = 0 end
				self.res.out_msgs[p] = m + 1

				local t = self.res.out_msgs["msgs_sent"]
				if t == nil then t = 0 end
				self.res.out_msgs["msgs_sent"] = t + 1

				-- Communication errors
				local p = sim.getRandom()
				local pError = 0
				if e.perf == "PRP" then
					pError = math.max(comm_error.all, comm_error.prp)
				elseif e.perf == "REF" then
					pError = math.max(comm_error.all, comm_error.ref)
				elseif e.perf == "READY" then
					pError = math.max(comm_error.all, comm_error.ready)
				elseif e.perf == "DONE" then
					pError = math.max(comm_error.all, comm_error.done)
				elseif e.perf == "FAIL" then
					pError = math.max(comm_error.all, comm_error.fail)
				end -- if

				if p >= pError then
					local m = self.comm.create_msg(self, e.rcvr, e.perf, e.cont)
					self.comm.send(m)
				end --if
			end -- if
		end -- for
		self.M = {}
	end -- write_outputs()
	,
	write_environment = function(self)	-- Modifies the physical environment
		local L4_event = self.L4:write_environment(self)
		local L3_event = self.L3:write_environment(self)
		local L2_event = self.L2:write_environment(self)
		local L1_event = self.L1:write_environment(self)
		local L0_event = self.L0:write_environment(self)
		local DV_event = self.DV:write_environment(self)
		local SR_event = self.SR:write_environment(self)
	end -- write_environment()
	,
	step = function(self)			-- Calculates the controllers next actuation
		local L4_event = self.L4:step(self)
		local L3_event = self.L3:step(self)
		local L2_event = self.L2:step(self)
		local L1_event = self.L1:step(self)
		local L0_event = self.L0:step(self)
		local DV_event = self.DV:step(self)
		local SR_event = self.SR:step(self)
	end -- step()
	,
	update = function(self, first)			-- Updates the variables values
		local update_event = false
		local L4_update_event = self.L4:update(self, first)
		local L3_update_event = self.L3:update(self, first)
		local L2_update_event = self.L2:update(self, first)
		local L1_update_event = self.L1:update(self, first)
		local L0_update_event = self.L0:update(self, first)
		local DV_update_event = self.DV:update(self, first)
		local SR_update_event = self.SR:update(self, first)
		
		return	update_event or L4_update_event or L3_update_event or
				L2_update_event or L1_update_event or L0_update_event or
				DV_update_event or SR_update_event
	end -- update()
	,
	active = function(self)			-- Returns if the agent is operating
		return  self.L4:active() and self.L3:active() and self.L2:active() and 
				self.L1:active() and self.L0:active() and self.DV:active() and 
				self.SR:active()
	end -- active()
} -- Taxi

return Taxi
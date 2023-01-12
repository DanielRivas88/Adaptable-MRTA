-- Robot fleet MAS: Executor Agent physical controller (L0)
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

local EFSSM = require "EFSSM"

L0 = {										-- L0 controller structure
	tostring = function()					-- Returns the controller name
		return "Taxi's physical controller"
	end -- tostring()
	,
	new = function(self, ang_vel, speed, safe_dist, block_deadline, ori, pos, phys_rep)	-- creates a new controller instance
		local o = EFSSM:new()
		for k in pairs(self) do o[k] = self[k] end
		
		-- Constants
		o.W = ang_vel						-- maximum angular velocity
		o.V = speed							-- maximum linear speed
		o.Dsafe = safe_dist					-- safety distance
		o.Tb = block_deadline				-- blocked timeout
		o._state_names_ = {"WAIT", "SPIN", "MOVE", "OBS"}	-- active state names (end states with no actions should not be listed here)
		
		-- Environmental inputs
		o.time = {};	o.time.prev = 0;			o.time.curr = 0				-- Current simulation time
		o.ori = {};		o.ori.prev = ori;			o.ori.curr = ori			-- Vehicle orientation
		o.pos = {};		o.pos.prev = pos;			o.pos.curr = pos			-- Vehicle position
		o.ang = {};		o.ang.prev = 0;				o.ang.curr = 0				-- Angle turned
		o.spc = {};		o.spc.prev = 0;				o.spc.curr = 0				-- Distance traveled
		o.oDist = {};	o.oDist.prev = math.huge;	o.oDist.curr = math.huge	-- Distance to nearest obstacle
		
		-- Communication inputs
		o.L1c = {};		o.L1c.prev = nil;			o.L1c.curr = nil			-- command to execute
		o.A = {};		o.A.prev = 0;				o.A.curr = 0				-- angle to turn
		o.S = {};		o.S.prev = 0;				o.S.curr = 0				-- distance to advance
		
		-- Variables
		o.state = {};	o.state.prev = "NONE";		o.state.curr = "WAIT";	o.state.next = "WAIT"	-- state
		o.turned = {};	o.turned.prev = 0;			o.turned.curr = 0;		o.turned.next = 0		-- angle turned
		o.moved = {};	o.moved.prev = 0;			o.moved.curr = 0;		o.moved.next = 0		-- distance moved
		o.aInc = {};	o.aInc.prev = 0;			o.aInc.curr = 0;		o.aInc.next = 0			-- angle increment at full angular speed
		o.sInc = {};	o.sInc.prev = 0;			o.sInc.curr = 0;		o.sInc.next = 0			-- space increment at full linear speed
		o.T0 = {};		o.T0.prev = nil;			o.T0.curr = nil;		o.T0.next = nil --math.huge	-- blockage start
		
		-- Communication outputs
		o.L0a = {};		o.L0a.prev = {};			o.L0a.curr = {};		o.L0a.next = {}			-- L0 answer
		
		-- Physical outputs
		o.da = {};		o.da.prev = 0;				o.da.curr = 0;			o.da.next = 0			-- angle increment
		o.ds = {};		o.ds.prev = 0;				o.ds.curr = 0;			o.ds.next = 0			-- position increment
				
		-- Monitoring
		
		-- Statistics
		o.count = {}
		o.count[o.state.curr] = 1
		
		-- Results recording
		o.traveled = {};	o.traveled.prev = 0;			o.traveled.curr = 0;		o.traveled.next = 0		-- distance traveled (while not free)
		
		return o
	end -- new()
	,
	reset = function(self)						-- resets the controller
		self.state.next = "WAIT"
		self.da.next = 0
		self.ds.next = 0
		self.aInc.next = 0
		self.sInc.next = 0
		self.turned.next = 0
		self.moved.next = 0
		self.T0.next = nil
		self.L0a.next = {}
		
		self.count = {}						-- statistics
		self.count[self.state.curr] = 1
		
		self.traveled.next = 0
		
		self:empty()
		self:clear_beliefs()
	end -- reset()
	,
	read_environment = function(self, parent, simTime, pos, ori, sonarDist)	-- registers the environmental inputs
		self.time.curr = simTime
		self.pos.curr = {pos[1], pos[2]}
		self.ori.curr = ori
		self.oDist.curr = sonarDist or self.oDist.curr
			
		self.ang.curr = self.ori.curr - self.ori.prev
		if self.ang.curr <= -180 then
			self.ang.curr = self.ang.curr + 360
		elseif self.ang.curr > 180 then
			self.ang.curr = self.ang.curr - 360
		end -- if
		
		local dx = self.pos.curr[1] - self.pos.prev[1]
		local dy = self.pos.curr[2] - self.pos.prev[2]
		self.spc.curr = math.sqrt((dx * dx) + (dy * dy))
		
		if dx == 0 then
			if dy == 0 then					-- '0'	(no movement)
				-- do_nothing()
			elseif dy > 0 then				-- '>'	(increasing along Y)
				if self.ori.curr < -90 or self.ori.curr > 90 then
					self.spc.curr = -self.spc.curr
				end -- if
			else							-- '<'	(decreasing along Y)
				if self.ori.curr < 90 and self.ori.curr > -90 then
					self.spc.curr = -self.spc.curr
				end -- if
			end -- if
		elseif dx > 0 then
			if dy == 0 then					-- 'V'	(increasing along X)
				if self.ori.curr > 0 then
					self.spc.curr = -self.spc.curr
				end -- if
			elseif dy > 0 then				-- 'V>'	(increasing along X and Y)
				if self.ori.curr < -135 or self.ori.curr > 45 then
					self.spc.curr = -self.spc.curr
				end -- if
			else							-- '<V'	(increasing along X and decreasing along Y)
				if self.ori.curr > -45 and self.ori.curr < 135 then
					self.spc.curr = -self.spc.curr
				end -- if
			end -- if
		else
			if dy == 0 then					-- 'A' (decreasing along X)
				if self.ori.curr < 0 then
					self.spc.curr = -self.spc.curr
				end -- if
			elseif dy > 0 then				-- 'A>' (decreasing along X and increasing along Y)
				if self.ori.curr > 135 or self.ori.curr < -45 then
					self.spc.curr = -self.spc.curr
				end -- if
			else							-- '<A' (decreasing along X and Y)
				if self.ori.curr < 45 and self.ori.curr > -135 then
					self.spc.curr = -self.spc.curr
				end -- if
			end -- if
		end -- if
	end -- read_environment()
	,
	read_inputs = function(self, parent, cmd, first)		-- registers the communication inputs
		if not first then
			self.ang.curr = 0
			self.spc.curr = 0
		end -- if
		
		if cmd[1] == "GO" then					-- GO command received
			local ang = cmd[2]
			local spc = cmd[3]
			if (ang == nil or ang < -180 or ang > 180) then
				println(string.format("Warning: Wrong angle: %s.", ang))
			elseif spc == nil or spc < 0 then
				println(string.format("Warning: Wrong distance: %s.", spc))
			else								-- All parameters are OK
				self.L1c.curr = cmd[1]
				if self:at("WAIT") then
					self.A.curr = ang
					self.S.curr = spc
				end -- if
			end -- if chain
		elseif cmd[1] == "HALT" then			-- HALT command received
			self.L1c.curr = cmd[1]
		elseif not cmd[1] then					-- No command received
			self.L1c.curr = nil
		else									-- Invalid operation code
			self.L1c.curr = nil
			println(string.format("L0| Unknown command received (%s|%s|%s. Length: %s). State: %s.", cmd[1], cmd[2], cmd[3], #cmd, self.state.curr))	-- monitoring
		end -- if
	end -- read_inputs()
	,
	monitor = function(self, parent)			-- Monitors the state machine constantly
		--println(string.format("				%s.L0| ----- VARIABLES -----", parent))
		println(string.format("				%s.L0| State: %s", parent, self.state.curr))
		--println(string.format("				%s.L0| Turned: %s", parent, self.turned.curr))
		--println(string.format("				%s.L0| Moved: %s", parent, self.moved.curr))
		--println(string.format("				%s.L0| w: %s", parent, self.aInc.curr))
		--println(string.format("				%s.L0| v: %s", parent, self.sInc.curr))
		--println(string.format("				%s.L0| begin: %s", parent, self.T0.curr))
		--println(string.format("				%s.L0| Init ori: %s", parent, self.initO.curr))
		--println(string.format("				%s.L0| Init pos: (%s,%s)", parent, self.initP.curr.x, self.initP.curr.y))
		
		--println(string.format("				%s.L0| ----- OUTPUTS -----", parent))
		--println(string.format("				%s.L0| da: %s", parent, self.da.curr))
		--println(string.format("				%s.L0| ds: %s", parent, self.ds.curr))
		--println(string.format("				%s.L0| Cmd exe: %s", parent, self.L0a.curr[1]))
		
		--[[println(string.format("				%s.L0| ----- INPUTS -----", parent))
		println(string.format("				%s.L0| Cmd: %s", parent, self.L1c.curr))
		println(string.format("				%s.L0| A: %s", parent, self.A.curr))
		println(string.format("				%s.L0| S: %s", parent, self.S.curr))
		println(string.format("				%s.L0| ObsDist: %s", parent, self.oDist.curr))
		println(string.format("				%s.L0| Orientation: %s", parent, self.ori.curr))
		println(string.format("				%s.L0| Pos: (%s,%s)", parent, self.pos.curr.x, self.pos.curr.y))--]]
	end -- monitor()
	,
	cmonitor = function(self, parent)			-- calls monitor() at certain events
		if self.state.prev ~= self.state.curr then
			self:monitor(parent)
		end -- if
	end -- cmonitor()
	,
	get_rest = function(self)					-- Returns the traveled distance
		local rest = self.S.curr - self.moved.curr
		if self:at("WAIT") then
			rest = 0
		end -- if
		
		return rest
	end -- get_rest()
	,
	get_L0ans = function(self)					-- Returns the answer from L0
		return self.L0a.curr
	end -- get_L0ans()
	,
	get_count = function(self)					-- Returns the states' count
		return self.count
	end -- get_count()
	,
	write_outputs = function(self, parent)		-- Sends the communication outputs
		-- Results recording
		if parent.L4:at("FREE") then
			self.traveled.next = 0
		elseif self:changed_to("WAIT") then	-- when a command is finished
			self.traveled.next = self.traveled.curr + self.moved.curr
		end -- if
		
		-- Graphic representation
		if showTaxi.state.L0 then
			if colorCode == "order" then
				if self:at("WAIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
				elseif self:at("SPIN") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("MOVE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 1})
				elseif self:at("OBS") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				end -- if chain
			elseif colorCode == "status" then
				if self:at("WAIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("SPIN") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("MOVE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("OBS") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				end -- if chain
			end -- if
		end -- if
	end -- write_outputs()
	,
	write_environment = function(self, parent)	-- Modifies the environment
		if self.da.curr ~= 0 then				-- When there is an angle increment:
			sim.setObjectOrientation(parent.carHandle, parent.carHandle, {0, 0, math.rad(self.da.curr)})	-- Changes the robot orientation
		end -- if
		if self.ds.curr ~= 0 then				-- When there is a distance increment:
			sim.setObjectPosition(parent.carHandle, parent.carHandle, {0, self.ds.curr, 0})	-- Changes te robot position
		end -- if
	end -- write_environment()
	,
	step = function(self, parent)				-- Calculates the controller next actuation
		if self:at("WAIT") then					-- Waiting for a command
			self.L0a.next = {}
			self.da.next = 0
			self.ds.next = 0
			self.turned.next = 0
			self.moved.next = 0
			if self.L1c.curr == "GO" then		-- GO command received
				self.state.next = "SPIN"
				if self.W == math.huge then
					self.aInc.next = self.A.curr
				else
					self.aInc.next = round(self.W * sign(self.A.curr) * dt, 2)
				end -- if
				if self.V == math.huge then
					self.sInc.next = self.S.curr
				else
					self.sInc.next = round(self.V * sign(self.S.curr) * dt, 3)
				end -- if
			elseif self.L1c.curr == "HALT" then	-- HALT command received
				self.L0a.next = {"HALTED", self.turned.curr, self.moved.curr}	-- Send a HALTED message to L1
			end -- if
		elseif self:at("SPIN") then				-- spinning 
			if self.L1c.curr == "HALT" then		-- HALT command received
				self.L0a.next = {"HALTED", self.turned.curr, self.moved.curr}	-- Send a HALTED message to L1
				self.state.next = "WAIT"
				self.da.next = 0
				self.ds.next = 0
			else
				if self.L1c.curr == "GO" then	-- GO command received
					self.L0a.next = {"BUSY"}
				end -- if
				-- 'turned'		angle turned until the previous cycle (cumulative)
				-- 'ang'		angle turned during the previous cycle
				-- 'da'			angle to turn during the current cycle
				local done = round(self.turned.curr + self.ang.curr, 2)	-- angle turned until the end of the previous cycle (cumulative)
				local expected = round(done + self.da.curr, 2)			-- angle turned until the end of the current cycle (cumulative)
				local predicted = round(expected + self.aInc.curr, 2)	-- angle turned until the end of the next cycle (cumulative)
				self.turned.next = done
				self.ds.next = 0
				
				local target = round(math.abs(self.A.curr), 0)
				if math.abs(done) == target then
					self.da.next = 0
					if self.da.curr == 0 then
						self.state.next = "MOVE"
					end -- if
				elseif math.abs(expected) == target then
					self.da.next = 0
				elseif math.abs(predicted) <= target then
					self.da.next = self.aInc.curr
				else
					self.da.next = self.A.curr - expected
				end -- if
			end -- if
		elseif self:at("MOVE") then
			if self.L1c.curr == "HALT" then		-- HALT command received
				self.L0a.next = {"HALTED", self.turned.curr, self.moved.curr}	-- Send a HALTED message to L1
				self.state.next = "WAIT"
				self.da.next = 0
				self.ds.next = 0
			else
				if self.L1c.curr == "GO" then	-- GO command received
					self.L0a.next = {"BUSY"}
				end -- if
				-- 'moved'		distance traveled until the previous cycle (cumulative)
				-- 'spc'		distance traveled during the previous cycle
				-- 'ds'			distance to travel during the current cycle
				local done = round(self.moved.curr + self.spc.curr, 3)	-- distance traveled until the end of the previous cycle (cumulative)
				local expected = round(done + self.ds.curr, 3)			-- distance traveled until the end of the current cycle (cumulative)
				local predicted = round(expected + self.sInc.curr, 3)	-- distance traveled until the end of the next cycle (cumulative)
				self.moved.next = done
				self.da.next = 0
				
				local target = round(math.abs(self.S.curr), 3)
				if math.abs(done) == target then
					self.ds.next = 0
					if self.ds.curr == 0 then
						self.state.next = "WAIT"
						self.L0a.next = {"OK"}				-- Send an OK message to L1
					end -- if
				elseif math.abs(expected) == target then
					self.ds.next = 0
					if self.oDist.curr < self.Dsafe then	-- There is an obstacle inside the safety distance
						self.state.next = "OBS"
						self.T0.next = self.time.curr		-- Save the simulation time at the start of the blockade
					end -- if
				elseif math.abs(predicted) <= target then
					if self.oDist.curr < self.Dsafe then	-- There is an obstacle inside the safety distance
						self.state.next = "OBS"
						self.ds.next = 0					-- Pause the movement
						self.T0.next = self.time.curr		-- Save the simulation time at the start of the blockade
					else									-- There is not an obstacle inside the safety distance
						self.ds.next = self.sInc.curr		-- Make a full 'ds' increment to the position
					end -- if
				else
					self.ds.next = self.S.curr - expected
				end -- if
			end -- if
		elseif self:at("OBS") then
			local done = self.moved.curr + self.spc.curr
			self.moved.next = done
		
			if self.L1c.curr == "HALT" then	-- HALT command received
				self.L0a.next = {"HALTED", self.turned.curr, self.moved.curr}	-- Send a HALTED message to L1
				self.state.next = "WAIT"
				self.da.next = 0
				self.ds.next = 0
			else
				if self.L1c.curr == "GO" then	-- GO command received
					self.L0a.next = {"BUSY"}
				end -- if
				if self.oDist.curr < self.Dsafe then	-- There is an obstacle inside the safety distance
					if (self.time.curr - self.T0.curr >= self.Tb) then	-- The timeout has been reached
						self.state.next = "WAIT"
						self.L0a.next = {"KO", self.turned.curr, self.moved.curr}	-- Send a 'KO' message to L1
						self.da.next = 0
						self.ds.next = 0
					end -- if
				else						-- There is not an obstacle inside the safety distance
					self.state.next = "MOVE"
					self.da.next = 0
					self.ds.next = 0
				end -- if
			end -- if 
		else
			println(string.format("Taxi.L0| Unknown state: %s.", self.state.curr))
		end -- if chain
	end -- step()
	,
	update = function(self, parent, first)		-- Updates the variables values
		local update_event = false
		
		if	self.L1c.prev		== self.L1c.curr
		and	self.state.prev		== self.state.curr
		and	self.T0.prev		== self.T0.curr
		and	self.L0a.prev[1]	== self.L0a.curr[1] then
			update_event = false
		else
			update_event = true
		end -- if

		self.time.prev		= self.time.curr
		self.ori.prev		= self.ori.curr
		self.pos.prev		= self.pos.curr
		self.ang.prev		= self.ang.curr
		self.spc.prev		= self.spc.curr
		self.oDist.prev		= self.oDist.curr
		self.L1c.prev		= self.L1c.curr
		self.A.prev			= self.A.curr
		self.S.prev			= self.S.curr
		self.state.prev		= self.state.curr
		self.turned.prev	= self.turned.curr
		self.moved.prev		= self.moved.curr
		self.aInc.prev		= self.aInc.curr
		self.sInc.prev		= self.sInc.curr
		self.T0.prev		= self.T0.curr
		self.L0a.prev		= self.L0a.curr
		self.da.prev		= self.da.curr
		self.ds.prev		= self.ds.curr
		self.traveled.prev	= self.traveled.curr
		
		self.state.curr		= self.state.next
		self.turned.curr	= self.turned.next
		self.moved.curr		= self.moved.next
		self.aInc.curr 		= self.aInc.next
		self.sInc.curr		= self.sInc.next
		self.T0.curr		= self.T0.next
		self.L0a.curr		= self.L0a.next
		self.da.curr 		= self.da.next
		self.ds.curr		= self.ds.next
		self.traveled.curr	= self.traveled.next

		-- Update immediate values: I = f(S+, V+)
		-- Accounting
		if first then
			local c = self.count[self.state.curr]
			if c == nil then c = 0 end
			self.count[self.state.curr] = c + 1
		end -- if
		
		return update_event
	end -- update()
} -- L0

return L0

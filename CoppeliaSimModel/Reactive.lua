-- Robot fleet MAS: Passenger Agent Reactive controller (Rct)
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

local EFSSM = require "EFSSM"

Reactive = {
	tostring = function()
		return "Passenger's reactive controller"
	end -- tostring()
	,
	new = function(self, map, pos, id, max_auctions, primary_auctions_wait, secondary_auctions_wait, 
					pick_up_wait, load_time, unload_time)
		local o = EFSSM:new()
		for k in pairs(self) do o[k] = self[k] end
		
		-- Constants
		o.map = map
		o.id = id
		o.Amax = max_auctions
		o.Trc = primary_auctions_wait
		o.Tra = secondary_auctions_wait
		o.Tpu = pick_up_wait
		o.Tld = load_time
		o.Tul = unload_time
		o._state_names_ = { "INIT", "WAIT", "GET_IN", "TRAVEL",
							"GET_OUT", "NO_TAXI", "RESTART"}
		
		-- Environmental inputs
		o.time = {};	o.time.prev = 0;		o.time.curr = 0		-- Current simulation time
		
		-- Graphical representation
		o.here = {};	o.here.prev = {};		o.here.curr = {}
		o.there = {};	o.there.prev = {};		o.there.curr = {}
		
		-- Communication inputs
		o.Da = {};		o.Da.prev = nil;		o.Da.curr = nil		-- Answer from Deliberative
		
		-- Variables
		o.state = {};	o.state.prev = "NONE";	o.state.curr = "INIT";	o.state.next = "INIT"
		o.x = {};		o.x.prev = nil;			o.x.curr = pos.x;		o.x.next = pos.x
		o.y = {};		o.y.prev = nil;			o.y.curr = pos.y;		o.y.next = pos.y
		o.aucs = {};	o.aucs.prev = nil;		o.aucs.curr = 0;		o.aucs.next = 0
		o.T0 = {};		o.T0.prev = 0;			o.T0.curr = 0;			o.T0.next = 0
		o.T1 = {};		o.T1.prev = nil;		o.T1.curr = 0;			o.T1.next = 0
		
		-- Communication outputs
		o.Rc = {};		o.Rc.prev = {};			o.Rc.curr = {};			o.Rc.next = {}	-- Command to Deliberative
		
		-- Environmental outputs
		local t = {x = o.x.curr, y = o.y.curr, id = o.id}
		o.map:add_person(t)
		
		-- Graphical representation
		o.dx = {};		o.dx.prev = nil;		o.dx.curr = 0;			o.dx.next = 0		-- x increment
		o.dy = {};		o.dy.prev = nil;		o.dy.curr = 0;			o.dy.next = 0		-- y increment
		o.dz = {};		o.dz.prev = nil;		o.dz.curr = 0;			o.dz.next = 0		-- z increment
		
		-- Monitoring
		
		-- Statistics
		o.count = {}
		o.count[o.state.curr] = 1
		
		return o
	end -- new()
	,
	reset = function(self, parent)
		self.state.next = "INIT"
		self.aucs.next = 0
		self.T0.next = 0
		self.T1.next = 0
		self.Rc.next = {}
		
		self.count = {}
		self.count[self.state.curr] = 1
		
		self:empty()
		self:clear_beliefs()
		return true
	end -- reset()
	,
	read_environment = function(self, parent, simTime)	-- registers the environmental inputs
		self.time.curr = simTime
	end -- read_environment()
	,
	read_inputs = function(self, parent, ans, first)		-- registers the communication inputs
		if ans[1] == "Taken" then							-- Order assigned
			self.Da.curr = ans[1]
			if not self:at("INIT") and not (self:at("RESTART") and announce) then
				println(string.format("%s.Rct| %s answer received while at %s.", parent, ans[1], self.state.curr))	-- monitoring
			end -- if
		elseif ans[1] == "Untaken" then						-- Order unassigned
			self.Da.curr = ans[1]
			if self:at("WAIT") or self:at("GET_IN") or self:at("TRAVEL") then
			else
				println(string.format("%s.Rct| %s answer received while at %s.", parent, ans[1], self.state.curr))	-- monitoring
			end -- if chain
		elseif ans[1] == "Arrived" then						-- Vehicle arrived to a location
			self.Da.curr = ans[1]
			if self:at("INIT") or self:at("WAIT") then
				-- Graphical representation
				if showPass.handling then
					local loc = sim.getObjectPosition(parent.passHandle, -1) 
					self.here.curr[1] = round(loc[1], 2)
					self.here.curr[2] = round(loc[2], 2)
					self.here.curr[3] = round(loc[3], 2)
					loc = parent:get_taxi_pos()
					self.there.curr[1] = round(loc[1], 2)
					self.there.curr[2] = round(loc[2], 2)
					self.there.curr[3] = r_height + o_height / 2	-- round(2*loc[3], 2) + o_height/2
					local movX = self.there.curr[1] - self.here.curr[1]
					local movY = self.there.curr[2] - self.here.curr[2]
					local movZ = self.there.curr[3] - self.here.curr[3]
					self.dx.next = movX * dt / self.Tld
					self.dy.next = movY * dt / self.Tld
					self.dz.next = movZ * dt / self.Tld
				end -- if
			elseif self:at("TRAVEL") then
				-- Graphical representation
				local loc = sim.getObjectPosition(parent.passHandle, -1) 
				self.here.curr[1] = round(loc[1], 2)
				self.here.curr[2] = round(loc[2], 2)
				self.here.curr[3] = round(loc[3], 4)
				for i, p in ipairs(self.map.port) do
					if p.name == parent.Dlb.dest.curr then
						local x = p.patch.x
						local y = p.patch.y
						local z = b_height + o_height / 2
						local xDist = x - self.here.curr[1]
						local yDist = y - self.here.curr[2]
						local zDist = z - self.here.curr[3]
						if math.abs(xDist) <= 1.5 and math.abs(yDist) <= 1.5 then
							self.there.curr = {x, y, z}
						end
					end -- if
				end -- for
				if showPass.handling then
					local movX = self.there.curr[1] - self.here.curr[1]
					local movY = self.there.curr[2] - self.here.curr[2]
					local movZ = self.there.curr[3] - self.here.curr[3]
					self.dx.next = movX * dt / self.Tul
					self.dy.next = movY * dt / self.Tul
					self.dz.next = movZ * dt / self.Tul
				end -- if
			else
				println(string.format("%s.Rct| %s answer received while at %s.", parent, ans[1], self.state.curr))	-- monitoring
			end -- if chain
		elseif ans[1] == "No bids" then						-- No transporters availables
			self.Da.curr = ans[1]
			if not self:at("INIT") and not self:at("WAIT") and
			   not (self:at("RESTART") and announce) then
			
				println(string.format("%s.Rct| %s answer received while at %s.", parent, ans[1], self.state.curr))	-- monitoring
			end -- if chain
		elseif not ans[1] then								-- No answer received
			self.Da.curr = nil
		else												-- Invalid operation code
			self.Da.curr = nil
			println(string.format("%s.Rct|Unknown answer received %s. State: %s.", parent, ans[1], self.state.curr))	-- monitoring
		end -- if
	end -- read_inputs()
	,
	monitor = function(self, parent)
		--println(string.format("							%s.Rct| ----- VARIABLES -----", parent))
		println(string.format("							%s.Rct| State: %s.",	parent, self.state.curr))
		--println(string.format("							%s.Rct| Auctions: %s.", parent, self.aucs.curr))
		--println(string.format("							%s.Rct| T0: %s.",	parent, self.T0.curr))
		--println(string.format("							%s.Rct| T1: %s.",	parent, self.T1.curr))
		--println(string.format("							%s.Rct| Here: (%s,%s,%s)", parent, self.here.curr[1], self.here.curr[2], self.here.curr[3]))
		--println(string.format("							%s.Rct| There: (%s,%s,%s)", parent, self.there.curr[1], self.there.curr[2], self.there.curr[3]))
		--println(string.format("							%s.Rct| dx: %s. dy: %s. dz: %s", parent, self.dx.curr, self.dy.curr, self.dz.curr))
		
		--println(string.format("							%s.Rct| ----- OUTPUTS -----", parent))
		--println(string.format("							%s.Rct| Rc: %s.",	parent, self.Rc.curr))
		
		--println(string.format(							"%s.Rct| ----- INPUTS -----", parent))
		--println(string.format("							%s.Rct| Da: %s.", parent, self.Da.curr))
	end -- monitor()
	,
	cmonitor = function(self, parent)					-- Calls monitor() when the machine changes to a different state
		if self.state.prev ~= self.state.curr then
			self:monitor(parent)
		end -- if
	end -- cmonitor()
	,
	get_Rcmd = function(self)							-- Returns the command from Rct
		return self.Rc.curr
	end -- get_Rcmd()
	,
	get_count = function(self)					-- Returns the states' count
		return self.count
	end -- get_count()
	,
	write_outputs = function(self, parent)
		-- Graphical representation
		if showPass.state.delib then
			if colorCode == "order" then
				if self:at("INIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
				elseif self:at("NO_TAXI") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("RESTART") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 1})
				elseif self:at("WAIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("GET_IN") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 1})
				elseif self:at("TRAVEL") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				elseif self:at("GET_OUT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 1})
				elseif self:at("IDLE") then
					if self.stateHandle then
						sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 0})
					end -- if
				end -- if chain
			elseif colorCode == "status" then
				if self:at("INIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
				elseif self:at("NO_TAXI") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("RESTART") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("WAIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				elseif self:at("GET_IN") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("TRAVEL") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				elseif self:at("GET_OUT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("IDLE") then
					if self.stateHandle then
						sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 0})
					end -- if
				end -- if chain
			end -- if
		end -- if
	end -- write_outputs()
	,
	write_environment = function(self, parent)			-- Modifies the physical environment
		-- Graphical representation
		if showPass.body then
			if self.state.curr == "IDLE" and self.state.prev == "NO_TAXI" then
				sim.setObjectPosition(parent.passHandle, -1, {-1, -1, o_height / 2})
			elseif self.state.curr == "TRAVEL" then
				local p = parent:get_taxi_pos()
				sim.setObjectPosition(parent.passHandle, -1, {p[1], p[2], r_height + o_height / 2})
			elseif self.state.curr == "IDLE" and self.state.prev == "GET_OUT" then
				sim.setObjectPosition(parent.passHandle, -1, {self.there.curr[1], self.there.curr[2], o_height / 2})
			end -- if
		end -- if
		
		if showPass.handling then
			if self:at("GET_IN") then
				local p = sim.getObjectPosition(parent.passHandle, -1)
				p[1] = p[1] + self.dx.curr
				p[2] = p[2] + self.dy.curr
				p[3] = p[3] + self.dz.curr
				sim.setObjectPosition(parent.passHandle, -1, p)
			elseif self:at("GET_OUT") then
				local p = sim.getObjectPosition(parent.passHandle, -1)
				p[1] = p[1] + self.dx.curr
				p[2] = p[2] + self.dy.curr
				p[3] = p[3] + self.dz.curr
				sim.setObjectPosition(parent.passHandle, -1, p)
			end -- if chain
		end -- if
	end -- write_environment()
	,
	step = function(self, parent)
		if self:at("INIT") then
			self.Rc.next = {}
			if self.Da.curr == "Taken" then
				self.aucs.next = self.aucs.curr + 1
				self.T0.next = self.time.curr
				self.T1.next = self.time.curr
				self:push(self.state.curr)
				self.state.next = "WAIT"
			elseif self.Da.curr == "No bids" then
				self.aucs.next = self.aucs.curr + 1
				self:push(self.state.curr)
				self.state.next = "NO_TAXI"
			elseif self.Da.curr == "Arrived" then
				self.T0.next = self.time.curr
				self:push(self.state.curr)
				self.state.next = "GET_IN"
			end -- if
		elseif self:at("WAIT") then 
			self.Rc.next = {}
			if self.Da.curr == "Untaken" then
				self.state.next = self:pop()
			elseif self.Da.curr == "No bids" then
				self.state.next = "NO_TAXI"
			elseif self.Da.curr == "Arrived" then
				self.T0.next = self.time.curr
				self.state.next = "GET_IN"
			elseif self.time.curr - self.T1.curr >= self.Tpu then
				self.Rc.next = {"Call"}
				self.state.next = self:pop()
			elseif self.time.curr - self.T0.curr >= self.Tra then
				self.Rc.next = {"Re-call"}
				self.T0.next = self.time.curr
			end -- if
		elseif self:at("GET_IN") then
			self.Rc.next = {}
			if self.Da.curr == "Untaken" then
				self.T0.next = self.time.curr
				self.state.next = "GET_OUT"
			elseif self.time.curr - self.T0.curr >= self.Tld then
				self.Rc.next = {"On"}
				self.state.next = "TRAVEL"
			end -- if
		elseif self:at("TRAVEL") then
			self.Rc.next = {}
			if self.Da.curr == "Untaken" then
				self.T0.next = self.time.curr
				self.state.next = "GET_OUT"
			elseif self.Da.curr == "Arrived" then
				self.T0.next = self.time.curr
				self:push("IDLE")
				self.state.next = "GET_OUT"
			end -- if
		elseif self:at("GET_OUT") then
			self.Rc.next = {}
			if self.time.curr - self.T0.curr >= self.Tul then
				self.Rc.next = {"Off"}
				self.state.next = self:pop()
				
				parent.res.dest.x = self.there.curr[1]
				parent.res.dest.y = self.there.curr[2]

				if port_sequence then
					local startTime = self.time.curr + sequence_time_separation
					local endTime = startTime + task_max_duration
					local destX = self.there.curr[1]
					local destY = self.there.curr[2]
					local port = self.map.patch[destX][destY].port
					if #port.dest > 0 then
						local pos = {x = self.there.curr[1], y = self.there.curr[2], name = port.name}
						local dest = port.dest[1]
						local pri = port.priority
						local task = {Ti = startTime, Tf = endTime, pos = pos, dest = dest, priority = pri}
						add_task_to_plan(task)
					end -- if
				end -- if
		
				if task_return then
					local startTime = self.time.curr + sequence_time_separation
					local endTime = startTime + task_max_duration
					local group = string.match(parent.Dlb.dest.curr, "(%a+)%d+")
					if group == "Pick" then
						local p = self.map:get_port(parent.Dlb.dest.curr)
						local pos = {x = p.patch.x, y = p.patch.y, name = p.name}
						local dest = parent.Dlb.pos.curr.name
						local pri = parent.res.priority
						local task = {Ti = startTime, Tf = endTime, pos = pos, dest = dest, priority = pri}
						add_task_to_plan(task)
					end 
				end -- if

			end -- if
		elseif self:at("NO_TAXI") then
			if self.aucs.curr < self.Amax then
				self.T0.next = self.time.curr
				self.Rc.next = {}
				self.state.next = "RESTART"
			else
				self.Rc.next = {"Stop"}
				self.state.next = "IDLE"
			end -- if
		elseif self:at("RESTART") then
			self.Rc.next = {}
			
			if self.Da.curr == "Taken" then
				self.aucs.next = self.aucs.curr + 1
				self.T0.next = self.time.curr
				self.T1.next = self.time.curr
				self.state.next = "WAIT"
			elseif self.time.curr - self.T0.curr >= self.Trc then
				self.Rc.next = {"Call"}
				self.state.next = self:pop()
			end -- if
		elseif self:at("IDLE") then
			self.Rc.next = {}
		else -- Unknown state
			println(string.format("%s.Rct| Unknown state: %s.", parent, self.state.curr))
		end -- if chain
	end -- step()
	,
	update = function(self, parent, first)						-- Update pending assignments to variables: S, V = S+, V+
		local update_event = false
		
		if self:at("GET_IN") then
			if self.time.curr - self.T0.curr >= self.Tld then
				local t = {x = self.x.curr, y = self.y.curr, id = self.id}
				self.map:remove_person(t)
			end -- if
		end -- if
		
		if	self.Da.prev	== self.Da.curr
		and	self.state.prev	== self.state.curr
		and self.x.prev		== self.x.curr
		and self.y.prev		== self.y.curr
		and	self.aucs.prev	== self.aucs.curr
		and	self.T0.prev	== self.T0.curr
		and	self.T1.prev	== self.T1.curr
		and	self.Rc.prev[1]	== self.Rc.curr[1] then -- self.Rc.prev	== self.Rc.curr
			update_event = false
		else
			update_event = true
		end -- if
		
		self.time.prev	= self.time.curr
		self.here.prev	= self.here.curr
		self.there.prev	= self.there.curr
		self.Da.prev	= self.Da.curr
		self.state.prev	= self.state.curr
		self.x.prev		= self.x.curr
		self.y.prev		= self.y.curr
		self.aucs.prev	= self.aucs.curr
		self.T0.prev	= self.T0.curr
		self.T1.prev	= self.T1.curr
		self.Rc.prev	= self.Rc.curr
		self.dx.prev	= self.dx.curr
		self.dy.prev	= self.dy.curr
		self.dz.prev	= self.dz.curr
		
		self.state.curr	= self.state.next
		self.x.curr		= self.x.next
		self.y.curr		= self.y.next
		self.aucs.curr	= self.aucs.next
		self.T0.curr	= self.T0.next
		self.T1.curr	= self.T1.next
		self.Rc.curr	= self.Rc.next
		self.dx.curr	= self.dx.next
		self.dy.curr	= self.dy.next
		self.dz.curr	= self.dz.next
		
		-- Update immediate values: I = f(S+, V+)
		-- Accounting
		if first then
			local c = self.count[self.state.curr]
			if c == nil then c = 0 end
			self.count[self.state.curr] = c + 1
		end -- if
		
		return update_event
	end -- update()
} -- Reactive

return Reactive

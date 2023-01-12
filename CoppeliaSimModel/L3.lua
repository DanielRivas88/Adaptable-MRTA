-- Robot fleet MAS: Executor Agent Path planner controller (L3)
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

local EFSSM = require "EFSSM"

L3 = {													-- L3 controller structure
	tostring = function()
		return "Taxi's path planner"
	end
	,
	new = function(self, map)
		local o = EFSSM:new()
		for k in pairs(self) do o[k] = self[k] end
	
		-- Constants
		o.map = map
		o._state_names_ = {"FREE", "SEND", "EXE", "BUSY"}	-- active state names (end states with no actions should not be listed here)
    
		-- Environmental inputs
		
		-- Communication inputs
		o.L4c = {};		o.L4c.prev = nil;	o.L4c.curr = nil
		o.goal = {};	o.goal.prev = {};	o.goal.curr = {}	-- List of possible destinations
		o.L2a = {};		o.L2a.prev = nil;	o.L2a.curr = nil
		o.start = {}	o.start.prev = {};	o.start.curr = {}
		o.avoid = {}	o.avoid.prev = {};	o.avoid.curr = {}
		
		-- Variables
		o.state = {};	o.state.prev = "NONE";	o.state.curr = "FREE";	o.state.next = "FREE"	
		o.path = {};	o.path.prev = {};		o.path.curr = {};		o.path.next = {}
		
		-- Communication outputs
		o.L3a = {};		o.L3a.prev = {};		o.L3a.curr = {};			o.L3a.next = {}
		o.L3c = {};		o.L3c.prev = {};		o.L3c.curr = {};			o.L3c.next = {}
		
		-- Environmental outputs
		
		-- Graphic representation
		o.marker = {}		-- group of markers to show the calculated path
		
		-- Monitoring
		
		-- Statistics
		o.count = {}
		o.count[o.state.curr] = 1

		return o
	end -- new
	,
	reset = function(self, parent)
		self.state.next = "FREE"
		self.path.next = {}
		
		self.count = {}
		self.count[self.state.curr] = 1
		
		self:empty()
		self:clear_beliefs()
		return true
	end -- reset()
	,
	read_environment = function(self, parent)		-- registers the environmental signals
		
	end -- read_environment()
	,
	read_inputs = function(self, parent, cmd, ans, first)	-- registers the communication inputs
		if cmd[1] == "GO" then
			self.L4c.curr = cmd[1]
			if self:at("FREE") or self:at("BUSY") then
				local data = cmd[2]
				if type(data) == "string" then				-- When the passenger gives a port name as destination
					local gates = {}
					for i, p in ipairs(self.map.port) do
						if p.name == data then
							for j, g in ipairs(p.gate) do
								table.insert(gates, g)		-- Save the gates from all the ports with that name
							end -- for
						end -- if
					end -- for
					self.goal.curr = gates
				elseif data.x and data.y then				-- When the passenger gives coordinates
					local point = self.map.patch[data.x][data.y]	-- get the destination patch
					if point.port then						-- When the passenger gives a port as destination
						self.goal.curr = point.port.gate			-- Save the gates from that port
					else									-- If is not a port
						self.goal.curr = {data}				-- Save the patch
					end -- if
				elseif data[1] and data[1].x and data[1].y then	-- When the passenger gives a list of nodes
					self.goal.curr = data					-- Save the list
				elseif #data == 0 then						-- No destination
					self.goal.curr = {}	
				else										-- Unknown
					self.goal.curr = {}	
					println(string.format("%s.L3.read_inputs| Destination is unknown: %s.", parent, data))	-- monitoring
					println(string.format("%s.L3.read_inputs| Destination is unknown. First element: %s.", parent, data[1]))	-- monitoring
				end -- if
				self.start.curr = parent.L2:get_start()
				self.avoid.curr = {}
			else
				println(string.format("%s.L3| %s command received while at %s.", parent, cmd[1], self.state.curr))	-- monitoring
			end --if
		elseif cmd[1] == "Free" then
			self.L4c.curr = cmd[1]
		elseif not cmd[1] then					-- No command received
			self.L4c.curr = nil
		else									-- Invalid operation code
			self.L4c.curr = nil
			println(string.format("%s.L3|Unknown command received (%s|%s. Length: %s). State: %s.", parent, cmd[1], cmd[2], #cmd, self.state.curr))	-- monitoring
		end -- if
		
		if ans[1] == "OK" then
			self.L2a.curr = ans[1]
			if self:at("EXE") then
				self.start.curr = ans[2]
			else
				println(string.format("%s.L3| %s answer received while at %s.", parent, ans[1], self.state.curr))	-- monitoring
			end -- if
		elseif ans[1] == "KO" then
			self.L2a.curr = ans[1]
			if self:at("EXE") then
				local arc = ans[2]
				self.start.curr = arc.ini
				self.avoid.curr = arc.fin
			else
				println(string.format("%s.L3| %s answer received while at %s.", parent, ans[1], self.state.curr))	-- monitoring
			end -- if
		elseif not ans[1] then					-- No answer received
			self.L2a.curr = nil
		else									-- Invalid operation code
			self.L2a.curr = nil
			println(string.format("%s.L3|Unknown answer received (%s. Length: %s). State: %s.", parent, ans[1], #ans, self.state.curr))	-- monitoring
		end -- if
	end -- read_inputs()
	,
	monitor = function(self, parent)		-- Monitors given elements of the state machine
		--println(string.format("	%s.L3| ----- VARIABLES -----", parent))
		println(string.format("	%s.L3| State: %s", parent, self.state.curr))
		
		--println(string.format("	%s.L3| ----- OUTPUTS -----"))
		--println(string.format("	%s.L3| L3a: %s", parent,	self.L3a.curr))
		--println(string.format("	%s.L3| Path length: %s", parent, #self.path.curr))
		
		--[[println(string.format("	%s.L3| ----- INPUTS -----", parent))
		--println(string.format("	%s.L3| Goal: (%s,%s)", parent , self.goal[1].x, self.goal[1].y))
		--println(string.format("	%s.L3| Goal: (%s,%s)", parent, self.goal.curr.x, self.goal.curr.y))
		--println(string.format("	%s.L3| Start: %s", parent, self.start.curr.x, self.start.curr.y))
		println(string.format("	%s.L3| Path exe: %s", parent, self.L2a.curr[1]))
		println(string.format("	%s.L3| Patch: (%s,%s)", parent, self.patch.x, self.patch.y))
		--]]
	end -- monitor()
	,
	cmonitor = function(self, parent)		-- Calls monitor() when the machine changes to a different state
		if self.state.prev ~= self.state.curr then
			self:monitor(parent)
		end -- if
	end -- cmonitor()
	,
	get_L3cmd = function(self)					-- Returns the command from L3
		return self.L3c.curr
	end -- get_L3cmd()
	,
	get_L3ans = function(self)					-- Returns the answer from L3
		return self.L3a.curr
	end -- get_L3ans()
	,
	get_count = function(self)					-- Returns the states' count
		return self.count
	end -- get_count()
	,
	write_outputs = function(self, parent)		-- Sends the communication outputs
		-- Graphic representation
		if showTaxi.state.L3 then
			if colorCode == "order" then
				if self:at("FREE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
				elseif self:at("SEND") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("EXE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 1})
				elseif self:at("BUSY") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				end -- if chain
			elseif colorCode == "status" then
				if self:at("FREE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("SEND") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("EXE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("BUSY") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				end -- if chain
			end -- if chain
		end -- if
	end -- write_outputs()
	,
	write_environment = function(self, parent)	-- Modifies the physical environment
		
	end -- write_environment()
	,
	get_cost = function(self, ini, dest, rest)
		local loc = {}
		local data = dest
		if type(data) == "string" then				-- When the passenger gives a port name as destination
			local gates = {}
			for i, p in ipairs(self.map.port) do
				if p.name == data then
					for j, g in ipairs(p.gate) do
						table.insert(gates, g)		-- Save the gates from all the ports with that name
					end -- for
				end -- if
			end -- for
			loc = gates
		elseif data.x and data.y then				-- When the passenger gives coordinates
			local point = self.map.patch[data.x][data.y]	-- get the destination patch
			if point.port then						-- When the passenger gives a port as destination
				loc = point.port.gate				-- Save the gates from that port
			else									-- If is not a port
				loc = {data}						-- Save the patch
			end -- if
		elseif data[1] and data[1].x and data[1].y then	-- When the passenger gives a list of nodes
			loc = data								-- Save the list
		elseif #data == 0 then						-- No destination
			loc = {}	
		else										-- Unknown
			loc = {}	
		end -- if

		local cost = -1								-- initial cost (invalid)
		local goal = {}
		local k = -1								-- initial index of shosen loc in loc list (invalid)
		for j, l in ipairs(loc) do					-- loc contains a list of destinations
			local p = self.map:minpath(ini, l)		-- The path to every destination is computed, avoiding the blocked node(s)
			if p[1] == ini then
				if 0 > cost or cost > (#p - 1) then	-- The shortest path is chosen
					cost = #p - 1
					k = j
				end -- if
			end -- if
		end -- for
		if cost >= 0 then
			cost = cost + rest
			goal = loc[k]
		else
			cost = math.huge
		end -- if
		
		return cost, goal
	end -- get_cost()
	,
	route = function(self, start, goal)			-- Returns the path from one node to another
		local path = {}
		local mincost = -1
		for j, g in ipairs(goal) do				-- Goal contains a list of destinations
			local p = self.map:minpath(start, g)	-- The path to every destination is computed, avoiding the blocked node(s)
			g.cost = #p
			if p[1] == start then
				if 0 > mincost or mincost > g.cost then	-- The shortest path is chosen
					path = p
					mincost = g.cost
				end -- if
			end -- if
		end -- for
		if mincost < 0 then 					-- no path to the goal
			path = {}
		elseif #path > 1 then
			table.remove(path, 1)
		end -- if
		
		return path
	end -- route()
	,
	re_route = function(self, start, goal, avoid)	-- Returns the path from one node to another, avoiding specific nodes
		local path = {}
		local mincost = -1
		for j, g in ipairs(goal) do				-- Goal contains a list of destinations
			local p = self.map:minpath(start, g, {avoid})	-- The path to every destination is computed, avoiding the blocked node(s)
			g.cost = #p
			if p[1] == start then
				if 0 > mincost or mincost > g.cost then	-- The shortest path is chosen
					path = p
					mincost = g.cost
				end -- if
			end -- if
		end -- for
		if mincost < 0 then 					-- if there is no path to the goal
			path = self:route(start, goal)		-- try without avoiding any nodes
		elseif #path > 1 then
			table.remove(path, 1)
		end -- if
		
		return path
	end -- re_route()
	,
	step = function(self, parent)
		if self:at("FREE") then
			self.L3a.next = {}
			self.L3c.next = {}
			if self.L4c.curr == "GO" then
				self.path.next = self:route(self.start.curr, self.goal.curr)
				self:push(self.state.curr)
				self.state.next = "SEND"
			end -- if
			
			-- Graphic representation
			if not showTaxi.keepPath then
				for i, m in ipairs(self.marker) do
					sim.removeObject(self.marker[i])
				end -- for
				self.marker = {}
			end -- if
		elseif self:at("SEND") then
			if self.L4c.curr == "Free" then
				self.path.next = {}
				self.L3a.next = {}
				self.L3c.next = {"Free"}
				self.state.next = self:pop()
			elseif self.path.curr[1] then
				self.L3a.next = {}
				self.L3c.next = {"GO", self.path.curr}
				self.state.next = "EXE"

				-- Graphic representation
				if showTaxi.path then
					local j = #self.marker
					for i, p in ipairs(self.path.curr) do
						self.marker[j + i] = sim.createPureShape(2, 26, {0.25, 0.25, 0}, 0, nil)
						sim.setObjectPosition(self.marker[j + i], -1, {p.x, p.y, 0.02})
						sim.setShapeColor(self.marker[j + i], nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
					end -- for
				end -- if
			else
				self.L3a.next = {"KO"}
				self.L3c.next = {"Free"}
				self.state.next = "FREE"
			end -- if
		elseif self:at("EXE") then
			if self.L4c.curr == "Free" then
				self.path.next = {}
				self.L3a.next = {}
				self.L3c.next = {"Free"}
				self.state.next = self:pop()
			elseif self.L2a.curr == "OK" then
				self.path.next = {}
				self.L3a.next = {"OK"}
				self.L3c.next = {}
				self.state.next = "BUSY"
			elseif self.L2a.curr == "KO" then
				self.path.next = self:re_route(self.start.curr, self.goal.curr, self.avoid.curr)
				self.L3a.next = {}
				self.L3c.next = {}
				self.state.next = "SEND"
			else
				self.L3a.next = {}
				self.L3c.next = {}
			end -- if
		elseif self:at("BUSY") then
			if self.L4c.curr == "Free" then
				self.path.next = {}
				self.L3a.next = {}
				self.L3c.next = {"Free"}
				self.state.next = self:pop()
			elseif self.L4c.curr == "GO" then
				self.path.next = self:route(self.start.curr, self.goal.curr)
				self.L3a.next = {}
				self.L3c.next = {}
				self.state.next = "SEND"
			else
				self.L3a.next = {}
				self.L3c.next = {}
			end -- if
			
			-- Graphic representation
			if not showTaxi.fullPath then
				for i, m in ipairs(self.marker) do
					sim.removeObject(self.marker[i])
				end -- for
				self.marker = {}
			end -- if
		else											-- Unknown state
			println(string.format("%s.L3| Unknown state: %s.", parent, self.state.curr))
		end -- if chain
	end -- step()
	,
	update = function(self, parent, first)
		local update_event = false
		
		if	self.L4c.prev	== self.L4c.curr
		and	self.L2a.prev	== self.L2a.curr
		and	self.start.prev.x	== self.start.curr.x
		and	self.start.prev.y	== self.start.curr.y
		and	self.avoid.prev.x	== self.avoid.curr.x
		and	self.avoid.prev.y	== self.avoid.curr.y
		and	self.state.prev	== self.state.curr
		and	self.path.prev[1]	== self.path.curr[1]
		and	self.L3a.prev[1]	== self.L3a.curr[1]
		and	self.L3c.prev[1]	== self.L3c.curr[1] then
			update_event = false
		else
			update_event = true
		end -- if
		
		self.L4c.prev	= self.L4c.curr
		self.goal.prev	= self.goal.curr
		self.L2a.prev	= self.L2a.curr
		self.start.prev	= self.start.curr
		self.avoid.prev	= self.avoid.curr
		self.state.prev	= self.state.curr
		self.path.prev	= self.path.curr
		self.L3a.prev	= self.L3a.curr
		self.L3c.prev	= self.L3c.curr
		
		self.state.curr	= self.state.next
		self.path.curr	= self.path.next
		self.L3a.curr	= self.L3a.next
		self.L3c.curr	= self.L3c.next
		
		-- Update immediate values: I = f(S+, V+)
		-- Accounting
		if first then
			local c = self.count[self.state.curr]
			if c == nil then c = 0 end
			self.count[self.state.curr] = c + 1
		end -- if
		
		return update_event
	end -- update()
} -- L3

return L3

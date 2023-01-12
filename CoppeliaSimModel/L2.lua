-- Robot fleet MAS: Executor Agent Path follower controller (L2) with wandering behavior while free
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

local EFSSM = require "EFSSM"

L2 = {											-- L2 controller structure
	tostring = function()						-- Returns the controller name
		return "Taxi's path follower"
	end -- tostring()
	,
	new = function(self, map, node)				-- creates a new controller instance
		local o = EFSSM:new()
		for k in pairs(self) do o[k] = self[k] end
	
		-- Constants
		o.map = map
		o._state_names_ = { "FREE", "ROAM", "SEND", "EXE", "BUSY"}	-- active state names (end states with no actions should not be listed here)
		
		-- Environmental inputs
		
		-- Communication inputs
		o.L3c = {};		o.L3c.prev = nil;		o.L3c.curr = nil
		o.path = {};	o.path.prev = {};		o.path.curr = {}
		o.L1a = {};		o.L1a.prev = nil;		o.L1a.curr = nil
		
		-- Variables
		local prox = o:near(node)
		
		o.state = {};	o.state.prev = "NONE";	o.state.curr = "FREE";		o.state.next = "FREE"
		o.i = {};		o.i.prev = 0;			o.i.curr = 1;				o.i.next = 1
		o.arc = {};		o.arc.prev = {ini = {}, fin = {}}
						o.arc.curr = {ini = node, fin = prox}
						o.arc.next = {ini = node, fin = prox}
		
		-- Communication outputs
		o.L2a = {};		o.L2a.prev = {};		o.L2a.curr = {};			o.L2a.next = {}
		o.L2c = {};		o.L2c.prev = {};		o.L2c.curr = {};			o.L2c.next = {}
		
		-- Environmental outputs
		
		-- Graphic representation
		if showTaxi.nodes then
			o.iniHandle = sim.createPureShape(2, 26, {0.25, 0.25, 0}, 0, nil)	-- Current node marker
			sim.setShapeColor(o.iniHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
			o.endHandle = sim.createPureShape(2, 26, {0.25, 0.25, 0}, 0, nil)	-- Next node marker
			sim.setShapeColor(o.endHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
		end -- if
		
		-- Monitoring
		
		-- Statistics
		o.count = {}
		o.count[o.state.curr] = 1
		return o
	end -- new()
	,
	reset = function(self)
		self.state.next = "FREE"
		self.i.next = 0
		self.arc.next.fin = {}
		self.L2a.next = {}
		self.L2c.next = {}
		
		self.count = {} -- statistics
		self.count[self.state.curr] = 1
		
		self:empty()
		self:clear_beliefs()
	end -- reset()
	,
	read_environment = function(self, parent)	-- registers the environmental signals
		
	end -- read_environment()
	,
	read_inputs = function(self, parent, cmd, ans, first)		-- registers the communication inputs
		if cmd[1] == "GO" then
			self.L3c.curr = cmd[1]
			if self:at("FREE") or  self:at("ROAM") or self:at("BUSY") then
				self.path.curr = cmd[2]
			else
				println(string.format("%s.L2| %s command received while at %s.", parent, cmd[1], self.state.curr))	-- monitoring
			end -- if
		elseif cmd[1] == "Free" then
			self.L3c.curr = cmd[1]
		elseif not cmd[1] then					-- No command received
			self.L3c.curr = nil
		else									-- Invalid operation code
			self.L3c.curr = nil
			println(string.format("%s.L2|Unknown command received (%s|%s. Length: %s). State: %s.", parent, cmd[1], cmd[2], #cmd, self.state.curr))	-- monitoring
		end -- if
		
		if ans[1] == "OK" then
			self.L1a.curr = ans[1]
		elseif ans[1] == "KO" then
			self.L1a.curr = ans[1]
		elseif not ans[1] then					-- No answer received
			self.L1a.curr = nil
		else									-- Invalid operation code
			self.L1a.curr = nil
			println(string.format("%s.L2|Unknown answer received (%s. Length: %s). State: %s.", parent, ans[1], #ans, self.state.curr))	-- monitoring
		end -- if
	end -- read_inputs()
	,
	monitor = function(self, parent)			-- Monitors given elements of the state machine
		--println(string.format("		%s.L2| ----- VARIABLES -----", parent))
		println(string.format("		%s.L2| State: %s", parent, self.state.curr))
		--println(string.format("		%s.L2| cmd counter: %s", parent, self.i.curr))
		
		--println(string.format("		%s.L2| ----- OUTPUTS -----"))
		--println(string.format("		%s.L2| L2a: %s", parent, self.L2a.curr))
		--println(string.format("		%s.L2| L2c: %s", parent, self.L2c.curr[1]))
		println(string.format("		%s.L2| Arc ini: (%s,%s)", parent, self.arc.curr.ini.x, self.arc.curr.ini.y))
		--println(string.format("		%s.L2| Arc fin: (%s,%s)", parent, self.arc.curr.fin.x, self.arc.curr.fin.y))
		
		--println(string.format("		%s.L2| ----- INPUTS -----", parent))
		--println(string.format("		%s.L2| L3c: %s", parent, self.L3c.curr))
		--println(string.format("		%s.L2| L1a: %s", parent, self.L1a.curr))
		--println(string.format("		%s.L2| Path length: %s", parent, #self.path.curr))--]]
	end -- monitor()
	,
	cmonitor = function(self, parent)			-- Calls monitor() when the machine changes to a different state
		if self.state.prev ~= self.state.curr then
			self:monitor(parent)
		end -- if
	end -- cmonitor()
	,
	get_L2cmd = function(self)					-- Returns the command from L2
		return self.L2c.curr
	end -- get_L2cmd()
	,
	get_L2ans = function(self)					-- Returns the answer from L2
		return self.L2a.curr
	end -- get_L2ans()
	,
	get_start = function(self)					-- Returns the starting node for path planning
		local node = {}
		if self:at("ROAM") or self:at("EXE") then
			node = self.arc.curr.fin
		else
			node = self.arc.curr.ini
		end -- if
		
		return node
	end -- get_start()
	,
	get_count = function(self)					-- Returns the states' count
		return self.count
	end -- get_count()
	,
	write_outputs = function(self, parent)		-- Sends the communication outputs
		-- Graphic representation
		if showTaxi.nodes then
			sim.setObjectPosition(self.iniHandle, -1, {self.arc_ini.curr.x, self.arc_ini.curr.y, 0.03})
			if self.arc_end.curr.x and self.arc_end.curr.y then
				sim.setObjectPosition(self.endHandle, -1, {self.arc_end.curr.x, self.arc_end.curr.y, 0.03})
			else
				sim.setObjectPosition(self.endHandle, -1, {100, 100, 0.02})
			end -- if
		end -- if
		if showTaxi.state.L2 then
			if colorCode == "order" then
				if self:at("FREE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
				elseif self:at("ROAM") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("SEND") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 1})
				elseif self:at("EXE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("BUSY") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 1})
				end -- if chain
			elseif colorCode == "status" then
				if self:at("FREE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("ROAM") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("SEND") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("EXE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("BUSY") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				end -- if chain
			end -- if
		end -- if
	end -- write_outputs()
	,
	write_environment = function(self, parent)	-- Modifies the physical environment
		
	end -- write_environment()
	,
	near = function(self, node)
		local x = node.x
		local y = node.y
		local outs = node.out
		if outs[1] > 0 then 					-- There is an out to the front
			if outs[3] > 0 then					-- And also to the right
				if math.random() > 0.5 then		-- Choose randomly with equal probability
					x = x + self.map.yaw[outs[3]].x
					y = y + self.map.yaw[outs[3]].y
				else
					x = x + self.map.yaw[outs[1]].x
					y = y + self.map.yaw[outs[1]].y
				end -- if
			else								-- And not to the right
				x = x + self.map.yaw[outs[1]].x
				y = y + self.map.yaw[outs[1]].y
			end -- if
		elseif outs[3] > 0 then 				-- There is no out to the front but there is one to the right
			if outs[2] > 0 then					-- And also to the left
				if math.random() > 0.25 then 	-- Choose randomly with higher probability for a right turn
					x = x + self.map.yaw[outs[3]].x
					y = y + self.map.yaw[outs[3]].y
				else
					x = x + self.map.yaw[outs[2]].x
					y = y + self.map.yaw[outs[2]].y
				end -- if
			else								-- And not to the left
				x = x + self.map.yaw[outs[3]].x
				y = y + self.map.yaw[outs[3]].y
			end -- if
		elseif outs[2] > 0 then 				-- There is only an out to the left
			x = x + self.map.yaw[outs[2]].x
			y = y + self.map.yaw[outs[2]].y
		end -- if  

		return self.map.patch[x][y]
	end -- near()
	,
	step = function(self, parent)
		if self:at("FREE") then
			self.L2a.next = {}
			if self.L3c.curr == "GO" then
				self.L2c.next = {}
				self.arc.next.fin = self.path.curr[self.i.curr]
				self.state.next = "SEND"
			else
				self.L2c.next = {"GO", self.arc.curr}
				self.state.next = "ROAM"
			end -- if
		elseif self:at("ROAM") then
			self.L2a.next = {}
			self.L2c.next = {}
			if self.L3c.curr == "GO" then
				if self.L1a.curr == "OK" then
					self.arc.next.ini = self.arc.curr.fin
					self.arc.next.fin = self.path.curr[self.i.curr]
					self.state.next = "SEND"
				elseif self.L1a.curr == "KO" then
					self.L2a.next = {"KO", self.arc.curr}
					self.arc.next.fin = {}
					self.state.next = "BUSY"
				else
					self.state.next = "EXE"
				end -- if
			else
				if self.L1a.curr == "OK" then
					self.arc.next.ini = self.arc.curr.fin
					self.arc.next.fin = self:near(self.arc.curr.fin)
					self.state.next = "FREE"
				elseif self.L1a.curr == "KO" then
					self.arc.next.fin = self:near(self.arc.curr.ini)
					self.state.next = "FREE"
				end -- if
			end -- if
		elseif self:at("SEND") then
			self.L2a.next = {}
			if self.L3c.curr == "Free" then
				self.L2c.next = {}
				self.arc.next.fin = self:near(self.arc.curr.ini)
				self.i.next = 1
				self.state.next = "FREE"
			else
				self.L2c.next = {"GO", self.arc.curr}
				self.i.next = self.i.curr + 1
				self.state.next = "EXE"
			end -- if
		elseif self:at("EXE") then
			self.L2c.next = {}
			if self.L3c.curr == "Free" then
				self.L2a.next = {}
				self.i.next = 1
				if self.L1a.curr == "OK" then
					self.arc.next.ini = self.arc.curr.fin
					self.arc.next.fin = self:near(self.arc.curr.fin)
					self.state.next = "FREE"
				elseif self.L1a.curr == "KO" then
					self.arc.next.fin = self:near(self.arc.curr.ini)
					self.state.next = "FREE"
				else
					self.state.next = "ROAM"
				end -- if
			else
				if self.L1a.curr == "OK" then
					self.arc.next.ini = self.arc.curr.fin
					if self.i.curr <= #self.path.curr then
						self.L2a.next = {}
						self.arc.next.fin = self.path.curr[self.i.curr]
						self.state.next = "SEND"
					else
						self.L2a.next = {"OK", self.arc.curr.fin}
						self.i.next = 1
						self.arc.next.fin = {}
						self.state.next = "BUSY"
					end -- if
				elseif self.L1a.curr == "KO" then
					self.L2a.next = {"KO", self.arc.curr}
					self.i.next = 1
					self.arc.next.fin = {}
					self.state.next = "BUSY"
				else
					self.L2a.next = {}
				end -- if
			end -- if
		elseif self:at("BUSY") then
			self.L2a.next = {}
			self.L2c.next = {}
			if self.L3c.curr == "Free" then
				self.arc.next.fin = self:near(self.arc.curr.ini)
				self.i.next = 1
				self.state.next = "FREE"
			elseif self.L3c.curr == "GO" then
				self.arc.next.fin = self.path.curr[self.i.curr]
				self.state.next = "SEND"
			end -- if
		else
			println(string.format("%s.L2| Unknown state: %s.", parent, self.state.curr))
		end -- if chain
	end -- step()
	,
	update = function(self, parent, first)
		local update_event = false
		
		if	self.L3c.prev	== self.L3c.curr
		and	self.path.prev[1]	== self.path.curr[1]		-- self.path.prev == self.path.curr
		and	self.L1a.prev	== self.L1a.curr
		and	self.state.prev	== self.state.curr
		and	self.i.prev		== self.i.curr
		and	self.arc.prev.ini.x	== self.arc.curr.ini.x
		and	self.arc.prev.ini.y	== self.arc.curr.ini.y
		and	self.arc.prev.fin.x	== self.arc.curr.fin.x
		and	self.arc.prev.fin.y	== self.arc.curr.fin.y
		and	self.L2a.prev[1]	== self.L2a.curr[1]			-- self.L2a.prev == self.L2a.curr
		and	self.L2c.prev[1]	== self.L2c.curr[1] then	-- self.L2c.prev == self.L2c.curr
			update_event = false
		else
			update_event = true
		end -- if
		
		self.L3c.prev	= self.L3c.curr
		self.path.prev	= self.path.curr
		self.L1a.prev	= self.L1a.curr
		self.state.prev	= self.state.curr
		self.i.prev		= self.i.curr
		self.arc.prev	= self.arc.curr
		self.L2a.prev	= self.L2a.curr
		self.L2c.prev	= self.L2c.curr
		
		self.state.curr	= self.state.next
		self.i.curr		= self.i.next
		self.arc.curr	= self.arc.next
		self.L2a.curr	= self.L2a.next
		self.L2c.curr	= self.L2c.next
		
		-- Update immediate values: I = f(S+, V+)
		-- Accounting
		if first then
			local c = self.count[self.state.curr]
			if c == nil then c = 0 end
			self.count[self.state.curr] = c + 1
		end -- if
		
		return update_event
	end -- update()
} -- L2

return L2

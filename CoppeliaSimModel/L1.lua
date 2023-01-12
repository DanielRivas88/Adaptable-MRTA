-- Robot fleet MAS: Executor Agent traffic manager (L1)
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

local EFSSM = require "EFSSM"

L1 = {											-- L1 controller structure
	tostring = function()						-- Returns the controller name
		return "Taxi's traffic manager"
	end -- tostring()
	,
	new = function(self, id, node, ori, block_deadline)	-- creates a new controller instance
		local o = EFSSM:new()
		for k in pairs(self) do o[k] = self[k] end
		
		-- Constants
		o.id = id
		o._state_names_ = {"WAIT", "INIT", "CHECK", "GOING", "BLOCK", "OBS"}	-- active state names (end states with no actions should not be listed here)
		
		o.Tb = block_deadline				-- blocked timeout
		
		-- Environmental inputs
		o.time = {};	o.time.prev = 0;		o.time.curr = 0				-- Current simulation time
		
		o.serv = {};	o.serv.prev = false;	o.serv.curr = false
		
		-- Communication inputs
		o.L2c = {};		o.L2c.prev = nil;		o.L2c.curr = nil
		o.L0a = {};		o.L0a.prev = nil;		o.L0a.curr = nil
		o.arc = {};		o.arc.prev = {ini = {}, fin = {}}
						o.arc.curr = {ini = {}, fin = {}}
		o.turned = {};	o.turned.prev = 0;		o.turned.curr = 0
		o.moved = {};	o.moved.prev = 0;		o.moved.curr = 0
		
		-- Variables
		o.state = {};	o.state.prev = "NONE";	o.state.curr = "WAIT";	o.state.next = "WAIT"
		o.A = {};		o.A.prev = 0;			o.A.curr = 0;			o.A.next = 0
		o.S = {};		o.S.prev = 0;			o.S.curr = 0;			o.S.next = 0
		o.ori = {};		o.ori.prev = nil;		o.ori.curr = ori;		o.ori.next = ori
		
		o.alt = {};		o.alt.prev = false;		o.alt.curr = false;		o.alt.next = false	-- signals that there is an alternative route from the node
		o.T0 = {};		o.T0.prev = nil;		o.T0.curr = nil;		o.T0.next = nil --math.huge	-- blockage start
		
		-- Communication outputs
		o.L1a = {};		o.L1a.prev = {}			o.L1a.curr = {};		o.L1a.next = {}
		o.L1c = {};		o.L1c.prev = {};		o.L1c.curr = {};		o.L1c.next = {}
		
		o:addRequest(node)
		
		-- Environmental outputs
		
		-- Monitoring
		
		-- Statistics
		
		-- Results recording
		o.block_reroute = 0			-- number of reroutes requested due to obstacle detection
		o.service_reroute = 0		-- number of reroutes requested due to lack of service from a node
		
		o.count = {}
		o.count[o.state.curr] = 1
		return o
	end -- new()
	,
	reset = function(self)						-- resets the controller
		self.state.next = "WAIT"
		self.A.next = 0
		self.S.next = 0
		self.L1c.next = {}
		self.L1a.next = {}
		
		self.count = {}							-- statistics
		self.count[self.state.curr] = 1
		
		self:empty()
		self:clear_beliefs()
	end -- reset()
	,
	read_environment = function(self, parent, simTime)	-- registers the environmental signals
		self.time.curr = simTime
	end -- read_environment()
	,
	read_inputs = function(self, parent, cmd, ans, first)	-- registers the communication inputs
		if cmd[1] == "GO" then					-- GO command received
			self.L2c.curr = cmd[1]
			if self:at("WAIT") then
				self.arc.curr = cmd[2]
			else
				println(string.format("%s.L1| %s command received while at %s.", parent, cmd[1], self.state.curr))	-- monitoring
			end -- if
		elseif not cmd[1] then					-- No command received
			self.L2c.curr = nil
		else									-- Invalid operation code
			self.L2c.curr = nil
			println(string.format("L1|Unknown command received (%s|%s. Length: %s). State: %s.", cmd[1], cmd[2], #cmd, self.state.curr))	-- monitoring
		end -- if
		
		if ans[1] == "OK" then					-- Command completed
			self.L0a.curr = ans[1]
		elseif ans[1] == "KO" then				-- Command blocked
			self.L0a.curr = ans[1]
			self.turned.curr = ans[2]
			self.moved.curr = ans[3]
		elseif ans[1] == "BUSY" then			-- L0 is busy
			self.L0a.curr = ans[1]
		elseif not ans[1] then					-- No answer received
			self.L0a.curr = nil
		else									-- Invalid operation code
			self.L0a.curr = nil
			println(string.format("%s.L1|Unknown answer received (%s|%s|%s. Length: %s). State: %s.", parent, ans[1], ans[2], ans[3], #ans, self.state.curr))	-- monitoring
		end -- if
		
		if self:at("CHECK") then
			self.serv.curr = self:served(self.arc.curr.fin)
		else
			self.serv.curr = false
		end -- if
	end -- read_inputs()
	,
	monitor = function(self, parent)			-- Monitors the state machine constantly
		--println(string.format("			%s.L1| ----- VARIABLES -----", parent))
		println(string.format("			%s.L1| State: %s", parent, self.state.curr))
		
		--println(string.format("			%s.L1| ----- OUTPUTS -----", parent))
		--println(string.format("			%s.L1| Cmd: %s, %s, %s", parent, self.L1c.curr[1], self.L1c.curr[2], self.L1c.curr[3]))
		--println(string.format("			%s.L1| A: %s", parent, self.A.curr))
		--println(string.format("			%s.L1| S: %s", parent, self.S.curr))
		--println(string.format("			%s.L1| L1a: %s", parent, self.L1a.curr[1]))
		
		--println(string.format("			%s.L1| ----- INPUTS -----", parent))
		--println(string.format("			%s.L1| L2c: %s", parent, self.L2c.curr))
		--println(string.format("			%s.L1| Arc: (%s,%s) (%s,%s)", parent, self.arc.curr.ini.x, self.arc.curr.ini.y, self.arc.curr.fin.x, self.arc.curr.fin.y))
		--println(string.format("			%s.L1| Arc ini: (%s,%s)", parent, self.arc.curr.ini.x, self.arc.curr.ini.y))
		--println(string.format("			%s.L1| Arc fin: (%s,%s)", parent, self.arc.curr.fin.x, self.arc.curr.fin.y))
		--[[println(string.format("			%s.L1| L0a: %s", parent, self.L0a.curr))
		println(string.format("			%s.L1| Orientation: %s", parent, self.ori.curr))--]]
	end -- monitor()
	,
	cmonitor = function(self, parent)			-- calls monitor() at certain events
		if self.state.prev ~= self.state.curr then
			self:monitor(parent)
		end -- if
	end -- cmonitor()
	,
	get_L1cmd = function(self)					-- Returns the command from L1
		return self.L1c.curr
	end -- get_L1cmd()
	,
	get_L1ans = function(self)					-- Returns the answer from L1
		return self.L1a.curr
	end -- get_L1ans()
	,
	get_count = function(self)					-- Returns the states' count
		return self.count
	end -- get_count()
	,
	write_outputs = function(self, parent)		-- Sends the communication outputs
		if self:at("INIT") and self.S.curr > 0 then
			self:addRequest(self.arc.curr.fin)
		elseif self:at("CHECK") and self.serv.curr then
			self:deleteRequest(self.arc.curr.ini)
		elseif self:at("OBS") and self.alt.curr then
			self:deleteRequest(self.arc.curr.fin)
		end -- if
		
		-- Results recording
		if not parent.L4:at("FREE") then
			if self:at("WAIT") and self:prev_at("BLOCK") then
				self.block_reroute = self.block_reroute + 1
			elseif self:at("WAIT") and self:prev_at("OBS") then
				self.service_reroute = self.service_reroute + 1
			end -- if
		end -- if
		
		-- Graphic representation
		if showTaxi.state.L1 then
			if colorCode == "order" then
				if self:at("WAIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
				elseif self:at("INIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("CHECK") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 1})
				elseif self:at("GOING") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("BLOCK") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 1})
				elseif self:at("OBS") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				end -- if chain
			elseif colorCode == "status" then
				if self:at("WAIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("INIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("CHECK") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				elseif self:at("GOING") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("BLOCK") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				elseif self:at("OBS") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				end -- if chain
			end -- if
		end -- if
	end -- write_outputs()
	,
	write_environment = function(self, parent)	-- Modifies the environment
		
	end -- write_environment()
	,
	command = function(self, arc, ori)			-- returns the command to travel the arc
		local start = arc.ini
		local goal = arc.fin
		local dx = goal.x - start.x
		local dy = goal.y - start.y
		local turn = 0
		local desp = 0
		if not (dx == 0) or not (dy == 0) then
			local ang1 = ori
			local ang2 = round(math.deg(math.atan2(dy,dx)), 0)
			ang2 = ang2 - 90
			turn = ang2 - ang1 			
			if turn > 180 then
				turn = turn - 360
			elseif turn <= -180 then
				turn = turn + 360
			end -- if
			turn = round(turn, 0)
			desp = round(math.sqrt((dx * dx) + (dy * dy)), 3)
		end -- if
		
		return  turn, desp
	end -- command()
	,
	deleteRequest = function(self, target)		-- deletes the service request from the target node
		local pos = nil
		if target and target.service then
			for i, v in ipairs(target.service) do
				if v == self.id then
					pos = i --true
				end -- if
			end -- for
			if pos then
				table.remove(target.service, pos)
				showMap.changed = true

				-- Graphical representation
				if showMap.served then
					showMap.servChange = true
				end --if
			else								-- Error: The passed node should be serving the taxi
				println("Warning: The node "..target.x..","..target.y.." was not serving this taxi")
			end -- if
		elseif not target then					-- Error: no node found
			println("Warning: No node found to delete request from")
		else 									-- Error: No service list on the node
			println("Warning: No service list on the node to delete request from")
		end -- if
	end -- deleteRequest()
	,
	addRequest = function(self, target)			-- adds a service request to the target node
		local found = false
		if target and target.service then
			for i, v in ipairs(target.service) do
				if v == self.id then
					found = true
				end -- if
			end -- for
			if not found then
				table.insert(target.service, self.id)
				showMap.changed = true
		
				-- Graphical representation
				if showMap.served then
					showMap.servChange = true
				end --if
			else								-- Warning: This should not happen
				println("Warning: The node "..target.x..","..target.y.." already has a request from this taxi")
			end -- if
		elseif not target then					-- Error: no node found
			println("Warning: No node found to add request to")
		else 									-- Error: no service list on the node
			println(string.format("L1:served| Warning: No service list on approached node (%s,%s)", target.x, target.y))
		end -- if
	end -- addRequest()
	,
	served = function(self, target)				-- returns if the vehicle is served by the target node
		local is_served = false
		if target and target.service then
			local served = target.service[1]
			is_served = (served == self.id)
		elseif not target then					-- Error: no node found
			println("Warning: No node specified to ask for service")
		else 									-- Error: no service list on the node
			println(string.format("L1:served| Warning: No service list on node asked for service (%s,%s)", target.x, target.y))
		end -- if
		
		return is_served
	end -- served()
	,
	outs = function(self, target)				-- returns if the node has an alternative out
		local other_out = false
		local outs = 0
		if target and target.out then			-- if the node exists and has an out list
			for i, o in ipairs(target.out) do
				if o > 0  then					-- if the output is valid
					outs = outs + 1
				end -- if
			end -- for
		elseif not target then					-- Error: no node found
			println("L1:outs|Warning: No node specified to ask for alternative outs")
		else 									-- Error: no service list on the node
			println(string.format("L1:outs|Warning: No out list on node asked for alternative outs (%s,%s)", target.x, target.y))
		end -- if
		if outs > 1 then
			other_out = true
		end -- if
		
		return other_out
	end -- outs()
	,
	step = function(self, parent)				-- Calculates the controller next actuation
		if self:at("WAIT") then
			self.L1a.next = {}
			self.L1c.next = {}
			if self.L2c.curr == "GO" then
				self.A.next, self.S.next = self:command(self.arc.curr, self.ori.curr)
				self.state.next = "INIT"
			else
				self.A.next = 0
				self.S.next = 0
			end -- if
		elseif self:at("INIT") then
			self.L1a.next = {}
			if self.S.curr == 0 then
				self.L1c.next = {"GO", self.A.curr, self.S.curr}
				self.state.next = "GOING"
			else
				self.L1c.next = {}
				self.state.next = "CHECK"
				self.T0.next = self.time.curr
			end -- if
		elseif self:at("CHECK") then
			if self.serv.curr then
				self.L1a.next = {}
				self.L1c.next = {"GO", self.A.curr, self.S.curr}
				self.state.next = "GOING"
			elseif self.time.curr - self.T0.curr >= self.Tb then
				self.T0.next = math.huge
				self.alt.next = self:outs(self.arc.curr.ini)
				self.L1a.next = {}
				self.L1c.next = {}
				self.state.next = "OBS"
			else 
				self.L1a.next = {}
				self.L1c.next = {}
			end -- if
		elseif self:at("GOING") then
			self.L1c.next = {}
			if self.L0a.curr == "OK" then
				self.L1a.next = {"OK"}
				
				local ori = self.ori.curr + self.A.curr
				if ori > 180 then
					ori = ori - 360
				elseif ori <= -180 then
					ori = ori + 360
				end -- if
				self.ori.next = ori
				self.state.next = "WAIT"
				if pose_override then
					local o = parent:get_ori()
					o[3] = math.rad(ori)
					sim.setObjectOrientation(parent.carHandle, -1, o)
					local p = parent:get_pos()
					p[1] = self.arc.curr.fin.x
					p[2] = self.arc.curr.fin.y
					sim.setObjectPosition(parent.carHandle, -1, p)
				end -- if
			elseif self.L0a.curr == "KO" then
				self.L1a.next = {}
				
				local ori = self.ori.curr + self.A.curr
				if ori > 180 then
					ori = ori - 360
				elseif ori <= -180 then
					ori = ori + 360
				end -- if
				self.ori.next = ori
				
				self.A.next = 0
				self.S.next = self.S.curr - self.moved.curr
				self.state.next = "BLOCK"
			else
				self.L1a.next = {}
			end -- if
		elseif self:at("BLOCK") then
			if self.moved.curr == 0 then
				self.L1a.next = {"KO"}
				self.L1c.next = {}
				self.state.next = "WAIT"
			else
				self.L1a.next = {}
				self.L1c.next = {"GO", self.A.curr, self.S.curr}
				self.state.next = "GOING"
			end -- if
		elseif self:at("OBS") then
			if self.alt.curr then
				self.L1a.next = {"KO"}
				self.L1c.next = {}
				self.state.next = "WAIT"
			else
				self.L1a.next = {}
				self.L1c.next = {}
				self.state.next = "CHECK"
			end -- if
		else
			println(string.format("T.L1| Unknown state: %s.", self.state.curr))
		end -- if chain
	end -- step()
	,
	update = function(self, parent, first)		-- Updates the variables values
		local update_event = false
		
		if	self.L2c.prev		== self.L2c.curr
		and	self.L0a.prev		== self.L0a.curr
		and	self.arc.prev.ini.x	== self.arc.curr.ini.x
		and	self.arc.prev.ini.y	== self.arc.curr.ini.y
		and	self.arc.prev.fin.x	== self.arc.curr.fin.x
		and	self.arc.prev.fin.y	== self.arc.curr.fin.y
		and	self.turned.prev	== self.turned.curr
		and	self.moved.prev		== self.moved.curr
		and	self.state.prev		== self.state.curr
		and	self.ori.prev 		== self.ori.curr
		and	self.A.prev			== self.A.curr
		and	self.S.prev			== self.S.curr
		and self.alt.prev		== self.alt.curr
		and self.T0.prev		== self.T0.curr
		and	self.L1c.prev[1]	== self.L1c.curr[1]
		and	self.L1a.prev[1]	== self.L1a.curr[1] then
			update_event = false
		else
			update_event = true
		end -- if
		
		self.ori.prev		= self.ori.curr
		self.serv.prev		= self.serv.curr
		self.L2c.prev		= self.L2c.curr
		self.L0a.prev		= self.L0a.curr
		self.arc.prev		= self.arc.curr
		self.turned.prev	= self.turned.curr
		self.moved.prev		= self.moved.curr
		self.state.prev		= self.state.curr
		self.ori.prev 		= self.ori.curr
		self.A.prev			= self.A.curr
		self.S.prev			= self.S.curr
		self.L1a.prev		= self.L1a.curr
		self.L1c.prev		= self.L1c.curr
		self.alt.prev		= self.alt.curr
		self.time.prev		= self.time.curr
		self.T0.prev		= self.T0.curr
		
		self.state.curr		= self.state.next
		self.ori.curr 		= self.ori.next
		self.A.curr			= self.A.next
		self.S.curr			= self.S.next
		self.L1a.curr		= self.L1a.next
		self.L1c.curr		= self.L1c.next
		self.alt.curr		= self.alt.next
		self.T0.curr		= self.T0.next
		
		-- Update immediate values: I = f(S+, V+)
		-- Accounting
		if first then
			local c = self.count[self.state.curr]
			if c == nil then c = 0 end
			self.count[self.state.curr] = c + 1
		end -- if
		
		return update_event
	end -- update()
} -- L1

return L1
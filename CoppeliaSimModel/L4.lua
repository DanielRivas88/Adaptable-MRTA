-- Robot fleet MAS: Executor Agent Communications controller (L4)
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

local EFSSM = require "EFSSM"

L4 = {														-- L4 controller structure
	tostring = function()
		return "Taxi's communications controller"
	end
	,
	new = function(self, pick_deadline, drop_deadline, talk)
		local o = EFSSM:new()
		for k in pairs(self) do o[k] = self[k] end
	
		-- Constants
		o.pick_dl = pick_deadline or math.huge	-- 10
		o.drop_dl = drop_deadline or math.huge	-- 10
		o.talk = talk
		o._state_names_ = {"FREE", "BUSY", "PICK",	"LOADED", "DROP"}	-- active state names (end states with no actions should not be listed here)
    
		-- Environmental inputs
		o.time = {};	o.time.prev = nil;		o.time.curr = nil		-- Current simulation time
		
		-- Communication inputs
		o.Imsg = {};	o.Imsg.prev = nil;		o.Imsg.curr = nil
		o.accepts = {};	o.accepts.prev = {};	o.accepts.curr = {}	
		o.L3a = {};		o.L3a.prev = nil;		o.L3a.curr = nil
		
		-- Variables
		o.state = {};	o.state.prev = "NONE";	o.state.curr = "FREE";	o.state.next = "FREE"
		o.callers = {};	o.callers.prev = {};	o.callers.curr = {};	o.callers.next = {}
		o.pass = {};	o.pass.prev = nil;		o.pass.curr = nil;		o.pass.next = nil
		o.T0 = {};		o.T0.prev = nil;		o.T0.curr = nil;		o.T0.next = nil --math.huge	-- timer start
		
		-- Communication outputs
		o.Omsg = {};	o.Omsg.prev = {};		o.Omsg.curr = {};		o.Omsg.next = {}
		o.L4c = {};		o.L4c.prev = {};		o.L4c.curr = {};		o.L4c.next = {}
		
		-- Environmental outputs
		
		-- Monitoring
		
		-- Statistics
		o.count = {}
		o.count[o.state.curr] = 1
		
		-- Assignment starting values
		o.Pstart = {}
		o.Tstart = nil
		o.Cstart = nil

		return o
	end -- new()
	,
	reset = function(self)
		self.state.next = "FREE"
		self.callers.next = {}
		self.pass.next = nil
		self.T0.next = nil
		self.Omsg.next = {}
		self.L4c.next = {}
		
		self.count = {}
		self.count[self.state.curr] = 1
		
		self:empty()
		self:clear_beliefs()
	end -- reset()
	,
	record_call = function(self, parent, msg)
		local id = msg.sender.__id
		local pos = msg.content[1]
		local dest = msg.content[2]
		local ini = parent.L2:get_start()
		local rest = parent.L0:get_rest()	-- distance to get to the next node
		local bid_pick, pick_point = parent.L3:get_cost(ini, pos, rest)
		
		if pick_point.x and pick_point.y then
			local bid_drop = 0
			if full_cost then			-- Include distance from pick-up to drop-off in the cost
				bid_drop = parent.L3:get_cost(pick_point, dest, 0)
			end -- if
			local bid = bid_pick + bid_drop
		
			self.callers.next[id] = {pos = pos, dest = dest, bid = bid}	-- callers[id]: {pos, dest, bid}
			local m = {rcvr = {msg.sender}, perf = "PRP", cont = bid}	-- PRP: sender, bid
			table.insert(self.Omsg.next, m)
		else
			local m = {rcvr = {msg.sender}, perf = "REF", cont = "Unable to reach you"}	-- message elements
			table.insert(self.Omsg.next, m)
		end -- if
	end -- record_call()
	,
	record_assignment = function(self, msg)
		local id = msg.sender.__id
		if self.callers.curr[id] then
			local cost = self.callers.curr[id].bid
			table.insert(self.accepts.curr, {id = id, cost = cost})	-- accepts: {id, cost}
		else
			println(string.format("%s.L4| Warning: %s received from %s but it is not in the auctions list|pass: %s|state: %s|", parent, msg.performative, msg.sender.__id, self.pass.curr, self.state.curr))	-- monitoring
			local m = {rcvr = {msg.sender}, perf = "FAIL", cont = "I do not have record of receiving your CFP"}	-- message elements
			table.insert(self.Omsg.next, m)
			self.Imsg.curr = nil
		end -- if
	end -- record_assignment()
	,
	refuse_call = function(self, msg)
		local m = {rcvr = {msg.sender}, perf = "REF", cont = "Currently busy"}	-- message elements
		table.insert(self.Omsg.next, m)
	end -- refuse_call()
	,
	refuse_assignment = function(self, msg)
		local m = {rcvr = {msg.sender}, perf = "FAIL", cont = "Currently busy"}	-- message elements
		table.insert(self.Omsg.next, m)
	end -- refuse_assignment
	,
	sender_is_passenger = function(self, msg)
		return msg.sender.__id == self.pass.curr
	end -- sender_is_passenger()
	,
	read_environment = function(self, parent, simTime)	-- registers the environmental signals
		self.time.curr = simTime
	end -- read_environment()
	,
	read_inputs = function(self, parent, ans, first)		-- registers the communication inputs
		self.Imsg.curr = nil
		self.accepts.curr = {}
		
		if self.talk then
			local msg = parent.comm.receive(parent)
			while msg do
				local p = string.format("%s_in", msg.performative)
				local m = parent.res.in_msgs[p]
				if m == nil then m = 0 end
				parent.res.in_msgs[p] = m + 1
				local t = parent.res.in_msgs["msgs_received"]
				if t == nil then t = 0 end
				parent.res.in_msgs["msgs_received"] = t + 1

				if msg.performative == "CFP" then			-- if a passenger asks for proposals
					if self.pass.curr then
						if self:sender_is_passenger(msg) then
							if self:at("LOADED") or self:at("DROP") then	-- Error: Should not receive a CFP at this stage
								println(string.format("%s.L4| Warning: %s received from %s and should not happen|state: %s|", parent, msg.performative, msg.sender.__id, self.state.curr))	-- monitoring
							end -- if
							self:record_call(parent, msg)
						else
							self:refuse_call(msg)
						end -- if
					else
						self:record_call(parent, msg)
					end -- if
				elseif msg.performative == "ACCEPT" then	-- if a passenger accepts the proposal
					if self.pass.curr then
						if self:sender_is_passenger(msg) then	-- Error: Should not receive another Accept from the passenger
							println(string.format("%s.L4| Warning: Another %s received from %s|State: %s|", parent, msg.performative, msg.sender.__id, self.state.curr))	-- monitoring
						else
							self:refuse_assignment(msg)
						end -- if
					else
						self.Imsg.curr = msg.performative
						self:record_assignment(msg)
					end -- if
				elseif msg.performative == "ABORT" then		-- task no longer assigned
					if self.pass.curr then
						if self:sender_is_passenger(msg) then
							self.Imsg.curr = msg.performative
							if self:at("LOADED") or self:at("DROP") then	-- Error: Should not receive an Abort at this stage
								println(string.format("%s.L4| Warning: %s received from %s and the travel can not be cancelled|state: %s|", parent, msg.performative, msg.sender.__id, self.state.curr))	-- monitoring
							end -- if
						else									-- Error: Should not receive an Abort from other passengers
							println(string.format("%s.L4| Warning: %s received from %s|pass: %s|state: %s|", parent, msg.performative, msg.sender.__id, self.pass.curr, self.state.curr))	-- monitoring
						end -- if
					else
						println(string.format("%s.L4| Warning: %s received from %s|pass: %s|state: %s|", parent, msg.performative, msg.sender.__id, self.pass.curr, self.state.curr))	-- monitoring
					end -- if
				elseif msg.performative == "ON" then		-- passenger onboard
					if self.pass.curr then
						if self:sender_is_passenger(msg) then	
							if self:at("PICK") then
								self.Imsg.curr = msg.performative
							else
								println(string.format("%s.L4| Warning: %s received from %s|state: %s|", parent, msg.performative, msg.sender.__id, self.state.curr))	-- monitoring
							end -- if
						else								-- Error: Should not receive an On from other passengers
							println(string.format("%s.L4| Warning: %s received from %s|pass: %s|state: %s|", parent, msg.performative, msg.sender.__id, self.pass.curr, self.state.curr))	-- monitoring
						end -- if
					else
						println(string.format("%s.L4| Warning: %s received from %s|pass: %s|state: %s|", parent, msg.performative, msg.sender.__id, self.pass.curr, self.state.curr))	-- monitoring
					end -- if
				elseif msg.performative == "OFF" then		-- passenger offboard
					if self.pass.curr then
						if self:sender_is_passenger(msg) then	
							if self:at("DROP") then
								self.Imsg.curr = msg.performative
							else
								println(string.format("%s.L4| Warning: %s received from %s|state: %s|", parent, msg.performative, msg.sender.__id, self.state.curr))	-- monitoring
							end -- if
						else								-- Error: Should not receive an Off from other passengers
							println(string.format("%s.L4| Warning: %s received from %s|pass: %s|state: %s|", parent, msg.performative, msg.sender.__id, self.pass.curr, self.state.curr))	-- monitoring
						end -- if
					else
						println(string.format("%s.L4| Warning: %s received from %s|pass: %s|state: %s|", parent, msg.performative, msg.sender.__id, self.pass.curr, self.state.curr))	-- monitoring
					end -- if
				else										-- Error: Unknown message
					println(string.format("%s.L4| Warning: %s received from %s|state: %s|", parent, msg.performative, msg.sender.__id, self.state.curr))	-- monitoring
				end -- if chain
					
				msg = parent.comm.receive(parent)
			end -- while
		end -- if
		
		if ans[1] == "OK" then
			self.L3a.curr = ans[1]
			if not self:at("LOADED") and not self:at("BUSY") then
				println(string.format("%s.L4| %s answer received while at %s.", parent, ans[1], self.state.curr))	-- monitoring
			end -- if
		elseif ans[1] == "KO" then
			self.L3a.curr = ans[1]
			if not self:at("LOADED") and not self:at("BUSY") then
				println(string.format("%s.L4| %s answer received while at %s.", parent, ans[1], self.state.curr))	-- monitoring
			end -- if
		elseif not ans[1] then					-- No answer received
			self.L3a.curr = nil
		else									-- Invalid operation code
			self.L3a.curr = nil
			println(string.format("%s.L3|Unknown answer received (%s. Length: %s). State: %s.", parent, ans[1], #ans, self.state.curr))	-- monitoring
		end -- if
	end -- read_inputs()
	,
	monitor = function(self, parent)			-- Monitors given elements of the state machine
		--println(string.format("%s.L4| ----- VARIABLES -----", parent))
		println(string.format("%s	%s	%s		%s", round(self.time.curr, 2), n_cycle, parent, self.state.curr))
		--println(string.format("%s.L4| State: %s", parent, self.state.curr))
		--println(string.format("%s.L4| Callers: %s", parent, #self.callers.curr))
		--println(string.format("%s.L4| Caller 1: %s", parent, self.callers.curr[1]))
		--println(string.format("%s.L4| Pass: %s", parent, self.pass.curr))
		
		--println(string.format("%s.L4| ----- OUTPUTS -----", parent))
		--[[if self.goal.curr[1] then
			println(string.format("%s.L4| Goal: (%s,%s)", parent, self.goal.curr[1].x, self.goal.curr[1].y))
		else
			println(string.format("%s.L4| Goal: %s", parent, self.goal.curr[1]))
		end -- if--]]
		--println(string.format("%s.L4| Out msgs: %s", parent, #self.Omsg.curr))
		--println(string.format("%s.L4| Out msgs: %s", parent, #self.Omsg.curr))
		for i, m in ipairs(self.Omsg.curr) do
			println(string.format("%s	%s	%s			%s", round(self.time.curr, 2), n_cycle, parent, m.perf))
			--println(string.format("%s.L4|	Out msg:	%s	Time	%s	Cycle	%s", parent, m.perf, round(self.time.curr, 2), n_cycle))
			--println(string.format("%s.L4| Out msg: %s", parent, m.perf))
		end -- for
		
		--[[println(string.format("%s.L4| ----- INPUTS -----", parent))
		println(string.format("%s.L4| Auctions: %s", parent, #self.auctions))
		println(string.format("%s.L4| Accepts: %s", parent, #self.accepts))
		println(string.format("%s.L4| Aborted: %s", parent, self.aborted))
		println(string.format("%s.L4| Loaded: %s", parent, self.loaded))
		println(string.format("%s.L4| Bids: %s", parent, #self.bids))
		println(string.format("%s.L4| L3a: %s", parent, self.L3a.curr))--]]
	end -- monitor()
	,
	cmonitor = function(self, parent)			-- Calls monitor() when the machine changes to a different state
		if self.state.prev ~= self.state.curr then
			self:monitor(parent)
		end -- if
	end -- cmonitor()
	,
	get_L4cmd = function(self)					-- Returns the command from L4
		return self.L4c.curr
	end -- get_L4cmd()
	,
	get_L4msgs = function(self)					-- Returns the messages from L4
		return self.Omsg.curr
	end -- get_L4msgs()
	,
	get_count = function(self)					-- Returns the states' count
		return self.count
	end -- get_count()
	,
	write_outputs = function(self, parent)		-- Sends the communication outputs
		-- Graphic representation
		if showTaxi.state.L4 then
			if colorCode == "order" then
				if self:at("FREE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
				elseif self:at("BUSY") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("PICK") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 1})
				elseif self:at("LOADED") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("DROP") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 1})
				end -- if chain
			elseif colorCode == "status" then
				if self:at("FREE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("BUSY") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("PICK") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				elseif self:at("LOADED") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("DROP") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				end -- if chain
			end -- if
		end -- if
	end -- write_outputs()
	,
	write_environment = function(self, parent)	-- Modifies the physical environment
		
	end -- write_environment()
	,
	best_assignment = function(self, list)
		local best = -1
		local winners = {}
		local id = nil
		for i, a in ipairs(list) do	-- a: {id, cost}
			if best < 0 then
				best = a.cost
				winners = {a.id}
			elseif a.cost < best then
				best = a.cost
				winners = {a.id}
			elseif a.cost == best then
				table.insert(winners, a.id)
			end -- if
		end -- for
		local n = math.random(#winners)
		id = winners[n]
		return id
	end -- best_assignment()
	,
	keep_best = function(self, list)
		local id = self:best_assignment(list)
		local fails = {}
		local acpt = table.remove(list)	-- acpt: {id, cost}
		while acpt do
			if not (acpt.id == id) then
				local m = {rcvr = {passengers[acpt.id]}, perf = "FAIL", cont = "Currently busy"}	-- message elements
				table.insert(fails, m)
			end -- if
			acpt = table.remove(list)
		end -- while
		return id, fails
	end -- keep_best()
	,
	step = function(self, parent)
		if self:at("FREE") then
			if self.Imsg.curr == "ACCEPT" then
				local id, fails = self:keep_best(self.accepts.curr)
				self.pass.next = id
				for i, f in ipairs(fails) do
					table.insert(self.Omsg.next, f)
				end -- for
				local goal = self.callers.curr[id].pos
				self:push(self.state.curr)
				self.L4c.next = {"GO", goal}
				self.state.next = "BUSY"
			else
				self.L4c.next = {}
			end -- if
		elseif self:at("BUSY") then
			if self.Imsg.curr == "ABORT" then
				self.pass.next = nil
				self.callers.next = {}
				self.L4c.next = {"Free"}
				self.state.next = self:pop()
			elseif self.L3a.curr == "OK" then
				self.T0.next = self.time.curr
				local m = {rcvr = {passengers[self.pass.curr]}, perf = "READY", cont = "At your location"}
				table.insert(self.Omsg.next, m)
				self.L4c.next = {}
				self.state.next = "PICK"
			elseif self.L3a.curr == "KO" then
				self.pass.next = nil
				self.callers.next = {}
				local m = {rcvr = {passengers[self.pass.curr]}, perf = "FAIL", cont = "No path found"}	-- message elements
				table.insert(self.Omsg.next, m)
				println(string.format("%s.L4.step| No path found while attending: %s.", parent, self.pass.curr))	-- monitoring
				self.L4c.next = {}
				self.state.next = self:pop()
			else
				self.L4c.next = {}
			end -- if
		elseif self:at("PICK") then
			if self.Imsg.curr == "ABORT" then
				self.pass.next = nil
				self.callers.next = {}
				self.L4c.next = {"Free"}
				self.state.next = self:pop()
			elseif self.Imsg.curr == "ON" then
				local goal = self.callers.curr[self.pass.curr].dest
				self.L4c.next = {"GO", goal}
				self.state.next = "LOADED"
			elseif (self.time.curr - self.T0.curr >= self.pick_dl) then	-- The pick-up deadline has been reached
				self.pass.next = nil
				self.callers.next = {}
				local m = {rcvr = {passengers[self.pass.curr]}, perf = "FAIL", cont = "You took too long to get onboard"}	-- message elements
				table.insert(self.Omsg.next, m)
				self.L4c.next = {"Free"}
				self.state.next = self:pop()
			else
				self.L4c.next = {}
			end -- if
		elseif self:at("LOADED") then
			if self.Imsg.curr == "ABORT" then
				println(string.format("T.L4.step| Abort received while at %s. This should not happen.", self.state.curr))
				self.pass.next = nil
				self.callers.next = {}
				self.L4c.next = {"Free"}
				self.state.next = self:pop()
			elseif self.L3a.curr == "OK" then
				self.T0.next = self.time.curr
				local m = {rcvr = {passengers[self.pass.curr]}, perf = "DONE", cont = "At your destination"}
				table.insert(self.Omsg.next, m)
				self.L4c.next = {}
				self.state.next = "DROP"
			elseif self.L3a.curr == "KO" then
				self.pass.next = nil
				self.callers.next = {}
				self.T0.next = self.time.curr
				local m = {rcvr = {passengers[self.pass.curr]}, perf = "FAIL", cont = "No path found"}	-- message elements
				table.insert(self.Omsg.next, m)
				println(string.format("%s.L4.step| No path found while attending: %s.", parent, self.pass.curr))	-- monitoring
				self.L4c.next = {}
				self.state.next = "DROP"
			else
				self.L4c.next = {}
			end -- if
		elseif self:at("DROP") then
			if self.Imsg.curr == "ABORT" then
				println(string.format("T.L4.step| Abort received while at %s. This should not happen.", self.state.curr))
				self.pass.next = nil
				self.callers.next = {}
				self.L4c.next = {"Free"}
				self.state.next = self:pop()
			elseif self.Imsg.curr == "OFF" then
				self.pass.next = nil
				self.callers.next = {}
				self.L4c.next = {"Free"}
				self.state.next = self:pop()
			elseif (self.time.curr - self.T0.curr >= self.drop_dl) then	-- The drop deadline has been reached
				self.pass.next = nil
				self.callers.next = {}
				local m = {rcvr = {passengers[self.pass.curr]}, perf = "FAIL", cont = "You took too long to get offboard"}	-- message elements
				table.insert(self.Omsg.next, m)
				self.L4c.next = {"Free"}
				self.state.next = self:pop()
			else
				self.L4c.next = {}
			end -- if
		else												-- Unknown state
			println(string.format("%s.L4| Unknown state: %s.", parent, self.state.curr))
		end -- if chain
		
		self:record_data(parent)
		if announce then
			self:announce_change()
		end -- if
	end -- step()
	,
	announce_change = function(self)	-- Announces to all Passengers that there is a change in the assignments
		if not (self.Imsg.prev == "ABORT") and not (self.Imsg.prev == "OFF") and
				not self.pass.curr and self.pass.prev then	-- The taxi is unassigned, but not by request from the task manager
			-- Only happens on erroneous situations, like not finding a path to the task after already being assigned to it (path previously calculated to get a cost)
			local m = {rcvr = passengers, perf = "CHANGE", cont = "Rare case"}
			table.insert(self.Omsg.next, m)
		end -- if
	end -- announce_change()
	,
	record_data = function(self, parent)		-- Records data about the task's execution
		if self:changed_to("BUSY") then			-- was assigned
			parent.res.Tasgn = self.time.curr
			self:record_assignment_start(parent, self.pass.curr, self.time.curr)
		elseif self:changed_to("FREE") and not self:prev_at("NONE") then		-- assignment finished
			if self:prev_at("DROP") then		-- the task was completed
				self:record_assignment_end(parent, self.pass.prev, self.time.curr, true)
			else								-- the task was lost
				self:record_assignment_end(parent, self.pass.prev, self.time.curr, false)
			end -- if
		else
			-- do_nothing()
		end -- if
	end -- record_data()
	,
	record_assignment_start = function(self, parent, id, simTime)	-- Records the assignment starting values 
		self.Pstart	= parent:get_pos()
		self.Tstart	= simTime
		self.Cstart	= self.callers.curr[id].bid
	end -- record_assignment_start()
	,
	record_assignment_end = function(self, parent, id, simTime, success)	-- Records the assignment ending values 
		local Pfinal	= parent:get_pos()
		local Tfinal	= simTime
		local Cfinal	= parent:get_travel_dist()
		if not (self.Tstart == Tfinal) then
			if success then
				parent.res.completed = parent.res.completed + 1
			else
				parent.res.lost = parent.res.lost + 1
			end -- if
			local a = 	{m_id = id,
						Compl = success,
						Pstart = self.Pstart, 
						Tstart = self.Tstart, 
						Cstart = self.Cstart, 
						Pfinal = Pfinal, 
						Tfinal = Tfinal, 
						Cfinal = Cfinal}
			table.insert(parent.res.assign, a)
		else
			-- do_nothing()	-- assignment dismissed immediately
		end -- if
		self.Pstart	= {}
		self.Tstart	= nil
		self.Cstart	= nil
	end -- record_assignment_end()
	,
	record_culmination = function(self, parent, simTime)		-- Records the executor's performed activities
		parent.res.posF = parent:get_pos()
		parent.res.finT = simTime
		parent.res.activeT = parent.res.finT - parent.res.initT
		parent.res.o_reroutes, parent.res.s_reroutes = parent:get_reroutes()
		parent.res.reroutes = parent.res.o_reroutes + parent.res.s_reroutes

		if #parent.res.assign > 1 then	-- merges contiguous assignments to the same task
			local e = nil
			local j = {}
			for i, a in ipairs(parent.res.assign) do
				if i == 1 then
					e = a.m_id
				elseif i > 1 then
					if e == a.m_id then
						a.Pstart = parent.res.assign[i - 1].Pstart
						a.Tstart = parent.res.assign[i - 1].Tstart
						a.Cstart = parent.res.assign[i - 1].Cstart
						a.Cfinal = a.Cfinal + parent.res.assign[i - 1].Cfinal
						table.insert(j, 1, i - 1)
					else
						e = a.m_id
					end -- if
				end -- if
			end -- for
			if #j > 0 then
				for i, n in ipairs(j) do
					table.remove(parent.res.assign, n)
				end -- for
			end -- if
		end -- if
		
		-- removes last assignments if not completed
		if #parent.res.assign > 0 then	-- assigned at least to one task
			local valid = false
			while #parent.res.assign > 0 and not valid do
				if parent.res.assign[#parent.res.assign].Compl then
					valid = true
				else
					table.remove(parent.res.assign)
				end -- if
			end -- while
		end -- if
		
		if #parent.res.assign > 0 then	-- completed at least one task
			local max_cost = 0
			local min_cost = math.huge
			for i, a in ipairs(parent.res.assign) do
				local t = a.Tfinal - a.Tstart
				parent.res.busyT = parent.res.busyT + t
				parent.res.totalCost = parent.res.totalCost + a.Cfinal
				if max_cost < a.Cfinal then
					max_cost = a.Cfinal
				end -- if
				if min_cost > a.Cfinal then
					min_cost = a.Cfinal
				end -- if
			end -- for
			parent.res.c_range = max_cost - min_cost
		else
			parent.res.assign[1]		= {}
			parent.res.assign[1].Pstart	= {}
			parent.res.assign[1].Pfinal	= {}
		end -- if
		table.insert(executorsOccupation, parent.res)

parent.data = {	exec_task_completion_ratio	= parent.res.completed,
				exec_task_losing_ratio		= parent.res.lost,
				exec_active_time			= parent.res.activeT,
				exec_occupied_time			= parent.res.busyT,
				exec_occupation_ratio		= parent.res.busyT / parent.res.activeT,
				exec_cost					= parent.res.totalCost,
				exec_cost_range				= parent.res.c_range,
				total_reroutes				= parent.res.reroutes,
				obstacle_reroutes			= parent.res.o_reroutes,
				service_reroutes			= parent.res.s_reroutes}
	end -- record_culmination()
	,
	update = function(self, parent, first)
		local update_event = false
		
		if	self.Imsg.prev			== self.Imsg.curr
		and	self.L3a.prev			== self.L3a.curr
		and	self.state.prev			== self.state.curr
		and	self.callers.prev[1]	== self.callers.curr[1]
		and	self.pass.prev			== self.pass.curr
		and	self.T0.prev			== self.T0.curr
		and	self.Omsg.prev[1]		== self.Omsg.curr[1]
		and	self.L4c.prev[1]		== self.L4c.curr[1] then
			update_event = false
		else
			update_event = true
		end -- if
		
		self.time.prev		= self.time.curr
		self.Imsg.prev		= self.Imsg.curr
		self.accepts.prev	= self.accepts.curr
		self.L3a.prev		= self.L3a.curr
		self.state.prev		= self.state.curr
		self.callers.prev	= self.callers.curr
		self.pass.prev		= self.pass.curr
		self.T0.prev		= self.T0.curr
		self.Omsg.prev		= self.Omsg.curr
		self.L4c.prev		= self.L4c.curr
		
		self.state.curr		= self.state.next
		self.callers.curr	= self.callers.next
		self.pass.curr		= self.pass.next
		self.T0.curr		= self.T0.next
		self.Omsg.curr		= self.Omsg.next
		self.L4c.curr		= self.L4c.next
		
		self.Omsg.next = {}
		
		-- Update immediate values: I = f(S+, V+)
		-- Accounting
		if first then
			local c = self.count[self.state.curr]
			if c == nil then c = 0 end
			self.count[self.state.curr] = c + 1
		end -- if
		
		return update_event
	end -- update()
} -- L4

return L4

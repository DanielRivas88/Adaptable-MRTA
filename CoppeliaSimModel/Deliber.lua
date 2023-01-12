-- Robot fleet MAS: Passenger Agent Deliberative controller (Dlb)
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

local EFSSM = require "EFSSM"

Deliber = {										-- Deliberative controller structure
	tostring = function()
		return "Passenger's deliberative controller"
	end -- tostring()
	,
	new = function(self, cfp_deadline, pos, dest)
		local o = EFSSM:new()
		for k in pairs(self) do o[k] = self[k] end
	
		-- Constants
		o.cfp_wait = cfp_deadline or 6
		o._state_names_ = { "INIT", "GET", "PRI_AUC", "SEC_AUC", "FREE",
							"WAIT", "LOAD", "RIDE", "UNLOAD"}	-- active state names (end states with no actions should not be listed here)
		
		-- Environmental inputs
		o.time = {};	o.time.prev = 0;		o.time.curr = 0			-- Current simulation time
		
		-- Communication inputs
		o.Imsg = {};	o.Imsg.prev = nil;		o.Imsg.curr = nil
		o.Rc = {};		o.Rc.prev = nil;		o.Rc.curr = nil			-- Command from Reactive controller
		
		-- Variables
		o.state = {};	o.state.prev = "NONE";	o.state.curr = "INIT";	o.state.next = "INIT"
		o.pos = {};		o.pos.prev = nil;		o.pos.curr = pos;		o.pos.next = pos
		o.dest = {};	o.dest.prev = nil;		o.dest.curr = dest;		o.dest.next = dest
		o.best = {};	o.best.prev = nil;		o.best.curr = nil;		o.best.next = nil
		o.bid = {};		o.bid.prev = nil;		o.bid.curr = nil;		o.bid.next = nil
		o.a_bid = {};	o.a_bid.prev = nil;		o.a_bid.curr = nil;		o.a_bid.next = nil	-- bid of the agent currently assigned (for Secondary Auctions)
		o.taxi = {};	o.taxi.prev = nil;		o.taxi.curr = nil;		o.taxi.next = nil
		o.i = {};		o.i.prev = 0;			o.i.curr = 0;			o.i.next = 0
		
		-- Communication outputs
		o.Omsg = {};	o.Omsg.prev = {};		o.Omsg.curr = {};		o.Omsg.next = {}	-- Output messages to other agents
		o.Da = {};		o.Da.prev = {};			o.Da.curr = {};			o.Da.next = {}	-- Answer to Reactive

		if announce then	-- announces the arrival of a new task
			local m = {rcvr = passengers, perf = "CHANGE", cont = "New task entered"}
			table.insert(o.Omsg.curr, m)
		end -- if
		
		-- Environmental outputs
		
		-- Monitoring
		
		-- Statistics
		o.count = {}
		o.count[o.state.curr] = 1

		-- Assignment starting values
		o.Pstart = {}
		o.Tstart = nil
		o.Cstart = nil
		o.A_bid = nil

		return o
	end -- new()
	,
	reset = function(self, parent)
		self.state.next = "INIT"
		self.best.next = nil
		self.bid.next = nil
		self.a_bid.next = nil
		self.taxi.next = nil
		self.i.next = 0
		
		self.count = {}
		self.count[self.state.curr] = 1
		
		self:empty()
		self:clear_beliefs()
	end -- reset()
	,
	sender_is_taxi = function(self, msg)
		return msg.sender.__id == self.taxi.curr
	end -- sender_is_taxi()
	,
	read_environment = function(self, parent, simTime)	-- registers the environmental inputs
		self.time.curr = simTime
	end -- read_environment()
	,
	read_inputs = function(self, parent, cmd, first)		-- registers the communication inputs
		self.Imsg.curr = nil
		self.Rc.curr = nil
	
		local msg = parent.comm.receive(parent)
		while msg do

			local p = string.format("%s_in", msg.performative)
			local m = parent.res.in_msgs[p]
			if m == nil then m = 0 end
			parent.res.in_msgs[p] = m + 1

			local t = parent.res.in_msgs["msgs_received"]
			if t == nil then t = 0 end
			parent.res.in_msgs["msgs_received"] = t + 1

			if msg.performative == "PRP" then
				if self:at("GET") then
					self:add_belief(self:create_belief("proposal", {msg.content, msg.sender.__id}))
				end -- if
			elseif msg.performative == "REF" then
				if self:at("GET") then
					self:add_belief(self:create_belief("refusal", {msg.content, msg.sender.__id}))
				end -- if chain
			elseif msg.performative == "FAIL" then
				if self.taxi.curr then
					if self:sender_is_taxi(msg) then
						self.Imsg.curr = msg.performative
					else
						println(string.format("%s.Dlb| %s received from %s while at %s| taxi: %s", parent, msg.performative, msg.sender, self.state.curr, self.taxi.curr))
					end -- if
				else
					println(string.format("%s.Dlb| Warning: %s received from %s while no taxi currently assigned|State: %s|", parent, msg.performative, msg.sender.__id, self.state.curr))	-- monitoring
				end -- if
			elseif msg.performative == "READY" then
				if self.taxi.curr then
					if self:sender_is_taxi(msg) then
						self.Imsg.curr = msg.performative
						if self:at("GET") or self:at("WAIT") or self:at("SEC_AUC") then
						else
							println(string.format("%s.Dlb|Warning: %s received from %s while at %s", parent, msg.performative, msg.sender, self.state.curr))
						end -- if
					else
						local m = {rcvr = {msg.sender}, perf = "ABORT", cont = "You are not assigned to this task"}	-- message elements
						table.insert(self.Omsg.next, m)
						if announce then
							-- Announce to other Passengers that there is an assignment change (a taxi is free)
							m = {rcvr = passengers, perf = "CHANGE", cont = "Not assigned to the task"}
							table.insert(self.Omsg.next, m)
						end -- if
						println(string.format("%s.Dlb| Warning: %s received from another taxi (%s) while at %s| taxi: %s", parent, msg.performative, msg.sender, self.state.curr, self.taxi.curr))
					end -- if
				else
					println(string.format("%s.Dlb| Warning: %s received from %s while no taxi currently assigned|State: %s|", parent, msg.performative, msg.sender.__id, self.state.curr))	-- monitoring
				end -- if
			elseif msg.performative == "DONE" then
				if self.taxi.curr then
					if self:sender_is_taxi(msg) then
						self.Imsg.curr = msg.performative
						if not self:at("RIDE") then		-- Arrival to destination
							println(string.format("%s.Dlb| %s received from %s while at %s| taxi: %s", parent, msg.performative, msg.sender, self.state.curr, self.taxi.curr))
						end -- if
					else
						println(string.format("%s.Dlb| %s received from %s while at %s| taxi: %s", parent, msg.performative, msg.sender, self.state.curr, self.taxi.curr))
					end -- if
				else
					println(string.format("%s.Dlb| Warning: %s received from %s while no taxi currently assigned|State: %s|", parent, msg.performative, msg.sender.__id, self.state.curr))	-- monitoring
				end -- if
			elseif msg.performative == "CHANGE" then
				if announce then
					if self:at("WAIT") and sec_auc_on_change then
						self.Rc.curr = "Re-call"
					elseif self:at("FREE") then
						self.Rc.curr = "Call"
					end -- if
				else
					println(string.format("%s.Dlb| Warning: %s received with the announces system turned off", parent, msg.performative))	-- monitoring
				end -- if
			else								-- Warning:! Unknown performative
				println(string.format("%s.Dlb| Warning: Unknown message (%s) received from %s while at %s| taxi: %s", parent, msg.performative, msg.sender, self.state.curr, self.taxi.curr))
			end -- if
			msg = parent.comm.receive(parent)
		end -- while
		
		if cmd[1] == "Call" then
			self.Rc.curr = cmd[1]
			if self:at("GET") or self:at("WAIT") or self:at("SEC_AUC") or self:at("FREE") then
			else
				println(string.format("%s.Dlb| %s command received while at %s.", parent, cmd[1], self.state.curr))	-- monitoring
			end --if
		elseif cmd[1] == "Re-call" then
			self.Rc.curr = cmd[1]
			if not self:at("WAIT") then
				println(string.format("%s.Dlb| %s command received while at %s.", parent, cmd[1], self.state.curr))	-- monitoring
			end --if
		elseif cmd[1] == "On" then
			self.Rc.curr = cmd[1]
			if not self:at("LOAD") then
				println(string.format("%s.Dlb| %s command received while at %s.", parent, cmd[1], self.state.curr))	-- monitoring
			end --if
		elseif cmd[1] == "Off" then
			self.Rc.curr = cmd[1]
			if not self:at("UNLOAD") then
				println(string.format("%s.Dlb| %s command received while at %s.", parent, cmd[1], self.state.curr))	-- monitoring
			end --if
		elseif cmd[1] == "Stop" then
			self.Rc.curr = cmd[1]
			if not self:at("FREE") then
				println(string.format("%s.Dlb| %s command received while at %s.", parent, cmd[1], self.state.curr))	-- monitoring
			end --if
		elseif not cmd[1] then					-- No command received
		else									-- Invalid operation code
			println(string.format("%s.Dlb|Unknown command received: %s. State: %s.", parent, cmd[1], self.state.curr))	-- monitoring
		end -- if
	end -- read_inputs()
	,
	monitor = function(self, parent)
		--println(string.format("						%s.Dlb| ----- VARIABLES -----", parent))
		println(string.format("%s	%s	%s		%s", round(self.time.curr, 2), n_cycle, parent, self.state.curr))
		--println(string.format("						%s.Dlb| State: %s",	parent, self.state.curr))
		--println(string.format("						%s.Dlb| Taxi: %s.", parent, self.taxi.curr))
		--println(string.format("						%s.Dlb| Pos: (%s,%s).", parent, self.pos.curr.x, self.pos.curr.y))
		--println(string.format("						%s.Dlb| Dest: %s.",	parent, self.dest.curr))
		--println(string.format("						%s.Dlb| Dest: (%s,%s).", parent, self.dest.curr.x, self.dest.curr.y))
		--println(string.format("						%s.Dlb| Cycle counter: %s.", parent, self.i.curr))
		--println(string.format("						%s.Dlb| Winner: %s.", parent, self.best.curr))
		--println(string.format("						%s.Dlb| Winning bid: %s.", parent, self.bid.curr))
		--println(string.format("						%s.Dlb| Assigned agent bid: %s.", parent, self.a_bid.curr))
		
		--println(string.format("						%s.Dlb| ----- OUTPUTS -----", parent))
		--println(string.format("						%s.Dlb| Dlb answer: %s.", parent, self.Da.curr))
		for i, m in ipairs(self.Omsg.curr) do
			println(string.format("%s	%s	%s			%s", round(self.time.curr, 2), n_cycle, parent, m.perf))
			--println(string.format("	%s.Dlb|	Out msg:	%s	Time	%s	Cycle %s", parent, m.perf, round(self.time.curr, 2), n_cycle))
			--println(string.format("						%s.Dlb| Out msg: %s", parent, m.perf))
		end -- for
		
		--println(string.format(						"%s.Dlb| ----- INPUTS -----", parent))
		--println(string.format("						%s.Dlb| Rct cmd: %s.", parent, self.Rc.curr))
	end -- monitor()
	,
	cmonitor = function(self, parent)					-- Calls monitor() when the machine changes to a different state
		if self.state.prev ~= self.state.curr then
			self:monitor(parent)
		end -- if
	end -- cmonitor()
	,
	get_Dans = function(self)					-- Returns the answer from Dlb
		return self.Da.curr
	end -- get_Dans()
	,
	get_Dmsgs = function(self)					-- Returns the messages from Dlb
		return self.Omsg.curr
	end -- get_Dmsgs()
	,
	get_taxi = function(self)					-- Returns the assigned taxi
		return self.taxi.curr
	end -- get_taxi()
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
				elseif self:at("GET") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("PRI_AUC") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 1})
				elseif self:at("WAIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("FREE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("SEC_AUC") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 1})
				elseif self:at("LOAD") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				elseif self:at("RIDE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 1})
				elseif self:at("UNLOAD") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 0})
				elseif self:at("IDLE") then
					if self.stateHandle then	-- added because of shape removal after task completion
						sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 0})
					end -- if
				end -- if chain
			elseif colorCode == "status" then
				if self:at("INIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0.3, 0.5, 1})
				elseif self:at("GET") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0.3, 0.5, 1})
				elseif self:at("PRI_AUC") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0.3, 0.5, 1})
				elseif self:at("WAIT") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 0})
				elseif self:at("FREE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 0, 0})
				elseif self:at("SEC_AUC") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0.3, 0.5, 1})
				elseif self:at("LOAD") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("RIDE") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("UNLOAD") then
					sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				elseif self:at("IDLE") then
					if self.stateHandle then	-- added because of shape removal after task completion
						sim.setShapeColor(self.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 0})
					end -- if
				end -- if chain
			end -- if
		end -- if
	end -- write_outputs()
	,
	write_environment = function(self, parent)	-- Modifies the physical environment
		
	end -- write_environment()
	,
	eval = function(self, assigned)				-- Returns the best bidder
		local best = -1
		local belief = self:get_belief("proposal")		-- proposal: {bid, sender}
		local winners = {}
		local winner = nil
		local curr_agent_bid = nil
		
		while belief do
			local proposal = self:content_of(belief)	-- proposal: {bid, sender}
			
			if assigned and assigned == proposal[2] then
				curr_agent_bid = proposal[1]
			end -- if
			
			if best < 0 then
				best = proposal[1]						-- best: bid
				winners = {proposal[2]}					-- winners: sender
			elseif proposal[1] < best then
				best = proposal[1]
				winners = {proposal[2]}
			elseif proposal[1] == best then
				table.insert(winners, proposal[2])
			end -- if
			belief = self:get_belief("proposal")
		end -- while
		
		if #winners > 0 then
			local reassign = true
			if assigned then
				for i, w in ipairs(winners) do
					if w == assigned then
						reassign = false
					end -- if
				end -- for
			end -- if
			if reassign then
				local n = math.random(#winners)
				winner = winners[n]
			else
				winner = assigned
			end -- if
		else
			winner = nil
		end -- if
		
		return winner, best, curr_agent_bid
	end -- eval()
	,
	step = function(self, parent)
		if self:at("INIT") then
			self.taxi.next = nil
			self.i.next = 0
			self.Da.next = {}
			local m = {rcvr = taxis, perf = "CFP", cont = {self.pos.curr, self.dest.curr}}
			table.insert(self.Omsg.next, m)
			self:push(self.state.curr)
			self:push("PRI_AUC") 
			self.state.next = "GET"
		elseif self:at("GET") then
			self.Da.next = {}
			if self.Imsg.curr == "READY" then
				self.Da.next = {"Arrived"}
				self.state.next = "LOAD"
			elseif self.Imsg.curr == "FAIL" then
				self.taxi.next = nil
			elseif self.Rc.curr == "Call" then
				self.taxi.next = nil
				local m = {rcvr = {taxis[self.taxi.curr]}, perf = "ABORT", cont = "Time for pick-up surpassed"}
				table.insert(self.Omsg.next, m)
			elseif self.i.curr >= self.cfp_wait or #self._knowledge_ >= #taxis then
				self.best.next, self.bid.next, self.a_bid.next = self:eval(self.taxi.curr)
				self.state.next = self:pop()
			else
				self.i.next = self.i.curr + 1
			end -- if
		elseif self:at("PRI_AUC") then
			if self.best.curr then
				self.taxi.next = self.best.curr
				self.Da.next = {"Taken"}
				local m = {rcvr = {taxis[self.best.curr]}, perf = "ACCEPT", cont = "Pick me up"}
				table.insert(self.Omsg.next, m)
				self.state.next = "WAIT"
			else
				self.Da.next = {"No bids"}
				self.state.next = "FREE"
			end -- if
		elseif self:at("SEC_AUC") then
			self.Da.next = {}
			if self.Imsg.curr == "READY" then
				self.Da.next = {"Arrived"}
				self.state.next = "LOAD"
			elseif self.Imsg.curr == "FAIL" then
				self.taxi.next = nil
				self.state.next = "PRI_AUC"
			elseif self.Rc.curr == "Call" then
				self.taxi.next = nil
				self.state.next = "PRI_AUC"
				local m = {rcvr = {taxis[self.taxi.curr]}, perf = "ABORT", cont = "Time for pick-up surpassed"}
				table.insert(self.Omsg.next, m)
			elseif not self.best.curr then
				self.Da.next = {"No bids"}
				if self.taxi.curr then
					self.state.next = self:pop()
					local m = {rcvr = {taxis[self.taxi.curr]}, perf = "ABORT", cont = "You did not participate in the re-auction"}
					table.insert(self.Omsg.next, m)
					println(string.format("%s.Dlb| No bid presented in re-auction, assigned agent: %s", parent, self.taxi.curr))	-- monitoring
				else
					self.state.next = "FREE"
				end -- if
			elseif self.taxi.curr == self.best.curr then
				self.state.next = "WAIT"
			else
				self.taxi.next = self.best.curr
				self.state.next = "WAIT"
				local m = {rcvr = {taxis[self.best.curr]}, perf = "ACCEPT", cont = "You won the re-auction"}
				table.insert(self.Omsg.next, m)
				m = {rcvr = {taxis[self.taxi.curr]}, perf = "ABORT", cont = "You lost the re-auction"}
				table.insert(self.Omsg.next, m)
			end -- if
		elseif self:at("WAIT") then
			self.Da.next = {}
			if self.Imsg.curr == "READY" then
				self.Da.next = {"Arrived"}
				self.state.next = "LOAD"
			elseif self.Imsg.curr == "FAIL" then
				self.Da.next = {"Untaken"}
				self.state.next = self:pop()
			elseif self.Rc.curr == "Call" then
				self.state.next = self:pop()
				local m = {rcvr = {taxis[self.taxi.curr]}, perf = "ABORT", cont = "Time for pick-up surpassed"}
				table.insert(self.Omsg.next, m)
			elseif self.Rc.curr == "Re-call" then
				self.i.next = 0
				local m = {rcvr = taxis, perf = "CFP", cont = {self.pos.curr, self.dest.curr}}	-- CFP: sender (id), {pos, dest}
				table.insert(self.Omsg.next, m)
				self:push("SEC_AUC")
				self.state.next = "GET"
			end -- if
		elseif self:at("LOAD") then
			self.Da.next = {}
			if self.Imsg.curr == "FAIL" then
				self.Da.next = {"Untaken"}
				self:empty()
				self:push("INIT")
				self.state.next = "UNLOAD"
			elseif self.Rc.curr == "On" then
				local m = {rcvr = {taxis[self.taxi.curr]}, perf = "ON", cont = "I am inside the vehicle"}
				table.insert(self.Omsg.next, m)
				self.state.next = "RIDE"
			end -- if
		elseif self:at("RIDE") then
			if self.Imsg.curr == "FAIL" then
				self.Da.next = {"Untaken"}
				self:empty()
				self:push("INIT")
				self.state.next = "UNLOAD"
			elseif self.Imsg.curr == "DONE" then			-- Taxi ready for drop-off
				self.Da.next = {"Arrived"}
				self:push("IDLE")
				self.state.next = "UNLOAD"
			else
				self.Da.next = {}
			end -- if
		elseif self:at("UNLOAD") then
			self.Da.next = {}
			if self.Imsg.curr == "FAIL" then
				self.taxi.next = nil
			end -- if
			if self.Rc.curr == "Off" then
				local m = {rcvr = {taxis[self.taxi.curr]}, perf = "OFF", cont = "I am outside the vehicle"}
				table.insert(self.Omsg.next, m)
				self.state.next = self:pop()
			end -- if
		elseif self:at("FREE") then
			self.Da.next = {}
			if self.Rc.curr == "Call" then
				self.state.next = self:pop()
			elseif self.Rc.curr == "Stop" then
				self.state.next = "IDLE"
			end -- if
		elseif self:at("IDLE") then
			self.Da.next = {}
			if self:prev_at("UNLOAD") then
				passengers_arrived = passengers_arrived + 1
			end -- if
		else -- Unknown state
			println(string.format("%s.Dlb| Unknown state: %s.", parent, self.state.curr))
		end -- if chain
		
		self:record_data(parent)
		if announce then
			self:announce_change()
		end -- if
	end -- step()
	,
	announce_change = function(self)	-- Announces to all Passengers that there is a change in the assignments
		if not self:at("FREE") and not self.Imsg.curr and self.Rc.curr == "Call" then	-- Time for pick-up surpassed
			local m = {rcvr = passengers, perf = "CHANGE", cont = "Time for pick-up surpassed"}
			table.insert(self.Omsg.next, m)
		elseif self:at("SEC_AUC") and not self.Imsg.curr then
			if not (self.best.curr) or not (self.taxi.curr == self.best.curr) then	-- Not participating or loosing SEC_AUC
				local m = {rcvr = passengers, perf = "CHANGE", cont = "It loosed the re-auction"}
				table.insert(self.Omsg.next, m)
			end -- if
		elseif self:at("UNLOAD") and self.Rc.curr == "Off" then		-- task completed
			local m = {rcvr = passengers, perf = "CHANGE", cont = "I am outside the vehicle"}
			table.insert(self.Omsg.next, m)
		end -- if 
	end -- announce_change()
	,
	record_data = function(self, parent)		-- Records data about the task's execution
		if not (self.taxi.curr) and self.taxi.prev then	-- was unassigned
			self:record_assignment_end(parent, self.taxi.prev, self.time.curr)
		elseif self:at("WAIT") and self:prev_at("PRI_AUC") then	-- was assigned. waiting started
			parent.res.Tasgn = self.time.curr
			self:record_assignment_start(self.taxi.curr, self.time.curr, self.bid.curr)
		elseif self:at("WAIT") and self:prev_at("SEC_AUC") then	-- re-auction finished
			if not self.taxi.prev then		-- was unassigned and assigned (FAIL while at GET)
				self:record_assignment_start(self.taxi.curr, self.time.curr, self.bid.curr)
			elseif not (self.taxi.curr == self.taxi.prev) then	-- was re-assigned
				local prev_cost = self.Cstart
				self:record_assignment_end(parent, self.taxi.prev, self.time.curr)
				self:record_assignment_start(self.taxi.curr, self.time.curr, self.bid.curr, self.a_bid.prev)
			end -- if
		elseif self:changed_to("LOAD") then	-- waiting finished. pick-up started
			parent.res.Tpick = self.time.curr
		elseif self:changed_to("RIDE") then	-- pick-up finished. travel started
			parent.res.Tload = self.time.curr
		elseif self:changed_to("UNLOAD") then	-- travel finished. drop-off started
			parent.res.Tdrop = self.time.curr
		elseif self:changed_to("IDLE") then	-- drop-off finished
			if self.taxi.curr then
				parent.res.Tunld = self.time.curr
				self:record_assignment_end(parent, self.taxi.curr, self.time.curr)
				self:record_completion(parent, true)
			else							-- Not attended or FAIL received while at UNLOAD (should not happen)
				self:record_completion(parent, false)
			end -- if
		else
			-- do_nothing()
		end -- if
	end -- record_data()
	,
	record_assignment_start = function(self, id, simTime, winning_bid, agent_bid)	-- Records the assignment starting values 
		self.Pstart	= taxis[id]:get_pos()
		self.Tstart	= simTime
		self.Cstart	= winning_bid
		self.A_bid = agent_bid
	end -- record_assignment_start()
	,
	record_assignment_end = function(self, parent, id, simTime)		-- Records the assignment ending values 
		local Pfinal	= taxis[id]:get_pos()
		local Tfinal	= simTime
		local Cfinal	= taxis[id]:get_travel_dist()
		if not (self.Tstart == Tfinal) then
			local a = 	{e_id = id,
						Pstart = self.Pstart, 
						Tstart = self.Tstart, 
						Cstart = self.Cstart, 
						A_bid = self.A_bid,
						Pfinal = Pfinal, 
						Tfinal = Tfinal, 
						Cfinal = Cfinal}
			table.insert(parent.res.assign, 1, a)
		else
			-- do_nothing()	-- assignment dismissed immediately
		end -- if
		self.Pstart	= {}
		self.Tstart	= nil
		self.Cstart	= nil
	end -- record_assignment_end()
	,
	record_completion = function(self, parent, success)		-- Records the task completion
		if success then
			parent.res.completed = 1
		else
			parent.res.completed = 0
		end -- if
		
		if not parent.res.Tasgn then
			-- do_nothing()
		elseif not parent.res.Tpick then
			parent.res.Tfree		= parent.res.Tasgn - parent.res.Tinit
		elseif not parent.res.Tload then
			parent.res.Tfree		= parent.res.Tasgn - parent.res.Tinit
			parent.res.Twait		= parent.res.Tpick - parent.res.Tasgn
		elseif not parent.res.Tdrop then
			parent.res.Tfree		= parent.res.Tasgn - parent.res.Tinit
			parent.res.Twait		= parent.res.Tpick - parent.res.Tasgn
			parent.res.Tg_on		= parent.res.Tload - parent.res.Tpick
		elseif not parent.res.Tunld then
			parent.res.Tfree		= parent.res.Tasgn - parent.res.Tinit
			parent.res.Twait		= parent.res.Tpick - parent.res.Tasgn
			parent.res.Tg_on		= parent.res.Tload - parent.res.Tpick
			parent.res.Ttrav		= parent.res.Tdrop - parent.res.Tload
		else
			parent.res.Tcomplete	= parent.res.Tunld - parent.res.Tasgn
			parent.res.Tsatisfy		= parent.res.Tunld - parent.res.Tinit
			parent.res.Tfree		= parent.res.Tasgn - parent.res.Tinit
			parent.res.Twait		= parent.res.Tpick - parent.res.Tasgn
			parent.res.Tg_on		= parent.res.Tload - parent.res.Tpick
			parent.res.Ttrav		= parent.res.Tdrop - parent.res.Tload
			parent.res.Tg_off		= parent.res.Tunld - parent.res.Tdrop
		end -- if chain
		
		if #parent.res.assign > 1 then	-- merges contiguous assignments to the same agent
			local e = nil
			local j = {}
			
			for i, a in ipairs(parent.res.assign) do
				if i == 1 then
					e = a.e_id
				elseif i > 1 then
					if e == a.e_id then
						a.Pfinal = parent.res.assign[i - 1].Pfinal
						a.Tfinal = parent.res.assign[i - 1].Tfinal
						a.Cfinal = a.Cfinal + parent.res.assign[i - 1].Cfinal
						table.insert(j, 1, i - 1)
					else
						e = a.e_id
					end -- if
				end -- if
			end -- for
			if #j > 0 then
				for i, n in ipairs(j) do
					table.remove(parent.res.assign, n)
				end -- for
			end -- if
		end -- if
		
		if #parent.res.assign > 0 then
			parent.res.reassigned = #parent.res.assign - 1
		end -- if
		
		if #parent.res.assign > 1 then
			local total_Cdif = 0	-- full task cost estimation difference
			local total_Cstart = 0	-- full task estimated cost
			local total_Cfinal = 0	-- full task real cost
			
			for i, a in ipairs(parent.res.assign) do
				local cd = (a.A_bid or 0) - (a.Cstart or 0)
				if i == 1 then
					total_Cdif = total_Cdif + cd
					total_Cstart = total_Cstart + a.Cstart
					total_Cfinal = total_Cfinal + a.Cfinal
				elseif i < #a then
					total_Cdif = total_Cdif + cd
					total_Cstart = total_Cstart + a.Cfinal
					total_Cfinal = total_Cfinal + a.Cfinal
				else
					total_Cstart = total_Cstart + a.Cfinal
					total_Cfinal = total_Cfinal + a.Cfinal
				end -- if
			end -- for
			parent.res.c_improve = total_Cdif
			
			local f = parent.res.assign[1]
			
			local full = {e_id = f.e_id,
						Pstart = f.Pstart, 
						Tstart = f.Tstart, 
						Cstart = total_Cstart, 
						A_bid = nil,
						Pfinal = f.Pfinal, 
						Tfinal = f.Tfinal, 
						Cfinal = total_Cfinal}
			table.insert(parent.res.assign, 1, full)
		else
			parent.res.c_improve = 0
		end -- if
		
		-- difference between estimated and real cost for the whole task
		if #parent.res.assign > 0 then
			if parent.res.Tunld then
				parent.res.c_diff = parent.res.assign[1].Cfinal - parent.res.assign[1].Cstart
			end -- if
		else
			parent.res.assign[1]		= {}
			parent.res.assign[1].Pstart	= {}
			parent.res.assign[1].Pfinal	= {}
		end -- if
		
		table.insert(tasksCompletion, parent.res)
		
		parent.data = {	task_completion_ratio						= parent.res.completed,
						task_completion_time						= parent.res.Tcomplete,
						task_satisfaction_time						= parent.res.Tsatisfy,
						task_unassigned_time						= parent.res.Tfree,
						task_waiting_time							= parent.res.Twait,
						task_gettingIn_time							= parent.res.Tg_on,
						task_traveling_time							= parent.res.Ttrav,
						task_gettingOff_time						= parent.res.Tg_off,
						task_reassignments							= parent.res.reassigned,
						task_estimated_cost							= parent.res.assign[1].Cstart,
						task_real_cost								= parent.res.assign[1].Cfinal,
						task_cost_estimation_improvement			= parent.res.c_improve,
						task_realCost_to_estimatedCost_difference	= parent.res.c_diff}
	end -- record_completion()
	,
	update = function(self, parent, first)
		local update_event = false
		
		if self:at("INIT") then
			self:clear_beliefs()
		elseif self:at("WAIT") then
			if not self.Imsg.curr and self.Rc.curr == "Re-call" then
				self:clear_beliefs()
			end -- if
		end -- if
		
		if	self.Imsg.prev	== self.Imsg.curr
		and	self.Rc.prev	== self.Rc.curr
		and	self.state.prev	== self.state.curr
		and	self.dest.prev	== self.dest.curr
		and	self.best.prev	== self.best.curr
		and	self.bid.prev	== self.bid.curr
		and	self.a_bid.prev	== self.a_bid.curr
		and	self.taxi.prev	== self.taxi.curr
		and	self.i.prev		== self.i.curr
		and	self.Omsg.prev[1]	== self.Omsg.curr[1]
		and	self.Da.prev[1]	== self.Da.curr[1] then
			update_event = false
		else
			update_event = true
		end -- if
		
		self.Imsg.prev	= self.Imsg.curr
		self.Rc.prev	= self.Rc.curr
		self.state.prev	= self.state.curr
		self.dest.prev	= self.dest.curr
		self.best.prev	= self.best.curr
		self.bid.prev	= self.bid.curr
		self.a_bid.prev	= self.a_bid.curr
		self.taxi.prev	= self.taxi.curr
		self.i.prev		= self.i.curr
		self.Omsg.prev	= self.Omsg.curr
		self.Da.prev	= self.Da.curr
		
		self.state.curr	= self.state.next
		self.dest.curr	= self.dest.next
		self.best.curr	= self.best.next
		self.bid.curr	= self.bid.next
		self.a_bid.curr	= self.a_bid.next
		self.taxi.curr	= self.taxi.next
		self.i.curr		= self.i.next
		self.Omsg.curr	= self.Omsg.next
		self.Da.curr	= self.Da.next
		
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
} -- Deliber

return Deliber

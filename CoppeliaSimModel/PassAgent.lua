-- Robot fleet MAS: Task Manager Agent
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

local EFSSM = require "EFSSM"
local Delib = require "Deliber"
local React = require "Reactive"

local Passenger = {
	__id = 0,
	tostring = function(self)
		return "Pass_"..self.__id
	end, -- tostring
	
	new = function(self, comm, map, pos, dest, simTime, width, long, height, 
					cfp_deadline, auctions_limit, primary_deadline,
					secondary_deadline, pick_deadline, load_time, unload_time, completion_time, priority)	-- Creates a new passenger instance
		
		local o = EFSSM:new()
		self.__id = self.__id + 1; o.__id = self.__id	-- Asigns and updates ID number
		for k in pairs(self) do o[k] = self[k] end
		
		-- Registring instance parameters
		local cfp_dl = cfp_deadline or 6				-- 3
		local max_aucs = auctions_limit or math.huge	-- 10
		local PA_wait = primary_deadline or 5			-- math.huge
		local SA_wait = secondary_deadline or 10		-- math.huge
		local pick_wait = pick_deadline or math.huge	-- 25
		local load_wait = load_time or 0
		local unload_wait = unload_time or 0
		
		-- Constants
		o.comm = comm; o.comm.setup(o)
		
		-- Environmental inputs
		
		-- Communication inputs
		
		-- Variables
		
		-- Communication outputs
		o.M = {}					-- Output messages list
		
		-- Environmental outputs
		
		-- Controllers
		o.Dlb = Delib:new(cfp_dl, pos, dest)
		o.Rct = React:new(map, pos, o.__id, max_aucs, PA_wait, SA_wait, pick_wait, load_wait, unload_wait)	
		
		-- Statistics
		o.count = {}
		
		o.data = {}
				
		-- Results recording
		o.res			= {}		-- results record structure
		o.res.m_id		= o.__id	-- manager id
		o.res.completed	= nil		-- completion status
		o.res.pos		= pos		-- starting position
		o.res.dest		= {}		-- destination
		o.res.dest.x	= nil
		o.res.dest.y	= nil
		o.res.dest.name	= dest
		o.res.Tcomplete	= nil
		o.res.Tsatisfy	= nil
		o.res.Tfree		= nil
		o.res.Twait		= nil
		o.res.Tg_on		= nil
		o.res.Ttrav		= nil
		o.res.Tg_off	= nil
		o.res.Tfin		= completion_time
		o.res.Tinit		= simTime
		o.res.Tasgn		= nil
		o.res.Tpick		= nil
		o.res.Tload		= nil
		o.res.Tdrop		= nil
		o.res.Tunld		= nil
		o.res.priority	= priority
		o.res.reassigned = 0		-- number of reassignments
		o.res.assign	= {}		-- structure for assigned taxis data
		o.res.c_improve = nil		-- cost estimation improvement
		o.res.c_diff	= nil		-- real to estimated cost difference
		o.res.in_msgs	= {}		-- received messages
		o.res.out_msgs	= {}		-- sent messages
		
		-- Graphical representation
		local w = width or 0.15
		local l = long or 0.15
		local h = height or 0.25
		if showPass.body or showPass.handling then
			o.passHandle = sim.createPureShape(2, 18, {w, l, h}, 0, nil)	-- Physical passenger handle
			sim.setObjectPosition(o.passHandle, -1, {pos.x, pos.y, b_height + h / 2})
			sim.setShapeColor(o.passHandle, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 1})
		end -- if
		if showPass.dest then
			o.destHandle = {}		-- Passenger destination handle
			for i, p in ipairs(map.port) do
				if p.name == dest then
					local xDest = p.patch.x
					local yDest = p.patch.y
					local zDest = 1.5 * 0.25 + 0.01
					o.destHandle.i = sim.createPureShape(2, 18, {w, l, 0}, 0, nil)	-- Passenger destination handle
					sim.setObjectPosition(o.destHandle.i, -1, {xDest, yDest, zDest})
					sim.setShapeColor(o.destHandle.i, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
				end -- if
			end -- for
		end -- if
		if showPass.state.delib then
			o.Dlb.stateHandle = sim.createPureShape(2, 18, {w + 0.01, l + 0.01, h / 2}, 0, nil)	-- Color band handle
			sim.setObjectPosition(o.Dlb.stateHandle, -1, {0, 0, h / 4 + 0.01})
			sim.setShapeColor(o.Dlb.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 1})
			sim.setObjectParent(o.Dlb.stateHandle, o.passHandle, false)
		end -- if
		if showPass.state.react then
			o.Rct.stateHandle = sim.createPureShape(2, 18, {w + 0.01, l + 0.01, h / 2}, 0, nil)	-- Color band handle
			sim.setObjectPosition(o.Rct.stateHandle, -1, {0, 0, -h / 4})
			sim.setShapeColor(o.Rct.stateHandle, nil, sim_colorcomponent_ambient_diffuse, {0, 1, 0})
			sim.setObjectParent(o.Rct.stateHandle, o.passHandle, false)
		end -- if
		
		return o
	end -- new()
	,
	reset = function(self)
		self.M = {}
		
		self.Dlb:reset(self)
		self.Rct:reset(self)
	end -- reset()
	,
	is_idle = function(self)			-- returns if the passenger finished its order
		return (self.Dlb:at("IDLE") and self.Rct:at("IDLE"))
	end -- is_idle()
	,
	read_environment = function(self, simTime)	-- registers the environmental inputs
		local Dlb_event = self.Dlb:read_environment(self, simTime)
		local Rct_event = self.Rct:read_environment(self, simTime)
	end -- read_environment()
	,
	read_inputs = function(self, first)	-- registers the input signals
		local Rct_cmd = self.Rct:get_Rcmd()
		local Dlb_ans = self.Dlb:get_Dans()
		
		local Dlb_event = self.Dlb:read_inputs(self, Rct_cmd, first)
		local Rct_event = self.Rct:read_inputs(self, Dlb_ans, first)
	end -- read_inputs()
	,
	monitor = function(self)
		self.Dlb:monitor(self)
		self.Rct:monitor(self)
	end -- monitor()
	,
	cmonitor = function(self)			-- Calls monitor() when the machine changes to a different state
		--self.Dlb:cmonitor(self)
		--self.Rct:cmonitor(self)
	end -- cmonitor()
	,
	get_taxi_pos = function(self)		-- Returns the position of the assigned taxi
		local t = self.Dlb:get_taxi()
		local p = taxis[t]:get_pos()
		return p
	end -- get_taxi_pos()
	,
	save_counts = function(self)		-- Registers data for statistical analysis and labels it with the controller name
		local d = self.Dlb:get_count()	-- table with amount of cycles at each state (Dlb.count[state])
		for c in pairs(d) do			-- for each state (c) in Dlb.count (d)
			local s = string.format("Dlb.%s", c)
			self.count[s] = d[c]
		end -- for
		
		d = self.Rct:get_count()		-- table with amount of cycles at each state (Rct.count[state])
		for c in pairs(d) do			-- for each state (c) in Rct.count (d)
			local s = string.format("Rct.%s", c)
			self.count[s] = d[c]
		end -- for
	end -- save_counts()
	,
	write_outputs = function(self)		-- Sends the communication outputs
		local Dlb_event = self.Dlb:write_outputs(self)
		local Rct_event = self.Rct:write_outputs(self)
		
		self.M = self.Dlb:get_Dmsgs()
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
				if e.perf == "CFP" then
					pError = math.max(comm_error.all, comm_error.cfp)
				elseif e.perf == "ACCEPT" then
					pError = math.max(comm_error.all, comm_error.accept)
				elseif e.perf == "ABORT" then
					pError = math.max(comm_error.all, comm_error.abort)
				elseif e.perf == "ON" then
					pError = math.max(comm_error.all, comm_error.on)
				elseif e.perf == "OFF" then
					pError = math.max(comm_error.all, comm_error.off)
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
		local Dlb_event = self.Dlb:write_environment(self)
		local Rct_event = self.Rct:write_environment(self)
	end -- write_environment()
	,
	step = function(self)				-- Calculates the controllers next actuation
		local Dlb_event = self.Dlb:step(self)
		local Rct_event = self.Rct:step(self)
		
		if self:is_idle() and not self.Dlb:prev_at("IDLE") then
			-- Graphical representation
			if self.passHandle then
				sim.removeObject(self.passHandle)
				self.passHandle = nil
			end -- if
			if self.Dlb.stateHandle then
				sim.removeObject(self.Dlb.stateHandle)
				self.Dlb.stateHandle = nil
			end -- if
			if self.Rct.stateHandle then
				sim.removeObject(self.Rct.stateHandle)
				self.Rct.stateHandle = nil
			end -- if
			if self.destHandle then		-- Passenger destination handle
				for i, d in ipairs(self.destHandle) do
					sim.removeObject(d)
				end -- for
				self.destHandle = nil
			end -- if
		end -- if
		
	end -- step()
	,
	update = function(self, first)
		local update_event	= false
		local Dlb_event		= self.Dlb:update(self, first)
		local Rct_event		= self.Rct:update(self, first)
		
		return	update_event or Dlb_event or Rct_event
	end -- update()
	,
	active = function(self)
		return	self.Dlb:active() and
				self.Rct:active()
	end -- active()
} -- Passenger

return Passenger

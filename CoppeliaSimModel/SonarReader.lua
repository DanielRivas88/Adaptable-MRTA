-- Robot fleet MAS: Executor Agent sonar reader
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

SR = {										-- Sonar reader state machine's structure
	tostring = function()					-- Returns the controller name
		return "Taxi's sonar reader"
	end -- tostring()
	,
	new = function(self)					-- Creates a new Sonar reader instance
		r = {}
		for k in pairs(self) do r[k] = self[k] end
		
		-- Constants
		r.console = nil --sim.auxiliaryConsoleOpen("Taxi "..c.__id.."'s sonar reader console", 500, 0x10)
		
		-- Environmental inputs
		
		-- Communication inputs
		r.echo = {};		r.echo.prev = nil;	r.echo.curr = nil	-- INPUT:	echo	--r.E
		
		-- Variables
		r.state = {};		r.state.prev = "NONE";	r.state.curr = "INIT";	r.state.next = "INIT"	-- State
		r.p = {};			r.p.prev = false;		r.p.curr = false		-- Indicates if a ping must be sent
		
		-- Communication outputs
		r.ping = {};		r.ping.prev = nil;		r.ping.curr = ""
		r.sonarDist = {};	r.sonarDist.prev = nil;	r.sonarDist.curr = nil
		
		-- Physical outputs
		
		return r
	end -- new()
	,
	reset = function(self, parent)			-- resets the controller
		self.state.curr = "INIT"
		self.p.curr = false
		self.ping.curr = ""
		self.sonarDist.curr = nil
	end -- reset()
	,
	read_environment = function(self, parent, first)
		
	end -- read_environment()
	,
	read_inputs = function(self, parent, sonar_echo, first)	-- registers the input signals
		if self.state.curr == "WAIT" then
			if sonar_echo then
				self.echo.curr = sonar_echo
			else
				self.echo.curr = nil
			end -- if
		else
			self.echo.curr = nil
		end -- if
	end -- read_inputs()
	,
	monitor = function(self, parent)		-- Monitors the state machine constantly
		print(string.format("Taxi "..parent.__id.." sonar reader's state: %s, Ping = ", self.state.curr))
		if (self.p) then print("true")
		else print("false")
		end -- if
		println(string.format(" obsDist = %icm\n", self.obsDist.curr)) 
	end -- monitor()
	,
	cmonitor = function(self, parent)		-- calls monitor at certain events
		if (self.state.prev ~= self.state.curr) then
			--self.state.prev = self.state.curr
			--self:monitor(parent)
		end -- if
	end -- cmonitor()
	,
	get_distance = function(self, parent)	-- Returns the measured distance
		return self.sonarDist.curr
	end -- get_distance()
	,
	get_ping = function(self, parent)		-- Returns ping
		return self.ping.curr
	end -- get_ping()
	,
	write_outputs = function(self, parent)	-- Establishes the output signals
		if self.p.curr then
			self.ping.curr = "PING"
		else
			self.ping.curr = "PING"
		end -- if
	end -- write_outputs()
	,
	write_environment = function(self, parent)	-- Modifies the environment
		
	end -- write_environment()
	,
	step = function(self, parent)			-- Calculates the controller next actuation
		if self.state.curr == "INIT" then
			self.state.next = "PING"
		elseif self.state.curr == "PING" then
			self.state.next = "WAIT"
		elseif self.state.curr == "WAIT" then
			if self.echo.curr then
				self.sonarDist.curr = self.echo.curr
				self.state.next = "PING"
			end -- if
		else -- Stop state or error
		end -- if chain
	end -- step()
	,
	update = function(self, parent)			-- Updates the variables values
		local update_event = false
		
		if self.state.curr == "PING" then
			self.p.curr = true
		else
			self.p.curr = false
		end -- if chain
		
		self.state.curr = self.state.next
		
		-- Update immediate values: I = f(S+, V+)
		return update_event
	end -- update()
	,
	active = function(self)					-- Disables the machine if it goes to an undefined state
		return  self.state.curr == "INIT" or
				self.state.curr == "PING" or
				self.state.curr == "WAIT"
	end -- active()
} -- SR

return SR
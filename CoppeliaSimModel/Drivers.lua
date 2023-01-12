-- Robot fleet MAS: Executor Agent drivers
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

DV = {										-- Drivers state machine's structure
	tostring = function()					-- Returns the controller name
		return "Executor's drivers"
	end -- tostring()
	,
	new = function(self)					-- Creates a new Drivers instance
		d = {}
		for k in pairs(self) do d[k] = self[k] end

		-- Constants
		
		-- Environmental inputs
		
		-- Communication inputs
		d.string = {};	d.string.prev = nil;		d.string.curr = ""	-- String received through the ping tube
		
		-- Variables
		
		-- Communication outputs
		d.echo = {};	d.echo.prev = math.huge;	d.echo.curr = math.huge
		
		-- Physical outputs
		
		return d
	end -- new()
	,
	reset = function(self, parent)			-- resets the controller
		self.string.curr = ""
		self.echo.curr = math.huge
	end -- reset()
	,
	read_environment = function(self, parent, simTime, ping, first)	-- Measures the distance to the closest obstacle
		local in_event = false
		
		local data = ping					-- Gets the input data
		if data then						-- Something has been received
			self.string.curr = data			-- Save the input data
		end -- if chain

		if (#self.string.curr > 0) then		-- Some command was received:
			result, distance, detectedPoint = sim.checkProximitySensor(parent.sensorHandle, sim.handle_all)	-- Check the readings from the sensor
			if result == 1 then				-- Something is detected
				self.string.curr = ""		-- Clear the ping string
				self.echo.curr = distance	-- Send the measured distance
			elseif result == 0 then			-- Nothing is detected
				self.string.curr = ""		-- Clear the ping string
				distance = math.huge		-- Set the measured distance to infinite
				self.echo.curr = distance	-- Send the measured distance
			end -- if chain
		end -- if chain
		
		return in_event
	end -- read_environment()
	,
	read_inputs = function(self, parent, first)
		
	end -- read_inputs()
	,
	monitor = function(self, parent)		-- Monitors given elements of the state machine
		--println(string.format("Taxi "..parent.__id.."  Sonar Drivers"))
	end -- monitor()
	,
	cmonitor = function(self, parent)		-- Calls monitor() at certain events
		self:monitor(parent)
	end -- cmonitor()
	,
	get_echo = function(self)				-- Returns the measured distance
		return self.echo.curr
	end -- get_echo()
	,
	write_outputs = function(self, parent)	-- Establishes the output signals
		
	end -- write_outputs()
	,
	write_environment = function(self, parent)	-- Modifies the environment
		
	end -- write_environment()
	,
	step = function(self, parent)			-- Calculates the controller next actuation
		
	end -- step()
	,
	update = function(self, parent)			-- Updates the variables values
		local update_event = false
		
		self.string.prev = self.string.curr
		self.echo.prev = self.echo.curr
		
		-- Update immediate values: I = f(S+, V+)
		return update_event
	end -- update()
	,
	active = function(self)					-- checks that the controller is active
		return true
	end -- active()
} -- DV

return DV
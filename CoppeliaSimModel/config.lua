-- Robot fleet MAS: Model configuration
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

--------------------------- FREQUENTLY USED CONFIGURATION PARAMETERS ---------------------------

-- Folder path to the model
folder = "C://folder/folder/CoppeliaSimModel"

-- PHYSICAL CHARACTERISTICS
	-- Mobile agents
		ang_vel = 30					-- [degrees/s]
		speed = 1						-- [m/s]

	-- Task managers
		load_time = 5					-- [s]
		unload_time = 5					-- [s]

-- AGENTS INITIALIZATION
	-- Executors
		number_of_taxis = 10			-- Number of active taxis
		number_of_obstacles = 0			-- Number of moving obstacles

	-- Tasks managers 
		passengersMax = 252				-- Maximum number of active passengers

-- SIMULATION PARAMETERS
	-- Execution parameters
	maxRuns = 100						-- Maximum number of executions to perform
	timeLimit = 7200 					-- Maximum simulation time
	
	-- Model parameters
			layout = "warehouse"			-- defines the layout to run the simulation
				-- Possible values: warehouse, workshop
			announce = true					-- announces when there are assignments changes, for all Managers to perform (re)auctions
			sec_auc_on_change = true		-- defines if secondary auctions launch on announces of assignment changes

	-- Task managers
		cfp_deadline = 6
		auctions_limit = math.huge
		primary_deadline = math.huge	-- [s]
		secondary_deadline = math.huge	-- [s]
		pick_deadline = math.huge		-- [s]

-- RESULTS GENERATION SECTION
	showStats = false					-- Shows the general statistics at the end of the run
	showSolution = true					-- Shows the assignment solution
		
--------------------------- LESS COMMONLY USED CONFIGURATION PARAMETERS ---------------------------

-- GRAPHIC REPRESENTATION
	-- Topography
		showMap = {}					-- topography related structure
		showMap.blocks = true			-- shows the layout's blocks
		showMap.streets = true			-- shows the layout's streets
		showMap.floor = true			-- shows an homogeneus floor
		showMap.ports = false			-- shows the layout's ports
		showMap.gates = false			-- shows the ports' gates

	-- Agents
		colorCode = "status"			-- Sets color representation of states
			-- Possible values: order, status

		-- Mobile agents
			showTaxi = {}				-- executors related structure
			showTaxi.body = true		-- shows the executors' body skin
			showTaxi.state = {}			-- executors state machines related structure
			showTaxi.state.L4 = true	-- shows L4 state in color code
			showTaxi.state.L3 = true	-- shows L3 state in color code
			showTaxi.state.L2 = true	-- shows L2 state in color code
			showTaxi.state.L1 = true	-- shows L1 state in color code
			showTaxi.state.L0 = true	-- shows L0 state in color code
			showTaxi.nodes = false		-- shows the executors' current node and next node
			showTaxi.path = false		-- shows the executors' path to the next location
			showTaxi.fullPath = false	-- shows the executors' path to complete the task (from location to position and from position to destination)
			showTaxi.keepPath = false	-- shows the executors' followed paths along the whole run

		-- Task managers
			showPass = {}				-- managers related structure
			showPass.body = true		-- shows the managers' body skin
			showPass.state = {}			-- managers state machines related structure
			showPass.state.delib = true	-- shows Delib state in color code
			showPass.state.react = true	-- shows React state in color code
			showPass.dest = false		-- shows the managers' destination
			showPass.handling = true	-- shows the managers' loading and unloading process

-- PHYSICAL CHARACTERISTICS
	-- Blocks (environment)
		b_width = 1						-- [m]
		b_long = 1						-- [m]
		b_height = 0.5					-- [m]

	-- Mobile agents
		x_scale = 1
		y_scale = 1
		r_width = 0.75					-- [m]
		r_long = 0.75					-- [m]
		r_height = 0.5					-- [m]
		safe_dist = 0.5					-- [m]

	-- Task managers
		o_width = 0.3					-- [m]
		o_long = 0.3					-- [m]
		o_height = 0.15					-- [m]
		
-- AGENTS INITIALIZATION
	-- Tasks managers 
		-- Planned insertion
			task_max_duration = 3600	-- Maximum time from task beginning to its end [s]
			port_sequence = false		-- sets if there is a port sequence to be followed or not
			task_return = true			-- sets if the task should be followed by another going in inverse direction
			sequence_time_separation = 25 -- time separation between tasks (from conclusion to initiation) [s]
		
		-- Dynamic insertion
			dynamism = "none"			-- Sets how unplanned tasks are inserted 
				-- Possible values: none, constant_amount, uniform_distribution
			passengersActive = 4		-- Number of active passengers (for constant_amount dynamism mode)
			prob_of_passengers = 5		-- Passenger creation probability per time step (for uniform_distribution dynamism mode)
			port_distinction = "name"	-- sets how to distinguish random pick-up and drop-off ports.
				-- Possible values: name, coords, none, same

-- SIMULATION PARAMETERS
	-- Executors
		block_deadline = 2				-- [s]
		accept_deadline = math.huge		-- [s]
		picking_deadline = math.huge	-- [s]
		drop_deadline = math.huge		-- [s]
		full_cost = true				-- 'true' includes distance from pick-up to drop-off in the cost
		
	-- Communication errors insertion
		comm_error = {}					-- Communication errors list
		comm_error.all = 0				-- Error probability in all messages [0 to 1]
		comm_error.cfp = 0				-- Error probability in CFP messages [0 to 1]
		comm_error.prp = 0				-- Error probability in PRP messages [0 to 1]
		comm_error.ref = 0				-- Error probability in REF messages [0 to 1]
		comm_error.accept = 0			-- Error probability in ACCEPT messages [0 to 1]
		comm_error.fail = 0				-- Error probability in FAIL messages [0 to 1]
		comm_error.abort = 0			-- Error probability in ABORT messages [0 to 1]
		comm_error.ready = 0			-- Error probability in READY messages [0 to 1]
		comm_error.on = 0				-- Error probability in ON messages [0 to 1]
		comm_error.done = 0				-- Error probability in DONE messages [0 to 1]
		comm_error.off = 0				-- Error probability in OFF messages [0 to 1]
		
-- MONITORING SECTION
	-- Traffic management monitoring
		showMap.served = false			-- shows the changes on the nodes' service list (traffic management)
		pose_override = true			-- sets if L1 corrects the agent pose at the end of each command to avoid cumulative errors from L0
	
	-- Simple representation
		showMap.changed = true			-- shows the changes in the environment as a text output

---------------------------------------------------------------------------------------------------
-------------------------- MODEL'S FUNCTIONALITY CONSTANTS AND VARIABLES --------------------------
-------------------------------------- (DO NOT MODIFY!!!) -----------------------------------------
---------------------------------------------------------------------------------------------------

-- AGENTS INITIALIZATION (DO NOT MODIFY!!!)
	-- Executors
		obstacles = {}					-- List of wandering vehicles (not participating in the solution)
		taxis = {}						-- List of active taxis
		taxis_not_moving = 0			-- Number of taxis not moving for unknown reasons
		taxis_not_moving_max = 3 + number_of_taxis	-- Maximum number of not moving taxis allowed
		locked = false					-- signal if all taxis are not moving
		lock_init = 0					-- marks the start of the deadlock
		cancel_simulation = false		-- signals that the simulation should stop
		
		-- Planned insertion
			execs_start = {}			-- list of executors' starting positions

	-- Tasks managers 
		passengers = {}					-- List of active passengers
		passengers_arrived = 0			-- Number of completed orders

		-- Planned insertion
			plan = {}					-- List of planned tasks
				-- plan item = {Ti, Tf, pos, dest, priority}

-- SIMULATION PARAMETERS (DO NOT MODIFY!!!)
	-- Execution repetition parameters
		runs = 1						-- Number of executions completed
		start = true					-- flag to signal the start of a run
		startingSimTime = 0				-- Simulation time at the start of the run
		
-- RESULTS GENERATION SECTION (DO NOT MODIFY!!!)
	-- printing order for the statistical data presentation
	stats_order = {	"real_cost",
					"expected_cost",
					"expected_cost_improvement",
					"solution_quality",
					"simTime_consumption",
					"system_time_consumption",
					"completed_tasks",
					"exec_occupation_ratio",
					"exec_task_cost_range",
					"task_reassignments",
					"messages_received",
					"messages_sent",
					"exec_reroutes"}
	
	tasksCompletion = {}				-- list of tasks' completion details
		--[[completion item:
			-- i:			order of completion
			-- m_id:		manager id number
			-- completed:	completion	['1' if successful, '0' if failed]
			-- pos:			position port.		pos = {x = port.x, y = port.y, name = port.name}
			-- dest:		destination port.	dest = {x = port.x, y = port.y, name = port.name}
			
			-- Tcomplete:	time to complete a task (from first assignment to completion)
			-- Tsatisfy:	time to satisfy a task (from insertion to completion)
			-- Tfree:		time while unassigned
			-- Twait:		time while waiting for pick-up
			-- Tg_on:		time while getting on the vehicle
			-- Ttrav:		time while traveling to the destination
			-- Tg_off:		time while getting off the vehicle
			
			-- Tinit:		time when entered the system
			-- Tasgn:		time when changed from unassigned to assigned
			-- Tpick:		time when ready for pick-up
			-- Tload:		time when got inside the vehicle
			-- Tdrop:		time when ready for drop-off
			-- Tunld:		time when got outside the vehicle
			-- Tfin:		maximum time at which the task had to be satisfied
			-- priority:	task priority number
			-- reassigned:	amount of times the task assignment changed
			-- assign:		list of assigned vehicles
				-- e_id:	executor id number
				-- Pstart:	starting position.	Pstart = {x,y}
				-- Pfinal:	final position.		Pfinal = {x,y}
				-- Tstart:	assignment starting time
				-- Tfinal:	assignment final time
				-- Cstart:	estimated cost (PRP cost)
				-- A_bid:	bid of the assigned agent losing the Secondary Auction
				-- Cfinal:	final cost (traveled distance)
			-- Cimprov:		cost estimation improvement when reassigned (Cstart' - Cstart)
			-- Cdiff:		cost estimation to real cost difference (Cfinal - Cstart)
			--]]
	
	executorsOccupation = {}			-- list of executors' assignments details
		--[[ocupation item:
			-- e_id:		executor id number
			-- completed:	amount of tasks completed
			-- lost:		amount of tasks lost
			-- posI:		initial position.	posI = {x, y}
			-- posF:		final position.		posF = {x, y}
			-- initT:		activation time
			-- finT:		deactivation time
			-- activeT:		time while active
			-- busyT:		time while assigned
			-- total_cost:	total distance traveled
			-- c_range:		difference between most costly completed task and less costly one
			-- o_reroutes:	reroute requests due to obstacle detection
			-- s_reroutes:	reroute requests due to no service from a node
			-- reroutes:	total amount of reroute requests
			-- assign:		list of assigned tasks
				-- m_ID:	manager id number
				-- Compl:	completion status
				-- Pstart:	starting position.	Pstart = {x,y}
				-- Pfinal:	final position.		Pfinal = {x,y}
				-- Tstart:	assignment starting time
				-- Tfinal:	assignment final time
				-- Cstart:	estimated cost (PRP cost)
				-- Cfinal:	final cost (traveled distance)
				--]]
			

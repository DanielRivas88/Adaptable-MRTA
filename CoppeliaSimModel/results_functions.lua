-- Robot fleet MAS: Results and statistics generation
-- (C) 2020-2022 Daniel Rivas Alonso, UAB

function start()							-- initializes the file for the statistical data recording
	local line1 = "run	"
	local line2 = "number	"
	for i, k in ipairs(stats_order) do
		if k == "real_cost" then
			line1 = string.format(line1.."real cost		")
			line2 = string.format("%stotal	mngr avg	mngr sd", line2)
		elseif k == "expected_cost" then
			line1 = string.format("%s	expected cost		", line1)
			line2 = string.format("%s	total	mngr avg	mngr sd", line2)
		elseif k == "expected_cost_improvement" then
			line1 = string.format("%s	expected cost improvement		", line1)
			line2 = string.format("%s	total	mngr avg	mngr sd", line2)
		elseif k == "solution_quality" then
			line1 = string.format("%s	solution quality", line1)
			line2 = string.format("%s	total", line2)
		elseif k == "simTime_consumption" then
			line1 = string.format("%s	simulation time consumption		", line1)
			line2 = string.format("%s	total	mngr avg	mngr sd", line2)
		elseif k == "system_time_consumption" then
			line1 = string.format("%s	system time consumption	", line1)
			line2 = string.format("%s	total	mngr avg", line2)
		elseif k == "completed_tasks" then
			line1 = string.format("%s	completed tasks				", line1)
			line2 = string.format("%s	total	mngr avg	mngr sd	exec avg	exec sd", line2)
		elseif k == "exec_occupation_ratio" then
			line1 = string.format("%s	executor occupation ratio	", line1)
			line2 = string.format("%s	exec avg	exec sd", line2)
		elseif k == "exec_task_cost_range" then
			line1 = string.format("%s	exec's task cost range	", line1)
			line2 = string.format("%s	exec avg	exec sd", line2)
		elseif k == "task_reassignments" then
			line1 = string.format("%s	tasks reassignments		", line1)
			line2 = string.format("%s	total	mngr avg	mngr sd", line2)
		elseif k == "messages_received" then
			line1 = string.format("%s	messages received	", line1)
			line2 = string.format("%s	total	agent avg", line2)
		elseif k == "messages_sent" then
			line1 = string.format("%s	messages sent	", line1)
			line2 = string.format("%s	total	agent avg", line2)
		elseif k == "exec_reroutes" then
			line1 = string.format("%s	executor reroutes		", line1)
			line2 = string.format("%s	total	exec avg	exec sd", line2)
		end -- if
	end -- for
	local head1 = string.format("Executors: %s", number_of_taxis)
	local head2 = string.format("Tasks to complete: %s", passengersMax)
	local head3 = string.format("Concurrent active tasks: %s", passengersActive)
	local head4 = string.format("Time limit: %s", timeLimit)
	
	println(head1);	println(head2);	println(head3);	println(head4)
	println(line1);	println(line2)
	
	local file = io.open(filename, "a")		-- creates a file 
	file:write("\n")
	file:write(head1);	file:write("\n");	file:write(head2);	file:write("\n")
	file:write(head3);	file:write("\n");	file:write(head4);	file:write("\n")
	file:write(line1);	file:write("\n");	file:write(line2);	file:write("\n")
	file:close()
end -- start()

function get_stats_of(agents)				-- efficient standard deviation calculation
	local stats = { d = {}, s = {}, n = {} }
		-- stats.d: standard deviation
		-- stats.s: mean
		-- stats.n: amount
	for i, p in ipairs(agents) do			-- for each element in agents' list
		for c in pairs(p.count) do			-- for each element in p.count
			-- p.count:	table with amount of cycles at each state (p.count[state])
			-- c: state
			if stats.n[c] then							-- if the section for that state? exists
				stats.n[c] = stats.n[c] + 1				-- increase 'n' in 1
				stats.s[c] = stats.s[c] + p.count[c]	-- increase 's' in 'count'
				stats.d[c] = stats.d[c] + p.count[c]*p.count[c]	-- increase 'd' in 'count'^2
			else										-- if the section for that state? does not exist
				stats.n[c] = 1							-- 'n' is 1
				stats.s[c] = p.count[c]					-- 's' is 'count'
				stats.d[c] = p.count[c]*p.count[c]		-- 'd' is 'count'^2
			end -- if
		end -- for
	end -- for
	for c in pairs(stats.n) do		-- for each state in 'stats.n'
		if stats.n[c] > 1 then		-- if the count is higher than 1
			stats.d[c] = math.sqrt((stats.d[c]-stats.s[c]*stats.s[c]/stats.n[c])/(stats.n[c]-1))
		else						-- if the count is not higher than 1
			stats.d[c] = 0			-- standard deviation is 0
		end -- if
		stats.s[c] = stats.s[c] / stats.n[c]	-- mean formula
	end -- for

	return stats
end -- get_stats_of()

function get_msgs_stats(agents)				-- avg (and standard deviation) number of messages exchanged
	local stats = { d = {}, s = {}, n = {}, t = {} }
		-- stats.d: standard deviation
		-- stats.s: mean
		-- stats.n: amount
		-- stats.t: total
	for i, p in ipairs(agents) do			-- for each element in agents' list
		local in_count = p.res.in_msgs		-- table with amount of input msgs per performative (in_count[perf])
		local out_count = p.res.out_msgs	-- table with amount of output msgs per performative (out_count[perf])
		for c in pairs(in_count) do			-- for each element in the list
			-- c: performative
			if stats.n[c] then							-- if the section for that perfromative exists
				stats.n[c] = stats.n[c] + 1				-- increase 'n' in 1
				stats.s[c] = stats.s[c] + in_count[c]	-- increase 's' in 'count'
				stats.d[c] = stats.d[c] + in_count[c] * in_count[c]	-- increase 'd' in 'count'^2
			else										-- if the section for that performative does not exist
				stats.n[c] = 1							-- 'n' is 1
				stats.s[c] = in_count[c]				-- 's' is 'count'
				stats.d[c] = in_count[c] * in_count[c]	-- 'd' is 'count'^2
			end -- if
		end -- for
		for c in pairs(out_count) do			-- for each element in the list
			-- c: performative
			if stats.n[c] then							-- if the section for that perfromative exists
				stats.n[c] = stats.n[c] + 1				-- increase 'n' in 1
				stats.s[c] = stats.s[c] + out_count[c]	-- increase 's' in 'count'
				stats.d[c] = stats.d[c] + out_count[c] * out_count[c]	-- increase 'd' in 'count'^2
			else										-- if the section for that performative does not exist
				stats.n[c] = 1							-- 'n' is 1
				stats.s[c] = out_count[c]				-- 's' is 'count'
				stats.d[c] = out_count[c]*out_count[c]	-- 'd' is 'count'^2
			end -- if
		end -- for
	end -- for
	for c in pairs(stats.n) do		-- for each state in 'stats.n'
		if stats.n[c] > 1 then		-- if the count is higher than 1
			stats.d[c] = math.sqrt((stats.d[c]-stats.s[c]*stats.s[c]/stats.n[c])/(stats.n[c]-1))
		else						-- if the count is not higher than 1
			stats.d[c] = 0			-- standard deviation is 0
		end -- if
		stats.t[c] = stats.s[c]
		stats.s[c] = stats.s[c] / stats.n[c]	-- mean formula
	end -- for

	return stats
end -- get_msgs_stats()

function get_solution_stats(agents)			-- Statistics of the assignment solution
	local stats = { d = {}, s = {}, n = {}, t = {} }
		-- stats.d: standard deviation
		-- stats.s: mean
		-- stats.n: amount
		-- stats.t: total
	for i, p in ipairs(agents) do			-- for each element in agents' list
		for c in pairs(p.data) do			-- for each element in p.data
			-- p.data:	table with the values for each metric (p.data[metric])
			-- c: metric
			if stats.n[c] then							-- if the section for that metric exists
				stats.n[c] = stats.n[c] + 1				-- increase 'n' in 1
				stats.s[c] = stats.s[c] + p.data[c]		-- increase 's' in 'data'
				stats.d[c] = stats.d[c] + p.data[c] * p.data[c]	-- increase 'd' in 'data'^2
			else										-- if the section for that metric does not exist
				stats.n[c] = 1							-- 'n' is 1
				stats.s[c] = p.data[c]					-- 's' is 'data'
				stats.d[c] = p.data[c] * p.data[c]		-- 'd' is 'data'^2
			end -- if
		end -- for
	end -- for
	for c in pairs(stats.n) do		-- for each metric in 'stats.n'
		if stats.n[c] > 1 then		-- if the amount is higher than 1
			stats.d[c] = math.sqrt((stats.d[c]-stats.s[c]*stats.s[c]/stats.n[c])/(stats.n[c]-1))	-- corrected standard deviation formula
		else						-- if the amount is not higher than 1
			stats.d[c] = 0			-- standard deviation is 0
		end -- if
		stats.t[c] = stats.s[c]
		stats.s[c] = stats.s[c] / stats.n[c]	-- mean formula
	end -- for

	return stats
end -- get_solution_stats()

function show_state_statistics()			-- Shows the average time (and standard deviation) at each state
	println(string.format(""))
	println(string.format("Total passengers: %s", #passengers))	-- monitoring
	println(string.format(""))
	for i, p in ipairs(passengers) do p:save_counts() end -- for
	local stats = get_stats_of(passengers)
	for k in pairs(stats.n) do
		println(string.format("At %s = (avg.) %.2f +/- (SD) %.2f seconds", k, stats.s[k]*dt, stats.d[k]*dt))
	end -- for
	println("")

	for i, t in ipairs(taxis) do t:save_counts() end -- for
	stats = get_stats_of(taxis)
	for k in pairs(stats.n) do
		println(string.format("At %s = (avg.) %.2f +/- (SD) %.2f seconds", k, stats.s[k]*dt, stats.d[k]*dt))
	end -- for
	println("")
end -- show_state_statistics()

function generate_solution()				-- Generates the allocation solution for the tasks
	for i, p in ipairs(passengers) do		-- for each element in passengers list
		if not p.Dlb:at("IDLE") then
			p.Dlb:record_completion(p, false)
		end -- if
	end -- for
	
	for i, t in ipairs(taxis) do			-- for each element in taxis list
		t.L4:record_culmination(t, simTime)
	end -- for
end -- generate_solution()

function show_solution(resumed)				-- Shows the assignment solution for the tasks
	if resumed then
		println(string.format("ID	Completed	A_ID	A_start_T	A_final_T	A_estimated_cost	A_real_cost	Cost_estim_improve"))
		for i, r in ipairs(tasksCompletion) do
			println(string.format("%s	%s	%s	%s	%s	%s	%s	%s", r.m_id, r.completed, r.assign[1].e_id, 
					round(r.assign[1].Tstart, 2), round(r.assign[1].Tfinal, 2), r.assign[1].Cstart, r.assign[1].Cfinal, r.c_improve))
			if #r.assign > 1 then
				local first = table.remove(r.assign, 1)
				for j, a in ipairs(r.assign) do
					println(string.format("		%s	%s	%s	%s	%s	", a.e_id, round(a.Tstart, 2),	round(a.Tfinal, 2),	a.Cstart, a.Cfinal))
				end -- for
				table.insert(r.assign, 1, first)
			end -- if
		end -- for
		println("")
		println(string.format("ID	activeT	busyT	total_cost	A_ID	A_completed	A_startT	A_finalT"))
		for i, r in ipairs(executorsOccupation) do
			println(string.format("%s	%s	%s	%s	%s	%s	%s	%s",
				r.e_id, 
				round(r.activeT, 2), 
				round(r.busyT, 2), 
				r.totalCost, 
				r.assign[1].m_id, 
				r.assign[1].Compl, 
				round(r.assign[1].Tstart, 2), 
				round(r.assign[1].Tfinal, 2)))
			
			if #r.assign > 1 then
				local first = table.remove(r.assign, 1)
				for j, a in ipairs(r.assign) do
					println(string.format("				%s	%s	%s	%s", a.m_id, a.Compl, round(a.Tstart, 2), round(a.Tfinal, 2)))
				end -- for
				table.insert(r.assign, 1, first)
			end -- if
		end -- for
		println("")
	else
		println(string.format("Completion order	ID	Completed	port_x	port_y	port_name	dest_x	dest_y	dest_name	T_complete	T_satisfy	T_free	T_waiting	T_get_on	T_travel	T_get_off	T_init	T_assign	T_pick	T_load	T_drop	T_unld	T_fin	Priority	N_reassign	A_ID	A_start_x	A_start_y	A_final_x	A_final_y	A_start_T	A_final_T	A_estimated_cost	A_looser_bid	A_real_cost	Cost_estim_improve	Cost_diff"))
		for i, r in ipairs(tasksCompletion) do
			println(string.format("%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s",
				i, r.m_id, r.completed, r.pos.x, r.pos.y, r.pos.name, r.dest.x, r.dest.y, r.dest.name, round(r.Tcomplete, 2), round(r.Tsatisfy , 2), round(r.Tfree, 2), round(r.Twait, 2), round(r.Tg_on, 2), round(r.Ttrav, 2), round(r.Tg_off, 2), round(r.Tinit, 2), round(r.Tasgn, 2), round(r.Tpick, 2), round(r.Tload, 2), round(r.Tdrop, 2), round(r.Tunld, 2), round(r.Tfin, 2), r.priority, r.reassigned, r.assign[1].e_id, r.assign[1].Pstart[1], r.assign[1].Pstart[2], r.assign[1].Pfinal[1], r.assign[1].Pfinal[2], round(r.assign[1].Tstart, 2), round(r.assign[1].Tfinal, 2), r.assign[1].Cstart, r.assign[1].A_bid, r.assign[1].Cfinal, r.c_improve, r.c_diff))
			
			if #r.assign > 1 then
				local first = table.remove(r.assign, 1)
				for j, a in ipairs(r.assign) do
					println(string.format("																									%s	%s	%s	%s	%s	%s	%s	%s	%s	%s		",
										a.e_id, a.Pstart[1], a.Pstart[2], a.Pfinal[1], a.Pfinal[2],	round(a.Tstart, 2),	round(a.Tfinal, 2),	a.Cstart, a.A_bid, a.Cfinal))
				end -- for
				table.insert(r.assign, 1, first)
			end -- if
		end -- for
		println("")
		println(string.format("ID	Completed	Lost	initP_x	initP_y	finP_x	finP_y	initT	finT	activeT	busyT	total_cost	c_range	total_reroutes	obs_reroutes	serv_reroutes	A_ID	A_completed	A_start_x	A_start_y	A_final_x	A_final_y	A_startT	A_finalT	A_estimated_cost	A_real_cost"))
		for i, r in ipairs(executorsOccupation) do
			println(string.format("%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s	%s",
				r.e_id, r.completed, r.lost, r.posI[1], r.posI[2], r.posF[1], r.posF[2], round(r.initT, 2), round(r.finT , 2), round(r.activeT, 2), round(r.busyT, 2), r.totalCost, r.c_range, r.reroutes, r.o_reroutes, r.s_reroutes, r.assign[1].m_id, r.assign[1].Compl, r.assign[1].Pstart[1], r.assign[1].Pstart[2], r.assign[1].Pfinal[1], r.assign[1].Pfinal[2], round(r.assign[1].Tstart, 2), round(r.assign[1].Tfinal, 2), r.assign[1].Cstart, r.assign[1].Cfinal))
			
			if #r.assign > 1 then
				local first = table.remove(r.assign, 1)
				for j, a in ipairs(r.assign) do
					println(string.format("																%s	%s	%s	%s	%s	%s	%s	%s	%s	%s",
										a.m_id, a.Compl, a.Pstart[1], a.Pstart[2], a.Pfinal[1], a.Pfinal[2], round(a.Tstart, 2), round(a.Tfinal, 2), a.Cstart, a.Cfinal))
				end -- for
				table.insert(r.assign, 1, first)
			end -- if
		end -- for
		println("")
	end -- if
end -- show_solution()

function show_statistics(elements)			-- Shows the solution statistics according to the input order
	local all_right = true
	local real_cost					= {}
	local expected_cost				= {}
	local expected_cost_improvement	= {}
	local solution_quality			= {}
	local simTime_consumption		= {}
	local system_time_consumption	= {}
	local completed_tasks			= {}
	local exec_occupation_ratio		= {}
	local exec_task_cost_range		= {}
	local task_reassignments		= {}
	local messages_received			= {}
	local messages_sent				= {}
	local exec_reroutes				= {}
	
	local total_cost = 0
	local max_cost = 0 -- -1
	for i, r in ipairs(executorsOccupation) do
		total_cost = total_cost + r.totalCost
		if r.totalCost > max_cost then
			max_cost = r.totalCost
		end -- if
	end -- for
	real_cost.total = total_cost
	solution_quality.total = max_cost
	
	simTime_consumption.total = simTime
	system_time_consumption.total = calcTime
	
	local completed = 0
	local estimated_cost = 0
	local cost_improvement = 0
	local reassignments = 0
	for i, r in ipairs(tasksCompletion) do
		completed = completed + r.completed
		estimated_cost = estimated_cost + (r.assign[1].Cstart or 0)
		cost_improvement = cost_improvement + r.c_improve
		reassignments = reassignments + r.reassigned
	end -- for
	completed_tasks.total = completed
	expected_cost.total = estimated_cost
	expected_cost_improvement.total = cost_improvement
	task_reassignments.total = reassignments
	
	system_time_consumption.mngr_avg = system_time_consumption.total / completed_tasks.total
	
	local pass_stats = get_solution_stats(passengers)
	for k in pairs(pass_stats.n) do
		local avg = pass_stats.s[k]
		local sd = pass_stats.d[k]
		if k == "task_completion_ratio" then
			completed_tasks.mngr_avg = avg
			completed_tasks.mngr_sd = sd
		elseif k == "task_satisfaction_time" then
			simTime_consumption.mngr_avg = avg
			simTime_consumption.mngr_sd = sd
		elseif k == "task_reassignments" then
			task_reassignments.mngr_avg = avg
			task_reassignments.mngr_sd = sd
		elseif k == "task_estimated_cost" then
			expected_cost.mngr_avg = avg
			expected_cost.mngr_sd = sd
		elseif k == "task_real_cost" then
			real_cost.mngr_avg = avg
			real_cost.mngr_sd = sd
		elseif k == "task_cost_estimation_improvement" then
			expected_cost_improvement.mngr_avg = avg
			expected_cost_improvement.mngr_sd = sd
		end -- if chain
	end -- for
	
	local taxi_stats = get_solution_stats(taxis)
	local reroutes = 0
	for k in pairs(taxi_stats.n) do
		local avg = taxi_stats.s[k]
		local sd = taxi_stats.d[k]
		if k == "exec_occupation_ratio" then
			exec_occupation_ratio.exec_avg = avg
			exec_occupation_ratio.exec_sd = sd
		elseif k == "exec_task_completion_ratio" then
			completed_tasks.exec_avg = avg
			completed_tasks.exec_sd = sd
		elseif k == "exec_cost_range" then
			exec_task_cost_range.exec_avg = avg
			exec_task_cost_range.exec_sd = sd
		elseif k == "total_reroutes" then
			reroutes = reroutes + taxi_stats.t[k]
			exec_reroutes.exec_avg = avg
			exec_reroutes.exec_sd = sd
		end -- if chain
	end -- for
	exec_reroutes.total = reroutes
	
	local pass_msgs = get_msgs_stats(passengers)
	local tasks_received_msgs = 0
	local receiver_tasks = 0
	local tasks_sent_msgs = 0
	local sender_tasks = 0
	for k in pairs(pass_msgs.n) do
		if k == "msgs_received" then
			tasks_received_msgs = tasks_received_msgs + pass_msgs.t[k]
			receiver_tasks = receiver_tasks + pass_msgs.n[k]
		elseif k == "msgs_sent" then
			tasks_sent_msgs = tasks_sent_msgs + pass_msgs.t[k]
			sender_tasks = sender_tasks + pass_msgs.n[k]
		end -- if
	end -- for
	
	local exec_msgs = get_msgs_stats(taxis)
	local execs_received_msgs = 0
	local receiver_execs = 0
	local execs_sent_msgs = 0
	local sender_execs = 0
	for k in pairs(exec_msgs.n) do
		if k == "msgs_received" then
			execs_received_msgs = execs_received_msgs + exec_msgs.t[k]
			receiver_execs = receiver_execs + exec_msgs.n[k]
		elseif k == "msgs_sent" then
			execs_sent_msgs = execs_sent_msgs + exec_msgs.t[k]
			sender_execs = sender_execs + exec_msgs.n[k]
		end -- if
	end -- for
	
	messages_received.total = tasks_received_msgs + execs_received_msgs
	messages_received.agent_avg = messages_received.total / (receiver_tasks + receiver_execs)
	messages_sent.total = tasks_sent_msgs + execs_sent_msgs
	messages_sent.agent_avg = messages_sent.total / (sender_tasks + sender_execs)
	
	local line3 = string.format("%s	", runs)
	for i, k in ipairs(elements) do
		if k == "real_cost" then
			line3 = string.format("%s%s	%s	%s", line3, real_cost.total, real_cost.mngr_avg, real_cost.mngr_sd)
		elseif k == "expected_cost" then
			line3 = string.format("%s	%s	%s	%s", line3, expected_cost.total, expected_cost.mngr_avg, expected_cost.mngr_sd)
		elseif k == "expected_cost_improvement" then
			line3 = string.format("%s	%s	%s	%s", line3, expected_cost_improvement.total, expected_cost_improvement.mngr_avg, expected_cost_improvement.mngr_sd)
		elseif k == "solution_quality" then
			line3 = string.format("%s	%s", line3, solution_quality.total)
		elseif k == "simTime_consumption" then
			line3 = string.format("%s	%s	%s	%s", line3, simTime_consumption.total, simTime_consumption.mngr_avg, simTime_consumption.mngr_sd)
		elseif k == "system_time_consumption" then
			line3 = string.format("%s	%s	%s", line3, system_time_consumption.total, system_time_consumption.mngr_avg)
		elseif k == "completed_tasks" then
			line3 = string.format("%s	%s	%s	%s	%s	%s", line3, completed_tasks.total, completed_tasks.mngr_avg, completed_tasks.mngr_sd, completed_tasks.exec_avg, completed_tasks.exec_sd)
		elseif k == "exec_occupation_ratio" then
			line3 = string.format("%s	%s	%s", line3, exec_occupation_ratio.exec_avg, exec_occupation_ratio.exec_sd)
		elseif k == "exec_task_cost_range" then
			line3 = string.format("%s	%s	%s", line3, exec_task_cost_range.exec_avg, exec_task_cost_range.exec_sd)
		elseif k == "task_reassignments" then
			line3 = string.format("%s	%s	%s	%s", line3, task_reassignments.total, task_reassignments.mngr_avg, task_reassignments.mngr_sd)
		elseif k == "messages_received" then
			line3 = string.format("%s	%s	%s", line3, messages_received.total, messages_received.agent_avg)
		elseif k == "messages_sent" then
			line3 = string.format("%s	%s	%s", line3, messages_sent.total, messages_sent.agent_avg)
		elseif k == "exec_reroutes" then
			line3 = string.format("%s	%s	%s	%s", line3, exec_reroutes.total, exec_reroutes.exec_avg, exec_reroutes.exec_sd)
		end -- if chain
	end -- for
	
	if expected_cost_improvement.total < 0 then
		all_right = false
	else	
		
		println(line3)
		local file = io.open(filename, "a")		-- opens the file 
		file:write(line3)
		file:write("\n")
		file:close()
		
	end -- if
	
	return all_right
end -- show_statistics()

function show_solution_statistics()			-- Shows the average value (and standard deviation) for each metric
	println(string.format(""))
	println(string.format("Solution statistics"))
	println(string.format("Metric	Total	AVG	SD"))
	
	local simTimeConsumption = simTime - startingSimTime
	local sysTimeConsumption = sim.getSystemTime() - startingSysTime
	local tasks_amount = #tasksCompletion
	local reassigned_tasks = 0
	local completed_tasks = 0
	local allocated_tasks = 0
	local reassignments = 0
	local estimated_cost = 0
	local tasks_real_cost = 0
	local cost_improvement = 0
	local real_to_estimated_cost_diff = 0
	for i, r in ipairs(tasksCompletion) do
		completed_tasks = completed_tasks + r.completed
		reassignments = reassignments + r.reassigned
		estimated_cost = estimated_cost + (r.assign[1].Cstart or 0)
		tasks_real_cost = tasks_real_cost + (r.assign[1].Cfinal or 0)
		cost_improvement = cost_improvement + r.c_improve
		real_to_estimated_cost_diff = real_to_estimated_cost_diff + (r.c_diff or 0)
		if r.reassigned > 0 then
			reassigned_tasks = reassigned_tasks + 1
		end -- if
		if r.Tasgn then
			allocated_tasks = allocated_tasks + 1
		end -- if
	end -- for
	local time_to_completion_ratio = simTimeConsumption / completed_tasks
	local allocated_reassign_ratio = reassigned_tasks / allocated_tasks
	local completed_reassign_ratio = reassigned_tasks / completed_tasks
	
	local execs_amount = #executorsOccupation
	local solution_cost = 0
	local solution_quality = 0
	for i, r in ipairs(executorsOccupation) do
		solution_cost = solution_cost + r.totalCost
		if r.totalCost > solution_quality then
			solution_quality = r.totalCost
		end -- if
	end -- for
	
	println(string.format("Total simulation time consumption	%.2f", simTimeConsumption))
	println(string.format("Total system time consumption	%.2f", sysTimeConsumption))
	println(string.format("Total tasks amount	%s", tasks_amount))
	println(string.format("Total tasks completed	%s", completed_tasks))
	println(string.format("Total tasks allocated	%s", allocated_tasks))
	println(string.format("Total tasks reassigned	%s", reassigned_tasks))
	println(string.format("Total reassignments	%s", reassignments))
	println(string.format("Time-consumption to task-completion ratio	%.2f", time_to_completion_ratio))
	println(string.format("Reassignment ratio (allocated)	%.2f", allocated_reassign_ratio))
	println(string.format("Reassignment ratio (completed)	%.2f", completed_reassign_ratio))
	println(string.format("Solution estimated cost (tasks)	%.2f", estimated_cost))
	println(string.format("Solution real cost (tasks)	%.2f", tasks_real_cost))
	println(string.format("Total cost estimation improvement	%.2f", cost_improvement))
	println(string.format("Total real-to-estimated-cost difference	%.2f", real_to_estimated_cost_diff))
	
	local pass_stats = get_solution_stats(passengers)
	local pass_print_order = {}
	for k in pairs(pass_stats.n) do
		local i = {k, pass_stats.s[k], pass_stats.d[k]}
		if k == "task_completion_ratio" then
			pass_print_order[1] = i
		elseif k == "task_completion_time" then
			pass_print_order[2] = i
		elseif k == "task_satisfaction_time" then
			pass_print_order[3] = i
		elseif k == "task_unassigned_time" then
			pass_print_order[4] = i
		elseif k == "task_waiting_time" then
			pass_print_order[5] = i
		elseif k == "task_gettingIn_time" then
			pass_print_order[6] = i
		elseif k == "task_traveling_time" then
			pass_print_order[7] = i
		elseif k == "task_gettingOff_time" then
			pass_print_order[8] = i
		elseif k == "task_reassignments" then
			pass_print_order[9] = i
		elseif k == "task_cost_estimation_improvement" then
			pass_print_order[10] = i
		elseif k == "task_realCost_to_estimatedCost_difference" then
			pass_print_order[11] = i
		end -- if chain
	end -- for
	println("")
	for i, j in ipairs(pass_print_order) do
		println(string.format("%s		%.3f	%.3f", j[1], j[2], j[3]))
	end -- for
	println("")
	
	println(string.format("Agents' total amount	%s", execs_amount))
	println(string.format("Solution's total cost	%s", solution_cost))
	println(string.format("Solution's quality	%s", solution_quality))
	
	local taxi_stats = get_solution_stats(taxis)
	local taxi_print_order = {}
	for k in pairs(taxi_stats.n) do
		local i = {k, taxi_stats.s[k], taxi_stats.d[k]}
		if k == "exec_occupied_time" then
			taxi_print_order[1] = i
		elseif k == "exec_active_time" then
			taxi_print_order[2] = i
		elseif k == "exec_occupation_ratio" then
			taxi_print_order[3] = i
		elseif k == "exec_task_completion_ratio" then
			taxi_print_order[4] = i
		elseif k == "exec_task_losing_ratio" then
			taxi_print_order[5] = i
		elseif k == "exec_cost_range" then
			taxi_print_order[6] = i
		elseif k == "total_reroutes" then
			taxi_print_order[7] = i
		elseif k == "obstacle_reroutes" then
			taxi_print_order[8] = i
		elseif k == "service_reroutes" then
			taxi_print_order[9] = i
		end -- if chain
	end -- for
	println(string.format("Task completion distribution	%s", taxi_print_order[3][2] / completed_tasks))
	println("")
	for i, j in ipairs(taxi_print_order) do
		println(string.format("%s		%.3f	%.3f", j[1], j[2], j[3]))
	end -- for
	println("")
	
	local msg_stats = get_msgs_stats(passengers)
	for k in pairs(msg_stats.n) do
		println(string.format("%s	%s	%.3f	%.3f", k, msg_stats.t[k], msg_stats.s[k], msg_stats.d[k]))
	end -- for
	println("")
	
	msg_stats = get_msgs_stats(taxis)
	for k in pairs(msg_stats.n) do
		println(string.format("%s	%s	%.3f	%.3f", k, msg_stats.t[k], msg_stats.s[k], msg_stats.d[k]))
	end -- for
	println("")
	
end -- show_solution_statistics()

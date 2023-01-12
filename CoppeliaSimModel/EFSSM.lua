-- EFSSM/EFSM class for Lua Models
-- (C) 2020-2022 Lluís Ribas-Xirgo & Daniel Rivas Alonso, UAB
--
-- BDI support
-- Variables
-- __state__ : current intention
-- __stack__ : intentions' list
-- __knowledge__ : beliefs
-- Methods
-- 
-- Requirement:
-- All modules that are modeled as "EFSSM" modules must be objects of the class EFSSM:
--   EFSSM_module = EFSSM:new()
-- so to inherit __state__, __stack__ and __knowledge__ handling methods. 
--

EFSSM = {
	--_state_ = nil,										-- machine's current state
	state = {},											-- machine's current state
	_state_names_ = {},									-- all valid (active) state names. specific to the agent
	_stack_ = {},										-- states' stack
	_delayed_ = {}, 									-- for delayed assignments (values updated in the next cycle)
	_knowledge_ = {},									-- analog to BDI's beliefs
	
	tostring = function(self)							-- returns the machine's current status 
		local objectname = "EFSSM"
		if self.state.curr then
			objectname = string.format("EFSSM {{%s, [%i]}, [%i]}", self.state.curr, #self._stack_, #self._knowledge_)
		else
			objectname = "EFSSM {}"
		end -- if
		return objectname
	end -- tostring()
	,
	__tostring = function(self)							
		return self:tostring()
	end -- __tostring()
	,	
	new = function(self) 								-- creates a new EFSSM agent (instance)
		o = {}
		setmetatable(o, self)
		self.__index = self
		o.state = {}
		o._stack_ = {}
		o._knowledge_ = {}
		return o
	end -- new()
	,
	at = function(self, state)							-- returns if the machine is at the specified state
		return self.state.curr == state
	end -- at()
	,
	prev_at = function(self, state)							-- returns if the machine was at the specified state in the previous cycle
		return self.state.prev == state
	end -- prev_at()
	,
	changed_to = function(self, state)						-- returns if the machine is at the specified state in the current cycle but was not at it in the previous cycle
		return (self:at(state) and not self:prev_at(state))
	end -- changed_to()
	,
	pop = function(self)								-- returns the last element in the states' stack and removes it from there
		local removed = nil
		local i = #self._stack_
		if i > 0 then
			removed = self._stack_[i]
			table.remove(self._stack_, i )
		end -- if
		return removed
	end -- pop()
	,
	empty = function(self)								-- clears the states' stack
		self._stack_ = {}
	end -- empty()
	,
	push = function(self, state_name)					-- puts a state into the stack
		table.insert(self._stack_, state_name)
	end -- push()
	,
	active = function(self)								-- returns if the machine is on a valid (active) state
		local a = false
		local i = #self._state_names_
		while 0 < i and not a do
			a = self.state.curr == self._state_names_[i]
			i = i - 1
		end -- while
		return a
	end -- active()
} -- EFSSM

function EFSSM:clear_beliefs()							-- removes all beliefs
	self._knowledge_ = {}
end -- function clear_intentions

function EFSSM:create_belief(btype, content)			-- returns a new belief with the specified type and content
	return {btype = btype, content = content}
end -- create_belief

function EFSSM:exists_belief(bel)						-- Returns true if a specific belief belong to the set of beliefs
	local found = false
	for i, b in ipairs(self._knowledge_) do
		if b.btype == bel.btype and b.content == bel.content then
			found = true
		end -- if
	end -- for
	return found
end -- exists_belief

function EFSSM:exists_belief_of_type(btype)				-- Returns true if a belief (of a specific type) exists in the __knowledge__ list
	local found = false
	for i, b in ipairs(self._knowledge_) do
		if b.btype == btype then
			found = true
		end -- if
	end -- for
	return found
end -- exists_belief_of_type

function EFSSM:beliefs_of_type(btype)					-- Returns all beliefs of (specified) b_type in a list
	local filterlist = {} 
	for i, b in ipairs(self._knowledge_) do
		if b.btype == btype then
			table.insert(filterlist, b)
		end -- if
	end -- for
	return filterlist
end -- beliefs_of_type

function EFSSM:first_belief_of_type(btype)				-- Returns the first belief of a certain type
	local bel = nil
	local i = 1
	while i <= #self._knowledge_ and bel == nil do
		if self._knowledge_[i].btype == btype then
			bel = {btype = self._knowledge_[i].btype, content = self._knowledge_[i].content}
		else
			i = i + 1
		end -- if
	end -- for
	return bel
end -- first_belief_of_type

function EFSSM:get_belief(btype)						-- Returns the first belief of a certain type and removes it
	local bel = nil
	local i = 1
	while i <= #self._knowledge_ and bel == nil do
		if self._knowledge_[i].btype == btype then
			bel = {btype = self._knowledge_[i].btype, content = self._knowledge_[i].content}
		else
			i = i + 1
		end -- if
	end -- for
	if bel ~= nil then
		table.remove(self._knowledge_, i)
	end -- if
	return bel
end -- get_belief

function EFSSM:add_belief(bel)							-- Adding information to the beliefs structure (adds it if its not already in)
	local found = false
	for k, b in ipairs(self._knowledge_) do
		if b.btype == bel.btype and b.content == bel.content then
			found = true
		end -- if
	end -- for
	if not found then
		table.insert(self._knowledge_, 1, bel)
	end -- if
end -- add_belief

function EFSSM:remove_belief(bel)						-- Removing information from the beliefs structure
	local i = 0
	for k, b in ipairs(self._knowledge_) do
		if b.btype == bel.btype and b.content == bel.content then
			i = k
		end -- if
	end -- for
	if i > 0 then
		table.remove(self._knowledge_, i)
	end -- if
end -- remove_belief

function EFSSM:update_belief(bel)						-- Changes the content of a belief of the same type as the input, or adds a new one if there are no other of that type
	local i = 0
	for k in pairs(self._knowledge_) do
		if i == 0 and self._knowledge_[k].btype == bel.btype then
			i = k
		end -- if
	end -- for
	if i > 0 then
		self._knowledge_[i] = bel
	else
		table.insert(self._knowledge_, 1, bel)
	end -- if   
end -- update_belief

function EFSSM:content_of(bel)							-- returns the content of the specified belief
	local c = nil
	if bel then
		c = bel.content
	end -- if
	return c
end -- content_of

--return BDIagent
return EFSSM
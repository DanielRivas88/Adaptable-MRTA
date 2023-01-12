-- Robot fleet MAS: Map of the plant
-- (C) 2020-2022 Lluís Ribas-Xirgo & Daniel Rivas Alonso, UAB

local Map = {														-- map definition
	patch = {}, port = {},
	yaw = { {x=1, y=0}, {x=0, y=-1}, {x=-1, y=0}, {x=0, y=1} },		-- directions in coordinates???
	S = 1, W = 2, N = 3, E = 4,										-- the reference is on the top left corner of the map
	count = { taxis = 0, passengers = 0, passengers_left = 0, passengers_in_taxis = 0, passengers_arrived = 0 }	-- register of all elements in the map
} -- Map

function rotleft(z)													-- rotates 90 degrees to the left
	r = z - 1
	if r < 1 then r = 4 end
	return r
end -- rotleft

function rotright(z)												-- rotates 90 degrees to the right
	r = z + 1
	if r > 4 then r = 1 end
	return r
end -- rotright 

function Map:front(x, y)											-- returns the patch in front of the current patch (regarding its direction). If the patch is not a road (no direction), returns the patch to the south
	local p = self.patch[x][y]										-- gets the patch at the coordinates
	local q = nil
	local rot = p.z													-- gets the traffic direction of the patch

	if rot == 0 then rot = 1 end									-- assumes a south direction if the patch has none
if rot == -1 then rot = 1 end									-- assumes a south direction if the patch has none
	x = x + self.yaw[rot].x											-- updates the x coordinate to where the current patch heads to
	y = y + self.yaw[rot].y											-- updates the y coordinate to where the current patch heads to

	if self.patch[x] and self.patch[x][y] then						-- if there is a patch where the current patch heads to:
		q = self.patch[x][y]										-- saves the pointed patch
	end -- if
	
	return q
end -- front

function Map:left(x, y)												-- returns the patch to the left of the current patch (regarding its direction)
	local p = self.patch[x][y]
	local q = nil
	local rot = p.z

	if rot == 0 then rot = 1 end
	if rot == -1 then rot = 1 end
	rot = rotleft(rot)
	x = x + self.yaw[rot].x
	y = y + self.yaw[rot].y
	
	if self.patch[x] and self.patch[x][y] then
		q = self.patch[x][y]
	end -- if
	
	return q
end -- left

function Map:right(x, y)											-- returns the patch to the right of the current patch (regarding its direction)
	local p = self.patch[x][y]
	local q = nil
	local rot = p.z

	if rot == 0 then rot = 1 end
	if rot == -1 then rot = 1 end
	rot = rotright(rot)
	x = x + self.yaw[rot].x
	y = y + self.yaw[rot].y
	
	if self.patch[x] and self.patch[x][y] then
		q = self.patch[x][y]
	end -- if
	
	return q
end -- right

function Map:back(x, y)												-- returns the patch in the back of the current patch (regarding its direction)
	local p = self.patch[x][y]
	local q = nil
	local rot = p.z

	if rot == 0 then rot = 1 end
	if rot == -1 then rot = 1 end
	rot = rotright(rotright(rot))
	x = x + self.yaw[rot].x
	y = y + self.yaw[rot].y
	
	if self.patch[x] and self.patch[x][y] then
		q = self.patch[x][y]
	end -- if
	
	return q
end -- back

function Map:frontward(x, y)										-- returns the patch in front of the current patch (regarding its direction), if it is a road
	local p = self:front(x, y)										-- gets the patch in front of the given coordinates
	if p and p.z == 0 then p = nil end								-- if the pointed patch is not a road, returns nothing
	return p
end -- frontward

function Map:leftward(x, y)											-- returns the patch to the left of the current patch (regarding its direction), if it is a road
	local p = self:left(x, y)
	if p and p.z == 0 then p = nil end
	return p
end -- leftward

function Map:rightward(x, y)										-- returns the patch to the right of the current patch (regarding its direction), if it is a road
	local p = self:right(x, y)
	if p and p.z == 0 then p = nil end
	return p
end -- rightward

function Map:backward(x, y)											-- returns the patch in the back of the current patch (regarding its direction), if it is a road
	local p = self:back(x, y)
	if p and p.z == 0 then p = nil end
	return p
end -- backward

function Map:outdegree(p)											-- returns the input patch's number of outputs 
	local i = 1
	local n = 0
	
	while i < 4 do													-- goes through all the elements in outputs
		if p.out[i] > 0 then n = n + 1 end							-- if the current element is a valid output, increases the count
		i = i + 1
	end -- while
	
	return n
end -- outdegree

function Map:creategraph()											-- assigns the possible outputs of each road patch (front, left and right)
	local x = 1
	local xx = #self.patch											-- maximum x coordinate value
	
	while x <= xx do												-- goes through all lines
		local y = 1
		local yy = #self.patch[x]									-- maximum y coordinate value
		
		while y <= yy do											-- goes through all cells in the line
			local m = self.patch[x][y]								-- gets the patch at the current coordinates
			local n = self:frontward(x, y)							-- gets the patch in front of the current patch (the one that it leads to)
			if n and n.z > 0 and self:frontward(n.x, n.y) ~= m then	-- if the patch in front exists and is a road that doesn't lead to the current patch
				m.out[1] = m.z										-- the first output of the patch will be pointing to the front of it
			end -- if
			n = self:leftward(x, y)									-- gets the patch to the left of the current patch
			if n and n.z > 0 and self:frontward(n.x, n.y) ~= m then	-- if the patch to the left exists and is a road that doesn't lead to the current patch
				m.out[2] = rotleft(m.z)								-- the second output of the patch will be pointing to the left of it
			end -- if
			n = self:rightward(x, y)								-- gets the patch to the right of the current patch
			if n and n.z > 0 and self:frontward(n.x, n.y) ~= m then	-- if the patch to the right exists and is a road that doesn't lead to the current patch
				m.out[3] = rotright(m.z)							-- the third output of the patch will be pointing to the right of it
			end -- if
			y = y + 1
		end -- while
		x = x + 1
	end -- while
end -- creategraph

function Map:createStreetGraph()									-- assigns the possible outputs of each road patch (front, left and right)
	local x = 1
	local xx = #self.patch											-- maximum x coordinate value

	while x <= xx do												-- goes through all lines
		local y = 1
		local yy = #self.patch[x]									-- maximum y coordinate value
		
		while y <= yy do											-- goes through all cells in the line
			local m = self.patch[x][y]								-- gets the patch at the current coordinates
			local n = self:frontward(x, y)							-- gets the patch in front of the current patch (the one that it leads to)
			if n and n.z > 0 and self:frontward(n.x, n.y) ~= m then	-- if the patch in front exists and is a road that doesn't lead to the current patch
				m.out[1] = m.z										-- the first output of the patch will be pointing to the front of it
			end -- if
			
			n = self:leftward(x, y)									-- gets the patch to the left of the current patch
			if n and n.z > 0 and (self:rightward(n.x, n.y) == m or self:backward(n.x, n.y) == m) then	-- if the patch to the left exists and is a road that goes in the same direction as the current patch or goes away from it
				m.out[2] = rotleft(m.z)								-- the second output of the patch will be pointing to the left of it
			end -- if
			n = self:rightward(x, y)								-- gets the patch to the right of the current patch
			if n and n.z > 0 and (self:leftward(n.x, n.y) == m or self:backward(n.x, n.y) == m) then	-- if the patch to the right exists and is a road that goes in the same direction as the current patch or goes away from it
				m.out[3] = rotright(m.z)							-- the third output of the patch will be pointing to the right of it
			end -- if
			y = y + 1
		end -- while
		x = x + 1
	end -- while
end -- createStreetGraph()

function Map:roundabouts()											-- sets each patch as a roundabout element if following the front direction of it and the next 3 patches leads to itself
	local x = 1
	local xx = #self.patch											-- maximum x coordinate value

	while x <= xx do												-- goes through all lines
		local y = 1
		local yy = #self.patch[x]									-- maximum y coordinate value
		
		while y <= yy do											-- goes through all cells in the line
			self.patch[x][y].roundabout = false						-- all patches start as not roundabout elements
			local n = self:frontward(x, y)							-- gets the patch in front of the current one
			if n then n = self:frontward(n.x, n.y) end				-- if the patch exists, gets the patch in front of it
			if n then n = self:frontward(n.x, n.y) end				-- if the patch exists, gets the patch in front of it
			if n then n = self:frontward(n.x, n.y) end				-- if the patch exists, gets the patch in front of it
			if n == self.patch[x][y] then							-- if the patch is the starting patch
				self.patch[x][y].roundabout = true					-- sets the patch as a roundabout element
			end 
			y = y + 1
		end -- while
		x = x + 1
	end -- while
end -- roundabouts

function Map:upload(filename)										-- creates the patch map with all its elemens (ports, gates, roundabouts, graph) from a taxt file
	local errormsg = ""												-- the error message starts as an empty string
	local f = io.open(filename, "r")								-- imports the input file 
	if f then														-- correct file load
		local portcount = 1
		local lin = f:read("*line")									-- gets the next line
		local x = 1
		while lin do												-- creates all the patches with coordinates, direction and ports (goes through all the lines in the map)
			if string.sub(lin, 1, 1) ~= '@' then					-- if the first element in the line is not '@' (a port)
				lin = string.gsub(lin, "%s", "") 					-- removes whitespaces
				local j = 1
				local y = 1
				local eol = false									-- eol: end of line
				
				while j <= string.len(lin) and not eol do			-- goes through all the elements in the line
					local c = string.sub(lin, j, j )				-- gets the element
					local z = 0										-- default patch orientation (none)
					local is_port = false
					if		c == 'V' then z = 1						-- sets the patch orientation
					elseif	c == '<' then z = 2
					elseif	c == "A" then z = 3
					elseif	c == '>' then z = 4
					elseif	c == '@' then is_port = true			-- sets the element as a port
					elseif	c == '#' then
					elseif c == '.' then z = -1
					else eol = true									-- if the element has a different value (nomenclature), assumes that the line ended
					end -- if chain
					
					if not eol then									-- if it is a valid element
						if not self.patch[x] then
							self.patch[x] = {}						-- creates the patch line if it does not exists
						end	-- if
						self.patch[x][y] = {
							x = x, y = y, z = z,
							out = {0, 0, 0},
							port = nil,
							gate = nil,
							taxi = nil,
							reservations = {},
							service = {},							-- L1's traffic management
							person = {}
						}											-- creates the corresponding patch
						
						-- Graphical representation
						if showMap.blocks then
							if self.patch[x][y].z == 0 then
								self.patch[x][y].block = sim.createPureShape(0, 26, {b_width, b_long, b_height}, math.huge, nil)	-- Block handle
								sim.setObjectPosition(self.patch[x][y].block, -1, {self.patch[x][y].x, self.patch[x][y].y, b_height / 2})
								sim.setObjectSpecialProperty(self.patch[x][y].block, sim.objectspecialproperty_renderable)
								sim.setShapeColor(self.patch[x][y].block, nil, sim_colorcomponent_ambient_diffuse, {0.6, 0.4, 0.3})
							end -- if
						end -- if
						
						if showMap.streets then
							if self.patch[x][y].z > 0 then
								self.patch[x][y].street = sim.createPureShape(0, 24, {b_width, b_long, 0}, 0, nil)	-- Street tile handle
								sim.setObjectPosition(self.patch[x][y].street, -1, {self.patch[x][y].x, self.patch[x][y].y, 0.04})
								sim.setShapeColor(self.patch[x][y].street, nil, sim_colorcomponent_ambient_diffuse, {0.8, 0.8, 0.8})
							end -- if
						end -- if
						
						if is_port then 							-- port definition (if it is a port)
							self.port[portcount] = {
								patch = self.patch[x][y],
								name = string.format("@port[%d]", portcount),
								gate = {},
								num = portcount,
								dest = {}
							}										-- creates the corresponding port in the ports list
							self.patch[x][y].port = self.port[portcount]	-- saves the port in the patch
							portcount = portcount + 1
							
							-- Graphical representation
							sim.setShapeColor(self.patch[x][y].block, nil, sim_colorcomponent_ambient_diffuse, {0.2, 0.6, 1})
							if showMap.ports then
								local height = 0.25
								self.patch[x][y].marker = sim.createPureShape(2, 26, {0.25, 0.25, 0}, 0, nil)
								sim.setObjectPosition(self.patch[x][y].marker, -1, {x, y, 1.5 * height + 0.01})
								sim.setShapeColor(self.patch[x][y].marker, nil, sim_colorcomponent_ambient_diffuse, {1, 1, 1})
							end -- if
							
						end -- if
						y = y + 1
					end -- if
					j = j + 1
				end -- while
				
				if y > 1 then x = x + 1 end							-- if not a blank line (at least an element inside)
			else 													-- port identification and destination setup (the first element in the line is '@')
				local portno, portname = string.match(lin, "@(%d+)%s+(%S+)")	-- gets the port number and name
				if portno and portname then
					portno = tonumber( portno )
					if self.port[portno] then						-- if there is a port with that number in the ports list
						self.port[portno].name = portname			-- sets the port name
						local b, e = string.find(lin, "@(%d+)%s+(%S+)")	-- gets the beginning and end indexes of the number and name string
						local lin = string.sub(lin, e+1)			-- gets the string after the previous string
						for w in string.gmatch(lin, "(%S+)") do		-- gets all the words in the string
							table.insert(self.port[portno].dest, w)	-- inserts all the port destinations???
						end -- for
					end -- if
				end -- if
			end -- if
			lin = f:read("*line")									-- gets the next line
		end -- while
		f:close()    												-- closes the file access
		--self:roundabouts()											-- marks all roundabout patches in the map
		--self:creategraph()											-- sets the outputs for all road patches in the map
		self:createStreetGraph()
		for i, p in ipairs(self.port) do 							-- create gates for all ports
			local m = p.patch 										-- gets the port patch (look for neighbour patches that are roads)
			
			local n = self:front(m.x, m.y)							-- gets the patch in front of the port
			if n and n.z > 0 then									-- if the patch is a road
				n.gate = p											-- saves the port in the gate property of the patch
				table.insert(p.gate, n)								-- puts the patch as a gate for the port
			end -- if
			
			n = self:left(m.x, m.y)									-- gets the patch to the left of the port
			if n and n.z > 0 then									
				n.gate = p
				table.insert(p.gate, n)
			end -- if 
			
			n = self:right(m.x, m.y)								-- gets the patch to the right of the port
			if n and n.z > 0 then
				n.gate = p
				table.insert(p.gate, n)
			end -- if
			
			n = self:back(m.x, m.y)									-- gets the patch in the back of the port
			if n and n.z > 0 then
				n.gate = p
				table.insert(p.gate, n)
			end -- if
			
			-- Graphical representation
			if showMap.gates then
				for i, g in ipairs(p.gate) do 	
					self.patch[g.x][g.y].marker = sim.createPureShape(2, 26, {0.25, 0.25, 0}, 0, nil)
					sim.setObjectPosition(self.patch[g.x][g.y].marker, -1, {g.x, g.y, 0.05})
					sim.setShapeColor(self.patch[g.x][g.y].marker, nil, sim_colorcomponent_ambient_diffuse, {0, 0, 0})
				end -- for
			end -- if
		end -- for
		
		-- Physical floor scaling
		local f_width = (#self.patch + 1) * b_width
		local f_long = (#self.patch[1] + 1) * b_long
		sim.setShapeBB(floorPhysicalHandle, {f_width, f_long, defaultPhysicalFloorSize[3]})
		sim.setObjectPosition(floorPhysicalHandle, -1, {f_width/2, f_long/2, defaultPhysicalFloorPosition[3]})
		
		-- Graphical representation
		if showMap.floor then
			local g_width = #self.patch
			local g_long = #self.patch[1]
			local g_height = 0
			local gx = g_width/2 + 0.5
			local gy = g_long/2 + 0.5
			local ground = sim.createPureShape(0, 26, {g_width, g_long, g_height}, 0, nil)	-- ground handle
			sim.setObjectPosition(ground, -1, {gx, gy, 0.02})
			sim.setObjectSpecialProperty(ground, sim.objectspecialproperty_renderable)
			if showMap.streets then
				sim.setShapeColor(ground, nil, sim.colorcomponent_ambient_diffuse, {0.6, 0.4, 0.3})
			else
				sim.setShapeColor(ground, nil, sim.colorcomponent_ambient_diffuse, {0.8, 0.8, 0.8})
			end -- if
		end -- if
	else															-- failed file load
		errormsg = string.format("Cannot open file \"%s\"", filename )	-- informs it in the error message
	end -- if
	return errormsg													-- returns the error message
end -- upload

function Map:add_person(p)											-- adds the person to its corresponding patch in the map
	if p then
		table.insert(self.patch[p.x][p.y].person, p.id)
		showMap.changed = true
	end
end -- add_person

function Map:remove_person(p)										-- removes the person from its patch in the map
	local j = 0
	for i, q in ipairs(self.patch[p.x][p.y].person) do
		if p.id == q then j = i end
	end -- for
	if j > 0 then
		table.remove(self.patch[p.x][p.y].person, j)
		showMap.changed = true
	end -- if
end -- remove_person
  
function Map:stats()												-- updates all count registers for the map
	local taxis = 0
	local passengers = 0
	local passengers_left = 0
	local passengers_in_taxis = 0
	local passengers_arrived = 0
	local max_x = #self.patch
	local i = 0
	while i < max_x do												-- goes through all the lines
		i = i + 1
		local j = 0
		local max_y = #self.patch[i]
		
		while j < max_y do											-- goes through all the patches in the line
			j = j + 1
			local p = self.patch[i][j]								-- current patch
			if p.taxi then											-- if there is a taxi at the patch
				taxis = taxis + 1									-- increases the taxi count
				if #p.taxi.onboard > 0 then							-- if the taxi has passengers
					passengers = passengers + #p.taxi.onboard		-- increases the number of passengers
					passengers_in_taxis = passengers_in_taxis + #p.taxi.onboard	-- increases the number of passengers in taxis
				end -- if
			end -- if
			if #p.person > 0 then									-- if there are persons in the patch
				passengers = passengers + #p.person					-- increases the number of passengers
				if p.z > 0 then										-- if the patch is a road
					passengers_left = passengers_left + #p.person	-- increases the number of passengers left
				end -- if
				if p.port then										-- if the patch is a port
					passengers_arrived = passengers_arrived + #p.person	-- increases the number of passengers arrived
				end -- if
			end -- if 
		end -- while
	end -- while
	
	self.count.taxis = taxis										-- saves the counts in the map registers
	self.count.passengers = passengers
	self.count.passengers_left = passengers_left
	self.count.passengers_in_taxis = passengers_in_taxis
	self.count.passengers_arrived = passengers_arrived
	return passengers_arrived
end -- stats
  
function Map:show(t)												-- prints out the current status of the environment
	local max_x = #self.patch
	local i = 0
	if max_x > 0 then												-- if there is a map (presentation heading)
		local j = 0
		local max_y = #self.patch[1]
		print("   ")												-- print 3 blank spaces
		while j < max_y do
			j = j + 1
			print(string.format("%1i",math.floor(j/10)))			-- print the decens for the y coordinates on top of the map
		end -- while
		print("\n   " )												-- go to the next line and print 3 blank spaces
		
		j = 0
		while j < max_y do
			j = j + 1
			print(string.format("%1i",j%10))						-- print the units for the y coordinates on top of the map
		end -- while
		print("\n")													-- go to the next line
	end -- if
	
	i = 0
	while i < max_x do
		i = i + 1
		print( string.format( "%02i ", i ))							-- print the x coordinate on the left of the map
		local max_y = #self.patch[i]
		local j = 0
		while j < max_y do
			j = j + 1
			local c = '#'											-- default cell symbol
			local p = self.patch[i][j]								-- get the current patch
			if p.z > 0 then c = ' ' end -- '.' end					-- symbol for roads
			if p.roundabout then c = ' ' end -- 'o' end				-- symbol for roundabouts
			if p.port then c = '@' end								-- symbol for ports
			if p.gate then c = ' ' end -- '*' end					-- symbol for gates
			if p.taxi then c = 't'									-- symbol for taxi on the patch
				if p.taxi.pickingpassenger then c = 'T' end			-- symbol for taxi with an assigned passenger
				if #p.taxi.onboard > 0 then c = 'P' end 			-- symbol for taxi with passenger(s) onboard
			end -- if
			if #p.person > 0 and p.z > 0 then						-- if there is a person on a road
				if p.person[1].auction then c = 'C'					-- symbol for an auctioning passenger
				else c = 'c' end									-- symbol for a waiting passenger
			end -- client(s) waiting to be a passenger
			
			print(c)												-- print the cell symbol
		end -- while
		if i == max_x - 11 then print(" # block") end				-- map legend
		if i == max_x - 10 then print(" ./o road/roundabout") end
		if i == max_x -  9 then print(" */@ gate/port") end	
		if i == max_x -  8 then print(" t/T wandering/picking-up taxi") end	
		if i == max_x -  7 then print(" C client call") end	
		if i == max_x -  6 then print(" P taxi with passenger aboard") end	
		if i == max_x -  5 then print(string.format(" Taxis = %i", self.count.taxis)) end	
		if i == max_x -  4 then print(string.format(" Passengers = %i", self.count.passengers)) end	
		if i == max_x -  3 then print(string.format(" ... waiting = %i", self.count.passengers_left)) end	
		if i == max_x -  2 then print(string.format(" ... in taxis = %i", self.count.passengers_in_taxis)) end	
		if i == max_x -  1 then print(string.format(" ... arrived = %i", self.count.passengers_arrived)) end	
		if i == max_x -  0 then print(string.format(" Tick = %i", t)) end	
		print('\n')													-- go to the next line
	end -- while
end -- show

function Map:show_test()											-- prints out which nodes are serving at least one vehicle
	local max_x = #self.patch
	local i = 0
	while i < max_x do
		i = i + 1
		local max_y = #self.patch[i]
		local j = 0
		while j < max_y do
			j = j + 1
			local c = '#'											-- default cell symbol (block)
			local p = self.patch[i][j]								-- get the current patch
			if p.z > 0 then c = ' ' end -- '.' end					-- symbol for roads
			if p.port then c = '@' end								-- symbol for ports
			if p.z > 0 then
				local a = p.service[1]
				if a then 
					local L4 = taxis[a].L4
					if L4.pass.curr then
						if L4:at("LOAD") or L4:at("DROP") then
							c = 'P'									-- symbol for loaded taxi
						else
							c = 'T'									-- symbol for busy taxi
						end -- if
					else
						c = 't'										-- symbol for free taxi
					end -- if
				end -- if
			end 
			if #p.person > 0 then									-- if there is a person on the patch
				local a = p.person[1]
				local Dlb = passengers[a].Dlb
				if Dlb.taxi.curr then
					c = 'p'											-- symbol for assigned task
				else
					c = 'c'											-- symbol for unassigned task (calling)
				end -- if
			end -- if
			print(c)												-- print the cell symbol
		end -- while
		println("")													-- go to the next line
	end -- while
	println("")
end -- show_test

function Map:show_service()											-- prints out the serviced vehicle by each node
	local max_x = #self.patch
	local i = 0
	while i < max_x do
		i = i + 1
		local max_y = #self.patch[i]
		local j = 0
		while j < max_y do
			j = j + 1
			local c = '#'	--' '									-- default cell symbol (empty)
			local p = self.patch[i][j]								-- get the current patch
			if p.z > 0 then
				local a = p.service[1]
				if not a then a = ' ' end
				c = string.format('%s', a)
			end 
			print(c)												-- print the cell symbol
		end -- while
		println("")													-- go to the next line
	end -- while
	println("")
end -- show_service

function belongsto(v, list)											-- returns if v is part of list
	local belong = false
	if list then
		local j = 1
		while j <= #list and not belong do
			if v == list[j] then
				belong = true
			else
				j = j + 1
			end -- if chain
		end -- if
	end -- if
	return belong
end -- function belongsto

function Map:minpath(s, g, a)										-- returns the minimum path between s and g avoiding a
	-- Dijkstra's algorithm between patches at (s.x, s.y) and (g.x, g.y)
	-- Requires self.setup to have the graph created on top of patches
	-- Returns a sequence of patches
	local tabu = a or {}
	local max_x = #self.patch
	local max_y = #self.patch[1] or 0
	local x = 1
	local y = 1
	while x <= max_x do												-- clears previous cost and predecesor to all patches (goes through all lines)
		max_y = #self.patch[x]
		y = 1
		while y <= max_y do											-- goes through all patch in the line
			self.patch[x][y].pred = nil								-- clears the predecesor patch
			self.patch[x][y].cost = -1								-- clears the patch cost 
			y = y + 1
		end -- while
		x = x + 1
	end -- while
	
	local Q = {}													-- priority patches queue
	local u = self.patch[s.x][s.y]									-- gets the start patch
	local r = self.patch[g.x][g.y]									-- gets the goal patch
	u.cost = 0
	while u ~= nil and u ~= r do									-- 
		for i, w in ipairs(u.out) do								-- goes through all the patch outputs
			if w > 0 then											-- if its a valid output
				local v = self.patch[u.x + self.yaw[w].x][u.y + self.yaw[w].y]	-- gets the neighbor patch in that direction (gets one neighbor)
				if not belongsto(v, tabu) then						-- if the neighbor is not required to be avoided
					local uvcost = 1 								-- base cost
					local rr = math.abs( v.z - u.z ) 				-- relative rotation
					uvcost = uvcost + rr / 10						-- preference to go straight than to turn
					if v.cost < 0 or v.cost > u.cost + uvcost then	-- if the neighbor has not been visited or has a costier path
						v.cost = u.cost + uvcost					-- update the neighbor cost
						v.pred = u									-- update the neighbor predecesor
						local i = 1
						local f = false 							-- enqueue v in priority queue Q
						while i < #Q and not f do					-- puts the new nodes in the queue, ordered by cost from higher to lower
							if Q[i].cost < v.cost then
								f = true
							else
								i = i + 1
							end -- if
						end -- while
						table.insert( Q, i, v )
					end -- if
				end -- if
			end -- if
		end -- for
		
		if #Q > 0 then												-- if the list is not empty
			u = table.remove(Q)										-- get the less costy patch
		else														-- if the list is empty
			u = nil													-- get nothing
		end -- dequeue from Q
	end -- while
	
	local P = {} 													-- path (patches list)
	while r ~= nil do												-- as long as the predecesor chain continues (the taxi checks if the path is valid)
		table.insert( P, 1, r )										-- insert the current patch in the path (goal patch as first element)
		r = r.pred													-- get the predecesor patch
	end -- while
	
	return P														-- return the path
end -- minpath

function Map:rnd_free_patch()										-- returns a road patch free of people and taxis, and also not a gate (the reference origin point if none is found)
	local xmax = #self.patch
	local ymax = #self.patch[1]
	local x = math.random(2, xmax - 1)								-- random x coordinate avoiding the map edges
	local y = math.random(2, ymax - 1)								-- random y coordinate avoiding the map edges
	local x0 = x
	local y0 = y
	local last = false
	local found = false
	while not found and not last do
		if   self.patch[x][y].z > 0
		and  self.patch[x][y].taxi == nil
		and #self.patch[x][y].person == 0
		and  self.patch[x][y].gate == nil then
			found = true											-- select a patch that is a road, not a gate, and has no taxis or people on it
		else 														-- if the patch is not suitable (try next one in zig-zag sweep from starting point)
			y = y + 1												-- go to the next patch in the line
			if y >= ymax then										-- if the map's east edge is reached
				y = 2	
				x = x + 1											-- go to the first element in the next line
				if x >= xmax then									-- if the map's south edge is reached
					x = 2											-- go to the first line
				end -- if
			end -- if
			last = (x == x0) and (y == y0)							-- reports if the whole map was searched (current coordinates coincide with the initial ones)
		end -- if
	end -- while
	
	local w = 0
	if last then													-- if no free patch was found
		x = 0; y = 0												-- set the coordinates to the reference origin (map edge and not a road)
	else
		w = self.patch[x][y].z										-- get the road direction
	end -- if
	return x, y, w													-- return the patch coordinates and direction
end -- rnd_free_patch

function Map:agent_starting_patch(list)								-- returns a previously planned patch (the reference origin point if none is found)
	local coords = table.remove(list)
	local x = coords.x
	local y = coords.y
	local valid = false
	if  self.patch[x][y].z > 0										-- select a patch that is a road,
	and (self.patch[x][y].service[1] == nil or self.patch[x][y].service[1] == 0)	-- is not servicing any vehicle,
	and self.patch[x][y].taxi == nil then							-- and has no taxis on it
		valid = true
	end -- if
	
	local w = 0
	if not valid then												-- if no valid patch was found at those coordinates
		x = 0; y = 0												-- set the coordinates to the reference origin (map edge and not a road)
	else
		w = self.patch[x][y].z										-- get the road direction
	end -- if
	
	return x, y, w													-- return the patch coordinates and direction
end -- agent_starting_patch

function Map:rnd_free_patch_for_taxi()								-- returns a road patch free of taxis and that is not a gate (the reference origin point if none is found)
	local xmax = #self.patch
	local ymax = #self.patch[1]
	local x = math.random(2, xmax - 1)								-- random x coordinate avoiding the map edges
	local y = math.random(2, ymax - 1)								-- random y coordinate avoiding the map edges
	local x0 = x
	local y0 = y
	local last = false
	local found = false
	while not found and not last do
		if  self.patch[x][y].z > 0
		and self.patch[x][y].taxi == nil
		and self.patch[x][y].service[1] == nil
		and self.patch[x][y].gate == nil then
			found = true											-- select a patch that is a road, not a gate, not servicing any vehicle, and has no taxis on it
		else 														-- if the patch is not suitable (try next one in zig-zag sweep from starting point)
			y = y + 1												-- go to the next patch in the line
			if y >= ymax then										-- if the map's east edge is reached
				y = 2
				x = x + 1											-- go to the first element in the next line
				if x >= xmax then									-- if the map's south edge is reached
					x = 2											-- go to the first line
				end -- if
			end -- if
			last = (x == x0) and (y == y0)							-- reports if the whole map was searched (current coordinates coincide with the initial ones)
		end -- if
	end -- while
	local w = 0
	if last then													-- if no free patch was found
		x = 0; y = 0												-- set the coordinates to the reference origin (map edge and not a road)
	else
		w = self.patch[x][y].z										-- get the road direction
	end -- if
	return x, y, w													-- return the patch coordinates and direction
end -- rnd_free_patch_for_taxi

function Map:rnd_free_patch_for_passenger()							-- returns a road patch free of people and that is not a gate (the reference origin point if none is found)
	local xmax = #self.patch
	local ymax = #self.patch[1]
	local x = math.random(2, xmax - 1)								-- random x coordinate avoiding the map edges
	local y = math.random(2, ymax - 1)								-- random y coordinate avoiding the map edges
	local x0 = x
	local y0 = y
	local last = false
	local found = false
	while not found and not last do
		if   self.patch[x][y].z > 0
		and #self.patch[x][y].person == 0
		and  self.patch[x][y].gate == nil then
			found = true											-- select a patch that is a road, not a gate, and has no people on it
		else 														-- try next one in zig-zag sweep from starting point
			y = y + 1
			if y >= ymax then
				y = 2
				x = x + 1; if x >= xmax then x = 2 end
			end -- if
			last = (x == x0) and (y == y0)
		end -- if
	end -- while
	local w = 0
	if last then													-- if no free patch was found
		x = 0; y = 0
	else
		w = self.patch[x][y].z
	end -- if
	return x, y, w													-- return the patch coordinates and direction
end -- rnd_free_patch_for_passenger

function Map:rnd_free_patch_simple()								-- returns a road patch free of people and taxis, and also not a gate (has no stopping condition if none is found)
	local xmax = #self.patch
	local ymax = #self.patch[1]
	local x = math.random(2, xmax - 1)								-- random x coordinate avoiding the map edges
	local y = math.random(2, ymax - 1)								-- random y coordinate avoiding the map edges
	local found = false
	while not found do
		if   self.patch[x][y].z > 0
		and  self.patch[x][y].taxi == nil
		and #self.patch[x][y].person == 0
		and  self.patch[x][y].gate == nil then
			found = true											-- select a patch that is a road, not a gate, and has no taxis or people on it
		else														-- if not found, pick another random patch
			x = math.random(2, xmax - 1)
			y = math.random(2, ymax - 1)
		end -- if
	end -- while
	local w = self.patch[x][y].z
	return x, y, w													-- return the patch coordinates and direction
end -- rnd_free_patch_simple

function Map:rnd_free_port()										-- returns a port free of people and taxis
	local p = {}
	local i = 0
	local num_ports = #self.port
	if num_ports > 0 then
		i = math.random(1, num_ports)
	else 															-- Error! No ports, nowhere to go
		println(string.format("Map:rnd_free_port| Warning: No ports to go in the map"))	-- monitoring
	end -- if
	
	local i0 = i
	local last = false
	local found = false
	while not found and not last do
		p = self.port[i]
		if   p.patch.taxi == nil
		and #p.patch.person == 0 then
			found = true											-- select a patch that is a port and has no taxis or people on it
		else														-- if not found, pick another random patch
			i = i + 1
			if i > num_ports then
				i = 1
			end -- if
			last = (i == i0)
		end -- if
	end -- while
	
	if last then													-- if no free port was found
		p = {}
	end -- if
	
	return p
end -- rnd_free_port

function Map:rnd_port()												-- returns a random port
	local p = {}
	local i = 0
	local num_ports = #self.port
	if num_ports > 0 then
		i = math.random(1, num_ports)
		p = self.port[i]
	else 															-- Error! No ports, nowhere to go
		println(string.format("Map:rnd_port| Warning: No ports to go in the map"))	-- monitoring
	end -- if
	
	return p
end -- rnd_port

function Map:rnd_starting_port()									-- returns a random port
	local p = {}
	local num_ports = #self.port
	if num_ports > 0 then
		local ports = {}
		for i, p in ipairs(self.port) do
			local num = string.match(p.name, "%a+(%d+)")
			if num == "0" then
				table.insert(ports, p)
			end -- if
		end -- for
		num_ports = #ports
		
		if num_ports > 0 then
			local i = math.random(1, num_ports)
			p = ports[i]
		else 														-- Error! No ports found, nowhere to go
			println(string.format("Map:rnd_starting_port| Warning: No ports found in the map with those specifications"))	-- monitoring
		end -- if
	else 															-- Error! No ports at all, nowhere to go
		println(string.format("Map:rnd_starting_port| Warning: No ports in the map"))	-- monitoring
	end -- if
	
	return p
end -- rnd_starting_port

function Map:get_port(name)											-- returns the port corresponding to the name
	local p = {}
	local num_ports = #self.port
	
	if num_ports > 0 then
		local num = string.match(name, "%a+(%d+)")
		local ports = {}

		if num and #num > 0 then									-- the name contains numbers (specific ports)
			for i, p in ipairs(self.port) do
				if p.name == name then
					table.insert(ports, p)
				end -- if
			end -- for
		else														-- the name does not contain numbers (group of ports)
			for i, p in ipairs(self.port) do
				local group = string.match(p.name, "(%a+)%d+")
				if group == name then
					table.insert(ports, p)
				end -- if
			end -- for
		end -- if
		num_ports = #ports
		if num_ports > 0 then
			local i = math.random(1, num_ports)
			p = ports[i]
		else 														-- Error! No ports found, nowhere to go
			println(string.format("Map:get_port| Warning: No ports found in the map with those specifications"))	-- monitoring
		end -- if
	else 															-- Error! No ports at all, nowhere to go
		println(string.format("Map:get_port| Warning: No ports in the map"))	-- monitoring
	end -- if
	
	return p
end -- get_port

function Map:get_starting_port(name)								-- returns the starting port corresponding to the group name
	local p = {}
	local num_ports = #self.port
	if num_ports > 0 then
		local ports = {}
		for i, p in ipairs(self.port) do
			local group = string.match(p.name, "(%a+)%d+")
			if group == name then
				local num = string.match(p.name, "%a+(%d+)")
				if num == "0" then
					table.insert(ports, p)
				end -- if
			end -- if
		end -- for
		num_ports = #ports
		
		if num_ports > 0 then
			local i = math.random(1, num_ports)
			p = ports[i]
		else 														-- Error! No ports found, nowhere to go
			p = self:get_port(name)
		end -- if
	else 															-- Error! No ports at all, nowhere to go
		println(string.format("Map:get_starting_port| Warning: No ports in the map"))	-- monitoring
	end -- if
	
	return p
end -- get_starting_port

function Map:make_reservation(x, y, t)								-- adds the taxi at the bottom of the reservation list if its not on it
	if self.patch[x] and self.patch[x][y] then
		local r = self.patch[x][y].reservations						-- get the patch reservations list
		local i = 1
		local found = false
		while i <= #r and not found do								-- checks if the taxi is already in the list
			if r[i] == t then
				found = true
			else
				i = i + 1
			end -- if
		end -- while
		if not found then table.insert(r, t) end					-- the taxi is added if its not on the list
	end -- if
end -- make_reservation
  
function Map:cancel_reservation(x, y, t)							-- removes the taxi from the reservations list 
	if self.patch[x] and self.patch[x][y] then
		local r = self.patch[x][y].reservations						-- get the patch reservations list
		local i = 1
		local found = false
		while i <= #r and not found do								-- looks for the taxi's index in the list
			if r[i] == t then
				found = true
			else
				i = i + 1
			end -- if chain
		end -- while
		if found then table.remove(r, i) end						-- removes the taxi from the list
	end -- if
end -- cancel_reservation

function Map:use_reservations()										-- updates the positions of all taxis according to their reservations and returns if at least one of them moved
	local some_movement = false
	local max_x = #self.patch
	local i = 0
	while i < max_x do
		i = i + 1
		local max_y = #self.patch[i]
		local j = 0
		while j < max_y do
			j = j + 1
			if self.patch[i][j].z > 0 then							-- if the patch is a road
				if #self.patch[i][j].reservations > 0 then			-- if the road is reserved
					if #self.patch[i][j].reservations > 1 then		-- if the road has multiple reservations
						io.write(string.format("use_reservations detected #i reservations on patch (%i, %i)!\n",
							#self.patch[i][j].reservations, i, j))	-- print how many reservations has said patch (debugging)
					end -- if
					
					local winner = self.patch[i][j].reservations[1]	-- the winner is the first taxi in the list
					if winner:move(self) then						-- orders the taxi to move
						some_movement = true						-- registers if at least a taxi performed an action
					end -- if
					self.patch[i][j].taxi = winner					-- moves the winner to the patch
					self.patch[i][j].reservations = {}				-- clears the reservations list
				else 												-- if the road is not reserved (empty patch)
					self.patch[i][j].taxi = nil						-- sets the patch as empty
				end -- if
			end -- if
		end -- while
	end -- while    
	return some_movement
end -- use_reservations

return Map
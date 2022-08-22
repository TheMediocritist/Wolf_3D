local pd <const> = playdate
local gfx <const> = pd.graphics

class('Map').extends()

function Map:init(columns, rows, mapdata)
	self.current_column = 1
	self.current_row = 1
	self.base_sprites = {}
	self.wall_sprites = {}
	self.full_map = {columns = 24, rows = 24, tiledata = {}}
	self.full_map.image = gfx.image.new(columns * 4, rows * 4)
	self.mini_map = {columns = 11, rows = 11, tiledata = {}, screenx = 10, screeny = 10}
	
	self.tileW = 16
	self.tileH = 16
	self.full_map.tiledata = Map:importMap()
	self.mini_map.tiledata = Map:new(11, 11, self.current_column, self.current_row)
	
	
	-- draw the map image
	gfx.lockFocus(self.full_map.image)
	gfx.setColor(gfx.kColorWhite)
	for y = 1, self.full_map.rows do
		for x = 1, self.full_map.columns do 
			gfx.fillRect((x - 1) * 4, (y - 1) * 4, 4, 4)
		end
	end
	gfx.unlockFocus()
	--self:refresh()
end

function Map:update()
	-- call this each playdate.update
end

function Map:scroll(shift_columns, shift_rows)
	if shift_columns < 0 and (self.current_column + shift_columns > 0) then -- scroll west (map moves east)
		for x = 0, shift_columns, -1 do
			self.current_column -= 1
			for row = 1, self.mini_map.rows do
				-- delete last tile in row
				self.mini_map.tiledata[row][self.mini_map.columns] = nil
				-- add a new tile at start of row
				table.insert(self.mini_map.tiledata[row], 1, self.full_map.tiledata[self.current_row + row - 1][self.current_column])
			end
		end
	elseif shift_columns > 0 and (self.current_column + shift_columns <= self.full_map.columns) then -- scroll east (map moves west)
		for x = 1, shift_columns do
			self.current_column -= 1
			for row = 1, self.mini_map.rows do
				-- delete first tile in row
				self.mini_map.tiledata[row][1] = nil
				-- add a new tile at end of row
				self.mini_map.tiledata[row][self.mini_map.columns] = self.full_map.tiledata[self.current_row + row - 1][self.current_column + self.mini_map.columns - 1]
			end
		end
	end
	
	if shift_rows < 0 and (self.current_row + shift_rows > 0) then -- scroll north (map moves south
		for row = 0, shift_rows, -1 do
			self.current_row -= 1
			-- delete the last row in mini map
			self.mini_map.tiledata[self.mini_map.rows] = nil
			-- add new first row and copy data from full map
			table.insert(self.mini_map.tiledata, 1)
			for column = 1, self.mini_map.columns do
				self.mini_map.tiledata[1][column] = self.full_map.tiledata[self.current_row][self.current_column + column - 1]
			end
		end
	elseif shift_rows > 0 and (self.current_row + shift_rows <= self.full_map.rows) then -- scroll north (map moves south
		for row = 0, shift_rows do
			self.current_row += 1
			-- delete the first row in mini map
			self.mini_map.tiledata[1] = nil
			-- add new last row and copy data from full map
			table.insert(self.mini_map.tiledata, #self.mini_map.tiledata + 1)
			for column = 1, self.mini_map.columns do
				self.mini_map.tiledata[self.mini_map.rows][column] = self.full_map.tiledata[self.current_row + self.mini_map.rows][self.current_column + column - 1]
			end
		end
	end
end

function Map:new(columns, rows, current_column, current_row)
	--local tile_index = 0
	local tiledata = {}
	for row = 1, rows do
		local rowdata = {}
		for column = 1, columns do
			local data = self.full_map.tiledata[current_row + row - 1][current_column + column - 1]
			table.insert(rowdata, data)
			self.base_sprites[#self.base_sprites + 1] = self:makeBaseSprite(column, row, data)
		end
		table.insert(tiledata, rowdata)
	end
	return tiledata
end

function Map:refresh()
	-- checks that sprite types match what's in their location on map
	local types = {"empty", "wall", "type3", "start", "exit", "door", "type7", "type8", "type9" }
	for row = 1, self.mini_map.rows do
		for column = 1, self.mini_map.columns do
			local index = (row - 1) * self.mini_map.rows + column
			if self.base_sprites[index].type ~= types[self.mini_map.tiledata[row][column]] then
				print("type: ".. self.base_sprites[index].type)
				print("column, row, data: " .. column .. ", " .. row .. ", " .. self.mini_map.tiledata[row][column])
				self.base_sprites[index] = self.makeBaseSprite(column, row, self.mini_map.tiledata[row][column])
			end
			if self.base_sprites[index].type == "wall" then
				self:makeWall(base_sprites[index])
			end
		end
	end
end

function Map:makeBaseSprite(this_column, this_row, this_data) --column, row, data)
	local s = gfx.sprite.new(16, 16)
	local types = {"wall", "type3", "start", "exit", "door", "type7", "type8", "type9", "empty"}
	print("screenx, tileW, column, screeny, tileH, row: " .. self.mini_map.screenx .. ", " .. self.tileW .. ", " ..this_column .. ", " .. self.mini_map.screeny .. ", " .. self.tileH .. ", " .. this_row)
	local x_pos = self.mini_map.screenx + self.tileW * (this_column - 1)
	local y_pos = self.mini_map.screeny + self.tileH * (this_row - 1)
	s.type = types[this_data]
	print("column, row, data, type: " .. this_column .. ", " .. this_row .. ", " .. this_data .. ", " .. s.type)
	s.column = column
	s.row = row
	s.in_view = false
	if s.type == "wall" then
		-- self.updateWallDetails(s, column, row)
		s.image_noview = gfx.image.new(16, 16, gfx.kColorBlack)
		s.image_inview = gfx.image.new(16, 16, gfx.kColorWhite)
		s:setImage(s.image_noview)
		s:setCollideRect(0, 0, 16, 16)
	end
	
	function s.update()
		if s.type == "wall" then
		  if s.in_view == true and s:getImage() ~= s.image_inview then
			  s:setImage(s.image_inview)
		  elseif s.in_view == false and s:getImage() ~= s.image_noview then
			  s:setImage(s.image_noview)
			  s.inview = false
		  else
			s.inview = false
		  end
		end
	end
	
	s:add()
	s:moveTo(x_pos, y_pos)
	
	return s
end

function Map:makeWall(this_sprite)
	this_sprite.image_noview = gfx.image.new(16, 16, gfx.kColorBlack)
	this_sprite.image_inview = gfx.image.new(16, 16, gfx.kColorWhite)
	this_sprite:setImage(s.image_noview)
	this_sprite:setCollideRect(0, 0, 16, 16)
end

function Map:updateWallDetails(this_sprite, column, row)
	--local s = this_sprite
	local screenx = 10--self.mini_map.screenx
	local screeny = 10--self.mini_map.screeny
	s.inview = false
	local vertices = {nw = geom.point.new(screenx + (column-1) * 16, screeny + (row-1) * 16),
				  ne = geom.point.new(screenx + column * 16, screeny + (row-1) * 16),
				  se = geom.point.new(screenx + column * 16, screeny + row * 16),
				  sw = geom.point.new(screenx + (column-1) * 16, screeny + row * 16)}
	s.view_vertices = {}
	
	local num_walls = 4
	
	-- cull walls between wall sprites and populate view vertices (8 directions)
	if row == 1 or self.mini_map.data[row - 1][column] == 1 then s.wall_n = true num_walls -=1 else s.wall_n = false end
	if row == self.mini_map.rows or self.mini_map.data[row + 1][column] == 1 then s.wall_s = true num_walls -=1 else s.wall_s = false end
	if column == 1 or self.mini_map.data[row][column - 1] == 1 then s.wall_w = true num_walls -=1 else s.wall_w = false end
	if column == self.mini_map.columns or self.mini_map.data[row][column + 1] == 1 then s.wall_e = true num_walls -=1 else s.wall_e = false end
	
	if num_walls == 4 then
	  s.image_noview = wall_tiles_imagetable:getImage(1)
	  s.image_inview = wall_tiles_imagetable:getImage(16)
	elseif num_walls == 3 then
	  if s.wall_n then 
		s.image_noview = wall_tiles_imagetable:getImage(2)
		s.image_inview = wall_tiles_imagetable:getImage(17)
	  elseif s.wall_e then 
		s.image_noview = wall_tiles_imagetable:getImage(3)
		s.image_inview = wall_tiles_imagetable:getImage(18)
	  elseif s.wall_s then 
		s.image_noview = wall_tiles_imagetable:getImage(4)
		s.image_inview = wall_tiles_imagetable:getImage(19)
	  elseif s.wall_w then 
		s.image_noview = wall_tiles_imagetable:getImage(5)
		s.image_inview = wall_tiles_imagetable:getImage(20)
	  end
	elseif num_walls == 2 then
	  if s.wall_s and s.wall_w then 
		s.image_noview = wall_tiles_imagetable:getImage(6)
		s.image_inview = wall_tiles_imagetable:getImage(21)
	  elseif s.wall_w and s.wall_n then 
		s.image_noview = wall_tiles_imagetable:getImage(7)
		s.image_inview = wall_tiles_imagetable:getImage(22)
	  elseif s.wall_n and s.wall_e then 
		s.image_noview = wall_tiles_imagetable:getImage(8)
		s.image_inview = wall_tiles_imagetable:getImage(23)
	  elseif s.wall_e and s.wall_s then 
		s.image_noview = wall_tiles_imagetable:getImage(9)
		s.image_inview = wall_tiles_imagetable:getImage(24)
	  elseif s.wall_n and s.wall_s then 
		s.image_noview = wall_tiles_imagetable:getImage(10)
		s.image_inview = wall_tiles_imagetable:getImage(25)
	  elseif s.wall_e and s.wall_w then 
		s.image_noview = wall_tiles_imagetable:getImage(11)
		s.image_inview = wall_tiles_imagetable:getImage(26)
	  end
	elseif num_walls == 1 then
	  if s.wall_e and s.wall_s and s.wall_w then 
		s.image_noview = wall_tiles_imagetable:getImage(12)
		s.image_inview = wall_tiles_imagetable:getImage(27)
	  elseif s.wall_s and s.wall_w and s.wall_n then 
		s.image_noview = wall_tiles_imagetable:getImage(13)
		s.image_inview = wall_tiles_imagetable:getImage(28)
	  elseif s.wall_w and s.wall_n and s.wall_e then 
		s.image_noview = wall_tiles_imagetable:getImage(14)
		s.image_inview = wall_tiles_imagetable:getImage(29)
	  elseif s.wall_n and s.wall_e and s.wall_s then 
		s.image_noview = wall_tiles_imagetable:getImage(15)
		s.image_inview = wall_tiles_imagetable:getImage(30)
	  end
	end
	
	if not (s.wall_n and s.wall_s and s.wall_e and s.wall_w) then
	  
	  -- when wall is below and right of player, draw left and top sides
	  if s.wall_n and s.wall_w then s.view_vertices.nw =  table.create(2, 0)
	  elseif s.wall_n then s.view_vertices.nw =           {vertices.nw, vertices.sw}
	  elseif s.wall_w then s.view_vertices.nw =           {vertices.ne, vertices.nw}
	  else s.view_vertices.nw =                           {vertices.ne, vertices.nw, vertices.sw}
	  end
	  
	  -- when wall is above and right of player, draw left and bottom sides
	  if s.wall_w and s.wall_s then s.view_vertices.sw =  table.create(2, 0)
	  elseif s.wall_w then s.view_vertices.sw =           {vertices.sw, vertices.se}
	  elseif s.wall_s then s.view_vertices.sw =           {vertices.nw, vertices.sw}
	  else s.view_vertices.sw =                           {vertices.nw, vertices.sw, vertices.se}
	  end
	  
	  -- when wall is below and left of player, draw right and top sides
	  if s.wall_n and s.wall_e then s.view_vertices.ne =  table.create(2, 0)
	  elseif s.wall_n then s.view_vertices.ne =           {vertices.se, vertices.ne}
	  elseif s.wall_e then s.view_vertices.ne =           {vertices.ne, vertices.nw}
	  else s.view_vertices.ne =                           {vertices.se, vertices.ne, vertices.nw}
	  end
	  
	  -- when wall is above and left of player, draw right and bottom sides
	  if s.wall_e and s.wall_s then s.view_vertices.se = table.create(2, 0)
	  elseif s.wall_e then s.view_vertices.se = {vertices.sw, vertices.se}
	  elseif s.wall_s then s.view_vertices.se = {vertices.se, vertices.ne}
	  else s.view_vertices.se = {vertices.sw, vertices.se, vertices.ne}
	  end
	  
	  -- when wall is directly below player, only draw the top side
	  if s.wall_n then s.view_vertices.n = table.create(2, 0)
	  else s.view_vertices.n = {vertices.ne, vertices.nw}
	  end
	  
	  -- when wall is directly above player, only draw the bottom side
	  if s.wall_s then s.view_vertices.s = table.create(2, 0)
	  else s.view_vertices.s = {vertices.sw, vertices.se}
	  end
	  
	  -- when wall is directly to right of player, only draw the left side
	  if s.wall_w then s.view_vertices.w = table.create(2, 0)
	  else s.view_vertices.w = {vertices.nw, vertices.sw}
	  end
	  
	  -- when wall is directly to left of player, only draw the right side
	  if s.wall_e then s.view_vertices.e = table.create(2, 0)
	  else s.view_vertices.e = {vertices.se, vertices.ne}
	  end
	  
	  s:setCollideRect(0, 0, 16, 16)

	end
end

function Map:convertTileToPixel(x,y)
	local tileW = self.tilewidth
	local tileH = self.tileheight
	return x * tileW, y * tileH
end

function Map:convertPixelToTile(x, y)
	local tileW = self.tilewidth
	local tileH = self.tileheight
	return x / tileW, y / tileH
end

function Map:importMap()
	map = {
	{9,9,1,1,1,1,9,9,9,9,9,9,9,1,1,1,1,1,1,1,1},
	{9,9,1,9,9,1,1,1,1,1,1,1,1,1,9,9,9,9,9,9,1},
	{9,9,1,9,9,9,9,6,9,9,9,9,9,6,9,9,9,9,9,9,1},
	{9,9,1,1,1,1,1,1,1,1,9,1,1,1,1,9,9,9,9,9,1},
	{9,9,1,9,9,9,9,9,1,1,9,1,1,9,1,1,9,9,9,1,1},
	{9,9,1,9,9,9,9,9,6,9,9,9,1,9,9,1,1,6,1,1,9},
	{9,9,1,9,9,9,9,9,1,1,1,1,1,9,9,9,1,9,1,9,9},
	{9,9,1,9,9,9,9,9,1,9,9,9,9,9,9,9,1,9,1,9,9},
	{1,1,1,1,1,6,1,1,1,9,9,9,9,9,9,9,1,9,1,9,9},
	{1,9,9,9,1,9,1,9,9,9,9,9,1,1,1,1,1,9,1,1,1},
	{1,9,9,9,1,9,1,9,9,9,9,9,1,9,9,9,9,9,9,9,1},
	{1,9,1,1,1,6,1,1,1,9,9,9,1,9,1,1,1,9,1,9,1},
	{1,9,1,9,9,9,9,9,1,9,9,9,1,9,1,9,1,9,1,9,1},
	{1,9,1,9,9,9,9,9,1,1,1,1,1,1,1,1,1,9,1,1,1},
	{1,9,6,9,9,9,9,9,1,1,9,9,9,9,9,1,1,9,1,9,9},
	{1,9,1,9,9,9,9,9,1,9,9,9,9,9,9,9,1,9,1,9,9},
	{1,9,1,9,9,9,9,9,1,9,9,9,9,9,9,9,9,9,1,9,9},
	{1,9,1,1,1,6,1,1,1,9,9,9,9,9,9,9,1,1,1,9,9},
	{1,9,1,9,1,9,1,9,1,1,9,9,9,9,9,1,1,1,1,1,1},
	{1,9,9,9,1,9,1,9,9,1,1,1,1,1,1,1,1,1,9,9,1},
	{1,9,1,9,1,9,1,9,9,1,1,1,1,9,9,9,9,1,9,4,1},
	{1,9,1,1,1,9,1,1,1,1,9,9,9,9,9,9,9,6,9,9,1},
	{1,9,9,9,9,9,9,9,9,6,9,9,1,9,9,9,9,1,9,9,1},
	{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}}

	return map
end
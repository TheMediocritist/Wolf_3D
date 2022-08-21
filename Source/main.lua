import 'CoreLibs/sprites'
import 'CoreLibs/graphics'
import 'CoreLibs/animation'
import 'CoreLibs/timer'

local gfx <const> = playdate.graphics
local geom <const> = playdate.geometry
local sin <const> = math.sin
local cos <const> = math.cos
local atan <const> = math.atan
local atan2 <const> = math.atan2
local tan <const> = math.tan
local deg <const> = math.deg 
local rad <const> = math.rad
local asin <const> = math.asin
local ceil <const> = math.ceil
local floor <const> = math.floor
local min <const> = math.min
local max <const> = math.max
local pow <const> = math.pow
local fast_intersection <const> = geom.lineSegment.fast_intersection

-- set up camera
local camera <const> = {fov = 70, view_distance = 70, width = 400, width_div = 200, height = 500, height_div = 250}
local camera_width_half <const> = camera.width / 2
local camera_height_half <const> = camera.height / 2
local camera_fov_half <const> = camera.fov / 2
local camera_fov_half_neg <const> = -camera_fov_half

-- variables to store dt/delta time
local dt, last_time = 0, 0

-- add custom menu items
local menu = playdate.getSystemMenu()
local draw_shaded, draw_debug, draw_minimap, draw_minimap_switched = true, false, true, false

menu:addCheckmarkMenuItem("shading", true, function(value)
    draw_shaded = value
end)
menu:addCheckmarkMenuItem("debug map", false, function(value)
  draw_debug = value
end)
menu:addCheckmarkMenuItem("mini map", true, function(value)
  draw_minimap = value
  draw_minimap_switched = true
end)

playdate.setMinimumGCTime(2) -- This is necessary to remove frequent stutters
gfx.setColor(gfx.kColorBlack)
playdate.display.setRefreshRate(40)

local map_floor1 <const> =  
{{0,0,1,1,1,1,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1},
{0,0,1,0,0,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,1},
{0,0,1,0,0,0,0,6,0,0,0,0,0,6,0,0,0,0,0,0,1},
{0,0,1,1,1,1,1,1,1,1,0,1,1,1,1,0,0,0,0,0,1},
{0,0,1,0,0,0,0,0,1,1,0,1,1,0,1,1,0,0,0,1,1},
{0,0,1,0,0,0,0,0,6,0,0,0,1,0,0,1,1,6,1,1,0},
{0,0,1,0,0,0,0,0,1,1,1,1,1,0,0,0,1,0,1,0,0},
{0,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,1,0,0},
{1,1,1,1,1,6,1,1,1,0,0,0,0,0,0,0,1,0,1,0,0},
{1,0,0,0,1,0,1,0,0,0,0,0,1,1,1,1,1,0,1,1,1},
{1,0,0,0,1,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,1},
{1,0,1,1,1,6,1,1,1,0,0,0,1,0,1,1,1,0,1,0,1},
{1,0,1,0,0,0,0,0,1,0,0,0,1,0,1,0,1,0,1,0,1},
{1,0,1,0,0,0,0,0,1,1,1,1,1,1,1,1,1,0,1,1,1},
{1,0,6,0,0,0,0,0,1,1,0,0,0,0,0,1,1,0,1,0,0},
{1,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0,1,0,0},
{1,0,1,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,1,0,0},
{1,0,1,1,1,6,1,1,1,0,0,0,0,0,0,0,1,1,1,0,0},
{1,0,1,0,1,0,1,0,1,1,0,0,0,0,0,1,1,1,1,1,1},
{1,0,0,0,1,0,1,0,0,1,1,1,1,1,1,1,1,1,0,0,1},
{1,0,1,0,1,0,1,0,0,1,1,1,1,0,0,0,0,1,0,4,1},
{1,0,1,1,1,0,1,1,1,1,0,0,0,0,0,0,0,6,0,0,1},
{1,0,0,0,0,0,0,0,0,6,0,0,1,0,0,0,0,1,0,0,1},
{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}}

local map <const> = {
  1, 1, 1, 1, 1, 1, 1,
  1, 0, 0, 0, 0, 0, 1,
  1, 0, 1, 1, 0, 1, 1,
  1, 0, 0, 0, 0, 0, 1,
  1, 0, 1, 0, 1, 0, 1,
  1, 0, 1, 0, 1, 0, 1,
  1, 1, 1, 1, 1, 1, 1
  }

local working_map_rows, working_map_columns = nil, nil
local working_map_sprites = {}

local initialised = false
local map_sprite, player_sprite = nil, nil
local sprite_size = 16
local wall_sprites = table.create(31, 0)
local player_start = {x = 24, y = 24, direction = 90}
local player_speed = 40
local draw_these = table.create(9, 0)
local view = gfx.image.new(400, 240, gfx.kColorBlack)
local background_image = gfx.image.new('Images/background_gradient')
local images = {}
local wall_tiles_imagetable = gfx.imagetable.new("Images/wall_tiles-table-16-16")
local gun_shot_sfx <const> = playdate.sound.sample.new("SFX/gun-shot")

local function cos_rad(x)
  return cos(rad(x))
end

local function sin_rad(x)
  return sin(rad(x))
end

local function isWall(tile_x, tile_y)
  -- returns true if working map has a wall at tile_x, tile_y
  if working_map[(tile_y - 1) * 7 + tile_x] == 1 then
    return true
  else 
    return false
  end
end

local function tileAt(x, y)
  -- returns: tileid, column, row
  -- or false if outside working map bounds
  local column, row = ceil(x/16), ceil(y/16)
  if column > 0 and column <= working_map_columns and row > 0 and row <= working_map_rows then
    local tileid = (row - 1) * working_map_columns + column
    return tileid, column, row
  else 
    return false
  end
end

local function spritesAt(column, row)
  -- returns {true, {sprite list} if mini map has a sprite at tile_x, tile_y
  local x = (column - 1) * 16 + 8
  local y = (row - 1) * 16 + 8
  local sprites_at_point = gfx.sprite.querySpritesAtPoint(x, y)
  if #sprites_at_point > 0 then
    return true, sprites_at_point
  end
end

function makeWorkingMap(columns, rows)
  working_map_sprites = {}
  local index = 0
  for y = 1, rows do
    for x = 1, columns do
      index += 1
      -- put a tile sprite here
      local sprite = gfx.sprite.new()
      sprite.tileid = index
      sprite.row = y
      sprite.column = x
      sprite.width, sprite.height = sprite_size, sprite_size
      sprite.is_wall = false
      working_map_sprites[#working_map_sprites + 1] = sprite
    end
  end
end

function initialise()
    --makeWorkingMap(12, 12)
    makeWallImages()
    makeWallSprites(map, 7, 7)
    player_sprite = makePlayer(player_start.x, player_start.y, player_start.direction)
    setUpCamera()
    initialised = true
    
    gfx.sprite.setBackgroundDrawingCallback(
      function()
        --gfx.setClipRect(10, 10, 380, 220)
        view:draw(0, 0)
        --gfx.clearClipRect()
      end
    )
end

function makeWallImages ()
  
  images.walls_noview = {}
  images.walls_inview = {}
  images.walls_noview.three_n = wall_tiles_imagetable:getImage(12)
  images.walls_noview.two_ne = wall_tiles_imagetable:getImage(8)
  images.walls_noview.two_ns = wall_tiles_imagetable:getImage(12)
  images.walls_noview.one_nes = wall_tiles_imagetable:getImage(2)
  images.walls_noview.four_nesw = wall_tiles_imagetable:getImage(1)
  
  images.walls_inview.three_n = wall_tiles_imagetable:getImage(27)
  images.walls_inview.two_ne = wall_tiles_imagetable:getImage(23)
  images.walls_inview.two_ns = wall_tiles_imagetable:getImage(27)
  images.walls_inview.one_nes = wall_tiles_imagetable:getImage(17)
  images.walls_inview.four_nesw = wall_tiles_imagetable:getImage(16)

end

function setUpCamera()
  
  -- calculate smallest number of rays required to detect all tiles in range of camera view_distance
  local required_angle = deg(atan(sprite_size/camera.view_distance))
  local camera_rays = floor(camera.fov/required_angle)  -- Temp until rays replaced with tree
  camera.ray_angles = camera.fov/camera_rays
  camera.rays = camera_rays + 1 -- fence segments vs posts
  camera.direction = player_sprite.direction
  camera.ray_lines = table.create(camera.rays, 0)
  print("FOV: " .. camera.fov .. ", " .. camera.rays .. " rays at intervals of " .. floor(camera.ray_angles * 100)/100 .. " degrees")
  for i = 1, camera.rays do
    local ray_direction = (player_sprite.direction - camera_fov_half) + (camera.ray_angles * (i - 1))
    local ray_end_x = player_sprite.x + camera.view_distance * sin_rad(ray_direction)
    local ray_end_y = player_sprite.y - camera.view_distance * cos_rad(ray_direction)
    camera.ray_lines[i] = geom.lineSegment.new(player_sprite.x, player_sprite.y, ray_end_x, ray_end_y)
  end
end


local function getVertices(wall_sprite)
  -- Fetch vertices for projecting/drawing
  if wall_sprite.x - 8 > player_sprite.x then
      if wall_sprite.y - 8 > player_sprite.y then return wall_sprite.view_vertices.nw         -- wall is below and right of player
      elseif (wall_sprite.y + 8) < player_sprite.y then return wall_sprite.view_vertices.sw   -- wall is above and right of player
      else return wall_sprite.view_vertices.w end                                             -- wall is directly to right of player
  elseif (wall_sprite.x + 8) < player_sprite.x then
      if wall_sprite.y - 8 > player_sprite.y then return wall_sprite.view_vertices.ne         -- wall is below and left of player
      elseif (wall_sprite.y + 8) < player_sprite.y then return wall_sprite.view_vertices.se   -- wall is above and left of player
      else return wall_sprite.view_vertices.e end                                             -- wall is directly to left of player
  elseif (wall_sprite.y - 8) > player_sprite.y then return wall_sprite.view_vertices.n        -- wall is directly below player
  elseif (wall_sprite.y + 8) < player_sprite.y then return wall_sprite.view_vertices.s        -- wall is directly above player 
  end
end

local function updateDeltaTime()
  -- updates dt (seconds since last frame)
  local old_last_time = last_time
  last_time = playdate.getCurrentTimeMilliseconds()
  dt = (last_time - old_last_time)/1000
end

function playdate.update()
    if initialised == false then initialise() end
    
    updateDeltaTime()
    playdate.timer.updateTimers()
    updateView()
    gfx.sprite.redrawBackground()
    gfx.sprite.update()
    
    if draw_minimap_switched then
      local do_draw = draw_minimap and true or false
      for i = 1, #wall_sprites do
        wall_sprites[i]:setVisible(do_draw)
        player_sprite:setVisible(do_draw)
      end
      draw_minimap_switched = false
    end
    
    -- draw camera rays on mini-map
    -- draw all rays: for i = 1, camera.rays do
    -- draw only left and right rays: for i = 1, camera.rays, (camera.rays -1) do
    if draw_minimap then 
      for i = 1, camera.rays, (camera.rays - 1) do
        gfx.setLineWidth(3)
        gfx.setColor(gfx.kColorWhite)
        gfx.drawLine(camera.ray_lines[i])
        gfx.setLineWidth(1)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawLine(camera.ray_lines[i])
      end
    end
    
    playdate.drawFPS(381, 4)
end

function updateView()

  gfx.pushContext(view)
  background_image:draw(0, 0)
  
  local screen_polys = {}
  local player = geom.point.new(player_sprite.x, player_sprite.y)
  local num_draw_these = #draw_these
  
  for i = 1, num_draw_these do
    local points = getVertices(draw_these[i])
    local p = {} 
    
    for i = 1, #points do
      p[i] = table.create(0, 4)
      p[i].vertex = points[i]
    end
    
    local last_p = #p
      if last_p > 0 then -- this skips over all the maths & drawing for objects with no visible vertices
        
        -- calculate angle to vertex in camera coordinates
        for i = 1, last_p do
          p[i].delta = player - p[i].vertex
          local deltax, deltay = p[i].delta:unpack()
          p[i].player_angle = deg(atan2(deltax, -deltay)) +180
          p[i].camera_angle = (p[i].player_angle - player_sprite.direction) % 360
          if p[i].camera_angle > 180 then p[i].camera_angle -= 360 end
        end
        
        -- remove end point if entire wall is out of view
        if last_p == 3 then
          if p[1].camera_angle <= camera_fov_half_neg and p[2].camera_angle <= camera_fov_half_neg then
            table.remove(p, 1)
            last_p -= 1
          end
      
          if p[last_p].camera_angle >= (camera_fov_half) and p[last_p-1].camera_angle >= (camera_fov_half) then
            table.remove(p, last_p)
            last_p -= 1
          end
        end
        
        -- calculate distance between player and vertex as well as 'forward' distance from camera
        for i = 1, last_p do
          p[i].player_distance = p[i].vertex:distanceToPoint(player)
          p[i].camera_distance = p[i].player_distance * cos(rad(p[i].camera_angle))
        end
      
      local last_point = #p
      
      -- if wall extends behind camera, shift the vertex to clip the wall
      if p[1].camera_distance < sprite_size or p[last_point].camera_distance < sprite_size then -- if walls close enough to extend behind camera
        local point = p[1]
        local ray_line = point.camera_angle < camera_fov_half_neg and {camera.ray_lines[1], camera_fov_half_neg} 

        if ray_line then -- only runs if _left_ vertex outside view
          
          local x1, y1 = p[2].vertex:unpack()
          local x2, y2 = point.vertex:unpack()
          local x3, y3, x4, y4 = ray_line[1]:unpack()
          local intersects, new_point_x, new_point_y = fast_intersection(x1, y1, x2, y2, x3, y3, x4, y4)
          
          if intersects then
            point.vertex = geom.point.new(new_point_x, new_point_y)
            point.delta = point.vertex - player
            point.player_distance = point.vertex:distanceToPoint(player)
            point.camera_angle = ray_line[2]
            point.camera_distance = point.player_distance * cos(rad(point.camera_angle))
          end
        end
        
        local point = p[last_point]
        local ray_line = point.camera_angle > camera_fov_half and {camera.ray_lines[camera.rays], camera_fov_half}
        
        if ray_line then -- only runs if _right_ vertex outside view
          local x1, y1 = p[last_point - 1].vertex:unpack()
          local x2, y2 = point.vertex:unpack()
          local x3, y3, x4, y4 = ray_line[1]:unpack()
          local intersects, new_point_x, new_point_y = fast_intersection(x1, y1, x2, y2, x3, y3, x4, y4)
          
          if intersects then
            point.vertex = geom.point.new(new_point_x, new_point_y)
            point.delta = point.vertex - player
            point.player_distance = point.vertex:distanceToPoint(player)
            point.camera_angle = ray_line[2]
            point.camera_distance = point.player_distance * cos(rad(point.camera_angle))
          end
        end
      end
      
      -- calculate vertex offset from screen centre
      for i = 1, last_p do
        p[i].offset_x = (p[i].camera_angle/(camera_fov_half)) * (camera_width_half)
        p[i].offset_y = (1/p[i].camera_distance) * (camera_height_half)
      end
      
      -- turn points into polygons
      for i = 1, last_point - 1 do
        screen_polys[#screen_polys+1] = table.create(0, 6)
        local poly = screen_polys[#screen_polys]
        local next_p = p[i+1]
        local p = p[i]
        poly.distance = (p.camera_distance + next_p.camera_distance)/2
        poly.left_angle = min(p.camera_angle, next_p.camera_angle)
        poly.right_angle = max(p.camera_angle, next_p.camera_angle)
  
        poly.polygon = geom.polygon.new(
          200 + p.offset_x, 120 + p.offset_y*4,
          200 + next_p.offset_x, 120 + next_p.offset_y*4,
          200 + next_p.offset_x, 120 - next_p.offset_y*4,
          200 + p.offset_x, 120 - p.offset_y*4,
          200 + p.offset_x, 120 + p.offset_y*4)
                            
        if draw_debug then
          -- draw wall to top-down view
          gfx.setColor(gfx.kColorWhite)
          gfx.drawLine(340 + p[i].camera_distance * tan(rad(p[i].camera_angle)), 68 - p[i].camera_distance, 
                  340 + p[i+1].camera_distance * tan(rad(p[i+1].camera_angle)), 68 - p[i+1].camera_distance)
        end
      end
    end
  end
    
  -- Draw polygons
  local num_screen_polys = #screen_polys
  
  if draw_shaded == false then
    gfx.setColor(gfx.kColorWhite)
    for i = num_screen_polys, 1, -1 do
      gfx.drawPolygon(screen_polys[i].polygon)
    end
  else
    for i = num_screen_polys, 1, -1 do
      gfx.setColor(gfx.kColorWhite)
      if player_sprite.hands.state == "shooting" then
        if player_sprite.hands.animation.current.frame == 1 then
          gfx.setDitherPattern(-0.6 + (screen_polys[i].distance/camera.view_distance*1.5),gfx.image.kDitherTypeBayer4x4)
        elseif player_sprite.hands.animation.current.frame == 2 then
          gfx.setDitherPattern(-0.6 + (screen_polys[i].distance/camera.view_distance*1.7),gfx.image.kDitherTypeBayer4x4)
        else
          gfx.setDitherPattern(-0.6 + (screen_polys[i].distance/camera.view_distance*1.8),gfx.image.kDitherTypeBayer4x4)
        end
      else
        gfx.setDitherPattern(0.1+(screen_polys[i].distance/camera.view_distance/1.2),gfx.image.kDitherTypeBayer4x4)
      end
      gfx.fillPolygon(screen_polys[i].polygon)
    end
  gfx.setColor(gfx.kColorBlack)
  end
  
  if draw_debug then
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(340, 68, 292, 20)
    gfx.drawLine(340, 68, 388, 20)
  end

  gfx.setColor(gfx.kColorBlack)
  gfx.popContext()
  
end

function makeWallSprites(map, columns, rows)
    local map_index = 0
    local image_outofview = gfx.image.new(16, 16, gfx.kColorBlack)
    local image_inview = gfx.image.new(16, 16, gfx.kColorBlack)
    gfx.lockFocus(image_inview)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(1, 1, 14, 14)
    gfx.unlockFocus()
    gfx.setColor(gfx.kColorBlack)
    
    for y = 1, rows do
        for x = 1, columns do
            map_index += 1
            if map[map_index] == 1 then
                local s = gfx.sprite.new(16,16)
                s.image_inview = image_inview
                s.image_noview = image_outofview
                s.inview = false
                s.wall = true
                s.index = map_index
                local vertices = {nw = geom.point.new((x-1) * 16, (y-1) * 16),
                              ne = geom.point.new(x * 16, (y-1) * 16),
                              se = geom.point.new(x * 16, y * 16),
                              sw = geom.point.new((x-1) * 16, y * 16)}
                s.view_vertices = {}
                
                local num_walls = 4
                
                -- cull walls between wall sprites and populate view vertices (8 directions)
                if y == 1 or (y > 1 and map[(y - 2) * columns + x] == 1) then s.wall_n = true num_walls -=1 else s.wall_n = false end
                if y == 7 or (y < 7 and map[y  * columns + x] == 1) then s.wall_s = true num_walls -=1 else s.wall_s = false end
                if x == 1 or (x > 1 and map[(y - 1) * columns + x - 1] == 1) then s.wall_w = true num_walls -=1 else s.wall_w = false end
                if x == 7 or (x < 7 and map[(y - 1) * columns + x + 1] == 1) then s.wall_e = true num_walls -=1 else s.wall_e = false end
                
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
                  
                  function s.update()
                      if s.inview == true and s:getImage() ~= s.image_inview then
                          s:setImage(s.image_inview)
                      elseif s.inview == false and s:getImage() ~= s.image_noview then
                          s:setImage(s.image_noview)
                          s.inview = false
                      else
                        s.inview = false
                      end
                  end
                  
                  s:add()
                  s:moveTo((x-1) * 16+8, (y-1) * 16+8)
                  
                  wall_sprites[#wall_sprites + 1] = s
                end
            end
        end
      
    end
end

function makePlayer(x_pos, y_pos, direction)
    local hands = gfx.sprite.new()
    hands.image = gfx.image.new(176, 160, gfx.kColorClear)
    hands.state = "idle"
    hands.imagetable = gfx.imagetable.new('Images/hands')
    hands.animation = { shoot = gfx.animation.loop.new(100, animation_grid(hands.imagetable, {1, 2, 3}), false),
                        reload = gfx.animation.loop.new(100, animation_grid(hands.imagetable, {4, 5, 6, 7, 8}), false),
                        idle = gfx.animation.loop.new(100, animation_grid(hands.imagetable, {1}), true)}
    hands.animation.current = hands.animation.idle
    function hands:update()
      if hands.state == "idle" then
        if playdate.buttonIsPressed(playdate.kButtonA) then
          gun_shot_sfx:play()
          hands.state = "shooting"
          hands.animation.current = gfx.animation.loop.new(100, animation_grid(hands.imagetable, {2, 3, 1}), false)
        end
      elseif hands.animation.current.frame == 3 then
        hands.state = "idle"
        hands.animation.current = hands.animation.idle
      end
      gfx.lockFocus(hands.image)
      gfx.setColor(gfx.kColorClear)
      gfx.fillRect(0, 0, 176, 160)
      hands.animation.current:draw(0, 0)
      gfx.unlockFocus()
      hands:setImage(hands.image)
    end
    hands:add()
    hands:moveTo(240, 160)
    
    local image = gfx.image.new(6, 6)
    gfx.lockFocus(image)
    gfx.fillCircleAtPoint(3, 3, 3)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(3, 30, 2)
    gfx.unlockFocus()
    
    local s = gfx.sprite.new(image)
    s.hands = hands
    s.moved = false
    s.direction = direction
    s:setCollideRect(0, 0, 6, 6)
    s:setCenter(0.5, 0.5)
    s.collisionResponse = gfx.sprite.kCollisionTypeSlide
    s.rotate_transform = playdate.geometry.affineTransform.new()
    s.sin_dir = sin_rad(s.direction)
    s.cos_dir = cos_rad(s.direction)
    s.view_left = geom.lineSegment.new(x_pos, y_pos, x_pos + sin_rad(s.direction - camera_fov_half), y_pos - cos_rad(s.direction - camera_fov_half))
    s.view_right = geom.lineSegment.new(x_pos, y_pos, x_pos + sin_rad(s.direction + camera_fov_half), y_pos - cos_rad(s.direction + camera_fov_half))
    function s:update()

      local movex, movey = 0, 0
        if playdate.buttonIsPressed(playdate.kButtonRight) then 
            if playdate.buttonIsPressed(playdate.kButtonB) then
                -- strafe right
                movex = s.cos_dir
                movey = -s.sin_dir
                s.moved = true
            else
                -- turn right
                s.direction += 4
                s.rotate_transform:rotate(4, s.x, s.y)
                if s.direction > 360 then s.direction -= 360 end
                s.moved = true
            end
        end
        if playdate.buttonIsPressed(playdate.kButtonLeft) then 
            if playdate.buttonIsPressed(playdate.kButtonB) then
                -- strafe left
                movex = -s.cos_dir
                movey = s.sin_dir
                s.moved = true
            else
                -- turn left
                s.direction -= 4
                s.rotate_transform:rotate(-4, s.x, s.y)
                if s.direction < 0 then s.direction += 360 end
                s.moved = true
            end 
        end
        if playdate.buttonIsPressed(playdate.kButtonUp) then
            movex = s.sin_dir
            movey = s.cos_dir
            s.moved = true
        end
        if playdate.buttonIsPressed(playdate.kButtonDown) then
            movex = -s.sin_dir
            movey = -s.cos_dir
            s.moved = true
        end
        
        if s.moved then
          
          local actualX, actualY, collisions = s:moveWithCollisions(s.x + (movex * dt * player_speed), s.y - (movey * dt * player_speed))
          for i = 1, #camera.ray_lines do
            camera.ray_lines[i]:offset(-(camera.ray_lines[i].x - actualX), -(camera.ray_lines[i].y - actualY))
            camera.ray_lines[i] = s.rotate_transform:transformedLineSegment(camera.ray_lines[i])
          end
          
          s.view_left = camera.ray_lines[1]
          s.view_right = camera.ray_lines[#camera.ray_lines]
          
          s.sin_dir = sin_rad(s.direction)
          s.cos_dir = cos_rad(s.direction)
          
          s.moved = false
          s.rotate_transform:reset()
        end
        
        s:raytrace() 
    end
    
    function s:raytrace()
        draw_these = table.create(9, 0)
        -- trace rays
          for i = 1, camera.rays do
              ray_hits = gfx.sprite.querySpritesAlongLine(camera.ray_lines[i])
              for i = 1, min(#ray_hits, 3) do
                  ray_hits[i].inview = true
              end
          end
          for i = 1, #wall_sprites do
              if wall_sprites[i].inview then
                  draw_these[#draw_these + 1] = wall_sprites[i]
              end
          end
    end
    
    s:add()
    s:moveTo(x_pos, y_pos)
    return s
    
end

function animation_grid(imagetable, sequence)
  local temp_imagetable = gfx.imagetable.new(#sequence)
  for i, v in ipairs(sequence) do
    temp_imagetable:setImage(i, imagetable:getImage(v))
  end
  return temp_imagetable
end
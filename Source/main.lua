import 'CoreLibs/sprites'
import 'CoreLibs/graphics'
local gfx <const> = playdate.graphics
local geom <const> = playdate.geometry
local sin <const> = math.sin
local cos <const> = math.cos
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
local camera <const> = {fov = 90, fov_div = 45, view_distance = 70, width = 400, width_div = 200, height = 500, height_div = 250}

-- performance monitoring (to work out what's using CPU time)
local perf_monitor <const> = table.create(0, 11)

-- add custom menu items
local menu = playdate.getSystemMenu()

local draw_shaded, draw_debug, perfmon = true, false, false

menu:addCheckmarkMenuItem("Shading", true, function(value)
    draw_shaded = value
end)
menu:addCheckmarkMenuItem("draw debug", true, function(value)
  draw_debug = value
end)
menu:addCheckmarkMenuItem("perfmon", false, function(value)
  perfmon = value
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
local draw_these = table.create(9, 0)
local view = gfx.image.new(400, 240, gfx.kColorBlack)
local background_image = gfx.image.new('Images/background_gradient')
local images = {}
local wall_tiles_imagetable = gfx.imagetable.new("Images/wall_tiles-table-16-16")

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
    setupPerformanceMonitor()
    makeWallImages()
    makeWallSprites(map, 7, 7)
    player_sprite = makePlayer(player_start.x, player_start.y, player_start.direction)
    setUpCamera()
    initialised = true
    
    gfx.sprite.setBackgroundDrawingCallback(
        function()
            view:draw(0, 0)
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
  
  print("fov: " .. camera.fov)
  
  -- calculate smallest number of rays required to detect all tiles in range of camera view_distance
  local required_angle = math.deg(math.atan(sprite_size/camera.view_distance))
  local camera_rays = math.floor(camera.fov/required_angle)  -- Temp until rays replaced with tree
  camera.ray_angles = camera.fov/camera_rays
  camera.rays = camera_rays + 1 -- fence segments vs posts
  camera.direction = player_sprite.direction
  camera.ray_lines = table.create(camera.rays, 0)
  print("FOV: " .. camera.fov .. ", " .. camera.rays .. " rays at intervals of " .. math.floor(camera.ray_angles * 100)/100 .. " degrees")
  for i = 1, camera.rays do
    local ray_direction = (player_sprite.direction - camera.fov_div) + (camera.ray_angles * (i - 1))
    local ray_end_x = player_sprite.x + camera.view_distance * sin_rad(ray_direction)
    local ray_end_y = player_sprite.y - camera.view_distance * cos_rad(ray_direction)
    camera.ray_lines[i] = geom.lineSegment.new(player_sprite.x, player_sprite.y, ray_end_x, ray_end_y)
  end
  --printTable(camera.ray_lines)
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

function playdate.update()
    if initialised == false then initialise() end
    
    updateView()
    
    gfx.sprite.redrawBackground()
    
    if perfmon then
      playdate.resetElapsedTime()
    end
    gfx.sprite.update()
    if perfmon then
      perf_monitor.sprites_update.finish = playdate.getElapsedTime()
      playdate.resetElapsedTime()
    end
    
    for i = 1, camera.rays do--, (camera.rays -1)  do
      gfx.setLineWidth(3)
      gfx.setColor(gfx.kColorWhite)
      gfx.drawLine(camera.ray_lines[i])
      gfx.setLineWidth(1)
      gfx.setColor(gfx.kColorBlack)
      gfx.drawLine(camera.ray_lines[i])
    end
    
    if perfmon then
      perf_monitor.sprites_draw.finish = playdate.getElapsedTime()
    end
    playdate.drawFPS(0,0)

end

local function updateView()

  gfx.lockFocus(view)
  background_image:draw(0, 0)
  
  if perfmon then
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(215, 5, 180, 230)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("player: " .. perf_monitor.player_update.finish*1000 .. "ms", 220, 10)
    gfx.drawText("load vert: " .. perf_monitor.projection_load_vertices.finish*1000 .. "ms", 220, 30)
    gfx.drawText("vert math: " .. perf_monitor.projection_vertex_maths.finish*1000 .. "ms", 220, 50)
    gfx.drawText("vert clip: " .. perf_monitor.projection_vertex_clip.finish*1000 .. "ms", 220, 70)
    gfx.drawText("vert proj: " .. perf_monitor.projection_vertex_project.finish*1000 .. "ms", 220, 90)
    gfx.drawText("poly make: " .. perf_monitor.projection_poly_make.finish*1000 .. "ms", 220, 110)
    gfx.drawText("poly sort: " .. perf_monitor.projection_poly_sort.finish*1000 .. "ms", 220, 130)
    gfx.drawText("poly cull: " .. perf_monitor.projection_poly_cull.finish*1000 .. "ms", 220, 150)
    gfx.drawText("poly draw: " .. perf_monitor.projection_poly_draw.finish*1000 .. "ms", 220, 170)
    gfx.drawText("sprite upd: " .. perf_monitor.projection_poly_draw.finish*1000 .. "ms", 220, 190)
    gfx.drawText("draw: " .. perf_monitor.projection_poly_draw.finish*1000 .. "ms", 220, 210)
  end
  
  local screen_polys = table.create(#draw_these, 0)
  local player = geom.point.new(player_sprite.x, player_sprite.y)
  local num_draw_these <const> = #draw_these
  
  if perfmon then
    perf_monitor.projection_load_vertices.start = playdate.getCurrentTimeMilliseconds()
    playdate.resetElapsedTime()
  end
  
  for i = 1, num_draw_these do
    --local wall_sprite = draw_these[i]
    local points = getVertices(draw_these[i])

    if perfmon then
      perf_monitor.projection_load_vertices.finish = playdate.getElapsedTime() * num_draw_these
      perf_monitor.projection_vertex_maths.start = playdate.getCurrentTimeMilliseconds()
      playdate.resetElapsedTime()
    end
    
    local p = table.create(#points, 0)
    for i = 1, #points do
      p[i] = table.create(0, 3)
      p[i].vertex = points[i]
    end

    local p1_obj <const> = p[1]
    local p2_obj <const> = p[2]

    local last_p = #p
      if last_p > 0 then
        for i = 1, last_p do
        local pp = p[i]
        pp.delta = player - pp.vertex
        local deltax, deltay = pp.delta:unpack()
        local player_angle = deg(atan2(deltax, -deltay)) + 180
        if player_angle < 0 then player_angle += 360 end
        pp.camera_angle = (player_angle - player_sprite.direction) % 360
        if pp.camera_angle > 180 then pp.camera_angle -= 360 end
      end
            
      -- remove vertices that make a wall completely outside view
      if last_p == 3 then
        if p1_obj.camera_angle <= -(camera.fov_div) and p2_obj.camera_angle <= -(camera.fov_div) then
            table.remove(p, 1)
            last_p -= 1
        end
        
        if p[last_p].camera_angle >= (camera.fov_div) and p[last_p-1].camera_angle >= (camera.fov_div) then
            table.remove(p, last_p)
            last_p -= 1
        end
        
      end          
      
      -- calculate distance and angle from player to each vertex
      for i = 1, last_p do
        local p = p[i]
        p.player_distance = p.vertex:distanceToPoint(player)
        p.camera_distance = p.player_distance * cos_rad(p.camera_angle)
      end
      
      if perfmon then
        perf_monitor.projection_vertex_maths.finish = playdate.getElapsedTime() * num_draw_these
        perf_monitor.projection_vertex_clip.start = playdate.getCurrentTimeMilliseconds()
        playdate.resetElapsedTime()
      end
      
      print("before clipping")
      for i = 1, #p do
        if p[i].camera_angle < (-camera.fov_div) or p[i].camera_angle > (camera.fov_div) then
          printTable(p[i])
        end
      end
      -- check if wall extends outside view and behind player, and if so
      -- determine where it crosses into view and shift it to this point
      if p1_obj.camera_angle < -(camera.fov_div) then --and p[1].camera_distance < sprite_size then 
          local intersects, new_point_x, new_point_y = fast_intersection(p2_obj.vertex.x, p2_obj.vertex.y, p1_obj.vertex.x, p1_obj.vertex.y, camera.ray_lines[1]:unpack())
          
          if intersects then
              p1_obj.vertex = geom.point.new(new_point_x, new_point_y)
              p1_obj.delta = p1_obj.vertex - player
              p1_obj.player_distance = p1_obj.vertex:distanceToPoint(player)
              p1_obj.camera_angle = -(camera.fov_div)
              p1_obj.camera_distance = p1_obj.player_distance * cos_rad(p1_obj.camera_angle)
          end
          
      elseif p1_obj.camera_angle > ((camera.fov_div)) then --and p[1].camera_distance < sprite_size then
          local intersects, new_point_x, new_point_y = fast_intersection(p2_obj.vertex.x, p2_obj.vertex.y, p1_obj.vertex.x, p1_obj.vertex.y, camera.ray_lines[#camera.ray_lines]:unpack())
  
          if intersects then
              p1_obj.vertex = geom.point.new(new_point_x, new_point_y)
              p1_obj.delta = p1_obj.vertex - player
              p1_obj.player_distance = p1_obj.vertex:distanceToPoint(player)
              p1_obj.camera_angle = (camera.fov_div)
              p1_obj.camera_distance = p1_obj.player_distance * cos_rad(p1_obj.camera_angle)
          end
      end
      
      local last_point_obj = p[#p]
      local last_last_point_obj = p[#p-1]
      
      if last_point_obj.camera_angle < (-(camera.fov_div)) and last_point_obj.camera_distance < sprite_size then 
          local intersects, new_point_x, new_point_y = fast_intersection(last_point_obj.vertex.x, last_point_obj.vertex.y, last_last_point_obj.vertex.x, last_last_point_obj.vertex.y, camera.ray_lines[1]:unpack())
          
          if intersects then
              last_point_obj.vertex = geom.point.new(new_point_x, new_point_y)
              last_point_obj.delta = last_point_obj.vertex - player
              last_point_obj.player_distance = last_point_obj.vertex:distanceToPoint(player)
              last_point_obj.camera_angle = -(camera.fov_div)
              last_point_obj.camera_distance = last_point_obj.player_distance * cos_rad(last_point_obj.camera_angle)
          end
          
      elseif last_point_obj.camera_angle > camera.fov_div and last_point_obj.camera_distance < sprite_size then
         local intersects, new_point_x, new_point_y = fast_intersection(last_point_obj.vertex.x, last_point_obj.vertex.y, last_last_point_obj.vertex.x, last_last_point_obj.vertex.y, camera.ray_lines[#camera.ray_lines]:unpack())

          if intersects then
              last_point_obj.vertex = geom.point.new(new_point_x, new_point_y)
              last_point_obj.delta = last_point_obj.vertex - player
              last_point_obj.player_distance = last_point_obj.vertex:distanceToPoint(player)
              last_point_obj.camera_angle = (camera.fov_div)
              last_point_obj.camera_distance = last_point_obj.player_distance * cos_rad(last_point_obj.camera_angle)
          end
      end
      
      print("after clipping")
      for i = 1, #p do
        if p[i].camera_angle < (-camera.fov_div) or p[i].camera_angle > (camera.fov_div) then
          printTable(p[i])
        end
      end
      
      if perfmon then
        perf_monitor.projection_vertex_clip.finish = playdate.getElapsedTime() * num_draw_these
        playdate.resetElapsedTime()
      end
      
      -- determine how far vertex is offset from centre of view
      for i = 1, last_p do
        local pp = p[i]
        pp.offset_x = (pp.camera_angle/(camera.fov_div)) * (camera.width_div)
        pp.offset_y = (1/pp.camera_distance) * (camera.height_div)
      end
      
      if perfmon then
        perf_monitor.projection_vertex_project.finish = playdate.getElapsedTime() * num_draw_these
        playdate.resetElapsedTime()
      end
      
      local last_point = #p
      
      -- convert vertices to screen coordinates using offsets, and make polygon
      for i = 1, last_point - 1 do
        screen_polys[#screen_polys+1] = table.create(0, 4)
        local p_obj = p[i]
        local p_plus = p[i+1]
        local poly = screen_polys[#screen_polys]
        poly.distance = (p_obj.camera_distance + p_plus.camera_distance) * 0.5
        poly.left_angle = min(p_obj.camera_angle, p_plus.camera_angle)
        poly.right_angle = max(p_obj.camera_angle, p_plus.camera_angle)
        local p_obj_offset_x = 200 + p_obj.offset_x
        local p_plus_offset_x = 200 + p_plus.offset_x
        local p_obj_offset_y = p_obj.offset_y*4
        local p_plus_offset_y = p_plus.offset_y*4
        poly.polygon = geom.polygon.new(
                                      p_obj_offset_x, 120 + p_obj_offset_y,
                                      p_plus_offset_x, 120 + p_plus_offset_y,
                                      p_plus_offset_x, 120 - p_plus_offset_y,
                                      p_obj_offset_x, 120 - p_obj_offset_y,
                                      p_obj_offset_x, 120 + p_obj_offset_y)
        
        if draw_debug then
          -- draw wall to top-down view
          gfx.setColor(gfx.kColorWhite)
          gfx.drawLine(   200 + p_obj.camera_distance * tan(rad(p_obj.camera_angle)), 128 - p_obj.camera_distance, 
                          200 + p_plus.camera_distance * tan(rad(p_plus.camera_angle)), 128 - p_plus.camera_distance)
          gfx.setColor(gfx.kColorBlack)
        end
      end
      
      if perfmon then
        perf_monitor.projection_poly_make.finish = playdate.getElapsedTime() * num_draw_these
        playdate.resetElapsedTime()
      end
    end
  end

  -- Draw polygons
  local num_screen_polys = #screen_polys
    
  for i = num_screen_polys, 1, -1 do
    gfx.setColor(gfx.kColorWhite)
    gfx.setDitherPattern(0.1+(screen_polys[i].distance/80),gfx.image.kDitherTypeBayer4x4)
    gfx.fillPolygon(screen_polys[i].polygon)
  end
  
  if perfmon then
    perf_monitor.projection_poly_draw.finish = playdate.getElapsedTime()
  end

  if draw_debug then
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(200, 128, 152, 80)
    gfx.drawLine(200, 128, 248, 80)
  end

  gfx.setColor(gfx.kColorBlack)
  gfx.unlockFocus()
    
end

function playdate.update()
    if initialised == false then initialise() end
    
    updateView()
    
    gfx.sprite.redrawBackground()
    
    if perfmon then
      playdate.resetElapsedTime()
    end
    
    gfx.sprite.update()

    -- draw camera rays over minimap   
    -- draw only first at last rays: for i = 1, camera.rays, camera.rays - 1 do
    -- draw all rays: for i = 1, camera.rays do
    for i = 1, camera.rays do
      gfx.setLineWidth(2)
      gfx.setColor(gfx.kColorWhite)
      gfx.drawLine(camera.ray_lines[i])
      gfx.setLineWidth(1)
      gfx.setColor(gfx.kColorBlack)
      gfx.drawLine(camera.ray_lines[i])
    end
    
    if perfmon then
      perf_monitor.sprites_update.finish = playdate.getElapsedTime()
      playdate.resetElapsedTime()
      perf_monitor.sprites_draw.finish = playdate.getElapsedTime()
    end
    
    playdate.drawFPS(0,0)
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
    
    local image = gfx.image.new(6, 6)
    gfx.lockFocus(image)
    gfx.fillCircleAtPoint(3, 3, 3)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillCircleAtPoint(3, 30, 2)

    gfx.unlockFocus()
    local s = gfx.sprite.new(image)
    s.moved = false
    s.direction = direction
    s:setCollideRect(0, 0, 6, 6)
    s:setCenter(0.5, 0.5)
    s.collisionResponse = gfx.sprite.kCollisionTypeSlide
    s.rotate_transform = playdate.geometry.affineTransform.new()
    s.sin_dir = sin_rad(s.direction)
    s.cos_dir = cos_rad(s.direction)
    function s:update()
      if perfmon then
        playdate.resetElapsedTime()
      end
      local movex, movey = 0, 0
        if playdate.buttonIsPressed('right') then 
            if playdate.buttonIsPressed('b') then
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
        if playdate.buttonIsPressed('left') then 
            if playdate.buttonIsPressed('b') then
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
        if playdate.buttonIsPressed('up') then
            movex = s.sin_dir
            movey = s.cos_dir
            s.moved = true
        end
        if playdate.buttonIsPressed('down') then
            movex = -s.sin_dir
            movey = -s.cos_dir
            s.moved = true
        end
        
        if s.moved then
          local actualX, actualY, collisions = s:moveWithCollisions(s.x + movex, s.y - movey)
          for i = 1, #camera.ray_lines do
            camera.ray_lines[i]:offset(-(camera.ray_lines[i].x - actualX), -(camera.ray_lines[i].y - actualY))
            camera.ray_lines[i] = s.rotate_transform:transformedLineSegment(camera.ray_lines[i])
          end
          
          s.sin_dir = sin(rad(s.direction))
          s.cos_dir = cos(rad(s.direction))
          
          s.moved = false
          s.rotate_transform:reset()
        end
        
        if perfmon then
          perf_monitor.player_update.finish = playdate.getElapsedTime()
          playdate.resetElapsedTime()
        end
        
        s:raytrace()
        
        if perfmon then
          perf_monitor.player_find_viewable_walls.finish = playdate.getElapsedTime()
        end
        
    end
    
    function s:raytrace()
        draw_these = table.create(9, 0)
        -- trace rays
          for i = 1, camera.rays do
              ray_hits = gfx.sprite.querySpritesAlongLine(camera.ray_lines[i])
              for i = 1, math.min(#ray_hits, 3) do
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


function setupPerformanceMonitor()
  
  perf_monitor.player_update = {start = 0, finish = 0, ms = 0, perc = 0}
  perf_monitor.player_find_viewable_walls = {start = 0, finish = 0, ms = 0, perc = 0}
  
  perf_monitor.projection_load_vertices = {start = 0, finish = 0, ms = 0, perc = 0}
  perf_monitor.projection_vertex_maths = {start = 0, finish = 0, ms = 0, perc = 0}
  perf_monitor.projection_vertex_project = {start = 0, finish = 0, ms = 0, perc = 0}
  perf_monitor.projection_vertex_clip = {start = 0, finish = 0, ms = 0, perc = 0}
  perf_monitor.projection_poly_make = {start = 0, finish = 0, ms = 0, perc = 0}
  perf_monitor.projection_poly_sort = {start = 0, finish = 0, ms = 0, perc = 0}
  perf_monitor.projection_poly_cull = {start = 0, finish = 0, ms = 0, perc = 0}
  perf_monitor.projection_poly_draw = {start = 0, finish = 0, ms = 0, perc = 0}
  
  perf_monitor.sprites_update = {start = 0, finish = 0, ms = 0, perc = 0}
  perf_monitor.sprites_draw = {start = 0, finish = 0, ms = 0, perc = 0}
  
end

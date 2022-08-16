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

-- set up camera
local camera <const> = {fov = 60, fov_div = 30, view_distance = 50, width = 400, width_div = 400/2, height = 500, height_div = 500/2}

-- performance monitoring (to work out what's using CPU time)
local perf_monitor <const> = table.create(0, 11)

-- add custom menu items
local menu = playdate.getSystemMenu()
local draw_shaded, sort_polys, cull_polys, perfmon = true, true, true, false
menu:addCheckmarkMenuItem("Shading", true, function(value)
    draw_shaded = value
end)
menu:addCheckmarkMenuItem("Sort/Cull", true, function(value)
  sort_polys = value
  cull_polys = value
end)
menu:addCheckmarkMenuItem("perfmon", false, function(value)
  perfmon = value
end)

playdate.setMinimumGCTime(8) -- This is necessary to remove frequent stutters
gfx.setColor(gfx.kColorBlack)
playdate.display.setRefreshRate(40)

local map_floor1 =  
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

local map = {
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
local wall_sprites = {}
local player_start = {x = 24, y = 24, direction = 90}
local rays = {}
local draw_these = {}
local view = gfx.image.new(400, 240, gfx.kColorBlack)
local background_image = gfx.image.new('Images/background_gradient')
local debug = false

function isWall(tile_x, tile_y)
  -- returns true if working map has a wall at tile_x, tile_y
  if working_map[(tile_y - 1) * 7 + tile_x] == 1 then
    return true
  else 
    return false
  end
end

function tileAt(x, y)
  -- returns: tileid, column, row
  -- or false if outside working map bounds
  local column, row = math.ceil(x/16), math.ceil(y/16)
  if column > 0 and column <= working_map_columns and row > 0 and row <= working_map_rows then
    local tileid = (row - 1) * working_map_columns + column
    return tileid, column, row
  else 
    return false
  end
end

function spritesAt(column, row)
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

function setUpCamera()
  -- calculate smallest number of rays required to detect all tiles in range of camera view_distance
  local required_angle = math.deg(math.asin(0.8*sprite_size/camera.view_distance))
  print("required angle: " .. required_angle)
  local camera_rays = math.floor(camera.fov/required_angle)
  print("camera_rays " .. camera_rays)
  local ray_angles = camera.fov/camera_rays
  print("ray_angles: " .. ray_angles)
  camera.direction = player_sprite.direction
  camera.rays = camera_rays + 1
  camera.ray_angles = ray_angles
  camera.ray_lines = {}
  for i = 1, camera.rays do
    local ray_direction = player_sprite.direction - (camera.fov_div) + camera.ray_angles * (i - 1)
    local ray_end_x = player_sprite.x + 60 * sin(rad(ray_direction))
    local ray_end_y = player_sprite.y - 60 * cos(rad(ray_direction))
    camera.ray_lines[#camera.ray_lines + 1] = geom.lineSegment.new(player_sprite.x, player_sprite.y, ray_end_x, ray_end_y)
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
    
    for i = 1, camera.rays, camera.rays - 1 do
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

function updateView()

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
  
  local num_draw_these = #draw_these
  
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
      p[i] = { vertex = points[i] }
    end

    local last_p = #p
      if last_p > 0 then
        for i = 1, last_p do
          p[i].delta = player - p[i].vertex
          local deltax, deltay = p[i].delta:unpack()
          p[i].player_angle = deg(atan2(deltax, -deltay)) +180
          --if p[i].player_angle < 0 then p[i].player_angle += 360 end
          p[i].camera_angle = (p[i].player_angle - player_sprite.direction) % 360
          if p[i].camera_angle > 180 then p[i].camera_angle -= 360 end
        end
            
        if last_p == 3 then
          if p[1].camera_angle <= -(camera.fov_div) and p[2].camera_angle <= -(camera.fov_div) then
              table.remove(p, 1)
              last_p -= 1
          end
    
          if p[last_p].camera_angle >= (camera.fov_div) and p[last_p-1].camera_angle >= (camera.fov_div) then
              table.remove(p, last_p)
              last_p -= 1
          end
        end
      end
          
      
      if last_p > 0 then
      
      for i = 1, last_p do
        p[i].player_distance = p[i].vertex:distanceToPoint(player)
        p[i].camera_distance = p[i].player_distance * cos(rad(p[i].camera_angle))
      end
      
      if perfmon then
        perf_monitor.projection_vertex_maths.finish = playdate.getElapsedTime() * num_draw_these
        perf_monitor.projection_vertex_clip.start = playdate.getCurrentTimeMilliseconds()
        playdate.resetElapsedTime()
      end
      
      local p1_obj <const> = p[1]
      local p2_obj <const> = p[2]
      if p1_obj.camera_angle < -(camera.fov_div) then 
          local x3, y3, x4, y4 = camera.ray_lines[1]:unpack()
          local intersects, new_point_x, new_point_y = geom.lineSegment.fast_intersection(p2_obj.vertex.x, p2_obj.vertex.y, p1_obj.vertex.x, p1_obj.vertex.y, x3, y3, x4, y4)
          
          if intersects then
              p1_obj.vertex = geom.point.new(new_point_x, new_point_y)
              p1_obj.delta = p1_obj.vertex - player
              p1_obj.player_distance = p1_obj.vertex:distanceToPoint(player)
              p1_obj.camera_angle = -(camera.fov_div)
              p1_obj.camera_distance = p1_obj.player_distance -- * cos(rad(p[1].camera_angle))
          end
          
      elseif p1_obj.camera_angle > ((camera.fov_div)) then
          local x3, y3, x4, y4 = camera.ray_lines[#camera.ray_lines]:unpack()
          local intersects, new_point_x, new_point_y = geom.lineSegment.fast_intersection(p2_obj.vertex.x, p2_obj.vertex.y, p1_obj.vertex.x, p1_obj.vertex.y, x3, y3, x4, y4)
  
          if intersects then
              p1_obj.vertex = geom.point.new(new_point_x, new_point_y)
              p1_obj.delta = p1_obj.vertex - player
              p1_obj.player_distance = p1_obj.vertex:distanceToPoint(player)
              p1_obj.camera_angle = (camera.fov_div)
              p1_obj.camera_distance = p1_obj.player_distance -- * cos(rad(p[1].camera_angle))
          end
      end
      
      local last_point_obj = p[#p]
      local last_last_point_obj = p[#p-1]
      if last_point_obj.camera_angle < (-(camera.fov_div)) then 
          local x3, y3, x4, y4 = camera.ray_lines[1]:unpack()
          local intersects, new_point_x, new_point_y = geom.lineSegment.fast_intersection(last_point_obj.vertex.x, last_point_obj.vertex.y, last_last_point_obj.vertex.x, last_last_point_obj.vertex.y, x3, y3, x4, y4)
          
          if intersects then
              last_point_obj.vertex = geom.point.new(new_point_x, new_point_y)
              last_point_obj.delta = last_point_obj.vertex - player
              last_point_obj.player_distance = last_point_obj.vertex:distanceToPoint(player)
              last_point_obj.camera_angle = -(camera.fov_div)
              last_point_obj.camera_distance = last_point_obj.player_distance * cos(rad(last_point_obj.camera_angle))
          end
      elseif last_point_obj.camera_angle > camera.fov_div then
         local x3, y3, x4, y4 = camera.ray_lines[#camera.ray_lines]:unpack()
         local intersects, new_point_x, new_point_y = geom.lineSegment.fast_intersection(last_point_obj.vertex.x, last_point_obj.vertex.y, last_last_point_obj.vertex.x, last_last_point_obj.vertex.y, x3, y3, x4, y4)
          if intersects then
              last_point_obj.vertex = geom.point.new(new_point_x, new_point_y)
              last_point_obj.delta = last_point_obj.vertex - player
              last_point_obj.player_distance = last_point_obj.vertex:distanceToPoint(player)
              last_point_obj.camera_angle = (camera.fov_div)
              last_point_obj.camera_distance = last_point_obj.player_distance * cos(rad(last_point_obj.camera_angle))
          end
      end
          
      if perfmon then
        perf_monitor.projection_vertex_clip.finish = playdate.getElapsedTime() * num_draw_these
        playdate.resetElapsedTime()
      end
      
      for i = 1, last_p do
        p[i].offset_x = (p[i].camera_angle/(camera.fov_div)) * (camera.width_div)
        p[i].offset_y = (1/p[i].camera_distance) * (camera.height_div)
      end
      
      if perfmon then
        perf_monitor.projection_vertex_project.finish = playdate.getElapsedTime() * num_draw_these
        playdate.resetElapsedTime()
      end
                    
          local last_point = #p

          for i = 1, last_point - 1 do
              screen_polys[#screen_polys+1] = table.create(0, 4)
              local p_plus = p[i+1]
              screen_polys[#screen_polys].distance = (p[i].camera_distance + p_plus.camera_distance)/2
              screen_polys[#screen_polys].left_angle = math.min(p[i].camera_angle, p_plus.camera_angle)
              screen_polys[#screen_polys].right_angle = math.max(p[i].camera_angle, p_plus.camera_angle)
  
              screen_polys[#screen_polys].polygon = geom.polygon.new(
                                                      200 + p[i].offset_x, 120 + p[i].offset_y*4,
                                                      200 + p_plus.offset_x, 120 + p_plus.offset_y*4,
                                                      200 + p_plus.offset_x, 120 - p_plus.offset_y*4,
                                                      200 + p[i].offset_x, 120 - p[i].offset_y*4,
                                                      200 + p[i].offset_x, 120 + p[i].offset_y*4)
              
              if debug then
                -- draw wall to top-down view
                gfx.drawLine(   200 + p[i].camera_distance * tan(rad(p[i].camera_angle)), 128 - p[i].camera_distance, 
                                200 + p[i+1].camera_distance * tan(rad(p[i+1].camera_angle)), 128 - p[i+1].camera_distance)
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
  
  if sort_polys == true then
    if num_screen_polys > 0 then
      -- sort screen polys from nearest to furthest
      table.sort(screen_polys, function (k1, k2) return k1.distance < k2.distance end)
    end
  end
  
  if perfmon then
    perf_monitor.projection_poly_sort.finish = playdate.getElapsedTime()
    playdate.resetElapsedTime()
  end
  
  if cull_polys == true then
    if num_screen_polys > 0 then
      -- determine if near polygons are blocking view of far polygons and if so, remove
      local blocked_area = table.create(num_screen_polys, 0)
      blocked_area[#blocked_area + 1] = table.create(0, 2)
      blocked_area[1].left = screen_polys[1].left_angle
      blocked_area[1].right = screen_polys[1].right_angle
      
      for i = 2, num_screen_polys do
        local done = false
        for j = 1, #blocked_area do
          if screen_polys[i].left_angle >= blocked_area[j].left and screen_polys[i].right_angle <= blocked_area[j].right then
            screen_polys[i].delete = true
            done = true
          elseif screen_polys[i].left_angle <= blocked_area[j].left and screen_polys[i].right_angle >= blocked_area[j].left then
            blocked_area[j].left = screen_polys[i].left_angle
            done = true
          elseif screen_polys[i].right_angle >= blocked_area[j].right and screen_polys[i].left_angle <= blocked_area[j].right then
            blocked_area[j].right = screen_polys[i].right_angle
            done = true
          end
        end
        
        if done == false then
          blocked_area[#blocked_area + 1] = table.create(0, 2)
          blocked_area[#blocked_area].left = screen_polys[i].left_angle
          blocked_area[#blocked_area].right = screen_polys[i].right_angle
        end
      end
            
      for i = num_screen_polys, 1, -1 do
        if screen_polys[i].delete == true then
          table.remove(screen_polys, i)
          num_screen_polys -= 1
        end
      end
    end
  end
  if perfmon then
    perf_monitor.projection_poly_cull.finish = playdate.getElapsedTime()
    playdate.resetElapsedTime()
  end
    
  if draw_shaded == false then
    gfx.setColor(gfx.kColorWhite)
    for i = num_screen_polys, 1, -1 do
      gfx.drawPolygon(screen_polys[i].polygon)
    end
  else
    
    for i = num_screen_polys, 1, -1 do
      gfx.setColor(gfx.kColorWhite)
      gfx.setDitherPattern(0.1+(screen_polys[i].distance/80),gfx.image.kDitherTypeBayer4x4)
      gfx.fillPolygon(screen_polys[i].polygon)
    end
    gfx.setColor(gfx.kColorBlack)
  end
  
  if perfmon then
    perf_monitor.projection_poly_draw.finish = playdate.getElapsedTime()
  end

  if debug then
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(200, 128, 152, 80)
    gfx.drawLine(200, 128, 248, 80)
  end

  gfx.setColor(gfx.kColorBlack)
  gfx.unlockFocus()
    
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
                local s = gfx.sprite.new(image_outofview)
                s.image_inview = image_inview
                s.image_noview = image_outofview
                s.inview = false
                s.wall = true
                s.index = map_index
                s.vertices = {nw = geom.point.new((x-1) * 16, (y-1) * 16),
                              ne = geom.point.new(x * 16, (y-1) * 16),
                              se = geom.point.new(x * 16, y * 16),
                              sw = geom.point.new((x-1) * 16, y * 16)}
                s.view_vertices = {}
                
                -- cull walls between wall sprites and populate view vertices (8 directions)
                if y == 1 or (y > 1 and map[(y - 2) * columns + x] == 1) then s.wall_n = true else s.wall_n = false end
                if y == 7 or (y < 7 and map[y  * columns + x] == 1) then s.wall_s = true else s.wall_s = false end
                if x == 1 or (x > 1 and map[(y - 1) * columns + x - 1] == 1) then s.wall_w = true else s.wall_w = false end
                if x == 7 or (x < 7 and map[(y - 1) * columns + x + 1] == 1) then s.wall_e = true else s.wall_e = false end
                
                -- when wall is below and right of player, draw left and top sides
                if s.wall_n and s.wall_w then s.view_vertices.nw =  table.create(2, 0)
                elseif s.wall_n then s.view_vertices.nw =           {s.vertices.nw, s.vertices.sw}
                elseif s.wall_w then s.view_vertices.nw =           {s.vertices.ne, s.vertices.nw}
                else s.view_vertices.nw =                           {s.vertices.ne, s.vertices.nw, s.vertices.sw}
                end
                
                -- when wall is above and right of player, draw left and bottom sides
                if s.wall_w and s.wall_s then s.view_vertices.sw =  table.create(2, 0)
                elseif s.wall_w then s.view_vertices.sw =           {s.vertices.sw, s.vertices.se}
                elseif s.wall_s then s.view_vertices.sw =           {s.vertices.nw, s.vertices.sw}
                else s.view_vertices.sw =                           {s.vertices.nw, s.vertices.sw, s.vertices.se}
                end
                
                -- when wall is below and left of player, draw right and top sides
                if s.wall_n and s.wall_e then s.view_vertices.ne =  table.create(2, 0)
                elseif s.wall_n then s.view_vertices.ne =           {s.vertices.se, s.vertices.ne}
                elseif s.wall_e then s.view_vertices.ne =           {s.vertices.ne, s.vertices.nw}
                else s.view_vertices.ne =                           {s.vertices.se, s.vertices.ne, s.vertices.nw}
                end
                
                -- when wall is above and left of player, draw right and bottom sides
                if s.wall_e and s.wall_s then s.view_vertices.se = table.create(2, 0)
                elseif s.wall_e then s.view_vertices.se = {s.vertices.sw, s.vertices.se}
                elseif s.wall_s then s.view_vertices.se = {s.vertices.se, s.vertices.ne}
                else s.view_vertices.se = {s.vertices.sw, s.vertices.se, s.vertices.ne}
                end
                
                -- when wall is directly below player, only draw the top side
                if s.wall_n then s.view_vertices.n = table.create(2, 0)
                else s.view_vertices.n = {s.vertices.ne, s.vertices.nw}
                end
                
                -- when wall is directly above player, only draw the bottom side
                if s.wall_s then s.view_vertices.s = table.create(2, 0)
                else s.view_vertices.s = {s.vertices.sw, s.vertices.se}
                end
                
                -- when wall is directly to right of player, only draw the left side
                if s.wall_w then s.view_vertices.w = table.create(2, 0)
                else s.view_vertices.w = {s.vertices.nw, s.vertices.sw}
                end
                
                -- when wall is directly to left of player, only draw the right side
                if s.wall_e then s.view_vertices.e = table.create(2, 0)
                else s.view_vertices.e = {s.vertices.se, s.vertices.ne}
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

    function s:update()
      playdate.resetElapsedTime()
      local movex, movey = 0, 0
        if playdate.buttonIsPressed('right') then 
            if playdate.buttonIsPressed('b') then
                -- strafe right
                movex = 1 * sin(rad(s.direction + 90))
                movey = 1 * cos(rad(s.direction + 90))
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
                movex = 1 * sin(rad(s.direction - 90))
                movey = 1 * cos(rad(s.direction - 90))
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
            movex = 1 * sin(rad(s.direction))
            movey = 1 * cos(rad(s.direction))
            s.moved = true
        end
        if playdate.buttonIsPressed('down') then
            movex = 1 * sin(rad(s.direction+180))
            movey = 1 * cos(rad(s.direction+180))
            s.moved = true
        end
        
        
        if s.moved then
          local actualX, actualY, collisions = s:moveWithCollisions(s.x + movex, s.y - movey)
          for i = 1, #camera.ray_lines do
            camera.ray_lines[i]:offset(-(camera.ray_lines[i].x - actualX), -(camera.ray_lines[i].y - actualY))
          end

          for i = 1, #camera.ray_lines do
            camera.ray_lines[i] = s.rotate_transform:transformedLineSegment(camera.ray_lines[i])

          end
          s.moved = false
          s.rotate_transform:reset()
        end
        
        if perfmon then
          perf_monitor.player_update.finish = playdate.getElapsedTime()
          perf_monitor.player_find_viewable_walls.start = playdate.getCurrentTimeMilliseconds()
          playdate.resetElapsedTime()
        end
        s:raytrace()
        if perfmon then
          perf_monitor.player_find_viewable_walls.finish = playdate.getElapsedTime()
        end
        
    end
    
    function s:raytrace()
        draw_these = {}
        -- trace rays
          for i = 1, camera.rays do
              ray_hits = gfx.sprite.querySpritesAlongLine(camera.ray_lines[i])
              for i = 1, #ray_hits do
                  ray_hits[i].inview = true
              end
          end
          for i = 1, #wall_sprites do
              if wall_sprites[i].inview then
                  draw_these[#draw_these + 1] = wall_sprites[i]
              end
          end
    end
    
    function s:tileSelect(angle)
      local view_tiles = {}
      draw_these = {}
      
      if angle >= 337.5 or angle < 22.5 then
        -- heading north
        view_tiles = {[1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [16] = true, [17] = true, [18] = true, [19] = true, [20] = true, [24] = true, [25] = true, [26] = true}
      end
      
      for i = 1, #wall_sprites do
        if view_tiles[wall_sprites[i].index] then
          wall_sprites[i].inview = true
          draw_these[#draw_these + 1] = wall_sprites[i]
        end
      end
      
      view_tiles = nil
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

function getVertices(wall_sprite)
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
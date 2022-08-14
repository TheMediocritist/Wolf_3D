import 'CoreLibs/sprites'
import 'CoreLibs/graphics'
local gfx = playdate.graphics
local geom = playdate.geometry
local sin = math.sin
local cos = math.cos
local atan2 = math.atan2
local deg = math.deg 
local rad = math.rad
playdate.setMinimumGCTime(8)

gfx.setColor(gfx.kColorBlack)

playdate.display.setRefreshRate(30)

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

local initialised = false
local map_sprite, player_sprite = nil, nil
local wall_sprites = {}
local player_start = {x = 24, y = 24, direction = 90}
local rays = {}
local draw_these= {}
local view = gfx.image.new(400, 240, gfx.kColorBlack)
local background_image = gfx.image.new('Images/background_gradient')
local camera = {x_offset = 0, y_offset = 16}

function initialise()
    makeWallSprites(map, 7, 7)
    player_sprite = makePlayer(player_start.x, player_start.y, player_start.direction)
    initialised = true
    
    gfx.sprite.setBackgroundDrawingCallback(
        function(x, y, width, height)
            --gfx.setClipRect(x, y, width, height) -- let's only draw the part of the screen that's dirty
            gfx.setClipRect(0, 0, 400, 240) -- let's only draw the part of the screen that's dirty - but pretend it's all dirty
            view:draw(0, 0)
            --gfx.clearClipRect() -- clear so we don't interfere with drawing that comes after this
        end
    )
end

function playdate.update()
    if initialised == false then initialise() end
    
    updateView()
    gfx.sprite.redrawBackground()
    gfx.sprite.update()
    gfx.setLineWidth(3)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(player_sprite.view_left)
    gfx.drawLine(player_sprite.view_right)
    gfx.setLineWidth(1)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(player_sprite.view_left)
    gfx.drawLine(player_sprite.view_right)
    playdate.drawFPS(0,0)
end

function updateView()

  gfx.lockFocus(view)
  background_image:draw(0, 0)
  gfx.setColor(gfx.kColorWhite)
  gfx.fillRect(0, 0, 112, 112)
  gfx.setColor(gfx.kColorBlack)

  local screen_polys = {}
  local player = geom.point.new(player_sprite.x, player_sprite.y)
  
  -- gfx.drawLine(player_sprite.view_left)
  -- gfx.drawLine(player_sprite.view_right)
  
  local num_draw_these = #draw_these
  
  for i = 1, num_draw_these do
    local wall_sprite = draw_these[i]
    local points = {}
        
    -- Fetch vertices for projecting/drawing
    if wall_sprite.x - 8 > player_sprite.x then
        if wall_sprite.y - 8 > player_sprite.y then -- wall is below and right of player, so draw left and top sides
          if wall_sprite.wall_n then
            points = {wall_sprite.vertices.nw, wall_sprite.vertices.sw}
          elseif wall_sprite.wall_w then
            points = {wall_sprite.vertices.ne, wall_sprite.vertices.nw}
          else
            points = {wall_sprite.vertices.ne, wall_sprite.vertices.nw, wall_sprite.vertices.sw}
          end
        elseif (wall_sprite.y + 8) < player_sprite.y then -- wall is above and right of player, so draw left and bottom sides
          if wall_sprite.wall_w then
            points = {wall_sprite.vertices.sw, wall_sprite.vertices.se}
          elseif wall_sprite.wall_s then
            points = {wall_sprite.vertices.nw, wall_sprite.vertices.sw}
          else
            points = {wall_sprite.vertices.nw, wall_sprite.vertices.sw, wall_sprite.vertices.se}
          end
        else -- wall is directly to right of player, so only draw the left side
            points = {wall_sprite.vertices.nw, wall_sprite.vertices.sw}
        end
    elseif (wall_sprite.x + 8) < player_sprite.x then
        if wall_sprite.y - 8 > player_sprite.y then -- wall is below and left of player, so draw right and top sides
          if wall_sprite.wall_n then
            points = {wall_sprite.vertices.se, wall_sprite.vertices.ne}
          elseif wall_sprite.wall_e then
            points = {wall_sprite.vertices.ne, wall_sprite.vertices.nw}
          else
            points = {wall_sprite.vertices.se, wall_sprite.vertices.ne, wall_sprite.vertices.nw}
          end
        elseif (wall_sprite.y + 8) < player_sprite.y then -- wall is above and left of player, so draw right and bottom sides
          if wall_sprite.wall_e then
            points = {wall_sprite.vertices.sw, wall_sprite.vertices.se}
          elseif wall_sprite.wall_s then
            points = {wall_sprite.vertices.se, wall_sprite.vertices.ne}
          else
            points = {wall_sprite.vertices.sw, wall_sprite.vertices.se, wall_sprite.vertices.ne}
          end
        else -- wall is directly to left of player, so only draw the right side
            points = {wall_sprite.vertices.se, wall_sprite.vertices.ne}
        end
    elseif (wall_sprite.y - 8) > player_sprite.y then -- wall is directly below player so only draw the top side
        points = {wall_sprite.vertices.ne, wall_sprite.vertices.nw}
    elseif (wall_sprite.y + 8) < player_sprite.y then -- wall is directly above player so only draw the bottom side
        points = {wall_sprite.vertices.sw, wall_sprite.vertices.se}
    end
            
    local p = {{}, {}}
    p[1].vertex, p[2].vertex = points[1]:copy(), points[2]:copy()
    
    if points[3] then
        p[3] = {}
        p[3].vertex = points[3]:copy()
    end
        
    local last_p = #p
        
    for i = 1, last_p do
      p[i] = {}
      p[i].vertex = points[i]
      p[i].delta = player - p[i].vertex
      local deltax, deltay = p[i].delta:unpack()
      p[i].player_angle = deg(atan2(deltax, -deltay)) +180
      if p[i].player_angle < 0 then p[i].player_angle += 360 end
      p[i].camera_angle = (p[i].player_angle - player_sprite.direction) % 360
      if p[i].camera_angle > 180 then p[i].camera_angle -= 360 end
    end
        
    if last_p == 3 then
      if p[1].camera_angle <= -45 and p[2].camera_angle <= -45 then
          -- print("removing point: 1")
          table.remove(p, 1)
          last_p -= 1
      end

      if p[last_p].camera_angle >= 45 and p[last_p-1].camera_angle >= 45 then
          -- print("removing point: " .. #p)
          table.remove(p, last_p)
          last_p -= 1
      end
    end
        
    for i = 1, last_p do
      p[i].player_distance = p[i].vertex:distanceToPoint(player)
      p[i].camera_distance = p[i].player_distance * cos(rad(p[i].camera_angle))
    end
        
    if p[1].camera_angle < -44 then 
        local view_line = geom.lineSegment.new(p[2].vertex.x, p[2].vertex.y, p[1].vertex.x, p[1].vertex.y)
        -- TO DO: Compare performance of geom.line_segment.fast_intersection
        local intersects, new_point = player_sprite.view_left:intersectsLineSegment(view_line)  
        if intersects then
            -- gfx.drawCircleAtPoint(new_point,3)
            p[1].vertex = geom.point.new(new_point.x, new_point.y)
            p[1].delta = p[1].vertex - player
            p[1].player_distance = p[1].vertex:distanceToPoint(player)
            p[1].camera_angle = -45
            p[1].camera_distance = p[1].player_distance * cos(rad(p[1].camera_angle))
        end
    elseif p[1].camera_angle > 44 then
        local view_line = geom.lineSegment.new(p[2].vertex.x, p[2].vertex.y, p[1].vertex.x, p[1].vertex.y)
        -- TO DO: Compare performance of geom.line_segment.fast_intersection
        local intersects, new_point = player_sprite.view_right:intersectsLineSegment(view_line)  
        if intersects then
            -- gfx.drawCircleAtPoint(new_point,3)
            p[1].vertex = geom.point.new(new_point.x, new_point.y)
            p[1].delta = p[1].vertex - player
            p[1].player_distance = p[1].vertex:distanceToPoint(player)
            p[1].camera_angle = 45
            p[1].camera_distance = p[1].player_distance * cos(rad(p[1].camera_angle))
        end
    end
        
        if p[2].camera_angle < -44 then 
            local view_line = geom.lineSegment.new(p[2].vertex.x, p[2].vertex.y, p[1].vertex.x, p[1].vertex.y)
            -- TO DO: Compare performance of geom.line_segment.fast_intersection
            local intersects, new_point = player_sprite.view_left:intersectsLineSegment(view_line)  
            if intersects then
                p[2].vertex = geom.point.new(new_point.x, new_point.y)
                p[2].delta = p[2].vertex - player
                p[2].player_distance = p[2].vertex:distanceToPoint(player)
                p[2].camera_angle = -45
                p[2].camera_distance = p[2].player_distance * cos(rad(p[2].camera_angle))
            end
        elseif p[2].camera_angle > 44 then
            local view_line = geom.lineSegment.new(p[2].vertex.x, p[2].vertex.y, p[1].vertex.x, p[1].vertex.y)
            -- TO DO: Compare performance of geom.line_segment.fast_intersection
            local intersects, new_point = player_sprite.view_right:intersectsLineSegment(view_line)  
            if intersects then
                p[2].vertex = geom.point.new(new_point.x, new_point.y)
                p[2].delta = p[2].vertex - player
                p[2].player_distance = p[2].vertex:distanceToPoint(player)
                p[2].camera_angle = 45
                p[2].camera_distance = p[2].player_distance * cos(rad(p[2].camera_angle))
            end
        end
        
        local last_point = #p
        if last_point == 3 then
          if p[last_point].camera_angle > 44 then
              local view_line = geom.lineSegment.new(p[last_point-1].vertex.x, p[last_point-1].vertex.y, p[last_point].vertex.x, p[last_point].vertex.y)
              -- TO DO: Compare performance of geom.line_segment.fast_intersection
              local intersects, new_point = player_sprite.view_right:intersectsLineSegment(view_line)  
              if intersects then
                  -- gfx.drawCircleAtPoint(new_point,3)
                  p[last_point].vertex = geom.point.new(new_point.x, new_point.y)
                  p[last_point].delta = p[last_point].vertex - player
                  p[last_point].player_distance = p[last_point].vertex:distanceToPoint(player)
                  p[last_point].camera_angle = 45
                  p[last_point].camera_distance = p[last_point].player_distance * cos(rad(p[last_point].camera_angle))
              end
          end
        end
        
        for i = 1, last_p do
          p[i].offset_x = p[i].camera_angle/44 * 200
          p[i].offset_y = 120 * (1/p[i].camera_distance) * 2
        end
        
        for i = 1, last_point - 1 do
            screen_polys[#screen_polys+1] = {}
            screen_polys[#screen_polys].distance = (p[i].camera_distance + p[i+1].camera_distance)/2
            screen_polys[#screen_polys].left_angle = math.min(p[i].camera_angle, p[i+1].camera_angle)
            screen_polys[#screen_polys].right_angle = math.max(p[i].camera_angle, p[i+1].camera_angle)

            screen_polys[#screen_polys].polygon = geom.polygon.new(
                                                    200 + p[i].offset_x, 120 + p[i].offset_y*4,
                                                    200 + p[i+1].offset_x, 120 + p[i+1].offset_y*4,
                                                    200 + p[i+1].offset_x, 120 - p[i+1].offset_y*4,
                                                    200 + p[i].offset_x, 120 - p[i].offset_y*4,
                                                    200 + p[i].offset_x, 120 + p[i].offset_y*4)
            
            if debug == false then
              -- draw wall to top-down view
              gfx.drawLine(   200 + p[i].camera_distance * math.tan(rad(p[i].camera_angle)), 128 - p[i].camera_distance, 
                              200 + p[i+1].camera_distance * math.tan(rad(p[i+1].camera_angle)), 128 - p[i+1].camera_distance)
            end
        end
    end

  -- Draw polygons
  gfx.setColor(gfx.kColorWhite)
  
  local num_screen_polys = #screen_polys
  if num_screen_polys > 0 then
    
    -- sort screen polys from nearest to furthest
    table.sort(screen_polys, function (k1, k2) return k1.distance < k2.distance end )
    
    -- determine if near polygons are blocking view of far polygons and if so, remove
    local blocked_area = {}
    blocked_area[#blocked_area + 1] = {}
    blocked_area[1].left = screen_polys[1].left_angle
    blocked_area[1].right = screen_polys[1].right_angle
    
    for i = 2, num_screen_polys do
      local done = false
      for j = 1, #blocked_area do
        -- print ("blocked area: " .. j .. "= " .. blocked_area[j].left .. ", " .. blocked_area[j].right)
        if screen_polys[i].left_angle >= blocked_area[j].left and screen_polys[i].right_angle <= blocked_area[j].right then
          screen_polys[i].delete = true
          done = true
          -- Would be quicker to escape here so subsequent blocked areas aren't examined
        elseif screen_polys[i].left_angle <= blocked_area[j].left and screen_polys[i].right_angle >= blocked_area[j].left then
          blocked_area[j].left = screen_polys[i].left_angle
          done = true
        elseif screen_polys[i].right_angle >= blocked_area[j].right and screen_polys[i].left_angle <= blocked_area[j].right then
          blocked_area[j].right = screen_polys[i].right_angle
          done = true
        end
      end
      
      if done == false then
        blocked_area[#blocked_area + 1] = {}
        blocked_area[#blocked_area].left = screen_polys[i].left_angle
        blocked_area[#blocked_area].right = screen_polys[i].right_angle
      end
    end
          
    for i = num_screen_polys, 1, -1 do
      -- print("screen_poly: " .. i)
      if screen_polys[i].delete == true then
        -- print("blocked, deleting")
        table.remove(screen_polys, i)
        num_screen_polys -= 1
      end
    end
    
    gfx.setColor(gfx.kColorWhite)
    
    for i = num_screen_polys, 1, -1 do
      gfx.setColor(gfx.kColorWhite)
      gfx.setDitherPattern(0.1+(screen_polys[i].distance/80),gfx.image.kDitherTypeBayer4x4)
      gfx.fillPolygon(screen_polys[i].polygon)
      gfx.setColor(gfx.kColorBlack)
      -- gfx.drawPolygon(screen_polys[i].polygon)
    end
    --gfx.setColor(gfx.kColorWhite)
  end
        
        
  if debug == false then
    gfx.setColor(gfx.kColorWhite)
    gfx.drawLine(200, 128, 152, 80)
    gfx.drawLine(200, 128, 248, 80)
  end

  gfx.setColor(gfx.kColorBlack)
  gfx.unlockFocus()
    
end

function makeMiniMap(map, columns, rows)
    local image = gfx.image.new(columns * 16, rows * 16, gfx.kColorWhite)
    local s = gfx.sprite.new(image)
    gfx.lockFocus(image)
    local map_index = 0
    for y = 1, rows do
        for x = 1, columns do
            map_index += 1
            if map[map_index] == 1 then
                gfx.fillRect((x-1) * 16, (y-1) * 16, 16, 16)
            end
        end
    end
    s:setImage(image)
    s:setCollideRect(0, 0, columns * 16, rows * 16)
    
    s:moveTo(180, 120)
    s:add()
    return s
end

function makeWallSprites(map, columns, rows)
    local map_index = 0
    local image_outofview = gfx.image.new(16, 16, gfx.kColorBlack)
    local image_inview = gfx.image.new(16, 16, gfx.kColorBlack)
    gfx.lockFocus(image_inview)
    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect(1, 1, 14, 14)
    gfx.setColor(gfx.kColorBlack)
    gfx.unlockFocus()
    
    for y = 1, rows do
        for x = 1, columns do
            map_index += 1
            if map[map_index] == 1 then
                local s = gfx.sprite.new(image_outofview)
                s.image_inview = image_inview
                s.image_noview = image_outofview
                s.inview = false
                s.wall = true
                -- s.wall_n = {(x-1) * 16, (y-1) * 16, x * 16, (y-1) * 16}
                -- s.wall_e = {x * 16, (y-1) * 16, x * 16, y * 16}
                -- s.wall_s = {(x-1) * 16, y * 16, x * 16, y * 16}
                -- s.wall_w = {(x-1) * 16, (y-1) * 16, (x-1) * 16, y * 16}
                s.vertices = {nw = geom.point.new((x-1) * 16, (y-1) * 16),
                            ne = geom.point.new(x * 16, (y-1) * 16),
                            se = geom.point.new(x * 16, y * 16),
                            sw = geom.point.new((x-1) * 16, y * 16)}
                -- cull walls between wall sprites
                if y > 1 and map[(y - 2) * columns + x] == 1 then s.wall_n = true else s.wall_n = false end
                if y < 7 and map[y  * columns + x] == 1 then s.wall_s = true else s.wall_s = false end
                if x > 1 and map[(y - 1) * columns + x - 1] == 1 then s.wall_w = true else s.wall_w = false end
                if x < 7 and map[(y - 1) * columns + x + 1] == 1 then s.wall_e = true else s.wall_e = false end

                s:setCollideRect(0, 0, 16, 16)
                function s.update()
                    if s.inview == true and s:getImage() ~= s.image_inview then
                        s:setImage(s.image_inview)
                    end
                    if s.inview == false and s:getImage() ~= s.image_noview then
                        s:setImage(s.image_noview)
                    end
                    s.inview = false
                end
                s:add()
                s:moveTo((x-1) * 16+8, (y-1) * 16+8)
                wall_sprites[#wall_sprites + 1] = s
            end
        end
    end
    -- printTable(wall_sprites)
end

function makePlayer(x_pos, y_pos, direction)
    
    -- local image = gfx.image.new(120, 120)
    local image = gfx.image.new(6, 6)
    gfx.lockFocus(image)
    -- gfx.fillCircleAtPoint(60, 60, 3)
    gfx.fillCircleAtPoint(3, 3, 3)
    gfx.setColor(gfx.kColorWhite)
    -- gfx.fillCircleAtPoint(60, 60, 2)
    gfx.fillCircleAtPoint(3, 30, 2)
    -- local view_left_x, view_left_y = 60 - 60 * cos(rad(direction+45)), 60 - 60 * sin(rad(direction+45))
    -- local view_right_x, view_right_y = 60 - 60 * cos(rad(direction+135)), 60 - 60 * sin(rad(direction+135))
    -- gfx.setLineWidth(3)
    -- gfx.drawLine(60, 60, view_left_x, view_left_y)
    -- gfx.drawLine(60, 60, view_right_x, view_right_y)
    -- gfx.setColor(gfx.kColorBlack)
    -- gfx.setLineWidth(1)
    -- gfx.drawLine(60, 60, view_left_x, view_left_y)
    -- gfx.drawLine(60, 60, view_right_x, view_right_y)
    gfx.unlockFocus()
    local s = gfx.sprite.new(image)
    s.moved = false
    s.direction = direction
    s.view_left = geom.lineSegment.new(x_pos, y_pos, x_pos + 80 * sin(rad(direction-45)), y_pos + 80 * cos(rad(direction-45)))
    s.view_right = geom.lineSegment.new(x_pos, y_pos, x_pos + 80 * sin(rad(direction+45)), y_pos + 80 * cos(rad(direction+45)))
    -- s:setCollideRect(57, 57, 6, 6)
    s:setCollideRect(0, 0, 6, 6)
    s:setCenter(0.5, 0.5)
    s.collisionResponse = gfx.sprite.kCollisionTypeSlide

    function s:update()
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
                --s:moveTo(s.x + movex, s.y - movey)
            else
                -- turn left
                s.direction -= 4
                if s.direction < 0 then s.direction += 360 end
                s.moved = true
            end 
        end
        if playdate.buttonIsPressed('up') then
            movex = 1 * sin(rad(s.direction))
            movey = 1 * cos(rad(s.direction))
            -- movex = 1
            -- movey = 1
            s.moved = true
            --s:moveWithCollisions(s.x + movex, s.y - movey)
            --s:moveTo(s.x + movex, s.y - movey)
        end
        if playdate.buttonIsPressed('down') then
            movex = 1 * sin(rad(s.direction+180))
            movey = 1 * cos(rad(s.direction+180))
            s.moved = true
            --s:moveTo(s.x + movex, s.y - movey)
        end
        
        
        if s.moved then
          --print("moving by x, y: " .. movex .. ", " .. movey)
          local actualX, actualY, collisions = s:moveWithCollisions(s.x + movex, s.y - movey)
          -- for i = 1, #collisions do
          --   printTable(collisions[i].other)
          -- end
          --s:moveTo(actualX, actualY)
          --s:redraw()     
          s.moved = false
        end
        s.view_right = geom.lineSegment.new(s.x, s.y, s.x + 60 * cos(rad(s.direction-45)), s.y + 60 * sin(rad(s.direction-45)))
        s.view_left = geom.lineSegment.new(s.x, s.y, s.x - 60 * cos(rad(s.direction+45)), s.y - 60 * sin(rad(s.direction+45)))
        s:raytrace()
        --s:tileSelect(s.direction)
        
    end
    
    function s:raytrace()
        rays = {}
        draw_these = {}
        -- trace rays
        for i = 0, 6 do
            local ray_direction = s.direction -45 + 15 * i
            local ray_end_x = s.x + 60 * sin(rad(ray_direction))
            local ray_end_y = s.y - 60 * cos(rad(ray_direction))
            rays[#rays + 1]= geom.lineSegment.new(s.x, s.y, ray_end_x, ray_end_y)
            --gfx.drawLine(rays[#rays])
            ray_hits = gfx.sprite.querySpritesAlongLine(rays[#rays])
            for i = 1, #ray_hits do
                ray_hits[i].inview = true
            end
        end
        for i = 1, #wall_sprites do
            if wall_sprites[i].inview then
                draw_these[#draw_these + 1] = wall_sprites[i]
            end
        end
        -- printTable(draw_these)
    end
    
    function s:tileSelect(angle)
      local view_tiles = {}
      draw_these = {}
      
      if angle >= 337.5 or angle < 22.5 then
        -- heading north
        view_tiles = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 19, 20, 24, 25, 26}
      elseif angle >= 22.5 and angle < 67.5 then
        -- heading north east
      elseif angle >= 67.5 and angle < 112.5 then
        -- heading east
      elseif angle >= 112.5 and angle < 155.5 then
        -- heading south east
      elseif angle >= 155.5 and angle < 202.5 then
        -- heading south
      elseif angle >= 202.5 and angle < 247.5 then
        -- heading south
      elseif angle >= 247.5 and angle < 292.5 then
        -- heading south
      elseif angle >= 292.5 and angle < 338.5 then
        -- heading south
      end
      
      n_view_tiles = #view_tiles
      for tile = 1, n_view_tiles do
        if wall_sprites[view_tiles[tile]].wall then
          wall_sprites[view_tiles[tile]].inview = true
          draw_these[#draw_these + 1] = wall_sprites[view_tiles[tile]]
        end
      end
      
      local view_tiles = nil
    end
        
    function s:redraw()
        -- local image = gfx.image.new(160, 160)
        -- gfx.lockFocus(image)
        -- gfx.fillCircleAtPoint(80, 80, 3)
        -- gfx.setColor(gfx.kColorWhite)
        -- gfx.fillCircleAtPoint(80, 80, 2)
        -- local view_left_x, view_left_y = 80 - 80 * cos(rad(s.direction+45)), 80 - 80 * sin(rad(s.direction+45))
        -- local view_right_x, view_right_y = 80 - 80 * cos(rad(s.direction+135)), 80 - 80 * sin(rad(s.direction+135))
        -- gfx.setLineWidth(3)
        -- gfx.drawLine(80, 80, view_left_x, view_left_y)
        -- gfx.drawLine(80, 80, view_right_x, view_right_y)
        -- gfx.setColor(gfx.kColorBlack)
        -- gfx.setLineWidth(1)
        -- gfx.drawLine(80, 80, view_left_x, view_left_y)
        -- gfx.drawLine(80, 80, view_right_x, view_right_y)
        -- gfx.unlockFocus()
        -- s:setImage(image)
    end
    
    s:add()
    s:moveTo(x_pos, y_pos)
    return s
    
end

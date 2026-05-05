local graphics = {}
local tau = math.pi * 2
local center_x = 64
local center_y = 32

graphics.visual_level = function(world, max_level)
  local min_level = 0
  return math.floor(util.linlin(0,1,min_level,max_level,level[world]))
end

graphics.screen_x = function(x)
  return util.clamp(math.floor(x),0,127)
end

graphics.screen_y = function(y)
  return util.clamp(math.floor(y),0,63)
end

graphics.draw_landscape = function(current_world)
  if current_world == 1 then
    graphics.draw_grid_world()
    return
  elseif current_world == 2 then
    graphics.draw_sine_world()
    return
  elseif current_world == 3 then
    graphics.draw_ripple_world()
    return
  elseif current_world == 6 then
    graphics.draw_graph_world()
    return
  end

  local world_events = events[current_world]
  for index,event in pairs(world_events) do
    if current_world == 4 then
      graphics.draw_warp_star(event)
    elseif current_world == 5 then
      if event.seed < probs[5] then
        graphics.draw_falling_dot(event)
      end
    end
  end
end

graphics.rotated_screen_point = function(x,y,cos_angle,sin_angle)
  return center_x + (x * cos_angle) - (y * sin_angle),
    center_y + (x * sin_angle) + (y * cos_angle)
end

graphics.draw_rotated_square = function(x,y,size,cos_angle,sin_angle)
  local half_size = size * 0.42
  local x1,y1 = graphics.rotated_screen_point(x - half_size,y - half_size,cos_angle,sin_angle)
  local x2,y2 = graphics.rotated_screen_point(x + half_size,y - half_size,cos_angle,sin_angle)
  local x3,y3 = graphics.rotated_screen_point(x + half_size,y + half_size,cos_angle,sin_angle)
  local x4,y4 = graphics.rotated_screen_point(x - half_size,y + half_size,cos_angle,sin_angle)

  screen.move(graphics.screen_x(x1),graphics.screen_y(y1))
  screen.line_rel(graphics.screen_x(x2) - graphics.screen_x(x1),graphics.screen_y(y2) - graphics.screen_y(y1))
  screen.line_rel(graphics.screen_x(x3) - graphics.screen_x(x2),graphics.screen_y(y3) - graphics.screen_y(y2))
  screen.line_rel(graphics.screen_x(x4) - graphics.screen_x(x3),graphics.screen_y(y4) - graphics.screen_y(y3))
  screen.close()
  screen.fill()
end

graphics.draw_grid_world = function()
  if not grid_blink_on then
    return
  end

  local square_level = graphics.visual_level(1,16)
  if square_level <= 0 then
    return
  end

  local angle = util.linlin(0,1,-0.75,0.75,brightnesses[1])
  local cos_angle = math.cos(angle)
  local sin_angle = math.sin(angle)

  screen.line_width(1)
  screen.level(square_level)
  for i,event in pairs(events[1]) do
    if event.seed < probs[1] then
      graphics.draw_rotated_square(event.x,event.y,event.size,cos_angle,sin_angle)
    end
  end
end

graphics.draw_sine_world = function()
  local amplitude = util.linlin(0,1,0,29,level[2])
  local cycles = util.linlin(0,0.9,0.5,8,probs[2])
  local phase = util.linlin(0,1,0,tau,brightnesses[2])
  local last_x = 0
  local last_y = graphics.screen_y(center_y + (math.sin(phase) * amplitude))

  screen.line_width(1)
  screen.level(16)
  screen.move(last_x,last_y)
  for x=1,127 do
    local t = x / 127
    local y = graphics.screen_y(center_y + (math.sin((t * tau * cycles) + phase) * amplitude))
    screen.line_rel(x - last_x,y - last_y)
    last_x = x
    last_y = y
  end
  screen.stroke()
end

graphics.draw_ripple_world = function()
  local ripple_level = graphics.visual_level(3,16)
  if ripple_level <= 0 then
    return
  end

  local max_radius = util.linlin(0,1,10,34,brightnesses[3])

  screen.line_width(1)
  for i,event in pairs(events[3]) do
    if event.seed < probs[3] then
      local radius = 2 + (event.phase * max_radius)
      local fade = util.clamp(1 - (event.phase * 0.75),0,1)
      screen.level(math.floor(ripple_level * fade))
      screen.circle(graphics.screen_x(event.x),graphics.screen_y(event.y),radius)
      screen.stroke()
    end
  end
end

graphics.draw_warp_star = function(event)
  local center_x = 64
  local center_y = 32
  local depth = util.clamp(event.z,1,100)
  local x = center_x + (event.x / depth) * 64
  local y = center_y + (event.y / depth) * 64
  local previous_depth = depth + util.linlin(0,1,8,22,brightnesses[4])
  local px = center_x + (event.x / previous_depth) * 64
  local py = center_y + (event.y / previous_depth) * 64

  if x < 0 or x > 128 or y < 0 or y > 64 then
    return
  end

  screen.line_width(1)
  screen.level(math.floor(util.linlin(1,100,16,2,depth)))
  local sx = graphics.screen_x(x)
  local sy = graphics.screen_y(y)
  screen.move(graphics.screen_x(px),graphics.screen_y(py))
  screen.line_rel(sx - graphics.screen_x(px),sy - graphics.screen_y(py))
  screen.stroke()
  screen.pixel(sx,sy)
  screen.fill()
end

graphics.draw_falling_dot = function(event)
  screen.line_width(1)
  screen.level(graphics.visual_level(5,16))

  local x = graphics.screen_x(event.x)
  local y = graphics.screen_y(event.y)
  local trail_top = graphics.screen_y(event.y - 6)
  local trail_bottom = graphics.screen_y(event.y - 1)
  screen.move(x,trail_top)
  screen.line_rel(0,trail_bottom - trail_top)
  screen.stroke()
  screen.circle(x,y,math.floor(event.radius))
  screen.fill()
end

graphics.draw_graph_world = function()
  local world_events = events[6]

  screen.line_width(1)
  screen.level(graphics.visual_level(6,5))
  for i=1,#world_events do
    local current = world_events[i]
    local next_node = world_events[(i % #world_events) + 1]
    if next_node ~= nil then
      local x = graphics.screen_x(current.x)
      local y = graphics.screen_y(current.y)
      local next_x = graphics.screen_x(next_node.x)
      local next_y = graphics.screen_y(next_node.y)
      screen.move(x,y)
      screen.line_rel(next_x - x,next_y - y)
      screen.stroke()
    end
  end

  for i,event in pairs(world_events) do
    local node_level = 4
    if event.seed < probs[6] then
      node_level = 16
    end

    screen.level(graphics.visual_level(6,node_level))
    local x = graphics.screen_x(event.x)
    local y = graphics.screen_y(event.y)
    screen.circle(x,y,2)
    screen.fill()

    if event.phase < 0.18 then
      screen.level(graphics.visual_level(6,16))
      screen.circle(x,y,math.floor(4 + (event.phase * 18)))
      screen.stroke()
    end
  end
end

return graphics

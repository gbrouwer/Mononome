local graphics = {}

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

graphics.draw_horizon = function(world)
  local horizon_colors = {3,2,1,1,1,1}
  screen.line_width(1)
  screen.move(0,horizon_height)
  screen.line_rel(128,0)
  screen.close()
  screen.stroke()
  screen.rect(0,horizon_height,128,44)
  screen.level(horizon_colors[world])
  screen.fill()
end

graphics.draw_stars = function()
  screen.line_width(1)
  screen.level(math.floor(16.0 * level[current_world]))
  for i = 1,#world_stars[current_world] do
    star = world_stars[current_world][i]
    screen.pixel(star.x,star.y)
    screen.fill()
  end
end

graphics.draw_sun = function(current_world)
  _x = math.floor(128 - (64*brightnesses[current_world]))
  _y = math.floor((horizon_height-20) + (16.0-(16*brightnesses[current_world])))
  screen.move(_x,_y)
  
  if current_world == 1 then
    -- sun
    screen.circle(_x, _y, 10)
    screen.level(math.floor(16.0 * brightnesses[current_world]))
    screen.fill()
  elseif current_world == 2 then
    _x = _x + 16
    _y = _y + 8
    -- rings
    screen.move(_x-12, _y)
    screen.level(16)
    screen.curve_rel(-8,4,0,16,24,0)
    screen.stroke()
    -- planet
    screen.circle(_x, _y, 10)
    screen.level(math.floor(16.0 * brightnesses[current_world] / 2))
    screen.fill()
    screen.level(16)
    screen.move(_x+12, _y)
    screen.curve_rel(8,-4,0,-16,-24,0)
    screen.stroke()
    -- moons
    _x = _x -24
    _y = _y -4
    screen.circle(_x, _y, 2)
    screen.level(math.floor(16.0 * brightnesses[current_world]))
    screen.fill()
    _x = _x -30
    _y = _y + 4
    screen.circle(_x, _y, 3)
    screen.level(math.floor(16.0 * brightnesses[current_world]))
    screen.fill()
  elseif current_world == 3 then
    -- moon
    _x = _x + 12
    screen.circle(_x, _y, 10)
    screen.level(math.floor(16.0 * brightnesses[current_world]))
    screen.fill()
    screen.circle(_x-4, _y-4, 10)
    screen.level(0)
    screen.fill()
  end
end

graphics.draw_landscape = function(current_world)
  if current_world == 6 then
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
    elseif event.seed < probs[current_world] then
      graphics.draw_world_item(current_world, event.x, event.y)
    end
  end
end

graphics.draw_world_item = function(world,x,y)
  if world == 1 then
    graphics.draw_pole(x,y)
  elseif world == 2 then
    graphics.draw_pyramid(x,y)
  elseif world == 3 then
    graphics.draw_cactus(x,y)
  end
end
    
graphics.draw_pole = function(x,y)
  screen.line_width(1)
  pole_height = 12 
  screen.move(x,y)
  screen.level(16)
  screen.line_rel(0,0-pole_height)
  screen.line_rel(-4,2)
  screen.line_rel(4,-2)
  screen.line_rel(4,-2)
  screen.stroke()
end

graphics.draw_pyramid = function(x,y)
  screen.line_width(1)
  pwidth = 12 
  pheight = 8 
  screen.move(x,y)
  screen.level(16)
  screen.line_rel(-pwidth/2, 0)
  screen.line_rel(pwidth, 0)
  screen.line_rel(-pwidth/2, 0-pheight)
  screen.line_rel(-pwidth/2, pheight)
  screen.line_rel(pwidth,0)
  screen.line_rel(2,-4)
  screen.line_rel(-2-(pwidth/2),4-pheight)
  screen.stroke()
end

graphics.draw_cactus = function(x,y)
  cactus_height =12 
  screen.line_width(3)
  screen.line_cap("round")
  screen.level(11) 
  screen.move(x,y)
  screen.line_rel(0,-cactus_height)
  screen.line_rel(0,math.floor(cactus_height/3))
  screen.line_rel(4,-1)
  screen.line_rel(0,-6)
  screen.line_rel(0,6)
  screen.line_rel(-4,1)
  screen.line_rel(-4,1)
  screen.line_rel(0,-8)
  screen.stroke()
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

graphics.init_all_stars = function()
-- initialize events
  for world=1,world_count do
    world_stars[world] = {}
    graphics.init_stars(world)
  end
end

graphics.init_stars = function(world)
  for i=1,10 do
    star = {}
    star.x = math.floor(math.random() * 128)
    star.y = math.floor(math.random() * horizon_height)
    world_stars[world][i] = star
  end
end

return graphics

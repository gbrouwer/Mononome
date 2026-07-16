local graphics = {}
local center_x = 64
local center_y = 32

graphics.visual_level = function(world, max_level)
  local min_level = math.min(2,max_level)
  return math.floor(util.linlin(0,1,min_level,max_level,level[world]))
end

graphics.screen_x = function(x)
  return util.clamp(math.floor(x),0,127)
end

graphics.screen_y = function(y)
  return util.clamp(math.floor(y),0,63)
end

graphics.draw_landscape = function(world)
  if world == 1 then
    graphics.draw_cathedral()
  elseif world == 2 then
    graphics.draw_mandala()
  elseif world == 3 then
    graphics.draw_liquid_light()
  elseif world == 4 then
    graphics.draw_light_city()
  elseif world == 5 then
    graphics.draw_portal()
  elseif world == 6 then
    graphics.draw_swarm_lattice()
  end
end

graphics.line = function(x1,y1,x2,y2)
  screen.move(graphics.screen_x(x1),graphics.screen_y(y1))
  screen.line(graphics.screen_x(x2),graphics.screen_y(y2))
  screen.stroke()
end

graphics.draw_polygon = function(cx,cy,r,sides,angle,close_shape)
  local first_x = nil
  local first_y = nil
  local last_x = nil
  local last_y = nil

  for i=1,sides do
    local a = angle + ((i - 1) / sides) * tau
    local x = cx + (math.cos(a) * r)
    local y = cy + (math.sin(a) * r)
    if i == 1 then
      first_x = x
      first_y = y
      screen.move(graphics.screen_x(x),graphics.screen_y(y))
    else
      screen.line(graphics.screen_x(x),graphics.screen_y(y))
    end
    last_x = x
    last_y = y
  end

  if close_shape and first_x ~= nil then
    screen.line(graphics.screen_x(first_x),graphics.screen_y(first_y))
  end
  screen.stroke()
  return first_x, first_y, last_x, last_y
end

graphics.draw_cathedral = function()
  local world = 1
  local pulse = math.sin(world_phase * tau)
  local vault_shift = util.linlin(-1,1,-8,8,pulse) * brightnesses[world]
  local frame_count = 7

  screen.line_width(1)
  for i=frame_count,1,-1 do
    local t = i / frame_count
    local top = util.linlin(0,1,8,28,t)
    local bottom = util.linlin(0,1,62,45,t)
    local half = util.linlin(0,1,60,9,t)
    local x1 = center_x - half + (vault_shift * t)
    local x2 = center_x + half + (vault_shift * t)
    local lvl = math.floor(util.linlin(0,1,2,graphics.visual_level(world,14),1 - t))

    screen.level(lvl)
    graphics.line(x1,bottom,x1,top + 8)
    graphics.line(x2,bottom,x2,top + 8)
    screen.move(graphics.screen_x(x1),graphics.screen_y(top + 8))
    screen.curve(graphics.screen_x(x1 + half * 0.25),graphics.screen_y(top - 6),graphics.screen_x(x2 - half * 0.25),graphics.screen_y(top - 6),graphics.screen_x(x2),graphics.screen_y(top + 8))
    screen.stroke()
  end

  for i,event in ipairs(events[world]) do
    local depth = event.phase
    local base_y = util.linlin(0,1,62,18,depth)
    local top_y = util.linlin(0,1,36,7,depth)
    local x = center_x + (event.side * util.linlin(0,1,56,8,depth)) + event.offset * depth
    local active = event.seed < probs[world]
    local lvl = active and graphics.visual_level(world,16) or graphics.visual_level(world,5)

    screen.level(lvl)
    graphics.line(x,base_y,x,top_y)
    if active then
      screen.circle(graphics.screen_x(x),graphics.screen_y(top_y),math.floor(2 + (1 - depth) * 4))
      screen.stroke()
    end
  end
end

graphics.draw_mandala = function()
  local world = 2
  local symmetry = 8
  local bloom = util.linlin(0,1,0.5,1.4,brightnesses[world])

  screen.line_width(1)
  screen.level(graphics.visual_level(world,5))
  for r=8,30,7 do
    screen.circle(center_x,center_y,r + (math.sin(world_phase * tau + r) * 2))
    screen.stroke()
  end

  for i,event in ipairs(events[world]) do
    local petal_phase = math.sin(event.phase * tau)
    local radius = event.radius * bloom + (petal_phase * 7)
    local active = event.seed < probs[world]
    local lvl = active and graphics.visual_level(world,16) or graphics.visual_level(world,7)

    screen.level(lvl)
    for s=1,symmetry do
      local a = event.angle + ((s - 1) / symmetry) * tau
      local x = center_x + math.cos(a) * radius
      local y = center_y + math.sin(a) * radius
      local inner_x = center_x + math.cos(a) * (radius * 0.35)
      local inner_y = center_y + math.sin(a) * (radius * 0.35)
      local tangent = a + (math.pi / 2)

      screen.move(graphics.screen_x(inner_x),graphics.screen_y(inner_y))
      screen.line(graphics.screen_x(x),graphics.screen_y(y))
      screen.stroke()
      screen.circle(graphics.screen_x(x + math.cos(tangent) * 2),graphics.screen_y(y + math.sin(tangent) * 2),active and 2 or 1)
      if active then
        screen.fill()
      else
        screen.stroke()
      end
    end
  end
end

graphics.draw_liquid_light = function()
  local world = 3
  local energy = util.linlin(0,1,0.4,2.4,brightnesses[world])

  screen.line_width(1)
  for i,event in ipairs(events[world]) do
    local active = event.seed < probs[world]
    local lvl = active and graphics.visual_level(world,16) or graphics.visual_level(world,6)
    local y0 = event.y
    local last_x = 0
    local last_y = graphics.screen_y(y0)

    screen.level(lvl)
    screen.move(last_x,last_y)
    for x=1,127 do
      local t = x / 127
      local wave1 = math.sin((t * tau * event.freq) + (event.phase * tau))
      local wave2 = math.sin((t * tau * (event.freq * 0.47)) - (world_phase * tau * energy))
      local y = y0 + (wave1 * event.amp * level[world]) + (wave2 * 4 * brightnesses[world])
      local sy = graphics.screen_y(y)
      screen.line_rel(x - last_x,sy - last_y)
      last_x = x
      last_y = sy
    end
    screen.stroke()
  end

  screen.level(graphics.visual_level(world,8))
  for x=0,127,8 do
    local y = center_y + math.sin((x / 127) * tau * 2 + world_phase * tau) * 24 * level[world]
    screen.pixel(x,graphics.screen_y(y))
    screen.fill()
  end
end

graphics.draw_light_city = function()
  local world = 4
  local scan_x = (world_phase * 160) - 16

  screen.line_width(1)
  screen.level(graphics.visual_level(world,3))
  graphics.line(0,60,127,60)

  for i,event in ipairs(events[world]) do
    local active = event.seed < probs[world]
    local h = event.h * util.linlin(0,1,0.6,1.2,level[world])
    local x = event.x
    local y = 60 - h
    local lvl = active and graphics.visual_level(world,16) or graphics.visual_level(world,7)

    screen.level(lvl)
    screen.rect(graphics.screen_x(x),graphics.screen_y(y),math.floor(event.w),math.floor(h))
    if active then
      screen.fill()
    else
      screen.stroke()
    end

    screen.level(active and 0 or graphics.visual_level(world,3))
    for wy=y + 3,58,5 do
      for wx=x + 1,x + event.w - 2,3 do
        if ((math.floor(wx + wy + event.phase * 10) % 3) == 0) then
          screen.pixel(graphics.screen_x(wx),graphics.screen_y(wy))
          screen.fill()
        end
      end
    end
  end

  screen.level(graphics.visual_level(world,16))
  graphics.line(scan_x,8,scan_x + 18,60)
  graphics.line(scan_x + 5,8,scan_x + 23,60)
end

graphics.draw_portal = function()
  local world = 5
  local breath = math.sin(world_phase * tau)

  screen.line_width(1)
  for i,event in ipairs(events[world]) do
    local active = event.seed < probs[world]
    local lvl = active and graphics.visual_level(world,16) or graphics.visual_level(world,6)
    local r = event.radius + breath * 3 * brightnesses[world]

    screen.level(lvl)
    graphics.draw_polygon(center_x,center_y,r,event.sides,event.angle + event.phase * tau,true)
    if active then
      local x = center_x + math.cos(event.angle) * r
      local y = center_y + math.sin(event.angle) * r
      graphics.line(center_x,center_y,x,y)
    end
  end

  screen.level(graphics.visual_level(world,15))
  for i=1,8 do
    local a = world_phase * tau + (i / 8) * tau
    local inner = 6
    local outer = 38
    graphics.line(
      center_x + math.cos(a) * inner,
      center_y + math.sin(a) * inner,
      center_x + math.cos(a) * outer,
      center_y + math.sin(a) * outer
    )
  end
end

graphics.draw_swarm_lattice = function()
  local world = 6
  local world_events = events[world]
  local max_dist = util.linlin(0,1,16,38,brightnesses[world])

  screen.line_width(1)
  for i=1,#world_events do
    local a = world_events[i]
    for j=i+1,#world_events do
      local b = world_events[j]
      local dx = a.x - b.x
      local dy = a.y - b.y
      local d = math.sqrt(dx * dx + dy * dy)
      if d < max_dist then
        local lvl = math.floor(util.linlin(0,max_dist,graphics.visual_level(world,10),1,d))
        screen.level(lvl)
        graphics.line(a.x,a.y,b.x,b.y)
      end
    end
  end

  for i,event in ipairs(world_events) do
    local active = event.seed < probs[world]
    screen.level(active and graphics.visual_level(world,16) or graphics.visual_level(world,7))
    screen.circle(graphics.screen_x(event.x),graphics.screen_y(event.y),active and 3 or 2)
    if active then
      screen.fill()
    else
      screen.stroke()
    end

    if event.phase < 0.22 then
      screen.level(graphics.visual_level(world,14))
      screen.circle(graphics.screen_x(event.x),graphics.screen_y(event.y),math.floor(4 + event.phase * 20))
      screen.stroke()
    end
  end
end

return graphics

-- Decipher
-- Gijs Joost Brouwer
--
-- Based on Ethereal
--
-- E1 volume
-- E2 brightness
-- E3 density
-- K2 evolve
-- K3 change worlds

local utils = include('lib/decipher/utils')
local graphics = include('lib/decipher/graphics')

sc = softcut -- typing shortcut

-- graphics things
world_count = 6
horizon_height = 28
world_stars = {}

-- sound things
current_world = 1
level = {1,0,0,0,0,0}
pulse_durations = {3.5,4,4,3.5,4,3}

brightnesses = {1,1,1,1,1,1}
probs = {0.2,0.2,0.2,0.2,0.2,0.2} -- probabilities per world

start_points = {0,11,0,31,20,42}
loop_points = {0,11,0,31,20,42}
buffer_indexes = {1,1,2,1,2,1}
loop_ranges = {
  {0,6},
  {11,26},
  {0,15},
  {31,37},
  {20,32},
  {42,46.5}
}
world_clock_rates = {(1.0/40),(1.0/30),(1.0/20),(1.0/50),(1.0/35),(1.0/24)}

events = {} -- ie, things in the landscape.

function init_all_events()
  for world=1,world_count do
    events[world] = {}
    init_world_events(world)
  end
end

function init_world_events(world)
  for step = 1,16 do
    event = {}

    if world == 4 then
      event.x = utils.random_between(-96,96)
      event.y = utils.random_between(-48,48)
      event.z = utils.random_between(6,60)
    elseif world == 5 then
      event.x = utils.random_between(0,128)
      event.y = utils.random_between(-64,64)
      event.radius = utils.random_between(1,3)
    elseif world == 6 then
      event.x = utils.random_between(8,120)
      event.y = utils.random_between(10,58)
      event.phase = step / 16
    else
      event.x = (step-1) * 16
      event.y = utils.random_between(horizon_height+5,64)
    end

    event.seed = math.random()
    events[world][step] = event
  end
end

function init()
  init_all_events()
  graphics.init_all_stars()
  file1 = _path.code .. "decipher/lib/dce_100_kit_loop_longjump_sfx_2_Dsharpmin.wav"
  file2 = _path.code .. "decipher/lib/dce_100_kit_loop_longjump_pad_2_Dsharpmin.wav"
  file3 = _path.code .. "decipher/lib/dce_100_kit_loop_longjump_lead_2_Dsharpmin.wav"
  file4 = _path.code .. "decipher/lib/dce_100_kit_loop_longjump_bass_1_Dsharpmin.wav"
  file5 = _path.code .. "decipher/lib/dce_120_synth_loop_arp_exist_Dsharpmin.wav"
  file6 = _path.code .. "decipher/lib/dce_synth_one_shot_pulsar_Dsharpmin.wav"

  sc.buffer_clear()
  sc.buffer_read_mono(file1,0,0,-1,1,1)
  sc.buffer_read_mono(file2,0,11,-1,1,1)
  sc.buffer_read_mono(file4,0,31,-1,1,1)
  sc.buffer_read_mono(file6,0,42,-1,1,1)
  sc.buffer_read_mono(file3,0,0,-1,1,2)
  sc.buffer_read_mono(file5,0,20,-1,1,2)

  for i=1,world_count do
    sc.enable(i,1)
    sc.buffer(i,buffer_indexes[i])

    sc.level(i,level[i])

    sc.loop(i,0)
    sc.rate(i,1.0)
    sc.play(i,0)

    sc.post_filter_dry(i,0)
    sc.post_filter_lp(i,1)
    sc.post_filter_hp(i,0)
    sc.post_filter_bp(i,0)
    sc.post_filter_br(i,0)
    sc.post_filter_rq(i,0.6)

    freq = util.linexp(0, 1, 60, 12000, brightnesses[i])
    sc.post_filter_fc(i,freq)

    sc.loop_start(i,start_points[i])
    sc.loop_end(i,start_points[i]+pulse_durations[i])
    sc.position(i,start_points[i])

  end

  animation_clock = metro.init(tick, (1.0/60), -1)
  animation_clock:start()

  world_clocks = {}
  for i=1,world_count do
    local world = i
    world_clocks[i] = metro.init(function() world_tick(world) end, world_clock_rates[i], -1)
    world_clocks[i]:start()
  end
end

function tick(stage)
  redraw(stage)
end

function trigger_world(world)
  if events[world] == nil then
    return
  end
  sc.position(world, loop_points[world])
  sc.play(world,1)
end

function world_tick(world)
  world_events = events[world]
  if world_events == nil then
    return
  end

  for i = 1,#world_events do
    e = world_events[i]
    if world == 4 then
      e.z = e.z - util.linlin(0,1,0.6,2.8,brightnesses[world])
      if e.z < 1 then
        e.x = utils.random_between(-96,96)
        e.y = utils.random_between(-48,48)
        e.z = utils.random_between(45,70)
        e.seed = math.random()
        if e.seed < probs[world] then
          trigger_world(world)
        end
      end
    elseif world == 5 then
      e.y = e.y + util.linlin(0,1,0.5,2.2,brightnesses[world])
      if e.y > 64 then
        e.x = utils.random_between(0,128)
        e.y = utils.random_between(-40,0)
        e.radius = utils.random_between(1,3)
        e.seed = math.random()
        if e.seed < probs[world] then
          trigger_world(world)
        end
      end
    elseif world == 6 then
      e.phase = e.phase + util.linlin(0,1,0.008,0.04,brightnesses[world])
      if e.phase > 1 then
        e.phase = e.phase - 1
        e.seed = math.random()
        if e.seed < probs[world] then
          trigger_world(world)
        end
      end
    else
      e.x = e.x - util.linlin(horizon_height+5,64,0.5,1.5,e.y)
      if e.x < 0 then
        e.x = 128
        e.seed = math.random()
        if e.seed < probs[world] then
          trigger_world(world)
        end
      end
    end
  end
end

function enc(n,d)
  if n==1 then
    level[current_world] = util.clamp(level[current_world] + d/100,0,1)
    sc.level(current_world, level[current_world])
  elseif n==2 then
    brightnesses[current_world] = util.clamp(brightnesses[current_world] + d/100,0,1)
    freq = util.linexp(0, 1, 60, 6000, brightnesses[current_world])
    sc.post_filter_fc(current_world,freq)
  elseif n==3 then
    -- adjust world probablity
    prob = probs[current_world] + d/100.0
    probs[current_world] = util.clamp(prob,0,0.9)
  end
end

function key(n,z)
  if n==3 and z==1 then
    current_world = current_world % world_count + 1
  elseif n==2 and z==1 then
    init_world_events(current_world)
    pick_new_loop(current_world)
  end
end

function pick_new_loop(world)
  local range = loop_ranges[world]
  local new_start = utils.random_between(range[1], range[2])

  loop_points[world] = new_start
  sc.loop_start(world, new_start)
  sc.loop_end(world, new_start+pulse_durations[world])
  sc.position(world, new_start)
end

function redraw(stage)
  screen.clear()
  screen.line_width(1)
  screen.line_cap("butt")
  screen.level(16)
  screen.move(0,5)
  screen.aa(1)
  if current_world <= 3 then
    graphics.draw_stars()
    graphics.draw_sun(current_world)
    graphics.draw_horizon(current_world)
  end
  graphics.draw_landscape(current_world)
  screen.level(16)
  screen.move(0,5)
  screen.text(current_world)
  screen.update()
end

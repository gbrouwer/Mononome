-- Ethereum transport
-- Gijs Joost Brouwer
--
-- Based on Ethereal
--
-- E1 volume
-- E2 division
-- E3 density
-- K1 start/stop
-- K2 evolve
-- K3 change worlds

local utils = include('lib/ethereum/utils')
local graphics = include('lib/ethereum/graphics')

sc = softcut -- typing shortcut

-- Link / transport state. Starts stopped; Ableton Link start will enable playback.
running = false

-- graphics things
world_count = 6
world_tick_counts = {}
world_phase = 0
tau = math.pi * 2

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
  {0,4.5},
  {11,15},
  {0,4},
  {31,35.5},
  {20,24},
  {42,46.5}
}
world_clock_rates = {(1.0/40),(1.0/30),(1.0/20),(1.0/50),(1.0/35),(1.0/24)}
division_names = {
  "1/32","1/16T","1/16","1/8T","1/8","1/4T","3/16","1/4",
  "1/2T","3/8","1/2","5/8","3/4","7/8","1 bar","5/4",
  "3/2","7/4","2 bars","3 bars","4 bars","8 bars"
}
division_values = {
  1/8,1/6,1/4,1/3,1/2,2/3,3/4,1,
  4/3,3/2,2,5/2,3,7/2,4,5,
  6,7,8,12,16,32
}
division_defaults = {8,5,3,8,11,5}

events = {}
pending_triggers = {}

function add_params()
  params:add_separator("ethereum_timing", "ethereum timing")
  for world=1,world_count do
    params:add_option(
      "world_"..world.."_division",
      "world "..world.." div",
      division_names,
      division_defaults[world]
    )
  end
end

function get_world_division(world)
  local index = params:get("world_"..world.."_division")
  return division_values[index] or division_values[division_defaults[world]]
end

function get_world_division_name(world)
  local index = params:get("world_"..world.."_division")
  return division_names[index] or division_names[division_defaults[world]]
end

function init_all_events()
  for world=1,world_count do
    init_world_events(world)
  end
end

function init_world_events(world)
  events[world] = {}
  world_tick_counts[world] = 0

  if world == 1 then
    -- Cathedral: receding vault frames and vertical light pillars.
    for i=1,16 do
      events[world][i] = {
        phase = i / 16,
        speed = utils.random_between(0.006,0.018),
        side = (i % 2 == 0) and -1 or 1,
        offset = utils.random_between(-18,18),
        seed = math.random()
      }
    end
  elseif world == 2 then
    -- Mandala: rotational symmetry with petals that bloom and fold.
    for i=1,24 do
      events[world][i] = {
        angle = (i / 24) * tau,
        radius = utils.random_between(7,31),
        spin = utils.random_between(-0.025,0.025),
        phase = math.random(),
        seed = math.random()
      }
    end
  elseif world == 3 then
    -- Liquid light: contour bands and sparks over a slow moving field.
    for i=1,12 do
      events[world][i] = {
        y = 8 + (i * 4.4),
        phase = math.random(),
        amp = utils.random_between(3,13),
        freq = utils.random_between(1.0,4.0),
        seed = math.random()
      }
    end
  elseif world == 4 then
    -- Light city: towers, windows, and a scanning stage beam.
    local x = 0
    local i = 1
    while x < 128 do
      local w = math.random(4,9)
      events[world][i] = {
        x = x,
        w = w,
        h = utils.random_between(10,54),
        phase = math.random(),
        seed = math.random()
      }
      x = x + w + math.random(1,3)
      i = i + 1
    end
  elseif world == 5 then
    -- Portal: nested spinning gates and streaks flying through them.
    for i=1,20 do
      events[world][i] = {
        radius = utils.random_between(3,38),
        angle = (i / 20) * tau,
        spin = utils.random_between(-0.045,0.045),
        sides = math.random(3,8),
        phase = math.random(),
        seed = math.random()
      }
    end
  elseif world == 6 then
    -- Swarm lattice: drifting agents that form temporary constellations.
    for i=1,20 do
      events[world][i] = {
        x = utils.random_between(6,122),
        y = utils.random_between(8,58),
        vx = utils.random_between(-0.9,0.9),
        vy = utils.random_between(-0.7,0.7),
        phase = math.random(),
        seed = math.random()
      }
    end
  end
end

function reset_event(world, e)
  if world == 1 then
    e.phase = e.phase - 1
    e.offset = utils.random_between(-18,18)
    e.seed = math.random()
  elseif world == 2 then
    e.phase = e.phase - 1
    e.radius = utils.random_between(7,31)
    e.seed = math.random()
  elseif world == 3 then
    e.phase = e.phase - 1
    e.amp = utils.random_between(3,13)
    e.freq = utils.random_between(1.0,4.0)
    e.seed = math.random()
  elseif world == 4 then
    e.phase = e.phase - 1
    e.h = utils.random_between(10,54)
    e.seed = math.random()
  elseif world == 5 then
    e.phase = e.phase - 1
    e.radius = utils.random_between(3,38)
    e.sides = math.random(3,8)
    e.seed = math.random()
  elseif world == 6 then
    e.phase = e.phase - 1
    e.seed = math.random()
  end
end

function maybe_trigger(world, e)
  if e.seed < probs[world] then
    pending_triggers[world] = true
  end
end

function tick_event(world, e)
  local energy = util.linlin(0,1,0.6,2.6,brightnesses[world])

  if world == 1 then
    e.phase = e.phase + (e.speed * energy)
    if e.phase > 1 then
      reset_event(world, e)
      maybe_trigger(world, e)
    end
  elseif world == 2 then
    e.angle = e.angle + (e.spin * energy)
    e.phase = e.phase + (0.008 * energy)
    if e.phase > 1 then
      reset_event(world, e)
      maybe_trigger(world, e)
    end
  elseif world == 3 then
    e.phase = e.phase + (0.006 * energy)
    if e.phase > 1 then
      reset_event(world, e)
      maybe_trigger(world, e)
    end
  elseif world == 4 then
    e.phase = e.phase + (0.012 * energy)
    if e.phase > 1 then
      reset_event(world, e)
      maybe_trigger(world, e)
    end
  elseif world == 5 then
    e.angle = e.angle + (e.spin * energy)
    e.phase = e.phase + (0.01 * energy)
    if e.phase > 1 then
      reset_event(world, e)
      maybe_trigger(world, e)
    end
  elseif world == 6 then
    e.x = e.x + (e.vx * energy)
    e.y = e.y + (e.vy * energy)
    e.phase = e.phase + (0.01 * energy)

    if e.x < 4 or e.x > 124 then
      e.vx = -e.vx
      e.seed = math.random()
      maybe_trigger(world, e)
    end
    if e.y < 7 or e.y > 60 then
      e.vy = -e.vy
      e.seed = math.random()
      maybe_trigger(world, e)
    end
    if e.phase > 1 then
      reset_event(world, e)
    end
  end
end

function stop_all_worlds()
  for i=1,world_count do
    sc.play(i,0)
  end
end

function clear_pending_triggers()
  for i=1,world_count do
    pending_triggers[i] = false
  end
end

function reset_transport()
  for i=1,world_count do
    sc.position(i, loop_points[i])
  end
  clear_pending_triggers()
end

function start_transport()
  reset_transport()
  running = true
end

function stop_transport()
  running = false
  stop_all_worlds()
  clear_pending_triggers()
end

function toggle_transport()
  if running then
    stop_transport()
  else
    start_transport()
  end
end

function clock.transport.start()
  start_transport()
end

function clock.transport.stop()
  stop_transport()
end

function clock.transport.reset()
  reset_transport()
end

function world_trigger_clock(world)
  while true do
    clock.sync(get_world_division(world))
    if running and pending_triggers[world] then
      pending_triggers[world] = false
      trigger_world(world)
    elseif not running then
      pending_triggers[world] = false
    end
  end
end

function init()
  add_params()
  init_all_events()
  file1 = _path.code .. "ethereum/lib/ethereum/Ethereum 1-Kontakt 8.wav"
  file2 = _path.code .. "ethereum/lib/ethereum/Ethereum 2-Kontakt 8.wav"
  file3 = _path.code .. "ethereum/lib/ethereum/Ethereum 3-Kontakt 8.wav"
  file4 = _path.code .. "ethereum/lib/ethereum/Ethereum 4-Kontakt 8.wav"
  file5 = _path.code .. "ethereum/lib/ethereum/Ethereum 5-Kontakt 8.wav"
  file6 = _path.code .. "ethereum/lib/ethereum/Ethereum 6-Analog Lab V.wav"

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

    local freq = util.linexp(0, 1, 60, 12000, brightnesses[i])
    sc.post_filter_fc(i,freq)

    sc.loop_start(i,start_points[i])
    sc.loop_end(i,start_points[i]+pulse_durations[i])
    sc.position(i,start_points[i])
  end

  stop_transport()

  animation_clock = metro.init(tick, (1.0/60), -1)
  animation_clock:start()

  world_clocks = {}
  for i=1,world_count do
    local world = i
    world_clocks[i] = metro.init(function() world_tick(world) end, world_clock_rates[i], -1)
    world_clocks[i]:start()
  end

  world_trigger_clocks = {}
  for i=1,world_count do
    world_trigger_clocks[i] = clock.run(world_trigger_clock, i)
  end
end

function tick(stage)
  world_phase = (world_phase + (1 / 60)) % 1
  redraw(stage)
end

function trigger_world(world)
  if not running then
    return
  end
  if events[world] == nil then
    return
  end
  sc.position(world, loop_points[world])
  sc.play(world,1)
end

function world_tick(world)
  if not running then
    return
  end
  world_tick_counts[world] = (world_tick_counts[world] or 0) + 1
  local world_events = events[world]
  if world_events == nil then
    return
  end

  for i = 1,#world_events do
    tick_event(world, world_events[i])
  end
end

function enc(n,d)
  if n==1 then
    level[current_world] = util.clamp(level[current_world] + d/100,0,1)
    sc.level(current_world, level[current_world])
  elseif n==2 then
    params:delta("world_"..current_world.."_division", d)
  elseif n==3 then
    local prob = probs[current_world] + d/100.0
    probs[current_world] = util.clamp(prob,0,0.9)
  end
end

function key(n,z)
  if n==1 and z==1 then
    toggle_transport()
  elseif n==3 and z==1 then
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
  graphics.draw_landscape(current_world)
  screen.level(16)
  screen.move(0,5)
  screen.text(current_world)
  screen.move(100,5)
  screen.text(running and "RUN" or "STOP")
  screen.level(10)
  screen.move(0,62)
  screen.text("div " .. get_world_division_name(current_world))
  screen.update()
end

function cleanup()
  stop_transport()
  if animation_clock ~= nil then
    animation_clock:stop()
  end
  if world_clocks ~= nil then
    for i=1,#world_clocks do
      world_clocks[i]:stop()
    end
  end
  if world_trigger_clocks ~= nil then
    for i=1,#world_trigger_clocks do
      clock.cancel(world_trigger_clocks[i])
    end
  end
end

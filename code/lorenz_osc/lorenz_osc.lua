-- lorenz_osc: chaotic attractor OSC MIDI generator
-- based on lorenz: crow study with chaotic attractor visualization
-- 
-- E1 adjust sigma/a
-- E2 adjust rho/b
-- E3 adjust beta/c
--
-- K1+E1 adjust simulation speed (dt)
-- K2+K3 cycle between 
-- Lorenz, Rössler, 
-- Sprott-Linz F, and 
-- Halvorsen attractors
--
-- K2+E3 adjust selected output attenuation (0-100%)
-- K2 switch selected output
-- K3 randomize parameters
--
-- K1 tap or Ableton Link start/stop: start/stop OSC MIDI
--
-- OUT1: x coordinate (-5V to 5V)
-- OUT2: y coordinate (-5V to 5V)
-- OUT3: z coordinate (-5V to 5V)
-- OUT4: distance from origin (0V to 5V)
--
-- Second crow (crow.ii) outputs:
-- OUT1: inverted x coordinate (5V to -5V)
-- OUT2: inverted y coordinate (5V to -5V)
-- OUT3: inverted z coordinate (5V to -5V)
-- OUT4: inverted distance (0V to -5V)

local MusicUtil = require "musicutil"

local options = {}
options.OUTPUT = {"osc", "crow", "osc + crow"}
options.OSC_TARGETS = {"Amma", "MakeMake"}
options.OSC_TARGET_IPS = {"192.168.178.220", "192.168.178.231"}
options.NOTE_SOURCES = {"x", "y", "z", "distance", "orbit"}
options.TRIGGER_MODES = {"clocked", "x crossing", "turning point", "distance"}
options.DIVISION_NAMES = {"1/16", "1/8", "1/4", "1/2", "1 bar", "2 bars", "4 bars"}
options.DIVISION_VALUES = {1/4, 1/2, 1, 2, 4, 8, 16}

local note_scale_names = {}
local note_scale = {}
local scale_note_log = ""

local x, y, z = 0.1, 0, 0
local initial_x, initial_y, initial_z = 0.1, 0, 0  -- Store initial conditions for reset
local dt = 0.005  -- Smaller time step for smoother simulation
local dt_min = 0.00001
local dt_max = 0.15

-- Lorenz parameters
local sigma = 10
local rho = 28
local beta = 8/3

-- Rössler parameters
local a = 0.2
local b = 0.2
local c = 5.7

-- Sprott-Linz F parameters
local sprott_a = 0.5

-- Halvorsen parameters
local halvorsen_a = 1.89

local scale = 1  -- Scale factor for visualization
local display_scale = 1  -- Display scale that changes per attractor
local points = {}
local max_points = 120  -- Increased for longer trails
local offset_x, offset_y = 64, 32  -- Center of the screen
local lorentz_metro
local key1_down = false
local key2_down = false
local current_attractor = "lorenz"  -- Can be "lorenz", "rossler", "sprott", or "halvorsen"
local out1_volts, out2_volts, out3_volts, out4_volts = 0, 0, 0, 0
local selected_output = 1  -- Track which output is currently selected
local output_attenuation = {1.0, 1.0, 1.0, 1.0}  -- Attenuation for each output (0.0-1.0)
local encoder_adjusted_during_k2 = false  -- Track if encoder was adjusted while K2 was held
local att_display_fade = 0  -- Fade timer for attenuation display (0-1)
local att_fade_metro  -- Metro for fading out attenuation display

-- Crow input values (continuously updated)
local crow1_input1 = 0  -- Store first crow input 1 value
local crow2_input1 = 0  -- Store second crow input 1 value
local crow2_input2 = 0  -- Store second crow input 2 value

-- Noise filtering for inputs
local filtered_inputs = {0, 0, 0}  -- Previous filtered values
local noise_threshold = 0.02  -- Deadband threshold (20mV)

-- Base parameter values (before offset)
local base_sigma = 10
local base_rho = 28
local base_beta = 8/3
local base_a = 0.2
local base_b = 0.2
local base_c = 5.7
local base_sprott_a = 0.5
local base_halvorsen_a = 1.89

local osc_running = false
local active_notes = {}
local last_sample = {x = x, y = y, z = z}
local last_x_sign = nil
local last_dx_sign = nil
local last_sent_note = nil
local key1_encoder_adjusted = false

local function crow_available()
  return type(crow) == "table" and type(crow.output) == "table"
end

local function follower_crow_available()
  return crow_available() and crow.ii and crow.ii.crow and crow.ii.crow[2]
end

local function uses_osc()
  if params.lookup["output"] == nil then return false end
  return params:get("output") == 1 or params:get("output") == 3
end

local function uses_crow()
  if params.lookup["output"] == nil then return false end
  return crow_available() and (params:get("output") == 2 or params:get("output") == 3)
end

local function set_osc_target(value)
  if params.lookup["osc_ip"] ~= nil then
    params:set("osc_ip", options.OSC_TARGET_IPS[value])
  end
end

local function osc_dest()
  return {params:get("osc_ip"), params:get("osc_port")}
end

local function build_note_scale()
  if params.lookup["scale_mode"] == nil or
     params.lookup["root_note"] == nil or
     params.lookup["octave_span"] == nil then
    return
  end

  local length = math.max(8, params:get("octave_span") * 8)
  note_scale = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), length)
  if note_scale == nil or #note_scale == 0 then
    note_scale = {params:get("root_note")}
  end

  local note_names = {}
  for i = 1, #note_scale do
    note_names[i] = MusicUtil.note_num_to_name(note_scale[i], true)
  end
  scale_note_log = table.concat(note_names, " ")
  print("lorenz_osc scale", params:string("root_note"), params:string("scale_mode"), scale_note_log)
end

local function nearest_scale_note(raw_note)
  if #note_scale == 0 then
    build_note_scale()
  end

  local best_note = params:get("root_note")
  local best_distance = 128
  for _, scale_note in ipairs(note_scale) do
    local distance = math.abs(scale_note - raw_note)
    if distance < best_distance then
      best_note = scale_note
      best_distance = distance
    end
  end
  return util.clamp(best_note, 0, 127)
end

local function beat_duration_ms(beats)
  local bpm = clock.get_tempo()
  return math.floor((60 / bpm) * beats * 1000)
end

local function atan2_safe(y_value, x_value)
  if math.atan2 then
    return math.atan2(y_value, x_value)
  end
  if x_value > 0 then
    return math.atan(y_value / x_value)
  elseif x_value < 0 and y_value >= 0 then
    return math.atan(y_value / x_value) + math.pi
  elseif x_value < 0 and y_value < 0 then
    return math.atan(y_value / x_value) - math.pi
  elseif x_value == 0 and y_value > 0 then
    return math.pi / 2
  elseif x_value == 0 and y_value < 0 then
    return -math.pi / 2
  end
  return 0
end

local function osc_note_off(note_num, force)
  if params.lookup["osc_ip"] == nil or
     params.lookup["osc_port"] == nil or
     params.lookup["osc_channel"] == nil then
    return
  end
  if not force and not uses_osc() then return end
  osc.send(osc_dest(), "/midi/note_off", {note_num, 0, params:get("osc_channel")})
end

local function all_notes_off()
  for note_num, _ in pairs(active_notes) do
    osc_note_off(note_num, true)
  end
  active_notes = {}
end

local function osc_note(note_num, velocity, duration_ms)
  if not uses_osc() then return end
  local channel = params:get("osc_channel")
  active_notes[note_num] = true
  osc.send(osc_dest(), "/midi/note", {note_num, velocity, channel, duration_ms})
  clock.run(function()
    clock.sleep((duration_ms + 50) / 1000)
    active_notes[note_num] = nil
  end)
end

local function reset_transport()
  all_notes_off()
  last_sample = {x = x, y = y, z = z}
  last_x_sign = x >= 0 and 1 or -1
  last_dx_sign = 0
  last_sent_note = nil
end

local function start_transport()
  reset_transport()
  osc_running = true
  redraw()
end

local function stop_transport()
  osc_running = false
  all_notes_off()
  redraw()
end

local function toggle_transport()
  if osc_running then
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
  redraw()
end

local function attractor_norms()
  local orbit = (atan2_safe(y, x) + math.pi) / (2 * math.pi)
  return {
    x = util.clamp((out1_volts + 5) / 10, 0, 1),
    y = util.clamp((out2_volts + 5) / 10, 0, 1),
    z = util.clamp((out3_volts + 5) / 10, 0, 1),
    distance = util.clamp(out4_volts / 5, 0, 1),
    orbit = util.clamp(orbit, 0, 1),
  }
end

local function should_emit_note(norms)
  local mode = params:get("trigger_mode")
  local dx = x - last_sample.x
  local x_sign = x >= 0 and 1 or -1
  local dx_sign = dx >= 0 and 1 or -1
  local emit = false

  if mode == 1 then
    emit = true
  elseif mode == 2 then
    emit = last_x_sign ~= nil and x_sign ~= last_x_sign
  elseif mode == 3 then
    emit = last_dx_sign ~= nil and last_dx_sign ~= 0 and dx_sign ~= last_dx_sign
  elseif mode == 4 then
    emit = norms.distance >= (params:get("activity_threshold") / 100)
  end

  last_x_sign = x_sign
  last_dx_sign = dx_sign
  return emit
end

local function attractor_note()
  if #note_scale == 0 then
    build_note_scale()
  end

  local norms = attractor_norms()
  if not should_emit_note(norms) then
    last_sample = {x = x, y = y, z = z}
    return
  end

  if math.random(100) > params:get("probability") then
    last_sample = {x = x, y = y, z = z}
    return
  end

  local source = options.NOTE_SOURCES[params:get("note_source")]
  local degree = util.clamp(math.floor(norms[source] * #note_scale) + 1, 1, #note_scale)
  local note_num = nearest_scale_note(note_scale[degree])
  local speed = math.sqrt(
    ((x - last_sample.x) * (x - last_sample.x)) +
    ((y - last_sample.y) * (y - last_sample.y)) +
    ((z - last_sample.z) * (z - last_sample.z))
  )
  local speed_norm = util.clamp(speed / 4, 0, 1)
  local energy = util.clamp((norms.distance + speed_norm) / 2, 0, 1)
  local vel_min = math.min(params:get("velocity_min"), params:get("velocity_max"))
  local vel_max = math.max(params:get("velocity_min"), params:get("velocity_max"))
  local velocity = util.clamp(math.floor(util.linlin(0, 1, vel_min, vel_max, energy)), 1, 127)
  local division = options.DIVISION_VALUES[params:get("note_division")]
  local duration_ms = math.max(20, math.floor(beat_duration_ms(division) * params:get("note_length_pct") / 100))

  if params:get("avoid_repeats") == 2 and note_num == last_sent_note and #note_scale > 1 then
    note_num = nearest_scale_note(note_scale[(degree % #note_scale) + 1])
  end

  osc_note(note_num, velocity, duration_ms)
  last_sent_note = note_num
  last_sample = {x = x, y = y, z = z}
end

local function osc_clock()
  while true do
    clock.sync(options.DIVISION_VALUES[params:get("note_division")])
    if osc_running then
      attractor_note()
      redraw()
    end
  end
end

function init()
  note_scale_names = {}
  for i = 1, #MusicUtil.SCALES do
    table.insert(note_scale_names, string.lower(MusicUtil.SCALES[i].name))
  end

  params:add_separator("Lorenz OSC")
  params:add{type = "option", id = "output", name = "output",
    options = options.OUTPUT, default = 1,
    action = function()
      all_notes_off()
    end}

  params:add_separator("OSC MIDI")
  params:add{type = "option", id = "osc_target", name = "OSC target",
    options = options.OSC_TARGETS, default = 1,
    action = function(value)
      set_osc_target(value)
    end}
  params:add_text("osc_ip", "PC IP", "192.168.178.220")
  set_osc_target(params:get("osc_target"))
  params:add_number("osc_port", "OSC port", 1, 65535, 7123)
  params:add_number("osc_channel", "MIDI channel", 1, 16, 1)
  params:add{type = "trigger", id = "osc_test_note", name = "send OSC test note",
    action = function()
      osc_note(60, 110, 250)
    end}

  params:add_separator("Attractor MIDI")
  params:add{type = "option", id = "trigger_mode", name = "trigger mode",
    options = options.TRIGGER_MODES, default = 1}
  params:add{type = "option", id = "note_source", name = "note source",
    options = options.NOTE_SOURCES, default = 5}
  params:add{type = "option", id = "note_division", name = "note division",
    options = options.DIVISION_NAMES, default = 2}
  params:add_number("probability", "probability", 0, 100, 100)
  params:add_number("note_length_pct", "note length %", 10, 200, 80)
  params:add_number("activity_threshold", "activity threshold", 0, 100, 35)
  params:add_number("velocity_min", "velocity min", 1, 127, 60)
  params:add_number("velocity_max", "velocity max", 1, 127, 110)
  params:add{type = "option", id = "avoid_repeats", name = "avoid repeats",
    options = {"off", "on"}, default = 2}

  params:add_separator("Pitch")
  params:add{type = "option", id = "scale_mode", name = "scale",
    options = note_scale_names, default = 12,
    action = build_note_scale}
  params:add_number("root_note", "root note", 0, 127, 48,
    function(param) return MusicUtil.note_num_to_name(param:get(), true) end)
  params:set_action("root_note", build_note_scale)
  params:add_number("octave_span", "octave span", 1, 6, 2)
  params:set_action("octave_span", build_note_scale)

	-- Define crow parameters
  params:add_separator("Crow CV")
  params:add_taper('slew', "slew", 0.001, 0.1, 0.001, 1, "s")
  params:set_action('slew', function(v)
    if crow_available() then
      for i=1,4 do crow.output[i].slew = v end
    end
  end)

  -- Initialize crow outputs for direct voltage control
  if crow_available() then
    crow.output[1].slew = params:get('slew')  -- Small slew for smooth transitions
    crow.output[2].slew = params:get('slew')
    crow.output[3].slew = params:get('slew')  -- Add slew for z coordinate
    crow.output[4].slew = params:get('slew')  -- Add slew for out4
  end

  -- Initialize second crow (crow.ii) outputs for inverted signals
  if follower_crow_available() then
    crow.ii.crow[2].slew(1, 0.001)
    crow.ii.crow[2].slew(2, 0.001)
    crow.ii.crow[2].slew(3, 0.001)
    crow.ii.crow[2].slew(4, 0.001)
  end

  -- Initialize screen
  screen.level(15)
  screen.aa(0)
  screen.line_width(1)

  build_note_scale()
  
  -- Start the attractor calculation using metro
  lorentz_metro = metro.init()
  lorentz_metro.time = 1/60 -- 60 fps (faster update rate)
  lorentz_metro.event = function()
    redraw()
  end
  lorentz_metro:start()

  att_fade_metro = metro.init()
  att_fade_metro.time = 1/30
  att_fade_metro.event = function()
    if att_display_fade > 0 then
      att_display_fade = math.max(0, att_display_fade - 1/30)
      redraw()
      if att_display_fade == 0 then
        att_fade_metro:stop()
      end
    end
  end

  -- Start attractor calculation in main runloop
  clock.run(function()
    while true do
      update_attractor()
      clock.sleep(1/120)
    end
  end)
  clock.run(osc_clock)
  
  -- Initialize with default values
  reset_parameters()
  
  -- Set up input 1 for parameter offset control
  if crow_available() and crow.input then
    crow.input[1].stream = function(volts)
      crow1_input1 = volts
    end
    crow.input[1].mode("stream", 0.01)  -- Update every 10ms

    -- Set up input 2 as reset button
    crow.input[2].change = function()
      reset_coordinates()
    end
    crow.input[2].mode("change", 2.0, 0.25, "rising")
  end

  if follower_crow_available() then
    crow.ii.crow[2].event = function(e, value)
      if e.name == 'input' then
        if e.arg == 1 then
          crow2_input1 = value
        elseif e.arg == 2 then
          crow2_input2 = value
        end
      end
    end
  end
end

function reset_parameters(randomize)
  if current_attractor == "lorenz" then
    if randomize then
      base_sigma = math.random() * 49.9 + 0.1  -- 0.1 to 50
      base_rho = math.random() * 59.5 + 0.5    -- 0.5 to 60
      base_beta = math.random() * 9.9 + 0.1    -- 0.1 to 10
      
      -- Also randomize initial conditions
      x = math.random() * 20 - 10         -- -10 to 10
      y = math.random() * 20 - 10         -- -10 to 10
      z = math.random() * 10              -- 0 to 10
      initial_x, initial_y, initial_z = x, y, z
    else
      base_sigma = 10
      base_rho = 28
      base_beta = 8/3
      x, y, z = 0.1, 0, 0
      initial_x, initial_y, initial_z = x, y, z
      dt = 0.005
    end
    display_scale = 1  -- Set display scale for Lorenz
  elseif current_attractor == "rossler" then -- rossler
    if randomize then
      base_a = math.random(10, 40) / 100
      base_b = math.random(10, 40) / 100
      base_c = math.random(40, 80) / 10

	  -- Also randomize initial conditions
      x = math.random() * 20 - 10         -- -10 to 10
      y = math.random() * 20 - 10         -- -10 to 10
      z = math.random() * 10              -- 0 to 10
      initial_x, initial_y, initial_z = x, y, z
    else
      base_a = 0.1
      base_b = 0.1
      base_c = 14
      x, y, z = 0.1, 0.1, 0.1
      initial_x, initial_y, initial_z = x, y, z
      dt = 0.05
    end
    display_scale = 1  -- Set display scale for Rössler
  elseif current_attractor == "sprott" then -- sprott
    if randomize then
      base_sprott_a = math.random(40, 50) / 100  -- 0.4 to 0.5
      
      -- Also randomize initial conditions
      x = math.random(50) * 0.01         -- 0 to 0.5
      y = math.random(-25, 25) * 0.01         -- -0.25 to 0.25
      z = math.random(-25, 25) * 0.01         -- -0.25 to 0.25
      initial_x, initial_y, initial_z = x, y, z
    else
      base_sprott_a = 0.5
      x, y, z = 1, 0, 0
      initial_x, initial_y, initial_z = x, y, z
      dt = 0.05
    end
    display_scale = 5.5  -- Set display scale for Sprott
  else -- halvorsen
    if randomize then
      base_halvorsen_a = math.random(165, 300) / 100  -- 1.65 to 3.0
      
      -- Also randomize initial conditions
      x = math.random(-1000, 1000) * 0.01     -- -10 to 10
      y = math.random(-1000, 1000) * 0.01     -- -10 to 10
      z = math.random(-1000, 1000) * 0.01     -- -10 to 10
      initial_x, initial_y, initial_z = x, y, z
    else
      base_halvorsen_a = 1.89
      x, y, z = 0.1, 0, 0
      initial_x, initial_y, initial_z = x, y, z
      dt = 0.01
    end
    display_scale = 3.0  -- Set display scale for Halvorsen
  end
  
  points = {}
end

function apply_parameter_offsets()
  -- Map input voltages (-5V to +5V) to parameter offsets
  -- crow1_input1 controls first parameter (a, sigma)
  -- crow2_input1 controls second parameter (b, rho) 
  -- crow2_input2 controls third parameter (c, beta)
  
  -- Apply noise filtering to inputs
  crow1_input1 = filter_input_noise(crow1_input1, 1)
  crow2_input1 = filter_input_noise(crow2_input1, 2)
  crow2_input2 = filter_input_noise(crow2_input2, 3)
  
  if current_attractor == "lorenz" then
    -- Lorenz parameter ranges: sigma(0-20), rho(0-60), beta(0-10)
    local sigma_offset = util.linlin(-5, 5, -10, 10, util.clamp(crow1_input1, -5, 5))
    local rho_offset = util.linlin(-5, 5, -30, 30, util.clamp(crow2_input1, -5, 5))
    local beta_offset = util.linlin(-5, 5, -5, 5, util.clamp(crow2_input2, -5, 5))
    
    sigma = util.clamp(base_sigma + sigma_offset, 0, 20)
    rho = util.clamp(base_rho + rho_offset, 0, 60)
    beta = util.clamp(base_beta + beta_offset, 0, 10)
    
  elseif current_attractor == "rossler" then
    -- Rössler parameter ranges: a(0-0.5), b(0-0.5), c(3-24)
    local a_offset = util.linlin(-5, 5, -0.25, 0.25, util.clamp(crow1_input1, -5, 5))
    local b_offset = util.linlin(-5, 5, -0.25, 0.25, util.clamp(crow2_input1, -5, 5))
    local c_offset = util.linlin(-5, 5, -10.5, 10.5, util.clamp(crow2_input2, -5, 5))
    
    a = util.clamp(base_a + a_offset, 0, 0.5)
    b = util.clamp(base_b + b_offset, 0, 0.5)
    c = util.clamp(base_c + c_offset, 3, 24)
    
  elseif current_attractor == "sprott" then
    -- Sprott parameter range: sprott_a(0.4-0.5)
    local sprott_a_offset = util.linlin(-5, 5, -0.05, 0.05, util.clamp(crow1_input1, -5, 5))
    
    sprott_a = util.clamp(base_sprott_a + sprott_a_offset, 0.4, 0.5)
    
  else -- halvorsen
    -- Halvorsen parameter range: halvorsen_a(1.65-3.0)
    local halvorsen_a_offset = util.linlin(-5, 5, -0.675, 0.675, util.clamp(crow1_input1, -5, 5))
    
    halvorsen_a = util.clamp(base_halvorsen_a + halvorsen_a_offset, 1.65, 3.0)
  end
end

function filter_input_noise(current_value, input_id)
  -- Deadband filtering: ignore changes smaller than noise threshold
  local previous_value = filtered_inputs[input_id]
  local change = math.abs(current_value - previous_value)
  
  local filtered_value
  if change < noise_threshold then
    -- Change is too small, keep previous value (deadband only)
    filtered_value = previous_value
  else
    -- Change is significant, use new value immediately (no slew)
    filtered_value = current_value
  end
  
  -- Store the filtered value for next time
  filtered_inputs[input_id] = filtered_value
  
  return filtered_value
end

function reset_coordinates()
  -- Reset coordinates to stored initial conditions
  x, y, z = initial_x, initial_y, initial_z
  
  -- Clear the trail
  points = {}
end

function update_attractor()
  -- Apply parameter offsets based on crow input values
  apply_parameter_offsets()
  
  if current_attractor == "lorenz" then
    -- Calculate next point in the Lorenz system
    local dx = sigma * (y - x)
    local dy = x * (rho - z) - y
    local dz = x * y - beta * z
    
    x = x + dx * dt
    y = y + dy * dt
    z = z + dz * dt
  elseif current_attractor == "rossler" then -- rossler
    -- Calculate next point in the Rössler system
    local dx = -y - z
    local dy = x + a * y
    local dz = b + z * (x - c)
    
    x = x + dx * dt
    y = y + dy * dt
    z = z + dz * dt
  elseif current_attractor == "sprott" then -- sprott
    -- Calculate next point in the Sprott-Linz F system
    local dx = y + z
    local dy = -x + sprott_a * y
    local dz = x * x - z
    
    x = x + dx * dt
    y = y + dy * dt
    z = z + dz * dt
  else -- halvorsen
    -- Calculate next point in the Halvorsen system
    local dx = -halvorsen_a * x - 4 * y - 4 * z - y * y
    local dy = -halvorsen_a * y - 4 * z - 4 * x - z * z
    local dz = -halvorsen_a * z - 4 * x - 4 * y - x * x
    
    x = x + dx * dt
    y = y + dy * dt
    z = z + dz * dt
  end
  
  -- Prevent numerical overflow with extreme values
  local max_value = 1000
  x = math.max(math.min(x, max_value), -max_value)
  y = math.max(math.min(y, max_value), -max_value)
  z = math.max(math.min(z, max_value), -max_value)

  if (math.abs(x) == 1000 or math.abs(y) == 1000 or math.abs(z) == 1000) then
    reset_parameters(true)
  end

  -- Add new point to the list
  table.insert(points, {x = x, y = y, z = z})
  
  -- Limit the number of points
  if #points > max_points then
    table.remove(points, 1)
  end
  
  -- Update crow outputs with scaled values
  if current_attractor == "lorenz" then
    -- Lorenz typically has larger values
    out1_volts = util.clamp(x * 0.1, -5, 5) * output_attenuation[1]
    out2_volts = util.clamp(y * 0.1, -5, 5) * output_attenuation[2]
    out3_volts = util.clamp(z * 0.1, -5, 5) * output_attenuation[3]  -- Z is much larger in Lorenz
    -- Calculate distance from origin (normalized chaos intensity)
    out4_volts = util.clamp(math.sqrt(x*x + y*y + z*z) * 0.05, 0, 5) * output_attenuation[4]
  elseif current_attractor == "rossler" then
    -- Rössler has different ranges for each dimension
    out1_volts = util.clamp(x * 0.25, -5, 5) * output_attenuation[1]
    out2_volts = util.clamp(y * 0.25, -5, 5) * output_attenuation[2]
    out3_volts = util.clamp(z * 0.25, -5, 5) * output_attenuation[3]  -- Z is still larger but not as extreme
    out4_volts = util.clamp(math.sqrt(x*x + y*y + z*z) * 0.1, 0, 5) * output_attenuation[4]
  elseif current_attractor == "sprott" then -- sprott
    -- Sprott-Linz F has smaller ranges
    out1_volts = util.clamp(x * 1.0, -5, 5) * output_attenuation[1]
    out2_volts = util.clamp(y * 1.0, -5, 5) * output_attenuation[2]
    out3_volts = util.clamp(z * 1.0, -5, 5) * output_attenuation[3]
    out4_volts = util.clamp(math.sqrt(x*x + y*y + z*z) * 0.5, 0, 5) * output_attenuation[4]
  else -- halvorsen
    -- Halvorsen has moderate ranges
    out1_volts = util.clamp(x * 0.5, -5, 5) * output_attenuation[1]
    out2_volts = util.clamp(y * 0.5, -5, 5) * output_attenuation[2]
    out3_volts = util.clamp(z * 0.5, -5, 5) * output_attenuation[3]
    out4_volts = util.clamp(math.sqrt(x*x + y*y + z*z) * 0.25, 0, 5) * output_attenuation[4]
  end
  
  if uses_crow() then
    crow.output[1].volts = out1_volts
    crow.output[2].volts = out2_volts
    crow.output[3].volts = out3_volts
    crow.output[4].volts = out4_volts
  end
  
  -- Send inverted versions to second crow
  if uses_crow() and follower_crow_available() then
    crow.ii.crow[2].volts(1, -out1_volts)
    crow.ii.crow[2].volts(2, -out2_volts) 
    crow.ii.crow[2].volts(3, -out3_volts)
    crow.ii.crow[2].volts(4, -out4_volts)

    crow.ii.crow[2].get('input', 1)
    crow.ii.crow[2].get('input', 2)
  end
end

function redraw()
  -- Read from follower crow's inputs (if needed)
  -- This triggers the follower to update its outputs 3&4 with input values
  -- You can read the values from the follower's outputs if needed
  
  screen.clear()

  -- Draw the attractor
  for i = 2, #points do
    local prev = points[i-1]
    local curr = points[i]
    
    -- Project 3D to 2D (simple orthographic projection)
    local prev_x = prev.x * scale * display_scale + offset_x
    local prev_y = prev.y * scale * display_scale + offset_y
    local curr_x = curr.x * scale * display_scale + offset_x
    local curr_y = curr.y * scale * display_scale + offset_y
    
    -- Fade based on age of the point (newer points are brighter)
    local age_factor = (i - 1) / #points
    local brightness = util.linlin(0, 1, 1, 15, age_factor)
    
    -- Also factor in z-coordinate for depth effect
    local z_brightness = util.linlin(-30, 30, 1, 15, curr.z)
    
    -- Combine age and z factors for final brightness
    local final_brightness = math.min(brightness, z_brightness)
    screen.level(math.floor(final_brightness))
    
    screen.move(prev_x, prev_y)
    screen.line(curr_x, curr_y)
    screen.stroke()
  end
  
  -- Draw output visualizers in bottom right
  draw_output_visualizers()
  
  -- Draw attractor name and parameters in title bar
  screen.level(15)
  screen.rect(0, 0, 128, 7)
  screen.fill()
  screen.level(0)
  screen.move(2, 6)
  
  if current_attractor == "lorenz" then
    screen.text("Lorenz  σ:" .. string.format("%.1f", sigma) .. 
                " ρ:" .. string.format("%.1f", rho) .. 
                " β:" .. string.format("%.1f", beta))
  elseif current_attractor == "rossler" then -- rossler
    screen.text("Rossler  a:" .. string.format("%.2f", a) .. 
                " b:" .. string.format("%.2f", b) .. 
                " c:" .. string.format("%.1f", c))
  elseif current_attractor == "sprott" then -- sprott
    screen.text("Sprott-F  a:" .. string.format("%.2f", sprott_a))
  else -- halvorsen
    screen.text("Halvorsen  a:" .. string.format("%.2f", halvorsen_a))
  end
  
  -- Display coordinate values
  screen.level(15)
  
  -- Show transport and dt value at the bottom
  screen.level(15)
  screen.move(2, 60)
  if key1_down then
    screen.text("dt:" .. string.format("%.5f", dt))
  else
    screen.text((osc_running and "RUN " or "STOP ") .. options.DIVISION_NAMES[params:get("note_division")])
  end
  screen.move(126, 60)
  screen.text_right(options.NOTE_SOURCES[params:get("note_source")])
  
  screen.update()
end

function draw_output_visualizers()
  local viz_width = 30
  local viz_height = 4
  local viz_x = 128 - viz_width - 2
  local viz_y_start = 40
  local viz_spacing = 6
  
  -- Draw output visualizers
  local outputs = {
    {value = out1_volts, name = "1", att = output_attenuation[1]},
    {value = out2_volts, name = "2", att = output_attenuation[2]},
    {value = out3_volts, name = "3", att = output_attenuation[3]},
    {value = out4_volts, name = "4", att = output_attenuation[4]}
  }
  
  for i, output in ipairs(outputs) do
    local y_pos = viz_y_start + (i-1) * viz_spacing
    
    -- Draw bipolar meter background
    screen.level(1)
    screen.rect(viz_x, y_pos, viz_width, viz_height)
    screen.fill()
    
    -- Draw center line (zero point)
    screen.level(3)
    screen.move(viz_x + viz_width/2, y_pos)
    screen.line(viz_x + viz_width/2, y_pos + viz_height)
    screen.stroke()
    
    -- Draw output level
    screen.level(15)
    local normalized_value = output.value / 5  -- Normalize to -1 to 1 range
    local bar_width = math.abs(normalized_value) * (viz_width/2)
    
    if normalized_value >= 0 then
      -- Positive value (right side)
      screen.rect(viz_x + viz_width/2, y_pos, bar_width, viz_height)
    else
      -- Negative value (left side)
      screen.rect(viz_x + viz_width/2 - bar_width, y_pos, bar_width, viz_height)
    end
    screen.fill()
    
    -- Draw selection border if this output is selected
    screen.level(i == selected_output and 15 or 0)
    screen.rect(viz_x, y_pos, viz_width + 1, viz_height + 1)
    screen.stroke()
    
    -- Draw attenuation indicator
    local att_percent = math.floor(output.att * 100)
    
    -- Only show percentage when K2 is held or during fade-out
    if key2_down or att_display_fade > 0 then
      -- Calculate brightness based on fade timer
      local brightness = key2_down and 15 or math.floor(15 * att_display_fade)
      screen.level(i == selected_output and brightness or math.floor(brightness * 0.5))
      screen.move(viz_x - 20, y_pos + 5)
      screen.text(att_percent .. "%")
    else
      -- Show dots for non-selected outputs when not displaying percentages
      if i ~= selected_output then
        screen.level(3)
        screen.move(viz_x - 20, y_pos + 5)
        screen.text(string.rep("·", math.ceil(output.att * 5)))
      end
    end
  end
end

function enc(n,d)
  if n==1 then
    if key1_down then
      -- Adjust dt when K1 is held
      dt = util.clamp(dt + d * 0.0001, dt_min, dt_max)
      key1_encoder_adjusted = true
    else
      if current_attractor == "lorenz" then
        -- Adjust base sigma parameter
        base_sigma = util.clamp(base_sigma + d*0.1, 0, 20)
      elseif current_attractor == "rossler" then -- rossler
        -- Adjust base a parameter
        base_a = util.clamp(base_a + d*0.01, 0, 0.5)
      elseif current_attractor == "sprott" then -- sprott
        -- Adjust base sprott_a parameter
        base_sprott_a = util.clamp(base_sprott_a + d*0.01, 0.4, 0.5)
      else -- halvorsen
        -- Adjust base halvorsen_a parameter
        base_halvorsen_a = util.clamp(base_halvorsen_a + d*0.01, 1.65, 3.0)
      end
    end
  elseif n==2 then
    if key2_down then
      -- No longer adjusting dt with K2+E2
      encoder_adjusted_during_k2 = true
    else
      -- Adjust base rho/b parameter
      if current_attractor == "lorenz" then
        base_rho = util.clamp(base_rho + d*0.1, 0, 60)
      elseif current_attractor == "rossler" then -- rossler
        base_b = util.clamp(base_b + d*0.01, 0, 0.5)
      end
      -- No second parameter for Sprott-Linz F or Halvorsen
    end
  elseif n==3 then
    if key2_down then
      -- Adjust attenuation for selected output when K2 is held
      output_attenuation[selected_output] = util.clamp(output_attenuation[selected_output] + d*0.01, 0.0, 1.0)
      encoder_adjusted_during_k2 = true
    else
      if current_attractor == "lorenz" then
        -- Adjust base beta parameter
        base_beta = util.clamp(base_beta + d*0.05, 0, 10)
      elseif current_attractor == "rossler" then -- rossler
        -- Adjust base c parameter
        base_c = util.clamp(base_c + d*0.1, 3, 24)
      end
      -- No third parameter for Sprott-Linz F or Halvorsen
    end
  end
end 

function key(n,z)
  if n==1 then
    if z==1 then
      key1_down = true
      key1_encoder_adjusted = false
    else
      if key1_down and not key1_encoder_adjusted then
        toggle_transport()
      end
      key1_down = false
    end
  elseif n==2 then
    if z==1 then
      -- K2 pressed down
      key2_down = true
      encoder_adjusted_during_k2 = false
      att_display_fade = 1  -- Show attenuation display
      if att_fade_metro then
        att_fade_metro:stop()  -- Stop any ongoing fade
      end
    else
      -- K2 released
      if key2_down and not encoder_adjusted_during_k2 then
        -- Switch selected output only on K2 release and if no encoder was adjusted
        selected_output = (selected_output % 4) + 1
      end
      key2_down = false
      att_display_fade = 1  -- Start fade from full brightness
      if att_fade_metro then
        att_fade_metro:start()  -- Start fade-out timer
      end
    end
  elseif n==3 and z==1 then
    if key2_down then
      -- Cycle between attractors when K2+K3 is pressed
      if current_attractor == "lorenz" then
        current_attractor = "rossler"
      elseif current_attractor == "rossler" then
        current_attractor = "sprott"
      elseif current_attractor == "sprott" then
        current_attractor = "halvorsen"
      else
        current_attractor = "lorenz"
      end
      print("Switched to " .. current_attractor)
      reset_parameters(true)
      encoder_adjusted_during_k2 = true  -- Prevent output selection change
    else
      -- Randomize parameters when K3 is pressed alone
      reset_parameters(true)
      print("Randomized parameters")
    end
  end
end

function cleanup()
  -- Stop the metros when the script is cleaned up
  stop_transport()
  if lorentz_metro then
    lorentz_metro:stop()
  end
  if att_fade_metro then
    att_fade_metro:stop()
  end
end

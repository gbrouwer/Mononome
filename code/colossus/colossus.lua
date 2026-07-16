engine.name = "Colossus"

local musicutil = require "musicutil"

local USER_PRESET_COUNT = 100
local LONG_PRESS_SECONDS = 0.70
local DATA_DIR = _path.data .. "colossus/"
local PRESET_DIR = DATA_DIR .. "presets/"

local playing = false
local selected = 1
local evolve_clock = nil
local morph_clock = nil
local status_clock = nil
local key_down_at = {}
local suppress_redraw = false
local engine_missing = false

local preset_mode = false
local preset_bank = "factory"
local preset_index = 1
local morph_index = 1
local morph_options = {
  { name = "IMMEDIATE", seconds = 0 },
  { name = "MORPH 2S", seconds = 2 },
  { name = "MORPH 8S", seconds = 8 },
  { name = "MORPH 30S", seconds = 30 }
}
local user_presets = {}
local pending_name = nil
local status_message = nil

local editable = {
  "root_level",
  "foundation",
  "fifth_level",
  "octave_level",
  "minor_ninth_level",
  "detune",
  "movement",
  "width",
  "cutoff",
  "resonance",
  "drive",
  "reverb_mix",
  "decay",
  "damping",
  "shimmer",
  "shimmer_feedback",
  "evolve_rate",
  "evolve_amount"
}

-- Transient performance states (drone/freeze) are deliberately excluded.
local preset_ids = {
  "root_note",
  "root_level",
  "foundation",
  "fifth_level",
  "octave_level",
  "minor_ninth_level",
  "detune",
  "movement",
  "width",
  "cutoff",
  "resonance",
  "drive",
  "reverb_mix",
  "decay",
  "damping",
  "shimmer",
  "shimmer_feedback",
  "output",
  "evolve",
  "evolve_rate",
  "evolve_amount"
}

local continuous_preset_ids = {
  "root_note",
  "root_level",
  "foundation",
  "fifth_level",
  "octave_level",
  "minor_ninth_level",
  "detune",
  "movement",
  "width",
  "cutoff",
  "resonance",
  "drive",
  "reverb_mix",
  "decay",
  "damping",
  "shimmer",
  "shimmer_feedback",
  "output",
  "evolve_rate",
  "evolve_amount"
}

local adjectives = {
  "Amber", "Ancient", "Ashen", "Astral", "Black", "Bleak", "Blue", "Broken",
  "Burning", "Celestial", "Cold", "Crimson", "Distant", "Dreaming", "Electric", "Endless",
  "Falling", "Feral", "Forgotten", "Frozen", "Ghostly", "Glass", "Golden", "Hidden",
  "Hollow", "Infinite", "Iron", "Last", "Liminal", "Lonely", "Lost", "Luminous",
  "Midnight", "Obsidian", "Pale", "Quiet", "Radiant", "Red", "Restless", "Sacred",
  "Silent", "Silver", "Sleeping", "Solar", "Static", "Velvet", "Violet", "Wandering"
}

local nouns = {
  "Archive", "Beacon", "Cathedral", "Chamber", "Choir", "Circuit", "Cloud", "Current",
  "Dawn", "Depth", "Ember", "Engine", "Field", "Forest", "Garden", "Harbor",
  "Horizon", "Machine", "Memory", "Monolith", "Moon", "Ocean", "Orbit", "Palace",
  "Planet", "Pulse", "Rain", "Ritual", "River", "Sanctuary", "Sea", "Signal",
  "Sky", "Star", "Station", "Stone", "Storm", "Temple", "Tide", "Tower",
  "Vessel", "Void", "Weather", "Whisper", "Wilderness", "Window", "Winter", "World"
}

local factory_presets = {
  {
    name = "Cathedral",
    values = {
      root_note = 36, root_level = 0.64, foundation = 0.46,
      fifth_level = 0.36, octave_level = 0.32, minor_ninth_level = 0.03,
      detune = 14, movement = 0.22, width = 0.92, cutoff = 3100,
      resonance = 0.18, drive = 1.20, reverb_mix = 0.84, decay = 0.95,
      damping = 0.30, shimmer = 0.42, shimmer_feedback = 0.38,
      output = 0.25, evolve = 0, evolve_rate = 42, evolve_amount = 0.22
    }
  },
  {
    name = "Glacier",
    values = {
      root_note = 31, root_level = 0.57, foundation = 0.66,
      fifth_level = 0.08, octave_level = 0.29, minor_ninth_level = 0.02,
      detune = 7, movement = 0.12, width = 0.74, cutoff = 1450,
      resonance = 0.31, drive = 1.55, reverb_mix = 0.79, decay = 0.92,
      damping = 0.52, shimmer = 0.18, shimmer_feedback = 0.25,
      output = 0.25, evolve = 0, evolve_rate = 68, evolve_amount = 0.14
    }
  },
  {
    name = "Black Sun",
    values = {
      root_note = 28, root_level = 0.80, foundation = 0.74,
      fifth_level = 0.12, octave_level = 0.05, minor_ninth_level = 0.22,
      detune = 27, movement = 0.46, width = 0.86, cutoff = 920,
      resonance = 0.47, drive = 2.30, reverb_mix = 0.69, decay = 0.86,
      damping = 0.63, shimmer = 0.10, shimmer_feedback = 0.18,
      output = 0.22, evolve = 0, evolve_rate = 28, evolve_amount = 0.38
    }
  },
  {
    name = "Choir",
    values = {
      root_note = 41, root_level = 0.41, foundation = 0.22,
      fifth_level = 0.28, octave_level = 0.56, minor_ninth_level = 0.04,
      detune = 11, movement = 0.36, width = 0.97, cutoff = 4200,
      resonance = 0.14, drive = 1.08, reverb_mix = 0.88, decay = 0.97,
      damping = 0.23, shimmer = 0.63, shimmer_feedback = 0.47,
      output = 0.23, evolve = 0, evolve_rate = 54, evolve_amount = 0.26
    }
  },
  {
    name = "Minor Void",
    values = {
      root_note = 33, root_level = 0.54, foundation = 0.31,
      fifth_level = 0.07, octave_level = 0.18, minor_ninth_level = 0.36,
      detune = 19, movement = 0.31, width = 0.95, cutoff = 1850,
      resonance = 0.29, drive = 1.42, reverb_mix = 0.91, decay = 0.98,
      damping = 0.42, shimmer = 0.34, shimmer_feedback = 0.44,
      output = 0.22, evolve = 1, evolve_rate = 47, evolve_amount = 0.32
    }
  },
  {
    name = "Distant Machinery",
    values = {
      root_note = 38, root_level = 0.48, foundation = 0.37,
      fifth_level = 0.26, octave_level = 0.12, minor_ninth_level = 0.16,
      detune = 34, movement = 0.72, width = 0.78, cutoff = 2650,
      resonance = 0.56, drive = 2.65, reverb_mix = 0.61, decay = 0.73,
      damping = 0.58, shimmer = 0.15, shimmer_feedback = 0.21,
      output = 0.21, evolve = 1, evolve_rate = 19, evolve_amount = 0.58
    }
  },
  {
    name = "Deep Ocean",
    values = {
      root_note = 25, root_level = 0.68, foundation = 0.88,
      fifth_level = 0.14, octave_level = 0.05, minor_ninth_level = 0.02,
      detune = 9, movement = 0.18, width = 0.63, cutoff = 690,
      resonance = 0.35, drive = 1.72, reverb_mix = 0.77, decay = 0.94,
      damping = 0.74, shimmer = 0.04, shimmer_feedback = 0.12,
      output = 0.24, evolve = 0, evolve_rate = 82, evolve_amount = 0.12
    }
  },
  {
    name = "Ascension",
    values = {
      root_note = 43, root_level = 0.42, foundation = 0.20,
      fifth_level = 0.38, octave_level = 0.72, minor_ninth_level = 0.08,
      detune = 13, movement = 0.41, width = 1.00, cutoff = 6100,
      resonance = 0.11, drive = 1.12, reverb_mix = 0.91, decay = 0.98,
      damping = 0.17, shimmer = 0.78, shimmer_feedback = 0.56,
      output = 0.20, evolve = 1, evolve_rate = 33, evolve_amount = 0.30
    }
  },
  {
    name = "Ember Field",
    values = {
      root_note = 35, root_level = 0.63, foundation = 0.44,
      fifth_level = 0.31, octave_level = 0.17, minor_ninth_level = 0.09,
      detune = 22, movement = 0.52, width = 0.88, cutoff = 2250,
      resonance = 0.26, drive = 2.05, reverb_mix = 0.72, decay = 0.84,
      damping = 0.49, shimmer = 0.22, shimmer_feedback = 0.27,
      output = 0.23, evolve = 1, evolve_rate = 25, evolve_amount = 0.42
    }
  },
  {
    name = "Glass Tundra",
    values = {
      root_note = 46, root_level = 0.34, foundation = 0.18,
      fifth_level = 0.12, octave_level = 0.63, minor_ninth_level = 0.11,
      detune = 5, movement = 0.17, width = 0.96, cutoff = 7800,
      resonance = 0.19, drive = 0.94, reverb_mix = 0.86, decay = 0.90,
      damping = 0.13, shimmer = 0.52, shimmer_feedback = 0.35,
      output = 0.22, evolve = 0, evolve_rate = 74, evolve_amount = 0.16
    }
  },
  {
    name = "Orbital Choir",
    values = {
      root_note = 39, root_level = 0.42, foundation = 0.19,
      fifth_level = 0.52, octave_level = 0.46, minor_ninth_level = 0.07,
      detune = 17, movement = 0.29, width = 1.00, cutoff = 4700,
      resonance = 0.16, drive = 1.16, reverb_mix = 0.89, decay = 0.96,
      damping = 0.25, shimmer = 0.57, shimmer_feedback = 0.42,
      output = 0.22, evolve = 1, evolve_rate = 61, evolve_amount = 0.24
    }
  },
  {
    name = "Sleeping Giant",
    values = {
      root_note = 27, root_level = 0.86, foundation = 0.72,
      fifth_level = 0.22, octave_level = 0.08, minor_ninth_level = 0.04,
      detune = 16, movement = 0.08, width = 0.69, cutoff = 1120,
      resonance = 0.24, drive = 1.88, reverb_mix = 0.74, decay = 0.93,
      damping = 0.67, shimmer = 0.08, shimmer_feedback = 0.16,
      output = 0.23, evolve = 0, evolve_rate = 104, evolve_amount = 0.08
    }
  }
}

local function engine_command(name, ...)
  local command = engine[name]
  if type(command) ~= "function" then
    engine_missing = true
    print("colossus: missing engine command " .. name)
    return false
  end

  command(...)
  return true
end

local function set_engine_parameter(id, value)
  local command = {
    root_note = function(v) engine_command("freq", musicutil.note_num_to_freq(v)) end,
    root_level = function(v) engine_command("rootLevel", v) end,
    foundation = function(v) engine_command("foundation", v) end,
    fifth_level = function(v) engine_command("fifthLevel", v) end,
    octave_level = function(v) engine_command("octaveLevel", v) end,
    minor_ninth_level = function(v) engine_command("minorNinthLevel", v) end,
    detune = function(v) engine_command("detune", v) end,
    movement = function(v) engine_command("movement", v) end,
    width = function(v) engine_command("width", v) end,
    cutoff = function(v) engine_command("cutoff", v) end,
    resonance = function(v) engine_command("resonance", v) end,
    drive = function(v) engine_command("drive", v) end,
    reverb_mix = function(v) engine_command("reverbMix", v) end,
    decay = function(v) engine_command("decay", v) end,
    damping = function(v) engine_command("damping", v) end,
    shimmer = function(v) engine_command("shimmer", v) end,
    shimmer_feedback = function(v) engine_command("shimmerFeedback", v) end,
    output = function(v) engine_command("amp", v) end,
    freeze = function(v) engine_command("freeze", v) end
  }

  if command[id] ~= nil then
    command[id](value)
  end
end

local function start_drone()
  if playing then return end
  if params:get("freeze") == 1 then params:set("freeze", 0) end
  playing = engine_command("start")
end

local function stop_drone()
  if not playing then return end
  engine_command("stop")
  playing = false
end

local function toggle_drone()
  params:set("drone", playing and 0 or 1)
end

local function preset_path(slot)
  return PRESET_DIR .. string.format("%03d.lua", slot)
end

local function load_table_file(path)
  local chunk = loadfile(path)
  if chunk == nil then return nil end
  local ok, result = pcall(chunk)
  if not ok or type(result) ~= "table" then return nil end
  return result
end

local function write_preset_file(slot, name, values)
  local path = preset_path(slot)
  local temporary_path = path .. ".tmp"
  local file = io.open(temporary_path, "w")
  if file == nil then return false end

  file:write("return {\n")
  file:write("  name = ", string.format("%q", name), ",\n")
  file:write("  values = {\n")
  for _, id in ipairs(preset_ids) do
    local value = values[id]
    if type(value) == "number" then
      file:write("    [", string.format("%q", id), "] = ", string.format("%.10g", value), ",\n")
    end
  end
  file:write("  }\n")
  file:write("}\n")
  file:close()

  if os.rename(temporary_path, path) ~= nil then return true end

  os.remove(temporary_path)
  return false
end

local function load_user_presets()
  user_presets = {}
  for slot = 1, USER_PRESET_COUNT do
    local preset = load_table_file(preset_path(slot))
    if preset ~= nil and type(preset.name) == "string" and type(preset.values) == "table" then
      user_presets[slot] = preset
    end
  end
end

local function used_names(excluding_slot)
  local names = {}
  for _, preset in ipairs(factory_presets) do
    names[string.lower(preset.name)] = true
  end
  for slot, preset in pairs(user_presets) do
    if slot ~= excluding_slot and preset.name ~= nil then
      names[string.lower(preset.name)] = true
    end
  end
  return names
end

local function generate_unique_name(excluding_slot)
  local used = used_names(excluding_slot)

  for _ = 1, 300 do
    local name = adjectives[math.random(#adjectives)] .. " " .. nouns[math.random(#nouns)]
    if not used[string.lower(name)] then return name end
  end

  for _, adjective in ipairs(adjectives) do
    for _, noun in ipairs(nouns) do
      local name = adjective .. " " .. noun
      if not used[string.lower(name)] then return name end
    end
  end

  local suffix = 2
  while true do
    local name = "Endless Signal " .. suffix
    if not used[string.lower(name)] then return name end
    suffix = suffix + 1
  end
end

local function capture_values()
  local values = {}
  for _, id in ipairs(preset_ids) do
    values[id] = params:get(id)
  end
  return values
end

local function set_status(message)
  status_message = message
  if status_clock ~= nil then clock.cancel(status_clock) end
  status_clock = clock.run(function()
    clock.sleep(2.0)
    status_message = nil
    status_clock = nil
    redraw()
  end)
  redraw()
end

local function cancel_morph()
  if morph_clock ~= nil then
    clock.cancel(morph_clock)
    morph_clock = nil
  end
end

local function apply_values(values, seconds)
  cancel_morph()

  if seconds <= 0 then
    suppress_redraw = true
    for _, id in ipairs(continuous_preset_ids) do
      if values[id] ~= nil then params:set(id, values[id]) end
    end
    if values.evolve ~= nil then params:set("evolve", values.evolve) end
    suppress_redraw = false
    redraw()
    return
  end

  local starts = {}
  local targets = {}
  for _, id in ipairs(continuous_preset_ids) do
    if values[id] ~= nil then
      starts[id] = params:get(id)
      targets[id] = values[id]
    end
  end

  morph_clock = clock.run(function()
    local steps = math.max(1, math.floor(seconds * 30))
    for step = 1, steps do
      local t = step / steps
      local smooth = t * t * (3 - (2 * t))
      suppress_redraw = true
      for _, id in ipairs(continuous_preset_ids) do
        if targets[id] ~= nil then
          params:set(id, starts[id] + ((targets[id] - starts[id]) * smooth))
        end
      end
      suppress_redraw = false
      redraw()
      clock.sleep(seconds / steps)
    end

    suppress_redraw = true
    for _, id in ipairs(continuous_preset_ids) do
      if targets[id] ~= nil then params:set(id, targets[id]) end
    end
    if values.evolve ~= nil then params:set("evolve", values.evolve) end
    suppress_redraw = false
    redraw()
    morph_clock = nil
  end)
end

local function selected_preset()
  if preset_bank == "factory" then
    return factory_presets[preset_index]
  end
  return user_presets[preset_index]
end

local function refresh_pending_name()
  if preset_bank ~= "user" then
    pending_name = nil
    return
  end

  local preset = user_presets[preset_index]
  pending_name = preset ~= nil and preset.name or generate_unique_name(preset_index)
end

local function load_selected_preset()
  local preset = selected_preset()
  if preset == nil then
    set_status("EMPTY SLOT")
    return
  end

  apply_values(preset.values, morph_options[morph_index].seconds)
  set_status("LOADED " .. string.upper(preset.name))
end

local function save_selected_preset()
  if preset_bank ~= "user" then
    set_status("FACTORY IS READ ONLY")
    return
  end

  local name = pending_name or generate_unique_name(preset_index)
  local values = capture_values()
  if write_preset_file(preset_index, name, values) then
    user_presets[preset_index] = { name = name, values = values }
    set_status("SAVED " .. string.upper(name))
  else
    set_status("SAVE FAILED")
  end
end

local function reroll_name()
  if preset_bank ~= "user" then return end
  pending_name = generate_unique_name(preset_index)
  set_status("NAME REROLLED")
end

local function enter_preset_mode()
  preset_mode = true
  preset_bank = "factory"
  preset_index = 1
  refresh_pending_name()
  redraw()
end

local function leave_preset_mode()
  preset_mode = false
  redraw()
end

local function evolve()
  while true do
    clock.sleep(params:get("evolve_rate"))

    if params:get("evolve") == 1 and playing then
      local amount = params:get("evolve_amount")
      local function wander(id, depth)
        local base = params:get(id)
        return util.clamp(base + ((math.random() * 2 - 1) * amount * depth), 0, 1)
      end

      engine_command("fifthLevel", wander("fifth_level", 0.20))
      engine_command("octaveLevel", wander("octave_level", 0.18))
      engine_command("minorNinthLevel", wander("minor_ninth_level", 0.14))

      local cutoff = params:get("cutoff")
      local cutoff_wander = 1 + ((math.random() * 2 - 1) * amount * 0.18)
      engine_command("cutoff", util.clamp(cutoff * cutoff_wander, 80, 15000))
    end
  end
end

local function parameter_name(id)
  return params:lookup_param(id).name
end

local function parameter_string(id)
  return params:string(id)
end

function init()
  math.randomseed(os.time())
  util.make_dir(DATA_DIR)
  util.make_dir(PRESET_DIR)
  load_user_presets()

  params:add_separator("colossus_header", "COLOSSUS")

  params:add_binary("drone", "drone", "toggle", 0)
  params:set_action("drone", function(value)
    if value == 1 then start_drone() else stop_drone() end
    redraw()
  end)

  params:add_binary("freeze", "freeze", "toggle", 0)
  params:set_action("freeze", function(value)
    set_engine_parameter("freeze", value)
    redraw()
  end)

  params:add_separator("source_header", "INTERVAL MIXER")

  params:add_control(
    "root_note", "root note",
    controlspec.new(24, 72, "lin", 1, 36, "", 1 / 48)
  )
  params:add_control("root_level", "root", controlspec.new(0, 1, "lin", 0.01, 0.72))
  params:add_control("foundation", "foundation", controlspec.new(0, 1, "lin", 0.01, 0.55))
  params:add_control("fifth_level", "fifth", controlspec.new(0, 1, "lin", 0.01, 0.28))
  params:add_control("octave_level", "octave", controlspec.new(0, 1, "lin", 0.01, 0.22))
  params:add_control("minor_ninth_level", "minor ninth", controlspec.new(0, 1, "lin", 0.01, 0.08))
  params:add_control("detune", "detune", controlspec.new(0, 50, "lin", 0.1, 18, "ct"))
  params:add_control("movement", "movement", controlspec.new(0, 1, "lin", 0.01, 0.32))
  params:add_control("width", "width", controlspec.new(0, 1, "lin", 0.01, 0.82))

  params:add_separator("tone_header", "TONE")
  params:add_control("cutoff", "cutoff", controlspec.new(80, 15000, "exp", 0, 2400, "Hz"))
  params:add_control("resonance", "resonance", controlspec.new(0, 1, "lin", 0.01, 0.22))
  params:add_control("drive", "drive", controlspec.new(0.75, 4, "exp", 0, 1.35))

  params:add_separator("space_header", "SPACE")
  params:add_control("reverb_mix", "reverb", controlspec.new(0, 1, "lin", 0.01, 0.72))
  params:add_control("decay", "decay", controlspec.new(0, 1, "lin", 0.01, 0.88))
  params:add_control("damping", "damping", controlspec.new(0, 1, "lin", 0.01, 0.38))
  params:add_control("shimmer", "shimmer", controlspec.new(0, 1, "lin", 0.01, 0.30))
  params:add_control(
    "shimmer_feedback", "shimmer feedback",
    controlspec.new(0, 0.88, "lin", 0.01, 0.34)
  )
  params:add_control("output", "output", controlspec.new(0, 0.55, "lin", 0.01, 0.26))

  params:add_separator("evolve_header", "EVOLUTION")
  params:add_binary("evolve", "evolve", "toggle", 0)
  params:set_action("evolve", function(value)
    if value == 0 then
      set_engine_parameter("fifth_level", params:get("fifth_level"))
      set_engine_parameter("octave_level", params:get("octave_level"))
      set_engine_parameter("minor_ninth_level", params:get("minor_ninth_level"))
      set_engine_parameter("cutoff", params:get("cutoff"))
    end
    if not suppress_redraw then redraw() end
  end)
  params:add_control(
    "evolve_rate", "evolve interval",
    controlspec.new(8, 120, "exp", 1, 36, "s")
  )
  params:add_control(
    "evolve_amount", "evolve amount",
    controlspec.new(0, 1, "lin", 0.01, 0.35)
  )
  params:set_action("evolve_rate", function()
    if not suppress_redraw then redraw() end
  end)
  params:set_action("evolve_amount", function()
    if not suppress_redraw then redraw() end
  end)

  local direct_ids = {
    "root_note", "root_level", "foundation", "fifth_level", "octave_level",
    "minor_ninth_level", "detune", "movement", "width", "cutoff",
    "resonance", "drive", "reverb_mix", "decay", "damping", "shimmer",
    "shimmer_feedback", "output"
  }

  for _, id in ipairs(direct_ids) do
    local parameter_id = id
    params:set_action(parameter_id, function(value)
      set_engine_parameter(parameter_id, value)
      if not suppress_redraw then redraw() end
    end)
  end

  params:bang()
  evolve_clock = clock.run(evolve)
  redraw()
end

function enc(n, delta)
  if preset_mode then
    if n == 1 then
      local maximum = preset_bank == "factory" and #factory_presets or USER_PRESET_COUNT
      preset_index = util.clamp(preset_index + delta, 1, maximum)
      refresh_pending_name()
    elseif n == 2 then
      local maximum = preset_bank == "factory" and #factory_presets or USER_PRESET_COUNT
      local jump = preset_bank == "factory" and delta or (delta * 10)
      preset_index = util.clamp(preset_index + jump, 1, maximum)
      refresh_pending_name()
    elseif n == 3 then
      morph_index = util.clamp(morph_index + delta, 1, #morph_options)
    end
    redraw()
    return
  end

  if n == 1 then
    params:delta("root_note", delta)
  elseif n == 2 then
    selected = util.clamp(selected + delta, 1, #editable)
    redraw()
  elseif n == 3 then
    params:delta(editable[selected], delta)
  end
end

function key(n, z)
  if z == 1 then
    key_down_at[n] = util.time()
    return
  end

  local held = util.time() - (key_down_at[n] or util.time())
  key_down_at[n] = nil

  if preset_mode then
    if n == 1 and held < LONG_PRESS_SECONDS then
      preset_bank = preset_bank == "factory" and "user" or "factory"
      preset_index = 1
      refresh_pending_name()
    elseif n == 2 then
      if held >= LONG_PRESS_SECONDS then leave_preset_mode() else load_selected_preset() end
    elseif n == 3 then
      if held >= LONG_PRESS_SECONDS then save_selected_preset() else reroll_name() end
    end
    redraw()
    return
  end

  if n == 2 then
    if held >= LONG_PRESS_SECONDS then
      enter_preset_mode()
    else
      params:set("freeze", params:get("freeze") == 1 and 0 or 1)
    end
  elseif n == 3 and held < LONG_PRESS_SECONDS then
    toggle_drone()
  end
end

local function redraw_main()
  local id = editable[selected]
  local note_name = musicutil.note_num_to_name(params:get("root_note"), true)
  local width = 108
  local normalized = params:get_raw(id)

  screen.level(4)
  screen.move(4, 9)
  screen.text("COLOSSUS")

  screen.level(engine_missing and 15 or (playing and 15 or 4))
  screen.move(124, 9)
  screen.text_right(engine_missing and "NO ENGINE" or (playing and "ACTIVE" or "SILENT"))

  screen.level(params:get("freeze") == 1 and 15 or 3)
  screen.move(124, 21)
  screen.text_right(params:get("freeze") == 1 and "FROZEN" or "K2 FREEZE")

  screen.level(6)
  screen.move(4, 24)
  screen.text("ROOT " .. note_name)

  screen.level(5)
  screen.move(64, 36)
  screen.text_center(string.upper(parameter_name(id)))

  screen.level(15)
  screen.move(64, 49)
  screen.text_center(parameter_string(id))

  screen.level(3)
  screen.rect(10, 55, width, 5)
  screen.stroke()

  screen.level(12)
  screen.rect(10, 55, width * normalized, 5)
  screen.fill()

  screen.level(4)
  screen.move(4, 63)
  screen.text("HOLD K2 PRESETS   K3 DRONE")
end

local function redraw_presets()
  local is_factory = preset_bank == "factory"
  local maximum = is_factory and #factory_presets or USER_PRESET_COUNT
  local preset = selected_preset()
  local name = is_factory and factory_presets[preset_index].name
    or (preset ~= nil and preset.name or pending_name or "EMPTY")

  screen.level(5)
  screen.move(4, 9)
  screen.text("PRESETS / " .. string.upper(preset_bank))

  screen.level(12)
  screen.move(124, 9)
  screen.text_right(string.format("%03d/%03d", preset_index, maximum))

  screen.level(preset ~= nil and 15 or 7)
  screen.move(64, 28)
  screen.text_center(string.upper(name))

  screen.level(5)
  screen.move(64, 41)
  screen.text_center(morph_options[morph_index].name)

  if status_message ~= nil then
    screen.level(15)
    screen.move(64, 52)
    screen.text_center(status_message)
  else
    screen.level(4)
    screen.move(64, 52)
    screen.text_center(is_factory and "K1 USER" or "K1 FACTORY")
  end

  screen.level(4)
  screen.move(4, 63)
  if is_factory then
    screen.text("K2 LOAD  HOLD K2 EXIT")
  else
    screen.text("K2 LOAD K3 NAME HOLD K3 SAVE")
  end
end

function redraw()
  screen.clear()
  if preset_mode then redraw_presets() else redraw_main() end
  screen.update()
end

function cleanup()
  cancel_morph()
  if evolve_clock ~= nil then clock.cancel(evolve_clock) end
  if status_clock ~= nil then clock.cancel(status_clock) end
  engine_command("stop")
end

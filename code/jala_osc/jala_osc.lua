--
--   JALA OSC
--   0.0.7- @ulfster
--   OSC MIDI bridge version
--
--
--   K1 - ALT
--
--   K2 - toggle learning mode
--        (set MIDI in before, optional)
--   K3 - press= Pause play
--        release= play note
--
--   E1 - change root
--   ALT E1 - change scale
--   E2 - select option shortcut
--   ALT E2 - select note to edit
--   E3 - change option value
--   ALT E3 - change interval

engine.name = 'PolyPerc'
MusicUtil = require "musicutil"

options = {}
options.OUTPUT = {"audio", "osc", "audio + osc"}

--options.OUTPUT = {"audio", "midi", "audio + midi", "mx"}
--mxsamples=include("mx.samples/lib/mx.samples")
--engine.name="MxSamples"
--skeys=mxsamples:new()

function table.copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end


devicepos = 1
local mdevs = {}
local midi_device
local msg = {}

local learning = false
local play = true
local alt = false

active_notes = {}
notes = {}
scale = table.copy(MusicUtil.SCALES[1])
root = 48
possible_scales = MusicUtil.SCALES
scale_index = 1
probs = {30,10,10,10,10,10,10,10}
opt_item = 1
edit_note = 1


opt_items = {
  {id = "output", label = "output", value = function() return options.OUTPUT[params:get("output")] end},
  {id = "clock_tempo", label = "bpm", value = function() return params:get("clock_tempo") end},
  {id = "osc_ip", label = "osc ip", value = function() return params:get("osc_ip") end},
  {id = "osc_port", label = "osc port", value = function() return params:get("osc_port") end},
  {id = "osc_channel", label = "channel", value = function() return params:get("osc_channel") end},
  {id = "probability", label = "prob", value = function() return params:get("probability") end},
  {id = "octaves", label = "octaves", value = function() return params:get("octaves") end},
  {id = "step_div", label = "Steps", value = function() return params:get("step_div") end},
  {id = "note_length_min", label = "min length", value = function() return params:get("note_length_min") end},
  {id = "note_length_max", label = "max length", value = function() return params:get("note_length_max") end},
  {id = "velocity_min", label = "min velocity", value = function() return params:get("velocity_min") end},
  {id = "velocity_max", label = "max velocity", value = function() return params:get("velocity_max") end},
}

function uses_audio()
  return params:get("output") == 1 or params:get("output") == 3
end

function uses_osc()
  return params:get("output") == 2 or params:get("output") == 3
end

function osc_dest()
  return {params:get("osc_ip"), params:get("osc_port")}
end

function step_duration_ms(steps)
  local bpm = clock.get_tempo()
  local step_beats = 1 / params:get("step_div")
  return math.max(10, math.floor((60 / bpm) * step_beats * steps * 1000))
end

function osc_note(note_num, velocity, duration_steps)
  local dest = osc_dest()
  local channel = params:get("osc_channel")
  local duration_ms = step_duration_ms(duration_steps)
  print("jala_osc send", dest[1], dest[2], note_num, velocity, channel, duration_ms)
  osc.send(dest, "/midi/note", {note_num, velocity, channel, duration_ms})
end

function osc_note_off(note_num)
  local dest = osc_dest()
  osc.send(dest, "/midi/note_off", {note_num, 0, params:get("osc_channel")})
end

function all_notes_off()
  if uses_osc() then
    for i, _ in pairs(active_notes) do
      osc_note_off(i)
    end
  end
  active_notes = {}
end

function actualStep()
  if root == nil then
    return
  end
  local r = math.random(100)
  local sum = 0
  local i = 1
  while sum < r and i <= #scale.intervals do
    sum = sum + probs[i]
    i = i+1
  end
  i = i -1

  print("Notes: " .. table.concat(notes, " "))
  local note_num = root + scale.intervals[i]
  local octaves = params:get("octaves")
  if octaves > 1 then
    local o = math.random(1, octaves+1)
    if o > 2 then
      note_num = note_num + (o-2) * 12
    end
  end

  print("Play : " .. note_num)
  local freq = MusicUtil.note_num_to_freq(note_num)
  probs = new_probs(probs, i)
  local duration_min = math.min(params:get("note_length_min"), params:get("note_length_max"))
  local duration_max = math.max(params:get("note_length_min"), params:get("note_length_max"))
  local duration = math.random(duration_min, duration_max)
  active_notes[note_num] = duration - 1

  -- Audio engine out
  if uses_audio() then
    engine.hz(freq)
  end

  -- OSC MIDI bridge out
  if uses_osc() then
    local velocity_min = math.min(params:get("velocity_min"), params:get("velocity_max"))
    local velocity_max = math.max(params:get("velocity_min"), params:get("velocity_max"))
    local velocity = math.random(velocity_min, velocity_max)
    osc_note(note_num, velocity, duration)
  end
end

function step()
  while true do
    clock.sync(1/params:get("step_div"))
    check_notes = active_notes
    for n, d in pairs(active_notes) do
      if d == 0  then
        active_notes[n] = nil
      else
        active_notes[n] = d - 1
      end
    end

    if play then

      -- Trig Probablility
      if math.random(100) <= params:get("probability") then
        actualStep()
      end
    end
    redraw()
  end
end

--
-- INIT
--

function init()
  engine.amp(0.5)
  engine.release(4)

  get_midi_names()
  print_midi_names()

  params:add_separator()

  params:add{type = "option", id = "output", name = "output", default = 3,
    options = options.OUTPUT,
    action = function(value)
      all_notes_off()
    end}


  params:add{type = "number", id = "step_div", name = "step division", min = 1, max = 16, default = 1}

  params:add{type = "number", id = "probability", name = "probability",
    min = 0, max = 100, default = 100,}

  params:add{type = "number", id = "note_length_min", name = "note_length_min",
    min = 1, max = 16, default = 2,}

  params:add{type = "number", id = "note_length_max", name = "note_length_max",
    min = 1, max = 16, default = 4,}

  params:add{type = "number", id = "velocity_min", name = "velocity_min",
             min = 1, max = 128, default = 96,}

  params:add{type = "number", id = "velocity_max", name = "velocity_max",
             min = 1, max = 128, default = 96,}

  params:add{type = "number", id = "octaves", name = "octaves",
    min = 1, max = 4, default = 1,}

  params:add_separator("OSC MIDI")

  params:add_text("osc_ip", "PC IP", "192.168.178.220")
  params:add_number("osc_port", "OSC port", 1, 65535, 7123)
  params:add_number("osc_channel", "MIDI channel", 1, 16, 1)
  params:add{type = "trigger", id = "osc_test_note", name = "send OSC test note",
    action = function()
      osc_note(60, 110, 1)
    end}

  params:add_separator("MIDI Learn")

  params:add{type = "option", id = "midi_device", name = "MIDI input", options = mdevs , default = 1,
    action = function(value)
      connect_midi_input(value)
    end}

  connect_midi_input(devicepos)

  -- Render Style
  screen.level(15)
  screen.aa(0)
  screen.line_width(1)

  clock.run(step)

  norns.enc.sens(1,6)


end
-- END INIT


function get_midi_names()
  mdevs = {}
  for id,device in pairs(midi.vports) do
    mdevs[id] = device.name
  end
  if #mdevs == 0 then
    mdevs[1] = "none"
  end
end

function print_midi_names()
  print ("MIDI Inputs:")
  for id,device in pairs(midi.vports) do
    mdevs[id] = device.name
    print(id, mdevs[id])
  end
end

function connect_midi_input(id)
  midi.update_devices()
  devicepos = id
  if midi_device ~= nil then
    midi_device.event = nil
  end
  if midi.vports[id] ~= nil then
    midi_device = midi.connect(id)
    midi_device.event = midi_event
    print ("midi input ".. id .." selected: " .. mdevs[id])
  else
    midi_device = nil
    print ("no midi input selected")
  end
end

function midi_event(data)
  print("Midi event called")
  if learning == false then
    return
  end
  msg = midi.to_msg(data)
  if msg.type ~= "clock" and data[1] ~= 0xfe then
    temp_msg = {}

    print("Note pressed: " .. msg.note)

    if msg.note then
      print(table.concat(notes, "/"))
      if not contains(notes, msg.note) then
        table.insert(notes, msg.note)
        local scales = find_scale(notes)
        if scales ~= nil then
          scale = scales[1]
          print("Active scale: " .. table.concat(scale.intervals, "/"))
          root = mini(notes).min
          possible_scales = scales
        end
      end
    end

    redraw()
  end
end

function map(tbl, f)
  local t = {}
  for k,v in pairs(tbl) do
    t[k] = f(v)
  end
  return t
end

function mini(array)
  min = 10000
  ret = {}
  for i = 1, #array do
    if array[i] < min then
      min = array[i]
    end
  end
  for i = 1, #array do
    table.insert(ret, array[i] - min)
  end
  return {min = min, data = ret}
end

function find_scale(notes)
  print(notes)
  m = mini(notes)
  print(m.min)
  print(table.concat(m.data, " / "))

  scales = {}

  for i,s in pairs(MusicUtil.SCALES) do
    common = intersect(m.data, s.intervals)
    if #common == #m.data then
      table.insert(scales, s)
    end
  end

  ret = map(scales, function(item) return item.name end)
  idx = m.min % 12 + 1
  step = math.floor(m.min / 12) - 1
  print(MusicUtil.NOTE_NAMES[idx])
  print(step)
  print(table.concat(ret, "\n"))
  return scales
end

function intersect(v1 ,v2)
  local v3 = {}

  for k1,v1 in pairs(v1) do
    for k2,v2 in pairs(v2) do
      if v1 == v2 then
        v3[#v3 + 1] = v1
      end
    end
  end

  return v3
end

function contains(t, el)
  local cont = false
  for k,v in pairs(t) do
    if v == el then
      cont = true
    end
  end
  return cont
end


function create_probs(notes)
  if notes == 8 then
    return {30,10,10,10,10,10,10,10}
  elseif notes == 9 then
    return {20,10,10,10,10,10,10,10,10}
  elseif notes == 6 then
    return {30,10,20,10,20,10}
  elseif notes == 13 then
    return {15,5,10,5,10,5,15,5,10,5,10,5,0}
  elseif notes == 5 then
    return {30,10,20,20,20}
  end

  local generated = {}
  local base = math.floor(100 / notes)
  local remainder = 100 - (base * notes)
  for i = 1, notes do
    generated[i] = base + (i <= remainder and 1 or 0)
  end
  return generated
end


function key(n, z)
  if n==2 and z == 1 then
    if learning then
      -- Now, set the scale to be played
      if possible_scales[scale_index] ~= nil then
        scale = table.copy(possible_scales[scale_index])
        probs = create_probs(#scale.intervals)
      else
        scale = table.copy(MusicUtil.SCALES[1])
        possible_scales = MusicUtil.SCALES
        probs = create_probs(#scale.intervals)
        root = 48
      end
      play = true
      learning = false
    else
      notes = {}
      possible_scales = {}
      learning = true
      connect_midi_input(devicepos)
    end
  end
  if n == 3 and z == 1 then
    play = false
  end
  if n == 3 and z == 0 then
    play = true
    actualStep()
  end
  if n == 1 and z == 1 then
    alt = true
  end
  if n == 1 and z == 0 then
    alt = false
  end
  redraw()
end

function enc(id,delta)
  if id == 1 then
    if alt then
      scale_index = scale_index + delta
      if scale_index < 1 then
        scale_index = 1
      end
      if scale_index > #possible_scales then
        scale_index = #possible_scales
      end

      scale = table.copy(possible_scales[scale_index])
      probs = create_probs(#scale.intervals)
    else
      root = root + delta
    end
  end
  if id == 2 then
    if learning then
      scale_index = scale_index + delta
      if scale_index < 1 then
        scale_index = 1
      end
      if scale_index > #possible_scales then
        scale_index = #possible_scales
      end
    elseif alt == true then
      edit_note = edit_note + delta
      if edit_note < 1 then
        edit_note = 1
      end
      if edit_note > #scale.intervals then
        edit_note = #scale.intervals
      end
    else
      opt_item = opt_item + delta
      if opt_item < 1 then
        opt_item = 1
      elseif  opt_item > #opt_items then
        opt_item = #opt_items
      end
    end
  end
  if id == 3 then
    if alt == true and edit_note > 1 then
      if scale.name ~= "Custom" then
        scale = { name = "Custom", intervals = table.copy(scale.intervals) }
      end
      scale.intervals[edit_note] = scale.intervals[edit_note] + delta
    else
      params:delta(opt_items[opt_item].id, delta)
    end
  end

  redraw()
end


function redraw()
  tempo_disp = util.round (clock.get_tempo(), 1)

  screen.clear()

  screen.level(3)
  screen.move(90,7)
  screen.text('bpm')
  screen.move(110,7)
  screen.text(tempo_disp)
  screen.stroke()

  if learning then
      screen.level(1)
      screen.circle(126, 5, 2)
      screen.fill()
      screen.move(0, 7)
      screen.text(table.concat(map(notes, function(x) return MusicUtil.NOTE_NAMES[x % 12 + 1] end), "-"))

      screen.move(0, 20)
      for i,s in pairs(possible_scales) do
        if i == scale_index then
          screen.level(12)
        else
          screen.level(2)
        end
        screen.move(0,20 + (i-1) *8)
        screen.text(s.name)
      end

  else
      screen.level(1)
      if play then
      else
        screen.stroke()
        screen.rect(124, 3, 1, 4)
        screen.rect(126, 3, 1, 4)
      end
      screen.move(0, 7)
      local scalename = ""
      if scale ~= nil then
        scalename = scale.name
      end

      if root ~= nil then
        local level = math.floor(root / 12) - 1
        screen.text(MusicUtil.NOTE_NAMES[root % 12 + 1] .. level .." " .. scalename)
        end

      if scale ~= nil then
        add = 0
        per_row = math.ceil(#scale.intervals / 2)
        width = 128 / per_row
        for i, steps in pairs(scale.intervals) do
           local level = math.floor((root + steps) / 12) - 1

           add = add + steps
           local x = 2 + ((i-1) % per_row) * width
           local y = 20 + math.floor((i-1) / per_row) * 20
           if active_notes[root + steps] ~= nil and active_notes[root + steps] > 0 then
             screen.level(15)
           else
             screen.level(1)
           end
           screen.move(x, y)
           screen.text(MusicUtil.NOTE_NAMES[(root + steps) % 12 + 1] .. level)
--           screen.move(x, y + 9)
--           screen.text(probs[i] .. "%")
           screen.rect(x, y + 3, math.ceil(probs[i] / 2), 2)
           screen.fill()

            if alt == true and edit_note == i then
              screen.rect(x-1, y-6, width-5, 14)
             screen.stroke()

            end

        end
      end

      showOptions()
  end

  screen.level(1)
  screen.line_width (1)
  screen.move(0, 10)
  screen.line (128, 10)
  screen.stroke()

  screen.move(0, 50)
  screen.line (128, 50)
  screen.stroke()

  --screen.line_width (1)
  --screen.move(116, 10)
  --screen.line (116, 64)
  --screen.stroke()

  screen.update()
end

function showOptions()
    screen.level(2)
    screen.move(2, 60)
    screen.text(opt_items[opt_item].label)
    screen.move(62, 60)
    screen.text(opt_items[opt_item].value())
  end

--
-- Utils
--

function truncate_txt(txt, size)
  if string.len(txt) > size then
    s1 = string.sub(txt, 1, 9) .. "..."
    s2 = string.sub(txt, string.len(txt) - 5, string.len(txt))
    s = s1..s2
  else
    s = txt
  end
  return s
end

function note_to_hz(note)
  return (440 / 32) * (2 ^ ((note - 9) / 12))
end

function new_probs(probs, selected)
  local share = math.floor(probs[selected] / 2)
  local items = #probs - 1

  probs[selected] = probs[selected] - share

  for i,p in pairs(probs) do
    if share <= 0 then
      break
    end
    if i ~= selected then
      local add = math.random(share)
      share = share - add
      probs[i] = p + add
    end
  end

  probs[#probs] = probs[#probs] + share

  return probs
end

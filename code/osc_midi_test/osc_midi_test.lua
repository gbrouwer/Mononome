-- OSC MIDI Test
-- Minimal norns -> PC OSC sender for tools/osc-midi-bridge.ps1.
--
-- K2: play/stop
-- K3: send one note
-- E1: root note
-- E2: step division
-- E3: velocity

engine.name = "PolyPerc"

local musicutil = require("musicutil")

local running = false
local step = 1
local pattern = {0, 2, 4, 7, 9, 12, 9, 7}
local dest = {"127.0.0.1", 7123}

local function refresh_dest()
  dest = {params:get("pc_ip"), params:get("osc_port")}
end

local function note_name(note)
  return musicutil.note_num_to_name(note, true)
end

local function send_note(note)
  refresh_dest()
  local velocity = params:get("velocity")
  local channel = params:get("channel")
  local duration_ms = params:get("duration_ms")
  print("osc_midi_test send", dest[1], dest[2], note, velocity, channel, duration_ms)
  osc.send(dest, "/midi/note", {note, velocity, channel, duration_ms})
  engine.hz(musicutil.note_num_to_freq(note))
end

local function current_note()
  return util.clamp(params:get("root_note") + pattern[step], 0, 127)
end

local function advance()
  step = step % #pattern + 1
end

local function play_loop()
  while true do
    if running then
      send_note(current_note())
      advance()
    end
    clock.sync(1 / params:get("division"))
  end
end

local function add_params()
  params:add_separator("OSC MIDI Test")

  params:add_text("pc_ip", "PC IP", "192.168.178.220")
  params:add_number("osc_port", "OSC port", 1, 65535, 7123)
  params:add_number("channel", "MIDI channel", 1, 16, 1)
  params:add_number("root_note", "Root note", 0, 127, 48)
  params:add_number("division", "Step division", 1, 16, 4)
  params:add_number("velocity", "Velocity", 1, 127, 96)
  params:add_number("duration_ms", "Duration ms", 10, 4000, 180)
end

function init()
  add_params()
  engine.amp(0.25)
  engine.release(0.12)
  clock.run(play_loop)
  redraw()
end

function enc(n, d)
  if n == 1 then
    params:delta("root_note", d)
  elseif n == 2 then
    params:delta("division", d)
  elseif n == 3 then
    params:delta("velocity", d)
  end
  redraw()
end

function key(n, z)
  if z == 1 and n == 2 then
    running = not running
  elseif z == 1 and n == 3 then
    send_note(current_note())
    advance()
  end
  redraw()
end

function redraw()
  screen.clear()
  screen.level(15)
  screen.move(0, 10)
  screen.text("OSC MIDI Test")

  screen.level(running and 15 or 4)
  screen.move(0, 24)
  screen.text(running and "playing" or "stopped")

  screen.level(10)
  screen.move(0, 38)
  screen.text("note " .. note_name(current_note()))
  screen.move(0, 50)
  screen.text("div " .. params:get("division") .. " vel " .. params:get("velocity"))
  screen.move(0, 62)
  screen.text(params:get("pc_ip") .. ":" .. params:get("osc_port"))
  screen.update()
end

-- repeater
-- repeater orchestra for norns
-- v1.1
--
-- multiple tempo-synced delays
-- with random timing, gain, pan
--
-- K1: shift
-- K2: toggle gate (mic on/off)
-- K3: toggle freeze (infinite repeats)
-- K1+K3: clear delays
-- E1: dry/wet mix
-- E2: input gain
-- K1+E2: output gain
-- E3: tempo
-- K1+E3: num delays

engine.name = "Repeater"

local repeater = include("repeater/lib/repeater_engine")

-- State
local gate_on = false
local freeze_on = false
local shift = false
local screen_dirty = true

function init()
  -- Add engine params
  repeater.add_params()

  -- Disable system monitoring so we can control dry/wet mix in engine
  -- We try both the audio API and the system parameter
  audio.level_monitor(0)
  if params:lookup_param("monitor_level") then
    params:set("monitor_level", -99) -- Set to minimum (dB)
  end

  -- Initialize
  repeater.gate(0)
  repeater.freeze(0)

  -- Clock Sync
  -- Default to 80 BPM if not set (or whatever the system clock is)
  -- The system clock will handle MIDI/Link sync automatically
  clock.tempo_change_handler = function(bpm)
    repeater.tempo(bpm)
    screen_dirty = true
  end
  
  -- Force initial sync
  repeater.tempo(clock.get_tempo())

  -- Load saved params
  params:bang()

  -- Screen refresh metro
  local screen_metro = metro.init()
  screen_metro.time = 1/15
  screen_metro.event = function()
    if screen_dirty then
      redraw()
      screen_dirty = false
    end
  end
  screen_metro:start()
end

function key(n, z)
  if n == 1 then
    shift = z == 1
    screen_dirty = true
  elseif z == 1 then  -- key pressed
    if n == 2 then
      -- Toggle gate
      gate_on = not gate_on
      repeater.gate(gate_on and 1 or 0)
      screen_dirty = true
    elseif n == 3 then
      if shift then
        -- Shift+K3: Clear delays, turn off gate and freeze
        gate_on = false
        freeze_on = false
        repeater.gate(0)
        repeater.freeze(0)
        repeater.clear()
        screen_dirty = true
      else
        -- Toggle freeze
        freeze_on = not freeze_on
        repeater.freeze(freeze_on and 1 or 0)
        screen_dirty = true
      end
    end
  end
end

function enc(n, d)
  if shift then
    if n == 2 then
      -- Output Gain (Master)
      params:delta("master_gain", d)
    elseif n == 3 then
      -- Number of delays
      params:delta("n_delays", d)
    end
  else
    if n == 1 then
      -- Dry/Wet Mix
      params:delta("mix", d)
    elseif n == 2 then
      -- Input gain
      params:delta("input_gain", d)
    elseif n == 3 then
      -- Tempo (Global Clock)
      params:delta("clock_tempo", d)
    end
  end
  screen_dirty = true
end

function redraw()
  screen.clear()
  screen.font_size(8)

  -- Top Center: Mix (E1)
  screen.level(15)
  screen.move(64, 10)
  screen.text_center("MIX " .. string.format("%.0f%%", params:get("mix") * 100))

  -- Title
  screen.level(3)
  screen.move(64, 25)
  screen.text_center("REPEATER")

  -- LEFT COLUMN (Gate, Input, Output)
  screen.move(0, 40)
  screen.level(gate_on and 15 or 3)
  screen.text("GATE")

  -- Input (E2) - highlight when NOT shifted
  screen.move(0, 52)
  screen.level(not shift and 15 or 3)
  screen.text("IN: " .. string.format("%.2f", params:get("input_gain")))

  -- Output (Shift+E2) - highlight when shifted
  screen.move(0, 64)
  screen.level(shift and 15 or 3)
  screen.text("OUT: " .. string.format("%.2f", params:get("master_gain")))


  -- RIGHT COLUMN (Freeze, BPM, Delays)
  screen.move(128, 40)
  screen.level(freeze_on and 15 or 3)
  screen.text_right("FREEZE")

  -- BPM (E3) - highlight when NOT shifted
  screen.move(128, 52)
  screen.level(not shift and 15 or 3)
  screen.text_right("BPM: " .. math.floor(clock.get_tempo()))

  -- Delays (Shift+E3) - highlight when shifted
  screen.move(128, 64)
  screen.level(shift and 15 or 3)
  screen.text_right("DELAYS: " .. params:get("n_delays"))

  screen.update()
end

function cleanup()
  repeater.gate(0)
  repeater.freeze(0)
  
  -- Restore system monitor on exit
  audio.level_monitor(1)
  if params:lookup_param("monitor_level") then
    params:set("monitor_level", 0) -- Set to 0dB (default)
  end
end

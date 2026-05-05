-- repeater_engine.lua
-- Lua wrapper for Engine_Repeater

local ControlSpec = require "controlspec"

local Repeater = {}

-- Engine command wrappers
function Repeater.gate(val)
  engine.gate(val)
end

function Repeater.freeze(val)
  engine.freeze(val)
end

function Repeater.input_gain(val)
  engine.inputGain(val)
end

function Repeater.master_gain(val)
  engine.masterGain(val)
end

function Repeater.mix(val)
  engine.dryWet(val)
end

function Repeater.tempo(val)
  engine.tempo(val)
end

function Repeater.n_delays(val)
  engine.nDelays(val)
end

function Repeater.randomize()
  engine.randomize()
end

function Repeater.clear()
  engine.clear()
end

-- Add parameters to norns param system
function Repeater.add_params()
  params:add_separator("repeater", "REPEATER")

  params:add{
    type = "number",
    id = "n_delays",
    name = "num delays",
    min = 1,
    max = 50,
    default = 20,
    action = function(x) Repeater.n_delays(x) end
  }

  params:add{
    type = "control",
    id = "input_gain",
    name = "input gain",
    controlspec = ControlSpec.new(0, 1, "lin", 0.01, 0.5),
    action = function(x) Repeater.input_gain(x) end
  }

  params:add{
    type = "control",
    id = "master_gain",
    name = "master gain",
    controlspec = ControlSpec.new(0, 1, "lin", 0.01, 0.5),
    action = function(x) Repeater.master_gain(x) end
  }

  params:add{
    type = "control",
    id = "mix",
    name = "dry/wet mix",
    controlspec = ControlSpec.new(0, 1, "lin", 0.01, 1.0),
    action = function(x) Repeater.mix(x) end
  }

  params:add{
    type = "trigger",
    id = "randomize",
    name = "randomize delays",
    action = function() Repeater.randomize() end
  }

  params:add{
    type = "trigger",
    id = "clear",
    name = "clear delays",
    action = function() Repeater.clear() end
  }
end

return Repeater

local presets = 8
local modenames = {}

local states = {}
local function state(pre)
    return states[pre][states[pre].mode]
end

local modes = {}
local function mode(pre)
    return modes[math.floor(states[pre].mode)]
end

local scale_names = {}

local function init_state()
    for i = 1, presets do
        states[i] = {
            mode = 1, --12tet
            tonic = 1, --C
        }
        for ii,vv in pairs(modes) do
            states[i][ii] = {
                scale = 1,
                tuning = {},
                toggles = {}
            }
            for iii,vvv in ipairs(modes[ii].scales) do
                states[i][ii].tuning[iii] = 1
                states[i][ii].toggles[iii] = {}
                for iiii, vvvv in ipairs(modes[ii].scales[iii].iv) do
                    states[i][ii].toggles[iii][iiii] = 1
                end
            end
        end
    end
end

local tonics = {}
for i = 1, 12 do
    local n = i - 9 - 1 -- start from C below middle A
    tonics[i] = n
end
local function tonic(pre)
    return tonics[states[pre].tonic]
end

local function tuning(pre)
    local scl = state(pre).scale
    return state(pre).tuning[scl]
end

local function intervals(pre)
    local scl = state(pre).scale
    local all = mode(pre).scales[scl].iv

    local some = {}
    for i,v in ipairs(all) do
        if state(pre).toggles[scl][i] > 0 then 
            table.insert(some, v)
        end
    end
    if #some == 0 then table.insert(some, all[1]) end
    return some
end

local tune = {}

tune.get_intervals = intervals

tune.wrap = function(deg, oct, pre)
    local iv = intervals(pre)

    oct = oct + (deg-1)//#iv + 1
    deg = (deg - 1)%#iv + 1

    return deg, oct
end

--TODO: start row wrapping in the middle of the grid vertically somehow
tune.degoct = function(row, column, pre, trans, toct)
    local iv = intervals(pre)
    local rowint = tuning(pre) - 1
    if rowint == 0 then rowint = #iv end

    local deg = (trans or 0) + row + ((column-1) * (rowint))
    local oct = (toct or 0) - 5
    deg, oct = tune.wrap(deg, oct, pre)
    
    return deg, oct
end

tune.is_tonic = function(row, column, pre, trans)
    return tune.degoct(row, column, pre, trans) == 1
end

--number to be multiplied by center freq in hz
tune.hz = function(row, column, trans, toct, pre)
    local iv = intervals(pre)
    local deg, oct = tune.degoct(row, column, pre, trans, toct)

    return (
        2^(tonic(pre)/(mode(pre).tones or 12)) * 2^oct 
        * (
            (mode(pre).temperment == 'just') 
            and (mode(pre).ratios[iv[deg] + 1])
            or (2^(iv[deg]/mode(pre).tones))
        )
    )
end

--TODO
tune.volts = function() end

--TODO
tune.midi = function() end

tune.setup = function(arg)
    presets = arg.presets or presets
    modes = arg.scales

    for i,v in pairs(modes) do 
        modenames[i] = v.name
        
        scale_names[i] = {}
        for ii, vv in ipairs(v.scales) do
            scale_names[i][ii] = vv.name
        end
    end

    init_state()

    return tune
end

tune.read = function(path)
    local t, err = tab.load(path)
    if t then states = t else print(err) end
end

tune.write = function(path)
    print(tab.save(states, path..'tune.data'))
end

------------------------------- UI components ----------------------------------

local Tune = { grid = {}, norns = {} }

local x, y
do
    local top, bottom = 10, 64-6
    local left, right = 4, 128-4
    local mul = { x = (right - left) / 2, y = (bottom - top) / 2 }
    x = { left, left + mul.x*5/4, [1.5] = 24  }
    y = { top, bottom - mul.y*1/2, [1.5] = 20 }
end

-- https://stackoverflow.com/questions/43565484/how-do-you-take-a-decimal-to-a-fraction-in-lua-with-no-added-libraries
local function to_frac(num)
    local W = math.floor(num)
    local F = num - W
    local pn, n, N = 0, 1
    local pd, d, D = 1, 0
    local x, err, q, Q
    repeat
        x = x and 1 / (x - q) or F
        q, Q = math.floor(x), math.floor(x + 0.5)
        pn, n, N = n, q*n + pn, Q*n + pn
        pd, d, D = d, q*d + pd, Q*d + pd
        err = F - N/D
   until math.abs(err) < 1e-15

   return N + D*W, D, err
end

local kb = {}
kb.grid = {
      { 05, 07, 00, 10, 12, 02, },
    { 04, 06, 08, 09, 11, 01, 03, }
}
kb.pos = {}
for i = 1,12 do
    for y = 1,2 do
        for x,v in ipairs(kb.grid[y]) do
            if i == v then
                kb.pos[i] = { x=x, y=y }
                kb.pos[i+0.5] = { x=x, y=y }
            end
        end
    end
end

local iv_names = {
    'octaves',
    "min 2nds", "maj 2nds",
    "min 3rds", "maj 3rds", "4ths",
    "tritones", "5ths", "min 6ths",
    "maj 6ths", "min 7ths", "maj 7ths",
}

-- ^ for half flat/sharp
local note_names = {
    [1] = 'A', [1.5] = 'A^#', 
    [2] = 'A#', [2.5] = 'B^b', 
    [3] = 'B', [3.5] = 'B^#', 
    [4] = 'C', [4.5] = 'C^#', 
    [5] = 'C#', [5.5] = 'D^b', 
    [6] = 'D', [6.5] = 'D^#', 
    [7] = 'D#', [7.5] = 'E^b',
    [8] = 'E',  [8.5] = 'E^#', 
    [9] = 'F', [9.5] = 'F^#', 
    [10] = 'F#', [10.5] = 'G^b', 
    [11] = 'G', [11.5] = 'G^#', 
    [12] = 'G#', [12.5] = 'A^b',
}
local tonic_names = {}
for i = 4, 15 do table.insert(tonic_names, note_names[(i-1)%12+1]) end

local function KeyboardBackground(args)
    local left, top = args.left or 1, args.top or 1
    local width = args.width or 16

    return function(props)
        local lvl = 4

        local g = nest.grid.device()

        if nest.grid.is_drawing() then
            for i = 1,12 do
                local pos = kb.pos[i]

                g:led(left + pos.x - 1, top + pos.y - 1, lvl)
            end
        end
    end
end

function Tune.grid.scale_degrees(args)
    local left, top = args.left or 1, args.top or 1
    local width = args.width or 16

    local _bg = KeyboardBackground({ left = left, top = top, width = width })

    local _mutes = {}
    for i = 1, 24 do _mutes[i] = Grid.toggle() end

    return function(props)
        props.preset = props.preset or 1
        local p = props.preset

        _bg()

        for i,_mute in ipairs(_mutes) do
            local ii = i/2 + 0.5

            local scl = state(p).scale
            local ivs = mode(p).scales[scl].iv
            local iv = (ii-1-tonic(p))%12
            local deg = tab.key(ivs, iv)
            local is_interval = tab.contains(ivs, iv)

            if is_interval then _mute{
                x = left + kb.pos[ii].x - 1,
                y = top + kb.pos[ii].y - 1,
                lvl = { 8, 15 },
                state = {
                    deg and state(p).toggles[scl][deg] or 0,
                    function(v)
                        if deg then state(p).toggles[scl][deg] = v end
                        nest.screen.make_dirty()
                    end
                },
            } end
        end
    end
end

function Tune.grid.tonic(args)
    local left, top = args.left or 1, args.top or 1
    local width = args.width or 16

    local _bg = KeyboardBackground({ left = left, top = top, width = width })

    local _toggles = {}
    for i = 1, 12 do _toggles[i] = Grid.toggle() end

    return function(props)
        props.preset = props.preset or 1
        local p = props.preset

        _bg()

        for i,_toggle in ipairs(_toggles) do
            _toggle{
                x = left + kb.pos[i].x - 1,
                y = top + kb.pos[i].y - 1,
                lvl = { 0, 15 },
                state = {
                    states[p].tonic == (i - 4)%12+1 and 1 or 0,
                    function(v)
                        if v > 0 then
                            states[p].tonic = (i - 4)%12+1
                            nest.screen.make_dirty()
                        end
                    end
                }
            }
        end
    end
end

function Tune.norns.scale_degrees(args)
    local _labels = {}
    for i = 1, 24 do _labels[i] = Text.label() end

    return function(props)
        props.preset = props.preset or 1
        local i = props.preset

        for ii2,_label in ipairs(_labels) do
            local ii = ii2/2 + 0.5

            local mul = 10
            local p = kb.pos[ii]
            local xx = 4 + (p.x - 1) * 20
            local yy = y[1.5] + (p.y - 1) * 10

            local ji = mode(i).temperment == 'just'
            local scl = state(i).scale
            local ivs = mode(i).scales[scl].iv
            local iv = (ii-1-tonic(i))%12
            local st = (iv+tonic(i))%12+1
            local deg = tab.key(ivs, iv)

            local is_interval = tab.contains(ivs, iv)
            local is_enabled = deg and (state(i).toggles[scl][deg] == 1)
            local is_tonic = iv==0

            _label{
                x = xx, y = yy, 
                padding = 1.5,
                font_face = 2,
                lvl = is_tonic and 0 or (is_interval and is_enabled) and 15  or 2,
                fill = (is_interval and is_enabled and is_tonic) and 10  or 0,
                label = (
                    tab.contains(ivs, iv) and (  
                        ji and (
                            string.format(
                                "%d/%d",
                                to_frac(mode(i).ratios[iv+1])
                            )
                        ) or (
                            note_names[st]
                        )
                    ) or '.'
                )
            }
        end
    end
end

function Tune.norns.options(args)
    _mode = Text.enc.number()
    _scale = Text.enc.number()
    _tuning = Text.enc.number()

    return function(props)
        props.preset = props.preset or 1
        local i = props.preset

        _mode{
            x = x[1], y = y[2], n = 2, wrap = true,
            min = 1, step = 1, inc = 1, max = #modenames, flow = 'y',
            label = 'tuning',
            formatter = function()
                return modenames[states[i].mode]
            end,
            value = function() return  end,
            state = {
                states[i].mode,
                function(v) 
                    states[i].mode = v 
                    nest.grid.make_dirty()
                end
            }
        }
        _scale{
            x = x[1], y = y[1], n = 1, wrap = true,
            min = 1, step = 1, inc = 1, 
            max = #scale_names[states[i].mode],
            label = 'scale',
            formatter = function(v)
                return scale_names[states[i].mode][v]
            end,
            state = { 
                state(i).scale,
                function(v)
                    state(i).scale = v
                    nest.grid.make_dirty()
                end
            }
        }
        _tuning{
            x = x[2], y = y[2], n = 3, flow = 'y',
            min = 1, max = 12, step = 1, inc = 1,
            label = 'rows',
            formatter = function(v)
                local deg
                local iv = intervals(i)
                local deg = iv[(v-1)%#iv+1]

                return iv_names[deg+1]
            end,
            state = {
                state(i).tuning[state(i).scale],
                function(v)
                    state(i).tuning[state(i).scale] = v
                    nest.grid.make_dirty()
                end
            }
        }
    end
end

print('Tune', Tune)

return tune, Tune

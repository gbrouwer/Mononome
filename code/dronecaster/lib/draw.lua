-- init
--------------------------------------------------------------------------------

local draw = {}

-- debug mode (toggle via params)
draw.DEBUG = false

-- Scene system: allows multiple visual styles (classic, mountain, etc.)
-- Each scene is a separate module with its own render function
local scenes = {}
local current_scene = nil
local scene_names = {}

-- shared screen levels
local screen_levels = {}

-- ui elements
local alert_x = 20
local alert_y = 40
local alert_w = 87
local alert_h = 12

function draw.init()
  if draw.DEBUG then print("draw.init: starting") end
  screen_levels["o"] = 0
  screen_levels["l"] = 5
  screen_levels["m"] = 10
  screen_levels["h"] = 15

  if draw.DEBUG then print("draw.init: loading scenes") end
  -- load all scene modules
  draw.load_scenes()
  if draw.DEBUG then print("draw.init: complete") end
end

function draw.load_scenes()
  if draw.DEBUG then print("draw.load_scenes: starting") end

  -- Provide utility functions to scenes for shared drawing operations
  local utils = {
    mlrs = draw.mlrs,
    mls = draw.mls,
    screen_levels = screen_levels,
    DEBUG = function() return draw.DEBUG end
  }

  if draw.DEBUG then print("draw.load_scenes: loading classic") end
  -- Load classic scene (original dronecaster graphics)
  local success, classic = pcall(include, "lib/scenes/classic")
  if success and classic then
    -- Protected call to scene init to catch any errors
    local init_success, init_error = pcall(classic.init, utils)
    if init_success then
      scenes["Classic"] = classic
      table.insert(scene_names, "Classic")
      current_scene = classic
      if draw.DEBUG then print("draw: loaded Classic scene") end
    else
      print("draw: ERROR initializing Classic scene: " .. tostring(init_error))
    end
  else
    print("draw: ERROR loading Classic scene file: " .. tostring(classic))
  end

  if draw.DEBUG then print("draw.load_scenes: loading mountain") end
  -- Load mountain scene (bitmap-optimized Mt. Zion visuals)
  local success, mountain = pcall(include, "lib/scenes/mountain/mountain")
  if success and mountain then
    -- Protected call to scene init to catch any errors
    local init_success, init_error = pcall(mountain.init, utils)
    if init_success then
      scenes["Mountain"] = mountain
      table.insert(scene_names, "Mountain")
      if draw.DEBUG then print("draw: loaded Mountain scene") end
    else
      print("draw: ERROR initializing Mountain scene: " .. tostring(init_error))
    end
  else
    print("draw: ERROR loading Mountain scene file: " .. tostring(mountain))
  end

  if draw.DEBUG then print("draw.load_scenes: complete, loaded " .. #scene_names .. " scenes") end
end

function draw.get_scene_names()
  return scene_names
end

function draw.set_scene(name)
  if scenes[name] then
    current_scene = scenes[name]
  end
end

-- utils
--------------------------------------------------------------------------------

function draw.mlrs(a, b, c, d)
  screen.move(a, b)
  screen.line_rel(c, d)
  screen.stroke()
end

function draw.mls(a, b, c, d)
  screen.move(a, b)
  screen.line(c, d)
  screen.stroke()
end

function draw.get_screen_level(s)
  return screen_levels[s]
end

-- main render function (delegates to active scene)
--------------------------------------------------------------------------------

function draw.render(playing_frame, recording_time, drone_name, hz, amp, playing, alt, alert, hz_num, amp_num)
  -- Protected call to scene render to prevent crashes from scene errors
  if current_scene and current_scene.render then
    local success, error_msg = pcall(current_scene.render, playing_frame, recording_time, drone_name, hz, amp, playing, alt, alert, hz_num, amp_num)
    if not success then
      -- Clear error logging to help debug scene issues
      print("===================================")
      print("SCENE RENDER ERROR:")
      print(tostring(error_msg))
      print("Scene: " .. (current_scene.name or "unknown"))
      print("===================================")
      -- Fallback: show error on screen so user knows
      screen.level(15)
      screen.move(64, 32)
      screen.text_center("SCENE ERROR")
    end
  end
  
  -- Always draw HUD elements (shared across all scenes)
  draw.top_menu(drone_name .. " " .. hz .. " " .. amp, alt)
  draw.clock(recording_time)
  draw.play_stop(playing)
  
  if (alert["recording"]) then
    alert = draw.alert_recording(alert, messages)
  end
  if (alert["casting"]) then
    alert = draw.alert_casting(alert, messages)
  end
  
  return alert
end



-- ui
--------------------------------------------------------------------------------

function draw.top_menu(hud, alt)
  if not alt then
    screen.level(screen_levels["h"])
    screen.move(2, 8)
    screen.text(hud)
  else
    screen.level(screen_levels["h"])    
    screen.rect(0, 0, 128, 11)
    screen.fill()
    screen.level(screen_levels["o"])
    screen.move(2, 8)
    screen.text(hud)
  end
end

function draw.play_stop(playing)
  screen.level(screen_levels["l"])
  if playing == true then
    draw.mls(121, 59, 121, 64)
    draw.mls(122, 60, 122, 63)
    draw.mls(123, 61, 123, 62)
  else
    draw.mls(120, 59, 120, 64)
    draw.mls(121, 59, 121, 64)
    draw.mls(122, 59, 122, 64)
    draw.mls(123, 59, 123, 64)
    draw.mls(124, 59, 124, 64)
  end
end

function draw.clock(recording_time)
  screen.level(screen_levels["l"])
  screen.move(2, 64)
  screen.text(util.s_to_hms(recording_time))
end

function draw.alert_casting(alert, messages)
  alert_window()
  alert_message(alert["casting_message"])
  alert["casting_frame"] = alert["casting_frame"] + 1
  if (alert["casting_frame"] == 15) then
    alert["casting"] = false
    alert["casting_frame"] = 0
    alert["casting_message"] = messages["empty"]
  end
  return alert
end

function draw.alert_recording(alert, messages)
  alert_window()
  alert_message(alert["recording_message"])
  alert["recording_frame"] = alert["recording_frame"] + 1
  if (alert["recording_frame"] == 5) then
    alert["recording"] = false
    alert["recording_frame"] = 0
    alert["recording_message"] = messages["empty"]
  end
  return alert
end

function alert_window()
  screen.rect(alert_x, alert_y, alert_w, alert_h)
  screen.level(screen_levels["h"])
  screen.stroke()
  screen.rect(alert_x, alert_y, alert_w - 1, alert_h - 1)
  screen.level(screen_levels["o"])
  screen.fill()
end

function alert_message(x)
  screen.move((alert_x + (alert_w / 2)), (alert_y + (alert_h / 2) + 2))
  screen.level(screen_levels["l"])
  screen.text_center(x)
end

-- return
--------------------------------------------------------------------------------

return draw
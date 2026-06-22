-- classic scene (original dronecaster graphics)
--------------------------------------------------------------------------------

local classic = {}

classic.name = "Classic"

-- state variables
local last_drift = 0
local last_wind = 0
local bird_home_x = 25
local bird_home_y = 25
local drift_min_x = bird_home_x - 5
local drift_min_y = bird_home_y - 3
local drift_max_x = bird_home_x + 5
local drift_max_y = bird_home_y + 3
local this_drift_x = bird_home_x
local this_drift_y = bird_home_y
local unidentified_aerial_phenomenon = false

-- drawing utilities (will be provided by draw.lua)
local mlrs, mls, screen_levels

function classic.init(utils)
  -- receive utility functions from draw.lua
  mlrs = utils.mlrs
  mls = utils.mls
  screen_levels = utils.screen_levels
end

-- internal helper functions
--------------------------------------------------------------------------------

local function drift(playing_frame)
  if last_drift == playing_frame then
    return
  else
    last_drift = playing_frame
    local x_coin = math.random(0, 1)
    local y_coin = math.random(0, 1)
    local this_or_that = math.random(0, 1)
    local that_or_this = math.random(0, 1)
    local check_x, check_y
    if this_or_that == 0 then
      check_x = (x_coin * -1) + this_drift_x
    else
      check_x = x_coin + this_drift_x
    end
    if that_or_this == 0 then
      check_y = (y_coin * -1) + this_drift_y
    else
      check_y = y_coin + this_drift_y
    end
    if (check_x > drift_max_x) then
      this_drift_x = drift_max_x
    elseif  (check_x < drift_min_x) then
      this_drift_x = drift_min_x
    else
      this_drift_x = check_x
    end
    if (check_y > drift_max_y) then
      this_drift_y = drift_max_y
    elseif  (check_y < drift_min_y) then
      this_drift_y = drift_min_y
    else
      this_drift_y = check_y
    end
  end
end

local function light_one() mlrs(62, 25, 1, 1) end
local function light_two() mlrs(65, 17, 1, 0) end
local function light_three() mlrs(69, 23, 1, 1) end
local function light_all() light_one() light_two() light_three() end
local function flare_one(x) screen.circle(62, 25, x) screen.stroke() end
local function flare_two(x) screen.circle(65, 17, x) screen.stroke() end
local function flare_three(x) screen.circle(69, 23, x) screen.stroke() end

-- drawing functions
--------------------------------------------------------------------------------

local function draw_lights(playing_frame)
  screen.level(screen_levels["l"])
  local light_frame = playing_frame % 9
  if light_frame == 1 then
    light_all()
  elseif light_frame == 2 then
    light_two()
    flare_two(2)
    light_three()
  elseif light_frame == 3 then
    flare_two(3)
    light_all()
  elseif light_frame == 4 then
    flare_one(2)
    flare_two(4)
    light_three()
  elseif light_frame == 5 then
    light_all()
  elseif light_frame == 6 then
    light_two()
  elseif light_frame == 7 then
    light_one()
    light_three()
    flare_three(5)
  elseif light_frame == 8 then
    light_all()
    flare_three(3)
  elseif light_frame == 9 then
    light_two()
  else
    light_all()
  end
end

local function draw_uap(playing_frame, playing)
  local luck = math.random(0, 7)
  local uap_frame = playing_frame % 5
  if playing and (luck == 3) and (unidentified_aerial_phenomenon == false) then
    unidentified_aerial_phenomenon = true
  end
  if (unidentified_aerial_phenomenon) then
    if uap_frame == 1 then
      mls(100, 18, 98, 20)
    elseif uap_frame == 2 then
      mls(100, 18, 90, 25)
    elseif uap_frame == 3 then
      mls(94, 22, 89, 26)
    elseif uap_frame == 4 then
      mls(88, 26, 86, 28)
    elseif uap_frame == 0 then
      mlrs(85, 30, 1, 0)
      unidentified_aerial_phenomenon = false
    end
  end
end

local function draw_wind(playing_frame)
  if last_wind == playing_frame then
    return
  else
    last_wind = playing_frame
    screen.level(screen_levels["l"])
    local wind_frame_1 = playing_frame % 20
    local wind_frame_2 = playing_frame % 13
    if math.random(0, 1) == 1 then mlrs(wind_frame_1 + 80, 49, 1, 0) end
    if math.random(0, 2) ~= 0 then mlrs(wind_frame_2 + 10, 49, 1, 0) end
    if math.random(0, 3) ~= 0 then mlrs((wind_frame_1 * 2), 54, 1, 0) end
    if math.random(0, 2) ~= 1 then mlrs(((wind_frame_1 + 4) * 3), 54, 1, 0) end
    if math.random(0, 4) ~= 0 then mlrs(((wind_frame_1 + 2) * 5) + 28, 54, 1, 0) end
    if math.random(0, 1) == 1 then mlrs((wind_frame_2 * 2) + 48, 61, 1, 0) end
    if math.random(0, 1) == 1 then mlrs(((wind_frame_1 + 6) * 4) + 57, 61, 1, 0) end
    if math.random(0, 1) == 1 then mlrs(((wind_frame_2 + 2) * 10) + 57, 61, 1, 0) end
    if math.random(0, 1) == 1 then mlrs((((wind_frame_2 + 3) * 8) + 57), 61, 1, 0) end
  end
end

local function draw_birds(playing_frame, playing)
  screen.level(screen_levels["l"])
  local bird_frame = playing_frame % 3
  if playing then
    drift(playing_frame)
  end
  local joe_now_x = this_drift_x
  local joe_now_y = this_drift_y
  local bethNowX = this_drift_x - 5
  local beth_now_y = this_drift_y + 5
  local alex_now_x = this_drift_x + 7
  local alex_now_y = this_drift_y + 4
  if bird_frame == 0 then
    -- joe
    mlrs(joe_now_x, joe_now_y, 2, 2)
    mlrs(joe_now_x, joe_now_y, -2, 2)
    -- beth
    mlrs(bethNowX, beth_now_y, 2, -2)
    mlrs(bethNowX, beth_now_y, -2, -2)
    -- alex
    mlrs(alex_now_x, alex_now_y, 2, 1)
    mlrs(alex_now_x, alex_now_y, -2, 1)
  elseif bird_frame == 1 then
    -- joe
    mlrs(joe_now_x, joe_now_y, 2, 1)
    mlrs(joe_now_x, joe_now_y, -2, 1)
    -- beth
    mlrs(bethNowX, beth_now_y, 2, 2)
    mlrs(bethNowX, beth_now_y, -2, 2)
    -- alex
    mlrs(alex_now_x, alex_now_y, 2, -2)
    mlrs(alex_now_x, alex_now_y, -2, -2)
  elseif bird_frame == 2 then
    -- joe
    mlrs(joe_now_x, joe_now_y, 2, -2)
    mlrs(joe_now_x, joe_now_y, -2, -2)
    -- beth
    mlrs(bethNowX, beth_now_y, 2, 1)
    mlrs(bethNowX, beth_now_y, -2, 1)
    -- alex
    mlrs(alex_now_x, alex_now_y, 2, 2)
    mlrs(alex_now_x, alex_now_y, -2, 2)
  end
end

local function draw_landscape()
  screen.level(screen_levels["l"])

  -- antenna sides
  mls(62, 52, 66, 20)
  mls(70, 53, 66, 20)

  -- antenna horizontals
  mlrs(64, 34, 3, 0)
  mlrs(64, 39, 3, 0)
  mlrs(64, 45, 3, 0)

  -- antenna supports
  mls(62, 52, 70, 44)
  mls(70, 52, 62, 44)
  mls(70, 44, 63, 37)

  -- antenna details
  mlrs(65, 19, 2, 0)
  mlrs(62, 30, 2, 0)
  mlrs(67, 28, 2, 0)
  mlrs(62, 27, 1, 2)
  mlrs(69, 25, 1, 2)

  -- distant horizon
  mlrs(0, 48, 60, 0)
  mlrs(72, 48, 50, 0)

  -- second horizon
  mlrs(1, 50, 1, 0)
  mlrs(4, 50, 40, 0)
  mlrs(46, 50, 9, 0)
  mlrs(57, 50, 1, 0)
  mlrs(74, 50, 40, 0)
  mlrs(116, 50, 2, 0)

  -- third horizon
  mlrs(5, 55, 3, 0)
  mlrs(10, 55, 40, 0)
  mlrs(55, 55, 20, 0)
  mlrs(80, 55, 41, 0)
  
  -- closest horizon
  mlrs(33, 62, 62, 0)
  mlrs(100, 62, 5, 0)
  mlrs(108, 62, 2, 0)
end

-- main render function
--------------------------------------------------------------------------------

function classic.render(playing_frame, recording_time, drone_name, hz, amp, playing, alt, alert, hz_num, amp_num)
  -- classic scene ignores numeric values, but future scenes can use them
  -- hz_num: raw frequency value (e.g., 55.0)
  -- amp_num: raw amplitude value (e.g., 0.4)
  
  -- draw all scene elements in correct order
  draw_birds(playing_frame, playing)
  draw_wind(playing_frame)
  draw_lights(playing_frame)
  draw_uap(playing_frame, playing)
  draw_landscape()
end

return classic

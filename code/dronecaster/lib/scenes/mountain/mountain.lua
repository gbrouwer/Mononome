-- mountain scene (Mt. Zion bitmap-based graphics - OPTIMIZED)
-- This version uses pre-rendered bitmaps for 10-100x better performance
--------------------------------------------------------------------------------

local mountain = {}

mountain.name = "Mountain"

-- drawing utilities (will be provided by draw.lua)
local mlrs, mls, screen_levels, DEBUG

-- Image heights and calculated Y positions for bottom alignment
local tower_y = 9   -- 64 - 55
local fg_01_y = 39  -- 64 - 25
local fg_00_y = 47  -- 64 - 17

local base_path = _path.code .. "dronecaster/lib/scenes/mountain/assets/"

-- Bitmap resources
local gradient_file = "fog_gradient_wide.png"
local noise_line_file = "fog_noise_line.png"
local noise_line_width = 128  -- norns screen width (we'll tile it)

-- Check if bitmaps exist
local bitmaps_generated = false
local bitmaps_check_done = false

local function check_bitmaps_exist()
  if bitmaps_check_done then return bitmaps_generated end
  
  local gradient_exists = util.file_exists(base_path .. gradient_file)
  local noise_exists = util.file_exists(base_path .. noise_line_file)
  
  bitmaps_generated = gradient_exists and noise_exists
  bitmaps_check_done = true
  
  if not bitmaps_generated then
    print("===================================")
    print("MOUNTAIN SCENE ERROR:")
    print("Required fog bitmaps not found in:")
    print(base_path)
    print("Missing files will prevent fog rendering")
    print("===================================")
  end
  
  return bitmaps_generated
end

function mountain.init(utils)
  -- receive utility functions from draw.lua
  mlrs = utils.mlrs
  mls = utils.mls
  screen_levels = utils.screen_levels
  DEBUG = utils.DEBUG

  if DEBUG and DEBUG() then print("mountain: scene initialized (bitmap mode)") end

  -- Check if bitmaps exist (will print helpful message if not)
  check_bitmaps_exist()
end

-- drawing functions
--------------------------------------------------------------------------------

local function draw_tower()
  -- Display tower PNG - norns will respect transparency
  screen.display_png(base_path .. "tower.png", 0, tower_y)
end

-- Tower lights animation state
local last_variation_update = 0
local variation_update_interval = 3.0
local light1_rate = 6.9  -- Hz (blinks per second) - fast visible rate
local light2_rate = 5.1  -- Hz (blinks per second) - slower visible rate
local light1_variation = 0
local light2_variation = 0

local function draw_tower_lights(playing_frame, hz_num, amp_num, playing)
  -- Animated blinking lights on tower
  -- Two pixels that blink at different rates based on Hz
  
  if not playing then
    -- Pause animation when not playing
    return
  end
  
  -- Use real time for smooth animation independent of parameter changes
  local current_time = util.time()
  
  -- Update random variation every few seconds
  if current_time - last_variation_update >= variation_update_interval then
    last_variation_update = current_time
    -- Small random variations (-5% to +5%)
    light1_variation = (math.random() - 0.5) * 0.1
    light2_variation = (math.random() - 0.5) * 0.1
    -- Vary the interval slightly too
    variation_update_interval = 3.0 + math.random() * 2.0
  end
  
  -- Map Hz (0-2000) to rate multipliers (1.0 to ~1.5)
  -- This speeds up blinking as frequency increases
  local hz_clamped = util.clamp(hz_num, 0, 2000)
  local hz_rate_factor = 0.2 + (hz_clamped / 2000) * 1.3
  
  -- Apply variations to rates
  local current_rate1 = light1_rate * hz_rate_factor * (1.0 + light1_variation)
  local current_rate2 = light2_rate * hz_rate_factor * (1.0 + light2_variation)
  
  -- Calculate blink state using sine waves based on real time
  local phase1 = math.sin(current_time * 2 * math.pi * current_rate1)
  local phase2 = math.sin(current_time * 2 * math.pi * current_rate2)
  
  -- Map amp to intensity range (0.3 to 1.0)
  -- So lights are always visible but get brighter with amplitude
  local amp_intensity = 0.3 + (amp_num * 0.7)
  
  -- Light 1 at (65, 16) - blinks when phase > 0
  if phase1 > 0 then
    -- Smooth the on/off with the sine value for nicer looking blinks
    local brightness = phase1 * amp_intensity
    local level = math.floor(brightness * 15)
    level = util.clamp(level, 3, 15)  -- minimum level 3 so it's always visible when "on"
    screen.level(level)
    screen.pixel(65, 16+9)
    screen.fill()
  end
  
  -- Light 2 at (64, 20) - blinks when phase > 0
  if phase2 > 0 then
    local brightness = phase2 * amp_intensity
    local level = math.floor(brightness * 15)
    level = util.clamp(level, 3, 15)
    screen.level(level)
    screen.pixel(64, 20+9)
    screen.fill()
  end
end

local function draw_fg_01()
  -- Display fg_01 PNG - norns will respect transparency
  screen.display_png(base_path .. "fg_01.png", 0, fg_01_y)
end

local function draw_fg_00()
  -- Display fg_00 PNG - norns will respect transparency
  screen.display_png(base_path .. "fg_00.png", 0, fg_00_y)
end

-- BLACK DOTS - simple particle system
--------------------------------------------------------------------------------

local dots = {}
local MAX_DOTS = 30
local DOT_LIFETIME_MIN = 0.3  -- seconds (very fast flash)
local DOT_LIFETIME_MAX = 1.2   -- seconds (slightly longer)

-- Spawn parameters
local CENTER_X = 65     -- antenna centerline x position
local X_SPREAD = 20     -- TWEAK THIS: max distance from center (px either side)
local Y_MIN = 9         -- minimum y position
local Y_MAX = 35        -- maximum y position
local AMP_THRESHOLD = 0.5 --only appear above these amps

local function spawn_dot()
  -- Seed random with time for true randomness
  math.randomseed(util.time() * 1000000 + math.random(1, 1000000))
  
  -- Bias distance toward center using power function
  -- Higher power = stronger bias toward center
  local random_factor = math.random()
  local biased_factor = math.pow(random_factor, 2)  -- Square for moderate center bias
  
  -- Random direction (-1 or 1) and biased distance
  local direction = (math.random() < 0.5) and -1 or 1
  local x_offset = direction * biased_factor * X_SPREAD
  
  -- Random y within range
  local y = math.random(Y_MIN, Y_MAX)
  
  -- Random lifetime for this dot
  local lifetime = DOT_LIFETIME_MIN + math.random() * (DOT_LIFETIME_MAX - DOT_LIFETIME_MIN)
  
  -- 50/50 chance: fade white to black (true) or black to white (false)
  local fade_to_black = math.random() < 0.5
  
  return {
    x = CENTER_X + x_offset,
    y = y,
    birth_time = util.time(),
    lifetime = lifetime,
    fade_to_black = fade_to_black
  }
end

local function draw_black_dots(amp_num, playing)
  if not playing or amp_num < AMP_THRESHOLD then
    -- Clear dots when not playing or amp too low
    dots = {}
    return
  end
  
  local current_time = util.time()
  
  -- Spawn new dots based on amplitude - spawn MANY more per frame
  -- More amplitude = more dots spawned per frame
  local spawn_attempts = math.floor(util.linlin(AMP_THRESHOLD, 1.0, 3, 12, amp_num))
  
  for i = 1, spawn_attempts do
    if #dots < MAX_DOTS then
      local new_dot = spawn_dot()
      table.insert(dots, new_dot)
    end
  end
  
  -- Update and draw existing dots
  local alive_dots = {}
  
  for _, dot in ipairs(dots) do
    local age = current_time - dot.birth_time
    
    if age < dot.lifetime then
      -- Calculate fade progress (0 to 1)
      local progress = age / dot.lifetime
      
      -- Set level based on fade direction
      local level
      if dot.fade_to_black then
        -- White to black: start at 15, fade to 0
        level = math.floor((1.0 - progress) * 15)
      else
        -- Black to white: start at 0, fade to 15
        level = math.floor(progress * 15)
      end
      
      screen.level(level)
      screen.pixel(math.floor(dot.x), math.floor(dot.y))
      screen.fill()
      
      -- Keep particle alive
      table.insert(alive_dots, dot)
    end
  end
  
  -- Update dots list
  dots = alive_dots
end

-- OPTIMIZED fog texture system using pre-rendered bitmaps
--------------------------------------------------------------------------------

-- Performance tuning options
local NOISE_LINE_STEP = 3  -- Draw every Nth line (1=every line, 2=every other, 3=every third)

local function draw_fog_texture(amp_num, hz_num, playing_frame, playing)
  -- Check if bitmaps exist before trying to draw
  if not check_bitmaps_exist() then
    -- Draw a simple replacement message
    screen.level(8)
    screen.move(64, 24)
    screen.text_center("FOG BITMAPS NOT FOUND")
    screen.move(64, 32)
    screen.level(5)
    screen.text_center("see maiden log for details")
    return
  end
  
  screen.clear()

  -- Use the wide gradient for fog effect
  
  -- Fade across entire amp range (0 to 1) with gentle curve
  -- Quadratic curve for balanced fade
  local FADE_EXPONENT = 1.8 -- determines how the fog fades across the amp range
  local corrected_fade = math.pow(amp_num, FADE_EXPONENT)
  
  -- Draw the selected gradient at full brightness
  screen.blend_mode(0)
  screen.level(15)
  screen.display_png(base_path .. gradient_file, 0, 0)
  
  -- Darken with rect - use gamma-corrected fade factor
  local darken_level = math.floor(corrected_fade * 15)
  
  screen.blend_mode(6)  -- Darken mode: min(source, dest)
  screen.level(darken_level) -- key trick happens here - the level is used to darken the fog
  screen.rect(0, 0, 128, 64)
  screen.fill()
  
  screen.blend_mode(0)
  
  -- Add noise lines on top - also use Darken so it doesn't brighten black areas
  screen.blend_mode(6)  -- Darken mode - noise can't make things brighter than they are
  
  -- Noise at high level (12-15) so it only darkens the brightest parts
  local noise_level = math.floor(corrected_fade * 3) + 12
  
  -- Use time for smooth continuous motion (not frame-based)
  local time_ms = playing and (util.time() * 1000) or 0
  
  -- Map hz to motion amplitude: 0 Hz = 6px motion, 400 Hz = 18px motion (max)
  local hz_amplitude = util.linlin(0, 400, 6, 18, hz_num)
  hz_amplitude = util.clamp(hz_amplitude, 6, 18)
  
  -- Draw noise lines with horizontal motion - each line at different offset/speed
  for y = 8, 56, NOISE_LINE_STEP do
    -- Each line gets its own random speed and phase offset
    math.randomseed(y * 47)
    local speed_variation = 0.8 + math.random() * 0.6  -- 0.8 to 1.4x speed
    local phase_offset = math.random() * 6.28  -- Random phase 0 to 2π
    
    -- Add random base x offset for each line (0 to 127 pixels)
    local base_x_offset = math.random(0, noise_line_width - 1)
    
    -- Calculate X offset with sine wave motion - smooth time-based animation
    -- Base frequency: one full cycle every ~500ms
    local x_offset = math.sin(time_ms * 0.012 * speed_variation + phase_offset) * (hz_amplitude / 12)
    
    -- Combine base offset with animated offset, then wrap
    local x_pos = math.floor(base_x_offset - x_offset) % noise_line_width
    
    screen.level(noise_level)
    screen.display_png(base_path .. noise_line_file, x_pos, y)
    
    -- Draw wrapped portion if needed
    if x_pos > 0 then
      screen.display_png(base_path .. noise_line_file, x_pos - noise_line_width, y)
    end
  end
  
  screen.blend_mode(0)
end

-- main render function
--------------------------------------------------------------------------------

function mountain.render(playing_frame, recording_time, drone_name, hz, amp, playing, alt, alert, hz_num, amp_num)
  -- draw scene in layers from back to front
  -- each PNG has transparency baked in, so norns handles it automatically
  -- header/HUD is drawn by draw.lua, not by the scene
  
  draw_fog_texture(amp_num, hz_num, playing_frame, playing)  -- OPTIMIZED bitmap-based fog
  draw_black_dots(amp_num, playing)  -- simple black dot particles
  draw_tower()          -- tower PNG with transparency
  draw_tower_lights(playing_frame, hz_num, amp_num, playing)  -- animated blinking lights on tower
  draw_fg_01()          -- mid-ground layer with transparency
  draw_fg_00()          -- foreground dark trees with transparency
  
end

return mountain

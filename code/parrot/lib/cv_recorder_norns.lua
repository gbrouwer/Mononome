        -- crow.output[1].action = "oscillate(440,5,'sine')"
        -- crow.output[1].action = "oscillate(" .. note_to_play .. "+ dyn{freq=" .. 800 .. "}:mul(" .. 0.8 .. "), dyn{lev=" .. 5 .. "}:mul(" .. 0.98 .. ") )"
        -- crow.output[1].execute()

--------------------------
-- play cv
--------------------------

cv_recorder = {}

cv_recorder.bucket1 = {}
cv_recorder.bucket2 = {}
-- cv_recorder.tap1 = {}
-- cv_recorder.tap2 = {}
-- cv_recorder.tap3 = {}
-- cv_recorder.tap4 = {}
cv_recorder.bucket_index1 = 1
cv_recorder.bucket_index2 = 1
cv_recorder.active_bucket_length1 = MAX_VISIBLE_BUCKET
cv_recorder.active_bucket_length2 = MAX_VISIBLE_BUCKET
cv_recorder.cv_sampling_rate1 = 1
cv_recorder.cv_sampling_rate2 = 1
-- cv_recorder.ellipses = ""

cv_recorder.nav_labels = {
  "bz",
  "br",
  "bl",
  "ta",
  "td",
  "tq"
}

cv_recorder.num_sub_controls = {2,2,2,4,4,4}

-- cv_recorder.nav_labels = {
--   "cv delay",
--   "cv player/recorder controls",
--   "reset loop1",
--   "reset loop2"
-- }

cv_recorder.active_control = 1
cv_recorder.active_sub_control = 1

cv_recorder.screen1 = {}
cv_recorder.screen1.selected_delay_tap = 1
cv_recorder.screen2 = {}
cv_recorder.screen2.selected_control_num = 1

P = norns.crow.public

-- local BOWERYPATH = norns.state.path .. "crow/"
norns.crow.loadscript("cv_recorder_crow.lua")



function cv_recorder.set_cv_delay(output_num)
  -- alt_param = "false"
  local new_tap_amount = params:get("cv_delay_tap"..output_num)
  -- P.delta(output_num, delta, alt_param)
  local tap_assignment = params:get("cv_assignment_tap"..output_num)
  tap_assignment = "tap"..output_num.."_b"..tap_assignment 
  crow.public[tap_assignment] = math.ceil(new_tap_amount/2)
  -- P.update("tap"..output_num, new_tap_amount)
  -- cv_recorder["tap"..output_num] = cv_recorder["tap"..output_num] + delta
end

function cv_recorder.set_cv_loop_length(bucket)
  if bucket == 1 then
    -- if params:get("cv_recorder_state1") == 2 then cv_recorder.bucket1 = {} end 
    local new_loop_length = params:get("cv_loop_length1")
    crow.public.loop_length_b1 = math.ceil(new_loop_length)
  else
    -- if params:get("cv_recorder_state2") == 2 then cv_recorder.bucket2 = {} end     
    local new_loop_length = params:get("cv_loop_length2")
    crow.public.loop_length_b2 = math.ceil(new_loop_length)
  end
end

function cv_recorder.set_cv_recorder_state(bucket, state) 
  if bucket == 1 then 
    crow.public.recorder_state_b1 = state
  else 
    crow.public.recorder_state_b2 = state
  end
end

function cv_recorder.reset_loop(bucket)
  print("reset loop")

  if bucket == 1 then 
    crow.public.reset1 = 1
  else
    crow.public.reset2 = 1
  end
end



function cv_recorder.play()

end

function cv_recorder.draw_delay_ui()
  local tap_num = cv_recorder.screen1.selected_delay_tap
  local sl1 = tap_num == 1 and 10 or 5
  local sl2 = tap_num == 2 and 10 or 5
  local sl3 = tap_num == 3 and 10 or 5
  local sl4 = tap_num == 4 and 10 or 5

  screen.level(sl1)
  screen.move(10,30)
  screen.text("delay tap 1: " .. params:get("cv_delay_tap1"))
  screen.level(sl2)
  screen.move(10,40)
  screen.text("delay tap 2: " .. params:get("cv_delay_tap2"))
  screen.level(sl3)
  screen.move(10,50)
  screen.text("delay tap 3: " .. params:get("cv_delay_tap3"))
  screen.level(sl4)
  screen.move(10,60)
  screen.text("delay tap 4: " .. params:get("cv_delay_tap4"))
  -- screen.level(5)
  -- screen.move(10,60)
  -- screen.text("loop: " .. "??")
end



-- this function will be called whenever a crow output value changes
-- norns.crow.public.reset()
function norns.crow.public.change()
  if params:get("cv_recorder_state1") == 2 then
    cv_recorder.bucket1[cv_recorder.bucket_index1] = norns.crow.public.viewing.input[1]
  end
  if params:get("cv_recorder_state2") == 2 then
    cv_recorder.bucket2[cv_recorder.bucket_index2] = norns.crow.public.viewing.input[2]
  end
  if crow.public.loop_restart1 == "true" then
    cv_recorder.active_bucket_length1 = cv_recorder.bucket_index1
    if cv_recorder.active_bucket_length1 and cv_recorder.active_bucket_length1 > 100 then
      for i=cv_recorder.active_bucket_length1,#cv_recorder.bucket1,1 do
        cv_recorder.bucket1[i]=0
      end
    end 
    cv_recorder.bucket_index1 = 1
    crow.public.loop_restart1 = "false"
  else
    cv_recorder.bucket_index1 = cv_recorder.bucket_index1 + 1
  end
  if crow.public.loop_restart2 == "true" then
    cv_recorder.active_bucket_length2 = cv_recorder.bucket_index2
    if cv_recorder.active_bucket_length2 and cv_recorder.active_bucket_length2 > 100 then
      for i=cv_recorder.active_bucket_length2,#cv_recorder.bucket2,1 do
        cv_recorder.bucket2[i]=0
      end
    end
    cv_recorder.bucket_index2 = 1
    crow.public.loop_restart2 = "false"
  else
    cv_recorder.bucket_index2 = cv_recorder.bucket_index2 + 1
  end
end


function cv_recorder.draw_player_recorder_controls()
  
  --[[
  cv_recorder.bucket1[crow.public.bucket1_ix] = crow.public.bucket1_slice 
  cv_recorder.bucket2[crow.public.bucket2_ix] = crow.public.bucket2_slice 
  ]]
  
  if #cv_recorder.bucket1 <= MAX_VISIBLE_BUCKET then 
    cv_recorder.cv_sampling_rate1 = 1
  else
    cv_recorder.cv_sampling_rate1 = MAX_VISIBLE_BUCKET/#cv_recorder.bucket1
  end 
  
  
  -- for i=1,crow.public.loop_length_b1,1 do
  for i=1,#cv_recorder.bucket1,1 do
    -- if cv_recorder.bucket1[i] and i/cv_recorder.cv_sampling_rate < MAX_VISIBLE_BUCKET then
    if cv_recorder.bucket1[i] and params:get("bucket_zoom1") and cv_recorder.active_bucket_length1 then
      screen.move(10+math.ceil(i*cv_recorder.cv_sampling_rate1)*1,20)
      local y_loc1 = -1*math.floor(cv_recorder.bucket1[i]*params:get("bucket_zoom1"))
      local level =  i <= cv_recorder.active_bucket_length1 and 10 or 3
      screen.level(level)
      screen.line_rel(0,y_loc1)
      screen.stroke()
    end
  end

  if #cv_recorder.bucket2 <= MAX_VISIBLE_BUCKET then 
    cv_recorder.cv_sampling_rate2 = 1
  else
    cv_recorder.cv_sampling_rate2 = MAX_VISIBLE_BUCKET/#cv_recorder.bucket2
  end 
  
  
  -- for i=1,crow.public.loop_length_b2,1 do
  for i=1,#cv_recorder.bucket2,1 do
    -- if cv_recorder.bucket2[i] and i/cv_recorder.cv_sampling_rate < MAX_VISIBLE_BUCKET then
    if cv_recorder.bucket2[i] and params:get("bucket_zoom2") and cv_recorder.active_bucket_length2 then
      screen.move(10+math.ceil(i*cv_recorder.cv_sampling_rate2)*1,50)
      local y_loc2 = -1*math.floor(cv_recorder.bucket2[i]*params:get("bucket_zoom2"))
      local level =  i <= cv_recorder.active_bucket_length2 and 10 or 3
      screen.level(level)
      screen.line_rel(0,y_loc2)
      screen.stroke()
    end
  end
end

function cv_recorder.draw_player_recorder_sub_control_values(vals)
  screen.level(10)
  screen.move(116,10)
  local subnav_title = cv_recorder.nav_labels[cv_recorder.active_control] 
  screen.text_center(subnav_title)
  screen.rect(106,2,22,58)
  screen.rect(106,12,22,2)
  screen.move(116,22)
  screen.stroke()
  if #vals == 2 then
    screen.move (116,30)
    local level = cv_recorder.active_sub_control == 1 and 15 or 3
    screen.level(level)
    screen.text_center(vals[1])
    screen.move (116,45)
    level = cv_recorder.active_sub_control == 2 and 15 or 3
    screen.level(level)
    screen.text_center(vals[2])
    screen.stroke()
    screen.level(15)
  else
    screen.move (116,22)
    local level = cv_recorder.active_sub_control == 1 and 15 or 3
    screen.level(level)
    screen.text_center(vals[1])
    screen.move (116,33)
    level = cv_recorder.active_sub_control == 2 and 15 or 3
    screen.level(level)
    screen.text_center(vals[2])
    screen.stroke()
    screen.move (116,44)
    level = cv_recorder.active_sub_control == 3 and 15 or 3
    screen.level(level)
    screen.text_center(vals[3])
    screen.move (116,55)
    level = cv_recorder.active_sub_control == 4 and 15 or 3
    screen.level(level)
    screen.text_center(vals[4])
    screen.stroke()
    screen.level(15)
  end
end

function cv_recorder.draw_player_recorder_sub_controls()
  local sub_control_values = {}
  if cv_recorder.active_control == 1 then  
    local param1 = params:lookup_param("bucket_zoom1")
    local param_val1 = params:get("bucket_zoom1")
    local param_val_name1 = param1.options[param_val1]
    local param2 = params:lookup_param("bucket_zoom2")
    local param_val2 = params:get("bucket_zoom2")
    local param_val_name2 = param2.options[param_val2]
    sub_control_values={param_val_name1,param_val_name2}
    cv_recorder.draw_player_recorder_sub_control_values(sub_control_values)
  elseif cv_recorder.active_control == 2 then
    local param1 = params:lookup_param("cv_recorder_state1")
    local param_val1 = params:get("cv_recorder_state1")
    local param_val_name1 = param1.options[param_val1]
    local param2 = params:lookup_param("cv_recorder_state2")
    local param_val2 = params:get("cv_recorder_state2")
    local param_val_name2 = param2.options[param_val2]
    sub_control_values={param_val_name1,param_val_name2}
    cv_recorder.draw_player_recorder_sub_control_values(sub_control_values)
  elseif cv_recorder.active_control == 3 then
    local param_val1 = params:get("cv_loop_length1")
    local param_val2 = params:get("cv_loop_length2")
    sub_control_values={param_val1,param_val2}
    cv_recorder.draw_player_recorder_sub_control_values(sub_control_values)
  elseif cv_recorder.active_control == 4 then
    local param1 = params:lookup_param("cv_assignment_tap1")
    local param_val1 = params:get("cv_assignment_tap1")
    local param_val_name1 = param1.options[param_val1]

    local param2 = params:lookup_param("cv_assignment_tap2")
    local param_val2 = params:get("cv_assignment_tap2")
    local param_val_name2 = param2.options[param_val2]
    
    local param3 = params:lookup_param("cv_assignment_tap3")
    local param_val3 = params:get("cv_assignment_tap3")
    local param_val_name3 = param3.options[param_val3]
    
    local param4 = params:lookup_param("cv_assignment_tap4")
    local param_val4 = params:get("cv_assignment_tap4")
    local param_val_name4 = param4.options[param_val4]
    sub_control_values={param_val_name1,param_val_name2,param_val_name3,param_val_name4}
    cv_recorder.draw_player_recorder_sub_control_values(sub_control_values)
  elseif cv_recorder.active_control == 5 then
    local param_val1 = params:get("cv_delay_tap1")
    local param_val2 = params:get("cv_delay_tap2")
    local param_val3 = params:get("cv_delay_tap3")
    local param_val4 = params:get("cv_delay_tap4")
    sub_control_values={param_val1,param_val2,param_val3,param_val4}
    cv_recorder.draw_player_recorder_sub_control_values(sub_control_values)
  elseif cv_recorder.active_control == 6 then
    local param1 = params:lookup_param("quantize_tap1")
    local param_val1 = params:get("quantize_tap1")
    local param_val_name1 = param1.options[param_val1]

    local param2 = params:lookup_param("quantize_tap2")
    local param_val2 = params:get("quantize_tap2")
    local param_val_name2 = param2.options[param_val2]
    
    local param3 = params:lookup_param("quantize_tap3")
    local param_val3 = params:get("quantize_tap3")
    local param_val_name3 = param3.options[param_val3]
    
    local param4 = params:lookup_param("quantize_tap4")
    local param_val4 = params:get("quantize_tap4")
    local param_val_name4 = param4.options[param_val4]
    sub_control_values={param_val_name1,param_val_name2,param_val_name3,param_val_name4}
    cv_recorder.draw_player_recorder_sub_control_values(sub_control_values)
  end

end

function cv_recorder.draw_reset_loop_ui()
  screen.level(10)
  screen.move(10,30)
  screen.text("press k2 to reset loop")
end

function cv_recorder.draw_sub_nav ()

  -- screen.level(10)
  -- screen.rect(2,10, screen_size.x-2, 3)
  -- screen.fill()
  -- screen.level(0)
  -- local num_field_menu_areas = #cv_recorder.nav_labels
  -- local area_menu_width = (screen_size.x-5)/num_field_menu_areas
  -- screen.rect(2+(area_menu_width*(cv_recorder.active_control-1)),10, area_menu_width, 3)
  -- screen.fill()
  -- screen.level(4)
  -- for i=1, num_field_menu_areas+1,1
  -- do
  --   if i < num_field_menu_areas+1 then
  --     screen.rect(2+(area_menu_width*(i-1)),10, 1, 3)
  --   else
  --     screen.rect(2+(area_menu_width*(i-1))-1,10, 1, 3)
  --   end
  -- end
  -- screen.fill()
end

function cv_recorder.draw_top_nav (msg)
  if show_instructions == true then
    subnav_title = "instructions"
  -- elseif initializing_crow == true and norns.crow.connected() == true then
  --   subnav_title = "initializing crow" .. cv_recorder.ellipses
  --   cv_recorder.ellipses = cv_recorder.ellipses== "......" and "" or cv_recorder.ellipses .. "."
  -- elseif norns.crow.connected() == false then
  --   subnav_title = "crow not connected :("
  else
    subnav_title = ""
  end

  screen.move(1,12)
  screen.text(subnav_title)
end



function cv_recorder.update()
  screen.clear()
  if intro_animation.anim_done == false then
    intro_animation.update()
  else
    if saving == false then
      cv_recorder.draw_top_nav()
    else
      cv_recorder.draw_top_nav("saving")
    end

    if  show_instructions == true and menu_status == false then
      instructions.display()
    elseif initializing_crow == false then
      cv_recorder.draw_player_recorder_controls()
    end

    if initializing_crow == false then
      cv_recorder.draw_player_recorder_sub_controls()
    end

    if cv_recorder.active_control == 1 then
    elseif cv_recorder.active_control == 2 then  
    elseif cv_recorder.active_control == 3 then  
    end
    -- if cv_recorder.active_control == 1 then
    --   cv_recorder.draw_player_recorder_controls()
    -- elseif cv_recorder.active_control == 2 then  
    --   cv_recorder.draw_delay_ui()
    -- elseif cv_recorder.active_control == 3 then  
    --   cv_recorder.draw_reset_loop_ui()
    -- end
  end
  screen.update()
end


return cv_recorder
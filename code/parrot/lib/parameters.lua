params:add_group("scales", 2)
params:add{type = "option", id = "scale_mode", name = "scale mode",
options = scale_names, default = 5,
action = function() fn.build_scale() end}

params:add{type = "number", id = "root_note", name = "root note",
min = 0, max = 127, default = ROOT_NOTE_DEFAULT, formatter = function(param) return MusicUtil.note_num_to_name(param:get(), true) end,
action = function() fn.build_scale() end}


params:add_separator("bucket controls")

for i=1,2,1 do
  params:add{
    type = "option", id = "bucket_zoom" .. i, name = "zoom" .. i, 
    options = {0.25,0.5,1,2,3,4,6,8,10,12,18,24},
    default = 3,
  }
end

for i=1,2,1 do
  params:add{
    type = "option", id = "cv_recorder_state" .. i, name = "record " .. i, 
    options = {"off","on"},
    default = 2,
    action = function(value) 
      local val
      if value == 1 then
        val = "off"
      elseif value == 2 then
        val = "on"
      end
      cv_recorder.set_cv_recorder_state(i,val)  
    end
  }
end


for i=1,2,1 do
  params:add{type = "number", id = "cv_loop_length" .. i, name = "loop length" .. i,
  min = 1, max = MAX_BUCKET_LENGTH, default = CV_LOOP_LENGTH_DEFAULT, 
  action = function(x) 
    cv_recorder.set_cv_loop_length(i)
    for i=1,4,1 do
      local cvd = params:lookup_param("cv_delay_tap" .. i)
      if cvd.max > x then cvd.max = x 
      elseif cvd.max < x then cvd.max = x end
      if cvd.value > x then params:set("cv_delay_tap" .. i,x) end
    end
  end}
end

params:add_separator("tap controls")

params:add_group("tap delay assignments", 4)
for i=1,4,1 do
  params:add{
    type = "option", id = "cv_assignment_tap" .. i, name = "cv assignment tap " .. i, 
    options = {"in1","in2","or12","&12","rec1","rec2"},
    default = 1,
    action = function(value) 
      if i==1 then crow.public.cv_assignment_tap1 = value  
        elseif i==2 then crow.public.cv_assignment_tap2 = value  
        elseif i==3 then crow.public.cv_assignment_tap3 = value  
        elseif i==4 then crow.public.cv_assignment_tap4 = value 
      end 
    end}
end
params:add_group("tap delay amounts", 4)

params:add{type = "number", id = "cv_delay_tap1", name = "cv delay tap 1",
min = 1, max = MAX_BUCKET_LENGTH, default = 1, 
action = function(x) 
  cv_recorder.set_cv_delay(1)
end}

params:add{type = "number", id = "cv_delay_tap2", name = "cv delay tap 2",
min = 1, max = MAX_BUCKET_LENGTH, default = 1, 
action = function(x) 
  cv_recorder.set_cv_delay(2)
end}

params:add{type = "number", id = "cv_delay_tap3", name = "cv delay tap 3",
min = 1, max = MAX_BUCKET_LENGTH, default = 1, 
action = function(x) 
  cv_recorder.set_cv_delay(3)
end}

params:add{type = "number", id = "cv_delay_tap4", name = "cv delay tap 4",
min = 1, max = MAX_BUCKET_LENGTH, default = 1, 
action = function(x) 
  cv_recorder.set_cv_delay(4)
end}



params:add_group("quantize taps", 4)
for i=1,4,1 do
  params:add{
    type = "option", id = "quantize_tap" .. i, name = "quantize tap " .. i, 
    options = {"off","on"},
    default = 1,
    action = function(value) 
      if i==1 then crow.public.quantize_tap1 = value == 1 and "off" or "on"
      elseif i==2 then crow.public.quantize_tap2 = value == 1 and "off" or "on"  
      elseif i==3 then crow.public.quantize_tap3 = value == 1 and "off" or "on"  
      elseif i==4 then crow.public.quantize_tap4 = value == 1 and "off" or "on" 
      end 
    end}
end

recorder_state = "on"

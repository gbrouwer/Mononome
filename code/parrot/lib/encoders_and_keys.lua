-- encoders and keys

local enc = function (n, d)

  d = util.clamp(d, -1, 1)
  if n == 1 and show_instructions == false and alt_key_active == false then
    -- scroll pages
    local page_increment = d
    local next_page = pages.index + page_increment
    if (next_page <= NUM_PAGES and next_page > 0) then
      page_scroll(page_increment)
    end
  elseif pages.index == 1 then
    if n==2 then
      if alt_key_active == true then
        params:set("bucket_zoom1",params:get("bucket_zoom1")+d)
      else
        cv_recorder.active_control = util.clamp(cv_recorder.active_control+d,1,#cv_recorder.nav_labels)
        cv_recorder.active_sub_control = 1
      end
    elseif n==3 and show_instructions == false then
      if cv_recorder.active_control == 1 then
        -- if alt_key_active == true then
        if cv_recorder.active_sub_control == 1 then
          params:set("bucket_zoom1",params:get("bucket_zoom1")+d)
        else
          params:set("bucket_zoom2",params:get("bucket_zoom2")+d)
        end
      elseif cv_recorder.active_control == 2 then
        if cv_recorder.active_sub_control == 1 then
          params:set("cv_recorder_state1",params:get("cv_recorder_state1")+d)
        else
          params:set("cv_recorder_state2",params:get("cv_recorder_state2")+d)
        end
      elseif cv_recorder.active_control == 3 then
        d = alt_key_active == false and d or d*10
        if cv_recorder.active_sub_control == 1 then
          params:set("cv_loop_length1",params:get("cv_loop_length1")+d)
        else
          params:set("cv_loop_length2",params:get("cv_loop_length2")+d)
        end
      elseif cv_recorder.active_control == 4 then
        if cv_recorder.active_sub_control == 1 then
          params:set("cv_assignment_tap1",params:get("cv_assignment_tap1")+d)
        elseif cv_recorder.active_sub_control == 2 then
          params:set("cv_assignment_tap2",params:get("cv_assignment_tap2")+d)
        elseif cv_recorder.active_sub_control == 3 then
          params:set("cv_assignment_tap3",params:get("cv_assignment_tap3")+d)
        elseif cv_recorder.active_sub_control == 4 then
          params:set("cv_assignment_tap4",params:get("cv_assignment_tap4")+d)
        end
      elseif cv_recorder.active_control == 5 then
        d = alt_key_active == false and d or d*10
        if cv_recorder.active_sub_control == 1 then
          params:set("cv_delay_tap1",params:get("cv_delay_tap1")+d)
        elseif cv_recorder.active_sub_control == 2 then
          params:set("cv_delay_tap2",params:get("cv_delay_tap2")+d)
        elseif cv_recorder.active_sub_control == 3 then
          params:set("cv_delay_tap3",params:get("cv_delay_tap3")+d)
        elseif cv_recorder.active_sub_control == 4 then
          params:set("cv_delay_tap4",params:get("cv_delay_tap4")+d)
        end
      elseif cv_recorder.active_control == 6 then
        if cv_recorder.active_sub_control == 1 then
          params:set("quantize_tap1",params:get("quantize_tap1")+d)
        elseif cv_recorder.active_sub_control == 2 then
          params:set("quantize_tap2",params:get("quantize_tap2")+d)
        elseif cv_recorder.active_sub_control == 3 then
          params:set("quantize_tap3",params:get("quantize_tap3")+d)
        elseif cv_recorder.active_sub_control == 4 then
          params:set("quantize_tap4",params:get("quantize_tap4")+d)
        end
      -- else
      --   local d = alt_key_active == true and d*10 or d*1
      --   -- local d = alt_key_active == true and d*100 or d*10
      --   local delay = params:get("cv_delay_tap"..cv_recorder.screen1.selected_delay_tap) + d
      --   params:set("cv_delay_tap"..cv_recorder.screen1.selected_delay_tap,delay)
      end
    end  
  elseif pages.index == 2 then
  end
end

local key = function (n,z)
  if n == 1 and z == 1 then
    alt_key_active = true
  elseif n == 1 and z == 0 then
    alt_key_active = false
  end

  if alt_key_active == true and n==2 then
    if z==1 then
      show_instructions = true
    else
      show_instructions = false
    end
  end

  if pages.index == 1 and z==1 then
    if show_instructions == false and alt_key_active == false then
      if n==2 then
        local new_control = cv_recorder.active_sub_control-1
        cv_recorder.active_sub_control = util.clamp(new_control,1,cv_recorder.num_sub_controls[cv_recorder.active_control])
      elseif n==3 then
        local new_control = cv_recorder.active_sub_control+1
        cv_recorder.active_sub_control = util.clamp(new_control,1,cv_recorder.num_sub_controls[cv_recorder.active_control])
      end
    else
    end
  elseif pages.index == 2 and z==1 then
    -- local delta = 0
    -- if n==2 then
    --   delta = -1
    -- elseif n==3 then
    --   delta = 1
    -- end
    -- if n>1 and cv_recorder.active_control == 1 then
    --   delta=util.clamp(cv_recorder.screen1.selected_delay_tap+delta,1,4)
    --   cv_recorder.screen1.selected_delay_tap = delta
    -- elseif n>1 and cv_recorder.active_control == 2 then
    --   delta=util.clamp(cv_recorder.screen1.selected_delay_tap+delta,1,2)
    --   cv_recorder.screen2.selected_control_num = delta
    -- elseif n==2 and cv_recorder.active_control == 3 then
    --   cv_recorder.reset_loop(1)
    -- end
  end
end

return{
  enc=enc,
  key=key
}

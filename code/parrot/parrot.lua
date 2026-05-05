---parrot
-- 1.0 @jaseknighter
-- lines: llllllll.co/t/53083
-- 
-- a cv recorder and player 
-- for norns+crow 
--
-- k1+e2: show instructions

-------------------------
-------------------------
include "lib/includes"

------------------------------
-- init
------------------------------
function init()
  -- set sensitivity of the encoders
  norns.enc.sens(1,6)
  norns.enc.sens(2,6)
  norns.enc.sens(3,6)
  
  pages = UI.Pages.new(0, 1)
  
  page_scroll(1)
  set_redraw_timer()
  initializing_norns = false
  if norns.crow.connected() == true then
    set_params()
    clock.run(finish_init)
  else
    print("crow not connected. :(")
  end
end

function finish_init()
  clock.sleep(5)
  print("init done")
  params:set("cv_assignment_tap2",2)
  params:set("cv_assignment_tap4",2)
  -- params:set("cv_loop_length1",800)
  -- params:set("cv_loop_length2",800)
  fn.build_scale()
  -- public.inited = false
  initializing_crow = false
end

--------------------------
-- params
--------------------------
function set_params()
  -- params:add_trigger("set_", "save samples")
  -- params:set_action("set_", function(x)
  --   if Namesizer ~= nil then
  --     textentry.enter(pre_save,Namesizer.phonic_nonsense().."_"..Namesizer.phonic_nonsense())
  --   else
  --     textentry.enter(sample_recorder.save_samples)
  --   end
  -- end)
end


--------------------------
-- encoders and keys
--------------------------
function enc(n, delta)
  encoders_and_keys.enc(n, delta)
end

function key(n,z)
  encoders_and_keys.key(n, z)
end

--------------------------
-- redraw 
--------------------------
function set_redraw_timer()
  redrawtimer = metro.init(function() 
    menu_status = norns.menu.status()
    -- screen.clear()
    if menu_status == false and initializing_norns == false then
      if pages.index == 1 then
        cv_recorder.update()
      else
        -- sample_player.update()
      end
      -- screen_dirty = false
      clear_subnav = true
    elseif menu_status == true and clear_subnav == true then
      -- screen_dirty = true
      clear_subnav = false
    end
  end, SCREEN_FRAMERATE, -1)
  redrawtimer:start()  

end


function cleanup ()
  -- add cleanup code
end


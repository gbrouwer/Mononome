--footie
--
--
-- this script will allow for you to hook up a midi foot controller to control things
-- I use it with a foot controller I made with a teensy.
-- I will not publicly support this. I leave it here if you want to tinker. 
-- and I am happy to help you make it work for your system just reach out to me
-- thanks
-- good luck
--
--    ululo
--
--
local ft = {}


footie = midi.connect()



expCC = 0

s1 = false
s3 = false
s6 = false
quieted = false

function ft.init()
  if footie then
   print("footie connected!!!!")
  end
  
 
  redraw()
  
  
end


footie.event = function(data)
  local d = midi.to_msg(data)
  
  if d.type == "cc" then
    -- for an expression pedal function
    if d.cc == 30 then
      expCC = (d.val/113) 
      expCC = expCC * 100
      expCC = math.floor(expCC)
      expCC = expCC / 100
      --express(expCC)
    end
    
    if d.cc > 20 and d.cc < 30 then
      
      local s = d.cc - 20
      if s == 1 and d.val == 1 then
        --do something for button 1
        curRec = (curRec - 1) % 6
        ft.setVoice(curRec + 1)
        s1 = true
        eraseCut()
      end 
      if s == 1 and d.val == 0 then
        s1 = false
      end
      if s == 2 and d.val == 1 then
        
        recKey(d.val)
        --[[
        --do something for button 2
        softcut.rec_level(curRec+1,d.val)
        --ft.setRec(curRec+1)
        --handle_rectangle_key(curRec+1, d.val)
        recording = true]]
        print(recording)
      end
      if s == 2 and d.val == 0 then
        recKey(d.val)
        --[[
        softcut.rec_level(curRec+1,d.val)
        --handle_rectangle_key(curRec+1, d.val)
        recording = false]]
        print(recording)
      end
      if s == 3 and d.val == 1 then
        --do something for button 3
        curRec = (curRec + 1) % 6
        ft.setVoice(curRec + 1)  
        s3 = true
        eraseCut()
        quietCut()
      end
      if s == 3 and d.val == 0 then
        s3 = false
      end
      if s == 6 and d.val == 1 then
        --do something for button 6
        flip(curRec+1)
        s6 = true
        quietCut()
      end
      if s == 6 and d.val == 0 then
        s6 = false
      end
      if s == 5 and d.val == 1 then
        --do something for button 5
        flop(curRec+1)
      end
      if s == 4 then
        --do something for button 4
        microLoop(d.val)
      end
      
      screen.ping()  
      
    end
    redraw()
   --print("cc " .. d.cc .. " = " .. d.val)
  end
end

function eraseCut()
  if s1 and s3 then
    softcut.buffer_clear()
    for i = 1, 6 do
      dVlevel[i] = 1
    end
    s1 = false
    s3 = false
    print('erased!!!!!')
    clearRects()
  end
end

function quietCut()
  if s3 and s6 then
    local level = 0
    
    if quieted == true then
      level = 1
      quieted = false
    elseif quieted == false then
      
      quieted = true
    end
    for i = 1, 6 do
      softcut.level_slew_time(i,math.random(4,8))
      dVlevel[i] = 1
    end
    for i = 1, 6 do
      softcut.level(i,level)
    end
    s3 = false
    s6 = false
    
  end
end

function ft.microLoop( v )
  --create micro loop of current voice while button is pressed
  local i = curRec + 1
  
  if v == 1 then
    softcut.query_position(i)
    softcut.pre_level(i,1)
    print('query called')
    micro = true
  end
  
  if v == 0 then
    softcut.loop_start(i, lStart[i])
    softcut.loop_end(i,  lEnd[i] + lStart[i])
    softcut.pre_level(i,scPre[i])
    micro = false
  end
  print('micro looping called')
end


function ft.setRec( vox ) -- this is where to call the rect handler

  dVlevel[vox] = 16
  --redraw()
end

function ft.setVoice( vox )
  
  recRec = recVox[vox]  
  --redraw()
end

function express(v)
  if scPre[curRec + 1] < (v+0.02) and v > (v - 0.02) then
    scPre[curRec + 1] = v
    sc.setPre(curRec+1,scPre[curRec+1])
    --print(scPre[curRec + 1])
    --redraw()
  end
end



return ft
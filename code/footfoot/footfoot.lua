-- 
-- Foot Foot
-- 
--      just_another_looper
--               l  l        l    l
-- @ululo   l  l  l l   l    l  l l  l
-- l l l l l l l l l l l l l l l l l l l l l
-- vvvvvvvvvvvvvvvvvvvvvvvvv
-- ////////////////////////////////////////
-- controls for beautiful /////////// 
-- uncontrollable moments ///////////
-- ----------------------------------------
-- E2 - rec level 
-- E3 - pre level 
-- ----------------------------------------
-- K2 --------- start record
-- K2 again --- stop record
-- K2 (long) --- clear record
-- ----------------------------------------
-- K3 - switch loop
-- ----------------------------------------
-- K1 + K2 - flip play direction
-- K1 + K2 (long) - turn on/off 
--                  auto flip
-- ----------------------------------------
-- K1 + K3 - micro loop
-- ----------------------------------------
-- K1 + E1 - loop length
--
-- 
-- ////////////////////////////////////////
-- ////////////////////////////////////////
-- though it isn't documented
-- there is a helper script that
-- will allow a midi foot controller
-- to drive the script
-- contact me to get help 
-- setting it up for your system
--
--
--
-- thanks
--
--
-- 
--
--
-- ////////////////////////////////////////
--
--
-- ////////////////////////////////////////
-- ////////////////////////////////////////
--
-- why aren't you playing 
-- music yet ? ? ? ? ?
--
--
-- ////////////////////////////////////////
-- ////////////////////////////////////////
--
--
--
-- fine,  here is a bunny
--
--
--              ,\
--             \\\,_
--               \` ,\
--          __,.-" =__)
--         1."        )
--    ,_/   ,    \/\_
--    \_|    )_-\ \_-`
--       `-----` `--`
--
--
--
-- ascii art by
-- Joan Smith
-- found on the
-- ascii art
-- archive
--
--
--
--
--
-- ////////////////////////////////////////
-- go play music
--
--
--
--
-- ////////////////////////////////////////
-- ////////////////////////////////////////
--
--
-- but
--
--
-- if you must know
--
--
-- I named this script
-- after an old pet 
-- rabbit
-- which was named after
-- a cat
-- from a Shaggs song
--
--
-- the rabbit died
--
--
--
-- I'm pretty sure the
-- cat did as well
--
-- 
--
--
--
-- the
--
--       End
--
--
-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^



-- //////////////////////////////////////////////////////////////////////////////////
-- //////////////////////////////////////////////////////////////////////////////////
-- //////////////////////////////////////////////////////////////////////////////////
-- //////////////////////////////////////////////////////////////////////////////////
-- now the actual code begins!!!
---------------------------------

-------------------------------------------------------------------------
-------------------------------------------------------------------------
-------------------------------------------------------------------------


sc = include('lib/sftct')
ft = include('lib/footie')

-------------------------------------------------------------------------
-------------------------------------------------------------------------

clearing = false                   -- to clear loop
clear_time = nil
clear_timer = nil
clear_threshold = 2                -- time for long press to clear loop
-------------------------------------
--------------------------
--------------------------
-- screen controls  ------
--------------------------




column_x = {6,26,46,66,86,106}     -- Fixed column X positions (6 columns)
recVox = {0,20,40,60,80,100}
recRec = 0

lStart = {1,51,101,151,201,251}
lEnd = {14,22,27,30,33,35} -- as duration
lStarts = {0,0,0,0,0,0} -- offSet for start
fall = {1,1,1,1,1,1} -- this is the playHead tracker
tapeD = {{},{},{},{},{},{}} -- this is the tapeLoop tracker 

scPre = {1,1,1,1,1,1}
scLev = {1,1,1,1,1,1}
scRte = {1,1,1,1,1,1}
scFlip = {1,1,1,1,1,1}
scFlipChnc={100,100,100,100,100,100}
scPitch = {0,0,0,0,0,0}
scPan = {0.3,0.6,-0.6,0.9,-0.9,-0.3}
encPre = {"pre_1","pre_2","pre_3","pre_4","pre_5","pre_6"}
encLev = {"lev_1","lev_2","lev_3","lev_4","lev_5","lev_6"}
encPitch = {"pitch_1","pitch_2","pitch_3","pitch_4","pitch_5","pitch_6"}
encFlip = {"flip_1","flip_2","flip_3","flip_4","flip_5","flip_6"}
loopLength = {"loop_1","loop_2","loop_3","loop_4","loop_5","loop_6"}
loopTimer = {loop1,loop2,loop3,loop4,loop5,loop6}

justI = { 1/1, 16/15, 9/8, 6/5, 5/4, 4/3, 45/32, 3/2, 8/5, 5/3, 9/5, 15/8, 2/1 } --"Ptolemy"
notes_nums = {}
scale_names = {}
MusicUtil = require("musicutil")
for i = 1, #MusicUtil.SCALES do
  table.insert(scale_names, MusicUtil.SCALES[i].name)
end

pRec = false
micro = false
posOff = 0.0675
curRec = 0
recording = false
fTime = 26 -- for flip flop timers randomization
K1 = false
-------------------------------------------------------------------------
-------------------------------------------------------------------------
-- builds timers to trigger flipping and flopping actions
flipper = metro.init()
flipper.time = math.random(1,26)
flipper.event = function()
  flip()
  -- flip direction of playback
end

flopper = metro.init()
flopper.time = math.random(1,26)
flopper.event = function()
  flop()
  screen.ping()
  --flop around the stereo image of the loops
end

--------------------------
--------------------------

function init()
  
  -- this sets up the tape tables for drawing to screen
  -- there are 52 lines we use maximum 49 for the loop
  -- the final three are to always have an indicator for the PRE value
  for x=1,6 do
    -- randomize loop lengths at startup
    lEnd[x] = math.random(42) + 3 
    
    for y=1,52 do
        -- fill tapes with initial values for tapeLoop
        tapeD[x][y] = 1 
    end
  end
  
  -- initialize other libraries
  sc.init()
  ft.init()
  audio.monitor_mono()
  
  --builds timers to drive playhead animations
  for i=1,6 do
    loopTimer[i] = metro.init()
    loopTimer[i].time = 1
    
    loopTimer[i].event = function()
      if i == 1 then
        redraw()
      end
      if micro and (curRec+1) == i then
        fall[i] = (((fall[i]+0 ) % (lEnd[i])))
      else
        fall[i] = ( (fall[i] + scRte[i] ) % (lEnd[i]-lStarts[i]) )
      end
      -- this should erase lines based on playhead position and PRE value
      if curRec+1 == i and recording then
        tapeD[i][math.floor(fall[i]+0.5)] = 16 
        -- draws white lines while recording
      else
        if tapeD[i][math.floor(fall[i]+0.5)] == nil then
        
        else
          if tapeD[i][math.floor(fall[i]+0.5)] < 1.0 then
             tapeD[i][math.floor(fall[i]+0.5)] = 1 
             -- keeps lines from going black forever
          else
            tapeD[i][math.floor(fall[i]+0.5)] = tapeD[i][math.floor(fall[i]+0.5)] * scPre[i] 
            -- reduces brightness of line based on PRE value
            -- possibly add 1 here to keep line alive longer
            --print(tape[i][fall[i]+1],scPre[i],i,fall[i])
          end
        end
      end
    end
    loopTimer[i]:start()
  end
  
  -- start flip and flop timers
  flipper:start()
  flopper:start()

end

function flip(v)
  -- changes direction of playback for selected voice
  -- if voice is not specified, one will be selected randomly
  local voice = math.random(1,6)
  local tV = 0
  local rate = {-1,1}
  local dir = math.random(2)
  local rand = math.random(100)
  local div = 0
  
  if recording and curRec == (voice-1) then
  -- DO NOTHING
  print('not flipping on purpose')
  elseif v == nil then
    tV = voice
    if rand <= scPitch[tV] then
      div = (justI[(notes_nums[math.random(8)] % 12)+1]/2) * rate[dir]
      print(tV,div)
    else
      div = rate[dir]
    end
    if scFlip[tV] == 1 then
      local randChnc = math.random(1,100)
      if randChnc <= scFlipChnc[tV]then
        softcut.rate(tV,div)
        scRte[tV] = div
        --softcut.rate(tV,rate[dir])
        --scRte[tV] = rate[dir]
      end
    end
  elseif not(v == nil) then
    tV = v
    if scFlip[tV] == 1 then
      local randChnc = math.random(1,100)
      if randChnc <= scFlipChnc[tV]then
        scRte[tV] = scRte[tV]*(-1)
        softcut.rate(tV,scRte[tV])
      end
    end        
    
  end
  
  flipper.time = math.random(1,fTime)
  --print('voice',tV,scRte[tV],'dir')
  
end

function flop(v)
  -- shifts the stereo image of the loops
  shuffle(scPan)
  
  for i = 1, #scPan do
    softcut.pan(i,scPan[i])
    --print('voice',i,scPan[i],'pan')
  end
  flopper.time = math.random(1,fTime)
end

function shuffle(tbl)
  -- helper function that rearranges the pan settings
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i] , tbl[j] = tbl[j] , tbl[i]
  end
end

function updateLoops(v,e)
  lEnd[v] = math.min(e,49) 
  softcut.loop_end(v,  lEnd[v] + (lStart[v]+lStarts[v]))
  --print("loop end", lEnd[v] + (lStart[v]+lStarts[v]))
end

function updateStarts(v,s)
  lStarts[v] = math.min(s,49) 
  softcut.loop_start(v,  lStart[v] + lStarts[v])
 
  print("loop start", lStart[v] + lStarts[v])
end

function clearLoop()
  -- to erase the currently selected loop
  softcut.buffer_clear_region(lStart[curRec+1]-1,lEnd[curRec+1]+2,0,0) 
  -- a bit over the buffer length to ensure deletion
  
  -- deleting tape table contents
  for i=1,52 do
    tapeD[curRec+1][i] = 1
  end
  
  print("loop", curRec + 1 , "cleared",(lStart[curRec+1]-1) + (lEnd[curRec+1]+2))
end

function recKey (z)

if z == 1 then
    if K1 then -- if key one is held, flip current track
      print("flip flip")
      flip(curRec+1)
      
      -- long press detection to disable/enable flipping for current track
      clearing = true
      clear_time = util.time()
      clear_timer = clock.run(function()
          clock.sleep(clear_threshold)
          if clearing and (util.time() - clear_time) >= clear_threshold then
            print("flipping flipped")
            scFlip[curRec+1] = scFlip[curRec+1] * -1
           
          end
      end)
      
    else 
      
      if recording then
        softcut.rec_level(curRec+1,0)
        recording = false
        print(recording)
      else
        if pRec then
          --do nothing if record while pitched is selected
        else  
          -- change speed to normal for recording
          if scRte[curRec+1] < 0 then 
            scRte[curRec+1] = -1
            softcut.rate(curRec+1,-1)
          else
            scRte[curRec+1] = 1
            softcut.rate(curRec+1,1)
          end
        end
        softcut.rec_level(curRec+1,1)
        recording = true
        print(recording,"recording loop",curRec+1)
      end
      
      clearing = true
      clear_time = util.time()
      clear_timer = clock.run(function()
          clock.sleep(clear_threshold)
          if clearing and (util.time() - clear_time) >= clear_threshold then
            print("long press detected... clearing loop")
            softcut.rec_level(curRec+1,0)
            recording = false
            clearLoop()
            
          end
      end)
    end
  end
  
  if z == 0 then
    clearing = false
  end

end
function key (n,z)
  redraw()
  if n == 1 and z == 1 then
    K1 = true
  end
  
  if n == 1 and z == 0 then
    K1 = false
  end
  
  -- KEY 2 to start RECORDING, KEY 2 again to STOP RECORDING
  -- KEY 2 LONG PRESS to CLEAR loop
  -- KEY 1 and KEY 2 flips direction of track
  -- KEY 1 and KEY 2 LONG PRESS turns off/on auto flipping for track.
  
 
  if n == 2 then
    recKey(z)
  end
    
  
  -- KEY 3 selects loop 
  -- KEY 1 and KEY 3 does micro loop
  if n == 3 and z == 1 then
    if recording then
      --protects from changing tracks while recording
    else
      if K1 then
        ft.microLoop(z)
      else
        curRec = (curRec + 1) % 6
        recRec = recVox[curRec + 1]  
        --ft.setVoice(curRec + 1)
        print('recording armed for voice',curRec + 1)
      end
    end
  end
  
  if n == 3 and z == 0 then
    if K1 then
      ft.microLoop(z)
    end
  end
  
end

function enc (n,d)
  redraw()
  if n==1 then
    if K1 then
    -- maybe to use for future alt options????
    
    elseif micro then
      posOff = posOff + (d*0.01)
      softcut.query_position(curRec+1)
    else
      posOff = 0.0675
    end
    
  end

  -- ENCODER 2 controls LEVEL
  if n == 2 then
    if K1 then
      -- TODO
      -- to change loopStart so that it effects the end 
      -- this isn't working out in the gui, for some reason
      
      --updateStarts(curRec+1,util.clamp(lStarts[curRec + 1] + (d * 1),0,49))
      --updateLoops(curRec+1,lEnd[curRec + 1])
      --params:set(loopLength[curRec+1],lStarts[curRec + 1])
    
    else
        
      scLev[curRec + 1] = util.clamp(scLev[curRec + 1] + (d * 0.01),0,1)
      sc.setLevel(curRec+1,scLev[curRec+1])
      print("loop",curRec+1, "level",scLev[curRec+1])
    end
    
    
  end
  
  -- ENCODER 3 controls PRE
  if n == 3 then
    if K1 then
      updateLoops(curRec+1,util.clamp(lEnd[curRec + 1] + (d * 1),0,49))
      params:set(loopLength[curRec+1],lEnd[curRec + 1])
    else
      scPre[curRec + 1] = util.clamp(scPre[curRec + 1] + (d * 0.01),0,1)
      sc.setPre(curRec+1,scPre[curRec+1])
      
      print("loop",curRec+1,"PRE level",scPre[curRec+1])
    end
  end

end



------------------------------------------------------------------
------------------------------------------------------------------
----------------- ___________________ ----------------------------
-----------------|                   |----------------------------
-----------------|   /\    /\  /\    |----------------------------
-----------------|  /  \  /  \/  \   |----------------------------
-----------------| /    \/        \  |----------------------------
-----------------|___________________|----------------------------
----------------- draw screen         ----------------------------
------------------------------------------------------------------
------------------------------------------------------------------


-- TODO
-- 
-- way to handle adjustable loopStart times
--
-- CBB
-- figure out a way to break up drawing of BG and playheads. 
-- should not need to redraw every element every time.
-- hope this will fix "warning: screen event Q full!" errors
-- doesn't bother me too much at the moment. 
-- just think it could be better


function redraw()
  screen.clear()
  ---------------------
  ------------------------------------------
  ---------------------
  -- recording selected
  -- rectangle drawn around active voice
  screen.level(math.ceil(scLev[curRec+1] * 16))
  screen.rect(4+recRec,4,18,56)
  screen.fill()
  ---------------------
  ------------------------------------------
  ---------------------
  
  -- draw bg field 
  -- voice 1
  for x=1,6 do
    screen.level(1)
    screen.rect(column_x[x],6,14,52)
    screen.fill()
  end
 
  ------------------------
  -- new algorithmic drawing of all tape tables
  
  for x=1,6 do
    for y=1,52 do
      if y < lEnd[x] and y > lStarts[x] then
        screen.level(math.ceil(tapeD[x][y]))
      else
        screen.level(math.ceil(16*scPre[x]))
      end
      screen.line_width(1)
      screen.move(column_x[x],y+6)
      screen.line(column_x[x]+14,y+6)
      screen.stroke(1) 
    end
  end
  
 
  ------------------------
  
  -- falling lines/playHeads
  for i=1,6 do
    screen.level(0)
    screen.line_width(1)
    screen.move(column_x[i],fall[i]+6+lStarts[i])
    screen.line(column_x[i]+14,fall[i]+6+lStarts[i])
    screen.stroke(2) 
  end
 
  
  screen.update()
end


local intro_animation = {}

local parrot_hop = 0
local parrot_hop_exit = 0
local p_hop_vector1 = vector:new(-10,64)
local p_hop_vector_around1 = vector:new(1,64)
local p_hop_vector2 = vector:new(11,64)
local p_hop_vector_around2 = vector:new(16,64)
local p_hop_vector3 = vector:new(21,64)
local p_hop_vector_around3 = vector:new(35,52)

local crow_hop = 0
local c_hop_vector1 = vector:new(145,64)
local c_hop_vector_around1 = vector:new(140,66)
local c_hop_vector2 = vector:new(135,64)
local c_hop_vector_around2 = vector:new(130,66)
local c_hop_vector3 = vector:new(125,64)
local c_hop_vector_around3 = vector:new(115,54)
local crow_animate = false
local crow_animate_starting = false
local parrot_animate_exit_started = false

intro_animation.anim_done = false

function intro_animation.animate_parrot()
  -- for i=1,9,1 do
  if parrot_hop < 9 then
    parrot_hop = parrot_hop + 1
    p_hop_vector1:rotate_around(p_hop_vector_around1,math.rad(-20))
  elseif parrot_hop < 18 then
    parrot_hop = parrot_hop + 1
    p_hop_vector2:rotate_around(p_hop_vector_around2,math.rad(-20))
  elseif parrot_hop < 29 then
    parrot_hop = parrot_hop + 1
    p_hop_vector3:rotate_around(p_hop_vector_around3,math.rad(-20))
  end
  if parrot_hop < 9 then
    screen.display_png("/home/we/dust/code/parrot/images/parrot.png",p_hop_vector1.x-45, p_hop_vector1.y-45) 
    screen.move(p_hop_vector1.x,p_hop_vector1.y)
    --screen.pixel(p_hop_vector1.x,p_hop_vector1.y)
  elseif parrot_hop < 18 then
    screen.display_png("/home/we/dust/code/parrot/images/parrot.png",p_hop_vector2.x-45, p_hop_vector2.y-45) 
    screen.move(p_hop_vector2.x,p_hop_vector2.y)
    --screen.pixel(p_hop_vector2.x,p_hop_vector2.y)
  -- elseif parrot_hop < 27 then
  else
    screen.display_png("/home/we/dust/code/parrot/images/parrot.png",p_hop_vector3.x-45, p_hop_vector3.y-45) 
    screen.move(p_hop_vector3.x,p_hop_vector3.y)
    --screen.pixel(p_hop_vector3.x,p_hop_vector3.y)
  end
  -- end
  screen.level(10)
  screen.stroke()
end

function intro_animation.start_animate_parrot_exit()
  clock.sleep(1)
  parrot_animate_exit_started = true
end

function intro_animation.animate_parrot_exit()
  if parrot_hop_exit < 9 then
    parrot_hop_exit = parrot_hop_exit + 1
    p_hop_vector3:rotate_around(p_hop_vector_around3,math.rad(20))
  elseif parrot_hop_exit < 18 then
    parrot_hop_exit = parrot_hop_exit + 1
    p_hop_vector2:rotate_around(p_hop_vector_around2,math.rad(20))
  elseif parrot_hop_exit < 29 then
    parrot_hop_exit = parrot_hop_exit + 1
    p_hop_vector1:rotate_around(p_hop_vector_around1,math.rad(20))
  else 
    screen.move(62,30)
    screen.level(15)
    screen.text_center("please connect crow")
    screen.move(62,45)
    screen.text_center("and reload the script")
    screen.stroke()
    screen.update()

  end
  if parrot_hop_exit < 9 then
    screen.display_png("/home/we/dust/code/parrot/images/parrot_exit.png",p_hop_vector3.x-45, p_hop_vector3.y-45) 
    screen.move(p_hop_vector3.x,p_hop_vector3.y)
    --screen.pixel(p_hop_vector3.x,p_hop_vector3.y)
  elseif parrot_hop_exit < 18 then
    screen.display_png("/home/we/dust/code/parrot/images/parrot_exit.png",p_hop_vector2.x-45, p_hop_vector2.y-45) 
    screen.move(p_hop_vector2.x,p_hop_vector2.y)
    --screen.pixel(p_hop_vector2.x,p_hop_vector2.y)
  -- elseif parrot_hop_exit < 27 then
  else
    screen.display_png("/home/we/dust/code/parrot/images/parrot_exit.png",p_hop_vector1.x-45, p_hop_vector1.y-45) 
    screen.move(p_hop_vector1.x,p_hop_vector1.y)
    --screen.pixel(p_hop_vector1.x,p_hop_vector1.y)
  end
  -- end
  screen.level(10)
  screen.stroke()
end

function intro_animation.start_animate_crow()
  crow_animate_starting = true
  clock.sleep(2)
  crow_animate = true
end

function intro_animation.animate_crow()
  if norns.crow.connected() == true and parrot_animate_exit_started == false then
    -- for i=1,9,1 do
    if crow_hop < 9 then
      crow_hop = crow_hop + 1
      c_hop_vector1:rotate_around(c_hop_vector_around1,math.rad(20))
    elseif crow_hop < 18 then
      crow_hop = crow_hop + 1
      c_hop_vector2:rotate_around(c_hop_vector_around2,math.rad(20))
    elseif crow_hop < 29 then
      crow_hop = crow_hop + 1
      c_hop_vector3:rotate_around(c_hop_vector_around3,math.rad(20))
    else
      crow_hop = crow_hop + 1
    end
    
    -- print("crow_hop",crow_hop)
    if crow_hop < 9 then
      screen.display_png("/home/we/dust/code/parrot/images/crow.png",c_hop_vector1.x-45, c_hop_vector1.y-48) 
      screen.move(c_hop_vector1.x,c_hop_vector1.y)
      --screen.pixel(c_hop_vector1.x,c_hop_vector1.y)
    elseif crow_hop < 18 then
      screen.display_png("/home/we/dust/code/parrot/images/crow.png",c_hop_vector2.x-45, c_hop_vector2.y-48) 
      screen.move(c_hop_vector2.x,c_hop_vector2.y)
      --screen.pixel(c_hop_vector2.x,c_hop_vector2.y)
    elseif crow_hop < 27 then
      screen.display_png("/home/we/dust/code/parrot/images/crow.png",c_hop_vector3.x-45, c_hop_vector3.y-48) 
      screen.move(c_hop_vector3.x,c_hop_vector3.y)
      --screen.pixel(c_hop_vector3.x,c_hop_vector3.y)
    elseif crow_hop < 70 then
      screen.display_png("/home/we/dust/code/parrot/images/crow.png",c_hop_vector3.x-45, c_hop_vector3.y-48) 
      if crow_hop > 35 then
        screen.display_png("/home/we/dust/code/parrot/images/crow_talk.png",70, 0) 
        screen.level(1)
        screen.move(85,13)
        local text = crow_hop < 57 and "caw" or "<3"
        screen.text(text)    
        screen.stroke()
        screen.update()
      end
      if crow_hop > 45 then
        screen.display_png("/home/we/dust/code/parrot/images/parrot_talk.png",20, 3) 
        screen.level(1)
        screen.move(33,16)
        local text = crow_hop < 57 and "caw" or "<3"
        screen.text(text)
        screen.stroke()
        screen.update()
      end
    end
  else
    clock.run(intro_animation.start_animate_parrot_exit)
  end
  screen.level(10)
  screen.stroke()
end

function intro_animation.update()

    --[[
  screen.display_png("/home/we/dust/code/parrot/images/parrot.png",25, 25) 
  screen.display_png("/home/we/dust/code/parrot/images/parrot_talk.png",20, 3) 
  screen.display_png("/home/we/dust/code/parrot/images/crow.png",70, 27) 
  screen.display_png("/home/we/dust/code/parrot/images/crow_talk.png",70, 0) 
  ]]

  if parrot_hop_exit < 29 then
    screen.level(15)
    screen.move(30,53)
    screen.rect(30,53,30,10)
    screen.move(32,60)
    screen.text("parrot")
    screen.move(70,53)
    screen.rect(70,53,30,10)
    screen.move(72,60)
    screen.text("crow")
    screen.stroke()
  end
    --[[
  screen.level(1)
  screen.move(85,13)
  screen.text("caw")
  screen.move(33,16)
  screen.text("caw")
  screen.stroke()
  ]]

  if crow_hop < 70 then
    if parrot_animate_exit_started == false then
      intro_animation.animate_parrot()
    else
      intro_animation.animate_parrot_exit()
    end

    if parrot_hop and parrot_hop > 27 then
      if  crow_animate == false and norns.crow.connected() == true and 
        crow_animate_starting == false then
        clock.run(intro_animation.start_animate_crow)
      elseif crow_animate == true then
        intro_animation.animate_crow()
      elseif crow_animate == false and 
         (crow_animate_starting == true or 
          norns.crow.connected() == false and 
          parrot_animate_exit_started == false) then
        
        screen.display_png("/home/we/dust/code/parrot/images/parrot_talk.png",20, 3)     
        screen.move(30,16)
        screen.level(1)
        screen.text("caw?")
        screen.stroke()
        if norns.crow.connected() == false then
          clock.run(intro_animation.start_animate_parrot_exit)
        end
      end
    end
  else 
    print("anim done")
    intro_animation.anim_done = true
    screen.clear()
  end
end
return intro_animation
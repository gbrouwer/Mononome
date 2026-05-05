-- screen instructions=accessed by pressing Key 1 (K1) and Key 2 (K2)

local instructions = {}

instructions.display = function ()
  screen.level(15)
  screen.move(1,20)
  screen.text("  e2: -/+ ctrl")
  screen.move(1, 28)
  screen.text("  k2/3: -/+ sub-ctrl")

  if cv_recorder.active_control == 1 then
    screen.move(1, 44)
    screen.text("  bz=bucket zoom")
    screen.move(1, 52)
    screen.text("  scale cv visualization")
  elseif cv_recorder.active_control == 2 then
    screen.move(1, 44)
    screen.text("  br=bucket record")
    screen.move(1, 52)
    screen.text("  record inputs 1/2")
  elseif cv_recorder.active_control == 3 then
    screen.move(1, 44)
    screen.text("  bl=bucket loop length")
    screen.move(1, 52)
    screen.text("  length of buckets 1/2")
  elseif cv_recorder.active_control == 4 then
    screen.move(1, 44)
    screen.text("  ta=tap assignment")
    screen.move(1, 52)
    screen.text("  link inputs to outputs")
  elseif cv_recorder.active_control == 5 then
    screen.move(1, 44)
    screen.text("  td=tap delay")
    screen.move(1, 52)
    screen.text("  delay taps 1-4")
  elseif cv_recorder.active_control == 6 then
    screen.move(1, 44)
    screen.text("  tq=quantize taps")
    screen.move(1, 52)
    screen.text("  quantize to set scale")
  end
  screen.update()
end

return instructions

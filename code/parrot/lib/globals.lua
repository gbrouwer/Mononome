-- global functions and variables 

-------------------------------------------
-- global functions
-------------------------------------------
fn = {}
page_scroll = function (delta)
  pages:set_index_delta(util.clamp(delta, -1, 1), false)
end

-- scale/note/quantize functions
SCALE_LENGTH_DEFAULT = 45 
ROOT_NOTE_DEFAULT = 33 --(A0)
NOTE_OFFSET_DEFAULT = 33 --(A0)
scale_names = {}
notes = {}
current_note_indices = {}
saving = false

for i= 1, #MusicUtil.SCALES do
  table.insert(scale_names, string.lower(MusicUtil.SCALES[i].name))
end

fn.build_scale = function()
  notes = {}
  -- notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), params:get("scale_length"))
  notes = MusicUtil.generate_scale_of_length(params:get("root_note"), params:get("scale_mode"), SCALE_LENGTH_DEFAULT)
  -- local num_to_add = SCALE_LENGTH_DEFAULT - #notes
  local scale_length = SCALE_LENGTH_DEFAULT
  -- for i = 1, num_to_add do
  for i = 1, scale_length do
    table.insert(notes, notes[i])
    -- table.insert(notes, notes[SCALE_LENGTH_DEFAULT - num_to_add])
  end
  print("build scale")
  crow.public.notes = {}
  crow.public.notes = notes
  -- engine.update_scale(table.unpack(notes))
end

fn.quantize = function(volts)
  local note_num = volts * 12
  local new_note_num
  for i=1,#notes-1,1 do
    if note_num >= notes[i] and note_num <= notes[i+1] then
      if note_num - notes[i] < notes[i+1] - note_num then
        new_note_num = notes[i]
      else
        new_note_num = notes[i+1]
      end
      break
    end
  end
  return new_note_num
end
-------------------------------------------
-- global variables
-------------------------------------------
NUM_PAGES = 1
show_instructions = false
updating_controls = false
SCREEN_FRAMERATE = 1/15
pages = 0

alt_key_active = false
screen_level_graphics = 15

menu_status = norns.menu.status()
clear_subnav = true
-- screen_dirty = true

initializing_norns = true
initializing_crow = true
CV_LOOP_LENGTH_DEFAULT = 400
MAX_VISIBLE_BUCKET = 80
MAX_BUCKET_LENGTH = 1000

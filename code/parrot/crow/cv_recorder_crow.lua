--- control voltage delay
-- input1: CV to delay
-- input2: 0v = capture, 5v = loop (continuous)
-- output1-4: delay equaly spaced delay taps

-- note: length units are increments of 
MAX_BUCKET_LENGTH = 1000 -- max loop time. MUST BE CONSTANT 
INIT_LENGTH = 400
-- CV_SAMPLING_RATE = 25
-- MAX_BUCKET_LENGTH = 1000 -- max loop time. MUST BE CONSTANT (1000 = to 20s)

public{tap1_b1 = 1}:range(1,MAX_BUCKET_LENGTH):type'slider'
public{tap2_b1 = 1}:range(1,MAX_BUCKET_LENGTH):type'slider'
public{tap3_b1 = 1}:range(1,MAX_BUCKET_LENGTH):type'slider'
public{tap4_b1 = 1}:range(1,MAX_BUCKET_LENGTH):type'slider'
public{loop_b1 = 0.001}:range(0,1):type'slider'
public{recorder_state_b1 = 'on'}:options{'off','on'}
public{loop_length_b1 = INIT_LENGTH}:range(1,MAX_BUCKET_LENGTH)

public{tap1_b2 = 1}:range(1,MAX_BUCKET_LENGTH):type'slider'
public{tap2_b2 = 1}:range(1,MAX_BUCKET_LENGTH):type'slider'
public{tap3_b2 = 1}:range(1,MAX_BUCKET_LENGTH):type'slider'
public{tap4_b2 = 1}:range(1,MAX_BUCKET_LENGTH):type'slider'
public{loop_b2 = 0.001}:range(0,1):type'slider'
public{recorder_state_b2 = 'on'}:options{'off','on'}
public{loop_length_b2 = INIT_LENGTH}:range(1,MAX_BUCKET_LENGTH)


public{loop_restart1 = 'false'}:range('false','true')
public{loop_restart2 = 'false'}:range('false','true')

-- public{bucket1_slice = 1}:range(-5,10)
-- public{bucket1_ix = 1}:range(1,MAX_BUCKET_LENGTH)
-- public{bucket2_slice = 1}:range(-5,10)
-- public{bucket2_ix = 1}:range(1,MAX_BUCKET_LENGTH)

public{cv_assignment_tap1 = 1}:range(1,6)
public{cv_assignment_tap2 = 1}:range(1,6)
public{cv_assignment_tap3 = 1}:range(1,6)
public{cv_assignment_tap4 = 1}:range(1,6)

public{quantize_tap1 = 'off'}:options{'off','on'}
public{quantize_tap2 = 'off'}:options{'off','on'}
public{quantize_tap3 = 'off'}:options{'off','on'}
public{quantize_tap4 = 'off'}:options{'off','on'}

public{notes = {11,12,13}}


public{reset1 = 0}
public{reset2 = 0}
-- public{p_bucket = {}}


bucket1 = {}
bucket2 = {}
write1 = 1
write2 = 1
cv_mode1 = 0
cv_mode2 = 0

inited = false

function init()
    public{capture = 0}:action(p_notes)
    
    -- stream rate is set to ___kHz so the crow memory buffer doesn't fill up
    local STREAM_RATE = 0.008 --8 kHz
    print("stream rate (kHz): " .. STREAM_RATE )
    input[1].mode('stream', STREAM_RATE) 
    input[2].mode('stream', STREAM_RATE) 
    
    for n=1,4 do output[n].slew = 0.002 end -- smoothing at nyquist
    -- for n=1,4 do output[n].slew = 0.002 end -- smoothing at nyquist
    for n=1,MAX_BUCKET_LENGTH  do 
        -- print("clear buf",n)
        bucket1[n] = 0 
        bucket2[n] = 0 
    end -- clear the buffer
    print("init crow streaming")
    
    public.view.input[1]( true )
    public.view.input[2]( true )
    -- public.view.all( true )
    inited = true
end

function quantize(volts)
    local note_num = 60 + (volts*12)
    local new_note_num = 1
    -- print("note num before ", note_num)
    
    for i=1,#public.notes-1,1 do
        if note_num >= public.notes[i] and note_num <= public.notes[i+1] then
            if note_num - public.notes[i] < public.notes[i+1] - note_num then
                new_note_num = public.notes[i]
            else
                new_note_num = public.notes[i+1]
            end
            break
        end
    end
    local new_volts = (new_note_num-60)/12
    return new_volts
end

  
function reset(bucket)
    for n=1,MAX_BUCKET_LENGTH do bucket[n] = 0 end -- clear the buffer
    if bucket == 1 then
        write1 = 1
    else
        write2 = 1
    end
end

function peek(bucket,tap)
    if bucket == 1 then
        local ix = (math.floor(write1 - tap - 1) % MAX_BUCKET_LENGTH) + 1
        return bucket1[ix]
    else
        local ix = (math.floor(write2 - tap - 1) % MAX_BUCKET_LENGTH) + 1
        return bucket2[ix]
    end
end

function poke(bucket, v, ix)
    -- local c = (input[2].volts / 4.5) + public.loop
    -- c = (c < 0) and 0 or c
    -- c = (c > 1) and 1 or c
    if bucket == 1 then
        local c = public.loop_b1
        bucket1[ix] = v + c*(bucket1[ix] - v)
        -- if ix%CV_SAMPLING_RATE == 0 then
            -- public.bucket1_slice =  v + c*(bucket1[ix] - v)
            -- public.bucket1_ix = ix
        -- end
    else
        local c = public.loop_b2
        -- print("poke2")
        bucket2[ix] = v + c*(bucket2[ix] - v)
        -- if ix%CV_SAMPLING_RATE == 0 then
            -- public.bucket2_slice =  v + c*(bucket2[ix] - v)
            -- public.bucket2_ix = ix
        -- end
    end
end

function output_volts(bucket, tap, quant, volts)
    -- print(tap, quant,volts)
    if bucket == 1 then
        if public.recorder_state_b1 == "off" then
            volts = peek(bucket, tap) 
        end
    elseif bucket == 2 then
        if public.recorder_state_b2 == "off" then
            volts = peek(bucket, tap) 
            -- print("off",volts)
        else
            -- print("on",volts)
        end
    end
    local do_quant = quant 
    if do_quant == "on" then
        volts = quantize(volts)
    end
    return volts 
end 

function output_and_volts(tap)
    local volts1 = peek(1, tap) 
    local volts2 = peek(2, tap) 
    local volts = volts1 <= volts2 and volts1 or volts2
    -- print(volts1 .. "/" .. volts2 .. "/" .. volts)
    return volts 
end 

function output_or_volts(tap)
    local volts1 = peek(1, tap) 
    local volts2 = peek(2, tap) 
    local volts = volts1 >= volts2 and volts1 or volts2
    -- print(volts1 .. "/" .. volts2 .. "/" .. volts)
    return volts 
end 

function rectify(volts)
    local rectified
    if volts < 0 then rectified = -1 * volts else rectified = volts end
    return rectified
end

input[1].stream = function(v)
    if (inited == true) then
        if public.reset1 == 1 then 
            public.reset1 = 0
            reset(1)
        else
            if public.cv_assignment_tap1 == 1 then 
                output[1].volts = output_volts(1, public.tap1_b1, public.quantize_tap1, v)
            end
            if public.cv_assignment_tap2 == 1 then 
                output[2].volts = output_volts(1, public.tap2_b1, public.quantize_tap2, v)
            end
            if public.cv_assignment_tap3 == 1 then 
                output[3].volts = output_volts(1, public.tap3_b1, public.quantize_tap3, v)
            end
            if public.cv_assignment_tap4 == 1 then 
                output[4].volts = output_volts(1, public.tap4_b1, public.quantize_tap4, v)
            end
            
            -- check for RECTIFY  
            if public.cv_assignment_tap1 == 5 then 
                output[1].volts = output_volts(1, public.tap1_b1, public.quantize_tap1, rectify(v))
            end
            if public.cv_assignment_tap2 == 5 then 
                output[2].volts = output_volts(1, public.tap2_b1, public.quantize_tap2, rectify(v))
            end
            if public.cv_assignment_tap3 == 5 then 
                output[3].volts = output_volts(1, public.tap3_b1, public.quantize_tap3, rectify(v))
            end
            if public.cv_assignment_tap4 == 5 then 
                output[4].volts = output_volts(1, public.tap4_b1, public.quantize_tap4, rectify(v))
            end

            
            -- local record_cv = input[2].volts
            if public.recorder_state_b1 == "on" then
                poke(1, v, write1)
            end

            -- check for OR  
            if public.cv_assignment_tap1 == 3 then 
                output[1].volts = output_or_volts(1)
            end
            if public.cv_assignment_tap2 == 3 then 
                output[2].volts = output_or_volts(2)
            end
            if public.cv_assignment_tap3 == 3 then 
                output[3].volts = output_or_volts(3)
            end
            if public.cv_assignment_tap4 == 3 then 
                output[4].volts = output_or_volts(4)
            end
            
            -- check for AND  
            if public.cv_assignment_tap1 == 4 then 
                output[1].volts = output_and_volts(1)
            end
            if public.cv_assignment_tap2 == 4 then 
                output[2].volts = output_and_volts(2)
            end
            if public.cv_assignment_tap3 == 4 then 
                output[3].volts = output_and_volts(3)
            end
            if public.cv_assignment_tap4 == 4 then 
                output[4].volts = output_and_volts(4)
            end

            if (write1 % public.loop_length_b1) == 0 then
                -- print("restart 1",public.loop_length_b1)
                public.loop_restart1 = "true"
            end
            write1 = (write1 % public.loop_length_b1) + 1
        end
    end
end

input[2].stream = function(v)
    if (inited == true) then
        if public.reset2 == 1 then 
            -- print("reset")
            public.reset2 = 0
            reset(2)
        else
            if public.cv_assignment_tap1 == 2 then 
                output[1].volts = output_volts(2, public.tap1_b2, public.quantize_tap1, v)
            end
            if public.cv_assignment_tap2 == 2 then 
                output[2].volts = output_volts(2, public.tap2_b2, public.quantize_tap2, v)
            end
            if public.cv_assignment_tap3 == 2 then 
                output[3].volts = output_volts(2, public.tap3_b2, public.quantize_tap3, v)
            end
            if public.cv_assignment_tap4 == 2 then 
                output[4].volts = output_volts(2, public.tap4_b2, public.quantize_tap4, v)
            end

            -- check for RECTIFY  
            if public.cv_assignment_tap1 == 6 then 
                output[1].volts = output_volts(1, public.tap1_b1, public.quantize_tap1, rectify(v))
            end
            if public.cv_assignment_tap2 == 6 then 
                output[2].volts = output_volts(1, public.tap2_b1, public.quantize_tap2, rectify(v))
            end
            if public.cv_assignment_tap3 == 6 then 
                output[3].volts = output_volts(1, public.tap3_b1, public.quantize_tap3, rectify(v))
            end
            if public.cv_assignment_tap4 == 6 then 
                output[4].volts = output_volts(1, public.tap4_b1, public.quantize_tap4, rectify(v))
            end
            
           
            -- local record_cv = input[2].volts
            if public.recorder_state_b2 == "on" then
                poke(2, v, write2)
            end
            if (write2 % public.loop_length_b2) == 0 then
                -- print("restart 2",public.loop_length_b2)
                public.loop_restart2 = "true"
            end
            write2 = (write2 % public.loop_length_b2) + 1
        end
    end
end
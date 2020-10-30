-- ??? v0.1.0
-- ???
--
-- llllllll.co/t/?
--
--
--
--    ▼ instructions below ▼

-- docs: https://monome.org/docs/norns/api/modules/softcut.html

--
-- globals
--

-- user state
us={
  mode=0,-- 0=sampler,1=pattern,2==chain
  update_ui=false,
  zoomed=false,
  playing=false,
  message='',
  available_files={},
  waveform_samples={},
  waveform_view={0,0},
  interval=0,
  scale=0,
  sample_cur=1,
  pattern_cur=1,
}

-- user parameters
-- put things that can be saved
-- don't put things here that can be put into global parameters
up={
  filename_save='1.json',
  filename='',
  length=0,
  rate=1,
  samples={},
  patterns={},
  chain={1,0,0,0,0,0,0,0,0,0},
}

-- user constants
uc={
  update_timer_interval=0.05,
  audio_dir=_path.audio..'a/',
  code_dir=_path.code..'a/',
}
--
-- initialization
--

function init()
  -- determine which files are available
  -- us.available_files={'amenbreak.wav'}
  -- us.available_saves={''}
  
  -- parameters
  -- params:add {
  --   type='option',
  --   id='choose_save',
  --   name='Choose save',
  --   options=us.available_save,
  --   action=function(value)
  --     up.filename_save=us.available_files[value]
  --   end
  -- }
  -- params:add {
  --   type='trigger',
  --   id='load_save',
  --   name='Load previous',
  --   action=function(value)
  --     if value=='-' then
  --       return
  --     end
  --     -- TODO: load a file name and the sample
  --   end
  -- }
  -- params:add {
  --   type='option',
  --   id='choose_sample',
  --   name='Choose sample',
  --   options={'amenbreak.wav'},
  --   action=function(value)
  --     up.filename=us.available_files[value]
  --   end
  -- }
  -- params:add {
  --   type='trigger',
  --   id='load_loops',
  --   name='Load loops',
  --   action=function(value)
  --     if value=='-' then
  --       return
  --     end
  --     load_sample()
  --     update_parameters()
  --   end
  -- }
  
  -- initialize softcut
  softcut.event_render(update_render)
  
  -- initialize samples
  for i=1,9 do
    up.samples[i]={}
    up.samples[i].start=0
    up.samples[i].length=0
    up.patterns[i]={}
  end
  
  -- update clocks
  clock.run(update_beat)
  
  -- initialize timer for updating screen
  timer=metro.init()
  timer.time=uc.update_timer_interval
  timer.count=-1
  timer.event=update_timer
  timer:start()
  
  up.filename=uc.code_dir..'sounds/amen.wav'
  load_sample()
end

--
-- updaters
--
function update_render(ch,start,i,s)
  us.waveform_samples=s
  us.interval=i
  us.update_ui=true
end

function update_timer()
  if us.update_ui then
    redraw()
  end
end

function update_beat()
  while true do
    clock.sync(1/16)
    if us.playing==false then goto continue end
    local beatstep=math.floor(clock.get_beats())%16
    -- TODO: figure out position in chain/pattern/sample
    -- TODO: add effects
    ::continue::
  end
end

function update_parameters()
  
end

function update_waveform_view(pos1,pos2)
  us.waveform_view={pos1,pos2}
  -- render new waveform
  softcut.render_buffer(1,pos1,pos2,128)
end

--
-- sample controls
--
function load_sample()
  -- load file
  up.length,up.rate=load_file(up.filename)
  update_waveform_view(0,up.length)
end

--
-- input
--

function enc(n,d)
  if n==2 then
    up.samples[us.sample_cur].start=util.clamp(up.samples[us.sample_cur].start+d/1000,us.waveform_view[1],us.waveform_view[2])
  elseif n==3 then
    up.samples[us.sample_cur].length=util.clamp(up.samples[us.sample_cur].length+d/1000,0,us.waveform_view[2]-up.samples[us.sample_cur].start)
  end
  us.update_ui=true
end

function key(n,z)
  if n==2 and z==1 then
    if up.samples[us.sample_cur].start==us.waveform_view[1] and up.samples[us.sample_cur].start+up.samples[us.sample_cur].length==us.waveform_view[2] then
      update_waveform_view(0,up.length)
    else
      print("zooming to "..up.samples[us.sample_cur].start..","..up.samples[us.sample_cur].start+up.samples[us.sample_cur].length)
      update_waveform_view(up.samples[us.sample_cur].start,up.samples[us.sample_cur].start+up.samples[us.sample_cur].length)
    end
  end
end

--
-- ui
--

function redraw()
  us.update_ui=false
  screen.clear()
  
  -- plot waveform
  -- https://github.com/monome/softcut-studies/blob/master/8-copy.lua
  if #us.waveform_samples>0 then
    screen.level(4)
    local x_pos=0
    local scale=20
    for i,s in ipairs(us.waveform_samples) do
      local height=util.round(math.abs(s)*scale)
      screen.move(x_pos,45-height)
      screen.line_rel(0,2*height)
      screen.stroke()
      x_pos=x_pos+1
    end
    screen.level(15)
    for i,s in ipairs(up.samples) do
      if s.start>0 and s.length>0 then
        x_pos=util.linlin(us.waveform_view[1],us.waveform_view[2],1,128,s.start)
        screen.move(x_pos,25)
        screen.line_rel(0,64-25)
        x_pos=util.linlin(us.waveform_view[1],us.waveform_view[2],1,128,s.start+s.length)
        screen.move(x_pos,25)
        screen.line_rel(0,64-25)
      end
    end
    screen.stroke()
  end
  
  -- show message if exists
  if us.message~="" then
    screen.level(0)
    x=64
    y=28
    w=string.len(us.message)*6
    screen.rect(x-w/2,y,w,10)
    screen.fill()
    screen.level(15)
    screen.rect(x-w/2,y,w,10)
    screen.stroke()
    screen.move(x,y+7)
    screen.text_center(us.message)
  end
  
  screen.update()
end

--
-- utils
--
function show_message(message)
  clock.run(function()
    us.message=message
    redraw()
    clock.sleep(0.5)
    us.message=""
    redraw()
  end)
end

function readAll(file)
  local f=assert(io.open(file,"rb"))
  local content=f:read("*all")
  f:close()
  return content
end

function calculate_lfo(current_time,period,offset)
  if period==0 then
    return 1
  else
    return math.sin(2*math.pi*current_time/period+offset)
  end
end

function round(x)
  return x>=0 and math.floor(x+0.5) or math.ceil(x-0.5)
end

function sign(x)
  if x>0 then
    return 1
  elseif x<0 then
    return-1
  else
    return 0
  end
end

function round_time_to_nearest_beat(t)
  seconds_per_qn=60/clock.get_tempo()
  remainder=t%seconds_per_qn
  if remainder==0 then
    return t
  end
  return t+seconds_per_qn-remainder
end

function load_file(file)
  print("loading "..file)
  softcut.buffer_clear_region(1,-1)
  local ch,samples,samplerate=audio.file_info(file)
  rate=samplerate/48000.0 -- compensate for files that aren't 48Khz
  duration=samples/48000.0
  softcut.buffer_read_mono(file,0,0,-1,1,1)
  print("loaded "..file.." sr="..samplerate..", duration="..duration)
  return duration,rate
end

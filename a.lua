-- ??? v0.1.0
-- ???
--
-- llllllll.co/t/?
--
--
--
--    ▼ instructions below ▼
-- K1+K2 toggles sample/pattern/chain mode
-- K1+K3 starts/stops pattern/chain
-- K2 zooms (sample mode) or patterns (pattern mode)
-- K3 plays current sample
-- E1 changes sample (sample+pattern) or pattern (chain)
-- E2 changes start (sample+pattern), chain position (chain)
-- E3 changes length (sample+pattern), pattern at current chain position (chain)


-- docs: https://monome.org/docs/norns/api/modules/softcut.html

--
-- globals
--

-- user state
us={
  mode=0,-- 0=sampler,1=pattern,2==chain
  shift=false,
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
  chain_cur=1,
  samples_playing={0,0},
}
-- user parameters
-- put things that can be saved
-- don't put things here that can be put into global parameters
up={
  filename_save='1.json',
  filename='',
  length=0,
  rate=1,
  bpm=0,
  samples={},
  patterns={},
  chain={1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
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
  for i=1,2 do
    softcut.enable(i,1)
    softcut.level(i,1)
    softcut.pan(i,0)
    softcut.rate(i,1)
    softcut.loop(i,0)
    softcut.rec(i,0)
    softcut.buffer(i,1)
    softcut.position(i,0)
  end
  softcut.event_render(update_render)

  -- initialize samples
	local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
  for i=1,26 do
    up.samples[i]={}
    up.samples[i].start=0
    up.samples[i].length=0
    up.samples[i].name=alphabet:sub(i,i)
  end
  for i=1,8 do
    up.patterns[i]={0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}
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
  up.samples[1]={start=0.3,length=0.2}
  up.patterns[1][1]=3
  up.patterns[1][2]=4
  up.patterns[1][3]=4
  up.patterns[1][4]=4
  up.patterns[1][5]=1
  up.patterns[1][6]=1
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
  softcut.render_buffer(1,pos1,pos2-pos1,128)
end

--
-- sample controls
--
function load_sample()
  -- load file
  up.length,up.rate,up.bpm=load_file(up.filename)
  update_waveform_view(0,up.length)
end

function sample_one_shot()
  local s=up.samples[us.sample_cur].start
  local e=up.samples[us.sample_cur].start+up.samples[us.sample_cur].length
  clock.run(function()
    us.samples_playing={s,e}
    redraw()
    clock.sleep(e-s)
    us.samples_playing={0,0}
    redraw()
  end)
  softcut.rate(2,up.rate*clock.get_tempo()/up.bpm)
  softcut.position(2,s)
  softcut.loop_start(2,s)
  softcut.loop_end(2,e)
  softcut.play(2,1)
end

--
-- input
--

function enc(n,d)
  if n==1 then
    us.sample_cur=util.clamp(us.sample_cur+sign(d),1,9)
  elseif n==2 then
    up.samples[us.sample_cur].start=util.clamp(up.samples[us.sample_cur].start+d/1000,us.waveform_view[1],us.waveform_view[2])
    if up.samples[us.sample_cur]==0 then
      up.samples[us.sample_cur]=clock.get_beat_sec()/16
    end
  elseif n==3 then
    local x=d*clock.get_beat_sec()/16
    up.samples[us.sample_cur].length=util.clamp(up.samples[us.sample_cur].length+x,0,us.waveform_view[2]-up.samples[us.sample_cur].start)
  end
  us.update_ui=true
end

function key(n,z)
  if n==1 then
    us.shift=(z==1)
  elseif n==2 and z==1 and us.shift then
    -- toggle sample/pattern/chain mode
    us.mode=us.mode+1
    if us.mode>2 then
      us.mode=0
    end
  elseif n==2 and z==1 then
    if up.samples[us.sample_cur].start==us.waveform_view[1] and up.samples[us.sample_cur].start+up.samples[us.sample_cur].length==us.waveform_view[2] then
      update_waveform_view(0,up.length)
    else
      print("zooming to "..up.samples[us.sample_cur].start..","..up.samples[us.sample_cur].start+up.samples[us.sample_cur].length)
      update_waveform_view(up.samples[us.sample_cur].start,up.samples[us.sample_cur].start+up.samples[us.sample_cur].length)
    end
  elseif n==3 and z==1 then
    -- play a sample at curent position
    sample_one_shot()
  end
end

--
-- ui
--

function redraw()
  us.update_ui=false
  screen.clear()

  -- check shift
  local shift_amount=0
  if us.shift then
    shift_amount=4
  end

  -- show sample info
  screen.level(15)
  screen.rect(1,1,7,8)
  screen.stroke()
  screen.move(2,7)
  screen.text(up.samples[us.sample_cur].name)

  -- show pattern info
  screen.level(4)
  screen.rect(10,1,7,8)
  screen.stroke()
  isone=0
  if us.pattern_cur==1 then
    isone=1
  end
  screen.move(11+isone,7)
  screen.text(us.pattern_cur)

  -- show chain info
  for i=1,#up.chain do
    if i==us.chain_cur and us.mode==2 then
      screen.level(15)
    else
      screen.level(4)
    end
    if up.chain[i]>0 then
      isone=0
      if up.chain[i]==1 then
        isone=1
      end
      screen.move(19+(i-1)*7+isone,7)
      screen.text(up.chain[i])
    end
  end

  -- show pattern
  local p=up.patterns[us.pattern_cur]
  for i=1,16 do
    screen.level(4)
    if p[i]==us.sample_cur and us.mode==1 then
      screen.level(15)
    end
    if p[i]~=0 then
      if i>1 and p[i-1]==p[i] then
        if i<16 and p[i+1]==p[i] then
          screen.rect(1+(i-1)*8,13,8,5)
        else
          screen.rect(1+(i-1)*8,13,7,5)
        end
      else
        screen.move(1+(i-1)*8,18)
        screen.text(up.samples[p[i]].name)
        if i<16 and p[i+1]==p[i] then
          screen.rect(6+(i-1)*8,13,3,5)
        else
          screen.rect(6+(i-1)*8,13,2,5)
        end
      end
    else
      screen.rect(1+(i-1)*8,13,7,5)
    end
    screen.fill()
  end

  -- plot waveform
  -- https://github.com/monome/softcut-studies/blob/master/8-copy.lua
  if #us.waveform_samples>0 then
    screen.level(4)
    local x_pos=0
    local scale=19
    for i,s in ipairs(us.waveform_samples) do
      local height=util.round(math.abs(s)*scale)
      local current_time=util.linlin(0,128,us.waveform_view[1],us.waveform_view[2],x_pos)
      if current_time>us.samples_playing[1] and current_time<us.samples_playing[2] then
        screen.level(15)
      else
        screen.level(4)
      end
      screen.move(i,45-height)
      screen.line_rel(0,2*height)
      screen.stroke()
      x_pos=x_pos+1
    end
    screen.level(15)
    for i,s in ipairs(up.samples) do
      if s.length>0 then
        x_pos=util.linlin(us.waveform_view[1],us.waveform_view[2],1,128,s.start)
        screen.move(x_pos-1,26)
        screen.text(up.samples[i].name)
        screen.move(x_pos,29)
        screen.line_rel(0,34)
        screen.move(x_pos,62)
        screen.line_rel(3,3)
        screen.move(x_pos,29)
        screen.line_rel(3,-3)
        x_pos=util.linlin(us.waveform_view[1],us.waveform_view[2],1,128,s.start+s.length)
        screen.move(x_pos,29)
        screen.line_rel(0,34)
        screen.move(x_pos+1,64)
        screen.text(up.samples[i].name)
        screen.move(x_pos,62)
        screen.line_rel(-3,3)
        screen.move(x_pos,29)
        screen.line_rel(-3,-3)
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
  local bpm=clock.get_bpm()
  -- TODO: get bpm from file
  return duration,rate,bpm
end

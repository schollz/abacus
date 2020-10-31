-- abacus v0.1.0
-- counting frame for music
--
-- llllllll.co/t/?
--
--
--
--    ▼ instructions below ▼
-- K1+E1 changes sample/pattern/chain mode
-- K1+K3 starts/stops pattern/chain
-- K2 zooms (sample mode) or patterns (pattern mode)
-- K3 plays current sample
-- E1 changes sample (sample+pattern) or pattern (chain)
-- E2 changes start (sample+pattern), chain position (chain)
-- E3 changes sample length (sample)
-- E3 changes pattern (pattern mode)
-- E3 changes chain position (chain mode)
-- K1+K2 erases patterns (pattern mode)
-- E3 changes
-- docs: https://monome.org/docs/norns/api/modules/softcut.html

json=include("lib/json")

--
-- globals
--

-- user state
us={
  mode=0,-- 0=sampler,1=pattern,2==chain
  shift=false,
  update_ui=false,
  zoomed=false,
  message='',
  available_files={},
  waveform_samples={},
  waveform_view={0,0},
  interval=0,
  scale=0,
  sample_cur=1,
  pattern_cur=1,
  chain_cur=1,
  pattern_temp={start=1,length=1},
  playing=false,-- is playing or not
  playing_sample={0,0},-- width of sample being played
  playing_beat=0,-- current
  playing_chain=1,
  playing_pattern=0,-- current pattern
  playing_pattern_segment=0,-- current sample pattern (sample id + random int decimal)
  playing_loop_end=0,
  samples_usable={},
  samples_usable_id=1,
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
  chain={1,2,3,4,0,0,0,0,0,0,0,0,0,0,0,0},
}

-- user constants
uc={
  update_timer_interval=0.05,
  audio_dir=_path.audio..'abacus/',
  code_dir=_path.code..'abacus/',
  data_dir=_path.data..'abacus/',
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
  local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZ'
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

  up.filename=uc.code_dir..'sounds/rach1.wav'
  load_sample()
  up.bpm=120
  -- us.sample_cur=2
  -- up.samples[1].start=0.32
  -- up.samples[1].length=4*clock.get_beat_sec()/4
  -- up.samples[2].start=0
  -- up.samples[2].length=4*clock.get_beat_sec()/4
  -- up.samples[3].start=0.591
  -- up.samples[3].length=2*clock.get_beat_sec()/4
  -- up.patterns[1][1]=2
  -- up.patterns[1][2]=2
  -- up.patterns[1][3]=2
  -- up.patterns[1][4]=2
  -- up.patterns[1][7]=1
  -- up.patterns[1][8]=1
  -- up.patterns[1][9]=1
  -- up.patterns[1][10]=1
  -- up.patterns[1][13]=3.1
  -- up.patterns[1][14]=3.1
  -- up.patterns[1][15]=3.2
  -- up.patterns[1][16]=3.2
  -- up.patterns[2][1]=2
  -- up.patterns[2][2]=2
  -- up.patterns[2][3]=2
  -- up.patterns[2][4]=2
  -- up.patterns[3][1]=2
  -- up.patterns[3][2]=2
  -- up.patterns[3][3]=2
  -- up.patterns[3][4]=2
  -- up.patterns[4][1]=2
  -- up.patterns[4][2]=2
  -- up.patterns[4][3]=2
  -- up.patterns[4][4]=2
  parameters_load("play.json")
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
  local current_voice=1
  local p=up.patterns[1]
  while true do
    clock.sync(1/4)
    if us.playing==false then goto continue end
    clock.run(function()
      us.playing_beat=us.playing_beat+1
      if us.playing_beat>16 then
        us.playing_chain=us.playing_chain+1
        if us.playing_chain>#up.chain or up.chain[us.playing_chain]==0 then
          us.playing_chain=1
        end
        us.pattern_cur=up.chain[us.playing_chain]
        p=up.patterns[up.chain[us.playing_chain]]
        us.playing_beat=1
      end
      -- if silence, continue
      local playing_pattern_segment=p[us.playing_beat]
      -- get sample id from the pattern segment
      local sample_id=math.floor(playing_pattern_segment)
      if sample_id==0 then
        us.playing_pattern_segment=0
        us.playing_sample={0,0}
        redraw()
        return
      end
      if playing_pattern_segment==us.playing_pattern_segment then
        return
      end
      us.playing_pattern_segment=playing_pattern_segment
      local start=us.playing_beat
      local finish=start
      for j=start,16 do
        if us.playing_pattern_segment~=p[j] then
          finish=j
          break
        end
      end
      if start==16 then
        finish=17
      end
      -- play sample
      local sample_start=up.samples[sample_id].start
      if up.samples[sample_id].start+up.samples[sample_id].length~=us.playing_loop_end then
        us.playing_loop_end=up.samples[sample_id].start+up.samples[sample_id].length
        softcut.loop_end(1,us.playing_loop_end)
      end
      us.playing_sample={up.samples[sample_id].start,us.playing_loop_end}
      softcut.position(1,up.samples[sample_id].start)
      -- softcut.rate(1,up.rate*clock.get_tempo()/up.bpm)
      -- softcut.loop_start(1,sample_start)
      -- softcut.level(1,1)
      -- softcut.play(1,1)
      -- TODO: figure out position in chain/pattern/sample
      -- TODO: add effects
      redraw()
    end)
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
-- pattern controls
--

function pattern_stamp(sampleid,start,length)
  local p=table.clone(up.patterns[us.pattern_cur])
  rvalue=math.random()
  for i=start,start+length-1 do
    p[i]=sampleid+rvalue
  end
  return p
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
  print("sample_length "..up.samples[us.sample_cur].length)
  clock.run(function()
    us.playing_sample={s,e}
    redraw()
    clock.sleep(e-s)
    us.playing_sample={0,0}
    redraw()
  end)
  softcut.rate(2,up.rate*clock.get_tempo()/up.bpm)
  softcut.position(2,s)
  softcut.loop_start(2,s)
  softcut.loop_end(2,e)
  softcut.play(2,1)
end

function sample_create_playback()
  local seconds_per_beat=60/up.bpm
  local current_position=80
  local testone=false
  for chainit=1,#up.chain do
    local chainid=up.chain[chainit]
    if chainid==0 then break end
    local current_pattern=0
    local p=up.patterns[chainid]
    for i=1,16 do
      if p[i]~=current_pattern then
        current_pattern=p[i]
        -- copy over buffer
        if current_pattern>0 then
          sample_id=math.floor(current_pattern)
          local sample_start=up.samples[sample_id].start
          local sample_length=up.samples[sample_id].length+clock.get_beat_sec()/4
          print("sample_length "..sample_length)
          if testone==false then
            softcut.buffer_copy_mono(1,1,sample_start,current_position,sample_length,0,0)
            testone=true
          end
        end
      end
    end
  end
  softcut.loop_start(1,80)
  softcut.loop_end(1,current_position)
  softcut.position(1,80)
  softcut.loop(1,1)
  softcut.rate(1,up.rate*clock.get_tempo()/up.bpm)
  softcut.play(1,1)
end

--
-- save/load
--
function parameters_save(filename)
  data=json.encode(up)
  print(data)
  file=io.open(uc.data_dir..filename,"w+")
  io.output(file)
  print(io.write(data))
  io.close(file)
end

function parameters_load(filename)
  filename=uc.data_dir..filename
  if util.file_exists(filename) then
    local f=io.open(filename,"rb")
    print(f)
    local content=f:read("*all")
    up=json.decode(content)
    f:close()
  end
end

--
-- input
--

function enc(n,d)
  if n==1 and us.shift then
    -- toggle sample/pattern/chain mode
    us.mode=util.clamp(us.mode+sign(d),0,2)
    if us.mode==1 then
      -- figure out which samples are usable
      us.samples_usable={}
      for i=1,#up.samples do
        if up.samples[i].length>0 then
          table.insert(us.samples_usable,i)
        end
      end
    end
  elseif n==1 and us.mode==0 then
    us.sample_cur=util.clamp(us.sample_cur+sign(d),1,26)
  elseif n==1 and us.mode==1 then
    -- change pattern
    us.pattern_cur=util.clamp(us.pattern_cur+sign(d),1,8)
  elseif n==2 and us.mode==0 then
    up.samples[us.sample_cur].start=util.clamp(up.samples[us.sample_cur].start+d/100,0,up.length)
    if up.samples[us.sample_cur].length==0 then
      up.samples[us.sample_cur].length=clock.get_beat_sec()/4
    end
    if up.samples[us.sample_cur].start<us.waveform_view[1] then
      update_waveform_view(up.samples[us.sample_cur].start,up.samples[us.sample_cur].start+up.samples[us.sample_cur].length)
    end
  elseif n==3 and us.mode==0 then
    local x=d*clock.get_beat_sec()/4
    up.samples[us.sample_cur].length=util.clamp(up.samples[us.sample_cur].length+x,0,up.length-up.samples[us.sample_cur].start)
    if up.samples[us.sample_cur].start+up.samples[us.sample_cur].length>us.waveform_view[2] then
      update_waveform_view(up.samples[us.sample_cur].start,up.samples[us.sample_cur].start+up.samples[us.sample_cur].length)
    end
    us.pattern_temp.length=util.round(up.samples[us.sample_cur].length/(clock.get_beat_sec()/4))
  elseif n==2 and us.mode==1 then
    us.samples_usable_id=util.clamp(us.samples_usable_id+sign(d),1,#us.samples_usable)
    us.sample_cur=us.samples_usable[us.samples_usable_id]
  elseif n==3 and us.mode==1 then
    -- change start position
    us.pattern_temp.start=util.clamp(us.pattern_temp.start+sign(d),1,16)
    us.pattern_temp.length=util.round(up.samples[us.sample_cur].length/(clock.get_beat_sec()/4))
  end
  us.update_ui=true
end

function key(n,z)
  if n==1 then
    us.shift=(z==1)
  elseif n==3 and z==1 and us.shift then
    -- toggle playback
    parameters_save("play.json")
    us.playing=not us.playing
    -- if us.playing then
    --   sample_create_playback()
    --   softcut.level(1,1)
    -- else
    --   softcut.level(1,0)
    -- end
    if us.playing then
      softcut.rate(1,up.rate*clock.get_tempo()/up.bpm)
      softcut.level(1,1)
      softcut.play(1,1)
    else
      softcut.level(1,0)
      softcut.play(1,0)
    end
    us.playing_chain=0
    us.playing_loop_end=0
    us.playing_sample={0,0}
    us.playing_beat=17
    us.playing_pattern=1 -- TODO: should be first in chain
  elseif n==2 and z==1 and us.mode==0 then
    if up.samples[us.sample_cur].start==us.waveform_view[1] and up.samples[us.sample_cur].start+up.samples[us.sample_cur].length==us.waveform_view[2] then
      update_waveform_view(0,up.length)
    else
      print("zooming to "..up.samples[us.sample_cur].start..","..up.samples[us.sample_cur].start+up.samples[us.sample_cur].length)
      update_waveform_view(up.samples[us.sample_cur].start,up.samples[us.sample_cur].start+up.samples[us.sample_cur].length)
    end
  elseif n==2 and z==1 and us.mode==1 and us.shift then
    -- make new pattern
    up.patterns[us.pattern_cur][us.pattern_temp.start]=0
  elseif n==2 and z==1 and us.mode==1 then
    -- make new pattern
    up.patterns[us.pattern_cur]=pattern_stamp(us.sample_cur,us.pattern_temp.start,us.pattern_temp.length)
  elseif n==3 and z==1 then
    -- play a sample at curent position
    sample_one_shot()
  end
  us.update_ui=true
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
  if us.mode==0 then
    screen.level(15)
  else
    screen.level(4)
  end
  screen.rect(1+shift_amount,1+shift_amount,7,8)
  screen.stroke()
  screen.move(2+shift_amount,7+shift_amount)
  screen.text(up.samples[us.sample_cur].name)

  -- show pattern info
  if us.mode==1 then
    screen.level(15)
  else
    screen.level(4)
  end
  screen.rect(10+shift_amount,1+shift_amount,7,8)
  screen.stroke()
  isone=0
  if us.pattern_cur==1 then
    isone=1
  end
  screen.move(11+isone+shift_amount,7+shift_amount)
  screen.text(us.pattern_cur)

  -- show chain info
  for i=1,#up.chain do
    if i==us.chain_cur and us.mode==2 then
      screen.level(15)
    else
      screen.level(4)
    end
    if i==us.playing_chain and us.playing then
      screen.level(15)
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
  local p=table.clone(up.patterns[us.pattern_cur])
  if us.mode==1 then
    -- fill in temp pattern
    p=pattern_stamp(us.sample_cur,us.pattern_temp.start,us.pattern_temp.length)
    -- print("us.pattern_temp.start "..us.pattern_temp.start)
    -- print("us.pattern_temp.length "..us.pattern_temp.length)
    -- rvalue = math.random()
    -- for i=us.pattern_temp.start,us.pattern_temp.start+us.pattern_temp.length-1 do
    --   p[i]=us.sample_cur+rvalue
    -- end
  end
  local start=us.pattern_temp.start
  local finish=us.pattern_temp.start+us.pattern_temp.length
  if us.shift then
    for i=start+1,finish do
      p[i]=up.patterns[us.pattern_cur][i]
    end
    finish=start+1
  end
  for i=1,16 do
    screen.level(4)
    local isactive=false
    if i>=start and i<finish and us.mode==1 then
      screen.level(15)
      isactive=true
    end
    if p[i]==us.playing_pattern_segment and p[i]>0 and us.playing then
      screen.level(15)
    end
    if p[i]==0 and us.playing and i==us.playing_beat then
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
        screen.text(up.samples[math.floor(p[i])].name)
        if i<16 and p[i+1]==p[i] then
          screen.rect(6+(i-1)*8,13,3,5)
        else
          screen.rect(6+(i-1)*8,13,2,5)
        end
      end
    else
      screen.rect(1+(i-1)*8,13,7,5)
    end
    if us.shift and isactive then
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
      if current_time>us.playing_sample[1] and current_time<us.playing_sample[2] then
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
      if i==us.sample_cur and s.length>0 and (s.start>=us.waveform_view[1] and s.start<=us.waveform_view[2]) then
        x_pos=util.linlin(us.waveform_view[1],us.waveform_view[2],1,128,s.start)
        if us.waveform_view[1]~=s.start then
          screen.move(x_pos-3,26)
        else
          screen.move(x_pos+4,26)
        end
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
        --   if us.waveform_view[1] == s.start then
        --   screen.move(x_pos+1,64)
        --   screen.text(up.samples[i].name)
        -- end
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
  local bpm=clock.get_tempo()
  -- TODO: get bpm from file
  return duration,rate,bpm
end

function table.clone(org)
  return {table.unpack(org)}
end



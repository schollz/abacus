-- abacus v0.2.0
-- sequence rows of beats
-- with samples.
--
-- llllllll.co/t/abacus
--
--
--    ▼ instructions below ▼
-- K1+E1 changes mode
-- K1+K3 starts/stops chain
--
-- sample mode
-- E1 changes sample
-- E2/E3 change splice position
-- K1+K3 starts/stops chain
-- K2 zooms
-- K3 plays sample (can hold)
--
-- pattern mode
-- E1 changes pattern
-- E2 selects sample
-- E3 positions sample
-- K2 patterns
-- K3 plays sample
-- K1+K2 erases position
-- K1+K3 plays pattern
--
-- chain mode
-- E2 positions
-- E3 selects pattern
-- K2/K3 does effects

json=include("lib/json")
local ControlSpec=require 'controlspec'
local Formatters=require 'formatters'
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
  playing_once=0,
  playing_pattern_segment=0,-- current sample pattern (sample id + random int decimal)
  playing_loop_end=0,
  playing_position=0,
  playing_sampleid=0,
  samples_usable={},
  samples_usable_id=1,
  effect_on=false,
  effect_stutter=false,
  effect_reverse=false,
  one_shot=false,
  crow_sample_cur=0,
  crow_position=0,
  crow_gate=0,
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
  chain={1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
}

-- user constants
uc={
  update_timer_interval=0.05,
  audio_dir=_path.audio..'abacus/',
  tape_dir=_path.audio..'tape/',
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

  -- create data directory if it doesn't exist
  -- and move the code audio to the data directory
  if not util.file_exists(uc.data_dir..'Amen-break.wav') then
    print("making data directory")
    util.make_dir(uc.data_dir)
    local f=io.popen('cp '..uc.code_dir..'sounds/* '..uc.data_dir)
  end

  -- load files from tape/data direcotry
  local files={}
  local files_fullpath={}
  local previous_files={}
  local previous_files_fullpath={}
  local f=io.popen('cd '..uc.tape_dir..'; ls -d *')
  for name in f:lines() do
    if string.match(name,".wav") then
      table.insert(files,name:match("^(.+).wav$"))
      table.insert(files_fullpath,uc.tape_dir..name)
    end
  end
  f=io.popen('cd '..uc.data_dir..'; ls -d *')
  for name in f:lines() do
    if string.match(name,".wav") and not string.match(name,".json")then
      table.insert(files,name:match("^(.+).wav$"))
      table.insert(files_fullpath,uc.data_dir..name)
    end
    if string.match(name,".wav.json") then
      table.insert(previous_files,name:match("^(.+).wav.json$"))
      table.insert(previous_files_fullpath,uc.data_dir..name)
    end
  end
  table.sort(files)
  table.sort(previous_files)
  print(files[1])
  local chosen_file=''
  for i,f in ipairs(files_fullpath) do
    -- https://stackoverflow.com/questions/48402876/getting-current-file-name-in-lua/48403164
    if get_file_name(f)==files[1]..".wav" then
      chosen_file=f
      print("chosen_file "..chosen_file)
      break
    end
  end
  local previous_chosen_file=''
  for i,f in ipairs(previous_files_fullpath) do
    -- https://stackoverflow.com/questions/48402876/getting-current-file-name-in-lua/48403164
    if get_file_name(f)==previous_files[1]..".wav.json" then
      previous_chosen_file=f
      print("previous_chosen_file "..previous_chosen_file)
      break
    end
  end
  print("previous_files: ")
  print(previous_files[1])

  local specs={}
  specs.AMP=ControlSpec.new(0,1,'lin',0,1,'')
  specs.FILTER_FREQ=ControlSpec.new(20,20000,'exp',0,20000,'Hz')
  specs.TIME=ControlSpec.new(0,5,'lin',0,1,'s')
  specs.FILTER_RESONANCE=ControlSpec.new(0.05,1,'lin',0,0.25,'')
  specs.PERCENTAGEADD=ControlSpec.new(-1,1,'lin',0.01,0,'%')
  specs.PERCENTAGE=ControlSpec.new(0,1,'lin',0.01,0,'%')

  params:add_separator("abacus")
  params:add_group("save/load",4)
  params:add {
    type='option',
    id='load_sample',
    name='choose sample',
    options=files,
    action=function(value)
      for i,f in ipairs(files_fullpath) do
        -- https://stackoverflow.com/questions/48402876/getting-current-file-name-in-lua/48403164
        if get_file_name(f)==files[value]..".wav" then
          chosen_file=f
          break
        end
      end
    end
  }

  params:add {
    type='trigger',
    id='load_loops',
    name='load sample',
    action=function(value)
      initialize_samples()
      load_sample(chosen_file)
    end
  }

  params:add {
    type='option',
    id='load_previous',
    name='choose previous',
    options=previous_files,
    action=function(value)
      for i,f in ipairs(previous_files_fullpath) do
        -- https://stackoverflow.com/questions/48402876/getting-current-file-name-in-lua/48403164
        if get_file_name(f)==previous_files[value]..".wav.json" then
          previous_chosen_file=f
          break
        end
      end
    end
  }

  params:add {
    type='trigger',
    id='open_previous',
    name='load previous',
    action=function(value)
      initialize_samples()
      parameters_load(previous_chosen_file)
    end
  }

  params:add_group("effects",6)
  params:add{
    type='control',
    id='global_rate',
    name='global rate',
    controlspec=specs.PERCENTAGEADD,
    formatter=Formatters.percentage,
    action=function(x)
      for i=1,4 do
        softcut.rate(i,up.rate+x)
      end
    end
  }

  params:add{
    type='control',
    id='effect_stutter',
    name='effect stutter',
    controlspec=specs.PERCENTAGE,
    formatter=Formatters.percentage,
  }

  params:add{
    type='control',
    id='effect_reverse',
    name='effect reverse',
    controlspec=specs.PERCENTAGE,
    formatter=Formatters.percentage,
  }


  params:add{
    type='control',
    id='effect_slow',
    name='effect slow',
    controlspec=specs.PERCENTAGE,
    formatter=Formatters.percentage,
  }

  params:add {
    type='control',
    id='filter_frequency',
    name='filter cutoff',
    controlspec=specs.FILTER_FREQ,
    formatter=Formatters.format_freq,
    action=function(value)
      for i=1,4 do
        softcut.post_filter_fc(i,value)
      end
    end
  }

  params:add {
    type='control',
    id='filter_reso',
    name='filter resonance',
    controlspec=specs.FILTER_RESONANCE,
    action=function(value)
      for i=1,4 do
        softcut.post_filter_rq(i,value)
      end
    end
  }

  -- TODO: add individual parameters for pitching up/down specific samples

 params:add_group("crow",4)
   params:add {
    type='option',
    id='crow_mode',
    name='crow mode',
    options={"free","samples"},
    action=function(value)
      if value == 1 then 
        softcut.loop(4,1)
        softcut.loop_start(4,0)
        softcut.loop_end(4,up.length)
      end
    end
  }


  params:add {
    type='control',
    id='gate_voltage',
    name='gate threshold',
    controlspec=ControlSpec.new(-5,10,'lin',0.01,2,'volts'),
    action=function(value)
      crow.input[1].mode("change",value,0.25,"both")
    end
  }

  params:add {
    type='option',
    id='crow_gating',
    name='gating',
    options={"once","continuous"},
    action=function(value)
      if value == 1 then 
        softcut.loop(4,0)
      else
        softcut.loop(4,1)
      end
    end
  }

  params:add {
    type='control',
    id='crow_slew1',
    name='crow slew',
    controlspec=specs.TIME,
    action=function(value)
      softcut.rate_slew_time(4,value)
      softcut.level_slew_time(4,value)
    end
  }


  initialize_samples()

  -- initialize softcut
  for i=1,4 do
    softcut.enable(i,1)
    softcut.level(i,1)
    softcut.pan(i,0)
    softcut.rate(i,1)
    softcut.loop(i,0)
    softcut.rec(i,0)
    softcut.buffer(i,1)
    softcut.position(i,0)
    softcut.level_slew_time(i,clock.get_beat_sec()/4)
    softcut.rate_slew_time(i,clock.get_beat_sec()/4)
    softcut.post_filter_dry(i,0.0)
    softcut.post_filter_lp(i,1.0)
    softcut.post_filter_rq(i,0.3)
    softcut.post_filter_fc(i,44100)
  end
  softcut.level(3,0)
  softcut.play(3,1)
  softcut.loop(4,1)
  softcut.phase_quant(1,0.025)
  softcut.event_render(update_render)


  -- position poll
  softcut.event_phase(update_positions)
  softcut.poll_start_phase()

  -- update clocks
  clock.run(update_beat)

  -- initialize timer for updating screen
  timer=metro.init()
  timer.time=uc.update_timer_interval
  timer.count=-1
  timer.event=update_timer
  timer:start()

  -- initialize crow 
  crow.input[1].change = process_change
  crow.input[1].mode("change",2.0,0.25,"both")
  crow.input[2].stream = process_stream
  crow.input[2].mode("stream",0.1)

  parameters_load(uc.data_dir.."play.json")
end

function initialize_samples()
  up={
    filename_save='1.json',
    filename='',
    length=0,
    rate=1,
    samples={},
    patterns={},
    chain={1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0},
  }
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
end
--
-- updaters
--
function update_positions(i,x)
  -- adjust position so it is relative to loop start
  if i==1 then
    us.playing_position=x
  end
end

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
  local current_level=0
  local is_slowing = false 
  while true do
    clock.sync(1/4)
    if us.playing==false then
      if current_level==1 then
        current_level=0
        softcut.level(1,0)
      end
      goto continue
    end
    clock.run(function()
      us.playing_beat=us.playing_beat+1
      if us.playing_beat>16 then
        if us.playing_once==2 then
          print("playing once!")
          us.playing_once=1
        elseif us.playing_once==1 then
          us.playing_once=0
          us.playing=false
          return
        else
          -- iterate through chain
          us.playing_chain=us.playing_chain+1
          if us.playing_chain>#up.chain or up.chain[us.playing_chain]==0 then
            us.playing_chain=1
          end
          us.pattern_cur=up.chain[us.playing_chain]
        end
        p=up.patterns[us.pattern_cur]
        us.playing_beat=1
      end
      -- if silence, continue
      local playing_pattern_segment=p[us.playing_beat]
      -- get sample id from the pattern segment
      local sample_id=math.floor(playing_pattern_segment)

      -- do effects
      effect_slow=us.effect_slow or math.random()<params:get("effect_slow")
      effect_stutter=us.effect_stutter or math.random()<params:get("effect_stutter")
      effect_reverse=us.effect_reverse or math.random()<params:get("effect_reverse")
      if effect_slow then
      	clock.run(function()
      	  is_slowing=true
      	  local slow_time = clock.get_beat_sec()*(math.random(2))
          softcut.rate_slew_time(1,slow_time)
      	  softcut.rate(1,0.5*up.rate+params:get("global_rate"))
      	  clock.sleep(slow_time)
      	  softcut.rate(1,up.rate+params:get("global_rate"))
      	  is_slowing = false
      	end)
      elseif (effect_stutter or effect_reverse) and us.playing_once==0 and not is_slowing then
        us.effect_on=false
        us.effect_stutter=false
        us.effect_reverse=false
        if us.playing_sampleid>0 then
          local pos=up.samples[us.playing_sampleid].start
          rate=1
          softcut.loop(3,1)
          if effect_stutter then
            print("stutter")
            softcut.loop(3,1)
            local stutter_amount=math.random(4)
            softcut.loop_end(3,pos+clock.get_beat_sec()/(64.0/stutter_amount))
            softcut.loop_start(3,pos-clock.get_beat_sec()/(64.0/stutter_amount))
          else
            softcut.loop_start(3,us.playing_loop_end)
            softcut.loop_end(3,us.playing_loop_end)
          end
          if effect_reverse then
            print("reverse")
            rate=-1
          end
          softcut.rate(3,rate*(up.rate+params:get("global_rate")))
          softcut.position(3,pos)
          if us.effect_reverse then
            for i=1,10 do
              softcut.level(3,i/10.0)
              softcut.level(1,(10-i)/10.0)
              clock.sleep(clock.get_beat_sec()/10)
            end
          else
            softcut.level(3,1)
            softcut.level(1,0)
          end
          clock.sleep(clock.get_beat_sec()/4*(2+math.random(8)))
          softcut.level(1,1)
          softcut.level(3,0)
        end
      elseif not us.effect_on then
        if sample_id==0 then
          if current_level==1 then
            current_level=0
            softcut.level(1,0)
          end
          us.playing_pattern_segment=0
          us.playing_sample={0,0}
          us.playing_sampleid=0
          us.update_ui=true
          return
        end
        if playing_pattern_segment==us.playing_pattern_segment then
          return
        end
        us.playing_pattern_segment=playing_pattern_segment
        -- play sample
        local sample_start=up.samples[sample_id].start
        if up.samples[sample_id].start+up.samples[sample_id].length~=us.playing_loop_end then
          us.playing_loop_end=up.samples[sample_id].start+up.samples[sample_id].length
          --  softcut.loop_end(1,us.playing_loop_end)
        end
        us.playing_sampleid=sample_id
        us.playing_sample={up.samples[sample_id].start,us.playing_loop_end}
        softcut.position(1,up.samples[sample_id].start)
        if current_level==0 then
          current_level=1
          softcut.level(1,1)
        end
        us.update_ui=true
      end
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
function load_sample(filename)
  -- load file
  up.filename=filename
  up.length,up.rate=load_file(filename)
  softcut.loop_start(1,0)
  softcut.loop_end(1,up.length)
  softcut.loop(1,1)
  update_waveform_view(0,up.length)
end

function sample_one_shot(z)
  if z==0 then
    -- stop looping
    us.one_shot=false
    softcut.loop(2,0)
    us.playing_sample={0,0}
  else
    us.one_shot=true
    sample_one_shot_update()
    softcut.loop(2,1)
    softcut.play(2,1)
    softcut.rate(2,up.rate+params:get("global_rate"))
  end
  us.update_ui=true
end

function sample_one_shot_update()
  if not us.one_shot then do return end end
local s=up.samples[us.sample_cur].start
  local e=up.samples[us.sample_cur].start+up.samples[us.sample_cur].length
  us.playing_sample={s,e}
  softcut.position(2,s)
  softcut.loop_start(2,s)
  softcut.loop_end(2,e)
  us.update_ui=true
end

--
-- save/load
--
function parameters_save()
  data=json.encode(up)
  write_file(uc.data_dir.."play.json",data)
  write_file(uc.data_dir..get_file_name(up.filename)..".json",data)
end

function parameters_load(filename)
  print("loading "..filename)
  if util.file_exists(filename) then
    local f=io.open(filename,"rb")
    print(f)
    local content=f:read("*all")
    up=json.decode(content)
    f:close()
    load_sample(up.filename)
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
      us.pattern_temp.length=util.round(up.samples[us.sample_cur].length/(clock.get_beat_sec()/4))
    end
  elseif n==1 and us.mode==0 then
    us.sample_cur=util.clamp(us.sample_cur+sign(d),1,26)
  elseif n==1 and us.mode==1 then
    -- change pattern
    us.pattern_cur=util.clamp(us.pattern_cur+sign(d),1,8)
  elseif n==2 and us.mode==0 then
    local x=d*up.length/1000
    up.samples[us.sample_cur].start=util.clamp(up.samples[us.sample_cur].start+x,0,up.length)
    if up.samples[us.sample_cur].length==0 then
      up.samples[us.sample_cur].length=clock.get_beat_sec()/4
      up.samples[us.sample_cur].start=util.clamp(up.samples[us.sample_cur].start,us.waveform_view[1],up.length)
    end
    local new_end=up.samples[us.sample_cur].start+up.samples[us.sample_cur].length
    if up.samples[us.sample_cur].start<us.waveform_view[1] then
      update_waveform_view(up.samples[us.sample_cur].start,us.waveform_view[2]+(up.samples[us.sample_cur].start-us.waveform_view[1]))
    elseif new_end>us.waveform_view[2] then
      update_waveform_view(us.waveform_view[1]+(new_end-us.waveform_view[2]),up.samples[us.sample_cur].start+up.samples[us.sample_cur].length)
    end
    sample_one_shot_update()
  elseif n==3 and us.mode==0 then
    -- local x=d*clock.get_beat_sec()/4
    local x=d*up.length/1000
    up.samples[us.sample_cur].length=util.clamp(up.samples[us.sample_cur].length+x,0,up.length-up.samples[us.sample_cur].start)
    if up.samples[us.sample_cur].start+up.samples[us.sample_cur].length>us.waveform_view[2] then
      update_waveform_view(up.samples[us.sample_cur].start,up.samples[us.sample_cur].start+up.samples[us.sample_cur].length)
    end
    us.pattern_temp.length=util.round(up.samples[us.sample_cur].length/(clock.get_beat_sec()/4))
    sample_one_shot_update()
  elseif n==2 and us.mode==1 then
    us.samples_usable_id=util.clamp(us.samples_usable_id+sign(d),1,#us.samples_usable)
    us.sample_cur=us.samples_usable[us.samples_usable_id]
    us.pattern_temp.length=util.round(up.samples[us.sample_cur].length/(clock.get_beat_sec()/4))
  elseif n==3 and us.mode==1 then
    -- change start position
    us.pattern_temp.start=util.clamp(us.pattern_temp.start+sign(d),1,16)
    us.pattern_temp.length=util.round(up.samples[us.sample_cur].length/(clock.get_beat_sec()/4))
  elseif n==2 and us.mode==2 then
    local last_chain=1
    for i=1,#up.chain do
      if up.chain[i]==0 then
        last_chain=i
        break
      end
    end
    us.chain_cur=util.clamp(us.chain_cur+sign(d),1,last_chain)
  elseif n==3 and us.mode==2 then
    local last_chain=1
    for i=1,#up.chain do
      if up.chain[i]==0 then
        last_chain=i
        break
      end
    end
    min_chain=1
    if us.chain_cur>=last_chain-1 then
      min_chain=0
    end
    up.chain[us.chain_cur]=util.clamp(up.chain[us.chain_cur]+sign(d),min_chain,9)
  end
  us.update_ui=true
end

function key(n,z)
  if n==1 then
    us.shift=(z==1)
  elseif n>=2 and z==1 and us.mode==2 and not us.shift then
    -- effects in chain mode
    us.effect_stutter=n==2
    us.effect_reverse=not us.effect_stutter
  elseif n==3 and z==1 and us.shift then
    -- toggle playback
    parameters_save()
    if not us.playing then
      softcut.rate(1,up.rate+params:get("global_rate"))
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
    us.playing_pattern=1
    if us.mode==1 then
      -- toggle playback of this chain only
      us.playing_once=2
    end
    us.playing=not us.playing
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
  elseif n==3 then
    -- play a sample at curent position
    sample_one_shot(z)
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
  local last_position=0
  for i=1,#up.chain do
    if i==us.chain_cur and us.mode==2 then
      screen.level(15)
    else
      screen.level(4)
    end
    if i==us.playing_chain and us.playing then
      screen.level(15)
    end
    if up.chain[i]>0 or us.chain_cur==i then
      isone=0
      if up.chain[i]==1 then
        isone=1
      end
      last_position=i
      screen.move(21+(i-1)*7+isone+shift_amount,7+shift_amount)
      if up.chain[i]>0 then
        screen.text(up.chain[i])
      else
        screen.text(" ")
      end
    end
  end
  if us.mode==2 then
    screen.level(15)
  end
  screen.rect(19+shift_amount,1+shift_amount,21+(last_position-1)*7-13,8)
  screen.stroke()

  -- show pattern
  local p=table.clone(up.patterns[us.pattern_cur])
  if us.mode==1 then
    -- fill in temp pattern
    p=pattern_stamp(us.sample_cur,us.pattern_temp.start,us.pattern_temp.length)
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
      if (i==us.sample_cur or i==us.playing_sampleid) and s.length>0 and (s.start>=us.waveform_view[1] and s.start<=us.waveform_view[2]) then
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
-- crow
--

function process_stream(v)
  if params:get("crow_mode") == 2 then 
    -- sample mode 
    us.samples_usable={}
    for i=1,#up.samples do
      if up.samples[i].length>0 then
        table.insert(us.samples_usable,i)
      end
    end
    us.crow_sample_cur = us.samples_usable[util.round(util.linlin(-10,10,1,#us.samples_usable,v))]
    local s=up.samples[us.crow_sample_cur].start
    local e=up.samples[us.crow_sample_cur].start+up.samples[us.crow_sample_cur].length
    us.playing_sample={s,e}
    softcut.loop_start(4,s)
    softcut.loop_end(4,e)
    if us.crow_gating == 1 then 
      process_change(1)
    end    
  else
    -- free mode 
    us.crow_position = util.linlin(-10,10,0,up.length,v)
    print("setting new position "..us.crow_position)
    softcut.position(4,us.crow_position)
    softcut.loop_end(4,up.length)
  end
end

function process_change(s)
  us.crow_gating=s
  if params:get("crow_mode") == 2 then 
    -- sample mode 
    -- keep playing current sample until gate is off
    if s==1 and us.crow_sample_cur > 0 then 
      softcut.play(4,1)
      softcut.level(4,1)
      softcut.position(4,up.samples[us.crow_sample_cur].start)
      softcut.rate(4,up.rate+params:get("global_rate"))
      us.update_ui=true
      softcut.loop(4,params:get("crow_gating")-1)
    else
      softcut.loop(4,0)
    end
  else
    -- free mode, start playing at current position
    if s==1 then 
      softcut.position(4,us.crow_position)
      softcut.play(4,1)
      softcut.level(4,1)
      softcut.rate(4,up.rate+params:get("global_rate"))
    else
      softcut.rate(4,0)
      softcut.level(4,0)
    end
  end
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

function table.clone(org)
  return {table.unpack(org)}
end



function get_file_name(file)
  return file:match("^.+/(.+)$")
end

function write_file(fname,data)
  print("saving to "..fname)
  file=io.open(fname,"w+")
  io.output(file)
  io.write(data)
  io.close(file)
end



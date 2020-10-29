local Sampler={}
Sampler.__index=Sampler

local ControlSpec=require 'controlspec'
local Formatters=require 'formatters'

function Sampler.new(voice)
  local i={
    voice=voice,
    running=false,
    amplitude=1.0,
    -- probability values
    probability={
      stutter=0,
      reverse=0,
      jump=0,
      jump_back=0
    },
  ui={slice_buttons_down={},mute_button=0,shift_button=0}}
  
  setmetatable(i,Sampler)
  return i
end

function Sampler:advance_step(in_beatstep,in_bpm)
  self.events={}
  self.message=''
  self.status=''
  self.beatstep=in_beatstep
  self.current_bpm=in_bpm
  
  if not self.running then
    self.status='NOT RUNNING'
    return
  end
  
  if self.loop_count==0 then
    self.status='LOAD LOOPS IN PARAMS'
    return
  end
  
  if self.muted then
    self.status='MUTED'
    softcut.level(self.id,0)
  else
    softcut.level(self.id,self.amplitude)
  end
  
  if self.editing then
    -- play the current edit position slice every other beat
    -- so that it's easier to hear what the sound is at the start of the slice
    if self.beatstep%4~=0 then
      self:play_nothing()
    else
      local edit_index=math.floor(self.editing_mode.cursor_location)
      self:play_slice(edit_index)
    end
    return
  end
  if self.beatstep==0 then
    self.on_beat_one()
  end
  self:calculate_next_slice()
  self:play_slice(self.index)
  self.played_index=self.index
end

function Sampler:instant_toggle_mute()
  self:toggle_mute()
  if self.muted then
    softcut.level(self.id,0)
  else
    softcut.level(self.id,self.amplitude)
  end
end

function Sampler:mute(in_muted)
  if in_muted then
    self.muted=true
  else
    self.muted=false
  end
end

function Sampler:toggle_mute()
  self:mute(not self.muted)
end

function Sampler:should(thing)
  if not self.enable_mutations then
    return false
  end
  return math.random(100)<=self.probability[thing]
end

function Sampler:play_nothing()
  softcut.level(self.id,0)
end

function Sampler:random_loop_index()
  local timeout=self.loop_count
  local l=math.random(self.loop_count)
  while timeout>0 do
    local loop=self:loop_at_index(l)
    if loop.enabled==1 then
      return l
    end
    l=l+1
    if l>self.loop_count then
      l=1
    end
  end
  return 1
end

function Sampler:play_slice(slice_index)
  self.played_loop_index=self.loop_index
  
  local loop=self:loop_at_index(self.played_loop_index)
  local current_rate=loop.rate*(self.current_bpm/loop.bpm)
  
  if (self:should('stutter')) then
    self.events['S']=1
    local stutter_amount=math.random(4)
    softcut.loop_start(self.id,loop.start+(slice_index*(loop.duration/self.beat_count)))
    softcut.loop_end(
      self.id,
    loop.start+(slice_index*(loop.duration/self.beat_count)+(loop.duration/(64.0/stutter_amount))))
  else
    self.events['S']=0
    softcut.loop_start(self.id,loop.start)
    softcut.loop_end(self.id,loop.start+loop.duration)
  end
  
  if (self:should('reverse')) then
    self.events['R']=1
    softcut.rate(self.id,0-current_rate)
  else
    self.events['R']=0
    softcut.rate(self.id,current_rate)
  end
  
  local position=loop.start+(slice_index*(loop.duration/self.beat_count))
  softcut.position(self.id,position)
  
  if not self.editing then
    self:notify_beat(loop.beat_types[slice_index+1])
  end
end

function Sampler:notify_beat(beat_type)
  if beat_type=='K' then
    self.on_kick()
  end
  if beat_type=='S' then
    self.on_snare()
  end
end

function Sampler:toggle_loop_enabled(index)
  local loop=self:loop_at_index(index)
  if loop.enabled==1 then
    loop.enabled=0
  elseif loop.enabled==0 then
    loop.enabled=1
  end
end

function Sampler:toggle_slice_enabled(slice_index)
  local loop=self:loop_at_index(self.loop_index)
  if loop.beat_enabled[slice_index+1]==1 then
    loop.beat_enabled[slice_index+1]=0
  elseif loop.beat_enabled[slice_index+1]==0 then
    loop.beat_enabled[slice_index+1]=1
  end
end

function Sampler:slice_is_enabled(slice_index)
  local loop=self:loop_at_index(self.loop_index)
  return loop.beat_enabled[slice_index+1]==1
end

function Sampler:next_loop(loop_index,direction)
  local new_index=loop_index
  local timeout=self.loop_count
  while timeout>0 do
    new_index=new_index+direction
    
    if new_index==0 then
      new_index=self.loop_count
    end
    if new_index>self.loop_count then
      new_index=1
    end
    
    local loop=self:loop_at_index(new_index)
    if loop.enabled==1 then
      return new_index
    end
    timeout=timeout-1
  end
end

function Sampler:step_forward(index)
  local timeout=self.beat_count
  local new_index=index
  while timeout>0 do
    new_index=new_index+1
    if new_index>self.beat_end then
      new_index=self.beat_start
      if params:get(self.id..'_'..'auto_advance')==2 then
        self.loop_index=self:next_loop(self.loop_index,1)
      end
    end
    if self:slice_is_enabled(new_index) then
      return new_index
    end
    timeout=timeout-1
  end
  return 0
end

function Sampler:step_backward(index)
  local timeout=self.beat_count
  local new_index=index
  while timeout>0 do
    new_index=new_index-1
    if new_index<self.beat_start then
      new_index=self.beat_end
      if params:get(self.id..'_'..'auto_advance')==2 then
        self.loop_index=self:next_loop(self.loop_index,-1)
      end
    end
    if self:slice_is_enabled(new_index) then
      return new_index
    end
    timeout=timeout-1
  end
  return 0
end

function Sampler:step_first()
  local new_index=self.beat_start
  if self:slice_is_enabled(new_index) then
    return new_index
  end
  return self:step_forward(new_index)
end

function Sampler:calculate_next_slice()
  local new_index=self:step_forward(self.index)
  
  if (self:should('jump')) then
    self.events['>']=1
    new_index=self:step_forward(new_index)
  else
    self.events['>']=0
  end
  
  if (self:should('jump_back')) then
    self.events['<']=1
    new_index=self:step_backward(new_index)
  else
    self.events['<']=0
  end
  
  if (self.beatstep==0) then
    new_index=self:step_first()
  end
  self.index=new_index
end

function Sampler:clear_loops()
  self.loop_index_to_filename={}
  self.loops_by_filename={}
  self.loop_count=0
end

function Sampler:load_directory(path)
  self:clear_loops()
  
  local f=io.popen('ls "'..path..'"/*.wav')
  local filenames={}
  for name in f:lines() do
    table.insert(filenames,name)
  end
  table.sort(filenames)
  
  for i,name in ipairs(filenames) do
    self:load_loop(i,{file=name})
    i=i+1
  end
end

function Sampler:save_loop_info(loop_info)
  local json_filename=loop_info.filename..'.json'
  
  local f=io.open(json_filename,'w')
  f:write(json.encode(loop_info))
  f:close()
end

function Sampler:load_loop(index,loop)
  local filename=loop.file
  local kicks=loop.kicks
  local snares=loop.snares
  local loop_info={}
  local json_filename=filename..'.json'
  
  local f=io.open(json_filename)
  if f~=nil then
    loop_info=json.decode(f:read('*a'))
  else
    local ch,samples,samplerate=audio.file_info(filename)
    loop_info.frames=samples
    loop_info.rate=samplerate/48000.0 -- compensate for files that aren't 48Khz
    loop_info.duration=samples/48000.0
    loop_info.beat_types={' ',' ',' ',' ',' ',' ',' ',' '}
    loop_info.filename=filename
    
    if kicks then
      for _,beat in ipairs(kicks) do
        loop_info.beat_types[beat+1]='K'
      end
    end
    
    if snares then
      for _,beat in ipairs(snares) do
        loop_info.beat_types[beat+1]='S'
      end
    end
    
    self:save_loop_info(loop_info)
  end
  
  loop_info.bpm=(4*60)/loop_info.duration
  loop_info.start=index*BREAK_OFFSET+self.id*VOICE_OFFSET
  loop_info.index=index
  loop_info.enabled=1
  loop_info.beat_enabled={1,1,1,1,1,1,1,1}
  
  softcut.buffer_read_mono(filename,0,loop_info.start,-1,1,1)
  
  self.loop_index_to_filename[index]=filename
  self.loops_by_filename[filename]=loop_info
  self.loop_count=index
  self:reset_loop_index_param()
end

function Sampler:softcut_init()
  softcut.enable(self.id,1)
  softcut.buffer(self.id,1)
  softcut.level(self.id,self.amplitude)
  softcut.level_slew_time(self.id,0.2)
  softcut.loop(self.id,1)
  softcut.loop_start(self.id,0)
  softcut.loop_end(self.id,0)
  softcut.position(self.id,0)
  softcut.rate(self.id,0)
  softcut.play(self.id,1)
  softcut.fade_time(self.id,0.010)
  
  softcut.post_filter_dry(self.id,0.0)
  softcut.post_filter_lp(self.id,1.0)
  softcut.post_filter_rq(self.id,0.3)
  softcut.post_filter_fc(self.id,44100)
end

function Sampler:start()
  self:softcut_init()
  self.running=true
end

function Sampler:stop()
  self.running=false
  softcut.play(self.id,0)
end

function Sampler:reset_loop_index_param()
  for _,p in ipairs(params.params) do
    if p.id==self.id..'_'..'loop_index' then
      p.controlspec=ControlSpec.new(1,self.loop_count,'lin',1,1,'')
    end
  end
end

function Sampler:add_params(arcify)
  local specs={}
  specs.AMP=ControlSpec.new(0,1,'lin',0,1,'')
  specs.FILTER_FREQ=ControlSpec.new(20,20000,'exp',0,20000,'Hz')
  specs.FILTER_RESONANCE=ControlSpec.new(0.05,1,'lin',0,0.25,'')
  specs.PERCENTAGE=ControlSpec.new(0,1,'lin',0.01,0,'%')
  specs.BEAT_START=ControlSpec.new(0,self.beat_count-1,'lin',1,0,'')
  specs.BEAT_END=ControlSpec.new(0,self.beat_count-1,'lin',1,self.beat_count-1,'')
  
  local files={}
  local files_count=0
  local loops_dir=_path.audio..'beets/'
  local f=io.popen('cd '..loops_dir..'; ls -d *')
  for name in f:lines() do
    table.insert(files,name)
    files_count=files_count+1
  end
  table.sort(files)
  
  local name
  if files_count==0 then
    name='Create folders in audio/beets to load'
    self.loops_folder_name='-'
  else
    name='Loops folder'
    self.loops_folder_name=files[1]
  end
  
  params:add_group('Voice '..self.id,16)
  
  params:add {
    type='option',
    id=self.id..'_'..'dir_chooser',
    name=name,
    options=files,
    action=function(value)
      self.loops_folder_name=files[value]
    end
  }
  
  params:add {
    type='trigger',
    id=self.id..'_'..'load_loops',
    name='Load loops',
    action=function(value)
      if value=='-' then
        return
      end
      self:load_directory(_path.audio..'beets/'..self.loops_folder_name)
    end
  }
  
  params:add_separator()
  
  params:add {
    type='control',
    id=self.id..'_'..'amplitude',
    name='Amplitude',
    controlspec=specs.AMP,
    default=1.0,
    action=function(value)
      self.amplitude=value
      softcut.level(self.id,self.amplitude)
    end
  }
  
  params:add {
    type='control',
    id=self.id..'_'..'pan',
    name='Pan',
    controlspec=ControlSpec.PAN,
    formatter=Formatters.bipolar_as_pan_widget,
    default=0.5,
    action=function(value)
      self.pan=value
      softcut.pan(self.id,self.pan)
    end
  }
  
  params:add {
    type='control',
    id=self.id..'_'..'jump_back_probability',
    name='Jump Back Probability',
    controlspec=specs.PERCENTAGE,
    formatter=Formatters.percentage,
    action=function(value)
      self.probability.jump_back=value*100
    end
  }
  
  params:add {
    type='control',
    id=self.id..'_'..'jump_probability',
    name='Jump Probability',
    controlspec=specs.PERCENTAGE,
    formatter=Formatters.percentage,
    action=function(value)
      self.probability.jump=value*100
    end
  }
  
  params:add {
    type='control',
    id=self.id..'_'..'reverse_probability',
    name='Reverse Probability',
    controlspec=specs.PERCENTAGE,
    formatter=Formatters.percentage,
    action=function(value)
      self.probability.reverse=value*100
    end
  }
  
  params:add {
    type='control',
    id=self.id..'_'..'stutter_probability',
    name='Stutter Probability',
    controlspec=specs.PERCENTAGE,
    formatter=Formatters.percentage,
    action=function(value)
      self.probability.stutter=value*100
    end
  }
  
  params:add {
    type='control',
    id=self.id..'_'..'filter_frequency',
    name='Filter Cutoff',
    controlspec=specs.FILTER_FREQ,
    formatter=Formatters.format_freq,
    action=function(value)
      softcut.post_filter_fc(self.id,value)
    end
  }
  
  params:add {
    type='control',
    id=self.id..'_'..'filter_reso',
    name='Filter Resonance',
    controlspec=specs.FILTER_RESONANCE,
    action=function(value)
      softcut.post_filter_rq(self.id,value)
    end
  }
  
  params:add {
    type='control',
    id=self.id..'_'..'beat_start',
    name='Beat Start',
    controlspec=specs.BEAT_START,
    action=function(value)
      self.beat_start=value
    end
  }
  
  params:add {
    type='control',
    id=self.id..'_'..'beat_end',
    name='Beat End',
    controlspec=specs.BEAT_END,
    action=function(value)
      self.beat_end=value
    end
  }
end

local layout={
  horiz_spacing=9,
  vert_spacing=9,
  left_margin=10,
  top_margin=10
}

function Sampler:_drawCurrentLoopGrid(options)
  local played_index=options.played_index or self.played_index
  local beatstep=options.beatstep or self.beatstep
  local loop_index=options.loop_index or self.loop_index
  
  local loop=self.loops_by_filename[self.loop_index_to_filename[loop_index]]
  for i=0,7 do
    screen.rect(
      layout.left_margin+layout.horiz_spacing*i,
      layout.top_margin,
      layout.horiz_spacing,
      layout.vert_spacing
    )
    if played_index==i then
      screen.level(15)
    elseif beatstep==i then
      screen.level(2)
    else
      screen.level(0)
    end
    screen.fill()
    screen.rect(
      layout.left_margin+layout.horiz_spacing*i,
      layout.top_margin,
      layout.horiz_spacing,
      layout.vert_spacing
    )
    
    screen.level(1)
    screen.move(layout.left_margin+layout.horiz_spacing*i+2,layout.top_margin+6)
    screen.text(loop.beat_types[i+1])
    
    screen.level(2)
    screen.stroke()
    
    screen.level(15)
  end
end

function Sampler:grid_key(x,y,z)
  if self.loop_count==0 or self.editing then
    return
  end
  if x==8 and y==8 then
    self.ui.mute_button=z
    if z==0 then
      self:toggle_mute()
    end
    redraw()
  end
  if x==1 and y==3 then
    self.ui.shift_button=z
    redraw()
  end
  if z==1 and x==8 and y==3 then -- auto_advance
    local current_auto_advance=params:get(self.id..'_'..'auto_advance')
    if current_auto_advance==1 then
      params:set(self.id..'_'..'auto_advance',2)
    else
      params:set(self.id..'_'..'auto_advance',1)
    end
  end
  if y==1 and x<=self.beat_count then
    if self.ui.shift_button==1 then
      if z==1 then
        self:toggle_slice_enabled(x-1)
      end
    elseif z==1 then
      self.ui.slice_buttons_down[x]=1
      local count=0
      local first,second
      for button_down in pairs(self.ui.slice_buttons_down) do
        if first==nil then
          first=button_down
        else
          if button_down>first then
            second=button_down
          else
            second=first
            first=button_down
          end
        end
        count=count+1
      end
      if count==1 then -- for double-tap single-button-loop handling
        if self.ui.slice_button_saved then
          if self.ui.slice_button_saved==x then
            -- DOUBLE TAP!
            params:set(self.id..'_'..'beat_start',x-1)
            params:set(self.id..'_'..'beat_end',x-1)
          end
          self.ui.slice_button_saved=nil
        else
          self.ui.slice_button_saved=x
        end
      else
        self.ui.slice_button_saved=nil
      end
      if count==2 then
        params:set(self.id..'_'..'beat_start',first-1)
        params:set(self.id..'_'..'beat_end',second-1)
      end
    else
      if self.ui.slice_button_saved then
        local count=0
        for _ in pairs(self.ui.slice_buttons_down) do
          count=count+1
        end
        if count~=1 then
          self.ui.slice_button_saved=nil
        end
      end
      self.ui.slice_buttons_down[x]=nil
    end
  end
  
  if y==2 and x<=self.loop_count then
    if self.ui.shift_button==1 then
      if z==1 and x~=self.loop_index then
        self:toggle_loop_enabled(x)
      end
    elseif z==1 then
      params:set(self.id..'_'..'loop_index',x)
    end
  end
  
  local c=0
  for _ in pairs(PROBABILITY_ORDER) do
    c=c+1
  end
  if x<=c and y>3 and z==1 then
    local name=PROBABILITY_ORDER[x]
    local value=(8-y)/4
    params:set(self.id..'_'..name..'_probability',value)
  end
end

function Sampler:drawUI()
  screen.clear()
  screen.level(15)
  
  screen.update()
end

function Sampler:edit_mode_begin()
  self.editing=true
  self.enable_mutations=false
  redraw()
end

function Sampler:loop_at_index(index)
  return self.loops_by_filename[self.loop_index_to_filename[index]]
end

function Sampler:edit_mode_end()
  self.editing=false
  self.enable_mutations=true
  local loop=self:loop_at_index(self.loop_index)
  self:save_loop_info(loop)
  redraw()
end

function Sampler:enc(n,d)
  if n==1 then
    self.editing_mode.cursor_location=(self.editing_mode.cursor_location+(d/50.0))%self.beat_count
    redraw()
  else
  end
end

function Sampler:key(n,z)
  if n==2 and z==0 then
    local beat_types_index=math.floor(self.editing_mode.cursor_location)+1
    local loop=self:loop_at_index(self.loop_index)
    if loop.beat_types[beat_types_index]==' ' then
      loop.beat_types[beat_types_index]='K'
    elseif loop.beat_types[beat_types_index]=='K' then
      loop.beat_types[beat_types_index]='S'
    elseif loop.beat_types[beat_types_index]=='S' then
      loop.beat_types[beat_types_index]=' '
    end
    redraw()
  else
    print('Key '..n..' '..z)
  end
end

return Sampler

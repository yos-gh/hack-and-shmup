-- Audition batch only. Saves all projects and renders outside shipped assets.
local script=debug.getinfo(1,'S').source:sub(2):gsub('\\','/')
local root=assert(script:match('^(.*)/tools/audio/[^/]+$'))
local base=root .. '/docs/audio/candidates/' .. (AUDIO_CANDIDATE_REVISION or 'underground-v1')
local selected=io.open(base .. '/render_selection.txt','r')
local selection=selected and selected:read('*l') or nil
if selected then selected:close() end
local log=assert(io.open(base .. '/render.txt','a'))
local function report(s) log:write(s..'\n'); log:flush() end
local function main()
  local catalog=dofile(base .. '/catalog.lua')
  for _, entry in ipairs(catalog) do
    if not selection or selection == entry.id then
    local out=base .. '/' .. entry.id
    local score=dofile(out .. '/score.lua')
    local engine=dofile(root .. '/tools/audio/reaper_engine.lua')(out,log)
    report('BEGIN ' .. entry.id)
    engine.new_project(score.bpm)
    for _, part in ipairs(score.tracks) do
      report('TRACK_START ' .. part.name)
      local track=engine.make_track(part.name,part.voice,part.level_db,part.pan,part.echo,part.patch)
      engine.add_notes(track,part.notes,60/score.bpm,score.seconds,3)
    end
    engine.render(entry.id .. '_source',score.seconds*3)
    report('DONE ' .. entry.id)
    end
  end
  report('COMPLETE ' .. (selection or 'ALL CANDIDATES'))
end
local ok,err=xpcall(main,debug.traceback)
if not ok then report('FAIL: '..tostring(err)) end
log:close()

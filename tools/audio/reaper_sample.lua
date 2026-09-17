-- Batch synthesis of the approved representative scope, not the full soundtrack.
local script = debug.getinfo(1, 'S').source:sub(2):gsub('\\', '/')
local root = assert(script:match('^(.*)/tools/audio/[^/]+$'))
local source = root .. '/docs/audio/sample'
local out = source .. '/v02'
reaper.RecursiveCreateDirectory(out, 0)
local score = dofile(source .. '/score.lua')
local log = assert(io.open(out .. '/render.txt', 'w'))
local function report(s) log:write(s .. '\n'); log:flush() end
local engine = dofile(root .. "/tools/audio/reaper_engine.lua")(out, log)
local make_track, add_notes = engine.make_track, engine.add_notes
local new_project, render = engine.new_project, engine.render

local function main()
  new_project(score.bpm)
  for _, part in ipairs(score.tracks) do
    local track = make_track(part.name, part.voice, part.level_db, part.pan,
                             part.voice == 'lead' or part.voice == 'stab' or part.voice == 'arp')
    add_notes(track, part.notes, 60/score.bpm, score.seconds, 3)
  end
  render('black_circuit_source', score.seconds * 3)

  new_project(120)
  -- All offsets below are seconds. Each family has three independent synth layers.
  local cues = {
    {'shot', .14, {{'shot_tone',65,-13},{'shot_edge',85,-25},{'kick',45,-23}}},
    {'scatter', .23, {{'scatter_tone',49,-13},{'scatter_noise',72,-18},{'kick',36,-15}}},
    {'shock', .40, {{'shock_body',29,-8},{'shock_noise',48,-18},{'scatter_tone',40,-23}}},
    {'lance', .27, {{'lance_tone',72,-17},{'lance_low',48,-14},{'shot_edge',80,-24}}},
    {'hit', .11, {{'hit_tone',64,-22},{'shot_edge',80,-30},{'snare_body',58,-28}}},
    {'kill', .20, {{'kill_tone',53,-17},{'kill_noise',65,-23},{'kick',39,-23}}},
    {'hunter_lock', .30, {{'lock_tone',78,-19},{'lock_tone',90,-31}}},
    {'death', .43, {{'death_tone',43,-14},{'death_noise',51,-20},{'shock_body',28,-14}}},
  }
  local manifest = assert(io.open(out .. '/cues.tsv', 'w'))
  manifest:write('name\tstart\tduration\n')
  for index, cue in ipairs(cues) do
    local start = (index-1)*2 + .5
    manifest:write(string.format('%s\t%.3f\t%.3f\n', cue[1], start, cue[2]))
    reaper.AddProjectMarker2(0, true, start, start+cue[2], cue[1], -1, 0)
    for layer, part in ipairs(cue[3]) do
      local track = make_track(cue[1] .. ' / ' .. part[1], part[1], part[3], 0, false)
      local notes = {{start, part[2], cue[2]-.018, 115}}
      if cue[1] == 'hunter_lock' then
        notes = {}
        for pulse=0,3 do notes[#notes+1]={start+pulse*.065,part[2]+pulse,.034,110} end
      end
      add_notes(track, notes, 1, #cues*2+1, 1)
    end
  end
  manifest:close()
  render('effects_source', #cues*2+1)
  report('COMPLETE')
end
local ok, err = xpcall(main, debug.traceback)
if not ok then report('FAIL: ' .. tostring(err)) end
log:close()

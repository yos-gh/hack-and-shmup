local script=debug.getinfo(1,'S').source:sub(2):gsub('\\','/')
local folder=assert(script:match('^(.*)/[^/]+$'))
AUDIO_CANDIDATE_REVISION='stage-v3'
local ok,err=pcall(dofile,folder .. '/reaper_candidates.lua')
AUDIO_CANDIDATE_REVISION=nil
if not ok then error(err) end

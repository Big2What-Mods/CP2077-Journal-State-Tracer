-- CP2077 JOURNAL STATE TRACER
local NAME,VER="CP2077 JOURNAL STATE TRACER","v1.6"
local overlay=false
local collapsed=false
local resizeMode="expanded"
local TRACE,RESULTS,ABOUT=1,2,3 local page=TRACE
local READY,INITIALIZING,TRACING,PROCESSING,COMPLETE,ERROR=1,2,3,4,5,6 local state=READY
local SUMMARY,JOURNAL,DETAIL,OTHER=1,2,3,4 local resultView=SUMMARY
local startedClock,started,stopped,elapsed=0,"","",0
local events,raw,changes,other=0,{},{},{} local selected=nil
local progress,processText,queued=0,"",false local lastFile,errText="",""
local hooks={path=false,hash=false} local outputAbs="bin\\x64\\plugins\\cyber_engine_tweaks\\mods\\CP2077 Journal State Tracer\\" local outputRel="output\\"
local C={bg={.018,.035,.045,.985},panel={.025,.055,.070,1},yellow={1,.77,.05,1},green={0,.92,.45,1},blue={.18,.58,1,1},red={1,.2,.2,1},text={.82,.89,.93,1},dim={.48,.65,.73,1}}
local G=IconGlyphs or {}
local IC={mark=G.Square or "",scan=G.Crosshairs or "",play=G.Play or "",stop=G.Stop or "",cog=G.Cog or "",file=G.FileDocument or "",folder=G.Folder or "",check=G.Check or "",plus=G.Plus or "",close=G.Close or "",right=G.ChevronRight or "",left=G.ArrowLeft or "",info=G.Information or "",cube=G.Cube or "",dots=G.DotsHorizontal or "",circle=G.CheckboxBlankCircleOutline or "",down=G.ChevronDown or ""}
local function tc(c,s) ImGui.TextColored(c[1],c[2],c[3],c[4],tostring(s)) end
local function sep() ImGui.Spacing();ImGui.Separator();ImGui.Spacing() end
local function now() return os.date("%Y-%m-%d %H:%M:%S") end
local function fs() return os.date("%Y%m%d_%H%M%S") end
local function dur(v) v=math.max(0,math.floor(v or 0));return string.format("%02d:%02d:%02d",math.floor(v/3600),math.floor((v%3600)/60),v%60) end
local function safe(v) local ok,s=pcall(tostring,v);return ok and s or "<unprintable>" end
local function norm(v) local s=safe(v);if s:find("Inactive",1,true) then return "Inactive" elseif s:find("Succeeded",1,true) then return "Succeeded" elseif s:find("Failed",1,true) then return "Failed" elseif s:find("Active",1,true) then return "Active" end;return s end
local function resolvePath()
 outputAbs="bin\\x64\\plugins\\cyber_engine_tweaks\\mods\\CP2077 Journal State Tracer\\"
end
local function ensureOutput()
 local t=io.open("output\\.st_test","w")
 if t then t:write("ok");t:close();os.remove("output\\.st_test");outputRel="output\\";return true end
 outputRel="";return true
end
local baselineSnapshot=nil

local function reset()
 events=0;raw={};changes={};other={};selected=nil;lastFile="";errText=""
end

local function resetTracer()
 baselineSnapshot=nil
 events=0;raw={};changes={};other={};selected=nil
 lastFile="";errText=""
 startedClock=0;started="";stopped="";elapsed=0
 progress=0;processText="";queued=false
 resultView=SUMMARY;page=TRACE;state=READY
 print("[STATE TRACER "..VER.."] RESET - ready for new trace")
end

local function P5journalSnapshot(stage)
 assert(type(stage)=="string" and #stage>0,"Supply a stage label")
 local jm=assert(Game.GetJournalManager(),"Journal manager unavailable")
 local filter=JournalRequestStateFilter.new()
 filter.inactive=true;filter.active=true;filter.succeeded=true;filter.failed=true
 local result={stage=stage,utc=os.date("!%Y-%m-%dT%H:%M:%SZ"),entries={}}
 local seen={}
 local function record(e,path)
  local stateNow=jm:GetEntryState(e);local t=jm:GetEntryTimestamp(e)
  return {path=path,id=tostring(e:GetId()),hash=jm:GetEntryHash(e)%4294967296,state=tostring(stateNow),
   active=stateNow==gameJournalEntryState.Active,succeeded=stateNow==gameJournalEntryState.Succeeded,
   inactive=stateNow==gameJournalEntryState.Inactive,failed=stateNow==gameJournalEntryState.Failed,
   timestamp={days=t:Days(),hours=t:Hours(),minutes=t:Minutes(),seconds=t:Seconds()}}
 end
 local function walk(e,path)
  local r=record(e,path);if seen[r.hash] then return end;seen[r.hash]=true;result.entries[r.hash]=r
  local children=jm:GetChildren(e,filter);assert(type(children)=="table","GetChildren did not return an array")
  for _,child in ipairs(children) do walk(child,path.."/"..tostring(child:GetId())) end
 end
 for _,root in ipairs({{"quests","gameJournalPrimaryFolderEntry"},{"ep1/quests","gameJournalPrimaryFolderEntry"}}) do
  local e=jm:GetEntryByString(root[1],root[2]);if e then walk(e,root[1]) end
 end
 assert(next(result.entries)~=nil,"Journal snapshot contained no entries")
 return result
end

local function timestampText(t)
 if not t then return "Unknown" end
 return string.format("%dd %02d:%02d:%02d",t.days or 0,t.hours or 0,t.minutes or 0,t.seconds or 0)
end

local function startTrace()
 print("[STATE TRACER v0.8] START");reset();state=INITIALIZING;page=TRACE
 local ok,snap=pcall(P5journalSnapshot,"START")
 if not ok then state=ERROR;errText="START P5 snapshot failed: "..tostring(snap);print("[STATE TRACER v0.8] "..errText);return end
 baselineSnapshot=snap;startedClock=os.clock();started=now();stopped="";elapsed=0;state=TRACING
 print("[STATE TRACER v0.8] P5 START snapshot OK")
end

local function stopTrace()
 if state~=TRACING then return end
 elapsed=os.clock()-startedClock;stopped=now();state=PROCESSING;progress=.15;processText="Finalizing capture data...";queued=true
end

local function buildResults()
 local ok,final=pcall(P5journalSnapshot,"STOP")
 if not ok then return false,"STOP P5 snapshot failed: "..tostring(final) end
 changes={}
 local A=(baselineSnapshot and baselineSnapshot.entries) or {};local B=final.entries or {}
 for hash,before in pairs(A) do
  local after=B[hash]
  if after and before.state~=after.state then
   changes[#changes+1]={path=after.path,id=after.id,hash=after.hash,type="gameJournalEntry",
    afterState=after.state,afterTime=timestampText(after.timestamp),source="P5"}
  end
 end
 table.sort(changes,function(x,y) return tostring(x.path)<tostring(y.path) end)
 return true,nil
end

local function prettyJSON(encoded)
 local out={}
 local indent=0
 local inString=false
 local escaped=false
 local i=1
 while i<=#encoded do
  local ch=encoded:sub(i,i)
  if inString then
   out[#out+1]=ch
   if escaped then
    escaped=false
   elseif ch=="\\" then
    escaped=true
   elseif ch=='"' then
    inString=false
   end
  else
   if ch=='"' then
    inString=true
    out[#out+1]=ch
   elseif ch=="{" or ch=="[" then
    indent=indent+1
    out[#out+1]=ch.."\n"..string.rep("  ",indent)
   elseif ch=="}" or ch=="]" then
    indent=math.max(0,indent-1)
    out[#out+1]="\n"..string.rep("  ",indent)..ch
   elseif ch=="," then
    out[#out+1]=ch.."\n"..string.rep("  ",indent)
   elseif ch==":" then
    out[#out+1]=": "
   else
    out[#out+1]=ch
   end
  end
  i=i+1
 end
 return table.concat(out)
end

local function writeReport()
 if not json or not json.encode then return false,"CET JSON encoder unavailable" end;ensureOutput()
 local n="StateTrace_"..fs()..".json";local f,e=io.open(outputRel..n,"w");if not f then return false,tostring(e) end
 local reportChanges={}
 for _,r in ipairs(changes) do
  reportChanges[#reportChanges+1]={
   id=r.id,
   path=r.path,
   hash=r.hash,
   state=norm(r.afterState),
   gameTime=r.afterTime
  }
 end
 local report={
  tool=NAME,
  version=VER,
  started=started,
  stopped=stopped,
  durationSeconds=elapsed,
  eventsCaptured=#changes,
  journalChanges=reportChanges,
 }
 f:write(prettyJSON(json.encode(report)));f:close();lastFile=n;return true
end
local function process()
 if state~=PROCESSING or not queued then return end;queued=false;progress=.45;processText="Comparing state changes..."
 local diffOK,diffErr=buildResults()
 if not diffOK then state=ERROR;errText="Snapshot comparison failed: "..tostring(diffErr);return end
 progress=.78;processText="Writing output file..."
 local ok,e=writeReport();if not ok then state=ERROR;errText=e;return end;progress=1;processText="Preparing results...";state=COMPLETE;page=RESULTS;resultView=SUMMARY
end
local function pushTheme()
 ImGui.PushStyleColor(ImGuiCol.WindowBg,table.unpack(C.bg));ImGui.PushStyleColor(ImGuiCol.ChildBg,table.unpack(C.panel));ImGui.PushStyleColor(ImGuiCol.Border,table.unpack(C.yellow));ImGui.PushStyleColor(ImGuiCol.Text,table.unpack(C.text));ImGui.PushStyleColor(ImGuiCol.Button,.025,.06,.075,1);ImGui.PushStyleColor(ImGuiCol.ButtonHovered,.055,.11,.125,1);ImGui.PushStyleColor(ImGuiCol.ButtonActive,.075,.14,.155,1)
 ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding,0);ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding,0);ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize,1);ImGui.PushStyleVar(ImGuiStyleVar.FrameBorderSize,1);ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding,12,12);ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing,7,7)
end
local function popTheme() ImGui.PopStyleVar(6);ImGui.PopStyleColor(7) end
local function header()
 local chevron=collapsed and IC.right or IC.down
 ImGui.PushStyleColor(ImGuiCol.Button,0,0,0,0)
 ImGui.PushStyleColor(ImGuiCol.ButtonHovered,0,0,0,0)
 ImGui.PushStyleColor(ImGuiCol.ButtonActive,0,0,0,0)
 ImGui.PushStyleColor(ImGuiCol.Border,0,0,0,0)
 ImGui.PushStyleColor(ImGuiCol.Text,table.unpack(C.yellow))
 if ImGui.Button(chevron.."##collapse",28,26) then
  collapsed=not collapsed
  resizeMode=collapsed and "collapsed" or "expanded"
 end
 ImGui.PopStyleColor(5)
 ImGui.SameLine()
 tc(C.yellow,NAME)
 if not collapsed then
  sep()
 end
end
local function tab(label,target,w) local a=page==target;if a then ImGui.PushStyleColor(ImGuiCol.Button,.12,.13,.10,1);ImGui.PushStyleColor(ImGuiCol.Text,table.unpack(C.yellow)) end;if ImGui.Button(label,w,32) then page=target end;if a then ImGui.PopStyleColor(2) end end
local function nav() local w=(ImGui.GetContentRegionAvail()-14)/3;tab("TRACE",TRACE,w);ImGui.SameLine();tab("RESULTS",RESULTS,w);ImGui.SameLine();tab("ABOUT",ABOUT,w);sep() end
local function footer()
 sep()
 tc(C.yellow,IC.folder.."  Output Location:")
 ImGui.TextWrapped(outputAbs)
end
local function isInGame()
 local okP,player=pcall(function() return Game.GetPlayer() end)
 if not okP or not player then return false end
 local okA,attached=pcall(function() return player:IsAttached() end)
 if not okA or not attached then return false end
 local okR,requests=pcall(function() return Game.GetSystemRequestsHandler() end)
 if not okR or not requests then return false end
 local okPre,preGame=pcall(function() return requests:IsPreGame() end)
 if not okPre or preGame then return false end
 return true
end

local function ready()
 if not isInGame() then
  tc(C.dim,IC.scan.."   Status:  NOT IN GAME")
  ImGui.TextWrapped("        Enter a playable game session to enable tracing.")
  ImGui.Spacing()
  return
 end
 tc(C.green,IC.scan.."   Status:  READY")
 ImGui.TextWrapped("        Tool ready to capture state changes.")
 ImGui.Spacing()
 ImGui.PushStyleColor(ImGuiCol.Text,table.unpack(C.yellow))
 if ImGui.Button(IC.play.."   START TRACE",-1,48) then startTrace() end
 ImGui.PopStyleColor()
 ImGui.Spacing()
end
local function tracing()
 tc(C.green,IC.scan.."   Status:  TRACING");ImGui.Spacing();ImGui.Spacing();ImGui.TextWrapped("        Capturing live changes.");ImGui.Spacing();ImGui.Spacing();elapsed=os.clock()-startedClock
 ImGui.Text("Started:     "..started);ImGui.Text("Duration:    "..dur(elapsed));tc(C.dim,"Capturing in progress...");ImGui.Spacing()
 ImGui.PushStyleColor(ImGuiCol.Button,.01,.16,.07,1);ImGui.PushStyleColor(ImGuiCol.ButtonHovered,.02,.25,.10,1);ImGui.PushStyleColor(ImGuiCol.ButtonActive,.02,.32,.13,1);ImGui.PushStyleColor(ImGuiCol.Border,table.unpack(C.green));ImGui.PushStyleColor(ImGuiCol.Text,table.unpack(C.green))
 if ImGui.Button(IC.stop.."   STOP TRACE",-1,48) then stopTrace() end;ImGui.PopStyleColor(5)
end
local function processing()
 tc(C.yellow,IC.cog.."   Status:  PROCESSING");ImGui.TextWrapped("        Capture stopped. Analyzing changes and writing results...");ImGui.ProgressBar(progress,-1,18);ImGui.Spacing()
 tc(C.green,IC.check.."  Finalizing capture data...");if progress>=.45 then tc(C.green,IC.check.."  Comparing state changes...") else tc(C.yellow,IC.circle.."  Comparing state changes...") end
 if progress>=.78 then tc(C.green,IC.check.."  Writing output file...") else tc(C.yellow,IC.circle.."  Writing output file...") end;tc(C.yellow,IC.circle.."  Preparing results...")
end
local function initializingPage()
 tc(C.yellow,IC.cog.."   Status:  INITIALIZING")
 ImGui.TextWrapped("        Capturing baseline journal state...")
 ImGui.Spacing()
 ImGui.ProgressBar(-1,-1,18)
end

local function tracePage()
 if state==READY then ready()
 elseif state==INITIALIZING then initializingPage()
 elseif state==TRACING then tracing()
 elseif state==PROCESSING then processing()
 elseif state==ERROR then tc(C.red,IC.close.." ERROR");ImGui.TextWrapped(errText)
 else
  tc(C.green,IC.check.." TRACE COMPLETE")
  ImGui.Text("Events Captured:  "..#changes)
  ImGui.TextWrapped("Results are available on the RESULTS page.")
  ImGui.TextWrapped("Report File:  "..outputAbs..lastFile)
  ImGui.Spacing();ImGui.Spacing()
  local bw=220
  local avail=ImGui.GetContentRegionAvail()
  ImGui.SetCursorPosX(ImGui.GetCursorPosX()+math.max(0,(avail-bw)/2))
  ImGui.PushStyleColor(ImGuiCol.Text,table.unpack(C.yellow))
  if ImGui.Button("RESET TRACER",bw,40) then resetTracer() end
  ImGui.PopStyleColor()
 end
end
local function summary()
 if state~=COMPLETE then ImGui.TextWrapped("No completed trace is available.");return end
 tc(C.dim,IC.file);ImGui.SameLine();ImGui.Text("Trace File:    "..lastFile);ImGui.Text("Duration:      "..dur(elapsed));ImGui.Text("Total Changes: "..(#changes+#other));ImGui.Text("Captured:      "..started);sep()
 if ImGui.Button(IC.file.."  Journal Changes    "..#changes.."    "..IC.right,-1,42) then resultView=JOURNAL end
end
local function jicon(r) local st=tostring(r.afterState or "");if st:find("Succeeded",1,true) then return IC.check,C.green elseif st:find("Active",1,true) then return IC.plus,C.blue elseif st:find("Failed",1,true) then return IC.close,C.red end;return IC.file,C.text end
local function journal()
 tc(C.yellow,"JOURNAL CHANGES ("..#changes..")");sep();if #changes==0 then ImGui.TextWrapped("No journal changes recorded in this trace.");return end
 for i,r in ipairs(changes) do local ic,col=jicon(r);tc(col,ic);ImGui.SameLine();ImGui.Text(tostring(r.afterState));if r.path then tc(C.dim,r.path) elseif r.hash then tc(C.dim,"Hash: "..r.hash) end
  if ImGui.Button("DETAILS  "..IC.right.."##"..i,-1,25) then selected=r;resultView=DETAIL end;ImGui.Spacing() end
end
local function detail()
 if not selected then resultView=JOURNAL;return end;if ImGui.Button(IC.left.."  Back to Results") then resultView=JOURNAL;return end;sep();local ic,col=jicon(selected);tc(col,ic.."  "..tostring(selected.afterState));if selected.path then tc(C.dim,selected.path) end;sep()
 ImGui.Text("Type:          "..tostring(selected.type or "Unknown"));ImGui.Text("Hash:          "..tostring(selected.hash or "Unknown"));ImGui.Text("After State:   "..selected.afterState);ImGui.Text("After Time:    "..selected.afterTime);sep();tc(C.yellow,IC.right.."  Raw Data (JSON)")
end
local function otherPage() tc(C.yellow,"OTHER CHANGES");sep();tc(C.dim,IC.info);ImGui.TextWrapped("No other changes recorded in this trace.");tc(C.dim,"This section shows non-journal game state changes when supported.") end
local function resultsPage() if resultView==SUMMARY then summary() elseif resultView==JOURNAL then journal() elseif resultView==DETAIL then detail() else otherPage() end end
local function centeredText(text)
 local w=ImGui.CalcTextSize(text)
 local avail=ImGui.GetContentRegionAvail()
 local x=math.max(0,(avail-w)/2)
 ImGui.SetCursorPosX(ImGui.GetCursorPosX()+x)
 ImGui.Text(text)
end

local function about()
 tc(C.yellow,NAME);sep()
 ImGui.TextWrapped("CP2077 Journal State Tracer is a read-only utility for Cyberpunk 2077. It compares JournalManager state at the start and end of a trace and reports journal entries whose state changed.")
 sep();tc(C.yellow,"HOW IT WORKS")
 for _,x in ipairs({"Press START TRACE.","Perform the action or sequence you want to test.","Press STOP TRACE.","Review the detected journal state changes."}) do
  tc(C.yellow,IC.check);ImGui.SameLine();ImGui.TextWrapped(x)
 end
 sep();tc(C.yellow,"PURPOSE")
 ImGui.TextWrapped("Built for players, mod authors, testers, and researchers who want to identify journal state changes caused by gameplay.")
 ImGui.Spacing()
 ImGui.Spacing()
 centeredText("Made by")
 centeredText("Big2What & ChatGPT GPT-5.6 Sol")
 centeredText("CP2077 Journal Tracer Version "..VER)
end
registerForEvent("onInit",function() resolvePath() end)
registerForEvent("onOverlayOpen",function() overlay=true end)
registerForEvent("onOverlayClose",function() overlay=false end)
registerForEvent("onUpdate",function() if state==PROCESSING and queued then process() end end)
registerForEvent("onDraw",function()
 if not overlay then return end

 pushTheme()

 -- Force size only when changing collapse state.
 -- This fixes v0.2 getting trapped at the compact height.
 if resizeMode=="collapsed" then
  ImGui.SetNextWindowSize(390,54,ImGuiCond.Always)
 elseif resizeMode=="expanded" then
  ImGui.SetNextWindowSize(690,560,ImGuiCond.Always)
 end

 local visible=ImGui.Begin(
  NAME.."##StateTracer",
  true,
  ImGuiWindowFlags.NoTitleBar+ImGuiWindowFlags.NoCollapse+ImGuiWindowFlags.NoScrollbar
 )

 -- The forced resize is consumed by this Begin().
 resizeMode=nil

 if visible then
  header()

  if not collapsed then
   nav()

   local footerReserve=72
   ImGui.BeginChild("Main",0,-footerReserve,true)

   if page==TRACE then
    tracePage()
   elseif page==RESULTS then
    resultsPage()
   else
    about()
   end

   ImGui.EndChild()
   footer()
  end
 end

 ImGui.End()
 popTheme()
end)

print("["..NAME.."] "..VER.." loaded")

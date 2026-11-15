include=function() end;
local planned=false;
local snapshot={};
AutoTheme={Collect=function() return snapshot; end,
    Plan=function() return {steps=planned and {{}} or {}}; end};
local function event()
    local handlers={};
    return {Add=function(f) handlers[f]=true; end,Remove=function(f) handlers[f]=nil; end,
        fire=function() for f in pairs(handlers) do f(); end end};
end
Events={};
for _,name in ipairs({"GreatWorkMoved","GreatWorkCreated","BuildingAddedToMap","BuildingRemovedFromMap",
    "CityAddedToMap","CityRemovedFromMap","CityFocusChanged","BuildingChanged","DistrictPillaged","DistrictDamageChanged","LocalPlayerTurnBegin","LocalPlayerTurnEnd","LoadScreenClose"}) do
    Events[name]=event();
end
local active=true;
Players={[0]={IsTurnActive=function() return active; end}};
Game={GetLocalPlayer=function() return 0; end,GetCurrentGameTurn=function() return 1; end};
UI={IsGameCoreBusy=function() return false; end};
Locale={Lookup=function(k,...) for i=1,select('#',...)do assert(select(i,...)~=nil,'native Locale.Lookup rejects nil');end;return k;end}; Mouse={eLClick=1};
local update,shutdown,disabled,status,tooltip,toolbarParent,toolbarHidden;
local ownedAnchor={};
local parent={IsHidden=function() return false; end};
ContextPtr={LookUpControl=function() return parent; end,SetHide=function() end,
    SetUpdate=function(_,f) update=f; end,SetInitHandler=function() end,
    SetShutdown=function(_,f) shutdown=f; end,ClearUpdate=function() update=nil; end};
Controls={UpdateAnchor=ownedAnchor,ThemeTools={ChangeParent=function(_,v)toolbarParent=v;end,SetHide=function(_,v)toolbarHidden=v;end},
    ThemeCount={SetText=function()end},
    ThemeIcon={SetIcon=function()end},
    StatusHeading={SetText=function()end,SetToolTipString=function()end},
    StatusPanel={SetHide=function() end},StatusLabel={SetText=function(_,v)status=v;end,SetToolTipString=function()end},
    ThemeButton={SetDisabled=function(_,v) disabled=v; end,SetToolTipString=function(_,v)tooltip=v;end,
        RegisterCallback=function() end}};
assert(loadfile("mod/AutoTheme.lua"))();
update(1); assert(disabled==true);
planned=true; update(0.2); assert(disabled==true, "unchanged snapshot keeps the cached plan");
Events.GreatWorkCreated.fire(); update(1); assert(disabled==false, "new work must invalidate cache");
planned=false; Events.CityFocusChanged.fire(); update(1); assert(disabled==true);
planned=true; Events.BuildingAddedToMap.fire(); update(1); assert(disabled==false);
active=false; Events.LocalPlayerTurnEnd.fire(); update(1); assert(disabled==true);
active=true; Events.LocalPlayerTurnBegin.fire(); update(1); assert(disabled==false);
-- Manual shuffling invalidates an old completion message even when no legal plan exists.
status='previous completion';planned=false;
snapshot={containers={{unlocked=false,slots={{work=1}}}},works={}};
Events.GreatWorkMoved.fire();update(1);
assert(disabled and status=='LOC_AT_BUILDINGS_PILLAGED' and tooltip:find(status,1,true));
snapshot.containers[1].unlocked=true;planned=true;
update(3);assert(not disabled and status=='LOC_AT_READY','repair must refresh even without an event');
planned=false;snapshot={works={{available=true,movable=false,object='GREATWORKOBJECT_RELIGIOUS'}}};
Events.GreatWorkMoved.fire();update(1);assert(disabled and status=='LOC_AT_ART_LOCKED');
snapshot={works={{available=true,movable=false,object='GREATWORKOBJECT_ARTIFACT'}}};
Events.GreatWorkMoved.fire();update(1);assert(disabled and status=='LOC_AT_ARTIFACTS_LOCKED');
snapshot={};Events.GreatWorkMoved.fire();update(1);assert(status=='LOC_AT_NO_COMBINATION_SHORT');
shutdown(); assert(update==nil);
assert(toolbarParent==ownedAnchor and toolbarHidden,'hot reload must reclaim and hide the old toolbar');
Events.GreatWorkCreated.fire();
print("Theme availability regression passed: new work, scoring, slots, turn ownership, shutdown");

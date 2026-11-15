-- Run the actual toolbar callbacks and scheduler against delayed slot changes.
include=function() end;
local active, hidden, busy = true, false, false;
local contents, requests, status, buttonText = {1,2,3}, {}, nil, nil;
local update, click, shutdown;
local canSwap = true;
local function event()
    local callbacks={};
    return {Add=function(f) callbacks[f]=true; end,Remove=function(f) callbacks[f]=nil; end,
        fire=function() for f in pairs(callbacks) do f(); end end};
end
Events={};
for _,name in ipairs({'GreatWorkMoved','GreatWorkCreated','BuildingAddedToMap','BuildingRemovedFromMap',
    'CityAddedToMap','CityRemovedFromMap','BuildingChanged','DistrictPillaged','DistrictDamageChanged',
    'CityFocusChanged','LocalPlayerTurnBegin','LocalPlayerTurnEnd','LoadScreenClose'}) do Events[name]=event(); end
Game={GetLocalPlayer=function() return 0; end,GetCurrentGameTurn=function() return 100; end};
Players={[0]={IsTurnActive=function() return active; end}};
PlayerOperations={MOVE_GREAT_WORK=1,PARAM_PLAYER_ONE='player',PARAM_CITY_SRC='citySource',PARAM_CITY_DEST='cityDest',
    PARAM_GREAT_WORK_INDEX='work',PARAM_BUILDING_SRC='buildingSource',PARAM_BUILDING_DEST='buildingDest',PARAM_SLOT='slot'};
UI={IsGameCoreBusy=function() return busy; end,RequestPlayerOperation=function(_,_,params) requests[#requests+1]=params; end};
AutoTheme={Collect=function()
    local container={key='city',allowed=true,unlocked=true,count=3,slots={}};
    local snapshot={containers={container},slots={},works={},themed=0};
    for key=1,3 do
        local slot={key=key,city=1,building=1,slot=key,work=contents[key],container=container};
        container.slots[key]=slot; snapshot.slots[key]=slot;
    end
    return snapshot;
end,Plan=function(snapshot)
    return {steps={{source=1,destination=2,work=snapshot.slots[1].work,other=snapshot.slots[2].work},
        {source=2,destination=3,work=snapshot.slots[1].work,other=snapshot.slots[3].work}},targets={},skipped=0};
end,ReadSlot=function(slot) return contents[slot.key]; end,CanSwap=function() return canSwap; end};
Locale={Lookup=function(key,...) return key; end}; Mouse={eLClick=1};
local panel={IsHidden=function() return hidden; end};
ContextPtr={LookUpControl=function() return panel; end,SetHide=function() end,SetUpdate=function(_,f) update=f; end,
    SetInitHandler=function() end,SetShutdown=function(_,f) shutdown=f; end,ClearUpdate=function() update=nil; end};
Controls={UpdateAnchor={},ThemeTools={ChangeParent=function() end,SetHide=function() end},
    ThemeCount={SetText=function() end},ThemeIcon={SetIcon=function() end},
    StatusPanel={SetHide=function() end},StatusHeading={SetText=function() end,SetToolTipString=function() end},
    StatusLabel={SetText=function(_,value) status=value; end,SetToolTipString=function() end},
    ThemeButton={SetText=function(_,value) buttonText=value; end,SetDisabled=function() end,SetToolTipString=function() end,
        RegisterCallback=function(_,_,f) click=f; end}};
dofile('mod/AutoTheme.lua');
local function tick() update(0.6); end
local function start()
    active=true; hidden=false; busy=false; contents={1,2,3}; requests={}; canSwap=true;
    Events.GreatWorkMoved.fire(); tick(); click(); tick(); tick();
    assert(#requests==1,'first native swap must be submitted exactly once');
end
local function reply()
    local request=requests[#requests];
    local source;
    for key,work in ipairs(contents) do if work==request.work then source=key; end end
    assert(source,'requested work disappeared');
    contents[source],contents[request.slot]=contents[request.slot],contents[source];
    Events.GreatWorkMoved.fire();
end

start(); tick(); tick(); assert(#requests==1,'duplicate pending swap');
reply(); tick(); assert(#requests==2); reply(); tick();
assert(status=='LOC_AT_DONE' and buttonText=='LOC_AT_START');

-- Explicit stop and closing the native panel wait for the submitted swap, then stop.
start(); click(); tick(); assert(status=='LOC_AT_CANCELLING' and #requests==1);
reply(); tick(); assert(status=='LOC_AT_CANCELLED' and #requests==1);
start(); hidden=true; tick(); reply(); tick(); assert(status=='LOC_AT_CANCELLED' and #requests==1);
hidden=false; tick(); tick(); assert(#requests==1,'reopening must not restart the cancelled run');

-- Cancellation while planning never submits a swap.
requests={}; click(); hidden=true; tick(); assert(#requests==0 and status=='LOC_AT_CANCELLED');

-- Unexpected manual changes, native rejection, and missing acknowledgements stop safely.
start(); contents[3]=999; tick(); assert(status=='LOC_AT_CHANGED' and #requests==1);
start(); update(9); assert(status=='LOC_AT_REJECTED' and #requests==1);
start(); reply(); canSwap=false; tick(); assert(status=='LOC_AT_REJECTED' and #requests==1);

-- A confirmed native result is accepted even after a long engine busy interval.
start(); busy=true; update(30); assert(#requests==1); reply(); busy=false; tick();
assert(#requests==2); reply(); tick(); assert(status=='LOC_AT_DONE');

start(); active=false; Events.LocalPlayerTurnEnd.fire(); tick();
assert(status=='LOC_AT_TURN_ENDED' and #requests==1);
reply(); active=true; Events.LocalPlayerTurnBegin.fire(); tick(); assert(#requests==1);
shutdown(); assert(update==nil);
print('AutoTheme interaction regression passed: serial swaps, cancel, close/reopen, manual change, rejection, busy, turn end');

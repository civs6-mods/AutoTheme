-- Two independent UI contexts sharing a simulated authoritative operation queue.
-- This tests the real scheduler, not Civ VI's networking implementation.
local checks = 0;
local function check(value, message) assert(value, message); checks=checks+1; end
local function event()
    local handlers={};
    return {Add=function(f) handlers[f]=true; end, Remove=function(f) handlers[f]=nil; end,
        fire=function(...) for f in pairs(handlers) do f(...); end end,
        count=function() local n=0; for _ in pairs(handlers) do n=n+1; end; return n; end};
end
local function world()
    local w={turn=100, contents={[0]={1,2,3},[1]={11,12,13}}, queue={}, clients={}};
    function w:deliver(index)
        local request=self.queue[index]; check(not request.delivered,'request delivered twice');
        request.delivered=true;
        local contents=self.contents[request.player]; local source;
        for key,id in ipairs(contents) do if id==request.params.work then source=key; end end
        check(source~=nil,'operation must reference a work owned by its submitting player');
        contents[source],contents[request.params.slot]=contents[request.params.slot],contents[source];
        for _,c in ipairs(self.clients) do c.env.Events.GreatWorkMoved.fire(); end
    end
    return w;
end
local function client(w,id)
    local c={id=id,active=true,sent=false,busy=false,resync=false,hidden=false};
    local e=setmetatable({}, {__index=_G}); c.env=e;
    e.print=function() end; e.include=function() end;
    e.Events={};
    for _,name in ipairs({'GreatWorkMoved','GreatWorkCreated','BuildingAddedToMap','BuildingRemovedFromMap',
        'CityAddedToMap','CityRemovedFromMap','BuildingChanged','DistrictPillaged','DistrictDamageChanged',
        'CityFocusChanged','LocalPlayerTurnBegin','LocalPlayerTurnEnd','LocalPlayerChanged','LoadScreenClose',
        'MultiplayerPrePlayerDisconnected'}) do
        e.Events[name]=event();
    end
    e.Game={GetLocalPlayer=function() return c.id; end, GetCurrentGameTurn=function() return w.turn; end};
    e.Players={[0]={IsTurnActive=function() return c.active; end},[1]={IsTurnActive=function() return c.active; end}};
    e.PlayerOperations={MOVE_GREAT_WORK=1, PARAM_PLAYER_ONE='player',PARAM_CITY_SRC='citySource',PARAM_CITY_DEST='cityDest',
        PARAM_GREAT_WORK_INDEX='work',PARAM_BUILDING_SRC='buildingSource',PARAM_BUILDING_DEST='buildingDest',PARAM_SLOT='slot'};
    e.UI={IsGameCoreBusy=function() return c.busy; end, HasSentTurnComplete=function() return c.sent; end,
        IsResyncLoadInProgress=function() return c.resync; end,
        RequestPlayerOperation=function(player,operation,params)
            check(player==c.id and player==params.player,'operation owner must match the local player');
            check(operation==1 and c.active and not c.sent and not c.resync,'request while input is unavailable');
            w.queue[#w.queue+1]={player=player,params=params};
            if c.throwAfterSubmit then error('transport response failed after submission'); end
        end};
    e.AutoTheme={Collect=function(player)
        player=player or c.id;
        check(player==c.id,'planner must only collect its own player');
        local container={key='city',allowed=true,unlocked=true,count=3,slots={}};
        local s={containers={container},slots={},works={},themed=0};
        for key,work in ipairs(w.contents[player] or {}) do
            local slot={key=key,city=1,building=1,slot=key,work=work,container=container};
            s.slots[key]=slot; container.slots[key]=slot;
        end
        return s;
    end, Plan=function(s)
        if not s.slots[1] then return {steps={},targets={}}; end
        return {steps={{source=1,destination=2,work=s.slots[1].work,other=s.slots[2].work},
            {source=2,destination=3,work=s.slots[1].work,other=s.slots[3].work}},targets={},skipped=0};
    end, ReadSlot=function(slot,player)
        check(player~=nil,'pending reads must bind the original player explicitly');
        return (w.contents[player] or {})[slot.key];
    end, CanSwap=function() return true; end};
    e.Locale={Lookup=function(key) return key; end}; e.Mouse={eLClick=1};
    local panel={IsHidden=function() return c.hidden; end};
    e.ContextPtr={LookUpControl=function() return panel; end,SetHide=function() end,
        SetUpdate=function(_,f) c.update=f; end,SetInitHandler=function() end,
        SetShutdown=function(_,f) c.shutdown=f; end,ClearUpdate=function() c.update=nil; end};
    e.Controls={UpdateAnchor={},ThemeTools={ChangeParent=function() end,SetHide=function() end},
        ThemeCount={SetText=function() end},ThemeIcon={SetIcon=function() end},StatusPanel={SetHide=function() end},
        StatusHeading={SetText=function() end,SetToolTipString=function() end},
        StatusLabel={SetText=function(_,s) c.status=s; end,SetToolTipString=function() end},
        ThemeButton={SetText=function() end,SetDisabled=function(_,v) c.disabled=v; end,SetToolTipString=function() end,
            RegisterCallback=function(_,_,f) c.click=f; end}};
    assert(loadfile('mod/AutoTheme.lua','t',e))(); w.clients[#w.clients+1]=c;
    function c:tick(delta) self.update(delta or 0.6); end
    function c:start() self:tick(); self.click(); self:tick(); self:tick(); end
    return c;
end

-- Both clients arrange independently. Replicated events never issue operations
-- on behalf of another player; a delay beyond the old eight-second limit is OK.
local w=world(); local a,b=client(w,0),client(w,1);
a:start(); b:start(); check(#w.queue==2,'one pending operation per client');
a:tick(12); b:tick(12); check(#w.queue==2,'delayed responses must not cause retries');
w:deliver(2); b:tick(); a:tick(); check(#w.queue==3 and w.queue[3].player==1,'client B can advance independently');
w:deliver(1); a:tick(); check(#w.queue==4 and w.queue[4].player==0,'client A advances after its own response');
w:deliver(4); w:deliver(3); a:tick(); b:tick();
check(a.status=='LOC_AT_DONE' and b.status=='LOC_AT_DONE','both clients finish');
check(table.concat(w.contents[0],',')=='2,3,1' and table.concat(w.contents[1],',')=='12,13,11','no cross-player writes');

-- Timeout retains a submission guard, including repeated clicks and panel reopen.
w=world(); a=client(w,0); a:start(); a:tick(31); a.click(); a:tick();
a.hidden=true; a:tick(); a.hidden=false; a:tick(); a.click(); a:tick();
check(#w.queue==1 and a.disabled,'unconfirmed operation blocks new runs after timeout');
w:deliver(1); a:tick(); check(#w.queue==1 and not a.disabled,'late success unlocks without resuming');
a.click(); a:tick(); a:tick(); check(#w.queue==2 and w.queue[2].params.work==2,'fresh plan reads confirmed state');

-- Interleaved manual/trade changes stop the chain but do not lose its guard.
w=world(); a=client(w,0); a:start(); w.contents[0][3]=99; a:tick(); a.click(); a:tick();
check(#w.queue==1,'external changes must not release an unconfirmed native request');
w:deliver(1); a:tick(); check(#w.queue==1 and not a.disabled,'guard watches its own two slots after external changes');

-- End-turn submission and rollover can happen without an intervening UI tick.
w=world(); a=client(w,0); a:start(); a.sent=true; a:tick(); w:deliver(1); a:tick();
check(#w.queue==1 and a.disabled,'sent end-turn blocks follow-up even while IsTurnActive is true');
a.sent=false; w.turn=w.turn+1; a:tick(); check(#w.queue==1,'next turn does not auto-resume');
w=world(); a=client(w,0); a:start(); w:deliver(1); w.turn=w.turn+1; a:tick();
check(#w.queue==1,'old plan must not cross turn boundary');
w=world(); a=client(w,0); a:start(); a:tick(31); w.turn=w.turn+1; a:start();
check(#w.queue==2,'unconfirmed previous-turn request allows a fresh next-turn plan');

-- Cancellation, observer transitions and overlapping city/slot IDs.
w=world(); a=client(w,0); a:start(); a.click(); w:deliver(1); a:tick();
check(#w.queue==1 and a.status=='LOC_AT_CANCELLED','cancel stops after confirmation');
w=world(); a=client(w,0); a:start(); a.id=1; a.env.Events.LocalPlayerChanged.fire(1,0); a:tick();
check(#w.queue==1,'player change discards the old plan');
a:start(); check(#w.queue==2 and w.queue[2].player==1,'new player gets an independent plan');
a.id=-1; a.env.Events.LocalPlayerChanged.fire(-1,1); a:tick(); a.click(); a:tick();
check(#w.queue==2 and a.disabled,'observer cannot arrange');
a.id=0; a.env.Events.LocalPlayerChanged.fire(0,-1); a:start();
check(#w.queue==2,'switching players cannot evade an outstanding guard');

-- A resync/read-load clears UI plans. The saved world alone determines the next plan.
w=world(); a=client(w,0); a:start(); a.resync=true; a:tick(); w:deliver(1);
a.resync=false; a.env.Events.LoadScreenClose.fire(); a:tick();
check(#w.queue==1,'load/reconnect must not replay queued UI actions');
a:start(); check(#w.queue==2 and w.queue[2].params.work==2,'reconnected plan uses restored positions');

-- Busy game core may acknowledge late; UI errors must not allow duplicate submits.
w=world(); a=client(w,0); a:start(); a.env.Events.MultiplayerPrePlayerDisconnected.fire(1);
a.click(); a:tick(); check(#w.queue==1,'disconnect stops the chain without discarding its pending guard');
w:deliver(1); a:tick(); check(#w.queue==1,'late response after disconnect must not restart the chain');
w=world(); a=client(w,0); a:start(); a.busy=true; a:tick(45); w:deliver(1); a.busy=false; a:tick();
check(#w.queue==2,'confirmed result survives a long game-core busy interval');
w=world(); a=client(w,0); a.throwAfterSubmit=true; a:start(); a.click(); a:tick();
check(#w.queue==1,'API exception after submit retains guard');
a.shutdown(); check(a.update==nil,'shutdown removes scheduler');
for _,ev in pairs(a.env.Events) do check(ev.count()==0,'shutdown removes all event handlers'); end
print('AutoTheme multiplayer scheduler: '..checks..' assertions passed (simulated clients, not live networking)');

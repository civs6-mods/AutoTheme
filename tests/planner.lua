-- Offline planning checks; engine acceptance is verified separately in game.
local root = "mod/";
local function rows(values)
    return setmetatable({}, {__call = function()
        local i = 0; return function() i = i + 1; return values[i]; end;
    end});
end
GameInfo = {
    GreatWork_ValidSubTypes = rows({
        {GreatWorkSlotType="ART", GreatWorkObjectType="GREATWORKOBJECT_PORTRAIT"},
        {GreatWorkSlotType="ARTIFACT", GreatWorkObjectType="GREATWORKOBJECT_ARTIFACT"},
        {GreatWorkSlotType="WRITING", GreatWorkObjectType="GREATWORKOBJECT_WRITING"}
    })
};
function include(name) assert(loadfile(root .. name .. ".lua"))(); end
include("AutoTheme_Planner");
local checks = 0;
local function check(value, message) assert(value, message); checks = checks + 1; end
local function museums()
    local snapshot = {containers={}, slots={}, works={}, themed=0, locked=0, objects={}};
    local people = {"A", "A", "B", "C", "C", "D"};
    for m=1,2 do
        local c = {key=tostring(m), allowed=true, unlocked=true, full=true, themeable=true,
            count=3, slots={}, groups={ART={slots={}, rules={ThemingUniquePerson=true,
            ThemingSameObjectType=true, ThemingTourismMultiplier=100}}},
            cityData={tourism={}, yields={}, favored={}}};
        snapshot.containers[m] = c;
        for j=1,3 do
            local id=(m-1)*3+j;
            local slot={key=m..":"..j, work=id, slotType="ART", group="ART", flexibility=1, container=c};
            c.slots[j]=slot; c.groups.ART.slots[j]=slot; snapshot.slots[slot.key]=slot;
            snapshot.works[id]={id=id, person=people[id], object="GREATWORKOBJECT_PORTRAIT",
                movable=true, available=true, home=c.key, originalSlot=slot.key,
                value={tourism=3, yields={}, percent={}}};
        end
    end
    return snapshot;
end
local function execute(snapshot, plan)
    local contents={}; for key,slot in pairs(snapshot.slots) do contents[key]=slot.work; end
    for _,step in ipairs(plan.steps) do
        local a,b=snapshot.slots[step.source],snapshot.slots[step.destination];
        check(contents[a.key]==step.work and contents[b.key]==step.other, "stale swap sequence");
        check(AutoTheme.CanSwap(a,b,snapshot,contents), "illegal swap in plan");
        contents[a.key],contents[b.key]=contents[b.key],contents[a.key];
    end
    local seen={}; for _,id in pairs(contents) do
        check(not seen[id], "work duplicated");seen[id]=true;
    end
    for _,c in ipairs(plan.targets) do
        local artists={};
        for _,slot in ipairs(c.slots) do
            local work=snapshot.works[contents[slot.key]];
            check(not artists[work.person], "theme repeats artist");artists[work.person]=true;
        end
    end
end
local s=museums(); local plan=AutoTheme.Plan(s);
check(#plan.targets==2, "two full themes should be possible");
check(#plan.steps>0, "theme needs an inter-museum exchange"); execute(s,plan);
s=museums();s.containers[2].allowed=false;s.containers[2].themed=true;
for id=4,6 do s.works[id].available=false; end
s.works[4].person="C";s.works[5].person="D";s.works[6].person="E";
plan=AutoTheme.Plan(s);check(#plan.targets==0 and #plan.steps==0,"preserve an existing theme");
s=museums();for _,work in pairs(s.works) do work.movable=false; end
plan=AutoTheme.Plan(s);check(#plan.targets==0 and #plan.steps==0,"respect new-art movement lock");
s=museums();s.containers[1].full=false;s.containers[1].slots[3].work=-1;
local a,b=s.containers[1].slots[1],s.containers[2].slots[1];
for _,slot in ipairs({a,b}) do slot.slotType="ARTIFACT";s.works[slot.work].object="GREATWORKOBJECT_ARTIFACT";end
check(not AutoTheme.CanSwap(a,b,s),"do not exchange incomplete artifact museums");
b.slotType="WRITING";s.works[b.work].object="GREATWORKOBJECT_WRITING";
check(not AutoTheme.CanSwap(a,b,s),"do not exchange incompatible slot types");
plan=AutoTheme.Plan({containers={},slots={},works={}});
check(#plan.steps==0 and #plan.targets==0,"empty collection is a valid no-op");
-- A pending request must continue reading its original owner's slots even if
-- the local player changes and both civilizations reuse the same city IDs.
Game={GetLocalPlayer=function() return 1; end};
local owner=0;
local buildings={HasBuilding=function() return true; end,GetNumGreatWorkSlots=function() return 3; end,
    GetGreatWorkInSlot=function() return 101; end};
local city={GetOwner=function() return owner; end,GetBuildings=function() return buildings; end};
Players={[0]={GetCities=function() return {FindID=function() return city; end}; end}};
local slot={city=1,building=1,slot=0};
check(AutoTheme.ReadSlot(slot,0)==101,'pending slot read binds original owner');
check(AutoTheme.ReadSlot(slot)==nil,'default read uses the current local player');
owner=1; check(AutoTheme.ReadSlot(slot,0)==nil,'captured city invalidates original owner read');
owner=0; slot.slot=3; check(AutoTheme.ReadSlot(slot,0)==nil,'removed slot invalidates pending read');
print("AutoTheme planner: "..checks.." assertions passed");

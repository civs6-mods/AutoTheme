include("AutoTheme_Planner");
local AT = AutoTheme;
local run;
local elapsed, clock = 0, 0;
local panel, toolbarParent;
local availabilityClock = -10;
local availabilityDirty = true;
local wasShown = false;
local availabilityTurn = -1;
local availabilityStatusDirty = true;
local availabilitySignature;
local availabilityPollClock = -10;
local availabilityPlayer, availabilityActive;
-- A submitted native operation cannot be cancelled. Keep its guard even if
-- the plan stops, so a slow response cannot cause a second conflicting run.
local outstanding = {};
local RESPONSE_TIMEOUT = 30;

local function SnapshotSignature(snapshot)
    local parts = {};
    for _, container in ipairs(snapshot.containers or {}) do
        parts[#parts + 1] = table.concat({tostring(container.key), tostring(container.unlocked),
            tostring(container.themed), tostring(container.count)}, ":");
        for _, slot in ipairs(container.slots or {}) do
            parts[#parts + 1] = tostring(slot.key) .. "=" .. tostring(slot.work);
        end
    end
    for id, work in pairs(snapshot.works or {}) do
        parts[#parts + 1] = tostring(id) .. ":" .. tostring(work.movable) .. ":" .. tostring(work.available);
    end
    table.sort(parts);
    return table.concat(parts, "|");
end

local function AttachToolbar()
    panel = ContextPtr:LookUpControl("/InGame/GreatWorksOverview");
    local parent = ContextPtr:LookUpControl("/InGame/GreatWorksOverview/HeaderStatsContainer");
    if parent and toolbarParent ~= parent then
        Controls.ThemeTools:ChangeParent(parent);
        toolbarParent = parent;
    end
    Controls.ThemeTools:SetHide(parent == nil);
    return panel and parent and not panel:IsHidden() and not parent:IsHidden();
end

local function Text(key, ...)
    if ... == nil then return Locale.Lookup("LOC_AT_" .. key); end
    return Locale.Lookup("LOC_AT_" .. key, ...);
end

local function Status(key, ...)
    Controls.StatusPanel:SetHide(false);
    local heading = (key == "DONE" or key == "DONE_PARTIAL" or key == "LIMITED") and "RESULT_TITLE" or
        ((key == "PLANNING" or key == "CANCELLING" or key == "RUNNING") and "WORKING_TITLE" or "STATUS_TITLE");
    Controls.StatusHeading:SetText(Text(heading));
    Controls.StatusHeading:SetToolTipString(Text(key, ...));
    Controls.StatusLabel:SetText(Text(key == "NO_COMBINATION" and "NO_COMBINATION_SHORT" or key, ...));
    Controls.StatusLabel:SetToolTipString(Text(key, ...));
end

local function Active(id)
    id = id or Game.GetLocalPlayer();
    return id ~= nil and id >= 0 and id == Game.GetLocalPlayer() and Players[id] ~= nil and
        Players[id]:IsTurnActive() and not (UI.HasSentTurnComplete and UI.HasSentTurnComplete()) and
        not (UI.IsResyncLoadInProgress and UI.IsResyncLoadInProgress());
end

local function PendingOperation()
    return outstanding[Game.GetLocalPlayer()];
end

local function RefreshOutstanding()
    for player, pending in pairs(outstanding) do
        -- A new authoritative turn ends the lifetime of a previous-turn request.
        -- Within the same turn, only the actual exchanged slots release it.
        if Game.GetCurrentGameTurn() ~= pending.turn or
            (AT.ReadSlot(pending.source, player) == pending.after[pending.source.key] and
             AT.ReadSlot(pending.destination, player) == pending.after[pending.destination.key]) then
            outstanding[player] = nil;
            availabilityDirty = true;
            availabilityStatusDirty = true;
        end
    end
end

local function Finish(reason, ...)
    run = nil;
    Controls.ThemeButton:SetText(Text("START"));
    Status(reason, ...);
    availabilityDirty = true;
    availabilityStatusDirty = false;
    availabilitySignature = nil;
end

local function NoPlanReason(snapshot, plan)
    if plan.limited then return "SEARCH_LIMIT"; end
    if (plan.skipped or 0) > 0 then return "NO_ROUTE"; end
    if #(plan.targets or {}) > 0 then return "RULE_MISMATCH"; end
    local damaged = 0;
    for _, container in ipairs(snapshot.containers or {}) do
        if container.unlocked == false then
            for _, slot in ipairs(container.slots or {}) do
                if slot.work ~= nil and slot.work ~= -1 then damaged = damaged + 1; break; end
            end
        end
    end
    if damaged > 0 then return "BUILDINGS_PILLAGED", damaged; end
    local artifactsLocked = false;
    for _, work in pairs(snapshot.works or {}) do
        if work.available and work.movable == false then
            if work.object == "GREATWORKOBJECT_ARTIFACT" then artifactsLocked = true;
            else return "ART_LOCKED"; end
        end
    end
    if artifactsLocked then return "ARTIFACTS_LOCKED"; end
    return "NO_COMBINATION";
end

local function Begin()
    if run then run.cancel = true; Status("CANCELLING"); return; end
    if not Active() then Status("WAIT_TURN"); return; end
    if PendingOperation() then Status("WAIT_SYNC"); return; end
    -- Do planning on the next UI update so the status can be drawn first.
    run = {planning = true, moves = 0, player = Game.GetLocalPlayer(), turn = Game.GetCurrentGameTurn()};
    Controls.ThemeButton:SetText(Text("CANCEL"));
    Status("PLANNING");
end

local function Prepare()
    local snapshot = AT.Collect(run.player);
    local plan = AT.Plan(snapshot);
    if #plan.steps == 0 then
        Finish(NoPlanReason(snapshot, plan)); return;
    end
    run.planning = false;
    run.snapshot = snapshot;
    run.plan = plan;
    run.allowed = {};
    run.expected = {};
    run.counts = {};
    run.cursor = 1;
    for _, container in ipairs(snapshot.containers) do
        run.allowed[container.key] = container.allowed;
        run.counts[container.key] = container.count;
    end
    for key, slot in pairs(snapshot.slots) do run.expected[key] = slot.work; end
    Status("RUNNING", #plan.targets, #plan.steps);
end

local function ReadAll(expected)
    for key, value in pairs(expected) do
        if AT.ReadSlot(run.snapshot.slots[key], run.player) ~= value then return false; end
    end
    return true;
end

local function Move(source, destination)
    local parameters = {};
    parameters[PlayerOperations.PARAM_PLAYER_ONE] = run.player;
    parameters[PlayerOperations.PARAM_CITY_SRC] = source.city;
    parameters[PlayerOperations.PARAM_CITY_DEST] = destination.city;
    parameters[PlayerOperations.PARAM_GREAT_WORK_INDEX] = source.work;
    parameters[PlayerOperations.PARAM_BUILDING_SRC] = source.building;
    parameters[PlayerOperations.PARAM_BUILDING_DEST] = destination.building;
    parameters[PlayerOperations.PARAM_SLOT] = destination.slot;
    local after = {};
    for key, value in pairs(run.expected) do after[key] = value; end
    after[source.key] = destination.work;
    after[destination.key] = source.work;
    -- Wait for the actual slot contents before submitting another swap.
    run.pending = {after = after, deadline = clock + RESPONSE_TIMEOUT, turn = run.turn,
        source = source, destination = destination};
    outstanding[run.player] = run.pending;
    UI.RequestPlayerOperation(run.player, PlayerOperations.MOVE_GREAT_WORK, parameters);
    print("[AutoTheme] Requested work " .. tostring(source.work) .. " -> " .. destination.key);
end

local function Step()
    if run == nil then return; end
    if run.player ~= Game.GetLocalPlayer() or (UI.IsResyncLoadInProgress and UI.IsResyncLoadInProgress()) then
        Finish("SESSION_CHANGED"); return;
    end
    if run.turn ~= Game.GetCurrentGameTurn() or not Active(run.player) then Finish("TURN_ENDED"); return; end
    if UI.IsGameCoreBusy() then return; end
    if run.planning then
        if run.cancel then Finish("CANCELLED", run.moves); else Prepare(); end
        return;
    end
    if run.pending then
        if ReadAll(run.pending.after) then
            outstanding[run.player] = nil;
            run.expected = run.pending.after;
            run.pending = nil;
            run.moves = run.moves + 1;
            run.cursor = run.cursor + 1;
        elseif not ReadAll(run.expected) then Finish("CHANGED"); return;
        elseif clock >= run.pending.deadline then Finish("WAIT_SYNC"); return;
        else return; end
    end
    if run.cancel then Finish("CANCELLED", run.moves); return; end
    if not ReadAll(run.expected) then Finish("CHANGED"); return; end

    local current = AT.Collect(run.player);
    local byContainer = {};
    for _, container in ipairs(current.containers) do
        byContainer[container.key] = container;
        container.allowed = container.unlocked and run.allowed[container.key] == true;
        if run.counts[container.key] and container.count ~= run.counts[container.key] then Finish("CHANGED"); return; end
    end
    local nextStep = run.plan.steps[run.cursor];
    if nextStep == nil then
        for _, target in ipairs(run.plan.targets) do
            local container = byContainer[target.key];
            if not container or not container.themed then Finish("RULE_MISMATCH"); return; end
        end
        local gained = current.themed - run.snapshot.themed;
        local reason = run.plan.limited and "LIMITED" or (run.plan.skipped > 0 and "DONE_PARTIAL" or "DONE");
        Finish(reason, gained, run.moves, run.plan.skipped);
        return;
    end
    local source, destination = current.slots[nextStep.source], current.slots[nextStep.destination];
    if not source or not destination or source.work ~= nextStep.work or destination.work ~= nextStep.other then
        Finish("CHANGED"); return;
    end
    if not AT.CanSwap(source, destination, current) then Finish("REJECTED"); return; end
    Move(source, destination);
end

local function Update(delta)
    clock = clock + delta; elapsed = elapsed + delta;
    if elapsed < 0.2 then return; end
    elapsed = 0;
    -- Guard settlement can outlive a cancelled/failed plan. Never retry a
    -- network operation merely because its response has not arrived yet.
    if not UI.IsGameCoreBusy() and not (UI.IsResyncLoadInProgress and UI.IsResyncLoadInProgress()) then
        local ok, message = pcall(RefreshOutstanding);
        if not ok then print("[AutoTheme] Waiting for slot confirmation: " .. tostring(message)); end
    end
    local player, active = Game.GetLocalPlayer(), Active();
    if player ~= availabilityPlayer or active ~= availabilityActive then
        availabilityPlayer, availabilityActive = player, active;
        availabilityDirty = true; availabilityStatusDirty = true;
    end
    local shown = AttachToolbar();
    if run and not shown then run.cancel = true; end
    if shown and not wasShown then availabilityDirty = true; availabilityStatusDirty = true; end
    wasShown = shown;
    if availabilityTurn ~= Game.GetCurrentGameTurn() then availabilityDirty = true; end
    -- Repairs and other mods do not always emit a work-moved/building event.
    -- Poll only the visible idle panel; rerun the planner only when facts change.
    local polled;
    if shown and not run and not availabilityDirty and clock - availabilityPollClock >= 2 and not UI.IsGameCoreBusy() then
        availabilityPollClock = clock;
        local ok, current = pcall(AT.Collect);
        if ok then
            local signature = SnapshotSignature(current);
            if signature ~= availabilitySignature then
                availabilityDirty = true;
                availabilityStatusDirty = true;
                polled = current;
            end
        end
    end
    if shown and not run and availabilityDirty and clock - availabilityClock >= 0.5 and not UI.IsGameCoreBusy() then
        availabilityDirty = false; availabilityClock = clock;
        availabilityTurn = Game.GetCurrentGameTurn();
        local ok, snapshot, plan = pcall(function()
            local current = polled or AT.Collect();
            return current, AT.Plan(current);
        end);
        local available = ok and #plan.steps > 0;
        if ok then availabilitySignature = SnapshotSignature(snapshot); end
        if ok then Controls.ThemeCount:SetText(Text("THEMED_COUNT", snapshot.themed or 0)); end
        local reason, detail;
        if not Active() then reason = "WAIT_TURN";
        elseif PendingOperation() then reason = "WAIT_SYNC";
        elseif not ok then reason = "ERROR";
        elseif available then reason = "READY";
        else reason, detail = NoPlanReason(snapshot, plan); end
        Controls.ThemeButton:SetDisabled(not Active() or PendingOperation() ~= nil or not available);
        Controls.ThemeButton:SetToolTipString(Text("HELP") .. "[NEWLINE]" .. Text(reason, detail));
        if availabilityStatusDirty then
            Status(reason, detail);
            availabilityStatusDirty = false;
        end
    elseif run then Controls.ThemeButton:SetDisabled(false); end
    local ok, errorMessage = pcall(Step);
    if not ok then
        print("[AutoTheme] Stopped: " .. tostring(errorMessage));
        Finish("ERROR");
    end
end

Controls.ThemeButton:RegisterCallback(Mouse.eLClick, Begin);
Controls.ThemeIcon:SetIcon("ICON_BUILDING_MUSEUM_ART");
Controls.ThemeButton:SetToolTipString(Text("HELP"));
local function StartUpdates()
    ContextPtr:SetHide(false);
    ContextPtr:SetUpdate(Update);
end
local function OnLoadComplete()
    -- Reconnect/resync/read-load must never resume a plan from a former session.
    if run then Finish("SESSION_CHANGED"); end
    outstanding = {};
    availabilityDirty = true; availabilityStatusDirty = true;
    availabilitySignature = nil;
    StartUpdates();
end
local function OnPlayerChanged()
    if run then Finish("SESSION_CHANGED"); end
    availabilityDirty = true; availabilityStatusDirty = true;
    availabilitySignature = nil;
end
local function OnTurnEnd()
    if run then Finish("TURN_ENDED"); end
    availabilityDirty = true; availabilityStatusDirty = true;
end
ContextPtr:SetInitHandler(StartUpdates);
-- A newly created work is not a move. Invalidate the cached plan for changes
-- to works, slots, city scoring and turn ownership while the panel stays open.
local function MarkAvailabilityDirty()
    availabilityDirty = true;
    if not run then availabilityStatusDirty = true; end
end
local availabilityEvents = {
    Events.GreatWorkMoved, Events.GreatWorkCreated, Events.BuildingAddedToMap,
    Events.BuildingRemovedFromMap, Events.CityAddedToMap, Events.CityRemovedFromMap,
    Events.BuildingChanged, Events.DistrictPillaged, Events.DistrictDamageChanged,
    Events.CityFocusChanged, Events.LocalPlayerTurnBegin, Events.LocalPlayerTurnEnd
};
for _, event in pairs(availabilityEvents) do
    event.Add(MarkAvailabilityDirty);
end
Events.LoadScreenClose.Add(OnLoadComplete);
Events.LocalPlayerChanged.Add(OnPlayerChanged);
Events.LocalPlayerTurnEnd.Add(OnTurnEnd);
-- A player departure can lead to host migration/resync. Stop the local chain;
-- retain any submitted operation guard until the core confirms its outcome.
if Events.MultiplayerPrePlayerDisconnected then Events.MultiplayerPrePlayerDisconnected.Add(OnPlayerChanged); end
ContextPtr:SetShutdown(function()
    -- Reparented controls otherwise survive a context hot reload under the
    -- native header and can overlap the replacement toolbar's labels.
    Controls.ThemeTools:SetHide(true);
    Controls.ThemeTools:ChangeParent(Controls.UpdateAnchor);
    ContextPtr:ClearUpdate();
    Events.LoadScreenClose.Remove(OnLoadComplete);
    Events.LocalPlayerChanged.Remove(OnPlayerChanged);
    Events.LocalPlayerTurnEnd.Remove(OnTurnEnd);
    if Events.MultiplayerPrePlayerDisconnected then Events.MultiplayerPrePlayerDisconnected.Remove(OnPlayerChanged); end
    for _, event in pairs(availabilityEvents) do event.Remove(MarkAvailabilityDirty); end
end);
StartUpdates();
print("[AutoTheme] UI loaded (0.3.0-mp.1 native toolbar)");

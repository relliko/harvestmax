--[[
* harvestmax
*
* The Harvest Festival with the fun taken out. Phoenix's costumed townsfolk (Southern and
* Northern San d'Oria, Bastok, Windurst) take one sweet per trade, with a 5% chance of one of
* eight prizes. This window says exactly what to wear and what to trade for the whole set in the
* fewest sweets, what each reply meant, and how to get the festival's other rewards.
*
* How it works (see core.lua): wear nothing festive until you have all four plain pieces, then
* wear the pieces whose upgrades you lack. A stack is used up for one try. The whole set takes
* about 160 trades; Garlic Crackers (4 gil, Lower Jeuno) are the cheapest sweet.
*
* Nothing is ever sent to the server by this addon. Gear swaps go through the game's own /equip
* command (/harvestmax auto off to do them yourself); Target only moves your client's cursor.
--]]

addon.name    = 'harvestmax';
addon.author  = 'Relli';
addon.version = '0.3';
addon.desc    = 'Harvest Festival: what to wear and trade for every prize in the fewest sweets.';
addon.link    = 'https://github.com/relliko/harvestmax';

require('common');
local chat     = require('chat');
local imgui    = require('imgui');
local settings = require('settings');
local core     = require('core');

local defaults = T{
    visible = true,
    auto    = true,  -- swap festival gear with /equip when the plan says so
    always  = false, -- show the window outside the festival towns too
    day     = -1,    -- the Vana'diel day `used` belongs to
    used    = T{ },  -- sweet ids traded that day (no more costumes from them)
};

local st = {
    settings = nil,
    s        = nil,  -- what core.next_step reads, refreshed 4 times a second
    step     = nil,
    ready    = nil,  -- the step shown before the latest trade, to explain its reply
    at       = -1,
    treats   = nil,  -- [id] = count last refresh
    owned    = nil,  -- owned prizes last refresh
    last     = nil,  -- what the latest reply meant
    trades   = 0,    -- this session
    hits     = 0,
    wasted   = 0,
    equip_at = -10,
};

local GOOD = { 0.55, 0.90, 0.55, 1.0 };
local NONE = { 0.65, 0.65, 0.65, 1.0 };
local WARN = { 1.00, 0.55, 0.40, 1.0 };
local NEXT = { 1.00, 0.85, 0.40, 1.0 };

local EQUIP_BAGS = { [0] = true, [8] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [15] = true, [16] = true };
local SLOT = { main = 0, head = 4 };

local function line(color, text)
    imgui.TextColored(color, (text:gsub('%%', '%%%%')));
end

local function wrapped(color, text)
    imgui.PushTextWrapPos(imgui.GetCursorPosX() + 340);
    line(color, text);
    imgui.PopTextWrapPos();
end

local function msg(text)
    print(chat.header(addon.name):append(chat.message(text)));
end

local function worn(inv, slot)
    local e = inv:GetEquippedItem(slot);
    local index = e ~= nil and bit.band(e.Index or 0, 0xFF) or 0;
    if (index == 0) then
        return 0;
    end
    local it = inv:GetContainerItem(bit.rshift(bit.band(e.Index, 0xFF00), 8), index);
    return (it ~= nil and it.Id ~= 65535) and (it.Id or 0) or 0;
end

local TRACKED = { };
for _, id in ipairs(core.ALL) do TRACKED[id] = true; end
for _, x in ipairs(core.extras(0)) do TRACKED[x.id] = true; end

-- The sweets traded this Vana'diel day, emptied at Vana'diel midnight.
local function used_today()
    local day = core.vana_day(os.time());
    if (st.settings.day ~= day) then
        st.settings.day, st.settings.used = day, T{ };
        settings.save();
    end
    local set = { };
    for _, id in ipairs(st.settings.used) do set[id] = true; end
    return set;
end

-- Everything core.next_step needs, read from client memory.
local function read()
    local mm = AshitaCore:GetMemoryManager();
    local inv, party, ent = mm:GetInventory(), mm:GetParty(), mm:GetEntity();
    local s = { owned = { }, bag = { }, treats = { }, free = 0, head = 0, main = 0 };
    s.zone = party:GetMemberZone(0) or 0;
    for c = 0, 16 do
        -- Items sit in slots 1 to the bag's size; the count the client holds is that size + 1.
        local max = (inv:GetContainerCountMax(c) or 0) - 1;
        for i = 1, max do
            local it = inv:GetContainerItem(c, i);
            local id = it ~= nil and it.Id or 0;
            if (id == 0 or id == 65535) then
                if (c == 0) then s.free = s.free + 1; end
            else
                if (TRACKED[id]) then
                    s.owned[id] = true;
                    if (EQUIP_BAGS[c]) then s.bag[id] = true; end
                end
                if (c == 0 and core.TREATS[id] ~= nil) then
                    s.treats[id] = (s.treats[id] or 0) + math.max(1, it.Count or 1);
                end
            end
        end
    end
    s.head, s.main = worn(inv, SLOT.head), worn(inv, SLOT.main);
    local okn, nation = pcall(function () return mm:GetPlayer():GetNation(); end);
    s.nation = okn and nation or nil;

    local town = core.NPCS[s.zone] or { };
    local shop = core.COOKIE_SHOPS[s.zone];
    local me = party:GetMemberTargetIndex(0) or 0;
    s.status = me ~= 0 and ent:GetStatus(me) or 0;
    for i = 1, 0x3FF do
        if (bit.band(ent:GetRenderFlags0(i) or 0, 0x200) ~= 0) then
            local name = ent:GetName(i);
            if (name ~= nil and (town[name] or name == shop)) then
                local d = math.sqrt(ent:GetDistance(i) or 0);
                if (name == shop) then
                    s.shop = shop;
                end
                if (town[name] and (s.npc == nil or d < s.npc.dist)) then
                    s.npc = { name = name, dist = d, idx = i, costume = town[name] };
                end
            end
        end
    end
    return s;
end

-- Session counts: a trade is sweets going down beside a costumed townsperson.
local function count(s)
    local total = core.treat_count(s.treats);
    local traded = false;
    if (st.treats ~= nil and s.npc ~= nil and s.npc.dist < 8) then
        local gone, kinds = 0, { };
        for id, n in pairs(st.treats) do
            local now = s.treats[id] or 0;
            if (now < n) then
                gone = gone + n - now;
                kinds[#kinds + 1] = id;
            end
        end
        if (gone > 0) then
            traded = true;
            st.trades = st.trades + 1;
            if (gone > 1) then
                st.wasted = st.wasted + gone - 1;
                msg(('That trade used up %d sweets for one try. Trade them one at a time.'):format(gone));
            end
            local used = used_today();
            local list = st.settings.used;
            for _, id in ipairs(kinds) do
                if (not used[id]) then list[#list + 1] = id; end
            end
            settings.save();
        end
    end
    if (st.owned ~= nil) then
        for _, id in ipairs(core.ALL) do
            if (s.owned[id] and not st.owned[id]) then
                st.hits = st.hits + 1;
                msg(('Got %s: %d of 8.'):format(core.NAMES[id], core.collected(s.owned)));
            end
        end
    end
    st.treats, st.owned = s.treats, s.owned;
    return traded, total;
end

local function equip(gear)
    local cm = AshitaCore:GetChatManager();
    for _, slot in ipairs({ 'head', 'main' }) do
        local id = gear[slot];
        if (id == false) then
            cm:QueueCommand(1, ('/equip %s'):format(slot));
        elseif (id ~= nil) then
            cm:QueueCommand(1, ('/equip %s "%s"'):format(slot, core.NAMES[id]));
        end
    end
end

local function in_festival_town(s)
    return core.NPCS[s.zone] ~= nil;
end

local function refresh()
    local now = os.clock();
    if (now - st.at < 0.25 and now >= st.at) then
        return;
    end
    st.at = now;
    local ok, s = pcall(read);
    if (not ok or s == nil) then
        return;
    end
    local traded = count(s);
    st.s, st.step = s, core.next_step(s);
    if (not traded) then
        st.ready = st.step;
    end
    -- Swap only standing idle in a festival town: once per new plan, retried every 15 seconds.
    if (st.step.kind == 'gear' and st.settings.auto and in_festival_town(s) and s.status == 0) then
        local key = st.step.text;
        if (key ~= st.equip_key or now - st.equip_at > 15) then
            st.equip_key, st.equip_at = key, now;
            equip(st.step.gear);
        end
    end
end

local function draw_extras(s)
    if (not imgui.CollapsingHeader('Other festival rewards')) then
        return;
    end
    for _, x in ipairs(core.extras(s.zone, s.nation)) do
        local have = s.owned[x.id];
        line(have and GOOD or NEXT, ('%s %s'):format(have and '+' or '-', x.name));
        if (not have) then
            wrapped(NONE, x.how);
        end
    end
end

local function draw()
    local s, step = st.s, st.step;
    if (s == nil or not st.settings.visible or not (st.settings.always or in_festival_town(s))) then
        return;
    end
    imgui.SetNextWindowSize({ 370, -1 }, ImGuiCond_FirstUseEver);
    local open = { true };
    if (imgui.Begin('harvestmax', open, ImGuiWindowFlags_AlwaysAutoResize)) then
        local have = core.collected(s.owned);
        line(NEXT, step.text);
        if (step.why ~= nil) then
            wrapped(NONE, step.why);
        end
        if (step.kind == 'gear' and imgui.Button('Equip now')) then
            st.equip_at = os.clock();
            equip(step.gear);
        end
        if (step.kind == 'trade' and s.npc ~= nil) then
            if (imgui.Button(('Target %s'):format(s.npc.name))) then
                pcall(function () AshitaCore:GetMemoryManager():GetTarget():SetTarget(s.npc.idx, false); end);
            end
        end
        if (st.last ~= nil) then
            wrapped(st.last.kind == 'item' and GOOD or NONE, 'Last trade: ' .. st.last.text);
        end
        imgui.Separator();
        line(have == 8 and GOOD or NEXT, ('%d of 8 prizes'):format(have));
        for _, p in ipairs(core.PIECES) do
            line(s.owned[p.id] and GOOD or NONE, ('  %s %-16s'):format(s.owned[p.id] and '+' or '-', core.NAMES[p.id]));
            imgui.SameLine();
            line(s.owned[p.up] and GOOD or NONE, ('%s %s'):format(s.owned[p.up] and '+' or '-', core.NAMES[p.up]));
        end
        if (have < 8) then
            local mean, enough = core.trades_left(s.owned);
            local treats = core.treat_count(s.treats);
            imgui.Separator();
            line(NONE, ('Trades left: about %.0f; %d covers 9 runs in 10.'):format(mean, enough));
            line(treats >= enough and GOOD or NONE, ('Sweets on you: %d (%d gil of Garlic Crackers covers it).'):format(treats, enough * 4));
            if (s.free < 1) then
                line(WARN, 'Inventory full: free a slot before trading.');
            end
        end
        -- Costumes matter for the Pitchfork and the witch hats, not for prizes.
        local used, fresh = used_today(), { };
        for id in pairs(s.treats) do
            if (not used[id]) then fresh[#fresh + 1] = core.TREATS[id].name; end
        end
        table.sort(fresh);
        imgui.Separator();
        wrapped(NONE, ('Sweets that still give a costume today: %s. Resets in %d min.'):format(
            #fresh > 0 and table.concat(fresh, ', ') or 'none on you', math.ceil(core.to_midnight(os.time()) / 60)));
        if (s.npc ~= nil) then
            line(NONE, ('%s gives the %s costume.'):format(s.npc.name, s.npc.costume));
        end
        if (st.trades > 0) then
            line(NONE, ('This session: %d trades, %d prizes%s.'):format(st.trades, st.hits,
                st.wasted > 0 and (', %d sweets wasted in stacks'):format(st.wasted) or ''));
        end
        draw_extras(s);
        line(NONE, ('Auto equip %s (/harvestmax auto).'):format(st.settings.auto and 'on' or 'off'));
    end
    imgui.End();
    if (not open[1]) then
        st.settings.visible = false;
        settings.save();
    end
end

ashita.events.register('load', 'harvestmax_load', function ()
    st.settings = settings.load(defaults);
    settings.register('settings', 'harvestmax_settings', function (s)
        if (s ~= nil) then st.settings = s; end
    end);
end);

ashita.events.register('d3d_present', 'harvestmax_present', function ()
    if (st.settings == nil) then
        return;
    end
    refresh();
    draw();
end);

-- The townsperson's reply to a trade, explained in the window.
ashita.events.register('text_in', 'harvestmax_text', function (e)
    local s = st.s;
    if (s == nil or s.npc == nil or s.npc.dist > 8 or e.injected) then
        return;
    end
    local kind = core.classify(e.message or '');
    if (kind == nil) then
        return;
    end
    local now = os.clock();
    -- One trade can print two lines (costume, then its hint): keep the first.
    if (st.last ~= nil and now - st.last.at < 1.5) then
        return;
    end
    st.last = { kind = kind, at = now, text = core.explain(kind, st.ready) };
end);

ashita.events.register('command', 'harvestmax_command', function (e)
    local args = e.command:args();
    if (#args == 0 or (args[1] ~= '/harvestmax' and args[1] ~= '/hmax')) then
        return;
    end
    e.blocked = true;
    local sub = args[2];
    if (sub == 'auto') then
        st.settings.auto = args[3] == 'on' or (args[3] ~= 'off' and not st.settings.auto);
        msg(('Auto equip %s.'):format(st.settings.auto and 'on' or 'off'));
    elseif (sub == 'always') then
        st.settings.always = not st.settings.always;
        msg(st.settings.always and 'Window shown everywhere.' or 'Window shown in festival towns only.');
    elseif (sub == 'equip') then
        if (st.step ~= nil and st.step.kind == 'gear') then
            equip(st.step.gear);
        else
            msg('Your gear is already right for the next trade.');
        end
    elseif (sub == 'next') then
        if (st.step ~= nil) then msg(st.step.text); end
    else
        st.settings.visible = not st.settings.visible;
    end
    settings.save();
end);

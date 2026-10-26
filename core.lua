--[[
* harvestmax core: the Harvest Festival trade rules as Phoenix's server runs them
* (scripts/globals/harvest_festivals.lua, onHalloweenTrade), and what to do next.
*
* Per trade of one treat to a festival NPC:
*   - if your head or main hand is Pumpkin Head (II) or Trick Staff (II), the only possible item
*     is that piece's upgrade (Horror Head (II), Treat Staff (II)), checked head first, and none
*     at all if you already own the upgrades of what you wear
*   - otherwise it picks one of the four plain pieces at random, up to 4 times, until it finds one
*     you don't own (the table.remove there is a no-op on LuaJIT, so the draws repeat)
*   - you get that item 1 time in 3 (math.randomInt(1, 3) < 2), and only with a free inventory slot
*   - the whole trade is used up either way, so a stack of 12 cookies is 12 cookies gone for 1 try
* "Own" means anywhere: the server's hasItem looks in every bag, Mog Safe included.
--]]

local core = { };

core.PUMPKIN_HEAD    = 13916;
core.HORROR_HEAD     = 13917;
core.PUMPKIN_HEAD_II = 15176;
core.HORROR_HEAD_II  = 15177;
core.TRICK_STAFF     = 17565;
core.TREAT_STAFF     = 17566;
core.TRICK_STAFF_II  = 17587;
core.TREAT_STAFF_II  = 17588;

core.NAMES = {
    [13916] = 'Pumpkin Head',    [13917] = 'Horror Head',
    [15176] = 'Pumpkin Head II', [15177] = 'Horror Head II',
    [17565] = 'Trick Staff',     [17566] = 'Treat Staff',
    [17587] = 'Trick Staff II',  [17588] = 'Treat Staff II',
};

-- The four pieces a plain trade can give, each with its upgrade and slot (in the server's order).
core.PIECES = {
    { id = 13916, up = 13917, slot = 'head' },
    { id = 15176, up = 15177, slot = 'head' },
    { id = 17565, up = 17566, slot = 'main' },
    { id = 17587, up = 17588, slot = 'main' },
};

core.ALL = { 13916, 13917, 15176, 15177, 17565, 17566, 17587, 17588 };

-- Treats the NPCs take, with the cheapest NPC price Phoenix has for each (nil: none sold).
-- Lebkuchen House is left out: the server's list marks it "breaks".
core.TREATS = {
    [4394] = { name = 'Ginger Cookie',      price = 12 },
    [4397] = { name = 'Cinna-cookie',       price = 15 },
    [4510] = { name = 'Acorn Cookie',       price = 24 },
    [4495] = { name = 'Goblin Chocolate',   price = 35 },
    [5567] = { name = 'Dried Date',         price = 200 },
    [4406] = { name = 'Baked Apple',        price = 440 },
    [4393] = { name = 'Orange Kuchen',      price = 975 },
    [5718] = { name = 'Cream Puff',         price = 1300 },
    [5577] = { name = 'Sutlac',             price = 1500 },
    [5572] = { name = 'Irmik Helvasi',      price = 2075 },
    [5729] = { name = 'Bavarois',           price = 3360 },
    [4556] = { name = 'Icecap Rolanberry',  price = 5544 },
    [5646] = { name = 'Bloody Chocolate' },  [4496] = { name = 'Bubble Chocolate' },
    [4413] = { name = 'Apple Pie' },         [4488] = { name = "Jack-o'-Pie" },
    [4421] = { name = 'Melon Pie' },         [4563] = { name = 'Pamama Tart' },
    [4446] = { name = 'Pumpkin Pie' },       [4414] = { name = 'Rolanberry Pie' },
    [5745] = { name = 'Cherry Bavarois' },   [5653] = { name = 'Cherry Muffin' },
    [5655] = { name = 'Coffee Muffin' },     [5144] = { name = 'Crimson Jelly' },
    [5681] = { name = 'Cupid Chocolate' },   [5672] = { name = 'Dried Berry' },
    [5614] = { name = 'Konigskuchen' },      [5230] = { name = 'Love Chocolate' },
    [4502] = { name = 'Marron Glace' },      [5147] = { name = 'Snoll Gelato' },
    [4270] = { name = 'Sweet Rice Cake' },   [5645] = { name = 'Witch Nougat' },
    [5552] = { name = 'Black Pudding' },     [5550] = { name = 'Buche au Chocolat' },
    [5633] = { name = 'Chocolate Cake' },    [5542] = { name = 'Gateau aux Fraises' },
    [5625] = { name = 'Maple Cake' },        [5559] = { name = 'Mille Feuille' },
    [5557] = { name = 'Mont Blanc' },        [5629] = { name = 'Orange Cake' },
    [5631] = { name = 'Pumpkin Cake' },      [5627] = { name = 'Yogurt Cake' },
};

-- The NPCs that take treats, by zone id (names as the client shows them).
core.NPCS = {
    [230] = { 'Apairemant', 'Corua', 'Machielle', 'Phamelise', 'Pourette' },        -- Southern San d'Oria
    [231] = { 'Antonian', 'Attarena', 'Vichuel' },                                  -- Northern San d'Oria
    [234] = { 'Aulavia', 'Emaliveulaux', 'Faustin', 'Mille', 'Proud Beard' },       -- Bastok Mines
    [235] = { 'Olwyn' },                                                            -- Bastok Markets
    [238] = { 'Ahyeekih', 'Ensasa', 'Maqu Molpih', 'Ness Rugetomal', 'Upih Khachla' }, -- Windurst Waters
    [241] = { 'Millerovieunet', 'Nhobi Zalkia', 'Taraihi-Perunhi' },                -- Windurst Woods
};

-- Who sells Ginger Cookies for 12 gil, by zone: Valeriano is only out in the town of the nation
-- first in conquest (the addon checks he is there), Ness Rugetomal always is.
core.COOKIE_SHOPS = {
    [230] = 'Valeriano', [236] = 'Valeriano', [241] = 'Valeriano', [238] = 'Ness Rugetomal',
};

core.CHANCE = 1 / 3;

-- The item one trade would aim for, as the server picks it. Returns an item id and its chance,
-- or 0 and 0 when the trade can give nothing.
function core.target(owned, head, main)
    for _, p in ipairs(core.PIECES) do
        if (head == p.id or main == p.id) then
            -- The server's upgrade chain, in its order.
            if (head == core.PUMPKIN_HEAD and not owned[core.HORROR_HEAD]) then return core.HORROR_HEAD, core.CHANCE; end
            if (head == core.PUMPKIN_HEAD_II and not owned[core.HORROR_HEAD_II]) then return core.HORROR_HEAD_II, core.CHANCE; end
            if (main == core.TRICK_STAFF and not owned[core.TREAT_STAFF]) then return core.TREAT_STAFF, core.CHANCE; end
            if (main == core.TRICK_STAFF_II and not owned[core.TREAT_STAFF_II]) then return core.TREAT_STAFF_II, core.CHANCE; end
            return 0, 0;
        end
    end
    local missing = core.missing_plain(owned);
    if (missing == 0) then
        return 0, 0;
    end
    return 'plain', core.plain_chance(missing);
end

function core.missing_plain(owned)
    local n = 0;
    for _, p in ipairs(core.PIECES) do
        if (not owned[p.id]) then n = n + 1; end
    end
    return n;
end

-- Chance one plain trade gives a new piece with `missing` of the four still to get.
function core.plain_chance(missing)
    return core.CHANCE * (1 - ((4 - missing) / 4) ^ 4);
end

function core.collected(owned)
    local n = 0;
    for _, id in ipairs(core.ALL) do
        if (owned[id]) then n = n + 1; end
    end
    return n;
end

--[[
* The chance of each trade still ahead, in the order they come: the plain pieces first (no gear
* swaps while farming them), then one upgrade per piece.
--]]
function core.chances(owned)
    local list = { };
    for k = core.missing_plain(owned), 1, -1 do
        list[#list + 1] = core.plain_chance(k);
    end
    for _, p in ipairs(core.PIECES) do
        if (not owned[p.up]) then
            list[#list + 1] = core.CHANCE;
        end
    end
    return list;
end

--[[
* How many more trades the whole set takes: the expected number and the number that is enough
* `q` of the time (a sum of geometric waits, worked out exactly up to `cap` trades).
--]]
function core.trades_left(owned, q, cap)
    q, cap = q or 0.9, cap or 600;
    local list = core.chances(owned);
    local mean = 0;
    for _, p in ipairs(list) do mean = mean + 1 / p; end
    if (#list == 0) then
        return 0, 0;
    end
    -- dist[n] = chance the steps so far are done after exactly n trades.
    local dist = { [0] = 1 };
    for _, p in ipairs(list) do
        local nxt, run = { [0] = 0 }, 0;
        for n = 1, cap do
            -- Finishing this step at n: either the previous ones finished at n-1 and this trade
            -- hit, or this step was already waiting at n-1 and this trade hit.
            run = run * (1 - p) + (dist[n - 1] or 0);
            nxt[n] = run * p;
        end
        dist = nxt;
    end
    local sum = 0;
    for n = 1, cap do
        sum = sum + dist[n];
        if (sum >= q) then
            return mean, n;
        end
    end
    return mean, cap;
end

-- The cheapest treat in your inventory (known shop prices first), or nil.
function core.best_treat(treats)
    local best, best_price;
    for id, count in pairs(treats) do
        local t = core.TREATS[id];
        if (t ~= nil and count > 0) then
            local price = t.price or 1e9;
            if (best == nil or price < best_price or (price == best_price and id < best)) then
                best, best_price = id, price;
            end
        end
    end
    return best;
end

function core.treat_count(treats)
    local n = 0;
    for id, count in pairs(treats) do
        if (core.TREATS[id] ~= nil) then n = n + count; end
    end
    return n;
end

--[[
* What to wear for the next trade: { head = id or false, main = id or false }, where an id is the
* piece to put on and false means "take off the piece you wear". nil for a slot to leave alone.
* While any plain piece is missing nothing festive is worn; after that, the pieces still waiting
* for their upgrades.
--]]
function core.wanted_gear(owned, head, main)
    local is_piece = { };
    for _, p in ipairs(core.PIECES) do is_piece[p.id] = p; end
    local want = { };
    if (core.missing_plain(owned) > 0) then
        if (is_piece[head]) then want.head = false; end
        if (is_piece[main]) then want.main = false; end
        return want;
    end
    for _, slot in ipairs({ 'head', 'main' }) do
        local cur = slot == 'head' and head or main;
        local pick;
        for _, p in ipairs(core.PIECES) do
            if (p.slot == slot and owned[p.id] and not owned[p.up]) then pick = pick or p.id; end
        end
        if (pick ~= nil) then
            if (cur ~= pick and not (is_piece[cur] and not owned[is_piece[cur].up])) then
                want[slot] = pick;
            end
        elseif (is_piece[cur]) then
            want[slot] = false;
        end
    end
    return want;
end

--[[
* The next thing to do. `s` holds:
*   owned   [id] = true for each of the eight anywhere you have it
*   bag     [id] = true for those in a bag you can equip from
*   head, main   item ids worn (0 for none)
*   free    empty inventory slots
*   treats  [id] = count in your inventory
*   npc     { name, dist } for the nearest festival NPC, or nil
*   shop    name of a 12-gil cookie seller here, or nil
* Returns { kind, text, why, gear } with kind one of done, fetch, gear, free, buy, trade.
--]]
function core.next_step(s)
    local owned = s.owned;
    if (core.collected(owned) == #core.ALL) then
        return { kind = 'done', text = 'All eight pieces collected. Nothing left to trade for.' };
    end
    local want = core.wanted_gear(owned, s.head, s.main);
    for _, slot in ipairs({ 'head', 'main' }) do
        local id = want[slot];
        if (id and not s.bag[id]) then
            return { kind = 'fetch', text = ('Take %s out of storage.'):format(core.NAMES[id]),
                     why = 'It needs to be worn for its upgrade, and it is not in a bag you can equip from.' };
        end
    end
    if (want.head ~= nil or want.main ~= nil) then
        local parts = { };
        for _, slot in ipairs({ 'head', 'main' }) do
            local id = want[slot];
            if (id == false) then
                local cur = slot == 'head' and s.head or s.main;
                parts[#parts + 1] = ('take off %s'):format(core.NAMES[cur]);
            elseif (id ~= nil) then
                parts[#parts + 1] = ('wear %s'):format(core.NAMES[id]);
            end
        end
        local text = table.concat(parts, ', ');
        local why = core.missing_plain(owned) > 0
            and 'Wearing a festival piece turns every trade into an upgrade try; plain pieces first.'
            or 'Worn pieces are upgraded: 1 in 3 per trade.';
        return { kind = 'gear', text = text:sub(1, 1):upper() .. text:sub(2) .. '.', why = why, gear = want };
    end
    if (s.free < 1) then
        return { kind = 'free', text = 'Free one inventory slot.', why = 'With a full bag the treat is used up and nothing is given.' };
    end
    local treat = core.best_treat(s.treats);
    if (treat == nil) then
        local _, enough = core.trades_left(owned);
        local where = s.shop ~= nil and ('%s sells Ginger Cookies for 12 gil here'):format(s.shop)
            or 'Ginger Cookies: Valeriano (town of the nation first in conquest) or Ness Rugetomal (Windurst Waters), 12 gil; or the AH';
        return { kind = 'buy', text = ('Buy about %d treats.'):format(enough), why = where .. '.' };
    end
    local aim, chance = core.target(owned, s.head, s.main);
    local npc = s.npc ~= nil and ('%s (%.0f yalms)'):format(s.npc.name, s.npc.dist) or 'a festival NPC';
    local what = aim == 'plain' and 'a new piece' or core.NAMES[aim];
    return {
        kind = 'trade',
        text = ('Trade ONE %s to %s.'):format(core.TREATS[treat].name, npc),
        why = ('1 in %.1f for %s. A whole stack is used up for a single try.'):format(1 / chance, what),
        treat = treat,
    };
end

return core;

--[[
* harvestmax core: the Harvest Festival trade rules as Phoenix runs them, and what to do next.
*
* The rules come from Phoenix's wiki page (wiki.phoenix-xi.com/Harvest_Festival, generated from
* "Phoenix game beta 136ed7307def"). That event code is not in the public Phoenix repo, whose
* scripts/globals/harvest_festivals.lua is an older 1-in-3 version the live server doesn't run.
*
* Per trade of one sweet to a costumed townsperson:
*   - 5% chance of a prize you don't own yet: one of the four plain pieces, or, while you wear a
*     piece, its upgrade instead (the wiki gives no separate upgrade chance; 5% is assumed)
*   - otherwise a costume, but each kind of sweet gives a costume only once per Vana'diel day;
*     after that the same kind only gets a "Thank you..." and the sweet is gone
*   - the whole trade is used up either way, so trade one sweet at a time
* "Own" means anywhere: prizes you keep in storage still count as owned.
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

-- The four plain prizes, each with its upgrade and slot.
core.PIECES = {
    { id = 13916, up = 13917, slot = 'head' },
    { id = 15176, up = 15177, slot = 'head' },
    { id = 17565, up = 17566, slot = 'main' },
    { id = 17587, up = 17588, slot = 'main' },
};

core.ALL = { 13916, 13917, 15176, 15177, 17565, 17566, 17587, 17588 };

core.PRIZE = 0.05;

-- The sweets the townsfolk take (the wiki's list), with the cheapest NPC price in Phoenix's shops
-- and who sells it (nil: no NPC sells it).
core.TREATS = {
    [4467] = { name = 'Garlic Cracker',    price = 4,    shop = 'Ghebi Damomohe, Lower Jeuno' },
    [4394] = { name = 'Ginger Cookie',     price = 12,   shop = 'Ness Rugetomal, Windurst Waters; Valeriano' },
    [4397] = { name = 'Cinna-cookie',      price = 15,   shop = 'Ness Rugetomal, Windurst Waters' },
    [4510] = { name = 'Acorn Cookie',      price = 24,   shop = 'Ness Rugetomal, Windurst Waters' },
    [4495] = { name = 'Goblin Chocolate',  price = 35,   shop = 'Pawkrix, Lower Jeuno' },
    [5567] = { name = 'Dried Date',        price = 200,  shop = 'Khaf Jhifanm, Aht Urhgan Whitegate' },
    [4406] = { name = 'Baked Apple',       price = 440,  shop = 'Glyke, Upper Jeuno' },
    [4539] = { name = 'Goblin Pie',        price = 650,  shop = 'Pawkrix, Lower Jeuno' },
    [4393] = { name = 'Orange Kuchen',     price = 975,  shop = 'Taajiji, Windurst Waters' },
    [5577] = { name = 'Sutlac',            price = 1500, shop = 'Yafaaf, Aht Urhgan Whitegate' },
    [5572] = { name = 'Irmik Helvasi',     price = 2075, shop = 'Fayeewah, Aht Urhgan Whitegate' },
    [4556] = { name = 'Icecap Rolanberry', price = 5544, shop = 'Yoskolo, Lower Jeuno' },
    [4413] = { name = 'Apple Pie' },         [4320] = { name = 'Apple Pie +1' },
    [4496] = { name = 'Bubble Chocolate' },  [4269] = { name = 'Bijou Glace' },
    [5552] = { name = 'Black Pudding' },     [4520] = { name = 'Coin Cookie' },
    [5144] = { name = 'Crimson Jelly' },     [5574] = { name = 'Dried Date +1' },
    [5553] = { name = 'Dusky Indulgence' },  [5555] = { name = 'Flurry Courante' },
    [4280] = { name = 'Garlic Cracker +1' }, [5542] = { name = 'Gateau aux Fraises' },
    [4497] = { name = 'Heart Chocolate' },   [4324] = { name = 'Hobgoblin Chocolate' },
    [4325] = { name = 'Hobgoblin Pie' },     [5573] = { name = 'Irmik Helvasi +1' },
    [5614] = { name = 'Konigskuchen' },      [4502] = { name = 'Marron Glace' },
    [4421] = { name = 'Melon Pie' },         [4523] = { name = 'Melon Pie +1' },
    [5543] = { name = 'Midwinter Dream' },   [4287] = { name = 'Opo-opo Tart' },
    [4332] = { name = 'Orange Kuchen +1' },  [4563] = { name = 'Pamama Tart' },
    [4446] = { name = 'Pumpkin Pie' },       [4525] = { name = 'Pumpkin Pie +1' },
    [4281] = { name = 'Red Hot Cracker' },   [4339] = { name = 'Rolanberry Pie +1' },
    [4414] = { name = 'Rolanberry Pie' },    [5147] = { name = 'Snoll Gelato' },
    [4594] = { name = 'Snowy Rolanberry' },  [4466] = { name = 'Spicy Cracker' },
    [5554] = { name = "Squirrel's Delight" }, [5578] = { name = 'Sutlac +1' },
    [4336] = { name = 'Sweet Baked Apple' }, [4270] = { name = 'Sweet Rice Cake' },
    [5615] = { name = 'Uberkuchen' },        [5158] = { name = 'Vermillion Jelly' },
    [4577] = { name = 'Wild Cookie' },       [4576] = { name = 'Wizard Cookie' },
};

-- The costumed townsfolk by zone id, with the costume each gives (names as the client shows them).
core.NPCS = {
    [230] = { -- Southern San d'Oria
        ['Apairemant'] = 'Shadow', ['Aveline'] = 'Orc', ['Benaige'] = 'Hound', ['Corua'] = 'Skeleton',
        ['Kueh Igunahmori'] = 'Ghost', ['Lotte'] = 'Quadav', ['Lusiane'] = 'Yagudo', ['Machielle'] = 'Yagudo',
        ['Malecharisant'] = 'Shadow', ['Ostalie'] = 'Skeleton', ['Paunelie'] = 'Hound', ['Phamelise'] = 'Ghost',
        ['Pourette'] = 'Orc',
    },
    [231] = { -- Northern San d'Oria
        ['Antonian'] = 'Hound', ['Attarena'] = 'Orc', ['Justi'] = 'Yagudo', ['Palguevion'] = 'Shadow',
        ['Pirvidiauce'] = 'Skeleton', ['Tavourine'] = 'Quadav', ['Vichuel'] = 'Ghost',
        ['Trick Bones'] = 'Quadav', ['Trick Ghast'] = 'Yagudo', ['Trick Ghost'] = 'Skeleton',
        ['Trick Phantom'] = 'Shadow', ['Trick Shade'] = 'Yagudo', ['Trick Shadow'] = 'Orc',
        ['Trick Skeleton'] = 'Hound', ['Trick Specter'] = 'Quadav', ['Trick Spirit'] = 'Ghost',
        ['Trick Wight'] = 'Orc',
    },
    [234] = { -- Bastok Mines
        ['Aulavia'] = 'Ghost', ['Deegis'] = 'Orc', ['Emaliveulaux'] = 'Skeleton', ['Faustin'] = 'Hound',
        ['Galdeo'] = 'Skeleton', ['Griselda'] = 'Ghost', ['Maymunah'] = 'Quadav', ['Mille'] = 'Quadav',
        ['Neigepance'] = 'Shadow', ['Odoba'] = 'Yagudo', ['Proud Beard'] = 'Shadow', ['Tibelda'] = 'Yagudo',
    },
    [235] = { -- Bastok Markets
        ['Belizieg'] = 'Orc', ['Carmelide'] = 'Hound', ['Charging Chocobo'] = 'Skeleton', ['Ciqala'] = 'Quadav',
        ['Harmodios'] = 'Shadow', ['Olwyn'] = 'Ghost', ['Peritrage'] = 'Yagudo', ['Visala'] = 'Hound',
        ['Trick Bones'] = 'Ghost', ['Trick Ghast'] = 'Shadow', ['Trick Ghost'] = 'Hound',
        ['Trick Phantom'] = 'Quadav', ['Trick Shade'] = 'Shadow', ['Trick Shadow'] = 'Skeleton',
        ['Trick Skeleton'] = 'Yagudo', ['Trick Specter'] = 'Ghost', ['Trick Spirit'] = 'Orc',
        ['Trick Wight'] = 'Skeleton',
    },
    [238] = { -- Windurst Waters
        ['Ahyeekih'] = 'Shadow', ['Ensasa'] = 'Skeleton', ['Hilkomu-Makimu'] = 'Yagudo', ['Maqu Molpih'] = 'Orc',
        ['Ness Rugetomal'] = 'Hound', ['Orez-Ebrez'] = 'Orc', ['Shohrun-Tuhrun'] = 'Quadav', ['Upih Khachla'] = 'Ghost',
        ['Trick Bones'] = 'Orc', ['Trick Ghast'] = 'Quadav', ['Trick Ghost'] = 'Yagudo',
        ['Trick Phantom'] = 'Ghost', ['Trick Shade'] = 'Quadav', ['Trick Shadow'] = 'Hound',
        ['Trick Skeleton'] = 'Shadow', ['Trick Specter'] = 'Orc', ['Trick Spirit'] = 'Skeleton',
        ['Trick Wight'] = 'Hound',
    },
    [241] = { -- Windurst Woods
        ['Bin Stejihna'] = 'Skeleton', ['Kuzah Hpirohpon'] = 'Yagudo', ['Meriri'] = 'Quadav',
        ['Millerovieunet'] = 'Orc', ['Mono Nchaa'] = 'Hound', ['Nhobi Zalkia'] = 'Shadow',
        ['Nya Labiccio'] = 'Yagudo', ['Quesse'] = 'Shadow', ['Retto-Marutto'] = 'Ghost',
        ['Shih Tayuun'] = 'Skeleton', ['Taraihi-Perunhi'] = 'Ghost', ['Wije Tiren'] = 'Quadav',
    },
};

-- Each town's Pitchfork costume pair and decoration square.
core.PITCHFORK = {
    [230] = { 'Ghost', 'Skeleton', 'L-7' },
    [231] = { 'Hound', 'Shadow', 'E-6' },
    [234] = { 'Shadow', 'Skeleton', 'H-7' },
    [235] = { 'Ghost', 'Hound', 'J-10' },
    [238] = { 'Hound', 'Skeleton', 'E-9 (north map)' },
    [241] = { 'Shadow', 'Ghost', 'G-9' },
};

-- The festival's other rewards, each with how to get it.
core.EXTRAS = {
    { id = 16075, name = 'Witch Hat', how = 'Wake of the Lilies: talk to Gertrude (Northern San d\'Oria D-8) out of costume, get a costume, then tail Poseaulloie (J-8/J-9) within 10 yalms without being in front of her within 6, for 10 progress messages. Take the costume off and report back before Vana\'diel midnight.' },
    { id = 16076, name = 'Coven Hat', how = 'On a later Vana\'diel day, talk to Gertrude wearing the Witch Hat and tail the warier witch Maryse (E-6/F-6/F-7): she sees 9 yalms and turns more.' },
    { id = 18102, name = 'Pitchfork', how = 'Party of exactly two: get your town\'s costume pair, one each, and both stand within 5 yalms of its Pitchfork decoration.' },
    { id = 18103, name = 'Pitchfork +1', how = 'Same two, in another nation\'s city: each equips the Pitchfork and trades a sweet not used today to a townsperson that gives goblin costumes to their own nation\'s citizens, then both stand by that town\'s Pitchfork +1 decoration (Southern San d\'Oria E-7, Northern D-9).' },
};

-- Who sells 12-gil Ginger Cookies in a festival town: Valeriano only in the town of the nation
-- first in conquest (the addon checks he is there), Ness Rugetomal always.
core.COOKIE_SHOPS = {
    [230] = 'Valeriano', [236] = 'Valeriano', [241] = 'Valeriano', [238] = 'Ness Rugetomal',
};

-- The server's Vana'diel day number: days run 3456 Earth seconds from its epoch (1009810800),
-- which is a Vana'diel midnight. Costumes reset when this changes.
function core.vana_day(unix)
    return math.floor((unix - 1009810800) / 3456);
end

-- Seconds until the next Vana'diel midnight.
function core.to_midnight(unix)
    return 3456 - (unix - 1009810800) % 3456;
end

-- What the NPC's reply to a trade means, checked in this order ("Thank you..." starts the
-- costume line too).
core.REPLIES = {
    { find = 'Here, take this',         kind = 'item' },
    { find = 'And now for your treat',  kind = 'costume' },
    { find = 'unexpected might happen', kind = 'costume' },
    { find = 'Thank you...',            kind = 'nothing' },
};

function core.classify(text)
    for _, r in ipairs(core.REPLIES) do
        if (text:find(r.find, 1, true)) then
            return r.kind;
        end
    end
    return nil;
end

local function cap(s)
    return s:sub(1, 1):upper() .. s:sub(2);
end

--[[
* One line on what a reply meant, given the step the window showed just before the trade.
--]]
function core.explain(kind, before)
    if (kind == 'item') then
        return '"Here, take this...": the 5% prize roll hit.';
    end
    local what = kind == 'costume' and 'a costume, no prize' or 'nothing';
    if (before ~= nil and before.kind == 'gear') then
        return ('%s: your gear was wrong for this trade (%s).'):format(cap(what), before.text:lower():gsub('%.$', ''));
    end
    if (kind == 'costume') then
        return 'Costume: the 5% prize roll missed. That kind of sweet gives no more costumes today.';
    end
    return '"Thank you...": the 5% prize roll missed, and that kind of sweet already gave a costume today. Normal: keep going.';
end

function core.missing_plain(owned)
    local n = 0;
    for _, p in ipairs(core.PIECES) do
        if (not owned[p.id]) then n = n + 1; end
    end
    return n;
end

function core.collected(owned)
    local n = 0;
    for _, id in ipairs(core.ALL) do
        if (owned[id]) then n = n + 1; end
    end
    return n;
end

-- The prize one trade aims for: an upgrade id, 'plain', or 0 for none; and its chance.
function core.target(owned, head, main)
    for _, p in ipairs(core.PIECES) do
        if ((p.slot == 'head' and head == p.id) or (p.slot == 'main' and main == p.id)) and not owned[p.up] then
            return p.up, core.PRIZE;
        end
    end
    if (core.missing_plain(owned) > 0) then
        return 'plain', core.PRIZE;
    end
    return 0, 0;
end

-- The chance of each prize still ahead: one per missing piece.
function core.chances(owned)
    local list = { };
    for _ = 1, #core.ALL - core.collected(owned) do
        list[#list + 1] = core.PRIZE;
    end
    return list;
end

--[[
* How many more trades the whole set takes: the expected number and the number that is enough
* `q` of the time (a sum of geometric waits, worked out exactly up to `cap` trades).
--]]
function core.trades_left(owned, q, cap_n)
    q, cap_n = q or 0.9, cap_n or 2000;
    local list = core.chances(owned);
    if (#list == 0) then
        return 0, 0;
    end
    local mean = 0;
    for _, p in ipairs(list) do mean = mean + 1 / p; end
    -- dist[n] = chance the prizes so far are all in after exactly n trades.
    local dist = { [0] = 1 };
    for _, p in ipairs(list) do
        local nxt, run = { [0] = 0 }, 0;
        for n = 1, cap_n do
            run = run * (1 - p) + (dist[n - 1] or 0);
            nxt[n] = run * p;
        end
        dist = nxt;
    end
    local sum = 0;
    for n = 1, cap_n do
        sum = sum + dist[n];
        if (sum >= q) then
            return mean, n;
        end
    end
    return mean, cap_n;
end

-- The cheapest sweet in your inventory (known shop prices first), or nil.
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
* While any plain piece is missing nothing festive is worn (no swaps after each prize); after
* that, the pieces still waiting for their upgrades. A worn piece whose upgrade you own comes off,
* since the wiki doesn't say what a trade gives then.
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
*   npc     { name, dist } for the nearest costumed townsperson, or nil
*   shop    name of a 12-gil cookie seller here, or nil
* Returns { kind, text, why, gear } with kind one of done, fetch, gear, free, buy, trade.
--]]
function core.next_step(s)
    local owned = s.owned;
    if (core.collected(owned) == #core.ALL) then
        return { kind = 'done', text = 'All eight prizes collected. Nothing left to trade for.' };
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
        local why = core.missing_plain(owned) > 0
            and 'A worn piece turns the prize into its upgrade; plain pieces first, so no swaps after each prize.'
            or 'Worn pieces win their upgrades.';
        return { kind = 'gear', text = cap(table.concat(parts, ', ')) .. '.', why = why, gear = want };
    end
    if (s.free < 1) then
        return { kind = 'free', text = 'Free one inventory slot.', why = 'A prize needs somewhere to go.' };
    end
    local treat = core.best_treat(s.treats);
    if (treat == nil) then
        local _, enough = core.trades_left(owned);
        local where = 'Cheapest: Garlic Crackers, 4 gil from Ghebi Damomohe (Lower Jeuno)';
        if (s.shop ~= nil) then
            where = ('%s sells Ginger Cookies for 12 gil here. %s'):format(s.shop, where);
        end
        return { kind = 'buy', text = ('Buy about %d sweets.'):format(enough), why = where .. '.' };
    end
    local aim, chance = core.target(owned, s.head, s.main);
    local npc = s.npc ~= nil and ('%s (%.0f yalms)'):format(s.npc.name, s.npc.dist) or 'a costumed townsperson';
    local what = aim == 'plain' and 'a new piece' or core.NAMES[aim];
    return {
        kind = 'trade',
        text = ('Trade ONE %s to %s.'):format(core.TREATS[treat].name, npc),
        why = ('%.0f%% for %s. A whole stack is used up for a single try.'):format(chance * 100, what),
        treat = treat,
    };
end

return core;

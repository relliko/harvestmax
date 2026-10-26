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

core.TOWNS = {
    [230] = "Southern San d'Oria", [231] = "Northern San d'Oria", [234] = 'Bastok Mines',
    [235] = 'Bastok Markets', [238] = 'Windurst Waters', [241] = 'Windurst Woods',
};

-- Which nation each town belongs to (the game's nation numbers: 0 San d'Oria, 1 Bastok, 2 Windurst).
core.TOWN_NATION = { [230] = 0, [231] = 0, [234] = 1, [235] = 1, [238] = 2, [241] = 2 };
core.NATIONS = { [0] = "San d'Oria", [1] = 'Bastok', [2] = 'Windurst' };

-- Each town's Pitchfork costume pair and decoration square, and its Pitchfork +1 decoration.
core.PITCHFORK = {
    [230] = { 'Ghost', 'Skeleton', 'L-7', 'E-7' },
    [231] = { 'Hound', 'Shadow', 'E-6', 'D-9' },
    [234] = { 'Shadow', 'Skeleton', 'H-7', 'E-8' },
    [235] = { 'Ghost', 'Hound', 'J-10', 'G-4' },
    [238] = { 'Hound', 'Skeleton', 'E-9 (north map)', 'K-6 (north map)' },
    [241] = { 'Shadow', 'Ghost', 'G-9', 'I-6' },
};

-- Townsfolk who give a goblin costume, instead of their own, to a citizen of `nation` holding a
-- Pitchfork: [zone][name] = nation.
core.GOBLIN = {
    [230] = { ['Aveline'] = 0, ['Lotte'] = 1, ['Lusiane'] = 2, ['Machielle'] = 2 },
    [231] = { ['Antonian'] = 0, ['Attarena'] = 0, ['Justi'] = 2, ['Tavourine'] = 1, ['Trick Bones'] = 1,
              ['Trick Ghast'] = 2, ['Trick Shade'] = 2, ['Trick Wight'] = 0 },
    [234] = { ['Deegis'] = 0, ['Maymunah'] = 1, ['Mille'] = 1, ['Tibelda'] = 2 },
    [235] = { ['Belizieg'] = 0, ['Ciqala'] = 1, ['Peritrage'] = 2, ['Trick Phantom'] = 1,
              ['Trick Skeleton'] = 2, ['Trick Spirit'] = 0 },
    [238] = { ['Hilkomu-Makimu'] = 2, ['Maqu Molpih'] = 0, ['Shohrun-Tuhrun'] = 1, ['Trick Bones'] = 0,
              ['Trick Ghast'] = 1, ['Trick Ghost'] = 2, ['Trick Shade'] = 1, ['Trick Specter'] = 0 },
    [241] = { ['Meriri'] = 1, ['Millerovieunet'] = 0, ['Nya Labiccio'] = 2, ['Wije Tiren'] = 1 },
};

-- Wake of the Lilies, by the zone its exorcist stands in: exorcist, witch, warier witch.
core.LILIES = {
    [231] = { 'Gertrude (D-8)', 'Poseaulloie (J-8, J-9)', 'Maryse (E-6, F-6, F-7)' },
    [235] = { 'Brian (G-9)', 'Selma (H-8, H-9)', 'Pretty Heart (F-7, G-7, G-8)' },
    [238] = { 'Roger (F-5, north map)', 'Bikho Ronpotteh (F-8, G-8, north map)', 'Guwanana (H-7, I-6, south map)' },
};

-- The exorcist nearest a town: its own, else its nation's.
local LILIES_FOR = { [230] = 231, [231] = 231, [234] = 235, [235] = 235, [238] = 238, [241] = 238 };

-- Who in `zone` gives `costume`: "Kueh Igunahmori, Phamelise".
function core.givers(zone, costume)
    local names = { };
    for name, c in pairs(core.NPCS[zone] or { }) do
        if (c == costume) then names[#names + 1] = name; end
    end
    table.sort(names);
    return table.concat(names, ', ');
end

-- Who in `zone` gives a goblin costume to a Pitchfork-holding citizen of `nation`.
function core.goblin_givers(zone, nation)
    local names = { };
    for name, n in pairs(core.GOBLIN[zone] or { }) do
        if (n == nation) then names[#names + 1] = name; end
    end
    table.sort(names);
    return table.concat(names, ', ');
end

--[[
* The festival's other rewards, each with how to get it, told for the town you're in (`zone`) and
* your nation (`nation`, nil when unknown): { id, name, how }.
--]]
function core.extras(zone, nation)
    local town = core.TOWNS[zone] or 'a festival town';
    local lz = LILIES_FOR[zone] or 231;
    local exorcist, witch, warier = core.LILIES[lz][1], core.LILIES[lz][2], core.LILIES[lz][3];
    local where = lz == zone and '' or (' in %s'):format(core.TOWNS[lz]);
    local list = {
        { id = 16075, name = 'Witch Hat',
          how = ('Wake of the Lilies: talk to %s%s out of costume, get a costume, then tail %s within 10 yalms without being in front of her within 6, for 10 progress messages. Take the costume off and report back before Vana\'diel midnight.'):format(exorcist, where, witch) },
        { id = 16076, name = 'Coven Hat',
          how = ('On a later Vana\'diel day, talk to %s%s wearing the Witch Hat and tail the warier witch %s: she sees 9 yalms and turns more.'):format(exorcist, where, warier) },
    };
    local fork = core.PITCHFORK[zone];
    local how = 'Party of exactly two: get the town\'s costume pair, one each, and both stand within 5 yalms of its Pitchfork decoration.';
    if (fork ~= nil) then
        how = how .. (' In %s: %s (%s) and %s (%s), decoration at %s.'):format(town,
            fork[1], core.givers(zone, fork[1]), fork[2], core.givers(zone, fork[2]), fork[3]);
    end
    list[#list + 1] = { id = 18102, name = 'Pitchfork', how = how };
    how = 'The same two, in another nation\'s city than where you got the Pitchforks: each equips their Pitchfork and trades a sweet not used today to a townsperson who gives their own nation\'s citizens a goblin costume, then both stand within 5 yalms of that town\'s Pitchfork +1 decoration.';
    if (fork ~= nil) then
        local who;
        if (nation ~= nil and core.NATIONS[nation] ~= nil) then
            who = ('%s citizens: %s'):format(core.NATIONS[nation], core.goblin_givers(zone, nation));
        else
            local parts = { };
            for n = 0, 2 do
                parts[#parts + 1] = ('%s: %s'):format(core.NATIONS[n], core.goblin_givers(zone, n));
            end
            who = table.concat(parts, '; ');
        end
        how = how .. (' In %s (not for Pitchforks won in %s): %s; decoration at %s.'):format(town,
            core.NATIONS[core.TOWN_NATION[zone]], who, fork[4]);
    end
    list[#list + 1] = { id = 18103, name = 'Pitchfork +1', how = how };
    return list;
end

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

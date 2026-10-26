"""Tests for harvestmax, run under LuaJIT via lupa.

    python tests/run.py

The server side is Phoenix's own scripts/globals/harvest_festivals.lua (C:/code/Phoenix), loaded
against a stub player, so the addon's rules are checked against the code the server runs.
"""
import os
import unittest

from lupa import luajit21

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)
PHOENIX = os.environ.get('PHOENIX', r'C:/code/Phoenix')
FESTIVAL = os.path.join(PHOENIX, 'scripts', 'globals', 'harvest_festivals.lua').replace('\\', '/')

SERVER = r"""
xi = { settings = { main = { HALLOWEEN_2005 = 1, HALLOWEEN_YEAR_ROUND = 0 } },
       slot = { HEAD = 4, MAIN = 0 }, effect = { COSTUME = 127 }, zoneMisc = { COSTUME = 1 },
       item = { HORROR_HEAD = 13917, HORROR_HEAD_II = 15177, TREAT_STAFF = 17566, TREAT_STAFF_II = 17588 } }
function JstMonth() return 10 end
function JstDayOfTheMonth() return 25 end
zones = { [230] = { text = { HERE_TAKE_THIS = 1, ITEM_OBTAINED = 2, IF_YOU_WEAR_THIS = 3, THANK_YOU_TREAT = 4, THANK_YOU = 5 } } }
utils = { mask = {
    getBit = function (m, b) return bit.band(m, bit.lshift(1, b)) ~= 0 end,
    setBit = function (m, b, v) return v and bit.bor(m, bit.lshift(1, b)) or bit.band(m, bit.bnot(bit.lshift(1, b))) end,
} }
math.randomInt = function (a, b) return math.random(a, b) end
dofile(FESTIVAL)

-- A stub player: owned items, worn head/main, free slots; trade() runs one trade of `item`.
function make_player(owned, head, main, free)
    local p = { owned = owned, head = head, main = main, free = free, vars = { }, got = nil, used = false }
    function p:getZoneName() return 'Southern_San_dOria' end
    function p:getZoneID() return 230 end
    function p:getEquipID(slot) return slot == 4 and self.head or self.main end
    function p:hasItem(id) return self.owned[id] == true end
    function p:getFreeSlotsCount() return self.free end
    function p:messageSpecial() end
    function p:addItem(id) self.owned[id] = true; self.got = id end
    function p:getCharVar(n) return self.vars[n] or 0 end
    function p:setCharVar(n, v) self.vars[n] = v end
    function p:canUseMisc() return true end
    function p:addStatusEffect() end
    function p:tradeComplete() self.used = true end
    return p
end
function trade(p, item)
    p.got = nil
    xi.events.harvestFestival.onHalloweenTrade(p, { getItemId = function () return item end }, { })
    return p.got
end
"""

GINGER = 4394
ALL = [13916, 13917, 15176, 15177, 17565, 17566, 17587, 17588]
HEADS = [0, 13916, 15176, 13917, 15177]
MAINS = [0, 17565, 17587, 17566, 17588]


def lua_env():
    lua = luajit21.LuaRuntime()
    lua.execute(f"package.path = [[{ADDON}]] .. '/?.lua;' .. package.path")
    lua.globals().FESTIVAL = FESTIVAL
    lua.execute(SERVER)
    lua.execute("core = require('core')")
    return lua


class Rules(unittest.TestCase):
    """core.target against the server's choice for every owned set and outfit."""

    @classmethod
    def setUpClass(cls):
        cls.lua = lua_env()
        cls.lua.execute(r"""
        -- Forces the 1-in-3 roll to hit, so the server shows which item it aimed for.
        function aim(owned, head, main)
            local real = math.randomInt
            math.randomInt = function (a, b) if a == 1 and b == 3 then return 1 end return real(a, b) end
            local p = make_player(owned, head, main, 10)
            local got = trade(p, 4394)
            math.randomInt = real
            return got or 0
        end
        """)

    def owned(self, mask):
        return self.lua.table_from({ALL[i]: True for i in range(8) if mask >> i & 1})

    def test_every_state(self):
        g = self.lua.globals()
        checked = 0
        for mask in range(256):
            for head in HEADS:
                for main in MAINS:
                    owned = self.owned(mask)
                    want, chance = g.core.target(owned, head, main)
                    if want == 'plain':
                        # Random among the missing plain pieces: every result must be one of them.
                        for _ in range(8):
                            got = g.aim(self.owned(mask), head, main)
                            self.assertTrue(got == 0 or (got in (13916, 15176, 17565, 17587) and not owned[got]))
                    else:
                        got = g.aim(self.owned(mask), head, main)
                        self.assertEqual(got, want, f'mask={mask:08b} head={head} main={main}')
                        self.assertEqual(chance > 0, want != 0)
                    checked += 1
        self.assertEqual(checked, 256 * 25)

    def test_plain_chance(self):
        # Measured against the server with its real randomness.
        g = self.lua.globals()
        for owned_plain in range(4):
            mask = sum(1 << [0, 2, 4, 6][i] for i in range(owned_plain))
            self.lua.execute('math.randomseed(7)')
            n = 30000
            hits = self.lua.execute(f"""
                local n, hits = {n}, 0
                for _ = 1, n do
                    local owned = {{ }}
                    for i, id in ipairs({{13916, 15176, 17565, 17587}}) do if i <= {owned_plain} then owned[id] = true end end
                    if trade(make_player(owned, 0, 0, 10), 4394) then hits = hits + 1 end
                end
                return hits
            """)
            expect = g.core.plain_chance(4 - owned_plain)
            self.assertAlmostEqual(hits / n, expect, delta=0.012, msg=f'{owned_plain} owned')

    def test_full_bag_and_stack(self):
        g = self.lua.globals()
        self.lua.execute(r"""
            real = math.randomInt
            math.randomInt = function (a, b) if a == 1 and b == 3 then return 1 end return real(a, b) end
        """)
        p = g.make_player(self.lua.table(), 0, 0, 0)
        self.assertIsNone(g.trade(p, GINGER))
        self.assertTrue(p.used, 'the treat goes even with a full bag')
        self.lua.execute('math.randomInt = real')


class Plan(unittest.TestCase):
    """Following next_step from nothing to all eight, with the server deciding each trade."""

    @classmethod
    def setUpClass(cls):
        cls.lua = lua_env()
        cls.lua.execute(r"""
        function run(seed)
            math.randomseed(seed)
            local p = make_player({ }, 0, 0, 30)
            local trades, swaps = 0, 0
            for _ = 1, 2000 do
                local s = { owned = p.owned, bag = p.owned, head = p.head, main = p.main, free = p.free,
                            treats = { [4394] = 99 }, npc = { name = 'Pourette', dist = 3 } }
                local step = core.next_step(s)
                if step.kind == 'done' then return trades, swaps end
                if step.kind == 'gear' then
                    swaps = swaps + 1
                    if step.gear.head ~= nil then p.head = step.gear.head or 0 end
                    if step.gear.main ~= nil then p.main = step.gear.main or 0 end
                elseif step.kind == 'trade' then
                    assert(step.treat == 4394)
                    trade(p, step.treat)
                    trades = trades + 1
                else
                    error('unexpected step ' .. step.kind)
                end
            end
            error('never finished')
        end
        """)

    def test_finishes_in_expected_trades(self):
        g = self.lua.globals()
        mean, enough = g.core.trades_left(self.lua.table())
        runs = [g.run(seed) for seed in range(1, 3001)]
        trades = [r[0] for r in runs]
        avg = sum(trades) / len(trades)
        self.assertAlmostEqual(avg, mean, delta=0.6)
        covered = sum(1 for t in trades if t <= enough) / len(trades)
        self.assertGreater(covered, 0.88)
        self.assertLess(max(r[1] for r in runs), 5, 'a handful of gear swaps at most')
        print(f'\n  expected {mean:.1f} trades, 90% within {enough}; simulated mean {avg:.1f}, max {max(trades)}')

    def test_wrong_gear_is_fixed_first(self):
        g = self.lua.globals()
        # Wearing Pumpkin Head with Horror Head owned and plain pieces missing: take it off.
        s = self.lua.table_from({
            'owned': self.lua.table_from({13916: True, 13917: True}), 'bag': self.lua.table_from({13916: True}),
            'head': 13916, 'main': 0, 'free': 5, 'treats': self.lua.table_from({GINGER: 3}),
        })
        step = g.core.next_step(s)
        self.assertEqual(step.kind, 'gear')
        self.assertEqual(step.gear.head, False)

    def test_fetch_from_storage(self):
        g = self.lua.globals()
        owned = self.lua.table_from({i: True for i in (13916, 15176, 17565, 17587)})
        s = self.lua.table_from({'owned': owned, 'bag': self.lua.table(), 'head': 0, 'main': 0,
                                 'free': 5, 'treats': self.lua.table_from({GINGER: 3})})
        self.assertEqual(g.core.next_step(s).kind, 'fetch')

    def test_cheapest_treat(self):
        g = self.lua.globals()
        self.assertEqual(g.core.best_treat(self.lua.table_from({5631: 1, 4510: 4, 4394: 2})), GINGER)
        self.assertEqual(g.core.best_treat(self.lua.table_from({5631: 1, 4510: 4})), 4510)


STUBS = r"""
events, printed, queued = {}, {}, {}
addon = {}
ashita = { events = { register = function (name, _, fn) events[name] = fn end } }
function T(t) return t end
string.args = function (s) local a = {} for w in s:gmatch('%S+') do a[#a + 1] = w end return a end
local function chain(x) local o = { text = x } o.append = function (_, y) return y end return o end
package.loaded['common'] = true
package.loaded['chat'] = { header = chain, message = function (x) return x end }
saved = 0
package.loaded['settings'] = { load = function (d) return d end, register = function () end, save = function () saved = saved + 1 end }
drawn = {}
local ui = {}
setmetatable(ui, { __index = function () return function () return true end end })
ui.TextColored = function (_, t) drawn[#drawn + 1] = t end
ui.Button = function (t) drawn[#drawn + 1] = '[' .. t .. ']' return false end
package.loaded['imgui'] = ui
ImGuiCond_FirstUseEver, ImGuiWindowFlags_AlwaysAutoResize = 0, 0
print = function (x) printed[#printed + 1] = x end

bags = { [0] = { [1] = { Id = 4394, Count = 12 }, [2] = { Id = 13916, Count = 1 } } }
sizes = { [0] = 31 }
worn_head = 2 -- slot index of the head piece in the inventory
AshitaCore = {
    GetMemoryManager = function () return {
        GetInventory = function () return {
            GetContainerCountMax = function (_, c) return sizes[c] or 0 end,
            GetContainerItem = function (_, c, i) return (bags[c] or {})[i] or { Id = 0, Count = 0 } end,
            GetEquippedItem = function (_, slot) return { Index = slot == 4 and worn_head or 0 } end,
        } end,
        GetParty = function () return {
            GetMemberZone = function () return 230 end,
            GetMemberTargetIndex = function () return 1000 end,
        } end,
        GetEntity = function () return {
            GetStatus = function () return 0 end,
            GetRenderFlags0 = function (_, i) return (i == 20 or i == 21) and 0x200 or 0 end,
            GetName = function (_, i) return i == 20 and 'Pourette' or i == 21 and 'Valeriano' or '' end,
            GetDistance = function (_, i) return i == 20 and 16 or 400 end,
        } end,
    } end,
    GetChatManager = function () return { QueueCommand = function (_, _, c) queued[#queued + 1] = c end } end,
}
"""


class Addon(unittest.TestCase):
    """harvestmax.lua against stubbed Ashita: reads the client, swaps gear, draws."""

    def setUp(self):
        self.lua = luajit21.LuaRuntime()
        self.lua.execute(f"package.path = [[{ADDON}]] .. '/?.lua;' .. package.path")
        self.lua.execute(STUBS)
        self.lua.execute(f"dofile([[{ADDON}/harvestmax.lua]])")
        self.g = self.lua.globals()
        self.g.events['load']()

    def frame(self):
        self.lua.execute("drawn = {}")
        self.lua.execute("local t = os.clock() while os.clock() - t < 0.26 do end")
        self.g.events['d3d_present']()
        return list(self.g.drawn.values())

    def test_takes_off_pumpkin_head_while_farming(self):
        drawn = self.frame()
        self.assertIn('/equip head', list(self.g.queued.values()))
        self.assertTrue(any('Take off Pumpkin Head' in t for t in drawn), drawn)

    def test_trade_step_and_counting(self):
        self.lua.execute("worn_head = 0")
        drawn = self.frame()
        self.assertTrue(any('Trade ONE Ginger Cookie to Pourette (4 yalms)' in t for t in drawn), drawn)
        self.assertTrue(any('1 of 8' in t for t in drawn), drawn)
        # The whole stack goes in one trade.
        self.lua.execute("bags[0][1] = nil")
        self.frame()
        self.assertTrue(any('12 treats for one try' in str(p) for p in self.g.printed.values()))
        self.lua.execute("bags[0][1] = { Id = 4394, Count = 5 }")
        self.frame()
        self.lua.execute("bags[0][1] = { Id = 4394, Count = 4 }; bags[0][3] = { Id = 15176, Count = 1 }")
        drawn = self.frame()
        self.assertTrue(any('Got Pumpkin Head II' in str(p) for p in self.g.printed.values()))
        self.assertTrue(any('2 trades, 1 pieces, 11 treats wasted' in t for t in drawn), drawn)

    def test_buy_mentions_valeriano(self):
        self.lua.execute("worn_head = 0; bags[0][1] = nil")
        drawn = self.frame()
        self.assertTrue(any('Valeriano sells Ginger Cookies' in t for t in drawn), drawn)

    def test_full_bag(self):
        self.lua.execute("worn_head = 0; sizes[0] = 3")  # two slots, both used
        drawn = self.frame()
        self.assertTrue(any('Free one inventory slot' in t for t in drawn), drawn)

    def test_commands(self):
        e = self.lua.table_from({'command': '/harvestmax auto off', 'blocked': False})
        self.g.events['command'](e)
        self.assertTrue(e['blocked'])
        self.frame()
        self.assertEqual(len(self.g.queued), 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)

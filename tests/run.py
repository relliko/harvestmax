"""Tests for harvestmax, run under LuaJIT via lupa.

    python tests/run.py

Phoenix's live festival code isn't public, so the server here is a model of the rules on
wiki.phoenix-xi.com/Harvest_Festival (generated from Phoenix game beta 136ed7307def): a 5% prize
roll per trade (a worn piece's upgrade instead), costumes once per sweet kind per Vana'diel day.
"""
import os
import unittest

from lupa import luajit21

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON = os.path.dirname(HERE)

SERVER = r"""
PLAIN = { 13916, 15176, 17565, 17587 }
UP = { [13916] = 13917, [15176] = 15177, [17565] = 17566, [17587] = 17588 }

function make_player(owned, head, main, free)
    return { owned = owned, head = head, main = main, free = free, costumed = { }, reply = nil }
end

-- One trade of `n` of a sweet, as the wiki tells it. Returns the prize id or nil.
function trade(p, sweet, n)
    local prize
    for _, id in ipairs({ p.head, p.main }) do
        if prize == nil and UP[id] and not p.owned[UP[id]] then prize = UP[id] end
    end
    if prize == nil then
        local missing = { }
        for _, id in ipairs(PLAIN) do if not p.owned[id] then missing[#missing + 1] = id end end
        if #missing > 0 then prize = missing[math.random(#missing)] end
    end
    if prize ~= nil and p.free > 0 and math.random() < 0.05 then
        p.owned[prize] = true
        p.reply = 'Here, take this...'
        return prize
    end
    if not p.costumed[sweet] then
        p.costumed[sweet] = true
        p.reply = 'Thank you... And now for your treat...'
    else
        p.reply = 'Thank you...'
    end
end
"""

GARLIC, GINGER = 4467, 4394


def lua_env():
    lua = luajit21.LuaRuntime()
    lua.execute(f"package.path = [[{ADDON}]] .. '/?.lua;' .. package.path")
    lua.execute(SERVER)
    lua.execute("core = require('core')")
    return lua


class Rules(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.lua = lua_env()
        cls.g = cls.lua.globals()

    def t(self, d):
        return self.lua.table_from(d)

    def test_targets(self):
        core = self.g.core
        none = self.t({})
        self.assertEqual(tuple(core.target(none, 0, 0)), ('plain', 0.05))
        # A worn piece aims for its upgrade, head first.
        self.assertEqual(core.target(self.t({13916: True}), 13916, 17565)[0], 13917)
        self.assertEqual(core.target(self.t({13916: True, 13917: True}), 13916, 17565)[0], 17566)
        everything = self.t({i: True for i in (13916, 15176, 17565, 17587)})
        self.assertEqual(core.target(everything, 0, 0)[0], 0)

    def test_trades_left(self):
        mean, enough = self.g.core.trades_left(self.t({}))
        self.assertAlmostEqual(mean, 160)
        self.assertTrue(220 < enough < 250, enough)
        mean, _ = self.g.core.trades_left(self.t({i: True for i in (13916, 13917, 15176, 15177, 17565, 17566, 17587)}))
        self.assertAlmostEqual(mean, 20)

    def test_vana_day(self):
        core = self.g.core
        epoch = 1009810800
        self.assertEqual(core.vana_day(epoch), 0)
        self.assertEqual(core.vana_day(epoch + 3455), 0)
        self.assertEqual(core.vana_day(epoch + 3456), 1)
        self.assertEqual(core.to_midnight(epoch + 3456 * 10 + 100), 3356)

    def test_replies(self):
        core = self.g.core
        self.assertEqual(core.classify('Here, take this...'), 'item')
        self.assertEqual(core.classify('Thank you... And now for your treat...'), 'costume')
        self.assertEqual(core.classify('If you put this on and walk around, something...unexpected might happen...'), 'costume')
        self.assertEqual(core.classify('Thank you...'), 'nothing')
        self.assertIsNone(core.classify('Thank you for shopping!'))
        self.assertIn('already gave a costume today', core.explain('nothing', None))
        gear = self.t({'kind': 'gear', 'text': 'Take off Pumpkin Head.'})
        self.assertIn('gear was wrong (take off pumpkin head)', core.explain('nothing', gear).replace(' for this trade', ''))

    def test_cheapest_treat(self):
        core = self.g.core
        self.assertEqual(core.best_treat(self.t({5631: 1, GINGER: 4, GARLIC: 2})), GARLIC)
        self.assertEqual(core.best_treat(self.t({4320: 1, 4510: 4})), 4510)
        self.assertIsNone(core.best_treat(self.t({5631: 3})))  # Pumpkin Cake isn't on Phoenix's list


class Plan(unittest.TestCase):
    """Following next_step from nothing to all eight, with the model server deciding each trade."""

    @classmethod
    def setUpClass(cls):
        cls.lua = lua_env()
        cls.lua.execute(r"""
        function run(seed)
            math.randomseed(seed)
            local p = make_player({ }, 0, 0, 30)
            local trades, swaps = 0, 0
            for _ = 1, 5000 do
                local s = { owned = p.owned, bag = p.owned, head = p.head, main = p.main, free = p.free,
                            treats = { [4467] = 99, [4394] = 5 }, npc = { name = 'Pourette', dist = 3 } }
                local step = core.next_step(s)
                if step.kind == 'done' then return trades, swaps end
                if step.kind == 'gear' then
                    swaps = swaps + 1
                    if step.gear.head ~= nil then p.head = step.gear.head or 0 end
                    if step.gear.main ~= nil then p.main = step.gear.main or 0 end
                elseif step.kind == 'trade' then
                    assert(step.treat == 4467)
                    trade(p, step.treat, 1)
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
        runs = [g.run(seed) for seed in range(1, 2001)]
        trades = [r[0] for r in runs]
        avg = sum(trades) / len(trades)
        self.assertAlmostEqual(avg, mean, delta=4)
        covered = sum(1 for t in trades if t <= enough) / len(trades)
        self.assertGreater(covered, 0.88)
        self.assertLess(max(r[1] for r in runs), 5, 'a handful of gear swaps at most')
        print(f'\n  expected {mean:.0f} trades, 90% within {enough}; simulated mean {avg:.1f}, max {max(trades)}')

    def test_wrong_gear_is_fixed_first(self):
        g = self.lua.globals()
        s = self.lua.table_from({
            'owned': self.lua.table_from({13916: True, 13917: True}), 'bag': self.lua.table_from({13916: True}),
            'head': 13916, 'main': 0, 'free': 5, 'treats': self.lua.table_from({GARLIC: 3}),
        })
        step = g.core.next_step(s)
        self.assertEqual(step.kind, 'gear')
        self.assertEqual(step.gear.head, False)

    def test_fetch_from_storage(self):
        g = self.lua.globals()
        owned = self.lua.table_from({i: True for i in (13916, 15176, 17565, 17587)})
        s = self.lua.table_from({'owned': owned, 'bag': self.lua.table(), 'head': 0, 'main': 0,
                                 'free': 5, 'treats': self.lua.table_from({GARLIC: 3})})
        self.assertEqual(g.core.next_step(s).kind, 'fetch')


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
ui.GetCursorPosX = function () return 0 end
ui.TextColored = function (_, t) drawn[#drawn + 1] = t end
ui.Button = function (t) drawn[#drawn + 1] = '[' .. t .. ']' return false end
package.loaded['imgui'] = ui
ImGuiCond_FirstUseEver, ImGuiWindowFlags_AlwaysAutoResize = 0, 0
print = function (x) printed[#printed + 1] = x end

bags = { [0] = { [1] = { Id = 4467, Count = 12 }, [2] = { Id = 13916, Count = 1 } } }
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
    """harvestmax.lua against stubbed Ashita: reads the client, swaps gear, explains replies, draws."""

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

    def say(self, text):
        e = self.lua.table_from({'message': text, 'injected': False, 'blocked': False})
        self.g.events['text_in'](e)

    def has(self, drawn, text):
        # line() doubles % for ImGui's format string.
        self.assertTrue(any(text in t.replace('%%', '%') for t in drawn), drawn)

    def test_takes_off_pumpkin_head_while_farming(self):
        drawn = self.frame()
        self.assertIn('/equip head', list(self.g.queued.values()))
        self.has(drawn, 'Take off Pumpkin Head')

    def test_trade_step_counting_and_replies(self):
        self.lua.execute("worn_head = 0")
        drawn = self.frame()
        self.has(drawn, 'Trade ONE Garlic Cracker to Pourette (4 yalms)')
        self.has(drawn, '1 of 8')
        self.has(drawn, 'Pourette gives the Orc costume')
        self.has(drawn, 'still give a costume today: Garlic Cracker')
        # The whole stack goes in one trade.
        self.lua.execute("bags[0][1] = nil")
        self.frame()
        self.assertTrue(any('12 sweets for one try' in str(p) for p in self.g.printed.values()))
        self.say('Thank you... And now for your treat...')
        self.lua.execute("bags[0][1] = { Id = 4467, Count = 5 }")
        drawn = self.frame()
        self.has(drawn, 'Last trade: Costume')
        self.has(drawn, 'still give a costume today: none on you')
        self.lua.execute("local t = os.clock() while os.clock() - t < 1.6 do end")
        self.lua.execute("bags[0][1] = { Id = 4467, Count = 4 }")
        self.frame()
        self.say('Thank you...')
        drawn = self.frame()
        self.has(drawn, 'already gave a costume today')
        self.lua.execute("local t = os.clock() while os.clock() - t < 1.6 do end")
        self.lua.execute("bags[0][1] = { Id = 4467, Count = 3 }; bags[0][3] = { Id = 15176, Count = 1 }")
        self.frame()
        self.say('Here, take this...')
        drawn = self.frame()
        self.has(drawn, '5% prize roll hit')
        self.assertTrue(any('Got Pumpkin Head II' in str(p) for p in self.g.printed.values()))
        self.has(drawn, '3 trades, 1 prizes, 11 sweets wasted')

    def test_costumes_reset_at_vana_midnight(self):
        self.lua.execute("worn_head = 0")
        self.frame()
        self.lua.execute("bags[0][1] = { Id = 4467, Count = 11 }")
        self.frame()
        self.has(self.frame(), 'none on you')
        self.lua.execute("harvest_day = os.time; local real = os.time; os.time = function () return real() + 3456 end")
        self.has(self.frame(), 'still give a costume today: Garlic Cracker')

    def test_buy_mentions_valeriano_and_crackers(self):
        self.lua.execute("worn_head = 0; bags[0][1] = nil")
        drawn = self.frame()
        self.has(drawn, 'Valeriano sells Ginger Cookies')
        self.has(drawn, 'Garlic Crackers, 4 gil')

    def test_full_bag(self):
        self.lua.execute("worn_head = 0; sizes[0] = 3")  # two slots, both used
        self.has(self.frame(), 'Free one inventory slot')

    def test_pitchfork_names_this_towns_npcs(self):
        drawn = self.frame()
        self.has(drawn, 'Ghost (Kueh Igunahmori, Phamelise) and Skeleton (Corua, Ostalie), decoration at L-7')

    def test_commands(self):
        e = self.lua.table_from({'command': '/harvestmax auto off', 'blocked': False})
        self.g.events['command'](e)
        self.assertTrue(e['blocked'])
        self.frame()
        self.assertEqual(len(self.g.queued), 0)


if __name__ == '__main__':
    unittest.main(verbosity=2)

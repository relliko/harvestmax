# harvestmax

The Harvest Festival with the fun taken out. One window tells you what to wear and what to trade so you get all eight festival pieces (Pumpkin Head, Pumpkin Head II, Trick Staff, Trick Staff II and their Horror/Treat upgrades) in the fewest treats.

    /addon load harvestmax

The rules come from Phoenix's `scripts/globals/harvest_festivals.lua`:

- Festival NPCs: Apairemant, Corua, Machielle, Phamelise and Pourette in Southern San d'Oria; Antonian, Attarena and Vichuel in Northern San d'Oria (plus the Bastok and Windurst ones).
- Trade **one** treat at a time. The whole stack is used up for a single try.
- Each trade has a 1 in 3 chance at best, and you need a free inventory slot or the treat is wasted.
- If you wear a festival piece, the only thing a trade can give is that piece's upgrade. So wear nothing festive until you have the four plain pieces, then wear the ones still waiting for upgrades.
- The full set takes about 26 trades, and 36 is enough 9 times in 10. The cheapest treat is a Ginger Cookie for 12 gil, from Valeriano (in Southern San d'Oria when San d'Oria is first in conquest) or Ness Rugetomal (Windurst Waters).

Commands (`/hmax` works too):

- `/harvestmax`: show or hide the window (it only shows in festival towns)
- `/harvestmax auto [on|off]`: swap the festival pieces with `/equip` on its own (on by default)
- `/harvestmax equip`: do the swap now
- `/harvestmax always`: show the window everywhere
- `/harvestmax next`: print the next step

Nothing is sent to the server except what your own `/equip` commands send.

Tests: `python tests/run.py` (needs lupa and a Phoenix checkout at C:/code/Phoenix, or set `PHOENIX`).

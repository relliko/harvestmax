# harvestmax

The Harvest Festival with the fun taken out. One window tells you what to wear and what to trade so you get all eight festival prizes (Pumpkin Head, Pumpkin Head II, Trick Staff, Trick Staff II and their Horror/Treat upgrades) in the fewest sweets. It also says what each townsperson's reply meant and how to get the festival's other rewards.

    /addon load harvestmax

The rules follow [Phoenix's wiki page](https://wiki.phoenix-xi.com/Harvest_Festival):

- Trade **one** sweet to a costumed townsperson (Southern and Northern San d'Oria, Bastok Mines and Markets, Windurst Waters and Woods). The whole stack is used up for a single try.
- Each trade has a 5% chance of a prize you don't own. If you wear one of the prizes, you can win its upgrade instead. So wear nothing festive until you have the four plain pieces, then wear the ones still waiting for upgrades.
- Otherwise you get a costume, but each kind of sweet gives a costume only once per Vana'diel day. After that, the same sweet only gets a "Thank you...". That's still a normal prize roll.
- The full set takes about 160 trades, and 234 is enough 9 times in 10. The cheapest sweet is a Garlic Cracker for 4 gil, from Ghebi Damomohe in Lower Jeuno.

The window also shows:

- which of your sweets still give a costume today, and which costume the nearest townsperson gives
- the Pitchfork, Pitchfork +1, Witch Hat and Coven Hat, with how to get each, told for the town you're in:
  - **Pitchfork:** the townsfolk who give that town's costume pair, and where its decoration is
  - **Pitchfork +1:** the townsfolk who give a goblin costume to citizens of your nation, and that town's decoration
  - **Witch Hat and Coven Hat:** the nearest exorcist and her witches (Northern San d'Oria, Bastok Markets or Windurst Waters)

Commands (`/hmax` works too):

- `/harvestmax`: show or hide the window (it only shows in festival towns)
- `/harvestmax auto [on|off]`: swap the festival pieces with `/equip` on its own (on by default)
- `/harvestmax equip`: do the swap now
- `/harvestmax always`: show the window everywhere
- `/harvestmax next`: print the next step

Nothing is sent to the server except what your own `/equip` commands send.

Tests: `python tests/run.py` (needs lupa).

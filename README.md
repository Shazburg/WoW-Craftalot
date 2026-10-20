# Craftalot

An in-game profession assistant for **Retail's Azeroth Tailoring, Enchanting
and Cooking (1–300)**. Craftalot compares the estimated cost of gaining skill,
plans a route toward your target, expands dependent crafts, and builds a
materials list using the stock you already own.

The recipe database is included. No desktop application, web account, AI model,
or external service is required. **Auctionator is optional** and supplies local
auction prices, shopping lists, and disenchant value estimates. Manual unit
prices and prices recorded while visiting vendors work without it.

## Use

In WowUp, select **Retail**, choose **Install from URL**, and enter
**https://github.com/Shazburg/WoW-Craftalot**. Packaged releases supply the
Retail flavor metadata. For manual installation:

1. Extract the release ZIP so `Interface/AddOns/Craftalot/Craftalot.toc` exists
   in the **Retail** installation you play. Enable Craftalot in WoW and reload.
2. Open a supported profession. Craftalot follows the profession you opened;
   use **`/craftalot`** or **`/calot`** if you closed the window.
3. The **Professions** page shows the next craft, its estimated cost per skill,
   and materials you have versus need. Set **Target skill** to change your goal.
   Route steps appear as compact cards below; click one to inspect it.
4. Use **Craft one** when ready. Enchanting opens the native recipe so you can
   choose an item or vellum. **Get materials** opens your shopping list.
5. Missing prices produce a **Find auction prices** action that creates an
   Auctionator price-check list. You can also visit a reagent vendor to record
   its prices, or click a material to enter its unit price in gold/silver/copper.
   Unknown prices never count as zero.
6. On **Shopping list**, **Send to Auctionator** creates/replaces the list named
   `Craftalot materials`. **Buy vendor materials** buys one planned material
   type from the open vendor per click, bounded by the plan, money, stock and
   stack limit. Update old auction scans before making large purchases.

Version 0.2 uses a **Modern interface inspired by Mastercraft**: a dark sidebar,
profession tiles, soft rounded panels, red accents, and the next crafting step
expanded with its materials and actions. Shopping, disenchant comparisons and
settings have separate pages. Its UI artwork and implementation are original.

To craft a specific item instead of leveling, select the recipe in WoW's
profession window and click **Use selected recipe**. Enter the number of
**crafts** beside that button. Intermediate crafts are ordered first; their
output and batch surplus are reused. Click **Leveling mode** to return to your
skill target. Quantities are casts, not the number of resulting items when a
recipe makes multiple items.

**Skip recipe** removes it from consideration; restore it in Settings.
Unlearned recipes are excluded by default. **Preview recipes you haven't
learned** includes scanned recipes you still need to obtain. Learning and
recipe purchase costs are not included, and the addon cannot craft an
unlearned recipe. Tool/station requirements are checked before crafting.

**Include bank materials** changes estimates; withdraw required reagents into
your bags to craft. Actual craft, bag and skill changes trigger replanning.
Nothing is crafted or purchased merely because a window opens or an event
fires. No fictional intermediate inventory is persisted.

The **Disenchanting** page compares the cost of known tailoring crafts with
Auctionator's expected market value of their disenchant materials. This helps
compare crafting for disenchanting with buying those materials. It does not
predict exact dust/essence yields, route disenchanting into the queue, or
disenchant your equipment automatically.

## Cost model and limits

The full route uses dynamic programming, including failed skill-up attempts
and recipes granting multiple points. Before yellow, estimated skill-up
chance is 100%; from yellow to grey it declines linearly. Blizzard does not
provide exact probabilities. These are **expected costs, not guarantees**.

The route minimizes expected cost within a **fixed unit-price model** using
the recipes you allow. Intermediate unit costs compare crafting versus buying,
reject cycles, and respect available skills. A second pass reserves inventory,
compares whole-batch crafting versus buying, credits intermediate skill gains,
and produces a concrete queue and shopping list. Next-craft alternatives use
your actual inventory. Shared materials are reserved once within a plan.

The resulting whole-batch plan is **not a proof of the globally cheapest
stochastic route with finite inventory and auction listings**. It excludes
training fees, acquisition of unlearned recipes, travel, output resale, and
changing auction prices. Intermediate choices minimize procurement cost, not
a joint multi-profession leveling objective. Planning each profession reuses
the current inventory; two separate plans do not reserve stock against each
other. Vendor quotes are recorded observations, not promises of availability.
Actual skill gains and material use are authoritative and trigger replanning.

Runtime API targets **Retail 12.1.5 / interface 120105** (installed client
12.1.5.70448 inspected). Bundled difficulty bands originate in 12.1.0.69933;
live scans replace availability, ingredient and output information before use.
See [data provenance](Data/PROVENANCE.md). Unsupported choice/quality/currency
recipes are excluded. This release is not for Classic Era, progression Classic,
WoW Forever, or Midnight profession tracks. No action-bar features are included.

Automated tests cover the pure Lua model, an exhaustive small-state cost
oracle, documented Retail/Auctionator API fixtures, UI lifecycle, merchant
safety, and deterministic release packaging. **A running-client smoke test is
still required**; the test harness is not an in-game compatibility claim.

## Updates and development

Use the packaged release ZIP, not GitHub's auto-generated source archive.
GitHub release assets include `release.json` with `mainline` / `120105`
metadata for WowUp. Stable `vX.Y.Z` tags must match the TOC version. Main-branch
pushes automatically publish a stable release when that TOC version has no
release yet. Subsequent pushes with the same version publish development
prereleases; WowUp must allow prereleases to follow those builds. Bump the TOC
version to publish the next stable update. Explicit version tags also work.

```sh
lua5.1 tests/engine.lua
lua5.1 tests/client.lua
python3 -m unittest discover -s tests -p 'test_*.py'
python3 scripts/package.py
```

The project has no build-time Python dependencies. Packaging uses an explicit
runtime file allowlist; it never includes game installations, SavedVariables,
credentials, development fixtures or repository metadata.

## License

GPL-3.0, preserving the license selected for the GitHub repository. The bundled
ProfessionDB subset remains MIT; its separate copyright and
license are included in every release under `licenses/ProfessionDB.txt`.

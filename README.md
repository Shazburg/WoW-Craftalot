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
2. Open each relevant profession once so Craftalot can scan live recipes and
   your Azeroth skill. Run **`/craftalot`** or **`/calot`** to open the panel.
3. Choose Tailoring, Enchanting or Cooking and enter the target skill. Click
   **Plan levels**. A gap does not hide useful crafts: an incomplete route
   shows the reachable portion and its stopping point.
4. Supply missing prices with Auctionator, by visiting a reagent vendor, or
   under **Settings** (item ID and copper per item). Unknown prices never
   count as zero. Update old Auctionator scans before making large purchases.
5. Inspect **Plan** for the queue and inventory-aware next-craft alternatives.
   Click a recipe row to open it. **Craft one** performs one craft per click;
   enchanting opens the native recipe so you can choose an item or vellum.
   Tool/station requirements reported by WoW are shown in the queue and
   checked before crafting; obtain the tool or move to the required station.
6. Inspect **Materials** for the combined shopping list. **Auctionator list**
   creates/replaces only the list named `Craftalot materials`. **Buy vendor
   item** buys one planned material type from the currently open vendor per
   click, bounded by the plan, money, merchant stock and stack limit.

To craft a specific item instead of leveling, select its recipe in WoW's
profession window (or click a Craftalot recipe row), enter the number of
**crafts**, and click **Plan recipe**. Intermediate crafts are ordered first;
their output and batch surplus are reused. The quantities are casts, not the
number of resulting items when a recipe makes multiple items.

**Exclude selected** removes a recipe from consideration. Restore it in
Settings. Unlearned recipes are excluded by default; **Preview unlearned
recipes** includes scanned recipes you still need to obtain. Learning costs
and recipe purchase prices are not included. Preview recipes remain marked
`LEARN FIRST`, and cannot be crafted by the addon.

**Include bank stock** changes estimates, not what the craft button can use:
withdraw required materials into your bags. Each craft/bag/skill change
triggers a replan from actual state. Nothing is crafted or purchased merely
because a window opens or an event fires. Recipe-specific output leftovers
are not persisted as fictional inventory.

The Materials tab also compares the cost of known tailoring crafts with
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

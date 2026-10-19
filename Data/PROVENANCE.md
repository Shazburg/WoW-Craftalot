# Recipe data

`Recipes.lua` is a generated subset of **ProfessionDB / LibProfessionDB 1.9.1**,
copyright 2026 Pimptasty, used under the MIT license reproduced in
`licenses/ProfessionDB.txt`.

- Project: https://www.curseforge.com/wow/addons/libprofessiondb
- Source release: https://www.curseforge.com/wow/addons/libprofessiondb/files/9095167
- Source filename: `ProfessionDB-ProfessionDB-v1.9.1.zip`
- SHA256: `909cb41720cf6bf6920f1c25c644f89b39ad63087f589c07737e7da943c52379`
- Source data client build: **12.1.0.69933**.
- Included skill lines: Azeroth Tailoring **2540** (270 records), Enchanting
  **2494** (141), Cooking **2548** (110). Parent professions: 197, 333, 185.
- Locale-independent reagent IDs, spell IDs, output IDs and difficulty bands;
  English fallback names. Names are replaced by localized live recipe names.

There is **no runtime dependency** on ProfessionDB or LibStub. The addon reads
its own internal table. The importer deliberately excludes every other skill
line and profession. Some bundled records may be unavailable/deprecated; live
recipe information determines availability, not their presence in this file.

Regenerate with `python3 scripts/import_recipes.py /path/to/source.zip`, then
run the tests and review the generated diff. Do not silently change source
versions or the hash here.

The bundled source does not specify output quantities. A live Retail recipe
scan is required to verify quantity and ingredients before a recipe can enter
a plan. Variable outputs use the minimum quantity, conservatively. Ingredients,
availability, skill gains and output IDs are overlaid from the current client.
Difficulty bands remain from the stated source build; exact 12.1.5 skill-up
probabilities have not been independently measured. The UI labels these
probabilities and all resulting leveling costs as **estimates**.

API references checked for the implementation:

- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUIDocumentation.lua
- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/TradeSkillUITypesDocumentation.lua
- https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_APIDocumentationGenerated/MerchantFrameDocumentation.lua
- Auctionator's installed `Source/API/v1/README.md`, `ShoppingLists.lua`,
  `GetDisenchantPrice.lua` and `GetAuctionAge.lua`. Only its public v1 API is used.

local _, A = ...
local panel, body, rows = nil, nil, {}
local rowCount=0
local tab = "Plan"
local gold, pale = "|cffedbf65", "|cffb9c6cc"

local function label(parent,text,x,y,width,font)
    local s=parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
    s:SetPoint("TOPLEFT",x,y); s:SetWidth(width or 700); s:SetJustifyH("LEFT"); s:SetText(text)
    s:SetWordWrap(false)
    return s
end
local function button(parent,text,x,y,width,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT",x,y); b:SetSize(width,24); b:SetText(text); b:SetScript("OnClick",fn)
    return b
end
local function edit(parent,x,y,width,value,fn,numeric)
    local b=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    b:SetPoint("TOPLEFT",x,y); b:SetSize(width,24); b:SetAutoFocus(false)
    if numeric then b:SetNumeric(true) end
    b:SetText(tostring(value)); b:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    b:SetScript("OnEditFocusLost",function(self) fn(self:GetText()) end)
    b:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    return b
end
local function line(text,recipe,action)
    rowCount=rowCount+1
    local index=rowCount
    local row=rows[index]
    if not row then
        row=CreateFrame("Button",nil,body)
        row:SetPoint("TOPLEFT",0,-(index-1)*24); row:SetSize(724,24)
        row.text=label(row,"",2,-4,714,"GameFontHighlightSmall")
        row:SetHighlightTexture("Interface/QuestFrame/UI-QuestTitleHighlight","ADD")
        rows[index]=row
    end
    row:Show(); row.text:SetText(text); row:SetScript("OnClick",nil)
    if action then row:SetScript("OnClick",action)
    elseif recipe then row:SetScript("OnClick",function() A.selectedRecipe=recipe; A.SelectRecipe(recipe); A.Render() end) end
end

local function check(parent,text,x,y,key)
    local b=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate")
    b:SetPoint("TOPLEFT",x,y); b:SetSize(26,26)
    label(parent,text,x+30,y-6,310,"GameFontHighlightSmall")
    b:SetScript("OnClick",function(self) A.db[key]=self:GetChecked() and true or false; A.Refresh() end)
    return b
end

local function routeView()
    local ctx,plan,route=A.ctx,A.plan,A.route
    line(gold.."Azeroth skill: "..(ctx.skills[A.profession] or 0).."  |  Target: "..(A.target or 300).."|r")
    if route then
        line("Expected route cost (before inventory): "..A.Money(route.expectedCost))
        if not route.complete then
            line("|cffffad71No complete route. Scan recipes, add prices, lower target, or preview unlearned recipes.|r")
            if route.blockedAt then line("Available route reaches skill "..route.blockedAt.."; expected cost "..A.Money(route.partialCost)..".") end
        end
        if #route.unknown>0 then
            line(gold.."Missing prices (not treated as free):|r")
            for index, id in ipairs(route.unknown) do
                if index>15 then line("  + "..(#route.unknown-15).." more. Update Auctionator prices or enter manual prices.");break end
                line("  "..A.ItemName(id).." ["..id.."]")
            end
        end
    end
    if plan then
        line("Shopping cost after inventory and whole batches: "..A.Money(plan.cost))
        if A.db.bank then line("Bank stock included in estimates; withdraw reagents before crafting.") end
        if plan.error then line("|cffffad71"..plan.error.."|r") end
        line(gold.."Crafting queue - click a row to open its recipe|r")
        for index,step in ipairs(plan.queue) do
            local r=ctx.recipes[step.recipe]
            line(string.format("%d. %dx %s%s%s  (~%.1f skill)",index,step.casts,r.name,
                step.intermediate and " [intermediate]" or "",r.learned and "" or " [LEARN FIRST]",step.skillGain or 0),r.id)
            for _,requirement in ipairs(r.requirements or {}) do line("    Needs: "..requirement,r.id) end
        end
        if #plan.queue==0 then line("No crafts queued. Open and scan the profession; recipes also need material prices.") end
        line(pale.."Skill gains are estimates. Craft one at a time near the target; the route updates from actual skill.|r")
    end
    line("")
    line(gold.."Cheapest next skill point with your inventory (click to inspect)|r")
    for index,row in ipairs(A.ranked or {}) do
        if index>10 then break end
        line(string.format("%s: %s / skill  |  %.0f%% chance  |  one craft %s",
            ctx.recipes[row.recipe].name,A.Money(row.expected),100*row.chance,A.Money(row.cost)),row.recipe)
    end
end

local function materialsView()
    line(gold.."Combined shopping list - inventory and intermediate output already reserved|r")
    local shopping=A.plan and A.plan.shopping or {}
    if not next(shopping) then line("No purchases planned. Build a priced plan first.") end
    for _, id in ipairs(A.SortedKeys(shopping)) do
        local row=shopping[id]
        local stamp=A.ctx.prices[id] and A.ctx.prices[id].age
        local age=stamp and ("  |  quote age "..stamp.." days") or ""
        line(string.format("%dx %s [%d]  |  %s  |  %s%s",row.quantity,A.ItemName(id),id,
            row.source,A.Money(row.quantity*row.unit),age))
    end
    line("")
    line(gold.."Tailoring -> disenchanting comparison|r")
    line("Craft cost versus Auctionator's expected auction value of the resulting enchanting materials.")
    line("This is a comparison, not a guaranteed yield or an automatic disenchant queue.")
    local comparisons=A.DisenchantComparisons()
    if #comparisons==0 then line("Scan Tailoring and load Auctionator enchanting prices to compare available crafts.") end
    for i,row in ipairs(comparisons) do
        if i>12 then break end
        line(string.format("%s: craft %s  |  materials %s  |  difference %s",
            A.ctx.recipes[row.recipe].name,A.Money(row.cost),A.Money(row.value),
            (row.saving < 0 and "-" or "+")..A.Money(math.abs(row.saving))),row.recipe)
    end
end

local function settingsView()
    line(gold.."Prices and recipe availability|r")
    line("Visit a vendor to record its current reagent prices. Auctionator supplies your last scanned auction prices.")
    line("Manual unit prices are copper per item, override automatic prices, and can be 0 for freely farmed items.")
    line("Enter an item ID and a copper value above, then click Save price. Blank copper removes the override.")
    line("Unknown prices block priced paths. Auction quotes can be stale; Craftalot never buys auctions.")
    line("")
    line(gold.."Model and scope|r")
    line("Retail Azeroth Tailoring, Enchanting and Cooking, 1-300. Each expansion has its own skill track.")
    line("Skill-up chance: 100% before yellow, then linear decline to 0% at grey. This is an estimate.")
    line("The full route minimizes expected cost with fixed unit prices; inventory and batches are expanded afterward.")
    line("Intermediate skill gains are shown; actual gains trigger a replan. Shopping quantities are expectations, not guarantees.")
    line("No output resale is credited. Future recipe acquisition / training fees are excluded.")
    line("Unlearned previews require obtaining the recipes; they never authorize Craftalot to learn or craft them.")
    line("Only verified simple, single-choice material recipes are supported. No modern quality/concentration recipes.")
    line("")
    line(gold.."Excluded recipes - click to restore|r")
    local any=false
    for _,id in ipairs(A.SortedKeys(A.char.excluded)) do
        if A.char.excluded[id] then
            any=true
            line((A.Recipes[id] and A.Recipes[id].name or tostring(id)),nil,function() A.char.excluded[id]=nil; A.Refresh() end)
        end
    end
    if not any then line("No exclusions. Select a queue/alternative recipe and click Exclude selected.") end
    line("")
    line(gold.."Manual price overrides - click to remove|r")
    for _, id in ipairs(A.SortedKeys(A.db.prices)) do
        line(A.ItemName(id).." ["..id.."] = "..A.Money(A.db.prices[id]),nil,function() A.db.prices[id]=nil; A.Refresh() end)
    end
end

function A.Render()
    if not panel then return end
    for _, row in ipairs(rows) do row:Hide() end
    rowCount=0
    panel.status:SetText(A.status or "Open a profession and click Refresh.")
    panel.selection:SetText("Selected: "..(A.selectedRecipe and A.Recipes[A.selectedRecipe] and A.Recipes[A.selectedRecipe].name or "none"))
    for _, control in ipairs(panel.settings) do control:SetShown(tab=="Settings") end
    panel.bank:SetChecked(A.db.bank or false)
    panel.unlearned:SetChecked(A.db.unlearned or false)
    panel.autoShow:SetChecked(A.db.autoShow or false)
    if not A.ctx then line("Open Tailoring, Enchanting or Cooking to scan your Azeroth recipes.")
    elseif tab=="Plan" then routeView()
    elseif tab=="Materials" then materialsView()
    else settingsView() end
    body:SetHeight(math.max(340,rowCount*24+10))
end

function A.CreateUI()
    panel=CreateFrame("Frame","CraftalotFrame",UIParent,"BackdropTemplate")
    A.frame=panel
    panel:SetSize(800,640); panel:SetPoint("CENTER",140,0)
    panel:SetFrameStrata("DIALOG"); panel:SetClampedToScreen(true)
    panel:SetBackdrop({bgFile="Interface/Tooltips/UI-Tooltip-Background",edgeFile="Interface/Tooltips/UI-Tooltip-Border",tile=true,tileSize=16,edgeSize=16,insets={left=4,right=4,top=4,bottom=4}})
    panel:SetBackdropColor(0.035,0.055,0.07,0.98)
    panel:EnableMouse(true); panel:SetMovable(true); panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart",panel.StartMoving); panel:SetScript("OnDragStop",panel.StopMovingOrSizing)
    table.insert(UISpecialFrames,"CraftalotFrame")
    label(panel,"Craftalot",18,-16,350,"GameFontNormalLarge")
    label(panel,"A little less grinding. A lot more crafting.",18,-39,600,"GameFontHighlightSmall")
    local close=CreateFrame("Button",nil,panel,"UIPanelCloseButton");close:SetPoint("TOPRIGHT",-4,-4)
    for index,p in ipairs(A.Professions) do
        button(panel,p.name,18+(index-1)*118,-62,110,function() A.OpenProfession(p.id) end)
    end
    label(panel,"Target",386,-69,48,"GameFontHighlightSmall")
    edit(panel,435,-62,45,300,function(v) A.target=math.floor(math.max(1,math.min(300,tonumber(v) or 300))); A.mode="level"; A.Refresh() end,true)
    button(panel,"Plan levels",492,-62,100,function() A.mode="level"; A.Refresh() end)
    button(panel,"Refresh",604,-62,80,function() A.Scan(); A.Refresh() end)
    for index,name in ipairs({"Plan","Materials","Settings"}) do
        button(panel,name,18+(index-1)*110,-96,104,function() tab=name; panel.scroll:SetVerticalScroll(0); A.Render() end)
    end
    panel.selection=label(panel,"Selected: none",18,-132,580,"GameFontHighlightSmall")
    edit(panel,590,-125,42,1,function(v) A.quantity=math.floor(math.max(1,math.min(1000,tonumber(v) or 1))) end,true)
    button(panel,"Plan recipe",645,-125,126,function()
        local form=ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
        local info=form and form.GetRecipeInfo and form:GetRecipeInfo()
        if info and A.Recipes[info.recipeID] then A.selectedRecipe=info.recipeID end
        A.mode="recipe"; A.Refresh()
    end)
    panel.bank=check(panel,"Include bank stock",18,-158,"bank")
    panel.unlearned=check(panel,"Preview unlearned recipes",260,-158,"unlearned")
    panel.autoShow=check(panel,"Open with profession",540,-158,"autoShow")
    panel.settings={}
    local function setting(widget) table.insert(panel.settings,widget); return widget end
    setting(label(panel,"Item ID",20,-195,70,"GameFontHighlightSmall"))
    local item=setting(edit(panel,90,-190,76,"",function() end,true))
    setting(label(panel,"Copper / item",185,-195,92,"GameFontHighlightSmall"))
    local price=setting(edit(panel,285,-190,110,"",function() end,true))
    setting(button(panel,"Save price",412,-190,100,function()
        local id,value=tonumber(item:GetText()),tonumber(price:GetText())
        if id and id>0 and id==math.floor(id) and (not value or value>=0) then
            A.db.prices[id]=value; A.Refresh()
        else A.Message("Use a numeric item ID and nonnegative copper price.") end
    end))
    local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
    panel.scroll=scroll
    scroll:SetPoint("TOPLEFT",20,-225);scroll:SetPoint("BOTTOMRIGHT",-40,94)
    body=CreateFrame("Frame",nil,scroll);body:SetSize(730,340);scroll:SetScrollChild(body)
    panel.status=label(panel,"",20,-559,750,"GameFontHighlightSmall")
    button(panel,"Craft one",18,-589,120,A.CraftNext)
    button(panel,"Auctionator list",151,-589,148,A.ExportShopping)
    button(panel,"Buy vendor item",312,-589,148,A.BuyVendor)
    button(panel,"Exclude selected",473,-589,148,function()
        if A.selectedRecipe then A.char.excluded[A.selectedRecipe]=true; A.Refresh() end
    end)
    label(panel,"/craftalot",648,-596,110,"GameFontDisableSmall")
    panel:Hide()
    panel:SetScript("OnShow",A.Schedule)
end

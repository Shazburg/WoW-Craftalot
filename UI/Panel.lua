local _, A = ...
local W,M=A.Widgets,A.Presentation
local C=W.colors
local panel,body,hero
local page="Professions"
local pool,used={},0
local WIDTH=652
local icons={[197]="Interface\\Icons\\Trade_Tailoring",[333]="Interface\\Icons\\Trade_Engraving",[185]="Interface\\Icons\\INV_Misc_Food_15"}
local function spellIcon(r)
    return r and ((C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(r.id)) or icons[r.profession]) or 134400
end
local function itemIcon(id)
    return (C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or 134400
end
local function showPage(name)
    page=name;panel.scroll:SetVerticalScroll(0);A.Render()
end
A.ShowPage=showPage
local function priceItem(id)
    A.priceItem=id;showPage("Settings")
end
local function row(y,height)
    used=used+1
    local r=pool[used]
    if not r then
        r=W.Card(body,0,y,WIDTH,height)
        r.icon=W.Icon(r,12,12,28)
        r.title=W.Text(r,"",50,12,350,13)
        r.detail=W.Text(r,"",50,32,480,11,C.muted)
        r.right=W.Text(r,"",475,15,160,11,C.muted);r.right:SetJustifyH("RIGHT")
        r.hit=CreateFrame("Button",nil,r);r.hit:SetAllPoints(r)
        pool[used]=r
    end
    r:ClearAllPoints();r:SetPoint("TOPLEFT",0,-y);W.Surface(r,WIDTH,height,C.card)
    r:Show();r.icon:Show();r.detail:Show();r.title:SetText("");r.detail:SetText("");r.right:SetText("")
    r.hit:SetScript("OnClick",nil)
    return r
end
local function heading(text,y)
    local r=row(y,28);for _,t in ipairs(r.fill) do t:SetVertexColor(C.background[1],C.background[2],C.background[3]) end
    for _,t in ipairs(r.edge) do t:SetVertexColor(C.background[1],C.background[2],C.background[3]) end
    r.icon:Hide();r.detail:Hide();r.title:ClearAllPoints();r.title:SetPoint("TOPLEFT",0,-6);r.title:SetText(text)
    return r
end
local function resetRows()
    used=0
    for _,r in ipairs(pool) do
        r:Hide();r.title:ClearAllPoints();r.title:SetPoint("TOPLEFT",50,-12)
    end
end
local function primary()
    local s=M.Next()
    if s.kind=="ready" then A.CraftNext(s.recipe.id)
    elseif s.kind=="prices" then A.ExportPriceSearch(s.unknown)
    elseif s.kind=="materials" then
        if A.inspectRecipe then
            A.selectedRecipe=s.recipe.id;A.mode="recipe";A.quantity=1;A.inspectRecipe=nil;A.Refresh()
        end
        showPage("Shopping list")
    elseif s.recipe then A.SelectRecipe(s.recipe.id)
    else A.OpenProfession(A.profession) end
end
local function buildHero()
    hero=W.Card(body,0,0,WIDTH,202)
    hero.caption=W.Text(hero,"NEXT CRAFT",18,16,420,10,C.muted)
    hero.icon=W.Icon(hero,18,42,42)
    hero.name=W.Text(hero,"",74,42,550,18)
    hero.detail=W.Text(hero,"",74,69,550,11,C.muted)
    hero.badge=W.Text(hero,"",340,16,290,11,C.green);hero.badge:SetJustifyH("RIGHT")
    hero.materials={}
    for i=1,4 do
        local x=18+((i-1)%2)*310
        local y=104+math.floor((i-1)/2)*27
        local b=CreateFrame("Button",nil,hero);b:SetPoint("TOPLEFT",x,-y);b:SetSize(300,24)
        b.icon=W.Icon(b,0,0,21);b.label=W.Text(b,"",29,4,265,11)
        hero.materials[i]=b
    end
    hero.primary=W.Button(hero,"",18,163,148,primary,true)
    hero.secondary=W.Button(hero,"Open recipe",176,163,134,function()
        local s=M.Next();if s.recipe then A.SelectRecipe(s.recipe.id) end
    end)
    hero.skip=W.Button(hero,"Skip recipe",320,163,118,function()
        local s=M.Next();if s.recipe then A.char.excluded[s.recipe.id]=true;A.inspectRecipe=nil;A.Refresh() end
    end)
    hero.back=W.Button(hero,"Recommended",448,163,180,function() A.inspectRecipe=nil;A.Render() end)
end
local function professions()
    local s=M.Next()
    local height=#s.materials>2 and 202 or 176
    W.Surface(hero,WIDTH,height,C.card)
    for _,b in ipairs({hero.primary,hero.secondary,hero.skip,hero.back}) do
        local x=b==hero.primary and 18 or (b==hero.secondary and 176 or (b==hero.skip and 320 or 448))
        b:ClearAllPoints();b:SetPoint("TOPLEFT",x,-(height-39))
    end
    hero:Show();hero.caption:SetText((A.inspectRecipe and "SELECTED STEP" or "NEXT CRAFT")..(s.recipe and ("  ·  "..s.casts.." planned") or ""))
    hero.name:SetText(s.title);hero.detail:SetText(s.detail)
    hero.icon:SetTexture(s.recipe and spellIcon(s.recipe) or icons[A.profession])
    hero.badge:SetText(s.badge or (s.kind=="done" and "Complete" or "Getting started"))
    hero.badge:SetTextColor(unpack(s.kind=="ready" and C.green or C.amber))
    hero.primary:SetText(s.action or "Target reached");W.Enabled(hero.primary,s.action~=nil and not InCombatLockdown())
    hero.secondary:SetShown(s.recipe~=nil);hero.skip:SetShown(s.recipe~=nil)
    hero.back:SetShown(A.inspectRecipe~=nil)
    for i,b in ipairs(hero.materials) do
        local material=s.materials[i]
        b:SetShown(material~=nil)
        if material then
            b.icon:SetTexture(itemIcon(material.id))
            b.label:SetText(A.ItemName(material.id).."  "..material.have.." / "..material.need)
            b.label:SetTextColor(unpack(material.missing==0 and C.green or C.muted))
            b:SetScript("OnClick",function() priceItem(material.id) end)
        end
    end
    if s.recipe and #s.materials>4 then hero.badge:SetText((s.badge or "").." · +"..(#s.materials-4).." materials in recipe") end
    local y=height+16
    local h=heading(A.mode=="recipe" and "Crafting steps" or "Leveling route",y)
    local plan=A.plan
    h.right:SetText(plan and #plan.queue>0 and ("Shopping: "..A.Money(plan.cost)) or "")
    y=y+34
    local queue=plan and plan.queue or {}
    for index,step in ipairs(queue) do
        if index>1 or A.inspectRecipe then
            local recipe=A.ctx.recipes[step.recipe]
            local r=row(y,54)
            r.icon:SetTexture(spellIcon(recipe));r.title:SetText(recipe.name)
            r.detail:SetText(step.intermediate and "Prepare materials" or ("About "..string.format("%.1f",step.skillGain or 0).." skill"))
            r.right:SetText(step.casts.." crafts  >")
            r.hit:SetScript("OnClick",function() A.inspectRecipe=recipe.id;panel.scroll:SetVerticalScroll(0);A.Render() end)
            y=y+62
        end
    end
    if #queue==0 then
        local r=row(y,58);r.icon:Hide();r.title:SetText(s.kind=="prices" and "Load prices to compare routes" or "Your route will appear here")
        r.detail:SetText(s.kind=="prices" and "Use Find auction prices above, or click a material to set its price." or "Open your profession and choose a target skill.")
        y=y+66
    elseif A.route and not A.route.complete then
        local r=row(y,58);r.icon:Hide();r.title:SetText("More recipes or prices needed to continue")
        r.detail:SetText(A.route.blockedAt and ("This route reaches skill "..A.route.blockedAt..". Check your trainer for the next steps.") or "The available steps are shown. Visit a trainer or update auction prices.")
        y=y+66
    end
    if #(A.ranked or {})>1 then
        heading("Other recipes",y);y=y+34
        for index,entry in ipairs(A.ranked) do
            if index>4 then break end
            if not s.recipe or entry.recipe~=s.recipe.id then
                local recipe=A.ctx.recipes[entry.recipe]
                local r=row(y,54);r.icon:SetTexture(spellIcon(recipe));r.title:SetText(recipe.name)
                r.detail:SetText(string.format("%.0f%% estimated skill chance",entry.chance*100))
                r.right:SetText(A.Money(entry.expected).." / skill")
                r.hit:SetScript("OnClick",function() A.inspectRecipe=recipe.id;panel.scroll:SetVerticalScroll(0);A.Render() end)
                y=y+62
            end
        end
    end
    return y
end
local function shopping()
    local y=0
    local plan=A.plan
    heading("Material                                        Buy                 Source / estimated cost",y);y=y+36
    local list=plan and plan.shopping or {}
    for _,id in ipairs(A.SortedKeys(list)) do
        local entry=list[id]
        local r=row(y,58);r.icon:SetTexture(itemIcon(id));r.title:SetText(A.ItemName(id))
        r.detail:SetText("Click to set a price · already-owned materials are accounted for")
        r.right:SetText(entry.quantity.."  ·  "..(entry.source=="vendor" and "Vendor" or "Auction").."  ·  "..A.Money(entry.quantity*entry.unit))
        r.hit:SetScript("OnClick",function() priceItem(id) end);y=y+66
    end
    local state=M.Next()
    if not next(list) then
        if state.kind=="materials" and state.recipe then
            for _,entry in ipairs(state.materials) do
                if entry.missing>0 then
                    local r=row(y,58);r.icon:SetTexture(itemIcon(entry.id));r.title:SetText(A.ItemName(entry.id))
                    r.detail:SetText("Needed for one craft · click to set a price")
                    r.right:SetText(entry.missing.." needed")
                    r.hit:SetScript("OnClick",function() priceItem(entry.id) end);y=y+66
                end
            end
        elseif state.kind=="prices" then
            for _,id in ipairs(state.unknown or {}) do
                local r=row(y,58);r.icon:SetTexture(itemIcon(id));r.title:SetText(A.ItemName(id))
                r.detail:SetText("Price unknown · click to set a price");r.right:SetText("Set price  >")
                r.hit:SetScript("OnClick",function() priceItem(id) end);y=y+66
            end
        else
            local r=row(y,64);r.icon:Hide();r.title:SetText("Nothing to buy")
            r.detail:SetText(plan and #plan.queue>0 and "Your available materials cover the current plan." or "Choose a profession and build a route first.");y=y+72
        end
    end
    return y
end
local function disenchanting()
    local y=0
    local comparisons=A.DisenchantComparisons()
    heading("Craft cost  vs.  expected enchanting-material value",y);y=y+36
    for _,entry in ipairs(comparisons) do
        local recipe=A.ctx.recipes[entry.recipe]
        local r=row(y,64);r.icon:SetTexture(spellIcon(recipe));r.title:SetText(recipe.name)
        r.detail:SetText("Craft "..A.Money(entry.cost).."  ·  materials "..A.Money(entry.value))
        r.right:SetText((entry.saving>=0 and "+" or "-")..A.Money(math.abs(entry.saving)))
        r.hit:SetScript("OnClick",function() A.SelectRecipe(recipe.id) end);y=y+72
    end
    if #comparisons==0 then
        local r=row(y,72);r.icon:Hide();r.title:SetText("No disenchant comparisons yet")
        r.detail:SetText("Open Tailoring once and load enchanting-material prices in Auctionator.");y=y+80
    end
    return y
end
local function settings()
    for _,check in ipairs(panel.checks) do check:Show();check.check:SetChecked(A.db[check.key] or false) end
    panel.price:Show()
    local id=A.priceItem
    panel.price.name:SetText(id and A.ItemName(id) or "Choose a material")
    panel.price.hint:SetText(id and "Set the price for one item, or clear your override." or "Click a material on the Professions or Shopping list page.")
    for _,b in ipairs(panel.price.actions) do W.Enabled(b,id~=nil) end
    if id~=panel.price.item then
        local value=(id and A.db.prices[id]) or 0
        panel.price.gold.input:SetText(tostring(math.floor(value/10000)))
        panel.price.silver.input:SetText(tostring(math.floor(value/100)%100))
        panel.price.copper.input:SetText(tostring(value%100));panel.price.item=id
    end
    local y=342
    heading("Skipped recipes · click to restore",y);y=y+36
    for _,id in ipairs(A.SortedKeys(A.char.excluded)) do
        if A.char.excluded[id] then
            local recipe=A.Recipes[id]
            local r=row(y,54);r.icon:SetTexture(spellIcon(recipe));r.title:SetText(recipe and recipe.name or "Unknown recipe")
            r.detail:SetText("Restore this recipe to your recommendations");r.right:SetText("Restore  >")
            r.hit:SetScript("OnClick",function() A.char.excluded[id]=nil;A.Refresh() end);y=y+62
        end
    end
    return y
end
function A.Render()
    if not panel then return end
    resetRows();hero:Hide();panel.price:Hide()
    for _,f in ipairs(panel.checks) do f:Hide() end
    local titles={Professions="Your next craft, materials, and route to your target.",["Shopping list"]="Everything missing from your current plan.",Disenchanting="Compare tailoring crafts with buying enchanting materials.",Settings="Adjust planning and prices."}
    panel.title:SetText(page);panel.subtitle:SetText(titles[page])
    panel.nativeOptions:SetShown(page=="Settings")
    panel.goal:SetShown(page=="Professions");panel.mode:SetShown(page=="Professions");panel.amount:SetShown(page=="Professions" and A.mode=="recipe")
    for name,b in pairs(panel.nav) do W.Selected(b,page==name) end
    for _,tile in ipairs(panel.tiles) do
        tile:SetShown(page=="Professions")
        local p=tile.profession
        local skill=A.ctx and A.ctx.skills[p.id] or 0
        W.Selected(tile,A.profession==p.id)
        tile.skill:SetTextColor(unpack(A.profession==p.id and C.text or C.muted))
        tile.skill:SetText(A.char.scanned[p.id] and (skill.." / 300 · Azeroth") or "Open to load recipes")
    end
    panel.scroll:ClearAllPoints()
    panel.scroll:SetPoint("TOPLEFT",218,page=="Professions" and -190 or -90)
    panel.scroll:SetPoint("BOTTOMRIGHT",-30,62)
    panel.mode:SetText(A.mode=="recipe" and "Leveling mode" or "Use selected recipe")
    local height
    if page=="Professions" then height=professions()
    elseif page=="Shopping list" then height=shopping()
    elseif page=="Disenchanting" then height=disenchanting()
    else height=settings() end
    body:SetHeight(math.max(380,height+12))
    local status=A.status=="Calculating..." and "Updating your recommendations..." or "Estimates update as you craft."
    if InCombatLockdown() then status="Crafting controls are unavailable in combat." end
    if A.status and A.status:match("^Unable to calculate") then status="Could not update the plan. Try reopening your profession." end
    panel.status:SetText(status)
    panel.shop:SetShown(page=="Shopping list");panel.vendor:SetShown(page=="Shopping list")
    panel.compareNote:SetShown(page=="Disenchanting")
end
function A.CreateUI()
    panel=CreateFrame("Frame","CraftalotFrame",UIParent)
    A.frame=panel
    W.Surface(panel,900,620,C.background,{.12,.13,.16})
    panel:SetPoint("CENTER");panel:SetFrameStrata("DIALOG");panel:SetClampedToScreen(true)
    panel:EnableMouse(true);panel:SetMovable(true);panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart",panel.StartMoving);panel:SetScript("OnDragStop",panel.StopMovingOrSizing)
    table.insert(UISpecialFrames,"CraftalotFrame")
    local sidebar=W.Card(panel,10,10,184,600,C.sidebar)
    W.Icon(sidebar,16,18,28,"Interface\\Icons\\Trade_Blacksmithing")
    W.Text(sidebar,"Craftalot",54,16,122,17);W.Text(sidebar,"Profession companion",54,38,122,10,C.muted)
    W.Text(sidebar,"v"..A.version,16,569,156,10,C.muted)
    local close=W.Button(panel,"x",860,12,26,function() panel:Hide() end,false,24)
    panel.nav={}
    for index,name in ipairs({"Professions","Shopping list","Disenchanting","Settings"}) do
        panel.nav[name]=W.Button(sidebar,name,10,92+(index-1)*46,164,function() showPage(name) end,false,38)
        panel.nav[name].label:SetJustifyH("LEFT")
    end
    panel.title=W.Text(panel,"Professions",218,25,610,24)
    panel.subtitle=W.Text(panel,"",218,59,640,11,C.muted)
    panel.nativeOptions=W.Button(panel,"WoW settings",738,25,132,function() A.OpenOptions() end)
    panel.tiles={}
    for index,p in ipairs(A.Professions) do
        local tile=W.Button(panel,"",218+(index-1)*220,90,212,function()
            A.inspectRecipe=nil;A.mode="level";A.OpenProfession(p.id);A.Scan();A.Refresh()
        end,false,52)
        tile.profession=p;W.Icon(tile,10,10,30,icons[p.id])
        W.Text(tile,p.name,50,10,152,13);tile.skill=W.Text(tile,"",50,30,152,10,C.muted)
        panel.tiles[index]=tile
    end
    local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
    panel.scroll=scroll;scroll:SetPoint("TOPLEFT",218,-190);scroll:SetPoint("BOTTOMRIGHT",-30,62)
    body=CreateFrame("Frame",nil,scroll);body:SetSize(WIDTH,380);scroll:SetScrollChild(body)
    panel.goal=CreateFrame("Frame",nil,panel);panel.goal:SetPoint("TOPLEFT",218,-153);panel.goal:SetSize(310,28)
    W.Text(panel.goal,"Target skill",0,8,78,11,C.muted)
    panel.target=W.Edit(panel.goal,82,0,55,300,function(v) A.target=math.floor(math.max(1,math.min(300,tonumber(v) or 300)));A.Refresh() end)
    panel.mode=W.Button(panel,"Use selected recipe",516,152,157,function()
        if A.mode=="recipe" then A.mode="level"
        else
            local form=ProfessionsFrame and ProfessionsFrame.CraftingPage and ProfessionsFrame.CraftingPage.SchematicForm
            local info=form and form.GetRecipeInfo and form:GetRecipeInfo()
            if info and A.Recipes[info.recipeID] then A.selectedRecipe=info.recipeID end
            if not A.selectedRecipe then A.Message("Select a recipe in WoW's profession window first.");return end
            A.profession=A.Recipes[A.selectedRecipe].profession;A.mode="recipe"
        end
        A.inspectRecipe=nil;A.Refresh()
    end,false,28)
    panel.amount=W.Edit(panel,680,152,70,1,function(v) A.quantity=math.floor(math.max(1,math.min(1000,tonumber(v) or 1)));if A.mode=="recipe" then A.Refresh() end end)
    W.Text(panel.amount,"crafts",77,8,60,11,C.muted)
    buildHero()
    panel.checks={
        W.Check(body,"Include bank materials","Withdraw them to your bags before crafting.",0,0,"bank"),
        W.Check(body,"Preview recipes you haven't learned","Recipe purchase and training costs are not included.",0,68,"unlearned"),
        W.Check(body,"Open with your profession","Show Craftalot when you open a supported profession.",0,136,"autoShow")}
    panel.price=W.Card(body,0,214,WIDTH,112)
    panel.price.name=W.Text(panel.price,"",14,12,600,14)
    panel.price.hint=W.Text(panel.price,"",14,36,610,11,C.muted)
    panel.price.gold=W.Edit(panel.price,14,68,56,0,function() end)
    W.Text(panel.price,"g",74,76,20,12,C.muted)
    panel.price.silver=W.Edit(panel.price,94,68,56,0,function() end)
    W.Text(panel.price,"s",154,76,20,12,C.muted)
    panel.price.copper=W.Edit(panel.price,174,68,56,0,function() end)
    W.Text(panel.price,"c",234,76,20,12,C.muted)
    local save=W.Button(panel.price,"Save price",268,67,118,function()
        if A.priceItem then
            local g=tonumber(panel.price.gold.input:GetText()) or 0
            local s=tonumber(panel.price.silver.input:GetText()) or 0
            local c=tonumber(panel.price.copper.input:GetText()) or 0
            A.db.prices[A.priceItem]=math.max(0,g*10000+s*100+c);A.Refresh()
        end
    end,true)
    local clear=W.Button(panel.price,"Use market price",396,67,150,function()
        if A.priceItem then A.db.prices[A.priceItem]=nil;panel.price.item=nil;A.Refresh() end
    end)
    panel.price.actions={save,clear}
    panel.shop=W.Button(panel,"Send to Auctionator",218,574,174,A.ExportShopping,true)
    panel.vendor=W.Button(panel,"Buy vendor materials",402,574,174,A.BuyVendor)
    panel.status=W.Text(panel,"",218,606,640,10,C.muted)
    panel.compareNote=W.Text(panel,"Expected values only; actual disenchant yields vary.",218,567,644,11,C.muted)
    panel:Hide();panel:SetScript("OnShow",A.Schedule)
end

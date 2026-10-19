local addonName, A = ...
local E = A.Engine
local T = C_TradeSkillUI
local pending, job = false, 0
local requestedItems = {}

local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, result = pcall(fn, ...)
    if ok then return result end
end

function A.ItemName(id)
    local name = call(C_Item.GetItemNameByID, id)
    if not name and not requestedItems[id] and C_Item.RequestLoadItemDataByID then
        requestedItems[id]=true
        call(C_Item.RequestLoadItemDataByID,id)
    end
    return name or ("Item " .. id)
end

function A.Inventory(includeBank)
    includeBank=includeBank==true
    local stock = {}
    for _, r in pairs(A.Recipes) do
        for id in pairs(r.reagents) do
            stock[id] = call(C_Item.GetItemCount, id, includeBank, false, includeBank, includeBank) or 0
        end
        if r.item then stock[r.item] = call(C_Item.GetItemCount, r.item, includeBank, false, includeBank, includeBank) or 0 end
    end
    return stock
end

function A.Price(id)
    local manual = A.db.prices[id]
    if manual ~= nil then return {cost=manual,source="manual"} end
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    local auction = api and call(api.GetAuctionPriceByItemID, addonName, id)
    local vendor = A.db.vendors[id]
    if vendor and (not auction or vendor.cost <= auction) then return {cost=vendor.cost,source="vendor",seen=vendor.seen,pack=vendor.pack or 1} end
    if auction then
        local age = call(api.GetAuctionAgeByItemID, addonName, id)
        return {cost=auction,source="auction",age=age}
    end
end

function A.Scan()
    if not A.db then return end
    local base = call(T.GetBaseProfessionInfo)
    if not base then return end
    local profession = base.parentProfessionID or base.professionID
    local found = false
    for _, p in ipairs(A.Professions) do if p.id == profession then found=true end end
    if not found then return end
    for id, r in pairs(A.Recipes) do
        if r.profession == profession then
            local info = call(T.GetRecipeInfo, id)
            if info and info.recipeID == id then
                local cached = A.char.recipes[id] or {}
                cached.learned, cached.name = info.learned == true, info.name
                cached.disabled = info.disabled or info.isDummyRecipe or info.isGatheringRecipe
                cached.numSkillUps = math.max(1, info.numSkillUps or 1)
                cached.enchant = info.isEnchantingRecipe
                cached.requirements={}
                for _,requirement in ipairs(call(T.GetRecipeRequirements,id) or {}) do
                    if not requirement.met then cached.requirements[#cached.requirements+1]=requirement.name end
                end
                local schematic = call(T.GetRecipeSchematic, id, false)
                if schematic and schematic.reagentSlotSchematics then
                    local reagents, supported = {}, true
                    for _, slot in ipairs(schematic.reagentSlotSchematics) do
                        if slot.required then
                            if #slot.reagents ~= 1 or not slot.reagents[1].itemID then supported=false
                            else
                                local item = slot.reagents[1].itemID
                                reagents[item] = (reagents[item] or 0) + slot.quantityRequired
                            end
                        end
                    end
                    cached.unsupported = not supported or not next(reagents)
                    if supported and next(reagents) then cached.reagents=reagents end
                    cached.item = schematic.outputItemID or r.item
                    -- Minimum output is conservative for variable-yield recipes.
                    cached.quantity = math.max(1, schematic.quantityMin or 1)
                    cached.verified = true
                end
                A.char.recipes[id] = cached
            end
        end
    end
    A.char.scanned[profession] = time()
end

function A.Context()
    local recipes, prices, skills = {}, {}, {}
    for _, p in ipairs(A.Professions) do
        local info = call(T.GetProfessionInfoBySkillLineID, p.skillLine)
        if info and info.skillLevel then
            skills[p.id] = info.skillLevel
            A.char.skills[p.id] = info.skillLevel
            A.char.caps[p.id] = info.maxSkillLevel
        else skills[p.id] = A.char.skills[p.id] or 0 end
    end
    for id, base in pairs(A.Recipes) do
        local r = A.Copy(base)
        local cached = A.char.recipes[id]
        if cached then for key, value in pairs(cached) do r[key]=A.Copy(value) end end
        -- Never price an executable plan from an assumed output quantity.
        if not r.verified then r.unsupported=true end
        recipes[id] = r
        for item in pairs(r.reagents) do if prices[item] == nil then prices[item]=A.Price(item) end end
        if r.item then prices[r.item]=A.Price(r.item) end
    end
    return E.Context(recipes, prices, skills, A.char.excluded)
end

function A.Refresh()
    if not A.db or not A.frame or not A.frame:IsShown() then return end
    job = job + 1
    local generation = job
    A.status = "Calculating..."
    A.Render()
    local co = coroutine.create(function()
        local ctx = A.Context()
        local skill = ctx.skills[A.profession] or 0
        local stock = A.Inventory(A.db.bank)
        local target = math.max(skill, math.min(300, A.target or 300))
        local route, plan
        if A.mode == "recipe" then
            plan = E.NewPlan(stock)
            local r = ctx.recipes[A.selectedRecipe]
            if not r or not r.learned or r.unsupported then plan.error="Select a learned Azeroth recipe in the profession window first."
            else
                local ok, why = E.AppendCraft(plan, ctx, r.id, A.quantity or 1)
                if not ok then plan.error=why end
                E.Credit(plan,ctx)
            end
        elseif skill == 0 then
            plan=E.NewPlan(stock)
            plan.error="Open this profession in WoW to learn its current Azeroth skill and recipes."
        else
            ctx.tick = function() coroutine.yield() end
            route = E.Route(ctx,A.profession,skill,target,A.db.unlearned)
            plan = E.Materialize(route,ctx,stock)
        end
        local ranked = E.Rank(ctx,A.profession,skill,stock)
        A.ctx, A.route, A.plan, A.ranked = ctx,route,plan,ranked
        A.status = plan.error or (route and not route.complete and "No fully priced route to target. See missing prices / try a smaller target." or "Ready")
        A.Render()
    end)
    local function resume()
        if generation ~= job then return end
        local ok, why = coroutine.resume(co)
        if not ok then A.status="Unable to calculate: "..tostring(why); A.Render(); return end
        if coroutine.status(co) ~= "dead" then C_Timer.After(0,resume) end
    end
    resume()
end

function A.Schedule()
    if pending or not A.db then return end
    pending=true
    C_Timer.After(0.35,function() pending=false; A.Refresh() end)
end

function A.OpenProfession(id)
    if InCombatLockdown() then A.Message("Open professions after combat."); return end
    local p
    for _, entry in ipairs(A.Professions) do if entry.id == id then p=entry end end
    if p then
        A.profession = id
        local opened = call(T.OpenTradeSkill, p.skillLine)
        if not opened then call(T.OpenTradeSkill, id) end
        A.Schedule()
    end
end

function A.SelectRecipe(id)
    if InCombatLockdown() then A.Message("Open recipes after combat."); return false end
    local r = A.ctx and A.ctx.recipes[id]
    if not r then return false end
    A.OpenProfession(r.profession)
    local function select()
        local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
        local info = call(T.GetRecipeInfo,id)
        if page and page.SelectRecipe and info then page:SelectRecipe(info)
        else A.Message("Select "..r.name.." in the profession window.") end
    end
    C_Timer.After(0.2,select)
    return true
end

function A.CraftNext()
    if InCombatLockdown() or not A.plan or not A.ctx then return end
    local step = A.plan.queue[1]
    if not step then return end
    local r = A.ctx.recipes[step.recipe]
    local live = call(T.GetRecipeInfo,r.id)
    if not live or not live.learned then A.SelectRecipe(r.id); A.Message("Learn this recipe before crafting."); return end
    local info = call(T.GetBaseProfessionInfo)
    if not info or (info.parentProfessionID or info.professionID) ~= r.profession then
        A.SelectRecipe(r.id); A.Message("Profession opened. Click Craft one again."); return
    end
    for id, count in pairs(r.reagents) do
        if (call(C_Item.GetItemCount,id,false,false,false,false) or 0) < count then
            A.Message("Collect the reagents in your bags before crafting."); return
        end
    end
    for _,requirement in ipairs(call(T.GetRecipeRequirements,r.id) or {}) do
        if not requirement.met then
            A.SelectRecipe(r.id)
            A.Message("Recipe requirement: "..requirement.name)
            return
        end
    end
    if r.enchant or live.isEnchantingRecipe then
        A.SelectRecipe(r.id)
        A.Message("Use WoW's Create button and choose the item or vellum to enchant.")
        return
    end
    -- The only craft call is reached by this button's hardware click. Never
    -- craft from a timer or automatically resume after events.
    local ok, why = pcall(T.CraftRecipe,r.id,1)
    if not ok then A.Message(why) end
end

local function merchantInfo(index)
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then return C_MerchantFrame.GetItemInfo(index) end
    if GetMerchantItemInfo then
        local name,texture,price,count,available,purchasable,usable,extended=GetMerchantItemInfo(index)
        return {name=name,texture=texture,price=price,stackCount=count,numAvailable=available,
            isPurchasable=purchasable,isUsable=usable,hasExtendedCost=extended}
    end
end

function A.ScanVendor()
    if not A.db or not MerchantFrame or not MerchantFrame:IsShown() then return end
    for index=1,GetMerchantNumItems() do
        local link = GetMerchantItemLink(index)
        local id = link and tonumber(link:match("item:(%d+)"))
        local info=merchantInfo(index)
        if id and info and info.price and info.stackCount and info.stackCount > 0 and not info.hasExtendedCost and info.isPurchasable then
            A.db.vendors[id]={cost=info.price/info.stackCount,pack=info.stackCount,seen=time()}
        end
    end
    A.Schedule()
end

-- Each call buys only one currently visible merchant item, bounded by the
-- current plan, stock, money, and stack limit. Re-evaluate before another buy.
function A.BuyVendor()
    if InCombatLockdown() or not A.plan or not MerchantFrame or not MerchantFrame:IsShown() then
        A.Message("Open a reagent vendor first."); return
    end
    for index=1,GetMerchantNumItems() do
        local link = GetMerchantItemLink(index)
        local id = link and tonumber(link:match("item:(%d+)"))
        local wanted = id and A.plan.shopping[id]
        local info=merchantInfo(index)
        local price,pack,available=info and info.price,info and info.stackCount,info and info.numAvailable
        if wanted and wanted.source == "vendor" and info.isPurchasable and not info.hasExtendedCost and price and pack and pack > 0 then
            local units = math.min(wanted.quantity,GetMerchantItemMaxStack(index) or pack)
            if available and available >= 0 then units=math.min(units,available) end
            units=math.floor(units/pack)*pack
            if price > 0 then units=math.min(units,math.floor(GetMoney()/price)*pack) end
            if units > 0 then
                BuyMerchantItem(index,units)
                -- Invalidate immediately to prevent double-click overspending
                -- before the asynchronous bag update / replan arrives.
                A.plan=nil
                A.Schedule()
                return
            end
        end
    end
    A.Message("No planned vendor materials can be bought here. Refresh prices at this vendor.")
end

function A.ExportShopping()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    if not api or not api.CreateShoppingList or not api.ConvertToSearchString then
        A.Message("Install Auctionator for shopping lists; the Materials tab also lists everything."); return
    end
    local searches = {}
    for _, id in ipairs(A.SortedKeys(A.plan and A.plan.shopping or {})) do
        local row = A.plan.shopping[id]
        if row.source ~= "vendor" then
            local name = call(C_Item.GetItemNameByID,id)
            if not name then A.ItemName(id); A.Message("Item names are still loading. Try again shortly."); return end
            searches[#searches+1] = api.ConvertToSearchString(addonName,{searchString=name,isExact=true,quantity=row.quantity})
        end
    end
    if #searches == 0 then A.Message("No auction materials needed."); return end
    api.CreateShoppingList(addonName,"Craftalot materials",searches)
    A.Message("Created Auctionator list: Craftalot materials.")
end

function A.DisenchantComparisons()
    local api = Auctionator and Auctionator.API and Auctionator.API.v1
    local rows = {}
    if not api or not api.GetDisenchantPriceByItemID or not A.ctx then return rows end
    for _, id in ipairs(A.SortedKeys(A.ctx.recipes)) do
        local r = A.ctx.recipes[id]
        if r.profession == 197 and r.item and r.learned and not r.unsupported then
            local value = call(api.GetDisenchantPriceByItemID,addonName,r.item)
            local cost = E.CraftCost(r,A.ctx)
            if value and value > 0 and cost < math.huge then
                rows[#rows+1]={recipe=id,cost=cost,value=value*r.quantity,saving=value*r.quantity-cost}
            end
        end
    end
    table.sort(rows,function(a,b) return a.saving>b.saving end)
    return rows
end

local events = CreateFrame("Frame")
for _, name in ipairs({"ADDON_LOADED","TRADE_SKILL_SHOW","TRADE_SKILL_LIST_UPDATE","TRADE_SKILL_DATA_SOURCE_CHANGED",
    "SKILL_LINES_CHANGED","BAG_UPDATE_DELAYED","MERCHANT_SHOW","MERCHANT_UPDATE","PLAYER_REGEN_ENABLED",
    "TRADE_SKILL_ITEM_CRAFTED_RESULT","GET_ITEM_INFO_RECEIVED"}) do events:RegisterEvent(name) end
events:SetScript("OnEvent",function(_,event,arg)
    if event == "ADDON_LOADED" and arg == addonName then
        CraftalotDB = CraftalotDB or {}
        CraftalotCharacterDB = CraftalotCharacterDB or {}
        A.db,A.char = CraftalotDB,CraftalotCharacterDB
        A.db.prices,A.db.vendors = A.db.prices or {},A.db.vendors or {}
        A.char.recipes,A.char.skills = A.char.recipes or {},A.char.skills or {}
        A.char.caps,A.char.scanned = A.char.caps or {},A.char.scanned or {}
        A.char.excluded = A.char.excluded or {}
        A.profession,A.target,A.mode,A.quantity = 197,300,"level",1
        A.CreateUI()
    elseif not A.db then return
    elseif event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_LIST_UPDATE" or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" then
        A.Scan()
        if A.db.autoShow and event == "TRADE_SKILL_SHOW" then A.frame:Show() end
        A.Schedule()
    elseif event == "MERCHANT_SHOW" or event == "MERCHANT_UPDATE" then A.ScanVendor()
    elseif event ~= "ADDON_LOADED" then A.Schedule() end
end)

SLASH_CRAFTALOT1 = "/craftalot"
SLASH_CRAFTALOT2 = "/calot"
SlashCmdList.CRAFTALOT = function()
    if A.frame then A.frame:SetShown(not A.frame:IsShown()); if A.frame:IsShown() then A.Scan(); A.Refresh() end end
end

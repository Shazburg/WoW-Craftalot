-- Integration harness for documented Retail/Auctionator contracts. This is not
-- a substitute for loading the release in a running WoW client.
local A={}
local frames,timers,buttons,edits={},{},{},{}
local messages={}
local inventory={[2589]=20,[2320]=2}
local craftCalls,purchases,selections,lists={},{},{},{}
local combat=false
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local methods={}
local noop=function() end
for _,name in ipairs({"SetPoint","SetWidth","SetJustifyH","SetSize","SetHeight","SetFrameStrata","SetClampedToScreen",
    "SetBackdrop","SetBackdropColor","EnableMouse","SetMovable","RegisterForDrag","SetNumeric","SetAutoFocus",
    "SetHighlightTexture","StartMoving","StopMovingOrSizing","SetVerticalScroll","SetScrollChild","SetWordWrap"}) do methods[name]=noop end
function methods:SetScript(name,fn) self.scripts[name]=fn end
function methods:RegisterEvent(name) self.events[name]=true end
function methods:SetText(value) self.text=value end
function methods:GetText() return self.text or "" end
function methods:SetChecked(value) self.checked=value end
function methods:GetChecked() return self.checked end
function methods:ClearFocus() if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end end
function methods:Show() local old=self.shown;self.shown=true;if not old and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() self.shown=false end
function methods:SetShown(show) if show then self:Show() else self:Hide() end end
function methods:IsShown() return self.shown end
local function widget(kind)
    local w=setmetatable({kind=kind,scripts={},events={},shown=true},{__index=methods})
    if kind=="Button" then buttons[#buttons+1]=w elseif kind=="EditBox" then edits[#edits+1]=w end
    return w
end
function methods:CreateFontString() return widget("FontString") end
function CreateFrame(kind,name,parent,template)
    local w=widget(kind);w.template=template;w.parent=parent;frames[#frames+1]=w
    if name then _G[name]=w end
    return w
end
local function emit(event,arg)
    for _,frame in ipairs(frames) do
        if frame.events[event] then frame.scripts.OnEvent(frame,event,arg) end
    end
end
local function drain()
    local rounds=0
    while #timers>0 do
        rounds=rounds+1;assert(rounds<1000,"Timer loop")
        local batch=timers;timers={}
        for _,fn in ipairs(batch) do fn() end
    end
end
local function click(text)
    for _,b in ipairs(buttons) do if b.text==text and b.scripts.OnClick then b.scripts.OnClick(b);return end end
    error("Missing button "..text)
end
UIParent=widget("Frame");UISpecialFrames={};SlashCmdList={}
DEFAULT_CHAT_FRAME={AddMessage=function(_,msg) messages[#messages+1]=msg end}
C_Timer={After=function(_,fn) timers[#timers+1]=fn end}
function time() return 1792440000 end
function InCombatLockdown() return combat end
local openProfession=197
local schematics={
    [2963]={recipeID=2963,quantityMin=1,quantityMax=1,outputItemID=2996,reagentSlotSchematics={
        {required=true,reagents={{itemID=2589}},quantityRequired=2}}},
    [2385]={recipeID=2385,quantityMin=1,quantityMax=1,outputItemID=2568,reagentSlotSchematics={
        {required=true,reagents={{itemID=2996}},quantityRequired=1},
        {required=true,reagents={{itemID=2320}},quantityRequired=1}}},
    [7418]={recipeID=7418,quantityMin=1,quantityMax=1,reagentSlotSchematics={
        {required=true,reagents={{itemID=10940}},quantityRequired=1}}},
}
local infos={
    [2963]={recipeID=2963,name="Bolt of Linen Cloth",learned=true,numSkillUps=1},
    [2385]={recipeID=2385,name="Brown Linen Vest",learned=true,numSkillUps=1},
    [7418]={recipeID=7418,name="Enchant Bracer - Minor Health",learned=true,isEnchantingRecipe=true,numSkillUps=1},
}
C_TradeSkillUI={
    GetBaseProfessionInfo=function() return {professionID=openProfession} end,
    GetRecipeInfo=function(id)
        local info=infos[id]
        if info and A.Recipes[id].profession==openProfession then return info end
    end,
    GetRecipeSchematic=function(id,recraft) eq(recraft,false);return schematics[id] end,
    GetProfessionInfoBySkillLineID=function(id)
        if id==2540 then return {professionID=2540,skillLevel=1,maxSkillLevel=300}
        elseif id==2494 then return {professionID=2494,skillLevel=1,maxSkillLevel=300}
        else return {skillLevel=0,maxSkillLevel=0} end
    end,
    OpenTradeSkill=function(id)
        openProfession=({[2540]=197,[2494]=333,[2548]=185})[id] or id;return true
    end,
    CraftRecipe=function(id,count) eq(count,1);craftCalls[#craftCalls+1]=id end,
}
C_Item={
    GetItemNameByID=function(id) return ({[2589]="Linen Cloth",[2320]="Coarse Thread",[2996]="Bolt of Linen Cloth"})[id] or "Item "..id end,
    RequestLoadItemDataByID=noop,
    GetItemCount=function(id,bank,uses,reagentBank,accountBank)
        eq(uses,false)
        assert(type(bank)=="boolean" and type(reagentBank)=="boolean" and type(accountBank)=="boolean")
        return inventory[id] or 0
    end,
}
Auctionator={API={v1={
    GetAuctionPriceByItemID=function(caller,id) eq(caller,"Craftalot");return ({[2589]=10,[2320]=100,[2996]=1000,[10940]=25})[id] end,
    GetAuctionAgeByItemID=function() return 2 end,
    GetDisenchantPriceByItemID=function() return 50 end,
    ConvertToSearchString=function(caller,row) eq(caller,"Craftalot");assert(row.isExact);return row.searchString.."/"..row.quantity end,
    CreateShoppingList=function(caller,name,terms) lists[#lists+1]={caller=caller,name=name,terms=terms} end,
}}}
MerchantFrame=widget("Frame")
function GetMerchantNumItems() return 2 end
function GetMerchantItemLink(index) return index==1 and "item:2320" or "item:9999" end
C_MerchantFrame={GetItemInfo=function(index)
    return {name="Coarse Thread",price=10,stackCount=1,numAvailable=-1,isPurchasable=true,hasExtendedCost=index==2}
end}
function GetMerchantItemMaxStack() return 200 end
function GetMoney() return 1000 end
function BuyMerchantItem(index,quantity) purchases[#purchases+1]={index,quantity} end
ProfessionsFrame={CraftingPage={SelectRecipe=function(_,info)
    assert(type(info)=="table" and info.recipeID,"Retail expects a recipeInfo table")
    selections[#selections+1]=info.recipeID
end}}
for _,file in ipairs({"Core/Bootstrap.lua","Data/Recipes.lua","Core/Engine.lua","Core/Client.lua","UI/Panel.lua"}) do
    assert(loadfile(file))("Craftalot",A)
end
emit("ADDON_LOADED","Craftalot")
eq(A.frame:IsShown(),false)
eq(A.Professions[2].skillLine,2494)
SlashCmdList.CRAFTALOT();drain()
assert(A.frame:IsShown());assert(A.ctx.recipes[2963].learned)
eq(A.ctx.recipes[2963].quantity,1)
A.target=3;A.Refresh();drain()
assert(A.route.complete);assert(#A.plan.queue>0)
eq(A.plan.cost,0)
local countBefore=#frames
for _=1,10 do A.Render() end
eq(#frames,countBefore) -- UI rows are reused rather than leaked.
A.SelectRecipe(2963);drain();eq(selections[#selections],2963)
A.CraftNext();eq(craftCalls[1],2963)
local count=#craftCalls;emit("BAG_UPDATE_DELAYED");drain();eq(#craftCalls,count)
combat=true;A.CraftNext();eq(#craftCalls,count);combat=false
inventory={};A.Refresh();drain()
A.ExportShopping();eq(lists[1].name,"Craftalot materials");assert(#lists[1].terms>0)
emit("MERCHANT_SHOW");drain();eq(A.db.vendors[2320].cost,10);eq(A.db.vendors[9999],nil)
A.plan={shopping={[2320]={quantity=12,source="vendor",unit=10}},queue={}}
A.BuyVendor();eq(purchases[1][1],1);eq(purchases[1][2],12)
A.BuyVendor();eq(#purchases,1) -- rapid repeated clicks cannot buy twice.
drain()
click("Materials");click("Settings");click("Plan")
openProfession=333;inventory={[10940]=3};A.Scan();A.profession=333;A.target=2;A.Refresh();drain()
assert(A.plan.queue[1]);A.CraftNext();drain();eq(#craftCalls,count);eq(selections[#selections],7418)
A.db.prices[10940]=0;eq(A.Price(10940).cost,0)
A.char.excluded[7418]=true;A.Refresh();drain();eq(A.route.complete,false)
print("PASS Retail loading, frame lifecycle, scans, planning, inventory, crafting clicks, combat, enchants, shopping, vendor safety, settings, exclusions")

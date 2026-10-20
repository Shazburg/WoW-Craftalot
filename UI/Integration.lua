local _, A = ...

function A.OpenUI()
    if not A.frame then return end
    A.frame:Show()
    A.Scan()
    A.Refresh()
end

function A.ToggleUI()
    if not A.frame then return end
    if A.frame:IsShown() then A.frame:Hide() else A.OpenUI() end
end

function A.OpenOptions()
    if A.settingsCategory and Settings and Settings.OpenToCategory then
        A.frame:Hide()
        Settings.OpenToCategory(A.settingsCategory:GetID())
    end
end

function A.UpdateProfessionButton()
    if not A.db or not ProfessionsFrame or InCombatLockdown() then return end
    if not A.professionButton then
        local b=A.Widgets.Button(ProfessionsFrame,"Craftalot",0,0,104,A.ToggleUI,true,24)
        b:ClearAllPoints()
        local anchor=ProfessionsFrame.MaximizeMinimize or ProfessionsFrame.CloseButton
        if anchor then b:SetPoint("RIGHT",anchor,"LEFT",-8,0)
        else b:SetPoint("TOPRIGHT",-92,-6) end
        A.professionButton=b
    end
    A.professionButton:SetShown(A.db.showProfessionButton~=false)
end

function A.InitializeUIAccess()
    if not A.db then return end
    A.UpdateProfessionButton()
    if A.settingsCategory or not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    local canvas=CreateFrame("Frame")
    canvas.name="Craftalot"
    A.optionsPanel=canvas
    local W=A.Widgets
    W.Text(canvas,"Craftalot",20,20,560,22)
    W.Text(canvas,"Profession planning, crafting, and material shopping.",20,54,560,12,W.colors.muted)
    local function open(page)
        if SettingsPanel then
            if HideUIPanel then HideUIPanel(SettingsPanel) else SettingsPanel:Hide() end
        end
        A.OpenUI()
        if page and A.ShowPage then A.ShowPage(page) end
    end
    W.Button(canvas,"Open Craftalot",20,88,156,function() open("Professions") end,true)
    W.Button(canvas,"Prices and recipes",188,88,164,function() open("Settings") end)
    local fields={
        {key="showProfessionButton",title="Show the Craftalot button in professions",detail="Open or close Craftalot from the profession window's title bar."},
        {key="autoShow",title="Open Craftalot with a profession",detail="Automatically show the companion when you open a supported profession."},
        {key="bank",title="Include bank materials in plans",detail="Withdraw the required materials into your bags before crafting."},
        {key="unlearned",title="Preview recipes you have not learned",detail="Recipe purchase and training costs are not included."},
    }
    canvas.controls={}
    for index,field in ipairs(fields) do
        local y=146+(index-1)*68
        local check=CreateFrame("CheckButton",nil,canvas,"UICheckButtonTemplate")
        check:SetPoint("TOPLEFT",20,-y);check:SetSize(26,26)
        W.Text(canvas,field.title,56,y+3,520,13)
        W.Text(canvas,field.detail,56,y+26,520,11,W.colors.muted)
        check:SetScript("OnClick",function(self)
            A.db[field.key]=self:GetChecked() and true or false
            A.UpdateProfessionButton()
            A.Schedule()
        end)
        canvas.controls[field.key]=check
    end
    canvas:SetScript("OnShow",function()
        for key,check in pairs(canvas.controls) do check:SetChecked(A.db[key] and true or false) end
    end)
    A.settingsCategory=Settings.RegisterCanvasLayoutCategory(canvas,"Craftalot")
    Settings.RegisterAddOnCategory(A.settingsCategory)
end

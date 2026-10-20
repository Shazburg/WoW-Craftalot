local _, A = ...
local W={}
A.Widgets=W
W.colors={background={.038,.041,.053},sidebar={.062,.066,.085},card={.086,.091,.118},
    button={.118,.124,.156},line={.145,.151,.184},accent={.91,.25,.21},
    text={.91,.92,.95},muted={.55,.59,.67},green={.48,.78,.59},amber={.96,.72,.39}}
local C=W.colors
local media="Interface\\AddOns\\Craftalot\\UI\\Media\\"

local function tint(texture,color,alpha) texture:SetVertexColor(color[1],color[2],color[3],alpha or 1) end
local function patches(parent,path,color,width,height,layer,existing)
    local pieces=existing or {}
    local x,y={0,6,width-6,width},{0,6,height-6,height}
    local uv={0,.25,.75,1}
    local i=0
    for row=1,3 do for col=1,3 do
        i=i+1
        local t=pieces[i] or parent:CreateTexture(nil,layer)
        t:SetTexture(media..path);t:ClearAllPoints()
        t:SetPoint("TOPLEFT",x[col],-y[row]);t:SetSize(x[col+1]-x[col],y[row+1]-y[row])
        t:SetTexCoord(uv[col],uv[col+1],uv[row],uv[row+1]);tint(t,color)
        pieces[i]=t
    end end
    return pieces
end
function W.Surface(frame,width,height,color,border)
    frame:SetSize(width,height)
    frame.fill=patches(frame,"Round",color,width,height,"BACKGROUND",frame.fill)
    frame.edge=patches(frame,"Border",border or C.line,width,height,"BORDER",frame.edge)
end
function W.Card(parent,x,y,width,height,color)
    local f=CreateFrame("Frame",nil,parent)
    f:SetPoint("TOPLEFT",x,-y)
    W.Surface(f,width,height,color or C.card)
    return f
end
function W.Text(parent,text,x,y,width,size,color)
    local f=parent:CreateFontString(nil,"OVERLAY")
    f:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF",size or 12,"")
    f:SetPoint("TOPLEFT",x,-y);f:SetWidth(width);f:SetJustifyH("LEFT");f:SetWordWrap(false)
    f:SetTextColor(unpack(color or C.text));f:SetText(text or "")
    return f
end
function W.Icon(parent,x,y,size,texture)
    local icon=parent:CreateTexture(nil,"ARTWORK")
    icon:SetPoint("TOPLEFT",x,-y);icon:SetSize(size,size)
    icon:SetTexture(texture or 134400);icon:SetTexCoord(.07,.93,.07,.93)
    return icon
end
function W.Button(parent,text,x,y,width,fn,primary,height)
    local b=CreateFrame("Button",nil,parent)
    b:SetPoint("TOPLEFT",x,-y);b:SetScript("OnClick",fn)
    b.primary=primary;b.width=width;b.height=height or 30
    b.caption=text
    b.label=W.Text(b,text,10,(b.height-12)/2,width-20,12)
    b.label:SetJustifyH("CENTER")
    function b:SetText(value) self.label:SetText(value);self.caption=value end
    function b:Paint(selected)
        W.Surface(self,self.width,self.height,selected and C.accent or (self.primary and C.accent or C.button),selected and C.accent or C.line)
    end
    b:Paint(false)
    b:SetScript("OnEnter",function(self) for _,t in ipairs(self.fill) do tint(t,(self.primary or self.selected) and {1,.32,.26} or {.17,.18,.22}) end end)
    b:SetScript("OnLeave",function(self) self:Paint(self.selected) end)
    return b
end
function W.Selected(button,selected)
    button.selected=selected;button:Paint(selected)
end
function W.Enabled(button,enabled)
    button:SetEnabled(enabled)
    button:SetAlpha(enabled and 1 or .45)
end
function W.Edit(parent,x,y,width,value,fn)
    local box=W.Card(parent,x,y,width,28,C.background)
    local e=CreateFrame("EditBox",nil,box)
    e:SetPoint("TOPLEFT",8,-2);e:SetSize(width-16,24);e:SetAutoFocus(false);e:SetNumeric(true)
    e:SetFontObject("GameFontHighlight");e:SetText(tostring(value or ""))
    e:SetScript("OnEnterPressed",function(self) self:ClearFocus() end)
    e:SetScript("OnEditFocusLost",function(self) fn(self:GetText()) end)
    e:SetScript("OnEscapePressed",function(self) self:ClearFocus() end)
    box.input=e
    return box
end
function W.Check(parent,text,detail,x,y,key)
    local frame=W.Card(parent,x,y,632,58)
    W.Text(frame,text,14,11,552,13)
    W.Text(frame,detail,14,32,552,11,C.muted)
    local b=CreateFrame("CheckButton",nil,frame,"UICheckButtonTemplate")
    b:SetPoint("TOPRIGHT",-12,-13);b:SetSize(26,26)
    b:SetScript("OnClick",function(self) A.db[key]=self:GetChecked() and true or false;A.Refresh() end)
    frame.check=b;frame.key=key
    return frame
end

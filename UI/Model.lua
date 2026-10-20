local _, A = ...
local E=A.Engine
local M={}
A.Presentation=M
function M.Profession(id)
    for _,p in ipairs(A.Professions) do if p.id==id then return p end end
    return A.Professions[1]
end
function M.Next()
    local ctx=A.ctx
    local p=M.Profession(A.profession)
    local skill=ctx and ctx.skills[p.id] or 0
    local state={profession=p,skill=skill,target=A.target or 300,kind="scan",
        title="Open "..p.name.." to get started",detail="Your recipes and skill will load from the profession window.",
        action="Open "..p.name,materials={}}
    if not ctx or not A.char.scanned[p.id] then return state end
    if A.mode~="recipe" and not A.inspectRecipe and skill>=state.target then
        state.kind="done";state.title="Target reached"
        state.detail="Choose a higher target or craft a specific recipe.";state.action=nil
        return state
    end
    local step=A.plan and A.plan.queue[1]
    local best=A.ranked and A.ranked[1]
    local id=A.inspectRecipe or (A.mode=="recipe" and A.selectedRecipe) or (step and step.recipe) or (best and best.recipe)
    if id and (not ctx.recipes[id] or ctx.recipes[id].unsupported) then id=nil end
    if not id then
        if skill>=state.target then
            state.kind="done";state.title="Target reached";state.detail="Choose a higher target or craft a specific recipe.";state.action=nil
            return state
        end
        local candidates={}
        for _,r in pairs(ctx.recipes) do
            if r.profession==p.id and E.Eligible(r,ctx,skill,false) and E.Chance(r,skill)>0 then
                local _,missing=E.CraftCost(r,ctx)
                candidates[#candidates+1]={recipe=r,missing=missing}
            end
        end
        table.sort(candidates,function(a,b)
            if #a.missing==#b.missing then return a.recipe.id<b.recipe.id end
            return #a.missing<#b.missing
        end)
        if #candidates==0 then
            state.kind="blocked";state.title="No skill-up recipes available"
            state.detail="Check your trainer for new recipes, or enable unlearned previews in Settings."
            state.action="Open "..p.name;return state
        end
        id=candidates[1].recipe.id
        state.unknown=candidates[1].missing
    end
    local r=ctx.recipes[id]
    state.recipe=r;state.title=r.name;state.casts=step and step.casts or 1
    if A.mode=="recipe" and (not A.plan or #A.plan.queue==0) then
        local _,missing=E.CraftCost(r,ctx);if #missing>0 then state.unknown=missing end
    end
    state.chance=E.Chance(r,skill)
    local bags=A.Inventory(false)
    local ready=true
    for _,item in ipairs(A.SortedKeys(r.reagents)) do
        local have=bags[item] or 0
        local need=r.reagents[item]
        if have<need then ready=false end
        state.materials[#state.materials+1]={id=item,have=have,need=need,missing=math.max(0,need-have)}
    end
    local ranked
    for _,row in ipairs(A.ranked or {}) do if row.recipe==id then ranked=row;break end end
    if skill<r.difficulty[1] then
        state.kind="locked";state.action="Open recipe";state.badge="Requires skill "..r.difficulty[1]
        state.detail="This is an upcoming recipe. Continue the earlier steps first."
    elseif state.unknown and #state.unknown>0 then
        state.kind="prices";state.action="Find auction prices";state.badge="Prices needed"
        state.detail="A material price is missing. Search the auction house or click a material to set its price."
    elseif not r.learned then
        state.kind="learn";state.action="Open recipe";state.badge="Learn recipe first"
        state.detail="Obtain this recipe before crafting. Recipe purchase costs are not included."
    elseif r.requirements and #r.requirements>0 then
        state.kind="requirement";state.action="Open recipe";state.badge=r.requirements[1]
        state.detail="Prepare the required tool or crafting station before crafting."
    elseif ready then
        state.kind="ready";state.action=r.enchant and "Open enchant" or "Craft one";state.badge="Ready to craft"
    else
        state.kind="materials";state.action="Get materials";state.badge="Materials needed"
    end
    if not state.unknown then
        local cost,unknown=E.CraftCost(r,ctx)
        if cost==math.huge and not ready and r.learned and state.kind~="locked" then
            state.unknown=unknown;state.kind="prices";state.action="Find auction prices";state.badge="Prices needed"
            state.detail="Search the auction house or click a material to set its price."
        end
    end
    if not state.detail or state.kind=="ready" or state.kind=="materials" then
        state.detail=(ranked and (A.Money(ranked.expected).." / skill") or "Dependent craft")
            ..string.format("  ·  %.0f%% estimated skill chance",state.chance*100)
    end
    return state
end

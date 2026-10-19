-- Pure Lua 5.1 model. No game APIs, globals, saved variables, or network calls.
local _, A = ...
local E = {}
A.Engine = E
local INF = math.huge

-- Blizzard exposes difficulty bands, not exact skill-up probabilities. This
-- explicitly estimated linear model is replaceable, not a claim about RNG.
function E.Chance(recipe, skill)
    local d = recipe.difficulty
    if not d or skill < d[1] or skill >= d[4] then return 0 end
    if skill < d[2] then return 1 end
    if d[4] <= d[2] then return 0 end
    return math.max(0, math.min(1, (d[4]-skill)/(d[4]-d[2])))
end

function E.Eligible(r, ctx, skill, includeUnlearned)
    return not (ctx.excluded or {})[r.id] and not r.disabled and not r.unsupported
        and (r.learned or includeUnlearned) and skill >= r.difficulty[1]
end

-- Cycles are evaluated per recursion path; never cache an infinity discovered
-- through a cycle. Recipes requiring future skills are not procurement options.
function E.Unit(item, ctx, visiting)
    visiting = visiting or {}
    local quote = (ctx.prices or {})[item]
    local best = quote and quote.cost or INF
    local method = quote and quote.source or nil
    if visiting[item] then return best, method end
    visiting[item] = true
    for _, id in ipairs(ctx.producers[item] or {}) do
        local r = ctx.recipes[id]
        if E.Eligible(r, ctx, (ctx.skills or {})[r.profession] or 0, false) then
            local cost = 0
            for reagent, quantity in pairs(r.reagents) do
                cost = cost + quantity * E.Unit(reagent, ctx, visiting)
            end
            cost = cost / r.quantity
            if cost < best then best, method = cost, id end
        end
    end
    visiting[item] = nil
    return best, method
end

function E.Context(recipes, prices, skills, excluded)
    local ctx = {recipes=recipes, prices=prices or {}, skills=skills or {}, excluded=excluded or {}, producers={}}
    for _, id in ipairs(A.SortedKeys(recipes)) do
        local r = recipes[id]
        if r.item and r.quantity and r.quantity > 0 then
            ctx.producers[r.item] = ctx.producers[r.item] or {}
            table.insert(ctx.producers[r.item], id)
        end
    end
    return ctx
end

function E.CraftCost(r, ctx)
    local cost, missing = 0, {}
    for item, qty in pairs(r.reagents) do
        local unit = E.Unit(item, ctx)
        if unit == INF then missing[#missing+1] = item else cost = cost + unit * qty end
    end
    table.sort(missing)
    return #missing == 0 and cost or INF, missing
end

-- Bellman recurrence over skill points, including failed attempts:
-- V(s)=min_r{cost(r)/p(r,s) + V(s+numSkillUps)}.
-- This is an optimal expected-cost path for the declared stationary unit-price
-- model, not an exact stochastic inventory / finite-auction optimizer.
function E.Route(ctx, profession, start, target, includeUnlearned)
    start, target = math.floor(start), math.floor(target)
    local value, choice, costs = {[target]=0}, {}, {}
    local candidates, unknown = {}, {}
    local model = A.Copy(ctx)
    -- Future-level recipes can supply their own intermediates at that level.
    for _, id in ipairs(A.SortedKeys(ctx.recipes)) do
        local r = ctx.recipes[id]
        if r.profession == profession then candidates[#candidates+1] = r end
    end
    for skill=target-1,start,-1 do
        if ctx.tick and skill % 5 == 0 then ctx.tick() end
        value[skill] = INF
        model.skills[profession] = skill
        costs[skill] = {}
        for _, r in ipairs(candidates) do
            local chance = E.Chance(r, skill)
            if chance > 0 and E.Eligible(r, ctx, skill, includeUnlearned) then
                local cost, missing = E.CraftCost(r, model)
                for _, item in ipairs(missing) do unknown[item] = true end
                local nextSkill = math.min(target, skill + math.max(1, r.numSkillUps or 1))
                local total = cost/chance + (value[nextSkill] or INF)
                costs[skill][r.id] = cost/chance
                if total < value[skill] then value[skill], choice[skill] = total, r.id end
            end
        end
    end
    local steps, skill = {}, start
    while skill < target and choice[skill] do
        local r = ctx.recipes[choice[skill]]
        local casts = 1/E.Chance(r, skill)
        steps[#steps+1] = {recipe=r.id, casts=casts, from=skill,
            to=math.min(target, skill + math.max(1, r.numSkillUps or 1)), costPerPoint=costs[skill][r.id]}
        skill = steps[#steps].to
    end
    if skill == start and start < target then
        -- A distant training gap must not suppress useful crafts available now.
        -- Find the highest reachable prefix, then solve that prefix optimally.
        local reachable,furthest={[start]=true},start
        for current=start,target-1 do
            if reachable[current] then
                for _,r in ipairs(candidates) do
                    local cost=costs[current] and costs[current][r.id]
                    if cost and cost < INF then
                        local nextSkill=math.min(target,current+math.max(1,r.numSkillUps or 1))
                        reachable[nextSkill]=true;furthest=math.max(furthest,nextSkill)
                    end
                end
            end
        end
        if furthest>start and furthest<target then
            local partial=E.Route(ctx,profession,start,furthest,includeUnlearned)
            partial.complete=false;partial.partialCost=partial.expectedCost;partial.expectedCost=INF
            partial.target=target;partial.blockedAt=furthest;partial.unknown=A.SortedKeys(unknown)
            return partial
        end
    end
    return {steps=steps, expectedCost=value[start] or 0, complete=skill >= target,
        unknown=A.SortedKeys(unknown), start=start, target=target, profession=profession,
        value=value, choices=choice}
end

-- Expand a concrete quantity with whole-cast rounding and shared inventory.
-- Both buying and crafting are compared at the requested quantity, including
-- batch surplus. A caller gets a transactional plan: failed branches consume
-- no stock. Dependency casts precede parents and retain skill-credit metadata.
local function adopt(target, source)
    for key in pairs(target) do target[key] = nil end
    for key, value in pairs(source) do target[key] = value end
end

local function need(item, quantity, ctx, plan, visiting)
    local have = math.min(plan.stock[item] or 0, quantity)
    plan.stock[item] = (plan.stock[item] or 0) - have
    quantity = quantity - have
    if quantity <= 0 then return true end
    local base = A.Copy(plan)
    local quote = ctx.prices[item]
    local best
    if quote and quote.cost >= 0 then
        best = A.Copy(base)
        local purchased=math.ceil(quantity/(quote.pack or 1))*(quote.pack or 1)
        best.cost = best.cost + quote.cost*purchased
        best.stock[item]=(best.stock[item] or 0)+purchased-quantity
        local purchase = best.shopping[item] or {quantity=0,source=quote.source,unit=quote.cost}
        purchase.quantity = purchase.quantity + purchased
        best.shopping[item] = purchase
    end
    if not visiting[item] then
        visiting[item] = true
        for _, id in ipairs(ctx.producers[item] or {}) do
            local r = ctx.recipes[id]
            if E.Eligible(r, ctx, (ctx.skills or {})[r.profession] or 0, false) then
                local branch, valid = A.Copy(base), true
                local casts = math.ceil(quantity/r.quantity)
                for _, reagent in ipairs(A.SortedKeys(r.reagents)) do
                    if not need(reagent, r.reagents[reagent]*casts, ctx, branch, visiting) then valid=false; break end
                end
                if valid then
                    branch.stock[item] = (branch.stock[item] or 0) + casts*r.quantity-quantity
                    branch.queue[#branch.queue+1] = {recipe=id,casts=casts,intermediate=true}
                    if not best or branch.cost < best.cost then best=branch end
                end
            end
        end
        visiting[item] = nil
    end
    if not best then
        plan.unknown[item] = (plan.unknown[item] or 0) + quantity
        return false
    end
    adopt(plan, best)
    return true
end

function E.NewPlan(stock)
    return {stock=A.Copy(stock or {}),shopping={},queue={},cost=0,unknown={},credits={}}
end

function E.AppendCraft(plan, ctx, recipeID, casts)
    local r = ctx.recipes[recipeID]
    if not r or casts < 1 then return false, "Invalid recipe or quantity" end
    local branch = A.Copy(plan)
    for _, item in ipairs(A.SortedKeys(r.reagents)) do
        if not need(item, casts*r.reagents[item], ctx, branch, {}) then
            return false, "Missing price for item " .. item
        end
    end
    branch.queue[#branch.queue+1] = {recipe=recipeID,casts=casts,intermediate=false}
    if r.item then branch.stock[r.item] = (branch.stock[r.item] or 0) + casts*r.quantity end
    adopt(plan, branch)
    return true
end

function E.Credit(plan, ctx)
    local skills = A.Copy(ctx.skills)
    for _, step in ipairs(plan.queue) do
        local r = ctx.recipes[step.recipe]
        local skill = skills[r.profession] or 0
        local before = skill
        -- Integrate the estimated gain across the batch rather than treating
        -- every intermediate as orange for its entire duration.
        for _=1,step.casts do
            skill = skill + E.Chance(r, skill)*math.max(1, r.numSkillUps or 1)
        end
        skills[r.profession] = skill
        step.skillGain = skill-before
    end
    for profession, skill in pairs(skills) do plan.credits[profession] = skill-(ctx.skills[profession] or 0) end
end

function E.Materialize(route, ctx, stock)
    local plan = E.NewPlan(stock)
    local groups = {}
    for _, step in ipairs(route.steps) do
        local group = groups[#groups]
        if group and group.recipe == step.recipe then group.casts=group.casts+step.casts; group.to=step.to
        else groups[#groups+1]={recipe=step.recipe,casts=step.casts,to=step.to} end
    end
    local model=A.Copy(ctx)
    for _, step in ipairs(groups) do
        E.Credit(plan,ctx)
        local current=route.start+(plan.credits[route.profession] or 0)
        if current < step.to then
            model.skills[route.profession]=current
            local casts=math.ceil(step.casts-0.000001)
            -- Dependent crafts can contribute points themselves. Find the
            -- smallest whole batch that reaches this segment's expected end.
            local lower,upper,best=1,casts,nil
            while lower<=upper do
                local mid=math.floor((lower+upper)/2)
                local trial=A.Copy(plan)
                local ok,why=E.AppendCraft(trial,model,step.recipe,mid)
                if not ok then plan.error=why; break end
                E.Credit(trial,ctx)
                if route.start+(trial.credits[route.profession] or 0)>=step.to-0.000001 then
                    best=trial; upper=mid-1
                else lower=mid+1 end
            end
            if plan.error then break end
            if best then plan=best
            else
                local ok,why=E.AppendCraft(plan,model,step.recipe,casts)
                if not ok then plan.error=why; break end
            end
        end
    end
    E.Credit(plan, ctx)
    return plan
end

function E.Rank(ctx, profession, skill, stock)
    local ranked = {}
    for _, id in ipairs(A.SortedKeys(ctx.recipes)) do
        local r = ctx.recipes[id]
        local p = E.Chance(r, skill)
        if r.profession == profession and p > 0 and E.Eligible(r, ctx, skill, false) then
            local plan = E.NewPlan(stock)
            if E.AppendCraft(plan, ctx, id, 1) then
                ranked[#ranked+1] = {recipe=id,cost=plan.cost,expected=plan.cost/(p*math.max(1,r.numSkillUps or 1)),chance=p}
            end
        end
    end
    table.sort(ranked,function(a,b) if a.expected==b.expected then return a.recipe < b.recipe end return a.expected < b.expected end)
    return ranked
end

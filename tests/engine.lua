local A={}
assert(loadfile("Core/Bootstrap.lua"))("Craftalot",A)
assert(loadfile("Core/Engine.lua"))("Craftalot",A)
local E=A.Engine
local passed=0
local function test(name,fn)
    local ok,why=pcall(fn)
    if not ok then error(name..": "..tostring(why)) end
    passed=passed+1; print("PASS "..name)
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function near(a,b) assert(math.abs(a-b)<0.000001,tostring(a).." ~= "..tostring(b)) end
local function recipe(id,item,reagents,difficulty,quantity,profession)
    return {id=id,name="Recipe "..id,item=item,reagents=reagents,difficulty=difficulty or {1,10,15,20},
        quantity=quantity or 1,profession=profession or 197,learned=true}
end
local function context(rs,ps,skill)
    return E.Context(rs,ps,{[197]=skill or 1,[333]=1},{})
end
test("skill-up boundaries and estimated decline",function()
    local r=recipe(1,2,{[1]=1},{1,10,15,20})
    eq(E.Chance(r,0),0);eq(E.Chance(r,1),1);eq(E.Chance(r,10),1)
    near(E.Chance(r,15),0.5);eq(E.Chance(r,20),0)
end)
test("unknown prices never become free",function()
    local ctx=context({[1]=recipe(1,2,{[1]=1})},{})
    local route=E.Route(ctx,197,1,3)
    eq(route.complete,false);eq(route.expectedCost,math.huge);eq(route.unknown[1],1)
end)
test("failure probability uses expected attempts",function()
    local ctx=context({[1]=recipe(1,2,{[1]=1},{1,1,2,3})},{[1]={cost=10,source="auction"}},2)
    local route=E.Route(ctx,197,2,3)
    near(route.expectedCost,20);near(route.steps[1].casts,2)
end)
test("a training gap preserves the optimal reachable prefix",function()
    local ctx=context({[1]=recipe(1,20,{[10]=1},{1,1,2,3})},{[10]={cost=10}})
    local route=E.Route(ctx,197,1,10)
    eq(route.complete,false);eq(route.target,10);eq(route.blockedAt,3)
    eq(#route.steps,2);eq(route.partialCost,30)
    eq(route.expectedCost,math.huge)
end)
test("unlearned and excluded recipes require opt-in",function()
    local r=recipe(1,2,{[1]=1});r.learned=false
    local ctx=context({[1]=r},{[1]={cost=10}})
    eq(E.Route(ctx,197,1,2).complete,false)
    eq(E.Route(ctx,197,1,2,true).complete,true)
    ctx.excluded[1]=true
    eq(E.Route(ctx,197,1,2,true).complete,false)
end)
test("multi-skill recipe beats greedy cheapest craft",function()
    local r1=recipe(1,10,{[1]=1});local r2=recipe(2,11,{[2]=1});r2.numSkillUps=3
    local ctx=context({[1]=r1,[2]=r2},{[1]={cost=4},[2]={cost=9}})
    local route=E.Route(ctx,197,1,4)
    eq(route.choices[1],2);eq(route.expectedCost,9)
end)
test("dynamic route agrees with exhaustive tiny-state oracle",function()
    math.randomseed(521)
    for _=1,100 do
        local rs,ps={},{}
        for i=1,4 do
            rs[i]=recipe(i,100+i,{[i]=1},{1,math.random(1,5),6,9})
            rs[i].numSkillUps=math.random(1,3)
            ps[i]={cost=math.random(1,50)}
        end
        local ctx=context(rs,ps)
        local function brute(s)
            if s>=7 then return 0 end
            local best=math.huge
            for _,r in pairs(rs) do
                local p=E.Chance(r,s)
                if p>0 then best=math.min(best,ps[next(r.reagents)].cost/p+brute(s+r.numSkillUps)) end
            end
            return best
        end
        near(E.Route(ctx,197,1,7).expectedCost,brute(1))
    end
end)
test("recursive unit costing and cycle rejection",function()
    local rs={[1]=recipe(1,2,{[1]=2}),[2]=recipe(2,3,{[2]=2}),[3]=recipe(3,1,{[3]=1})}
    local ctx=context(rs,{[1]={cost=3,source="auction"}})
    near(E.Unit(3,ctx),12)
    ctx.prices={}
    eq(E.Unit(3,ctx),math.huge)
end)
test("whole batches compare buying against crafting",function()
    local rs={[1]=recipe(1,20,{[10]=10},nil,10),[2]=recipe(2,30,{[20]=1})}
    local ctx=context(rs,{[10]={cost=1},[20]={cost=3,source="auction"}})
    local plan=E.NewPlan({})
    assert(E.AppendCraft(plan,ctx,2,1));eq(plan.cost,3);eq(#plan.queue,1)
    plan=E.NewPlan({});assert(E.AppendCraft(plan,ctx,2,10));eq(plan.cost,10)
    eq(plan.queue[1].recipe,1);eq(plan.queue[1].casts,1);eq(plan.queue[2].recipe,2)
end)
test("shared stock and intermediate surplus are reserved once",function()
    local rs={[1]=recipe(1,20,{[10]=2},nil,3),[2]=recipe(2,30,{[20]=2})}
    local ctx=context(rs,{[10]={cost=4,source="auction"}})
    local plan=E.NewPlan({[10]=2})
    assert(E.AppendCraft(plan,ctx,2,1));eq(plan.cost,0);eq(plan.stock[20],1)
    assert(E.AppendCraft(plan,ctx,2,1));eq(plan.cost,8);eq(plan.stock[20],2)
    eq(plan.shopping[10].quantity,2)
end)
test("vendor packs include cost and retain surplus",function()
    local ctx=context({[1]=recipe(1,20,{[10]=3})},{[10]={cost=2,pack=5,source="vendor"}})
    local plan=E.NewPlan({});assert(E.AppendCraft(plan,ctx,1,1))
    eq(plan.cost,10);eq(plan.shopping[10].quantity,5);eq(plan.stock[10],2)
end)
test("failed dependency branch rolls back all stock and purchases",function()
    local ctx=context({[1]=recipe(1,20,{[10]=1,[11]=1})},{[10]={cost=2}})
    local plan=E.NewPlan({[10]=1});local ok=E.AppendCraft(plan,ctx,1,1)
    eq(ok,false);eq(plan.stock[10],1);eq(plan.cost,0);eq(#plan.queue,0)
end)
test("future skill intermediates cannot be crafted prematurely",function()
    local rs={[1]=recipe(1,20,{[10]=1},{50,60,70,80}),[2]=recipe(2,30,{[20]=1})}
    local ctx=context(rs,{[10]={cost=1}})
    eq(E.Unit(20,ctx),math.huge)
    ctx.skills[197]=50;eq(E.Unit(20,ctx),1)
end)
test("intermediate skill gains count and reduce parent batches",function()
    local rs={[1]=recipe(1,20,{[10]=1}),[2]=recipe(2,30,{[20]=1})}
    local ctx=context(rs,{[10]={cost=2}},1)
    local route={start=1,profession=197,steps={{recipe=2,casts=4,from=1,to=5}}}
    local plan=E.Materialize(route,ctx,{})
    eq(plan.queue[1].casts,2);eq(plan.queue[2].casts,2)
    eq(plan.credits[197],4);eq(plan.cost,4)
end)
test("next-recipe ranking consumes existing stock before purchases",function()
    local rs={[1]=recipe(1,20,{[10]=1}),[2]=recipe(2,30,{[11]=1})}
    local ctx=context(rs,{[10]={cost=100},[11]={cost=5}})
    local ranked=E.Rank(ctx,197,1,{[10]=1})
    eq(ranked[1].recipe,1);eq(ranked[1].expected,0)
end)
test("bundled database stays within the three Azeroth skill lines",function()
    assert(loadfile("Data/Recipes.lua"))("Craftalot",A)
    local count=0;local lines={[197]=2540,[333]=2494,[185]=2548}
    for id,r in pairs(A.Recipes) do
        eq(id,r.id);eq(r.skillLine,lines[r.profession]);eq(#r.difficulty,4)
        assert(next(r.reagents));count=count+1
    end
    eq(count,521);eq(A.Recipes[7418].profession,333);eq(A.Recipes[2963].item,2996)
end)
print(string.format("%d engine tests passed",passed))

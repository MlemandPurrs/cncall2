

UnitTypes = { "1tnk.nod", "stnk", "ftnk", "napc.armed" }
BeachUnitTypes = { "e1", "e1", "e3", "e4", "e1", "e1", "e3", "e4", "e1", "e1", "cybr", "cybr", "bggy", "bggy", "1tnk.nod", "bike" }
ShipUnitTypes = { "gapc", "hmmv.tow", "hmmv", "2tnk.gdi", "2tnk.gdi" }
ProxyType = "powerproxy.paratroopers"
ProducedUnitTypes =
{
	{ factory = AlliedBarracks1, types = { "e1", "e3", "e1", "e2", "e2" } },
	{ factory = AlliedBarracks2, types = { "e1", "e3", "e1", "e2", "e2" } },
	{ factory = SovietBarracks1, types = { "e1", "e1", "e3", "e3", "e4", "e5" } },
	{ factory = SovietBarracks2, types = { "e1", "e1", "e3", "e3", "e4", "e5" } },
	{ factory = SovietBarracks3, types = { "e1", "e1", "e3", "e3", "e4", "e5" } },
	{ factory = AlliedWarFactory1, types = { "hmmv", "gapc", "2tnk.gdi", "mrls", "4tnk.gdi" } },
	{ factory = SovietWarFactory1, types = { "1tnk.nod", "bggy", "howi", "stnk", "napc.armed" } }
}

HelicopterUnitTypes = { "e1", "e1", "e2", "e1", "e2", "e3" };
ParadropWaypoints = { Paradrop1, Paradrop2, Paradrop3, Paradrop4, Paradrop5, Paradrop6, Paradrop7, Paradrop8 }
Mig1Waypoints = { Mig11, Mig12, Mig13, Mig14 }
Mig2Waypoints = { Mig21, Mig22, Mig23, Mig24 }

BindActorTriggers = function(a)
	if a.HasProperty("Hunt") then
		if a.Owner == allies then
			Trigger.OnIdle(a, function(a)
				if a.IsInWorld then
					a.Hunt()
				end
			end)
		else
			Trigger.OnIdle(a, function(a)
				if a.IsInWorld then
					a.AttackMove(AlliedTechnologyCenter.Location)
				end
			end)
		end
	end

	if a.HasProperty("HasPassengers") then
		Trigger.OnDamaged(a, function()
			if a.HasPassengers then
				a.Stop()
				a.UnloadPassengers()
			end
		end)
	end
end

SendSovietUnits = function(entryCell, unitTypes, interval)
	local units = Reinforcements.Reinforce(soviets, unitTypes, { entryCell }, interval)
	Utils.Do(units, function(unit)
		BindActorTriggers(unit)
	end)
	Trigger.OnAllKilled(units, function() SendSovietUnits(entryCell, unitTypes, interval) end)
end

SendMigs = function(waypoints)
	local migEntryPath = { waypoints[1].Location, waypoints[2].Location }
	local migs = Reinforcements.Reinforce(soviets, { "f22" }, migEntryPath, 4)
	Utils.Do(migs, function(mig)
		mig.Move(waypoints[3].Location)
		mig.Move(waypoints[4].Location)
		mig.Destroy()
	end)

	Trigger.AfterDelay(DateTime.Seconds(40), function() SendMigs(waypoints) end)
end

ShipAlliedUnits = function()
	local units = Reinforcements.ReinforceWithTransport(allies, "lst.cnc",
		ShipUnitTypes, { LstEntry.Location, LstUnload.Location }, { LstEntry.Location })[2]

	Utils.Do(units, function(unit)
		BindActorTriggers(unit)
	end)

	Trigger.AfterDelay(DateTime.Seconds(60), ShipAlliedUnits)
end

InsertAlliedChinookReinforcements = function(entry, hpad)
	local units = Reinforcements.ReinforceWithTransport(allies, "tran",
		HelicopterUnitTypes, { entry.Location, hpad.Location + CVec.New(1, 2) }, { entry.Location })[2]

	Utils.Do(units, function(unit)
		BindActorTriggers(unit)
	end)

	Trigger.AfterDelay(DateTime.Seconds(60), function() InsertAlliedChinookReinforcements(entry, hpad) end)
end

ParadropSovietUnits = function()
	local lz = Utils.Random(ParadropWaypoints)
	local aircraft = powerproxy.ActivateParatroopers(lz.CenterPosition)

	Utils.Do(aircraft, function(a)
		Trigger.OnPassengerExited(a, function(t, p)
			BindActorTriggers(p)
		end)
	end)

	Trigger.AfterDelay(DateTime.Seconds(35), ParadropSovietUnits)
end

ProduceUnits = function(t)
	local factory = t.factory
	if not factory.IsDead then
		local unitType = t.types[Utils.RandomInteger(1, #t.types + 1)]
		factory.Wait(Actor.BuildTime(unitType))
		factory.Produce(unitType)
		factory.CallFunc(function() ProduceUnits(t) end)
	end
end

SetupAlliedUnits = function()
	Utils.Do(Map.NamedActors, function(a)
		if a.Owner == allies and a.HasProperty("AcceptsCondition") and a.AcceptsCondition("unkillable") then
			a.GrantCondition("unkillable")
			a.Stance = "Defend"
		end
	end)
end

SetupFactories = function()
	Utils.Do(ProducedUnitTypes, function(production)
		Trigger.OnProduction(production.factory, function(_, a) BindActorTriggers(a) end)
	end)
end

ticks = 0
speed = 5

Tick = function()
	ticks = ticks + 1

	local t = (ticks + 45) % (360 * speed) * (math.pi / 180) / speed;
	Camera.Position = viewportOrigin + WVec.New(19200 * math.sin(t), 20480 * math.cos(t), 0)
end

WorldLoaded = function()
	allies = Player.GetPlayer("Allies")
	soviets = Player.GetPlayer("Soviets")
	viewportOrigin = Camera.Position

	SetupAlliedUnits()
	SetupFactories()
	ShipAlliedUnits()
	InsertAlliedChinookReinforcements(Chinook1Entry, HeliPad1)
	InsertAlliedChinookReinforcements(Chinook2Entry, HeliPad2)
	powerproxy = Actor.Create(ProxyType, false, { Owner = soviets })
	ParadropSovietUnits()
	Utils.Do(ProducedUnitTypes, ProduceUnits)

	Trigger.AfterDelay(DateTime.Seconds(30), function() SendMigs(Mig1Waypoints) end)
	Trigger.AfterDelay(DateTime.Seconds(30), function() SendMigs(Mig2Waypoints) end)

	SendSovietUnits(Entry1.Location, UnitTypes, 50)
	SendSovietUnits(Entry2.Location, UnitTypes, 50)
	SendSovietUnits(Entry3.Location, UnitTypes, 50)
	SendSovietUnits(Entry4.Location, UnitTypes, 50)
	SendSovietUnits(Entry5.Location, UnitTypes, 50)
	SendSovietUnits(Entry6.Location, UnitTypes, 50)
	SendSovietUnits(Entry7.Location, BeachUnitTypes, 15)
end

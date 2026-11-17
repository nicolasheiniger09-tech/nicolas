--[[
	💎 KRISTALL-GARTEN – Server-Skript 💎

	WO EINFÜGEN?
	Roblox Studio → Explorer → ServerScriptService → "+" → Script
	Das Script "GameServer" nennen und diesen ganzen Text hineinkopieren.

	Das Skript baut die ganze Welt (Gärten, Felder, Deko) automatisch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

------------------------------------------------------------------------
-- ⚙️ EINSTELLUNGEN – hier trägst du deine Robux-IDs ein (siehe README)
-- 0 = noch nicht eingerichtet (der Knopf im Spiel ist dann ausgegraut)
------------------------------------------------------------------------
local CONFIG = {
	GAMEPASS_DOUBLE_COINS = 0, -- Game Pass: dauerhaft doppelte Münzen
	GAMEPASS_FAST_GROW = 0, -- Game Pass: Kristalle wachsen doppelt so schnell
	PRODUCT_COINS_SMALL = 0, -- Developer Product: kleines Münzpaket
	PRODUCT_COINS_BIG = 0, -- Developer Product: großes Münzpaket
	PRODUCT_INSTANT_GROW = 0, -- Developer Product: alle Kristalle sofort fertig
}

local DATASTORE_NAME = "KristallGarten_v1"
local PLOT_COUNT = 10 -- Anzahl Gärten = maximale Spieler pro Server!
local PLOT_RADIUS = 110
local MAX_SLOTS = 12
local START_SLOTS = 4
local MAX_SPEED_LEVEL = 10
local DAILY_COOLDOWN = 20 * 60 * 60 -- 20 Stunden
local START_COINS = 25

-- Alle Kristallsorten: Preis des Samens, Wachstumszeit (Sekunden), Verkaufswert
local CRYSTALS = {
	{ id = "Quarz", price = 10, time = 15, value = 14, rebirth = 0, color = Color3.fromRGB(235, 240, 255) },
	{ id = "Amethyst", price = 75, time = 40, value = 120, rebirth = 0, color = Color3.fromRGB(170, 90, 255) },
	{ id = "Rubin", price = 400, time = 90, value = 700, rebirth = 0, color = Color3.fromRGB(255, 40, 70) },
	{ id = "Saphir", price = 2000, time = 180, value = 3800, rebirth = 0, color = Color3.fromRGB(40, 110, 255) },
	{ id = "Smaragd", price = 10000, time = 300, value = 20000, rebirth = 0, color = Color3.fromRGB(40, 220, 110) },
	{ id = "Diamant", price = 60000, time = 600, value = 125000, rebirth = 1, color = Color3.fromRGB(180, 250, 255) },
	{ id = "Sternenkristall", price = 400000, time = 1200, value = 900000, rebirth = 3, color = Color3.fromRGB(255, 210, 60) },
}
local CRYSTAL_BY_ID = {}
for _, c in ipairs(CRYSTALS) do
	CRYSTAL_BY_ID[c.id] = c
end

-- Seltene Varianten: zufällig beim Pflanzen
local MUTATIONS = {
	{ id = "Regenbogen", chance = 0.01, mult = 10 },
	{ id = "Gold", chance = 0.06, mult = 3 },
}
local MUT_MULT = { [""] = 1 }
for _, m in ipairs(MUTATIONS) do
	MUT_MULT[m.id] = m.mult
end

local rng = Random.new()

------------------------------------------------------------------------
-- Remotes (Verbindung zwischen Server und Spieler-Bildschirm)
------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "KristallRemotes"
remotes.Parent = ReplicatedStorage

local actionFn = Instance.new("RemoteFunction")
actionFn.Name = "Action"
actionFn.Parent = remotes

local dataEvent = Instance.new("RemoteEvent")
dataEvent.Name = "DataUpdate"
dataEvent.Parent = remotes

local notifyEvent = Instance.new("RemoteEvent")
notifyEvent.Name = "Notify"
notifyEvent.Parent = remotes

------------------------------------------------------------------------
-- Hilfsfunktionen
------------------------------------------------------------------------
local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }
local function fmt(n)
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local i = 1
	local x = n
	while x >= 1000 and i < #SUFFIXES do
		x /= 1000
		i += 1
	end
	return (string.gsub(string.format("%.1f%s", x, SUFFIXES[i]), "%.0(%a)", "%1"))
end

local function formatTime(sec)
	sec = math.max(0, math.floor(sec))
	if sec >= 3600 then
		return string.format("%dh %02dm", sec // 3600, (sec % 3600) // 60)
	elseif sec >= 60 then
		return string.format("%dm %02ds", sec // 60, sec % 60)
	end
	return sec .. "s"
end

local function makePart(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function makeLabel(part, text, sizeX, sizeY, offsetY, maxDist)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(sizeX, sizeY)
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.MaxDistance = maxDist or 80
	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundTransparency = 1
	tl.TextScaled = true
	tl.Font = Enum.Font.GothamBold
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.TextStrokeTransparency = 0.2
	tl.Text = text
	tl.Parent = bb
	bb.Parent = part
	return tl
end

local function rollMutation()
	local r = rng:NextNumber()
	local acc = 0
	for _, m in ipairs(MUTATIONS) do
		acc += m.chance
		if r < acc then
			return m.id
		end
	end
	return ""
end

------------------------------------------------------------------------
-- Spielerdaten
------------------------------------------------------------------------
local store = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(DATASTORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[KristallGarten] DataStore nicht verfügbar:", result)
	end
end

local function defaultData()
	return {
		coins = START_COINS,
		rebirths = 0,
		seeds = { Quarz = 3 },
		inventory = {}, -- ["Rubin|Gold"] = Anzahl
		planted = {}, -- ["3"] = { id, mut, s = Startzeit, done = Fertigzeit }
		slots = START_SLOTS,
		speed = 0,
		selected = "Quarz",
		lastDaily = 0,
		totalEarned = 0,
		receipts = {},
	}
end

local function reconcile(data)
	local def = defaultData()
	if type(data) ~= "table" then
		return def
	end
	for k, v in pairs(def) do
		if data[k] == nil then
			data[k] = v
		end
	end
	return data
end

local sessions = {} -- [player] = session

local function slotCost(d)
	if d.slots >= MAX_SLOTS then
		return nil
	end
	return math.floor(150 * 2.6 ^ (d.slots - START_SLOTS))
end

local function speedCost(d)
	if d.speed >= MAX_SPEED_LEVEL then
		return nil
	end
	return math.floor(250 * 3 ^ d.speed)
end

local function rebirthCost(d)
	return math.floor(100000 * 3 ^ d.rebirths)
end

local function coinPack(d, big)
	local base = math.max(1000, math.floor(rebirthCost(d) * 0.1))
	return big and base * 6 or base
end

local function dailyReward(d)
	return math.max(250, math.floor(rebirthCost(d) * 0.02))
end

local function coinMultiplier(session)
	local m = 1 + 0.5 * session.data.rebirths
	if session.doubleCoins then
		m *= 2
	end
	return m
end

local function growDuration(session, crystal)
	local t = crystal.time * (0.9 ^ session.data.speed)
	if session.fastGrow then
		t *= 0.5
	end
	return math.max(1, math.ceil(t))
end

local function inventoryValue(session)
	local total = 0
	for key, count in pairs(session.data.inventory) do
		local id, mut = string.match(key, "^(.-)|(.*)$")
		local c = CRYSTAL_BY_ID[id]
		if c then
			total += c.value * (MUT_MULT[mut] or 1) * count
		end
	end
	return math.floor(total * coinMultiplier(session))
end

local function snapshot(session)
	local d = session.data
	return {
		coins = d.coins,
		rebirths = d.rebirths,
		seeds = d.seeds,
		inventory = d.inventory,
		inventoryValue = inventoryValue(session),
		slots = d.slots,
		maxSlots = MAX_SLOTS,
		speed = d.speed,
		maxSpeed = MAX_SPEED_LEVEL,
		slotCost = slotCost(d),
		speedCost = speedCost(d),
		rebirthCost = rebirthCost(d),
		multiplier = coinMultiplier(session),
		selected = d.selected,
		dailyIn = math.max(0, d.lastDaily + DAILY_COOLDOWN - os.time()),
		dailyReward = dailyReward(d),
		smallPack = coinPack(d, false),
		bigPack = coinPack(d, true),
		doubleCoins = session.doubleCoins,
		fastGrow = session.fastGrow,
		totalEarned = d.totalEarned,
	}
end

local function notify(player, text, kind)
	notifyEvent:FireClient(player, text, kind or "info")
end

local function sync(player)
	local session = sessions[player]
	if not session then
		return
	end
	dataEvent:FireClient(player, snapshot(session))
	if session.coinsValue then
		session.coinsValue.Value = session.data.coins
		session.rebirthValue.Value = session.data.rebirths
	end
end

local function save(player)
	local session = sessions[player]
	if not session or not session.canSave or not store then
		return false
	end
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			store:SetAsync("p_" .. player.UserId, session.data)
		end)
		if ok then
			return true
		end
		warn("[KristallGarten] Speichern fehlgeschlagen (Versuch " .. attempt .. "):", err)
		task.wait(1)
	end
	return false
end

------------------------------------------------------------------------
-- 🌍 Welt bauen
------------------------------------------------------------------------
local SOIL_COLOR = Color3.fromRGB(95, 65, 45)
local LOCKED_COLOR = Color3.fromRGB(70, 70, 75)
local GOLD_COLOR = Color3.fromRGB(255, 200, 40)

local groundY = 0
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	groundY = baseplate.Position.Y + baseplate.Size.Y / 2
	baseplate.Color = Color3.fromRGB(85, 150, 80)
	baseplate.Material = Enum.Material.Grass
else
	makePart({
		Name = "Boden",
		Size = Vector3.new(600, 2, 600),
		Position = Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(85, 150, 80),
		Material = Enum.Material.Grass,
	}, workspace)
end

-- Schwebender Riesenkristall in der Mitte
local giant = makePart({
	Name = "Riesenkristall",
	Size = Vector3.new(6, 12, 6),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(150, 100, 255),
	CanCollide = false,
	CFrame = CFrame.new(0, groundY + 22, 0),
}, workspace)
local giantLight = Instance.new("PointLight")
giantLight.Range = 30
giantLight.Brightness = 2
giantLight.Color = giant.Color
giantLight.Parent = giant
makeLabel(giant, "💎 KRISTALL-GARTEN 💎", 400, 70, 10, 400)

local giantAngle = 0
RunService.Heartbeat:Connect(function(dt)
	giantAngle += dt * 0.6
	giant.CFrame = CFrame.new(0, groundY + 22 + math.sin(giantAngle * 2) * 1.5, 0)
		* CFrame.Angles(0, giantAngle, 0)
		* CFrame.Angles(0, 0, math.rad(45))
end)

local plotsFolder = Instance.new("Folder")
plotsFolder.Name = "Gaerten"
plotsFolder.Parent = workspace

local plots = {}
local onSlotClicked -- wird weiter unten definiert

for pi = 1, PLOT_COUNT do
	local angle = (pi - 1) / PLOT_COUNT * math.pi * 2
	local pos = Vector3.new(math.cos(angle) * PLOT_RADIUS, groundY + 0.5, math.sin(angle) * PLOT_RADIUS)
	local cf = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)) -- Vorderseite (-Z) zeigt zur Mitte

	local model = Instance.new("Model")
	model.Name = "Garten" .. pi
	model.Parent = plotsFolder

	makePart({
		Name = "Basis",
		Size = Vector3.new(46, 1, 46),
		CFrame = cf,
		Color = Color3.fromRGB(150, 115, 80),
		Material = Enum.Material.WoodPlanks,
	}, model)

	local post = makePart({
		Name = "Schild",
		Size = Vector3.new(1, 8, 1),
		CFrame = cf * CFrame.new(0, 4.5, 21),
		Color = Color3.fromRGB(110, 80, 50),
		Material = Enum.Material.Wood,
	}, model)
	local signLabel = makeLabel(post, "Freier Garten", 300, 60, 6, 150)

	local slots = {}
	for i = 1, MAX_SLOTS do
		local col = (i - 1) % 4
		local row = (i - 1) // 4
		local slotModel = Instance.new("Model")
		slotModel.Name = "Feld" .. i
		slotModel.Parent = model

		local soil = makePart({
			Name = "Erde",
			Size = Vector3.new(7, 0.6, 7),
			CFrame = cf * CFrame.new((col - 1.5) * 9.5, 0.8, (row - 1) * 9.5),
			Color = SOIL_COLOR,
			Material = Enum.Material.Ground,
		}, slotModel)

		local cd = Instance.new("ClickDetector")
		cd.MaxActivationDistance = 40
		cd.Parent = slotModel

		local label = makeLabel(soil, "", 170, 46, 5, 45)
		slots[i] = { model = slotModel, soil = soil, label = label }

		cd.MouseClick:Connect(function(player)
			onSlotClicked(pi, i, player)
		end)
	end

	plots[pi] = {
		index = pi,
		slots = slots,
		signLabel = signLabel,
		spawn = cf * CFrame.new(0, 4, -19) * CFrame.Angles(0, math.pi, 0),
		owner = nil,
	}
end

------------------------------------------------------------------------
-- Kristall-Anzeige auf den Feldern
------------------------------------------------------------------------
local function removeCrystal(slot)
	if slot.crystal then
		slot.crystal:Destroy()
		slot.crystal = nil
	end
	slot.crystalKey = nil
end

local function createCrystal(slot, c, mut)
	local color = c.color
	if mut == "Gold" then
		color = GOLD_COLOR
	end
	local part = makePart({
		Name = "Kristall",
		Size = Vector3.new(1, 1, 1),
		Material = Enum.Material.Neon,
		Color = color,
		CanCollide = false,
		CastShadow = false,
	}, slot.model)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 8
	light.Brightness = 1.5
	light.Parent = part

	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Glitzer"
	sparkle.Enabled = false
	sparkle.Rate = 8
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.Size = NumberSequence.new(0.4, 0)
	sparkle.LightEmission = 1
	sparkle.Color = ColorSequence.new(color)
	sparkle.Parent = part

	slot.crystal = part
end

local function resetSlotVisual(slot)
	removeCrystal(slot)
	slot.soil.Color = SOIL_COLOR
	slot.soil.Transparency = 0
	slot.label.Text = ""
end

local function refreshSlot(session, i)
	local slot = session.plot.slots[i]
	local d = session.data

	if i > d.slots then
		removeCrystal(slot)
		slot.soil.Color = LOCKED_COLOR
		slot.soil.Transparency = 0.4
		slot.label.Text = "🔒 Gesperrt"
		slot.label.TextColor3 = Color3.fromRGB(190, 190, 190)
		return
	end
	slot.soil.Color = SOIL_COLOR
	slot.soil.Transparency = 0

	local p = d.planted[tostring(i)]
	if not p then
		removeCrystal(slot)
		slot.label.Text = "🌱 Klicken zum Pflanzen"
		slot.label.TextColor3 = Color3.fromRGB(200, 255, 200)
		return
	end

	local c = CRYSTAL_BY_ID[p.id]
	if not c then
		d.planted[tostring(i)] = nil
		return
	end

	local now = os.time()
	local total = math.max(1, p.done - p.s)
	local progress = math.clamp((now - p.s) / total, 0, 1)
	local key = p.id .. "|" .. p.mut
	if slot.crystalKey ~= key then
		removeCrystal(slot)
		createCrystal(slot, c, p.mut)
		slot.crystalKey = key
	end

	local crystal = slot.crystal
	local scale = 0.25 + 0.75 * progress
	crystal.Size = Vector3.new(2.2, 4.5, 2.2) * scale
	crystal.CFrame = slot.soil.CFrame * CFrame.new(0, 0.3 + crystal.Size.Y / 2, 0) * CFrame.Angles(0, math.rad(45), 0)

	if p.mut == "Regenbogen" then
		local rainbow = Color3.fromHSV((os.clock() * 0.2) % 1, 0.8, 1)
		crystal.Color = rainbow
		crystal.PointLight.Color = rainbow
	end

	local name = (p.mut ~= "" and (p.mut .. "-") or "") .. p.id
	if progress >= 1 then
		crystal.Glitzer.Enabled = true
		slot.label.Text = "✨ " .. name .. " fertig!"
		slot.label.TextColor3 = Color3.fromRGB(255, 240, 120)
	else
		crystal.Glitzer.Enabled = false
		slot.label.Text = name .. " · " .. formatTime(p.done - now)
		slot.label.TextColor3 = Color3.new(1, 1, 1)
	end
end

local function refreshPlot(session)
	if not session.plot then
		return
	end
	for i = 1, MAX_SLOTS do
		refreshSlot(session, i)
	end
end

task.spawn(function()
	while true do
		for _, session in pairs(sessions) do
			if session.loaded then
				refreshPlot(session)
			end
		end
		task.wait(1)
	end
end)

------------------------------------------------------------------------
-- Pflanzen & Ernten
------------------------------------------------------------------------
local function bestOwnedSeed(d)
	if d.selected and (d.seeds[d.selected] or 0) > 0 then
		return d.selected
	end
	local best = nil
	for _, c in ipairs(CRYSTALS) do
		if (d.seeds[c.id] or 0) > 0 then
			best = c.id
		end
	end
	return best
end

local function plant(session, i, seedId)
	local d = session.data
	local c = CRYSTAL_BY_ID[seedId]
	if not c or (d.seeds[seedId] or 0) <= 0 or d.planted[tostring(i)] or i > d.slots then
		return false
	end
	d.seeds[seedId] -= 1
	if d.seeds[seedId] <= 0 then
		d.seeds[seedId] = nil
	end
	local now = os.time()
	d.planted[tostring(i)] = {
		id = seedId,
		mut = rollMutation(),
		s = now,
		done = now + growDuration(session, c),
	}
	return true
end

-- Gibt den geernteten Kristall zurück (oder nil, wenn nicht fertig)
local function harvest(session, i)
	local d = session.data
	local key = tostring(i)
	local p = d.planted[key]
	if not p or os.time() < p.done then
		return nil
	end
	local invKey = p.id .. "|" .. p.mut
	d.inventory[invKey] = (d.inventory[invKey] or 0) + 1
	d.planted[key] = nil
	-- automatisch dieselbe Sorte neu pflanzen, falls Samen da sind
	plant(session, i, p.id)
	return p
end

onSlotClicked = function(plotIndex, i, player)
	local session = sessions[player]
	if not session or not session.loaded then
		return
	end
	if session.plot ~= plots[plotIndex] then
		notify(player, "Das ist nicht dein Garten!", "error")
		return
	end
	local d = session.data
	if i > d.slots then
		notify(player, "🔒 Gesperrt – kaufe mehr Felder bei den Upgrades!", "error")
		return
	end

	local p = d.planted[tostring(i)]
	if p then
		local got = harvest(session, i)
		if got then
			local name = (got.mut ~= "" and (got.mut .. "-") or "") .. got.id
			notify(player, "+1 " .. name .. "!", got.mut ~= "" and "rare" or "good")
		else
			notify(player, p.id .. " braucht noch " .. formatTime(p.done - os.time()), "info")
		end
	else
		local seed = bestOwnedSeed(d)
		if not seed then
			notify(player, "Keine Samen! Kaufe welche im 🌱 Samen-Shop.", "error")
			return
		end
		d.selected = seed
		plant(session, i, seed)
	end
	refreshSlot(session, i)
	sync(player)
end

------------------------------------------------------------------------
-- Aktionen vom Spieler-Bildschirm
------------------------------------------------------------------------
actionFn.OnServerInvoke = function(player, action, arg1, arg2)
	if action == "GetConfig" then
		return { crystals = CRYSTALS, config = CONFIG }
	end

	local session = sessions[player]
	if not session or not session.loaded then
		return false
	end
	if action == "GetData" then
		return snapshot(session)
	end

	local clock = os.clock()
	if clock - session.lastAction < 0.1 then
		return false
	end
	session.lastAction = clock
	local d = session.data

	if action == "BuySeed" then
		local c = CRYSTAL_BY_ID[arg1]
		if not c then
			return false
		end
		local amount = (arg2 == 10) and 10 or 1
		if d.rebirths < c.rebirth then
			notify(player, "🔒 " .. c.id .. " braucht " .. c.rebirth .. " Rebirth(s)!", "error")
			return false
		end
		local cost = c.price * amount
		if d.coins < cost then
			notify(player, "Nicht genug Münzen! Du brauchst 💰 " .. fmt(cost), "error")
			return false
		end
		d.coins -= cost
		d.seeds[c.id] = (d.seeds[c.id] or 0) + amount
		d.selected = c.id
		notify(player, "Gekauft: " .. amount .. "x " .. c.id .. "-Samen", "good")
	elseif action == "Select" then
		if CRYSTAL_BY_ID[arg1] then
			d.selected = arg1
		end
	elseif action == "SellAll" then
		local value = inventoryValue(session)
		if value <= 0 then
			notify(player, "Nichts zum Verkaufen – ernte zuerst Kristalle!", "error")
			return false
		end
		d.coins += value
		d.totalEarned += value
		d.inventory = {}
		notify(player, "Verkauft für 💰 " .. fmt(value) .. "!", "good")
	elseif action == "HarvestAll" then
		local count = 0
		for i = 1, d.slots do
			if harvest(session, i) then
				count += 1
			end
		end
		if count == 0 then
			notify(player, "Noch kein Kristall ist fertig.", "info")
			return false
		end
		notify(player, "🧺 " .. count .. " Kristalle geerntet!", "good")
	elseif action == "PlantAll" then
		local count = 0
		for i = 1, d.slots do
			if not d.planted[tostring(i)] then
				local seed = bestOwnedSeed(d)
				if not seed then
					break
				end
				d.selected = seed
				if plant(session, i, seed) then
					count += 1
				end
			end
		end
		if count == 0 then
			notify(player, "Keine freien Felder oder keine Samen.", "error")
			return false
		end
		notify(player, "🌱 " .. count .. " Samen gepflanzt!", "good")
	elseif action == "Upgrade" then
		local cost = (arg1 == "slots" and slotCost(d)) or (arg1 == "speed" and speedCost(d)) or nil
		if not cost then
			return false
		end
		if d.coins < cost then
			notify(player, "Nicht genug Münzen! Du brauchst 💰 " .. fmt(cost), "error")
			return false
		end
		d.coins -= cost
		if arg1 == "slots" then
			d.slots += 1
			notify(player, "🟫 Neues Feld freigeschaltet!", "good")
		else
			d.speed += 1
			notify(player, "⚡ Kristalle wachsen jetzt schneller!", "good")
		end
	elseif action == "Rebirth" then
		local cost = rebirthCost(d)
		if d.coins < cost then
			notify(player, "Du brauchst 💰 " .. fmt(cost) .. " für einen Rebirth!", "error")
			return false
		end
		d.rebirths += 1
		d.coins = START_COINS
		d.seeds = { Quarz = 3 }
		d.inventory = {}
		d.planted = {}
		d.slots = START_SLOTS
		d.speed = 0
		d.selected = "Quarz"
		notify(player, "🔁 REBIRTH! Jetzt x" .. coinMultiplier(session) .. " Münzen!", "rare")
	elseif action == "Daily" then
		local now = os.time()
		if now < d.lastDaily + DAILY_COOLDOWN then
			notify(player, "🎁 Nächste Belohnung in " .. formatTime(d.lastDaily + DAILY_COOLDOWN - now), "info")
			return false
		end
		local reward = dailyReward(d)
		d.lastDaily = now
		d.coins += reward
		notify(player, "🎁 Tägliche Belohnung: 💰 " .. fmt(reward) .. "!", "rare")
	else
		return false
	end

	refreshPlot(session)
	sync(player)
	return true
end

------------------------------------------------------------------------
-- 💎 Robux-Käufe
------------------------------------------------------------------------
local function ownsPass(player, id)
	if not id or id == 0 then
		return false
	end
	local ok, res = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	return ok and res == true
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local session = sessions[player]
	if not purchased or not session then
		return
	end
	if passId == CONFIG.GAMEPASS_DOUBLE_COINS then
		session.doubleCoins = true
		notify(player, "💎 Danke! Ab jetzt doppelte Münzen!", "rare")
	elseif passId == CONFIG.GAMEPASS_FAST_GROW then
		session.fastGrow = true
		notify(player, "💎 Danke! Kristalle wachsen jetzt doppelt so schnell!", "rare")
	end
	sync(player)
end)

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local session = player and sessions[player]
	if not session or not session.loaded then
		return Enum.ProductPurchaseDecision.NotYetGranted
	end
	local d = session.data
	if table.find(d.receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local pid = info.ProductId
	if pid == CONFIG.PRODUCT_COINS_SMALL then
		local amount = coinPack(d, false)
		d.coins += amount
		notify(player, "💎 +" .. fmt(amount) .. " Münzen! Danke!", "rare")
	elseif pid == CONFIG.PRODUCT_COINS_BIG then
		local amount = coinPack(d, true)
		d.coins += amount
		notify(player, "💎 +" .. fmt(amount) .. " Münzen! Danke!", "rare")
	elseif pid == CONFIG.PRODUCT_INSTANT_GROW then
		local now = os.time()
		for _, p in pairs(d.planted) do
			p.done = now
		end
		notify(player, "💎 Alle Kristalle sind sofort fertig!", "rare")
	else
		return Enum.ProductPurchaseDecision.NotYetGranted
	end

	table.insert(d.receipts, info.PurchaseId)
	while #d.receipts > 50 do
		table.remove(d.receipts, 1)
	end
	refreshPlot(session)
	sync(player)
	if session.canSave and not save(player) then
		return Enum.ProductPurchaseDecision.NotYetGranted
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

------------------------------------------------------------------------
-- Spieler kommt / geht
------------------------------------------------------------------------
local function onPlayerAdded(player)
	local session = {
		data = defaultData(),
		loaded = false,
		canSave = false,
		lastAction = 0,
		doubleCoins = false,
		fastGrow = false,
	}
	sessions[player] = session

	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("NumberValue")
	coins.Name = "Münzen"
	coins.Parent = ls
	local reb = Instance.new("IntValue")
	reb.Name = "Rebirths"
	reb.Parent = ls
	ls.Parent = player
	session.coinsValue = coins
	session.rebirthValue = reb

	if store then
		local ok, result = pcall(function()
			return store:GetAsync("p_" .. player.UserId)
		end)
		if ok then
			session.data = reconcile(result)
			session.canSave = true
		else
			warn("[KristallGarten] Laden fehlgeschlagen:", result)
		end
	end
	if not player.Parent then
		sessions[player] = nil
		return
	end

	session.doubleCoins = ownsPass(player, CONFIG.GAMEPASS_DOUBLE_COINS)
	session.fastGrow = ownsPass(player, CONFIG.GAMEPASS_FAST_GROW)

	for _, plot in ipairs(plots) do
		if not plot.owner then
			plot.owner = player
			session.plot = plot
			plot.signLabel.Text = "💎 " .. player.DisplayName .. "s Garten"
			break
		end
	end
	session.loaded = true

	local function onCharacter(char)
		local hrp = char:WaitForChild("HumanoidRootPart", 10)
		if hrp and session.plot then
			task.wait(0.2)
			char:PivotTo(session.plot.spawn)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	refreshPlot(session)
	sync(player)

	-- Kristalle wachsen auch, wenn man offline ist
	local ready = 0
	for _, p in pairs(session.data.planted) do
		if os.time() >= p.done then
			ready += 1
		end
	end
	if ready > 0 then
		notify(player, "Willkommen zurück! " .. ready .. " Kristalle sind fertig ✨", "rare")
	end
	if not session.canSave then
		notify(player, "⚠️ Fortschritt wird nicht gespeichert (API-Zugriff in Studio aktivieren).", "error")
	end
end

local function onPlayerRemoving(player)
	local session = sessions[player]
	if not session then
		return
	end
	save(player)
	if session.plot then
		local plot = session.plot
		plot.owner = nil
		plot.signLabel.Text = "Freier Garten"
		for _, slot in ipairs(plot.slots) do
			resetSlotVisual(slot)
		end
	end
	sessions[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Automatisch alle 2 Minuten speichern
task.spawn(function()
	while true do
		task.wait(120)
		for player in pairs(sessions) do
			task.spawn(save, player)
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player in pairs(sessions) do
		pending += 1
		task.spawn(function()
			save(player)
			pending -= 1
		end)
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.1)
	end
end)

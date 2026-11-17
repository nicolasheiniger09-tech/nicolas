--[[
	💎 KRISTALL-GARTEN – Bildschirm (GUI) für Spieler 💎

	WO EINFÜGEN?
	Roblox Studio → Explorer → StarterPlayer → StarterPlayerScripts → "+" → LocalScript
	Das LocalScript "Client" nennen und diesen ganzen Text hineinkopieren.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("KristallRemotes")
local Action = remotes:WaitForChild("Action")
local DataUpdate = remotes:WaitForChild("DataUpdate")
local Notify = remotes:WaitForChild("Notify")

local cfg = Action:InvokeServer("GetConfig")
local CRYSTALS = cfg.crystals
local CONFIG = cfg.config

local data = nil
local dataTime = os.clock()
local openPanel = nil

------------------------------------------------------------------------
-- Farben & Hilfsfunktionen
------------------------------------------------------------------------
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(35, 25, 60)
local ROW = Color3.fromRGB(55, 42, 90)
local ACCENT = Color3.fromRGB(170, 120, 255)
local GREEN = Color3.fromRGB(60, 190, 90)
local GRAY = Color3.fromRGB(90, 90, 100)
local GOLD = Color3.fromRGB(240, 180, 30)
local RED = Color3.fromRGB(210, 60, 70)
local BLUE = Color3.fromRGB(60, 120, 230)
local PINK = Color3.fromRGB(220, 80, 200)

local function new(class, props)
	local obj = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		obj[k] = v
	end
	obj.Parent = parent
	return obj
end

local function corner(obj, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 10), Parent = obj })
end

local function stroke(obj, color, t)
	new("UIStroke", { Color = color, Thickness = t or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = obj })
end

local function maxText(obj, size)
	new("UITextSizeConstraint", { MaxTextSize = size, Parent = obj })
end

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi" }
local function fmt(n)
	n = math.floor(n or 0)
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

local function fmtMult(m)
	return "x" .. (string.gsub(string.format("%.1f", m), "%.0$", ""))
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

local function act(...)
	local ok, res = pcall(function(...)
		return Action:InvokeServer(...)
	end, ...)
	return ok and res
end

------------------------------------------------------------------------
-- Bildschirm aufbauen
------------------------------------------------------------------------
local gui = new("ScreenGui", {
	Name = "KristallGUI",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

-- Auf kleinen Bildschirmen (Handy) alles etwas kleiner machen
local scaled = {}
local function addScale(frame)
	table.insert(scaled, new("UIScale", { Parent = frame }))
end
local function updateScale()
	local cam = workspace.CurrentCamera
	local h = cam and cam.ViewportSize.Y or 800
	local s = math.clamp(h / 720, 0.55, 1)
	for _, ui in ipairs(scaled) do
		ui.Scale = s
	end
end

-- Oben: Münzen
local top = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 6),
	Size = UDim2.fromOffset(320, 60),
	BackgroundColor3 = PANEL,
	Parent = gui,
})
corner(top, 14)
stroke(top, ACCENT)
addScale(top)
local coinsLabel = new("TextLabel", {
	Position = UDim2.fromOffset(10, 2),
	Size = UDim2.new(1, -20, 0, 34),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(255, 225, 90),
	Text = "💰 0",
	Parent = top,
})
local multLabel = new("TextLabel", {
	Position = UDim2.fromOffset(10, 36),
	Size = UDim2.new(1, -20, 0, 20),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = Color3.fromRGB(220, 200, 255),
	Text = "",
	Parent = top,
})

-- Benachrichtigungen
local toastHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 74),
	Size = UDim2.fromOffset(420, 200),
	BackgroundTransparency = 1,
	Parent = gui,
})
addScale(toastHolder)
new("UIListLayout", {
	Padding = UDim.new(0, 4),
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Parent = toastHolder,
})

local KIND_COLORS = { good = GREEN, error = RED, info = BLUE, rare = PINK }
local toastCount = 0
local function toast(text, kind)
	toastCount += 1
	local t = new("TextLabel", {
		Size = UDim2.fromOffset(400, 34),
		BackgroundColor3 = KIND_COLORS[kind] or BLUE,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = text,
		LayoutOrder = toastCount,
		Parent = toastHolder,
	})
	corner(t, 8)
	maxText(t, 20)
	new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = t })
	local labels = {}
	for _, child in ipairs(toastHolder:GetChildren()) do
		if child:IsA("TextLabel") then
			table.insert(labels, child)
		end
	end
	table.sort(labels, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #labels > 4 do
		table.remove(labels, 1):Destroy()
	end
	task.delay(2.6, function()
		if t.Parent then
			TweenService:Create(t, TweenInfo.new(0.4), { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			task.wait(0.4)
			t:Destroy()
		end
	end)
end
Notify.OnClientEvent:Connect(toast)

-- Links: Menü
local menu = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(160, 6 * 54),
	BackgroundTransparency = 1,
	Parent = gui,
})
addScale(menu)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = menu })

local function menuButton(text, color, order, onClick)
	local b = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = color,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = text,
		LayoutOrder = order,
		Parent = menu,
	})
	corner(b, 12)
	stroke(b, Color3.new(0, 0, 0), 2)
	maxText(b, 20)
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = b })
	b.Activated:Connect(onClick)
	return b
end

-- Mitte: Fenster für Shop, Upgrades usw.
local panel = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(500, 420),
	BackgroundColor3 = PANEL,
	Visible = false,
	Parent = gui,
})
corner(panel, 16)
stroke(panel, ACCENT, 3)
addScale(panel)
local panelTitle = new("TextLabel", {
	Position = UDim2.fromOffset(16, 8),
	Size = UDim2.new(1, -80, 0, 40),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextColor3 = WHITE,
	Text = "",
	Parent = panel,
})
local closeBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -10, 0, 10),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = RED,
	Font = Enum.Font.GothamBlack,
	TextScaled = true,
	TextColor3 = WHITE,
	Text = "X",
	Parent = panel,
})
corner(closeBtn, 10)
local list = new("ScrollingFrame", {
	Position = UDim2.fromOffset(10, 58),
	Size = UDim2.new(1, -20, 1, -68),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	Parent = panel,
})
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

-- Unten: Samen-Auswahl und Schnellknöpfe
local bottom = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(740, 128),
	BackgroundTransparency = 1,
	Parent = gui,
})
addScale(bottom)
local hint = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1,
	Font = Enum.Font.GothamBold,
	TextScaled = true,
	TextColor3 = WHITE,
	TextStrokeTransparency = 0.3,
	Text = "👉 Klicke auf ein Erdfeld in deinem Garten, um zu pflanzen!",
	Visible = false,
	Parent = bottom,
})
local quick = new("Frame", {
	Position = UDim2.fromOffset(0, 28),
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
	Parent = bottom,
})
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 8),
	Parent = quick,
})
local function quickButton(text, color, onClick)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(180, 40),
		BackgroundColor3 = color,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = text,
		Parent = quick,
	})
	corner(b, 10)
	stroke(b, Color3.new(0, 0, 0), 2)
	maxText(b, 18)
	b.Activated:Connect(onClick)
	return b
end
quickButton("🧺 Alles ernten", GOLD, function()
	act("HarvestAll")
end)
quickButton("🌱 Alles pflanzen", GREEN, function()
	act("PlantAll")
end)

local hotbar = new("Frame", {
	Position = UDim2.fromOffset(0, 74),
	Size = UDim2.new(1, 0, 0, 54),
	BackgroundTransparency = 1,
	Parent = bottom,
})
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 6),
	Parent = hotbar,
})

------------------------------------------------------------------------
-- Inhalt der Fenster
------------------------------------------------------------------------
local function clearList()
	for _, child in ipairs(list:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function makeRow(order, title, subtitle, swatchColor)
	local row = new("Frame", {
		Size = UDim2.new(1, -8, 0, 68),
		BackgroundColor3 = ROW,
		LayoutOrder = order,
		Parent = list,
	})
	corner(row, 10)
	local left = 12
	if swatchColor then
		local sw = new("Frame", {
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.new(0, 18, 0.5, -15),
			Rotation = 45,
			BackgroundColor3 = swatchColor,
			Parent = row,
		})
		corner(sw, 6)
		left = 62
	end
	local t = new("TextLabel", {
		Position = UDim2.fromOffset(left, 6),
		Size = UDim2.new(1, -left - 190, 0, 28),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE,
		Text = title,
		Parent = row,
	})
	maxText(t, 22)
	local s = new("TextLabel", {
		Position = UDim2.fromOffset(left, 36),
		Size = UDim2.new(1, -left - 190, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(210, 200, 235),
		Text = subtitle,
		Parent = row,
	})
	maxText(s, 16)
	return row
end

-- slot 1 = ganz rechts, slot 2 = links daneben
local function rowButton(row, slot, width, text, color, onClick)
	local right = 10
	if slot == 2 then
		right = 10 + 85 + 6
	end
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -right, 0.5, 0),
		Size = UDim2.fromOffset(width, 46),
		BackgroundColor3 = color,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = WHITE,
		Text = text,
		Parent = row,
	})
	corner(b, 10)
	maxText(b, 18)
	new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4), Parent = b })
	if onClick then
		b.Activated:Connect(onClick)
	end
	return b
end

local function affordColor(cost)
	return (data and data.coins >= cost) and GREEN or GRAY
end

local rebirthConfirm = false
local render = {}

function render.seeds()
	panelTitle.Text = "🌱 Samen-Shop"
	for i, c in ipairs(CRYSTALS) do
		local owned = data.seeds[c.id] or 0
		local title = c.id .. (owned > 0 and ("  (" .. owned .. ")") or "")
		local sub = "💰 " .. fmt(c.price) .. "  →  Wert " .. fmt(c.value * data.multiplier) .. "  ·  ⏱ " .. formatTime(c.time)
		local row = makeRow(i, title, sub, c.color)
		if data.rebirths < c.rebirth then
			rowButton(row, 1, 176, "🔒 " .. c.rebirth .. " Rebirth", GRAY)
		else
			rowButton(row, 1, 85, "x10", affordColor(c.price * 10), function()
				act("BuySeed", c.id, 10)
			end)
			rowButton(row, 2, 85, "x1", affordColor(c.price), function()
				act("BuySeed", c.id, 1)
			end)
		end
	end
	makeRow(99, "💡 Tipp", "6% Chance auf GOLD (x3 Wert), 1% auf REGENBOGEN (x10)!")
end

function render.upgrades()
	panelTitle.Text = "⬆️ Upgrades"
	local r1 = makeRow(1, "🟫 Mehr Felder", "Felder: " .. data.slots .. " / " .. data.maxSlots)
	if data.slotCost then
		rowButton(r1, 1, 176, "💰 " .. fmt(data.slotCost), affordColor(data.slotCost), function()
			act("Upgrade", "slots")
		end)
	else
		rowButton(r1, 1, 176, "MAX ✅", GRAY)
	end
	local r2 = makeRow(2, "⚡ Schneller wachsen", "Stufe " .. data.speed .. " / " .. data.maxSpeed .. "  ·  -10% Wachstumszeit pro Stufe")
	if data.speedCost then
		rowButton(r2, 1, 176, "💰 " .. fmt(data.speedCost), affordColor(data.speedCost), function()
			act("Upgrade", "speed")
		end)
	else
		rowButton(r2, 1, 176, "MAX ✅", GRAY)
	end
	makeRow(3, "ℹ️ Gilt für neu gepflanzte Kristalle", "Upgrades werden bei einem Rebirth zurückgesetzt.")
end

function render.rebirth()
	panelTitle.Text = "🔁 Rebirth"
	makeRow(1, "Rebirths: " .. data.rebirths, "Dein Münz-Multiplikator: " .. fmtMult(data.multiplier))
	makeRow(2, "Was passiert?", "Münzen, Samen, Felder & Upgrades werden zurückgesetzt …")
	makeRow(3, "… aber du bekommst:", "+50% Münzen für immer und neue Kristalle (Diamant, Sternenkristall)!")
	local r = makeRow(4, "Kosten", "💰 " .. fmt(data.rebirthCost))
	local text = rebirthConfirm and "Sicher? Nochmal!" or "🔁 Rebirth!"
	rowButton(r, 1, 176, text, rebirthConfirm and RED or affordColor(data.rebirthCost), function()
		if data.coins < data.rebirthCost then
			act("Rebirth") -- zeigt die Fehlermeldung
			return
		end
		if rebirthConfirm then
			rebirthConfirm = false
			act("Rebirth")
		else
			rebirthConfirm = true
			render.open("rebirth")
		end
	end)
end

function render.robux()
	panelTitle.Text = "💎 Robux-Shop"
	local function passRow(order, title, sub, id, owned)
		local row = makeRow(order, title, sub)
		if owned then
			rowButton(row, 1, 176, "✅ Gekauft", GRAY)
		elseif id == 0 then
			rowButton(row, 1, 176, "Bald verfügbar", GRAY)
		else
			rowButton(row, 1, 176, "💎 Kaufen", PINK, function()
				MarketplaceService:PromptGamePassPurchase(player, id)
			end)
		end
	end
	local function productRow(order, title, sub, id)
		local row = makeRow(order, title, sub)
		if id == 0 then
			rowButton(row, 1, 176, "Bald verfügbar", GRAY)
		else
			rowButton(row, 1, 176, "💎 Kaufen", PINK, function()
				MarketplaceService:PromptProductPurchase(player, id)
			end)
		end
	end
	passRow(1, "💰 Doppelte Münzen", "Für immer x2 Münzen beim Verkaufen", CONFIG.GAMEPASS_DOUBLE_COINS, data.doubleCoins)
	passRow(2, "⚡ Turbo-Wachstum", "Für immer: Kristalle wachsen 2x schneller", CONFIG.GAMEPASS_FAST_GROW, data.fastGrow)
	productRow(3, "💰 Münzpaket", "+" .. fmt(data.smallPack) .. " Münzen", CONFIG.PRODUCT_COINS_SMALL)
	productRow(4, "💰 Riesen-Münzpaket", "+" .. fmt(data.bigPack) .. " Münzen", CONFIG.PRODUCT_COINS_BIG)
	productRow(5, "⏩ Sofort fertig", "Alle gepflanzten Kristalle sofort fertig", CONFIG.PRODUCT_INSTANT_GROW)
end

function render.open(name)
	if not data then
		return
	end
	if name ~= "rebirth" then
		rebirthConfirm = false
	end
	openPanel = name
	clearList()
	render[name]()
	panel.Visible = true
end

local function closePanel()
	openPanel = nil
	rebirthConfirm = false
	panel.Visible = false
end
closeBtn.Activated:Connect(closePanel)

local function toggle(name)
	if openPanel == name then
		closePanel()
	else
		render.open(name)
	end
end

menuButton("🌱 Samen", GREEN, 1, function()
	toggle("seeds")
end)
menuButton("⬆️ Upgrades", BLUE, 2, function()
	toggle("upgrades")
end)
local sellBtn = menuButton("💰 Verkaufen", GOLD, 3, function()
	act("SellAll")
end)
menuButton("🔁 Rebirth", Color3.fromRGB(150, 70, 220), 4, function()
	toggle("rebirth")
end)
local dailyBtn = menuButton("🎁 Täglich", RED, 5, function()
	act("Daily")
end)
menuButton("💎 Robux-Shop", PINK, 6, function()
	toggle("robux")
end)

------------------------------------------------------------------------
-- Anzeige aktualisieren
------------------------------------------------------------------------
local function renderHotbar()
	for _, child in ipairs(hotbar:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local any = false
	for i, c in ipairs(CRYSTALS) do
		local count = data.seeds[c.id] or 0
		if count > 0 then
			any = true
			local selected = data.selected == c.id
			local b = new("TextButton", {
				Size = UDim2.fromOffset(96, 50),
				BackgroundColor3 = selected and ACCENT or PANEL,
				Font = Enum.Font.GothamBold,
				TextScaled = true,
				TextColor3 = WHITE,
				Text = c.id .. "\n" .. count .. "x",
				LayoutOrder = i,
				Parent = hotbar,
			})
			corner(b, 10)
			stroke(b, selected and WHITE or c.color, selected and 3 or 2)
			maxText(b, 16)
			b.Activated:Connect(function()
				act("Select", c.id)
			end)
		end
	end
	if not any then
		local l = new("TextLabel", {
			Size = UDim2.fromOffset(420, 40),
			BackgroundColor3 = PANEL,
			BackgroundTransparency = 0.2,
			Font = Enum.Font.GothamBold,
			TextScaled = true,
			TextColor3 = WHITE,
			Text = "Keine Samen – kaufe welche im 🌱 Samen-Shop!",
			Parent = hotbar,
		})
		corner(l, 10)
		maxText(l, 18)
	end
end

local function updateDaily()
	if not data then
		return
	end
	local left = data.dailyIn - (os.clock() - dataTime)
	if left > 0 then
		dailyBtn.Text = "🎁 " .. formatTime(left)
		dailyBtn.BackgroundColor3 = GRAY
	else
		dailyBtn.Text = "🎁 Abholen!"
		dailyBtn.BackgroundColor3 = RED
	end
end

local function refreshAll()
	coinsLabel.Text = "💰 " .. fmt(data.coins)
	multLabel.Text = "🔁 " .. data.rebirths .. " Rebirths  ·  Münzen " .. fmtMult(data.multiplier)
	sellBtn.Text = data.inventoryValue > 0 and ("💰 Verkaufen\n+" .. fmt(data.inventoryValue)) or "💰 Verkaufen"
	hint.Visible = data.totalEarned == 0
	renderHotbar()
	updateDaily()
	if openPanel then
		render.open(openPanel)
	end
end

DataUpdate.OnClientEvent:Connect(function(snap)
	data = snap
	dataTime = os.clock()
	refreshAll()
end)

-- Erste Daten holen (Server lädt evtl. noch)
task.spawn(function()
	while not data do
		local snap = act("GetData")
		if type(snap) == "table" and not data then
			data = snap
			dataTime = os.clock()
			refreshAll()
		end
		task.wait(1)
	end
end)

task.spawn(function()
	while true do
		updateScale()
		updateDaily()
		task.wait(1)
	end
end)

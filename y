--!nonstrict
--[[
	KizzDev - Malam Sama Opah
	Version 20.0.0

	Client-side helper for "[CLASS] MALAM SAMA OPAH" by Sabun Studios
	(place 101051454784523, universe 10772066587).

	v20 Features:
		* Animated KizzDev intro splash
		* Purple fire around the UI window (sides + top/bottom, embers, pulsing border)
		* ESP: Opah, keys, passcode note, front door, locks, wardrobes, drawers, Opah tracer
		* Opah radar: state, distance, chase target + danger bars when chased
		* Passcode overlay with clipboard copy
		* Auto loot: drawers, keys, passcode note, flip flops, locks (walk or teleport)
		* Auto hide: nearest wardrobe while Opah is chasing
		* Player: speed, jump power, infinite jump, noclip, fullbright, FOV, anti AFK
		* Teleport / walk to markers, save and return to position
		* Rejoin and server hop
		* Diagnostics ("Check my game")

	UI: Robly Airflow (bobloscript/Robly_Airflow).
	Language: English only.
]]

local VERSION = "20.0.0"
local BRAND = "KizzDev"
local GAME_NAME = "[CLASS] MALAM SAMA OPAH"
local GAME_PLACE_ID = 101051454784523

--== Re-execution guard ==
local environment = (typeof(getgenv) == "function" and getgenv()) or _G
if environment.KZ_Unload then
	pcall(environment.KZ_Unload)
end
if environment.RMSO_Unload then
	pcall(environment.RMSO_Unload)
end

--== Services ==
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

--== Constants ==
local COLOR_OPAH = Color3.fromRGB(255, 60, 60)
local COLOR_KEY_UNKNOWN = Color3.fromRGB(240, 240, 240)
local COLOR_NOTE = Color3.fromRGB(255, 255, 255)
local COLOR_DOOR = Color3.fromRGB(255, 165, 40)
local COLOR_WARDROBE = Color3.fromRGB(70, 220, 120)
local COLOR_DRAWER = Color3.fromRGB(220, 200, 90)

local KEY_COLORS = {
	Red = Color3.fromRGB(255, 75, 75),
	Blue = Color3.fromRGB(80, 140, 255),
	Green = Color3.fromRGB(75, 220, 115),
	Yellow = Color3.fromRGB(255, 210, 60),
	Purple = Color3.fromRGB(185, 105, 255),
}

local KEY_ORDER = { "Red", "Blue", "Green", "Yellow", "Purple" }

local FIRE_PRESETS = {
	Purple = { Color3.fromRGB(245, 215, 255), Color3.fromRGB(176, 92, 255), Color3.fromRGB(70, 18, 150) },
	Violet = { Color3.fromRGB(225, 205, 255), Color3.fromRGB(125, 90, 255), Color3.fromRGB(40, 20, 130) },
	Magenta = { Color3.fromRGB(255, 220, 245), Color3.fromRGB(255, 70, 190), Color3.fromRGB(110, 10, 90) },
	Blue = { Color3.fromRGB(215, 240, 255), Color3.fromRGB(70, 150, 255), Color3.fromRGB(15, 40, 140) },
}

--== State ==
local hub = {
	running = true,
	world = {
		drawers = {},
		flipflops = {},
		wardrobes = {},
		keys = {},
		locks = {},
		note = nil,
		opah = nil,
		door = nil,
		code = nil,
		drawerTotal = 0,
	},
	esp = {},
	code = nil,
	hiddenPrompt = nil,
	hideInProgress = false,
	savedPosition = nil,
	danger = false,
	wasDanger = false,
	lastAlert = 0,
}

local lootBlacklist = {}
local connections = {}

local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end

--== Helpers ==
local function getRoot()
	local character = LocalPlayer.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
	local character = LocalPlayer.Character
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

local function getCamera()
	return workspace.CurrentCamera
end

local function instancePosition(instance)
	if not instance then
		return nil
	end
	if instance:IsA("BasePart") then
		return instance.Position
	end
	if instance:IsA("Attachment") then
		return instance.WorldPosition
	end
	if instance:IsA("Model") then
		local ok, pivot = pcall(function()
			return instance:GetPivot()
		end)
		if ok and pivot then
			return pivot.Position
		end
	end
	return nil
end

local function promptPosition(prompt)
	if not prompt then
		return nil
	end
	return instancePosition(prompt.Parent)
end

local function distanceBetween(a, b)
	if not a or not b then
		return math.huge
	end
	return (a - b).Magnitude
end

local function escapeRich(text)
	if type(text) ~= "string" then
		return ""
	end
	local result = text:gsub("&", "&amp;")
	result = result:gsub("<", "&lt;")
	result = result:gsub(">", "&gt;")
	return result
end

local function isAlive()
	local root = getRoot()
	local humanoid = getHumanoid()
	if not root or not humanoid then
		return false
	end
	if humanoid.Health <= 0 then
		return false
	end
	if LocalPlayer:GetAttribute("Out") == true then
		return false
	end
	return true
end

local function toggleValue(handle)
	return handle ~= nil and handle.Value == true
end

local function numberValue(handle, fallback)
	local value = handle and handle.Value
	if type(value) == "number" then
		return value
	end
	return fallback
end

local function selectedValues(handle)
	local value = handle and handle.Value
	if type(value) == "table" then
		return value
	end
	if type(value) == "string" then
		return { value }
	end
	return {}
end

local function listContains(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

local function stringValue(handle, fallback)
	local value = handle and handle.Value
	if type(value) == "string" then
		return value
	end
	if type(value) == "table" and type(value[1]) == "string" then
		return value[1]
	end
	return fallback
end

--== Overlay parent ==
local guiParent = LocalPlayer:WaitForChild("PlayerGui")
if typeof(gethui) == "function" then
	local ok, hidden = pcall(gethui)
	if ok and hidden then
		guiParent = hidden
	end
end

--== Intro splash ==
local function playSplash()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KZ_Splash"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1000
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = guiParent

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(7, 5, 12)
	backdrop.BackgroundTransparency = 0.05
	backdrop.BorderSizePixel = 0
	backdrop.Parent = gui

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.new(0.5, 0, 0.46, 12)
	title.Size = UDim2.fromOffset(520, 80)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 68
	title.Text = "KIZZDEV"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextTransparency = 1
	title.Parent = backdrop

	local titleGradient = Instance.new("UIGradient")
	titleGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(235, 200, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(176, 92, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 40, 220)),
	})
	titleGradient.Parent = title

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Color = Color3.fromRGB(150, 70, 255)
	titleStroke.Thickness = 2
	titleStroke.Transparency = 1
	titleStroke.Parent = title

	local subtitle = Instance.new("TextLabel")
	subtitle.AnchorPoint = Vector2.new(0.5, 0.5)
	subtitle.Position = UDim2.new(0.5, 0, 0.46, 62)
	subtitle.Size = UDim2.fromOffset(520, 24)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamMedium
	subtitle.TextSize = 15
	subtitle.Text = "MALAM SAMA OPAH  |  v20"
	subtitle.TextColor3 = Color3.fromRGB(190, 160, 235)
	subtitle.TextTransparency = 1
	subtitle.Parent = backdrop

	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 0.5)
	track.Position = UDim2.new(0.5, 0, 0.46, 104)
	track.Size = UDim2.fromOffset(260, 4)
	track.BackgroundColor3 = Color3.fromRGB(40, 28, 64)
	track.BorderSizePixel = 0
	track.BackgroundTransparency = 1
	track.Parent = backdrop

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.fromRGB(176, 92, 255)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local fillGradient = Instance.new("UIGradient")
	fillGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 40, 220)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(235, 190, 255)),
	})
	fillGradient.Parent = fill

	local fadeIn = TweenInfo.new(0.6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	TweenService:Create(title, fadeIn, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.46, 0) }):Play()
	TweenService:Create(titleStroke, fadeIn, { Transparency = 0.35 }):Play()
	TweenService:Create(subtitle, TweenInfo.new(0.8), { TextTransparency = 0.1 }):Play()
	TweenService:Create(track, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
	TweenService:Create(fill, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Size = UDim2.fromScale(1, 1) }):Play()

	task.wait(2.3)

	local fadeOut = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
	TweenService:Create(backdrop, fadeOut, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(title, fadeOut, { TextTransparency = 1, Position = UDim2.new(0.5, 0, 0.46, -16) }):Play()
	TweenService:Create(titleStroke, fadeOut, { Transparency = 1 }):Play()
	TweenService:Create(subtitle, fadeOut, { TextTransparency = 1 }):Play()
	TweenService:Create(track, fadeOut, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(fill, fadeOut, { BackgroundTransparency = 1 }):Play()
	task.wait(0.6)
	gui:Destroy()
end

task.spawn(function()
	pcall(playSplash)
end)

--== Airflow UI ==
local UI_SOURCES = {
	"https://raw.githubusercontent.com/bobloscript/Robly_Airflow/main/Source.luau",
	"https://raw.githubusercontent.com/PookiePepelsss/Airflow-UI/refs/heads/main/Source.luau",
}

local Airflow = nil
for _, url in ipairs(UI_SOURCES) do
	local ok, library = pcall(function()
		return loadstring(game:HttpGet(url))()
	end)
	if ok and type(library) == "table" and type(library.CreateWindow) == "function" then
		Airflow = library
		break
	end
end

if not Airflow then
	warn("[KZ] Airflow UI could not be loaded")
	return
end

local THEME = {
	Background = Color3.fromHex("#08060D"),
	Surface = Color3.fromHex("#110D1A"),
	Surface2 = Color3.fromHex("#18122A"),
	Surface3 = Color3.fromHex("#2A2046"),
	Stroke = Color3.fromRGB(48, 36, 76),
	StrokeHover = Color3.fromRGB(86, 62, 140),
	Accent = Color3.fromHex("#A855F7"),
	AccentDark = Color3.fromHex("#150A26"),
	Text = Color3.fromHex("#F5F1FF"),
	Muted = Color3.fromHex("#9A90B5"),
}

if Airflow.ThemePresets then
	Airflow.ThemePresets.KizzDev = THEME
end
Airflow:SetDefaultTheme(THEME)

-- Snapshot existing ScreenGuis so the fire can find the window the library creates.
local preExistingGuis = {}
do
	local roots = { guiParent, LocalPlayer:FindFirstChild("PlayerGui") }
	pcall(function()
		table.insert(roots, game:GetService("CoreGui"))
	end)
	for _, root in ipairs(roots) do
		if root then
			local ok, children = pcall(function()
				return root:GetChildren()
			end)
			if ok then
				for _, child in ipairs(children) do
					preExistingGuis[child] = true
				end
			end
		end
	end
end

local Window = Airflow:CreateWindow({
	Name = BRAND .. " - Malam Sama Opah",
	LoadingSubtitle = "fire ui, esp, radar, auto loot",
	ToggleUIKeybind = "RightControl",
	Size = UDim2.fromOffset(780, 540),
	Backdrop = { Weather = "Fireflies", Tint = 0.35 },
	Theme = THEME,
	ConfigurationSaving = { Enabled = true, FolderName = "KizzDevMalamSamaOpah" },
	Home = {
		Title = BRAND .. " Hub",
		Welcome = "Welcome back,",
		Tier = "v20 FULL",
		Stats = { "Players", "Session", "FPS", "Ping", "Game", "Executor" },
	},
})

--== UI handles (assigned below, read by the loops) ==
local EspOpah, EspKeys, EspNote, EspDoor, EspWardrobe, EspDrawer, EspTracer
local EspLabels, EspMaxDistance, RadarEnabled, PasscodeOverlay
local FireEnabled, FireIntensity, FireColor, ChaseAlert
local AutoLoot, LootTargets, LootMode, LootRange, PauseOnChase
local AutoHide, HideRange, HideMode
local TeleportTarget
local SpeedToggle, SpeedValue, JumpToggle, JumpValue, InfJump, Noclip, Fullbright, FovToggle, FovValue, AntiAfk
local ActivityLog
local KeysStatus, LocksStatus, PasscodeStatus, OpahStateStatus, LootStatus, HideStatus

local function pushLog(text)
	if ActivityLog then
		pcall(function()
			ActivityLog:Push(text)
		end)
	end
end

local function notify(title, content, style)
	pcall(function()
		Window:Notify({ Title = title, Content = content, Type = style or "Info" })
	end)
end

if game.PlaceId ~= GAME_PLACE_ID then
	task.delay(2.5, function()
		notify("Wrong game?", "This script is made for " .. GAME_NAME, "Warning")
	end)
end

--== World scan ==
local function readPasscodeLabel(note)
	if not note then
		return nil
	end
	local label = note:FindFirstChild("Code", true)
	if label and label:IsA("TextLabel") then
		local text = label.Text
		if type(text) == "string" and text:gsub("%s", "") ~= "" then
			return text
		end
	end
	return nil
end

local function scanWorld()
	local world = {
		drawers = {},
		flipflops = {},
		wardrobes = {},
		keys = {},
		locks = {},
		note = nil,
		opah = workspace:FindFirstChild("Opah"),
		door = workspace:FindFirstChild("FrontDoor"),
		code = nil,
		drawerTotal = 0,
	}

	local chests = workspace:FindFirstChild("PuzzleChests")
	if chests then
		for _, instance in ipairs(chests:GetDescendants()) do
			if instance:IsA("ProximityPrompt") then
				if instance.ActionText == "Open" then
					table.insert(world.drawers, instance)
					world.drawerTotal = world.drawerTotal + 1
				elseif instance.ActionText == "Close" then
					world.drawerTotal = world.drawerTotal + 1
				end
			end
		end
	end

	local flipFlops = workspace:FindFirstChild("FlipFlops")
	if flipFlops then
		for _, instance in ipairs(flipFlops:GetDescendants()) do
			if instance:IsA("ProximityPrompt") and instance.ActionText == "Pick up" then
				table.insert(world.flipflops, instance)
			end
		end
	end

	local wardrobes = workspace:FindFirstChild("HidingWardrobes")
	if wardrobes then
		for _, instance in ipairs(wardrobes:GetDescendants()) do
			if instance:IsA("ProximityPrompt") and instance.ActionText == "Hide" then
				table.insert(world.wardrobes, instance)
			end
		end
	end

	local items = workspace:FindFirstChild("PuzzleItems")
	if items then
		for _, child in ipairs(items:GetChildren()) do
			local itemType = child:GetAttribute("ItemType")
			if itemType == "Key" then
				table.insert(world.keys, child)
			elseif itemType == "Passcode" then
				world.note = child
				world.code = readPasscodeLabel(child)
			end
		end
	end

	local door = world.door
	if door then
		local locks = door:FindFirstChild("PuzzleLocks")
		if locks then
			for _, lock in ipairs(locks:GetChildren()) do
				table.insert(world.locks, lock)
			end
		end
	end

	hub.world = world

	for prompt in pairs(lootBlacklist) do
		if prompt.Parent == nil then
			lootBlacklist[prompt] = nil
		end
	end

	if world.code and world.code ~= hub.code then
		hub.code = world.code
		pushLog("<Accent>Passcode</Accent> found: <b>" .. escapeRich(world.code) .. "</b>")
	end
end

local function keyColor(keyModel)
	local name = keyModel:GetAttribute("KeyColor")
	return KEY_COLORS[name] or COLOR_KEY_UNKNOWN, name
end

local function lockColor(lockModel)
	local value = lockModel:GetAttribute("KeyColorValue")
	if typeof(value) == "Color3" then
		return value
	end
	local name = lockModel:GetAttribute("KeyColor")
	return KEY_COLORS[name] or COLOR_DOOR
end

local function lockPrompt(lockModel)
	for _, descendant in ipairs(lockModel:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then
			return descendant
		end
	end
	return nil
end

local function findPickupPrompt(model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.ActionText == "Pick up" then
			return descendant
		end
	end
	return nil
end

local function wardrobeModelFromPrompt(prompt)
	local parent = prompt.Parent
	while parent and not parent:IsA("Model") do
		parent = parent.Parent
	end
	return parent
end

--== ESP ==
local function createEspEntry(instance, color, labelText, withLabel)
	local highlight = Instance.new("Highlight")
	highlight.Name = "KZ_Highlight"
	highlight.FillColor = color
	highlight.FillTransparency = 0.72
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = instance
	highlight.Parent = instance

	local billboard = nil
	if withLabel and labelText then
		billboard = Instance.new("BillboardGui")
		billboard.Name = "KZ_Label"
		billboard.Size = UDim2.fromOffset(150, 22)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
		billboard.AlwaysOnTop = true
		billboard.MaxDistance = 600
		billboard.LightInfluence = 0
		billboard.Adornee = instance

		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.GothamBold
		text.TextSize = 13
		text.TextColor3 = color
		text.TextStrokeTransparency = 0.35
		text.Text = labelText
		text.Parent = billboard

		billboard.Parent = instance
	end

	return { highlight = highlight, billboard = billboard, labelText = labelText }
end

local function destroyEspEntry(entry)
	if entry.highlight then
		pcall(function()
			entry.highlight:Destroy()
		end)
	end
	if entry.billboard then
		pcall(function()
			entry.billboard:Destroy()
		end)
	end
end

local function syncEsp()
	local origin = getCamera() and getCamera().CFrame.Position or Vector3.new(0, 0, 0)
	local maxDistance = numberValue(EspMaxDistance, 300)
	local withLabels = toggleValue(EspLabels)
	local desired = {}

	local function add(instance, color, labelText)
		if not instance then
			return
		end
		if instance.Parent == nil then
			return
		end
		local position = instancePosition(instance)
		if position and distanceBetween(position, origin) > maxDistance then
			return
		end
		desired[instance] = { color = color, label = labelText }
	end

	local world = hub.world

	if toggleValue(EspOpah) and world.opah then
		add(world.opah, COLOR_OPAH, "OPAH")
	end

	if toggleValue(EspKeys) then
		for _, key in ipairs(world.keys) do
			local color, name = keyColor(key)
			add(key, color, string.upper(name or "KEY") .. " KEY")
		end
	end

	if toggleValue(EspNote) and world.note then
		add(world.note, COLOR_NOTE, "PASSCODE")
	end

	if toggleValue(EspDoor) and world.door then
		add(world.door, COLOR_DOOR, "EXIT")
		local keypad = world.door:FindFirstChild("Keypad")
		if keypad then
			local plate = keypad:FindFirstChild("Plate", true)
			add(plate or keypad, COLOR_DOOR, "KEYPAD")
		end
		for _, lock in ipairs(world.locks) do
			add(lock, lockColor(lock), "LOCK")
		end
	end

	if toggleValue(EspWardrobe) then
		for _, prompt in ipairs(world.wardrobes) do
			local wardrobe = wardrobeModelFromPrompt(prompt)
			if wardrobe then
				add(wardrobe, COLOR_WARDROBE, "HIDE")
			end
		end
	end

	if toggleValue(EspDrawer) then
		for _, prompt in ipairs(world.drawers) do
			local drawer = prompt.Parent and prompt.Parent.Parent
			if drawer then
				add(drawer, COLOR_DRAWER, "DRAWER")
			end
		end
	end

	for instance, spec in pairs(desired) do
		local entry = hub.esp[instance]
		if not entry then
			hub.esp[instance] = createEspEntry(instance, spec.color, spec.label, withLabels)
		else
			entry.highlight.FillColor = spec.color
			entry.highlight.OutlineColor = spec.color
			if withLabels and not entry.billboard then
				destroyEspEntry(entry)
				hub.esp[instance] = createEspEntry(instance, spec.color, spec.label, true)
			elseif not withLabels and entry.billboard then
				entry.billboard:Destroy()
				entry.billboard = nil
			end
		end
	end

	for instance, entry in pairs(hub.esp) do
		if not desired[instance] or instance.Parent == nil then
			destroyEspEntry(entry)
			hub.esp[instance] = nil
		end
	end
end

local function clearEsp()
	for instance, entry in pairs(hub.esp) do
		destroyEspEntry(entry)
		hub.esp[instance] = nil
	end
end

--== Opah tracer (Drawing API, optional) ==
local tracer = nil
pcall(function()
	if Drawing and Drawing.new then
		tracer = Drawing.new("Line")
		tracer.Thickness = 1.5
		tracer.Color = Color3.fromRGB(190, 90, 255)
		tracer.Transparency = 1
		tracer.Visible = false
	end
end)

local function updateTracer()
	if not tracer then
		return
	end
	local ok = pcall(function()
		local opah = hub.world.opah
		local camera = getCamera()
		if toggleValue(EspTracer) and opah and camera then
			local position = instancePosition(opah)
			if position then
				local screen, onScreen = camera:WorldToViewportPoint(position)
				if onScreen then
					tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
					tracer.To = Vector2.new(screen.X, screen.Y)
					tracer.Visible = true
					return
				end
			end
		end
		tracer.Visible = false
	end)
	if not ok then
		tracer.Visible = false
	end
end

--== Overlay GUIs ==
local radarGui = Instance.new("ScreenGui")
radarGui.Name = "KZ_Radar"
radarGui.ResetOnSpawn = false
radarGui.IgnoreGuiInset = true
radarGui.DisplayOrder = 900
radarGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
radarGui.Parent = guiParent

local radarFrame = Instance.new("Frame")
radarFrame.Name = "Panel"
radarFrame.AnchorPoint = Vector2.new(0, 0)
radarFrame.Position = UDim2.fromOffset(16, 96)
radarFrame.Size = UDim2.fromOffset(232, 108)
radarFrame.BackgroundColor3 = THEME.Background
radarFrame.BackgroundTransparency = 0.12
radarFrame.BorderSizePixel = 0
radarFrame.Parent = radarGui

local radarCorner = Instance.new("UICorner")
radarCorner.CornerRadius = UDim.new(0, 10)
radarCorner.Parent = radarFrame

local radarStroke = Instance.new("UIStroke")
radarStroke.Color = THEME.Stroke
radarStroke.Thickness = 1.5
radarStroke.Parent = radarFrame

local radarTitle = Instance.new("TextLabel")
radarTitle.BackgroundTransparency = 1
radarTitle.Position = UDim2.fromOffset(12, 8)
radarTitle.Size = UDim2.new(1, -24, 0, 16)
radarTitle.Font = Enum.Font.GothamBold
radarTitle.TextSize = 11
radarTitle.TextXAlignment = Enum.TextXAlignment.Left
radarTitle.TextColor3 = Color3.fromRGB(190, 130, 255)
radarTitle.Text = "KIZZDEV OPAH RADAR - v20"
radarTitle.Parent = radarFrame

local function makeRadarLine(offsetY, textSize, color)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromOffset(12, offsetY)
	label.Size = UDim2.new(1, -24, 0, textSize + 4)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = color
	label.Text = ""
	label.Parent = radarFrame
	return label
end

local radarState = makeRadarLine(28, 13, THEME.Text)
local radarDistance = makeRadarLine(48, 12, THEME.Muted)
local radarTarget = makeRadarLine(68, 12, THEME.Muted)
local radarFooter = makeRadarLine(87, 11, THEME.Muted)

local passGui = Instance.new("ScreenGui")
passGui.Name = "KZ_Passcode"
passGui.ResetOnSpawn = false
passGui.IgnoreGuiInset = true
passGui.DisplayOrder = 900
passGui.Parent = guiParent

local passFrame = Instance.new("Frame")
passFrame.AnchorPoint = Vector2.new(0.5, 0)
passFrame.Position = UDim2.new(0.5, 0, 0, 14)
passFrame.Size = UDim2.fromOffset(268, 56)
passFrame.BackgroundColor3 = THEME.Background
passFrame.BackgroundTransparency = 0.1
passFrame.BorderSizePixel = 0
passFrame.Parent = passGui

local passCorner = Instance.new("UICorner")
passCorner.CornerRadius = UDim.new(0, 10)
passCorner.Parent = passFrame

local passStroke = Instance.new("UIStroke")
passStroke.Color = Color3.fromRGB(255, 255, 255)
passStroke.Thickness = 1.5
passStroke.Transparency = 0.1
passStroke.Parent = passFrame

local passStrokeGradient = Instance.new("UIGradient")
passStrokeGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 40, 220)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(235, 190, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(110, 40, 220)),
})
passStrokeGradient.Parent = passStroke

local passCaption = Instance.new("TextLabel")
passCaption.BackgroundTransparency = 1
passCaption.Position = UDim2.fromOffset(12, 6)
passCaption.Size = UDim2.new(1, -24, 0, 14)
passCaption.Font = Enum.Font.GothamBold
passCaption.TextSize = 10
passCaption.TextXAlignment = Enum.TextXAlignment.Left
passCaption.TextColor3 = THEME.Muted
passCaption.Text = "PASSCODE NOTE"
passCaption.Parent = passFrame

local passValue = Instance.new("TextLabel")
passValue.BackgroundTransparency = 1
passValue.Position = UDim2.fromOffset(12, 22)
passValue.Size = UDim2.new(1, -70, 0, 26)
passValue.Font = Enum.Font.GothamBold
passValue.TextSize = 22
passValue.TextXAlignment = Enum.TextXAlignment.Left
passValue.TextColor3 = THEME.Text
passValue.Text = "- - - -"
passValue.Parent = passFrame

local passCopy = Instance.new("TextButton")
passCopy.AnchorPoint = Vector2.new(1, 0.5)
passCopy.Position = UDim2.new(1, -10, 0.5, 0)
passCopy.Size = UDim2.fromOffset(52, 26)
passCopy.BackgroundColor3 = THEME.Surface3
passCopy.BorderSizePixel = 0
passCopy.Font = Enum.Font.GothamBold
passCopy.TextSize = 11
passCopy.TextColor3 = THEME.Text
passCopy.Text = "COPY"
passCopy.AutoButtonColor = true
passCopy.Parent = passFrame

local passCopyCorner = Instance.new("UICorner")
passCopyCorner.CornerRadius = UDim.new(0, 6)
passCopyCorner.Parent = passCopy

connect(passCopy.MouseButton1Click, function()
	local code = hub.code
	if code then
		local digits = code:gsub("%s", "")
		if typeof(setclipboard) == "function" then
			pcall(setclipboard, digits)
			passCopy.Text = "COPIED"
			task.delay(1.2, function()
				passCopy.Text = "COPY"
			end)
		end
	end
end)

-- Danger bars shown while Opah is chasing the local player
local dangerGui = Instance.new("ScreenGui")
dangerGui.Name = "KZ_Danger"
dangerGui.ResetOnSpawn = false
dangerGui.IgnoreGuiInset = true
dangerGui.DisplayOrder = 899
dangerGui.Parent = guiParent

local function makeDangerBar(anchorY)
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0, anchorY)
	bar.Position = UDim2.fromScale(0, anchorY)
	bar.Size = UDim2.new(1, 0, 0, 7)
	bar.BackgroundColor3 = Color3.fromRGB(255, 40, 60)
	bar.BackgroundTransparency = 1
	bar.BorderSizePixel = 0
	bar.Parent = dangerGui
	return bar
end

local dangerTop = makeDangerBar(0)
local dangerBottom = makeDangerBar(1)

--== Purple fire FX ==
local FLAME_COUNTS = { L = 14, R = 14, T = 18, B = 18 }
local EMBERS_PER_SIDE = 10

local fire = {
	gui = nil,
	holder = nil,
	border = nil,
	borderGradient = nil,
	flames = {},
	embers = {},
	target = nil,
	nextFind = 0,
	attempts = 0,
	preset = nil,
}

local function frameShown(frame)
	local node = frame
	while node and node ~= game do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("ScreenGui") and not node.Enabled then
			return false
		end
		node = node.Parent
	end
	return true
end

local function findWindowFrame()
	local best, bestScore = nil, math.huge
	local roots = { guiParent, LocalPlayer:FindFirstChild("PlayerGui") }
	pcall(function()
		table.insert(roots, game:GetService("CoreGui"))
	end)
	for _, root in ipairs(roots) do
		if root then
			local okChildren, children = pcall(function()
				return root:GetChildren()
			end)
			if okChildren then
				for _, gui in ipairs(children) do
					if gui:IsA("ScreenGui") and not preExistingGuis[gui] and string.sub(gui.Name, 1, 3) ~= "KZ_" then
						local okDesc, descendants = pcall(function()
							return gui:GetDescendants()
						end)
						if okDesc then
							for _, object in ipairs(descendants) do
								if object:IsA("Frame") then
									local size = object.AbsoluteSize
									local score = math.abs(size.X - 780) + math.abs(size.Y - 540)
									if size.X > 600 and size.Y > 400 and score < 60 and score < bestScore then
										best, bestScore = object, score
									end
								end
							end
						end
					end
				end
			end
		end
	end
	return best
end

local function applyFirePreset(name)
	local preset = FIRE_PRESETS[name] or FIRE_PRESETS.Purple
	fire.preset = name
	for _, flame in ipairs(fire.flames) do
		flame.gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, preset[1]),
			ColorSequenceKeypoint.new(0.35, preset[2]),
			ColorSequenceKeypoint.new(1, preset[3]),
		})
	end
	for _, ember in ipairs(fire.embers) do
		ember.frame.BackgroundColor3 = preset[2]
	end
	if fire.border then
		local stroke = fire.border:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = preset[2]
		end
	end
	if fire.borderGradient then
		fire.borderGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, preset[3]),
			ColorSequenceKeypoint.new(0.5, preset[1]),
			ColorSequenceKeypoint.new(1, preset[3]),
		})
	end
end

local function buildFire()
	local gui = Instance.new("ScreenGui")
	gui.Name = "KZ_Fire"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 1
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = guiParent
	fire.gui = gui

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	fire.holder = holder

	local border = Instance.new("Frame")
	border.Name = "Border"
	border.BackgroundTransparency = 1
	border.BorderSizePixel = 0
	border.Size = UDim2.fromScale(1, 1)
	border.ZIndex = 3
	border.Parent = holder
	fire.border = border

	local borderCorner = Instance.new("UICorner")
	borderCorner.CornerRadius = UDim.new(0, 12)
	borderCorner.Parent = border

	local borderStroke = Instance.new("UIStroke")
	borderStroke.Thickness = 2
	borderStroke.Color = FIRE_PRESETS.Purple[2]
	borderStroke.Transparency = 0.25
	borderStroke.Parent = border

	local borderGradient = Instance.new("UIGradient")
	borderGradient.Parent = borderStroke
	fire.borderGradient = borderGradient

	local sideConfig = {
		L = { pos = function(s) return UDim2.new(0, 6, s, 0) end, anchor = Vector2.new(1, 0.5), rotation = 180, horizontal = true },
		R = { pos = function(s) return UDim2.new(1, -6, s, 0) end, anchor = Vector2.new(0, 0.5), rotation = 0, horizontal = true },
		T = { pos = function(s) return UDim2.new(s, 0, 0, 6) end, anchor = Vector2.new(0.5, 1), rotation = 270, horizontal = false },
		B = { pos = function(s) return UDim2.new(s, 0, 1, -6) end, anchor = Vector2.new(0.5, 0), rotation = 90, horizontal = false },
	}

	for side, count in pairs(FLAME_COUNTS) do
		local config = sideConfig[side]
		for index = 1, count do
			local flame = Instance.new("Frame")
			flame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			flame.BorderSizePixel = 0
			flame.AnchorPoint = config.anchor
			flame.ZIndex = 2
			flame.Parent = holder

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = flame

			local gradient = Instance.new("UIGradient")
			gradient.Rotation = config.rotation
			gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.55, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			})
			gradient.Parent = flame

			table.insert(fire.flames, {
				frame = flame,
				gradient = gradient,
				side = side,
				index = index,
				count = count,
				config = config,
				phase = math.random() * math.pi * 2,
				speed = 2.2 + math.random() * 2.4,
			})
		end
	end

	for _, side in ipairs({ "L", "R" }) do
		for _ = 1, EMBERS_PER_SIDE do
			local ember = Instance.new("Frame")
			ember.BackgroundColor3 = FIRE_PRESETS.Purple[2]
			ember.BorderSizePixel = 0
			ember.ZIndex = 4
			ember.Parent = holder

			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = ember

			table.insert(fire.embers, {
				frame = ember,
				side = side,
				life = math.random(),
				speed = 0.25 + math.random() * 0.4,
				y = math.random(),
				drift = (math.random() - 0.5) * 36,
			})
		end
	end

	applyFirePreset("Purple")
end

local function updateFire(dt)
	local gui = fire.gui
	local holder = fire.holder
	if not gui or not holder then
		return
	end

	local enabled = toggleValue(FireEnabled)
	gui.Enabled = enabled
	if not enabled then
		return
	end

	local now = os.clock()
	if (not fire.target or not fire.target.Parent) and now >= fire.nextFind then
		fire.attempts = fire.attempts + 1
		fire.target = findWindowFrame()
		fire.nextFind = now + (fire.attempts < 8 and 1.5 or 6)
	end

	local target = fire.target
	if target and target.Parent then
		if not frameShown(target) then
			holder.Visible = false
			return
		end
		holder.Visible = true
		local position = target.AbsolutePosition
		local size = target.AbsoluteSize
		local insetY = 0
		local targetGui = target:FindFirstAncestorWhichIsA("ScreenGui")
		if targetGui and not targetGui.IgnoreGuiInset then
			insetY = GuiService:GetGuiInset().Y
		end
		holder.Position = UDim2.fromOffset(position.X, position.Y + insetY)
		holder.Size = UDim2.fromOffset(size.X, size.Y)
	else
		holder.Visible = true
		holder.Position = UDim2.fromOffset(0, 0)
		holder.Size = UDim2.fromScale(1, 1)
	end

	local presetName = stringValue(FireColor, "Purple")
	if presetName ~= fire.preset then
		applyFirePreset(presetName)
	end

	local intensity = numberValue(FireIntensity, 100) / 100
	local absolute = holder.AbsoluteSize

	for _, flame in ipairs(fire.flames) do
		local a = math.sin(now * flame.speed + flame.phase) * 0.5 + 0.5
		local b = math.sin(now * flame.speed * 2.3 + flame.phase * 1.7) * 0.5 + 0.5
		local length = (12 + 26 * a + 10 * b) * intensity
		local span = flame.config.horizontal and absolute.Y or absolute.X
		local thick = span / flame.count * 1.9
		local along = (flame.index - 0.5) / flame.count
		local wobble = math.sin(now * 2.1 + flame.phase) * 4
		local base = flame.config.pos(along)

		if flame.config.horizontal then
			flame.frame.Size = UDim2.fromOffset(length, thick)
			flame.frame.Position = UDim2.new(base.X.Scale, base.X.Offset, base.Y.Scale, wobble)
		else
			flame.frame.Size = UDim2.fromOffset(thick, length)
			flame.frame.Position = UDim2.new(base.X.Scale, wobble, base.Y.Scale, base.Y.Offset)
		end
		flame.frame.Visible = length > 2
	end

	for _, ember in ipairs(fire.embers) do
		ember.life = ember.life + dt * ember.speed * (0.6 + intensity * 0.6)
		if ember.life >= 1 then
			ember.life = 0
			ember.y = math.random()
			ember.drift = (math.random() - 0.5) * 36
			ember.speed = 0.25 + math.random() * 0.4
		end
		local life = ember.life
		local outward = life * 46 + 4
		local sizePx = math.max(1, 5 * (1 - life) + 1)
		ember.frame.Size = UDim2.fromOffset(sizePx, sizePx)
		ember.frame.BackgroundTransparency = 0.15 + 0.85 * life * life
		local xOffset = (ember.side == "L") and (-outward + ember.drift * life) or (outward + ember.drift * life)
		ember.frame.Position = UDim2.new(ember.side == "L" and 0 or 1, xOffset, ember.y, -life * 150)
	end

	if fire.borderGradient then
		fire.borderGradient.Rotation = (now * 70) % 360
	end
	local stroke = fire.border and fire.border:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Transparency = 0.15 + 0.2 * (math.sin(now * 3) * 0.5 + 0.5)
		stroke.Thickness = 1.6 + 0.9 * (math.sin(now * 2.4) * 0.5 + 0.5)
	end
end

buildFire()

-- Passcode overlay + radar ambient animation, danger bars
local function updateAmbient(now)
	passStrokeGradient.Rotation = (now * 90) % 360
	radarTitle.TextTransparency = 0.05 + 0.2 * (math.sin(now * 2.2) * 0.5 + 0.5)

	if hub.danger and toggleValue(ChaseAlert) then
		local pulse = 0.35 + 0.35 * (math.sin(now * 9) * 0.5 + 0.5)
		dangerTop.BackgroundTransparency = pulse
		dangerBottom.BackgroundTransparency = pulse
	else
		dangerTop.BackgroundTransparency = 1
		dangerBottom.BackgroundTransparency = 1
	end
end

do
	local accumulator = 0
	connect(RunService.RenderStepped, function(dt)
		if not hub.running then
			return
		end
		accumulator = accumulator + dt
		if accumulator < 1 / 45 then
			return
		end
		local step = accumulator
		accumulator = 0
		pcall(updateFire, step)
		pcall(updateAmbient, os.clock())
		updateTracer()
	end)
end

--== Prompt and movement helpers ==
local function triggerPrompt(prompt)
	if not prompt or not prompt.Enabled then
		return false
	end
	if typeof(fireproximityprompt) == "function" then
		local ok = pcall(fireproximityprompt, prompt)
		if ok then
			return true
		end
	end
	local ok = pcall(function()
		prompt:InputHoldBegin()
		if prompt.HoldDuration > 0 then
			task.wait(prompt.HoldDuration)
		end
		prompt:InputHoldEnd()
	end)
	return ok
end

local function teleportNear(position)
	local root = getRoot()
	if not root or not position then
		return false
	end

	local from = root.Position
	local direction = Vector3.new(from.X - position.X, 0, from.Z - position.Z)
	if direction.Magnitude < 1 then
		direction = Vector3.new(0, 0, 1)
	end

	local standPoint = position + direction.Unit * 3 + Vector3.new(0, 2.5, 0)
	local ok = pcall(function()
		root.CFrame = CFrame.lookAt(standPoint, Vector3.new(position.X, standPoint.Y, position.Z))
		root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end)
	return ok
end

local function walkTo(position, radius, timeout)
	local root = getRoot()
	local humanoid = getHumanoid()
	if not root or not humanoid or not position then
		return false
	end

	local deadline = os.clock() + (timeout or 6)
	humanoid:MoveTo(position)

	while os.clock() < deadline and hub.running do
		if not root.Parent then
			return false
		end
		local current = root.Position
		if distanceBetween(current, position) <= radius then
			humanoid:MoveTo(current)
			return true
		end
		if hub.hideInProgress then
			humanoid:MoveTo(current)
			return false
		end
		task.wait(0.08)
	end

	humanoid:MoveTo(root.Position)
	return distanceBetween(root.Position, position) <= radius + 4
end

--== Target resolution ==
local function nearestKey(origin)
	local best, bestDistance = nil, math.huge
	for _, key in ipairs(hub.world.keys) do
		local position = instancePosition(key)
		if position then
			local distance = distanceBetween(position, origin)
			if distance < bestDistance then
				best, bestDistance = key, distance
			end
		end
	end
	return best, bestDistance
end

local function nearestPrompt(prompts, origin)
	local best, bestDistance = nil, math.huge
	for _, prompt in ipairs(prompts) do
		if prompt.Enabled then
			local position = promptPosition(prompt)
			if position then
				local distance = distanceBetween(position, origin)
				if distance < bestDistance then
					best, bestDistance = prompt, distance
				end
			end
		end
	end
	return best, bestDistance
end

local function nearestWardrobePrompt(origin)
	return nearestPrompt(hub.world.wardrobes, origin)
end

local function resolveTargetPosition(kind)
	local world = hub.world
	local origin = getRoot() and getRoot().Position or (getCamera() and getCamera().CFrame.Position)

	if kind == "Passcode note" then
		return instancePosition(world.note)
	elseif kind == "Nearest key" then
		local key = nearestKey(origin)
		return instancePosition(key)
	elseif kind == "Front door" then
		return instancePosition(world.door)
	elseif kind == "Keypad" then
		local keypad = world.door and world.door:FindFirstChild("Keypad")
		local plate = keypad and keypad:FindFirstChild("Plate", true)
		return instancePosition(plate or keypad)
	elseif kind == "Nearest wardrobe" then
		return promptPosition((nearestPrompt(world.wardrobes, origin)))
	elseif kind == "Nearest drawer" then
		return promptPosition((nearestPrompt(world.drawers, origin)))
	elseif kind == "Nearest flip flop" then
		return promptPosition((nearestPrompt(world.flipflops, origin)))
	elseif kind == "Nearest lock" then
		local best, bestDistance = nil, math.huge
		for _, lock in ipairs(world.locks) do
			local position = instancePosition(lock)
			if position then
				local distance = distanceBetween(position, origin)
				if distance < bestDistance then
					best, bestDistance = position, distance
				end
			end
		end
		return best
	elseif kind == "Saved position" then
		return hub.savedPosition
	elseif kind == "Spawn" then
		local spawn = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
		return instancePosition(spawn)
	end
	return nil
end

--== Diagnostics ==
local function remotesSummary()
	local parts = {}
	local function addRemote(name, instance)
		if instance then
			table.insert(parts, name .. "=ok")
		else
			table.insert(parts, name .. "=missing")
		end
	end
	addRemote("WardrobeHide", ReplicatedStorage:FindFirstChild("WardrobeHideRemote"))
	local puzzleShared = ReplicatedStorage:FindFirstChild("PuzzleShared")
	local remotes = puzzleShared and puzzleShared:FindFirstChild("Remotes")
	if remotes then
		addRemote("PuzzleRemote", remotes:FindFirstChild("PuzzleRemote"))
		addRemote("SubmitPasscode", remotes:FindFirstChild("SubmitPasscode"))
	end
	local gameShared = ReplicatedStorage:FindFirstChild("GameShared")
	if gameShared then
		addRemote("GameRemote", gameShared:FindFirstChild("GameRemote"))
		addRemote("ReviveRemote", gameShared:FindFirstChild("ReviveRemote"))
		addRemote("JumpscareRemote", gameShared:FindFirstChild("JumpscareRemote"))
	end
	return table.concat(parts, " ")
end

local function keysSummary()
	local found = {}
	for _, key in ipairs(hub.world.keys) do
		local _, name = keyColor(key)
		if name then
			table.insert(found, name)
		end
	end
	local missing = {}
	for _, name in ipairs(KEY_ORDER) do
		if not listContains(found, name) then
			table.insert(missing, name)
		end
	end
	return found, missing
end

local function locksRemaining()
	local remaining = 0
	for _, lock in ipairs(hub.world.locks) do
		local prompt = lockPrompt(lock)
		if prompt and prompt.Enabled then
			remaining = remaining + 1
		end
	end
	return remaining
end

local function opahSummary()
	local opah = hub.world.opah
	if not opah then
		return nil
	end
	local root = getRoot()
	local origin = root and root.Position or (getCamera() and getCamera().CFrame.Position)
	local position = instancePosition(opah)
	local distance = 0
	if position and origin then
		distance = distanceBetween(position, origin)
	end
	return {
		state = tostring(opah:GetAttribute("State")),
		mode = tostring(opah:GetAttribute("Mode")),
		chasing = opah:GetAttribute("Chasing") == true,
		targetUserId = opah:GetAttribute("TargetUserId"),
		lair = tostring(opah:GetAttribute("Lair")),
		distance = distance,
	}
end

local function runDiagnostics()
	local lines = {}
	local root = getRoot()
	local lives = LocalPlayer:GetAttribute("Lives")
	local maxLives = LocalPlayer:GetAttribute("MaxLives")
	local duit = LocalPlayer:FindFirstChild("leaderstats") and LocalPlayer.leaderstats:FindFirstChild("Duit")
	local flops = LocalPlayer:GetAttribute("FlipFlopsFound")
	local found, missing = keysSummary()
	local opah = opahSummary()

	table.insert(lines, "<b>Diagnostics v" .. VERSION .. "</b>")
	table.insert(lines, "Game: " .. escapeRich(GAME_NAME) .. " | place " .. GAME_PLACE_ID)
	table.insert(lines, "Executor: " .. escapeRich(tostring(identifyexecutor and identifyexecutor() or "unknown")))
	table.insert(lines, "Character: " .. (root and "alive" or "none") .. " | Out=" .. tostring(LocalPlayer:GetAttribute("Out")))
	table.insert(lines, "Lives: " .. tostring(lives) .. "/" .. tostring(maxLives) .. " | Duit: " .. tostring(duit and duit.Value) .. " | Flip flops: " .. tostring(flops))
	table.insert(lines, "Keys in house: " .. #found .. "/5 | missing: " .. (#missing > 0 and table.concat(missing, ", ") or "none"))
	table.insert(lines, "Locks with active prompt: " .. locksRemaining() .. "/" .. #hub.world.locks)
	table.insert(lines, "Passcode: " .. (hub.code and escapeRich(hub.code) or "not read yet") .. (hub.world.note and "" or " (note picked up)"))
	table.insert(lines, "Drawers: openable " .. #hub.world.drawers .. " / total " .. hub.world.drawerTotal .. " | Wardrobes: " .. #hub.world.wardrobes)
	if opah then
		table.insert(lines, "Opah: state=" .. escapeRich(opah.state) .. " mode=" .. escapeRich(opah.mode) .. " chasing=" .. tostring(opah.chasing))
		table.insert(lines, "Opah distance: " .. tostring(math.floor(opah.distance)) .. " studs | target=" .. tostring(opah.targetUserId) .. " | lair=" .. escapeRich(opah.lair))
	else
		table.insert(lines, "Opah: not found in workspace")
	end
	table.insert(lines, "Remotes: " .. remotesSummary())
	table.insert(lines, "Fire window: " .. ((fire.target and fire.target.Parent) and "attached" or "screen edges") .. " | Tracer: " .. (tracer and "available" or "no Drawing API"))

	for _, line in ipairs(lines) do
		pushLog(line)
	end
	notify("Diagnostics", "Report added to Activity", "Success")
end

--== Radar / overlay updates ==
local function playerNameFromUserId(userId)
	if not userId then
		return nil
	end
	local player = Players:GetPlayerByUserId(userId)
	return player and player.Name or nil
end

local function updateDanger()
	local opah = opahSummary()
	local danger = opah ~= nil and opah.chasing and opah.targetUserId == LocalPlayer.UserId
	hub.danger = danger
	if danger and not hub.wasDanger and toggleValue(ChaseAlert) and os.clock() - hub.lastAlert > 6 then
		hub.lastAlert = os.clock()
		notify("Opah is chasing you", "Distance " .. math.floor(opah.distance) .. " studs", "Error")
		pushLog("<Error>Opah is chasing you</Error>")
	end
	hub.wasDanger = danger
end

local function updateRadar()
	updateDanger()

	if not toggleValue(RadarEnabled) then
		radarFrame.Visible = false
		return
	end
	radarFrame.Visible = true

	local opah = opahSummary()
	if not opah then
		radarState.Text = "No Opah in workspace"
		radarState.TextColor3 = THEME.Muted
		radarDistance.Text = ""
		radarTarget.Text = ""
		radarFooter.Text = "Hidden: " .. (hub.hiddenPrompt and "yes" or "no")
		radarStroke.Color = THEME.Stroke
		return
	end

	local isMine = opah.targetUserId == LocalPlayer.UserId
	local stateText = opah.state
	if opah.chasing then
		stateText = "CHASING - " .. opah.mode
	end
	radarState.Text = "State: " .. stateText
	radarDistance.Text = string.format("Distance: %d studs", math.floor(opah.distance or 0))

	if isMine then
		radarState.TextColor3 = Color3.fromRGB(255, 80, 80)
		radarStroke.Color = Color3.fromRGB(255, 60, 60)
	elseif opah.chasing then
		radarState.TextColor3 = Color3.fromRGB(255, 170, 60)
		radarStroke.Color = Color3.fromRGB(255, 160, 40)
	else
		radarState.TextColor3 = Color3.fromRGB(120, 220, 150)
		radarStroke.Color = Color3.fromRGB(150, 80, 240)
	end

	if isMine then
		radarTarget.Text = "Target: YOU"
		radarTarget.TextColor3 = Color3.fromRGB(255, 120, 120)
	else
		local name = playerNameFromUserId(opah.targetUserId)
		radarTarget.Text = "Target: " .. (name or "none")
		radarTarget.TextColor3 = THEME.Muted
	end

	radarFooter.Text = "Lair: " .. tostring(opah.lair) .. " | Hidden: " .. (hub.hiddenPrompt and "yes" or "no")
end

local function updatePasscodeOverlay()
	if not toggleValue(PasscodeOverlay) then
		passFrame.Visible = false
		return
	end
	passFrame.Visible = true
	if hub.code then
		passValue.Text = hub.code
	else
		passValue.Text = "- - - -"
	end
end

--== Auto loot ==
local function findLootTarget(origin)
	local selected = selectedValues(LootTargets)
	local best, bestDistance = nil, math.huge
	local maxRange = numberValue(LootRange, 250)

	local function consider(prompt, position, kind)
		if not prompt or not prompt.Enabled or not position then
			return
		end
		local expires = lootBlacklist[prompt]
		if expires and expires > os.clock() then
			return
		end
		local distance = distanceBetween(position, origin)
		if distance > maxRange then
			return
		end
		if distance < bestDistance then
			bestDistance = distance
			best = { prompt = prompt, position = position, kind = kind }
		end
	end

	if listContains(selected, "Drawers") then
		for _, prompt in ipairs(hub.world.drawers) do
			consider(prompt, promptPosition(prompt), "drawer")
		end
	end

	if listContains(selected, "Keys") then
		for _, key in ipairs(hub.world.keys) do
			local prompt = findPickupPrompt(key)
			consider(prompt, instancePosition(key), "key")
		end
	end

	if listContains(selected, "Passcode note") and hub.world.note then
		local prompt = findPickupPrompt(hub.world.note)
		consider(prompt, instancePosition(hub.world.note), "note")
	end

	if listContains(selected, "Flip flops") then
		for _, prompt in ipairs(hub.world.flipflops) do
			consider(prompt, promptPosition(prompt), "flip flop")
		end
	end

	if listContains(selected, "Locks") then
		for _, lock in ipairs(hub.world.locks) do
			consider(lockPrompt(lock), instancePosition(lock), "lock")
		end
	end

	return best
end

local function lootStep()
	if not toggleValue(AutoLoot) then
		return
	end
	if hub.hideInProgress or hub.hiddenPrompt then
		return
	end
	if not isAlive() then
		return
	end

	local root = getRoot()
	if not root then
		return
	end

	if toggleValue(PauseOnChase) then
		local opah = opahSummary()
		if opah and opah.chasing and opah.distance < 55 then
			return
		end
	end

	local target = findLootTarget(root.Position)
	if not target then
		return
	end

	local mode = stringValue(LootMode, "Walk")
	if mode == "Teleport" then
		teleportNear(target.position)
		task.wait(0.15)
	else
		local reached = walkTo(target.position, 7, 6)
		if not reached then
			lootBlacklist[target.prompt] = os.clock() + 15
			pushLog("<Muted>Skipped " .. escapeRich(target.kind) .. " (unreachable)</Muted>")
			return
		end
	end

	local fired = triggerPrompt(target.prompt)
	if fired then
		lootBlacklist[target.prompt] = os.clock() + 8
		pushLog("<Success>Looted</Success> " .. escapeRich(target.kind))
	else
		lootBlacklist[target.prompt] = os.clock() + 3
	end
	task.wait(0.2)
end

--== Auto hide ==
local function hideStep()
	if not toggleValue(AutoHide) then
		if hub.hiddenPrompt then
			triggerPrompt(hub.hiddenPrompt)
			hub.hiddenPrompt = nil
			pushLog("<Muted>Left the wardrobe (auto hide off)</Muted>")
		end
		return
	end

	local opah = opahSummary()
	local root = getRoot()

	if hub.hiddenPrompt then
		local safe = true
		if opah and opah.chasing then
			safe = opah.distance > numberValue(HideRange, 45) + 25
		end
		if safe or not root then
			triggerPrompt(hub.hiddenPrompt)
			pushLog("<Muted>Left the wardrobe</Muted>")
			hub.hiddenPrompt = nil
		end
		return
	end

	if not root or not opah then
		return
	end
	if not opah.chasing or opah.distance > numberValue(HideRange, 45) then
		return
	end

	local prompt = nearestWardrobePrompt(root.Position)
	if not prompt then
		return
	end

	hub.hideInProgress = true
	local mode = stringValue(HideMode, "Teleport")
	if mode == "Walk" then
		walkTo(promptPosition(prompt), 7, 5)
	else
		teleportNear(promptPosition(prompt))
		task.wait(0.2)
	end
	triggerPrompt(prompt)
	hub.hideInProgress = false
	hub.hiddenPrompt = prompt
	pushLog("<Warning>Hiding</Warning> - Opah is chasing")
end

--== Player mods ==
local mods = {
	humanoid = nil,
	defaultSpeed = 16,
	defaultJump = 50,
	defaultFov = 70,
	speedWasOn = false,
	jumpWasOn = false,
	fovWasOn = false,
	lighting = nil,
}

local function applyFullbright(on)
	if on then
		if not mods.lighting then
			local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
			mods.lighting = {
				Brightness = Lighting.Brightness,
				ClockTime = Lighting.ClockTime,
				FogEnd = Lighting.FogEnd,
				GlobalShadows = Lighting.GlobalShadows,
				Ambient = Lighting.Ambient,
				OutdoorAmbient = Lighting.OutdoorAmbient,
				AtmosphereDensity = atmosphere and atmosphere.Density or nil,
			}
		end
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 1000000
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(190, 190, 190)
		Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere then
			atmosphere.Density = 0
		end
	elseif mods.lighting then
		local backup = mods.lighting
		Lighting.Brightness = backup.Brightness
		Lighting.ClockTime = backup.ClockTime
		Lighting.FogEnd = backup.FogEnd
		Lighting.GlobalShadows = backup.GlobalShadows
		Lighting.Ambient = backup.Ambient
		Lighting.OutdoorAmbient = backup.OutdoorAmbient
		local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmosphere and backup.AtmosphereDensity then
			atmosphere.Density = backup.AtmosphereDensity
		end
		mods.lighting = nil
	end
end

local function updateMods()
	local humanoid = getHumanoid()
	if humanoid and humanoid ~= mods.humanoid then
		mods.humanoid = humanoid
		mods.defaultSpeed = humanoid.WalkSpeed
		mods.defaultJump = humanoid.JumpPower
		mods.speedWasOn = false
		mods.jumpWasOn = false
	end

	if humanoid then
		if toggleValue(SpeedToggle) then
			if not mods.speedWasOn then
				mods.defaultSpeed = humanoid.WalkSpeed
			end
			mods.speedWasOn = true
			humanoid.WalkSpeed = numberValue(SpeedValue, 32)
		elseif mods.speedWasOn then
			humanoid.WalkSpeed = mods.defaultSpeed
			mods.speedWasOn = false
		end

		if toggleValue(JumpToggle) then
			if not mods.jumpWasOn then
				mods.defaultJump = humanoid.JumpPower
			end
			mods.jumpWasOn = true
			humanoid.UseJumpPower = true
			humanoid.JumpPower = numberValue(JumpValue, 80)
		elseif mods.jumpWasOn then
			humanoid.JumpPower = mods.defaultJump
			mods.jumpWasOn = false
		end
	end

	local camera = getCamera()
	if camera then
		if toggleValue(FovToggle) then
			if not mods.fovWasOn then
				mods.defaultFov = camera.FieldOfView
			end
			mods.fovWasOn = true
			camera.FieldOfView = numberValue(FovValue, 90)
		elseif mods.fovWasOn then
			camera.FieldOfView = mods.defaultFov
			mods.fovWasOn = false
		end
	end

	applyFullbright(toggleValue(Fullbright))
end

connect(UserInputService.JumpRequest, function()
	if toggleValue(InfJump) then
		local humanoid = getHumanoid()
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

connect(RunService.Stepped, function()
	if not hub.running or not toggleValue(Noclip) then
		return
	end
	local character = LocalPlayer.Character
	if not character then
		return
	end
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
		end
	end
end)

connect(LocalPlayer.Idled, function()
	if toggleValue(AntiAfk) then
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new(0, 0))
		end)
	end
end)

--== Server utilities ==
local function rejoin()
	notify("Rejoin", "Rejoining this server", "Info")
	pcall(function()
		if #Players:GetPlayers() <= 1 then
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		else
			TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
		end
	end)
end

local function serverHop()
	notify("Server hop", "Searching for another server", "Info")
	task.spawn(function()
		local ok, result = pcall(function()
			local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
			return HttpService:JSONDecode(game:HttpGet(url))
		end)
		if not ok or type(result) ~= "table" or type(result.data) ~= "table" then
			notify("Server hop", "Could not read the server list", "Error")
			return
		end
		local candidates = {}
		for _, server in ipairs(result.data) do
			if server.id ~= game.JobId and type(server.playing) == "number" and type(server.maxPlayers) == "number" and server.playing < server.maxPlayers then
				table.insert(candidates, server.id)
			end
		end
		if #candidates == 0 then
			notify("Server hop", "No other server available", "Warning")
			return
		end
		pcall(function()
			TeleportService:TeleportToPlaceInstance(game.PlaceId, candidates[math.random(1, #candidates)], LocalPlayer)
		end)
	end)
end

--== UI construction ==
local DiagnosticsTab = Window:CreateTab({ Name = "Diagnostics", Icon = "activity" })
local DiagBox = DiagnosticsTab:CreateGroupbox({ Name = "Checklist", Side = "Left" })
local LogBox = DiagnosticsTab:CreateGroupbox({ Name = "Activity", Side = "Right" })

KeysStatus = DiagBox:CreateStatus({
	Name = "Keys",
	Style = "Row",
	Update = function()
		local found, missing = keysSummary()
		local text = #found .. "/5 in house"
		if #missing > 0 then
			text = text .. " | " .. table.concat(missing, ", ")
		end
		return "<Text>" .. text .. "</Text>"
	end,
	UpdateRate = 1,
})

LocksStatus = DiagBox:CreateStatus({
	Name = "Locks",
	Style = "Row",
	Update = function()
		return "<Text>" .. locksRemaining() .. " active prompts</Text>"
	end,
	UpdateRate = 1,
})

PasscodeStatus = DiagBox:CreateStatus({
	Name = "Passcode",
	Style = "Row",
	Update = function()
		if hub.code then
			return "<Success>" .. escapeRich(hub.code) .. "</Success>"
		end
		return "<Muted>waiting for note</Muted>"
	end,
	UpdateRate = 1,
})

OpahStateStatus = DiagBox:CreateStatus({
	Name = "Opah",
	Style = "Row",
	Pin = true,
	Update = function()
		local opah = opahSummary()
		if not opah then
			return "<Muted>not spawned</Muted>"
		end
		local text = escapeRich(opah.state) .. " | " .. math.floor(opah.distance) .. " studs"
		if opah.chasing then
			return "<Error>" .. text .. "</Error>"
		end
		return "<Success>" .. text .. "</Success>"
	end,
	UpdateRate = 0.5,
})

DiagBox:CreateButton({
	Name = "Check my game",
	Icon = "stethoscope",
	Callback = function()
		runDiagnostics()
	end,
})

ActivityLog = LogBox:CreateLog({
	Name = "Activity",
	MaxEntries = 300,
	MaxRows = 14,
	Timestamps = true,
	EmptyText = "Nothing yet",
})

local VisualsTab = Window:CreateTab({ Name = "Visuals", Icon = "eye" })
local EspBox = VisualsTab:CreateGroupbox({ Name = "ESP", Side = "Left" })
local OverlayBox = VisualsTab:CreateGroupbox({ Name = "Overlays", Side = "Right" })
local FxBox = VisualsTab:CreateGroupbox({ Name = "Purple fire", Side = "Right" })
local RangeBox = VisualsTab:CreateGroupbox({ Name = "Range", Side = "Right" })

EspOpah = EspBox:CreateToggle({
	Name = "Opah",
	Desc = "Highlight the ghost through walls",
	Flag = "EspOpah",
	CurrentValue = true,
})

EspTracer = EspBox:CreateToggle({
	Name = "Opah tracer",
	Desc = "Line from the screen bottom to Opah (needs Drawing API)",
	Flag = "EspTracer",
	CurrentValue = false,
})

EspKeys = EspBox:CreateToggle({
	Name = "Keys",
	Desc = "Colored highlight for every key still in the house",
	Flag = "EspKeys",
	CurrentValue = true,
})

EspNote = EspBox:CreateToggle({
	Name = "Passcode note",
	Flag = "EspNote",
	CurrentValue = true,
})

EspDoor = EspBox:CreateToggle({
	Name = "Front door and locks",
	Flag = "EspDoor",
	CurrentValue = true,
})

EspWardrobe = EspBox:CreateToggle({
	Name = "Wardrobes",
	Flag = "EspWardrobe",
	CurrentValue = false,
})

EspDrawer = EspBox:CreateToggle({
	Name = "Drawers",
	Desc = "Heavy: 60+ highlights",
	Flag = "EspDrawer",
	CurrentValue = false,
})

EspLabels = EspBox:CreateToggle({
	Name = "Text labels",
	Flag = "EspLabels",
	CurrentValue = true,
})

RadarEnabled = OverlayBox:CreateToggle({
	Name = "Opah radar",
	Desc = "State, distance and chase target",
	Flag = "RadarEnabled",
	CurrentValue = true,
})

PasscodeOverlay = OverlayBox:CreateToggle({
	Name = "Passcode overlay",
	Desc = "Reads the note and copies digits",
	Flag = "PasscodeOverlay",
	CurrentValue = true,
})

ChaseAlert = OverlayBox:CreateToggle({
	Name = "Chase alert",
	Desc = "Red pulsing bars and a notice when Opah chases you",
	Flag = "ChaseAlert",
	CurrentValue = true,
})

FireEnabled = FxBox:CreateToggle({
	Name = "Fire around UI",
	Desc = "Animated flames and embers on the window edges",
	Flag = "FireEnabled",
	CurrentValue = true,
})

FireColor = FxBox:CreateDropdown({
	Name = "Fire color",
	Options = { "Purple", "Violet", "Magenta", "Blue" },
	CurrentOption = "Purple",
	Flag = "FireColor",
})

FireIntensity = FxBox:CreateSlider({
	Name = "Fire intensity",
	Range = { 30, 200 },
	Increment = 10,
	Suffix = "%",
	CurrentValue = 100,
	Flag = "FireIntensity",
})

EspMaxDistance = RangeBox:CreateSlider({
	Name = "Max ESP distance",
	Range = { 50, 600 },
	Increment = 25,
	Suffix = " studs",
	CurrentValue = 300,
	Flag = "EspMaxDistance",
})

local AutomationTab = Window:CreateTab({ Name = "Automation", Icon = "bot" })
local LootBox = AutomationTab:CreateGroupbox({ Name = "Auto loot", Side = "Left" })
local HideBox = AutomationTab:CreateGroupbox({ Name = "Auto hide", Side = "Right" })
local StateBox = AutomationTab:CreateGroupbox({ Name = "State", Side = "Right" })

AutoLoot = LootBox:CreateToggle({
	Name = "Auto loot",
	Desc = "Opens drawers and picks up selected items",
	Flag = "AutoLoot",
	CurrentValue = false,
})

LootTargets = LootBox:CreateDropdown({
	Name = "Targets",
	Options = { "Drawers", "Keys", "Passcode note", "Flip flops", "Locks" },
	MultipleOptions = true,
	CurrentOption = { "Drawers", "Keys", "Passcode note" },
	Flag = "LootTargets",
})

LootMode = LootBox:CreateDropdown({
	Name = "Mode",
	Options = { "Walk", "Teleport" },
	CurrentOption = "Walk",
	Flag = "LootMode",
})

LootRange = LootBox:CreateSlider({
	Name = "Search range",
	Range = { 50, 500 },
	Increment = 25,
	Suffix = " studs",
	CurrentValue = 250,
	Flag = "LootRange",
})

PauseOnChase = LootBox:CreateToggle({
	Name = "Pause while chased",
	Flag = "PauseOnChase",
	CurrentValue = true,
})

AutoHide = HideBox:CreateToggle({
	Name = "Auto hide",
	Desc = "Runs to the nearest wardrobe when Opah chases",
	Flag = "AutoHide",
	CurrentValue = false,
})

HideRange = HideBox:CreateSlider({
	Name = "Trigger distance",
	Range = { 10, 120 },
	Increment = 5,
	Suffix = " studs",
	CurrentValue = 45,
	Flag = "HideRange",
})

HideMode = HideBox:CreateDropdown({
	Name = "Mode",
	Options = { "Teleport", "Walk" },
	CurrentOption = "Teleport",
	Flag = "HideMode",
})

HideBox:CreateButton({
	Name = "Leave wardrobe now",
	Icon = "door-open",
	Callback = function()
		if hub.hiddenPrompt then
			triggerPrompt(hub.hiddenPrompt)
			hub.hiddenPrompt = nil
			pushLog("<Muted>Leave wardrobe requested</Muted>")
		else
			pushLog("<Muted>Not hidden</Muted>")
		end
	end,
})

LootStatus = StateBox:CreateStatus({
	Name = "Loot",
	Style = "Row",
	Update = function()
		if toggleValue(AutoLoot) then
			return "<Success>running</Success>"
		end
		return "<Muted>idle</Muted>"
	end,
	UpdateRate = 0.5,
})

HideStatus = StateBox:CreateStatus({
	Name = "Hide",
	Style = "Row",
	Update = function()
		if hub.hiddenPrompt then
			return "<Warning>hidden</Warning>"
		end
		if toggleValue(AutoHide) then
			return "<Text>armed</Text>"
		end
		return "<Muted>idle</Muted>"
	end,
	UpdateRate = 0.5,
})

local PlayerTab = Window:CreateTab({ Name = "Player", Icon = "user" })
local MoveBox = PlayerTab:CreateGroupbox({ Name = "Movement", Side = "Left" })
local WorldBox = PlayerTab:CreateGroupbox({ Name = "World and camera", Side = "Right" })

SpeedToggle = MoveBox:CreateToggle({
	Name = "Walk speed",
	Flag = "SpeedToggle",
	CurrentValue = false,
})

SpeedValue = MoveBox:CreateSlider({
	Name = "Speed value",
	Range = { 16, 120 },
	Increment = 2,
	CurrentValue = 32,
	Flag = "SpeedValue",
})

JumpToggle = MoveBox:CreateToggle({
	Name = "Jump power",
	Flag = "JumpToggle",
	CurrentValue = false,
})

JumpValue = MoveBox:CreateSlider({
	Name = "Jump value",
	Range = { 50, 200 },
	Increment = 5,
	CurrentValue = 80,
	Flag = "JumpValue",
})

InfJump = MoveBox:CreateToggle({
	Name = "Infinite jump",
	Flag = "InfJump",
	CurrentValue = false,
})

Noclip = MoveBox:CreateToggle({
	Name = "Noclip",
	Desc = "Walk through walls and furniture",
	Flag = "Noclip",
	CurrentValue = false,
})

Fullbright = WorldBox:CreateToggle({
	Name = "Fullbright",
	Desc = "Removes darkness and fog, restores on disable",
	Flag = "Fullbright",
	CurrentValue = false,
})

FovToggle = WorldBox:CreateToggle({
	Name = "Custom FOV",
	Flag = "FovToggle",
	CurrentValue = false,
})

FovValue = WorldBox:CreateSlider({
	Name = "FOV value",
	Range = { 50, 120 },
	Increment = 2,
	CurrentValue = 90,
	Flag = "FovValue",
})

AntiAfk = WorldBox:CreateToggle({
	Name = "Anti AFK",
	Desc = "Prevents the idle kick",
	Flag = "AntiAfk",
	CurrentValue = true,
})

local TeleportTab = Window:CreateTab({ Name = "Teleport", Icon = "map-pin" })
local TeleportBox = TeleportTab:CreateGroupbox({ Name = "Markers", Side = "Left" })
local TeleportInfo = TeleportTab:CreateGroupbox({ Name = "Info", Side = "Right" })

TeleportTarget = TeleportBox:CreateDropdown({
	Name = "Destination",
	Options = {
		"Passcode note",
		"Nearest key",
		"Front door",
		"Keypad",
		"Nearest lock",
		"Nearest wardrobe",
		"Nearest drawer",
		"Nearest flip flop",
		"Saved position",
		"Spawn",
	},
	CurrentOption = "Passcode note",
	Flag = "TeleportTarget",
})

TeleportBox:CreateButton({
	Name = "Teleport",
	Icon = "move",
	Style = "Primary",
	Callback = function()
		local kind = stringValue(TeleportTarget, "Passcode note")
		local position = resolveTargetPosition(kind)
		if not position then
			notify("Teleport", "Target not found", "Warning")
			return
		end
		teleportNear(position)
		pushLog("<Success>Teleported</Success> to " .. escapeRich(kind))
	end,
})

TeleportBox:CreateButton({
	Name = "Walk to",
	Icon = "footprints",
	Callback = function()
		local kind = stringValue(TeleportTarget, "Passcode note")
		local position = resolveTargetPosition(kind)
		if not position then
			notify("Walk", "Target not found", "Warning")
			return
		end
		task.spawn(function()
			local ok = walkTo(position, 8, 15)
			if not ok then
				notify("Walk", "Target unreachable", "Warning")
			end
		end)
	end,
})

TeleportBox:CreateButton({
	Name = "Save current position",
	Icon = "bookmark",
	Callback = function()
		local root = getRoot()
		if root then
			hub.savedPosition = root.Position
			notify("Saved", "Pick 'Saved position' as destination to return", "Success")
			pushLog("<Accent>Position saved</Accent>")
		else
			notify("Save", "No character found", "Warning")
		end
	end,
})

TeleportInfo:CreateParagraph({
	Title = "Targets",
	Content = "Positions are resolved from the live workspace: note, keys, door, keypad, locks, wardrobes, drawers and flip flops.",
})

local SettingsTab = Window:CreateTab({ Name = "Settings", Icon = "settings" })
local AboutBox = SettingsTab:CreateGroupbox({ Name = "About", Side = "Right" })

SettingsTab:CreateConfigManager({ Name = "Configs", Side = "Left" })
SettingsTab:CreateThemeManager({ Name = "Theme", Side = "Right" })

SettingsTab:CreateButton({
	Name = "Copy passcode",
	Icon = "clipboard-copy",
	Callback = function()
		if hub.code and typeof(setclipboard) == "function" then
			local digits = hub.code:gsub("%s", "")
			pcall(setclipboard, digits)
			notify("Copied", "Passcode digits copied", "Success")
		else
			notify("Copy", "No passcode read yet", "Warning")
		end
	end,
})

SettingsTab:CreateButton({
	Name = "Rejoin server",
	Icon = "refresh-cw",
	Callback = rejoin,
})

SettingsTab:CreateButton({
	Name = "Server hop",
	Icon = "shuffle",
	Callback = serverHop,
})

SettingsTab:CreateButton({
	Name = "Unload",
	Icon = "power",
	Style = "Primary",
	Callback = function()
		if environment.KZ_Unload then
			environment.KZ_Unload()
		end
	end,
})

AboutBox:CreateParagraph({
	Title = BRAND .. " - Malam Sama Opah v" .. VERSION,
	Content = "Client helper for [CLASS] MALAM SAMA OPAH. Purple fire UI, ESP, radar, passcode overlay, auto loot, auto hide, player mods, teleport. RightControl toggles the window.",
})

AboutBox:CreateDivider()

AboutBox:CreateLabel({
	Text = "Game: " .. GAME_NAME,
})

AboutBox:CreateLabel({
	Text = "Place: " .. GAME_PLACE_ID,
})

--== Unload ==
local function unload()
	hub.running = false
	for _, connection in ipairs(connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(connections)
	clearEsp()
	pcall(function()
		applyFullbright(false)
	end)
	pcall(function()
		local humanoid = getHumanoid()
		if humanoid and mods.speedWasOn then
			humanoid.WalkSpeed = mods.defaultSpeed
		end
		if humanoid and mods.jumpWasOn then
			humanoid.JumpPower = mods.defaultJump
		end
		local camera = getCamera()
		if camera and mods.fovWasOn then
			camera.FieldOfView = mods.defaultFov
		end
	end)
	if tracer then
		pcall(function()
			tracer:Remove()
		end)
	end
	for _, gui in ipairs({ radarGui, passGui, dangerGui, fire.gui }) do
		pcall(function()
			gui:Destroy()
		end)
	end
	pcall(function()
		Window:Destroy()
	end)
	environment.KZ_Unload = nil
	environment.KZ = nil
	print("[KZ] unloaded")
end
environment.KZ_Unload = unload

--== Debug API ==
environment.KZ = {
	version = VERSION,
	hub = hub,
	triggerPrompt = triggerPrompt,
	walkTo = walkTo,
	teleportNear = teleportNear,
	lootStep = lootStep,
	hideStep = hideStep,
	runDiagnostics = runDiagnostics,
	toggle = function(name, value)
		local handles = {
			AutoLoot = AutoLoot,
			AutoHide = AutoHide,
			LootTargets = LootTargets,
			LootMode = LootMode,
			HideMode = HideMode,
			EspDrawer = EspDrawer,
			EspWardrobe = EspWardrobe,
			FireEnabled = FireEnabled,
			FireColor = FireColor,
		}
		local handle = handles[name]
		if handle and handle.Set then
			handle:Set(value)
			return true
		end
		return false
	end,
}

--== Background loops ==
local function loop(label, interval, callback)
	task.spawn(function()
		while hub.running do
			local ok, err = pcall(callback)
			if not ok then
				warn("[KZ] " .. label .. ": " .. tostring(err))
			end
			task.wait(interval)
		end
	end)
end

loop("scan", 1, scanWorld)
loop("esp", 0.5, syncEsp)
loop("radar", 0.2, updateRadar)
loop("overlay", 0.5, updatePasscodeOverlay)
loop("mods", 0.1, updateMods)

task.spawn(function()
	while hub.running do
		if toggleValue(AutoLoot) then
			local ok, err = pcall(lootStep)
			if not ok then
				pushLog("<Error>Loot error</Error> " .. escapeRich(tostring(err)))
			end
		end
		task.wait(0.35)
	end
end)

task.spawn(function()
	while hub.running do
		local ok, err = pcall(hideStep)
		if not ok then
			warn("[KZ] hide: " .. tostring(err))
		end
		task.wait(0.25)
	end
end)

Window:LoadAutoload()

pushLog("<Accent>Loaded</Accent> " .. BRAND .. " - Malam Sama Opah v" .. VERSION)
pushLog("<Muted>RightControl toggles the window</Muted>")
notify("Loaded", BRAND .. " - Malam Sama Opah v" .. VERSION, "Success")

pcall(scanWorld)
print("[KZ] loaded v" .. VERSION .. " | drawers=" .. #hub.world.drawers .. " wardrobes=" .. #hub.world.wardrobes .. " keys=" .. #hub.world.keys .. " locks=" .. #hub.world.locks)

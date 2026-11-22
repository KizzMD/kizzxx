--[[
    KizzDev | Malam Sama Kaka  v1.0
    UI: sidebar ikon + search + drag + resize (tema ungu)
    Tab: Home, Player, Auto Farm, ESP, Guard, Settings
]]

if getgenv and getgenv().KizzDevMSK then
    pcall(getgenv().KizzDevMSK.Unload)
end

----------------------------------------------------------------
-- SERVICES
----------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local PPS = game:GetService("ProximityPromptService")
local TeleportService = game:GetService("TeleportService")
local LP = Players.LocalPlayer

----------------------------------------------------------------
-- STATE / CONFIG
----------------------------------------------------------------
local S = {
    Running = true,
    SpeedOn = false, SpeedVal = 40,
    InfStamina = false, SetStamina = false, StamVal = 100,
    Noclip = false, InfJump = false, Fly = false, FlySpeed = 60,
    Fullbright = false, ThirdPerson = false, FovOn = false, Fov = 70, NoFog = false,
    AutoFarm = false, LobbyStart = false, SkipIntro = false, AutoWin = false,
    ReturnBack = true, InstantPrompt = false, AutoInteract = false,
    ESPKey = false, ESPKaka = false, ESPFlip = false, ESPExit = false, ESPPlayer = false,
    KakaMode = "Otomatis",
    Guard = false, GuardMode = "Zona Aman", GuardDist = 30,
    WarnText = false, Radar = false,
    AntiAFK = true,
    SafeCF = nil, SavedCF = nil,
    NearKaka = nil, NearDist = math.huge,
}

local KEY_WORDS   = {"kunci", "key"}
local KEY_EXCL    = {"monkey", "keyboard", "keypad", "donkey"}
local FLIP_WORDS  = {"flip", "sandal", "jepit", "flop"}
local EXIT_WORDS  = {"finish", "exit", "keluar", "escape", "selesai", "gerbang"}
local EXIT_EXCL   = {"window"}
local KAKA_WORDS  = {"kaka", "kakak", "kak_", "hantu", "pocong", "kunti", "genderuwo", "tuyul"}
local STAM_WORDS  = {"stamina", "stam", "energi", "energy", "sprint"}

local Conns = {}
local function track(c) Conns[#Conns + 1] = c return c end

----------------------------------------------------------------
-- HELPERS
----------------------------------------------------------------
local function lower(s) return string.lower(tostring(s or "")) end
local function matchAny(name, list)
    name = lower(name)
    for _, k in ipairs(list) do
        if name:find(k, 1, true) then return true end
    end
    return false
end
local function hrp() local c = LP.Character return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c = LP.Character return c and c:FindFirstChildOfClass("Humanoid") end

local function posOf(i)
    if not i or not i.Parent then return nil end
    if i:IsA("BasePart") then return i.Position end
    if i:IsA("Model") then
        local ok, cf = pcall(i.GetPivot, i)
        if ok then return cf.Position end
    end
    local p = i:FindFirstChildWhichIsA("BasePart", true)
    return p and p.Position
end

local function adorneePart(i)
    if i:IsA("BasePart") then return i end
    if i:IsA("Model") then return i.PrimaryPart or i:FindFirstChildWhichIsA("BasePart", true) end
    return i:FindFirstChildWhichIsA("BasePart", true)
end

task.spawn(function()
    local r = hrp()
    while not r and S.Running do task.wait(0.5) r = hrp() end
    if r and not S.SafeCF then S.SafeCF = r.CFrame end
end)

----------------------------------------------------------------
-- UI LIBRARY
----------------------------------------------------------------
local ACCENT = Color3.fromRGB(124, 77, 255)
local BG     = Color3.fromRGB(13, 13, 16)
local PANEL  = Color3.fromRGB(21, 21, 26)
local ELEM   = Color3.fromRGB(30, 30, 37)
local OFF    = Color3.fromRGB(45, 45, 54)
local TEXT   = Color3.fromRGB(228, 228, 238)
local SUB    = Color3.fromRGB(150, 150, 168)
local FONT   = Enum.Font.Code

local function new(class, props, kids)
    local o = Instance.new(class)
    local parent
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v else o[k] = v end
    end
    for _, c in ipairs(kids or {}) do c.Parent = o end
    if parent then o.Parent = parent end
    return o
end
local function corner(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r), Parent = o}) end
local function stroke(o, c, t, tr)
    return new("UIStroke", {Color = c or ACCENT, Thickness = t or 1, Transparency = tr or 0.6,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o})
end

local function guiParent()
    local ok, p = pcall(function() return (gethui and gethui()) or game:GetService("CoreGui") end)
    if ok and p then return p end
    return LP:WaitForChild("PlayerGui")
end

local Parent = guiParent()
local Gui = new("ScreenGui", {Name = "KizzDevMSK", ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999, Parent = Parent})
local Holder = new("Folder", {Name = "KizzDevMSK_ESP", Parent = Parent})

local function makeDrag(handle, target, onEnd)
    local dragging, startIn, startPos, moved = false, nil, nil, 0
    track(handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; startIn = i.Position; startPos = target.Position; moved = 0
            local c; c = i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if onEnd then onEnd(moved) end
                    c:Disconnect()
                end
            end)
        end
    end))
    track(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - startIn
            moved = math.max(moved, d.Magnitude)
            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
end

-- Window
local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.new(800, 400)
local W, H = math.min(450, vp.X - 20), math.min(270, vp.Y - 20)
local Main = new("Frame", {Name = "Main", Size = UDim2.fromOffset(W, H),
    Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2), BackgroundColor3 = BG, BorderSizePixel = 0,
    Active = true, ClipsDescendants = true, Parent = Gui})
corner(Main, 8)
local mainStroke = stroke(Main, ACCENT, 1.5, 0.15)
local grad = new("UIGradient", {Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 90, 255)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(70, 40, 160)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 120, 255))}), Parent = mainStroke})
track(RunService.RenderStepped:Connect(function(dt) grad.Rotation = (grad.Rotation + dt * 60) % 360 end))

-- Sidebar
local Side = new("Frame", {Size = UDim2.new(0, 44, 1, -22), BackgroundColor3 = Color3.fromRGB(17, 17, 21),
    BorderSizePixel = 0, Parent = Main})
local Logo = new("TextLabel", {Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(5, 5),
    BackgroundColor3 = ACCENT, Text = "KD", Font = Enum.Font.GothamBlack, TextSize = 15,
    TextColor3 = Color3.new(1, 1, 1), Parent = Side})
corner(Logo, 8)
new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(170, 100, 255), Color3.fromRGB(80, 50, 200)),
    Rotation = 45, Parent = Logo})
local TabList = new("ScrollingFrame", {Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44),
    BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = Side})
new("UIListLayout", {Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = TabList})

-- Top bar (search + drag handle)
local SearchBox = new("Frame", {Position = UDim2.fromOffset(50, 6), Size = UDim2.new(1, -92, 0, 28),
    BackgroundColor3 = PANEL, Parent = Main})
corner(SearchBox, 6); stroke(SearchBox, ACCENT, 1, 0.8)
new("TextLabel", {Size = UDim2.fromOffset(26, 28), BackgroundTransparency = 1, Text = "🔍", TextSize = 12,
    TextColor3 = SUB, Font = FONT, Parent = SearchBox})
local Search = new("TextBox", {Position = UDim2.fromOffset(26, 0), Size = UDim2.new(1, -30, 1, 0),
    BackgroundTransparency = 1, Text = "", PlaceholderText = "Search - KizzDev Library",
    PlaceholderColor3 = SUB, TextColor3 = TEXT, Font = FONT, TextSize = 12, ClearTextOnFocus = false, Parent = SearchBox})
local DragH = new("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 6),
    Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Text = "✥", TextSize = 20,
    TextColor3 = SUB, Font = FONT, Parent = Main})
makeDrag(DragH, Main)
makeDrag(Logo, Main)

-- Content + footer
local Content = new("Frame", {Position = UDim2.fromOffset(50, 40), Size = UDim2.new(1, -56, 1, -66),
    BackgroundTransparency = 1, ClipsDescendants = true, Parent = Main})
local Footer = new("TextLabel", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0),
    Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = Color3.fromRGB(17, 17, 21), BorderSizePixel = 0,
    Text = "KizzDev | Malam Sama Kaka | v1.0", TextColor3 = SUB, Font = FONT, TextSize = 10, Parent = Main})
local Resize = new("TextButton", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -3, 1, -1),
    Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, Text = "⤡", TextSize = 14,
    TextColor3 = SUB, Font = FONT, ZIndex = 5, Parent = Main})
do
    local rs, sSize
    track(Resize.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            rs = i.Position; sSize = Main.AbsoluteSize
            local c; c = i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then rs = nil c:Disconnect() end
            end)
        end
    end))
    track(UIS.InputChanged:Connect(function(i)
        if rs and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            local d = i.Position - rs
            Main.Size = UDim2.fromOffset(math.clamp(sSize.X + d.X, 360, 700), math.clamp(sSize.Y + d.Y, 220, 480))
        end
    end))
end

-- Toast
local Toasts = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12),
    Size = UDim2.fromOffset(260, 10), BackgroundTransparency = 1, Parent = Gui})
new("UIListLayout", {Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = Toasts})
local function notify(msg, dur)
    local t = new("TextLabel", {Size = UDim2.fromOffset(250, 26), BackgroundColor3 = PANEL, Text = msg,
        TextColor3 = TEXT, Font = FONT, TextSize = 12, Parent = Toasts})
    corner(t, 6); stroke(t, ACCENT, 1, 0.3)
    task.delay(dur or 3, function() if t.Parent then t:Destroy() end end)
end

-- Pages / tabs / search registry
local Pages, TabBtns, Registry = {}, {}, {}
local CurrentTab
local function scrollLock(locked)
    for _, p in pairs(Pages) do p.ScrollingEnabled = not locked end
end
local function reg(frame, name) Registry[#Registry + 1] = {f = frame, n = lower(name)} end
local function applySearch()
    local q = lower(Search.Text)
    for _, r in ipairs(Registry) do
        r.f.Visible = (q == "" or r.n:find(q, 1, true) ~= nil)
    end
end
track(Search:GetPropertyChangedSignal("Text"):Connect(applySearch))

local function selectTab(name)
    CurrentTab = name
    for n, p in pairs(Pages) do p.Visible = (n == name) end
    for n, b in pairs(TabBtns) do
        b.BackgroundColor3 = (n == name) and Color3.fromRGB(40, 30, 75) or Color3.fromRGB(17, 17, 21)
        b.TextColor3 = (n == name) and Color3.fromRGB(190, 150, 255) or ACCENT
    end
end

local Tab = {}
Tab.__index = Tab
local Sec = {}
Sec.__index = Sec

local function newTab(name, icon)
    local btn = new("TextButton", {Size = UDim2.fromOffset(36, 34), BackgroundColor3 = Color3.fromRGB(17, 17, 21),
        Text = icon, TextSize = 18, TextColor3 = ACCENT, Font = Enum.Font.GothamBold, AutoButtonColor = false,
        Parent = TabList})
    corner(btn, 8)
    TabBtns[name] = btn
    local page = new("ScrollingFrame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = ACCENT, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false, Parent = Content})
    local left = new("Frame", {Size = UDim2.new(0.5, -3, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Parent = page})
    new("UIListLayout", {Padding = UDim.new(0, 6), Parent = left})
    local right = new("Frame", {Position = UDim2.new(0.5, 3, 0, 0), Size = UDim2.new(0.5, -3, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = page})
    new("UIListLayout", {Padding = UDim.new(0, 6), Parent = right})
    Pages[name] = page
    track(btn.Activated:Connect(function() selectTab(name) end))
    return setmetatable({Left = left, Right = right}, Tab)
end

function Tab:Section(title, icon, col)
    local holder = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = PANEL, BorderSizePixel = 0, Parent = (col == 2) and self.Right or self.Left})
    corner(holder, 6); stroke(holder, ACCENT, 1, 0.8)
    local header = new("TextButton", {Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Text = "", Parent = holder})
    new("TextLabel", {Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(18, 28), BackgroundTransparency = 1,
        Text = icon, TextSize = 14, TextColor3 = ACCENT, Font = Enum.Font.GothamBold, Parent = header})
    new("TextLabel", {Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -52, 1, 0), BackgroundTransparency = 1,
        Text = title, TextColor3 = TEXT, Font = FONT, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = header})
    local arrow = new("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0),
        Size = UDim2.fromOffset(16, 28), BackgroundTransparency = 1, Text = "v", TextColor3 = SUB, Font = FONT,
        TextSize = 11, Parent = header})
    local body = new("Frame", {Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = holder})
    new("UIListLayout", {Padding = UDim.new(0, 3), Parent = body})
    new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6), Parent = body})
    local open = true
    track(header.Activated:Connect(function()
        open = not open
        body.Visible = open
        arrow.Text = open and "v" or "^"
    end))
    return setmetatable({Body = body}, Sec)
end

function Sec:Toggle(name, def, cb)
    local f = new("TextButton", {Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, Parent = self.Body})
    new("TextLabel", {Size = UDim2.new(1, -40, 1, 0), BackgroundTransparency = 1, Text = name, TextColor3 = TEXT,
        Font = FONT, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = f})
    local sw = new("Frame", {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        Size = UDim2.fromOffset(32, 16), BackgroundColor3 = OFF, Parent = f})
    corner(sw, 8)
    local knob = new("Frame", {Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(2, 2),
        BackgroundColor3 = Color3.new(1, 1, 1), Parent = sw})
    corner(knob, 6)
    local state = def and true or false
    local obj = {}
    local function render()
        TweenService:Create(sw, TweenInfo.new(0.12), {BackgroundColor3 = state and ACCENT or OFF}):Play()
        TweenService:Create(knob, TweenInfo.new(0.12), {Position = state and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2)}):Play()
    end
    function obj:Set(v, silent)
        state = v and true or false
        render()
        if not silent then task.spawn(cb, state) end
    end
    function obj:Get() return state end
    track(f.Activated:Connect(function() obj:Set(not state) end))
    render()
    if state then task.spawn(cb, state) end
    reg(f, name)
    return obj
end

function Sec:Slider(name, min, max, def, cb)
    local f = new("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = self.Body})
    new("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = name, TextColor3 = TEXT,
        Font = FONT, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
    local bar = new("Frame", {Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 14),
        BackgroundColor3 = ELEM, Parent = f})
    corner(bar, 4)
    local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = ACCENT, Parent = bar})
    corner(fill, 4)
    local txt = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
        TextColor3 = Color3.new(1, 1, 1), Font = FONT, TextSize = 10, ZIndex = 2, Parent = bar})
    local obj = {}
    local val = def
    local function set(v, fire)
        v = math.clamp(math.floor(v + 0.5), min, max)
        val = v
        fill.Size = UDim2.new((v - min) / (max - min), 0, 1, 0)
        txt.Text = v .. "/" .. max
        if fire then task.spawn(cb, v) end
    end
    local dragging = false
    local function upd(x)
        local rel = (x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
        set(min + (max - min) * math.clamp(rel, 0, 1), true)
    end
    track(bar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true; scrollLock(true); upd(i.Position.X)
            local c; c = i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then dragging = false scrollLock(false) c:Disconnect() end
            end)
        end
    end))
    track(UIS.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
            upd(i.Position.X)
        end
    end))
    function obj:Get() return val end
    function obj:Set(v) set(v, true) end
    set(def, true)
    reg(f, name)
    return obj
end

function Sec:Button(name, cb)
    local b = new("TextButton", {Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = ELEM, Text = name,
        TextColor3 = TEXT, Font = FONT, TextSize = 11, AutoButtonColor = true, Parent = self.Body})
    corner(b, 5); stroke(b, ACCENT, 1, 0.85)
    track(b.Activated:Connect(function() task.spawn(cb) end))
    reg(b, name)
    return b
end

function Sec:Label(text)
    local l = new("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = text,
        TextColor3 = SUB, Font = FONT, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Body})
    return {Set = function(_, t) l.Text = t end}
end

function Sec:Input(name, def, cb)
    local f = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = self.Body})
    new("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = name, TextColor3 = TEXT,
        Font = FONT, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
    local tb = new("TextBox", {Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = ELEM,
        Text = def, TextColor3 = TEXT, Font = FONT, TextSize = 11, ClearTextOnFocus = false, Parent = f})
    corner(tb, 5)
    track(tb.FocusLost:Connect(function() cb(tb.Text) end))
    reg(f, name)
    return tb
end

function Sec:Dropdown(name, opts, def, cb)
    local f = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, Parent = self.Body})
    new("UIListLayout", {Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder, Parent = f})
    new("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = name, TextColor3 = TEXT,
        Font = FONT, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = f})
    local btn = new("TextButton", {Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = ELEM, Text = "  " .. tostring(def),
        TextColor3 = TEXT, Font = FONT, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = true, LayoutOrder = 2, Parent = f})
    corner(btn, 5)
    local arrow = new("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0),
        Size = UDim2.fromOffset(14, 22), BackgroundTransparency = 1, Text = "v", TextColor3 = SUB, Font = FONT,
        TextSize = 11, Parent = btn})
    local list = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = ELEM, Visible = false, LayoutOrder = 3, Parent = f})
    corner(list, 5)
    new("UIListLayout", {Parent = list})
    local obj = {Value = def}
    local function fill()
        for _, c in ipairs(list:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
        local o = type(opts) == "function" and opts() or opts
        if #o == 0 then o = {"(kosong)"} end
        for _, v in ipairs(o) do
            local ob = new("TextButton", {Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Text = "  " .. v,
                TextColor3 = TEXT, Font = FONT, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = list})
            ob.Activated:Connect(function()
                obj.Value = v
                btn.Text = "  " .. v
                list.Visible = false
                arrow.Text = "v"
                task.spawn(cb, v)
            end)
        end
    end
    track(btn.Activated:Connect(function()
        if not list.Visible then fill() end
        list.Visible = not list.Visible
        arrow.Text = list.Visible and "^" or "v"
    end))
    reg(f, name)
    return obj
end

----------------------------------------------------------------
-- SCANNER (Kunci / Flip Flop / Pintu keluar / Kaka / Prompts)
----------------------------------------------------------------
local catCache = {}
local function classify(name)
    local c = catCache[name]
    if c then return c end
    c = {
        key  = matchAny(name, KEY_WORDS) and not matchAny(name, KEY_EXCL),
        flip = matchAny(name, FLIP_WORDS),
        exit = matchAny(name, EXIT_WORDS) and not matchAny(name, EXIT_EXCL),
        kaka = matchAny(name, KAKA_WORDS),
    }
    catCache[name] = c
    return c
end
local function resetCats() catCache = {} end

local scanCache, scanTime = nil, 0
local function getScan(maxAge)
    if scanCache and (tick() - scanTime) < (maxAge or 3) then return scanCache end
    local res = {keys = {}, flips = {}, exits = {}, kaka = {}, npcs = {}, prompts = {}}
    local chars = {}
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then chars[p.Character] = true end end
    local function inChar(d)
        local m = d
        while m and m ~= Workspace do
            if chars[m] then return true end
            m = m.Parent
        end
        return false
    end
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            res.prompts[#res.prompts + 1] = d
        elseif d:IsA("Humanoid") then
            local m = d.Parent
            if m and m:IsA("Model") and not inChar(m) then res.npcs[#res.npcs + 1] = m end
        elseif d:IsA("BasePart") or d:IsA("Model") or d:IsA("Tool") then
            local c = classify(d.Name)
            if c.key or c.flip or c.exit or c.kaka then
                local p = d.Parent
                local pc = (p and p ~= Workspace) and classify(p.Name) or nil
                if not inChar(d) then
                    if c.key and not (pc and pc.key) then res.keys[#res.keys + 1] = d end
                    if c.flip and not (pc and pc.flip) then res.flips[#res.flips + 1] = d end
                    if c.exit and not (pc and pc.exit) then res.exits[#res.exits + 1] = d end
                    if c.kaka and d:IsA("Model") and not (pc and pc.kaka) then res.kaka[#res.kaka + 1] = d end
                end
            end
        end
    end
    scanCache, scanTime = res, tick()
    return res
end

local function getKakaList()
    local sc = getScan(3)
    if S.KakaMode == "Nama Kaka saja" then return sc.kaka end
    if S.KakaMode == "Semua NPC" then return sc.npcs end
    if #sc.kaka > 0 then return sc.kaka end
    return sc.npcs
end

local function nearestKaka()
    local r = hrp()
    if not r then return nil, math.huge end
    local best, bd = nil, math.huge
    for _, m in ipairs(getKakaList()) do
        local p = posOf(m)
        if p then
            local d = (p - r.Position).Magnitude
            if d < bd then best, bd = m, d end
        end
    end
    return best, bd
end

----------------------------------------------------------------
-- INTERACT HELPERS
----------------------------------------------------------------
local function promptsOf(d)
    local out = {}
    if d:IsA("ProximityPrompt") then out[1] = d end
    for _, x in ipairs(d:GetDescendants()) do
        if x:IsA("ProximityPrompt") then out[#out + 1] = x end
    end
    return out
end

local function pressPrompt(p, tp)
    if not fireproximityprompt or not p or not p.Parent or not p.Enabled then return end
    local r = hrp()
    local par = p.Parent
    local pos = par and ((par:IsA("BasePart") and par.Position)
        or (par:IsA("Attachment") and par.WorldPosition) or (par:IsA("Model") and posOf(par)))
    local old
    if tp and r and pos and (r.Position - pos).Magnitude > math.max(p.MaxActivationDistance * 0.8, 4) then
        old = r.CFrame
        r.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
        task.wait(0.2)
    end
    pcall(function() p.HoldDuration = 0 end)
    pcall(fireproximityprompt, p)
    if old and r then task.wait(0.15) r.CFrame = old end
end

local function collectItem(d)
    local r = hrp()
    if not r or not d or not d.Parent then return false end
    local pos = posOf(d)
    if not pos then return false end
    local old = r.CFrame
    r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    task.wait(0.2)
    local part = (d:IsA("BasePart") and d) or d:FindFirstChildWhichIsA("BasePart", true)
    if part and firetouchinterest then
        pcall(function() firetouchinterest(r, part, 0) firetouchinterest(r, part, 1) end)
    end
    for _, p in ipairs(promptsOf(d)) do
        if p.Enabled then
            pcall(function() p.HoldDuration = 0 end)
            if fireproximityprompt then pcall(fireproximityprompt, p) end
        end
    end
    local cd = d:FindFirstChildWhichIsA("ClickDetector", true)
    if cd and fireclickdetector then pcall(fireclickdetector, cd) end
    task.wait(0.25)
    if S.ReturnBack and r.Parent then r.CFrame = old end
    return true
end

local collected = {}
local function collectAll(list, label, force)
    local n = 0
    for _, it in ipairs(list) do
        if not S.Running then break end
        if it.Parent and (force or not collected[it] or tick() - collected[it] > 20) then
            collected[it] = tick()
            if collectItem(it) then n = n + 1 end
        end
    end
    return n
end

local function goExit()
    local sc = getScan(2)
    local r = hrp()
    if not r then return 0 end
    local n = 0
    for _, it in ipairs(sc.exits) do
        local pos = posOf(it)
        if pos then
            r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
            task.wait(0.2)
            local part = (it:IsA("BasePart") and it) or it:FindFirstChildWhichIsA("BasePart", true)
            if part and firetouchinterest then
                pcall(function() firetouchinterest(r, part, 0) firetouchinterest(r, part, 1) end)
            end
            for _, p in ipairs(promptsOf(it)) do pcall(function() p.HoldDuration = 0 end) pressPrompt(p, false) end
            n = n + 1
            task.wait(0.3)
        end
    end
    return n
end

-- GUI button helpers (skip intro / start)
local function guiVisible(b)
    local x = b
    while x and x ~= game do
        if x:IsA("GuiObject") and not x.Visible then return false end
        if x:IsA("ScreenGui") and not x.Enabled then return false end
        x = x.Parent
    end
    return true
end
local function btnText(b)
    local t = lower(b.Name)
    if b:IsA("TextButton") then t = t .. " " .. lower(b.Text) end
    for _, c in ipairs(b:GetChildren()) do
        if c:IsA("TextLabel") then t = t .. " " .. lower(c.Text) end
    end
    return t
end
local function pressButton(b)
    for _, sig in ipairs({"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up"}) do
        if getconnections then
            pcall(function() for _, c in ipairs(getconnections(b[sig])) do c:Fire() end end)
        end
        if firesignal then pcall(firesignal, b[sig]) end
    end
end
local function pressGuiWords(words)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return 0 end
    local n = 0
    for _, b in ipairs(pg:GetDescendants()) do
        if (b:IsA("TextButton") or b:IsA("ImageButton")) and not b:IsDescendantOf(Gui) and guiVisible(b) then
            if matchAny(btnText(b), words) then pressButton(b) n = n + 1 end
        end
    end
    return n
end

local START_WORDS = {"start", "mulai", "night", "malam"}
local function pressStart()
    local n = pressGuiWords({"start", "mulai"})
    local sc = getScan(3)
    for _, p in ipairs(sc.prompts) do
        if p.Enabled then
            local t = lower(p.ObjectText .. " " .. p.ActionText .. " " .. (p.Parent and p.Parent.Name or "")
                .. " " .. ((p.Parent and p.Parent.Parent) and p.Parent.Parent.Name or ""))
            if matchAny(t, START_WORDS) then pressPrompt(p, true) n = n + 1 end
        end
    end
    return n
end

----------------------------------------------------------------
-- ESP
----------------------------------------------------------------
local ESP = {}
local COLORS = {
    Kunci = Color3.fromRGB(255, 215, 0), Kaka = Color3.fromRGB(255, 60, 60),
    ["Flip Flop"] = Color3.fromRGB(0, 220, 255), Keluar = Color3.fromRGB(80, 255, 120),
    Pemain = Color3.fromRGB(190, 150, 255),
}
local function removeESP(inst)
    local e = ESP[inst]
    if e then
        if e.hl then e.hl:Destroy() end
        if e.bb then e.bb:Destroy() end
        ESP[inst] = nil
    end
end
local function addESP(inst, kind)
    local part = adorneePart(inst)
    if not part then return end
    local col = COLORS[kind] or ACCENT
    local hl = new("Highlight", {Adornee = inst:IsA("Tool") and part or inst, FillColor = col, OutlineColor = col,
        FillTransparency = 0.65, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop, Parent = Holder})
    local bb = new("BillboardGui", {Adornee = part, AlwaysOnTop = true, Size = UDim2.fromOffset(140, 22),
        StudsOffset = Vector3.new(0, 2.5, 0), Parent = Holder})
    local lbl = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = kind,
        TextColor3 = col, TextStrokeTransparency = 0.3, Font = FONT, TextSize = 13, Parent = bb})
    ESP[inst] = {hl = hl, bb = bb, lbl = lbl, kind = kind}
end

local function espTick()
    local desired = {}
    local any = S.ESPKey or S.ESPKaka or S.ESPFlip or S.ESPExit or S.ESPPlayer
    if any then
        local sc = (S.ESPKey or S.ESPFlip or S.ESPExit or S.ESPKaka) and getScan(3) or nil
        if S.ESPKey then for _, i in ipairs(sc.keys) do desired[i] = "Kunci" end end
        if S.ESPFlip then for _, i in ipairs(sc.flips) do desired[i] = "Flip Flop" end end
        if S.ESPExit then for _, i in ipairs(sc.exits) do desired[i] = "Keluar" end end
        if S.ESPKaka then for _, i in ipairs(getKakaList()) do desired[i] = "Kaka" end end
        if S.ESPPlayer then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then desired[p.Character] = "Pemain" end
            end
        end
    end
    for inst, e in pairs(ESP) do
        if not inst.Parent or desired[inst] ~= e.kind then removeESP(inst) end
    end
    local r = hrp()
    for inst, kind in pairs(desired) do
        if not ESP[inst] then addESP(inst, kind) end
        local e = ESP[inst]
        if e and r then
            local p = posOf(inst)
            local nm = kind
            if kind == "Pemain" then nm = inst.Name end
            e.lbl.Text = p and (nm .. " [" .. math.floor((p - r.Position).Magnitude) .. "m]") or nm
        end
    end
end

----------------------------------------------------------------
-- RADAR (arah Kaka)
----------------------------------------------------------------
local Radar = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(220, 220), BackgroundTransparency = 1, Visible = false, Parent = Gui})
new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(34, 34),
    BackgroundTransparency = 1, Text = "▲", TextColor3 = Color3.fromRGB(255, 70, 70), TextSize = 30,
    Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.4, Parent = Radar})
local RadarTxt = new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 60),
    Size = UDim2.fromOffset(160, 20), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(255, 120, 120),
    Font = FONT, TextSize = 13, TextStrokeTransparency = 0.4, Visible = false, Parent = Gui})
RadarTxt.Position = UDim2.new(0.5, 0, 0.5, -130)

track(RunService.RenderStepped:Connect(function()
    local m = S.NearKaka
    if S.Radar and m and m.Parent and S.NearDist < 300 then
        local cam = Workspace.CurrentCamera
        local kp = posOf(m)
        if cam and kp then
            local rel = cam.CFrame:PointToObjectSpace(kp)
            Radar.Rotation = math.deg(math.atan2(rel.X, -rel.Z))
            Radar.Visible = true
            RadarTxt.Visible = true
            local r = hrp()
            RadarTxt.Text = "Kaka " .. math.floor(r and (kp - r.Position).Magnitude or 0) .. "m"
            return
        end
    end
    Radar.Visible = false
    RadarTxt.Visible = false
end))

----------------------------------------------------------------
-- PLAYER FEATURES
----------------------------------------------------------------
local LightOrig
local function saveLight()
    LightOrig = LightOrig or {Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
        FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart, GlobalShadows = Lighting.GlobalShadows,
        Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient}
end
local function restoreLight(which)
    if not LightOrig then return end
    if which == "fb" then
        Lighting.Brightness = LightOrig.Brightness; Lighting.ClockTime = LightOrig.ClockTime
        Lighting.GlobalShadows = LightOrig.GlobalShadows; Lighting.Ambient = LightOrig.Ambient
        Lighting.OutdoorAmbient = LightOrig.OutdoorAmbient
    else
        Lighting.FogEnd = LightOrig.FogEnd; Lighting.FogStart = LightOrig.FogStart
    end
end

local camOrig
local function setThird(on)
    if on then
        camOrig = camOrig or {min = LP.CameraMinZoomDistance, max = LP.CameraMaxZoomDistance, mode = LP.CameraMode}
        LP.CameraMode = Enum.CameraMode.Classic
        LP.CameraMaxZoomDistance = 100
        LP.CameraMinZoomDistance = 12
    elseif camOrig then
        LP.CameraMinZoomDistance = camOrig.min
        LP.CameraMaxZoomDistance = camOrig.max
        LP.CameraMode = camOrig.mode
    end
end

-- Fly
local flyBV, flyBG
local function stopFly()
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
    local h = hum()
    if h then h.PlatformStand = false end
end

-- Heartbeat: speed + fly
track(RunService.Heartbeat:Connect(function()
    local h = hum()
    if S.SpeedOn and h then h.WalkSpeed = S.SpeedVal end
    if S.Fly then
        local r = hrp()
        local cam = Workspace.CurrentCamera
        if r and h and cam then
            if not flyBV then
                flyBV = new("BodyVelocity", {MaxForce = Vector3.new(1e9, 1e9, 1e9), Velocity = Vector3.zero, Parent = r})
                flyBG = new("BodyGyro", {MaxTorque = Vector3.new(1e9, 1e9, 1e9), P = 9e4, CFrame = cam.CFrame, Parent = r})
            end
            h.PlatformStand = true
            local loc = cam.CFrame:VectorToObjectSpace(h.MoveDirection)
            local v = cam.CFrame.LookVector * (-loc.Z) + cam.CFrame.RightVector * loc.X
            flyBV.Velocity = v * S.FlySpeed
            flyBG.CFrame = cam.CFrame
        end
    end
end))

-- Stepped: noclip
track(RunService.Stepped:Connect(function()
    if S.Noclip then
        local c = LP.Character
        if c then
            for _, p in ipairs(c:GetDescendants()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end
end))

-- RenderStepped: fov / fullbright / fog
track(RunService.RenderStepped:Connect(function()
    local cam = Workspace.CurrentCamera
    if S.FovOn and cam then cam.FieldOfView = S.Fov end
    if S.Fullbright then
        Lighting.Brightness = 2; Lighting.ClockTime = 14; Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(190, 190, 190); Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
    end
    if S.NoFog then Lighting.FogEnd = 1e9; Lighting.FogStart = 1e9 end
end))

track(UIS.JumpRequest:Connect(function()
    if S.InfJump then
        local h = hum()
        if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end))

track(PPS.PromptButtonHoldBegan:Connect(function(p)
    if S.InstantPrompt and fireproximityprompt then pcall(fireproximityprompt, p) end
end))

-- Stamina
local stamTargets, stamTime = {}, 0
local function scanStamina()
    stamTargets = {}
    local roots = {LP, LP.Character}
    for _, root in ipairs(roots) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if (d:IsA("NumberValue") or d:IsA("IntValue")) and matchAny(d.Name, STAM_WORDS) and not lower(d.Name):find("max", 1, true) then
                    local mx = 100
                    for _, s in ipairs(d.Parent:GetChildren()) do
                        if (s:IsA("NumberValue") or s:IsA("IntValue")) and s ~= d and lower(s.Name):find("max", 1, true) and matchAny(s.Name, STAM_WORDS) then
                            mx = s.Value
                        end
                    end
                    stamTargets[#stamTargets + 1] = {obj = d, max = mx}
                end
            end
            for name, val in pairs(root:GetAttributes()) do
                if type(val) == "number" and matchAny(name, STAM_WORDS) and not lower(name):find("max", 1, true) then
                    local mx = root:GetAttribute("Max" .. name) or root:GetAttribute("Max" .. name:sub(1, 1):upper() .. name:sub(2)) or 100
                    stamTargets[#stamTargets + 1] = {attr = name, root = root, max = type(mx) == "number" and mx or 100}
                end
            end
        end
    end
    stamTime = tick()
end
task.spawn(function()
    while S.Running do
        task.wait(0.15)
        if S.InfStamina or S.SetStamina then
            if tick() - stamTime > 3 then pcall(scanStamina) end
            for _, t in ipairs(stamTargets) do
                pcall(function()
                    if t.obj then
                        if t.obj.Parent then
                            t.obj.Value = S.SetStamina and S.StamVal or math.max(t.obj.Value, t.max)
                        end
                    elseif t.root and t.root.Parent then
                        local cur = t.root:GetAttribute(t.attr) or 0
                        t.root:SetAttribute(t.attr, S.SetStamina and S.StamVal or math.max(cur, t.max))
                    end
                end)
            end
        end
    end
end)

-- Anti AFK
pcall(function()
    local VU = game:GetService("VirtualUser")
    track(LP.Idled:Connect(function()
        if S.AntiAFK then
            VU:CaptureController()
            VU:ClickButton2(Vector2.new())
        end
    end))
end)

----------------------------------------------------------------
-- BACKGROUND LOOPS
----------------------------------------------------------------
-- ESP loop
task.spawn(function()
    while S.Running do
        task.wait(0.3)
        pcall(espTick)
    end
end)

-- Guard / notif loop
task.spawn(function()
    local lastAct, lastWarn = 0, 0
    while S.Running do
        task.wait(0.2)
        if S.Guard or S.WarnText or S.Radar then
            local ok, m, d = pcall(nearestKaka)
            if ok then
                S.NearKaka, S.NearDist = m, d
                local r = hrp()
                if m and r and d <= S.GuardDist then
                    if S.WarnText and tick() - lastWarn > 4 then
                        lastWarn = tick()
                        notify("⚠ Kaka dekat! " .. math.floor(d) .. " m")
                    end
                    if S.Guard and tick() - lastAct > 2 then
                        lastAct = tick()
                        if S.GuardMode == "Zona Aman" and S.SafeCF then
                            r.CFrame = S.SafeCF
                        elseif S.GuardMode == "Lari Menjauh" then
                            local kp = posOf(m)
                            if kp then
                                local dir = (r.Position - kp) * Vector3.new(1, 0, 1)
                                if dir.Magnitude < 0.1 then dir = Vector3.new(1, 0, 0) end
                                r.CFrame = r.CFrame + dir.Unit * (S.GuardDist + 30)
                            end
                        end
                    end
                end
            end
        else
            S.NearKaka, S.NearDist = nil, math.huge
        end
    end
end)

-- Auto farm loop
task.spawn(function()
    while S.Running do
        task.wait(0.6)
        if S.AutoFarm then
            local ok = pcall(function()
                local sc = getScan(2)
                collectAll(sc.keys)
                if S.AutoFarm then collectAll(sc.flips) end
                if S.AutoFarm and S.AutoWin then goExit() end
            end)
        elseif S.AutoWin then
            pcall(goExit)
            task.wait(3)
        end
    end
end)

-- Lobby start loop
task.spawn(function()
    while S.Running do
        task.wait(4)
        if S.LobbyStart then pcall(pressStart) end
    end
end)

-- Skip intro loop
task.spawn(function()
    while S.Running do
        task.wait(1)
        if S.SkipIntro then pcall(pressGuiWords, {"skip", "lewati"}) end
    end
end)

-- Auto interact loop
task.spawn(function()
    while S.Running do
        task.wait(0.4)
        if S.AutoInteract and fireproximityprompt then
            local r = hrp()
            if r then
                for _, p in ipairs(getScan(4).prompts) do
                    if p.Parent and p.Enabled then
                        local par = p.Parent
                        local pos = (par:IsA("BasePart") and par.Position) or (par:IsA("Attachment") and par.WorldPosition) or (par:IsA("Model") and posOf(par))
                        if pos and (pos - r.Position).Magnitude <= math.max(p.MaxActivationDistance, 10) then
                            pcall(function() p.HoldDuration = 0 end)
                            pcall(fireproximityprompt, p)
                        end
                    end
                end
            end
        end
    end
end)

----------------------------------------------------------------
-- DIAGNOSTIC REPORT
----------------------------------------------------------------
local function buildReport()
    local sc = getScan(0)
    local t = {"=== KizzDev MSK Scan ===", "PlaceId: " .. game.PlaceId, "Game: " .. game.Name}
    local function add(title, list)
        t[#t + 1] = ("[%s] %d"):format(title, #list)
        for i = 1, math.min(#list, 12) do
            local ok, n = pcall(function() return list[i]:GetFullName() end)
            t[#t + 1] = "  " .. (ok and n or "?")
        end
    end
    add("Kunci", sc.keys); add("Flip Flop", sc.flips); add("Pintu Keluar", sc.exits)
    add("Kaka (nama)", sc.kaka); add("NPC Humanoid", sc.npcs)
    t[#t + 1] = "[Prompt] " .. #sc.prompts
    for i = 1, math.min(#sc.prompts, 20) do
        local p = sc.prompts[i]
        t[#t + 1] = ("  %s | %s | %s"):format(p:GetFullName(), p.ActionText, p.ObjectText)
    end
    pcall(scanStamina)
    t[#t + 1] = "[Stamina] " .. #stamTargets
    for _, s in ipairs(stamTargets) do
        t[#t + 1] = "  " .. (s.obj and s.obj:GetFullName() or (tostring(s.attr) .. " (attribute)"))
    end
    t[#t + 1] = "[Workspace top-level]"
    local i = 0
    for _, c in ipairs(Workspace:GetChildren()) do
        i = i + 1
        if i > 40 then break end
        t[#t + 1] = "  " .. c.Name .. " (" .. c.ClassName .. ")"
    end
    return table.concat(t, "\n")
end

----------------------------------------------------------------
-- BUILD UI
----------------------------------------------------------------
-- HOME
local tHome = newTab("Home", "⌂")
do
    local s = tHome:Section("KizzDev - Malam Sama Kaka", "★", 1)
    local lFps = s:Label("FPS: -")
    local lPing = s:Label("Ping: -")
    local lPl = s:Label("Pemain: -")
    local s2 = tHome:Section("Info", "ℹ", 2)
    s2:Label("Aktifkan fitur di tab masing-masing. Kalau Kunci/Kaka tidak terdeteksi, atur kata kunci di tab Settings lalu tekan Refresh ESP.")
    local ex = "-"
    pcall(function() ex = identifyexecutor() end)
    s2:Label("Executor: " .. tostring(ex))
    local frames, acc = 0, 0
    track(RunService.RenderStepped:Connect(function(dt) frames = frames + 1 acc = acc + dt end))
    task.spawn(function()
        while S.Running do
            task.wait(0.5)
            local fps = acc > 0 and math.floor(frames / acc) or 0
            frames, acc = 0, 0
            lFps:Set("FPS: " .. fps)
            local ping = "-"
            pcall(function() ping = math.floor(LP:GetNetworkPing() * 1000) .. " ms" end)
            lPing:Set("Ping: " .. ping)
            lPl:Set("Pemain: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers)
        end
    end)
end

-- PLAYER
local tPlayer = newTab("Player", "👤")
do
    local p = tPlayer:Section("Player", "👤", 1)
    p:Toggle("Speed Modifier", false, function(v)
        S.SpeedOn = v
        if not v then local h = hum() if h then h.WalkSpeed = 16 end end
    end)
    p:Slider("Kecepatan jalan", 16, 100, 40, function(v) S.SpeedVal = v end)
    p:Toggle("Infinite Stamina", false, function(v) S.InfStamina = v end)
    p:Toggle("Atur Stamina (manual)", false, function(v) S.SetStamina = v end)
    p:Slider("Nilai Stamina", 0, 500, 100, function(v) S.StamVal = v end)
    p:Toggle("Noclip", false, function(v) S.Noclip = v end)
    p:Toggle("Infinite Jump", false, function(v) S.InfJump = v end)
    p:Toggle("Fly", false, function(v) S.Fly = v if not v then stopFly() end end)
    p:Slider("Kecepatan terbang", 20, 150, 60, function(v) S.FlySpeed = v end)

    local v = tPlayer:Section("Visual", "☀", 2)
    v:Toggle("Fullbright", false, function(on)
        if on then saveLight() else restoreLight("fb") end
        S.Fullbright = on
    end)
    v:Toggle("Third Person", false, function(on) S.ThirdPerson = on setThird(on) end)
    v:Toggle("FOV Changer", false, function(on)
        S.FovOn = on
        if not on and Workspace.CurrentCamera then Workspace.CurrentCamera.FieldOfView = 70 end
    end)
    v:Slider("FOV", 40, 120, 70, function(x) S.Fov = x end)
    v:Toggle("No Fog", false, function(on)
        if on then saveLight() else restoreLight("fog") end
        S.NoFog = on
    end)

    local t = tPlayer:Section("Teleport", "➤", 2)
    local sel = t:Dropdown("Pilih pemain", function()
        local o = {}
        for _, pl in ipairs(Players:GetPlayers()) do if pl ~= LP then o[#o + 1] = pl.Name end end
        return o
    end, "(pilih)", function() end)
    t:Button("Teleport ke pemain", function()
        local pl = Players:FindFirstChild(sel.Value)
        local r, tr = hrp(), pl and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
        if r and tr then r.CFrame = tr.CFrame * CFrame.new(0, 0, 3) else notify("Pemain tidak ditemukan") end
    end)
    t:Button("Simpan posisi", function()
        local r = hrp()
        if r then S.SavedCF = r.CFrame notify("Posisi disimpan") end
    end)
    t:Button("Ke posisi tersimpan", function()
        local r = hrp()
        if r and S.SavedCF then r.CFrame = S.SavedCF else notify("Belum ada posisi") end
    end)
end

-- AUTO FARM
local tFarm = newTab("Auto Farm", "▶")
do
    local a = tFarm:Section("Auto Farm", "▶", 1)
    a:Toggle("Aktifkan Auto Farm", false, function(v) S.AutoFarm = v end)
    a:Toggle("Lobby Auto Start (Night)", false, function(v) S.LobbyStart = v end)
    a:Toggle("Auto Skip Intro", false, function(v) S.SkipIntro = v end)
    a:Toggle("Auto Win (pintu keluar)", false, function(v) S.AutoWin = v end)
    a:Toggle("Kembali ke posisi awal", true, function(v) S.ReturnBack = v end)
    a:Toggle("Instant Prompt (tanpa tahan)", false, function(v) S.InstantPrompt = v end)
    a:Toggle("Auto Interact (dekat)", false, function(v) S.AutoInteract = v end)

    local m = tFarm:Section("Ambil Manual", "✋", 2)
    m:Button("Get Key All", function()
        local sc = getScan(0)
        local n = collectAll(sc.keys, "Kunci", true)
        notify("Kunci diambil: " .. n .. "/" .. #sc.keys)
    end)
    m:Button("Get Flip Flop", function()
        local sc = getScan(0)
        local n = collectAll(sc.flips, "Flip Flop", true)
        notify("Flip flop diambil: " .. n .. "/" .. #sc.flips)
    end)
    m:Button("Auto Win Sekarang", function()
        local n = goExit()
        notify(n > 0 and ("Ke pintu keluar x" .. n) or "Pintu keluar tidak ditemukan")
    end)
    m:Button("Tekan Start Sekarang", function()
        notify("Tombol/prompt ditekan: " .. pressStart())
    end)
end

-- ESP
local tEsp = newTab("ESP", "👁")
do
    local e = tEsp:Section("ESP Options", "👁", 1)
    e:Toggle("ESP Kunci", false, function(v) S.ESPKey = v end)
    e:Toggle("ESP Kaka", false, function(v) S.ESPKaka = v end)
    e:Toggle("ESP Flip Flop", false, function(v) S.ESPFlip = v end)
    e:Toggle("ESP Pintu Keluar", false, function(v) S.ESPExit = v end)
    e:Toggle("ESP Pemain", false, function(v) S.ESPPlayer = v end)
    e:Button("Refresh ESP", function()
        getScan(0)
        for i in pairs(ESP) do removeESP(i) end
        notify("ESP direfresh")
    end)
    local k = tEsp:Section("Deteksi Kaka", "☠", 2)
    k:Dropdown("Mode deteksi", {"Otomatis", "Nama Kaka saja", "Semua NPC"}, "Otomatis", function(v)
        S.KakaMode = v
        scanCache = nil
    end)
    k:Label("Otomatis: pakai nama Kaka, kalau tidak ketemu pakai semua NPC bernyawa.")
end

-- GUARD
local tGuard = newTab("Guard", "🛡")
do
    local g = tGuard:Section("Guard System", "🛡", 1)
    g:Toggle("Guard Kaka", false, function(v) S.Guard = v end)
    g:Dropdown("Mode Berlindung", {"Zona Aman", "Lari Menjauh", "Notifikasi saja"}, "Zona Aman", function(v) S.GuardMode = v end)
    g:Slider("Jarak Deteksi (m)", 10, 100, 30, function(v) S.GuardDist = v end)
    g:Button("Set Zona Aman (posisi ini)", function()
        local r = hrp()
        if r then S.SafeCF = r.CFrame notify("Zona aman disimpan") end
    end)
    local n = tGuard:Section("Notifications", "🔔", 2)
    n:Toggle("Peringatan Teks", false, function(v) S.WarnText = v end)
    n:Toggle("Radar Arah", false, function(v) S.Radar = v end)
end

-- SETTINGS
local tSet = newTab("Settings", "⚙")
do
    local u = tSet:Section("Umum", "⚙", 1)
    u:Toggle("Anti AFK", true, function(v) S.AntiAFK = v end)
    u:Button("Rejoin", function() TeleportService:Teleport(game.PlaceId, LP) end)
    u:Button("Server Hop", function() TeleportService:Teleport(game.PlaceId, LP) end)
    u:Button("Copy Scan Report", function()
        local rep = buildReport()
        if setclipboard then setclipboard(rep) notify("Report disalin") else print(rep) notify("Report di console") end
    end)
    u:Button("Unload Script", function() if getgenv then getgenv().KizzDevMSK.Unload() end end)

    local k = tSet:Section("Kata Kunci (pisah koma)", "✎", 2)
    local function parse(str, tbl)
        for i = #tbl, 1, -1 do tbl[i] = nil end
        for w in tostring(str):gmatch("[^,]+") do
            w = lower(w):gsub("^%s+", ""):gsub("%s+$", "")
            if #w > 0 then tbl[#tbl + 1] = w end
        end
        resetCats(); scanCache = nil
        notify("Kata kunci diperbarui")
    end
    k:Input("Kunci", table.concat(KEY_WORDS, ","), function(t) parse(t, KEY_WORDS) end)
    k:Input("Flip Flop", table.concat(FLIP_WORDS, ","), function(t) parse(t, FLIP_WORDS) end)
    k:Input("Kaka", table.concat(KAKA_WORDS, ","), function(t) parse(t, KAKA_WORDS) end)
    k:Input("Pintu keluar", table.concat(EXIT_WORDS, ","), function(t) parse(t, EXIT_WORDS) end)
end

selectTab("Home")

----------------------------------------------------------------
-- FLOATING BUTTON + UNLOAD
----------------------------------------------------------------
local Float = new("TextButton", {Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 10, 0.5, -20),
    BackgroundColor3 = ACCENT, Text = "KD", Font = Enum.Font.GothamBlack, TextSize = 16,
    TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Parent = Gui})
corner(Float, 10); stroke(Float, Color3.fromRGB(200, 160, 255), 1.5, 0.2)
makeDrag(Float, Float, function(moved)
    if moved < 6 then Main.Visible = not Main.Visible end
end)

local function unload()
    S.Running = false
    S.Fly = false; stopFly()
    for i in pairs(ESP) do removeESP(i) end
    if LightOrig then restoreLight("fb") restoreLight("fog") end
    if camOrig then setThird(false) end
    local h = hum()
    if h and S.SpeedOn then h.WalkSpeed = 16 end
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    pcall(function() Gui:Destroy() end)
    pcall(function() Holder:Destroy() end)
    if getgenv then getgenv().KizzDevMSK = nil end
end
if getgenv then getgenv().KizzDevMSK = {Unload = unload} end

notify("KizzDev Malam Sama Kaka dimuat ✔", 4)

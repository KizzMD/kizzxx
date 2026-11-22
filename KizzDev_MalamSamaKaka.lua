--[[
    KizzDev | Malam Sama Kaka  v3.0
    - UI ungu compact: sidebar ikon, search, drag, resize
    - Kalibrasi otomatis: berdiri dekat objek -> tekan "Pelajari" di tab Setup
    - Cek executor + scan otomatis saat dimuat
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
-- STATE / KATA KUNCI
----------------------------------------------------------------
local S = {
    Running = true,
    SpeedOn = false, SpeedVal = 40,
    InfStamina = false, SetStamina = false, StamVal = 100,
    Noclip = false, InfJump = false, Fly = false, FlySpeed = 60,
    Fullbright = false, ThirdPerson = false, FovOn = false, Fov = 70, NoFog = false,
    AutoFarm = false, FarmMode = "Otomatis", LobbyStart = false, SkipIntro = false, AutoWin = false,
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
local KAKA_WORDS  = {"kaka", "kakak", "hantu", "pocong", "kunti", "genderuwo", "tuyul"}
local START_WORDS = {"start", "mulai", "night", "malam"}
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
    if i:IsA("Attachment") then return i.WorldPosition end
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

local CAPS = {
    fireproximityprompt = fireproximityprompt ~= nil,
    firetouchinterest = firetouchinterest ~= nil,
    getconnections = getconnections ~= nil,
    setclipboard = setclipboard ~= nil,
    writefile = (writefile ~= nil and getcustomasset ~= nil),
}

task.spawn(function()
    local r = hrp()
    while not r and S.Running do task.wait(0.5) r = hrp() end
    if r and not S.SafeCF then S.SafeCF = r.CFrame end
end)

----------------------------------------------------------------
-- LOGO (tertanam, dibuat jadi file lewat writefile)
----------------------------------------------------------------
local LOGO_B64 = [[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]]
local function b64dec(s)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local map = {}
    for i = 1, 64 do map[chars:sub(i, i)] = i - 1 end
    local out, buf, bits = {}, 0, 0
    for i = 1, #s do
        local v = map[s:sub(i, i)]
        if v then
            buf = buf * 64 + v
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local p = 2 ^ bits
                local byte = math.floor(buf / p)
                buf = buf % p
                out[#out + 1] = string.char(byte)
            end
        end
    end
    return table.concat(out)
end
local LOGO_ASSET
do
    local ok, res = pcall(function()
        if not (writefile and getcustomasset) then return nil end
        writefile("kizzdev_msk_logo.jpg", b64dec(LOGO_B64))
        return getcustomasset("kizzdev_msk_logo.jpg")
    end)
    if ok and res and res ~= "" then LOGO_ASSET = res end
end

----------------------------------------------------------------
-- UI LIBRARY
----------------------------------------------------------------
local ACCENT = Color3.fromRGB(124, 77, 255)
local ACCENT_L = Color3.fromRGB(190, 150, 255)
local BG     = Color3.fromRGB(13, 13, 16)
local SIDEBG = Color3.fromRGB(17, 17, 21)
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

-- ikon digambar pakai Frame (tidak bergantung font/emoji)
local function mkIcon(kind, parent, color)
    color = color or ACCENT
    local box = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, ClipsDescendants = (kind == "player"),
        Active = false, Parent = parent})
    local parts = {}
    local function P(inst, prop) parts[#parts + 1] = {inst, prop} end
    local function ring(x, y, w, h, th, r)
        local f = new("Frame", {Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
            BackgroundTransparency = 1, Parent = box})
        corner(f, r or 999)
        local st = new("UIStroke", {Thickness = th, Color = color, Parent = f})
        P(st, "Color")
    end
    local function solid(x, y, w, h, r, rot)
        local f = new("Frame", {Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
            BackgroundColor3 = color, BorderSizePixel = 0, Rotation = rot or 0, Parent = box})
        if r then corner(f, r) end
        P(f, "BackgroundColor3")
    end
    local function glyph(t, size)
        local l = new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = t,
            TextSize = size, Font = Enum.Font.GothamBold, TextColor3 = color, Parent = box})
        P(l, "TextColor3")
    end
    if kind == "home" then glyph("⌂", 20)
    elseif kind == "play" then glyph("▶", 15)
    elseif kind == "player" then ring(6, 1, 8, 8, 1.5) ring(2, 11, 16, 16, 1.5)
    elseif kind == "eye" then ring(0, 4, 20, 12, 1.5) solid(7, 7, 6, 6, 3)
    elseif kind == "shield" then ring(3, 1, 14, 17, 1.5, 6) solid(9, 5, 2, 9)
    elseif kind == "gear" then ring(4, 4, 12, 12, 2.5) solid(9, 0, 2, 4) solid(9, 16, 2, 4) solid(0, 9, 4, 2) solid(16, 9, 4, 2)
    elseif kind == "search" then ring(2, 2, 11, 11, 1.5) solid(11, 14, 8, 2, 1, 45)
    elseif kind == "move" then solid(9, 1, 2, 18, 1) solid(1, 9, 18, 2, 1) solid(7, 0, 6, 2, 1) solid(7, 18, 6, 2, 1)
    elseif kind == "resize" then solid(3, 12, 15, 2, 1, -45) solid(10, 15, 8, 2, 1, -45)
    end
    return parts
end
local function colorIcon(parts, c)
    for _, p in ipairs(parts) do p[1][p[2]] = c end
end

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
local W, H = math.min(440, vp.X - 20), math.min(260, vp.Y - 20)
local Main = new("Frame", {Name = "Main", Size = UDim2.fromOffset(W, H),
    Position = UDim2.new(0.5, -W / 2, 0.5, -H / 2), BackgroundColor3 = BG, BorderSizePixel = 0,
    Active = true, ClipsDescendants = true, Parent = Gui})
corner(Main, 16)
stroke(Main, ACCENT, 1, 0.6)
new("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(18, 15, 27), Color3.fromRGB(11, 10, 15)), Rotation = 90, Parent = Main})

-- Sidebar
local Side = new("Frame", {Position = UDim2.fromOffset(7, 7), Size = UDim2.new(0, 40, 1, -14), BackgroundColor3 = SIDEBG, BorderSizePixel = 0, Parent = Main})
corner(Side, 16)
local Logo = new("ImageButton", {Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(4, 4),
    BackgroundColor3 = ACCENT, Image = LOGO_ASSET or "", AutoButtonColor = false, ScaleType = Enum.ScaleType.Crop, Parent = Side})
corner(Logo, 16)
if not LOGO_ASSET then
    new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "KD",
        Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Parent = Logo})
end
local TabList = new("ScrollingFrame", {Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -46),
    BackgroundTransparency = 1, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y, BorderSizePixel = 0, Parent = Side})
new("UIListLayout", {Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = TabList})

-- Top bar
local SearchBox = new("Frame", {Position = UDim2.fromOffset(55, 8), Size = UDim2.new(1, -101, 0, 28),
    BackgroundColor3 = PANEL, Parent = Main})
corner(SearchBox, 14); stroke(SearchBox, ACCENT, 1, 0.8)
local sIcon = new("Frame", {Size = UDim2.fromOffset(26, 28), BackgroundTransparency = 1, Parent = SearchBox})
mkIcon("search", sIcon, SUB)
local Search = new("TextBox", {Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -32, 1, 0),
    BackgroundTransparency = 1, Text = "", PlaceholderText = "Search - KizzDev Library",
    PlaceholderColor3 = SUB, TextColor3 = TEXT, Font = FONT, TextSize = 12, ClearTextOnFocus = false, Parent = SearchBox})
local DragH = new("TextButton", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8),
    Size = UDim2.fromOffset(30, 28), BackgroundTransparency = 1, Text = "", Parent = Main})
mkIcon("move", DragH, SUB)
makeDrag(DragH, Main)
makeDrag(Logo, Main)

-- Content + footer
local Content = new("Frame", {Position = UDim2.fromOffset(55, 44), Size = UDim2.new(1, -63, 1, -70),
    BackgroundTransparency = 1, ClipsDescendants = true, Parent = Main})
new("TextLabel", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 55, 1, -3),
    Size = UDim2.new(1, -90, 0, 18), BackgroundTransparency = 1,
    Text = "KizzDev | Malam Sama Kaka | v3.0", TextColor3 = SUB, Font = FONT, TextSize = 10, Parent = Main})
local Resize = new("TextButton", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -6, 1, -2),
    Size = UDim2.fromOffset(26, 22), BackgroundTransparency = 1, Text = "", ZIndex = 5, Parent = Main})
mkIcon("resize", Resize, SUB)
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
    Size = UDim2.fromOffset(300, 10), BackgroundTransparency = 1, Parent = Gui})
new("UIListLayout", {Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = Toasts})
local function notify(msg, dur)
    local t = new("TextLabel", {Size = UDim2.fromOffset(290, 26), BackgroundColor3 = PANEL, Text = msg,
        TextColor3 = TEXT, Font = FONT, TextSize = 12, TextWrapped = true, Parent = Toasts})
    corner(t, 12); stroke(t, ACCENT, 1, 0.4)
    task.delay(dur or 3, function() if t.Parent then t:Destroy() end end)
end

-- Pages / tabs / search
local Pages, TabBtns, TabIcons, Registry = {}, {}, {}, {}
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
    for n, p in pairs(Pages) do p.Visible = (n == name) end
    for n, b in pairs(TabBtns) do
        local on = (n == name)
        b.BackgroundColor3 = on and Color3.fromRGB(40, 30, 75) or SIDEBG
        colorIcon(TabIcons[n], on and ACCENT_L or ACCENT)
    end
end

local Tab = {}
Tab.__index = Tab
local Sec = {}
Sec.__index = Sec

local function newTab(name, icon)
    local btn = new("TextButton", {Size = UDim2.fromOffset(32, 32), BackgroundColor3 = SIDEBG,
        Text = "", AutoButtonColor = false, Parent = TabList})
    corner(btn, 16)
    TabBtns[name] = btn
    TabIcons[name] = mkIcon(icon, btn, ACCENT)
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

function Tab:Section(title, col)
    local holder = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Color3.fromRGB(23, 21, 31), BorderSizePixel = 0, Parent = (col == 2) and self.Right or self.Left})
    corner(holder, 12); stroke(holder, ACCENT, 1, 0.9)
    local header = new("TextButton", {Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, Text = "", Parent = holder})
    new("TextLabel", {Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -34, 1, 0), BackgroundTransparency = 1,
        Text = title, TextColor3 = TEXT, Font = FONT, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, Parent = header})
    local arrow = new("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0),
        Size = UDim2.fromOffset(16, 26), BackgroundTransparency = 1, Text = "v", TextColor3 = SUB, Font = FONT,
        TextSize = 11, Parent = header})
    local body = new("Frame", {Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 0),
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
    local function render(instant)
        local c = state and ACCENT or OFF
        local p = state and UDim2.fromOffset(18, 2) or UDim2.fromOffset(2, 2)
        if instant then
            sw.BackgroundColor3 = c; knob.Position = p
        else
            TweenService:Create(sw, TweenInfo.new(0.12), {BackgroundColor3 = c}):Play()
            TweenService:Create(knob, TweenInfo.new(0.12), {Position = p}):Play()
        end
    end
    function obj:Set(v, silent)
        state = v and true or false
        render(false)
        if not silent then task.spawn(cb, state) end
    end
    function obj:Get() return state end
    track(f.Activated:Connect(function() obj:Set(not state) end))
    render(true)
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
    corner(bar, 7)
    local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = ACCENT, Parent = bar})
    corner(fill, 7)
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
    corner(b, 10); stroke(b, ACCENT, 1, 0.8)
    track(b.Activated:Connect(function() task.spawn(cb) end))
    reg(b, name)
    return b
end

function Sec:Label(text)
    local l = new("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = text,
        TextColor3 = SUB, Font = FONT, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.Y, Parent = self.Body})
    return {Set = function(_, t) l.Text = t end}
end

function Sec:Input(name, def, cb)
    local f = new("Frame", {Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = self.Body})
    new("TextLabel", {Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = name, TextColor3 = TEXT,
        Font = FONT, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = f})
    local tb = new("TextBox", {Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = ELEM,
        Text = def, TextColor3 = TEXT, Font = FONT, TextSize = 11, ClearTextOnFocus = false, Parent = f})
    corner(tb, 10)
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
    corner(btn, 10)
    local arrow = new("TextLabel", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 0),
        Size = UDim2.fromOffset(14, 22), BackgroundTransparency = 1, Text = "v", TextColor3 = SUB, Font = FONT,
        TextSize = 11, Parent = btn})
    local list = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = ELEM, Visible = false, LayoutOrder = 3, Parent = f})
    corner(list, 10)
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
-- SCANNER
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
    local npcSeen = {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            res.prompts[#res.prompts + 1] = d
        elseif d:IsA("Humanoid") or d:IsA("Animator") or d:IsA("AnimationController") then
            local m = d.Parent
            if m and not m:IsA("Model") then m = nil end
            if m and d:IsA("Animator") and m:IsA("Model") == false then m = nil end
            if m and (d:IsA("Animator") and m.Parent and m.Parent:IsA("Model") and m.Parent ~= Workspace
                and (m:FindFirstChildOfClass("Humanoid") == nil)) then
                -- Animator di dalam Humanoid/AnimationController -> ambil model di atasnya
                m = m.Parent
            end
            if m and m ~= Workspace and not npcSeen[m] and not inChar(m) then
                npcSeen[m] = true
                res.npcs[#res.npcs + 1] = m
            end
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
    local pos = posOf(p.Parent)
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

local function touch(r, part)
    if part and firetouchinterest then
        pcall(function() firetouchinterest(r, part, 0) firetouchinterest(r, part, 1) end)
    end
end

local VIM
pcall(function() VIM = game:GetService("VirtualInputManager") end)
local function holdKey(key, dur)
    if not VIM then return end
    pcall(function()
        VIM:SendKeyEvent(true, key, false, game)
        task.wait(dur)
        VIM:SendKeyEvent(false, key, false, game)
    end)
end

-- pakai prompt: fireproximityprompt, kalau gagal tahan tombol interaksi
local function usePrompt(p)
    if not p or not p.Parent or not p.Enabled then return end
    pcall(function() p.HoldDuration = 0 end)
    local fired = false
    if fireproximityprompt then fired = pcall(fireproximityprompt, p) end
    task.wait(0.12)
    if (not fired) or (p.Parent and p.Enabled) then
        local k = p.KeyboardKeyCode
        holdKey((k and k ~= Enum.KeyCode.Unknown) and k or Enum.KeyCode.E, 0.15)
    end
end

local function itemPrompts(d)
    local ps = promptsOf(d)
    if #ps == 0 and d.Parent and d.Parent ~= Workspace and d.Parent:IsA("Model") then
        local ok, n = pcall(function() return #d.Parent:GetDescendants() end)
        if ok and n < 80 then ps = promptsOf(d.Parent) end
    end
    return ps
end

local function collectItem(d)
    local r = hrp()
    if not r or not d or not d.Parent then return false end
    local pos = posOf(d)
    if not pos then return false end
    local old = r.CFrame
    r.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
    task.wait(0.12)
    touch(r, (d:IsA("BasePart") and d) or d:FindFirstChildWhichIsA("BasePart", true))
    for _, p in ipairs(itemPrompts(d)) do usePrompt(p) end
    local cd = d:FindFirstChildWhichIsA("ClickDetector", true)
    if cd and fireclickdetector then pcall(fireclickdetector, cd) end
    task.wait(0.1)
    if S.ReturnBack and r.Parent then r.CFrame = old end
    return true
end

local collected = {}
local function collectAll(list, force)
    local n = 0
    for _, it in ipairs(list) do
        if not S.Running then break end
        if it.Parent and (force or not collected[it] or tick() - collected[it] > 15) then
            collected[it] = tick()
            if collectItem(it) then n = n + 1 end
        end
    end
    return n
end

-- semua objek ber-prompt (kecuali Kaka / pintu keluar / start)
local function promptItems()
    local out, seen = {}, {}
    for _, p in ipairs(getScan(2).prompts) do
        if p.Enabled and p.Parent then
            local par = p.Parent
            if par:IsA("Attachment") then par = par.Parent end
            if par and (par:IsA("BasePart") or par:IsA("Model")) and not seen[par] then
                local txt = par.Name .. " " .. p.ObjectText .. " " .. p.ActionText
                if not matchAny(txt, KAKA_WORDS) and not matchAny(txt, EXIT_WORDS) and not matchAny(txt, START_WORDS) then
                    seen[par] = true
                    out[#out + 1] = par
                end
            end
        end
    end
    return out
end

local function keyTargets(fresh)
    local sc = getScan(fresh and 0 or 2)
    if #sc.keys > 0 then return sc.keys end
    return promptItems()
end
local function flipTargets(fresh)
    local sc = getScan(fresh and 0 or 2)
    if #sc.flips > 0 then return sc.flips end
    return promptItems()
end
local function farmTargets(mode)
    local sc = getScan(2)
    if mode == "Semua Prompt" then return promptItems() end
    local list = {}
    for _, i in ipairs(sc.keys) do list[#list + 1] = i end
    for _, i in ipairs(sc.flips) do list[#list + 1] = i end
    if #list == 0 and mode == "Otomatis" then return promptItems() end
    return list
end

-- baca "Kunci: 0/5" dari HUD game
local function hudProgress(word)
    local pg = LP:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, l in ipairs(pg:GetDescendants()) do
        if l:IsA("TextLabel") and not l:IsDescendantOf(Gui) then
            local t = lower(l.Text)
            if t:find(word, 1, true) then
                local x, y = t:match("(%d+)%s*/%s*(%d+)")
                if x then return tonumber(x), tonumber(y) end
            end
        end
    end
    return nil
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
            touch(r, (it:IsA("BasePart") and it) or it:FindFirstChildWhichIsA("BasePart", true))
            for _, p in ipairs(promptsOf(it)) do usePrompt(p) end
            n = n + 1
            task.wait(0.3)
        end
    end
    return n
end

-- tombol GUI (skip intro / start)
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

local function pressStart()
    local n = pressGuiWords({"start", "mulai"})
    for _, p in ipairs(getScan(3).prompts) do
        if p.Enabled then
            local t = lower(p.ObjectText .. " " .. p.ActionText .. " " .. (p.Parent and p.Parent.Name or "")
                .. " " .. ((p.Parent and p.Parent.Parent) and p.Parent.Parent.Name or ""))
            if matchAny(t, START_WORDS) then pressPrompt(p, true) n = n + 1 end
        end
    end
    return n
end

----------------------------------------------------------------
-- KALIBRASI (pelajari nama objek terdekat)
----------------------------------------------------------------
local GENERIC = {part = 1, model = 1, union = 1, meshpart = 1, handle = 1, folder = 1, default = 1, base = 1,
    baseplate = 1, wedge = 1, cylinder = 1, sphere = 1, block = 1, cube = 1, mesh = 1, root = 1, main = 1}

local function cleanName(n)
    local s = lower(n)
    s = s:gsub("[%d%s_%-%.]+$", "")
    if #s < 3 then s = lower(n) end
    return s
end
local function addWord(list, w)
    w = lower(w)
    if #w < 2 or GENERIC[w] then return false end
    for _, x in ipairs(list) do if x == w then return true end end
    list[#list + 1] = w
    resetCats(); scanCache = nil
    return true
end

local function isPlayerPart(pt)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and pt:IsDescendantOf(p.Character) then return true end
    end
    return false
end

-- objek interaktif terdekat (prompt > click > touch)
local function nearestInteractable(radius)
    local r = hrp()
    if not r then return nil end
    local ok, parts = pcall(function() return Workspace:GetPartBoundsInRadius(r.Position, radius) end)
    if not ok then return nil end
    local best, bscore, kind, prompt = nil, math.huge, nil, nil
    for _, pt in ipairs(parts) do
        if not isPlayerPart(pt) and pt.Size.Magnitude < 80 then
            local pr = pt:FindFirstChildWhichIsA("ProximityPrompt")
            local pri = 1
            if not pr and pt.Parent and pt.Parent:IsA("Model") then pr = pt.Parent:FindFirstChildWhichIsA("ProximityPrompt", true) end
            local k = pr and "prompt" or nil
            if not k and pt:FindFirstChildWhichIsA("ClickDetector") then k = "click" pri = 2 end
            if not k then
                local okT, tt = pcall(function() return pt:FindFirstChildWhichIsA("TouchTransmitter") end)
                if okT and tt then k = "touch" pri = 3 end
            end
            if k then
                local score = pri * 1000 + (pt.Position - r.Position).Magnitude
                if score < bscore then best, bscore, kind, prompt = pt, score, k, pr end
            end
        end
    end
    return best, kind, prompt
end

local function itemNameOf(pt)
    local cand = {}
    local m = pt:FindFirstAncestorOfClass("Model")
    if m and m ~= LP.Character then
        local ok, n = pcall(function() return #m:GetDescendants() end)
        if ok and n < 80 then cand[#cand + 1] = m.Name end
    end
    cand[#cand + 1] = pt.Name
    if pt.Parent and pt.Parent ~= Workspace then cand[#cand + 1] = pt.Parent.Name end
    for _, n in ipairs(cand) do
        local c = cleanName(n)
        if not GENERIC[c] then return c, n end
    end
    return nil
end

local function learnItem(list, label, extra)
    local pt, kind, prompt = nearestInteractable(20)
    if not pt then notify("Tidak ada objek interaktif dalam 20 stud. Dekati dulu objeknya.", 4) return end
    local w, raw = itemNameOf(pt)
    if not w then notify("Nama objek terlalu umum (" .. pt.Name .. "). Copy Sekitar lalu kirim ke saya.", 5) return end
    addWord(list, w)
    if extra and prompt then
        addWord(extra, prompt.ObjectText); addWord(extra, prompt.ActionText)
    end
    notify(label .. " dipelajari: '" .. w .. "' (" .. kind .. ")", 4)
end

local function learnKaka()
    local r = hrp()
    if not r then return end
    local best, bd
    bd = math.huge
    for _, m in ipairs(getScan(0).npcs) do
        local p = posOf(m)
        if p then
            local d = (p - r.Position).Magnitude
            if d < bd then best, bd = m, d end
        end
    end
    if not best then notify("Tidak ada NPC/monster terdeteksi. Dekati Kaka lalu coba lagi.", 4) return end
    local c = cleanName(best.Name)
    if GENERIC[c] or not addWord(KAKA_WORDS, c) then
        S.KakaMode = "Semua NPC"
        notify("Nama '" .. best.Name .. "' umum -> mode deteksi: Semua NPC", 4)
    else
        S.KakaMode = "Nama Kaka saja"
        notify("Kaka dipelajari: '" .. c .. "' (" .. math.floor(bd) .. " m)", 4)
    end
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
    if S.ESPKey or S.ESPKaka or S.ESPFlip or S.ESPExit or S.ESPPlayer then
        local sc = getScan(3)
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
            local nm = (kind == "Pemain") and inst.Name or kind
            e.lbl.Text = p and (nm .. " [" .. math.floor((p - r.Position).Magnitude) .. "m]") or nm
        end
    end
end

----------------------------------------------------------------
-- RADAR
----------------------------------------------------------------
local Radar = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(220, 220), BackgroundTransparency = 1, Visible = false, Parent = Gui})
new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(34, 34),
    BackgroundTransparency = 1, Text = "▲", TextColor3 = Color3.fromRGB(255, 70, 70), TextSize = 30,
    Font = Enum.Font.GothamBold, TextStrokeTransparency = 0.4, Parent = Radar})
local RadarTxt = new("TextLabel", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -130),
    Size = UDim2.fromOffset(160, 20), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(255, 120, 120),
    Font = FONT, TextSize = 13, TextStrokeTransparency = 0.4, Visible = false, Parent = Gui})

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

local flyBV, flyBG
local function stopFly()
    if flyBV then flyBV:Destroy() flyBV = nil end
    if flyBG then flyBG:Destroy() flyBG = nil end
    local h = hum()
    if h then h.PlatformStand = false end
end

track(RunService.Heartbeat:Connect(function()
    local h = hum()
    if S.SpeedOn and h then h.WalkSpeed = S.SpeedVal end
    if S.Fly then
        local r = hrp()
        local cam = Workspace.CurrentCamera
        if r and h and cam then
            if not flyBV or not flyBV.Parent then
                flyBV = new("BodyVelocity", {MaxForce = Vector3.new(1e9, 1e9, 1e9), Velocity = Vector3.new(), Parent = r})
                flyBG = new("BodyGyro", {MaxTorque = Vector3.new(1e9, 1e9, 1e9), P = 9e4, CFrame = cam.CFrame, Parent = r})
            end
            h.PlatformStand = true
            local loc = cam.CFrame:VectorToObjectSpace(h.MoveDirection)
            flyBV.Velocity = (cam.CFrame.LookVector * (-loc.Z) + cam.CFrame.RightVector * loc.X) * S.FlySpeed
            flyBG.CFrame = cam.CFrame
        end
    end
end))

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
    for _, root in ipairs({LP, LP.Character}) do
        if root then
            for _, d in ipairs(root:GetDescendants()) do
                if (d:IsA("NumberValue") or d:IsA("IntValue")) and matchAny(d.Name, STAM_WORDS)
                    and not lower(d.Name):find("max", 1, true) then
                    local mx = 100
                    for _, s in ipairs(d.Parent:GetChildren()) do
                        if (s:IsA("NumberValue") or s:IsA("IntValue")) and s ~= d and lower(s.Name):find("max", 1, true)
                            and matchAny(s.Name, STAM_WORDS) then mx = s.Value end
                    end
                    stamTargets[#stamTargets + 1] = {obj = d, max = mx}
                end
            end
            for name, val in pairs(root:GetAttributes()) do
                if type(val) == "number" and matchAny(name, STAM_WORDS) and not lower(name):find("max", 1, true) then
                    local mx = root:GetAttribute("Max" .. name) or 100
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
                        if t.obj.Parent then t.obj.Value = S.SetStamina and S.StamVal or math.max(t.obj.Value, t.max) end
                    elseif t.root and t.root.Parent then
                        local cur = t.root:GetAttribute(t.attr) or 0
                        t.root:SetAttribute(t.attr, S.SetStamina and S.StamVal or math.max(cur, t.max))
                    end
                end)
            end
        end
    end
end)

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
-- LOOPS
----------------------------------------------------------------
task.spawn(function()
    while S.Running do
        task.wait(0.3)
        pcall(espTick)
    end
end)

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
                        notify("Kaka dekat! " .. math.floor(d) .. " m")
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

task.spawn(function()
    while S.Running do
        task.wait(0.4)
        if S.AutoFarm then
            pcall(function()
                local a, b = hudProgress("kunci")
                if a and b and a >= b then
                    if S.AutoWin then goExit() task.wait(2) end
                    return
                end
                collectAll(farmTargets(S.FarmMode))
                if S.AutoWin then
                    local a2, b2 = hudProgress("kunci")
                    if a2 and b2 and a2 >= b2 then goExit() end
                end
            end)
        elseif S.AutoWin then
            pcall(goExit)
            task.wait(3)
        end
    end
end)

task.spawn(function()
    while S.Running do
        task.wait(4)
        if S.LobbyStart then pcall(pressStart) end
    end
end)

task.spawn(function()
    while S.Running do
        task.wait(1)
        if S.SkipIntro then pcall(pressGuiWords, {"skip", "lewati"}) end
    end
end)

task.spawn(function()
    while S.Running do
        task.wait(0.4)
        if S.AutoInteract and fireproximityprompt then
            local r = hrp()
            if r then
                for _, p in ipairs(getScan(4).prompts) do
                    if p.Parent and p.Enabled then
                        local pos = posOf(p.Parent)
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
-- LAPORAN / COPY SEKITAR
----------------------------------------------------------------
local function out(text)
    if setclipboard then setclipboard(text) notify("Disalin ke clipboard (" .. #text .. " karakter)", 4)
    else print(text) notify("Tidak ada setclipboard, lihat console", 4) end
end

local function reportNearby(radius)
    local r = hrp()
    if not r then return "(karakter belum siap)" end
    local t = {"=== KizzDev MSK - Sekitar " .. radius .. " stud ===", "PlaceId: " .. game.PlaceId}
    local ok, parts = pcall(function() return Workspace:GetPartBoundsInRadius(r.Position, radius) end)
    local seen, n = {}, 0
    if ok then
        table.sort(parts, function(a, b) return (a.Position - r.Position).Magnitude < (b.Position - r.Position).Magnitude end)
        for _, pt in ipairs(parts) do
            if not isPlayerPart(pt) then
                local full = pt:GetFullName()
                if not seen[full] then
                    seen[full] = true
                    n = n + 1
                    if n > 60 then break end
                    local flags = {}
                    if pt:FindFirstChildWhichIsA("ProximityPrompt", true) then flags[#flags + 1] = "PROMPT" end
                    if pt:FindFirstChildWhichIsA("ClickDetector") then flags[#flags + 1] = "CLICK" end
                    pcall(function() if pt:FindFirstChildWhichIsA("TouchTransmitter") then flags[#flags + 1] = "TOUCH" end end)
                    t[#t + 1] = ("%dm %s [%s] %s"):format(math.floor((pt.Position - r.Position).Magnitude), full, pt.ClassName, table.concat(flags, "+"))
                end
            end
        end
    end
    t[#t + 1] = "--- Prompt dalam 60 stud ---"
    for _, p in ipairs(getScan(0).prompts) do
        local pos = posOf(p.Parent)
        if pos and (pos - r.Position).Magnitude <= 60 then
            t[#t + 1] = ("%dm %s | Action=%s | Object=%s | Enabled=%s"):format(
                math.floor((pos - r.Position).Magnitude), p:GetFullName(), p.ActionText, p.ObjectText, tostring(p.Enabled))
        end
    end
    t[#t + 1] = "--- NPC/Humanoid/Animator ---"
    for _, m in ipairs(getScan(0).npcs) do
        local pos = posOf(m)
        t[#t + 1] = ("%dm %s"):format(pos and math.floor((pos - r.Position).Magnitude) or -1, m:GetFullName())
    end
    return table.concat(t, "\n")
end

local function buildReport()
    local sc = getScan(0)
    local t = {"=== KizzDev MSK Scan v2 ===", "PlaceId: " .. game.PlaceId, "Game: " .. game.Name}
    local ca = {}
    for k, v in pairs(CAPS) do ca[#ca + 1] = k .. "=" .. tostring(v) end
    t[#t + 1] = "Executor caps: " .. table.concat(ca, ", ")
    t[#t + 1] = "Kata Kunci: " .. table.concat(KEY_WORDS, ",")
    t[#t + 1] = "Kata Flip: " .. table.concat(FLIP_WORDS, ",")
    t[#t + 1] = "Kata Kaka: " .. table.concat(KAKA_WORDS, ",")
    t[#t + 1] = "Kata Start: " .. table.concat(START_WORDS, ",")
    local function add(title, list)
        t[#t + 1] = ("[%s] %d"):format(title, #list)
        for i = 1, math.min(#list, 12) do
            local ok, n = pcall(function() return list[i]:GetFullName() end)
            t[#t + 1] = "  " .. (ok and n or "?")
        end
    end
    add("Kunci", sc.keys); add("Flip Flop", sc.flips); add("Pintu Keluar", sc.exits)
    add("Kaka (nama)", sc.kaka); add("NPC", sc.npcs)
    t[#t + 1] = "[Prompt] " .. #sc.prompts
    for i = 1, math.min(#sc.prompts, 25) do
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
local tHome = newTab("Home", "home")
do
    local s = tHome:Section("KizzDev - Malam Sama Kaka", 1)
    local lFps = s:Label("FPS: -")
    local lPing = s:Label("Ping: -")
    local lPl = s:Label("Pemain: -")
    local s2 = tHome:Section("Status Executor", 2)
    local function yn(v) return v and "OK" or "TIDAK ADA" end
    s2:Label("fireproximityprompt: " .. yn(CAPS.fireproximityprompt))
    s2:Label("firetouchinterest: " .. yn(CAPS.firetouchinterest))
    s2:Label("getconnections: " .. yn(CAPS.getconnections))
    s2:Label("setclipboard: " .. yn(CAPS.setclipboard))
    local ex = "-"
    pcall(function() ex = identifyexecutor() end)
    s2:Label("Executor: " .. tostring(ex))
    local s3 = tHome:Section("Cara Pakai", 1)
    s3:Label("Kalau Kunci/Kaka belum terdeteksi: buka tab Setup, dekati objeknya, lalu tekan tombol Pelajari.")
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
local tPlayer = newTab("Player", "player")
do
    local p = tPlayer:Section("Player", 1)
    p:Toggle("Speed Modifier", false, function(v)
        S.SpeedOn = v
        if not v then local h = hum() if h then h.WalkSpeed = 16 end end
    end)
    p:Slider("Kecepatan jalan", 16, 100, 40, function(v) S.SpeedVal = v end)
    p:Toggle("Infinite Stamina", false, function(v) S.InfStamina = v end)
    p:Toggle("Atur Stamina", false, function(v) S.SetStamina = v end)
    p:Slider("Nilai Stamina", 0, 500, 100, function(v) S.StamVal = v end)
    p:Toggle("Noclip", false, function(v) S.Noclip = v end)
    p:Toggle("Infinite Jump", false, function(v) S.InfJump = v end)
    p:Toggle("Fly", false, function(v) S.Fly = v if not v then stopFly() end end)
    p:Slider("Kecepatan terbang", 20, 150, 60, function(v) S.FlySpeed = v end)

    local v = tPlayer:Section("Visual", 2)
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

    local t = tPlayer:Section("Teleport", 2)
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
local tFarm = newTab("Auto Farm", "play")
do
    local a = tFarm:Section("Auto Farm", 1)
    a:Toggle("Aktifkan Auto Farm", false, function(v) S.AutoFarm = v end)
    a:Toggle("Lobby Auto Start (Night)", false, function(v) S.LobbyStart = v end)
    a:Toggle("Auto Skip Intro", false, function(v) S.SkipIntro = v end)
    a:Toggle("Auto Win (pintu keluar)", false, function(v) S.AutoWin = v end)
    a:Toggle("Kembali ke posisi awal", true, function(v) S.ReturnBack = v end)
    a:Toggle("Instant Prompt", false, function(v) S.InstantPrompt = v end)
    a:Toggle("Auto Interact (dekat)", false, function(v) S.AutoInteract = v end)
    a:Dropdown("Mode Farm", {"Otomatis", "Nama Kunci/Flip", "Semua Prompt"}, "Otomatis", function(v) S.FarmMode = v end)

    local m = tFarm:Section("Ambil Manual", 2)
    local function progressText()
        local x, y = hudProgress("kunci")
        return x and (" | HUD Kunci " .. x .. "/" .. y) or ""
    end
    m:Button("Get Key All", function()
        local list = keyTargets(true)
        if #list == 0 then notify("Tidak ada objek yang bisa diambil. Dekati kunci lalu Setup > Pelajari Kunci", 5) return end
        notify("Mengambil " .. #list .. " objek...", 2)
        local n = collectAll(list, true)
        notify("Selesai: " .. n .. "/" .. #list .. progressText(), 4)
    end)
    m:Button("Get Flip Flop", function()
        local list = flipTargets(true)
        if #list == 0 then notify("Tidak ada objek yang bisa diambil. Dekati flip flop lalu Setup > Pelajari Flip Flop", 5) return end
        notify("Mengambil " .. #list .. " objek...", 2)
        local n = collectAll(list, true)
        notify("Selesai: " .. n .. "/" .. #list .. progressText(), 4)
    end)
    m:Button("Ambil Semua Prompt", function()
        local list = promptItems()
        notify("Mengambil " .. #list .. " prompt...", 2)
        notify("Selesai: " .. collectAll(list, true) .. "/" .. #list .. progressText(), 4)
    end)
    m:Button("Auto Win Sekarang", function()
        local n = goExit()
        notify(n > 0 and ("Ke pintu keluar x" .. n) or "Pintu keluar tidak ditemukan. Pakai Setup > Pelajari Pintu", 4)
    end)
    m:Button("Tekan Start Sekarang", function()
        notify("Tombol/prompt ditekan: " .. pressStart())
    end)
end

-- ESP
local tEsp = newTab("ESP", "eye")
do
    local e = tEsp:Section("ESP Options", 1)
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
    local k = tEsp:Section("Deteksi Kaka", 2)
    k:Dropdown("Mode deteksi", {"Otomatis", "Nama Kaka saja", "Semua NPC"}, "Otomatis", function(v)
        S.KakaMode = v
        scanCache = nil
    end)
    k:Label("Otomatis: pakai nama Kaka, kalau tidak ketemu pakai semua NPC.")
end

-- GUARD
local tGuard = newTab("Guard", "shield")
do
    local g = tGuard:Section("Guard System", 1)
    g:Toggle("Guard Kaka", false, function(v) S.Guard = v end)
    g:Dropdown("Mode Berlindung", {"Zona Aman", "Lari Menjauh", "Notifikasi saja"}, "Zona Aman", function(v) S.GuardMode = v end)
    g:Slider("Jarak Deteksi (m)", 10, 100, 30, function(v) S.GuardDist = v end)
    g:Button("Set Zona Aman (posisi ini)", function()
        local r = hrp()
        if r then S.SafeCF = r.CFrame notify("Zona aman disimpan") end
    end)
    local n = tGuard:Section("Notifications", 2)
    n:Toggle("Peringatan Teks", false, function(v) S.WarnText = v end)
    n:Toggle("Radar Arah", false, function(v) S.Radar = v end)
end

-- SETUP
local tSet = newTab("Setup", "gear")
do
    local c = tSet:Section("Kalibrasi (dekati objek)", 1)
    c:Label("Berdiri dekat objeknya, lalu tekan tombol.")
    c:Button("Pelajari Kunci", function() learnItem(KEY_WORDS, "Kunci") end)
    c:Button("Pelajari Flip Flop", function() learnItem(FLIP_WORDS, "Flip Flop") end)
    c:Button("Pelajari Pintu Keluar", function() learnItem(EXIT_WORDS, "Pintu") end)
    c:Button("Pelajari Start (Night)", function() learnItem(START_WORDS, "Start", START_WORDS) end)
    c:Button("Pelajari Kaka (NPC terdekat)", function() learnKaka() end)
    c:Button("Scan Ulang", function()
        local sc = getScan(0)
        notify(("Kunci %d | Flip %d | Pintu %d | Kaka %d | NPC %d"):format(#sc.keys, #sc.flips, #sc.exits, #sc.kaka, #sc.npcs), 5)
    end)

    local u = tSet:Section("Umum", 2)
    u:Toggle("Anti AFK", true, function(v) S.AntiAFK = v end)
    u:Button("Copy Sekitar 25m", function() out(reportNearby(25)) end)
    u:Button("Copy Scan Report", function() out(buildReport()) end)
    u:Button("Rejoin", function() TeleportService:Teleport(game.PlaceId, LP) end)
    u:Button("Unload Script", function() if getgenv and getgenv().KizzDevMSK then getgenv().KizzDevMSK.Unload() end end)

    local k = tSet:Section("Kata Kunci (pisah koma)", 2)
    local function parse(str, tbl)
        for i = #tbl, 1, -1 do tbl[i] = nil end
        for w in tostring(str):gmatch("[^,]+") do
            w = lower(w)
            w = w:gsub("^%s+", "")
            w = w:gsub("%s+$", "")
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
-- TOMBOL MELAYANG + UNLOAD
----------------------------------------------------------------
local Float = new("ImageButton", {Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0, 10, 0.5, -20),
    BackgroundColor3 = ACCENT, Image = LOGO_ASSET or "", ScaleType = Enum.ScaleType.Crop,
    AutoButtonColor = false, Parent = Gui})
corner(Float, 20); stroke(Float, ACCENT_L, 1.5, 0.2)
if not LOGO_ASSET then
    new("TextLabel", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "KD",
        Font = Enum.Font.GothamBlack, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Parent = Float})
end
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

notify("KizzDev Malam Sama Kaka v2 dimuat", 3)
task.spawn(function()
    task.wait(2)
    local ok, sc = pcall(getScan, 0)
    if ok and sc then
        notify(("Terdeteksi - Kunci %d | Flip %d | Pintu %d | Kaka %d | NPC %d"):format(
            #sc.keys, #sc.flips, #sc.exits, #sc.kaka, #sc.npcs), 6)
        if #sc.keys == 0 then notify("Kunci belum ketemu: buka tab Setup > Pelajari Kunci", 6) end
    end
    if not CAPS.fireproximityprompt then notify("Executor tidak punya fireproximityprompt: ambil item/prompt terbatas", 6) end
end)

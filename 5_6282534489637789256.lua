--[[
    egg_ui.lua  ·  一个能直接 loadstring 运行的 Roblox 脚本界面库
    ------------------------------------------------------------
    用法（把 USER / REPO 换成你自己的）：

        loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/egg_ui.lua"))()

    仓库必须是 Public，文件必须真的在 main 分支根目录，名字一字不差。

    自己加功能就照最下面「示例」那段抄，改个名字换个回调就行。
]]

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local LP = Players.LocalPlayer

------------------------------------------------------------------
-- 主题（改这里就能换配色）
------------------------------------------------------------------
local Theme = {
    Bg       = Color3.fromRGB(17, 19, 24),
    Panel    = Color3.fromRGB(23, 26, 33),
    Element  = Color3.fromRGB(30, 34, 43),
    Element2 = Color3.fromRGB(38, 43, 54),
    Element3 = Color3.fromRGB(46, 52, 65),
    Accent   = Color3.fromRGB(124, 92, 255),
    Accent2  = Color3.fromRGB(0, 194, 255),
    Text     = Color3.fromRGB(233, 236, 242),
    Sub      = Color3.fromRGB(138, 145, 160),
    Off      = Color3.fromRGB(56, 61, 74),
    Line     = Color3.fromRGB(48, 53, 66),
}

local F_BODY = Enum.Font.Gotham
local F_BOLD = Enum.Font.GothamBold

------------------------------------------------------------------
-- 小工具
------------------------------------------------------------------
local function make(class, props)
    local inst = Instance.new(class)
    local parent = props and props.Parent
    if props then
        for k, v in pairs(props) do
            if k ~= "Parent" then
                inst[k] = v
            end
        end
    end
    if parent then
        inst.Parent = parent
    end
    return inst
end

local function corner(inst, r)
    return make("UICorner", { Parent = inst, CornerRadius = UDim.new(0, r or 6) })
end

local function stroke(inst, color, thick, trans)
    return make("UIStroke", {
        Parent = inst,
        Color = color or Theme.Line,
        Thickness = thick or 1,
        Transparency = trans or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    })
end

local function pad(inst, t, b, l, r)
    return make("UIPadding", {
        Parent = inst,
        PaddingTop = UDim.new(0, t or 0),
        PaddingBottom = UDim.new(0, b or 0),
        PaddingLeft = UDim.new(0, l or 0),
        PaddingRight = UDim.new(0, r or 0),
    })
end

local function vlist(inst, gap)
    return make("UIListLayout", {
        Parent = inst,
        SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = Enum.FillDirection.Vertical,
        Padding = UDim.new(0, gap or 6),
    })
end

local TI = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function anim(inst, props)
    TweenService:Create(inst, TI, props):Play()
end

local function safeCall(fn, ...)
    if not fn then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        warn("[egg_ui] 回调出错: " .. tostring(err))
    end
end

local function createScreenGui()
    local gui = Instance.new("ScreenGui")
    gui.Name = "EggUI_" .. tostring(math.random(1000, 9999))
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 999
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    if typeof(gethui) == "function" then
        local ok = pcall(function() gui.Parent = gethui() end)
        if ok and gui.Parent then return gui end
    end
    if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
        pcall(function() syn.protect_gui(gui) end)
    end
    local ok = pcall(function() gui.Parent = game:GetService("CoreGui") end)
    if ok and gui.Parent then return gui end
    gui.Parent = LP:WaitForChild("PlayerGui")
    return gui
end

local function makeDraggable(target, handle)
    handle = handle or target
    local dragging, dragStart, startPos = false, nil, nil

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

------------------------------------------------------------------
-- Section：一栏控件
------------------------------------------------------------------
local Section = {}
Section.__index = Section

function Section:_nextOrder()
    self.Order = (self.Order or 0) + 10
    return self.Order
end

function Section:AddLabel(text)
    local l = make("TextLabel", {
        Parent = self.Holder,
        Size = UDim2.new(1, 0, 0, 18),
        BackgroundTransparency = 1,
        Font = F_BODY,
        TextSize = 12,
        TextColor3 = Theme.Sub,
        Text = text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        LayoutOrder = self:_nextOrder(),
    })
    return l
end

function Section:AddToggle(text, default, callback)
    default = default and true or false

    local row = make("Frame", {
        Parent = self.Holder,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.Element,
        BorderSizePixel = 0,
        LayoutOrder = self:_nextOrder(),
    })
    corner(row, 6)

    make("TextLabel", {
        Parent = row,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -70, 1, 0),
        BackgroundTransparency = 1,
        Font = F_BODY,
        TextSize = 13,
        TextColor3 = Theme.Text,
        Text = text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local sw = make("Frame", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -10, 0.5, 0),
        Size = UDim2.fromOffset(38, 20),
        BackgroundColor3 = default and Theme.Accent or Theme.Off,
        BorderSizePixel = 0,
    })
    corner(sw, 10)

    local knob = make("Frame", {
        Parent = sw,
        AnchorPoint = Vector2.new(0, 0.5),
        Position = default and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.fromOffset(16, 16),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    corner(knob, 8)

    local api = { Value = default }

    local function set(v, silent)
        api.Value = v and true or false
        anim(sw, { BackgroundColor3 = api.Value and Theme.Accent or Theme.Off })
        anim(knob, {
            Position = api.Value and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0)
        })
        if not silent then
            safeCall(callback, api.Value)
        end
    end

    local hit = make("TextButton", {
        Parent = row,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    })
    hit.MouseButton1Click:Connect(function()
        set(not api.Value)
    end)

    api.Set = function(v) set(v) end
    api.Toggle = function() set(not api.Value) end
    return api
end

function Section:AddButton(text, callback)
    local b = make("TextButton", {
        Parent = self.Holder,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.Element2,
        BorderSizePixel = 0,
        Font = F_BOLD,
        TextSize = 13,
        TextColor3 = Theme.Text,
        Text = text,
        AutoButtonColor = false,
        LayoutOrder = self:_nextOrder(),
    })
    corner(b, 6)

    b.MouseEnter:Connect(function() anim(b, { BackgroundColor3 = Theme.Element3 }) end)
    b.MouseLeave:Connect(function() anim(b, { BackgroundColor3 = Theme.Element2 }) end)
    b.MouseButton1Click:Connect(function() safeCall(callback) end)
    return b
end

function Section:AddSlider(text, min, max, default, callback)
    default = default or min
    if max <= min then max = min + 1 end

    local row = make("Frame", {
        Parent = self.Holder,
        Size = UDim2.new(1, 0, 0, 46),
        BackgroundColor3 = Theme.Element,
        BorderSizePixel = 0,
        LayoutOrder = self:_nextOrder(),
    })
    corner(row, 6)

    make("TextLabel", {
        Parent = row,
        Position = UDim2.new(0, 10, 0, 5),
        Size = UDim2.new(1, -80, 0, 16),
        BackgroundTransparency = 1,
        Font = F_BODY,
        TextSize = 13,
        TextColor3 = Theme.Text,
        Text = text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local valLabel = make("TextLabel", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -10, 0, 5),
        Size = UDim2.fromOffset(64, 16),
        BackgroundTransparency = 1,
        Font = F_BOLD,
        TextSize = 13,
        TextColor3 = Theme.Accent2,
        Text = tostring(default),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local track = make("Frame", {
        Parent = row,
        Position = UDim2.new(0, 10, 0, 32),
        Size = UDim2.new(1, -20, 0, 6),
        BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0,
    })
    corner(track, 3)

    local fill = make("Frame", {
        Parent = track,
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    })
    corner(fill, 3)

    local dot = make("Frame", {
        Parent = track,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0,
        ZIndex = 2,
    })
    corner(dot, 6)

    local api = { Value = default }

    local function apply(v, silent)
        v = math.clamp(v, min, max)
        local alpha = (max - min > 0) and ((v - min) / (max - min)) or 0
        api.Value = v
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        dot.Position = UDim2.new(alpha, 0, 0.5, 0)
        local shown = (max - min >= 20) and math.floor(v + 0.5) or (math.floor(v * 10 + 0.5) / 10)
        valLabel.Text = tostring(shown)
        if not silent then
            safeCall(callback, v)
        end
    end

    local dragging = false
    local function fromInput(input)
        local rel = 0
        if track.AbsoluteSize.X > 0 then
            rel = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        end
        apply(min + (max - min) * rel)
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromInput(input)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            fromInput(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    apply(default, true)

    api.Set = function(v) apply(v) end
    return api
end

function Section:AddDropdown(text, options, default, callback)
    options = options or {}
    default = default or options[1] or ""

    local baseOrder = self:_nextOrder()

    local row = make("Frame", {
        Parent = self.Holder,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.Element,
        BorderSizePixel = 0,
        LayoutOrder = baseOrder,
    })
    corner(row, 6)

    make("TextLabel", {
        Parent = row,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -150, 1, 0),
        BackgroundTransparency = 1,
        Font = F_BODY,
        TextSize = 13,
        TextColor3 = Theme.Text,
        Text = text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local valLabel = make("TextLabel", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -22, 0.5, 0),
        Size = UDim2.new(0, 110, 1, 0),
        BackgroundTransparency = 1,
        Font = F_BOLD,
        TextSize = 12,
        TextColor3 = Theme.Accent2,
        Text = tostring(default),
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    make("TextLabel", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(12, 12),
        BackgroundTransparency = 1,
        Font = F_BOLD,
        TextSize = 12,
        TextColor3 = Theme.Sub,
        Text = "v",
    })

    local list = make("Frame", {
        Parent = self.Holder,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Element2,
        BorderSizePixel = 0,
        Visible = false,
        LayoutOrder = baseOrder + 5,
    })
    corner(list, 6)
    pad(list, 5, 5, 5, 5)
    vlist(list, 3)

    local api = { Value = default }

    local function select(opt)
        api.Value = opt
        valLabel.Text = tostring(opt)
        list.Visible = false
        safeCall(callback, opt)
    end

    for _, opt in ipairs(options) do
        local ob = make("TextButton", {
            Parent = list,
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            Font = F_BODY,
            TextSize = 12,
            TextColor3 = Theme.Text,
            Text = "  " .. tostring(opt),
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
        })
        corner(ob, 5)
        ob.MouseEnter:Connect(function() anim(ob, { BackgroundColor3 = Theme.Element3 }) end)
        ob.MouseLeave:Connect(function() anim(ob, { BackgroundColor3 = Theme.Element }) end)
        ob.MouseButton1Click:Connect(function() select(opt) end)
    end

    local hit = make("TextButton", {
        Parent = row,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        AutoButtonColor = false,
    })
    hit.MouseButton1Click:Connect(function()
        list.Visible = not list.Visible
    end)

    api.Set = function(v) select(v) end
    return api
end

function Section:AddTextbox(text, default, callback)
    local row = make("Frame", {
        Parent = self.Holder,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.Element,
        BorderSizePixel = 0,
        LayoutOrder = self:_nextOrder(),
    })
    corner(row, 6)

    make("TextLabel", {
        Parent = row,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -180, 1, 0),
        BackgroundTransparency = 1,
        Font = F_BODY,
        TextSize = 13,
        TextColor3 = Theme.Text,
        Text = text,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local box = make("TextBox", {
        Parent = row,
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 0),
        Size = UDim2.fromOffset(160, 22),
        BackgroundColor3 = Theme.Element2,
        BorderSizePixel = 0,
        Font = F_BODY,
        TextSize = 12,
        TextColor3 = Theme.Text,
        PlaceholderText = "输入…",
        PlaceholderColor3 = Theme.Sub,
        Text = default or "",
        ClearTextOnFocus = false,
    })
    corner(box, 5)
    pad(box, 0, 0, 6, 6)

    box.FocusLost:Connect(function(enter)
        safeCall(callback, box.Text, enter)
    end)

    return box
end

------------------------------------------------------------------
-- Tab：一个页面
------------------------------------------------------------------
local Tab = {}
Tab.__index = Tab

function Tab:Section(title)
    self.PageOrder = (self.PageOrder or 0) + 1

    local holder = make("Frame", {
        Parent = self.Page,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
        LayoutOrder = self.PageOrder,
    })
    corner(holder, 10)
    pad(holder, 8, 10, 8, 8)
    vlist(holder, 6)

    local sec = setmetatable({ Holder = holder, Order = 0 }, Section)

    if title and title ~= "" then
        make("TextLabel", {
            Parent = holder,
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1,
            Font = F_BOLD,
            TextSize = 13,
            TextColor3 = Theme.Text,
            Text = title,
            TextXAlignment = Enum.TextXAlignment.Left,
            LayoutOrder = 0,
        })
    end

    return sec
end

function Tab:Label(text)
    local l = make("TextLabel", {
        Parent = self.Page,
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Font = F_BODY,
        TextSize = 12,
        TextColor3 = Theme.Sub,
        Text = text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = (self.PageOrder or 0) + 1,
    })
    self.PageOrder = (self.PageOrder or 0) + 1
    return l
end

------------------------------------------------------------------
-- EggUI 主类
------------------------------------------------------------------
local EggUI = {}
EggUI.__index = EggUI
EggUI.Theme = Theme

function EggUI.new(cfg)
    cfg = cfg or {}
    local self = setmetatable({}, EggUI)

    local W = cfg.Width or 500
    local H = cfg.Height or 340

    self.Tabs = {}
    self.Gui = createScreenGui()
    self.FullSize = UDim2.fromOffset(W, H)

    local root = make("Frame", {
        Name = "Root",
        Parent = self.Gui,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.45),
        Size = self.FullSize,
        BackgroundColor3 = Theme.Bg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    corner(root, 12)
    stroke(root, Theme.Line, 1, 0.25)
    self.Root = root

    local uiScale = make("UIScale", { Parent = root, Scale = 1 })
    self.UIScale = uiScale
    local function updateScale()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local s = math.min(1, (vp.X - 24) / W, (vp.Y - 24) / H)
        uiScale.Scale = math.clamp(s, 0.55, 1)
    end
    pcall(function()
        updateScale()
        if workspace.CurrentCamera then
            workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
        end
    end)

    -- 顶栏
    local bar = make("Frame", {
        Parent = root,
        Size = UDim2.new(1, 0, 0, 44),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
    })
    self.Bar = bar

    make("Frame", {
        Parent = bar,
        Position = UDim2.new(0, 0, 1, -1),
        Size = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = Theme.Line,
        BorderSizePixel = 0,
    })

    local logo = make("Frame", {
        Parent = bar,
        Position = UDim2.new(0, 12, 0.5, -11),
        Size = UDim2.fromOffset(22, 22),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel = 0,
    })
    corner(logo, 7)
    make("UIGradient", {
        Parent = logo,
        Color = ColorSequence.new(Theme.Accent, Theme.Accent2),
        Rotation = 45,
    })

    make("TextLabel", {
        Parent = bar,
        Position = UDim2.new(0, 42, 0, 7),
        Size = UDim2.new(1, -120, 0, 16),
        BackgroundTransparency = 1,
        Font = F_BOLD,
        TextSize = 14,
        TextColor3 = Theme.Text,
        Text = cfg.Title or "EGG HUB",
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    make("TextLabel", {
        Parent = bar,
        Position = UDim2.new(0, 42, 0, 23),
        Size = UDim2.new(1, -120, 0, 14),
        BackgroundTransparency = 1,
        Font = F_BODY,
        TextSize = 11,
        TextColor3 = Theme.Sub,
        Text = cfg.Subtitle or "v1.0",
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local function barButton(text, x, cb)
        local b = make("TextButton", {
            Parent = bar,
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, x, 0.5, 0),
            Size = UDim2.fromOffset(24, 24),
            BackgroundColor3 = Theme.Element,
            BorderSizePixel = 0,
            Font = F_BOLD,
            TextSize = 14,
            TextColor3 = Theme.Sub,
            Text = text,
            AutoButtonColor = false,
        })
        corner(b, 6)
        b.MouseEnter:Connect(function()
            anim(b, { BackgroundColor3 = Theme.Element3, TextColor3 = Theme.Text })
        end)
        b.MouseLeave:Connect(function()
            anim(b, { BackgroundColor3 = Theme.Element, TextColor3 = Theme.Sub })
        end)
        b.MouseButton1Click:Connect(function() safeCall(cb) end)
        return b
    end

    barButton("x", -12, function() self:Destroy() end)
    barButton("-", -42, function() self:ToggleMinimize() end)

    -- 左侧标签栏
    local tabbar = make("Frame", {
        Parent = root,
        Position = UDim2.new(0, 8, 0, 52),
        Size = UDim2.new(0, 120, 1, -60),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
    })
    corner(tabbar, 10)
    pad(tabbar, 6, 6, 6, 6)
    vlist(tabbar, 3)
    self.TabBar = tabbar

    -- 右侧内容区
    local content = make("Frame", {
        Parent = root,
        Position = UDim2.new(0, 136, 0, 52),
        Size = UDim2.new(1, -144, 1, -60),
        BackgroundTransparency = 1,
    })
    self.Content = content

    self.Minimized = false
    makeDraggable(root, bar)

    return self
end

function EggUI:AddTab(name)
    self.TabCount = (self.TabCount or 0) + 1

    local btn = make("TextButton", {
        Parent = self.TabBar,
        Size = UDim2.new(1, 0, 0, 32),
        BackgroundColor3 = Theme.Element,
        BorderSizePixel = 0,
        Font = F_BODY,
        TextSize = 13,
        TextColor3 = Theme.Sub,
        Text = "  " .. tostring(name),
        TextXAlignment = Enum.TextXAlignment.Left,
        AutoButtonColor = false,
        LayoutOrder = self.TabCount,
    })
    corner(btn, 6)

    local page = make("ScrollingFrame", {
        Parent = self.Content,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Theme.Element3,
        ScrollBarImageTransparency = 0.3,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true,
    })
    pad(page, 2, 12, 2, 8)
    vlist(page, 8)

    local tab = setmetatable({
        Name = tostring(name),
        Button = btn,
        Page = page,
        PageOrder = 0,
        Owner = self,
    }, Tab)

    btn.MouseEnter:Connect(function()
        if self.Active ~= tab then
            anim(btn, { BackgroundColor3 = Theme.Element2 })
        end
    end)
    btn.MouseLeave:Connect(function()
        if self.Active ~= tab then
            anim(btn, { BackgroundColor3 = Theme.Element })
        end
    end)
    btn.MouseButton1Click:Connect(function()
        self:SelectTab(tab)
    end)

    table.insert(self.Tabs, tab)

    if #self.Tabs == 1 then
        self:SelectTab(tab)
    end

    return tab
end

function EggUI:SelectTab(tab)
    for _, t in ipairs(self.Tabs) do
        t.Page.Visible = false
        t.Button.BackgroundColor3 = Theme.Element
        t.Button.TextColor3 = Theme.Sub
    end
    tab.Page.Visible = true
    tab.Button.BackgroundColor3 = Theme.Accent
    tab.Button.TextColor3 = Color3.fromRGB(255, 255, 255)
    self.Active = tab
end

function EggUI:ToggleMinimize()
    self.Minimized = not self.Minimized
    if self.Minimized then
        self.TabBar.Visible = false
        self.Content.Visible = false
        self.Root.Size = UDim2.fromOffset(self.FullSize.X.Offset, 44)
    else
        self.TabBar.Visible = true
        self.Content.Visible = true
        self.Root.Size = self.FullSize
    end
end

function EggUI:Notify(text, duration)
    duration = duration or 2
    if self._toast and self._toast.Parent then
        self._toast:Destroy()
    end

    local frame = make("Frame", {
        Parent = self.Gui,
        AnchorPoint = Vector2.new(0.5, 1),
        Position = UDim2.new(0.5, 0, 1, -26),
        Size = UDim2.fromOffset(230, 36),
        BackgroundColor3 = Theme.Panel,
        BorderSizePixel = 0,
    })
    corner(frame, 8)
    stroke(frame, Theme.Accent, 1, 0.2)

    make("TextLabel", {
        Parent = frame,
        Position = UDim2.new(0, 10, 0, 0),
        Size = UDim2.new(1, -20, 1, 0),
        BackgroundTransparency = 1,
        Font = F_BOLD,
        TextSize = 13,
        TextColor3 = Theme.Text,
        Text = tostring(text),
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    self._toast = frame
    task.delay(duration, function()
        if frame and frame.Parent then
            frame:Destroy()
        end
    end)
end

function EggUI:Destroy()
    if self.Gui then
        pcall(function() self.Gui:Destroy() end)
        self.Gui = nil
    end
end

------------------------------------------------------------------
-- 示例：下面这段就是你的功能，改这里
------------------------------------------------------------------
local Settings = {
    WalkSpeed = 16,
    JumpPower = 50,
    InfiniteJump = false,
}

local function getHumanoid()
    local char = LP.Character
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end

-- 持续把设置写回角色（重生后也会自动恢复）
task.spawn(function()
    while task.wait(0.5) do
        local hum = getHumanoid()
        if hum then
            hum.WalkSpeed = Settings.WalkSpeed
            hum.JumpPower = Settings.JumpPower
            hum.UseJumpPower = true
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if not Settings.InfiniteJump then return end
    local hum = getHumanoid()
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

local Win = EggUI.new({
    Title = "EGG HUB",
    Subtitle = "v1.0  ·  自己改着玩",
    Width = 500,
    Height = 340,
})

-- 第一个标签
local tabMain = Win:AddTab("主要")

local secChar = tabMain:Section("角色")
secChar:AddSlider("移动速度", 16, 300, 16, function(v)
    Settings.WalkSpeed = v
end)
secChar:AddSlider("跳跃力度", 50, 300, 50, function(v)
    Settings.JumpPower = v
end)
secChar:AddToggle("无限跳跃", false, function(v)
    Settings.InfiniteJump = v
end)
secChar:AddButton("回到默认速度", function()
    Settings.WalkSpeed = 16
    Settings.JumpPower = 50
    local hum = getHumanoid()
    if hum then
        hum.WalkSpeed = 16
        hum.JumpPower = 50
    end
    Win:Notify("已恢复默认")
end)

local secInfo = tabMain:Section("说明")
secInfo:AddLabel("这一栏的控件都是真的能用，速度改了马上生效。")
secInfo:AddLabel("重生之后设置会自动重新应用一次。")

-- 第二个标签
local tabMore = Win:AddTab("其他")

local secDemo = tabMore:Section("控件示例")
secDemo:AddToggle("示例开关", false, function(v)
    print("[egg_ui] 开关 ->", v)
end)
secDemo:AddDropdown("示例下拉", {"选项 A", "选项 B", "选项 C"}, "选项 A", function(v)
    print("[egg_ui] 下拉 ->", v)
end)
secDemo:AddTextbox("示例输入", "", function(text)
    print("[egg_ui] 输入 ->", text)
end)
secDemo:AddButton("点我弹提示", function()
    Win:Notify("回调跑通了")
end)
secDemo:AddLabel("要加自己的功能，就照上面这几行的写法抄，换个名字换个回调。")

local secOps = tabMore:Section("操作")
secOps:AddButton("收起窗口", function() Win:ToggleMinimize() end)
secOps:AddButton("关闭界面", function() Win:Destroy() end)

print("[egg_ui] 加载完成")

return EggUI

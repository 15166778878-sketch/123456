--[[ ================================================================
     文件：eggstealer_safe.lua
     罗布勒斯 自动偷蛋 · 反踢人安全版（不瞬移 / 不改提示属性 / 拟人节奏）
     执行器：忍者 / Fluxus / Delta / Codex
     左上角拖动，右上角红色 ✕ 一键卸载
     ================================================================ ]]

local Players     = game:GetService("Players")
local UIS         = game:GetService("UserInputService")
local WS          = game:GetService("Workspace")
local Pathfinding = game:GetService("PathfindingService")
local VirtualUser = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
local PG = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")

local CFG = {
	Running   = false, -- 总开关
	Speed     = 20,    -- 步速（极度安全值 16~24）
	MaxDist   = 400,   -- 索敌距离
	ActGapMin = 1.2,   -- 两次偷蛋最小间隔（拟人）
	ActGapMax = 2.8,   -- 两次偷蛋最大间隔
	RestEvery = 50,    -- 每多少次秒休息一次
	RestFor   = 4,     -- 每次休息秒数
	PerEggCD  = 10,    -- 同一个蛋的冷却
	MineSkip  = true,  -- 跳过自己地块上的蛋
	AutoJump  = true,  -- 卡住自动跳
	HideName  = true,  -- UI 随机命名（防管理员扫描界面名）
}

local KEYWORDS = {"steal","take","grab","egg","rob","claim","collect","pick"}

local Running   = true
local Stolen, Failed = 0, 0
local blocked   = {}
local nextActAt = 0
local restUntil = 0
local restTrigger = os.clock() + CFG.RestEvery
local Gui, Status, MainBtn
local speedApplied = false

-- ================= 基础 =================
local function getChar()
	local ch = LP.Character
	if not ch then return end
	local hum = ch:FindFirstChildOfClass("Humanoid")
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	if hum and hrp then return ch, hrp, hum end
end

local function hasKW(s, kw)
	return s and string.find(string.lower(s), kw, 1, true) ~= nil
end

local function isMe(v)
	if v == nil then return false end
	local s = tostring(v)
	return s == tostring(LP.UserId) or s == LP.Name or s == LP.DisplayName
end

local function plotOwner(inst)
	local cur = inst
	for _ = 1, 16 do
		if not cur or cur == WS then break end
		local o = cur:GetAttribute("Owner") or cur:GetAttribute("PlacedBy")
			or cur:GetAttribute("OwnerName") or cur:GetAttribute("OwnerId")
		if o ~= nil then return o end
		if cur.Name == LP.Name or cur.Name == LP.Name .. "'s Plot"
			or cur.Name == LP.Name .. "'s Base" then return LP.Name end
		cur = cur.Parent
	end
end

local function setStatus(t)
	if Status and Status.Parent then Status.Text = t end
end

-- ================= 提示索引（增量，不刷 GetDescendants） =================
local prompts = {}
local function indexPrompt(d)
	if d:IsA("ProximityPrompt") then table.insert(prompts, d) end
end

for _, d in ipairs(WS:GetDescendants()) do
	pcall(indexPrompt, d)
end
WS.DescendantAdded:Connect(function(d)
	pcall(indexPrompt, d)
end)

-- ================= 蛋识别 =================
local function isEggPrompt(p)
	local txt = (p.ActionText or "") .. "|" .. (p.ObjectText or "")
	for _, kw in ipairs(KEYWORDS) do
		if hasKW(txt, kw) then return true end
	end
	local cur = p
	for _ = 1, 7 do
		if not cur or cur == WS then break end
		if hasKW(cur.Name, "egg") then return true end
		cur = cur.Parent
	end
	return false
end

local function eggInfo(p)
	if not isEggPrompt(p) then return end
	local par = p.Parent
	if not par then return end
	local part = par:IsA("BasePart") and par or par:FindFirstChildWhichIsA("BasePart", true)
	if not part then return end
	return {
		prompt = p,
		part   = part,
		pos    = part.Position,
		mine   = isMe(plotOwner(p)),
	}
end

local function pickTarget()
	local _, hrp = getChar()
	if not hrp then return end
	local origin, now = hrp.Position, os.clock()
	local best, bestD, bestPart, bestInfo

	for i = #prompts, 1, -1 do
		local p = prompts[i]
		if not p or not p.Parent then
			table.remove(prompts, i)
		elseif p.Enabled then
			local rel = blocked[p]
			if not (rel and now < rel) then
				local info = eggInfo(p)
				if info and not (CFG.MineSkip and info.mine) then
					local d = (info.pos - origin).Magnitude
					if d <= CFG.MaxDist and (not bestD or d < bestD) then
						best, bestD, bestPart, bestInfo = p, d, info.part, info
					end
				end
			end
		end
	end
	return best, bestPart, bestInfo
end

-- ================= 步行前往（合法移动，服务端看不到瞬移） =================
local function walkTo(goal, deadline)
	local ch, hrp, hum = getChar()
	if not hum then return false end

	local waypoints
	local path = Pathfinding:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = true,
		WaypointSpacing = 6,
	})
	local ok = pcall(function()
		path:ComputeAsync(hrp.Position, goal)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		waypoints = path:GetWaypoints()
	end
	if not waypoints or #waypoints == 0 then
		waypoints = { { Position = goal, Action = Enum.PathWaypointAction.Walk } }
	end

	for _, wp in ipairs(waypoints) do
		if os.clock() > deadline then return false end
		if not hum.Parent or not hrp.Parent then return false end

		hum:MoveTo(wp.Position)
		if wp.Action == Enum.PathWaypointAction.Jump then hum.Jump = true end

		local lastPos = hrp.Position
		local stuck = 0
		while os.clock() < deadline do
			if not hum.Parent or not hrp.Parent then return false end
			if (hrp.Position - wp.Position).Magnitude < 4 then break end
			task.wait(0.15)
			if (hrp.Position - lastPos).Magnitude < 0.8 then
				stuck = stuck + 1
				if CFG.AutoJump and stuck == 3 then hum.Jump = true end
				if stuck >= 12 then return false end
			else
				stuck = 0
			end
			lastPos = hrp.Position
		end
	end
	return true
end

-- ================= 触发提示（保留原属性，等同真人按 E） =================
local FPP = (typeof(fireproximityprompt) == "function") and fireproximityprompt or nil

local function trySteal(p, part)
	local ch, hrp, hum = getChar()
	if not hrp then return false end
	if not p.Parent or not part.Parent then return false end

	local reach = math.min(p.MaxActivationDistance or 10, 12)
	if (hrp.Position - part.Position).Magnitude > reach then return false end

	if FPP then
		if pcall(FPP, p) then return true end
	end
	return pcall(function()
		p:InputHoldBegin()
		task.wait((p.HoldDuration or 0) + 0.06)
		p:InputHoldEnd()
	end)
end

-- ================= 主流程 =================
local function step()
	local ch, hrp, hum = getChar()
	if not hrp then
		setStatus("状态：等待角色加载…")
		task.wait(0.3)
		return
	end

	local now = os.clock()
	if now < restUntil then
		setStatus(string.format("状态：拟人休息中 %.1fs  |  已偷 %d", restUntil - now, Stolen))
		task.wait(0.3)
		return
	end
	if now < nextActAt then
		setStatus(string.format("状态：待命 %.1fs  |  已偷 %d  |  失败 %d", nextActAt - now, Stolen, Failed))
		task.wait(0.2)
		return
	end
	if now > restTrigger then
		restUntil = now + CFG.RestFor
		restTrigger = now + CFG.RestEvery
		setStatus("状态：拟人休息中…")
		return
	end

	local target, part, info = pickTarget()
	if not target then
		setStatus(string.format("状态：搜索中…  |  已偷 %d  |  失败 %d", Stolen, Failed))
		task.wait(0.4)
		return
	end

	setStatus(string.format("状态：前往目标（%d 格）  |  已偷 %d", math.floor((info.pos - hrp.Position).Magnitude), Stolen))
	walkTo(info.pos, os.clock() + 25)

	if not target.Parent then return end

	if trySteal(target, part) then
		Stolen = Stolen + 1
		blocked[target] = os.clock() + CFG.PerEggCD
	else
		Failed = Failed + 1
		blocked[target] = os.clock() + 5
	end

	nextActAt = os.clock() + CFG.ActGapMin + math.random() * (CFG.ActGapMax - CFG.ActGapMin)
end

task.spawn(function()
	while Running do
		if CFG.Running then
			local ok = pcall(step)
			if not ok then
				setStatus("状态：运行异常，自动恢复")
				task.wait(0.5)
			end
			task.wait(0.1)
		else
			task.wait(0.25)
		end
	end
end)

-- ================= UI =================
local ACCENT = Color3.fromRGB(98, 178, 255)
local RED    = Color3.fromRGB(224, 76, 76)
local GREEN  = Color3.fromRGB(62, 176, 112)
local BG     = Color3.fromRGB(24, 26, 33)
local CARD   = Color3.fromRGB(36, 39, 49)
local TXT    = Color3.fromRGB(228, 234, 244)
local DIM    = Color3.fromRGB(158, 168, 186)

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = o
	return c
end

local vp = Vector2.new(400, 800)
pcall(function() vp = WS.CurrentCamera.ViewportSize end)

Gui = Instance.new("ScreenGui")
Gui.Name = CFG.HideName and ("UI_" .. string.format("%x", math.random(4096, 65535))) or "EggSafeUI"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 5000
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PG

local Main = Instance.new("Frame")
Main.AnchorPoint = Vector2.new(0.5, 0)
Main.Position = UDim2.new(0.5, 0, 0, 46)
Main.Size = UDim2.new(0, math.clamp(vp.X - 40, 250, 320), 0, math.clamp(vp.Y * 0.6, 320, 500))
Main.BackgroundColor3 = BG
Main.BorderSizePixel = 0
Main.Parent = Gui
corner(Main, 14)

local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT
stroke.Thickness = 1.2
stroke.Transparency = 0.55
stroke.Parent = Main

local Bar = Instance.new("Frame")
Bar.Size = UDim2.new(1, 0, 0, 48)
Bar.BackgroundTransparency = 1
Bar.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -64, 0, 48)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextColor3 = TXT
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Text = "🥚 偷蛋 · 安全模式"
Title.Parent = Bar

local Close = Instance.new("TextButton")
Close.Size = UDim2.new(0, 44, 0, 44)
Close.Position = UDim2.new(1, -50, 0, 2)
Close.BackgroundColor3 = RED
Close.Text = "✕"
Close.Font = Enum.Font.GothamBold
Close.TextSize = 22
Close.TextColor3 = Color3.new(1, 1, 1)
Close.ZIndex = 30
Close.Parent = Main
corner(Close, 12)

local Scroll = Instance.new("ScrollingFrame")
Scroll.Size = UDim2.new(1, -20, 1, -58)
Scroll.Position = UDim2.new(0, 10, 0, 52)
Scroll.BackgroundTransparency = 1
Scroll.BorderSizePixel = 0
Scroll.ScrollBarThickness = 4
Scroll.ScrollBarImageColor3 = ACCENT
Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
Scroll.ScrollingDirection = Enum.ScrollingDirection.Y
Scroll.Parent = Main

local List = Instance.new("UIListLayout", Scroll)
List.Padding = UDim.new(0, 8)
List.SortOrder = Enum.SortOrder.LayoutOrder

Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 44)
Status.BackgroundColor3 = CARD
Status.Font = Enum.Font.Gotham
Status.TextSize = 12
Status.TextColor3 = DIM
Status.TextWrapped = true
Status.Text = "状态：待机"
Status.LayoutOrder = 1
Status.Parent = Scroll
corner(Status, 10)

MainBtn = Instance.new("TextButton")
MainBtn.Size = UDim2.new(1, 0, 0, 48)
MainBtn.BackgroundColor3 = ACCENT
MainBtn.Font = Enum.Font.GothamBold
MainBtn.TextSize = 17
MainBtn.TextColor3 = Color3.new(1, 1, 1)
MainBtn.Text = "开始自动偷蛋"
MainBtn.LayoutOrder = 2
MainBtn.Parent = Scroll
corner(MainBtn, 12)

local function makeToggle(order, text, default, onChange)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 44)
	b.BackgroundColor3 = default and GREEN or CARD
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text .. "：" .. (default and "开" or "关")
	b.LayoutOrder = order
	b.Parent = Scroll
	corner(b, 10)
	local state = default
	b.MouseButton1Click:Connect(function()
		state = not state
		b.Text = text .. "：" .. (state and "开" or "关")
		b.BackgroundColor3 = state and GREEN or CARD
		if onChange then onChange(state) end
	end)
	return b
end

local function makeSlider(order, text, min, max, default, decimals, onChange)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 50)
	row.BackgroundColor3 = CARD
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = Scroll
	corner(row, 10)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -92, 0, 20)
	label.Position = UDim2.new(0, 12, 0, 5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextColor3 = TXT
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.Parent = row

	local val = Instance.new("TextLabel")
	val.Size = UDim2.new(0, 80, 0, 20)
	val.Position = UDim2.new(1, -88, 0, 5)
	val.BackgroundTransparency = 1
	val.Font = Enum.Font.GothamBold
	val.TextSize = 13
	val.TextColor3 = ACCENT
	val.TextXAlignment = Enum.TextXAlignment.Right
	val.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -24, 0, 10)
	track.Position = UDim2.new(0, 12, 0, 30)
	track.BackgroundColor3 = Color3.fromRGB(58, 62, 74)
	track.BorderSizePixel = 0
	track.ZIndex = 1
	track.Parent = row
	corner(track, 6)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	fill.ZIndex = 2
	fill.Parent = track
	corner(fill, 6)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new(0, 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.ZIndex = 3
	knob.Parent = track
	corner(knob, 9)

	local hit = Instance.new("TextButton")
	hit.Size = UDim2.new(1, -12, 0, 44)
	hit.Position = UDim2.new(0, 6, 0, 12)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.ZIndex = 5
	hit.Parent = row

	local value = default
	local function render()
		local a = math.clamp((value - min) / (max - min), 0, 1)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		val.Text = (decimals == 0) and tostring(math.floor(value + 0.5))
			or string.format("%." .. decimals .. "f", value)
	end

	local dragging = false
	local function setFromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
		value = min + (max - min) * a
		render()
		if onChange then onChange(value) end
	end

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(input.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
			setFromX(input.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	render()
	return row
end

makeToggle(3, "跳过自己地块的蛋", CFG.MineSkip, function(v) CFG.MineSkip = v end)
makeToggle(4, "卡住自动跳",       CFG.AutoJump, function(v) CFG.AutoJump = v end)

makeSlider(5, "步速（建议 16~24）", 16, 40,  CFG.Speed,     0, function(v)
	CFG.Speed = v
	local _, _, hum = getChar()
	if hum and CFG.Running then hum.WalkSpeed = v end
end)
makeSlider(6, "索敌距离",           50, 800, CFG.MaxDist,   0, function(v) CFG.MaxDist = v end)
makeSlider(7, "偷蛋间隔下限（秒）", 0.5, 5,  CFG.ActGapMin, 1, function(v) CFG.ActGapMin = v end)
makeSlider(8, "偷蛋间隔上限（秒）", 0.5, 8,  CFG.ActGapMax, 1, function(v) CFG.ActGapMax = v end)
makeSlider(9, "同蛋冷却（秒）",     2,  30,  CFG.PerEggCD,  0, function(v) CFG.PerEggCD = v end)

local QuitBtn = Instance.new("TextButton")
QuitBtn.Size = UDim2.new(1, 0, 0, 44)
QuitBtn.BackgroundColor3 = Color3.fromRGB(80, 44, 44)
QuitBtn.Font = Enum.Font.GothamBold
QuitBtn.TextSize = 14
QuitBtn.TextColor3 = Color3.fromRGB(255, 190, 190)
QuitBtn.Text = "关闭脚本（完全卸载）"
QuitBtn.LayoutOrder = 20
QuitBtn.Parent = Scroll
corner(QuitBtn, 10)

-- 拖动（限制在屏幕内）
do
	local dragging, dragStart, startPos = false, nil, nil
	Bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = Main.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UIS.InputChanged:Connect(function(input)
		if not dragging then return end
		if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local d = input.Position - dragStart
		local cam = WS.CurrentCamera
		local screen = cam and cam.ViewportSize or vp
		local w = Main.AbsoluteSize.X
		local nx = math.clamp(startPos.X.Offset + d.X, -w / 2 + 30, screen.X + w / 2 - 30)
		local ny = math.clamp(startPos.Y.Offset + d.Y, 0, math.max(screen.Y - 60, 0))
		Main.Position = UDim2.new(startPos.X.Scale, nx, startPos.Y.Scale, ny)
	end)
end

-- ================= 控制 =================
local function shutdown()
	Running = false
	CFG.Running = false
	pcall(function()
		local _, hrp, hum = getChar()
		if hum then
			hum:MoveTo(hum.Parent.HumanoidRootPart.Position)
			hum.WalkSpeed = 16
		end
	end)
	if Gui then Gui:Destroy() end
end

Close.MouseButton1Click:Connect(shutdown)
QuitBtn.MouseButton1Click:Connect(shutdown)

MainBtn.MouseButton1Click:Connect(function()
	CFG.Running = not CFG.Running
	if CFG.Running then
		MainBtn.Text = "停止自动偷蛋"
		MainBtn.BackgroundColor3 = RED
		local _, _, hum = getChar()
		if hum then hum.WalkSpeed = CFG.Speed end   -- 只在开始时设一次，避免被服务器判速
		nextActAt = os.clock() + 1
		restTrigger = os.clock() + CFG.RestEvery
		setStatus("状态：启动中…")
	else
		MainBtn.Text = "开始自动偷蛋"
		MainBtn.BackgroundColor3 = ACCENT
		pcall(function()
			local _, hrp, hum = getChar()
			if hum and hrp then
				hum:MoveTo(hrp.Position)
				hum.WalkSpeed = 16
			end
		end)
		setStatus("状态：已停止")
	end
end)

LP.Idled:Connect(function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

setStatus("状态：已加载  |  点「开始自动偷蛋」")

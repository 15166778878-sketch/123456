--[[ ================================================================
     文件：eggstealer_ui.lua
     罗布勒斯 自动偷蛋 · 隐形反作弊 + 护蛋 · 手机UI版
     执行器：忍者 / Fluxus / Delta / Codex
     关闭：右上角红色 ✕（44×44 大按钮，一键彻底销毁）
     ================================================================ ]]

local Players      = game:GetService("Players")
local UIS          = game:GetService("UserInputService")
local Workspace    = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualUser  = game:GetService("VirtualUser")

local LP = Players.LocalPlayer
local PG = LP:FindFirstChildOfClass("PlayerGui") or LP:WaitForChild("PlayerGui")

-- ================= 配置 =================
local CFG = {
	Enabled    = false, -- 偷蛋开关
	Guard      = true,  -- 护蛋：优先抢回自己被偷的蛋
	Stealth    = true,  -- 反作弊规避：回弹检测 / 分段位移 / 抖动
	Speed      = 120,   -- 移动速度
	ScanDelay  = 0.05,  -- 扫描间隔
	MaxDist    = 600,   -- 索敌距离
	HoldTime   = 0.02,  -- 按压时长
	Cooldown   = 2.5,   -- 同一个蛋的冷却
	Jitter     = 0.25,  -- 随机抖动比例（反行为检测）
}

local KEYWORDS = {"steal","take","grab","egg","rob","claim","collect","pick"}

local Running, Stolen, Blocked, Alarms = true, 0, 0, 0
local CooldownTbl = {}
local alarmUntil  = 0
local homeCFrame  = nil

_G.EggStealerAlive = true

-- ================= 基础工具 =================
local function getRoot()
	local ch = LP.Character
	if not ch then return end
	local hrp = ch:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	return ch, hrp, ch:FindFirstChildOfClass("Humanoid")
end

local function raiseAlarm(sec)
	alarmUntil = math.max(alarmUntil, os.clock() + (sec or 5))
	Alarms = Alarms + 1
end
local function inAlarm()
	return os.clock() < alarmUntil
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
		if not cur or cur == Workspace then break end
		local o = cur:GetAttribute("Owner") or cur:GetAttribute("PlacedBy")
			or cur:GetAttribute("OwnerName") or cur:GetAttribute("OwnerId")
		if o ~= nil then return o end
		if cur.Name == LP.Name or cur.Name == LP.Name .. "'s Plot"
			or cur.Name == LP.Name .. "'s Base" then return LP.Name end
		cur = cur.Parent
	end
end

local function eggTag(inst)
	local cur = inst
	for _ = 1, 5 do
		if not cur or cur == Workspace then break end
		local t = cur:GetAttribute("OriginalOwner") or cur:GetAttribute("EggOwner")
			or cur:GetAttribute("PlacedBy") or cur:GetAttribute("ClaimedBy")
		if t ~= nil then return t end
		cur = cur.Parent
	end
end

-- ================= 反作弊规避 · 传送 =================
local function teleportTo(target)
	local ch, hrp = getRoot()
	if not hrp then return false end
	local dest = target + Vector3.new(0, 2.6, 0)
	if not homeCFrame then homeCFrame = hrp.CFrame end

	-- 保守模式：已判定被反作弊回弹 → 分段小跳，轨迹连续不像瞬移
	if CFG.Stealth and inAlarm() then
		local start = hrp.Position
		local steps = math.clamp(math.ceil((dest - start).Magnitude / 30), 1, 10)
		for i = 1, steps do
			if not hrp.Parent then return false end
			hrp.CFrame = CFrame.new(start:Lerp(dest, i / steps))
			hrp.AssemblyLinearVelocity = Vector3.zero
			task.wait(0.035)
		end
		return true
	end

	hrp.AssemblyLinearVelocity  = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	hrp.CFrame = CFrame.new(dest)

	-- 回弹检测：0.12 秒后仍被拉回去 → 判定游戏有位置校验
	if CFG.Stealth then
		task.spawn(function()
			task.wait(0.12)
			local _, h2 = getRoot()
			if h2 and (h2.Position - dest).Magnitude > 35 then
				raiseAlarm(6)
			end
		end)
	end
	return true
end

-- ================= 提示触发 =================
local FPP = (typeof(fireproximityprompt) == "function") and fireproximityprompt or nil

local function shieldPrompt(p)
	pcall(function()
		p.RequiresLineOfSight = false
		p.HoldDuration = 0
		p.MaxActivationDistance = math.huge
		p.Exclusivity = Enum.ProximityPromptExclusivity.AlwaysShow
	end)
end

local function firePrompt(p)
	if FPP and pcall(FPP, p) then return true end
	return pcall(function()
		p:InputHoldBegin()
		task.wait(math.max(CFG.HoldTime, p.HoldDuration or 0))
		p:InputHoldEnd()
	end)
end

-- ================= 蛋信息 =================
local function isEggPrompt(p)
	local txt = (p.ActionText or "") .. "|" .. (p.ObjectText or "")
	for _, kw in ipairs(KEYWORDS) do
		if hasKW(txt, kw) then return true end
	end
	local cur = p
	for _ = 1, 7 do
		if not cur or cur == Workspace then break end
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

	local onMyPlot = isMe(plotOwner(p))
	local taggedMine = isMe(eggTag(p))
	local stolenMine = (not onMyPlot) and taggedMine

	return {
		prompt = p,
		pos = part.Position,
		mine = onMyPlot,
		stolenMine = stolenMine,
	}
end

-- ================= 提示缓存（性能优化） =================
local prompts = {}
local function rebuildPrompts()
	local list = {}
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") then list[#list + 1] = d end
	end
	prompts = list
end
rebuildPrompts()
Workspace.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then table.insert(prompts, d) end
end)
task.spawn(function()
	while Running do
		task.wait(2)
		pcall(rebuildPrompts)
	end
end)

-- ================= 选蛋（护蛋优先） =================
local function bestEgg()
	local ch, hrp = getRoot()
	if not hrp then return end
	local origin = hrp.Position
	local now = os.clock()
	local best, bestPos, bestScore, bestInfo

	for i = #prompts, 1, -1 do
		local obj = prompts[i]
		if obj and obj.Parent and obj.Enabled and obj:IsA("ProximityPrompt") then
			local prev = CooldownTbl[obj]
			if not (prev and now - prev < CFG.Cooldown) then
				local info = eggInfo(obj)
				if info and not info.mine then
					if info.stolenMine and not CFG.Guard then info = nil end
					if info then
						local d = (info.pos - origin).Magnitude
						if d <= CFG.MaxDist then
							local score = (info.stolenMine and 0 or 1) * 100000 + d
							if not bestScore or score < bestScore then
								best, bestPos, bestScore, bestInfo = obj, info.pos, score, info
							end
						end
					end
				end
			end
		elseif obj and not obj.Parent then
			table.remove(prompts, i)
		end
	end
	return best, bestPos, bestInfo
end

-- ================= UI =================
local ACCENT = Color3.fromRGB(96, 176, 255)
local RED    = Color3.fromRGB(226, 74, 74)
local GREEN  = Color3.fromRGB(64, 178, 112)
local BG     = Color3.fromRGB(24, 26, 33)
local CARD   = Color3.fromRGB(36, 39, 49)
local TXT    = Color3.fromRGB(228, 234, 244)
local DIM    = Color3.fromRGB(160, 170, 188)

local function corner(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = o
	return c
end

local vp = Vector2.new(400, 800)
pcall(function() vp = Workspace.CurrentCamera.ViewportSize end)

local Gui = Instance.new("ScreenGui")
Gui.Name = "EggStealerUI"
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true
Gui.DisplayOrder = 9999
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PG

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.AnchorPoint = Vector2.new(0.5, 0)
Main.Position = UDim2.new(0.5, 0, 0, 50)
Main.Size = UDim2.new(0, math.clamp(vp.X - 36, 250, 320), 0, math.clamp(vp.Y * 0.62, 340, 520))
Main.BackgroundColor3 = BG
Main.BorderSizePixel = 0
Main.Parent = Gui
corner(Main, 14)

local stroke = Instance.new("UIStroke")
stroke.Color = ACCENT
stroke.Thickness = 1.2
stroke.Transparency = 0.5
stroke.Parent = Main

-- 标题栏
local Bar = Instance.new("Frame")
Bar.Size = UDim2.new(1, 0, 0, 48)
Bar.BackgroundTransparency = 1
Bar.Active = true
Bar.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -62, 0, 48)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.TextSize = 15
Title.TextColor3 = TXT
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Text = "🥚 自动偷蛋 · 隐身版"
Title.Parent = Bar

-- 关闭按钮（大、显眼、永远在屏幕内）
local Close = Instance.new("TextButton")
Close.Name = "CloseBtn"
Close.Size = UDim2.new(0, 44, 0, 44)
Close.Position = UDim2.new(1, -50, 0, 2)
Close.BackgroundColor3 = RED
Close.Text = "✕"
Close.Font = Enum.Font.GothamBold
Close.TextSize = 22
Close.TextColor3 = Color3.new(1, 1, 1)
Close.ZIndex = 30
Close.AutoButtonColor = true
Close.Parent = Main
corner(Close, 12)

-- 内容滚动区
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

-- 状态栏
local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 42)
Status.BackgroundColor3 = CARD
Status.Font = Enum.Font.Gotham
Status.TextSize = 12
Status.TextColor3 = DIM
Status.TextWrapped = true
Status.Text = "状态：待机"
Status.LayoutOrder = 1
Status.Parent = Scroll
corner(Status, 10)

-- 主按钮
local MainBtn = Instance.new("TextButton")
MainBtn.Size = UDim2.new(1, 0, 0, 48)
MainBtn.BackgroundColor3 = ACCENT
MainBtn.Font = Enum.Font.GothamBold
MainBtn.TextSize = 17
MainBtn.TextColor3 = Color3.new(1, 1, 1)
MainBtn.Text = "开启偷蛋"
MainBtn.LayoutOrder = 2
MainBtn.AutoButtonColor = true
MainBtn.Parent = Scroll
corner(MainBtn, 12)

-- 开关按钮
local function makeToggle(order, text, default, onChange)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 44)
	b.BackgroundColor3 = default and GREEN or CARD
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text .. "：" .. (default and "开" or "关")
	b.LayoutOrder = order
	b.AutoButtonColor = true
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

-- 滑动条（大触摸区，手机一拖就动）
local function makeSlider(order, text, min, max, default, decimals, onChange)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 50)
	row.BackgroundColor3 = CARD
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = Scroll
	corner(row, 10)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -90, 0, 20)
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

	local hit = Instance.new("TextButton")     -- 40px 厚触摸区
	hit.Size = UDim2.new(1, -12, 0, 40)
	hit.Position = UDim2.new(0, 6, 0, 14)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.ZIndex = 5
	hit.Parent = row

	local value = default
	local function render()
		local a = (value - min) / (max - min)
		a = math.clamp(a, 0, 1)
		fill.Size = UDim2.new(a, 0, 1, 0)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		val.Text = (decimals == 0)
			and tostring(math.floor(value + 0.5))
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

-- 控件
makeToggle(3, "护蛋：优先抢回自己的蛋", CFG.Guard,   function(v) CFG.Guard = v end)
makeToggle(4, "反作弊规避",             CFG.Stealth, function(v) CFG.Stealth = v end)

makeSlider(5, "移动速度",       16,  400, CFG.Speed,     0, function(v) CFG.Speed = v end)
makeSlider(6, "扫描间隔（秒）", 0.01, 0.5, CFG.ScanDelay, 2, function(v) CFG.ScanDelay = v end)
makeSlider(7, "索敌距离",       20,  2000, CFG.MaxDist,   0, function(v) CFG.MaxDist = v end)
makeSlider(8, "按压时长（秒）", 0,   0.4, CFG.HoldTime,   2, function(v) CFG.HoldTime = v end)
makeSlider(9, "同蛋冷却（秒）", 0.5, 10,  CFG.Cooldown,   1, function(v) CFG.Cooldown = v end)

-- 彻底退出按钮
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

local function setStatus(t)
	Status.Text = t
end

-- 拖动窗口（带边界限制，标题栏永远拉不丢）
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
		local cam = Workspace.CurrentCamera
		local screen = cam and cam.ViewportSize or vp
		local w, h = Main.AbsoluteSize.X, Main.AbsoluteSize.Y
		local nx = math.clamp(startPos.X.Offset + d.X, -w / 2 + 30, screen.X + w / 2 - 30)
		local ny = math.clamp(startPos.Y.Offset + d.Y, 0, math.max(screen.Y - 60, 0))
		Main.Position = UDim2.new(startPos.X.Scale, nx, startPos.Y.Scale, ny)
	end)
end

-- ================= 逻辑 =================
local function shutdown()
	Running = false
	CFG.Enabled = false
	_G.EggStealerAlive = false
	pcall(function()
		local ch, hrp = getRoot()
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = 16 end
	end)
	if Gui then Gui:Destroy() end
end

Close.MouseButton1Click:Connect(shutdown)
QuitBtn.MouseButton1Click:Connect(shutdown)

MainBtn.MouseButton1Click:Connect(function()
	CFG.Enabled = not CFG.Enabled
	if CFG.Enabled then
		MainBtn.Text = "停止偷蛋"
		MainBtn.BackgroundColor3 = RED
		local ch, hrp = getRoot()
		if hrp then homeCFrame = hrp.CFrame end
	else
		MainBtn.Text = "开启偷蛋"
		MainBtn.BackgroundColor3 = ACCENT
		local ch = LP.Character
		local hum = ch and ch:FindFirstChildOfClass("Humanoid")
		if hum then hum.WalkSpeed = 16 end
	end
end)

-- 反 AFK（防止 20 分钟挂机踢出）
LP.Idled:Connect(function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

-- 反作弊对抗：速度被重置 / 角色被冻结 / 被锚定 → 立刻恢复
task.spawn(function()
	while Running do
		pcall(function()
			local ch, hrp, hum = getRoot()
			if hum and hrp then
				if CFG.Enabled then
					if hum.WalkSpeed < CFG.Speed * 0.9 then hum.WalkSpeed = CFG.Speed end
					if hum.PlatformStand then hum.PlatformStand = false end
					if hrp.Anchored then hrp.Anchored = false end
				end
			end
		end)
		task.wait(0.4)
	end
end)

-- 主循环
task.spawn(function()
	while Running do
		if CFG.Enabled then
			local ok, err = pcall(function()
				local ch, hrp, hum = getRoot()
				if not hrp then
					setStatus("状态：等待角色加载…")
					return
				end
				if hum then hum.WalkSpeed = CFG.Speed end

				local p, pos, info = bestEgg()
				if p and pos then
					shieldPrompt(p)
					teleportTo(pos)
					task.wait(0.02)
					if firePrompt(p) then
						Stolen = Stolen + 1
						CooldownTbl[p] = os.clock()
					else
						Blocked = Blocked + 1
					end
					local tagTxt = (info and info.stolenMine) and "抢回自己的蛋" or "抢夺中"
					setStatus(string.format(
						"状态：%s  |  已偷 %d  |  失败 %d  |  回弹警报 %d",
						tagTxt, Stolen, Blocked, Alarms))
				else
					setStatus(string.format(
						"状态：搜索中…  |  已偷 %d  |  失败 %d  |  回弹警报 %d",
						Stolen, Blocked, Alarms))
				end
			end)
			if not ok then
				setStatus("状态：运行异常，已自动恢复")
			end
			local j = 1 + (math.random() * 2 - 1) * CFG.Jitter
			task.wait(math.max(0.01, CFG.ScanDelay * j))
		else
			setStatus(string.format("状态：待机  |  已偷 %d  |  失败 %d  |  回弹警报 %d",
				Stolen, Blocked, Alarms))
			task.wait(0.2)
		end
	end
end)

-- 脚本自保护：UI 被别的脚本删掉会自动恢复
Gui.AncestryChanged:Connect(function()
	if Running and not Gui.Parent then
		task.wait(0.2)
		if Running and not Gui.Parent then
			pcall(function() Gui.Parent = PG end)
		end
	end
end)

setStatus("状态：已加载  |  点「开启偷蛋」开始")

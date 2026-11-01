--[[
	PetUI - Thư viện UI panel cho Pet Hub (Dạng Loadstring / GitHub)
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local PetUI = {}
PetUI.Version = "1.0"
PetUI.Options = {}

local Window = {}
Window.__index = Window
local Tab = {}
Tab.__index = Tab

---------------------------------------------------------------------
-- Màu sắc
---------------------------------------------------------------------

local C = {
	ink = Color3.fromRGB(245, 247, 255),
	mute = Color3.fromRGB(180, 187, 224),
	mint = Color3.fromRGB(61, 242, 176),
	violet = Color3.fromRGB(155, 140, 255),
	amber = Color3.fromRGB(255, 196, 92),
	rose = Color3.fromRGB(255, 122, 147),
	blue = Color3.fromRGB(108, 182, 255),
	card = Color3.fromRGB(27, 32, 64),
	cardOn = Color3.fromRGB(28, 52, 70),
	panel = Color3.fromRGB(16, 19, 42),
	line = Color3.fromRGB(70, 77, 125),
	off = Color3.fromRGB(57, 64, 122),
	dark = Color3.fromRGB(10, 22, 30),
	white = Color3.new(1, 1, 1),
}
PetUI.Colors = C

---------------------------------------------------------------------
-- Hàm phụ
---------------------------------------------------------------------

local function create(class, props)
	local inst = Instance.new(class)
	local parent = props.Parent
	for k, v in pairs(props) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(inst, radius)
	return create("UICorner", {
		CornerRadius = UDim.new(0, radius),
		Parent = inst,
	})
end

local function stroke(inst, color, thickness, transparency)
	return create("UIStroke", {
		Color = color,
		Thickness = thickness or 1.5,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = inst,
	})
end

local function tween(inst, time, props, style, direction)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quint, direction or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function label(parent, props)
	local p = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = C.ink,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = parent,
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return create("TextLabel", p)
end

local function isAsset(v)
	if type(v) == "number" then
		return true
	end
	if type(v) == "string" then
		return tonumber(v) ~= nil or v:find("rbxasset") ~= nil or v:find("http") ~= nil
	end
	return false
end

-- Icon: emoji / chữ (vd "🥚") hoặc ID ảnh (vd "73866843639743")
local function makeIcon(parent, icon, textSize)
	if isAsset(icon) then
		local id = tonumber(icon) and ("rbxassetid://" .. icon) or icon
		return create("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			Image = id,
			ScaleType = Enum.ScaleType.Crop,
			Parent = parent,
		})
	end
	return label(parent, {
		Size = UDim2.fromScale(1, 1),
		Text = tostring(icon or ""),
		TextSize = textSize or 20,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
end

-- 18400 -> "18.4K"
function PetUI.Format(n)
	n = tonumber(n) or 0
	for _, u in ipairs({ { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }) do
		if n >= u[1] then
			local v = n / u[1]
			v = v >= 100 and math.floor(v + 0.5) or math.floor(v * 100 + 0.5) / 100
			return tostring(v) .. u[2]
		end
	end
	return tostring(math.floor(n))
end

-- Cho phép AddToggle("Id", {...}) hoặc AddToggle({...})
local function args(id, opts)
	if type(id) == "table" then
		return nil, id
	end
	return id, opts or {}
end

---------------------------------------------------------------------
-- Cửa sổ
---------------------------------------------------------------------

local PW, PH = 440, 490

function PetUI:CreateWindow(config)
	config = config or {}

	local self = setmetatable({}, Window)
	self.Tabs = {}
	self.Elements = {}
	self.IsOpen = false
	self.ActiveTab = nil
	self.ToggleKey = config.ToggleKey or Enum.KeyCode.RightControl
	self.Accent = config.Accent or C.mint
	self.OpenColor = config.FloatingOpenColor or C.violet

	-- Parent: gethui -> CoreGui -> PlayerGui
	local parent = config.Parent
		or (gethui and gethui())
		or (pcall(function() return CoreGui.RobloxGui end) and CoreGui)
		or LocalPlayer:WaitForChild("PlayerGui")

	for _, p in ipairs({ parent, LocalPlayer:WaitForChild("PlayerGui") }) do
		local old = p:FindFirstChild("PetHub")
		if old then
			old:Destroy()
		end
	end

	local gui = create("ScreenGui", {
		Name = "PetHub",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 999,
	})
	if syn and syn.protect_gui then
		pcall(syn.protect_gui, gui)
	end
	gui.Parent = parent
	self.Gui = gui

	-----------------------------------------------------------------
	-- Khung chính
	-----------------------------------------------------------------

	local panel = create("CanvasGroup", {
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(PW, PH),
		BackgroundColor3 = C.panel,
		GroupTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	corner(panel, 24)
	stroke(panel, C.white, 1.5, 0.85)
	self.Panel = panel
	self.PScale = create("UIScale", { Scale = 0.3, Parent = panel })

	local topBar = create("Frame", {
		Size = UDim2.new(1, 0, 0, 4),
		BorderSizePixel = 0,
		BackgroundColor3 = C.white,
		ZIndex = 5,
		Parent = panel,
	})
	create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.mint),
			ColorSequenceKeypoint.new(0.5, C.violet),
			ColorSequenceKeypoint.new(1, C.amber),
		}),
		Parent = topBar,
	})

	-----------------------------------------------------------------
	-- Tiêu đề
	-----------------------------------------------------------------

	local logo = create("Frame", {
		Position = UDim2.fromOffset(16, 18),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = C.violet,
		Parent = panel,
	})
	corner(logo, 13)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(155, 140, 255), Color3.fromRGB(91, 140, 255)),
		Rotation = 45,
		Parent = logo,
	})
	makeIcon(logo, config.Logo or "🥚", 22)

	label(panel, {
		Position = UDim2.fromOffset(66, 16),
		Size = UDim2.fromOffset(190, 26),
		Text = config.Title or "PET HUB",
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	label(panel, {
		Position = UDim2.fromOffset(66, 42),
		Size = UDim2.fromOffset(190, 16),
		Text = config.SubTitle or "",
		TextSize = 12,
		TextColor3 = C.mute,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	-- Pill "N ON"
	self._pill = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -62, 0, 22),
		Size = UDim2.fromOffset(74, 30),
		BackgroundColor3 = C.mute,
		BackgroundTransparency = 0.88,
		Parent = panel,
	})
	corner(self._pill, 15)
	self._pillStroke = stroke(self._pill, C.mute, 1.5, 0.6)
	self._pillLbl = label(self._pill, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBlack,
		TextSize = 12,
		TextColor3 = C.mute,
	})

	-- Nút đóng
	local closeBtn = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 20),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0.9,
		Text = "✕",
		TextSize = 15,
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.ink,
		AutoButtonColor = false,
		Parent = panel,
	})
	corner(closeBtn, 17)
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, 0.2, { BackgroundColor3 = C.rose, BackgroundTransparency = 0, TextColor3 = C.dark })
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, 0.2, { BackgroundColor3 = C.white, BackgroundTransparency = 0.9, TextColor3 = C.ink })
	end)
	closeBtn.MouseButton1Click:Connect(function()
		self:Close()
	end)

	-----------------------------------------------------------------
	-- Thân trang + thanh tab dưới
	-----------------------------------------------------------------

	self._body = create("Frame", {
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, PH - 70 - 82),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = panel,
	})

	local tabBar = create("Frame", {
		Position = UDim2.new(0, 12, 1, -70),
		Size = UDim2.new(1, -24, 0, 58),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0.94,
		Parent = panel,
	})
	corner(tabBar, 20)
	stroke(tabBar, C.white, 1.5, 0.9)

	self._inner = create("Frame", {
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		BackgroundTransparency = 1,
		Parent = tabBar,
	})
	self._ind = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.violet,
		BackgroundTransparency = 0.6,
		Visible = false,
		Parent = self._inner,
	})
	corner(self._ind, 14)
	stroke(self._ind, C.white, 1.5, 0.75)

	-----------------------------------------------------------------
	-- Thông báo (toast) giữa dưới màn hình
	-----------------------------------------------------------------

	local toast = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(10, 40),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.mint,
		BackgroundTransparency = 1,
		ZIndex = 50,
		Visible = false,
		Parent = gui,
	})
	corner(toast, 20)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 18),
		PaddingRight = UDim.new(0, 18),
		Parent = toast,
	})
	self._toast = toast
	self._toastLbl = label(toast, {
		Size = UDim2.new(0, 10, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
		TextColor3 = C.dark,
		TextTransparency = 1,
		ZIndex = 51,
	})
	self._toastId = 0

	-----------------------------------------------------------------
	-- Nút nổi + phím tắt
	-----------------------------------------------------------------

	if config.FloatingButton ~= false then
		self:_buildFloating(config)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == self.ToggleKey then
			self:Toggle()
		end
	end)

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self.IsOpen then
			self.PScale.Scale = self:_fitScale()
		end
	end)

	self:_updatePill()
	if config.StartOpen ~= false then
		task.defer(function()
			self:Open()
		end)
	end
	return self
end

---------------------------------------------------------------------
-- Nút nổi (floating)
---------------------------------------------------------------------

function Window:_buildFloating(config)
	local size = config.FloatingSize or 60

	local holder = create("Frame", {
		Name = "Floating",
		Position = config.FloatingPosition or UDim2.new(0, 36, 0.5, -size / 2),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = self.Gui,
	})
	self._holder = holder

	-- Vòng sóng nhấp nháy
	if config.FloatingPulse ~= false then
		self._ring = create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Parent = holder,
		})
		corner(self._ring, size)
		local ringStroke = stroke(self._ring, self.Accent, 2, 0.2)
		local info = TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1)
		TweenService:Create(self._ring, info, { Size = UDim2.fromScale(1.6, 1.6) }):Play()
		TweenService:Create(ringStroke, info, { Transparency = 1 }):Play()
	end

	local fab = create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = self.Accent,
		Text = "",
		AutoButtonColor = false,
		Parent = holder,
	})
	corner(fab, size)
	stroke(fab, C.white, 2, 0.7)
	self._fab = fab
	self._fabScale = create("UIScale", { Scale = 1, Parent = fab })

	local iconA = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = fab,
	})
	local iconImg = makeIcon(iconA, config.FloatingIcon or "🥚", math.floor(size * 0.5))
	if iconImg:IsA("ImageLabel") then
		corner(iconImg, size)
	else
		iconImg.TextColor3 = C.dark
	end
	self._fabIconA = iconA
	self._fabIconB = label(fab, {
		Size = UDim2.fromScale(1, 1),
		Text = "✕",
		Font = Enum.Font.GothamBlack,
		TextSize = math.floor(size * 0.42),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.white,
		Visible = false,
	})

	-- Lơ lửng lên xuống
	if config.FloatingBobbing ~= false then
		TweenService:Create(
			fab,
			TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = UDim2.fromOffset(0, -7) }
		):Play()
	end

	-- Kéo thả / bấm để mở
	local dragging, moved, dragStart, startPos = false, false, nil, nil

	fab.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, moved = true, false
			dragStart, startPos = input.Position, holder.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					if not moved then
						self:Toggle()
					end
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			if delta.Magnitude > 6 then
				moved = true
			end
			if moved then
				holder.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + delta.X,
					startPos.Y.Scale, startPos.Y.Offset + delta.Y
				)
			end
		end
	end)

	fab.MouseEnter:Connect(function()
		tween(self._fabScale, 0.25, { Scale = 1.12 }, Enum.EasingStyle.Back)
	end)
	fab.MouseLeave:Connect(function()
		tween(self._fabScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
end

---------------------------------------------------------------------
-- Mở / đóng
---------------------------------------------------------------------

function Window:_fitScale()
	local v = self.Gui.AbsoluteSize
	if v.X < 1 then
		v = Vector2.new(1280, 720)
	end
	return math.clamp(math.min((v.X - 30) / PW, (v.Y - 30) / PH), 0.5, 1)
end

-- Vị trí nút nổi (panel bung ra / thu về đây)
function Window:_origin()
	if self._holder then
		return self._holder.AbsolutePosition + self._holder.AbsoluteSize / 2
	end
	return self.Gui.AbsoluteSize / 2
end

function Window:Open()
	if self.IsOpen then
		return
	end
	self.IsOpen = true

	local c = self:_origin()
	local p = self.Panel
	p.Position = UDim2.fromOffset(c.X, c.Y)
	self.PScale.Scale = 0.25
	p.GroupTransparency = 1
	p.Visible = true

	tween(p, 0.55, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Back)
	tween(p, 0.25, { GroupTransparency = 0 }, Enum.EasingStyle.Quad)
	tween(self.PScale, 0.55, { Scale = self:_fitScale() }, Enum.EasingStyle.Back)
	self:_fabState(true)

	if self.ActiveTab and self.ActiveTab.OnShow then
		task.spawn(self.ActiveTab.OnShow)
	end
end

function Window:Close()
	if not self.IsOpen then
		return
	end
	self.IsOpen = false

	local c = self:_origin()
	local p = self.Panel
	tween(p, 0.3, { Position = UDim2.fromOffset(c.X, c.Y) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	tween(p, 0.25, { GroupTransparency = 1 }, Enum.EasingStyle.Quad)
	tween(self.PScale, 0.3, { Scale = 0.25 }, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	task.delay(0.32, function()
		if not self.IsOpen then
			p.Visible = false
		end
	end)
	self:_fabState(false)
end

function Window:Toggle()
	if self.IsOpen then
		self:Close()
	else
		self:Open()
	end
end

function Window:_fabState(open)
	if not self._fab then
		return
	end
	if self._ring then
		self._ring.Visible = not open
	end
	self._fabIconA.Visible = not open
	self._fabIconB.Visible = open
	self._fab.Rotation = open and -90 or 90
	tween(self._fab, 0.5, {
		Rotation = 0,
		BackgroundColor3 = open and self.OpenColor or self.Accent,
	}, Enum.EasingStyle.Back)
end

function Window:SetToggleKey(key)
	self.ToggleKey = key
end

function Window:Destroy()
	self.Gui:Destroy()
end

---------------------------------------------------------------------
-- Thông báo
-- Window:Notify({ Title = "...", Content = "...", Duration = 2 })
---------------------------------------------------------------------

function Window:Notify(opts)
	if type(opts) == "string" then
		opts = { Content = opts }
	end
	opts = opts or {}

	local msg
	if opts.Title and opts.Content then
		msg = opts.Title .. " · " .. opts.Content
	else
		msg = tostring(opts.Title or opts.Content or "")
	end

	self._toastId += 1
	local id = self._toastId
	local t, l = self._toast, self._toastLbl

	l.Text = msg
	t.Visible = true
	t.Position = UDim2.new(0.5, 0, 1, 20)
	tween(t, 0.4, { Position = UDim2.new(0.5, 0, 1, -24), BackgroundTransparency = 0 }, Enum.EasingStyle.Back)
	tween(l, 0.25, { TextTransparency = 0 })

	task.delay(opts.Duration or 2, function()
		if id ~= self._toastId then
			return
		end
		tween(t, 0.3, { Position = UDim2.new(0.5, 0, 1, 10), BackgroundTransparency = 1 })
		tween(l, 0.25, { TextTransparency = 1 })
		task.delay(0.35, function()
			if id == self._toastId then
				t.Visible = false
			end
		end)
	end)
end

---------------------------------------------------------------------
-- Pill "N ON"
---------------------------------------------------------------------

function Window:_updatePill()
	local n = 0
	for _, e in ipairs(self.Elements) do
		if e.Type == "Toggle" and e.Value then
			n += 1
		end
	end

	local live = n > 0
	self._pillLbl.Text = n .. " ON"
	tween(self._pillLbl, 0.25, { TextColor3 = live and C.mint or C.mute })
	tween(self._pill, 0.25, {
		BackgroundColor3 = live and C.mint or C.mute,
		BackgroundTransparency = live and 0.85 or 0.88,
	})
	tween(self._pillStroke, 0.25, {
		Color = live and C.mint or C.mute,
		Transparency = live and 0.2 or 0.6,
	})
end

---------------------------------------------------------------------
-- Tab
-- Window:AddTab({ Title = "Auto", Icon = "73866843639743" })
---------------------------------------------------------------------

function Window:AddTab(opts)
	opts = opts or {}

	local tab = setmetatable({
		Window = self,
		Name = opts.Title or "Tab",
		Order = 0,
	}, Tab)

	local btn = create("TextButton", {
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		ZIndex = 3,
		Parent = self._inner,
	})
	local ic = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 3),
		Size = UDim2.fromOffset(22, 22),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = btn,
	})
	makeIcon(ic, opts.Icon or "•", 17)

	tab.Label = label(btn, {
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 16),
		Text = tab.Name,
		TextSize = 11.5,
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.mute,
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
	})
	tab.Btn = btn

	tab.Group = create("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = self._body,
	})
	tab.Scroll = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = tab.Group,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = tab.Scroll,
	})
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 16),
		PaddingRight = UDim.new(0, 16),
		PaddingTop = UDim.new(0, 4),
		PaddingBottom = UDim.new(0, 8),
		Parent = tab.Scroll,
	})

	table.insert(self.Tabs, tab)
	tab.Index = #self.Tabs
	local n = #self.Tabs

	-- Chia đều chiều rộng thanh tab
	for i, t in ipairs(self.Tabs) do
		t.Btn.Position = UDim2.fromScale((i - 1) / n, 0)
		t.Btn.Size = UDim2.fromScale(1 / n, 1)
	end
	self._ind.Size = UDim2.fromScale(1 / n, 1)
	if self.ActiveTab then
		self._ind.Position = UDim2.fromScale((self.ActiveTab.Index - 1) / n, 0)
	end

	btn.MouseButton1Click:Connect(function()
		self:SelectTab(tab)
	end)
	if n == 1 then
		self:SelectTab(tab, true)
	end
	return tab
end

function Window:SelectTab(target, instant)
	local tab = type(target) == "number" and self.Tabs[target] or target
	if not tab or self.ActiveTab == tab then
		return
	end
	self.ActiveTab = tab

	local n = #self.Tabs
	self._ind.Visible = true
	if instant then
		self._ind.Position = UDim2.fromScale((tab.Index - 1) / n, 0)
	else
		tween(self._ind, 0.5, { Position = UDim2.fromScale((tab.Index - 1) / n, 0) }, Enum.EasingStyle.Back)
	end

	for _, t in ipairs(self.Tabs) do
		tween(t.Label, 0.2, { TextColor3 = t == tab and C.white or C.mute })
		if t == tab then
			t.Group.Position = UDim2.fromOffset(0, instant and 0 or 16)
			t.Group.GroupTransparency = instant and 0 or 1
			t.Group.Visible = true
			if not instant then
				tween(t.Group, 0.4, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Back)
				tween(t.Group, 0.3, { GroupTransparency = 0 })
			end
		else
			t.Group.Visible = false
		end
	end

	if tab.OnShow then
		task.spawn(tab.OnShow)
	end
end

---------------------------------------------------------------------
-- Thành phần chung
---------------------------------------------------------------------

-- Hàng chung: icon + tiêu đề + mô tả, chừa chỗ bên phải cho nút / công tắc
local function newRow(tab, opts, ctrlW)
	tab.Order += 1

	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = C.card,
		BorderSizePixel = 0,
		LayoutOrder = tab.Order,
		Parent = tab.Scroll,
	})
	corner(row, 16)
	local rowStroke = stroke(row, C.line, 1.5, 0.5)

	local x = 14
	if opts.Icon then
		local ico = create("Frame", {
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.fromOffset(46, 46),
			BackgroundColor3 = opts.Color or C.mint,
			BackgroundTransparency = 0.82,
			Parent = row,
		})
		corner(ico, 15)
		makeIcon(ico, opts.Icon, 22)
		x = 70
	end

	local w = -(x + ctrlW + 26)
	label(row, {
		Name = "Title",
		Position = UDim2.fromOffset(x, 11),
		Size = UDim2.new(1, w, 0, 22),
		Text = opts.Title or "",
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	label(row, {
		Name = "Description",
		Position = UDim2.fromOffset(x, 33),
		Size = UDim2.new(1, w, 0, 30),
		Text = opts.Description or "",
		TextSize = 11.5,
		TextColor3 = C.mute,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	return row, rowStroke
end

local function makeElement(win, id, kind, row)
	local el = { Id = id, Type = kind, Row = row, Value = nil, _listeners = {} }

	function el:OnChanged(fn)
		table.insert(self._listeners, fn)
	end
	function el:SetTitle(text)
		local l = row:FindFirstChild("Title")
		if l then
			l.Text = text
		end
	end
	function el:SetDesc(text)
		local l = row:FindFirstChild("Description")
		if l then
			l.Text = text
		end
	end
	function el:Destroy()
		row:Destroy()
		if id then
			PetUI.Options[id] = nil
		end
	end

	if id then
		PetUI.Options[id] = el
	end
	table.insert(win.Elements, el)
	return el
end

function Tab:AddSection(text)
	self.Order += 1
	return label(self.Scroll, {
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = self.Order,
		Text = tostring(text),
		Font = Enum.Font.GothamBlack,
		TextSize = 12,
		TextColor3 = self.Window.Accent,
	})
end

function Tab:AddParagraph(opts)
	self.Order += 1

	local card = create("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.card,
		LayoutOrder = self.Order,
		Parent = self.Scroll,
	})
	corner(card, 16)
	stroke(card, C.line, 1.5, 0.5)
	create("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 14),
		PaddingRight = UDim.new(0, 14),
		Parent = card,
	})
	create("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = card,
	})

	label(card, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = opts.Title or "",
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextWrapped = true,
		LayoutOrder = 1,
	})
	label(card, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = opts.Content or "",
		TextSize = 12,
		TextColor3 = C.mute,
		TextWrapped = true,
		LayoutOrder = 2,
	})
end

---------------------------------------------------------------------
-- Toggle
-- Tab:AddToggle("Id", { Title, Description, Icon, Color, Default, Callback })
---------------------------------------------------------------------

function Tab:AddToggle(id, opts)
	id, opts = args(id, opts)
	local win = self.Window
	local row, rowStroke = newRow(self, opts, 54)

	local track = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(54, 30),
		BackgroundColor3 = C.off,
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	})
	corner(track, 15)

	local thumb = create("Frame", {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = C.white,
		Parent = track,
	})
	corner(thumb, 12)

	local el = makeElement(win, id, "Toggle", row)
	el.Value = false

	function el:SetValue(v, silent)
		v = v and true or false
		self.Value = v

		tween(track, 0.25, { BackgroundColor3 = v and C.mint or C.off })
		tween(thumb, 0.35, { Position = v and UDim2.fromOffset(27, 3) or UDim2.fromOffset(3, 3) }, Enum.EasingStyle.Back)
		tween(rowStroke, 0.25, { Color = v and C.mint or C.line, Transparency = v and 0.1 or 0.5 })
		tween(row, 0.25, { BackgroundColor3 = v and C.cardOn or C.card })
		win:_updatePill()

		if silent then
			return
		end
		for _, fn in ipairs(self._listeners) do
			task.spawn(fn, v)
		end
		if opts.Callback then
			task.spawn(opts.Callback, v)
		end
	end

	track.MouseButton1Click:Connect(function()
		el:SetValue(not el.Value)
	end)

	if opts.Default == true then
		el:SetValue(true)
	end
	return el
end

---------------------------------------------------------------------
-- Button
-- Tab:AddButton({ Title, Description, Icon, Color, ButtonText, Callback })
---------------------------------------------------------------------

function Tab:AddButton(opts)
	local row = newRow(self, opts, 92)

	local btn = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(92, 40),
		BackgroundColor3 = opts.Color or C.mint,
		Font = Enum.Font.GothamBlack,
		TextSize = 13,
		TextColor3 = C.dark,
		AutoButtonColor = false,
		Text = opts.ButtonText or "OK",
		Parent = row,
	})
	corner(btn, 13)

	btn.MouseEnter:Connect(function()
		tween(btn, 0.15, { Size = UDim2.fromOffset(96, 42) })
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, 0.15, { Size = UDim2.fromOffset(92, 40) })
	end)
	btn.MouseButton1Down:Connect(function()
		tween(btn, 0.08, { Size = UDim2.fromOffset(86, 36) })
	end)
	btn.MouseButton1Click:Connect(function()
		tween(btn, 0.25, { Size = UDim2.fromOffset(92, 40) }, Enum.EasingStyle.Back)
		if opts.Callback then
			task.spawn(opts.Callback)
		end
	end)

	return makeElement(self.Window, opts.Id, "Button", row)
end

---------------------------------------------------------------------
-- Thành phần cho tab Info
---------------------------------------------------------------------

local function makeCard(tab, height, gradient)
	tab.Order += 1
	local f = create("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = gradient and C.white or C.card,
		LayoutOrder = tab.Order,
		Parent = tab.Scroll,
	})
	corner(f, 16)
	stroke(f, C.line, 1.5, 0.5)
	return f
end

-- Thẻ người chơi: ảnh đại diện + tên + huy hiệu bên phải
-- obj:SetBadge("Rebirths 5")
function Tab:AddPlayerCard(opts)
	opts = opts or {}
	local pc = makeCard(self, 64, true)
	create("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(70, 60, 140), Color3.fromRGB(28, 70, 80)),
		Rotation = 20,
		Parent = pc,
	})

	local avatar = create("ImageLabel", {
		Position = UDim2.fromOffset(12, 9),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = C.amber,
		Image = "",
		Parent = pc,
	})
	corner(avatar, 23)
	task.spawn(function()
		local ok, img = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and img then
			avatar.Image = img
		end
	end)

	label(pc, {
		Position = UDim2.fromOffset(68, 12),
		Size = UDim2.fromOffset(160, 14),
		Text = opts.Caption or "Player",
		TextSize = 11,
		TextColor3 = C.mute,
	})
	label(pc, {
		Position = UDim2.fromOffset(68, 28),
		Size = UDim2.fromOffset(170, 24),
		Text = opts.Name or LocalPlayer.DisplayName,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	local badge = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(120, 30),
		BackgroundColor3 = C.amber,
		BackgroundTransparency = 0.84,
		Parent = pc,
	})
	corner(badge, 15)
	stroke(badge, C.amber, 1.5, 0.4)
	local badgeLbl = label(badge, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBlack,
		TextSize = 12.5,
		TextColor3 = C.amber,
	})

	local obj = {}
	function obj:SetBadge(text)
		badgeLbl.Text = text
	end
	return obj
end

-- Hàng ô số liệu
-- Tab:AddStats({ { Id = "Cash", Title = "Cash", Color = C.amber }, ... })
-- obj:Set("Cash", "18.4K")
function Tab:AddStats(defs)
	self.Order += 1

	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundTransparency = 1,
		LayoutOrder = self.Order,
		Parent = self.Scroll,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 10),
		Parent = row,
	})

	local values = {}
	for _, d in ipairs(defs) do
		local f = create("Frame", {
			Size = UDim2.new(1 / #defs, -(10 * (#defs - 1) / #defs), 1, 0),
			BackgroundColor3 = C.card,
			Parent = row,
		})
		corner(f, 14)
		stroke(f, C.line, 1.5, 0.5)

		label(f, {
			Position = UDim2.fromOffset(12, 8),
			Size = UDim2.new(1, -16, 0, 14),
			Text = d.Title,
			TextSize = 11,
			TextColor3 = C.mute,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		values[d.Id] = label(f, {
			Position = UDim2.fromOffset(12, 24),
			Size = UDim2.new(1, -16, 0, 26),
			Text = "—",
			Font = Enum.Font.GothamBlack,
			TextSize = 20,
			TextColor3 = d.Color or C.ink,
		})
	end

	local obj = {}
	function obj:Set(id, text)
		if values[id] then
			values[id].Text = tostring(text)
		end
	end
	return obj
end

-- Thẻ mục tiêu (rebirth): tên mục tiêu + vật phẩm cần + thanh tiến độ + trạng thái
-- Tab:AddGoalCard({ Title = "Next Rebirth", Icon = "", ItemLabel = "Required Egg", CostLabel = "Cost" })
-- obj:Update({ Name, Item, ItemOk, ItemOkText, ItemBadText, CostText, Ratio, Ready, Message })
function Tab:AddGoalCard(opts)
	local rc = makeCard(self, 184)

	label(rc, {
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(0.5, 0, 0, 18),
		Text = opts.Title or "",
		TextSize = 11,
		TextColor3 = C.mute,
	})
	local nameLbl = label(rc, {
		Position = UDim2.new(0.4, 0, 0, 8),
		Size = UDim2.new(0.6, -14, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextColor3 = C.amber,
	})

	local ico = create("Frame", {
		Position = UDim2.fromOffset(14, 40),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = C.amber,
		BackgroundTransparency = 0.84,
		Parent = rc,
	})
	corner(ico, 12)
	makeIcon(ico, opts.Icon or "🥚", 18)

	label(rc, {
		Position = UDim2.fromOffset(60, 40),
		Size = UDim2.fromOffset(170, 14),
		Text = opts.ItemLabel or "",
		TextSize = 10.5,
		TextColor3 = C.mute,
	})
	local itemLbl = label(rc, {
		Position = UDim2.fromOffset(60, 54),
		Size = UDim2.fromOffset(170, 22),
		Font = Enum.Font.GothamBlack,
		TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	-- Chip trạng thái vật phẩm
	local chip = create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 46),
		Size = UDim2.fromOffset(110, 26),
		BackgroundColor3 = C.rose,
		BackgroundTransparency = 0.85,
		Parent = rc,
	})
	corner(chip, 13)
	local chipStroke = stroke(chip, C.rose, 1.5, 0.4)
	local chipLbl = label(chip, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBlack,
		TextSize = 12,
		TextColor3 = C.rose,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})

	-- Chi phí + thanh tiến độ
	label(rc, {
		Position = UDim2.fromOffset(14, 88),
		Size = UDim2.fromOffset(120, 14),
		Text = opts.CostLabel or "Cost",
		TextSize = 10.5,
		TextColor3 = C.mute,
	})
	local costLbl = label(rc, {
		Position = UDim2.new(0.3, 0, 0, 86),
		Size = UDim2.new(0.7, -14, 0, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = Enum.Font.GothamBlack,
		TextSize = 12.5,
	})

	local bar = create("Frame", {
		Position = UDim2.fromOffset(14, 108),
		Size = UDim2.new(1, -28, 0, 12),
		BackgroundColor3 = Color3.fromRGB(42, 48, 102),
		Parent = rc,
	})
	corner(bar, 6)
	local fill = create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = C.white,
		Parent = bar,
	})
	corner(fill, 6)
	create("UIGradient", {
		Color = ColorSequence.new(C.amber, C.mint),
		Parent = fill,
	})

	-- Ô trạng thái
	local status = create("Frame", {
		Position = UDim2.fromOffset(14, 136),
		Size = UDim2.new(1, -28, 0, 34),
		BackgroundColor3 = C.rose,
		BackgroundTransparency = 0.86,
		Parent = rc,
	})
	corner(status, 12)
	local statusLbl = label(status, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Enum.Font.GothamBlack,
		TextSize = 12.5,
		TextColor3 = C.rose,
		TextWrapped = true,
	})

	local obj = {}
	function obj:Update(d)
		nameLbl.Text = d.Name or "—"
		itemLbl.Text = d.Item or "—"
		costLbl.Text = d.CostText or ""
		chipLbl.Text = d.ItemOk and (d.ItemOkText or "OK") or (d.ItemBadText or "—")

		local chipColor = d.ItemOk and C.mint or C.rose
		tween(chipLbl, 0.25, { TextColor3 = chipColor })
		tween(chip, 0.25, { BackgroundColor3 = chipColor })
		tween(chipStroke, 0.25, { Color = chipColor })
		tween(fill, 0.6, { Size = UDim2.fromScale(math.clamp(d.Ratio or 0, 0, 1), 1) })

		statusLbl.Text = d.Message or ""
		if d.Ready then
			tween(status, 0.25, { BackgroundColor3 = C.mint, BackgroundTransparency = 0 })
			tween(statusLbl, 0.25, { TextColor3 = C.dark })
		else
			tween(status, 0.25, { BackgroundColor3 = C.rose, BackgroundTransparency = 0.86 })
			tween(statusLbl, 0.25, { TextColor3 = C.rose })
		end
	end
	return obj
end

-- BẮT BUỘC CÓ DÒNG NÀY ĐỂ LOADSTRING TRẢ VỀ THƯ VIỆN
return PetUI

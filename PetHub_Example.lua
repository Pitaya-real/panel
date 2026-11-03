-- =================================================================
-- PET HUB - SCRIPT CHỨC NĂNG (DẠNG LOADSTRING GITHUB)
-- Dán link raw của file PetUI.lua vào rawUrl bên dưới
-- Icon: để "" là trống, điền ID ảnh vào sau (vd "73866843639743")
-- =================================================================

-- 1. Tải và nạp Library từ GitHub
local rawUrl = "DÁN_LINK_RAW_VÀO_ĐÂY"
local PetUI = loadstring(game:HttpGet(rawUrl))()

-- Dịch vụ
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Colors = PetUI.Colors

-- 2. Tạo cửa sổ menu chính
local Window = PetUI:CreateWindow({
	Title = "PET HUB",
	SubTitle = "Rebirth Helper",

	Logo = "",
	FloatingIcon = "",

	FloatingSize = 90,
	FloatingPosition = UDim2.new(0, 36, 0.5, -45),
	FloatingPulse = true,
	FloatingBobbing = true,

	Accent = Color3.fromRGB(61, 242, 176),
	ToggleKey = Enum.KeyCode.RightControl,
	StartOpen = true,
})

-- 3. Tạo các Tab
local Tabs = {
	Auto = Window:AddTab({ Title = "Auto", Icon = "" }),
	Shop = Window:AddTab({ Title = "Shop", Icon = "" }),
	Info = Window:AddTab({ Title = "Info", Icon = "" }),
}

local Options = PetUI.Options

---------------------------------------------------------------------
-- Hàm dùng chung
---------------------------------------------------------------------
-- Vòng lặp nền: chỉ chạy khi công tắc bật
local running = {}

local function autoLoop(key, delay, fn)
	task.spawn(function()
		while Window.Gui.Parent do
			if running[key] then
				local ok, err = pcall(fn)
				if not ok then
					warn("[PetHub] " .. key .. ": " .. tostring(err))
				end
			end
			task.wait(delay)
		end
	end)
end

-- Module Rebirth của game (dùng cho tự tái sinh + tab Info)
local RebirthMod

local function getRebirth()
	if RebirthMod then
		return RebirthMod
	end
	local ok, mod = pcall(function()
		local r = ReplicatedStorage:FindFirstChild("Rebirth")
		return r and require(r)
	end)
	if ok and mod then
		RebirthMod = mod
	end
	return RebirthMod
end

-- Lấy module của game trong ReplicatedStorage (Pen, Remotes, Format, Animals...)
local moduleCache = {}

local function getModule(name)
	if moduleCache[name] then
		return moduleCache[name]
	end
	local ok, mod = pcall(function()
		local m = ReplicatedStorage:FindFirstChild(name)
		return m and require(m)
	end)
	if ok and mod then
		moduleCache[name] = mod
	end
	return moduleCache[name]
end

-- Số tiền theo kiểu của game (dự phòng: PetUI.Format)
local function formatCash(n)
	local f = getModule("Format")
	if f and f.cash then
		local ok, r = pcall(f.cash, n)
		if ok and type(r) == "string" then
			return r
		end
	end
	return PetUI.Format(n)
end

-- Tên con thú theo kiểu của game
local function animalName(name)
	local a = getModule("Animals")
	if a and a.displayName then
		local ok, r = pcall(a.displayName, name)
		if ok and type(r) == "string" then
			return r
		end
	end
	return tostring(name)
end

-- Base của mình: game lưu số base trong attribute "Base" của người chơi
-- (dự phòng: base nào có attribute "Owner" trùng tên mình)
local MyBase

local function findMyBase()
	local bases = workspace:FindFirstChild("Bases")
	if not bases then
		return nil
	end

	local id = LocalPlayer:GetAttribute("Base")
	if id then
		local base = bases:FindFirstChild(tostring(id))
		if base then
			return base
		end
	end

	for _, base in ipairs(bases:GetChildren()) do
		if base:GetAttribute("Owner") == LocalPlayer.Name then
			return base
		end
	end
	return nil
end

---------------------------------------------------------------------
-- Tab Auto
---------------------------------------------------------------------
Tabs.Auto:AddToggle("AutoHatch", {
	Title = "Auto Hatch Egg",
	Description = "Keeps opening eggs for you",
	Icon = "",
	Color = Colors.mint,
	Default = false,
	Callback = function(on)
		running.hatch = on
	end,
})
-- Trứng chín khi thời gian server >= HatchAt của nest trong LocalPlayer.Nests
local lastHatch = {}

autoLoop("hatch", 0.5, function()
	local nests = LocalPlayer:FindFirstChild("Nests")
	if not nests then
		return
	end

	local now = workspace:GetServerTimeNow()
	for _, nest in ipairs(nests:GetChildren()) do
		local hatchAt = nest:GetAttribute("HatchAt")
		local ready = nest:GetAttribute("Owned") == true
			and nest:GetAttribute("Egg")
			and hatchAt
			and now >= hatchAt

		-- Chỉ mở nest có trứng đã chín, mỗi nest cách nhau 1.5 giây
		if ready and (not lastHatch[nest.Name] or os.clock() - lastHatch[nest.Name] > 1.5) then
			lastHatch[nest.Name] = os.clock()

			local args = {
				nest.Name
			}
			game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("OpenBlockEvent"):FireServer(unpack(args))
		end
	end
end)

Tabs.Auto:AddToggle("AutoEquip", {
	Title = "Auto Equip Best",
	Description = "Always wear your strongest pets",
	Icon = "",
	Color = Colors.violet,
	Default = false,
	Callback = function(on)
		running.equip = on
	end,
})
autoLoop("equip", 3, function()
	game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("EquipBestEvent"):FireServer()
end)

Tabs.Auto:AddToggle("AutoRebirth", {
	Title = "Auto Rebirth",
	Description = "Rebirths as soon as you can",
	Icon = "",
	Color = Colors.amber,
	Default = false,
	Callback = function(on)
		running.rebirth = on
	end,
})
autoLoop("rebirth", 1, function()
	local mod = getRebirth()
	-- Chưa đủ điều kiện thì chờ
	if mod and not mod.CanRebirth(LocalPlayer) then
		return
	end
	game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("RebirthEvent"):FireServer()
end)

Tabs.Auto:AddToggle("AutoUpgrade", {
	Title = "Auto Upgrade Base",
	Description = "Upgrades your pen when you have enough cash",
	Icon = "",
	Color = Colors.blue,
	Default = false,
	Callback = function(on)
		running.upgrade = on
	end,
})
autoLoop("upgrade", 1, function()
	local pen = getModule("Pen")
	local remotes = getModule("Remotes")
	if not (pen and remotes) then
		return
	end

	local cost = pen.getCost(LocalPlayer:GetAttribute("PenUpgrades") or 0)

	-- Hết cấp để nâng thì tự tắt
	if not cost then
		Options.AutoUpgrade:SetValue(false)
		Window:Notify({ Title = "Auto Upgrade", Content = "Base is maxed", Duration = 2 })
		return
	end

	local ls = LocalPlayer:FindFirstChild("leaderstats")
	local cv = ls and ls:FindFirstChild("Cash")
	if cv and cv.Value >= cost then
		remotes.BaseUpgradeEvent:FireServer()
	end
end)

---------------------------------------------------------------------
-- Tab Shop
---------------------------------------------------------------------
-- Gắn hitbox vào người để game tự mở shop.
-- Hitbox bám theo người suốt lúc frame mở, frame tắt thì trả về chỗ cũ.
local function holdHitbox(hitbox, frame, root)
	-- Đang giữ rồi thì không làm lại
	if hitbox:GetAttribute("PetHubHeld") then
		return
	end
	hitbox:SetAttribute("PetHubHeld", true)

	local oldCFrame = hitbox.CFrame

	local follow = game:GetService("RunService").Heartbeat:Connect(function()
		if root.Parent then
			hitbox.CFrame = root.CFrame
		end
	end)

	local function giveBack()
		follow:Disconnect()
		hitbox.CFrame = oldCFrame
		hitbox:SetAttribute("PetHubHeld", nil)
	end

	task.spawn(function()
		-- Chờ shop mở (tối đa 2 giây), không mở được thì trả hitbox về luôn
		local t = 0
		while not frame.Visible and t < 2 do
			t += task.wait(0.1)
		end
		if not frame.Visible then
			giveBack()
			return
		end

		-- Shop tắt (nút X hoặc đi ra) thì trả hitbox về chỗ cũ
		local conn
		conn = frame:GetPropertyChangedSignal("Visible"):Connect(function()
			if not frame.Visible then
				conn:Disconnect()
				giveBack()
			end
		end)
	end)
end

Tabs.Shop:AddButton({
	Title = "Food Shop",
	Description = "Open the pet food store",
	Icon = "",
	Color = Colors.violet,
	ButtonText = "OPEN",
	Callback = function()
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hitbox = workspace:FindFirstChild("Map")
			and workspace.Map:FindFirstChild("Food")
			and workspace.Map.Food:FindFirstChild("Hitbox")
		local mainGui = LocalPlayer.PlayerGui:FindFirstChild("MainGui")
		local frame = mainGui and mainGui:FindFirstChild("FoodFrame")

		-- Không tìm thấy hitbox / frame thì gọi thẳng remote mở shop
		if not (root and hitbox and frame) then
			local args = {
				"Open"
			}
			game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("FoodEvent"):FireServer(unpack(args))
		else
			holdHitbox(hitbox, frame, root)
		end

		Window:Notify({ Title = "Food Shop", Content = "Opened", Duration = 1.5 })
	end,
})

Tabs.Shop:AddButton({
	Title = "Scanner Shop",
	Description = "Open the scanner store",
	Icon = "",
	Color = Colors.blue,
	ButtonText = "OPEN",
	Callback = function()
		local character = LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hitbox = workspace:FindFirstChild("Map")
			and workspace.Map:FindFirstChild("Scanners")
			and workspace.Map.Scanners:FindFirstChild("Hitbox")
		local mainGui = LocalPlayer.PlayerGui:FindFirstChild("MainGui")
		local frame = mainGui and mainGui:FindFirstChild("ScannersFrame")

		-- Không tìm thấy hitbox / frame thì gọi thẳng remote mở shop
		if not (root and hitbox and frame) then
			local args = {
				"Open"
			}
			game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("ScannerEvent"):FireServer(unpack(args))
		else
			holdHitbox(hitbox, frame, root)
		end

		Window:Notify({ Title = "Scanner Shop", Content = "Opened", Duration = 1.5 })
	end,
})

Tabs.Shop:AddButton({
	Title = "Sell All Pets",
	Description = "Sell your whole pet inventory",
	Icon = "",
	Color = Colors.amber,
	ButtonText = "SELL",
	Callback = function()
		local args = {
			"Pets"
		}
		game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("SellAllEvent"):FireServer(unpack(args))
		Window:Notify({ Title = "Sell All Pets", Content = "Sent", Duration = 1.5 })
	end,
})

---------------------------------------------------------------------
-- Tab Info (người chơi + rebirth)
---------------------------------------------------------------------
local PlayerCard = Tabs.Info:AddPlayerCard()

local Stats = Tabs.Info:AddStats({
	{ Id = "Cash", Title = "Cash", Color = Colors.amber },
	{ Id = "Speed", Title = "Hatch Speed", Color = Colors.blue },
	{ Id = "Boost", Title = "Cash Boost", Color = Color3.fromRGB(183, 171, 255) },
})

local PenStats = Tabs.Info:AddStats({
	{ Id = "Slots", Title = "Max Slots", Color = Colors.mint },
	{ Id = "Upgrade", Title = "Next Upgrade", Color = Colors.amber },
})

local Goal = Tabs.Info:AddGoalCard({
	Title = "Next Rebirth",
	Icon = "",
	ItemLabel = "Required Egg",
	CostLabel = "Cost",
})

local function times(x)
	return x and (tostring(math.floor(x * 100 + 0.5) / 100) .. "x") or "—"
end

local lastIcon

local function refreshInfo()
	local fmt = formatCash
	local ls = LocalPlayer:FindFirstChild("leaderstats")
	local rbv = ls and ls:FindFirstChild("Rebirths")
	local cv = ls and ls:FindFirstChild("Cash")
	local rebirths = rbv and rbv.Value or 0
	local cash = cv and cv.Value or 0
	local mod = getRebirth()

	local nxt, speed, boost, hatched, can
	if mod then
		pcall(function()
			nxt = mod.getNext(rebirths)
			speed = mod.getPlayerHatchSpeed(LocalPlayer)
			boost = mod.getCashMulti(rebirths)
			hatched = mod.hasHatched(LocalPlayer)
			can = mod.CanRebirth(LocalPlayer)
		end)
	end

	PlayerCard:SetBadge("Rebirths " .. rebirths)
	Stats:Set("Cash", fmt(cash))
	Stats:Set("Speed", times(speed))
	Stats:Set("Boost", times(boost))

	local pen = getModule("Pen")
	if pen then
		local up = LocalPlayer:GetAttribute("PenUpgrades") or 0
		local okSlots, slots = pcall(pen.getMaxSlots, up)
		local okCost, cost = pcall(pen.getCost, up)
		PenStats:Set("Slots", okSlots and slots or "—")
		PenStats:Set("Upgrade", okCost and (cost and fmt(cost) or "MAX") or "—")
	end

	if nxt then
		local eggKey = nxt.animal
		local ok, egg = pcall(function()
			return mod.eggFor(nxt.animal)
		end)
		if ok and type(egg) == "table" then
			eggKey = egg.displayName or egg.name or eggKey
		end
		local eggName = animalName(eggKey) .. " Egg"

		-- Icon trứng / thú: dùng chính hàm vẽ icon của game
		local viewport = getModule("ViewportIcons")
		local hasEgg = ok and type(egg) == "table" and egg.name
		local iconKey = hasEgg and ("Egg:" .. egg.name) or ("Animal:" .. nxt.animal)
		if viewport and iconKey ~= lastIcon then
			lastIcon = iconKey
			pcall(function()
				if hasEgg then
					viewport.apply(Goal.IconLabel, "Egg", egg.name)
				else
					viewport.apply(Goal.IconLabel, "Animal", nxt.animal)
				end
			end)
		end

		local msg
		if can then
			msg = "READY · You can rebirth now!"
		elseif not hatched then
			msg = "NOT READY · Hatch the egg first"
		else
			msg = "NOT READY · Need " .. fmt(math.max(0, nxt.cost - cash)) .. " more Cash"
		end

		Goal:Update({
			Name = "#" .. nxt.level .. " " .. animalName(nxt.animal),
			Item = eggName,
			ItemOk = hatched and true or false,
			ItemOkText = "Hatched",
			ItemBadText = "Not hatched",
			CostText = fmt(cash) .. " / " .. fmt(nxt.cost),
			Ratio = cash / nxt.cost,
			Ready = can and true or false,
			Message = msg,
		})
	else
		Goal:Update({
			Name = mod and "MAX" or "—",
			Item = "—",
			CostText = fmt(cash),
			Ratio = mod and 1 or 0,
			Ready = mod ~= nil,
			Message = mod and "MAX · Max rebirth reached" or "—",
		})
	end
end

-- Làm mới ngay khi mở tab, và mỗi giây khi đang xem
Tabs.Info.OnShow = refreshInfo
task.spawn(function()
	while Window.Gui.Parent do
		task.wait(1)
		if Window.IsOpen and Window.ActiveTab == Tabs.Info then
			pcall(refreshInfo)
		end
	end
end)

---------------------------------------------------------------------
-- THÊM CHỨC NĂNG MỚI Ở ĐÂY (copy mẫu ở trên: AddToggle / AddButton)
---------------------------------------------------------------------

Window:Notify({ Title = "Pet Hub", Content = "Press RightControl or tap the floating button", Duration = 3 })

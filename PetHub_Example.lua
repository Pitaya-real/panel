-- =================================================================
-- PET HUB - SCRIPT CHỨC NĂNG (DẠNG LOADSTRING GITHUB)
-- Dán link raw của file PetUI.lua vào rawUrl bên dưới
-- Icon: để "" là trống, điền ID ảnh vào sau (vd "73866843639743")
-- =================================================================

-- 1. Tải và nạp Library từ GitHub
local rawUrl = "https://raw.githubusercontent.com/Pitaya-real/panel/refs/heads/main/PetUI.lua"
local PetUI = loadstring(game:HttpGet(rawUrl))()

-- Dịch vụ
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Colors = PetUI.Colors

-- 2. Tạo cửa sổ menu chính
local Window = PetUI:CreateWindow({
	Title = "VELTRIX HUB",
	SubTitle = "HELPER FOR YOU!!",

	Logo = "81206582590579",
	FloatingIcon = "129870829580868",

	FloatingSize = 60,
	FloatingPosition = UDim2.new(0, 36, 0.5, -30),
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
autoLoop("hatch", 0.3, function()
	-- Mỗi lượt mở hết 12 ô (thay "1" bằng 1 -> 12)
	for slot = 1, 12 do
		local args = {
			tostring(slot)
		}
		game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("OpenBlockEvent"):FireServer(unpack(args))
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

---------------------------------------------------------------------
-- Tab Shop
---------------------------------------------------------------------
Tabs.Shop:AddButton({
	Title = "Food Shop",
	Description = "Open the pet food store",
	Icon = "",
	Color = Colors.violet,
	ButtonText = "OPEN",
	Callback = function()
		local args = {
			"Open"
		}
		game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("FoodEvent"):FireServer(unpack(args))
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
		local args = {
			"Open"
		}
		game:GetService("ReplicatedStorage"):WaitForChild("RemoteEvents"):WaitForChild("ScannerEvent"):FireServer(unpack(args))
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

local Goal = Tabs.Info:AddGoalCard({
	Title = "Next Rebirth",
	Icon = "",
	ItemLabel = "Required Egg",
	CostLabel = "Cost",
})

local function times(x)
	return x and (tostring(math.floor(x * 100 + 0.5) / 100) .. "x") or "—"
end

local function refreshInfo()
	local fmt = PetUI.Format
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

	if nxt then
		local eggName = nxt.animal .. " Egg"
		local ok, egg = pcall(function()
			return mod.eggFor(nxt.animal)
		end)
		if ok and type(egg) == "table" and type(egg.name or egg.Name) == "string" then
			eggName = egg.name or egg.Name
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
			Name = "#" .. nxt.level .. " " .. nxt.animal,
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

-- =====================================================================
--  VILLE FOLLE (Roblox) - script joueur (LocalScript)
--  A mettre dans StarterPlayer > StarterPlayerScripts (deja fait dans VilleFolle.rbxlx)
--  Affichage (argent, etoiles, messages), conduite des voitures, tir.
-- =====================================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = RS:WaitForChild("VilleFolleRemotes")
local ShootEvent = Remotes:WaitForChild("Shoot")
local NotifyEvent = Remotes:WaitForChild("Notify")

-- ---------- interface ----------
local gui = Instance.new("ScreenGui")
gui.Name = "VilleFolleHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(pos, size, color, font)
	local l = Instance.new("TextLabel")
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 1
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Font = font or Enum.Font.GothamBlack
	l.TextScaled = true
	l.Text = ""
	l.Parent = gui
	return l
end

local moneyL = label(UDim2.new(1, -230, 0, 50), UDim2.new(0, 210, 0, 44), Color3.fromRGB(120, 255, 120))
moneyL.TextXAlignment = Enum.TextXAlignment.Right
local starsL = label(UDim2.new(1, -230, 0, 96), UDim2.new(0, 210, 0, 34), Color3.fromRGB(255, 220, 60))
starsL.TextXAlignment = Enum.TextXAlignment.Right
local speedL = label(UDim2.new(0.5, -90, 1, -110), UDim2.new(0, 180, 0, 40), Color3.new(1, 1, 1))
local msgL = label(UDim2.new(0.5, -300, 0, 140), UDim2.new(0, 600, 0, 40), Color3.new(1, 1, 1), Enum.Font.GothamBold)
local helpL = label(UDim2.new(0.5, -320, 1, -40), UDim2.new(0, 640, 0, 26), Color3.fromRGB(220, 220, 220), Enum.Font.Gotham)
helpL.Text = "E : interagir / braquer  -  Clic : tirer  -  Monte dans une voiture en t'asseyant dessus"

local msgUntil = 0
NotifyEvent.OnClientEvent:Connect(function(text)
	msgL.Text = tostring(text)
	msgUntil = os.clock() + 4
end)

local function refreshHUD()
	local ls = player:FindFirstChild("leaderstats")
	local money = ls and ls:FindFirstChild("Argent")
	moneyL.Text = "$" .. tostring(money and money.Value or 0)
	local s = player:GetAttribute("Etoiles") or 0
	starsL.Text = string.rep("★", s) .. string.rep("☆", 5 - s)
	if os.clock() > msgUntil then msgL.Text = "" end
end

-- ---------- conduite ----------
local speed = 0
RunService.Heartbeat:Connect(function(dt)
	refreshHUD()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriveSeat" and seat.Parent then
		local body = seat.Parent:FindFirstChild("Body")
		if not body then return end
		local maxS = seat:GetAttribute("MaxSpeed") or 70
		local thr = seat.ThrottleFloat
		local steer = seat.SteerFloat
		if thr > 0 then
			speed = math.min(maxS, speed + thr * 38 * dt)
		elseif thr < 0 then
			if speed > 0 then speed = math.max(0, speed + thr * 90 * dt) else speed = math.max(-25, speed + thr * 30 * dt) end
		else
			speed = speed * (1 - 1.2 * dt)
			if math.abs(speed) < 0.3 then speed = 0 end
		end
		local look = body.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude < 0.1 then flat = Vector3.new(0, 0, -1) end
		flat = flat.Unit
		local vy = body.AssemblyLinearVelocity.Y
		body.AssemblyLinearVelocity = flat * speed + Vector3.new(0, math.min(vy, 30), 0)
		local turn = math.clamp(speed / 12, -1, 1)
		body.AssemblyAngularVelocity = Vector3.new(0, -steer * turn * 1.7, 0)
		-- remet la voiture sur ses roues si elle se retourne
		if body.CFrame.UpVector.Y < 0.4 then
			local _, yaw, _ = body.CFrame:ToEulerAnglesYXZ()
			body.CFrame = CFrame.new(body.Position + Vector3.new(0, 3, 0)) * CFrame.Angles(0, yaw, 0)
		end
		speedL.Text = math.floor(math.abs(speed) * 1.1) .. " km/h"
	else
		speed = 0
		speedL.Text = ""
	end
end)

-- ---------- tir ----------
local mouse = player:GetMouse()
local holding = false
local lastShot = 0
local RATES = {Pistolet = 0.45, ["Fusil d'assaut"] = 0.11, ["Fusil a pompe"] = 0.9, Sniper = 1.3}

local function currentTool()
	local char = player.Character
	return char and char:FindFirstChildOfClass("Tool")
end

local function tryShoot()
	local tool = currentTool()
	if not tool then return end
	local rate = RATES[tool.Name]
	if not rate then return end
	local now = os.clock()
	if now - lastShot < rate then return end
	lastShot = now
	ShootEvent:FireServer(mouse.Hit.Position)
end

local function hookTool(tool)
	if not tool:IsA("Tool") then return end
	tool.Activated:Connect(function()
		holding = true
		tryShoot()
	end)
	tool.Deactivated:Connect(function()
		holding = false
	end)
end

local function hookCharacter(char)
	for _, t in ipairs(char:GetChildren()) do hookTool(t) end
	char.ChildAdded:Connect(hookTool)
end
if player.Character then hookCharacter(player.Character) end
player.CharacterAdded:Connect(hookCharacter)

-- tir automatique en restant appuye (fusil d'assaut)
RunService.RenderStepped:Connect(function()
	if holding then
		local tool = currentTool()
		if tool and tool.Name == "Fusil d'assaut" then tryShoot() end
		if not tool then holding = false end
	end
end)

-- zoom du sniper : clic droit
UIS.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		local tool = currentTool()
		if tool and tool.Name == "Sniper" then workspace.CurrentCamera.FieldOfView = 20 end
	end
end)
UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		workspace.CurrentCamera.FieldOfView = 70
	end
end)

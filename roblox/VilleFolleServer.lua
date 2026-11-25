-- =====================================================================
--  VILLE FOLLE (Roblox) - script serveur
--  A mettre dans ServerScriptService (deja fait dans VilleFolle.rbxlx)
--  Genere la ville, les voitures, les armes, les braquages, la police
--  et sauvegarde l'argent de chaque joueur.
-- =====================================================================
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local DSS = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- ---------- reglages ----------
local BLOCK = 70        -- taille d'un pate de maisons
local ROAD = 24         -- largeur des routes
local CELL = BLOCK + ROAD
local N = 7             -- ville de N x N blocs
local SIZE = N * CELL + ROAD
local START_MONEY = 500
local rng = Random.new(2024)

-- ---------- evenements reseau ----------
local Remotes = Instance.new("Folder")
Remotes.Name = "VilleFolleRemotes"
Remotes.Parent = RS
local ShootEvent = Instance.new("RemoteEvent")
ShootEvent.Name = "Shoot"
ShootEvent.Parent = Remotes
local NotifyEvent = Instance.new("RemoteEvent")
NotifyEvent.Name = "Notify"
NotifyEvent.Parent = Remotes

local function notify(player, text)
	if player then NotifyEvent:FireClient(player, text) end
end

-- ---------- outils de construction ----------
local City = Instance.new("Folder")
City.Name = "Ville"
City.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "Parent" then p[k] = v end
	end
	p.Parent = props.Parent or City
	return p
end

-- ---------- sol, routes, trottoirs ----------
part({Name = "Herbe", Size = Vector3.new(SIZE + 400, 2, SIZE + 400), Position = Vector3.new(SIZE / 2, -1, SIZE / 2), Color = Color3.fromRGB(76, 130, 60), Material = Enum.Material.Grass})
for i = 0, N do
	local c = i * CELL + ROAD / 2
	part({Name = "Route", Size = Vector3.new(ROAD, 0.2, SIZE), Position = Vector3.new(c, 0.1, SIZE / 2), Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Asphalt})
	part({Name = "Route", Size = Vector3.new(SIZE, 0.21, ROAD), Position = Vector3.new(SIZE / 2, 0.1, c), Color = Color3.fromRGB(45, 45, 50), Material = Enum.Material.Asphalt})
	-- lignes jaunes au milieu
	for k = 0, N - 1 do
		local m = k * CELL + ROAD + BLOCK / 2
		part({Name = "Ligne", Size = Vector3.new(0.5, 0.05, BLOCK - 6), Position = Vector3.new(c, 0.23, m), Color = Color3.fromRGB(240, 200, 40), Material = Enum.Material.SmoothPlastic, CanCollide = false})
		part({Name = "Ligne", Size = Vector3.new(BLOCK - 6, 0.05, 0.5), Position = Vector3.new(m, 0.23, c), Color = Color3.fromRGB(240, 200, 40), Material = Enum.Material.SmoothPlastic, CanCollide = false})
	end
end

-- ---------- lieux speciaux ----------
local SPECIAL = {}
SPECIAL["3,3"] = "spawn"
SPECIAL["2,3"] = "gun"
SPECIAL["4,3"] = "cars"
SPECIAL["1,1"] = "bank"
SPECIAL["5,5"] = "bank"
SPECIAL["3,1"] = "casino"
local storeCount = 0

local function blockOrigin(bx, bz)
	return bx * CELL + ROAD, bz * CELL + ROAD
end

local function sign(text, pos, rot, color)
	local p = part({Name = "Panneau", Size = Vector3.new(16, 4, 0.5), CFrame = CFrame.new(pos) * CFrame.Angles(0, rot, 0), Color = color, Material = Enum.Material.SmoothPlastic})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Parent = gui
	local back = gui:Clone()
	back.Face = Enum.NormalId.Back
	back.Parent = p
	return p
end

local function prompt(parentPart, action, object, hold)
	local pp = Instance.new("ProximityPrompt")
	pp.ActionText = action
	pp.ObjectText = object
	pp.HoldDuration = hold or 0
	pp.MaxActivationDistance = 12
	pp.RequiresLineOfSight = false
	pp.Parent = parentPart
	return pp
end

-- immeuble simple avec fenetres
local BUILD_COLORS = {Color3.fromRGB(180, 170, 160), Color3.fromRGB(150, 90, 70), Color3.fromRGB(90, 110, 140), Color3.fromRGB(200, 190, 150), Color3.fromRGB(120, 120, 125)}
local function building(x0, z0, w, d, h)
	local col = BUILD_COLORS[rng:NextInteger(1, #BUILD_COLORS)]
	part({Name = "Immeuble", Size = Vector3.new(w, h, d), Position = Vector3.new(x0 + w / 2, h / 2, z0 + d / 2), Color = col, Material = Enum.Material.Concrete})
	-- bandes de fenetres (lumineuses la nuit)
	local floors = math.floor(h / 8)
	for f = 1, floors do
		local y = f * 8 - 3
		part({Name = "Fenetres", Size = Vector3.new(w + 0.2, 2.2, d + 0.2), Position = Vector3.new(x0 + w / 2, y, z0 + d / 2), Color = Color3.fromRGB(255, 225, 150), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false})
	end
end

-- magasin a braquer
local function store(x, z, rot, kind)
	storeCount = storeCount + 1
	local name = kind == "bank" and "Banque" or "Superette"
	local w, d, h = 26, 20, 12
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, rot, 0)
	local function piece(sz, off, color, mat, collide)
		return part({Name = name, Size = sz, CFrame = cf * CFrame.new(off), Color = color, Material = mat or Enum.Material.Concrete, CanCollide = collide ~= false})
	end
	local wall = kind == "bank" and Color3.fromRGB(220, 220, 225) or Color3.fromRGB(230, 120, 60)
	piece(Vector3.new(w, h, 1), Vector3.new(0, h / 2, -d / 2), wall)                       -- fond
	piece(Vector3.new(1, h, d), Vector3.new(-w / 2, h / 2, 0), wall)                        -- cotes
	piece(Vector3.new(1, h, d), Vector3.new(w / 2, h / 2, 0), wall)
	piece(Vector3.new(w / 2 - 4, h, 1), Vector3.new(-w / 4 - 2, h / 2, d / 2), wall)        -- facade avec porte
	piece(Vector3.new(w / 2 - 4, h, 1), Vector3.new(w / 4 + 2, h / 2, d / 2), wall)
	piece(Vector3.new(8, h - 8, 1), Vector3.new(0, h - (h - 8) / 2, d / 2), wall)
	piece(Vector3.new(w, 1, d), Vector3.new(0, h, 0), Color3.fromRGB(60, 60, 65))          -- toit
	local counter = piece(Vector3.new(12, 4, 3), Vector3.new(0, 2, -d / 2 + 5), Color3.fromRGB(110, 70, 40), Enum.Material.Wood)
	counter:SetAttribute("Kind", kind)
	counter:SetAttribute("Cooldown", 0)
	sign(kind == "bank" and "BANQUE" or "SUPERETTE", (cf * CFrame.new(0, h + 2.5, d / 2)).Position, rot, kind == "bank" and Color3.fromRGB(20, 120, 60) or Color3.fromRGB(200, 60, 40))
	prompt(counter, "Braquer", name, kind == "bank" and 4 or 2.5)
	return counter
end

local GUN_SHOP, CAR_SHOP, CASINO

for bx = 0, N - 1 do
	for bz = 0, N - 1 do
		local X0, Z0 = blockOrigin(bx, bz)
		local kind = SPECIAL[bx .. "," .. bz]
		-- trottoir
		part({Name = "Trottoir", Size = Vector3.new(BLOCK, 0.6, BLOCK), Position = Vector3.new(X0 + BLOCK / 2, 0.3, Z0 + BLOCK / 2), Color = Color3.fromRGB(170, 170, 170), Material = Enum.Material.Concrete})
		-- lampadaires aux coins
		for _, c in ipairs({{X0 + 2, Z0 + 2}, {X0 + BLOCK - 2, Z0 + BLOCK - 2}}) do
			part({Name = "Lampadaire", Size = Vector3.new(0.6, 14, 0.6), Position = Vector3.new(c[1], 7, c[2]), Color = Color3.fromRGB(50, 50, 55), Material = Enum.Material.Metal})
			local lamp = part({Name = "Lampe", Size = Vector3.new(1.6, 0.8, 1.6), Position = Vector3.new(c[1], 14.2, c[2]), Color = Color3.fromRGB(255, 230, 170), Material = Enum.Material.Neon})
			local light = Instance.new("PointLight")
			light.Range = 40
			light.Brightness = 2
			light.Color = Color3.fromRGB(255, 220, 160)
			light.Parent = lamp
		end
		if kind == "spawn" then
			local sp = Instance.new("SpawnLocation")
			sp.Anchored = true
			sp.Size = Vector3.new(12, 1, 12)
			sp.Position = Vector3.new(X0 + BLOCK / 2, 0.7, Z0 + BLOCK / 2)
			sp.Color = Color3.fromRGB(80, 160, 255)
			sp.Material = Enum.Material.Neon
			sp.Duration = 0
			sp.Parent = City
			sign("VILLE FOLLE", Vector3.new(X0 + BLOCK / 2, 9, Z0 + 8), 0, Color3.fromRGB(255, 120, 0))
		elseif kind == "gun" then
			GUN_SHOP = part({Name = "Armurerie", Size = Vector3.new(14, 4, 3), Position = Vector3.new(X0 + BLOCK / 2, 2.6, Z0 + BLOCK / 2), Color = Color3.fromRGB(60, 60, 60), Material = Enum.Material.Metal})
			sign("ARMURERIE", Vector3.new(X0 + BLOCK / 2, 9, Z0 + BLOCK / 2 - 4), 0, Color3.fromRGB(40, 40, 40))
		elseif kind == "cars" then
			CAR_SHOP = part({Name = "Concession", Size = Vector3.new(14, 4, 3), Position = Vector3.new(X0 + BLOCK / 2, 2.6, Z0 + BLOCK / 2), Color = Color3.fromRGB(30, 80, 200), Material = Enum.Material.SmoothPlastic})
			sign("AUTO FOLLE", Vector3.new(X0 + BLOCK / 2, 9, Z0 + BLOCK / 2 - 4), 0, Color3.fromRGB(30, 80, 200))
		elseif kind == "casino" then
			CASINO = part({Name = "Casino", Size = Vector3.new(14, 4, 3), Position = Vector3.new(X0 + BLOCK / 2, 2.6, Z0 + BLOCK / 2), Color = Color3.fromRGB(120, 30, 160), Material = Enum.Material.Neon})
			sign("CASINO FORTUNA", Vector3.new(X0 + BLOCK / 2, 9, Z0 + BLOCK / 2 - 4), 0, Color3.fromRGB(120, 30, 160))
		elseif kind == "bank" then
			store(X0 + BLOCK / 2, Z0 + BLOCK / 2, 0, "bank")
		else
			-- 1 superette sur 4 blocs, sinon des immeubles
			if (bx + bz * 3) % 4 == 0 then
				store(X0 + BLOCK / 2, Z0 + BLOCK / 2, 0, "store")
			else
				local half = BLOCK / 2 - 4
				for qx = 0, 1 do
					for qz = 0, 1 do
						local h = rng:NextInteger(16, 70)
						building(X0 + 3 + qx * (half + 2), Z0 + 3 + qz * (half + 2), half, half, h)
					end
				end
			end
		end
	end
end

-- ---------- voitures ----------
local CARS = Instance.new("Folder")
CARS.Name = "Voitures"
CARS.Parent = workspace
local CAR_TYPES = {
	{name = "Berline", color = Color3.fromRGB(40, 90, 200), speed = 70, size = Vector3.new(6, 2.2, 11)},
	{name = "Taxi", color = Color3.fromRGB(240, 200, 30), speed = 70, size = Vector3.new(6, 2.2, 11)},
	{name = "Pick-up", color = Color3.fromRGB(150, 40, 40), speed = 65, size = Vector3.new(6.5, 2.6, 12)},
	{name = "Sportive", color = Color3.fromRGB(230, 30, 60), speed = 110, size = Vector3.new(6, 1.8, 11), price = 6000},
	{name = "Supercar", color = Color3.fromRGB(20, 20, 25), speed = 140, size = Vector3.new(6.2, 1.6, 11.5), price = 15000},
}

local function makeCar(t, cf, owner)
	local m = Instance.new("Model")
	m.Name = t.name
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = t.size
	body.CFrame = cf * CFrame.new(0, t.size.Y / 2 + 1.2, 0)
	body.Color = t.color
	body.Material = Enum.Material.SmoothPlastic
	body.CustomPhysicalProperties = PhysicalProperties.new(1, 0.25, 0.1, 1, 1)
	body.Parent = m
	-- habitacle et vitres
	local cab = Instance.new("Part")
	cab.Name = "Cabine"
	cab.Size = Vector3.new(t.size.X - 0.6, 1.8, t.size.Z * 0.45)
	cab.CFrame = body.CFrame * CFrame.new(0, t.size.Y / 2 + 0.9, 0.4)
	cab.Color = Color3.fromRGB(30, 40, 55)
	cab.Material = Enum.Material.Glass
	cab.Transparency = 0.2
	cab.CanCollide = false
	cab.Massless = true
	cab.Parent = m
	-- roues (decoratives)
	for _, o in ipairs({{-1, -1}, {1, -1}, {-1, 1}, {1, 1}}) do
		local w = Instance.new("Part")
		w.Name = "Roue"
		w.Shape = Enum.PartType.Cylinder
		w.Size = Vector3.new(1, 2.4, 2.4)
		w.CFrame = body.CFrame * CFrame.new(o[1] * (t.size.X / 2 + 0.1), -t.size.Y / 2 + 0.2, o[2] * t.size.Z * 0.33)
		w.Color = Color3.fromRGB(20, 20, 20)
		w.CanCollide = false
		w.Massless = true
		w.Parent = m
	end
	-- phares
	local hl = Instance.new("Part")
	hl.Name = "Phares"
	hl.Size = Vector3.new(t.size.X - 1, 0.5, 0.2)
	hl.CFrame = body.CFrame * CFrame.new(0, 0.2, -t.size.Z / 2 - 0.05)
	hl.Color = Color3.fromRGB(255, 250, 220)
	hl.Material = Enum.Material.Neon
	hl.CanCollide = false
	hl.Massless = true
	hl.Parent = m
	local spot = Instance.new("SpotLight")
	spot.Range = 45
	spot.Angle = 60
	spot.Brightness = 3
	spot.Face = Enum.NormalId.Front
	spot.Parent = hl
	-- siege conducteur
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriveSeat"
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = body.CFrame * CFrame.new(0, t.size.Y / 2 + 0.5, 0.8)
	seat.Transparency = 1
	seat.Massless = true
	seat.MaxSpeed = t.speed
	seat:SetAttribute("MaxSpeed", t.speed)
	seat.Parent = m
	for _, p in ipairs(m:GetChildren()) do
		if p ~= body and p:IsA("BasePart") then
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = body
			wc.Part1 = p
			wc.Parent = body
		end
	end
	m.PrimaryPart = body
	if owner then
		m:SetAttribute("Owner", owner.UserId)
		seat:SetAttribute("Owner", owner.UserId)
	end
	m.Parent = CARS
	return m
end

-- voitures garees au bord des routes
local function roadSpot()
	local i = rng:NextInteger(0, N)
	local k = rng:NextInteger(0, N - 1)
	local c = i * CELL + ROAD / 2 + 7
	local m = k * CELL + ROAD + rng:NextNumber(10, BLOCK - 10)
	if rng:NextNumber() < 0.5 then
		return CFrame.new(c, 0.3, m)
	else
		return CFrame.new(m, 0.3, c) * CFrame.Angles(0, math.pi / 2, 0)
	end
end
for n = 1, 18 do
	makeCar(CAR_TYPES[rng:NextInteger(1, 3)], roadSpot())
end
-- regulierement, on remet des voitures s'il en manque
task.spawn(function()
	while true do
		task.wait(30)
		if #CARS:GetChildren() < 18 then
			makeCar(CAR_TYPES[rng:NextInteger(1, 3)], roadSpot())
		end
	end
end)

-- ---------- armes ----------
local WEAPONS = {
	Pistolet = {damage = 25, rate = 0.45, range = 250, price = 0},
	["Fusil d'assaut"] = {damage = 18, rate = 0.11, range = 300, price = 2500},
	["Fusil a pompe"] = {damage = 14, rate = 0.9, range = 90, pellets = 6, price = 3500},
	Sniper = {damage = 95, rate = 1.3, range = 600, price = 6000},
}
local WEAPON_ORDER = {"Fusil d'assaut", "Fusil a pompe", "Sniper"}

local function giveTool(player, name)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack or backpack:FindFirstChild(name) then return end
	local char = player.Character
	if char and char:FindFirstChild(name) then return end
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	tool.ToolTip = name
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = name == "Pistolet" and Vector3.new(0.4, 1, 1.6) or Vector3.new(0.4, 1, 3.6)
	h.Color = Color3.fromRGB(30, 30, 32)
	h.Material = Enum.Material.Metal
	h.CanCollide = false
	h.Massless = true
	h.Parent = tool
	tool.GripForward = Vector3.new(0, 0, -1)
	tool.GripPos = Vector3.new(0, -0.3, 0.4)
	tool:SetAttribute("Weapon", true)
	tool.Parent = backpack
end

-- ---------- donnees des joueurs (sauvegarde) ----------
local store_ok, DATA = pcall(function() return DSS:GetDataStore("VilleFolle_v1") end)
local playerData = {}

local function loadData(player)
	local d = {money = START_MONEY, guns = {}}
	if store_ok and DATA then
		local ok, saved = pcall(function() return DATA:GetAsync("p" .. player.UserId) end)
		if ok and type(saved) == "table" then
			if type(saved.money) == "number" then d.money = math.clamp(math.floor(saved.money), 0, 1e9) end
			if type(saved.guns) == "table" then
				for _, g in ipairs(saved.guns) do
					if WEAPONS[g] then table.insert(d.guns, g) end
				end
			end
		end
	end
	return d
end

local function saveData(player)
	local d = playerData[player]
	if not d or not store_ok or not DATA then return end
	pcall(function()
		DATA:SetAsync("p" .. player.UserId, {money = d.money, guns = d.guns})
	end)
end

local function setMoney(player, v)
	local d = playerData[player]
	if not d then return end
	d.money = math.max(0, math.floor(v))
	local ls = player:FindFirstChild("leaderstats")
	if ls and ls:FindFirstChild("Argent") then ls.Argent.Value = d.money end
end
local function addMoney(player, v)
	local d = playerData[player]
	if d then setMoney(player, d.money + v) end
end
local function getMoney(player)
	local d = playerData[player]
	return d and d.money or 0
end

-- ---------- etoiles (recherche par la police) ----------
local function stars(player)
	return player:GetAttribute("Etoiles") or 0
end
local function setStars(player, s)
	s = math.clamp(math.floor(s), 0, 5)
	player:SetAttribute("Etoiles", s)
	if s > 0 then player:SetAttribute("VuLe", os.clock()) end
end
local function crime(player, minStars)
	if stars(player) < minStars then setStars(player, minStars) else setStars(player, stars(player)) end
end

Players.PlayerAdded:Connect(function(player)
	local d = loadData(player)
	playerData[player] = d
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	ls.Parent = player
	local money = Instance.new("IntValue")
	money.Name = "Argent"
	money.Value = d.money
	money.Parent = ls
	setStars(player, 0)
	player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		giveTool(player, "Pistolet")
		for _, g in ipairs(d.guns) do giveTool(player, g) end
		local hum = char:WaitForChild("Humanoid")
		hum.Died:Connect(function()
			if stars(player) > 0 then
				local fee = math.floor(getMoney(player) * 0.1)
				addMoney(player, -fee)
				notify(player, "Tu as perdu " .. fee .. " $ et la police t'oublie")
			end
			setStars(player, 0)
		end)
	end)
	notify(player, "Bienvenue a Ville Folle ! Vole une voiture, braque une superette...")
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
	playerData[player] = nil
end)
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do saveData(p) end
end)
task.spawn(function()
	while true do
		task.wait(60)
		for _, p in ipairs(Players:GetPlayers()) do saveData(p) end
	end
end)

-- ---------- PNJ : passants et policiers ----------
local NPCS = Instance.new("Folder")
NPCS.Name = "PNJ"
NPCS.Parent = workspace

local function makeNPC(kind, pos)
	local desc = Instance.new("HumanoidDescription")
	local shirt = kind == "police" and Color3.fromRGB(20, 40, 110) or Color3.fromHSV(rng:NextNumber(), 0.6, 0.8)
	desc.TorsoColor = shirt
	desc.LeftArmColor = shirt
	desc.RightArmColor = shirt
	local skin = Color3.fromRGB(rng:NextInteger(120, 240), rng:NextInteger(90, 200), rng:NextInteger(70, 170))
	desc.HeadColor = skin
	desc.LeftLegColor = Color3.fromRGB(30, 30, 40)
	desc.RightLegColor = Color3.fromRGB(30, 30, 40)
	local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15) end)
	if not ok or not model then return nil end
	model.Name = kind == "police" and "Policier" or "Passant"
	model:SetAttribute("NPC", kind)
	model:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
	model.Parent = NPCS
	local root = model:FindFirstChild("HumanoidRootPart")
	if root then pcall(function() root:SetNetworkOwner(nil) end) end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = kind == "police" and 18 or 8
		hum.MaxHealth = kind == "police" and 80 or 50
		hum.Health = hum.MaxHealth
		hum.Died:Connect(function() Debris:AddItem(model, 6) end)
	end
	return model
end

local function sidewalkPoint()
	local bx = rng:NextInteger(0, N - 1)
	local bz = rng:NextInteger(0, N - 1)
	local X0, Z0 = blockOrigin(bx, bz)
	if rng:NextNumber() < 0.5 then
		return Vector3.new(X0 + rng:NextNumber(2, BLOCK - 2), 1, Z0 + 1.5)
	end
	return Vector3.new(X0 + 1.5, 1, Z0 + rng:NextNumber(2, BLOCK - 2))
end

-- passants qui se baladent
task.spawn(function()
	for i = 1, 16 do
		makeNPC("civil", sidewalkPoint())
		task.wait(0.2)
	end
	while true do
		task.wait(2)
		local civils = 0
		for _, m in ipairs(NPCS:GetChildren()) do
			local hum = m:FindFirstChildOfClass("Humanoid")
			if m:GetAttribute("NPC") == "civil" and hum and hum.Health > 0 then
				civils = civils + 1
				if rng:NextNumber() < 0.3 then hum:MoveTo(sidewalkPoint()) end
			end
		end
		if civils < 16 then makeNPC("civil", sidewalkPoint()) end
	end
end)

-- policiers : ils poursuivent les joueurs recherches et leur tirent dessus
local function lineOfSight(fromPos, toPos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local r = workspace:Raycast(fromPos, toPos - fromPos, params)
	return r == nil
end

local function tracer(a, b)
	local dist = (b - a).Magnitude
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 220, 120)
	p.Size = Vector3.new(0.12, 0.12, dist)
	p.CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -dist / 2)
	p.Parent = workspace
	Debris:AddItem(p, 0.06)
end

task.spawn(function()
	while true do
		task.wait(0.4)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local s = stars(player)
			local char = player.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			local phum = char and char:FindFirstChildOfClass("Humanoid")
			local mine = {}
			for _, m in ipairs(NPCS:GetChildren()) do
				if m:GetAttribute("NPC") == "police" and m:GetAttribute("Cible") == player.UserId then
					local hum = m:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then table.insert(mine, m) end
				end
			end
			if s == 0 or not root or not phum or phum.Health <= 0 then
				for _, m in ipairs(mine) do m:Destroy() end
			else
				-- renforts
				local want = math.min(8, s * 2)
				if #mine < want then
					local a = rng:NextNumber() * math.pi * 2
					local pos = root.Position + Vector3.new(math.cos(a) * 70, 0, math.sin(a) * 70)
					local cop = makeNPC("police", Vector3.new(pos.X, 1, pos.Z))
					if cop then cop:SetAttribute("Cible", player.UserId) end
				end
				local seen = false
				for _, cop in ipairs(mine) do
					local croot = cop:FindFirstChild("HumanoidRootPart")
					local chum = cop:FindFirstChildOfClass("Humanoid")
					if croot and chum then
						local dist = (root.Position - croot.Position).Magnitude
						chum:MoveTo(root.Position)
						if dist < 90 then
							local head = cop:FindFirstChild("Head")
							local from = head and head.Position or croot.Position
							if lineOfSight(from, root.Position, {cop, char}) then
								seen = true
								local last = cop:GetAttribute("Tir") or 0
								if dist < 50 and now - last > 1.3 then
									cop:SetAttribute("Tir", now)
									tracer(from, root.Position + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(-1, 1), rng:NextNumber(-2, 2)))
									if rng:NextNumber() < 0.4 + s * 0.05 then phum:TakeDamage(6 + s * 2) end
								end
							end
						end
					end
				end
				if seen then
					player:SetAttribute("VuLe", now)
				elseif now - (player:GetAttribute("VuLe") or now) > 20 then
					setStars(player, 0)
					notify(player, "Tu as seme la police !")
				end
			end
		end
	end
end)

-- ---------- tirs des joueurs ----------
local lastShot = {}
ShootEvent.OnServerEvent:Connect(function(player, target)
	if typeof(target) ~= "Vector3" then return end
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not tool or not hum or hum.Health <= 0 then return end
	local w = WEAPONS[tool.Name]
	if not w then return end
	local now = os.clock()
	if now - (lastShot[player] or 0) < w.rate * 0.9 then return end
	lastShot[player] = now
	local head = char:FindFirstChild("Head")
	if not head then return end
	local origin = head.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	for i = 1, (w.pellets or 1) do
		local dir = (target - origin).Unit
		if w.pellets then dir = (dir + Vector3.new(rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.04, 0.04), rng:NextNumber(-0.06, 0.06))).Unit end
		local r = workspace:Raycast(origin, dir * w.range, params)
		local hitPos = r and r.Position or origin + dir * w.range
		tracer(origin, hitPos)
		if r and r.Instance then
			local model = r.Instance:FindFirstAncestorOfClass("Model")
			local thum = model and model:FindFirstChildOfClass("Humanoid")
			if thum and thum.Health > 0 then
				local npc = model:GetAttribute("NPC")
				local other = Players:GetPlayerFromCharacter(model)
				if npc or (other and workspace:GetAttribute("PvP")) then
					local dmg = w.damage
					if r.Instance.Name == "Head" then dmg = dmg * 2 end
					thum:TakeDamage(dmg)
					if thum.Health <= 0 then
						if npc == "police" then
							crime(player, math.min(5, stars(player) + 1))
							addMoney(player, 50)
						elseif npc == "civil" then
							crime(player, math.max(2, stars(player)))
						end
					elseif npc == "civil" then
						crime(player, 1)
					end
				end
			end
		end
	end
end)

-- ---------- braquages ----------
for _, d in ipairs(City:GetDescendants()) do
	if d:IsA("ProximityPrompt") and d.ActionText == "Braquer" then
		d.Triggered:Connect(function(player)
			local counter = d.Parent
			local char = player.Character
			if not char or not char:FindFirstChildOfClass("Tool") then
				notify(player, "Sors une arme pour braquer !")
				return
			end
			local now = os.clock()
			local cd = counter:GetAttribute("Cooldown") or 0
			if now < cd then
				notify(player, "La caisse est vide, reviens dans " .. math.ceil(cd - now) .. " s")
				return
			end
			local bank = counter:GetAttribute("Kind") == "bank"
			counter:SetAttribute("Cooldown", now + (bank and 240 or 60))
			local gain = bank and rng:NextInteger(6000, 9000) or rng:NextInteger(300, 900)
			addMoney(player, gain)
			crime(player, bank and 4 or 2)
			notify(player, "Braquage reussi : +" .. gain .. " $ ! La police arrive...")
		end)
	end
end

-- ---------- boutiques ----------
local function refuseIfWanted(player)
	if stars(player) > 0 then
		notify(player, "On ne sert pas les gens recherches par la police !")
		return true
	end
	return false
end

if GUN_SHOP then
	for i, name in ipairs(WEAPON_ORDER) do
		local holder = part({Name = "Vitrine", Size = Vector3.new(3, 3, 3), Position = GUN_SHOP.Position + Vector3.new(-8 + i * 4, 3, 6), Color = Color3.fromRGB(80, 80, 85), Material = Enum.Material.Metal})
		local w = WEAPONS[name]
		local pp = prompt(holder, "Acheter (" .. w.price .. " $)", name, 0.5)
		pp.Triggered:Connect(function(player)
			if refuseIfWanted(player) then return end
			local d = playerData[player]
			if not d then return end
			for _, g in ipairs(d.guns) do
				if g == name then notify(player, "Tu as deja cette arme") return end
			end
			if d.money < w.price then notify(player, "Pas assez d'argent") return end
			addMoney(player, -w.price)
			table.insert(d.guns, name)
			giveTool(player, name)
			notify(player, name .. " achete !")
			saveData(player)
		end)
	end
end

if CAR_SHOP then
	local idx = 0
	for _, t in ipairs(CAR_TYPES) do
		if t.price then
			idx = idx + 1
			local holder = part({Name = "Vitrine", Size = Vector3.new(3, 3, 3), Position = CAR_SHOP.Position + Vector3.new(-6 + idx * 6, 3, 6), Color = t.color, Material = Enum.Material.SmoothPlastic})
			local pp = prompt(holder, "Acheter (" .. t.price .. " $)", t.name, 0.5)
			pp.Triggered:Connect(function(player)
				if refuseIfWanted(player) then return end
				if getMoney(player) < t.price then notify(player, "Pas assez d'argent") return end
				addMoney(player, -t.price)
				local cf = CFrame.new(CAR_SHOP.Position + Vector3.new(0, -2, 22))
				makeCar(t, cf, player)
				notify(player, "Ta " .. t.name .. " t'attend devant le magasin !")
			end)
		end
	end
end

-- casino : machine a sous (retour moyen environ 88 %, comme un vrai casino)
if CASINO then
	local SYM = {"Cerise", "Citron", "Cloche", "Diamant", "7"}
	local pp = prompt(CASINO, "Jouer (100 $)", "Machine a sous", 0.3)
	pp.Triggered:Connect(function(player)
		if refuseIfWanted(player) then return end
		if getMoney(player) < 100 then notify(player, "Pas assez d'argent") return end
		addMoney(player, -100)
		local function roll()
			local r = rng:NextNumber()
			if r < 0.1 then return 5 end
			if rng:NextNumber() < 0.15 then return 4 end
			return rng:NextInteger(1, 3)
		end
		local a, b, c = roll(), roll(), roll()
		local k = 0
		if a == b and b == c then
			if a == 5 then k = 60 elseif a == 4 then k = 25 else k = 10 end
		elseif a == b or b == c or a == c then
			k = 0.5
		end
		local win = math.floor(100 * k)
		addMoney(player, win)
		notify(player, SYM[a] .. " | " .. SYM[b] .. " | " .. SYM[c] .. (win > 0 and ("  ->  +" .. win .. " $") or "  ->  perdu"))
	end)
end

-- ---------- jour / nuit ----------
Lighting.ClockTime = 14
RunService.Heartbeat:Connect(function(dt)
	Lighting.ClockTime = (Lighting.ClockTime + dt * 0.02) % 24
end)

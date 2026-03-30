local gmt = getrawmetatable(game)
local oldIndex = gmt.__index
local oldNamecall = gmt.__namecall
setreadonly(gmt, false)

local HS = game:GetService("HttpService")
local RS = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Teams = game:GetService("Teams")
local UIS = game:GetService("UserInputService")
local GS = game:GetService("GuiService")

local UILibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/fatesc/fates-esp/main/ui.lua"))()

if not game:IsLoaded() then game.Loaded:Wait() end

local PlaceId = game.PlaceId
local CurrentCamera = Workspace.CurrentCamera
local WorldToViewportPoint = CurrentCamera.WorldToViewportPoint
local GetPartsObscuringTarget = CurrentCamera.GetPartsObscuringTarget
local Inset = GS:GetGuiInset().Y

local FindFirstChild = game.FindFirstChild
local FindFirstChildWhichIsA = game.FindFirstChildWhichIsA
local IsA = game.IsA
local Vector2new = Vector2.new
local Vector3new = Vector3.new
local CFramenew = CFrame.new
local Color3new = Color3.new
local Tfind = table.find
local create = table.create
local format = string.format
local floor = math.floor
local gsub = string.gsub
local sub = string.sub
local upper = string.upper
local random = math.random

local DefaultSettings = {
    Esp = {
        NamesEnabled = true,
        DisplayNamesEnabled = false,
        DistanceEnabled = true,
        HealthEnabled = true,
        TracersEnabled = false,
        BoxEsp = false,
        TeamColors = true,
        Thickness = 1.5,
        TracerThickness = 1.6,
        Transparency = 0.9,
        TracerTrancparency = 0.7,
        Size = 16,
        RenderDistance = 9e9,
        Color = Color3.fromRGB(19, 130, 226),
        OutlineColor = Color3new(),
        TracerTo = "Head",
        BlacklistedTeams = {}
    },
    Aimbot = {
        Enabled = false,
        SilentAim = false,
        Wallbang = false,
        ShowFov = false,
        Snaplines = true,
        ThirdPerson = false,
        FirstPerson = false,
        ClosestCharacter = false,
        ClosestCursor = true,
        Smoothness = 1,
        SilentAimHitChance = 100,
        FovThickness = 1,
        FovTransparency = 1,
        FovSize = 150,
        FovColor = Color3new(1, 1, 1),
        Aimlock = "Head",
        SilentAimRedirect = "Head",
        BlacklistedTeams = {}
    },
    WindowPosition = UDim2.new(0.5, -200, 0.5, -139),
    Version = 1.2
}

local deepsearchset
deepsearchset = function(tbl: {any}, ret: (any, any) -> boolean, value: (any, any) -> any): {any}
    if type(tbl) == "table" then
        local new = {}
        for i, v in next, tbl do
            new[i] = v
            if type(v) == "table" then
                new[i] = deepsearchset(v, ret, value)
            end
            if ret(i, v) then
                new[i] = value(i, v)
            end
        end
        return new
    end
    return tbl
end

local DecodeConfig = function(Config: {any}): {any}
    return deepsearchset(Config, function(_, Value)
        return type(Value) == "table" and (Value.HSVColor or Value.Position)
    end, function(_, Value)
        local Color = Value.HSVColor
        local Position = Value.Position
        if Color then
            return Color3.fromHSV(Color.H, Color.S, Color.V)
        end
        if Position and Position.Y and Position.X then
            return UDim2.new(UDim.new(Position.X.Scale, Position.X.Offset), UDim.new(Position.Y.Scale, Position.Y.Offset))
        end
        return DefaultSettings.WindowPosition
    end)
end

local EncodeConfig = function(Config: {any}): {any}
    local ToHSV = Color3new().ToHSV
    return deepsearchset(Config, function(_, Value)
        return typeof(Value) == "Color3" or typeof(Value) == "UDim2"
    end, function(_, Value)
        if typeof(Value) == "Color3" then
            local H, S, V = ToHSV(Value)
            return {HSVColor = {H = H, S = S, V = V}}
        end
        return {Position = {
            X = {Scale = Value.X.Scale, Offset = Value.X.Offset},
            Y = {Scale = Value.Y.Scale, Offset = Value.Y.Offset}
        }}
    end)
end

local GetConfig = function(): {any}
    local read, data = pcall(readfile, "fates-esp.json")
    local canDecode, config = pcall(HS.JSONDecode, HS, data)
    if read and canDecode then
        local Decoded = DecodeConfig(config)
        if Decoded.Version ~= DefaultSettings.Version then
            writefile("fates-esp.json", HS:JSONEncode(EncodeConfig(DefaultSettings)))
            return DefaultSettings
        end
        return Decoded
    end
    writefile("fates-esp.json", HS:JSONEncode(EncodeConfig(DefaultSettings)))
    return DefaultSettings
end

local Settings = GetConfig()
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local MouseVector = Vector2new(Mouse.X, Mouse.Y)
local Characters = {}

local CustomGet = {
    [0] = function() return {} end
}

local Get = CustomGet[PlaceId] and CustomGet[PlaceId]() or nil

local GetCharacter = function(Player: Player): Model?
    if Get then return Get.GetCharacter(Player) end
    return Player.Character
end
local CharacterAdded = function(Player: Player, Callback: (Model) -> ())
    if Get then return end
    Player.CharacterAdded:Connect(Callback)
end
local CharacterRemoving = function(Player: Player, Callback: (Model) -> ())
    if Get then return end
    Player.CharacterRemoving:Connect(Callback)
end
local GetTeam = function(Player: Player): Team?
    if Get then return Get.GetTeam(Player) end
    return Player.Team
end

local Drawings = {}
local AimbotSettings = Settings.Aimbot
local EspSettings = Settings.Esp

local FOV = Drawing.new("Circle")
FOV.Color = AimbotSettings.FovColor
FOV.Thickness = AimbotSettings.FovThickness
FOV.Transparency = AimbotSettings.FovTransparency
FOV.Filled = false
FOV.Radius = AimbotSettings.FovSize

local Snaplines = Drawing.new("Line")
Snaplines.Color = AimbotSettings.FovColor
Snaplines.Thickness = 0.1
Snaplines.Transparency = 1
Snaplines.Visible = AimbotSettings.Snaplines

table.insert(Drawings, FOV)
table.insert(Drawings, Snaplines)

local HandlePlayer = function(Player: Player)
    local Character = GetCharacter(Player)
    if Character then
        Characters[Player] = Character
    end
    CharacterAdded(Player, function(Char)
        Characters[Player] = Char
    end)
    CharacterRemoving(Player, function()
        Characters[Player] = nil
        local PlayerDrawings = Drawings[Player]
        if PlayerDrawings then
            PlayerDrawings.Text.Visible = false
            PlayerDrawings.Box.Visible = false
            PlayerDrawings.Tracer.Visible = false
        end
    end)

    if Player == LocalPlayer then return end

    local Text = Drawing.new("Text")
    Text.Color = EspSettings.Color
    Text.OutlineColor = EspSettings.OutlineColor
    Text.Size = EspSettings.Size
    Text.Transparency = EspSettings.Transparency
    Text.Center = true
    Text.Outline = true

    local Tracer = Drawing.new("Line")
    Tracer.Color = EspSettings.Color
    Tracer.From = Vector2new(CurrentCamera.ViewportSize.X / 2, CurrentCamera.ViewportSize.Y)
    Tracer.Thickness = EspSettings.TracerThickness
    Tracer.Transparency = EspSettings.TracerTrancparency

    local Box = Drawing.new("Quad")
    Box.Thickness = EspSettings.Thickness
    Box.Transparency = EspSettings.Transparency
    Box.Filled = false
    Box.Color = EspSettings.Color

    Drawings[Player] = {Text = Text, Tracer = Tracer, Box = Box}
end

for _, Player in pairs(Players:GetPlayers()) do
    HandlePlayer(Player)
end
Players.PlayerAdded:Connect(HandlePlayer)
Players.PlayerRemoving:Connect(function(Player: Player)
    Characters[Player] = nil
    local PlayerDrawings = Drawings[Player]
    for _, DrawObj in pairs(PlayerDrawings or {}) do
        DrawObj.Visible = false
    end
    Drawings[Player] = nil
end)

local SetProperties = function(Properties: {[string]: {[string]: any}})
    for Player, PlayerDrawings in pairs(Drawings) do
        if type(Player) ~= "number" then
            for Property, Value in pairs(Properties.Tracer or {}) do
                PlayerDrawings.Tracer[Property] = Value
            end
            for Property, Value in pairs(Properties.Text or {}) do
                PlayerDrawings.Text[Property] = Value
            end
            for Property, Value in pairs(Properties.Box or {}) do
                PlayerDrawings.Box[Property] = Value
            end
        end
    end
end

local randomised = random(1, 10)
local randomisedVector = Vector3new(random(1, 10), random(1, 10), random(1, 10))
Mouse.Move:Connect(function()
    randomised = random(1, 10)
    randomisedVector = Vector3new(random(1, 10), random(1, 10), random(1, 10))
end)

local ClosestCharacter: Model? = nil
local ClosestVector: Vector2? = nil
local ClosestPlayer: Player? = nil
local Aimlock: BasePart? = nil

local GetClosestPlayerAndRender = function(): (Model?, Vector2?, Player?, BasePart?)
    MouseVector = Vector2new(Mouse.X, Mouse.Y + Inset)
    local BestV2Dist = math.huge
    local BestV3Dist = math.huge
    local ResultChar: Model? = nil
    local ResultVec: Vector2? = nil
    local ResultPlayer: Player? = nil
    local ResultLock: BasePart? = nil

    if AimbotSettings.ShowFov then
        FOV.Position = MouseVector
        FOV.Visible = true
        Snaplines.Visible = false
    else
        FOV.Visible = false
    end

    local LocalRoot = Characters[LocalPlayer] and FindFirstChild(Characters[LocalPlayer], "HumanoidRootPart")

    for Player, Character in pairs(Characters) do
        if Player == LocalPlayer then continue end
        local PlayerDrawings = Drawings[Player]
        local PlayerRoot = FindFirstChild(Character, "HumanoidRootPart")
        local PlayerTeam = GetTeam(Player)

        if PlayerRoot then
            local Redirect = FindFirstChild(Character, AimbotSettings.Aimlock)
            if not Redirect then
                PlayerDrawings.Text.Visible = false
                PlayerDrawings.Box.Visible = false
                PlayerDrawings.Tracer.Visible = false
                continue
            end

            local RedirectPos = Redirect.Position
            local Tuple, Visible = WorldToViewportPoint(CurrentCamera, RedirectPos)
            local CharVec2 = Vector2new(Tuple.X, Tuple.Y)
            local V2Mag = (MouseVector - CharVec2).Magnitude
            local V3Mag = LocalRoot and (RedirectPos - LocalRoot.Position).Magnitude or math.huge
            local InRenderDistance = V3Mag <= EspSettings.RenderDistance

            if not Tfind(AimbotSettings.BlacklistedTeams, PlayerTeam) then
                if V2Mag <= FOV.Radius then
                    if Visible and V2Mag <= BestV2Dist and AimbotSettings.ClosestCursor then
                        BestV2Dist = V2Mag
                        ResultChar = Character
                        ResultVec = CharVec2
                        ResultPlayer = Player
                        ResultLock = Redirect
                        if AimbotSettings.Snaplines and AimbotSettings.ShowFov then
                            Snaplines.Visible = true
                            Snaplines.From = MouseVector
                            Snaplines.To = CharVec2
                        else
                            Snaplines.Visible = false
                        end
                    end
                    if Visible and V3Mag <= BestV3Dist and AimbotSettings.ClosestCharacter then
                        BestV3Dist = V3Mag
                        ResultChar = Character
                        ResultVec = CharVec2
                        ResultPlayer = Player
                        ResultLock = Redirect
                    end
                end
            end

            if InRenderDistance and Visible and not Tfind(EspSettings.BlacklistedTeams, PlayerTeam) then
                local Humanoid = FindFirstChildWhichIsA(Character, "Humanoid") or {Health = 0, MaxHealth = 0}
                PlayerDrawings.Text.Text = format("%s\n%s%s",
                    EspSettings.NamesEnabled and Player.Name or "",
                    EspSettings.DistanceEnabled and format("[%s]", floor(V3Mag)) or "",
                    EspSettings.HealthEnabled and format(" [%s/%s]", floor(Humanoid.Health), floor(Humanoid.MaxHealth)) or ""
                )
                PlayerDrawings.Text.Position = Vector2new(Tuple.X, Tuple.Y - 40)

                if EspSettings.TracersEnabled then
                    PlayerDrawings.Tracer.To = CharVec2
                end

                if EspSettings.BoxEsp then
                    local Parts = {}
                    for _, Part in pairs(Character:GetChildren()) do
                        if IsA(Part, "BasePart") then
                            local VP = WorldToViewportPoint(CurrentCamera, Part.Position)
                            Parts[Part] = Vector2new(VP.X, VP.Y)
                        end
                    end

                    local function closestTo(target: Vector2): Vector2?
                        local best: Vector2? = nil
                        local bestDist = math.huge
                        for _, Pos in next, Parts do
                            local d = (Pos - target).Magnitude
                            if d < bestDist then
                                bestDist = d
                                best = Pos
                            end
                        end
                        return best
                    end

                    local VS = CurrentCamera.ViewportSize
                    local Top = closestTo(Vector2new(Tuple.X, 0))
                    local Bottom = closestTo(Vector2new(Tuple.X, VS.Y))
                    local Left = closestTo(Vector2new(0, Tuple.Y))
                    local Right = closestTo(Vector2new(VS.X, Tuple.Y))

                    if Top and Bottom and Left and Right then
                        PlayerDrawings.Box.PointA = Vector2new(Right.X, Top.Y)
                        PlayerDrawings.Box.PointB = Vector2new(Left.X, Top.Y)
                        PlayerDrawings.Box.PointC = Vector2new(Left.X, Bottom.Y)
                        PlayerDrawings.Box.PointD = Vector2new(Right.X, Bottom.Y)
                    end
                end

                if EspSettings.TeamColors then
                    local TeamColor: Color3
                    if PlayerTeam then
                        TeamColor = PlayerTeam.TeamColor.Color
                    else
                        TeamColor = Color3new(0.639216, 0.635294, 0.647059)
                    end
                    PlayerDrawings.Text.Color = TeamColor
                    PlayerDrawings.Box.Color = TeamColor
                    PlayerDrawings.Tracer.Color = TeamColor
                end

                PlayerDrawings.Text.Visible = true
                PlayerDrawings.Box.Visible = EspSettings.BoxEsp
                PlayerDrawings.Tracer.Visible = EspSettings.TracersEnabled
            else
                PlayerDrawings.Text.Visible = false
                PlayerDrawings.Box.Visible = false
                PlayerDrawings.Tracer.Visible = false
            end
        else
            PlayerDrawings.Text.Visible = false
            PlayerDrawings.Box.Visible = false
            PlayerDrawings.Tracer.Visible = false
        end
    end

    return ResultChar, ResultVec, ResultPlayer, ResultLock
end

-- Undetected direct metatable hooks (no hookmetamethod/newcclosure)
gmt.__index = function(self, property)
    if ClosestPlayer and Aimlock and self == Mouse and not checkcaller() then
        local CallingScript = getfenv(2).script
        if CallingScript and CallingScript.Name == "CallingScript" then
            return oldIndex(self, property)
        end

        local Index = property
        if type(Index) == "string" then
            Index = gsub(sub(Index, 0, 100), "%z.*", "")
        end

        local PassedChance = random(1, 100) < AimbotSettings.SilentAimHitChance
        if PassedChance and AimbotSettings.SilentAim then
            local Parts = GetPartsObscuringTarget(CurrentCamera, {CurrentCamera.CFrame.Position, Aimlock.Position}, {LocalPlayer.Character, ClosestCharacter})
            Index = gsub(Index, "^%l", upper)
            local Hit = #Parts == 0 or AimbotSettings.Wallbang
            if not Hit then
                return oldIndex(self, property)
            end
            if Index == "Target" then return Aimlock end
            if Index == "Hit" then
                local hit = oldIndex(self, property)
                local pos = Aimlock.Position + randomisedVector / 10
                return CFramenew(pos.X, pos.Y, pos.Z, select(4, hit:components()))
            end
            if Index == "X" then return ClosestVector.X + randomised / 10 end
            if Index == "Y" then return ClosestVector.Y + randomised / 10 end
        end
    end
    return oldIndex(self, property)
end

local HookedFunctions: {[string]: {any}} = {}

gmt.__namecall = function(self, ...)
    local Method = gsub(getnamecallmethod() or "", "^%l", upper)
    local Hooked = HookedFunctions[Method]
    if Hooked and self == Hooked[1] then
        return Hooked[3](self, ...)
    end
    return oldNamecall(self, ...)
end

setreadonly(gmt, true)

HookedFunctions.FindPartOnRay = {Workspace, Workspace.FindPartOnRay, function(...)
    local old = HookedFunctions.FindPartOnRay[4]
    if AimbotSettings.SilentAim and ClosestPlayer and Aimlock and not checkcaller() then
        if ClosestCharacter and random(1, 100) < AimbotSettings.SilentAimHitChance then
            local Parts = GetPartsObscuringTarget(CurrentCamera, {CurrentCamera.CFrame.Position, Aimlock.Position}, {LocalPlayer.Character, ClosestCharacter})
            if #Parts == 0 or AimbotSettings.Wallbang then
                return Aimlock, Aimlock.Position + Vector3new(random(1,10),random(1,10),random(1,10))/10, Vector3new(0,1,0), Aimlock.Material
            end
        end
    end
    return old(...)
end}

HookedFunctions.FindPartOnRayWithIgnoreList = {Workspace, Workspace.FindPartOnRayWithIgnoreList, function(...)
    local old = HookedFunctions.FindPartOnRayWithIgnoreList[4]
    if ClosestPlayer and Aimlock and not checkcaller() then
        local CS = getcallingscript()
        if CS and CS.Name ~= "ControlModule" and ClosestCharacter and random(1,100) < AimbotSettings.SilentAimHitChance then
            local Parts = GetPartsObscuringTarget(CurrentCamera, {CurrentCamera.CFrame.Position, Aimlock.Position}, {LocalPlayer.Character, ClosestCharacter})
            if #Parts == 0 or AimbotSettings.Wallbang then
                return Aimlock, Aimlock.Position + Vector3new(random(1,10),random(1,10),random(1,10))/10, Vector3new(0,1,0), Aimlock.Material
            end
        end
    end
    return old(...)
end}

for _, Func in pairs(HookedFunctions) do
    Func[4] = hookfunction(Func[2], Func[3])
end

local Locked = false
local SwitchedCamera = false

UIS.InputBegan:Connect(function(Inp)
    if AimbotSettings.Enabled and Inp.UserInputType == Enum.UserInputType.MouseButton2 then
        Locked = true
        if AimbotSettings.FirstPerson and LocalPlayer.CameraMode ~= Enum.CameraMode.LockFirstPerson then
            LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
            SwitchedCamera = true
        end
    end
end)
UIS.InputEnded:Connect(function(Inp)
    if AimbotSettings.Enabled and Inp.UserInputType == Enum.UserInputType.MouseButton2 then
        Locked = false
        if SwitchedCamera then
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
            SwitchedCamera = false
        end
    end
end)

RS.RenderStepped:Connect(function()
    ClosestCharacter, ClosestVector, ClosestPlayer, Aimlock = GetClosestPlayerAndRender()
    if Locked and AimbotSettings.Enabled and ClosestCharacter and ClosestVector then
        if AimbotSettings.FirstPerson then
            CurrentCamera.CoordinateFrame = CFramenew(CurrentCamera.CoordinateFrame.p, Aimlock.Position)
        elseif AimbotSettings.ThirdPerson then
            mousemoveabs(ClosestVector.X, ClosestVector.Y)
        end
    end
end)

local MainUI = UILibrary.new(Color3.fromRGB(255, 79, 87))
local Window = MainUI:LoadWindow('<font color="#ff4f57">fates</font> esp', UDim2.fromOffset(400, 279))
local EspPage = Window.NewPage("esp")
local AimbotPage = Window.NewPage("aimbot")
local EspSection = EspPage.NewSection("Esp")
local TracerSection = EspPage.NewSection("Tracers")
local SilentAimSection = AimbotPage.NewSection("Silent Aim")
local AimbotSection = AimbotPage.NewSection("Aimbot")

EspSection.Toggle("Show Names", EspSettings.NamesEnabled, function(v) EspSettings.NamesEnabled = v end)
EspSection.Toggle("Show Health", EspSettings.HealthEnabled, function(v) EspSettings.HealthEnabled = v end)
EspSection.Toggle("Show Distance", EspSettings.DistanceEnabled, function(v) EspSettings.DistanceEnabled = v end)
EspSection.Toggle("Box Esp", EspSettings.BoxEsp, function(v)
    EspSettings.BoxEsp = v
    SetProperties({Box = {Visible = v}})
end)
EspSection.Slider("Render Distance", {Min=0,Max=50000,Default=math.clamp(EspSettings.RenderDistance,0,50000),Step=10}, function(v) EspSettings.RenderDistance = v end)
EspSection.Slider("Esp Size", {Min=0,Max=30,Default=EspSettings.Size,Step=1}, function(v)
    EspSettings.Size = v
    SetProperties({Text = {Size = v}})
end)
EspSection.ColorPicker("Esp Color", EspSettings.Color, function(v)
    EspSettings.TeamColors = false
    EspSettings.Color = v
    SetProperties({Box={Color=v},Text={Color=v},Tracer={Color=v}})
end)
EspSection.Toggle("Team Colors", EspSettings.TeamColors, function(v)
    EspSettings.TeamColors = v
    if not v then
        SetProperties({Tracer={Color=EspSettings.Color},Box={Color=EspSettings.Color},Text={Color=EspSettings.Color}})
    end
end)
EspSection.Dropdown("Teams", {"Allies","Enemies","All"}, function(v)
    table.clear(EspSettings.BlacklistedTeams)
    if v == "Enemies" then
        table.insert(EspSettings.BlacklistedTeams, LocalPlayer.Team)
    elseif v == "Allies" then
        local AllTeams = Teams:GetTeams()
        table.remove(AllTeams, table.find(AllTeams, LocalPlayer.Team))
        EspSettings.BlacklistedTeams = AllTeams
    end
end)

TracerSection.Toggle("Enable Tracers", EspSettings.TracersEnabled, function(v)
    EspSettings.TracersEnabled = v
    SetProperties({Tracer={Visible=v}})
end)
TracerSection.Dropdown("To", {"Head","Torso"}, function(v)
    AimbotSettings.Aimlock = v == "Torso" and "HumanoidRootPart" or v
end)
TracerSection.Dropdown("From", {"Top","Bottom","Left","Right"}, function(v)
    local VS = CurrentCamera.ViewportSize
    local From = v == "Top" and Vector2new(VS.X/2, 0)
        or v == "Bottom" and Vector2new(VS.X/2, VS.Y)
        or v == "Left" and Vector2new(0, VS.Y/2)
        or Vector2new(VS.X, VS.Y/2)
    EspSettings.TracerFrom = From
    SetProperties({Tracer={From=From}})
end)
TracerSection.Slider("Tracer Transparency", {Min=0,Max=1,Default=EspSettings.TracerTrancparency,Step=0.1}, function(v)
    EspSettings.TracerTrancparency = v
    SetProperties({Tracer={Transparency=v}})
end)
TracerSection.Slider("Tracer Thickness", {Min=0,Max=5,Default=EspSettings.TracerThickness,Step=0.1}, function(v)
    EspSettings.TracerThickness = v
    SetProperties({Tracer={Thickness=v}})
end)

SilentAimSection.Toggle("Silent Aim", AimbotSettings.SilentAim, function(v) AimbotSettings.SilentAim = v end)
SilentAimSection.Toggle("Wallbang", AimbotSettings.Wallbang, function(v) AimbotSettings.Wallbang = v end)
SilentAimSection.Dropdown("Redirect", {"Head","Torso"}, function(v) AimbotSettings.SilentAimRedirect = v end)
SilentAimSection.Slider("Hit Chance", {Min=0,Max=100,Default=AimbotSettings.SilentAimHitChance,Step=1}, function(v) AimbotSettings.SilentAimHitChance = v end)
SilentAimSection.Dropdown("Lock Type", {"Closest Cursor","Closest Player"}, function(v)
    if v == "Closest Cursor" then
        AimbotSettings.ClosestCharacter = false
        AimbotSettings.ClosestCursor = true
    else
        AimbotSettings.ClosestCharacter = true
        AimbotSettings.ClosestCursor = false
    end
end)

AimbotSection.Toggle("Aimbot (M2)", AimbotSettings.Enabled, function(v)
    AimbotSettings.Enabled = v
    if not AimbotSettings.FirstPerson and not AimbotSettings.ThirdPerson then
        AimbotSettings.FirstPerson = true
    end
end)
AimbotSection.Slider("Aimbot Smoothness", {Min=1,Max=10,Default=AimbotSettings.Smoothness,Step=0.5}, function(v) AimbotSettings.Smoothness = v end)

local sortTeams = function(v: string)
    table.clear(AimbotSettings.BlacklistedTeams)
    if v == "Enemies" then
        table.insert(AimbotSettings.BlacklistedTeams, LocalPlayer.Team)
    elseif v == "Allies" then
        local AllTeams = Teams:GetTeams()
        table.remove(AllTeams, table.find(AllTeams, LocalPlayer.Team))
        AimbotSettings.BlacklistedTeams = AllTeams
    end
end
AimbotSection.Dropdown("Team Target", {"Allies","Enemies","All"}, sortTeams)
sortTeams("Enemies")

AimbotSection.Dropdown("Aimlock Type", {"Third Person","First Person"}, function(v)
    AimbotSettings.ThirdPerson = v == "Third Person"
    AimbotSettings.FirstPerson = v == "First Person"
end)
AimbotSection.Toggle("Show Fov", AimbotSettings.ShowFov, function(v)
    AimbotSettings.ShowFov = v
    FOV.Visible = v
end)
AimbotSection.ColorPicker("Fov Color", AimbotSettings.FovColor, function(v)
    AimbotSettings.FovColor = v
    FOV.Color = v
    Snaplines.Color = v
end)
AimbotSection.Slider("Fov Size", {Min=70,Max=500,Default=AimbotSettings.FovSize,Step=10}, function(v)
    AimbotSettings.FovSize = v
    FOV.Radius = v
end)
AimbotSection.Toggle("Enable Snaplines", AimbotSettings.Snaplines, function(v) AimbotSettings.Snaplines = v end)

Window.SetPosition(Settings.WindowPosition)

if gethui then
    MainUI.UI.Parent = gethui()
else
    local protectGui = (syn or getgenv()).protect_gui
    if protectGui then
        protectGui(MainUI.UI)
    end
    MainUI.UI.Parent = game:GetService("CoreGui")
end

while task.wait(5) do
    Settings.WindowPosition = Window.GetPosition()
    writefile("fates-esp.json", HS:JSONEncode(EncodeConfig(Settings)))
end

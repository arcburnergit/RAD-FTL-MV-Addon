mods.rad = {}

-----------------------
-- UTILITY FUNCTIONS --
-----------------------
--[[
local slot1X = 117
local slot2X = slot1X+97
local slot3X = slot2X+97
local slot4X = slot3X+97
local slotY = 623
local slot1oh1 = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_1.png", slot1X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local slot1oh2 = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_2.png", slot1X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local slot1oh3 = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_3.png", slot1X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local slot1oh4 = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_4.png", slot1X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local slot1oh5 = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_5.png", slot1X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local slot1oh6 = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_6.png", slot1X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local slot1oh7 = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_7.png", slot1X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local slot1oh8 = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_8.png", slot1X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local slot1oh9 = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_9.png", slot1X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
local slot1oh10 = Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_10.png", slot1X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false)
]]


-- Get a table for a userdata value by name
local function userdata_table(userdata, tableName)
    if not userdata.table[tableName] then userdata.table[tableName] = {} end
    return userdata.table[tableName]
end

local function vter(cvec)
    local i = -1
    local n = cvec:size()
    return function()
        i = i + 1
        if i < n then return cvec[i] end
    end
end

-- Find ID of a room at the given location
local function get_room_at_location(shipManager, location, includeWalls)
    return Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId):GetSelectedRoom(location.x, location.y, includeWalls)
end

-- Returns a table of all crew belonging to the given ship on the room tile at the given point
local function get_ship_crew_point(shipManager, x, y, maxCount)
    res = {}
    x = x//35
    y = y//35
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and x == crewmem.x//35 and y == crewmem.y//35 then
            table.insert(res, crewmem)
            if maxCount and #res >= maxCount then
                return res
            end
        end
    end
    return res
end

local function get_ship_crew_room(shipManager, roomId)
    local radCrewList = {}
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == shipManager.iShipId and crewmem.iRoomId == roomId then
            table.insert(radCrewList, crewmem)
        end
    end
    return radCrewList
end

-- Returns a table where the indices are the IDs of all rooms adjacent to the given room
-- and the values are the rooms' coordinates
local function get_adjacent_rooms(shipId, roomId, diagonals)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipId)
    local roomShape = shipGraph:GetRoomShape(roomId)
    local adjacentRooms = {}
    local currentRoom = nil
    local function check_for_room(x, y)
        currentRoom = shipGraph:GetSelectedRoom(x, y, false)
        if currentRoom > -1 and not adjacentRooms[currentRoom] then
            adjacentRooms[currentRoom] = Hyperspace.Pointf(x, y)
        end
    end
    for offset = 0, roomShape.w - 35, 35 do
        check_for_room(roomShape.x + offset + 17, roomShape.y - 17)
        check_for_room(roomShape.x + offset + 17, roomShape.y + roomShape.h + 17)
    end
    for offset = 0, roomShape.h - 35, 35 do
        check_for_room(roomShape.x - 17,               roomShape.y + offset + 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + offset + 17)
    end
    if diagonals then
        check_for_room(roomShape.x - 17,               roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y - 17)
        check_for_room(roomShape.x + roomShape.w + 17, roomShape.y + roomShape.h + 17)
        check_for_room(roomShape.x - 17,               roomShape.y + roomShape.h + 17)
    end
    return adjacentRooms
end

local function offset_point_direction(oldX, oldY, angle, distance)
    local newX = oldX + (distance * math.cos(math.rad(angle)))
    local newY = oldY + (distance * math.sin(math.rad(angle)))
    return Hyperspace.Pointf(newX, newY)
end

--[[
int iDamage;
int iShieldPiercing;
int fireChance;
int breachChance;
int stunChance;
int iIonDamage;
int iSystemDamage;
int iPersDamage;
bool bHullBuster;
int ownerId;
int selfId;
bool bLockdown;
bool crystalShard;
bool bFriendlyFire;
int iStun;]]--

-----------
-- LOGIC --
-----------


mods.rad.aoeWeapons = {}
local aoeWeapons = mods.rad.aoeWeapons
aoeWeapons["RAD_CLUSTER_MISSILE"] = Hyperspace.Damage()
aoeWeapons["RAD_CLUSTER_MISSILE"].iSystemDamage = 2
aoeWeapons["RAD_CLUSTER_MISSILE"].iPersDamage = 1
aoeWeapons["RAD_CLUSTER_MISSILE_2"] = Hyperspace.Damage()
aoeWeapons["RAD_CLUSTER_MISSILE_2"].iDamage = 1
aoeWeapons["RAD_CLUSTER_MISSILE_2"].iSystemDamage = 1
aoeWeapons["RAD_CLUSTER_MISSILE_2"].iPersDamage = 2
aoeWeapons["RAD_CLUSTER_MISSILE_3"] = Hyperspace.Damage()
aoeWeapons["RAD_CLUSTER_MISSILE_3"].iDamage = 2
aoeWeapons["RAD_CLUSTER_MISSILE_3"].iSystemDamage = 1
aoeWeapons["RAD_CLUSTER_MISSILE_3"].iPersDamage = 2
aoeWeapons["RAD_CLUSTER_MISSILE_3"].bLockdown = true

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local weaponName = nil
    pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    local aoeDamage = aoeWeapons[weaponName]
    if aoeDamage then
        Hyperspace.Get_Projectile_Extend(projectile).name = ""
        for roomId, roomPos in pairs(get_adjacent_rooms(shipManager.iShipId, get_room_at_location(shipManager, location, false), false)) do
            shipManager:DamageArea(roomPos, aoeDamage, true)
        end
        Hyperspace.Get_Projectile_Extend(projectile).name = weaponName
    end
end)

mods.rad.teleWeapons = {}
local teleWeapons = mods.rad.teleWeapons
teleWeapons["RAD_ABDUCTOR"] = 15
teleWeapons["RAD_ABDUCTOR_ENEMY"] = 10
teleWeapons["RAD_JAILERBEAM_PLAYER"] = 30

-- Handle teleportation beams
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    local teleControl = teleWeapons[projectile.extend.name]
    local otherShip = Hyperspace.Global.GetInstance():GetShipManager((shipManager.iShipId + 1)%2)
    local weaponRoomID = otherShip:GetSystemRoom(3)
    if teleControl then
        for i, crewmem in ipairs(get_ship_crew_point(shipManager, location.x, location.y)) do
            userdata_table(crewmem, "mods.tpbeam.time").tpTime = teleControl
            crewmem.extend:InitiateTeleport(otherShip.iShipId,weaponRoomID,0)
        end
    end
    return Defines.Chain.CONTINUE, beamHitType
end)

--make list, make local version of list, set value in list to the room that you want to teleport them to, with a key of a weapon name
mods.rad.jailEnemyWeapons = {}
local jailEnemyWeapons = mods.rad.jailEnemyWeapons
jailEnemyWeapons["RAD_JAILERBEAM"] = 9

-- Handle teleportation beams
script.on_internal_event(Defines.InternalEvents.DAMAGE_BEAM, function(shipManager, projectile, location, damage, realNewTile, beamHitType)
    local jailControl = jailEnemyWeapons[projectile.extend.name]
    local otherShip = Hyperspace.Global.GetInstance():GetShipManager((shipManager.iShipId + 1)%2)
    local weaponRoomID = otherShip:GetSystemRoom(3)
    if jailControl then
        local hitRoomId = get_room_at_location(shipManager,location,false)
        for i, crewmem in ipairs(get_ship_crew_room(shipManager, hitRoomId)) do
            userdata_table(crewmem, "mods.tpbeam.time").tpTime = 30
            crewmem.extend:InitiateTeleport(otherShip.iShipId,jailControl,0)
        end
    end
    return Defines.Chain.CONTINUE, beamHitType
end)

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    local teleTable = userdata_table(crewmem, "mods.tpbeam.time")
    if teleTable.tpTime then
        if crewmem.bDead then
            teleTable.tpTime = nil
        else
            teleTable.tpTime = math.max(teleTable.tpTime - Hyperspace.FPS.SpeedFactor/16, 0)
            if teleTable.tpTime == 0 then
                crewmem.extend:InitiateTeleport(crewmem.iShipId,0,0)
                teleTable.tpTime = nil
            end
        end
    end
end)

mods.rad.overheatWeapons = {}
local overheatWeapons = mods.rad.overheatWeapons
overheatWeapons["RAD_GATLING"] = true

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    for weapon in vter(shipManager:GetWeaponList()) do
        pcall(function() weaponData = overheatWeapons[weapon.blueprint.name] end)
        if weaponData then
            weapon.boostLevel = 1
            userdata_table(weapon, "mods.rad.overHeatShots").amount = weapon.boostLevel
            userdata_table(weapon, "mods.rad.overHeatShots").timer = 1
            userdata_table(weapon, "mods.rad.overHeatShots").timerLast = 1
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function (shipManager)
    for weapon in vter(shipManager:GetWeaponList()) do
        pcall(function() weaponData = overheatWeapons[weapon.blueprint.name] end)
        if weaponData then
            local oHTable = userdata_table(weapon, "mods.rad.overHeatShots")
            if oHTable.amount then
                if weapon.boostLevel ~= oHTable.amount then
                    weapon.boostLevel = oHTable.amount
                end
                if weapon.boostLevel > 0 and weapon:IsChargedGoal() and oHTable.timer then
                    oHTable.timer = oHTable.timer - Hyperspace.FPS.SpeedFactor/16
                    if oHTable.timer <= 0 then
                        userdata_table(weapon, "mods.rad.overHeatShots").timer = math.max(oHTable.timerLast * 0.8, 0.05)
                        userdata_table(weapon, "mods.rad.overHeatShots").timerLast = math.max(oHTable.timerLast * 0.8, 0.05)
                        weapon.boostLevel = weapon.boostLevel - 1
                        userdata_table(weapon, "mods.rad.overHeatShots").amount = weapon.boostLevel
                    end
                else
                    userdata_table(weapon, "mods.rad.overHeatShots").timer = 1
                    userdata_table(weapon, "mods.rad.overHeatShots").timerLast = 1
                end
            else
                userdata_table(weapon, "mods.rad.overHeatShots").amount = weapon.boostLevel
                userdata_table(weapon, "mods.rad.overHeatShots").timer = 1
                userdata_table(weapon, "mods.rad.overHeatShots").timerLast = 1
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.WEAPON_RENDERBOX, function(weapon, cooldown, maxCooldown, firstLine, secondLine, thirdLine)
    --print(firstLine.."|"..secondLine.."|"..thirdLine)
    pcall(function() weaponData = overheatWeapons[weapon.blueprint.name] end)
    if weaponData then
        local oHTable = userdata_table(weapon, "mods.rad.overHeatShots")
        if oHTable.timer then
            if oHTable.timer < oHTable.timerLast then
                secondLine = tostring(math.ceil(oHTable.timer*10)/10).."s to Cooldown"
            end
        end
    end
    return Defines.Chain.CONTINUE, firstLine, secondLine, thirdLine
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local overHeatData = nil
    pcall(function() overHeatData = overheatWeapons[weapon.blueprint.name] end)
    if overHeatData then
        local oHTable = userdata_table(weapon, "mods.rad.overHeatShots")
        if oHTable.amount then
            if weapon.boostLevel < 50 then
                weapon.boostLevel = weapon.boostLevel + 1
                userdata_table(weapon, "mods.rad.overHeatShots").amount = weapon.boostLevel
            end
        else
            userdata_table(weapon, "mods.rad.overHeatShots").amount = weapon.boostLevel
            userdata_table(weapon, "mods.rad.overHeatShots").timer = 1
            userdata_table(weapon, "mods.rad.overHeatShots").timerLast = 1
        end
    end
end)

mods.rad.fireSpreaders = {}
local fireSpreaders = mods.rad.fireSpreaders
fireSpreaders["phantom_experiment_alpha"] = 1

--[[script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    log("CREWLOOOP AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA")
    log(crewmem.type)
    local fireSpreader = nil
    pcall(function() fireSpreader = fireSpreaders[crewmem.type] end)
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(crewmem.iShipId)
    --local fireDamage = Hyperspace.Damage()
    --fireDamage.fireChance = 2
    if fireSpreader then
        log(crewmem.type.."InFIRESPREADER")
        shipManager:StartFire(crewmem.iRoomId)
        --[[
        local fSTable = userdata_table(crewmem, "mods.fireSpreaders.fstime")
        if fSTable.fSTime then
            fSTable.fSTime = math.max(fSTable.fSTime - Hyperspace.FPS.SpeedFactor/16, 0)
            if fSTable.fSTime == 0 then 
                shipManager:DamageArea(crewmem:GetLocation(), fireDamage, false)
                fSTable.fSTime = fireSpreader
            end
        else
            userdata_table(crewmem, "mods.fireSpreaders.fstime").fSTime = fireSpreader
        end]

    end
end)]]

mods.rad.burstPinpoints = {}
local burstPinpoints = mods.rad.burstPinpoints
burstPinpoints["RAD_BEAM_BURST_1"] = "RAD_PROJECTILE_BEAM_FOCUS_1"
burstPinpoints["RAD_BEAM_BURST_2"] = "RAD_PROJECTILE_BEAM_FOCUS_1"
burstPinpoints["RAD_BEAM_BURST_3"] = "RAD_PROJECTILE_BEAM_FOCUS_1"
burstPinpoints["RAD_LIGHT_BEAM"] = "RAD_PROJECTILE_BEAM_FOCUS_0"

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    if weapon.blueprint and burstPinpoints[weapon.blueprint.name] then
        local burstPinpointBlueprint = Hyperspace.Blueprints:GetWeaponBlueprint(burstPinpoints[weapon.blueprint.name])

        local spaceManager = Hyperspace.App.world.space
        local beam = spaceManager:CreateBeam(
            burstPinpointBlueprint, 
            projectile.position, 
            projectile.currentSpace, 
            projectile.ownerId, 
            projectile.target, 
            Hyperspace.Pointf(projectile.target.x, projectile.target.y + 1), 
            projectile.destinationSpace, 
            1, 
            -0.1)
        beam.sub_start = offset_point_direction(projectile.target.x, projectile.target.y, projectile.entryAngle, 600)
        projectile:Kill()
    end
end)

mods.rad.popPinpoints = {}
local burstPinpoints = mods.rad.popPinpoints
burstPinpoints["RAD_PROJECTILE_BEAM_FOCUS_1"] = {count = 1, countSuper = 1}
burstPinpoints["RAD_PROJECTILE_BEAM_FOCUS_0"] = {count = 1, countSuper = 1}
-- Pop shield bubbles
script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
    local shieldPower = shipManager.shieldSystem.shields.power
    local popData = burstPinpoints[projectile and projectile.extend and projectile.extend.name]
    if popData then
        if shieldPower.super.first > 0 then
            if popData.countSuper > 0 then
                shipManager.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, Hyperspace.Damage(), true)
                shieldPower.super.first = math.max(0, shieldPower.super.first - popData.countSuper)
            end
        else
            shipManager.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, Hyperspace.Damage(), true)
            shieldPower.first = math.max(0, shieldPower.first - popData.count)
        end
        projectile:Kill()
    end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint)
    if weaponBlueprint.name == "RAD_LASER_SMART" then
        local ship = Hyperspace.Global.GetInstance():GetShipManager(projectile.ownerId)
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager((projectile.ownerId + 1)%2)
        local targetRoom = nil

        if not otherShip:GetSystem(0):CompletelyDestroyed() then
            targetRoom = otherShip:GetSystemRoom(0)
        elseif not otherShip:GetSystem(3):CompletelyDestroyed() then
            targetRoom = otherShip:GetSystemRoom(3)
        elseif not otherShip:GetSystem(4):CompletelyDestroyed() then
            targetRoom = otherShip:GetSystemRoom(4)
        elseif not otherShip:GetSystem(10):CompletelyDestroyed() then
            targetRoom = otherShip:GetSystemRoom(10)
        elseif not otherShip:GetSystem(1):CompletelyDestroyed() then
            targetRoom = otherShip:GetSystemRoom(1)
        end
        
        -- Retarget the bomb to that room
        if targetRoom then
            projectile.target = otherShip:GetRoomCenter(targetRoom)
            userdata_table(projectile, "mods.radsmartlaser.comhead").notComputed = true
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.PROJECTILE_PRE, function(projectile)
    local weaponName = projectile.extend.name
    if weaponName == "RAD_LASER_SMART" then
        local chTable = userdata_table(projectile, "mods.radsmartlaser.comhead")
        if projectile.currentSpace == projectile.destinationSpace and chTable.notComputed then 
            chTable.notComputed = nil
            projectile:ComputeHeading()
        end
    end
end)

mods.rad.zsWeapons = {}
local zsWeapons = mods.rad.zsWeapons
zsWeapons["RAD_ZSGUN_1"] = 1
zsWeapons["RAD_ZSGUN_2"] = 2
zsWeapons["RAD_ZSGUN_3"] = 3

script.on_internal_event(Defines.InternalEvents.PROJECTILE_INITIALIZE, function(projectile, weaponBlueprint) 
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(projectile.ownerId)
    local zsData = nil
    if pcall(function() zsData = zsWeapons[Hyperspace.Get_Projectile_Extend(projectile).name] end) and zsData then
        sRecover = zsData
        while sRecover > 0 do 
            shipManager.shieldSystem:AddSuperShield(shipManager.shieldSystem.superUpLoc)
            sRecover = sRecover - 1
        end
        projectile:Kill()
    end
end)

mods.rad.lightningWeapons = {}
local lightningWeapons = mods.rad.lightningWeapons
lightningWeapons["RAD_LIGHTNING_1"] = Hyperspace.Damage()
lightningWeapons["RAD_LIGHTNING_1"].iSystemDamage = 1
lightningWeapons["RAD_LIGHTNING_1"].iShieldPiercing = 5
lightningWeapons["RAD_LIGHTNING_2"] = Hyperspace.Damage()
lightningWeapons["RAD_LIGHTNING_2"].iDamage = 1
lightningWeapons["RAD_LIGHTNING_2"].iShieldPiercing = 3
lightningWeapons["RAD_LIGHTNING_3"] = Hyperspace.Damage()
lightningWeapons["RAD_LIGHTNING_3"].iIonDamage = 1
lightningWeapons["RAD_LIGHTNING_3"].iDamage = 2
lightningWeapons["RAD_LIGHTNING_3"].iShieldPiercing = 2
lightningWeapons["RAD_LIGHTNING_ION"] = Hyperspace.Damage()
lightningWeapons["RAD_LIGHTNING_ION"].iIonDamage = 2
lightningWeapons["RAD_LIGHTNING_ION"].iShieldPiercing = 3
lightningWeapons["RAD_LIGHTNING_FIRE"] = Hyperspace.Damage()
lightningWeapons["RAD_LIGHTNING_FIRE"].fireChance = 5
lightningWeapons["RAD_LIGHTNING_FIRE"].iShieldPiercing = 3

local lightningBeam = Hyperspace.Blueprints:GetWeaponBlueprint("RAD_LIGHTNING_BEAM")
--local lastLocation = nil

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local weaponName = nil
    pcall(function() weaponName = Hyperspace.Get_Projectile_Extend(projectile).name end)
    local aoeDamage = lightningWeapons[weaponName]
    if aoeDamage then
        --log("lightning Hit")
        local lastLocation = location
        local loopCount = 0
        --userdata_table(shipManager, "mods.rad.lightning").jumps = aoeDamage.iShieldPiercing
        --userdata_table(shipManager, "mods.rad.lightning").damage = aoeDamage
        local jumptable = userdata_table(shipManager, "mods.rad.lightning")
        if jumptable.table == nil then
            jumptable.table = {}
        end
        --log("hit")
        --log(shipManager.iShipId)
        table.insert(jumptable.table, {aoeDamage, aoeDamage.iShieldPiercing, location.x, location.y, 0.1, projectile.currentSpace})
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    local jumptable = userdata_table(shipManager, "mods.rad.lightning")

    if jumptable.table then 
        --log("jumptable.table exists")
        --log(shipManager.iShipId)
        local removeTable = {}
        for k,v in pairs(jumptable.table) do
            --log("Inner Table Exists")
            local timer = v[5]
            timer = math.max(timer - Hyperspace.FPS.SpeedFactor/16, 0)
            --log(timer)
            if timer == 0 then
                --log("timer hits 0")
                local lastLocation = Hyperspace.Pointf(v[3],v[4])
                local aoeDamage = v[1]
                local countDown = v[2]
                local spaceSpace = v[6]

                local roomPositions = {}
                local tblSize = 0
                --log(lastLocation.x)
                --log(lastLocation.y)
                --log(get_room_at_location(shipManager,lastLocation,false))
                --Hyperspace.Get_Projectile_Extend(projectile).name = ""
                for roomId, roomPos in pairs(get_adjacent_rooms(shipManager.iShipId, get_room_at_location(shipManager, lastLocation, false), false)) do
                    table.insert(roomPositions, roomPos)
                    --log("add room")
                    tblSize = tblSize + 1
                end
                --log(tblSize)

                if tblSize > 0 then
                    local randomNumber = math.random(1, tblSize)
                    --log(randomNumber)
                    local randomRoom = roomPositions[randomNumber]

                    local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
                    local alpha = math.atan((randomRoom.y-lastLocation.y), (randomRoom.x-lastLocation.x))
                    local newX1 = randomRoom.x - 5 * math.cos(alpha)
                    local newX2 = randomRoom.x + 5 * math.cos(alpha)
                    local newY1 = randomRoom.y - 5 * math.sin(alpha)
                    local newY2 = randomRoom.y + 5 * math.sin(alpha)

                    local beam = spaceManager:CreateBeam(
                        lightningBeam, lastLocation, spaceSpace, ((shipManager.iShipId + 1)%2),
                        Hyperspace.Pointf(newX1, newY1), Hyperspace.Pointf(newX2, newY2),
                        spaceSpace, 10, 1.0)
                    --log(beam.timer)
                    --beam.lifespan = 10.0
                    --log(beam.lifespan)]]

                    shipManager:DamageArea(randomRoom, aoeDamage, true)
                    --Hyperspace.Get_Projectile_Extend(projectile).name = weaponName
                    --lastLocation = randomRoom
                    countDown = countDown - 1
                    if countDown == 0 then 
                        --log("TABLE fail no more jumps")
                        table.remove(jumptable.table, k)
                    else
                        local newEntry = {aoeDamage, countDown, randomRoom.x, randomRoom.y,0.4, spaceSpace}
                        jumptable.table[k] = newEntry
                    end
                else
                    --log("TABLE fail no rooms")
                    table.remove(jumptable.table, k)
                end
            else 
                jumptable.table[k][5] = timer 
            end 
        end
    end
end)

mods.rad.diffuseWeapons = {}
local diffuseWeapons = mods.rad.diffuseWeapons
diffuseWeapons["RAD_DIFFUSE_1"] = "rad_diff_shot"
diffuseWeapons["RAD_DIFFUSE_2"] = "rad_diff_shot"
diffuseWeapons["RAD_DIFFUSE_3"] = "rad_diff_shot"
diffuseWeapons["RAD_DIFFUSE_ION"] = "ion_4_shot"

script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response) 
    local diffData = nil
    --local otherShip = Hyperspace.Global.GetInstance():GetShipManager()
    if pcall(function() diffData = diffuseWeapons[Hyperspace.Get_Projectile_Extend(projectile).name] end) and diffData and shipManager.shieldSystem.shields.power.super.first <= 0 then
        local damage = projectile.damage
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local proj1 = spaceManager:CreateBurstProjectile(
            Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name),
            diffData,
            false,
            projectile.position,
            projectile.currentSpace,
            projectile.ownerId,
            get_random_point_in_radius(projectile.target, 10),
            projectile.destinationSpace,
            projectile.heading)
        local proj2 = spaceManager:CreateBurstProjectile(
            Hyperspace.Blueprints:GetWeaponBlueprint(projectile.extend.name),
            diffData,
            false,
            projectile.position,
            projectile.currentSpace,
            projectile.ownerId,
            get_random_point_in_radius(projectile.target, 10),
            projectile.destinationSpace,
            projectile.heading)
        proj1:SetDamage(damage)
        proj2:SetDamage(damage)
    end
end)
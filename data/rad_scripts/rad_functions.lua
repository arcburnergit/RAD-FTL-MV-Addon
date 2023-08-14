mods.rad = {}

-----------------------
-- UTILITY FUNCTIONS --
-----------------------


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

script.on_game_event("RAD_PIRATE_FIGHT_TRIGGER", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(1)
    for i, crewmem in ipairs(get_ship_crew_room(shipManager, 9)) do
        --log("in crewmem for loop jail")
        --userdata_table(crewmem, "mods.tpbeam.time").tpTime = 30
        crewmem.extend:InitiateTeleport(shipManager.iShipId,0,0)
    end
end)

script.on_game_event("RAD_JAILER_RETURN_CREW", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(1)
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.intruder == true then
            local teleTable = userdata_table(crewmem, "mods.tpbeam.time")
            if teleTable.tpTime then
                teleTable.tpTime = nil
            end
            crewmem.extend:InitiateTeleport(0,0,0)
        end
    end
end)

script.on_game_event("RAD_GHOST_BEFORE_FIGHT", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(1)
    for i=1,8 do 
        location = shipManager:GetRandomRoomCenter() 
        local damage = Hyperspace.Damage()
        damage.fireChance = 8
        shipManager:DamageArea(location, damage, true)
    end
end)

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
--aoeWeapons["RAD_SHRAPNEL_DAMAGE"] = Hyperspace.Damage()
--aoeWeapons["RAD_SHRAPNEL_DAMAGE"].iSystemDamage = 2

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
    --log("DAMAGE_BEAM ---------------------------------------------")
    if teleControl then
        --log("teleControl True")
        for i, crewmem in ipairs(get_ship_crew_point(shipManager, location.x, location.y)) do
            --log("in crewmem for loop")
            userdata_table(crewmem, "mods.tpbeam.time").tpTime = teleControl
            crewmem.extend:InitiateTeleport(otherShip.iShipId,weaponRoomID,0)
        end
    end
    return Defines.Chain.CONTINUE, beamHitType
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA_HIT, function(shipManager, projectile, location, damage, shipFriendlyFire)
    local teleControl = nil
    pcall(function() teleControl = teleWeapons[projectile.extend.name] end)
    --[[if false then
        local otherShip = Hyperspace.Global.GetInstance():GetShipManager((projectile.ownerId + 1)%2)
        local weaponRoomID = otherShip:GetSystemRoom(3)
        local roomId = get_room_at_location(shipManager, location, true)
        local mindControlledCrew = 0
        for crewmem in vter(shipManager.vCrewList) do
            local doControl = crewmem.iRoomId == roomId and
                              crewmem.currentShipId == shipManager.iShipId and
                              crewmem.iShipId ~= projectile.ownerId
            if doControl then
                if can_be_mind_controlled(crewmem) then
                    crewmem:SetMindControl(true)
                    local mcTable = userdata_table(crewmem, "mods.trc.crewStuff")
                    mcTable.mcTime = math.max(mindControl.duration, mcTable.mcTime or 0)
                    mindControlledCrew = mindControlledCrew + 1
                    if mindControl.limit and mindControlledCrew >= mindControl.limit then break end
                elseif resists_mind_control(crewmem) then
                    crewmem.bResisted = true
                end
            end
        end
    end]]
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
    --log("DAMAGE_BEAM jail ---------------------------------------------")
    if jailControl then
        --log("jailControl True")
        local hitRoomId = get_room_at_location(shipManager,location,false)
        --log("WHY WON'T YOU WORKKKKKKKKKKKKKKKKKKKKKKKKK")
        --log(tostring(hitRoomId))
        for i, crewmem in ipairs(get_ship_crew_room(shipManager, hitRoomId)) do
            --log("in crewmem for loop jail")
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
overheatWeapons["RAD_GATLING"] = {
    maxShots = 17,
    power = 3,
    cDown = 1
}
overheatWeapons["RAD_CHAINGUN_DAMAGE_ENEMY"] = {
    maxShots = 7,
    power = 2,
    cDown = 5
}

script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local overHeatData = nil
    pcall(function() overHeatData = overheatWeapons[weapon.blueprint.name] end)
    if overHeatData then
        --log("cooldown multiplyer, time | changeLevel | goalChargeLevel | IsChargeGoal | shot")
        local cooldown = weapon.cooldown
        --log(tostring(cooldown.first))
        --log(tostring(cooldown.second))
        --log(tostring(weapon.chargeLevel))
        --log(tostring(weapon.goalChargeLevel))
        --log(tostring(weapon:IsChargedGoal()))
        local oHTable = userdata_table(weapon, "mods.overheatweapons.shots")
        --log("oHTable.oHShots")
        --log(tostring(oHTable.oHShots))
        if oHTable.oHShots then
            local ship = Hyperspace.Global.GetInstance():GetShipManager(projectile.ownerId)
            local weaponPower = ship:GetSystemPower(3)
            local weaponSystem = ship:GetSystem(3)
            oHTable.oHShots = math.max(oHTable.oHShots - 1, 0)
            log("shots -------------------------------------------------------------------------------------------")
            log(tostring(oHTable.oHShots))
            --oHTable.oHper = 1 - (oHTable.oHShots/overHeatData.maxShots)
            if oHTable.oHShots == 0 then
                oHTable.oHShots = nil
                weapon.powered = false
                weapon.requiredPower = 16
                oHTable.oHCDown = overHeatData.cDown
            end
        else
            userdata_table(weapon, "mods.overheatweapons.shots").oHShots = overHeatData.maxShots
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.SHIP_LOOP, function(shipManager)
    local weaponData = nil
    --log("shiploop")
    for weapon in vter(shipManager:GetWeaponList()) do
        --log(tostring(weapon.blueprint.name))
        pcall(function() weaponData = overheatWeapons[weapon.blueprint.name] end)
        if weaponData then
            local oHTable = userdata_table(weapon, "mods.overheatweapons.shots")
            if oHTable.oHCDown then
                oHTable.oHCDown = math.max(oHTable.oHCDown - Hyperspace.FPS.SpeedFactor/16, 0)
                if oHTable.oHCDown == 0 then
                    oHTable.oHCDown = nil
                    weapon.requiredPower = weaponData.power
                    weapon.powered = true
                end
            end
        end
    end
end)

mods.rad.popWeapons = {}
local popWeapons = mods.rad.popWeapons
popWeapons["RAD_GATLING"] = {
    count = 1,
    countSuper = 1,
    delete = false
}
popWeapons["RAD_PROJECTILE_BEAM_FOCUS_1"] = {
    count =1,
    countSuper =1,
    delete = true
}

script.on_internal_event(Defines.InternalEvents.SHIELD_COLLISION, function(shipManager, projectile, damage, response)
    local shieldPower = shipManager.shieldSystem.shields.power
    local popData = nil
    if pcall(function() popData = popWeapons[Hyperspace.Get_Projectile_Extend(projectile).name] end) and popData then
        if shieldPower.super.first > 0 then
            if popData.countSuper > 0 then
                shipManager.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, Hyperspace.Damage(), true)
                shieldPower.super.first = math.max(0, shieldPower.super.first - popData.countSuper)
                if popData.delete == true then
                    projectile:Kill()
                end
            end
        else
            shipManager.shieldSystem:CollisionReal(projectile.position.x, projectile.position.y, Hyperspace.Damage(), true)
            shieldPower.first = math.max(0, shieldPower.first - popData.count)
            if popData.delete == true then
                projectile:Kill()
            end
        end
    end
end)

--[[mods.rad.fireSpreaders = {}
local fireSpreaders = mods.rad.fireSpreaders
fireSpreaders["phantom_experiment_alpha"] = 1

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
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
local pinpoint1 = Hyperspace.Blueprints:GetWeaponBlueprint("RAD_PROJECTILE_BEAM_FOCUS_1")
--local pinpoint2 = Hyperspace.Blueprints:GetWeaponBlueprint("RAD_PROJECTILE_BEAM_FOCUS_2")
local burstsToBeams = {}
burstsToBeams.RAD_BEAM_BURST_1 = pinpoint1
burstsToBeams.RAD_BEAM_BURST_2 = pinpoint1
burstsToBeams.RAD_BEAM_BURST_3 = pinpoint1
burstsToBeams.RAD_LIGHT_BEAM = pinpoint1
script.on_internal_event(Defines.InternalEvents.PROJECTILE_FIRE, function(projectile, weapon)
    local beamReplacement = burstsToBeams[weapon.blueprint.name]
    if beamReplacement then
        local spaceManager = Hyperspace.Global.GetInstance():GetCApp().world.space
        local beam = spaceManager:CreateBeam(
            beamReplacement, projectile.position, projectile.currentSpace, projectile.ownerId,
            projectile.target, Hyperspace.Pointf(projectile.target.x, projectile.target.y + 1),
            projectile.destinationSpace, 1, projectile.heading)
        beam.sub_start.x = 500*math.cos(projectile.entryAngle)
        beam.sub_start.y = 500*math.sin(projectile.entryAngle) 
        projectile:Kill()
    end
end)


script.on_render_event(Defines.RenderEvents.MOUSE_CONTROL, function()
    --log("RENDERSTART")
    local slot1X = 106
    local slotY = 623
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(0)
    local weaponlist = {}
    if shipManager then
        weaponlist = shipManager:GetWeaponList()
        for system in vter(shipManager.vSystemList) do
            if (system.iSystemType == 0 or system.iSystemType == 1 or system.iSystemType == 2 or system.iSystemType == 5 or system.iSystemType == 13) then
                slot1X = slot1X + 36
            elseif (system.iSystemType == 9 or system.iSystemType == 10 or system.iSystemType == 11 or system.iSystemType == 14 or system.iSystemType >= 15) then
                slot1X = slot1X + 54
            end
        end
    end
    local slot2X = slot1X+97
    local slot3X = slot2X+97
    local slot4X = slot3X+97
    local weaponData = nil
      
    --log("before")
    --log(weaponlist[0].blueprint.name)
    --if not weaponlist[0] then return end
    if weaponlist[0] then
        --log("render")
        pcall(function() weaponData = overheatWeapons[weaponlist[0].blueprint.name] end)
        if weaponData then
            --log("pass name check")
            local oHTable = userdata_table(weaponlist[0], "mods.overheatweapons.shots")
            if oHTable.oHShots then
                if oHTable.oHShots <= 10 then
                    local renderString = "statusUI/rad_overheat_"..tostring(oHTable.oHShots)..".png"
                    log(renderString)
                    Graphics.CSurface.GL_RenderPrimitive(Hyperspace.Resources:CreateImagePrimitiveString(renderString, slot1X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false))
                    --Graphics.CSurface.GL_RenderPrimitive(Hyperspace.Resources:CreateImagePrimitiveString(renderString, slot1X, 500, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false))
                end
            elseif oHTable.oHCDown then
                --log("on cooldown")
                Graphics.CSurface.GL_RenderPrimitive(Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_0.png", slot1X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false))
            end
        end
    end

    if weaponlist[1] then
        --log("render")
        pcall(function() weaponData = overheatWeapons[weaponlist[1].blueprint.name] end)
        if weaponData then
            --log("pass name check")
            local oHTable = userdata_table(weaponlist[1], "mods.overheatweapons.shots")
            if oHTable.oHShots then
                if oHTable.oHShots <= 10 then
                    local renderString = "statusUI/rad_overheat_"..tostring(oHTable.oHShots)..".png"
                    log(renderString)
                    Graphics.CSurface.GL_RenderPrimitive(Hyperspace.Resources:CreateImagePrimitiveString(renderString, slot2X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false))
                    --Graphics.CSurface.GL_RenderPrimitive(Hyperspace.Resources:CreateImagePrimitiveString(renderString, slot2X, 500, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false))
                end
            elseif oHTable.oHCDown then
                --log("on cooldown")
                Graphics.CSurface.GL_RenderPrimitive(Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_0.png", slot2X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false))
            end
        end
    end

    if weaponlist[2] then
        --log("render")
        pcall(function() weaponData = overheatWeapons[weaponlist[2].blueprint.name] end)
        if weaponData then
            --log("pass name check")
            local oHTable = userdata_table(weaponlist[2], "mods.overheatweapons.shots")
            if oHTable.oHShots then
                if oHTable.oHShots <= 10 then
                    local renderString = "statusUI/rad_overheat_"..tostring(oHTable.oHShots)..".png"
                    log(renderString)
                    Graphics.CSurface.GL_RenderPrimitive(Hyperspace.Resources:CreateImagePrimitiveString(renderString, slot3X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false))
                    --Graphics.CSurface.GL_RenderPrimitive(Hyperspace.Resources:CreateImagePrimitiveString(renderString, slot3X, 500, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false))
                end
            elseif oHTable.oHCDown then
                --log("on cooldown")
                Graphics.CSurface.GL_RenderPrimitive(Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_0.png", slot3X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false))
            end
        end
    end

    if weaponlist[3] then
        --log("render")
        pcall(function() weaponData = overheatWeapons[weaponlist[3].blueprint.name] end)
        if weaponData then
            --log("pass name check")
            local oHTable = userdata_table(weaponlist[3], "mods.overheatweapons.shots")
            if oHTable.oHShots then
                if oHTable.oHShots <= 10 then
                    local renderString = "statusUI/rad_overheat_"..tostring(oHTable.oHShots)..".png"
                    --log(renderString)
                    Graphics.CSurface.GL_RenderPrimitive(Hyperspace.Resources:CreateImagePrimitiveString(renderString, slot4X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false))
                    --Graphics.CSurface.GL_RenderPrimitive(Hyperspace.Resources:CreateImagePrimitiveString(renderString, slot4X, 500, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false))
                end
            elseif oHTable.oHCDown then
                --log("on cooldown")
                Graphics.CSurface.GL_RenderPrimitive(Hyperspace.Resources:CreateImagePrimitiveString("statusUI/rad_overheat_0.png", slot4X, slotY, 0, Graphics.GL_Color(1, 1, 1, 1), 1.0, false))
            end
        end
    end
end, function() end)

--script.on_internal_event(Defines)

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(shipManager)
    local weaponData = nil
    --log("shiploop")
    for weapon in vter(shipManager:GetWeaponList()) do
        --log(tostring(weapon.blueprint.name))
        pcall(function() weaponData = overheatWeapons[weapon.blueprint.name] end)
        if weaponData then
            local oHTable = userdata_table(weapon, "mods.overheatweapons.shots")
            if oHTable.oHShots then
                oHTable.oHShots = nil
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.DAMAGE_AREA, function(shipManager, projectile, location, damage, evasion, friendlyfire) 
    local roomId = get_room_at_location(shipManager, location, true)
    --log("damagearea -------------------------------------------------------------------")
    for i, crewmem in ipairs(get_ship_crew_room(shipManager, roomId)) do
        log(crewmem:GetSpecies())
        if crewmem:GetSpecies() == "drone_repulsor" and crewmem:Functional() then
            --log("projectile miss make")
            return Defines.Chain.CONTINUE, Defines.Evasion.MISS
        end
    end
end)


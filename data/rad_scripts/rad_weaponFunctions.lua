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
        userdata_table(crewmem, "mods.tpbeam.time").tpTime = 30
        crewmem.extend:InitiateTeleport(shipManager.iShipId,0,0)
    end
end)

script.on_game_event("RAD_JAILER_RETURN_CREW", false, function()
    local shipManager = Hyperspace.Global.GetInstance():GetShipManager(1)
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.intruder == true then
            crewmem.extend:InitiateTeleport(0,0,0)
        end
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
        log("WHY WON'T YOU WORKKKKKKKKKKKKKKKKKKKKKKKKK")
        log(tostring(hitRoomId))
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

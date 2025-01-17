local Logging = require("SharkPlanner.Utils.Logging")
local JSON = require("JSON")
local Position = require("SharkPlanner.Base.Position")

-- handle lua 5.4 deprecation
if table.unpack == nil then
table.unpack = unpack
end

local CoordinateData = {}
local EventTypes = {
    AddWayPoint = 1,
    RemoveWayPoint = 2,
    AddFixPoint = 3,
    RemoveFixPoint = 4,
    AddTargetPoint = 5,
    RemoveTargetPoint = 6,
    Reset = 7,
    FlightPlanSaved = 8,
    FlightPlanLoaded = 9,
    LocalCoordinatesRecalculated = 10
}
-- make event types visible to users
CoordinateData.EventTypes = EventTypes

function CoordinateData:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    o.wayPoints = {}
    o.fixPoints = {}
    o.targetPoints = {}
    o.planningPosition = nil
    o.eventHandlers = {
        [EventTypes.AddWayPoint] = {},
        [EventTypes.RemoveWayPoint] = {},
        [EventTypes.AddFixPoint] = {},
        [EventTypes.RemoveFixPoint] = {},
        [EventTypes.AddTargetPoint] = {},
        [EventTypes.RemoveTargetPoint] = {},
        [EventTypes.Reset] = {},
        [EventTypes.FlightPlanSaved] = {},
        [EventTypes.FlightPlanLoaded] = {},
        [EventTypes.LocalCoordinatesRecalculated] = {}
    }
    return o
end

function CoordinateData:createPlanningPosition()
    if #self.wayPoints == 0 or self.planningPosition == nil then
        local selfData = Export.LoGetSelfData()
        if selfData == nil then
            Logging.info("Own position could not be retrieved")
            self.planningPosition = nil
            return
        end
        local selfX = selfData["Position"]["x"]
        local selfZ = selfData["Position"]["z"]
        local selfLat, selfLong = Export.LoLoCoordinatesToGeoCoordinates(selfX, selfZ)
        local altitude = Export.LoGetAltitudeAboveSeaLevel()
        self.planningPosition = Position:new{x = selfX, y = altitude, z = selfZ, longitude = selfLong, latitude = selfLat }
    end
end

function CoordinateData:addWaypoint(wayPoint)
    self:createPlanningPosition()
    self.wayPoints[#self.wayPoints + 1] = wayPoint
    local eventArg = {
        planningPosition  = self.planningPosition,
        wayPoints = self.wayPoints,
        wayPoint = wayPoint,
        wayPointIndex = #self.wayPoints,
        elevationProfile = self:extractElevationProfile()
    }
    self:dispatchEvent(EventTypes.AddWayPoint, eventArg)
end

function CoordinateData:removeWaypoint(wayPointIndex)
    local wayPoint = table.remove(self.wayPoints, wayPointIndex)
    local eventArg = {
        wayPoints = self.wayPoints,
        wayPoint = wayPoint,
        wayPointIndex = wayPointIndex,
        elevationProfile = self:extractElevationProfile()
    }
    self:dispatchEvent(EventTypes.RemoveWayPoint, eventArg)
end

function CoordinateData:addFixpoint(fixPoint)
    self:createPlanningPosition()
    self.fixPoints[#self.fixPoints + 1] = fixPoint

    local eventArg = {
        planningPosition  = self.planningPosition,
        fixPoints = self.fixPoints,
        fixPoint = fixPoint,
        fixPointIndex = #self.fixPoints
    }
    self:dispatchEvent(EventTypes.AddFixPoint, eventArg)
end

function CoordinateData:removeFixpoint(fixPointIndex)
    local fixPoint = table.remove(self.fixPoints, fixPointIndex)
    local eventArg = {
        planningPosition  = self.planningPosition,
        fixPoints = self.fixPoints,
        fixPoint = fixPoint,
        fixPointIndex = fixPointIndex
    }
    self:dispatchEvent(EventTypes.RemoveFixPoint, eventArg)
end

function CoordinateData:addTargetpoint(targetPoint)
    self:createPlanningPosition()
    self.targetPoints[#self.targetPoints + 1] = targetPoint

    local eventArg = {
        targetPoints = self.targetPoints,
        targetPoint = targetPoint,
        targetPointIndex = #self.targetPoints
    }
    self:dispatchEvent(EventTypes.AddTargetPoint, eventArg)
end

function CoordinateData:removeTargetpoint(targetPointIndex)
    local targetPoint = table.remove(self.targetPoints, targetPointIndex)
    local eventArg = {
        targetPoints = self.targetPoints,
        targetPoint = targetPoint,
        targetPointIndex = targetPointIndex
    }
    self:dispatchEvent(EventTypes.RemoveTargetPoint, eventArg)
end

function CoordinateData:reset()
    self.wayPoints = {}
    self.fixPoints = {}
    self.targetPoints = {}
    self.planningPosition = nil
    local eventArg = {
        -- at the moment no actual need, but still needed for generic dispatchEvent method
        -- reserved for future use
    }
    self:dispatchEvent(EventTypes.Reset, eventArg)
end

function CoordinateData:save(filePath)
    local fp = io.open(filePath, 'w')
    if fp then
        fp:write(JSON:encode_pretty(
                {
                    ['wayPoints'] = self.wayPoints,
                    ['fixPoints'] = self.fixPoints,
                    ['targetPoints'] = self.targetPoints
                }
            )
        )
        fp:close()
        local eventArg = {
            -- leave empty for now
            filePath = filePath
        }
        Logging.info("Flight plan is saved.")
        self:dispatchEvent(EventTypes.FlightPlanSaved, eventArg)
    end
end

function CoordinateData:load(filePath)
    local fp = io.open(filePath, "r")
    if fp then
        self:reset()
        local rawBuffer = fp:read("*all")
        local flightPathInput = JSON:decode(rawBuffer)
        if flightPathInput.wayPoints then
            for i, v in ipairs(flightPathInput.wayPoints) do
                local position = Position:new(v)
                self:addWaypoint(position)
            end
        end
        if flightPathInput.fixPoints then
            for i, v in ipairs(flightPathInput.fixPoints) do
                local position = Position:new(v)
                self:addFixpoint(position)
            end
        end
        if flightPathInput.targetPoints then
            for i, v in ipairs(flightPathInput.targetPoints) do
                local position = Position:new(v)
                self:addTargetpoint(position)
            end
        end
        fp:close()
        local eventArg = {
            -- leave empty for now
            filePath = filePath
        }
        -- make sure that coordinates are recalculated (e.g. flight plan was loaded on different map)
        self:recalculateLocalCoordinates()
        Logging.info("Flight plan is loaded.")
        self:dispatchEvent(EventTypes.FlightPlanLoaded, eventArg)
    end
end

function CoordinateData:addEventHandler(eventType, object, eventHandler)
    self.eventHandlers[eventType][#self.eventHandlers[eventType] + 1] = { object = object, eventHandler = eventHandler }
end

-- the dispatchEvent for now executes directly the event handlers
function CoordinateData:dispatchEvent(eventType, eventArg)
    for k, eventHandlerInfo in pairs(self.eventHandlers[eventType]) do
        eventHandlerInfo.eventHandler(eventHandlerInfo.object, eventArg)
    end
end

function CoordinateData:normalize(commandGenerator)
    Logging.info("Normalizing data structures")
    -- no commandGenerator nothing to do
    if commandGenerator == nil then return end
    self.planningPosition = nil
    self:createPlanningPosition()
    -- trim number of waypoints
    Logging.info("Setting correct structure size")
    if #self.wayPoints > commandGenerator:getMaximalWaypointCount() then
        Logging.info("Prunning waypoints from "..#self.wayPoints.." to "..commandGenerator:getMaximalWaypointCount())        
        -- self.wayPoints = { table.unpack(self.wayPoints, 1, math.min(#self.wayPoints, commandGenerator:getMaximalWaypointCount())) }
        for i = #self.wayPoints, commandGenerator:getMaximalWaypointCount() + 1, -1 do
            self:removeWaypoint(i)
        end
        Logging.info("Result: "..#self.wayPoints)
    end
    if #self.fixPoints > commandGenerator:getMaximalFixPointCount() then
        Logging.info("Prunning fixpoints...")
        -- self.fixPoints = { table.unpack(self.fixPoints, 1, math.min(#self.fixPoints, commandGenerator:getMaximalFixPointCount())) }
        for i = #self.fixPoints, commandGenerator:getMaximalFixPointCount() + 1, -1 do
            self:removeFixpoint(i)
        end
        Logging.info("Result: "..#self.fixPoints)
    end
    if #self.targetPoints > commandGenerator:getMaximalTargetPointCount() then
        Logging.info("Prunning target points...")
        -- self.targetPoints = { table.unpack(self.targetPoints, 1, math.min(#self.targetPoints, commandGenerator:getMaximalTargetPointCount())) }
        for i = #self.targetPoints, commandGenerator:getMaximalTargetPointCount() + 1, -1 do
            self:removeTargetpoint(i)
        end
        Logging.info("Result: "..#self.targetPoints)
    end
end

function CoordinateData:OnPlayerEnteredSupportedVehicle(eventArgs)
    self:recalculateLocalCoordinates()
    self:createPlanningPosition()
end

function CoordinateData:recalculateLocalCoordinate(position)
    local localCoordinates = Export.LoGeoCoordinatesToLoCoordinates(position:getLongitude(), position:getLatitude())
    local elevation = Export.LoGetAltitude(localCoordinates.x, localCoordinates.z)
    Logging.debug(
        "Chekcing coordinates,  Lat: "..tostring(position:getLatitude())..
        " Long: "..tostring(position:getLongitude())..
        " X: "..tostring(position:getX())..
        " Z: "..tostring(position:getZ())
    )
    -- recalculate only if the coordinates differ or if it is nil
    if
        (
            position:getX() == nil or
            position:getZ() == nil
        )
        or
        (
            -- since there can be a numeric error in conversion, we do not wish to recalculate if difference is less than 1
            math.abs(localCoordinates.x - position:getX()) >= 1 or
            math.abs(localCoordinates.z - position:getZ()) >= 1
            -- localCoordinates.x ~= position:getX() or
            -- localCoordinates.z ~= position:getZ()
        )
    then
        Logging.debug("Updating coordinates,  Lat: "..tostring(position:getLatitude()).." Long: "..tostring(position:getLongitude()))
        position:setX(localCoordinates.x)
        position:setZ(localCoordinates.z)
        position:setY(elevation)
        return true
    end

    return false
end

function CoordinateData:recalculateLocalCoordinates()
    Logging.info("Recalculation initiated")
    local wayPointsRecalculated = false
    local fixPointsRecalculated = false
    local targetPointsRecalculated = false
    for i, position in ipairs(self.wayPoints) do
        Logging.debug("Recalculating waypoint: "..i)
        wayPointsRecalculated = self:recalculateLocalCoordinate(position) or wayPointsRecalculated
    end
    Logging.info("Waypoints recalculated: "..tostring(wayPointsRecalculated))
    for i, position in ipairs(self.fixPoints) do
        Logging.debug("Recalculating fixpoint: "..i)
        fixPointsRecalculated = self:recalculateLocalCoordinate(position) or fixPointsRecalculated
    end
    Logging.info("Fixpoints recalculated: "..tostring(fixPointsRecalculated))
    for i, position in ipairs(self.targetPoints) do
        Logging.debug("Recalculating targetpoint: "..i)
        targetPointsRecalculated = self:recalculateLocalCoordinate(position) or targetPointsRecalculated
    end
    Logging.info("Target points recalculated: "..tostring(targetPointsRecalculated))
    local overallResult = wayPointsRecalculated or fixPointsRecalculated or targetPointsRecalculated
    if overallResult then
        Logging.info("Recalculating occured, triggering event handlers")
        local eventArgs = {
            wayPoints = self.wayPoints,
            fixPoints = self.fixPoints,
            targetPoints = self.targetPoints,
            overallResult = overallResult,
            wayPointsRecalculated = wayPointsRecalculated,
            fixPointsRecalculated = fixPointsRecalculated,
            targetPointsRecalculated = targetPointsRecalculated
        }
        self:dispatchEvent(EventTypes.LocalCoordinatesRecalculated, eventArgs)
    end
end


function CoordinateData:extractSectionElevationProfile(elevations, startPoint, endPoint)
    -- calculate necessary variables:
    -- deltaX - distance on X
    -- deltaZ - distance on Z
    -- d - diagonal distance
    -- mX - X multiplicator
    -- mZ - Z multiplicator
    local deltaX = endPoint:getX() - startPoint:getX()
    local deltaZ = endPoint:getZ() - startPoint:getZ()
    local D = math.sqrt(
      math.pow(deltaX, 2) +
      math.pow(deltaZ, 2)
    )
    local mX = deltaX / D
    local mZ = deltaZ / D
    -- define step, this may need tweaking to improve performance 
    local step = 1
    -- move along diagonal and calculate points on it
    for d = 0, D, step do
      local x = startPoint:getX() + mX * d
      local z = startPoint:getZ() + mZ * d
      local elevation = terrain.GetHeight(x, z)
      --Logging.info("d: "..d.." X: "..x.." Z:"..z.." Elevation: "..elevation)
      elevations[#elevations + 1] = elevation
    end
    return D
  end

  function CoordinateData:extractElevationProfile()
    local allPoints = {}
    local waypointDistances = {}
    -- add planning position if any
    if self.planningPosition then
      allPoints[#allPoints + 1] = self.planningPosition
    end
    -- append requested waypoints
    for k, v in  pairs(self.wayPoints) do
      allPoints[#allPoints + 1] = v
    end
    -- if we do not have at least 2 points we can not calculate the profile
    if #allPoints < 2 then return nil end
    local elevations = {}
    local currentPosition = allPoints[1]
    local totalDistance = 0
    for i = 2, #allPoints do
      Logging.info("Calculating stage: "..tostring(i-1))
      local nextPosition = allPoints[i]
      local distance = self:extractSectionElevationProfile(elevations, currentPosition, nextPosition)
      totalDistance = totalDistance + distance
      waypointDistances[#waypointDistances + 1] = distance
      currentPosition = nextPosition
    end
    return {
      elevations = elevations,
      waypointDistances = waypointDistances,
      totalDistance = totalDistance,
      allPoints = allPoints
    }
  end


-- Singleton
return CoordinateData:new{}



-- provide sub-packages and modules
local Logging = require("SharkPlanner.Utils.Logging")
local coordinateData = require("SharkPlanner.Base.CoordinateData")
local DialogLoader = require("DialogLoader")
local GameState = require("SharkPlanner.Base.GameState")
local CommandGeneratorFactory = require("SharkPlanner.Base.CommandGeneratorFactory")
local DCSEventHandlers = require("SharkPlanner.Base.DCSEventHandlers")
local Position = require("SharkPlanner.Base.Position")
local SkinHelper = require("SharkPlanner.UI.SkinHelper")
local dxgui = require('dxgui')
local Input = require("Input")
local lfs = require("lfs")
local Skin = require("Skin")
local SkinUtils = require("SkinUtils")
local Static = require("Static")
local inspect = require("SharkPlanner.inspect")

local ChartWindow = DialogLoader.spawnDialogFromFile(
    lfs.writedir() .. "Scripts\\SharkPlanner\\UI\\ChartWindow.dlg"
)


local AggregationModes = {
  MAX = 1,
  MIN = 2,
  AVG = 3,
  SUM = 4
}

ChartWindow.AggregationModes = AggregationModes

-- Constructor
function ChartWindow:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    local x, y, w, h = o.crosshairWindow:getBounds()
    Logging.info("Creating chart window")
    -- o:setBounds(x - ownWidth, y, ownWidth, ownHeight)
    local width = 805
    local height = 200
    o.negativeAsymptote = 20

    Logging.info("Width: "..width)
    Logging.info("Height: ".. height)
    o:setBounds(x, y + h + 26, width,height)
    o:setVisible(true)
    local lineSkin = SkinHelper.loadSkin("graphSkinSharkPlannerLine")
    local axisLineSkin = SkinHelper.loadSkin("graphSkinSharkPlannerAxisLine")
    local horizontalAxisLineSkin = SkinHelper.loadSkin("graphSkinSharkPlannerHorizontalAxisLine")
    local asymptoteLineSkin = SkinHelper.loadSkin("graphSkinSharkPlannerAsymptoteLine")
    local thousandLineSkin = SkinHelper.loadSkin("graphSkinSharkPlannerThousandLine")
    local thousandLabelSkin = SkinHelper.loadSkin("graphSkinSharkPlannerThousandLabel")
    self.waypointLineSkin = SkinHelper.loadSkin("graphSkinSharkPlannerWaypointLine")
    self.waypointVerticalLabelSkin = SkinHelper.loadSkin("graphSkinSharkPlannerWaypointVerticalLabel")
    self.waypointHorizontalLabelSkin = SkinHelper.loadSkin("graphSkinSharkPlannerWaypointHorizontalLabel")
    local seaSkin = SkinHelper.loadSkin("graphSkinSharkPlannerSea")
    self.axisLineSkin = axisLineSkin
    -- create maximum asymptote
    local sea = Static.new()
    sea:setSkin(seaSkin)
    sea:setBounds(0, height - o.negativeAsymptote, width, 20)
    sea:setAngle(0)
    sea:setVisible(true)
    o:insertWidget(sea, self:getWidgetCount() + 1)
    

    self.value_histogram = {}
    for x = 0, width do
      local line = Static.new()
      line:setSkin(lineSkin)
      line:setBounds(x - 1, height - o.negativeAsymptote, 0, 1)
      line:setAngle(90)
      line:setVisible(true)
      o:insertWidget(line, 1)
      self.value_histogram[x] = line
    end
    o:setAggregationMode(AggregationModes.MAX)

    -- create horizontal Axis
    local horizontalAxis = Static.new()
    horizontalAxis:setSkin(horizontalAxisLineSkin)
    horizontalAxis:setBounds(0, height - o.negativeAsymptote, width, o.negativeAsymptote)
    horizontalAxis:setAngle(0)
    horizontalAxis:setText("0m")
    horizontalAxis:setVisible(true)
    o:insertWidget(horizontalAxis, self:getWidgetCount() + 1)
    -- create vertical Axis
    local verticalAxis = Static.new()
    verticalAxis:setSkin(axisLineSkin)
    -- verticalAxis:setBounds(1, 1, height, 1)
    verticalAxis:setBounds(0, 0, 1, height)
    -- verticalAxis:setAngle(90)
    verticalAxis:setVisible(true)
    o:insertWidget(verticalAxis, self:getWidgetCount() + 1)


    o.thousandLines = {}
    for i = 1,20 do
      local thousandLine = Static.new()
      thousandLine:setSkin(thousandLineSkin)
      thousandLine:setBounds(0, height - 10, width, 1)
      thousandLine:setAngle(0)
      thousandLine:setVisible(false)
      o:insertWidget(thousandLine, o:getWidgetCount() + 1)
      o.thousandLines[#o.thousandLines + 1] = thousandLine
    end
    -- create minimum asymptote
    o.minimumAsymptote = Static.new()
    o.minimumAsymptote:setSkin(asymptoteLineSkin)
    o.minimumAsymptote:setBounds(0, height - 10, width, 1)
    o.minimumAsymptote:setAngle(0)
    o.minimumAsymptote:setVisible(false)
    o:insertWidget(o.minimumAsymptote, o:getWidgetCount() + 1)

    -- create maximum asymptote
    o.maximumAsymptote = Static.new()
    o.maximumAsymptote:setSkin(asymptoteLineSkin)
    o.maximumAsymptote:setBounds(0, height - 10, width, 1)
    o.maximumAsymptote:setAngle(0)
    o.maximumAsymptote:setVisible(false)
    o:insertWidget(o.maximumAsymptote, o:getWidgetCount() + 1)

    o.thousandLabels = {}
    for i = 1,20 do
      local thousandLabel = Static.new()
      thousandLabel:setSkin(thousandLabelSkin)
      thousandLabel:setBounds(0, height - 10, width, 1)
      thousandLabel:setAngle(0)
      thousandLabel:setVisible(false)
      thousandLabel:setText(tostring(i * 1000).."m")
      o:insertWidget(thousandLabel, o:getWidgetCount() + 1)
      o.thousandLabels[#o.thousandLabels + 1] = thousandLabel
    end

    return o
end

function ChartWindow:show()
    self:setVisible(true)
    -- show all widgets on status window
    local count = self:getWidgetCount()
  	for i = 1, count do
      local index 		= i - 1
  	  local widget 		= self:getWidget(index)
    end
end

function ChartWindow:hide()
    -- hide all widgets on status window
    local count = self:getWidgetCount()
    for i = 1, count do
        local index 		= i - 1
        local widget 		= self:getWidget(index)
    widget:setVisible(false)
    widget:setFocused(false)
  end
  self:setHasCursor(false)
  self:setVisible(false)
end

function ChartWindow:setAggregationMode(mode)
  self.aggregationMode = mode
end

function ChartWindow:determineMinMax(values)
  local minimum = nil
  local maximum = nil
  local sample
  for pos, value in pairs(values) do
    if minimum == nil then
      minimum = value
    elseif value < minimum then
      minimum = value
    end
    if maximum == nil then
      maximum = value
    elseif value > maximum then
      maximum = value
    end
  end
  return minimum, maximum
end

function ChartWindow:determineSampleValues(values)
  local sampledValues = {}
  -- determine number of valuesPerInterval
  local valuesPerInterval = #values / #self.value_histogram
  local globalMax = values[1]
  local globalMin = values[1]
  -- local localSum = 0
  -- local localCount = 0
  for x = 1, #self.value_histogram + 1 do
    local startIndex = math.min(math.floor ( (x - 1) * valuesPerInterval + 1 + 0.5), #values)
    -- local endIndex = math.min(math.floor ( (x - 1) * valuesPerInterval + 1 + valuesPerInterval + 0.5), #values)
    local endIndex = math.min(math.floor(startIndex + valuesPerInterval - 1 + 0.5), #values)
    if endIndex < startIndex then endIndex = startIndex end
    -- Logging.info("valuesPerInterval: "..valuesPerInterval)
    -- Logging.info("Start index: "..startIndex)
    -- Logging.info("End index: "..endIndex)
    assert(startIndex <= endIndex, "Start index: "..startIndex.." End index: ".. endIndex)
    assert(startIndex <= #values, "Start index: "..startIndex.." #values: ".. #values)
    assert(endIndex <= #values, "End index: "..endIndex.." #values: ".. #values)
    local sum = 0
    local count = endIndex - startIndex + 1
    local min = values[startIndex]
    local max = values[startIndex]
    for vx = startIndex, endIndex do
      sum = sum + values[vx]
      if min > values[vx] then min = values[vx] end
      if max < values[vx] then max = values[vx] end
    end
    local avg = sum / count
    if self.aggregationMode == AggregationModes.MAX then
      sampledValues[#sampledValues + 1] = max
    elseif self.aggregationMode == AggregationModes.MIN then
      sampledValues[#sampledValues + 1] = min
    elseif self.aggregationMode == AggregationModes.AVG then
      sampledValues[#sampledValues + 1] = avg
    elseif self.aggregationMode == AggregationModes.SUM then
      sampledValues[#sampledValues + 1] = sum
    end
    if globalMax < max then
      globalMax = max
    end
    if globalMin > min then
      globalMin = min
    end
  end
  return sampledValues, globalMin, globalMax
end

function ChartWindow:setValues(elevationProfile)
  local values = elevationProfile.elevations
  if values == nil then return end
  -- determine number of horizontal Intervals
  local width, height = self:getSize()
  Logging.info("Width: "..#self.value_histogram)
  Logging.info("Initial values count: "..#values)
  -- Logging.info("Initial values: "..inspect(values))
  local minimum, maximum = self:determineMinMax(values)
  local trim = self.negativeAsymptote
  height = height - trim
  self:setAggregationMode(AggregationModes.MAX)
  local sampledValues = self:determineSampleValues(values)
  Logging.info("Sampled values count: "..#sampledValues)
  -- Logging.info("Sampled values"..inspect(sampledValues))
  local thousandCount = math.ceil(maximum / 1000)
  local nextThousand = thousandCount * 1000
  local verticalScalingFactor = (height - trim) / nextThousand
  Logging.info("Next thousaned is: "..nextThousand)
  -- plot graph
  for i, line in ipairs(self.value_histogram) do
    local value = math.floor(sampledValues[i + 1] * verticalScalingFactor)
    line:setSize(value, 1)
  end
  -- set asymptotes
  self.maximumAsymptote:setBounds(0, height - math.floor(maximum * verticalScalingFactor), width, 20)
  self.maximumAsymptote:setVisible(true)
  self.maximumAsymptote:setText(string.format("%.0f", maximum).."m")
  self.minimumAsymptote:setBounds(0, height - math.floor(minimum * verticalScalingFactor), width, 20)
  self.minimumAsymptote:setText(string.format("%.0f", minimum).."m")
  if minimum ~= 0 then
    self.minimumAsymptote:setVisible(true)
  else
    self.minimumAsymptote:setVisible(false)
  end
  -- set thousand lines
  for i = 1, #self.thousandLines do
    if i > thousandCount then
      self.thousandLines[i]:setVisible(false)
      self.thousandLabels[i]:setVisible(false)
    else
      self.thousandLines[i]:setBounds(0, height - math.floor(i * 1000 * verticalScalingFactor), width, 20)
      self.thousandLines[i]:setVisible(true)
      self.thousandLabels[i]:setBounds(0, height - math.floor(i * 1000 * verticalScalingFactor), width, 20)
      self.thousandLabels[i]:setVisible(true)
    end
  end
  -- set waypoints
  local horizontalScale = width / elevationProfile.totalDistance
  Logging.info("Width: "..width)
  Logging.info("Total distance: "..elevationProfile.totalDistance)
  Logging.info("Scale: "..horizontalScale)
  local cumulativeDistance = 0
  local labelWidth = 70
  local labelHeight = 20
  local lastDistanceX = 0
  for i = 1, #elevationProfile.waypointDistances do
    cumulativeDistance = cumulativeDistance + elevationProfile.waypointDistances[i]
    local waypoint = Static.new()
    waypoint:setSkin(self.waypointLineSkin)
    waypoint:setBounds(cumulativeDistance * horizontalScale - labelWidth, 0, labelWidth, height + 20)
    waypoint:setText(tostring(i))
    waypoint:setVisible(true)
    self:insertWidget(waypoint, self:getWidgetCount() + 1)
    local waypointDistance = Static.new()
    waypointDistance:setSkin(self.waypointHorizontalLabelSkin)
    local distanceX = cumulativeDistance * horizontalScale - labelWidth
    waypointDistance:setBounds(distanceX, height - 2, labelWidth, 20)
    local distanceText = string.format("%.0f", cumulativeDistance / 1000)
    -- if i == #elevationProfile.waypointDistances then
    --   distanceText = distanceText.."km"
    -- end
    waypointDistance:setText(distanceText)
    waypointDistance:setAngle(0)
    if distanceX - lastDistanceX >= 33 then
      waypointDistance:setVisible(true)
    else
      waypointDistance:setVisible(false)
    end
    lastDistanceX = distanceX
    self:insertWidget(waypointDistance, self:getWidgetCount() + 1)
    local waypointHeight = Static.new()
    waypointHeight:setSkin(self.waypointVerticalLabelSkin)
    waypointHeight:setBounds(
      cumulativeDistance * horizontalScale - labelHeight,
      -- 180 - math.floor(elevationProfile.allPoints[i + 1]:getY() * verticalScalingFactor),
      100,
      labelWidth, 
      20
    )
    waypointHeight:setText(string.format("%.0fm", elevationProfile.allPoints[i + 1]:getY()))
    waypointHeight:setAngle(90)
    waypointHeight:setVisible(true)
    self:insertWidget(waypointHeight, self:getWidgetCount() + 1)
  end
end


return ChartWindow
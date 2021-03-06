os.loadAPI("json.lua")
os.loadAPI("base64.lua")

local inf = (1/0)

local LDClientInstance = {
    clientsideId = "",
    currentUser = {},
    allFlags = {},
    _lastPoll = -inf,
    _lastFlush = -inf
}

function LDClientInstance:__init__(baseClass, clientsideId, currentUser, config)
    self.clientsideId = clientsideId or ""
    self.currentUser  = currentUser  or {}

    config = config or {}
    self.config = {}
    self.config.pollInterval  = config.pollInterval  or 5 -- 60
    self.config.flushInterval = config.flushInterval or 15 -- 5
    self.config.baseUrl       = config.baseUrl       or "https://app.launchdarkly.com/"
    self.config.eventsUrl     = config.eventsUrl     or "https://events.launchdarkly.com/"

    self._lastPoll  = -inf
    self._lastFlush = -inf

    setmetatable ( self, {__index=LDClientInstance})

    return self
end

function LDClientInstance:identify(user)
    self.currentUser = user
    self._enqueueIdentifyEvent()
    self._maybePollAllFlags(true)
    self._maybeFlushAllEvents()
end

function LDClientInstance:variationDetails(variation, fallbackValue)
    self._maybePollAllFlags()
    local details = self.allFlags[variation] or fallbackValue
    self._enqueueVariationEvent(details, fallbackValue)
    self._maybeFlushAllEvents()
    return details
end

function LDClientInstance:variation(variation, fallbackValue)
    local details = self.variationDetails(variation, fallbackValue)
    local value = fallbackValue
    if details then
        value = details.value
    end
    return value
end

function LDClientInstance:allFlags()
    self._maybePollAllFlags()
    return self.allFlags
end

function LDClientInstance:track(metric)
    self._enqueueTrackEvent(metric)
    self._maybeFlushAllEvents()
end

function LDClientInstance:flush()
    self._maybeFlushAllEvents(true)
end

-- private methods

function LDClientInstance:_enqueueIdentifyEvent()
    -- TODO
    -- ¯\_(ツ)_/¯
end

function LDClientInstance:_enqueueVariationEvent()
    -- TODO
    -- ¯\_(ツ)_/¯
end

function LDClientInstance:_enqueueTrackEvent()
    -- TODO
    -- ¯\_(ツ)_/¯
end

function LDClientInstance:_maybePollAllFlags(force)
    if force or (self._lastPoll + self.config.pollInterval > os.clock()) then
        return
    end

    self.allFlags = self._fetchAllFlags()
    self._lastPoll = os.clock()
end

function LDClientInstance:_maybeFlushAllEvents(force)
    if force or (self._lastFlush + self.config.flushInterval > os.clock()) then
        return
    end

    self._flushAllEvents()
    self._lastFlush = os.clock()
end

function LDClientInstance:_fetchAllFlags()
    local user = self._buildUserObject()
    local userString = json.encode(user)
    local userBase64 = base64.encode(userString)
    local url = self.config.baseUrl .. "sdk/evalx/" .. clientsideId .. "/users/" .. userBase64
    
    local request = http.get(url)
    if not request then
        this._printError("Fetching flags failed: (" .. url .. ")")
        return
    end
    local response = request.readAll()

    return json.decode(response)
end

function LDClientInstance:_flushAllEvents()
    local url = self.config.eventsUrl .. "events/bulk/" .. self.clientsideId
    local headers = { [ "Content-Type" ] = "application/json" }
    local event = json.encode({
        kind = "index",
        user = self._buildUser()
    })
    -- TODO: Summary events

    local request = http.post(url, event, headers)
    if not request then
        this._printError("Flushing events failed: (" .. url .. ")")
        return
    end
    local response = request.readAll()
end

function LDClientInstance:_buildUserObject()
    local user = {}
    user.key = "" .. (self.currentUser.key or os.getComputerID())

    user.custom = {}
    for key, value in pairs(self.currentUser.custom) do
        user.custom[key] = value
    end

    -- overrides
    user.custom.time = os.time()*1000
    user.custom.hour = math.floor(os.time())
    user.custom.day = os.day()
    for key, side in pairs(redstone.getSides()) do
        user.custom["redstone_" .. side] = redstone.getInput(side)
    end

    return user
end

function LDClientInstance:_printError(msg)
    print("[LDClient Error]: " .. msg)
end

setmetatable (LDClientInstance, {__call=LDClientInstance.__init__})

function init(clientsideId, currentUser)
    return LDClientInstance (clientsideId, currentUser)
end

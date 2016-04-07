local mal = require "libmal"
local malzmq = require "malzmq"

local Context = mal.Context
local binding = malzmq('localhost', '6666')
local malctx = Context:new(binding)

local logger_actor = [[
    local mal = require "libmal"
    local Actor, class = mal.Actor, mal.class
    local DemoArea = require "demoarea"

    local MyLogHandler = class('MyLogHandler', DemoArea.ProviderLogHandler)

    function MyLogHandler:on_send(message)
        print(self.actor.prefix .. "LOG: " .. message.body)
    end

    local MyPingHandler = class('MyPingHandler', DemoArea.ProviderPingHandler)

    function MyPingHandler:on_submit(message)
        print(self.actor.prefix .. "PING: " .. message.body)
        self:submit_ack(message)
    end

    local MyStatusHandler = class('MyStatusHandler', DemoArea.ProviderStatusHandler)

    function MyStatusHandler:on_request(message)
        print(self.actor.prefix .. "STATUS: " .. message.body)
        self:respond(message, "I'm ready to rock'n'roll.")
    end

    local MyHealthCheckHandler = class('MyHealthCheckHandler', DemoArea.ProviderHealthCheckHandler)

    function MyHealthCheckHandler:on_invoke(message)
        print(self.actor.prefix .. "HEALTH CHECK: " .. message.body)
        self:invoke_ack(message)
        local health_status = self.actor:health_check()
        self:respond(message, health_status)
    end

    local MyCountDownHandler = class('MyCountDownHandler', DemoArea.ProviderCountDownHandler)

    function MyCountDownHandler:on_progress(message)
        print(self.actor.prefix .. "COUNTDOWN TO: " .. message.body)
        local count = tonumber(message.body)
        self:progress_ack(message)
        for i=count,1,-1 do
            self:update(message, i)
        end
        self:respond(message, "BOOM!")
    end

    local MyClockHandler = class('MyClockHandler', DemoArea.ProviderClockHandler)

    local DemoActor = class('DemoActor', Actor)

    function DemoActor:init()
        self.prefix = self.identity .. "# "
        self.log_handler = MyLogHandler:new(self)
        self.ping_handler = MyPingHandler:new(self)
        self.status_handler = MyStatusHandler:new(self)
        self.health_check_handler = MyHealthCheckHandler:new(self)
        self.countdown_handler = MyCountDownHandler:new(self)
        self.clock_handler = MyClockHandler:new(self)
    end

    function DemoActor:handle_tick()
        local broker_uri = self.context:get_broker_uri()
        self.clock_handler:publish(broker_uri, "It's 15:23.")
    end

    function DemoActor:health_check()
        return "I'm feeling fine."
    end

    return DemoActor
]]


malctx:add_actor('demo/actor1', logger_actor)
malctx:add_actor('demo/actor2', logger_actor)
malctx:start()


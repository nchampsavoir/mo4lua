local mal = require "libmal"
local malzmq = require "malzmq"

local Context = mal.Context
local binding = malzmq('localhost', 7777)
local malctx = Context:new(binding)

actor_code = [[
    local mal = require "libmal"
    local Actor, Message, class = mal.Actor, mal.Message, mal.class
    local DemoArea = require "demoarea"
    
    local MyLogHandler = class('MyLogHandler', DemoArea.ConsumerLogHandler)

    local MyPingHandler = class('MyPingHandler', DemoArea.ConsumerPingHandler)

    function MyPingHandler:on_ack(message)
        print(self.actor.prefix .. "Received pong from " .. message.uri_from)
    end

    local MyStatusHandler = class('MyStatusHandler', DemoArea.ConsumerStatusHandler)

    function MyStatusHandler:on_response(message)
        print(self.actor.prefix .. "Received status '" .. message.body ..  "' from " .. message.uri_from)
    end

    local MyHealthCheckHandler = class('MyHealthCheckHandler', DemoArea.ConsumerHealthCheckHandler)

    function MyHealthCheckHandler:on_ack(message)
        print(self.actor.prefix .. "Health check acknowledge by " .. message.uri_from)
    end

    function MyHealthCheckHandler:on_response(message)
        print(self.actor.prefix .. "Received health status '" .. message.body ..  "' from " .. message.uri_from)
    end

    local MyCountDownHandler = class('MyCountDownHandler', DemoArea.ConsumerCountDownHandler)

    function MyCountDownHandler:on_ack(message)
        print(self.actor.prefix .. "Countdown acknowledge by " .. message.uri_from)
    end

    function MyCountDownHandler:on_update(message)
        print(self.actor.prefix .. "Countdown: '" .. message.body ..  "' from " .. message.uri_from)
    end

    function MyCountDownHandler:on_response(message)
        print(self.actor.prefix .. "Final Countdown: '" .. message.body ..  "' from " .. message.uri_from)
    end

    local MyClockHandler = class('MyClockHandler', DemoArea.ConsumerClockHandler)

    function MyClockHandler:on_notify(message)
        print(self.actor.prefix .. "Clock: '" .. message.body ..  "' from " .. message.uri_from)
        self.actor.clock_message_count = self.actor.clock_message_count + 1
        if self.actor.clock_message_count >= 5 then
            self:deregister(self.actor.broker)
            self.actor:shutdown()
        end
    end

    local DemoClientActor = class('DemoClientActor', Actor)

    function DemoClientActor:init()
        self.prefix = self.identity .. "# "
        self.log_handler = MyLogHandler:new(self)
        self.ping_handler = MyPingHandler:new(self)
        self.status_handler = MyStatusHandler:new(self)
        self.health_check_handler = MyHealthCheckHandler:new(self)
        self.countdown_handler = MyCountDownHandler:new(self)
        self.clock_handler = MyClockHandler:new(self)

        local provider1 = 'malzmq://localhost:6666/demo/actor1'
        local provider2 = 'malzmq://localhost:6666/demo/actor2'
        self.broker = self.context:get_broker_uri()
        
        self.log_handler:log(provider1, 'Log something important on logger 1')
        self.log_handler:log(provider2, 'Log something amazing on logger 2')
        self.log_handler:log(provider1, 'Log something even more important on logger 1')
        self.log_handler:log(provider2, 'Log something even more amazing on logger 2')

        self.ping_handler:ping(provider1)

        self.status_handler:status(provider1)

        self.health_check_handler:health_check(provider1)

        self.countdown_handler:countdown(provider1, 10)
        
        self.clock_message_count = 0
        self.clock_handler:register(self.broker)
    end

    function DemoClientActor:handle_tick()
        print(self.identity .. '# So far, so good...')
    end

    return DemoClientActor

]]

malctx:add_actor('demo/client', actor_code)
malctx:start()
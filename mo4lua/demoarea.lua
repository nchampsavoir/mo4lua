-- This is a demo area with tests for the various MAL IP
-- This kind of file should typically be automatically generated
-- from MO-XML

local mal = require "libmal"
local Actor, Message, Handler, Service, class = mal.Actor, mal.Message, mal.Handler, mal.Service, mal.class
local ProviderSendHandler, ConsumerSendHandler = mal.ProviderSendHandler, mal.ConsumerSendHandler
local ProviderSubmitHandler, ConsumerSubmitHandler = mal.ProviderSubmitHandler, mal.ConsumerSubmitHandler
local ProviderRequestHandler, ConsumerRequestHandler = mal.ProviderRequestHandler, mal.ConsumerRequestHandler
local ProviderInvokeHandler, ConsumerInvokeHandler = mal.ProviderInvokeHandler, mal.ConsumerInvokeHandler
local ProviderProgressHandler, ConsumerProgressHandler = mal.ProviderProgressHandler, mal.ConsumerProgressHandler
local ProviderPubsubHandler, ConsumerPubsubHandler = mal.ProviderPubsubHandler, mal.ConsumerPubsubHandler
local MAL_IP_TYPES, MAL_IP_STAGES = mal.MAL_IP_TYPES, mal.MAL_IP_STAGES

local Area = {
    AREA = 99,
    AREA_VERSION = 1,
    LOGGING_SERVICE = 1,
    LOG_OPERATION = 1,
    MONITORING_SERVICE = 2,
    PING_OPERATION = 1,
    STATUS_OPERATION = 2,
    HEALTH_CHECK_OPERATION = 3,
    CLOCK_SERVICE = 3,
    COUNTDOWN_OPERATION = 1,
    CLOCK_OPERATION = 2,
}

-- SEND TEST

local ConsumerLogHandler = class('ConsumerLogHandler', ConsumerSendHanlder)

function ConsumerLogHandler:initialize(actor)
    ConsumerSendHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.LOGGING_SERVICE, Area.LOG_OPERATION, actor)
end

function ConsumerLogHandler:log(uri_to, string)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.LOGGING_SERVICE, Area.LOG_OPERATION, MAL_IP_TYPES.SEND, MAL_IP_STAGES.SEND)
    message.body = string
    self.actor:init_operation(message, uri_to)
end

local ProviderLogHandler = class('ProviderLogHandler', ProviderSendHandler)

function ProviderLogHandler:initialize(actor)
    ProviderSendHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.LOGGING_SERVICE, Area.LOG_OPERATION, actor)
end

-- SUBMIT TEST

local ConsumerPingHandler = class('ConsumerPingHandler', ConsumerSubmitHandler)

function ConsumerPingHandler:initialize(actor)
    ConsumerSubmitHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.PING_OPERATION, actor)
end

function ConsumerPingHandler:ping(uri_to)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.PING_OPERATION, MAL_IP_TYPES.SUBMIT, MAL_IP_STAGES.SUBMIT)
    message.body = 'Anyone home?'
    self.actor:init_operation(message, uri_to)
end

local ProviderPingHandler = class('ProviderPingHandler', ProviderSubmitHandler)

function ProviderPingHandler:initialize(actor)
    ProviderSubmitHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.PING_OPERATION, actor)
end

function ProviderPingHandler:submit_ack(original_message)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.PING_OPERATION, MAL_IP_TYPES.SUBMIT, MAL_IP_STAGES.SUBMIT_ACK)
    message.body = 'PONG'
    self.actor:return_operation(original_message, message)
end

-- REQUEST TEST

local ConsumerStatusHandler = class('ConsumerStatusHandler', ConsumerRequestHandler)

function ConsumerStatusHandler:initialize(actor)
    ConsumerRequestHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.STATUS_OPERATION, actor)
end

function ConsumerStatusHandler:status(uri_to)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.STATUS_OPERATION, MAL_IP_TYPES.REQUEST, MAL_IP_STAGES.REQUEST)
    message.body = "What's your status?"
    self.actor:init_operation(message, uri_to)
end

local ProviderStatusHandler = class('ProviderStatusHandler', ProviderRequestHandler)

function ProviderStatusHandler:initialize(actor)
    ProviderRequestHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.STATUS_OPERATION, actor)
end

function ProviderStatusHandler:respond(original_message, status)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.STATUS_OPERATION, MAL_IP_TYPES.REQUEST, MAL_IP_STAGES.REQUEST_RESPONSE)
    message.body = status
    self.actor:return_operation(original_message, message)
end

-- INVOKE TEST

local ConsumerHealthCheckHandler = class('ConsumerHealthCheckHandler', ConsumerInvokeHandler)

function ConsumerHealthCheckHandler:initialize(actor)
    ConsumerInvokeHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.HEALTH_CHECK_OPERATION, actor)
end

function ConsumerHealthCheckHandler:health_check(uri_to)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.HEALTH_CHECK_OPERATION, MAL_IP_TYPES.INVOKE, MAL_IP_STAGES.INVOKE)
    message.body = "How do you feel?"
    self.actor:init_operation(message, uri_to)
end

local ProviderHealthCheckHandler = class('ProviderHealthCheckHandler', ProviderInvokeHandler)

function ProviderHealthCheckHandler:initialize(actor)
    ProviderInvokeHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.HEALTH_CHECK_OPERATION, actor)
end

function ProviderHealthCheckHandler:invoke_ack(original_message)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.HEALTH_CHECK_OPERATION, MAL_IP_TYPES.INVOKE, MAL_IP_STAGES.INVOKE_ACK)
    self.actor:return_operation(original_message, message)
end

function ProviderHealthCheckHandler:respond(original_message, status)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.MONITORING_SERVICE, Area.HEALTH_CHECK_OPERATION, MAL_IP_TYPES.INVOKE, MAL_IP_STAGES.INVOKE_RESPONSE)
    message.body = status
    self.actor:return_operation(original_message, message)
end

-- PROGRESS TEST

local ConsumerCountDownHandler = class('ConsumerCountDownHandler', ConsumerProgressHandler)

function ConsumerCountDownHandler:initialize(actor)
    ConsumerProgressHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.COUNTDOWN_OPERATION, actor)
end

function ConsumerCountDownHandler:countdown(uri_to, count)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.COUNTDOWN_OPERATION, MAL_IP_TYPES.PROGRESS, MAL_IP_STAGES.PROGRESS)
    message.body = tostring(count)
    self.actor:init_operation(message, uri_to)
end

local ProviderCountDownHandler = class('ProviderCountDownHandler', ProviderProgressHandler)

function ProviderCountDownHandler:initialize(actor)
    ProviderProgressHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.COUNTDOWN_OPERATION, actor)
end

function ProviderCountDownHandler:progress_ack(original_message)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.COUNTDOWN_OPERATION, MAL_IP_TYPES.PROGRESS, MAL_IP_STAGES.PROGRESS_ACK)
    self.actor:return_operation(original_message, message)
end

function ProviderCountDownHandler:update(original_message, count)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.COUNTDOWN_OPERATION, MAL_IP_TYPES.PROGRESS, MAL_IP_STAGES.PROGRESS_UPDATE)
    message.body = tostring(count)
    self.actor:return_operation(original_message, message)
end

function ProviderCountDownHandler:respond(original_message, final_message)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.COUNTDOWN_OPERATION, MAL_IP_TYPES.PROGRESS, MAL_IP_STAGES.PROGRESS_RESPONSE)
    message.body = final_message
    self.actor:return_operation(original_message, message)
end

-- PUBSUB TEST

local ConsumerClockHandler = class('ConsumerClockHandler', ConsumerPubsubHandler)

function ConsumerClockHandler:initialize(actor)
    ConsumerPubsubHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.CLOCK_OPERATION, actor)
end

function ConsumerClockHandler:register(broker_uri)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.CLOCK_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_REGISTER)
    self.actor:init_operation(message, broker_uri)
end

function ConsumerClockHandler:deregister(broker_uri)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.CLOCK_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_DEREGISTER)
    self.actor:init_operation(message, broker_uri)
end

local ProviderClockHandler = class('ProviderClockHandler', ProviderPubsubHandler)

function ProviderClockHandler:initialize(actor)
    ProviderPubsubHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.CLOCK_OPERATION, actor)
end

function ProviderClockHandler:publish_register(broker_uri)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.CLOCK_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH_REGISTER)
    self.actor:init_operation(message, broker_uri)
end

function ProviderClockHandler:publish_deregister(broker_uri)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.CLOCK_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH_DEREGISTER)
    self.actor:init_operation(message, broker_uri)
end

function ProviderClockHandler:publish(broker_uri, content)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.CLOCK_SERVICE, Area.CLOCK_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH)
    message.body = content
    self.actor:init_operation(message, broker_uri)
end

Area.ConsumerLogHandler = ConsumerLogHandler
Area.ProviderLogHandler = ProviderLogHandler
Area.ConsumerPingHandler = ConsumerPingHandler
Area.ProviderPingHandler = ProviderPingHandler
Area.ConsumerStatusHandler = ConsumerStatusHandler
Area.ProviderStatusHandler = ProviderStatusHandler
Area.ConsumerHealthCheckHandler = ConsumerHealthCheckHandler
Area.ProviderHealthCheckHandler = ProviderHealthCheckHandler
Area.ConsumerCountDownHandler = ConsumerCountDownHandler
Area.ProviderCountDownHandler = ProviderCountDownHandler
Area.ConsumerClockHandler = ConsumerClockHandler
Area.ProviderClockHandler = ProviderClockHandler

return Area

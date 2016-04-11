local mal = require "libmal"
local Actor, Message, Handler, Service, class = mal.Actor, mal.Message, mal.Handler, mal.Service, mal.class
local ProviderPubsubHandler, ConsumerPubsubHandler = mal.ProviderPubsubHandler, mal.ConsumerPubsubHandler
local MAL_IP_TYPES, MAL_IP_STAGES = mal.MAL_IP_TYPES, mal.MAL_IP_STAGES

local Area = {
    AREA = 100,
    AREA_VERSION = 1,
    PACKET_SERVICE = 1,
    MONITOR_PACKET_OPERATION = 1,
    DECOMMUTED_PACKET_SERVICE = 2,
    MONITOR_DECOMMUTED_PACKET_OPERATION = 2
}


-- PACKET SERVICE

local ConsumerMonitorPacketHandler = class('ConsumerMonitorPacketHandler', ConsumerPubsubHandler)

function ConsumerMonitorPacketHandler:initialize(actor)
    ConsumerPubsubHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, actor)
end

function ConsumerMonitorPacketHandler:register(broker_uri)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_REGISTER)
    self.actor:init_operation(message, broker_uri)
end

function ConsumerMonitorPacketHandler:deregister(broker_uri)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_DEREGISTER)
    self.actor:init_operation(message, broker_uri)
end

local ProviderMonitorPacketHandler = class('ProviderMonitorPacketHandler', ProviderPubsubHandler)

function ProviderMonitorPacketHandler:initialize(actor)
    ProviderPubsubHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, actor)
end

function ProviderMonitorPacketHandler:publish_register(broker_uri)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH_REGISTER)
    self.actor:init_operation(message, broker_uri)
end

function ProviderMonitorPacketHandler:publish_deregister(broker_uri)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH_DEREGISTER)
    self.actor:init_operation(message, broker_uri)
end

function ProviderMonitorPacketHandler:publish(broker_uri, content)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH)
    message.body = content
    self.actor:init_operation(message, broker_uri)
end

Area.ConsumerMonitorPacketHandler = ConsumerMonitorPacketHandler
Area.ProviderMonitorPacketHandler = ProviderMonitorPacketHandler

-- DECOMMUTED PACKET SERVICE

local ConsumerMonitorDecommutedPacketHandler = class('ConsumerMonitorDecommutedPacketHandler', ConsumerPubsubHandler)

function ConsumerMonitorDecommutedPacketHandler:initialize(actor)
    ConsumerPubsubHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.DECOMMUTED_PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, actor)
end

function ConsumerMonitorDecommutedPacketHandler:register(broker_uri)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.DECOMMUTED_PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_REGISTER)
    self.actor:init_operation(message, broker_uri)
end

function ConsumerMonitorDecommutedPacketHandler:deregister(broker_uri)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.DECOMMUTED_PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_DEREGISTER)
    self.actor:init_operation(message, broker_uri)
end

local ProviderMonitorDecommutedPacketHandler = class('ProviderMonitorDecommutedPacketHandler', ProviderPubsubHandler)

function ProviderMonitorDecommutedPacketHandler:initialize(actor)
    ProviderPubsubHandler.initialize(self, Area.AREA, Area.AREA_VERSION, Area.DECOMMUTED_PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, actor)
end

function ProviderMonitorDecommutedPacketHandler:publish_register(broker_uri)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.DECOMMUTED_PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH_REGISTER)
    self.actor:init_operation(message, broker_uri)
end

function ProviderMonitorDecommutedPacketHandler:publish_deregister(broker_uri)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.DECOMMUTED_PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH_DEREGISTER)
    self.actor:init_operation(message, broker_uri)
end

function ProviderMonitorDecommutedPacketHandler:publish(broker_uri, content)
    local message = Message()
    message:init(Area.AREA, Area.AREA_VERSION, Area.DECOMMUTED_PACKET_SERVICE, Area.MONITOR_PACKET_OPERATION, MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH)
    message.body = content
    self.actor:init_operation(message, broker_uri)
end

Area.ConsumerMonitorDecommutedPacketHandler = ConsumerMonitorDecommutedPacketHandler
Area.ProviderMonitorDecommutedPacketHandler = ProviderMonitorDecommutedPacketHandler

return Area

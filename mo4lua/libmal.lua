local class = require '3rdparty.middleclass'
local ffi = require 'ffi'
local utils = require 'utils'
local dictionnary = utils.dictionnary

local uint64 = ffi.typeof("uint64_t")

local MAL_IP_TYPES = {
    SEND = 1,
    SUBMIT = 2,
    REQUEST = 3,
    INVOKE = 4,
    PROGRESS = 5,
    PUBSUB = 6
}

local MAL_IP_STAGES = {
    SEND = 0,
    SUBMIT = 1,
    SUBMIT_ACK = 2,
    REQUEST = 3,
    REQUEST_RESPONSE = 4,
    INVOKE = 5,
    INVOKE_ACK = 6,
    INVOKE_RESPONSE = 7,
    PROGRESS = 8,
    PROGRESS_ACK = 9,
    PROGRESS_UPDATE = 10,
    PROGRESS_RESPONSE = 11,
    PUBSUB_REGISTER = 12,
    PUBSUB_REGISTER_ACK = 13,
    PUBSUB_PUBLISH_REGISTER = 14,
    PUBSUB_PUBLISH_REGISTER_ACK = 15,
    PUBSUB_PUBLISH = 16,
    PUBSUB_NOTIFY = 17,
    PUBSUB_DEREGISTER = 18,
    PUBSUB_DEREGISTER_ACK = 19,
    PUBSUB_PUBLISH_DEREGISTER = 20,
    PUBSUB_PUBLISH_DEREGISTER_ACK = 21
}

local MAL_IP_ERRORS = {
    SUBMIT_ERROR = 2,
    REQUEST_ERROR = 4,
    INVOKE_ACK_ERROR = 6,
    INVOKE_RESPONSE_ERROR = 7,
    PROGRESS_ACK_ERROR = 9,
    PROGRESS_UPDATE_ERROR = 10,
    PROGRESS_RESPONSE_ERROR = 11,
    PUBSUB_REGISTER_ACK_ERROR = 13,
    PUBSUB_PUBLISH_REGISTER_ERROR = 14,
    PUBSUB_PUBLISH_ERROR = 16,
    PUBSUB_NOTIFY_ERROR = 17
}

local Message = class('Message')

function Message:initialize(authentication_id, qos_level, priority, domain, network_zone, session, session_name, body_length)
    self.authentication_id = authentication_id
    self.qos_level = qos_level or 0
    self.priority = priority
    self.domain = domain 
    self.network_zone = network_zone
    self.session = session or 0
    self.session_name = session_name
    self.body = ""
    self.is_error_message = false
end

function Message:init(area, area_version, service, operation, interaction_type, interaction_stage)
    self.area = area
    self.area_version = area_version
    self.service = service
    self.operation = operation
    self.interaction_type = interaction_type
    self.interaction_stage = interaction_stage    
end

local Endpoint = class('Endpoint')

function Endpoint:initialize(context, identity)
    self.context = context
    self.binding = context.binding
    self.identity = identity
    self.uri = self.context:create_uri(identity)
    self.transaction_counter = uint64(0)
    self.binding:initialize_endpoint(self)
end

function Endpoint:dispatch_signal(signal)
    self.binding:dispatch_signal(self, signal)
end

function Endpoint:shutdown()
    self.binding:shutdown(self)
end


function Endpoint:init_operation(message, uri_to, transaction_id)
    message.uri_to = uri_to
    message.uri_from = self.uri
    if tid then
        message.transaction_id = transaction_id
    else
        self.transaction_counter = self.transaction_counter + 1
        message.transaction_id = self.transaction_counter
    end
    self.binding:send_message(self, message)
end

function Endpoint:return_operation(init_message, message, is_error_message)
    message.uri_to = init_message.uri_from
    message.uri_from = self.uri
    message.transaction_id = init_message.transaction_id
    message.is_error_message = is_error_message
    self.binding:send_message(self, message)
end

function Endpoint:recv_message()
    return self.binding:recv_message(self)
end

function Endpoint:get_broker_uri()
    return self.context:get_broker_uri()
end

local Poller = class('Poller')

function Poller:initialize(context)
    self.context = context
    self.binding = context.binding
    self.endpoints = {}
    self.binding:initialize_poller(self)
end

function Poller:add(endpoint)
    self.binding:add_endpoint_to_poller(endpoint, self)
end

function Poller:remove(endpoint)
    self.binding:remover_endpoint_from_poller(endpoint, self)
end

local Handler = class('Handler')

function Handler:initialize(area, version, service, operation, actor)
    self.area = area
    self.version = version
    self.service = service
    self.operation = operation
    self.actor = actor
    self.context = actor.context
end

local ConsumerSendHandler = class('ConsumerSendHandler', Handler)

function ConsumerSendHandler:initialize(area, version, service, operation, actor)
    Handler.initialize(self, area, version, service, operation, actor)
    actor.consumer_send_handlers[area][version][service][operation] = self
end

local ProviderSendHandler = class('ProviderSendHandler', Handler)

function ProviderSendHandler:initialize(area, version, service, operation, actor)
    Handler.initialize(self, area, version, service, operation, actor)
    actor.provider_send_handlers[area][version][service][operation] = self
end

local ConsumerSubmitHandler = class('ConsumerSubmitHandler', Handler)

function ConsumerSubmitHandler:initialize(area, version, service, operation, actor)
    Handler.initialize(self, area, version, service, operation, actor)
    actor.consumer_submit_handlers[area][version][service][operation] = self
end

local ProviderSubmitHandler = class('ProviderSubmitHandler', Handler)

function ProviderSubmitHandler:initialize(area, version, service, operation, actor)
    Handler.initialize(self, area, version, service, operation, actor)
    actor.provider_submit_handlers[area][version][service][operation] = self
end

local ConsumerRequestHandler = class('ConsumerRequestHandler', Handler)

function ConsumerRequestHandler:initialize(area, version, service, operation, actor)
    Handler.initialize(self, area, version, service, operation, actor)
    actor.consumer_request_handlers[area][version][service][operation] = self
end

local ProviderRequestHandler = class('ProviderRequestHandler', Handler)

function ProviderRequestHandler:initialize(area, version, service, operation, actor)
    Handler.initialize(self, area, version, service, operation, actor)
    actor.provider_request_handlers[area][version][service][operation] = self
end

local ConsumerInvokeHandler = class('ConsumerInvokeHandler', Handler)

function ConsumerInvokeHandler:initialize(area, version, service, operation, actor)
    Handler.initialize(self, area, version, service, operation, actor)
    actor.consumer_invoke_handlers[area][version][service][operation] = self
end

local ProviderInvokeHandler = class('ProviderInvokeHandler', Handler)

function ProviderInvokeHandler:initialize(area, version, service, operation, actor)
    Handler.initialize(self, area, version, service, operation, actor)
    actor.provider_invoke_handlers[area][version][service][operation] = self
end

local ConsumerProgressHandler = class('ConsumerProgressHandler', Handler)

function ConsumerProgressHandler:initialize(area, version, service, operation, actor)
    Handler.initialize(self, area, version, service, operation, actor)
    actor.consumer_progress_handlers[area][version][service][operation] = self
end

local ProviderProgressHandler = class('ProviderProgressHandler', Handler)

function ProviderProgressHandler:initialize(area, version, service, operation, actor)
    Handler.initialize(self, area, version, service, operation, actor)
    actor.provider_progress_handlers[area][version][service][operation] = self
end

local ConsumerPubsubHandler = class('ConsumerPubsubHandler', Handler)

function ConsumerPubsubHandler:initialize(area, version, service, operation, actor)
    Handler.initialize(self, area, version, service, operation, actor)
    actor.consumer_pubsub_handlers[area][version][service][operation] = self
end

local ProviderPubsubHandler = class('ProviderPubsubHandler', Handler)

function ProviderPubsubHandler:initialize(area, version, service, operation, actor)
    Handler.initialize(self, area, version, service, operation, actor)
    actor.provider_pubsub_handlers[area][version][service][operation] = self
end

function ProviderPubsubHandler:on_register(...)
end    

function ProviderPubsubHandler:on_deregister(...)
end    


local COMMANDS = {
    STOP = 1
}

local SIGNALS = {
    TICK = 1,
    TERM = 2
}

--- MAL Actor Class
-- An actor is basically a thread with a MAL endpoint
local Actor = class('Actor', Endpoint)

function Actor:initialize(context, identity, args)
    Endpoint.initialize(self, context, identity)

    -- handlers by AREA -> AREA VERSION -> SERVICE -> OPERATION
    self.provider_send_handlers = dictionnary()
    self.provider_submit_handlers = dictionnary()
    self.provider_request_handlers = dictionnary()
    self.provider_invoke_handlers = dictionnary()
    self.provider_progress_handlers = dictionnary()
    self.provider_pubsub_handlers = dictionnary()
    self.consumer_send_handlers = dictionnary()
    self.consumer_submit_handlers = dictionnary()
    self.consumer_request_handlers = dictionnary()
    self.consumer_invoke_handlers = dictionnary()
    self.consumer_progress_handlers = dictionnary()
    self.consumer_pubsub_handlers = dictionnary()
    self.broker_pubsub_handlers = dictionnary()

    self:init(args)
end

function Actor:init(args)
    -- overload in child class
end

--- Hook called on every tick. Tick resolution is 
-- a global configuration option of the context
function Actor:handle_tick()
    -- overload in child class
end

--- Handle signals coming from upstream
function Actor:handle_signal(signal)
    -- overload in child class
end

function Actor:finalize()
    -- overload in child class
end

--- Handles messages coming throught the actor's endpoint
-- Dispacthes the message to a dedicated method on one of
-- the actor's registered handlers
function Actor:handle_message(message)
    local interaction_type = message.interaction_type
    local interaction_stage = message.interaction_stage
    local is_error_message = message.is_error_message
    local area = message.area
    local version = message.area_version
    local service = message.service
    local operation = message.operation

    if not is_error_message then

        -- SEND
        if interaction_stage == MAL_IP_STAGES.SEND then
            self.provider_send_handlers[area][version][service][operation]:on_send(message)
        
        -- SUBMIT
        elseif interaction_stage == MAL_IP_STAGES.SUBMIT then
            self.provider_submit_handlers[area][version][service][operation]:on_submit(message)
        elseif interaction_stage == MAL_IP_STAGES.SUBMIT_ACK then
            self.consumer_submit_handlers[area][version][service][operation]:on_ack(message)

        -- REQUEST
        elseif interaction_stage == MAL_IP_STAGES.REQUEST then
            self.provider_request_handlers[area][version][service][operation]:on_request(message)
        elseif interaction_stage == MAL_IP_STAGES.REQUEST_RESPONSE then
            self.consumer_request_handlers[area][version][service][operation]:on_response(message)
        
        -- INVOKE
        elseif interaction_stage == MAL_IP_STAGES.INVOKE then
            self.provider_invoke_handlers[area][version][service][operation]:on_invoke(message)
        elseif interaction_stage == MAL_IP_STAGES.INVOKE_ACK then
            self.consumer_invoke_handlers[area][version][service][operation]:on_ack(message)
        elseif interaction_stage == MAL_IP_STAGES.INVOKE_RESPONSE then
            self.consumer_invoke_handlers[area][version][service][operation]:on_response(message)
        
        -- PROGRESS
        elseif interaction_stage == MAL_IP_STAGES.PROGRESS then
            self.provider_progress_handlers[area][version][service][operation]:on_progress(message)
        elseif interaction_stage == MAL_IP_STAGES.PROGRESS_ACK then
            self.consumer_progress_handlers[area][version][service][operation]:on_ack(message)
        elseif interaction_stage == MAL_IP_STAGES.PROGRESS_UPDATE then
            self.consumer_progress_handlers[area][version][service][operation]:on_update(message)
        elseif interaction_stage == MAL_IP_STAGES.PROGRESS_UPDATE_ERROR then
            self.consumer_progress_handlers[area][version][service][operation]:on_update_error(message)
        elseif interaction_stage == MAL_IP_STAGES.PROGRESS_RESPONSE then
            self.consumer_progress_handlers[area][version][service][operation]:on_response(message)
        
        -- PUBSUB
        elseif interaction_stage == MAL_IP_STAGES.PUBSUB_REGISTER then
            self.broker_pubsub_handlers[area][version][service][operation]:on_register(message)
        elseif interaction_stage == MAL_IP_STAGES.PUBSUB_REGISTER_ACK then
            self.consumer_pubsub_handlers[area][version][service][operation]:on_register_ack(message)
        elseif interaction_stage == MAL_IP_STAGES.PUBSUB_PUBLISH_REGISTER then
            self.broker_pubsub_handlers[area][version][service][operation]:on_publish_register(message)
        elseif interaction_stage == MAL_IP_STAGES.PUBSUB_PUBLISH_REGISTER_ACK then
            self.provider_pubsub_handlers[area][version][service][operation]:on_publish_register_ack(message)
        elseif interaction_stage == MAL_IP_STAGES.PUBSUB_PUBLISH then
            self.broker_pubsub_handlers[area][version][service][operation]:on_publish(message)
        elseif interaction_stage == MAL_IP_STAGES.PUBSUB_NOTIFY then
            self.consumer_pubsub_handlers[area][version][service][operation]:on_notify(message)
        elseif interaction_stage == MAL_IP_STAGES.PUBSUB_DEREGISTER then
            self.broker_pubsub_handlers[area][version][service][operation]:on_deregister(message)
        elseif interaction_stage == MAL_IP_STAGES.PUBSUB_DEREGISTER_ACK then
            self.consumer_pubsub_handlers[area][version][service][operation]:on_deregister_ack(message)
        elseif interaction_stage == MAL_IP_STAGES.PUBSUB_PUBLISH_DEREGISTER then
            self.broker_pubsub_handlers[area][version][service][operation]:on_publish_deregister(message)
        elseif interaction_stage == MAL_IP_STAGES.PUBSUB_PUBLISH_DEREGISTER_ACK then
            self.provider_pubsub_handlers[area][version][service][operation]:on_publish_deregister_ack(message)
        else
            error("Invalid Interaction Stage")
        end

    else

        if interaction_stage == MAL_IP_ERRORS.SUBMIT_ERROR then
            self.consumer_send_handlers[area][version][service][operation]:on_error(message)

        -- REQUEST
        elseif interaction_stage == MAL_IP_ERRORS.REQUEST_ERROR then
            self.consumer_submit_handlers[area][version][service][operation]:on_error(message)

        -- INVOKE
        elseif interaction_stage == MAL_IP_ERRORS.INVOKE_ACK_ERROR then
            self.consumer_invoke_handlers[area][version][service][operation]:on_ack_error(message)
        elseif interaction_stage == MAL_IP_ERRORS.INVOKE_RESPONSE_ERROR then
            self.consumer_invoke_handlers[area][version][service][operation]:on_reponse_error(message)

        -- PROGRESS
        elseif interaction_stage == MAL_IP_ERRORS.PROGRESS_ACK_ERROR then
            self.consumer_progress_handlers[area][version][service][operation]:on_ack_error(message)
        elseif interaction_stage == MAL_IP_ERRORS.PROGRESS_UPDATE_ERROR then
            self.consumer_progress_handlers[area][version][service][operation]:on_update_error(message)
        elseif interaction_stage == MAL_IP_ERRORS.PROGRESS_RESPONSE_ERROR then
            self.consumer_progress_handlers[area][version][service][operation]:on_response_error(message)

        -- PUBSUB
        elseif interaction_stage == MAL_IP_ERRORS.PUBSUB_REGISTER_ACK_ERROR then
            self.provider_pubsub_handlers[area][version][service][operation]:on_register_ack_error(message)
        elseif interaction_stage == MAL_IP_ERRORS.PUBSUB_PUBLISH_REGISTER_ERROR then
            self.provider_pubsub_handlers[area][version][service][operation]:on_publish_register_error(message)
        elseif interaction_stage == MAL_IP_ERRORS.PUBSUB_PUBLISH_ERROR then
            self.provider_pubsub_handlers[area][version][service][operation]:on_publish_error(message)
        elseif interaction_stage == MAL_IP_ERRORS.PUBSUB_NOTIFY_ERROR then
            self.provider_pubsub_handlers[area][version][service][operation]:on_notify_error(message)
        else
            error("Invalid Interaction Stage")
        end
    end
end

local Context = class('Context')

function Context:initialize(binding)
    self.binding = binding
    self.actors = {}
    self.tick_resolution = 2000
    self.binding:bind_context(self)
end

function Context:get_broker_uri()
    return self.binding:get_broker_uri(self)
end

function Context:start()
    self.binding:start_brocker()
end

function Context:stop()
    self:broadcast_signal(SIGNALS.TERM)
    self.binding:stop_broker()
end

function Context:create_uri(id)
    return self.binding:create_uri(id)    
end

function Context:create_poller()
    return self.binding:create_poller()    
end

function Context:add_actor(identity, code, args)
    self.actors[identity] = {code, args}
end

function Context:handle_command(command)
    if command == COMMANDS.STOP then
        self:stop()
    end
end

function Context:broadcast_signal(signal)
    for identity, actor in pairs(self.actors) do
        self.binding:send_signal(signal, identity)
    end
end

local M = {
    class = class,
    MAL_IP_TYPES = MAL_IP_TYPES,
    MAL_IP_STAGES = MAL_IP_STAGES,
    MAL_IP_ERRORS = MAL_IP_ERRORS,
    COMMANDS = COMMANDS,
    Context = Context,
    Endpoint = Endpoint,
    Poller = Poller,
    Message = Message,
    Actor = Actor,
    Handler = Handler,
    ConsumerSendHandler = ConsumerSendHandler,
    ProviderSendHandler = ProviderSendHandler,
    ConsumerSubmitHandler = ConsumerSubmitHandler,
    ProviderSubmitHandler = ProviderSubmitHandler,
    ConsumerRequestHandler = ConsumerRequestHandler,
    ProviderRequestHandler = ProviderRequestHandler,
    ConsumerInvokeHandler = ConsumerInvokeHandler,
    ProviderInvokeHandler = ProviderInvokeHandler,
    ConsumerProgressHandler = ConsumerProgressHandler,
    ProviderProgressHandler = ProviderProgressHandler,
    ConsumerPubsubHandler = ConsumerPubsubHandler,
    ProviderPubsubHandler = ProviderPubsubHandler
}

return M
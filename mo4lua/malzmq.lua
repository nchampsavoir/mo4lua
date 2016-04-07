local zmq   = require "lzmq"
local zloop = require "lzmq.loop"
local zthreads = require "lzmq.threads"
local class = require '3rdparty.middleclass'
local Buffer = require "3rdparty.buffer"
require "bitbuffer"
local utils = require 'utils'
local mal = require 'libmal'

local dictionnary, counter = utils.dictionnary, utils.counter
local COMMANDS = mal.COMMANDS
local MAL_IP_TYPES = mal.MAL_IP_TYPES
local MAL_IP_STAGES = mal.MAL_IP_STAGES
local MAL_IP_ERRORS = mal.MAL_IP_ERRORS

local Binding = class('MalZmqBinding')

local zassert = zmq.assert
local poller = zmq.poller

local SIGNALS = {
    START = 1,
    TERM = 2,
    TICK = 3,
    SHUTDOWN = 4
}

Binding.SIGNALS = SIGNALS

local SDU_TYPES_BY_MAL_IP = {}

SDU_TYPES_BY_MAL_IP[MAL_IP_TYPES.SEND] = {
    [MAL_IP_STAGES.SEND] = 0 }

SDU_TYPES_BY_MAL_IP[MAL_IP_TYPES.SUBMIT] = {
    [MAL_IP_STAGES.SUBMIT] = 1,
    [MAL_IP_STAGES.SUBMIT_ACK] = 2,
    [MAL_IP_ERRORS.SUBMIT_ERROR] = 2,
}

SDU_TYPES_BY_MAL_IP[MAL_IP_TYPES.REQUEST] = {
    [MAL_IP_STAGES.REQUEST] = 3,
    [MAL_IP_STAGES.REQUEST_RESPONSE] = 4,
    [MAL_IP_ERRORS.REQUEST_ERROR] = 4,
}

SDU_TYPES_BY_MAL_IP[MAL_IP_TYPES.INVOKE] = {
    [MAL_IP_STAGES.INVOKE] = 5,
    [MAL_IP_STAGES.INVOKE_ACK] = 6,
    [MAL_IP_ERRORS.INVOKE_ACK_ERROR] = 6,
    [MAL_IP_STAGES.INVOKE_RESPONSE] = 7,
    [MAL_IP_ERRORS.INVOKE_RESPONSE_ERROR] = 7,
}

SDU_TYPES_BY_MAL_IP[MAL_IP_TYPES.PROGRESS] = {
    [MAL_IP_STAGES.PROGRESS] = 8,
    [MAL_IP_STAGES.PROGRESS_ACK] = 9,
    [MAL_IP_ERRORS.PROGRESS_ACK_ERROR] = 9,
    [MAL_IP_STAGES.PROGRESS_UPDATE] = 10,
    [MAL_IP_ERRORS.PROGRESS_UPDATE_ERROR] = 10, 
    [MAL_IP_STAGES.PROGRESS_RESPONSE] = 11,
    [MAL_IP_ERRORS.PROGRESS_RESPONSE_ERROR] = 11
}

SDU_TYPES_BY_MAL_IP[MAL_IP_TYPES.PUBSUB] = {
    [MAL_IP_STAGES.PUBSUB_REGISTER] = 12,
    [MAL_IP_STAGES.PUBSUB_REGISTER_ACK] = 13,
    [MAL_IP_ERRORS.PUBSUB_REGISTER_ACK_ERROR] = 13,
    [MAL_IP_STAGES.PUBSUB_PUBLISH_REGISTER] = 14,
    [MAL_IP_STAGES.PUBSUB_PUBLISH_REGISTER_ACK] = 15,
    [MAL_IP_ERRORS.PUBSUB_PUBLISH_REGISTER_ERROR] = 15,
    [MAL_IP_STAGES.PUBSUB_PUBLISH] = 16,
    [MAL_IP_ERRORS.PUBSUB_PUBLISH_ERROR] = 16,
    [MAL_IP_STAGES.PUBSUB_NOTIFY] = 17,
    [MAL_IP_ERRORS.PUBSUB_NOTIFY_ERROR] = 17,
    [MAL_IP_STAGES.PUBSUB_DEREGISTER] = 18,
    [MAL_IP_STAGES.PUBSUB_DEREGISTER_ACK] = 19,
    [MAL_IP_STAGES.PUBSUB_PUBLISH_DEREGISTER] = 20,
    [MAL_IP_STAGES.PUBSUB_PUBLISH_DEREGISTER_ACK] = 21
}

--- Creates the MALZMQ Binding
function Binding:initialize(hostname, port, options)
    self.zmq_context = zthreads.context()
    self.hostname = hostname or "localhost"
    self.ptp_port = port or 6666
    self.pubsub_port = self.ptp_port + 1
    self.options = options or {}
    self.default_header = self.options.default_header or {} 
    self.mal_socket_uri = string.format("tcp://*:%d", self.ptp_port)
    self.mal_socket = nil     
    self.mal_pub_socket_uri = string.format("tcp://*:%d", self.pubsub_port)
    self.mal_pub_socket = nil 
    self.mal_sub_socket = nil 
    self.broker_uri = "inproc://malzmq.broker"
    self.version_number = 1
end


--- Starts a MALZMQ Broker
-- A broker consists in a zloop that creates a bridge between 
-- an inproc broker socket (which all endpoints are connected to) 
-- and the outside world. The outside world takes the form of a
-- router socket for point-to-point communications and a sub socket
-- for message subscriptions. 
-- For outgoing messages, the broker manages a pool of connections 
-- to other brokers using pairs of DEALER/PUB sockets
function Binding:start_brocker()
    local err

    self.peers = {}
    self.connections = counter()
    self.subscriptions = dictionnary()
    
    self.mal_socket = self.zmq_context:socket(zmq.ROUTER)
    err = self.mal_socket:bind(self.mal_socket_uri)
    zassert(self.mal_socket, err)
    print('P2P Bound to ' .. self.mal_socket_uri)

    self.mal_pub_socket = self.zmq_context:socket(zmq.PUB)
    err = self.mal_pub_socket:bind(self.mal_pub_socket_uri)
    zassert(self.mal_pub_socket, err)
    print('PUBSUB Bound to ' .. self.mal_pub_socket_uri)

    self.mal_sub_socket = self.zmq_context:socket(zmq.SUB)
    self.mal_sub_socket:set_subscribe("")

    self.broker_socket = self.zmq_context:socket(zmq.ROUTER)
    err = self.broker_socket:bind(self.broker_uri)
    zassert(self.broker_socket, err)
    print('Internal router bound to ' .. self.broker_uri)

    self.loop = zloop.new(4, self.zmq_context)

    -- Process external point-to-point messages
    self.loop:add_socket(self.mal_socket, function(sock) 
        local identity, header, body = sock:recvx()
        self:forward_to_endpoint(header, body)     
    end)
    
    -- Process external pub-sub messages
    self.loop:add_socket(self.mal_sub_socket, function(sock) 
        local header, body = sock:recvx()
        if self.verbose then print(string.format('Broadcasting pubsub message "%s" to subscribers', body)) end
        self:broadcast_to_subscribers(header, body) 
    end)
    
    -- Process internal messages
    self.loop:add_socket(self.broker_socket, function(sock)
        local identity, uri_to, header, body = sock:recvx()

        -- If uri is a number then the message is actually a signal
        local signal = tonumber(uri_to)
        if signal then
            self:handle_signal(signal, identity)
    
        -- If message destination is the broker itself (pubsub interaction)
        elseif uri_to == self:get_broker_uri() then
            self:process_pubsub_message(identity, header, body)
            
        -- If message destination is another endpoint
        else
            local protocol, hostname, port, path = self:split_uri(uri_to)
            if hostname == self.hostname and port == self.port then
                -- Message destination is in the same process
                self.broker_socket:sendx(identity, header, body)
            else
                -- Message destination is in another process
                local socket = self:get_socket(uri_to)
                socket:sendx(header, body)
            end
        end
    end)
    
    -- Send a TICK signal to every actor every TICK_INTERVAL milliseconds
    self.loop:add_interval(self.mal_context.tick_resolution, function()
        self:broadcast_signal(SIGNALS.TICK)
    end)

    self.actors = {}

    -- Start all the registered actors in separate threads
    for identity, code in pairs(self.mal_context.actors) do
        local actor = self:start_actor(identity, code)
        self.actors[identity] = actor
        self.loop:add_socket(actor, function(sock) 
            local signal = sock:recv()
            self:handle_signal(tonumber(signal), identity)
        end)
    end

    -- Start the broker loop. This call blocks until the loop
    -- is stopped by a command send from an actor
    self.loop:start()
end

function get_text_for_signal(signal)
    for k, v in SIGNALS do
        if v == signal then return k end
    end
    return tostring(signal)
end

function Binding:handle_signal(signal, identity)
    if self.verbose then 
        print(string.format('Broker handling %s signal...', get_text_for_signal(signal)))
    end
    if signal == SIGNALS.SHUTDOWN then
        self:stop()
    end
end

--- Sends a signal from an endpoint to the broker
function Binding:dispatch_signal(endpoint, signal)
    endpoint.socket:send(tostring(signal))
end

--- Sends a signal from an endpoint to the broker
function Binding:shutdown(endpoint)
    endpoint.socket:send(tostring(SIGNALS.SHUTDOWN))
end

--- Sends a signal to the endpoint (actor) matching the provided identity
-- Signals are used for actor shutdown (TERM) or ticks (TICK)
function Binding:send_signal(signal, identity)
    self.actors[identity]:send(tostring(signal))
end

--- Broadcasts a signal to every known actors
function Binding:broadcast_signal(signal)
    if self.verbose then print(string.format('Broadcasting %s signal to actors...', get_text_for_signal(signal))) end
    for _, actor in pairs(self.actors) do
        actor:send(tostring(signal))
    end
end

--- Stops the broker and closes all open connections to the
-- outside world
function Binding:stop()
    if self.verbose then print('Broadcasting TERM  down...') end
    self:broadcast_signal(SIGNALS.TERM)
    for _, actor in pairs(self.actors) do
        actor:join()
    end
    if self.verbose then print('Shutting down...') end
    self.peers = {}
    self.connections = {}
    self.subscriptions = {}
    self.loop:stop()
    if self.verbose then print('Bye.') end
end

--- Processes messages that take part in a brokered pubsub interaction
function Binding:process_pubsub_message(identity, header, body)
    local msg = self:make_mal_message(header, body)

    -- An internal provider publishes a message 
    if msg.interaction_stage == MAL_IP_STAGES.PUBSUB_PUBLISH then
        print('Published message: ' .. body)
        -- Convert the publish message to a notify message 
        msg.interaction_stage = MAL_IP_STAGES.PUBSUB_NOTIFY
        header = self:serialize_mal_header(msg)
        self.mal_pub_socket:sendx(tostring(header), body)

    -- An internal consumer registers for a set of publications
    elseif msg.interaction_stage == MAL_IP_STAGES.PUBSUB_REGISTER then
        local subscribers = self.subscriptions[msg.session][msg.area][msg.area_version][msg.service][msg.operation]
        table.insert(subscribers, identity)
        -- local zmq_uri = self:get_ps_uri(msg.uri_to)
        local zmq_uri = "tcp://localhost:6667"
        if self.connections[zmq_uri] == 0 then
            self.mal_sub_socket:connect(zmq_uri)
            print('Connected to ' .. zmq_uri)
        end
        self.connections[zmq_uri] = self.connections[zmq_uri] + 1

    -- An internal consumer deregisters for a set of publications
    elseif msg.interaction_stage == MAL_IP_STAGES.PUBSUB_DEREGISTER then
        local subscribers = self.subscriptions[msg.session][msg.area][msg.area_version][msg.service][msg.operation]
        table.insert(subscribers, identity)
    
        -- local zmq_uri = self:get_ps_uri(msg.uri_to)
        local zmq_uri = "tcp://localhost:6667"
        if self.connections[zmq_uri] >= 1 then
            self.connections[zmq_uri] = self.connections[zmq_uri] - 1
        end
        if self.connections[zmq_uri] <= 0 then
            self.mal_sub_socket:disconnect(zmq_uri)
            print('Disconnected from ' .. zmq_uri)
        end

    elseif msg.interaction_stage == MAL_IP_STAGES.PUBSUB_PUBLISH_REGISTER or
           msg.interaction_stage == MAL_IP_STAGES.PUBSUB_PUBLISH_DEREGISTER then
        -- No ops. External Pub socket is always open and never closed.
        -- Maybe at some point we will get fancy and close the socket when 
        -- there are no active publishers, maybe we won't.
    else
        error(string.format('Broker does not support MAL IP %s / %s', msg.interaction_type, msg.interaction_stage))
    end
end

--- Converts an endpoint identity (usually a path like 'demo/actor1') to
-- a fully qualifed malzmq url (e.g. malzmq://hostname:port/demo/actor1)
function Binding:create_uri(identity)
    return string.format('malzmq://%s:%d/%s', self.hostname, self.ptp_port, identity)   
end

--- Returns the MAL URI of the broker.
-- MAL PUBSUB messages addressed directly to the broker must
-- use the URI ain thir URI_TO field
function Binding:get_broker_uri()
    return string.format('malzmq://%s:%d/broker', self.hostname, self.ptp_port)   
end

--- Converts a mal_endpoit into a malzmq_endpoint
-- It creates a DEALER socket connected to the broker 
-- internal socket
function Binding:initialize_endpoint(mal_endpoint)    
    local protocol, host, port, path = self:split_uri(mal_endpoint.uri)
    mal_endpoint.socket_uri = self.broker_uri
    mal_endpoint.socket = self.zmq_context:socket(zmq.DEALER)
    mal_endpoint.socket:set_identity(path)
    mal_endpoint.identity = path
    err = mal_endpoint.socket:connect(self.broker_uri)
    zassert(mal_endpoint.socket, err)
    return mal_endpoint
end

--- Returns a socket used to communicate to the
-- peer matching provided mal uri
-- Sockets are created and added to the broker pool when 
-- used for the first time. 
function Binding:get_socket(uri_to)    
    local socket = self.peers[uri_to]
    if not socket then 
        socket = self.zmq_context:socket(zmq.DEALER)
        local ptp_uri = self:get_ptp_uri(uri_to)
        err = socket:connect(ptp_uri)
        zassert(socket, err)      
        self.peers[uri_to] = socket
    end
    return socket
end

--- Sends a MAL message over the provided MAL endpoint 
function Binding:send_message(endpoint, message)
    local header = self:serialize_mal_header(message)
    endpoint.socket:sendx(message.uri_to, tostring(header), message.body)
end

--- Converts an encoded header and body into a 
-- a MAL message structure
function Binding:make_mal_message(header, body)
    local header_buffer = Buffer(string.len(header) + 10)
    header_buffer:append_luastr_right(header)
    local length, msg = self:read_mal_header(header_buffer)
    msg.body = body
    return msg
end

--- Receives a message on the provided endpoint
-- @returns a MAL message with all its header fields 
function Binding:recv_message(endpoint)
    local header, body = endpoint.socket:recvx()

    -- If MAL message, process and return
    return self:make_mal_message(header, body)
end

--- Converts a MAL poller into a zmq poller
function Binding:initialize_poller(mal_poller)
    mal_poller.zmq_poller = poller:new()
    mal_poller.endpoints = {}
end

--- Adds an endpoint to the provided poller
function Binding:add_endpoint_to_poller(endpoint, poller)
    local id = poller.zmq_poller:add(endpoint.socket, zmq.POLLIN)
    poller.endpoints[id] = endpoint
end

--- Removes an endpoint from the provided poller
function Binding:remove_endpoint_from_poller(endpoint, poller)
    poller.zmq_poller:remove(endpoint.socket)  
    for id, ep in pairs(poller.endpoints) do
        if ep == endpoint then
            poller.endpoints[id] = nil
        end
    end
end

--- Wait until a message is available on the given poller
-- @returns nil if timeout, the endpoint on which the message 
-- has arrived otherwise
function Binding:wait(poller, timeout)
    local count, err = poller.zmq_poller:poll(timeout)    
    if err then
        error(err)
    end
    if not count then
        return nil
    end 
    local id, revents = poller.zmq_poller:next_revents_idx()
    local endpoint = poller.endpoints[id]
    if endpoint then
        return endpoint
    else
        error("poller trigger on an unknown endpoint")
    end
end

--- Starts the actor in a separate thread
function Binding:start_actor(identity, code)
    local zmq_actor = zthreads.actor(self.zmq_context, function(pipe, code, identity, hostname, port)
        local zloop = require "lzmq.loop"
        local mal = require "libmal"
        local malzmq = require "malzmq"
        local Context, Actor = mal.Context, mal.Actor
        local binding = malzmq(hostname, port)
        local SIGNALS = binding.SIGNALS
        local malctx = Context:new(binding)
        local Actor = loadstring(code)()
        local actor = Actor:new(malctx, identity)

        local loop = zloop:new(2)

        --- Process internal signals submitted through the actor's pipe
        loop:add_socket(pipe, function(sock) 
            local signal = sock:recv()
            signal = tonumber(signal)
            if signal == SIGNALS.TERM then
                loop:stop()
            elseif signal == SIGNALS.TICK then
                actor:handle_tick()
            elseif signal > 255 then
                actor:handle_signal(signal)
            end
        end)

        loop:add_socket(actor.socket, function(sock) 
            local header, body = actor.socket:recvx()
            actor:handle_message(binding:make_mal_message(header, body)) 
        end)

        loop:start()
    end, code, identity, self.hostname, self.ptp_port)

    zmq_actor:start()
    return zmq_actor
end

--- Splits a MALZMQ URI into its components
-- @returns protocol, hostname, port, path
function Binding:split_uri(mal_uri)
    local protocol, host, port, path
    local s = mal_uri
    local i, j = string.find(s, "://")
    if i then
        protocol = string.sub(s, 1, i-1)
        s = string.sub(s, j+1)
    end
    i, j = string.find(s, ":")
    if i then
        host = string.sub(s, 1, i-1)
        s = string.sub(s, i+1, #s)
        i, j = string.find(s, "/")
        port = tonumber(string.sub(s, 1, i-1))
        s = string.sub(s, j+1)
    end
    return protocol, host, port, s
end

--- Gets the zmq point-to-point uri corresponding to this
-- malzmq uri
function Binding:get_ptp_uri(mal_uri)
    local protocol, host, port, path = self:split_uri(mal_uri)
    return string.format("tcp://%s:%d", host, port)
end

--- Gets the zmq pubsub uri corresponding to this
-- malzmq uri
function Binding:get_ps_uri(mal_uri)
    local protocol, host, port, path = self:split_uri(mal_uri)
    return string.format("tcp://%s:%d", host, port+1)
end

--- Binds the mAL ZMQ Binding to the porvided mal context
function Binding:bind_context(mal_context)
    self.mal_context = mal_context
end

--- Forwards the provided message to the endpoint (actor)
-- whose identity matches the URI_TO field of the message header
function Binding:forward_to_endpoint(header, body)
    if self.options.verbose then
        self:log_msg(msg, "I: received message:\n")
    end

    local header_buffer = Buffer(string.len(header) + 10)
    header_buffer:append_luastr_right(header)
    local length, decoded_header = self:read_mal_header(header_buffer)
    local protocol, host, port, path = self:split_uri(decoded_header.uri_to)
    
    if not path then 
        self:log_msg(msg, "E: invalid message:\n")
    else
        self.broker_socket:sendx(path, header, body)
    end
end

--- Broadcasts the provided message to all the endpoints (actors)
function Binding:broadcast_to_subscribers(header, body)
    if self.options.verbose then
        self:log_msg(msg, "I: received message:\n")
    end

    local msg = self:make_mal_message(header)

    -- An internal provider publishes a message 
    if msg.interaction_stage == MAL_IP_STAGES.PUBSUB_NOTIFY then
        local subscribers = self.subscriptions[msg.session][msg.area][msg.area_version][msg.service][msg.operation]
        for _, subscriber_identity in pairs(subscribers) do
            self.broker_socket:sendx(subscriber_identity, header, body)
        end
    else
        print("Ignored message ", msg.interaction_type, msg.interaction_stage)
    end
end

--- Converts a mapping directory key to a string
function Binding:mdk_to_string(mdk)
    -- FIXME
    return nil
end

--- Converts a string to a mapping directory key
function Binding:string_to_mdk(s)
    -- FIXME
    return nil
end

function Binding:get_timestamp()
    --  FIXME
    return 0
end

--- Returns the interaction type and the interaction stage
-- mathcing this SDU_type
function Binding:get_ip_type_and_stage(sdu_type, is_error_message)
    if sdu_type == 0 then
        return MAL_IP_TYPES.SEND, MAL_IP_STAGES.SEND
    elseif sdu_type == 1 then
        return MAL_IP_TYPES.SUBMIT, MAL_IP_STAGES.SUBMIT
    elseif sdu_type == 2 and not is_error_message then
        return MAL_IP_TYPES.SUBMIT, MAL_IP_STAGES.SUBMIT_ACK
    elseif sdu_type == 2 then
        return MAL_IP_TYPES.SUBMIT, MAL_IP_STAGES.SUBMIT_ERROR
    elseif sdu_type == 3 then
        return MAL_IP_TYPES.REQUEST, MAL_IP_STAGES.REQUEST
    elseif sdu_type == 4 and not is_error_message then
        return MAL_IP_TYPES.REQUEST, MAL_IP_STAGES.REQUEST_RESPONSE
    elseif sdu_type == 4 then
        return MAL_IP_TYPES.REQUEST, MAL_IP_STAGES.REQUEST_ERROR
    elseif sdu_type == 5 then
        return MAL_IP_TYPES.INVOKE, MAL_IP_STAGES.INVOKE
    elseif sdu_type == 6 and not is_error_message then
        return MAL_IP_TYPES.INVOKE, MAL_IP_STAGES.INVOKE_ACK
    elseif sdu_type == 6 then
        return MAL_IP_TYPES.INVOKE, MAL_IP_STAGES.INVOKE_ACK_ERROR
    elseif sdu_type == 7 and not is_error_message then
        return MAL_IP_TYPES.INVOKE, MAL_IP_STAGES.INVOKE_RESPONSE
    elseif sdu_type == 7 then
        return MAL_IP_TYPES.INVOKE, MAL_IP_STAGES.INVOKE_RESPONSE_ERROR
    elseif sdu_type == 8 then
        return MAL_IP_TYPES.PROGRESS, MAL_IP_STAGES.PROGRESS
    elseif sdu_type == 9 and not is_error_message then
        return MAL_IP_TYPES.PROGRESS, MAL_IP_STAGES.PROGRESS_ACK
    elseif sdu_type == 9 then
        return MAL_IP_TYPES.PROGRESS, MAL_IP_STAGES.PROGRESS_ACK_ERROR
    elseif sdu_type == 10 and not is_error_message then
        return MAL_IP_TYPES.PROGRESS, MAL_IP_STAGES.PROGRESS_UPDATE
    elseif sdu_type == 10 then
        return MAL_IP_TYPES.PROGRESS, MAL_IP_STAGES.PROGRESS_UPDATE_ERROR
    elseif sdu_type == 11 and not is_error_message then
        return MAL_IP_TYPES.PROGRESS, MAL_IP_STAGES.PROGRESS_RESPONSE
    elseif sdu_type == 11 then
        return MAL_IP_TYPES.PROGRESS, MAL_IP_STAGES.PROGRESS_RESPONSE_ERROR
    elseif sdu_type == 12 then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_REGISTER
    elseif sdu_type == 13 and not is_error_message then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_REGISTER_ACK
    elseif sdu_type == 13 then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_REGISTER_ERROR
    elseif sdu_type == 14 then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH_REGISTER
    elseif sdu_type == 15 and not is_error_message then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH_REGISTER
    elseif sdu_type == 15 then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH_REGISTER_ERROR
    elseif sdu_type == 16 and not is_error_message then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH
    elseif sdu_type == 16 then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH_ERROR
    elseif sdu_type == 17  then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_NOTIFY
    elseif sdu_type == 18 then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_DEREGISTER
    elseif sdu_type == 19 then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_DEREGISTER_ACK
    elseif sdu_type == 20 then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH_DEREGISTER
    elseif sdu_type == 21 then
        return MAL_IP_TYPES.PUBSUB, MAL_IP_STAGES.PUBSUB_PUBLISH_DEREGISTER_ACK
    else
        error('Invalid SDU Type')
    end
end

--- Deserializes a MAL message header
function Binding:read_mal_header(buffer)
    local header = {}
    header.version_number   = buffer:read_uint3 (0) 
    header.sdu_type         = buffer:read_uint5 (3) 
    header.area             = buffer:read_uint16(8) 
    header.service          = buffer:read_uint16(24)
    header.operation        = buffer:read_uint16(40)
    header.area_version     = buffer:read_uint8 (56)
    header.is_error_message = buffer:read_uint1 (64) ~= 0
    header.qos_level        = buffer:read_uint3 (65)
    header.session          = buffer:read_uint4 (68)
    header.transaction_id   = buffer:read_uint64(72)
    -- 2 spare bits
    local presence_flags    = buffer:read_uint8 (136)
    local priority_flag     = bit.band(presence_flags, 32) ~= 0
    local timestamp_flag    = bit.band(presence_flags, 16) ~= 0
    local network_zone_flag = bit.band(presence_flags, 8) ~= 0
    local session_name_flag = bit.band(presence_flags, 4) ~= 0
    local domain_flag       = bit.band(presence_flags, 2) ~= 0
    local auth_id_flag      = bit.band(presence_flags, 1) ~= 0

    local location_in_bits = 144

    -- optional priority
    if priority_flag then
        header.priority = buffer:read_uint32(location_in_bits)
        location_in_bits = location_in_bits + 32
    else
        header.priority = self.default_header.priority
    end

    -- URI from
    local uri_from_length = buffer:read_int32(location_in_bits)
    location_in_bits = location_in_bits + 32
    if uri_from_length > 0 then
        header.uri_from = buffer:read_binary(location_in_bits, uri_from_length*8)
        location_in_bits = location_in_bits + uri_from_length*8
    end
    
    -- URI To
    local uri_to_length = buffer:read_int32(location_in_bits)
    location_in_bits = location_in_bits + 32
    if uri_to_length > 0 then
        header.uri_to = buffer:read_binary(location_in_bits, uri_to_length*8)
        location_in_bits = location_in_bits + uri_to_length*8
    end
    
    -- optional timestamp
    if timestamp_flag then
        header.timestamp = buffer:read_uint32(location_in_bits)
        location_in_bits = location_in_bits + 32
    else
        header.timestamp = nil
    end

    -- optional network zone
    if network_zone_flag then
        local network_zone_length = buffer:read_int32(location_in_bits)
        location_in_bits = location_in_bits + 32
        if network_zone_length > 0 then
            header.network_zone = buffer:read_binary(location_in_bits, network_zone_length*8)
            location_in_bits = location_in_bits + network_zone_length*8
        end
    else
        header.network_zone = self.default_header.network_zone
    end

    -- optional session name
    if session_name_flag then
        local session_name_length = buffer:read_int32(location_in_bits)
        location_in_bits = location_in_bits + 32
        if session_name_length > 0 then
            header.session_name = buffer:read_binary(location_in_bits, session_name_length*8)
            location_in_bits = location_in_bits + session_name_length*8
        end
    else
        header.session_name = self.default_header.session_name
    end
    
    -- optional domain
    if domain_flag then
        local domain_length = buffer:read_uint32(location_in_bits)
        location_in_bits = location_in_bits + 32
        header.domain_length = buffer:read_binary(location_in_bits, domain_length*8)
        location_in_bits = location_in_bits + domain_length*8
    else
        header.domain = self.default_header.domain
    end

    -- optional authentication id
    if auth_id_flag then
        local auth_id_length = buffer:read_uint32(location_in_bits)
        location_in_bits = location_in_bits + 32
        header.authentication_id = buffer:read_binary(location_in_bits, auth_id_length*8)
        location_in_bits = location_in_bits + auth_id_length*8
    else
        header.authentication_id = self.default_header.authentication_id
    end

    header.interaction_type, header.interaction_stage = self:get_ip_type_and_stage(header.sdu_type, header.is_error_message)
    return bit.rshift(location_in_bits, 3), header
end

--- Serializes a MAL message header
function Binding:serialize_mal_header(header)
    local buffer = Buffer(100)
    header.sdu_type = SDU_TYPES_BY_MAL_IP[header.interaction_type][header.interaction_stage]
    buffer:append_uint8(
        bit.bor(
            bit.lshift(self.version_number, 5),
            bit.band(header.sdu_type, 0x1F)))
    buffer:append_uint16(header.area)
    buffer:append_uint16(header.service)
    buffer:append_uint16(header.operation)
    buffer:append_uint8 (header.area_version)
    buffer:append_uint8 (
        bit.bor(
            bit.lshift(header.is_error_message and 1 or 0, 7),
            bit.lshift(bit.band(header.qos_level, 3), 4),
            bit.band(header.session, 0xF)))
    buffer:append_uint64(header.transaction_id)
    -- 2 spare bits
    local presence_flags = bit.bor(
        header.priority          and 32 or 0,
        header.timestamp         and 16 or 0,
        header.network_zone      and 8  or 0,
        header.session_name      and 4  or 0,
        header.domain            and 2  or 0,
        header.authentication_id and 1  or 0)
    buffer:append_uint8(presence_flags)

    -- optional priority
    if header.priority then
        buffer:append_uint32(header.priority)
    end

    -- URI from
    local uri_mdk = self:string_to_mdk(header.uri_from)
    if uri_mdk then
        buffer:append_int32(uri_mdk)
    else
        buffer:append_int32(string.len(header.uri_from))
        buffer:append_luastr_right(header.uri_from)
    end
    
    -- URI To
    local uri_mdk = self:string_to_mdk(header.uri_to)
    if uri_mdk then
        buffer:append_int32(uri_mdk)
    else
        buffer:append_int32(string.len(header.uri_to))
        buffer:append_luastr_right(header.uri_to)
    end

    -- optional timestamp
    if header.timestamp then
        buffer:append_uint32(header.priority)
    end

    -- optional network zone
    if header.network_zone then 
        local uri_mdk = self:string_to_mdk(header.network_zone)
        if uri_mdk then
            buffer:append_int32(uri_mdk)
        else
            buffer:append_int32(string.len(header.network_zone))
            buffer:append_luastr_right(header.network_zone)
        end
    end

    -- optional session name
    if header.session_name then 
        local uri_mdk = self:string_to_mdk(header.session_name)
        if uri_mdk then
            buffer:append_int32(uri_mdk)
        else
            buffer:append_int32(string.len(header.session_name))
            buffer:append_luastr_right(header.session_name)
        end
    end
    
    -- optional domain
    if header.domain then
        local uri_mdk = self:string_to_mdk(header.domain)
        if uri_mdk then
            buffer:append_int32(uri_mdk)
        else
            buffer:append_int32(string.len(header.domain))
            buffer:append_luastr_right(header.domain)
        end
    end

    -- optional authentication id
    if header.authentication_id then
        buffer:append_int32(string.len(header.authentication_id))
        buffer:append_luastr_right(header.authentication_id)
    end

    return buffer
end

return Binding
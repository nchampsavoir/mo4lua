local Buffer = require "3rdparty.buffer"
local mal = require "libmal"
local Actor, class = mal.Actor, mal.class
local MC = require "mcarea"

local Decom = require "libdecom"

function printf(fmt, ...)
  return io.write((string.format(fmt, ...)))
end


local PacketHandler = class('PacketHandler', MC.ConsumerMonitorPacketHandler)

function PacketHandler:on_notify(message)
    local actor = self.actor
    local verbose = actor.args.verbose 
    local dump_headers = actor.args.dump_headers
    local json = true -- actor.args.json
    local model = actor.args.model
    local decom = actor.decom
    local buffer = actor.buffer

    if not actor.start_time then
        actor.start_time = os.clock()
        actor.wall_clock_start_time = os.time()
    end

    actor.receive_buffer = actor.receive_buffer - 1

    if actor.receive_buffer == 0 then
        if verbose then print('Sending credit...') end
        actor.credit:send("CREDIT")     
        actor.receive_buffer = 200
    end

    actor.packet_count = (actor.packet_count or 0) + 1
    
    if verbose then print('Packet received.') end
    
    if message.body:len() == 0 then
        actor:shutdown()
        return
    end

    decom:append(message.body)
    if not decom:has_more() then 
        self.actor:shutdown()
    end    

    -- if packet is invalid, bail out
    if not decom:packet_is_valid() then
        print ("OUPS")
        os.exit(1)
    end       

    actor.total_bytes = actor.total_bytes + string.len(message.body)        
    
    decom:read_headers()

    -- print the content of the headers if the user asked for it        
    if dump_headers then decom:write_headers() end                

    -- if a decommutation model was provided
    if model then
        local first = true
        
        local s

        if json then 
            buffer:clear()        
            buffer:append_luastr_right("[")
        elseif msgpack then
            s = {}
        end

        -- decommute each parameter in the packet using the decom engine
        for k, raw_val, eng_val in decom:iter_values() do            
            actor.total_params = actor.total_params + 1

            if json then 
                -- serialize the parameter values to json 
                local s = string.format('%s[%s, %q]', (not first and ', ') or '', raw_val, eng_val)
                buffer:append_luastr_right(s)
            elseif msgpack then
                table.insert(s, {raw_val, eng_val})
            end

            first = false
        end
        
        if json then
            buffer:append_luastr_right("]\n") 
            s = tostring(buffer)
        elseif msgpack then
            s = mpac(s)
        end            

        -- publish the serialized json
        -- if pub then pub:send(s) end
        -- if pub then pub:send("X") end

        -- write the serialized json to disk
        if actor.outputfile then actor.outputfile:write(s) end
    end

    decom:next()
end

local DecomActor = class('DecomActor', Actor)

function DecomActor:init(args)
    local zmq = require "lzmq"
    local credit = self.context.binding.zmq_context:socket(zmq.PUSH)
    credit:connect(string.format("tcp://localhost:5444"))
    self.credit = credit
    credit:send("CREDIT")

    self.packet_handler = PacketHandler:new(self)
    self.args = args
    self.buffer = Buffer()
    self.total_params = 0
    self.total_bytes = 0
    self.outputfile = nil
    self.receive_buffer = 200

    if self.args.output then
        self.outputfile, err = io.open(self.args.output, "w")
        if self.outputfile == nil then
            print(err)
            os.exit()
        end
    end

    self.decom = Decom(self.args.model, self.args.pus_mode)
    if self.outputfile then self.outputfile:write("[\n") end
    self.packet_handler:register(self:get_broker_uri())
    print('Decom ready.')
end

function DecomActor:handle_tick()
    print(string.format('%d packets received for a total of %d kbytes.', self.decom.total_packets, self.total_bytes / 1000))
    print(string.format('%d parameters processed.', self.total_params))
end

function DecomActor:finalize()
    if self.outputfile then self.outputfile:write("]\n") end

    local end_time = os.clock()
    local elapsed_time = end_time-self.start_time
    local elapsed_wall_clock_time = os.time() - self.wall_clock_start_time

    self.decom:print_stats(io.stdout)    
    print ("----------------------------")
    print ("Bytes: " .. math.floor(self.total_bytes / 1000) .. " KB")
    print ("CPU Time: " .. string.format("%.2f s", elapsed_time))
    print ("Speed: " .. math.floor(self.total_bytes / elapsed_time / 1000) .. " KB/s")
    print ("Wall Clock Time: " .. elapsed_wall_clock_time .. " s")
end

return DecomActor

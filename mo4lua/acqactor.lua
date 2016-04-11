local Buffer = require "3rdparty.buffer"
local mal = require "libmal"
local MC = require "mcarea"
local Decom = require "libdecom"

local Actor, class = mal.Actor, mal.class
local PacketHandler = class('PacketHandler', MC.ProviderMonitorPacketHandler)
local AcqActor = class('AcqActor', Actor)

function AcqActor:init(args)

    local zmq = require "lzmq"
    local control = self.context.binding.zmq_context:socket(zmq.PULL)
    local url = string.format("tcp://*:5444")
    control:bind(url)
    self.control = control

    self.total_credit = 0
    while true do
        msg = control:recv()   
        if msg == "CREDIT" then 
            self.total_credit = self.total_credit + 200 
            print('Credit: ' .. tostring(self.total_credit))
        elseif msg == "GO" then
            break
        else
            print("Wrong control message " .. msg)
        end
    end

    local file, err = io.open(args.inputfile, "rb")
    if file == nil then
        print(err)
        self:shutdown()
    end

    self.args = args
    self.packet_handler = PacketHandler:new(self)
    self.buffer = Buffer()
    self.total_bytes = 0
    self.start_time = nil
    self.decom = Decom()

    self.start_time = os.clock()
    self.wall_clock_start = os.time()
    print('Processing file ' .. args.inputfile .. ' ...')
    self:process_file(file)
end

function AcqActor:process_file(file)
    local block
    local decom = self.decom
    local broker_uri = self:get_broker_uri()
    local packet_handler = self.packet_handler
    local verbose = self.args.verbose
    local block_size = 2^15

    while true do
        block = file:read(block_size)    
        if block == nil then
            break -- EOF
        end

        -- push block at the end of the decom buffer
        decom:append(block)

        -- while there are still packets to be read in the decom buffer
        while decom:has_more() do

            -- if packet is invalid, bail out
            if not decom:packet_is_valid() then
                print ("OUPS")
                os.exit(1)
            end

            -- ensure that we still have credit to send new packets
            if self.total_credit == 0 then
                -- if not, wait for new credit
                if verbose then print('Waiting for credit...') end
                self.control:recv()      
                self.total_credit = 200
                if verbose then print('Credit received.') end
            end     

            -- get the content of the packet from the decom buffer
            local packet_data = decom:get_packet()

            -- send the content of the packet over the pub socket
            -- if verbose then print('Sending packet ...') end
            packet_handler:publish(broker_uri, packet_data)
            
            -- update stats and credits
            self.total_bytes = self.total_bytes + string.len(packet_data)
            self.total_credit = self.total_credit - 1

            -- move to the next packet
            decom:next()
        end
    end
    packet_handler:publish(broker_uri, "")
    self:shutdown()
end

function AcqActor:handle_tick()
    print("Credit: " ..tostring(self.total_credit))
end

function AcqActor:finalize()
    local end_time = os.clock()
    local elapsed_time = end_time-self.start_time
    local elapsed_wall_clock_time = os.time() - self.wall_clock_start

    self.decom:print_stats(io.stdout)    
    print ("----------------------------")
    print ("Bytes: " .. math.floor(self.total_bytes / 1000) .. " KB")
    print ("CPU Time: " .. string.format("%.2f s", elapsed_time))
    print ("Speed: " .. math.floor(self.total_bytes / elapsed_time / 1000) .. " KB/s")
    print ("Wall Clock Time: " .. elapsed_wall_clock_time .. " s")
    
end

return AcqActor

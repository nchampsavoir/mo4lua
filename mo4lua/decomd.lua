local zmq      = require "lzmq"
local ztimer  = require "lzmq.timer"
local argparse = require "3rdparty.argparse"
local Buffer = require "3rdparty.buffer"
local mp = require '3rdparty.MessagePack'

local Decom = require "libdecom"

local parser = argparse("decomd", "A telemetry decommutation daemon in lua")
parser:option("-c --acqd-ctrl", "Acquisition Daemon control port number", "6666")
parser:option("-s --acqd-subscribe", "Acquisition Daemon subscription port number", "6677")
parser:option("-p --publish", "Publish port number", "6669")
parser:flag("-v --verbose")
parser:flag("-d --dump-headers", "Dump headers content")
parser:flag("-u --pus-mode", "Read PUS secondary headers")
parser:option("-o --output", "Write JSON output to a file")
parser:option("-m --model", "Decommutation model generated from an XTCE file")
parser:option("-f --format", "Published messages format", "json")



local args = parser:parse()
local context = zmq.init(1)

function printf(fmt, ...)
  return io.write((string.format(fmt, ...)))
end


--  Socket to receive packets from
local credit = context:socket(zmq.PUSH)
credit:connect(string.format("tcp://localhost:%s", args.acqd_ctrl))

--  Socket to receive packets from
local sub = context:socket(zmq.SUB)
sub:set_subscribe("")
sub:connect(string.format("tcp://localhost:%s", args.acqd_subscribe))

--  Socket to publish decommuted packets to
local pub 
local pub_url
if args.publish then
    pub = context:socket(zmq.PUB)
    pub_url = string.format("tcp://*:%s", args.publish) 
    pub:bind(pub_url)
    print('Publishing on ' .. pub_url .. '.')
end

local outputfile = nil
if args.output then
    outputfile, err = io.open(args.output, "w")
    if outputfile == nil then
        print(err)
        os.exit()
    end
end

local model = args.model
local decom = Decom(model, args.pus_mode)

local total_bytes = 0    
local start_time = 0
local receive_buffer = 0   
local total_params = 0
local verbose = args.verbose 
local msgpack = args.format == "msgpack"
local json = args.format == "json"
local mpac = mp.pack


start_time = os.clock()

if outputfile then outputfile:write("[\n") end

local buffer = Buffer()

print('Ready.')

--  Process tasks forever
while true do   
    if receive_buffer == 0 then
        if verbose then print('Sending credit...') end
        credit:send("CREDIT")     
        receive_buffer = 200
    end

    if verbose then print('Waiting for packets...') end
    local msg = sub:recv()   
    if verbose then print('Packet received.') end
    
    decom:append(msg)
    if not decom:has_more() then break end    

    -- if packet is invalid, bail out
    if not decom:packet_is_valid() then
        print ("OUPS")
        os.exit(1)
    end       

    total_bytes = total_bytes + string.len(msg)        
    if decom.total_packets % 100000 == 0 then print('Packets received: ' .. decom.total_packets) end
    receive_buffer = receive_buffer - 1

    decom:read_headers()

    -- print the content of the heders if the user asked for it        
    if args.dump_headers then decom:write_headers() end                

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
            total_params = total_params + 1

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
        if pub then pub:send(s) end
        -- if pub then pub:send("X") end

        -- write the serialized json to disk
        if outputfile then outputfile:write(s) end
    end

    decom:next()
end

if outputfile then outputfile:write("]\n") end
pub:send('END')

local end_time = os.clock()
local elapsed_time = end_time-start_time

decom:print_stats(io.stdout)    
print ("----------------------------")
print ("Bytes: " .. math.floor(total_bytes / 1000) .. " KB")
print ("Time: " .. string.format("%.2f s", elapsed_time))
print ("Speed: " .. math.floor(total_bytes / elapsed_time / 1000) .. " KB/s")

ztimer.sleep(2000)

sub:close()
credit:close()   
context:term()
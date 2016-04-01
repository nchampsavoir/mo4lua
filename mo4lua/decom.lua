--
--  Demo parser for CCSDS SPACE PACKETS
--
local argparse = require "3rdparty.argparse"
local Buffer = require "3rdparty.buffer"
local Decom = require "libdecom"
local mp = require '3rdparty.MessagePack'

local parser = argparse("decomcli", "Command line interface to libdecom")
parser:argument("inputfile")
parser:flag("-v --verbose", "Dump headers content")
parser:flag("-d --debug", "Set debug mode on")
parser:flag("-p --pus-mode", "Read PUS secondary headers")
parser:flag("-n --no-output", "Pur computation mode - no serialization and nothing written to disk")
parser:option("-o --output", "Defaults to input-file + .json")
parser:option("-m --model", "Decommutation model generated from an XTCE file")

local args = parser:parse()

local inputfile, err = io.open(args.inputfile, "rb")
if inputfile == nil then
    print(err)
    os.exit()
end


local outputfile = nil
if not args.no_output then
    args.output = args.output or args.inputfile .. ".json"
    outputfile, err = io.open(args.output, "w")
    if outputfile == nil then
        print(err)
        os.exit()
    end
end


local model = args.model
local decom = Decom(model, {pus=args.pus_mode, debug=args.debug})
local start_time = os.clock()
local total_bytes = 0
local total_params = 0
local block_size = 2^16
local total_block = 0

function pprint(tbl)
  for attr, value in pairs(tbl) do
    print(attr .. "=" .. value)   
  end
end

if outputfile then outputfile:write("[") end

-- for every packet in the input stream
while true do

    -- if there is still data left in the input file push them to
    -- the decom internal buffer
    block = inputfile:read(block_size)        
    if block == nil then break end -- EOF    
    decom:append(block)
    total_block = total_block + 1

    -- for every packet in the decom buffer
    while decom:has_more() do

        -- if packet is not valid, bail out
        if not decom:packet_is_valid() then
            print ("OUPS")            
            os.exit(-1)
        end        

        total_bytes = total_bytes + decom.packet_length

        decom:read_headers()        

        -- print the content of the heders if the user asked for it        
        if args.verbose then 
            print('-- PACKET #' .. tostring(decom.total_packets + 1))
            decom:write_headers()
        end                

        -- if a decommutation model was provided
        if model then
            local first = true
            if outputfile then outputfile:write("[\n") end

            -- decommute each parameter in th packet using the decom engine
            for k, raw_val, eng_val in decom:iter_values() do            
                total_params = total_params + 1

                if outputfile then 
                    -- serialize the parameter values to json 
                    local s = string.format('%s  {"m": "%s", "r": "%s", "e": "%s"}', (not first and ',\n') or '', k, raw_val, eng_val)
                    
                    -- write the serialized json to disk
                    outputfile:write(s) 
                end
                first = false
            end
            if outputfile then outputfile:write("\n], ") end
        end

        decom:next()       
    end
end

inputfile:close()
if outputfile then outputfile:write("\n]\n") end

local end_time = os.clock()
local elapsed_time = end_time - start_time

decom:print_stats()

print ("----------------------------")
print ("Bytes: " .. math.floor(total_bytes / 1000) .. " KB")
print ("Time: " .. string.format("%.2f s", elapsed_time))
print ("Speed: " .. math.floor(total_bytes / elapsed_time / 1000) .. " KB/s")
print ("Parameters: " .. total_params .. " params")
print ("Speed: " .. math.floor(total_params / elapsed_time) .. " params/s")



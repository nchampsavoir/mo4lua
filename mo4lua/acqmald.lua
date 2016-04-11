-- ACQUISITION Daemon using the LUA MAL API

local mal = require "libmal"
local malzmq = require "malzmq"
local argparse = require "3rdparty.argparse"

local parser = argparse("acqd", "A telemetry acquisition daemon in lua")
parser:argument("inputfile")
parser:option("-p --port", "Control port number", "6666")
parser:flag("-v --verbose")

local args = parser:parse()

local Context = mal.Context
local binding = malzmq('localhost', args.port)
local malctx = Context:new(binding)

malctx:add_actor('acq', '@acqactor.lua', args)
malctx:start()
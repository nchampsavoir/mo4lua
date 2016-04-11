-- DECOM Daemon using the LUA MAL API

local mal = require "libmal"
local malzmq = require "malzmq"
local argparse = require "3rdparty.argparse"

local parser = argparse("decomd", "A telemetry decommutation daemon in lua")
parser:option("-s --acqd-subscribe", "Acquisition Daemon subscription port number", "5557")
parser:option("-p --port", "Port number", "6670")
parser:flag("-v --verbose")
parser:flag("-d --dump-headers", "Dump headers content")
parser:flag("-u --pus-mode", "Read PUS secondary headers")
parser:option("-o --output", "Write JSON output to a file")
parser:option("-m --model", "Decommutation model generated from an XTCE file")
parser:option("-f --format", "Published messages format", "json")

local args = parser:parse()

local Context = mal.Context
local binding = malzmq('localhost', args.port)
local malctx = Context:new(binding)

malctx:add_actor('decom', '@decomactor.lua', args)
malctx:start()
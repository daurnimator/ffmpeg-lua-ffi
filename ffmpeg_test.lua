-- A test for ffi based ffmpeg bindings
-- Based on https://github.com/mkottman/ffi_fun/blob/master/ffmpeg_audio.lua

local FILENAME = assert ( arg[1] , "No input file" )

package.path = "./?/init.lua;" .. package.path
package.loaded [ "ffmpeg" ] = dofile ( "init.lua" )
local ffmpeg = 		require"ffmpeg"
local avutil = 		ffmpeg.avutil
local avAssert = 	ffmpeg.avAssert
local avcodec = 	ffmpeg.avcodec
local avformat =	ffmpeg.avformat

local ffi = 		require"ffi"

local SECTION = print

SECTION "Opening file"

local formatctx = ffmpeg.openfile ( FILENAME )
local audioctx = assert ( ffmpeg.findaudiostreams ( formatctx ) [ 1 ] , "No Audio Stream Found" )

print ( "Bitrate:", 	tonumber(audioctx.bit_rate))
print ( "Channels:", 	tonumber(audioctx.channels))
print ( "Sample rate:",	tonumber(audioctx.sample_rate))
print ( "Sample type:",	({[0]="u8", "s16", "s32", "flt", "dbl"}) [ audioctx.sample_fmt ] )


SECTION "Decoding"

local all_samples = {}
local total_samples = 0

local buffsize = 192000--ffmpeg.AVCODEC_MAX_AUDIO_FRAME_SIZE
local frame_size = ffi.new ( "int[1]" )

local output_type = ffmpeg.format_to_type [ audioctx.sample_fmt ]
local output_buff = ffi.new ( output_type .. "[?]" , buffsize )

for packet in ffmpeg.read_frames ( formatctx ) do
	frame_size[0] = buffsize
	avAssert ( avcodec.avcodec_decode_audio3 ( audioctx , output_buff , frame_size , packet ) )
	local size = tonumber ( frame_size[0] ) / ffi.sizeof ( output_type ) -- frame_size is in bytes

	local frame = ffi.new ( "int16_t[?]" , size )
	ffi.copy ( frame , output_buff , size*2 )
	all_samples[#all_samples + 1] = frame
	total_samples = total_samples + size
end


SECTION "Merging samples"

local samples = ffi.new ( "int16_t[?]" , total_samples )
local offset = 0
for _ , s in ipairs ( all_samples ) do
	local size = ffi.sizeof ( s )
	ffi.copy ( samples + offset , s , size )
	offset = offset + size/2
end

local outfilename = "samples.raw"
SECTION "Generating: " .. outfilename

local out = assert ( io.open ( outfilename , 'wb' ) )
local size = ffi.sizeof ( samples )
out:write ( ffi.string ( samples , size ) )
out:close ( )

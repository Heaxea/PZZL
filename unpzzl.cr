#!/usr/bin/env crystal
# unpzzl

# files bigger than this will be read in chunks of this size
CHUNK_SIZE = 1073741824 # 1GiB


require "option_parser"
require "colorize"

VERSION = "1.1.0" # File Format Version, Program Version, Program Revision

MAGIC = Bytes[0x50,0x5A,0x5A,0x4C, 0x00] # "PZZL" & null

enum EXIT_CODE
	SUCCESS
	UNKNOWN_ERROR
	SYSTEM_ERROR
	INCORRECT_USAGE
	MISSING_DATA
	INVALID_FILE
	UNSUPPORTED_VERSION
	UNSUPPORTED_FEATURES
	FILE_SKIPPED
end

module Flag
	class_property info   = false
	class_property strict = false
	class_property quiet  = false
	class_property silent = false
end

fileList = [] of String


def log(level, msg, errorCode = 1)
	level = level.upcase
	case level
	when "ERROR"
		STDERR.puts "[#{level}] :: [#{EXIT_CODE.new(errorCode)}] :: #{msg}".colorize(:red) unless Flag.silent
		raise EXIT_CODE.new(errorCode).to_s
	when "WARN"
		puts "[#{level}]  :: #{msg}".colorize(:light_yellow) unless Flag.quiet
	end
end

def getPZLheader(fname)
	header = Bytes.new(16)
	if File.file?(fname) && File.readable?(fname)
		File.open(fname) do |file|
			log("ERROR", "header is too short", 4) if file.read(header) < 16
		end
		return header
	else
		log("ERROR", "cannot read input file: #{fname}", 2)
		exit(1) # should be unreachable, required to compile
	end
end

def getPZLhash(fname)
	hash = Bytes.new(32)
	File.open(fname) do |file|
		file.skip(16)
		log("ERROR", "missing hash data", 4) if file.read(hash) < 32
	end
	return hash
end

def parsePZL(header)
	type, version, features, metadata, padding = 0, 0x00_u8, 0x00_u8, false, Bytes.new(8)
	level = Flag.strict ? "ERROR" : "WARN"
	log("ERROR", "not a PZZL file", 5) if header[0..4] != MAGIC
	version = header[5]
	if version == 0
		if Flag.strict
			log("ERROR", "[STRICT] :: version is 0", 5)
		else
			return [type]
		end
	end
	log("ERROR", "version number: #{version}", 6) if version > 1
	type = 10
	features = header[6]
	if features == 0
		features = 0x01_u8
		log(level, "reserved features number (0)", 5)
		return [type, version, features, metadata, padding.hexstring]
	end
	log("ERROR", "features: #{features}", 7) if features > 2
	metadata = header[7] == 0x00_u8 ? false : true
	log(level, "unsupported metadata value: #{header[7]}", 5) if metadata && header[7] < 0xFF_u8
	type = 11 if metadata
	padding = header[8..15]
	expected_padding = header[7] == 0xFF_u8 ? Bytes.new(8, 0xFF) : Bytes.new(8)
	log(level, "invalid padding: #{padding}", 5) unless padding == expected_padding
	return [type, version, features, metadata, padding.hexstring]
end

def infoPZL(data, fname)
	puts "PZL file format"
	puts "  Filename: #{fname}"
	type = data[0].as(Int)
	if type == 0
		puts "  Version: 0"
		return 16
	end
	puts "  Version:  #{data[1]}"
	puts "  Features: #{data[2] == 1 ? "(01) standard" : "(02) GPG signed"}"
	puts "  Metadata: #{data[3]}"
	puts "  Padding:  #{data[4]}"
	if type == 11
		hash = getPZLhash(fname)
		puts "  metadata: unchecked embedded SHA-256: #{hash.hexstring}"
		return 16+32
	end
	return 16
end

def getOffset(data, fname)
	if data[0].as(Int) == 11
		return 16+32
	else
		return 16
	end
end

def getOutFname(fname)
	outfile : String
	if fname.matches?(/\.pzz?l$/i) # filename extension ends in .pzl or .pzzl
		outfile = fname.sub(/\.pzz?l/i, "")
		if File.file?(outfile)
			log("WARN", "output file '#{outfile}' already exists")
			outfile = "#{outfile}.dat"
			log("WARN", "using output file '#{outfile}' instead")
		end
	else
		outfile = "#{fname}.dat"
	end
	log("ERROR", "output file already exists: #{outfile}", 2) if File.file?(outfile)
	begin
		File.touch(outfile)
	rescue
		log("ERROR", "cannot create output file: #{outfile}", 2)
	else
		log("ERROR", "cannot write output file: #{outfile}", 2) unless File.writable?(outfile)
	end
	return outfile
end

def copyData(infile, outfile, size, offset = 0, outMode = "wb")
	data = Bytes.new(size)
	File.open(infile, "rb") do |infile|
		infile.skip(offset) if offset > 0
		infile.read(data)
	end
	File.open(outfile, outMode) do |outfile|
		outfile.write(data)
	end
end

def setup(fname)
	if Flag.quiet
		offset = getOffset(parsePZL(getPZLheader(fname)),fname)
	else
		offset = infoPZL(parsePZL(getPZLheader(fname)),fname)
	end
	if Flag.info
		outfile = ""
	else
		outfile = getOutFname(fname)
	end
	return [outfile, offset]
end

def extractData(infile, outfile, initOffset)
	chunkSize = 0_i64 + CHUNK_SIZE
	size = File.size(infile) - initOffset
	offset = 0_i64
	offset += initOffset
	if size > chunkSize
		chunkCount = (size // chunkSize) - 1
		remainder = size % chunkSize
		copyData(infile, outfile, chunkSize, offset: initOffset)
		chunkCount.times do |i|
			offset = chunkSize*(i+1) -1
			copyData(infile, outfile, chunkSize, offset: offset, outMode: "ab")
		end
		offset = size - remainder
		copyData(infile, outfile, remainder, offset: offset, outMode: "ab")
	else
		copyData(infile, outfile, size, offset: initOffset)
	end
end

parser = OptionParser.new do |parser|
	parser.banner = "unpzzl v#{VERSION}\n\nusage:\n    unpzzl [-i][-s][-q] <FILE>..."
	parser.on("-h", "--help", "show help and exit") {puts parser; exit(0)}
	parser.on("-v", "--version", "show version and exit") {
		puts "unpzzl v#{VERSION}"
		vvv = VERSION.split('.')
		puts "  Supported PZZL version: #{vvv[0]}"
		puts "  Program version: #{vvv[1]}.#{vvv[2]}"
		exit(0)}
	parser.on("-i", "--info",    "info only:   do not extract data") {Flag.info = true}
	parser.on("-s", "--strict",  "strict mode: do not attempt to process invalid files") {Flag.strict = true}
	parser.on("-q", "--quiet",   "quiet:  suppress output") {Flag.quiet = true}
	parser.on("-z", "--silent",  "silent: suppress most output") {Flag.quiet, Flag.silent = true, true}
	parser.invalid_option {|flag|
		STDERR.puts "[FATAL] :: [#{EXIT_CODE.new(3)}] :: invalid flag: '#{flag}'".colorize(:red)
		exit(3)}
	parser.unknown_args {|files| fileList = files}
end

if ARGV.size == 0
	STDERR.puts parser
	exit(3)
end
parser.parse

if fileList.size < 1
	STDERR.puts "[FATAL] :: [#{EXIT_CODE.new(3)}] :: requires at least one file".colorize(:red)
	exit(3)
end

errorCounter = 0
fileList.each do |fname|
	infile = File.basename(fname)
	begin
		outInfo = setup(infile)
	rescue ex
		STDERR.puts "[WARN]  :: #{EXIT_CODE.new(8)}: '#{fname}' because of error: [#{ex}]".colorize(:red)
		errorCounter += 1
	else
		unless Flag.info
			unless Flag.quiet
				puts "[info] Extracting data from '#{infile}'"
				fsize = File.size(infile)
				puts "[warn] Large file (~ #{fsize//(1024**3)} GB), may take a while!" if fsize > 1024**3
			end
			extractData(infile, outInfo[0].as(String), outInfo[1].as(Int))
		end
	end
end
if errorCounter == 0
	exit(0)
else
	log("WARN", "skipped #{errorCounter} files due to errors")
	exit(8)
end

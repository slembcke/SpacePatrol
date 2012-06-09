def system(str)
	puts str
	Kernel.system str
end

TEXTURE_TOOL = "/Developer/Platforms/iPhoneOS.platform/Developer/usr/bin/texturetool"

TAG = "-hd"

filename = ARGV[0]
basename = File.basename(filename, File.extname(filename));
dirname = File.dirname(filename)

system "../Support/retinaconvert --tag '#{TAG}' --dir /tmp --fmt png #{filename}"

def PVR(basename, indirname, outdirname, tag = "")
	inpath = File.join(indirname, basename + tag)
	outpath = File.join(outdirname, basename + tag)
	
	system "#{TEXTURE_TOOL} -e PVRTC -f PVR -p #{outpath}-pvrtc.png -o #{outpath}.pvr #{inpath}.png"
end

PVR(basename, "/tmp", dirname)
PVR(basename, "/tmp", dirname, '-hd')

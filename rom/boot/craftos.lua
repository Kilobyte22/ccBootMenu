@general(name="CraftOS",version="1.4",description="This is CraftOS, the default OS for ComputerCraft.",fullReplace=false)
@turtle(name="TurtleOS")
			
-- Load APIs
local tApis = fs.list( "rom/apis" )
for n,sFile in ipairs( tApis ) do
	if string.sub( sFile, 1, 1 ) ~= "." then
		local sPath = fs.combine( "rom/apis", sFile )
		if not fs.isDir( sPath ) then
			os.loadAPI( sPath )
		end
	end
end




if turtle then
	local tApis = fs.list( "rom/apis/turtle" )
	for n,sFile in ipairs( tApis ) do
		if string.sub( sFile, 1, 1 ) ~= "." then
			local sPath = fs.combine( "rom/apis/turtle", sFile )
			if not fs.isDir( sPath ) then
				os.loadAPI( sPath )
			end
		end
	end
end

-- Run the shell
local ok, err = pcall( function()
	parallel.waitForAny(
		function()
			rednet.run()
		end,
		function()
			os.run( {}, "rom/programs/shell" )
		end
	)
end )

-- If the shell errored, let the user read it.
if not ok then
	printError( err )
end

pcall( function()
	term.setCursorBlink( false )
	print( "Press any key to continue" )
	os.pullEvent( "key" ) 
end )
os.shutdown()


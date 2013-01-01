function pairs( _t )
	local typeT = type( _t )
	if typeT ~= "table" then
		error( "bad argument #1 to pairs (table expected, got "..typeT..")", 2 )
	end
	return next, _t, nil
end

function ipairs( _t )
	local typeT = type( _t )
	if typeT ~= "table" then
		error( "bad argument #1 to ipairs (table expected, got "..typeT..")", 2 )
	end
	return function( t, var )
		var = var + 1
		local value = t[var] 
		if value == nil then
			return
		end
		return var, value
	end, _t, 0
end

function coroutine.wrap( _fn )
	local typeT = type( _fn )
	if typeT ~= "function" then
		error( "bad argument #1 to coroutine.wrap (function expected, got "..typeT..")", 2 )
	end
	local co = coroutine.create( _fn )
	return function( ... )
		local tResults = { coroutine.resume( co, ... ) }
		if tResults[1] then
			return unpack( tResults, 2 )
		else
			error( tResults[2], 2 )
		end
	end
end

function string.gmatch( _s, _pattern )
	local type1 = type( _s )
	if type1 ~= "string" then
		error( "bad argument #1 to string.gmatch (string expected, got "..type1..")", 2 )
	end
	local type2 = type( _pattern )
	if type2 ~= "string" then
		error( "bad argument #2 to string.gmatch (string expected, got "..type2..")", 2 )
	end
	
	local nPos = 1
	return function()
		local nFirst, nLast = string.find( _s, _pattern, nPos )
		if nFirst == nil then
			return
		end		
		nPos = nLast + 1
		return string.match( _s, _pattern, nFirst )
	end
end

local nativesetmetatable = setmetatable
function setmetatable( _o, _t )
	if _t and type(_t) == "table" then
		local idx = rawget( _t, "__index" )
		if idx and type( idx ) == "table" then
			rawset( _t, "__index", function( t, k ) return idx[k] end )
		end
		local newidx = rawget( _t, "__newindex" )
		if newidx and type( newidx ) == "table" then
			rawset( _t, "__newindex", function( t, k, v ) newidx[k] = v end )
		end
	end
	return nativesetmetatable( _o, _t )
end

-- Install lua parts of the os api
function os.pullEventRaw( _sFilter )
	return coroutine.yield( _sFilter )
end

function os.pullEvent( _sFilter )
	local eventData = {os.pullEventRaw( _sFilter )}
	if eventData[1] == "terminate" then
		printError( "Terminated" )
		error()
	end
	return unpack(eventData)
end

-- Install globals
function sleep( _nTime )
    local timer = os.startTimer( _nTime )
	repeat
		local sEvent, param = os.pullEvent( "timer" )
	until param == timer
end

function write( sText )
	local w,h = term.getSize()		
	local x,y = term.getCursorPos()
	
	local nLinesPrinted = 0
	local function newLine()
		if y + 1 <= h then
			term.setCursorPos(1, y + 1)
		else
			term.setCursorPos(1, h)
			term.scroll(1)
		end
		x, y = term.getCursorPos()
		nLinesPrinted = nLinesPrinted + 1
	end
	
	-- Print the line with proper word wrapping
	while string.len(sText) > 0 do
		local whitespace = string.match( sText, "^[ \t]+" )
		if whitespace then
			-- Print whitespace
			term.write( whitespace )
			x,y = term.getCursorPos()
			sText = string.sub( sText, string.len(whitespace) + 1 )
		end
		
		local newline = string.match( sText, "^\n" )
		if newline then
			-- Print newlines
			newLine()
			sText = string.sub( sText, 2 )
		end
		
		local text = string.match( sText, "^[^ \t\n]+" )
		if text then
			sText = string.sub( sText, string.len(text) + 1 )
			if string.len(text) > w then
				-- Print a multiline word				
				while string.len( text ) > 0 do
					if x > w then
						newLine()
					end
					term.write( text )
					text = string.sub( text, (w-x) + 2 )
					x,y = term.getCursorPos()
				end
			else
				-- Print a word normally
				if x + string.len(text) - 1 > w then
					newLine()
				end
				term.write( text )
				x,y = term.getCursorPos()
			end
		end
	end
	
	return nLinesPrinted
end

function print( ... )
	local nLinesPrinted = 0
	for n,v in ipairs( { ... } ) do
		nLinesPrinted = nLinesPrinted + write( tostring( v ) )
	end
	nLinesPrinted = nLinesPrinted + write( "\n" )
	return nLinesPrinted
end

function printError( ... )
	if term.isColour() then
		term.setTextColour( 16384 )
	end
	print( ... )
	term.setTextColour( colours.white )
end

function printWarning( ... )
	if term.isColour() then
		term.setTextColour( 2 )
	end
	print( ... )
	term.setTextColour( colours.white )
end

function read( _sReplaceChar, _tHistory )
	term.setCursorBlink( true )

    local sLine = ""
	local nHistoryPos = nil
	local nPos = 0
    if _sReplaceChar then
		_sReplaceChar = string.sub( _sReplaceChar, 1, 1 )
	end
	
	local w, h = term.getSize()
	local sx, sy = term.getCursorPos()	
	
	local function redraw( _sCustomReplaceChar )
		local nScroll = 0
		if sx + nPos >= w then
			nScroll = (sx + nPos) - w
		end
			
		term.setCursorPos( sx, sy )
		local sReplace = _sCustomReplaceChar or _sReplaceChar
		if sReplace then
			term.write( string.rep(sReplace, string.len(sLine) - nScroll) )
		else
			term.write( string.sub( sLine, nScroll + 1 ) )
		end
		term.setCursorPos( sx + nPos - nScroll, sy )
	end
	
	while true do
		local sEvent, param = os.pullEvent()
		if sEvent == "char" then
			sLine = string.sub( sLine, 1, nPos ) .. param .. string.sub( sLine, nPos + 1 )
			nPos = nPos + 1
			redraw()
			
		elseif sEvent == "key" then
		    if param == keys.enter then
				-- Enter
				break
				
			elseif param == keys.left then
				-- Left
				if nPos > 0 then
					nPos = nPos - 1
					redraw()
				end
				
			elseif param == keys.right then
				-- Right				
				if nPos < string.len(sLine) then
					nPos = nPos + 1
					redraw()
				end
			
			elseif param == keys.up or param == keys.down then
                -- Up or down
				if _tHistory then
					redraw(" ");
					if param == keys.up then
						-- Up
						if nHistoryPos == nil then
							if #_tHistory > 0 then
								nHistoryPos = #_tHistory
							end
						elseif nHistoryPos > 1 then
							nHistoryPos = nHistoryPos - 1
						end
					else
						-- Down
						if nHistoryPos == #_tHistory then
							nHistoryPos = nil
						elseif nHistoryPos ~= nil then
							nHistoryPos = nHistoryPos + 1
						end						
					end
					
					if nHistoryPos then
                    	sLine = _tHistory[nHistoryPos]
                    	nPos = string.len( sLine ) 
                    else
						sLine = ""
						nPos = 0
					end
					redraw()
                end
			elseif param == keys.backspace then
				-- Backspace
				if nPos > 0 then
					redraw(" ");
					sLine = string.sub( sLine, 1, nPos - 1 ) .. string.sub( sLine, nPos + 1 )
					nPos = nPos - 1					
					redraw()
				end
			elseif param == keys.home then
				-- Home
				nPos = 0
				redraw()		
			elseif param == keys.delete then
				if nPos < string.len(sLine) then
					redraw(" ");
					sLine = string.sub( sLine, 1, nPos ) .. string.sub( sLine, nPos + 2 )				
					redraw()
				end
			elseif param == keys["end"] then
				-- End
				nPos = string.len(sLine)
				redraw()
			end
		end
	end
	
	term.setCursorBlink( false )
	term.setCursorPos( w + 1, sy )
	print()
	
	return sLine
end

loadfile = function( _sFile )
	local file = fs.open( _sFile, "r" )
	if file then
		local func, err = loadstring( file.readAll(), fs.getName( _sFile ) )
		file.close()
		return func, err
	end
	return nil, "File not found"
end

dofile = function( _sFile )
	local fnFile, e = loadfile( _sFile )
	if fnFile then
		setfenv( fnFile, getfenv(2) )
		return fnFile()
	else
		error( e, 2 )
	end
end

-- Install the rest of the OS api
function os.run( _tEnv, _sPath, ... )
    local tArgs = { ... }
    local fnFile, err = loadfile( _sPath )
    if fnFile then
        local tEnv = _tEnv
		setmetatable( tEnv, { __index = _G } )
        setfenv( fnFile, tEnv )
        local ok, err = pcall( function()
        	fnFile( unpack( tArgs ) )
        end )
        if not ok then
        	if err and err ~= "" then
	        	printError( err )
	        end
        	return false
        end
        return true
    end
    if err and err ~= "" then
		printError( err )
	end
    return false
end

local nativegetmetatable = getmetatable
local nativetype = type
local nativeerror = error
function getmetatable( _t )
	if nativetype( _t ) == "string" then
		nativeerror( "Attempt to access string metatable", 2 )
		return nil
	end
	return nativegetmetatable( _t )
end

local tAPIsLoading = {}
local tLoadedAPIs = {}
function os.loadAPI( _sPath )
	local sName = fs.getName( _sPath )
	if tAPIsLoading[sName] == true then
		printError( "API "..sName.." is already being loaded" )
		return false
	end
	tAPIsLoading[sName] = true
		
	local tEnv = {}
	setmetatable( tEnv, { __index = _G } )
	local fnAPI, err = loadfile( _sPath )
	if fnAPI then
		setfenv( fnAPI, tEnv )
		fnAPI()
	else
		printError( err )
        tAPIsLoading[sName] = nil
		return false
	end
	
	local tAPI = {}
	for k,v in pairs( tEnv ) do
		tAPI[k] =  v
	end
	
	_G[sName] = tAPI	
	tAPIsLoading[sName] = nil
	table.insert(tLoadedAPIs,sName)
	return true
end

local function findValue( _tTable, _value )
	for i=1, #_tTable do
		if _tTable[i] == _value then
			return i
		end
	end
end

function os.unloadAPI( _sName )
	if _sName ~= "_G" and type(_G[_sName]) == "table" then
		_G[_sName] = nil
		table.remove(tLoadedAPIs, findValue(tLoadedAPIs, _sName))
	end
end

function os.getLoadedApis()
	if tLoadedAPIs[1] then
		return tLoadedAPIs
	end
end

function os.sleep( _nTime )
	sleep( _nTime )
end

local nativeShutdown = os.shutdown
function os.shutdown()
	nativeShutdown()
	while true do
		coroutine.yield()
	end
end

-- Install the lua part of the HTTP api (if enabled)
if http then
	local function wrapRequest( _url, _post )
		local requestID = http.request( _url, _post )
		while true do
			local event, param1, param2 = os.pullEvent()
			if event == "http_success" and param1 == _url then
				return param2
			elseif event == "http_failure" and param1 == _url then
				return nil
			end
		end		
	end
	
	http.get = function( _url )
		return wrapRequest( _url, nil )
	end

	http.post = function( _url, _post )
		return wrapRequest( _url, _post or "" )
	end
end

-- Install the lua part of the peripheral api
peripheral.wrap = function( _sSide )
	if peripheral.isPresent( _sSide ) then
		local tMethods = peripheral.getMethods( _sSide )
		local tResult = {}
		for n,sMethod in ipairs( tMethods ) do
			tResult[sMethod] = function( ... )
				return peripheral.call( _sSide, sMethod, ... )
			end
		end
		return tResult
	end
	return nil
end

-- Fancy Custom BootLoading stuff

local tBiosList = {}
local xSize, ySize = term.getSize()
local sSelectedBios
local nLastUsed
local tBios

local function runBios( _tEnv, _sBios )
    local fnFile, err = loadstring( _sBios )
    if fnFile then
        local tEnv = _tEnv
		setmetatable( tEnv, { __index = _G } )
        setfenv( fnFile, tEnv )
        local ok, err = pcall( fnFile )
        if not ok then
        	if err and err ~= "" then
	        	error( err )
	        end
        	return false
        end
        return true
    end
    if err and err ~= "" then
		error(err)
	end
    return false
end

local function UIDToNumber( _sUID )
	for i=1, #tBiosList do
		if _sUID == tBiosList[i].uid then
			return i
		end
	end
end

local function parseBios( _sName, _sDir )
	local sPath = _sDir.."/".._sName..".lua"
	local fBios = fs.open(sPath,"r")
	local sBios = fBios.readAll()
	fBios.close()
	local tAnnotations = {
		["general"] = {},
		["override"] = {
			["color"] = {},
			["turtle"] = {},
			["regular"] = {}
		}
	}
	for str in sBios:gmatch("(@ *%w+%([^%)]+%))") do
		if str:find('@ *%w+%( *"[^"]+" *%)') then
			local index, value = str:match('@ *(%w+)%( *"([^"]+)" *%)')
			value = value:gsub("\\n","\n")
			value = value:gsub("\\t","\t")
			tAnnotations.general[index] = value
		elseif str:find("@color") or str:find("@turtle") or str:find("@regular") then
			local sOverride = str:match("@ *(%w+)")
			local str2 = str:match("@ *%w+%(([^%)]+)%)")
			for str3 in str2:gmatch("[^,]+") do
				local index, value = str3:match('(%w+) *= *"([^"]+)"')
				value = value:gsub("\\n","\n")
				value = value:gsub("\\t","\t")
				tAnnotations.override[sOverride][index] = value
			end
		end
	end
	

	local function applyOverrides( _sOverride )
		local bOverride = false
		if _sOverride == "turtle" then bOverride = turtle
		elseif _sOverride == "color" then bOverride = term.isColor()
		elseif _sOverride == "regular" then bOverride = not (turtle or term.isColor()) end
		if bOverride then
			for k,v in pairs(tAnnotations.override[_sOverride]) do
				tAnnotations.general[k] = v
			end
		end
	end
	
	applyOverrides("turtle")
	applyOverrides("color")
	applyOverrides("regular")	
	tAnnotations = tAnnotations.general
	
	sBios = sBios:gsub("^@[^\n]+","")
	sBios = sBios:gsub("\n@[^\n]+","\n")

	return sBios, tAnnotations
end

local function scanBootDir( _sBootDir )
	if fs.isDir(_sBootDir) then
		local ok, tBootDirList = pcall(function() return fs.list(_sBootDir) end)
		for i = 1, #tBootDirList do
			local sBiosName = tBootDirList[i]
			
			if sBiosName:find(".lua$") then
				
				sBiosName = sBiosName:gsub(".lua$","")
				
				local ok, sBios, tAnnotations = pcall ( function() return parseBios(sBiosName,_sBootDir) end)
				if not ok then printError(sBios) end
				
				if not UIDToNumber(sBiosName) then
					table.insert(tBiosList,{["uid"]=sBiosName, ["annotations"] = tAnnotations, ["bios"] = sBios, ["isBeingUsed"] = false})
				end
			end
		end
	end
end

local function drawTextField( _sText, _nXPos, _nYPos, _nWidth, _nHeight )
	term.setCursorPos(_nXPos,_nYPos)
	local nXMax, nYMax = _nXPos + _nWidth - 1, _nYPos + _nHeight - 1
	while true do
		local nXCurs, nYCurs = term.getCursorPos()
		if _sText:find("^%S+") then
			local str = _sText:match("^%S+")
			if str:len() + nXCurs <= nXMax then 
				term.write(str)
			elseif nYCurs <= nYMax then
				term.setCursorPos(_nXPos,nYCurs + 1)
				term.write(str)
			end
			
			_sText = _sText:gsub("^%S+","")
		elseif _sText:find("^ ") then
			if nXCurs + 1 <= nXMax then
				term.write(" ")
			end
			_sText = _sText:gsub("^ ","")
			
		elseif _sText:find("^\n") then
			if nYCurs <= nYMax then
				term.setCursorPos(_nXPos,nYCurs + 1)
			end
			_sText = _sText:gsub("^\n","")
		elseif (nXCurs == nXMax) and (nXCurs == nXMax) then
			break
		else
			break
		end
	end	
end


local function fillBackground( _nColor, _nXPos, _nYPos, _nWidth, _nHeight )
	local nXMax, nYMax = _nXPos + _nWidth - 1, _nYPos + _nHeight - 1
	term.setBackgroundColor(_nColor)
	for x = _nXPos, nXMax do
		for y = _nYPos, nYMax do
			term.setCursorPos(x, y)
			term.write(" ")
		end
	end
end

local function DeactivateAll()
	for i=1, #tBiosList do
		tBiosList[i].isBeingUsed = false
	end
end

local function drawMenu()
	term.clear()
	if not nSelectedBios then nSelectedBios = nLastUsed or 1 end
	tBios = tBiosList[nSelectedBios]
	local sTitle = tBios.annotations.name.." "..tBios.annotations.version
	local sDescription = tBios.annotations.description	
	if term.isColor() then
		term.setTextColor(1)
		fillBackground(128, 1, 1, xSize, ySize)
		term.setCursorPos((xSize - sTitle:len()) / 2+1, 3)
		term.write(sTitle)
		term.setCursorPos((xSize - ("Press Enter to continue!"):len()) / 2+2, ySize-3)
		term.write("Press Enter to continue!")
		--arrow right
		if tBiosList[nSelectedBios + 1] then
			term.setCursorPos(xSize-3,ySize/2)
			term.write("\\")
			term.setCursorPos(xSize-3,ySize/2+1)
			term.write("/")
		end
		--arrow left
		if tBiosList[nSelectedBios - 1] then		
			term.setCursorPos(3,ySize/2)
			term.write("/")
			term.setCursorPos(3,ySize/2+1)
			term.write("\\")
		end
		--page count
		local sPageCount = "Page "..nSelectedBios.." of "..#tBiosList
		term.setCursorPos(xSize - (1 + sPageCount:len()),ySize-1)
		term.write(sPageCount)
		--description
		fillBackground(256, 9, 5, xSize -16, ySize -9)
		term.setTextColor(32768)
		drawTextField(sDescription or "No description provided." , 9, 5, xSize -16, ySize -9 )
		term.setTextColor(1)
		term.setBackgroundColor(32768)
	else
		term.setCursorPos((xSize + sTitle:len()) / 2 - sTitle:len(), 3)
		term.write(sTitle)
		term.setCursorPos((xSize - ("Press Enter to continue!"):len()) / 2+2, ySize-2)
		term.write("Press Enter to continue!")
		--arrow right
		if tBiosList[nSelectedBios + 1] then
			term.setCursorPos(xSize-3,ySize/2)
			term.write("\\")
			term.setCursorPos(xSize-3,ySize/2+1)
			term.write("/")
		end
		--arrow left
		if tBiosList[nSelectedBios - 1] then		
			term.setCursorPos(3,ySize/2)
			term.write("/")
			term.setCursorPos(3,ySize/2+1)
			term.write("\\")
		end
		--page count
		local sPageCount = "Page "..nSelectedBios.." of "..#tBiosList
		term.setCursorPos(xSize - (1 + sPageCount:len()),ySize-1)
		term.write(sPageCount)
		drawTextField(sDescription or "No description provided." , 9, 5, xSize -16, ySize -8 )
	end
end

function os.boot( _sUID )
	print(true)
	nBiosID = UIDToNumber(_sUID)
	if nBiosID then
		term.clear()
		term.setCursorPos(1,1)
		local fConfig = fs.open("boot/bootConf.cfg","w")
		fConfig.write("LastUsed = "..tBiosList[nSelectedBios or 1].uid)
		fConfig.close()
		DeactivateAll()
		tBiosList[nBiosID].isBeingUsed = true
		local ok, err = pcall(function() runBios({},tBiosList[nBiosID].bios) end)
		if not ok then
			pcall(function() printError(err) end)
			os.pullEvent("key")
		end
	end
end

function os.bootMenu()
	
	local function scrollRight()
		if nSelectedBios < #tBiosList then
			nSelectedBios = nSelectedBios + 1
		end
		drawMenu()
	end

	local function scrollLeft()
		if nSelectedBios > 1 then
			nSelectedBios = nSelectedBios - 1
		end
		drawMenu()
	end
	
	drawMenu()
	while true do
		event, p1, p2, p3 = os.pullEvent()
		if event == "key" then
			if p1 == 205 then -- right
				scrollRight()
			elseif p1 == 203 then -- left
				scrollLeft()
			elseif p1 == 28 then -- enter
				os.boot(tBiosList[nSelectedBios].uid)
			end
		elseif event == "mouse_click" then
			if p2 > xSize - 8 and p3 >= 5 and p3 <= ySize -5 then --right
				scrollRight()
			elseif p2 <= 8 and p3 >= 5 and p3 <= ySize -5 then -- left
				scrollLeft()
			elseif p2 <= xSize - 8 and p2 > 8 and p3 >= 5 and p3 <= ySize -5 then
				os.boot(tBiosList[nSelectedBios].uid)
				break
			end
		elseif event == "mouse_scroll" then
			if p1 == -1 then
				scrollLeft()
			elseif p1 == 1 then
				scrollRight()
			end
		end
	end
end

function os.version()
	local tBios = tBiosList[(nSelectedBios or nLastUsed) or 1]
	local sVersion
	return tBios.annotations.name.." "..tBios.annotations.version
end

function os.getBootList()
	return tBiosList
end

function os.setBootFile( _sUID )
	if UIDToNumber(_sUID) then
		local fConfig = fs.open("boot/bootConf.cfg","w")
		fConfig.write("LastUsed = ".._sUID)
		fConfig.close()
	end
end

-- Stuff finally happens here

scanBootDir("boot")
scanBootDir("rom/boot")

if not fs.exists("boot") then fs.makeDir("boot") end

if not tBiosList[2] and tBiosList[1] then
	os.boot(tBiosList[1].uid)
else
	local fConfig = fs.open("boot/bootConf.cfg","r")
	if fConfig then
		sConfig = fConfig.readAll()
		fConfig.close()
		nLastUsed = UIDToNumber(sConfig:match("LastUsed = ([^\n]+)"))
	end
	
	if nLastUsed then
		print("Booting...")
		print("Hold ctrl + t to open the boot menu.")
		os.startTimer(2)
		while true do
			event = os.pullEventRaw()
			if event == "timer" then
				os.boot(tBiosList[nLastUsed].uid)
				break
			elseif event == "terminate" then 
				os.bootMenu()
				break
			end
		end
	else
		os.bootMenu()
	end
end
os.shutdown()
-------------------------
--Nova Instance Tracker--
--Novaspark-Arugal OCE (classic).
--https://www.curseforge.com/members/venomisto/projects

NIT = LibStub("AceAddon-3.0"):NewAddon("NovaInstanceTracker", "AceComm-3.0");
if (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC) then
	NIT.isClassic = true;
elseif (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC) then
	NIT.isTBC = true;
elseif (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE) then
	NIT.isRetail = true;
end
NIT.LSM = LibStub("LibSharedMedia-3.0");
NIT.DDM = LibStub("LibUIDropDownMenu-4.0");
NIT.commPrefix = "NIT";
NIT.hasAddon = {};
NIT.realm = GetRealmName();
NIT.faction = UnitFactionGroup("player");
NIT.serializer = LibStub:GetLibrary("LibSerialize");
NIT.libDeflate = LibStub:GetLibrary("LibDeflate");
--NIT.aceGUI = LibStub:GetLibrary("AceGUI-3.0");
NIT.acr = LibStub:GetLibrary("AceConfigRegistry-3.0");
local L = LibStub("AceLocale-3.0"):GetLocale("NovaInstanceTracker");
local LDB = LibStub:GetLibrary("LibDataBroker-1.1");
NIT.LDBIcon = LibStub("LibDBIcon-1.0");
local version = GetAddOnMetadata("NovaInstanceTracker", "Version") or 9999;
NIT.classic = true;
NIT.latestRemoteVersion = version;
--local tbcRelease = 1622570400;
local utcTime = time(date("!*t", GetServerTime()));
if (NIT.isTBC) then
	NIT.hourlyLimit = 5;
	NIT.dailyLimit = 200;  --No limit in prepatch, but maybe limit after portal opens?
	--if (utcTime > tbcRelease) then
		NIT.maxLevel = 70;
	--else
	--	NIT.maxLevel = 60;
	--end
else
	NIT.hourlyLimit = 5;
	NIT.dailyLimit = 30;
	NIT.maxLevel = 60;
end
NIT.prefixColor = "|cFFFF6900";
NIT.perCharOnly = false; --Per char is gone in TBC, not sure how I didn't notice this earlier tbc, blizz never announced it.
NIT.loadTime = GetServerTime();

function NIT:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("NITdatabase", NIT.optionDefaults, "Default");
    LibStub("AceConfig-3.0"):RegisterOptionsTable("NovaInstanceTracker", NIT.options);
	self.NITOptions = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("NovaInstanceTracker", "NovaInstanceTracker");
	self:RegisterComm(self.commPrefix);
	self:buildDatabase();
	self.chatColor = "|cff" .. self:RGBToHex(self.db.global.chatColorR, self.db.global.chatColorG, self.db.global.chatColorB);
	self.mergeColor = "|cff" .. self:RGBToHex(self.db.global.mergeColorR, self.db.global.mergeColorG, self.db.global.mergeColorB);
	self.prefixColor = "|cff" .. self:RGBToHex(self.db.global.prefixColorR, self.db.global.prefixColorG, self.db.global.prefixColorB);
	self:createBroker();
	self:resetCharData();
	self:ticker();
	self:tickerCharacterData();
	self:resetOldLockouts();
end

NIT.regionFont = "Fonts\\ARIALN.ttf";
function NIT:setRegionFont()
	if (LOCALE_koKR) then
     	NIT.regionFont = "Fonts\\2002.TTF";
    elseif (LOCALE_zhCN) then
     	NIT.regionFont = "Fonts\\ARKai_T.ttf";
    elseif (LOCALE_zhTW) then
     	NIT.regionFont = "Fonts\\blei00d.TTF";
    elseif (LOCALE_ruRU) then
    	--ARIALN seems to work in RU.
     	--NIT.regionFont = "Fonts\\FRIZQT___CYR.TTF";
    end
end
NIT:setRegionFont();

--Add prefix and colors from db then print.
local printPrefix;
function NIT:print(msg, channel, prefix, nonClickable, tradeLog)
	if (prefix) then
		printPrefix = prefix;
	else
		printPrefix = "[NIT]";
	end
	if (channel == "group" or channel == "team") then
		channel = "party";
	end
	if (channel == "gchat" or channel == "gmsg") then
		channel = "guild";
	end
	if (channel == "say" or channel == "yell" or channel == "party" or channel == "guild" or channel == "officer" or channel == "raid") then
		SendChatMessage(printPrefix .. " " .. msg, channel);
	elseif (tonumber(channel)) then
		--Send to numbered channel by number.
		local id, name = GetChannelName(channel);
		if (id == 0) then
			print(NIT.chatColor .. "No channel with id " .. NIT.prefixColor .. channel .. NIT.chatColor .. " exists.");
			print(NIT.chatColor .. "Type \"/nit\" to show your instance history.");
			print(NIT.chatColor .. "Type \"/nit config\" to open options.");
			print(NIT.chatColor .. "Type \"/nit channelname\" to post your current lockouts to a channel.");
			return;
		end
		SendChatMessage(printPrefix .. " " .. NIT:stripColors(msg), "CHANNEL", nil, id);
	elseif (channel ~= nil) then
		--Send to numbered channel by name.
		local id, name = GetChannelName(channel);
		if (id == 0) then
			print(NIT.chatColor .. "No channel with id or name " .. NIT.prefixColor .. channel .. NIT.chatColor .. " exists.");
			print(NIT.chatColor .. "Type \"/nit\" to show your instance history.");
			print(NIT.chatColor .. "Type \"/nit config\" to open options.");
			print(NIT.chatColor .. "Type \"/nit channelname\" to post your current lockouts to a channel.");
			return;
		end
		SendChatMessage(printPrefix .. " " .. NIT:stripColors(msg), "CHANNEL", nil, id);
	else
		--if (not prefix) then
		--	printPrefix = "|HNITCustomLink:instancelog|h[NIT]|h|r";
		--end
		if (tradeLog) then
			printPrefix = "|HNITCustomLink:tradelog|h" .. printPrefix .. "|h|r";
			msg = "|HNITCustomLink:tradelog|h" .. msg .. "|h";
		elseif (string.match(msg, "|H.-|h(.-)|h")) then
			--If we put a chat link in the msg then don't re-add it, this is for strings with textures.
			--You can't add a seperate link inside another link, has to be done side by side in the string.
			printPrefix = "|HNITCustomLink:instancelog|h" .. printPrefix .. "|h|r";
		elseif (not nonClickable) then
			printPrefix = "|HNITCustomLink:instancelog|h" .. printPrefix .. "|h|r";
			msg = "|HNITCustomLink:instancelog|h" .. msg .. "|h";
		else
			printPrefix = "|HNITCustomLink:instancelog|h" .. printPrefix .. "|h|r";
		end
		print(NIT.prefixColor .. printPrefix .. " " .. NIT.chatColor .. msg);
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_SYSTEM")
f:SetScript('OnEvent', function(self, event, msg)
	local instance, success;
	local text = "";
	if (string.match(msg, string.gsub(INSTANCE_RESET_SUCCESS, "%%s", ".+"))) then
		instance = string.match(msg, string.gsub(INSTANCE_RESET_SUCCESS, "%%s", "(.+)"));
		text = msg;
		success = true;
	elseif (string.match(msg, string.gsub(INSTANCE_RESET_FAILED, "%%s", ".+"))) then
		instance = string.match(msg, string.gsub(INSTANCE_RESET_FAILED, "%%s", "(.+)"));
		--[[if (raid) then
		
		else
		
		end]]
		text = instance .. " " .. L["playersStillInside"];
		--Not sure why this is called a fail by Blizzard, the reset still works for everyone outside, and anyone that zones out after.
		success = true;
	elseif (string.match(msg, string.gsub(INSTANCE_RESET_FAILED_ZONING, "%%s", ".+"))) then
		instance = string.match(msg, string.gsub(INSTANCE_RESET_FAILED_ZONING, "%%s", "(.+)"));
		text = msg;
	elseif (string.match(msg, string.gsub(INSTANCE_RESET_FAILED_OFFLINE, "%%s", ".+"))) then
		instance = string.match(msg, string.gsub(INSTANCE_RESET_FAILED_OFFLINE, "%%s", "(.+)"));
		text = msg;
	end
	if (string.match(msg, TRANSFER_ABORT_TOO_MANY_INSTANCES)) then
		C_Timer.After(0.2, function()
			local msg, shortMsg, msgColorized = NIT:getInstanceLockoutInfoString();
			NIT:print(msgColorized);
		end)
		return;
	end
	--Strip plural escape from Korean client "SendChatMessage(): Invalid escape code in chat message".
	text = string.gsub(text, "|1이;가;", "이");
	if (success) then
		if (UnitIsGroupLeader("player")) then
			local cmd = "instanceReset";
			if (not NIT.db.global.instanceResetMsg) then
				--Tell the group if we're not announcing this to party so they can get still get a chat window print.
				cmd = "instanceResetNoMsg";
			end
			if (IsInRaid()) then
				NIT:sendComm("RAID", cmd .. " " .. version .. " " .. instance);
	  		elseif (IsInGroup()) then
	  			NIT:sendComm("PARTY", cmd .. " " .. version .. " " .. instance);
	  		end
	  	end
  	end
  	if (NIT.db.global.instanceResetMsg and instance and text) then
		if (IsInRaid()) then
  			SendChatMessage("[NIT] " .. NIT:stripColors(text), "RAID");
  		elseif (IsInGroup()) then
  			SendChatMessage("[NIT] " .. NIT:stripColors(text), "PARTY");
		end
  	end
end)

--Gloabl strings
--INSTANCE_RESET_FAILED = "Cannot reset %s.  There are players still inside the instance.";
--INSTANCE_RESET_FAILED_OFFLINE = "Cannot reset %s.  There are players offline in your party.";
--INSTANCE_RESET_FAILED_ZONING = "Cannot reset %s.  There are players in your party attempting to zone into an instance.";
--INSTANCE_RESET_SUCCESS = "%s has been reset.";

--Convert seconds to a readable format.
function NIT:getTimeString(seconds, countOnly, type)
	local timecalc = 0;
	if (countOnly) then
		timecalc = seconds;
	else
		timecalc = seconds - time();
	end
	local d = math.floor((timecalc % (86400*365)) / 86400);
	local h = math.floor((timecalc % 86400) / 3600);
	local m = math.floor((timecalc % 3600) / 60);
	local s = math.floor((timecalc % 60));
	local space = "";
	if (LOCALE_koKR or LOCALE_zhCN or LOCALE_zhTW) then
		space = " ";
	end
	if (type == "short") then
		if (d == 1 and h == 0) then
			return d .. L["dayShort"];
		elseif (d == 1) then
			return d .. L["dayShort"] .. space .. h .. L["hourShort"];
		end
		if (d > 1 and h == 0) then
			return d .. L["dayShort"];
		elseif (d > 1) then
			return d .. L["dayShort"] .. space .. h .. L["hourShort"];
		end
		if (h == 1 and m == 0) then
			return h .. L["hourShort"];
		elseif (h == 1) then
			return h .. L["hourShort"] .. space .. m .. L["minuteShort"];
		end
		if (h > 1 and m == 0) then
			return h .. L["hourShort"];
		elseif (h > 1) then
			return h .. L["hourShort"] .. space .. m .. L["minuteShort"];
		end
		if (m == 1 and s == 0) then
			return m .. L["minuteShort"];
		elseif (m == 1) then
			return m .. L["minuteShort"] .. space .. s .. L["secondShort"];
		end
		if (m > 1 and s == 0) then
			return m .. L["minuteShort"];
		elseif (m > 1) then
			return m .. L["minuteShort"] .. space .. s .. L["secondShort"];
		end
		--If no matches it must be seconds only.
		return s .. L["secondShort"];
	elseif (type == "medium") then
		if (d == 1 and h == 0) then
			return d .. " " .. L["dayMedium"];
		elseif (d == 1) then
			return d .. " " .. L["dayMedium"] .. " " .. h .. " " .. L["hoursMedium"];
		end
		if (d > 1 and h == 0) then
			return d .. " " .. L["daysMedium"];
		elseif (d > 1) then
			return d .. " " .. L["daysMedium"] .. " " .. h .. " " .. L["hoursMedium"];
		end
		if (h == 1 and m == 0) then
			return h .. " " .. L["hourMedium"];
		elseif (h == 1) then
			return h .. " " .. L["hourMedium"] .. " " .. m .. " " .. L["minutesMedium"];
		end
		if (h > 1 and m == 0) then
			return h .. " " .. L["hoursMedium"];
		elseif (h > 1) then
			return h .. " " .. L["hoursMedium"] .. " " .. m .. " " .. L["minutesMedium"];
		end
		if (m == 1 and s == 0) then
			return m .. " " .. L["minuteMedium"];
		elseif (m == 1) then
			return m .. " " .. L["minuteMedium"] .. " " .. s .. " " .. L["secondsMedium"];
		end
		if (m > 1 and s == 0) then
			return m .. " " .. L["minutesMedium"];
		elseif (m > 1) then
			return m .. " " .. L["minutesMedium"] .. " " .. s .. " " .. L["secondsMedium"];
		end
		--If no matches it must be seconds only.
		return s .. " " .. L["secondsMedium"];
	else
		if (d == 1 and h == 0) then
			return d .. " " .. L["day"];
		elseif (d == 1) then
			return d .. " " .. L["day"] .. " " .. h .. " " .. L["hours"];
		end
		if (d > 1 and h == 0) then
			return d .. " " .. L["days"];
		elseif (d > 1) then
			return d .. " " .. L["days"] .. " " .. h .. " " .. L["hours"];
		end
		if (h == 1 and m == 0) then
			return h .. " " .. L["hour"];
		elseif (h == 1) then
			return h .. " " .. L["hour"] .. " " .. m .. " " .. L["minutes"];
		end
		if (h > 1 and m == 0) then
			return h .. " " .. L["hours"];
		elseif (h > 1) then
			return h .. " " .. L["hours"] .. " " .. m .. " " .. L["minutes"];
		end
		if (m == 1 and s == 0) then
			return m .. " " .. L["minute"];
		elseif (m == 1) then
			return m .. " " .. L["minute"] .. " " .. s .. " " .. L["seconds"];
		end
		if (m > 1 and s == 0) then
			return m .. " " .. L["minutes"];
		elseif (m > 1) then
			return m .. " " .. L["minutes"] .. " " .. s .. " " .. L["seconds"];
		end
		--If no matches it must be seconds only.
		return s .. " " .. L["seconds"];
	end
end

--Returns am/pm and lt/st format.
function NIT:getTimeFormat(timeStamp, fullDate, abbreviate)
	if (NIT.db.global.timeStampZone == "server") then
		--This is ugly and shouldn't work, and probably doesn't work on some time difference.
		--Need a better solution but all I can get from the wow client in server time is hour:mins, not date or full timestamp.
		local data = date("*t", GetServerTime());
		local localHour, localMin = data.hour, data.min;
		local serverHour, serverMin = GetGameTime();
		local localSecs = (localMin*60) + ((localHour*60)*60);
		local serverSecs = (serverMin*60) + ((serverHour*60)*60);
		local diff = localSecs - serverSecs;
		--local diff = difftime(localSecs - serverSecs);
		local serverTime = 0;
		--if (localHour < serverHour) then
		--	timeStamp = timeStamp - (diff + 86400);
		--else
			timeStamp = timeStamp - diff;
		--end
	end
	if (NIT.db.global.timeStampFormat == 12) then
		--Strip leading zero and convert to lowercase am/pm.
		if (fullDate) then
			if (abbreviate) then
				local string = date("%a %b %d", timeStamp);
				if (date("%x", timeStamp) == date("%x", GetServerTime())) then
					string = "Today";
				elseif (date("%x", timeStamp) == date("%x", GetServerTime() - 86400)) then
					string = "Yesterday";
				end
				return string .. " " .. gsub(string.lower(date("%I:%M%p", timeStamp)), "^0", "");
			else
				return date("%a %b %d", timeStamp) .. " " .. gsub(string.lower(date("%I:%M%p", timeStamp)), "^0", "");
			end
		else
			return gsub(string.lower(date("%I:%M%p", timeStamp)), "^0", "");
		end
	else
		if (fullDate) then
			local dateFormat = NIT:getRegionTimeFormat();
			return date(dateFormat .. " %H:%M:%S", timeStamp);
		else
		 return date("%H:%M:%S", timeStamp);
		end
	end
end

--Date 24h string format based on region, won't be 100% accurate but better than %x returning US format for every region like it does now.
function NIT:getRegionTimeFormat()
	local dateFormat = "%x";
	local region = GetCurrentRegion();
	if (NIT.realm == "Arugal" or NIT.realm == "Felstriker" or NIT.realm == "Remulos" or NIT.realm == "Yojamba") then
		--OCE
		dateFormat = "%d/%m/%y";
	elseif (NIT.realm == "Sulthraze" or NIT.realm == "Loatheb") then
		--Brazil/Latin America.
		dateFormat = "%d/%m/%y";
	elseif (region == 1) then
		--US.
		dateFormat = "%m/%d/%y";
	elseif (region == 2 or region == 4 or region == 5) then
		--Korea, Taiwan, Chinda all same format.
		dateFormat = "%y/%m/%d";
	elseif (region == 3) then
		--EU.
		dateFormat = "%d/%m/%y";
	end
	return dateFormat;
end

--Iterate table keys in alphabetical order.
function NIT:pairsByKeys(t, f)
	local a = {};
	for n in pairs(t) do
		table.insert(a, n);
	end
	table.sort(a, f);
	local i = 0;
	local iter = function()
		i = i + 1;
		if (a[i] == nil) then
			return nil;
		else
			return a[i], t[a[i]];
		end
	end
	return iter;
end

function NIT:commaValue(amount)
	if (not amount or not tonumber(amount)) then
		return;
	end
	local formatted = amount;
	while true do
		local k;
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2');
		if (k == 0) then
			break;
		end;
	end;
	return formatted;
end

--The built in coin strings didn't do exactly what I needed.
function NIT:convertMoney(money, short, separator, colorized, amountColor)
	if (not separator) then
		separator = "";
	end
	if (not amountColor) then
		amountColor = "|cFFFFFFFF";
	end
	local gold = math.floor(money / 100 / 100);
	local silver = math.floor((money / 100) % 100);
	local copper = math.floor(money % 100);
	local goldText = amountColor .. "%d|cffFFDF00" .. L["gold"] .. "|r"; 
	local silverText = amountColor .. "%d|cFFF0F0F0" .. L["silver"] .. "|r"; 
	local copperText = amountColor .. "%d|cFFD69151" .. L["copper"] .. "|r";
	if (short) then
		goldText = amountColor .. "%d|cffFFDF00g|r"; 
		silverText = amountColor .. "%d|cFFF0F0F0s|r"; 
		copperText = amountColor .. "%d|cFFD69151c|r";
	end
	if (not colorized) then
		goldText = NIT:stripColors(goldText);
		silverText = NIT:stripColors(silverText);
		copperText = NIT:stripColors(copperText);
	end
	--local text = goldText .. separator .. silverText .. separator .. copperText;
	--local foundGold, foundSilver;
	local text = "";
	local currencies = {};
	if (gold > 0) then
		local moneyString = string.format(goldText, gold);
		table.insert(currencies, moneyString);
	end
	if (silver > 0) then
		local moneyString = string.format(silverText, silver);
		table.insert(currencies, moneyString);
	end
	if (copper > 0) then
		local moneyString = string.format(copperText, copper);
		table.insert(currencies, moneyString);
	end
	local count = 0;
	for k, v in ipairs(currencies) do
		count = count + 1;
		if (count == 1) then
			text = text .. v;
		else
			text = text .. separator .. v;
		end
	end
	if (count < 1) then
		return string.format(copperText, 0);
	else
		return text;
	end
end

--Add options to choose how money is displayed later.
function NIT:getCoinString(money, color)
	if (NIT.db.global.moneyString == "text") then
		return NIT:convertMoney(money, true, "", true, color);
	else
		return GetCoinTextureString(money);
	end
end

--Strip escape strings from chat msgs.
function NIT:stripColors(str)
	local escapes = {
    	["|c%x%x%x%x%x%x%x%x"] = "", --Color start.
    	["|r"] = "", --Color end.
    	--["|H.-|h(.-)|h"] = "%1", --Links.
    	["|T.-|t"] = "", --Textures.
    	["{.-}"] = "", --Raid target icons.
	};
	if (str) then
    	for k, v in pairs(escapes) do
        	str = gsub(str, k, v);
    	end
    end
    return str;
end

function NIT:RGBToHex(r, g, b)
	r = tonumber(r);
	g = tonumber(g);
	b = tonumber(b);
	--Check if whole numbers.
	if (r == math.floor(r) and g == math.floor(g) and b == math.floor(b)
			and (r> 1 or g > 1 or b > 1)) then
		r = r <= 255 and r >= 0 and r or 0;
		g = g <= 255 and g >= 0 and g or 0;
		b = b <= 255 and b >= 0 and b or 0;
		return string.format("%02x%02x%02x", r, g, b);
	else
		return string.format("%02x%02x%02x", r*255, g*255, b*255);
	end
end

function NIT:round(num, numDecimalPlaces)
	if (not num or not tonumber(num)) then
		return;
	end
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

--PHP explode type function.
function NIT:explode(div, str, count)
	if (div == '') then
		return false;
	end
	local pos,arr = 0,{};
	local index = 0;
	for st, sp in function() return string.find(str, div, pos, true) end do
		index = index + 1;
 		table.insert(arr, string.sub(str, pos, st-1));
		pos = sp + 1;
		if (count and index == count) then
			table.insert(arr, string.sub(str, pos));
			return arr;
		end
	end
	table.insert(arr, string.sub(str, pos));
	return arr;
end

function NIT:openConfig()
	--Opening the frame needs to be run twice to avoid a bug.
	InterfaceOptionsFrame_OpenToCategory("NovaInstanceTracker");
	--Hack to fix the issue of interface options not opening to menus below the current scroll range.
	--This addon name starts with N and will always be closer to the middle so just scroll to the middle when opening.
	local min, max = InterfaceOptionsFrameAddOnsListScrollBar:GetMinMaxValues();
	if (min < max) then
		InterfaceOptionsFrameAddOnsListScrollBar:SetValue(math.floor(max/2));
	end
	InterfaceOptionsFrame_OpenToCategory("NovaInstanceTracker");
end

function NIT:isInArena()
	--Check if the func exists for classic.
	if (IsActiveBattlefieldArena and IsActiveBattlefieldArena()) then
		return true;
	end
end

SLASH_NOVALUACMD1 = '/lua';
function SlashCmdList.NOVALUACMD(msg, editBox, msg2)
	if (msg and (string.lower(msg) == "on" or string.lower(msg) == "enable")) then
		if (GetCVar("ScriptErrors") == "1") then
			print("Lua errors are already enabled.")
		else
			SetCVar("ScriptErrors","1")
			print("Lua errors enabled.")
		end
	elseif (msg and (string.lower(msg) == "off" or string.lower(msg) == "disable")) then
		if (GetCVar("ScriptErrors") == "0") then
			print("Lua errors are already off.")
		else
			SetCVar("ScriptErrors","0")
			print("Lua errors disabled.")
		end
	else
		print("Valid args are \"on\" and \"off\".");
	end
end

SLASH_NOVALUAONCMD1 = '/luaon';
function SlashCmdList.NOVALUAONCMD(msg, editBox, msg2)
	if (GetCVar("ScriptErrors") == "1") then
		print("Lua errors are already enabled.")
	else
		SetCVar("ScriptErrors","1")
		print("Lua errors enabled.")
	end
end

SLASH_NOVALUAOFFCMD1 = '/luaoff';
function SlashCmdList.NOVALUAOFFCMD(msg, editBox)
	if (GetCVar("ScriptErrors") == "0") then
		print("Lua errors are already off.")
	else
		SetCVar("ScriptErrors","0")
		print("Lua errors disabled.")
	end
end

function NIT:debug(...)
	if (NIT.isDebug) then
		if (type(...) == "table") then
			UIParentLoadAddOn('Blizzard_DebugTools');
			--DevTools_Dump(...);
    		DisplayTableInspectorWindow(...);
    	else
			print("NITDebug:", ...);
		end
	end
end

SLASH_NITCMD1, SLASH_NITCMD2 = '/nit', '/novainstancetracker';
function SlashCmdList.NITCMD(msg, editBox)
	local cmd, channel, extra;
	if (msg) then
		msg = string.lower(msg);
		cmd, channel, extra = strsplit(" ", msg, 3);
	end
	if (msg == "add" or msg == "new") then
		local isInstance, instanceType = IsInInstance();
		if (isInstance) then
			--Simulate entering instance.
			NIT:enteredInstance();
		else
			NIT:print("You are not inside an instance to add.");
		end
	elseif (msg == "options" or msg == "option" or msg == "config" or msg == "menu") then
		NIT:openConfig();
	elseif (msg == "money" or msg == "gold" or msg == "trade" or msg == "trades" or msg == "tradelog") then
		NIT:openTradeLogFrame();
	elseif (cmd == "stats" or cmd == "stat") then
		local allStats;
		if (channel) then
			channel = string.lower(channel);
		end
		if (channel == "all" or extra == "all") then
			allStats = true;
		end
		if (not channel or channel == "all") then
			NIT:showInstanceStats(nil, "send", allStats);
		elseif (channel == "self" or channel == "me" or channel == "myself"  or channel == "print") then
			NIT:showInstanceStats(nil, "self", allStats);
		elseif (channel == "say" or channel == "yell" or channel == "party" or channel == "guild"
			or channel == "officer" or channel == "raid" or channel == "group") then
			NIT:showInstanceStats(nil, channel, allStats);
		else
			NIT:print("Please specify a valid channel like /nit stats party or /nit stats raid or /nit stats guild.");
		end
	elseif (msg ~= nil and msg ~= "") then
		if (msg == "raid" and not IsInRaid()) then
			NIT:print("You are not in a raid.");
			return;
	  	elseif (msg == "party" and not IsInGroup()) then
	  		NIT:print("You are not in a party.");
	  		return;
		end
		local lockoutString, lockoutStringShort, lockoutStringColorized = NIT:getInstanceLockoutInfoString();
		NIT:print(lockoutString, msg);
	else
		NIT:openInstanceLogFrame();
	end
end

local lockoutNum, lockoutNum24 = 0, 0;
function NIT:ticker()
	local hourCount, hourCount24, hourTimestamp, hourTimestamp24 = NIT:getInstanceLockoutInfo();
	if (hourCount24 < lockoutNum24 and lockoutNum24 == NIT.dailyLimit and GetServerTime() - NIT.lastMerge > 3) then
		local texture = "|TInterface\\AddOns\\NovaInstanceTracker\\Media\\redX2:12:12:0:0|t";
		local hourCount, hourCount24, hourTimestamp, hourTimestamp24 = NIT:getInstanceLockoutInfo();
		local countMsg = " (" .. NIT.prefixColor .. hourCount24 .. NIT.chatColor .. " " .. L["thisHour24"] .. ")";
		NIT:print(L["newInstanceNow"] .. countMsg .. ".");
	elseif (hourCount < lockoutNum and lockoutNum == 5 and GetServerTime() - NIT.lastMerge > 3) then
		local texture = "|TInterface\\AddOns\\NovaInstanceTracker\\Media\\redX2:12:12:0:0|t";
		local hourCount, hourCount24, hourTimestamp, hourTimestamp24 = NIT:getInstanceLockoutInfo();
		local countMsg = " (" .. NIT.prefixColor .. hourCount .. NIT.chatColor .. " " .. L["thisHour"] .. ")";
		NIT:print(L["newInstanceNow"] .. countMsg .. ".");
	end
	lockoutNum24 = hourCount24;
	lockoutNum = hourCount;
	C_Timer.After(1, function()
		NIT:ticker();
	end)
end

--Prefixes are clickable in chat to open buffs frame.
function NIT.addClickLinks(self, event, msg, author, ...)
	local types = {};
	if (event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER") then
		--Don't color the prefix for group msgs;
		types = {
			["%[NIT%]"] = "|HNITCustomLink:instancelog|h[NIT]|h|r",
		};
	else
		types = {
			["%[NIT%]"] = NIT.prefixColor .. "|HNITCustomLink:instancelog|h[NIT]|h|r",
		};
	end
	for k, v in pairs(types) do
		local match = string.match(msg, k);
		if (match) then
			msg = string.gsub(msg, k .. " (.+)", v .. " |HNITCustomLink:instancelog|h%1|h");
			return false, msg, author, ...;
		end
	end
	return false, msg, author, ...;
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", NIT.addClickLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", NIT.addClickLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", NIT.addClickLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", NIT.addClickLinks);
ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_WARNING", NIT.addClickLinks);

--Hook the chat link click func.
hooksecurefunc("ChatFrame_OnHyperlinkShow", function(...)
	local chatFrame, link, text, button = ...;
    if (link == "NITCustomLink:instancelog") then
		NIT:openInstanceLogFrame();
	end
	if (link == "NITCustomLink:tradelog") then
		NIT:openTradeLogFrame();
	end
	if (link == "NITCustomLink:deletelast") then
		NIT:openDeleteConfirmFrame(1);
	end
	if (link == "NITCustomLink:addinstance") then
		NIT:enteredInstance();
	end
end)

--Insert our custom link type into blizzards SetHyperlink() func.
local OriginalSetHyperlink = ItemRefTooltip.SetHyperlink
function ItemRefTooltip:SetHyperlink(link, ...)
	if (link and link:sub(0, 13) == "NITCustomLink") then
		return;
	end
	return OriginalSetHyperlink(self, link, ...);
end

local NITLDB, doUpdateMinimapButton;
function NIT:createBroker()
	local data = {
		type = "launcher",
		label = "NIT",
		text = "NovaInstanceTracker",
		icon = "Interface\\AddOns\\NovaInstanceTracker\\Media\\portal",
		OnClick = function(self, button)
			if (button == "LeftButton" and IsShiftKeyDown()) then
				NIT:openTradeLogFrame();
			elseif (button == "LeftButton") then
				NIT:openInstanceLogFrame();
			elseif (button == "RightButton" and IsShiftKeyDown()) then
				if (InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown()) then
					InterfaceOptionsFrame:Hide();
				else
					NIT:openConfig();
				end
			elseif (button == "RightButton") then
				NIT:openAltsFrame();
			end
		end,
		OnLeave = function(self, button)
			doUpdateMinimapButton = nil;
		end,
		OnTooltipShow = function(tooltip)
			doUpdateMinimapButton = true;
			NIT:updateMinimapButton(tooltip);
		end,
		OnEnter = function(self, button)
			GameTooltip:SetOwner(self, "ANCHOR_NONE")
			GameTooltip:SetPoint("TOPLEFT", self, "BOTTOMLEFT")
			doUpdateMinimapButton = true;
			NIT:updateMinimapButton(GameTooltip, true);
			GameTooltip:Show()
		end,
	};
	NITLDB = LDB:NewDataObject("NIT", data);
	NIT.LDBIcon:Register("NovaInstanceTracker", NITLDB, NIT.db.global.minimapIcon);
end

function NIT:updateMinimapButton(tooltip, usingPanel)
	local _, relativeTo = tooltip:GetPoint();
	if (doUpdateMinimapButton and (usingPanel or relativeTo and relativeTo:GetName() == "LibDBIcon10_NovaInstanceTracker")) then
		tooltip:ClearLines()
		tooltip:AddLine("NovaInstanceTracker");
		if (NIT.inInstance) then
			if (not tooltip.NITSeparator) then
			    tooltip.NITSeparator = tooltip:CreateTexture(nil, "BORDER");
			    tooltip.NITSeparator:SetColorTexture(0.6, 0.6, 0.6, 0.85);
			    tooltip.NITSeparator:SetHeight(0.9);
			    tooltip.NITSeparator:SetPoint("LEFT", 10, 0);
			    tooltip.NITSeparator:SetPoint("RIGHT", -10, 0);
			    tooltip.NITSeparator2 = tooltip:CreateTexture(nil, "BORDER");
			    tooltip.NITSeparator2:SetColorTexture(0.6, 0.6, 0.6, 0.85);
			    tooltip.NITSeparator2:SetHeight(0.9);
			    tooltip.NITSeparator2:SetPoint("LEFT", 10, 0);
			    tooltip.NITSeparator2:SetPoint("RIGHT", -10, 0);
			end
			tooltip:AddLine(" ");
			tooltip.NITSeparator:SetPoint("TOP", _G[tooltip:GetName() .. "TextLeft" .. tooltip:NumLines()], "CENTER");
			tooltip.NITSeparator:Show();
			local data = NIT.data.instances[1];
			if (data) then
				--tooltip:AddLine("|cFF9CD6DECurrently Inside:");
				local timeInside = NIT:getTimeString(GetServerTime() - data.enteredTime, true);
				if (data.isPvp) then
					tooltip:AddLine("|cFFFFA500" .. data.instanceName);
				else
					tooltip:AddLine("|cFF00C800" .. data.instanceName);
				end
				tooltip:AddLine("|cFF9CD6DE" .. timeInside);		
				if (not data.isPvp) then
					local mobCount = 0;
					if (data.mobCount and data.mobCount > 0) then
						mobCount = data.mobCount;
					elseif (data.mobCountFromKill and data.mobCountFromKill > 0) then
						mobCount = data.mobCountFromKill;
					end
					tooltip:AddLine("|cFF9CD6DE" .. L["mobCount"] .. ":|r |cFFFFFFFF" .. (mobCount or "Unknown"));
					tooltip:AddLine("|cFF9CD6DE" .. L["experience"] .. ":|r |cFFFFFFFF" .. (NIT:commaValue(data.xpFromChat) or "Unknown"));
					if (data.rawMoneyCount and data.rawMoneyCount > 0) then
						tooltip:AddLine("|cFF9CD6DE" .. L["rawGoldMobs"] .. ":|r |cFFFFFFFF" .. GetCoinTextureString(data.rawMoneyCount));
					elseif (data.enteredMoney and data.leftMoney and data.enteredMoney > 0 and data.leftMoney > 0
							and data.leftMoney > data.enteredMoney) then
						--Backup for people with addons installed using an altered money string.
						local moneyCount = data.leftMoney - data.enteredMoney;
						tooltip:AddLine("\n|cFF9CD6DE" .. L["rawGoldMobs"] .. ":|r |cFFFFFFFF" .. GetCoinTextureString(moneyCount));
					else
						tooltip:AddLine("|cFF9CD6DE" .. L["rawGoldMobs"] .. ":|r |cFFFFFFFF" .. GetCoinTextureString(0));
					end
					if (data.groupAverage and data.groupAverage > 0) then
						tooltip:AddLine("|cFF9CD6DE" .. L["averageGroupLevel"] .. ":|r |cFFFFFFFF" .. (NIT:round(data.groupAverage, 2) or "Unknown"));
					end
				end
				if (data.honor) then
					tooltip:AddLine("|cFF9CD6DE" .. L["Honor"] .. ":|r |cFFFFFFFF" .. data.honor);
				end
				if (data.rep and next(data.rep)) then
					tooltip:AddLine("|cFFFFFF00" .. L["repGains"] .. ":|r");
					for k, v in NIT:pairsByKeys(data.rep) do
						if (v > 0) then
							v = "+" .. NIT:commaValue(v);
						end
						tooltip:AddLine(" |cFF9CD6DE" .. k .. "|r |cFFFFFFFF" .. v);
					end
				end
			end
			tooltip:AddLine(" ");
			tooltip.NITSeparator2:SetPoint("TOP", _G[tooltip:GetName() .. "TextLeft" .. tooltip:NumLines()], "CENTER");
			tooltip.NITSeparator2:Show();
		else
			if (tooltip.NITSeparator) then
				tooltip.NITSeparator:Hide();
				tooltip.NITSeparator2:Hide();
			end
		end
		if (NIT.perCharOnly) then
			tooltip:AddLine("|cFF9CD6DE(" .. L["thisChar"] .. ")|r");
		end
		tooltip:AddLine(NIT:getMinimapButtonLockoutString() .. "\n");
		local expires = NIT:getMinimapButtonNextExpires();
		if (expires) then
			tooltip:AddLine(expires .. "\n");
		end
		tooltip:AddLine("|cFF9CD6DELeft-Click|r " .. L["openInstanceFrame"]);
		tooltip:AddLine("|cFF9CD6DERight-Click|r " .. L["openYourChars"]);
		tooltip:AddLine("|cFF9CD6DEShift Left-Click|r " .. L["openTradeLog"]);
		tooltip:AddLine("|cFF9CD6DEShift Right-Click|r " .. L["config"]);
		C_Timer.After(0.1, function()
			NIT:updateMinimapButton(tooltip, usingPanel);
		end)
	else
		if (tooltip.NITSeparator) then
			tooltip.NITSeparator:Hide();
			tooltip.NITSeparator2:Hide();
		end
	end
end

function NIT:getMinimapButtonLockoutString()
	local hourCount, hourCount24, hourTimestamp, hourTimestamp24 = NIT:getInstanceLockoutInfo();
	local countStringColorized = NIT.prefixColor .. hourCount .. NIT.chatColor.. " " .. L["instancesPastHour"] .. "\n"
			.. NIT.prefixColor .. hourCount24 .. NIT.chatColor .. " " .. L["instancesPastHour24"] .. "\n";
	local lockoutInfo = L["now"];
	local timeLeft24 = 86400 - (GetServerTime() - hourTimestamp24);
	local timeLeft = 3600 - (GetServerTime() - hourTimestamp);
	local timeLeftMax = math.max(timeLeft24, timeLeft);
	if (GetServerTime() - hourTimestamp24 < 86400 and hourCount24 >= NIT.dailyLimit and timeLeft24 == timeLeftMax) then
		lockoutInfo = L["in"] .. " " .. NIT:getTimeString(86400 - (GetServerTime() - hourTimestamp24), true) .. " (" .. L["active24"] .. ")";
	elseif (GetServerTime() - hourTimestamp < 3600 and hourCount >= NIT.hourlyLimit) then
		lockoutInfo = L["in"] .. " " .. NIT:getTimeString(3600 - (GetServerTime() - hourTimestamp), true);
	end
	local msg = NIT.prefixColor .. hourCount .. NIT.chatColor.. " " .. L["instancesPastHour"] .. "\n"
			.. NIT.prefixColor .. hourCount24 .. NIT.chatColor .. " " .. L["instancesPastHour24"] .. "\n"
			.. L["nextInstanceAvailable"] .. " " .. lockoutInfo .. ".";
	return msg;
end

function NIT:getMinimapButtonNextExpires(char)
	if (not char) then
		char = UnitName("player");
	end
	--local msg = "Current Hour Lockouts:";
	local msg = "";
	local count = 0;
	local found;
	for k, v in ipairs(self.data.instances) do
		local noLockout;
		if (v.instanceID and NIT.zones[v.instanceID] and NIT.zones[v.instanceID].noLockout) then
			noLockout = true;
		end
		if (not v.isPvp and not noLockout and (not NIT.perCharOnly or char == v.playerName)) then
			if (v.leftTime and v.leftTime > (GetServerTime() - 3600)) then
				local time = 3600 - (GetServerTime() - v.leftTime);
				--msg = msg .. "\n|cFF9CD6DE" .. v.instanceName .. " expires in " .. NIT:getTimeString(time, true);
				--msg = "\n|cFF9CD6DE" .. v.instanceName .. " expires in " .. NIT:getTimeString(time, true, NIT.db.global.timeStringType) .. msg;
				local timeAgo = GetServerTime() - v.leftTime;
				local lockoutTime = NIT:getTimeString(3600 - timeAgo, true, NIT.db.global.timeStringType)
				msg = msg .. "\n|cFF9CD6DE" .. v.instanceName .. " (" .. lockoutTime .. " " .. L["leftOnLockout"] .. ")|r";
				found = true;
			elseif (v.enteredTime and v.enteredTime > (GetServerTime() - 3600)) then
				local time = 3600 - (GetServerTime() - v.enteredTime);
				--msg = msg .. "\n|cFF9CD6DE" .. v.instanceName .. " expires in " .. NIT:getTimeString(time, true);
				--msg = "\n|cFF9CD6DE" .. v.instanceName .. " expires in " .. NIT:getTimeString(time, true, NIT.db.global.timeStringType) .. msg;
				local timeAgo = GetServerTime() - v.enteredTime;
				local lockoutTime = NIT:getTimeString(3600 - timeAgo, true, NIT.db.global.timeStringType)
				msg = msg .. "\n|cFF9CD6DE" .. v.instanceName .. " (" .. lockoutTime .. " " .. L["leftOnLockout"] .. ")|r";
				found = true;
			else
				break;
			end
		end
	end
	if (found) then
		return "Current Hour Lockouts:" .. msg;
	else
		return;
	end
end

function NIT:addBackdrop(string)
	if (BackdropTemplateMixin) then
		if (string) then
			--Inherit backdrop first so our frames points etc don't get overwritten.
			return "BackdropTemplate," .. string;
		else
			return "BackdropTemplate";
		end
	else
		return string;
	end
end

local NITInstanceFrame = CreateFrame("ScrollFrame", "NITInstanceFrame", UIParent, NIT:addBackdrop("InputScrollFrameTemplate"));
local instanceFrameWidth = 620;
NITInstanceFrame:Hide();
NITInstanceFrame:SetToplevel(true);
NITInstanceFrame:SetMovable(true);
NITInstanceFrame:EnableMouse(true);
tinsert(UISpecialFrames, "NITInstanceFrame");
NITInstanceFrame:SetPoint("CENTER", UIParent, 0, 100);
NITInstanceFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8",insets = {top = 0, left = 0, bottom = 0, right = 0}});
NITInstanceFrame:SetBackdropColor(0,0,0,.5);
NITInstanceFrame.CharCount:Hide();
NITInstanceFrame:SetFrameStrata("HIGH");
NITInstanceFrame.EditBox:SetAutoFocus(false);
NITInstanceFrame.EditBox:SetScript("OnKeyDown", function(self, arg)
	NITInstanceFrame.EditBox:ClearFocus();
end)
NITInstanceFrame.EditBox:SetScript("OnShow", function(self, arg)
	NITInstanceFrame:SetVerticalScroll(0);
	NITInstanceFrame:SetVerticalScroll(0);
end)
local instanceFrameUpdateTime = 0;
NITInstanceFrame:HookScript("OnUpdate", function(self, arg)
	NITInstanceFrame.EditBox:ClearFocus();
	--Only update once per second.
	if (GetServerTime() - instanceFrameUpdateTime > 0) then
		instanceFrameUpdateTime = GetServerTime();
		NIT:recalcInstanceLineFrames();
	end
end)
--NITInstanceFrame.fsCalc = NITInstanceFrame:CreateFontString("NITInstanceFrameFSCalc", "LOW");
--NITInstanceFrame.fsCalc:SetFont(NIT.regionFont, 14);
NITInstanceFrame.fs = NITInstanceFrame.EditBox:CreateFontString("NITInstanceFrameFS", "HIGH");
NITInstanceFrame.fs:SetPoint("TOP", 0, -0);
NITInstanceFrame.fs:SetFont(NIT.regionFont, 14);
NITInstanceFrame.fs2 = NITInstanceFrame:CreateFontString("NITInstanceFrameFS", "HIGH");
NITInstanceFrame.fs2:SetPoint("TOPLEFT", 0, -14);
NITInstanceFrame.fs2:SetFont(NIT.regionFont, 14);
NITInstanceFrame.fs3 = NITInstanceFrame:CreateFontString("NITbuffListFrameFS", "HIGH");
NITInstanceFrame.fs3:SetPoint("BOTTOM", 0, -20);
NITInstanceFrame.fs3:SetFont(NIT.regionFont, 14);

local NITInstanceDragFrame = CreateFrame("Frame", "NITlayerDragFrame", NITInstanceFrame);
NITInstanceDragFrame:SetToplevel(true);
NITInstanceDragFrame:EnableMouse(true);
NITInstanceDragFrame:SetWidth(305);
NITInstanceDragFrame:SetHeight(38);
NITInstanceDragFrame:SetPoint("TOP", 0, 4);
NITInstanceDragFrame:SetFrameLevel(131);
NITInstanceDragFrame.tooltip = CreateFrame("Frame", "NITInstanceDragTooltip", NITInstanceDragFrame, "TooltipBorderedFrameTemplate");
NITInstanceDragFrame.tooltip:SetPoint("CENTER", NITInstanceDragFrame, "TOP", 0, 12);
NITInstanceDragFrame.tooltip:SetFrameStrata("TOOLTIP");
NITInstanceDragFrame.tooltip:SetFrameLevel(9);
NITInstanceDragFrame.tooltip:SetAlpha(.8);
NITInstanceDragFrame.tooltip.fs = NITInstanceDragFrame.tooltip:CreateFontString("NITInstanceDragTooltipFS", "HIGH");
NITInstanceDragFrame.tooltip.fs:SetPoint("CENTER", 0, 0.5);
NITInstanceDragFrame.tooltip.fs:SetFont(NIT.regionFont, 12);
NITInstanceDragFrame.tooltip.fs:SetText("Hold to drag");
NITInstanceDragFrame.tooltip:SetWidth(NITInstanceDragFrame.tooltip.fs:GetStringWidth() + 16);
NITInstanceDragFrame.tooltip:SetHeight(NITInstanceDragFrame.tooltip.fs:GetStringHeight() + 10);
NITInstanceDragFrame:SetScript("OnEnter", function(self)
	NITInstanceDragFrame.tooltip:Show();
end)
NITInstanceDragFrame:SetScript("OnLeave", function(self)
	NITInstanceDragFrame.tooltip:Hide();
end)
NITInstanceDragFrame.tooltip:Hide();
NITInstanceDragFrame:SetScript("OnMouseDown", function(self, button)
	if (button == "LeftButton" and not self:GetParent().isMoving) then
		self:GetParent().EditBox:ClearFocus();
		self:GetParent():StartMoving();
		self:GetParent().isMoving = true;
		--self:GetParent():SetUserPlaced(false);
	end
end)
NITInstanceDragFrame:SetScript("OnMouseUp", function(self, button)
	if (button == "LeftButton" and self:GetParent().isMoving) then
		self:GetParent():StopMovingOrSizing();
		self:GetParent().isMoving = false;
	end
end)
NITInstanceDragFrame:SetScript("OnHide", function(self)
	if (self:GetParent().isMoving) then
		self:GetParent():StopMovingOrSizing();
		self:GetParent().isMoving = false;
	end
end)

--Top right X close button.
local NITInstanceFrameClose = CreateFrame("Button", "NITInstanceFrameClose", NITInstanceFrame, "UIPanelCloseButton");
--NITInstanceFrameClose:SetPoint("TOPRIGHT", -5, 8.6);
--NITInstanceFrameClose:SetWidth(31);
--NITInstanceFrameClose:SetHeight(31);
NITInstanceFrameClose:SetPoint("TOPRIGHT", -12, 3.75);
NITInstanceFrameClose:SetWidth(20);
NITInstanceFrameClose:SetHeight(20);
NITInstanceFrameClose:SetScript("OnClick", function(self, arg)
	NITInstanceFrame:Hide();
end)
--Adjust the X texture so it fits the entire frame and remove the empty clickable space around the close button.
--Big thanks to Meorawr for this.
NITInstanceFrameClose:GetNormalTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITInstanceFrameClose:GetHighlightTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITInstanceFrameClose:GetPushedTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITInstanceFrameClose:GetDisabledTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);

--Config button.
local NITInstanceFrameConfButton = CreateFrame("Button", "NITInstanceFrameConfButton", NITInstanceFrameClose, "UIPanelButtonTemplate");
--NITInstanceFrameConfButton:SetPoint("CENTER", -60, 1);
NITInstanceFrameConfButton:SetPoint("CENTER", -61, -22);
NITInstanceFrameConfButton:SetWidth(95);
NITInstanceFrameConfButton:SetHeight(17);
NITInstanceFrameConfButton:SetText("Options");
NITInstanceFrameConfButton:SetNormalFontObject("GameFontNormalSmall");
NITInstanceFrameConfButton:SetScript("OnClick", function(self, arg)
	NIT:openConfig();
end)
NITInstanceFrameConfButton:SetScript("OnMouseDown", function(self, button)
	if (button == "LeftButton" and not self:GetParent():GetParent().isMoving) then
		self:GetParent():GetParent().EditBox:ClearFocus();
		self:GetParent():GetParent():StartMoving();
		self:GetParent():GetParent().isMoving = true;
	end
end)
NITInstanceFrameConfButton:SetScript("OnMouseUp", function(self, button)
	if (button == "LeftButton" and self:GetParent():GetParent().isMoving) then
		self:GetParent():GetParent():StopMovingOrSizing();
		self:GetParent():GetParent().isMoving = false;
	end
end)
NITInstanceFrameConfButton:SetScript("OnHide", function(self)
	if (self:GetParent():GetParent().isMoving) then
		self:GetParent():GetParent():StopMovingOrSizing();
		self:GetParent():GetParent().isMoving = false;
	end
end)

--Trade log button.
local NITInstanceFrameTradesButton = CreateFrame("Button", "NITInstanceFrameTradesButton", NITInstanceFrameClose, "UIPanelButtonTemplate");
--NITInstanceFrameTradesButton:SetPoint("CENTER", -60, -14);
NITInstanceFrameTradesButton:SetPoint("CENTER", -61, -38);
NITInstanceFrameTradesButton:SetWidth(95);
NITInstanceFrameTradesButton:SetHeight(17);
NITInstanceFrameTradesButton:SetText("Trade Log");
NITInstanceFrameTradesButton:SetNormalFontObject("GameFontNormalSmall");
NITInstanceFrameTradesButton:SetScript("OnClick", function(self, arg)
	NIT:openTradeLogFrame();
end)
NITInstanceFrameTradesButton:SetScript("OnMouseDown", function(self, button)
	if (button == "LeftButton" and not self:GetParent():GetParent().isMoving) then
		self:GetParent():GetParent().EditBox:ClearFocus();
		self:GetParent():GetParent():StartMoving();
		self:GetParent():GetParent().isMoving = true;
	end
end)
NITInstanceFrameTradesButton:SetScript("OnMouseUp", function(self, button)
	if (button == "LeftButton" and self:GetParent():GetParent().isMoving) then
		self:GetParent():GetParent():StopMovingOrSizing();
		self:GetParent():GetParent().isMoving = false;
	end
end)
NITInstanceFrameTradesButton:SetScript("OnHide", function(self)
	if (self:GetParent():GetParent().isMoving) then
		self:GetParent():GetParent():StopMovingOrSizing();
		self:GetParent():GetParent().isMoving = false;
	end
end)

--Rested button.
local NITInstanceFrameRestedButton = CreateFrame("Button", "NITInstanceFrameRestedButton", NITInstanceFrameClose, "UIPanelButtonTemplate");
--NITInstanceFrameRestedButton:SetPoint("CENTER", -80, -30);
--NITInstanceFrameRestedButton:SetPoint("CENTER", -60, -28);
NITInstanceFrameRestedButton:SetPoint("CENTER", -70, -3);
--NITInstanceFrameRestedButton:SetWidth(134);
--NITInstanceFrameRestedButton:SetHeight(18);
NITInstanceFrameRestedButton:SetWidth(115);
--NITInstanceFrameRestedButton:SetHeight(17);
NITInstanceFrameRestedButton:SetHeight(25);
NITInstanceFrameRestedButton:SetText("Your Characters");
NITInstanceFrameRestedButton:SetNormalFontObject("GameFontNormalSmall");
NITInstanceFrameRestedButton:SetScript("OnClick", function(self, arg)
	NIT:openAltsFrame();
end)
NITInstanceFrameRestedButton:SetScript("OnMouseDown", function(self, button)
	if (button == "LeftButton" and not self:GetParent():GetParent().isMoving) then
		self:GetParent():GetParent().EditBox:ClearFocus();
		self:GetParent():GetParent():StartMoving();
		self:GetParent():GetParent().isMoving = true;
	end
end)
NITInstanceFrameRestedButton:SetScript("OnMouseUp", function(self, button)
	if (button == "LeftButton" and self:GetParent():GetParent().isMoving) then
		self:GetParent():GetParent():StopMovingOrSizing();
		self:GetParent():GetParent().isMoving = false;
	end
end)
NITInstanceFrameRestedButton:SetScript("OnHide", function(self)
	if (self:GetParent():GetParent().isMoving) then
		self:GetParent():GetParent():StopMovingOrSizing();
		self:GetParent():GetParent().isMoving = false;
	end
end)

function NIT:createInstanceFrameShowsAltsButton()
	if (NIT.instanceFrameShowsAltsButton) then
		return;
	end
	NIT.instanceFrameShowsAltsButton = CreateFrame("CheckButton", "NITInstanceFrameShowsAltsButton", NITInstanceFrame.EditBox, "ChatConfigCheckButtonTemplate");
	--NIT.instanceFrameShowsAltsButton:SetPoint("TOPLEFT", 5, -5);
	NIT.instanceFrameShowsAltsButton:SetPoint("TOPLEFT", 108, 2);
	--So strange the way to set text is to append Text to the global frame name.
	NITInstanceFrameShowsAltsButtonText:SetText("Show Alts");
	NIT.instanceFrameShowsAltsButton.tooltip = "Show all alts in the instance log? (Lockouts are per character)";
	NIT.instanceFrameShowsAltsButton:SetFrameStrata("HIGH");
	NIT.instanceFrameShowsAltsButton:SetFrameLevel(3);
	NIT.instanceFrameShowsAltsButton:SetWidth(24);
	NIT.instanceFrameShowsAltsButton:SetHeight(24);
	NIT.instanceFrameShowsAltsButton:SetChecked(NIT.db.global.showAltsLog);
	NIT.instanceFrameShowsAltsButton:SetScript("OnClick", function()
		local value = NIT.instanceFrameShowsAltsButton:GetChecked();
		NIT.db.global.showAltsLog = value;
		NIT:hideAllLineFrames();
		NIT:recalcInstanceLineFrames();
		--Refresh the config page.
		NIT.acr:NotifyChange("NovaInstanceTracker");
	end)
	--frame:SetHitRectInsets(left, right, top, bottom);
	NIT.instanceFrameShowsAltsButton:SetHitRectInsets(0, 0, -10, 7);
end

function NIT:createInstanceFramePvpButton()
	if (NIT.instanceFramePvpButton) then
		return;
	end
	NIT.instanceFramePvpButton = CreateFrame("CheckButton", "NITInstanceFramePvpButton", NITInstanceFrame.EditBox, "ChatConfigCheckButtonTemplate");
	NIT.instanceFramePvpButton:SetPoint("TOPLEFT", 3, 2);
	NITInstanceFramePvpButtonText:SetText("PvP");
	NIT.instanceFramePvpButton.tooltip = "Show battleground and arena instances?";
	NIT.instanceFramePvpButton:SetFrameStrata("HIGH");
	NIT.instanceFramePvpButton:SetFrameLevel(4);
	NIT.instanceFramePvpButton:SetWidth(24);
	NIT.instanceFramePvpButton:SetHeight(24);
	NIT.instanceFramePvpButton:SetChecked(NIT.db.global.showPvpLog);
	NIT.instanceFramePvpButton:SetScript("OnClick", function()
		local value = NIT.instanceFramePvpButton:GetChecked();
		NIT.db.global.showPvpLog = value;
		NIT:hideAllLineFrames();
		NIT:recalcInstanceLineFrames();
		--Refresh the config page.
		NIT.acr:NotifyChange("NovaInstanceTracker");
	end)
	NIT.instanceFramePvpButton:SetHitRectInsets(0, 0, -10, 7);
end

function NIT:createInstanceFramePveButton()
	if (NIT.instanceFramePveButton) then
		return;
	end
	NIT.instanceFramePveButton = CreateFrame("CheckButton", "NITInstanceFramePveButton", NITInstanceFrame.EditBox, "ChatConfigCheckButtonTemplate");
	NIT.instanceFramePveButton:SetPoint("TOPLEFT", 55, 2);
	NITInstanceFramePveButtonText:SetText("PvE");
	NIT.instanceFramePveButton.tooltip = "Show dungeons and raids?";
	NIT.instanceFramePveButton:SetFrameStrata("HIGH");
	NIT.instanceFramePveButton:SetFrameLevel(4);
	NIT.instanceFramePveButton:SetWidth(24);
	NIT.instanceFramePveButton:SetHeight(24);
	NIT.instanceFramePveButton:SetChecked(NIT.db.global.showPveLog);
	NIT.instanceFramePveButton:SetScript("OnClick", function()
		local value = NIT.instanceFramePveButton:GetChecked();
		NIT.db.global.showPveLog = value;
		NIT:hideAllLineFrames();
		NIT:recalcInstanceLineFrames();
		--Refresh the config page.
		NIT.acr:NotifyChange("NovaInstanceTracker");
	end)
	NIT.instanceFramePveButton:SetHitRectInsets(0, 0, -10, 7);
end

function NIT:createInstanceFrameSelectAltMenu()
	if (NIT.instanceFrameSelectAltMenu) then
		return;
	end
	NIT.instanceFrameSelectAltMenu = NIT.DDM:Create_UIDropDownMenu("NITInstanceFrameSelectAltMenu", NITInstanceFrame.EditBox)
	NIT.instanceFrameSelectAltMenu:SetPoint("TOPLEFT", -14, -17);
	NIT.instanceFrameSelectAltMenu:SetFrameStrata("HIGH");
	NIT.instanceFrameSelectAltMenu:SetFrameLevel(2);
	NIT.instanceFrameSelectAltMenu.tooltip = CreateFrame("Frame", "NITInstanceFrameSelectAltMenuTooltip", NITInstanceFrame, "TooltipBorderedFrameTemplate");
	NIT.instanceFrameSelectAltMenu.tooltip:SetPoint("TOPLEFT", 30, 45);
	NIT.instanceFrameSelectAltMenu.tooltip:SetFrameStrata("TOOLTIP");
	NIT.instanceFrameSelectAltMenu.tooltip:SetFrameLevel(9);
	NIT.instanceFrameSelectAltMenu.tooltip.fs = NIT.instanceFrameSelectAltMenu.tooltip:CreateFontString("NITInstanceFrameSelectAltMenuTooltipFS", "ARTWORK");
	NIT.instanceFrameSelectAltMenu.tooltip.fs:SetPoint("CENTER", 0, 0);
	NIT.instanceFrameSelectAltMenu.tooltip.fs:SetFont(NIT.regionFont, 14);
	NIT.instanceFrameSelectAltMenu.tooltip.fs:SetText("|Cffffd000" .. L["instanceFrameSelectAltMsg"]);
	NIT.instanceFrameSelectAltMenu.tooltip:SetWidth(NIT.instanceFrameSelectAltMenu.tooltip.fs:GetStringWidth() + 18);
	NIT.instanceFrameSelectAltMenu.tooltip:SetHeight(NIT.instanceFrameSelectAltMenu.tooltip.fs:GetStringHeight() + 12);
	NIT.instanceFrameSelectAltMenu.tooltip:Hide();
	NIT.instanceFrameSelectAltMenu.initialize = function(dropdown)
		local chars = {
			[UnitName("player")] = true,
		};
		for k, v in pairs(NIT.data.instances) do
			chars[v.playerName] = true;
		end
		for k, v in NIT:pairsByKeys(chars) do
			local info = NIT.DDM:UIDropDownMenu_CreateInfo()
			info.text = k;
			info.checked = false;
			info.value = k;
			info.func = function(self)
				NIT.DDM:UIDropDownMenu_SetSelectedValue(dropdown, self.value)
				NIT:recalcInstanceLineFrames();
			end
			NIT.DDM:UIDropDownMenu_AddButton(info);
		end
		if (not NIT.DDM:UIDropDownMenu_GetSelectedValue(NIT.instanceFrameSelectAltMenu)) then
			--If no value set then it's first load, set current char.
			NIT.DDM:UIDropDownMenu_SetSelectedValue(NIT.instanceFrameSelectAltMenu, UnitName("player"));
		end
	end
	NIT.instanceFrameSelectAltMenu:HookScript("OnShow", NIT.instanceFrameSelectAltMenu.initialize);
	NIT.instanceFrameSelectAltMenu:HookScript("OnEnter", function(self)
		NIT.instanceFrameSelectAltMenu.tooltip:Show();
	end)
	NIT.instanceFrameSelectAltMenu:HookScript("OnLeave", function(self)
		NIT.instanceFrameSelectAltMenu.tooltip:Hide();
	end)
end

function NIT:setInstanceLogFrameHeader()
	local header = "";
	local pvp = ""
	if (NIT.db.global.showPvpLog) then
		pvp = "/PvP";
	end
	if (NIT.db.global.showAltsLog) then
		header = NIT.prefixColor .. "NovaInstanceTracker v" .. version .. "|r\n"
				.. "|TInterface\\AddOns\\NovaInstanceTracker\\Media\\00C800Square:10:10:0:0|t " .. L["pastHour"]
				.. "    |TInterface\\AddOns\\NovaInstanceTracker\\Media\\FFFF00Square:10:10:0:0|t " .. L["pastHour24"]
				.. "    |TInterface\\AddOns\\NovaInstanceTracker\\Media\\FF0000Square:10:10:0:0|t " .. L["older"] .. "\n"
				.. "|TInterface\\AddOns\\NovaInstanceTracker\\Media\\RaidSquare:10:10:0:0|t " .. L["raid"] .. pvp
				.. "    |TInterface\\AddOns\\NovaInstanceTracker\\Media\\AltsSquare:10:10:0:0|t " .. L["alts"];
	else
		header = NIT.prefixColor .. "NovaInstanceTracker v" .. version .. "|r\n"
				.. "|TInterface\\AddOns\\NovaInstanceTracker\\Media\\00C800Square:10:10:0:0|t " .. L["pastHour"]
				.. "   |TInterface\\AddOns\\NovaInstanceTracker\\Media\\FFFF00Square:10:10:0:0|t " .. L["pastHour24"]
				.. "   |TInterface\\AddOns\\NovaInstanceTracker\\Media\\FF0000Square:10:10:0:0|t " .. L["older"]
				.. "   |TInterface\\AddOns\\NovaInstanceTracker\\Media\\RaidSquare:10:10:0:0|t " .. L["raid"] .. pvp;
	end
	NITInstanceFrame.fs:SetText(header);
end

function NIT:openInstanceLogFrame()
	if (not NIT.instanceFrameShowsAltsButton) then
		NIT:createInstanceFrameShowsAltsButton();
	end
	if (not NIT.instanceFramePvpButton) then
		NIT:createInstanceFramePvpButton();
	end
	if (not NIT.instanceFramePveButton) then
		NIT:createInstanceFramePveButton();
	end
	if (not NIT.instanceFrameSelectAltMenu) then
		NIT:createInstanceFrameSelectAltMenu();
	end
	NITInstanceFrameRestedButton:SetText(L["yourChars"]);
	NITInstanceFrameTradesButton:SetText(L["tradeLog"]);
	NITInstanceFrameConfButton:SetText(L["Options"]);
	NIT:setInstanceLogFrameHeader();
	NIT:createInstanceLineFrames(true);
	--Quick fix to re-set the region font since the frames are created before we set region font.
	NITInstanceFrame.fs:SetFont(NIT.regionFont, 14);
	NITInstanceFrame.fs2:SetFont(NIT.regionFont, 14);
	NITInstanceFrame.fs3:SetFont(NIT.regionFont, 14);
	if (NITInstanceFrame:IsShown()) then
		NITInstanceFrame:Hide();
	else
		if (not _G["titleNITInstanceLine"]) then
			NIT:createTitleInstanceLineFrame();
			_G["titleNITInstanceLine"]:Show();
			_G["titleNITInstanceLine"]:ClearAllPoints();
			_G["titleNITInstanceLine"]:SetPoint("LEFT", NITInstanceFrame.EditBox, "TOPLEFT", 3, -63);
		end
		--Fit exactly the last 30 instances in the frames opening scroll area.
		--NITInstanceFrame:SetHeight(501);
		--NITInstanceFrame:SetWidth(instanceFrameWidth);
		NITInstanceFrame:SetHeight(NIT.db.global.instanceWindowHeight);
		NITInstanceFrame:SetWidth(NIT.db.global.instanceWindowWidth);
		local fontSize = false;
		NITInstanceFrame.EditBox:SetFont(NIT.regionFont, 14);
		NITInstanceFrame.EditBox:SetWidth(NITInstanceFrame:GetWidth() - 30);
		NITInstanceFrame:Show();
		--Changing scroll position requires a slight delay.
		--Second delay is a backup.
		C_Timer.After(0.05, function()
			NITInstanceFrame:SetVerticalScroll(0);
		end)
		C_Timer.After(0.3, function()
			NITInstanceFrame:SetVerticalScroll(0);
		end)
		--So interface options and this frame will open on top of each other.
		if (InterfaceOptionsFrame:IsShown()) then
			NITInstanceFrame:SetFrameStrata("DIALOG");
		else
			NITInstanceFrame:SetFrameStrata("HIGH");
		end
		NIT:recalcInstanceLineFrames();
	end
end

function NIT:createInstanceLineFrames(skipRecalc)
	local count = 0;
	local new;
	for k, v in NIT:pairsByKeys(NIT.data.instances) do
		count = count + 1;
		if (not _G[k .. "NITInstanceLine"]) then
			NIT:createInstanceLineFrame(k, v, count);
			new = true;
		end
	end
	if (new and not skipRecalc) then
		NIT:recalcInstanceLineFrames();
	end
end

function NIT:createInstanceLineFrame(type, data, count)
	if (not _G[type .. "NITInstanceLine"]) then
		local obj = CreateFrame("Frame", type .. "NITInstanceLine", NITInstanceFrame.EditBox);
		obj.name = data.name;
		obj.count = count;
		--Keep track of the real instance ID and not just the frame count for use with tooltip data etc.
		obj.id = count;
		local bg = obj:CreateTexture(nil, "HIGH");
		bg:SetAllPoints(obj);
		obj.texture = bg;
		obj.fs = obj:CreateFontString(type .. "NITInstanceLineFS", "ARTWORK");
		obj.fs:SetPoint("LEFT", 0, 0);
		obj.fs:SetFont(NIT.regionFont, 14);
		--They don't quite line up properly without justify on top of set point left.
		obj.fs:SetJustifyH("LEFT");
		obj.tooltip = CreateFrame("Frame", type .. "NITInstanceLineTooltip", NITInstanceFrame, "TooltipBorderedFrameTemplate");
		obj.tooltip:SetPoint("CENTER", obj, "CENTER", 0, -46);
		obj.tooltip:SetFrameStrata("HIGH");
		obj.tooltip:SetFrameLevel(4);
		obj.tooltip.fs = obj.tooltip:CreateFontString(type .. "NITInstanceLineTooltipFS", "ARTWORK");
		obj.tooltip.fs:SetPoint("CENTER", 0, 0);
		obj.tooltip.fs:SetFont(NIT.regionFont, 13);
		obj.tooltip.fs:SetJustifyH("LEFT");
		obj.tooltip.fs:SetText("|CffDEDE42Frame " .. count);
		obj.tooltip.fsCalc = obj.tooltip:CreateFontString(type .. "NITInstanceLineTooltipFS", "ARTWORK");
		obj.tooltip.fsCalc:SetFont(NIT.regionFont, 13);
		obj.tooltip:SetWidth(obj.tooltip.fs:GetStringWidth() + 18);
		obj.tooltip:SetHeight(obj.tooltip.fs:GetStringHeight() + 12);
		obj.tooltip:SetScript("OnUpdate", function(self)
			obj.tooltip.updateTime = 0;
			--Keep our custom tooltip at the mouse when it moves.
			local scale, x, y = obj.tooltip:GetEffectiveScale(), GetCursorPosition();
			obj.tooltip:SetPoint("RIGHT", nil, "BOTTOMLEFT", (x / scale) - 2, y / scale);
			local instanceFrameUpdateTime = 0;
			--Only update once per second.
			if (GetServerTime() - obj.tooltip.updateTime > 0) then
				obj.tooltip.updateTime = GetServerTime();
				NIT:recalcInstanceLineFramesTooltip(obj);
			end
		end)
		obj:SetScript("OnEnter", function(self)
			obj.tooltip:Show();
			NIT:recalcInstanceLineFramesTooltip(obj);
			local scale, x, y = obj.tooltip:GetEffectiveScale(), GetCursorPosition();
			obj.tooltip:SetPoint("CENTER", nil, "BOTTOMLEFT", x / scale, y / scale);
		end)
		obj:SetScript("OnLeave", function(self)
			obj.tooltip:Hide();
		end)
		obj.tooltip:Hide();
		--obj:SetScript("OnMouseDown", function(self)
			--Maybe add a mouse event here later.
		--end)
		
		obj.removeButton = CreateFrame("Button", type .. "NITInstanceLineRB", obj, "UIPanelButtonTemplate");
		obj.removeButton:SetPoint("LEFT", obj, "RIGHT", 34, 0);
		obj.removeButton:SetWidth(13);
		obj.removeButton:SetHeight(13);
		--obj.removeButton:SetText("X");
		obj.removeButton:SetNormalFontObject("GameFontNormalSmall");
		--obj.removeButton:SetScript("OnClick", function(self, arg)

		--end)
		obj.removeButton:SetNormalTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_7");
		obj.removeButton.tooltip = CreateFrame("Frame", type .. "NITInstanceLineTooltipRB", NITInstanceFrame, "TooltipBorderedFrameTemplate");
		obj.removeButton.tooltip:SetPoint("RIGHT", obj.removeButton, "LEFT", -5, 0);
		obj.removeButton.tooltip:SetFrameStrata("HIGH");
		obj.removeButton.tooltip:SetFrameLevel(3);
		obj.removeButton.tooltip.fs = obj.removeButton.tooltip:CreateFontString(type .. "NITInstanceLineTooltipRBFS", "ARTWORK");
		obj.removeButton.tooltip.fs:SetPoint("CENTER", -0, 0);
		obj.removeButton.tooltip.fs:SetFont(NIT.regionFont, 13);
		obj.removeButton.tooltip.fs:SetJustifyH("LEFT");
		obj.removeButton.tooltip.fs:SetText("|CffDEDE42" .. L["deleteEntry"] .. " " .. count);
		obj.removeButton.tooltip:SetWidth(obj.removeButton.tooltip.fs:GetStringWidth() + 18);
		obj.removeButton.tooltip:SetHeight(obj.removeButton.tooltip.fs:GetStringHeight() + 12);
		obj.removeButton:SetScript("OnEnter", function(self)
			obj.removeButton.tooltip:Show();
		end)
		obj.removeButton:SetScript("OnLeave", function(self)
			obj.removeButton.tooltip:Hide();
		end)
		obj.removeButton.tooltip:Hide();
	end
end

function NIT:createTitleInstanceLineFrame()
	if (not _G["titleNITInstanceLine"]) then
		local obj = CreateFrame("Frame", "titleNITInstanceLine", NITInstanceFrame.EditBox);
		local bg = obj:CreateTexture(nil, "HIGH");
		bg:SetAllPoints(obj);
		obj.texture = bg;
		obj.fs = obj:CreateFontString("titleNITInstanceLineFS", "ARTWORK");
		obj.fs:SetPoint("LEFT", 0, 0);
		obj.fs:SetFont(NIT.regionFont, 14);
		obj.fs:SetJustifyH("LEFT");
	end
end

function NIT:recalcInstanceLineFrames()
	if (not _G["titleNITInstanceLine"]) then
		--Frame hasn't been opened since logon, no need to recalc.
		return;
	end
	local nameMatch = UnitName("player");
	if (UIDropDownMenu_GetSelectedValue(NIT.instanceFrameSelectAltMenu)) then
		nameMatch = UIDropDownMenu_GetSelectedValue(NIT.instanceFrameSelectAltMenu);
	end
	NIT:setInstanceLogFrameHeader();
	--local offset, count = 75, 0; --60
	local offset, count = 90, 0; --Start offset, per line offset.
	local hour, hour24, hourTimestamp, hourTimestamp24 = NIT:getInstanceLockoutInfo(nameMatch);
	local lockoutString, lockoutStringShort = NIT:getInstanceLockoutInfoString(nameMatch);
	local text = "|cFFFFFF00 " .. L["lastHour"] .. ": |cFFFF6900" .. hour .. " |cFFFFFF00" .. L["lastHour24"] .. ": |cFFFF6900" .. hour24;
	if (NIT.perCharOnly) then
		text = text	.. " |cFFFFFF00(" .. nameMatch .. ")";
	end
	text = text	.. "\n |cFF9CD6DE" .. lockoutStringShort;
	_G["titleNITInstanceLine"].fs:SetText(text);
	_G["titleNITInstanceLine"]:SetWidth(_G["titleNITInstanceLine"].fs:GetWidth());
	_G["titleNITInstanceLine"]:SetHeight(_G["titleNITInstanceLine"].fs:GetHeight());
	local framesUsed = {};
	for k, v in NIT:pairsByKeys(NIT.data.instances) do
		if ((nameMatch == v.playerName or NIT.db.global.showAltsLog)
				and (not v.isPvp or NIT.db.global.showPvpLog)
				and (v.isPvp or NIT.db.global.showPveLog)) then
			if (_G[k .. "NITInstanceLine"]) then
				local timeAgo = GetServerTime() - v.enteredTime;
				if (v.leftTime and v.leftTime > 0) then
					timeAgo = GetServerTime() - v.leftTime;
				end
				if (NIT.db.global.show24HourOnly and timeAgo > 86400) then
					break;
				end
				count = count + 1;
				if (count > self.db.global.logSize) then
					if (_G[count .. "NITInstanceLine"]) then
						_G[count .. "NITInstanceLine"]:Hide();
					end
				else
					framesUsed[count] = true;
					_G[count .. "NITInstanceLine"]:Show();
					_G[count .. "NITInstanceLine"]:ClearAllPoints();
					_G[count .. "NITInstanceLine"]:SetPoint("LEFT", NITInstanceFrame.EditBox, "TOPLEFT", 3, -offset);
					offset = offset + 14;
					local line = NIT:buildInstanceLineFrameString(v, count);
					if (count < 10) then
						--Offset the text for single digit numbers so the date comlumn lines up.
						_G[count .. "NITInstanceLine"].fs:SetPoint("LEFT", 7, 0);
					else
						_G[count .. "NITInstanceLine"].fs:SetPoint("LEFT", 0, 0);
					end
					_G[count .. "NITInstanceLine"].fs:SetText(line);
					--Leave enough room on the right of frame to not overlap the scroll bar (-20) and remove button (-20).
					_G[count .. "NITInstanceLine"]:SetWidth(NITInstanceFrame:GetWidth() - 120);
					_G[count .. "NITInstanceLine"]:SetHeight(_G[count .. "NITInstanceLine"].fs:GetHeight());
					_G[count .. "NITInstanceLine"].removeButton.count = count;
					_G[count .. "NITInstanceLine"].removeButton:SetScript("OnClick", function(self, arg)
						--Open delete confirmation box to delete table id (k), but display it as matching log number (count).
						NIT:openDeleteConfirmFrame(k, self.count);
					end)
					--Keep track of the real instance ID and not just the frame count for use with tooltip data etc.
					_G[count .. "NITInstanceLine"].id = k;
				end
			end
		end
	end
	--Hide any no longer is use lines frames from the bottom when instances are deleted.
	for i = 1, NIT.maxRecordsShown do
		if (_G[i .. "NITInstanceLine"] and not framesUsed[i]) then
			_G[i .. "NITInstanceLine"]:Hide();
		end
	end
end

function NIT:buildInstanceLineFrameString(v, count)
	local player = v.playerName;
	local _, _, _, classColorHex = GetClassColor(v.classEnglish);
	--Safeguard for weakauras/addons that like to overwrite and break the GetClassColor() function.
	if (not classColorHex and v.classEnglish == "SHAMAN") then
		classColorHex = "ff0070dd";
	elseif (not classColorHex) then
		classColorHex = "ffffffff";
	end
	local instance = v.instanceName;
	--Remove prefixes for english version for readability and fitting in the frame better.
	instance = string.gsub(instance, "Hellfire Citadel: ", "");
	instance = string.gsub(instance, "Coilfang: ", "");
	instance = string.gsub(instance, "Auchindoun: ", "");
	instance = string.gsub(instance, "Tempest Keep: ", "");
	instance = string.gsub(instance, "Opening of the Dark Portal", "Black Morass");
	if (v.difficultyID == 174) then
		instance = instance .. " (|cFFFF2222H|r)";
	end
	local time = NIT:getTimeFormat(v.enteredTime, true, true);
	local timeAgo = GetServerTime() - v.enteredTime;
	local enteredType = "entered";
	if (v.leftTime and v.leftTime > 0) then
		--If valid left time use that instead.
		enteredType = "left";
		timeAgo = GetServerTime() - v.leftTime;
		time = NIT:getTimeFormat(v.leftTime, true, true);
	end
	local nameMatch = UnitName("player");
	if (NIT.instanceFrameSelectAltMenu and UIDropDownMenu_GetSelectedValue(NIT.instanceFrameSelectAltMenu)) then
		nameMatch = UIDropDownMenu_GetSelectedValue(NIT.instanceFrameSelectAltMenu);
	end
	local lockoutTime;
	local timeColor = "|cFFFF2222";
	local lockoutTimeString, altString = "", "";
	if (NIT.perCharOnly and UnitName("player") ~= v.playerName) then
		lockoutTimeString = instance .. " (" .. L["entered"] .. " " .. NIT:getTimeString(timeAgo, true, NIT.db.global.timeStringType) .. " " .. L["ago"] .. ")";
	else
		lockoutTimeString = instance .. " (" .. L["entered"] .. " " .. NIT:getTimeString(timeAgo, true, NIT.db.global.timeStringType) .. " " .. L["ago"] .. ")";
	end
	if (timeAgo < 3600) then
		lockoutTime = NIT:getTimeString(3600 - timeAgo, true, NIT.db.global.timeStringType)
		if (not NIT.perCharOnly or nameMatch == v.playerName) then
			timeColor = "|cFF00C800";
			if (count == 1 and NIT.inInstance) then
				lockoutTimeString = instance .. " (" .. L["stillInDungeon"] .. ")";
			else
				lockoutTimeString = instance .. " (" .. lockoutTime .. " " .. L["leftOnLockout"] .. ")";
			end
		end
	elseif (timeAgo < 86400) then
		lockoutTime = NIT:getTimeString(86400 - timeAgo, true, NIT.db.global.timeStringType)
		if (not NIT.perCharOnly or nameMatch == v.playerName) then
			timeColor = "|cFFDEDE42";
			if (count == 1 and NIT.inInstance) then
				lockoutTimeString = instance .. " (" .. L["stillInDungeon"] .. ")";
			else
				lockoutTimeString = instance .. " (" .. lockoutTime .. " " .. L["leftOnDailyLockout"] .. ")";
			end
		end
	end
	if (v.type == "arena") then
		timeColor = "|cFFFFA500";
		local ratingChange = NIT:getRatingChange(v);
		if (ratingChange) then
			lockoutTimeString = instance .. " (" .. ratingChange .. " Arena Rating)";
		else
			lockoutTimeString = instance .. " (Arena)";
		end
		if (count == 1 and NIT.inInstance) then
			if (LOCALE_koKR or LOCALE_zhCN or LOCALE_zhTW or LOCALE_ruRU) then
				lockoutTimeString = lockoutTimeString .. " (" .. L["stillInDungeon"] .. ")";
			else
				lockoutTimeString = lockoutTimeString .. " (" .. L["stillInArena"] .. ")";
			end
		end
		if (v.faction and v.winningFaction and v.faction == v.winningFaction) then
			lockoutTimeString = lockoutTimeString .. " |cFF00C800" .. L["Won"] .. "|r";
		elseif (v.faction and v.winningFaction) then
			lockoutTimeString = lockoutTimeString .. " |cFFFF2222" .. L["Lost"] .. "|r";
		end
	elseif (v.type == "bg") then
		timeColor = "|cFFFFA500";
		if (v.honor) then
			lockoutTimeString = instance .. " (+" .. v.honor .. " Honor)";
		else
			lockoutTimeString = instance .. " (Battleground)";
		end
		if (count == 1 and NIT.inInstance) then
			if (LOCALE_koKR or LOCALE_zhCN or LOCALE_zhTW or LOCALE_ruRU) then
				lockoutTimeString = lockoutTimeString .. " (" .. L["stillInDungeon"] .. ")";
			else
				lockoutTimeString = lockoutTimeString .. " (" .. L["stillInBattleground"] .. ")";
			end
		end
		if (v.faction and v.winningFaction and v.faction == v.winningFaction) then
			lockoutTimeString = lockoutTimeString .. " |cFF00C800" .. L["Won"] .. "|r";
		elseif (v.faction and v.winningFaction) then
			lockoutTimeString = lockoutTimeString .. " |cFFFF2222" .. L["Lost"] .. "|r";
		end
	elseif (v.instanceID and NIT.zones[v.instanceID] and NIT.zones[v.instanceID].noLockout) then
		--timeColor = "|cFFFF7F50";
		timeColor = "|cFFFFA500";
		lockoutTimeString = instance .. " (" .. L["noLockout"] .. ")";
	end
	if (nameMatch ~= v.playerName) then
		timeColor = "|cFFA1A1A1";
	end
	local line = "";
	if (NIT.db.global.showLockoutTime) then
		line = "|cFF9CD6DE" .. count .. ")|r [" .. timeColor .. time .. "|cFF9CD6DE]|r |c" .. classColorHex .. player 
			.. "|r |cFF9CD6DE" .. lockoutTimeString .. altString;
	else
		line = "|cFF9CD6DE" .. count .. ")|r [" .. timeColor .. time .. "|cFF9CD6DE]|r |c" .. classColorHex .. player 
			.. "|r |cFF9CD6DE" .. instance .. " (" .. L["entered"] .. " " .. NIT:getTimeString(timeAgo, true, NIT.db.global.timeStringType) .. " " .. L["ago"] .. ")";
	end
	return line;
end

function NIT:getRatingChange(data)
	--Find which team we were on.
	local team;
	if (data.purpleTeam) then
		for k, v in pairs(data.purpleTeam) do
			if (k == data.playerName) then
				team = data.purpleTeam;
			end
		end
	end
	if (data.goldTeam) then
		for k, v in pairs(data.goldTeam) do
			if (k == data.playerName) then
				team = data.goldTeam;
			end
		end
	end
	if (team) then
		local _, first = next(team);
		if (first and first.newTeamRating and first.teamRating) then
			local delta = first.newTeamRating - first.teamRating;
			if (delta > 0) then
				delta = "+" .. delta;
			end
			return delta;
		end
	end
end

function NIT:hideAllLineFrames()
	for i = 1, NIT.db.global.maxRecordsKept do
		if (_G[i .. "NITInstanceLine"]) then
			_G[i .. "NITInstanceLine"]:Hide();
		end
	end
end

function NIT:recalcInstanceLineFramesTooltip(obj)
	local data = NIT.data.instances[obj.id];
	if (data) then
		local timeSpent = L["unknown"];
		local timeSpentRaw = 0;
		if (data.enteredTime and data.leftTime and data.enteredTime > 0 and data.leftTime > 0) then
			timeSpent = NIT:getTimeString(data.leftTime - data.enteredTime, true);
			timeSpentRaw = data.leftTime - data.enteredTime;
		elseif (data.enteredTime and data.leftTime and data.enteredTime > 0 and (GetServerTime() - data.enteredTime) < 21600) then
			timeSpent = NIT:getTimeString(GetServerTime() - data.enteredTime, true);
			timeSpentRaw = GetServerTime() - data.enteredTime;
		end
		local averageXP = L["unknown"];
		local mobCount = 0;
		--Check both count from xp and count from combat log event.
		--So it works for boosters that mobs are grey and people out of range of combat event but still get xp.
		if (data.mobCount and data.mobCount > 0) then
			mobCount = data.mobCount;
		elseif (data.mobCountFromKill and data.mobCountFromKill > 0) then
			mobCount = data.mobCountFromKill;
		end
		--if (data.xpFromChat and data.mobCount and data.enteredTime > 0 and data.mobCount > 0) then
		if (data.xpFromChat and data.enteredTime > 0 and mobCount > 0) then
			averageXP = data.xpFromChat / mobCount;
		end
		local timeLastInside = GetServerTime() - data.enteredTime;
		if (data.leftTime and data.leftTime > 0) then
			timeLastInside = GetServerTime() - data.leftTime;
		end
		local timeLeft = L["unknown"];
		if (data.leftTime and data.leftTime > 0) then
			 timeLeft = NIT:getTimeFormat(data.leftTime, true, true);
		end
		local timeColor = "|cFFFF2222";
		if (timeLastInside < 3600) then
			 timeColor = "|cFF00C800";
		elseif (timeLastInside < 86400) then
			timeColor = "|cFFDEDE42";
		end
		local player = data.playerName;
		local _, _, _, classColorHex = GetClassColor(data.classEnglish);
		--Safeguard for weakauras/addons that like to overwrite and break the GetClassColor() function.
		if (not classColorHex and data.classEnglish == "SHAMAN") then
			classColorHex = "ff0070dd";
		elseif (not classColorHex) then
			classColorHex = "ffffffff";
		end
		local heroicString = "";
		if (data.difficultyID == 174) then
			heroicString = " (|cFFFF2222H|r)";
		end
		local text = timeColor .. "Instance " .. obj.count .. " (" .. data.instanceName .. heroicString .. ")|r";
		if (not data.isPvp and data.instanceID and (NIT.zones[data.instanceID] and NIT.zones[data.instanceID].noLockout)) then
			timeColor = "|cFFFFA500";
			text = timeColor .. "Instance " .. obj.count .. " (" .. data.instanceName .. ") (Raid with no lockout)|r";
		end
		if (UnitName("player") ~= data.playerName) then
			timeColor = "|cFFA1A1A1";
			text = timeColor .. "Instance " .. obj.count .. " (" .. data.instanceName .. ") (Alt)|r";
		end
		if (not data.isPvp and data.zoneID) then
			text = text .. " (ZoneID: " .. data.zoneID .. ")";
		end
		text = text .. "\n|cFF9CD6DE" .. L["timeEntered"] .. ":|r " .. NIT:getTimeFormat(data.enteredTime, true, true);
		text = text .. "\n|cFF9CD6DE" .. L["timeLeft"] .. ":|r " .. timeLeft;
		text = text .. "\n|cFF9CD6DE" .. L["timeInside"] .. ":|r " .. timeSpent;
		if (not data.isPvp) then
			text = text .. "\n|cFF9CD6DE" .. L["mobCount"] .. ":|r " .. (mobCount or "Unknown");
		end
		if (not data.isPvp) then
			text = text .. "\n|cFF9CD6DE" .. L["experience"] .. ":|r " .. (NIT:commaValue(data.xpFromChat) or "Unknown");
			if (timeSpentRaw and timeSpentRaw > 0 and tonumber(data.xpFromChat) and data.xpFromChat > 0 and not data.isPvp) then
				local xpPerHour = NIT:commaValue(NIT:round((tonumber(data.xpFromChat) / timeSpentRaw) * 3600));
				text = text .. "\n|cFF9CD6DE" .. L["experiencePerHour"] .. ":|r " .. xpPerHour;
			end
			if (tonumber(data.xpFromChat) and data.xpFromChat > 0 and not data.isPvp) then
				text = text .. "\n|cFF9CD6DE" .. L["statsAverageXP"] .. "|r " .. (NIT:round(averageXP, 2) or "0");
			end
		end
		if (not data.isPvp) then
			if (data.rawMoneyCount and data.rawMoneyCount > 0) then
				text = text .. "\n|cFF9CD6DE" .. L["rawGoldMobs"] .. ":|r " .. GetCoinTextureString(data.rawMoneyCount);
			elseif (data.enteredMoney and data.leftMoney and data.enteredMoney > 0 and data.leftMoney > 0
					and data.leftMoney > data.enteredMoney) then
				--Backup for people with addons installed using an altered money string.
				local moneyCount = data.leftMoney - data.enteredMoney;
				text = text .. "\n|cFF9CD6DE" .. L["rawGoldMobs"] .. ":|r " .. GetCoinTextureString(moneyCount);
			else
				text = text .. "\n|cFF9CD6DE" .. L["rawGoldMobs"] .. ":|r " .. GetCoinTextureString(0);
			end
		end
		if (not data.isPvp) then
			text = text .. "\n|cFF9CD6DE" .. L["enteredLevel"] .. ":|r " .. (data.enteredLevel or "Unknown");
			text = text .. "\n|cFF9CD6DE" .. L["leftLevel"] .. ":|r " .. (data.leftLevel or "Unknown");
		end
		if (data.type ~= "arena" and data.groupAverage and data.groupAverage > 0) then
			text = text .. "\n|cFF9CD6DE" .. L["averageGroupLevel"] .. ":|r " .. (NIT:round(data.groupAverage, 2) or "Unknown");
		end
		if (data.isPvp) then
			if (data.type == "arena") then
				if (data.faction and data.winningFaction and data.faction == data.winningFaction) then
					text = text .. "\n|cFF00C800" .. L["Won"] .. "|r";
					--[[if (data.winningFaction == 1) then
						--Gold won.
						text = text .. " |cFFFFFFFF(as Gold)|r";
					elseif (data.winningFaction == 0) then
						--Purple won.
						text = text .. " |cFFFFFFFF(as Purple)|r";
					end]]
				elseif (data.faction and data.winningFaction) then
					text = text .. "\n|cFFFF2222" .. L["Lost"] .. "|r";
					--[[if (data.winningFaction == 1) then
						text = text .. " |cFFFFFFFF(as Gold)|r";
					elseif (data.winningFaction == 0) then
						text = text .. " |cFFFFFFFF(as Purple)|r";
					end]]
				end
				if (data.purpleTeam) then
					text = text .. "\n\n|cFFB75EFFPurple Team|r";
					local _, first = next(data.purpleTeam);
					if (first) then
						text = text .. "  (|cFFB75EFF" .. first.teamName .. "|r)";
						local delta = first.newTeamRating - first.teamRating;
						if (delta > 0) then
							delta = "+" .. delta;
						end
						text = text .. "\n|cFFB75EFFRating:|r " .. first.newTeamRating .. " (" .. delta .. ")";
						text = text .. " |cFFB75EFFMMR:|r " .. first.teamMMR;
					end
					for k, v in pairs(data.purpleTeam) do
						--local coords = CLASS_BUTTONS[v.class];
						--local texture = "|TInterface\\WorldStateFrame\\Icons-Classes:13:13:0:0:256:256:" .. coords[1] * 256 ..":"
						--		.. coords[2] + 256 ..":" .. coords[3] * 256 ..":" .. coords[4] * 256 .. "|t";
						local _, _, _, classColorHex = GetClassColor(v.class);
						text = text .. "\n|c" .. classColorHex .. k .. "|r ";
						if (v.damage) then
							text = text .. " |cFFB75EFFDmg:|r " .. v.damage;
						end
						if (v.healing) then
							text = text .. " |cFFB75EFFHeals:|r " .. v.healing;
						end
						if (v.kb) then
							text = text .. " |cFFB75EFFKB:|r " .. v.kb;
						end
					end
				end
				if (data.goldTeam) then
					text = text .. "\n\n|cFFFFD101Gold Team|r";
					local _, first = next(data.goldTeam);
					if (first) then
						text = text .. "  (|cFFFFD101" .. first.teamName .. "|r)";
						local delta = first.newTeamRating - first.teamRating;
						if (delta > 0) then
							delta = "+" .. delta;
						end
						text = text .. "\n|cFFFFD101Rating:|r " .. first.newTeamRating .. " (" .. delta .. ")";
						text = text .. " |cFFFFD101MMR:|r " .. first.teamMMR;
					end
					for k, v in pairs(data.goldTeam) do
						local _, _, _, classColorHex = GetClassColor(v.class);
						text = text .. "\n|c" .. classColorHex .. k .. "|r ";
						if (v.damage) then
							text = text .. " |cFFFFD101Dmg:|r " .. v.damage;
						end
						if (v.healing) then
							text = text .. " |cFFFFD101Heals:|r " .. v.healing;
						end
						if (v.kb) then
							text = text .. " |cFFFFD101KB:|r " .. v.kb;
						end
					end
				end
			else
				if (data.faction and data.winningFaction and data.faction == data.winningFaction) then
					text = text .. "\n|cFF00C800" .. L["Won"] .. "|r";
					if (NIT.faction == "Horde" and data.winningFaction == 1) then
						text = text .. " |cFFFFFFFF(as Alliance)|r";
					elseif (NIT.faction == "Alliance" and data.winningFaction == 0) then
						text = text .. " |cFFFFFFFF(as Horde)|r";
					end
				elseif (data.faction and data.winningFaction) then
					text = text .. "\n|cFFFF2222" .. L["Lost"] .. "|r";
					if (NIT.faction == "Horde" and data.winningFaction == 0) then
						text = text .. " |cFFFFFFFF(as Alliance)|r";
					elseif (NIT.faction == "Alliance" and data.winningFaction == 1) then
						text = text .. " |cFFFFFFFF(as Horde)|r";
					end
				end
				if (data.damage) then
					text = text .. "\n\n|cFF9CD6DE-" .. L["Damage"] .. ":|r " .. NIT:commaValue(data.damage);
				end
				if (data.healing) then
					text = text .. "\n|cFF9CD6DE-" .. L["Healing"] .. ":|r " .. NIT:commaValue(data.healing);
				end
				if (data.hk) then
					text = text .. "\n|cFF9CD6DE-" .. L["Honorable Kills"] .. ":|r " .. data.hk;
				end
				if (data.kb) then
					text = text .. "\n|cFF9CD6DE-" .. L["Killing Blows"] .. ":|r " .. data.kb;
				end
				if (data.deaths) then
					text = text .. "\n|cFF9CD6DE-" .. L["Deaths"] .. ":|r " .. data.deaths;
				end
				if (data.objectives and next(data.objectives)) then
					for k, v in ipairs(data.objectives) do
						local texture = "|T" .. v.icon .. ":13:13:0:0|t";
						text = text .. "\n|cFF9CD6DE-" .. texture .. v.text .. ":|r " .. v.score;
					end
				end
			end
		end
		if (not data.isPvp and data.playerName ~= UnitName("player")) then
			--Show lockout timers for alts if you hover them.
			--Use the minimap lockout string for this, it's small and neat.
			--text = text .. "\n\n|cFF9CD6DEThis alts current lockouts:|r\n";
			text = text .. "\n\n|c" .. classColorHex .. player .. "|r|cFF9CD6DE " .. L["currentLockouts"] .. ":|r\n";
			text = text .. NIT:getAltLockoutString(data.playerName);
			local expires = NIT:getMinimapButtonNextExpires(data.playerName);
			if (expires) then
				text = text .. "\n\n" .. expires;
			end
		end
		if (data.honor) then
			text = text .. "\n\n|cFFFFFF00" .. L["honorGains"] .. ":|r"
			text = text .. "\n |cFF9CD6DE+" .. data.honor .. "|r";
		end
		if (data.rep and next(data.rep)) then
			text = text .. "\n\n|cFFFFFF00" .. L["repGains"] .. ":|r"
			for k, v in NIT:pairsByKeys(data.rep) do
				if (v > 0) then
					v = "+" .. NIT:commaValue(v);
				end
				text = text .. "\n |cFF9CD6DE" .. k .. "|r " .. v;
			end
		end
		if (data.group and next(data.group)) then
			local memberCount = 0;
			for k, v in pairs(data.group) do
				memberCount = memberCount + 1;
			end
			--Make extra columns if many group members.
			local perLine = 1;
			if (memberCount > 50) then
				perLine = 4
			elseif (memberCount > 24) then
				perLine = 3
			elseif (memberCount > 14) then
				perLine = 2
			end
			text = text .. "\n\n|cFFFFFF00" .. L["groupMembers"] .. " (" .. memberCount .. "):|r\n";
			local count = 0;
			local spacing = 30;
			--This is ugly but works, table is small.
			--Sorts by level and then name.
			local temp = {};
			for i = NIT.maxLevel, 0, -1 do
				for k, v in NIT:pairsByKeys(data.group) do
					if (i == v.level) then
						v.name = k;
						table.insert(temp, v);
					end
				end
			end
			for k, v in ipairs(temp) do
				count = count + 1;
				local nl = "";
				local classColorHexString = "";
				if (v.classEnglish) then
					local _, _, _, classColorHex = GetClassColor(string.upper(v.classEnglish));
					--Safeguard for weakauras/addons that like to overwrite and break the GetClassColor() function.
					if (not classColorHex and string.upper(v.classEnglish) == "SHAMAN") then
						classColorHex = "ff0070dd";
					elseif (not classColorHex) then
						classColorHex = "ffffffff";
					end
					classColorHexString = "|c" .. classColorHex;
				end
				if ((count ~= 1 and math.fmod(count, perLine) == 0)
						or (count == 1 and perLine == 1)) then
					nl = "\n";
				end
				local groupLine = "";
				if (v.guildName) then
					groupLine = " |cFFFFFFFF" .. v.level .. "|r " .. classColorHexString .. v.name .. "|r |cFF989898(" .. v.guildName .. ")|r";
				else
					groupLine = " |cFFFFFFFF" .. v.level .. "|r " .. classColorHexString .. v.name .. "|r";
				end
				obj.tooltip.fsCalc:SetText(groupLine);
				--Space strings so they roughly look like columns.
				if (math.fmod(count, perLine) > 0) then
					obj.tooltip.fsCalc:SetText(groupLine);
					--Trim string if multiple columns.
					while obj.tooltip.fsCalc:GetWidth() > 150 do
						groupLine = string.sub(groupLine, 1, -2);
						obj.tooltip.fsCalc:SetText(groupLine);
					end
					obj.tooltip.fsCalc:SetText(groupLine);
					while obj.tooltip.fsCalc:GetWidth() < 160 do
						groupLine = groupLine .. " ";
						obj.tooltip.fsCalc:SetText(groupLine);
					end
				end
				text = text .. groupLine .. nl;
			end
		end
		local foundTrades;
		local trades = "";
		for k, v in ipairs(NIT.data.trades) do
			--[[count = count + 1;
			if (count > 100) then
				break;
			end]]
			if (data.leftTime and data.leftTime > 0 and v.time > data.enteredTime and v.time < data.leftTime
					and v.where == data.instanceName) then
				local msg = "";
				local _, _, _, classColorHex = GetClassColor(v.tradeWhoClass);
				--Safeguard for weakauras/addons that like to overwrite and break the GetClassColor() function.
				if (not classColorHex and v.tradeWhoClass == "SHAMAN") then
					classColorHex = "ff0070dd";
				elseif (not classColorHex) then
					classColorHex = "ffffffff";
				end
				local time = NIT:getTimeFormat(v.time, true, true);
				local timeAgo = GetServerTime() - v.time;
				if (v.playerMoney > 0) then
					msg = msg .. "[|cFFDEDE42" .. time .. "|r] |cFF9CD6DE" .. L["gave"] .. " |r" .. NIT:getCoinString(v.playerMoney)
							.. "|r |cFF9CD6DE" .. L["to"] .. " |c"
							.. classColorHex .. v.tradeWho .. NIT.chatColor .. " |cFF9CD6DE" .. L["in"] .. " " .. v.where 
							.. " (" .. NIT:getTimeString(timeAgo, true) .. " " .. L["ago"] .. "\n"
					foundTrades = true;
				end
				if (v.targetMoney > 0) then
					msg = msg .. "[|cFFDEDE42" .. time .. "|r] |cFF9CD6DE" .. L["received"] .. " |r" .. NIT:getCoinString(v.targetMoney)
							.. "|r |cFF9CD6DE" .. L["from"] .. " |c"
							.. classColorHex .. v.tradeWho .. NIT.chatColor .. " |cFF9CD6DE" .. L["in"] .. " " .. v.where 
							.. " (" .. NIT:getTimeString(timeAgo, true) .. " " .. L["ago"] .. ")\n"
					foundTrades = true;
				end
				trades = trades .. msg;
			end
		end
		if (foundTrades) then
			text = text .. "\n\n|cFFFFFF00" .. L["tradesWhileInside"] .. ":|r\n";
			text = text .. trades;
		end
		obj.tooltip.fs:SetText(text);
	else
		obj.tooltip.fs:SetText("|CffDEDE42Frame " .. obj.count .. "\n" .. L["noDataInstance"] .. ".");
	end
	obj.tooltip:SetWidth(obj.tooltip.fs:GetStringWidth() + 18);
	obj.tooltip:SetHeight(obj.tooltip.fs:GetStringHeight() + 12);
end

function NIT:getAltLockoutString(char)
	local hourCount, hourCount24, hourTimestamp, hourTimestamp24 = NIT:getInstanceLockoutInfo(char);
	local countStringColorized = NIT.prefixColor .. hourCount .. "|r" .. NIT.chatColor.. " " .. L["instancesPastHour"] .. "|r\n"
			.. NIT.prefixColor .. hourCount24 .. "|r" .. NIT.chatColor .. " " .. L["instancesPastHour24"] .. "|r\n";
	local lockoutInfo = "now";
	if (GetServerTime() - hourTimestamp24 < 86400 and hourCount24 >= NIT.dailyLimit) then
		lockoutInfo = "in " .. NIT:getTimeString(86400 - (GetServerTime() - hourTimestamp24), true) .. " (" .. L["active24"] .. ")";
	elseif (GetServerTime() - hourTimestamp < 3600 and hourCount >= NIT.hourlyLimit) then
		lockoutInfo = "in " .. NIT:getTimeString(3600 - (GetServerTime() - hourTimestamp), true);
	end
	local msg = NIT.prefixColor .. hourCount .. "|r" .. NIT.chatColor.. " " .. L["instancesPastHour"] .. "|r\n"
			.. NIT.prefixColor .. hourCount24 .. "|r" .. NIT.chatColor .. " " .. L["instancesPastHour24"] .. "|r\n"
			.. NIT.chatColor .. L["nextInstanceAvailable"] .. " " .. lockoutInfo .. ".|r";
	return msg;
end

local NITInstanceFrameDeleteConfirm = CreateFrame("ScrollFrame", "NITInstanceFrameDC", UIParent, NIT:addBackdrop("InputScrollFrameTemplate"));
NITInstanceFrameDeleteConfirm:Hide();
NITInstanceFrameDeleteConfirm:SetToplevel(true);
NITInstanceFrameDeleteConfirm:SetHeight(130);
NITInstanceFrameDeleteConfirm:SetWidth(250);
tinsert(UISpecialFrames, "NITInstanceFrameDeleteConfirm");
NITInstanceFrameDeleteConfirm:SetPoint("CENTER", UIParent, 0, 200);
NITInstanceFrameDeleteConfirm:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8",insets = {top = 0, left = 0, bottom = 0, right = 0}});
NITInstanceFrameDeleteConfirm:SetBackdropColor(0,0,0,1);
NITInstanceFrameDeleteConfirm.CharCount:Hide();
NITInstanceFrameDeleteConfirm:SetFrameStrata("HIGH");
NITInstanceFrameDeleteConfirm.EditBox:SetAutoFocus(false);
NITInstanceFrameDeleteConfirm.EditBox:EnableMouse(false);
NITInstanceFrameDeleteConfirm.EditBox:SetScript("OnKeyDown", function(self, arg)
	NITInstanceFrameDeleteConfirm.EditBox:ClearFocus();
end)
NITInstanceFrameDeleteConfirm.EditBox:SetScript("OnUpdate", function(self, arg)
	--This is a hack so the editbox never gets focus and I can use the same frame template minus the editbox.
	NITInstanceFrameDeleteConfirm.EditBox:ClearFocus();
end)
NITInstanceFrameDeleteConfirm.EditBox:SetScript("OnHide", function(self, arg)
	--Clear the instance deletion that was set.
	NITInstanceFrameDCDelete:SetScript("OnClick", function(self, arg) end);
end)

NITInstanceFrameDeleteConfirm.fs = NITInstanceFrameDeleteConfirm:CreateFontString("NITInstanceFrameFS", "HIGH");
NITInstanceFrameDeleteConfirm.fs:SetPoint("TOP", 0, -4);
NITInstanceFrameDeleteConfirm.fs:SetFont(NIT.regionFont, 14);
NITInstanceFrameDeleteConfirm.fs:SetText("Instance data missing");

--Delete button.
local NITInstanceFrameDCDelete = CreateFrame("Button", "NITInstanceFrameDCDelete", NITInstanceFrameDeleteConfirm, "UIPanelButtonTemplate");
NITInstanceFrameDCDelete:SetPoint("CENTER", 0, -40);
NITInstanceFrameDCDelete:SetWidth(120);
NITInstanceFrameDCDelete:SetHeight(30);
--NITInstanceFrameDCDelete:SetText(L["confirmDelete"]);
NITInstanceFrameDCDelete:SetText(L["delete"]);
NITInstanceFrameDCDelete:SetNormalFontObject("GameFontNormal");

--Top right X close button.
local NITInstanceDCFrameClose = CreateFrame("Button", "NITInstanceDCFrameClose", NITInstanceFrameDeleteConfirm, "UIPanelCloseButton");
--NITInstanceDCFrameClose:SetPoint("TOPRIGHT", 10, 10);
--NITInstanceDCFrameClose:SetWidth(36);
--NITInstanceDCFrameClose:SetHeight(36);
NITInstanceDCFrameClose:SetPoint("TOPRIGHT", -12, 3.75);
NITInstanceDCFrameClose:SetWidth(20);
NITInstanceDCFrameClose:SetHeight(20);
NITInstanceDCFrameClose:SetScript("OnClick", function(self, arg)
	NITInstanceFrameDeleteConfirm:Hide();
end)
--Adjust the X texture so it fits the entire frame and remove the empty clickable space around the close button.
--Big thanks to Meorawr for this.
NITInstanceDCFrameClose:GetNormalTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITInstanceDCFrameClose:GetHighlightTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITInstanceDCFrameClose:GetPushedTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITInstanceDCFrameClose:GetDisabledTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);

--Open delete confirmation box.
--If displayNum is provided then we display it as the matching number in the instance log.
--But we still delete the right table id number.
local deleteItemLast;
function NIT:openDeleteConfirmFrame(num, displayNum)
	--Close window if we click delete button for same item again, but open new one if different item is clicked.
	if (NITInstanceFrameDeleteConfirm:IsShown() and num == deleteItemLast) then
		NITInstanceFrameDeleteConfirm:Hide();
	else
		NITInstanceFrameDeleteConfirm:Hide();
		local data = NIT.data.instances[num];
		if (data) then
			local player = data.playerName;
			local _, _, _, classColorHex = GetClassColor(data.classEnglish);
			--Safeguard for weakauras/addons that like to overwrite and break the GetClassColor() function.
			if (not classColorHex and data.classEnglish == "SHAMAN") then
				classColorHex = "ff0070dd";
			elseif (not classColorHex) then
				classColorHex = "ffffffff";
			end
			local instance = data.instanceName;
			local time = NIT:getTimeFormat(data.enteredTime, true, true);
			local timeAgo = GetServerTime() - data.enteredTime;
			local timeLastInside = GetServerTime() - data.enteredTime;
			if (data.leftTime and data.leftTime > 0) then
				timeLastInside = GetServerTime() - data.leftTime;
			end
			local timeColor = "|cFFFF2222";
			if (timeLastInside < 3600) then
				 timeColor = "|cFF00C800";
			elseif (timeLastInside < 86400) then
				timeColor = "|cFFDEDE42";
			end
			local text = NIT.prefixColor .. L["confirmInstanceDeletion"] .. "|r\n";
			if (displayNum) then
				text = text .. "\n|cFF9CD6DE" .. instance .. " (" .. displayNum .. ")|r";
			else
				text = text .. "\n|cFF9CD6DE" .. instance .. " (" .. num .. ")|r";
			end
			text = text .. "\n" .. timeColor .. time .. "|r";
			text = text .. "\n|c" .. classColorHex .. player .. " |cFF9CD6DE(" .. NIT:getTimeString(timeAgo, true) .. " ago)";
			NITInstanceFrameDeleteConfirm.fs:SetText(text);
			NITInstanceFrameDCDelete:Show();
			NITInstanceFrameDCDelete:SetScript("OnClick", function(self, arg)
				NIT:deleteInstance(num, displayNum);
				NITInstanceFrameDeleteConfirm:Hide();
			end)
		else
			NITInstanceFrameDeleteConfirm.fs:SetText("Error: Instance data missing");
			--NITInstanceFrameDCDelete:SetText(L["Error"]);
			NITInstanceFrameDCDelete:Hide();
		end
		NITInstanceFrameDeleteConfirm:Show();
	end
	deleteItemLast = num;
end

---Trade Log---
local NITTradeLogFrame = CreateFrame("ScrollFrame", "NITTradeLogFrame", UIParent, NIT:addBackdrop("InputScrollFrameTemplate"));
NITTradeLogFrame:Hide();
NITTradeLogFrame:SetToplevel(true);
NITTradeLogFrame:SetMovable(true);
NITTradeLogFrame:EnableMouse(true);
tinsert(UISpecialFrames, "NITTradeLogFrame");
NITTradeLogFrame:SetPoint("CENTER", UIParent, 20, 120);
NITTradeLogFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8",insets = {top = 0, left = 0, bottom = 0, right = 0}});
NITTradeLogFrame:SetBackdropColor(0,0,0,.8);
NITTradeLogFrame.CharCount:Hide();
--NITTradeLogFrame:SetFrameLevel(128);
NITTradeLogFrame:SetFrameStrata("MEDIUM");
NITTradeLogFrame.EditBox:SetAutoFocus(false);
NITTradeLogFrame.EditBox:SetFont(NIT.regionFont, 10);
NITTradeLogFrame.EditBox:SetScript("OnKeyDown", function(self, arg)
	NITTradeLogFrame.EditBox:ClearFocus();
end)
NITTradeLogFrame.EditBox:SetScript("OnShow", function(self, arg)
	NITTradeLogFrame:SetVerticalScroll(0);
end)
local buffUpdateTime = 0;
NITTradeLogFrame:HookScript("OnUpdate", function(self, arg)
	if (GetServerTime() - buffUpdateTime > 0 and self:GetVerticalScrollRange() == 0) then
		NIT:recalcTradeLogFrame();
		buffUpdateTime = GetServerTime();
	end
end)
NITTradeLogFrame.fs = NITTradeLogFrame.EditBox:CreateFontString("NITTradeLogFrameFS", "HIGH");
NITTradeLogFrame.fs:SetPoint("TOP", 0, 0);
NITTradeLogFrame.fs:SetFont(NIT.regionFont, 14);

local NITTradeLogDragFrame = CreateFrame("Frame", "NITTradeLogDragFrame", NITTradeLogFrame);
NITTradeLogDragFrame:EnableMouse(true);
NITTradeLogDragFrame:SetWidth(205);
NITTradeLogDragFrame:SetHeight(38);
NITTradeLogDragFrame:SetPoint("TOP", 0, 4);
NITTradeLogDragFrame:SetFrameLevel(131);
NITTradeLogDragFrame.tooltip = CreateFrame("Frame", "NITTradeLogDragTooltip", NITTradeLogDragFrame, "TooltipBorderedFrameTemplate");
NITTradeLogDragFrame.tooltip:SetPoint("CENTER", NITTradeLogDragFrame, "TOP", 0, 12);
NITTradeLogDragFrame.tooltip:SetFrameStrata("TOOLTIP");
NITTradeLogDragFrame.tooltip:SetFrameLevel(9);
NITTradeLogDragFrame.tooltip:SetAlpha(.8);
NITTradeLogDragFrame.tooltip.fs = NITTradeLogDragFrame.tooltip:CreateFontString("NITTradeLogDragTooltipFS", "HIGH");
NITTradeLogDragFrame.tooltip.fs:SetPoint("CENTER", 0, 0.5);
NITTradeLogDragFrame.tooltip.fs:SetFont(NIT.regionFont, 13);
NITTradeLogDragFrame.tooltip.fs:SetText("Hold to drag");
NITTradeLogDragFrame.tooltip:SetWidth(NITTradeLogDragFrame.tooltip.fs:GetStringWidth() + 16);
NITTradeLogDragFrame.tooltip:SetHeight(NITTradeLogDragFrame.tooltip.fs:GetStringHeight() + 10);
NITTradeLogDragFrame:SetScript("OnEnter", function(self)
	NITTradeLogDragFrame.tooltip:Show();
end)
NITTradeLogDragFrame:SetScript("OnLeave", function(self)
	NITTradeLogDragFrame.tooltip:Hide();
end)
NITTradeLogDragFrame.tooltip:Hide();
NITTradeLogDragFrame:SetScript("OnMouseDown", function(self, button)
	if (button == "LeftButton" and not self:GetParent().isMoving) then
		self:GetParent().EditBox:ClearFocus();
		self:GetParent():StartMoving();
		self:GetParent().isMoving = true;
		--self:GetParent():SetUserPlaced(false);
	end
end)
NITTradeLogDragFrame:SetScript("OnMouseUp", function(self, button)
	if (button == "LeftButton" and self:GetParent().isMoving) then
		self:GetParent():StopMovingOrSizing();
		self:GetParent().isMoving = false;
	end
end)
NITTradeLogDragFrame:SetScript("OnHide", function(self)
	if (self:GetParent().isMoving) then
		self:GetParent():StopMovingOrSizing();
		self:GetParent().isMoving = false;
	end
end)

--Top right X close button.
local NITTradeLogFrameClose = CreateFrame("Button", "NITTradeLogFrameClose", NITTradeLogFrame, "UIPanelCloseButton");
--NITTradeLogFrameClose:SetPoint("TOPRIGHT", -5, 8.6);
--NITTradeLogFrameClose:SetWidth(31);
--NITTradeLogFrameClose:SetHeight(31);
NITTradeLogFrameClose:SetPoint("TOPRIGHT", -12, 3.75);
NITTradeLogFrameClose:SetWidth(20);
NITTradeLogFrameClose:SetHeight(20);
NITTradeLogFrameClose:SetScript("OnClick", function(self, arg)
	NITTradeLogFrame:Hide();
end)
--Adjust the X texture so it fits the entire frame and remove the empty clickable space around the close button.
--Big thanks to Meorawr for this.
NITTradeLogFrameClose:GetNormalTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITTradeLogFrameClose:GetHighlightTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITTradeLogFrameClose:GetPushedTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITTradeLogFrameClose:GetDisabledTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);

--Reset button.
local NITTradeLogFrameResetButton = CreateFrame("Button", "NITTradeLogFrameResetButton", NITTradeLogFrameClose, "UIPanelButtonTemplate");
NITTradeLogFrameResetButton:SetPoint("CENTER", -100,0);
NITTradeLogFrameResetButton:SetWidth(90);
NITTradeLogFrameResetButton:SetHeight(17);
NITTradeLogFrameResetButton:SetText("Reset Data");
NITTradeLogFrameResetButton:SetNormalFontObject("GameFontNormalSmall");
NITTradeLogFrameResetButton:SetScript("OnClick", function(self, arg)
	StaticPopupDialogs["NIT_TRADEDATARESET"] = {
	  text = "Delete all trade data?",
	  button1 = "Yes",
	  button2 = "No",
	  OnAccept = function()
	      NIT:resetTradeData();
	  end,
	  timeout = 0,
	  whileDead = true,
	  hideOnEscape = true,
	  preferredIndex = 3,
	};
	StaticPopup_Show("NIT_TRADEDATARESET");
end)

function NIT:openTradeLogFrame()
	NITTradeLogFrame.fs:SetFont(NIT.regionFont, 14);
	local header = NIT.prefixColor .. "NovaInstanceTracker v" .. version .. "|r\n"
			.. "|cffffff00Trade Log";
	NITTradeLogFrame.fs:SetText(header);
	NITTradeLogFrameResetButton:SetText(L["Reset Data"]);
	if (NITTradeLogFrame:IsShown()) then
		NITTradeLogFrame:Hide();
	else
		--NITTradeLogFrame:SetHeight(320);
		--NITTradeLogFrame:SetWidth(580);
		NITTradeLogFrame:SetHeight(NIT.db.global.tradeWindowHeight);
		NITTradeLogFrame:SetWidth(NIT.db.global.tradeWindowWidth);
		local fontSize = false
		NITTradeLogFrame.EditBox:SetFont(NIT.regionFont, 13);
		NIT:recalcTradeLogFrame();
		NITTradeLogFrame.EditBox:SetWidth(NITTradeLogFrame:GetWidth() - 30);
		NITTradeLogFrame:Show();
		--Changing scroll position requires a slight delay.
		--Second delay is a backup.
		C_Timer.After(0.05, function()
			NITTradeLogFrame:SetVerticalScroll(0);
		end)
		C_Timer.After(0.3, function()
			NITTradeLogFrame:SetVerticalScroll(0);
		end)
		--So interface options and this frame will open on top of each other.
		if (InterfaceOptionsFrame:IsShown()) then
			NITTradeLogFrame:SetFrameStrata("DIALOG")
		else
			NITTradeLogFrame:SetFrameStrata("HIGH")
		end
	end
end

function NIT:recalcTradeLogFrame()
	NITTradeLogFrame.EditBox:SetText("\n\n\n");
	local count = 0;
	local found;
	for k, v in ipairs(NIT.data.trades) do
		count = count + 1;
		if (count > 200) then
			break;
		end
		local msg = "";
		local traded;
		local _, _, _, classColorHex = GetClassColor(v.tradeWhoClass);
		--Safeguard for weakauras/addons that like to overwrite and break the GetClassColor() function.
		if (not classColorHex and v.tradeWhoClass == "SHAMAN") then
			classColorHex = "ff0070dd";
		elseif (not classColorHex) then
			classColorHex = "ffffffff";
		end
		local time = NIT:getTimeFormat(v.time, true, true);
		local timeAgo = GetServerTime() - v.time;
		if (v.playerMoney > 0) then
			msg = msg .. "[|cFFDEDE42" .. time .. "|r] |cFF9CD6DE" .. L["gave"] .. "|r "
					.. NIT:getCoinString(v.playerMoney) .. "|r |cFF9CD6DE" .. L["to"] .. "|r |c"
					.. classColorHex .. v.tradeWho .. "|r |cFF9CD6DE" .. L["in"] .. " " .. v.where 
					.. " (" .. NIT:getTimeString(timeAgo, true) .. " ago)|r\n";
			traded = true;
			found = true;
		end
		if (v.targetMoney > 0) then
			msg = msg .. "[|cFFDEDE42" .. time .. "|r] |cFF9CD6DE" .. L["received"] .. "|r "
					.. NIT:getCoinString(v.targetMoney) .. "|r |cFF9CD6DE" .. L["from"] .. "|r |c"
					.. classColorHex .. v.tradeWho .. "|r |cFF9CD6DE" .. L["in"] .. " " .. v.where 
					.. " (" .. NIT:getTimeString(timeAgo, true) .. " " .. L["ago"] .. ")|r\n";
			found = true;
		end
		NITTradeLogFrame.EditBox:Insert(msg);
	end
	if (not found) then
		NITTradeLogFrame.EditBox:Insert("\n|cffffff00No trade logs found.");
	end
end

function NIT:resetTradeData()
	NIT.data.trades = {};
	NIT:print("Trade log data has been reset.");
	NIT:recalcTradeLogFrame();
end

--Copy Paste.
local NITTradeCopyFrame = CreateFrame("ScrollFrame", "NITTradeCopyFrame", UIParent, NIT:addBackdrop("InputScrollFrameTemplate"));
NITTradeCopyFrame:Hide();
NITTradeCopyFrame:SetToplevel(true);
NITTradeCopyFrame:SetMovable(true);
NITTradeCopyFrame:EnableMouse(true);
tinsert(UISpecialFrames, "NITTradeCopyFrame");
NITTradeCopyFrame:SetPoint("CENTER", UIParent, -70, 150);
NITTradeCopyFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8",insets = {top = 0, left = 0, bottom = 0, right = 0}});
NITTradeCopyFrame:SetBackdropColor(0,0,0,0.9);
NITTradeCopyFrame.CharCount:Hide();
NITTradeCopyFrame:SetFrameStrata("HIGH");
NITTradeCopyFrame.EditBox:SetAutoFocus(false);
--Top right X close button.
local NITTradeCopyFrameClose = CreateFrame("Button", "NITTradeCopyFrameClose", NITTradeCopyFrame, "UIPanelCloseButton");
NITTradeCopyFrameClose:SetPoint("TOPRIGHT", -12, 3.75);
NITTradeCopyFrameClose:SetWidth(20);
NITTradeCopyFrameClose:SetHeight(20);
NITTradeCopyFrameClose:SetFrameLevel(3);
NITTradeCopyFrameClose:SetScript("OnClick", function(self, arg)
	NITTradeCopyFrame:Hide();
end)
--Adjust the X texture so it fits the entire frame and remove the empty clickable space around the close button.
NITTradeCopyFrameClose:GetNormalTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITTradeCopyFrameClose:GetHighlightTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITTradeCopyFrameClose:GetPushedTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITTradeCopyFrameClose:GetDisabledTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);

local NITTradeCopyDragFrame = CreateFrame("Frame", "NITTradeCopyDragFrame", NITTradeCopyFrame, NIT:addBackdrop());
NITTradeCopyDragFrame:SetToplevel(true);
NITTradeCopyDragFrame:EnableMouse(true);
--NITTradeCopyDragFrame:SetPoint("TOP", 0, 25);
NITTradeCopyDragFrame:SetPoint("TOP", 0, 91);
NITTradeCopyDragFrame:SetBackdrop({
	bgFile = "Interface\\Buttons\\WHITE8x8",
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]],
	edgeSize = 14,
	insets = {left = 4, right = 4, top = 4, bottom = 4},
});
NITTradeCopyDragFrame:SetBackdropColor(0,0,0,0.9);
NITTradeCopyDragFrame:SetBackdropBorderColor(0.235, 0.235, 0.235);
NITTradeCopyDragFrame.fs = NITTradeCopyDragFrame:CreateFontString("NITTradeCopyDragFrameFS", "HIGH");
--NITTradeCopyDragFrame.fs:SetPoint("CENTER", 0, 0);
NITTradeCopyDragFrame.fs:SetPoint("TOP", 0, -5);
NITTradeCopyDragFrame.fs:SetFont(NIT.regionFont, 14);
NITTradeCopyDragFrame.fs:SetText(NIT.prefixColor .. "Trade Copy Frame|r");
--NITTradeCopyDragFrame:SetWidth(NITTradeCopyDragFrame.fs:GetWidth() + 16);
--NITTradeCopyDragFrame:SetHeight(22);
NITTradeCopyDragFrame:SetWidth(300);
NITTradeCopyDragFrame:SetHeight(90);

NITTradeCopyDragFrame:SetScript("OnMouseDown", function(self, button)
	if (button == "LeftButton" and not self:GetParent().isMoving) then
		self:GetParent().EditBox:ClearFocus();
		self:GetParent():StartMoving();
		self:GetParent().isMoving = true;
		--self:GetParent():SetUserPlaced(false);
	end
end)
NITTradeCopyDragFrame:SetScript("OnMouseUp", function(self, button)
	if (button == "LeftButton" and self:GetParent().isMoving) then
		self:GetParent():StopMovingOrSizing();
		self:GetParent().isMoving = false;
	end
end)
NITTradeCopyDragFrame:SetScript("OnHide", function(self)
	if (self:GetParent().isMoving) then
		self:GetParent():StopMovingOrSizing();
		self:GetParent().isMoving = false;
	end
end)

local NITTradeFrameCopyButton = CreateFrame("Button", "NITTradeFrameCopyButton", NITTradeLogFrameClose, "UIPanelButtonTemplate");
NITTradeFrameCopyButton:SetPoint("TOPLEFT", NITTradeLogFrame, 1, 1);
NITTradeFrameCopyButton:SetWidth(90);
NITTradeFrameCopyButton:SetHeight(17);
NITTradeFrameCopyButton:SetText("Copy/Paste");
NITTradeFrameCopyButton:SetNormalFontObject("GameFontNormalSmall");
NITTradeFrameCopyButton:SetScript("OnClick", function(self, arg)
	NIT:openTradeCopyFrame();
end)
NITTradeFrameCopyButton:SetScript("OnMouseDown", function(self, button)
	if (button == "LeftButton" and not self:GetParent():GetParent().isMoving) then
		self:GetParent():GetParent().EditBox:ClearFocus();
		self:GetParent():GetParent():StartMoving();
		self:GetParent():GetParent().isMoving = true;
	end
end)
NITTradeFrameCopyButton:SetScript("OnMouseUp", function(self, button)
	if (button == "LeftButton" and self:GetParent():GetParent().isMoving) then
		self:GetParent():GetParent():StopMovingOrSizing();
		self:GetParent():GetParent().isMoving = false;
	end
end)
NITTradeFrameCopyButton:SetScript("OnHide", function(self)
	if (self:GetParent():GetParent().isMoving) then
		self:GetParent():GetParent():StopMovingOrSizing();
		self:GetParent():GetParent().isMoving = false;
	end
end)

function NIT:createTradeCopyFormatButtons()
	if (not NIT.copyTradeTimeButton) then
		NIT.copyTradeTimeButton = CreateFrame("CheckButton", "NITCopyTradeTimeButton", NITTradeCopyDragFrame, "ChatConfigCheckButtonTemplate");
		NIT.copyTradeTimeButton:SetPoint("BOTTOM", -100, 0);
		NITCopyTradeTimeButtonText:SetText("Time");
		NIT.copyTradeTimeButton.tooltip = "Show time?";
		--NIT.copyTradeTimeButton:SetFrameStrata("HIGH");
		NIT.copyTradeTimeButton:SetFrameLevel(3);
		NIT.copyTradeTimeButton:SetWidth(24);
		NIT.copyTradeTimeButton:SetHeight(24);
		NIT.copyTradeTimeButton:SetChecked(NIT.db.global.copyTradeTime);
		NIT.copyTradeTimeButton:SetScript("OnClick", function()
			local value = NIT.copyTradeTimeButton:GetChecked();
			NIT.db.global.copyTradeTime = value;
			NIT:recalcTradeCopyFrame();
			C_Timer.After(0.05, function()
				NITTradeCopyFrame:SetVerticalScroll(0);
			end)
			C_Timer.After(0.3, function()
				NITTradeCopyFrame:SetVerticalScroll(0);
			end)
			--Refresh the config page.
			--NIT.acr:NotifyChange("NovaInstanceTracker");
		end)
		NIT.copyTradeTimeButton:SetHitRectInsets(0, 0, -10, 7);
	end
	if (not NIT.copyTradeZoneButton) then
		NIT.copyTradeZoneButton = CreateFrame("CheckButton", "NITCopyTradeZoneButton", NITTradeCopyDragFrame, "ChatConfigCheckButtonTemplate");
		NIT.copyTradeZoneButton:SetPoint("BOTTOM", -15, 0);
		NITCopyTradeZoneButtonText:SetText("Zone");
		NIT.copyTradeZoneButton.tooltip = "Show Zonewhere trade happened?";
		--NIT.copyTradeZoneButton:SetFrameStrata("HIGH");
		NIT.copyTradeZoneButton:SetFrameLevel(4);
		NIT.copyTradeZoneButton:SetWidth(24);
		NIT.copyTradeZoneButton:SetHeight(24);
		NIT.copyTradeZoneButton:SetChecked(NIT.db.global.copyTradeZone);
		NIT.copyTradeZoneButton:SetScript("OnClick", function()
			local value = NIT.copyTradeZoneButton:GetChecked();
			NIT.db.global.copyTradeZone = value;
			NIT:recalcTradeCopyFrame();
			C_Timer.After(0.05, function()
				NITTradeCopyFrame:SetVerticalScroll(0);
			end)
			C_Timer.After(0.3, function()
				NITTradeCopyFrame:SetVerticalScroll(0);
			end)
			--Refresh the config page.
			--NIT.acr:NotifyChange("NovaInstanceTracker");
		end)
		NIT.copyTradeZoneButton:SetHitRectInsets(0, 0, -10, 7);
	end
	if (not NIT.copyTradeTimeAgoButton) then
		NIT.copyTradeTimeAgoButton = CreateFrame("CheckButton", "NITCopyTradeTimeAgoButton", NITTradeCopyDragFrame, "ChatConfigCheckButtonTemplate");
		NIT.copyTradeTimeAgoButton:SetPoint("BOTTOM", 60, 0);
		NITCopyTradeTimeAgoButtonText:SetText("Time Ago");
		NIT.copyTradeTimeAgoButton.tooltip = "Show how long ago?";
		--NIT.copyTradeTimeAgoButton:SetFrameStrata("HIGH");
		NIT.copyTradeTimeAgoButton:SetFrameLevel(5);
		NIT.copyTradeTimeAgoButton:SetWidth(24);
		NIT.copyTradeTimeAgoButton:SetHeight(24);
		NIT.copyTradeTimeAgoButton:SetChecked(NIT.db.global.copyTradeTimeAgo);
		NIT.copyTradeTimeAgoButton:SetScript("OnClick", function()
			local value = NIT.copyTradeTimeAgoButton:GetChecked();
			NIT.db.global.copyTradeTimeAgo = value;
			NIT:recalcTradeCopyFrame();
			C_Timer.After(0.05, function()
				NITTradeCopyFrame:SetVerticalScroll(0);
			end)
			C_Timer.After(0.3, function()
				NITTradeCopyFrame:SetVerticalScroll(0);
			end)
			--Refresh the config page.
			--NIT.acr:NotifyChange("NovaInstanceTracker");
		end)
		NIT.copyTradeTimeAgoButton:SetHitRectInsets(0, 0, -10, 7);
	end
	if (not NIT.copyTradeRecordsSlider) then
		NIT.copyTradeRecordsSlider = CreateFrame("Slider", "NITCopyTradeRecordsSlider", NITTradeCopyDragFrame, "OptionsSliderTemplate");
		NIT.copyTradeRecordsSlider:SetPoint("BOTTOM", 0, 40);
		NITCopyTradeRecordsSliderText:SetText("Records");
		NIT.copyTradeRecordsSlider.tooltip = "How many trade records to show?";
		--NIT.copyTradeRecordsSlider:SetFrameStrata("HIGH");
		NIT.copyTradeRecordsSlider:SetFrameLevel(5);
		NIT.copyTradeRecordsSlider:SetWidth(224);
		NIT.copyTradeRecordsSlider:SetHeight(16);
		NIT.copyTradeRecordsSlider:SetMinMaxValues(1, 100);
	    NIT.copyTradeRecordsSlider:SetObeyStepOnDrag(true);
	    NIT.copyTradeRecordsSlider:SetValueStep(1);
	    NIT.copyTradeRecordsSlider:SetStepsPerPage(1);
		NIT.copyTradeRecordsSlider:SetValue(NIT.db.global.copyTradeRecords);
	    NITCopyTradeRecordsSliderLow:SetText("1");
	    NITCopyTradeRecordsSliderHigh:SetText("100");
		NITCopyTradeRecordsSlider:HookScript("OnValueChanged", function(self, value)
			NIT.db.global.copyTradeRecords = value;
			NIT.copyTradeRecordsSlider.editBox:SetText(value);
			NIT:recalcTradeCopyFrame();
		end)
		--Some of this was taken from AceGUI.
		local function EditBox_OnEscapePressed(frame)
			frame:ClearFocus();
		end
		local function EditBox_OnEnterPressed(frame)
			local value = frame:GetText();
			value = tonumber(value);
			if value then
				PlaySound(856);
				NIT.db.global.copyTradeRecords = value;
				NIT.copyTradeRecordsSlider:SetValue(value);
				frame:ClearFocus();
				NIT:recalcTradeCopyFrame();
			else
				--If not a valid number reset the box.
				NIT.copyTradeRecordsSlider.editBox:SetText(NIT.db.global.copyTradeRecords);
				frame:ClearFocus();
			end
		end
		local function EditBox_OnEnter(frame)
			frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1);
		end
		local function EditBox_OnLeave(frame)
			frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8);
		end
		local ManualBackdrop = {
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
			tile = true, edgeSize = 1, tileSize = 5,
		};
		NIT.copyTradeRecordsSlider.editBox = CreateFrame("EditBox", nil, NIT.copyTradeRecordsSlider, NIT:addBackdrop());
		NIT.copyTradeRecordsSlider.editBox:SetAutoFocus(false);
		NIT.copyTradeRecordsSlider.editBox:SetFontObject(GameFontHighlightSmall);
		NIT.copyTradeRecordsSlider.editBox:SetPoint("TOP", NIT.copyTradeRecordsSlider, "BOTTOM");
		NIT.copyTradeRecordsSlider.editBox:SetHeight(14);
		NIT.copyTradeRecordsSlider.editBox:SetWidth(70);
		NIT.copyTradeRecordsSlider.editBox:SetJustifyH("CENTER");
		NIT.copyTradeRecordsSlider.editBox:EnableMouse(true);
		NIT.copyTradeRecordsSlider.editBox:SetBackdrop(ManualBackdrop);
		NIT.copyTradeRecordsSlider.editBox:SetBackdropColor(0, 0, 0, 0.5);
		NIT.copyTradeRecordsSlider.editBox:SetBackdropBorderColor(0.3, 0.3, 0.30, 0.80);
		NIT.copyTradeRecordsSlider.editBox:SetScript("OnEnter", EditBox_OnEnter);
		NIT.copyTradeRecordsSlider.editBox:SetScript("OnLeave", EditBox_OnLeave);
		NIT.copyTradeRecordsSlider.editBox:SetScript("OnEnterPressed", EditBox_OnEnterPressed);
		NIT.copyTradeRecordsSlider.editBox:SetScript("OnEscapePressed", EditBox_OnEscapePressed);
	end
end

function NIT:openTradeCopyFrame()
	if (not NIT.copyTradeTimeButton) then
		NIT:createTradeCopyFormatButtons();
	end
	NITTradeCopyDragFrame.fs:SetFont(NIT.regionFont, 14);
	if (NITTradeCopyFrame:IsShown()) then
		NITTradeCopyFrame:Hide();
	else
		NITTradeCopyFrame:SetHeight(NIT.db.global.tradeWindowHeight + 5.5);
		NITTradeCopyFrame:SetWidth(NIT.db.global.tradeWindowWidth);
		NITTradeCopyFrame.EditBox:SetFont(NIT.regionFont, 14);
		NITTradeCopyFrame.EditBox:SetWidth(NITTradeCopyFrame:GetWidth() - 30);
		NIT.copyTradeRecordsSlider.editBox:SetText(NIT.db.global.copyTradeRecords);
		NITTradeCopyFrame:Show();
		NIT:recalcTradeCopyFrame();
		C_Timer.After(0.05, function()
			NITTradeCopyFrame:SetVerticalScroll(0);
		end)
		C_Timer.After(0.3, function()
			NITTradeCopyFrame:SetVerticalScroll(0);
		end)
		--So interface options and this frame will open on top of each other.
		if (InterfaceOptionsFrame:IsShown()) then
			NITTradeCopyFrame:SetFrameStrata("DIALOG")
		else
			NITTradeCopyFrame:SetFrameStrata("HIGH")
		end
	end
end

function NIT:recalcTradeCopyFrame()
	local text = "";
	local count = 0;
	local found;
	for k, v in ipairs(NIT.data.trades) do
		count = count + 1;
		if (count > NIT.db.global.copyTradeRecords) then
			break;
		end
		local msg = "";
		local _, _, _, classColorHex = GetClassColor(v.tradeWhoClass);
		--Safeguard for weakauras/addons that like to overwrite and break the GetClassColor() function.
		if (not classColorHex and v.tradeWhoClass == "SHAMAN") then
			classColorHex = "ff0070dd";
		elseif (not classColorHex) then
			classColorHex = "ffffffff";
		end
		local time = NIT:getTimeFormat(v.time, true, true);
		local timeAgo = GetServerTime() - v.time;
		if (v.playerMoney > 0) then
			if (NIT.db.global.copyTradeTime) then
				msg = msg .. "[|cFFDEDE42" .. time .. "|r] ";
			end
			msg = msg .. "|cFF9CD6DE" .. L["gave"] .. " |r"
					..NIT:convertMoney(v.playerMoney, true, "", true) .. "|r |cFF9CD6DE" .. L["to"] .. " |c"
					.. classColorHex .. v.tradeWho .. NIT.chatColor;
			if (NIT.db.global.copyTradeZone) then
				msg = msg .. " |cFF9CD6DE" .. L["in"] .. " " .. v.where;
			end
			if (NIT.db.global.copyTradeTimeAgo) then
				msg = msg .. " |cFF9CD6DE(" .. NIT:getTimeString(timeAgo, true) .. " ago)";
			end
			msg = msg .. "\n";
			found = true;
		end
		if (v.targetMoney > 0) then
			if (NIT.db.global.copyTradeTime) then
				msg = msg .. "[|cFFDEDE42" .. time .. "|r] ";
			end
			msg = msg .. "|cFF9CD6DE" .. L["received"] .. " |r"
					..NIT:convertMoney(v.targetMoney, true, "", true) .. "|r |cFF9CD6DE" .. L["from"] .. " |c"
					.. classColorHex .. v.tradeWho .. NIT.chatColor;
			if (NIT.db.global.copyTradeZone) then
				msg = msg .. " |cFF9CD6DE" .. L["in"] .. " " .. v.where;
			end
			if (NIT.db.global.copyTradeTimeAgo) then
				msg = msg .. " |cFF9CD6DE(" .. NIT:getTimeString(timeAgo, true) .. " ago)";
			end
			msg = msg .. "\n";
			found = true;
		end
		text = text .. msg;
	end
	--Remove newline chars from start and end of string.
	--text = string.gsub(text, "^%s*(.-)%s*$", "%1");
	if (not found) then
		NITTradeCopyFrame.EditBox:SetText("|cffffff00No trade logs found.");
	else
		NITTradeCopyFrame.EditBox:SetText(text);
		NITTradeCopyFrame.EditBox:HighlightText();
		NITTradeCopyFrame.EditBox:SetFocus();
	end
end

---Rested Info---

function NIT:calcRested(currentXP, maxXP, time, resting, restedXP, online)
	local percent, bubbles, totalRestedXP = 0, 0, 0;
	if (online) then
		--Ignore timestamp and get rested stats from the API if character is online.
		if (UnitXP("player") > 0) then
			currentXP = UnitXP("player");
		end
		if (UnitXPMax("player") > 0) then
			maxXP = UnitXPMax("player");
		end
		if (GetXPExhaustion()) then
			restedXP = GetXPExhaustion();
		end
		local storedRested = (restedXP / maxXP) * 100;
		percent = NIT:round(storedRested, 2);
	else
		local percentPerSecond = 0;
		if (resting) then
			percentPerSecond = 0.00017361111;
		else
			percentPerSecond = 0.0000434027775;
		end
		local storedRested = (restedXP / maxXP) * 100;
		percent = (time * percentPerSecond) + storedRested;
		percent = NIT:round(percent, 2);
		if (percent > 150) then
			percent = 150;
		end
	end
	--Get xp amount in one bubble of current level.
	local bubbleXP = maxXP / 20;
	--Get how many bubbles fit into our current rested XP.
	bubbles = NIT:round(restedXP / bubbleXP, 1);
	--Get 1% of current levels xp required, times it by current % of rested.
	totalRestedXP = NIT:round((maxXP / 100) * percent);
	return percent, bubbles, totalRestedXP;
end

local NITAltsFrame = CreateFrame("ScrollFrame", "NITAltsFrame", UIParent, NIT:addBackdrop("InputScrollFrameTemplate"));
local altsFrameWidth = 550;
NITAltsFrame:Hide();
NITAltsFrame:SetToplevel(true);
NITAltsFrame:SetMovable(true);
NITAltsFrame:EnableMouse(true);
tinsert(UISpecialFrames, "NITAltsFrame");
NITAltsFrame:SetPoint("CENTER", UIParent, 0, 100);
NITAltsFrame:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8",insets = {top = 0, left = 0, bottom = 0, right = 0}});
NITAltsFrame:SetBackdropColor(0,0,0,.8);
NITAltsFrame.CharCount:Hide();
NITAltsFrame:SetFrameStrata("HIGH");
NITAltsFrame.EditBox:SetAutoFocus(false);
NITAltsFrame.EditBox:SetScript("OnKeyDown", function(self, arg)
	NITAltsFrame.EditBox:ClearFocus();
end)
NITAltsFrame.EditBox:SetScript("OnShow", function(self, arg)
	NITAltsFrame:SetVerticalScroll(0);
	NITAltsFrame:SetVerticalScroll(0);
end)
local altsFrameUpdateTime = 0;
NITAltsFrame:HookScript("OnUpdate", function(self, arg)
	NITAltsFrame.EditBox:ClearFocus();
	--Only update once per second.
	if (GetServerTime() - altsFrameUpdateTime > 0) then
		altsFrameUpdateTime = GetServerTime();
		NIT:recalcAltsLineFrames();
	end
end)
NITAltsFrame.fs = NITAltsFrame.EditBox:CreateFontString("NITAltsFrameFS", "HIGH");
NITAltsFrame.fs:SetPoint("TOP", 0, -0);
NITAltsFrame.fs:SetFont(NIT.regionFont, 14);

local NITAltsDragFrame = CreateFrame("Frame", "NITCharDragFrame", NITAltsFrame);
NITAltsDragFrame:SetToplevel(true);
NITAltsDragFrame:EnableMouse(true);
NITAltsDragFrame:SetWidth(205);
NITAltsDragFrame:SetHeight(38);
NITAltsDragFrame:SetPoint("TOP", 0, 4);
NITAltsDragFrame:SetFrameLevel(131);
NITAltsDragFrame.tooltip = CreateFrame("Frame", "NITAltsDragTooltip", NITAltsDragFrame, "TooltipBorderedFrameTemplate");
NITAltsDragFrame.tooltip:SetPoint("CENTER", NITAltsDragFrame, "TOP", 0, 12);
NITAltsDragFrame.tooltip:SetFrameStrata("TOOLTIP");
NITAltsDragFrame.tooltip:SetFrameLevel(9);
NITAltsDragFrame.tooltip:SetAlpha(.8);
NITAltsDragFrame.tooltip.fs = NITAltsDragFrame.tooltip:CreateFontString("NITAltsDragTooltipFS", "HIGH");
NITAltsDragFrame.tooltip.fs:SetPoint("CENTER", 0, 0.5);
NITAltsDragFrame.tooltip.fs:SetFont(NIT.regionFont, 12);
NITAltsDragFrame.tooltip.fs:SetText("Hold to drag");
NITAltsDragFrame.tooltip:SetWidth(NITAltsDragFrame.tooltip.fs:GetStringWidth() + 16);
NITAltsDragFrame.tooltip:SetHeight(NITAltsDragFrame.tooltip.fs:GetStringHeight() + 10);
NITAltsDragFrame:SetScript("OnEnter", function(self)
	NITAltsDragFrame.tooltip:Show();
end)
NITAltsDragFrame:SetScript("OnLeave", function(self)
	NITAltsDragFrame.tooltip:Hide();
end)
NITAltsDragFrame.tooltip:Hide();
NITAltsDragFrame:SetScript("OnMouseDown", function(self, button)
	if (button == "LeftButton" and not self:GetParent().isMoving) then
		self:GetParent().EditBox:ClearFocus();
		self:GetParent():StartMoving();
		self:GetParent().isMoving = true;
		--self:GetParent():SetUserPlaced(false);
	end
end)
NITAltsDragFrame:SetScript("OnMouseUp", function(self, button)
	if (button == "LeftButton" and self:GetParent().isMoving) then
		self:GetParent():StopMovingOrSizing();
		self:GetParent().isMoving = false;
	end
end)
NITAltsDragFrame:SetScript("OnHide", function(self)
	if (self:GetParent().isMoving) then
		self:GetParent():StopMovingOrSizing();
		self:GetParent().isMoving = false;
	end
end)

--Top right X close button.
local NITAltsFrameClose = CreateFrame("Button", "NITAltsFrameClose", NITAltsFrame, "UIPanelCloseButton");
--NITAltsFrameClose:SetPoint("TOPRIGHT", -5, 8.6);
--NITAltsFrameClose:SetWidth(31);
--NITAltsFrameClose:SetHeight(31);
NITAltsFrameClose:SetPoint("TOPRIGHT", -12, 3.75);
NITAltsFrameClose:SetWidth(20);
NITAltsFrameClose:SetHeight(20);
NITAltsFrameClose:SetScript("OnClick", function(self, arg)
	NITAltsFrame:Hide();
end)
--Adjust the X texture so it fits the entire frame and remove the empty clickable space around the close button.
--Big thanks to Meorawr for this.
NITAltsFrameClose:GetNormalTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITAltsFrameClose:GetHighlightTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITAltsFrameClose:GetPushedTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);
NITAltsFrameClose:GetDisabledTexture():SetTexCoord(0.1875, 0.8125, 0.1875, 0.8125);

function NIT:createAltsFrameCheckbox()
	if (NIT.altsFrameCheckbox) then
		return;
	end
	NIT.altsFrameCheckbox = CreateFrame("CheckButton", "NITAltsFrameCheckbox", NITAltsFrame.EditBox, "ChatConfigCheckButtonTemplate");
	NIT.altsFrameCheckbox:SetPoint("TOPLEFT", 5, -5);
	--So strange the way to set text is to append Text to the global frame name.
	NITAltsFrameCheckboxText:SetText(L["restedOnlyText"]);
	NIT.altsFrameCheckbox.tooltip = L["restedOnlyTextTooltip"];
	NIT.altsFrameCheckbox:SetFrameStrata("HIGH");
	NIT.altsFrameCheckbox:SetFrameLevel(9);
	NIT.altsFrameCheckbox:SetWidth(24);
	NIT.altsFrameCheckbox:SetHeight(24);
	NIT.altsFrameCheckbox:SetChecked(NIT.db.global.restedCharsOnly);
	NIT.altsFrameCheckbox:SetScript("OnClick", function()
		local value = NIT.altsFrameCheckbox:GetChecked();
		NIT.db.global.restedCharsOnly = value;
		NIT:recalcAltsLineFrames();
		--Refresh the config page.
		NIT.acr:NotifyChange("NovaInstanceTracker");
	end)
end

function NIT:createAltsFrameSlider()
	if (not NIT.charsMinLevelSlider) then
		NIT.charsMinLevelSlider = CreateFrame("Slider", "NITCharsMinLevelSlider", NITAltsFrame.EditBox, "OptionsSliderTemplate");
		NIT.charsMinLevelSlider:SetPoint("TOPRIGHT", -22, -11);
		NITCharsMinLevelSliderText:SetText("Min Level");
		--NIT.charsMinLevelSlider.tooltipText = "Minimum level alts to show?";
		--NIT.charsMinLevelSlider:SetFrameStrata("HIGH");
		NIT.charsMinLevelSlider:SetFrameLevel(5);
		NIT.charsMinLevelSlider:SetWidth(120);
		NIT.charsMinLevelSlider:SetHeight(12);
		NIT.charsMinLevelSlider:SetMinMaxValues(1, NIT.maxLevel);
	    NIT.charsMinLevelSlider:SetObeyStepOnDrag(true);
	    NIT.charsMinLevelSlider:SetValueStep(1);
	    NIT.charsMinLevelSlider:SetStepsPerPage(1);
		NIT.charsMinLevelSlider:SetValue(NIT.db.global.charsMinLevel);
		NITCharsMinLevelSliderLow:SetText("1");
		NITCharsMinLevelSliderHigh:SetText(NIT.maxLevel);
		NITCharsMinLevelSlider:HookScript("OnValueChanged", function(self, value)
			NIT.db.global.charsMinLevel = value;
			NIT.charsMinLevelSlider.editBox:SetText(value);
			NIT:recalcAltsLineFrames();
		end)
		--Some of this was taken from AceGUI.
		local function EditBox_OnEscapePressed(frame)
			frame:ClearFocus();
		end
		local function EditBox_OnEnterPressed(frame)
			local value = frame:GetText();
			value = tonumber(value);
			if value then
				PlaySound(856);
				NIT.db.global.charsMinLevel = value;
				NIT.charsMinLevelSlider:SetValue(value);
				frame:ClearFocus();
				NIT:recalcAltsLineFrames();
			else
				--If not a valid number reset the box.
				NIT.charsMinLevelSlider.editBox:SetText(NIT.db.global.charsMinLevel);
				frame:ClearFocus();
			end
		end
		local function EditBox_OnEnter(frame)
			frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 1);
		end
		local function EditBox_OnLeave(frame)
			frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8);
		end
		local ManualBackdrop = {
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
			tile = true, edgeSize = 1, tileSize = 5,
		};
		NIT.charsMinLevelSlider.editBox = CreateFrame("EditBox", nil, NIT.charsMinLevelSlider, NIT:addBackdrop());
		NIT.charsMinLevelSlider.editBox:SetAutoFocus(false);
		NIT.charsMinLevelSlider.editBox:SetFontObject(GameFontHighlightSmall);
		NIT.charsMinLevelSlider.editBox:SetPoint("TOP", NIT.charsMinLevelSlider, "BOTTOM");
		NIT.charsMinLevelSlider.editBox:SetHeight(14);
		NIT.charsMinLevelSlider.editBox:SetWidth(70);
		NIT.charsMinLevelSlider.editBox:SetJustifyH("CENTER");
		NIT.charsMinLevelSlider.editBox:EnableMouse(true);
		NIT.charsMinLevelSlider.editBox:SetBackdrop(ManualBackdrop);
		NIT.charsMinLevelSlider.editBox:SetBackdropColor(0, 0, 0, 0.5);
		NIT.charsMinLevelSlider.editBox:SetBackdropBorderColor(0.3, 0.3, 0.30, 0.80);
		NIT.charsMinLevelSlider.editBox:SetScript("OnEnter", EditBox_OnEnter);
		NIT.charsMinLevelSlider.editBox:SetScript("OnLeave", EditBox_OnLeave);
		NIT.charsMinLevelSlider.editBox:SetScript("OnEnterPressed", EditBox_OnEnterPressed);
		NIT.charsMinLevelSlider.editBox:SetScript("OnEscapePressed", EditBox_OnEscapePressed);
	end
end

function NIT:openAltsFrame()
	if (not NIT.altsFrameShowsAltsButton) then
		NIT:createAltsFrameCheckbox();
	end
	if (not NIT.charsMinLevelSlider) then
		NIT:createAltsFrameSlider();
	end
	NITAltsFrame.fs:SetFont(NIT.regionFont, 14);
	local header = NIT.prefixColor .. "NovaInstanceTracker v" .. version .. "|r\n"
			.. "|cffffff00Alts (Mouseover names for info)";
	NITAltsFrame.fs:SetText(header);
	NIT:createAltsLineFrames(true);
	--Quick fix to re-set the region font since the frames are created before we set region font.
	NITAltsFrame.fs:SetFont(NIT.regionFont, 14);
	if (NITAltsFrame:IsShown()) then
		NITAltsFrame:Hide();
	else
		--NITAltsFrame:SetHeight(320);
		--NITAltsFrame:SetWidth(altsFrameWidth);
		NITAltsFrame:SetHeight(NIT.db.global.charsWindowHeight);
		NITAltsFrame:SetWidth(NIT.db.global.charsWindowWidth);
		local fontSize = false;
		NITAltsFrame.EditBox:SetFont(NIT.regionFont, 14);
		NITAltsFrame.EditBox:SetWidth(NITAltsFrame:GetWidth() - 30);
		NITAltsFrame:Show();
		NIT.charsMinLevelSlider.editBox:SetText(NIT.db.global.charsMinLevel);
		--Changing scroll position requires a slight delay.
		--Second delay is a backup.
		C_Timer.After(0.05, function()
			NITAltsFrame:SetVerticalScroll(0);
		end)
		C_Timer.After(0.3, function()
			NITAltsFrame:SetVerticalScroll(0);
		end)
		--So interface options and this frame will open on top of each other.
		if (InterfaceOptionsFrame:IsShown()) then
			NITAltsFrame:SetFrameStrata("DIALOG");
		else
			NITAltsFrame:SetFrameStrata("HIGH");
		end
		NIT:recalcAltsLineFrames();
	end
end

local totalAltLines = 0;
function NIT:createAltsLineFrames(skipRecalc)
	local count = 0;
	local new;
	--Create enough line frames for each realm + character.
	for k, v in NIT:pairsByKeys(NIT.db.global) do --Iterate realms.
		if (type(v) == "table" and k ~= "minimapIcon" and k ~= "data") then
			count = count + 1;
			if (not _G[k .. "NITAltsLine"]) then
				NIT:createAltsLineFrame(count, v, count);
				new = true;
			end
			if (v.myChars) then
				for k, v in NIT:pairsByKeys(v.myChars) do --Iterate characters.
					count = count + 1;
					if (not _G[k .. "NITAltsLine"]) then
						NIT:createAltsLineFrame(count, v, count);
						new = true;
					end
				end
			end
		end
	end
	if (count > totalAltLines) then
		totalAltLines = count;
	end
	if (new and not skipRecalc) then
		NIT:recalcAltsLineFrames();
	end
end

function NIT:createAltsLineFrame(type, data, count)
	if (not _G[type .. "NITAltsLine"]) then
		local obj = CreateFrame("Frame", type .. "NITAltsLine", NITAltsFrame.EditBox);
		obj.name = data.name;
		obj.count = count;
		local bg = obj:CreateTexture(nil, "HIGH");
		bg:SetAllPoints(obj);
		obj.texture = bg;
		obj.fs = obj:CreateFontString(type .. "NITAltsLineFS", "ARTWORK");
		obj.fs:SetPoint("LEFT", 0, 0);
		obj.fs:SetFont(NIT.regionFont, 14);
		--They don't quite line up properly without justify on top of set point left.
		obj.fs:SetJustifyH("LEFT");
		obj.tooltip = CreateFrame("Frame", type .. "NITAltsLineTooltip", NITAltsFrame, "TooltipBorderedFrameTemplate");
		obj.tooltip:SetPoint("CENTER", obj, "CENTER", 0, -46);
		obj.tooltip:SetFrameStrata("HIGH");
		obj.tooltip:SetFrameLevel(4);
		obj.tooltip.fs = obj.tooltip:CreateFontString(type .. "NITAltsLineTooltipFS", "ARTWORK");
		obj.tooltip.fs:SetPoint("CENTER", 0, 0);
		obj.tooltip.fs:SetFont(NIT.regionFont, 13);
		obj.tooltip.fs:SetJustifyH("LEFT");
		obj.tooltip.fs:SetText("|CffDEDE42Error " .. count);
		obj.tooltip.fsCalc = obj.tooltip:CreateFontString(type .. "NITAltsLineTooltipFS", "ARTWORK");
		obj.tooltip.fsCalc:SetFont(NIT.regionFont, 13);
		obj.tooltip:SetWidth(obj.tooltip.fs:GetStringWidth() + 18);
		obj.tooltip:SetHeight(obj.tooltip.fs:GetStringHeight() + 12);
		obj.tooltip.updateTime = GetServerTime();
		obj.tooltip:SetScript("OnUpdate", function(self)
			--Keep our custom tooltip at the mouse when it moves.
			local scale, x, y = obj.tooltip:GetEffectiveScale(), GetCursorPosition();
			obj.tooltip:SetPoint("RIGHT", nil, "BOTTOMLEFT", (x / scale) - 2, y / scale);
			if (GetServerTime() - obj.tooltip.updateTime > 0) then
				obj.tooltip.updateTime = GetServerTime();
				NIT:recalcAltsLineFramesTooltip(obj);
			end
		end)
		obj:SetScript("OnEnter", function(self)
			obj.tooltip:Show();
			NIT:recalcAltsLineFramesTooltip(obj);
			local scale, x, y = obj.tooltip:GetEffectiveScale(), GetCursorPosition();
			obj.tooltip:SetPoint("CENTER", nil, "BOTTOMLEFT", x / scale, y / scale);
		end)
		obj:SetScript("OnLeave", function(self)
			obj.tooltip:Hide();
		end)
		obj.tooltip:Hide();
		--obj:SetScript("OnMouseDown", function(self)
			--Maybe add a mouse event here later.
		--end)
		
		obj.removeButton = CreateFrame("Button", type .. "NITAltsLineRB", obj, "UIPanelButtonTemplate");
		obj.removeButton:SetPoint("LEFT", obj, "RIGHT", 34, 0);
		obj.removeButton:SetWidth(13);
		obj.removeButton:SetHeight(13);
		--obj.removeButton:SetText("X");
		obj.removeButton:SetNormalFontObject("GameFontNormalSmall");
		--obj.removeButton:SetScript("OnClick", function(self, arg)

		--end)
		obj.removeButton:SetNormalTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_7");
		obj.removeButton.tooltip = CreateFrame("Frame", type .. "NITAltsLineTooltipRB", NITAltsFrame, "TooltipBorderedFrameTemplate");
		obj.removeButton.tooltip:SetPoint("RIGHT", obj.removeButton, "LEFT", -5, 0);
		obj.removeButton.tooltip:SetFrameStrata("HIGH");
		obj.removeButton.tooltip:SetFrameLevel(3);
		obj.removeButton.tooltip.fs = obj.removeButton.tooltip:CreateFontString(type .. "NITAltsLineTooltipRBFS", "ARTWORK");
		obj.removeButton.tooltip.fs:SetPoint("CENTER", -0, 0);
		obj.removeButton.tooltip.fs:SetFont(NIT.regionFont, 13);
		obj.removeButton.tooltip.fs:SetJustifyH("LEFT");
		obj.removeButton.tooltip.fs:SetText("|CffDEDE42" .. L["deleteEntry"] .. " " .. count);
		obj.removeButton.tooltip:SetWidth(obj.removeButton.tooltip.fs:GetStringWidth() + 18);
		obj.removeButton.tooltip:SetHeight(obj.removeButton.tooltip.fs:GetStringHeight() + 12);
		obj.removeButton:SetScript("OnEnter", function(self)
			obj.removeButton.tooltip:Show();
		end)
		obj.removeButton:SetScript("OnLeave", function(self)
			obj.removeButton.tooltip:Hide();
		end)
		obj.removeButton.tooltip:Hide();
	end
end

function NIT:recalcAltsLineFrames()
	if (not NITAltsFrame:IsShown()) then
		return;
	end
	local offset, count = 45, 0;
	local framesUsed = {};
	local foundAnyChars;
	local color1, color2 = "|cFFFFAE42", "|cFF9CD6DE";
	for k, v in NIT:pairsByKeys(NIT.db.global) do --Iterate realms.
		local msg = "";
		if (type(v) == "table" and k ~= "minimapIcon" and k ~= "data") then
			local coloredFaction = "";
			local realmString = "|cff00ff00[" .. k .. "]|r";
			local realmName = k;
			local printedRealm;
			local realmObj;
			if (v.myChars) then
				local realmGold = 0;
				local realmGoldData = {};
				realmGoldData.realm = realmName;
				for k, v in pairs(v.myChars) do
					if (v.gold) then
						realmGold = realmGold + v.gold;
					end
				end
				local foundRested;
				for k, v in NIT:pairsByKeys(v.myChars) do --Iterate characters.
					--Add the key (playername) to the data passed to the tooltip and delete button.
					v.playerName = k;
					realmGoldData[k] = {
						gold = (v.gold or 0),
						classEnglish = v.classEnglish,
					}
					foundRested = nil;
					local _, _, _, classColor = GetClassColor(v.classEnglish);
					--Safeguard for weakauras/addons that like to overwrite and break the GetClassColor() function.
					if (not classColor and v.classEnglish == "SHAMAN") then
						classColor = "ff0070dd";
					elseif (not classColor) then
						classColor = "ffffffff";
					end
					local msg = "  -|c" .. classColor .. k .. "|r";
					local online;
					local stateString = "";
					local onlineString = "";
					if (k == UnitName("player") and realmName == NIT.realm) then
						online = true;
						onlineString = " |cFF00C800(" .. L["online"] .. ")|r";
					end
					if (v.level == NIT.maxLevel) then
						stateString = "(" .. L["maximum"] .. " " .. string.lower(L["level"]) .. ")";
						msg = msg .. " " .. color1 .. "" .. L["level"] .. ":|r " .. color2 .. v.level .. onlineString .. "\n";
					elseif (v.time and v.time > 0 and v.currentXP and v.maxXP) then
						local timeOffline = GetServerTime() - v.time;
						local percent, bubbles, xp = NIT:calcRested(v.currentXP, v.maxXP, timeOffline, v.resting, v.restedXP, online);
						--if (percent > 0) then
							local percentString = percent .. "%";
							local stateString = "(" .. L["rested"] .. ")"
							if (percent == 150) then
								percentString = percentString .. " (" .. L["maximum"] .. ")";
							end
							local xpString = color2 .. NIT:commaValue(v.currentXP) .. color1 .. "/" .. color2 .. NIT:commaValue(v.maxXP);
							msg = msg .. " " .. color1 .. L["level"] .. ":|r " .. color2 .. v.level .. "|r " .. color1
									.. L["experienceShort"] .. ":|r " .. color2 .. xpString .. " " .. color1 .. L["rested"] .. ":|r "
									.. color2 .. percentString .. onlineString .. "\n";
						--end
						foundRested = true;
					end
					if ((not NIT.db.global.restedCharsOnly or foundRested)
						and (v.level and v.level >= NIT.db.global.charsMinLevel)) then
						--Add realm line if we found chars for this realm and have not printed realm line yet.
						if (not printedRealm) then
							count = count + 1;
							printedRealm = true;
							framesUsed[count] = true;
							_G[count .. "NITAltsLine"]:Show();
							_G[count .. "NITAltsLine"]:ClearAllPoints();
							_G[count .. "NITAltsLine"]:SetPoint("LEFT", NITAltsFrame.EditBox, "TOPLEFT", 3, -offset);
							offset = offset + 14;
							_G[count .. "NITAltsLine"].fs:SetPoint("LEFT", 0, 0);
							--_G[count .. "NITAltsLine"].fs:SetText(realmString .. " |cFF9CD6DE"
							--		..  GetCoinTextureString(realmGold, 11) .. "|r");
							_G[count .. "NITAltsLine"].fs:SetText(realmString);
							--Leave enough room on the right of frame to not overlap the scroll bar (-20) and remove button (-20).
							_G[count .. "NITAltsLine"]:SetWidth(NITAltsFrame:GetWidth() - 120);
							_G[count .. "NITAltsLine"]:SetHeight(_G[count .. "NITAltsLine"].fs:GetHeight());
							--_G[count .. "NITAltsLine"].removeButton.count = count;
							_G[count .. "NITAltsLine"].removeButton:Hide();
							_G[count .. "NITAltsLine"].removeButton.tooltip.fs:SetText("Disabled");
							_G[count .. "NITAltsLine"].removeButton.tooltip:SetWidth(_G[count .. "NITAltsLine"].removeButton.tooltip.fs:GetStringWidth() + 18);
							_G[count .. "NITAltsLine"].removeButton.tooltip:SetHeight(_G[count .. "NITAltsLine"].removeButton.tooltip.fs:GetStringHeight() + 12);
							_G[count .. "NITAltsLine"].data = nil;
							_G[count .. "NITAltsLine"].type = "realm";
							realmObj = _G[count .. "NITAltsLine"];
						end
						--Add the char line.
						count = count + 1;
						framesUsed[count] = true;
						_G[count .. "NITAltsLine"]:Show();
						_G[count .. "NITAltsLine"]:ClearAllPoints();
						_G[count .. "NITAltsLine"]:SetPoint("LEFT", NITAltsFrame.EditBox, "TOPLEFT", 3, -offset);
						offset = offset + 14;
						_G[count .. "NITAltsLine"].fs:SetPoint("LEFT", 0, 0);
						_G[count .. "NITAltsLine"].fs:SetText(msg);
						--Leave enough room on the right of frame to not overlap the scroll bar (-20) and remove button (-20).
						_G[count .. "NITAltsLine"]:SetWidth(NITAltsFrame:GetWidth() - 120);
						_G[count .. "NITAltsLine"]:SetHeight(_G[count .. "NITAltsLine"].fs:GetHeight());
						--_G[count .. "NITAltsLine"].removeButton.count = count;
						_G[count .. "NITAltsLine"].removeButton.tooltip.fs:SetText("|CffDEDE42Delete " .. k);
						_G[count .. "NITAltsLine"].removeButton:Show();
						_G[count .. "NITAltsLine"].removeButton.tooltip:SetWidth(_G[count .. "NITAltsLine"].removeButton.tooltip.fs:GetStringWidth() + 18);
						_G[count .. "NITAltsLine"].removeButton.tooltip:SetHeight(_G[count .. "NITAltsLine"].removeButton.tooltip.fs:GetStringHeight() + 12);
						_G[count .. "NITAltsLine"].data = v;
						_G[count .. "NITAltsLine"].type = "char";
						_G[count .. "NITAltsLine"].removeButton:SetScript("OnClick", function(self, arg)
							--Open delete confirmation box to delete table id (k), but display it as matching log number (count).
							NIT:openDeleteCharConfirmFrame(realmName, k);
						end)
						foundAnyChars = true;
					end
				end
				if (realmObj) then
					realmObj.data = realmGoldData;
				end
			end
		end
	end
	if (not foundAnyChars) then
		NIT:hideAllAltLineFrames()
		NITAltsFrame.EditBox:Insert("\n\n\n\n|cffffff00No alts found.");
	else
		NITAltsFrame.EditBox:SetText("");
	end
	--Hide any no longer is use lines frames no longer in use.
	for i = 1, totalAltLines do
		if (_G[i .. "NITAltsLine"] and not framesUsed[i]) then
			_G[i .. "NITAltsLine"]:Hide();
			_G[i .. "NITAltsLine"].data = nil;
		end
	end
end

function NIT:hideAllAltLineFrames()
	for i = 1, totalAltLines do
		if (_G[i .. "NITAltsLine"]) then
			_G[i .. "NITAltsLine"]:Hide();
		end
	end
end

function NIT:recalcAltsLineFramesTooltip(obj)
	local data = obj.data;
	--NIT:debug(data)
	if (data) then
		if (obj.type == "realm") then
			local text = "|cFFFFAE42" .. L["realmGold"] .. "|r |cff00ff00[" .. data.realm .. "]|r";
			local total = 0;
			for k, v in NIT:pairsByKeys(data) do
				if (v.gold) then
					local _, _, _, classColor = GetClassColor(v.classEnglish);
					--Safeguard for weakauras/addons that like to overwrite and break the GetClassColor() function.
					if (not classColor and v.classEnglish == "SHAMAN") then
						classColor = "ff0070dd";
					elseif (not classColor) then
						classColor = "ffffffff";
					end
					total = total + v.gold;
					local line = "\n|c" .. classColor .. k .. "|r";
					obj.tooltip.fsCalc:SetText(line);
					--Trim string if multiple columns.
					while obj.tooltip.fsCalc:GetWidth() > 80 do
						line = string.sub(line, 1, -2);
						obj.tooltip.fsCalc:SetText(line);
					end
					obj.tooltip.fsCalc:SetText(line);
					while obj.tooltip.fsCalc:GetWidth() < 90 do
						line = line .. " ";
						obj.tooltip.fsCalc:SetText(line);
					end
					text = text .. line .. " " .. GetCoinTextureString(v.gold, 10);
					--text = text .. "\n|c" .. classColor .. k .. "|r " .. GetCoinTextureString(v.gold, 10);
				end
			end
			local line = "\n\n|cFFFFAE42" .. L["total"] .. ": |r";
			obj.tooltip.fsCalc:SetText(line);
			while obj.tooltip.fsCalc:GetWidth() < 90 do
				line = line .. " ";
				obj.tooltip.fsCalc:SetText(line);
			end
			line = line .. " " .. GetCoinTextureString(total, 10);
			obj.tooltip.fs:SetText(text .. line);
		else
			local color1, color2 = "|cFFFFAE42", "|cFF9CD6DE";
			local player = data.playerName;
			local _, _, _, classColorHex = GetClassColor(data.classEnglish);
			--Safeguard for weakauras/addons that like to overwrite and break the GetClassColor() function.
			if (not classColorHex and data.classEnglish == "SHAMAN") then
				classColorHex = "ff0070dd";
			elseif (not classColorHex) then
				classColorHex = "ffffffff";
			end
			local online;
			if (player == UnitName("player")) then
				online = true;
			end
			local timeOffline;
			if (data.time) then
				timeOffline = GetServerTime() - data.time;
			end
			local text = "";
			--Some of the data exists checks are here to be compatible with older versions that didn't record some data.
			if (data.realm) then
				text = "|c" .. classColorHex .. player .. "|r |cff00ff00[" .. data.realm .. "]|r";
			else
				text = "|c" .. classColorHex .. player .. "|r";
			end
			text = text .. "\n" .. color1 .. L["guild"] .. ":|r " .. color2 .. (data.guild or "none") .. "|r";
			text = text .. "\n" .. color1 .. L["level"] .. ":|r " .. color2 .. data.level .. "|r";
			if (timeOffline and data.level < NIT.maxLevel) then
				local percent, bubbles, xp = NIT:calcRested(data.currentXP, data.maxXP, timeOffline, data.resting, data.restedXP, online);
				if (data.currentXP) then
					local percentXP;
					if (data.currentXP == 0 and data.maxXP == 0) then
						percentXP = 0;
					else
						percentXP = (data.currentXP / data.maxXP) * 100;
					end
					text = text .. "\n" .. color1 .. L["experienceShort"] .. ":|r " .. color2 .. NIT:commaValue(data.currentXP) .. "|r"
							.. color1 .. "/|r" .. color2 .. NIT:commaValue(data.maxXP) .. " (" .. NIT:round(percentXP) .. "%)|r";
				end
				if (data.restedXP) then
					local percentString = percent .. "\%";
					--local stateString = "(|cFFFF2222Not Resting" .. color2 .. ")|r";
					local stateString = "(" .. L["notResting"] .. ")|r";
					if (data.resting) then
						stateString = "(|cFF00C800" .. L["resting"] .. color2 .. ")|r";
					end
					local percentMax = "";
					if (percent == 150) then
						percentMax = " (Max)";
					end
					text = text .. "\n" .. color1 .. L["rested"] .. ":|r " .. color2 .. percentString .. " ("
							.. NIT:commaValue(data.restedXP) .. string.lower(L["experienceShort"]) .. ")" .. percentMax .. "|r";
					text = text .. "\n" .. color1 .. L["restedBubbles"] .. ":|r " .. color2 .. bubbles .. "|r";
					text = text .. "\n" .. color1 .. L["restedState"] .. ":|r " .. color2 .. stateString .. "|r";
				end
			end
			if (data.freeBagSlots and data.totalBagSlots) then
				local displayFreeSlots = color2 .. data.freeBagSlots .. "|r";
				if (data.freeBagSlots < (data.totalBagSlots * 0.10)) then
					--Display in red when less than 10% of bag space left.
					displayFreeSlots = "|cffff0000" .. data.freeBagSlots .. "|r";
				end
				text = text .. "\n" .. color1 .. L["bagSlots"] .. ":|r " .. displayFreeSlots .. color1 .. "/|r"
						.. color2 .. data.totalBagSlots .. "|r";
			end
			if (data.gold) then
				text = text .. "\n" .. color1 .. L["Gold"] .. ":|r " .. color2 .. GetCoinTextureString(data.gold, 10) .. "|r";
			end
			local durabilityAverage = data.durabilityAverage or 100;
			local displayDurability;
			if (durabilityAverage < 10) then
				displayDurability = "|cffff0000" .. NIT:round(durabilityAverage) .. "%|r";
			elseif (durabilityAverage < 30) then
				displayDurability = "|cffffa500" .. NIT:round(durabilityAverage) .. "%|r";
			else
				displayDurability = color2 .. NIT:round(durabilityAverage) .. "%|r";
			end
			text = text .. "\n" .. color1 .. L["durability"] .. ": " .. displayDurability .. "|r";
			
			if (data.classEnglish == "PRIEST" or data.classEnglish == "MAGE" or data.classEnglish == "DRUID"
					or data.classEnglish == "WARLOCK" or data.classEnglish == "SHAMAN" or data.classEnglish == "PALADIN"
							or data.classEnglish == "HUNTER") then
				local foundItems;
				local itemString = "\n\n|cFFFFFF00" .. L["items"] .. "|r";
				if (data.classEnglish == "HUNTER" and data.ammo) then
					local ammoTypeString = "";
					if (data.ammoType) then
						local itemName, _, itemRarity, _, _, _, _, _, _, itemTexture = GetItemInfo(data.ammoType);
		    			if (itemName) then
		    				local ammoTexture = "|T" .. itemTexture .. ":12:12:0:0|t";
							ammoTypeString = " (" .. itemName .. " " .. ammoTexture .. ")";
						end
					end
					itemString = itemString .. "\n  |c" .. classColorHex .. L["ammunition"] .. ":|r " .. color2 .. (data.ammo or 0)
							.. ammoTypeString .. "|r";
					foundItems = true;
				end
				if (_G["NIT"]["trackItems" .. data.classEnglish]) then
					for k, v in ipairs(_G["NIT"]["trackItems" .. data.classEnglish]) do
						if (not v.minLvl or v.minLvl < data.level) then
							local texture = "";
							if (v.texture) then
								texture = "|T" .. v.texture .. ":12:12:0:0|t ";
							end
							local itemName = v.name;
							--Try and get localization for the item name.
							local itemName = GetItemInfo(v.id);
							if (not itemName) then
								itemName = v.name;
							end
							itemString = itemString .. "\n  " .. texture .. "|c" .. classColorHex .. itemName .. ":|r "
									.. color2 .. (data[v.id] or 0) .. "|r";
							foundItems = true;
						end
					end
				end
				if (foundItems) then
					text = text .. itemString;
				end
			end
			if (data.classEnglish == "HUNTER") then
				local happinessTexture = "";
				if (data.petHappiness and data.petHappiness == 1) then
					happinessTexture = "|TInterface\\PetPaperDollFrame\\UI-PetHappiness:13:13:0:0:128:64:48:72:0:23|t";
					--SetTexCoord(0.375, 0.5625, 0, 0.359375);
				elseif (data.petHappiness and data.petHappiness == 2) then
					--happinessTexture = "|TInterface\\PetPaperDollFrame\\UI-PetHappiness:13:13:0:0:128:64:0.1875:0.375:0:0.359375|t";
					happinessTexture = "|TInterface\\PetPaperDollFrame\\UI-PetHappiness:13:13:0:0:128:64:24:46.5:0:23|t";
					--SetTexCoord(0.1875, 0.375, 0, 0.359375);
				elseif (data.petHappiness and data.petHappiness == 3) then
					--happinessTexture = "|TInterface\\PetPaperDollFrame\\UI-PetHappiness:13:13:0:0:0:128:64:0.1875:0:0.359375|t";
					happinessTexture = "|TInterface\\PetPaperDollFrame\\UI-PetHappiness:13:13:0:0:128:64:0:24:0:23|t";
					--SetTexCoord(0, 0.1875, 0, 0.359375);
				end
				text = text .. "\n\n|cFFFFFF00" .. L["currentPet"] .. "|r";
				if (data.isPetDead and data.hasPet) then
					text = text .. "\n" .. color1 .. "  " .. L["petStatus"] .. ":|r (|cFFFF2222Dead" .. color2 .. ")|r";
				elseif (data.hasPet) then
					text = text .. "\n" .. color1 .. "  " .. L["petStatus"] .. ":|r (|cFF00C800Alive" .. color2 .. ")|r";
				else
					text = text .. "\n" .. color1 .. "  " .. L["petStatus"] .. ":|r " .. color2 .. "(" .. L["noPetSummoned"] .. ")|r";
					text = text ..	"\n  |cFF989898" .. L["lastSeenPetDetails"] .. ":|r";
				end
				if (data.petName) then
					text = text .. "\n" .. color1 .. "  " .. L["name"] .. ":|r " .. color2 .. data.petName .. "|r";
				end
				if (data.petLevel) then
					text = text .. "\n" .. color1 .. "  " .. L["level"] .. ":|r " .. color2 .. data.petLevel .. "|r";
				end
				if (data.petFamily) then
					text = text .. "\n" .. color1 .. "  " .. L["family"] .. ":|r " .. color2 .. data.petFamily .. "|r";
				end
				if (data.petHappiness) then
					text = text .. "\n" .. color1 .. "  " .. L["happiness"] .. ":|r " .. happinessTexture .. "|r";
				end
				if (data.petLoyaltyRate) then
					text = text .. "\n" .. color1 .. "  " .. L["loyaltyRate"] .. ":|r " .. color2 .. data.petLoyaltyRate .. "|r";
				end
				if (data.loyaltyString) then
					text = text .. "\n  " .. color1 .. data.loyaltyString;
				end
				if (data.petCurrentXP and data.petMaxXP) then
					local percentXP;
					if (data.petCurrentXP == 0 and data.petMaxXP == 0) then
						percentXP = 0;
					else
						percentXP = (data.petCurrentXP / data.petMaxXP) * 100;
					end
					text = text .. "\n" .. color1 .. "  " .. L["petExperience"] .. ":|r " .. color2 .. data.petCurrentXP .. "|r"
							.. color1 .. "/|r" .. color2 .. data.petMaxXP .. " (" .. NIT:round(percentXP) .. "%)|r";
				end
				if (data.totalPetPoints and data.spentPetPoints) then
					local unspentPetPoints = data.totalPetPoints - data.spentPetPoints;
					if (unspentPetPoints < 0) then
						unspentPetPoints = 0;
					end
					text = text .. "\n" .. color1 .. "  " .. L["unspentTrainingPoints"] .. ":|r " .. color2 .. unspentPetPoints .. "|r";
				end
			end
			text = text .. "\n\n|cFFFFFF00" .. L["professions"] .. "|r";
			--[[local cooldowns = {};
			if (data.cooldowns and next(data.cooldowns)) then
				for k, v in pairs(data.cooldowns) do
					cooldowns[k] = v;
				end
			end]]
			local foundprofs;
			if (data.prof1 and data.prof1 ~= "none") then
				text = text .. "\n  " .. color1 .. data.prof1 .. ":|r " .. color2 .. data.profSkill1 .. "|r"
						.. color1 .. "/|r" .. color2 .. data.profSkillMax1 .. "|r";
				foundprofs = true;
				--[[for k, v in pairs(cooldowns) do
					if (v.prof == data.prof11) then
						text = text .. "\n    " .. color1 .. k .. ": " .. color2 .. v.time;
						cooldowns[k] = nil;
					end
				end]]
			end
			if (data.prof2 and data.prof2 ~= "none") then
				text = text .. "\n  " .. color1 .. data.prof2 .. ":|r " .. color2 .. data.profSkill2 .. "|r"
						.. color1 .. "/|r" .. color2 .. data.profSkillMax2 .. "|r";
				foundprofs = true;
				--[[for k, v in pairs(cooldowns) do
					if (v.prof == data.prof2) then
						text = text .. "\n    " .. color1 .. k .. ": " .. color2 .. v.time;
						cooldowns[k] = nil;
					end
				end]]
			end
			if (data.firstaidSkill and data.firstaidSkill > 0) then
				text = text .. "\n  " .. color1 .. PROFESSIONS_FIRST_AID .. ":|r " .. color2 .. data.firstaidSkill .. "|r"
						.. color1 .. "/|r" .. color2 .. data.firstaidSkillMax;
				foundprofs = true;
			end
			if (data.fishingSkill and data.fishingSkill > 0) then
				text = text .. "\n  " .. color1 .. PROFESSIONS_FISHING .. ":|r " .. color2 .. data.fishingSkill .. "|r"
						.. color1 .. "/|r" .. color2 .. data.fishingSkillMax;
				foundprofs = true;
			end
			if (data.cookingSkill and data.cookingSkill > 0) then
				text = text .. "\n  " .. color1 .. PROFESSIONS_COOKING .. ":|r " .. color2 .. data.cookingSkill .. "|r"
						.. color1 .. "/|r" .. color2 .. data.cookingSkillMax;
				foundprofs = true;
			end
			if (not foundprofs) then
				text = text .. "\n  " .. color2 .. L["noProfessions"] .. "|r";
			end
			local foundCooldowns;
			local cooldownText = "\n\n|cFFFFFF00" .. L["cooldowns"] .. "|r";
			if (data.cooldowns and next(data.cooldowns)) then
				for k, v in pairs(data.cooldowns) do
					if (v.time > GetServerTime()) then
						local timeString = "(" .. NIT:getTimeString(v.time - GetServerTime(), true, NIT.db.global.timeStringType) .. " " .. L["left"] .. ")";
						cooldownText = cooldownText .. "\n    " .. color1 .. k .. ":|r " .. color2 .. timeString .. "|r";
						foundCooldowns = true;
					elseif (GetServerTime() - v.time < 1209600) then
						--Display cooldowns are ready only for 2 weeks after last used so we don't have to worrie about dropped professions.
						cooldownText = cooldownText .. "\n    " .. color1 .. k .. ":|r " .. color2 .. L["ready"] .. "|r";
						foundCooldowns = true;
					end
				end
			end
			if (foundCooldowns) then
				text = text .. cooldownText;
			end
			local pvpString = "";
			if (data.honor and data.honor > 0) then
				local texture;
				if (NIT.faction == "Horde") then
					texture = "|TInterface\\TargetingFrame\\UI-PVP-Horde:12:12:-1:0:64:64:7:36:1:36|t"
				else
					texture = "|TInterface\\TargetingFrame\\UI-PVP-Alliance:12:12:0:0:64:64:7:36:1:36|t";
				end
				pvpString = pvpString .. "\n  " .. texture .. " " .. color1 .. L["Honor"] .. ":|r " .. color2 .. NIT:commaValue(data.honor) .. "|r";
			end
			if (data.arenaPoints and data.arenaPoints > 0) then
				local texture = "|T4006481:12:12|t";
				pvpString = pvpString .. "\n  " .. texture .. " " .. color1 .. L["Arena Points"] .. ":|r " .. color2 .. NIT:commaValue(data.arenaPoints) .. "|r";
			end
			if (data.marks and next(data.marks)) then
				for k, v in NIT:pairsByKeys(data.marks) do
					if (v > 0) then
						local texture = NIT.bgMarks[k].icon;
						if (texture) then
							texture = "|T" .. texture .. ":12:12:0:0|t";
						end
						--Try and get localization for the item name.
						local itemName = GetItemInfo(k);
						if (not itemName) then
							itemName = NIT.bgMarks[k].name;
						end
						itemName = string.gsub(itemName, " of Honor", "");
						pvpString = pvpString .. "\n  " .. texture .. " " .. color1 .. itemName .. ":|r "
								.. color2 .. v .. "|r";
					end
				end
			end
			if (pvpString ~= "") then
				text = text .. "\n\n|cFFFFFF00" .. L["PvP"] .. "|r";
				text = text .. pvpString;
			end
			if (not NIT.isTBC) then
				local pvpRank = "\n\n|cFFFFFF00" .. L["pvp"] .. " " .. L["rank"] .. "|r";
				if (data.pvpRankName and data.pvpRankNumber and data.pvpRankPercent) then
					local percent = (string.match(tostring(data.pvpRankPercent), "%.(%d+)") or 0);
					percent = string.sub(percent, 1, 2);
					pvpRank = pvpRank .. "\n  " .. color1 .. data.pvpRankName .. " (" .. L["rank"] .. " " .. data.pvpRankNumber .. ") " .. percent .. "%|r";
					text = text .. pvpRank;
					if (data.pvpRankNameLastWeek and data.pvpRankNumberLastWeek and data.pvpRankPercentLastWeek) then
						local percent = (string.match(tostring(data.pvpRankPercentLastWeek), "%.(%d+)") or 0);
						percent = string.sub(percent, 1, 2);
						pvpRank = "\n  |cFFA1A1A1(" .. L["lastWeek"] .. ": " .. L["rank"] .. " " .. data.pvpRankNumberLastWeek .. " " .. percent .. "%)|r";
						text = text .. pvpRank;
					end
				end
			end
			local attunements = "\n\n|cFFFFFF00" .. L["attunements"] .. "|r";
			local foundAttune;
			if (data.mcAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Molten Core|r";
				foundAttune = true;
			end
			if (data.onyAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Onyxia's Lair|r";
				foundAttune = true;
			end
			if (data.bwlAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Blackwing Lair|r";
				foundAttune = true;
			end
			if (data.naxxAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Naxxramas|r";
				foundAttune = true;
			end
			if (data.karaAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Karazhan|r";
				foundAttune = true;
			end
			if (data.shatteredHallsAttune) then
				attunements = attunements .. "\n  " .. color1 .. "The Shattered Halls|r"; --Key.
				foundAttune = true;
			end
			if (data.serpentshrineAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Serpentshrine Cavern|r";
				foundAttune = true;
			end
			if (data.arcatrazAttune) then
				attunements = attunements .. "\n  " .. color1 .. "The Arcatraz|r"; --Key.
				foundAttune = true;
			end
			if (data.blackMorassAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Black Morass|r";
				foundAttune = true;
			end
			if (data.hyjalAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Battle of Mount Hyjal|r";
				foundAttune = true;
			end
			if (data.blackTempleAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Black Temple|r";
				foundAttune = true;
			end
			if (data.hellfireCitadelAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Hellfire Citadel|r"; --Key.
				foundAttune = true;
			end
			if (data.coilfangAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Coilfang Reservoir|r"; --Key.
				foundAttune = true;
			end
			if (data.shadowLabAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Shadow Labyrinth|r"; --Key.
				foundAttune = true;
			end
			if (data.auchindounAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Auchindoun|r"; --Key.
				foundAttune = true;
			end
			if (data.tempestKeepAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Tempest Keep|r"; --Key
				foundAttune = true;
			end
			if (data.cavernAttune) then
				attunements = attunements .. "\n  " .. color1 .. "Caverns of Time|r"; --Key.
				foundAttune = true;
			end
			if (foundAttune) then
				text = text .. attunements;
			end
			text = text .. "\n\n|cFFFFFF00" .. L["currentRaidLockouts"] .. "|r";
			local foundLockout;
			local lockoutString = "";
			if (data.savedInstances and next(data.savedInstances)) then
				for k, v in pairs(data.savedInstances) do
					if (not tonumber(k)) then
						--Remove any non-numbered entries such as "NOT SAVED" from other addons that were recorded in older versions.
						data.savedInstances[k] = nil;
					end
				end
				for k, v in NIT:pairsByKeys(data.savedInstances) do
					if (v.locked and v.resetTime and v.resetTime > GetServerTime()) then
						local timeString = "(" .. NIT:getTimeString(v.resetTime - GetServerTime(), true, NIT.db.global.timeStringType) .. " " .. L["left"] .. ")";
						lockoutString = lockoutString .. "\n  " .. color1 .. v.name .. "|r " .. color2 .. timeString .. "|r";
						foundLockout = true;
					end
				end
			end
			if (not foundLockout) then
				text = text .. "\n  " .. color2 .. L["none"] .. "|r";
			else
				text = text .. lockoutString;
			end
			obj.tooltip.fs:SetText(text);
		end
	else
		obj.tooltip.fs:SetText("|CffDEDE42No data found for this character.|r");
	end
	obj.tooltip:SetWidth(obj.tooltip.fs:GetStringWidth() + 18);
	obj.tooltip:SetHeight(obj.tooltip.fs:GetStringHeight() + 12);
end

local NITCharsFrameDeleteConfirm = CreateFrame("ScrollFrame", "NITCharsFrameDC", UIParent, NIT:addBackdrop("InputScrollFrameTemplate"));
NITCharsFrameDeleteConfirm:Hide();
NITCharsFrameDeleteConfirm:SetToplevel(true);
NITCharsFrameDeleteConfirm:SetHeight(130);
NITCharsFrameDeleteConfirm:SetWidth(250);
tinsert(UISpecialFrames, "NITCharsFrameDeleteConfirm");
NITCharsFrameDeleteConfirm:SetPoint("CENTER", UIParent, 0, 200);
NITCharsFrameDeleteConfirm:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8",insets = {top = 0, left = 0, bottom = 0, right = 0}});
NITCharsFrameDeleteConfirm:SetBackdropColor(0,0,0,1);
NITCharsFrameDeleteConfirm.CharCount:Hide();
NITCharsFrameDeleteConfirm:SetFrameStrata("HIGH");
NITCharsFrameDeleteConfirm.EditBox:SetAutoFocus(false);
NITCharsFrameDeleteConfirm.EditBox:EnableMouse(false);
NITCharsFrameDeleteConfirm.EditBox:SetScript("OnKeyDown", function(self, arg)
	NITCharsFrameDeleteConfirm.EditBox:ClearFocus();
end)
NITCharsFrameDeleteConfirm.EditBox:SetScript("OnUpdate", function(self, arg)
	--This is a hack so the editbox never gets focus and I can use the same frame template minus the editbox.
	NITCharsFrameDeleteConfirm.EditBox:ClearFocus();
end)
NITCharsFrameDeleteConfirm.EditBox:SetScript("OnHide", function(self, arg)
	--Clear the instance deletion that was set.
	NITCharsFrameDCDelete:SetScript("OnClick", function(self, arg) end);
end)

NITCharsFrameDeleteConfirm.fs = NITCharsFrameDeleteConfirm:CreateFontString("NITCharsFrameFS", "HIGH");
NITCharsFrameDeleteConfirm.fs:SetPoint("TOP", 0, -4);
NITCharsFrameDeleteConfirm.fs:SetFont(NIT.regionFont, 14);
NITCharsFrameDeleteConfirm.fs:SetText("Character data missing");

--Delete button.
local NITCharsFrameDCDelete = CreateFrame("Button", "NITCharsFrameDCDelete", NITCharsFrameDeleteConfirm, "UIPanelButtonTemplate");
NITCharsFrameDCDelete:SetPoint("CENTER", 0, -40);
NITCharsFrameDCDelete:SetWidth(120);
NITCharsFrameDCDelete:SetHeight(30);
--NITCharsFrameDCDelete:SetText(L["confirmDelete"]);
NITCharsFrameDCDelete:SetText("delete");
NITCharsFrameDCDelete:SetNormalFontObject("GameFontNormal");

--Top right X close button.
local NITCharsDCFrameClose = CreateFrame("Button", "NITCharsDCFrameClose", NITCharsFrameDeleteConfirm, "UIPanelCloseButton");
NITCharsDCFrameClose:SetPoint("TOPRIGHT", 10, 10);
NITCharsDCFrameClose:SetWidth(36);
NITCharsDCFrameClose:SetHeight(36);
NITCharsDCFrameClose:SetScript("OnClick", function(self, arg)
	NITCharsFrameDeleteConfirm:Hide();
end)

--Open delete confirmation box.
--If displayNum is provided then we display it as the matching number in the instance log.
--But we still delete the right table id number.
local deleteCharLast;
function NIT:openDeleteCharConfirmFrame(realm, char)
	NITCharsFrameDCDelete:SetText(L["delete"]);
	--Close window if we click delete button for same item again, but open new one if different item is clicked.
	if (NITCharsFrameDeleteConfirm:IsShown() and realm .. " " .. char == deleteCharLast) then
		NITCharsFrameDeleteConfirm:Hide();
	else
		NITCharsFrameDeleteConfirm:Hide();
		local data = NIT.db.global[realm].myChars[char];
		if (data) then
			local _, _, _, classColorHex = GetClassColor(data.classEnglish);
			--Safeguard for weakauras/addons that like to overwrite and break the GetClassColor() function.
			if (not classColorHex and data.classEnglish == "SHAMAN") then
				classColorHex = "ff0070dd";
			elseif (not classColorHex) then
				classColorHex = "ffffffff";
			end
			local text = NIT.prefixColor .. L["confirmCharacterDeletion"] .. "|r\n";
			text = text .. "\n\n|cff00ff00[" .. realm .. "]";
			text = text .. "\n\|c" .. classColorHex ..char;
			NITCharsFrameDeleteConfirm.fs:SetText(text);
			NITCharsFrameDCDelete:Show();
			NITCharsFrameDCDelete:SetScript("OnClick", function(self, arg)
				NIT:deleteCharacter(realm, char);
				NITCharsFrameDeleteConfirm:Hide();
			end)
		else
			NITCharsFrameDeleteConfirm.fs:SetText("Error: Character data missing");
			--NITCharsFrameDCDelete:SetText(L["Error"]);
			NITCharsFrameDCDelete:Hide();
		end
		NITCharsFrameDeleteConfirm:Show();
	end
	deleteCharLast = realm .. " " .. char;
end

--NPC events
local f = CreateFrame("Frame");
f:RegisterEvent("GOSSIP_SHOW");
f:SetScript('OnEvent', function(self, event, ...)
	if (event == "GOSSIP_SHOW") then
		local g1, type1, g2, type2, g3, type3, g4, type4, g5, type5, g6, type6, g7, type7, g8, type8 = GetGossipOptions();
		local npcGUID = UnitGUID("npc");
		local npcID;
		if (npcGUID) then
			_, _, _, _, _, npcID = strsplit("-", npcGUID);
		end
		if (not g1 or not npcID) then
			return;
		end
		if (npcID == "3849" and NIT.db.global.autoSfkDoor) then
			--Deathstalker Adamant Creature-0-4672-33-573-3849-000012AA57
			SelectGossipOption(1);
			return;
		end
		if (npcID == "17893" and NIT.db.global.autoSlavePens) then
			--Naturalist Bite Creature-0-4672-547-7775-17893-0000371B0A
			SelectGossipOption(1);
			return;
		end
		if (npcID == "20201" and NIT.db.global.autoBlackMorass and C_QuestLog.IsQuestFlaggedCompleted(10298)) then
			--Sa'at													--Hero of the Brood
			SelectGossipOption(1);
			return;
		end
		if (npcID == "20142" and NIT.db.global.autoCavernsFlight and C_QuestLog.IsQuestFlaggedCompleted(10279)) then
			--Steward of Time										--To The Master's Lair
			SelectGossipOption(1);
			return;
		end
	end
end)

function NIT:removeCharsBelowLevel()
	local level = NIT.db.global.trimDataBelowLevel;
	NIT:print(string.format(L["trimDataMsg2"], level));
	local found;
	local count = 0;
	for realm, v in NIT:pairsByKeys(NIT.db.global) do --Iterate realms.
		local msg = "";
		if (type(v) == "table" and realm ~= "minimapIcon"  and realm ~= "data"  and realm ~= "instances") then --The only tables in db.global are realm names.
			if (v.myChars) then
				for k, v in NIT:pairsByKeys(v.myChars) do --Iterate characters.
					if (v.level and v.level <= level) then
						NIT.db.global[realm].myChars[k] = nil;
						count = count + 1;
						print(NIT.chatColor .. string.format(L["trimDataMsg3"], k .. "-" .. realm));
						found = true;
					end
				end
			end
		end
	end
	if (not found) then
		NIT:print(L["trimDataMsg4"]);
	else
		NIT:print(string.format(L["trimDataMsg5"], count));
	end
	C_Timer.After(1, function()
		NIT:recalcInstanceLineFrames();
		NIT:recalcAltsLineFrames();
	end)
end

--No need for this, there's a clickable button in the alts frame for deleting.
--[[function NIT:removeSingleChar(name)
	if (not name or type(name) ~= "string" or name == "") then
		NIT:print(L["trimDataMsg6"]);
		return;
	end
	if (not string.match(name, "-")) then
		NIT:print(string.format(L["trimDataMsg7"], name));
		return;
	end
	--Normalize the realm name, removing spaces and '.
	local nomalizedName = string.gsub(name, " ", "");
	nomalizedName = string.gsub(nomalizedName, "'", "");
	local level = NIT.db.global.trimDataBelowLevel;
	local found;
	for realm, v in NIT:pairsByKeys(NIT.db.global) do --Iterate realms.
		local msg = "";
		if (type(v) == "table" and realm ~= "minimapIcon") then --The only tables in db.global are realm names.
			if (v.myChars) then
				for k, v in NIT:pairsByKeys(v.myChars) do --Iterate characters.
					if ((k .. "-" .. realm) == nomalizedName) then
						NIT.db.global[realm].myChars[k] = nil;
						found = true;
					end
				end
			end
		end
	end
	if (not found) then
		NIT:print(string.format(L["trimDataMsg8"], name));
	else
		NIT:print(string.format(L["trimDataMsg9"], name));
	end
	C_Timer.After(3, function()
		NIT:syncBuffsWithCurrentDuration();
	end)
end]]
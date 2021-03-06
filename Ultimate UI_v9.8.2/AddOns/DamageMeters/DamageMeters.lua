--[[
DamageMeters.lua
See the Readme for author and permissions.


TODO:
 FEATURES
- Change commands to /dm command args
- Help tooltips.
- Test matrix cases (falling in party).
- Per-character settings.
- Individual reports.
- Accumulate self data only option?
- time monitoring, DPS over total combat time.
- How are sessions cleared?
- Sort-by-class or class filter or something.
- Store min/max.

 KNOWN BUGS
- Sometime tooltip doesn't show for the first bar.  Making window big and small seems to fix it.

Threat Notes:
- All commented out threat stuff can be found by searching for comments with Threat just after them.
- "ThreatMeters" removed from SavedVariables in DamageMeters.toc.
- Binding removed:
	<Binding name="DAMAGEMETERS_THREAT_SETTARGETANDCLEAR" description="Threat Set Target And Clear">
		ThreatMeters_SetTargetAndClear();
	</Binding>
]]--

-------------------------------------------------------------------------------

-- CONSTANTS ---
DamageMeters_BARCOUNT_MAX = 40;	-- Note this is also the table max size atm.
DamageMeters_TABLE_MAX = 50;
DamageMeters_DEFAULTBARWIDTH = 119;
DamageMeters_BARHEIGHT = 12;
DamageMeters_PULSE_TIME = 1.00;
-- This number represents the version number where the saved data format
-- was last changed.  Every time the data stored in the tables are changed
-- this number needs to be changed so the mod knows not to load in obsolete
-- data.
DamageMeters_VERSION = 4207;
DamageMeters_VERSIONSTRING = "4.2.0";
DamageMeters_SYNCMSGCOLOR = { r = 0.35, g = 1.00, b = 0.75 };
DamageMeters_RPSCOLOR = { r = 0.00, g = 1.00, b = 1.00 };
DamageMeters_SYNCEMOTECOLOR = { r = 1.00, g = 0.60, b = 0.00 };
DM_COMBAT_TIMEOUT_SECONDS = 5.0;

DamageMeters_Sort_DECREASING = 1;
DamageMeters_Sort_INCREASING = 2;
DamageMeters_Sort_ALPHABETICAL = 3;
DamageMeters_Sort_MAX = 3;

DamageMeters_Relation_SELF = 1;
DamageMeters_Relation_PET = 2;
DamageMeters_Relation_PARTY = 3;
DamageMeters_Relation_FRIENDLY = 4;
DamageMeters_Relation_MAX = 4;

DamageMeters_Text_RANK = 1;
DamageMeters_Text_NAME = 2;
DamageMeters_Text_TOTALPERCENTAGE = 3;
DamageMeters_Text_LEADERPERCENTAGE = 4;
DamageMeters_Text_VALUE = 5;
DamageMeters_Text_MAX = 5;

DamageMeters_EventData_NONE = 1;
DamageMeters_EventData_SELF = 2;
DamageMeters_EventData_ALL = 3;

DamageMeters_colorScheme_RELATIONSHIP = 1;
DamageMeters_colorScheme_CLASS = 2;
DamageMeters_colorScheme_MAX = 2;

DM_Pause_Not = 0;
DM_Pause_Paused = 1;
DM_Pause_Ready = 2;

DMSYNC_PREFIX = "SYNC_10_";
DMSYNC_EVENT_PREFIX = "SYNCE_9_";
DamageMeters_SYNCREQUEST = "REQ_SYNC_9_";
DamageMeters_SYNCSTART = "SYNC_START_9_";
DamageMeters_SYNCCLEARREQUEST = "REQ_CLEAR_9_";
DamageMeters_SYNCCLEARACK = "REQ_CLEARACK_9_";
DamageMeters_SYNCPAUSEREQ = "SYNC_PAUSE_9_";
DamageMeters_SYNCUNPAUSEREQ = "SYNC_UNPAUSE_9_";
DamageMeters_SYNCREADYREQ = "SYNC_READY_9_";
DamageMeters_SYNCEND = "SYNC_END_9_";

DMSYNC_QUANTFORMATSTR = " %s %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d";

-- These are maintenance or informational functions, can be on a different version safely with 
-- the real sync functions.
DamageMeters_SYNCMSG = "SYNC_MSG_6_";
DamageMeters_SYNCPING = "SYNC_PING_6_"
DamageMeters_SYNCPINGREQ = "SYNC_PINGREQ_6_";
DamageMeters_SYNCEMOTE = "SYNC_EMOTE_6_";
DamageMeters_SYNCKICK = "SYNC_KICK_6_";
DamageMeters_SYNCJOINED = "SYNC_JOINED_7_";
DamageMeters_SYNCSESSIONMISMATCH = "SYNC_SESSIONMISMATCH_6_";
DamageMeters_SYNCHALT = "SYNC_HALT_6_";
DamageMeters_SYNCRPS = "SYNC_RPS_1_";
DamageMeters_SYNCRPSRESPONSE = "SYNC_RPSR_1_";
DamageMeters_SYNCRPSCOUNTERRESPONSE = "SYNC_RPSCR_1_";

DamageMeters_MINSYNCCOOLDOWN = 1.0;
DamageMeters_SYNCMSGSENDDELAY = 0.25; -- seconds.  increased from 0.05.  again from 0.1 (dc'ed a few people).
DamageMeters_SYNCMSGPROCESSDELAY = 0.005; -- seconds
-- 1 / (frame/sec * sec/msg) = msg /frame
-- 1 / (5 * 0.15) = 1.333, approx = 1;
DamageMeters_MAXSYNCMSGPERFRAME = 1;

-- Default quantity color text codes (ex. "cFF..."). Construct at runtime.
DamageMeters_quantityColorCodeDefault = {};

DamageMeters_TEXTSTATEDURATION = 6.0;
DamageMeters_BARFADEINMINTIME = 0.5;
DamageMeters_BARFADEINTIME = 0.01;
DamageMeters_BARCHARTIME = 0.02;
DamageMeters_QUANTITYSHOWDURATION = 6.0;

DMVIEW_NORMAL = 1;
DMVIEW_MAX = 2;
DMVIEW_MIN = 3;

DMPROF_PARSEMESSAGE = 1;
DMPROF_ADDVALUE = 2;
DMPROF_UPDATE = 3;
DMPROF_BARS = 4;
DMPROF_SORT = 5;
DMPROF_COUNT = 5;

DMPROF_NAMES = {
	"Parse",
	"AddValue",
	"Update",
	"Bars",
	"Sort",
};

-- GLOBALS ---
DamageMeters_bars = {};
DamageMeters_text = {};
--DamageMeters_table = {}; -- player, hitCount, critCount, lastTime, relationship, class, damageThisCombat, firstMsg
DamageMeters_tables = {};
DamageMeters_tableInfo = {}; -- sessionLabel, sessionIndex
DamageMeters_tableSortHash = {}; -- DamageMeters_tableSortHash[quantity][rank] = index in DamageMeters_tables[DMT_VISIBLE]
DMT_ACTIVE = DM_TABLE_A;
DMT_SAVED = DM_TABLE_B;
DMT_VISIBLE = DM_TABLE_A;
DamageMeters_bannedTable = {};
DamageMeters_tooltipBarIndex = nil;
DamageMeters_frameNeedsToBeGenerated = true;
DamageMeters_clickedBarIndex = nil;
DamageMeters_lastSyncTime = 0;
DamageMeters_listLocked = false;
DamageMeters_startCombatOnNextValue = true;
DamageMeters_inCombat = false;	-- This doesn't mean the player is in combat, but rather that someone we're monitoring appears to be.
DamageMeters_playerInCombat = false; -- This means we are in combat or not.
DamageMeters_combatStartTime = 0;
DamageMeters_combatEndTime = 0;
DamageMeters_reportBuffer = "";
DamageMeters_textStateStartTime = 0;
DamageMeters_currentQuantStartTime = -1;
DamageMeters_firstGeneration = true;
DamageMeters_lastEvent = {};
DamageMeters_missedMessages = {};
--DamageMeters_requestSyncWhenReportDone = false;
DamageMeters_lastUpdateTime = -1;
DamageMeters_lastSyncMsgTime = 0;
DamageMeters_lastSyncIncMsgTime = 0;
DamageMeters_syncMsgQueue = {};
DamageMeters_syncIncMsgQueue = {};
DamageMeters_syncIncMsgSourceQueue = {};
DamageMeters_debug_syncTestFactor = 1;
DamageMeters_syncStartTime = -1;
DamageMeters_sendMsgQueueBar = nil
DamageMeters_sendMsgQueueBarText = nil;
DamageMeters_processMsgQueueBar = nil;
DamageMeters_processMsgQueueBarText = nil;
DamageMeters_totals = {0,0,0,0,0,0};
DamageMeters_lastProcessQueueTime = -1;
DamageMeters_syncEvents = false;
DamageMeters_waitingForChainHeal = false;
DamageMeters_queuedChainHealCount = 0;
DamageMeters_queuedChainHealValue = {};
DamageMeters_queuedChainHealCrit = {};
DamageMeters_lastEventTime = nil;
DamageMeters_lastPlayerPosition = -1;
DamageMeters_barStartIndex = -1;
DamageMeters_debugTimers = {};
DamageMeters_lastDebugTime = -1;
DamageMeters_tablesDirty = true;
DamageMeters_lastBarUpdateTime = 0;
DamageMeters_activeDebugTimer = 0;

-- SETTINGS ---
DamageMeters_barCount = 10;
DamageMeters_quantity = DamageMeters_Quantity_DAMAGE;
DamageMeters_sort = DamageMeters_Sort_DECREASING;
DamageMeters_textOptions = {false, true, false, false};
DamageMeters_colorScheme = DamageMeters_colorScheme_CLASS;
DamageMeters_autoCountLimit = 0;
DamageMeters_syncChannel = "";
DamageMeters_loadedDataVersion = 0;
DamageMeters_pauseState = DM_Pause_Not;
DamageMeters_quantityColor = {};
DamageMeters_contributorList = {}; 
DamageMeters_eventDataLevel = DamageMeters_EventData_SELF;
DamageMeters_textState = 0;
DamageMeters_savedBarCount = 1;
DamageMeters_syncEventDataLevel = DamageMeters_EventData_ALL;
DamageMeters_quantitiesFilter = {};
DamageMeters_viewMode = DMVIEW_NORMAL;
DMTIMERMODE = 0;
DamageMeters_debugEnabled = false;	-- Debug: Enables display of various debug messages.
DamageMeters_BARWIDTH = DamageMeters_DEFAULTBARWIDTH;

-- Flags.  These are stored in a table to reduce the overall number of variables saved.
-- The .toc reader seems to only be able to handle lines that are under 1024 characters.  
-- (Rather, it ignores text after that cutoff.)
DamageMeters_flags = {};
DMFLAG_showFightAsPS = 1;
DMFLAG_justifyTextLeft = 2;
DMFLAG_applyFilterToAutoCycle = 3;
DMFLAG_applyFilterToManualCycle = 4;
DMFLAG_playerAlwaysVisible = 5;
DMFLAG_groupDPSMode = 6;
DMFLAG_showEventTooltipsFirst = 7;
DMFLAG_onlySyncWithGroup = 8;
DMFLAG_permitAutoSyncChanJoin = 9;
DMFLAG_enableDMM = 10;
DMFLAG_visibleOnlyInParty = 11;
DMFLAG_autoClearOnChannelJoin = 12;
DMFLAG_positionLocked = 13;
DMFLAG_isVisible = 14;
DMFLAG_groupMembersOnly = 15;
DMFLAG_addPetToPlayer = 16;
DMFLAG_showTotal = 17;
DMFLAG_resizeLeft = 18;
DMFLAG_resizeUp = 19;
DMFLAG_haveContributors = 20; -- For some reason this list can be non-empty but getn returns zero: thus this variable was added.
DMFLAG_cycleVisibleQuantity = 21;
DMFLAG_accumulateToMemory = 22;
DMFLAG_constantVisualUpdate = 23;
DMFLAG_resetWhenCombatStarts = 24;

function DamageMeters_SetDefaultOptions()
	DamageMeters_barCount = 10;
	DamageMeters_quantity = DamageMeters_Quantity_DAMAGE;
	DamageMeters_sort = DamageMeters_Sort_DECREASING;
	DamageMeters_textOptions = {false, true, false, false};
	DamageMeters_colorScheme = DamageMeters_colorScheme_CLASS;
	DamageMeters_autoCountLimit = 0;
	DamageMeters_syncChannel = "";
	DamageMeters_debugEnabled = false;	-- Debug: Enables display of various debug messages.
	DamageMeters_loadedDataVersion = 0;
	DamageMeters_pauseState = DM_Pause_Not;
	DamageMeters_quantityColor = {};
	DamageMeters_contributorList = {}; 
	DamageMeters_eventDataLevel = DamageMeters_EventData_SELF;
	DamageMeters_textState = 0;
	DamageMeters_savedBarCount = 1;
	DamageMeters_syncEventDataLevel = DamageMeters_EventData_ALL;
	DamageMeters_quantitiesFilter = {};
	DamageMeters_viewMode = DMVIEW_NORMAL;
	DMTIMERMODE = 0;
	DamageMeters_BARWIDTH = DamageMeters_DEFAULTBARWIDTH;

	-- Flags
	DamageMeters_flags[DMFLAG_showFightAsPS] = true;
	DamageMeters_flags[DMFLAG_justifyTextLeft] = false;
	DamageMeters_flags[DMFLAG_applyFilterToAutoCycle] = true;
	DamageMeters_flags[DMFLAG_applyFilterToManualCycle] = false;
	DamageMeters_flags[DMFLAG_playerAlwaysVisible] = false;
	DamageMeters_flags[DMFLAG_groupDPSMode] = true;
	DamageMeters_flags[DMFLAG_showEventTooltipsFirst] = false;
	DamageMeters_flags[DMFLAG_onlySyncWithGroup] = true;
	DamageMeters_flags[DMFLAG_permitAutoSyncChanJoin] = true;
	DamageMeters_flags[DMFLAG_enableDMM] = true;
	DamageMeters_flags[DMFLAG_visibleOnlyInParty] = false;
	DamageMeters_flags[DMFLAG_autoClearOnChannelJoin] = true;
	DamageMeters_flags[DMFLAG_positionLocked] = false;
	DamageMeters_flags[DMFLAG_isVisible] = true;
	DamageMeters_flags[DMFLAG_groupMembersOnly] = true;
	DamageMeters_flags[DMFLAG_addPetToPlayer] = false;
	DamageMeters_flags[DMFLAG_showTotal] = false;
	DamageMeters_flags[DMFLAG_resizeLeft] = true;
	DamageMeters_flags[DMFLAG_resizeUp] = true;
	DamageMeters_flags[DMFLAG_haveContributors] = false;
	DamageMeters_flags[DMFLAG_cycleVisibleQuantity] = false;
	DamageMeters_flags[DMFLAG_accumulateToMemory] = false;
	DamageMeters_flags[DMFLAG_constantVisualUpdate] = false;
	DamageMeters_flags[DMFLAG_resetWhenCombatStarts] = false;

	-- Init cyclable quantities.
	DamageMeters_quantitiesFilter[DamageMeters_Quantity_DAMAGE] = true;
	DamageMeters_quantitiesFilter[DamageMeters_Quantity_HEALING] = true;
	DamageMeters_quantitiesFilter[DamageMeters_Quantity_DAMAGED] = true;
	DamageMeters_quantitiesFilter[DamageMeters_Quantity_HEALINGRECEIVED] = true;
	DamageMeters_quantitiesFilter[DamageMeters_Quantity_DPS] = true;
	DamageMeters_quantitiesFilter[DamageMeters_Quantity_HPS] = false;
	DamageMeters_quantitiesFilter[DamageMeters_Quantity_DTPS] = false;
	DamageMeters_quantitiesFilter[DamageMeters_Quantity_HTPS] = false;
	DamageMeters_quantitiesFilter[DamageMeters_Quantity_TIME] = true;

	-- Initialize color table.
	DamageMeters_SetDefaultColors();

	-- Init the tables.
	local tableIndex;
	for tableIndex = 1, DMT_MAX do
		DamageMeters_tables[tableIndex] = {};
		DamageMeters_tableInfo[tableIndex] = {};
	end

	--[[ Threat
	-- Init threat meter's variables.
	ThreatMeters = { 
		["Version"] = DamageMeters_VERSIONSTRING;
		["Classes"] = {},
		["Talents"] = {},
		["Stances"] = {},
		["Equipment"] = {},
		["ClearOnPhaseChange"] = false;
	};
	]]--
end

-- DEBUG --
DamageMeters_msgCounts = {};

-- NOTE: Whenever you add/remove a new variable, increase the number in this
-- tables name so that it gets reset.
DamageMeters_debug3 = {};
-- Shows all messages.
DamageMeters_debug3.showAll = false;
DamageMeters_debug3.showParse = false;
-- When true, allows you to parse your own sync messages.
DamageMeters_debug3.syncSelf = false;
DamageMeters_debug3.syncSelfTestMode = false; -- Adds "x" to the end of player names for self-sync testing.
DamageMeters_debug3.showValueChanges = false;
-- When true, each incoming message becomes instead a 1 point of damage message 
-- caused by a player by the name of the message.
DamageMeters_debug3.msgWatchMode = false;
DamageMeters_debug3.showSyncChanges = false;
DamageMeters_debug3.showSyncQueueInfo = false;
DamageMeters_debug3.showGCInfo = false;


-------------------------------------------------------------------------------

function DMPrint(msg, color, bSecondChatWindow)
	local r = 0.50;
	local g = 0.50;
	local b = 1.00;

	if (color) then
		r = color.r;
		g = color.g;
		b = color.b;
	end

	local frame = DEFAULT_CHAT_FRAME;
	if (bSecondChatWindow) then
		frame = ChatFrame2;
	end

	if (frame) then
		frame:AddMessage(msg,r,g,b);
	end
end

-- stolen from sky (assertEquals)
function DMASSERTEQUALS(expected, actual)
	if  actual ~= expected  then
		local function wrapValue( v )
			if type(v) == 'string' then return "'"..v.."'" end
			return tostring(v)
		end
		errorMsg = "expected: "..wrapValue(expected)..", actual: "..wrapValue(actual)
		DMPrintD( errorMsg, 2 )
	end
end
function DMASSERTNOTEQUALS(expected, actual)
	if  actual == expected  then
		local function wrapValue( v )
			if type(v) == 'string' then return "'"..v.."'" end
			return tostring(v)
		end
		errorMsg = "not expected: "..wrapValue(expected)..", actual: "..wrapValue(actual)
		DMPrintD( errorMsg, 2 )
	end
end

function DMPrintD(msg, color, bSecondChatWindow)
	if (DamageMeters_debugEnabled) then
		--SendChatMessage(msg, "CHANNEL", nil, GetChannelName("dmdebug"));
		DMPrint(msg, color, bSecondChatWindow);
	end
end

function DMVerbose(msg)
	--DMPrint(msg);
end

-------------------------------------------------------------------------------

function DamageMetersFrame_OnLoad()
	-- Initialize debug timers.
	for timer = 1, DMPROF_COUNT do
		DamageMeters_debugTimers[timer] = {};
		DamageMeters_debugTimers[timer].time = 0;
		DamageMeters_debugTimers[timer].count = 0;
		DamageMeters_debugTimers[timer].peak = 0;
	end

	-- Define DamageMeters_Quantity_MAX.
	-- ALL QUANTITIES MUST BE DEFINED BEFORE THIS POINT.
	DamageMeters_Quantity_MAX = table.getn(DM_QUANTDEFS);
	DMPrintD("DamageMeters_Quantity_MAX = "..DamageMeters_Quantity_MAX);

	-- Inititalize quantity color codes.
	for quant = 1, DamageMeters_Quantity_MAX do
		local color = DM_QUANTDEFS[quant].defaultColor;
		local code = string.format("|cFF%02X%02X%02X",
			floor(color[1] * 255.0),
			floor(color[2] * 255.0),
			floor(color[3] * 255.0));
		DamageMeters_quantityColorCodeDefault[quant] = code;
	end

	-- Set default options.  Variable loading from SavedVars happens after OnLoad.
	DamageMeters_SetDefaultOptions();

	if (not DamageMetersFrame:IsUserPlaced()) then
		DMPrintD("Not user placed: resetting pos.");
		DamageMeters_ResetPos();
	end

	-- Build arrays for easy reference of Bars and BarText, and initialize those elements.
	local name = this:GetName();
	local i;
	for i = 1,DamageMeters_BARCOUNT_MAX do
		DamageMeters_bars[i] = getglobal(name.."Bar"..i);
		DamageMeters_bars[i]:SetID(i);
		DamageMeters_bars[i]:Hide();
		DamageMeters_text[i] = getglobal(name.."Text"..i);
		SetTextStatusBarText(DamageMeters_bars[i], DamageMeters_text[i]);
		-- Force text on always.
		ShowTextStatusBarText(DamageMeters_bars[i]);
	end

	-- Initialize the sync bars.
	DamageMeters_sendMsgQueueBar = getglobal("DamageMetersFrame_SendMsgQueueBar");
	DamageMeters_sendMsgQueueBarText = getglobal("DamageMetersFrame_SendMsgQueueBarText");
	SetTextStatusBarText(DamageMeters_sendMsgQueueBar, DamageMeters_sendMsgQueueBarText);
	DamageMeters_sendMsgQueueBar:SetMinMaxValues(0, 100);
	DamageMeters_sendMsgQueueBar:SetValue(100);
	DamageMeters_sendMsgQueueBar:SetStatusBarColor(1.00, 0.0, 0.00);
	-- Force text on always.
	ShowTextStatusBarText(DamageMeters_sendMsgQueueBar);
	DamageMeters_sendMsgQueueBarText:SetPoint("CENTER", DamageMeters_sendMsgQueueBar:GetName(), "CENTER", 0, 0);
	DamageMeters_sendMsgQueueBarText:SetText("");
	DamageMeters_sendMsgQueueBar:Hide();

	DamageMeters_processMsgQueueBar = getglobal("DamageMetersFrame_ProcessMsgQueueBar");
	DamageMeters_processMsgQueueBarText = getglobal("DamageMetersFrame_ProcessMsgQueueBarText");
	SetTextStatusBarText(DamageMeters_processMsgQueueBar, DamageMeters_processMsgQueueBarText);
	DamageMeters_processMsgQueueBar:SetMinMaxValues(0, 250);
	DamageMeters_processMsgQueueBar:SetValue(0);
	DamageMeters_processMsgQueueBar:SetStatusBarColor(1.00, 0.0, 0.00);
	-- Force text on always.
	ShowTextStatusBarText(DamageMeters_processMsgQueueBar);
	DamageMeters_processMsgQueueBarText:SetPoint("CENTER", DamageMeters_processMsgQueueBar:GetName(), "CENTER", 0, 0);
	DamageMeters_processMsgQueueBarText:SetText("");
	DamageMeters_processMsgQueueBar:Hide();

	-- General messages.
	this:RegisterEvent("VARIABLES_LOADED");
	this:RegisterEvent("PARTY_MEMBERS_CHANGED");
	this:RegisterEvent("PLAYER_REGEN_ENABLED");
	this:RegisterEvent("PLAYER_REGEN_DISABLED");
	this:RegisterEvent("CHAT_MSG_CHANNEL_NOTICE");

	-- Messages to measure how much damage is dealt.
	this:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS");	-- Melee you do on things.
	this:RegisterEvent("CHAT_MSG_COMBAT_PET_HITS");		-- Melee your pets do.
	this:RegisterEvent("CHAT_MSG_COMBAT_PARTY_HITS");	-- Melee done by part.
	this:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLYPLAYER_HITS");	-- Melee done by friendlies.
	this:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE");	-- Your spells that damage other things.
	this:RegisterEvent("CHAT_MSG_SPELL_PET_DAMAGE");
	this:RegisterEvent("CHAT_MSG_SPELL_PARTY_DAMAGE");	-- Party member's spell hits.
	this:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_DAMAGE"); -- Spells other people cast on things.
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_CREATURE_DAMAGE"); -- Blah suffers # Arcane damage from #'s/your Spell.  Works on self, party, friendly.
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE");
	this:RegisterEvent("CHAT_MSG_SPELL_DAMAGESHIELDS_ON_SELF");		-- Thorns on self.
	this:RegisterEvent("CHAT_MSG_SPELL_DAMAGESHIELDS_ON_OTHERS");	-- Thorns on others.

	-- Messages to measure healing done and received.
	this:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF");
	this:RegisterEvent("CHAT_MSG_SPELL_PARTY_BUFF");
	this:RegisterEvent("CHAT_MSG_SPELL_FRIENDLYPLAYER_BUFF");
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS");
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_BUFFS");
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_BUFFS");
	this:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_BUFF");
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_BUFFS");

	-- Messages to measure damage taken.
	this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS");
	this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES");
	this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_PARTY_HITS");
	this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_PARTY_MISSES");
	this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_HITS");
	this:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_CREATURE_MISSES");
	this:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_SELF_DAMAGE");
	this:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_PARTY_DAMAGE");
	this:RegisterEvent("CHAT_MSG_SPELL_CREATURE_VS_CREATURE_DAMAGE");
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_SELF_DAMAGE");
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_PARTY_DAMAGE");
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_FRIENDLYPLAYER_DAMAGE");
	-- The HOSTILEPLAYER ones are for dueling and pvp.
	this:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS");
	this:RegisterEvent("CHAT_MSG_SPELL_HOSTILEPLAYER_DAMAGE");
	this:RegisterEvent("CHAT_MSG_SPELL_PERIODIC_HOSTILEPLAYER_DAMAGE");

	-- For sync stuff.
	this:RegisterEvent("CHAT_MSG_CHANNEL");
	this:RegisterEvent("CHAT_MSG_RAID");
	this:RegisterEvent("CHAT_MSG_PARTY");

	--[[ Threat
	-- For threat stuff.
	this:RegisterEvent("CHAT_MSG_SPELL_FAILED_LOCALPLAYER");
	this:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES");
	this:RegisterEvent("CHAT_MSG_COMBAT_PARTY_MISSES");
	this:RegisterEvent("CHAT_MSG_COMBAT_FRIENDLYPLAYER_MISSES");
	this:RegisterEvent("CHAT_MSG_MONSTER_YELL");
	this:RegisterEvent("PLAYER_DEAD");
	]]--

	-- Console commands.
	SlashCmdList["DAMAGEMETERSHELP"] = DamageMeters_Help;
	SLASH_DAMAGEMETERSHELP1 = "/dmhelp";
	SlashCmdList["DAMAGEMETERSCMD"] = DamageMeters_ListCommands;
	SLASH_DAMAGEMETERSCMD1 = "/dmcmd";
	SlashCmdList["DAMAGEMETERSSHOW"] = DamageMeters_ToggleShow;
	SLASH_DAMAGEMETERSSHOW1 = "/dmshow";
	SlashCmdList["DAMAGEMETERSHIDE"] = DamageMeters_Hide;
	SLASH_DAMAGEMETERSHIDE1 = "/dmhide";
	SlashCmdList["DAMAGEMETERSCLEAR"] = DamageMeters_Clear;
	SLASH_DAMAGEMETERSCLEAR1 = "/dmclear";
	SlashCmdList["DAMAGEMETERSREPORT"] = DamageMeters_Report;
	SLASH_DAMAGEMETERSREPORT1 = "/dmreport";
	SlashCmdList["DAMAGEMETERSSORT"] = DamageMeters_SetSort;
	SLASH_DAMAGEMETERSSORT1 = "/dmsort";
	SlashCmdList["DAMAGEMETERSCOUNT"] = DamageMeters_SetCount;
	SLASH_DAMAGEMETERSCOUNT1 = "/dmcount";
	SlashCmdList["DAMAGEMETERSSAVE"] = DamageMeters_Save;
	SLASH_DAMAGEMETERSSAVE1 = "/dmsave";
	SlashCmdList["DAMAGEMETERSRESTORE"] = DamageMeters_Restore;
	SLASH_DAMAGEMETERSRESTORE1 = "/dmrestore";
	--SlashCmdList["DAMAGEMETERSMERGE"] = DamageMeters_Merge;
	--SLASH_DAMAGEMETERSMERGE1 = "/dmmerge";
	SlashCmdList["DAMAGEMETERSSWAP"] = DamageMeters_Swap;
	SLASH_DAMAGEMETERSSWAP1 = "/dmswap";
	SlashCmdList["DAMAGEMETERSMEMCLEAR"] = DamageMeters_MemClear;
	SLASH_DAMAGEMETERSMEMCLEAR1 = "/dmmemclear";
	SlashCmdList["DAMAGEMETERSRESETPOS"] = DamageMeters_ResetPos;
	SLASH_DAMAGEMETERSRESETPOS1 = "/dmresetpos";
	SlashCmdList["DAMAGEMETERSSHOWTEXT"] = DamageMeters_SetTextOptions;
	SLASH_DAMAGEMETERSSHOWTEXT1 = "/dmtext";
	SlashCmdList["DAMAGEMETERSCOLORSCHEME"] = DamageMeters_SetColorScheme;
	SLASH_DAMAGEMETERSCOLORSCHEME1 = "/dmcolor";
	SlashCmdList["DAMAGEMETERSQUANTITY"] = DamageMeters_SetQuantity;
	SLASH_DAMAGEMETERSQUANTITY1 = "/dmquant";
	SlashCmdList["DAMAGEMETERSVISINPARTY"] = DamageMeters_SetVisibleInParty;
	SLASH_DAMAGEMETERSVISINPARTY1 = "/dmvisinparty";
	SlashCmdList["DAMAGEMETERSAUTOCOUNT"] = DamageMeters_SetAutoCount;
	SLASH_DAMAGEMETERSAUTOCOUNT1 = "/dmautocount";
	SlashCmdList["DAMAGEMETERSLISTBANNED"] = DamageMeters_ListBanned;
	SLASH_DAMAGEMETERSLISTBANNED1 = "/dmlistbanned";
	SlashCmdList["DAMAGEMETERSCLEARBANNED"] = DamageMeters_ClearBanned;
	SLASH_DAMAGEMETERSCLEARBANNED1 = "/dmclearbanned";
	SlashCmdList["DAMAGEMETERSSYNC"] = DamageMeters_Sync;
	SLASH_DAMAGEMETERSSYNC1 = "/dmsync";
	SlashCmdList["DAMAGEMETERSSYNCCHAN"] = DamageMeters_SyncChan;
	SLASH_DAMAGEMETERSSYNCCHAN1 = "/dmsyncchan";
	SlashCmdList["DAMAGEMETERSSYNCLEAVE"] = DamageMeters_SyncLeaveChanCmd;
	SLASH_DAMAGEMETERSSYNCLEAVE1 = "/dmsyncleave";
	SlashCmdList["DAMAGEMETERSSYNCSEND"] = DamageMeters_SyncReport;
	SLASH_DAMAGEMETERSSYNCSEND1 = "/dmsyncsend";
	SlashCmdList["DAMAGEMETERSSYNCREQUEST"] = DamageMeters_SyncRequest;
	SLASH_DAMAGEMETERSSYNCREQUEST1 = "/dmsyncrequest";
	SlashCmdList["DAMAGEMETERSSYNCCLEAR"] = DamageMeters_SyncClear;
	SLASH_DAMAGEMETERSSYNCCLEAR1 = "/dmsyncclear";
	SlashCmdList["DAMAGEMETERSSYNCMSG"] = DamageMeters_SendSyncMsg;
	SLASH_DAMAGEMETERSSYNCMSG1 = "/dmsyncmsg";
	SLASH_DAMAGEMETERSSYNCMSG2 = "/dmm";
	SlashCmdList["DAMAGEMETERSSYNCBROADCASTCHAN"] = DamageMeters_SyncBroadcastChan;
	SLASH_DAMAGEMETERSSYNCBROADCASTCHAN1 = "/dmsyncbroadcastchan";
	SLASH_DAMAGEMETERSSYNCBROADCASTCHAN2 = "/dmsyncb";
	SlashCmdList["DAMAGEMETERSSYNCPING"] = DamageMeters_SyncPingRequest;
	SLASH_DAMAGEMETERSSYNCPING1 = "/dmsyncping";
	SlashCmdList["DAMAGEMETERSSYNCPAUSE"] = DamageMeters_SyncPause;
	SLASH_DAMAGEMETERSSYNCPAUSE1 = "/dmsyncpause";
	SlashCmdList["DAMAGEMETERSSYNCUNPAUSE"] = DamageMeters_SyncUnpause;
	SLASH_DAMAGEMETERSSYNCUNPAUSE1 = "/dmsyncunpause";
	SlashCmdList["DAMAGEMETERSSYNCREADY"] = DamageMeters_SyncReady;
	SLASH_DAMAGEMETERSSYNCREADY1 = "/dmsyncready";
	SlashCmdList["DAMAGEMETERSSYNCKICK"] = DamageMeters_SyncKick;
	SLASH_DAMAGEMETERSSYNCKICK1 = "/dmsynckick";
	SlashCmdList["DAMAGEMETERSSYNCLABEL"] = DamageMeters_SyncLabel;
	SLASH_DAMAGEMETERSSYNCLABEL1 = "/dmsynclabel";
	SlashCmdList["DAMAGEMETERSSYNCSTART"] = DamageMeters_SyncStart;
	SLASH_DAMAGEMETERSSYNCSTART1 = "/dmsyncstart";
	SlashCmdList["DAMAGEMETERSSYNCHALT"] = DamageMeters_SyncHalt;
	SLASH_DAMAGEMETERSSYNCHALT1 = "/dmsynchalt";
	-- Undocumented atm.
	SlashCmdList["DAMAGEMETERSSYNCEMOTE"] = DamageMeters_SyncEmote;
	SLASH_DAMAGEMETERSSYNCEMOTE1 = "/dme";
	SlashCmdList["DAMAGEMETERSRPS"] = DamageMeters_RPSChallenge;
	SLASH_DAMAGEMETERSRPS1 = "/dmrps";
	SlashCmdList["DAMAGEMETERSRPSR"] = DamageMeters_RPSResponse;
	SLASH_DAMAGEMETERSRPSR1 = "/dmrpsr";

	SlashCmdList["DAMAGEMETERSPOPULATE"] = DamageMeters_Populate;
	SLASH_DAMAGEMETERSPOPULATE1 = "/dmpop";
	SlashCmdList["DAMAGEMETERSTOGGLELOCK"] = DamageMeters_ToggleLock;
	SLASH_DAMAGEMETERSTOGGLELOCK1 = "/dmlock";
	SlashCmdList["DAMAGEMETERSTOGGLEPAUSE"] = DamageMeters_TogglePause;
	SLASH_DAMAGEMETERSTOGGLEPAUSE1 = "/dmpause";
	SlashCmdList["DAMAGEMETERSSETREADY"] = DamageMeters_SetReady;
	SLASH_DAMAGEMETERSSETREADY1 = "/dmready";
	SlashCmdList["DAMAGEMETERSTOGGLELOCKPOS"] = DamageMeters_ToggleLockPos;
	SLASH_DAMAGEMETERSTOGGLELOCKPOS1 = "/dmlockpos";
	SlashCmdList["DAMAGEMETERSTOGGLEGROUPONLY"] = DamageMeters_ToggleGroupMembersOnly;
	SLASH_DAMAGEMETERSTOGGLEGROUPONLY1 = "/dmgrouponly";
	SlashCmdList["DAMAGEMETERSTOGGLEADDPETTOPLAYER"] = DamageMeters_ToggleAddPetToPlayer;
	SLASH_DAMAGEMETERSTOGGLEADDPETTOPLAYER1 = "/dmaddpettoplayer";
	SlashCmdList["DAMAGEMETERSTOGGLERESETWHENCOMBATSTARTS"] = DamageMeters_ToggleResetWhenCombatStarts;
	SLASH_DAMAGEMETERSTOGGLERESETWHENCOMBATSTARTS1 = "/dmresetoncombat";
	SlashCmdList["DAMAGEMETERSVERSION"] = DamageMeters_ShowVersion;
	SLASH_DAMAGEMETERSVERSION1 = "/dmversion";
	SLASH_DAMAGEMETERSVERSION2 = "/dmver";
	SlashCmdList["DAMAGEMETERSTOGGLETOTAL"] = DamageMeters_ToggleTotal;
	SLASH_DAMAGEMETERSTOGGLETOTAL1 = "/dmtotal";
	SlashCmdList["DAMAGEMETERSTOGGLESHOWMAX"] = DamageMeters_ToggleMaxBars;
	SLASH_DAMAGEMETERSTOGGLESHOWMAX1 = "/dmshowmax";

	--[[ Threat
	-- Threat commands.
	SlashCmdList["DAMAGEMETERSSETTARGET"] = ThreatMeters_SetTarget;
	SLASH_DAMAGEMETERSSETTARGET1 = "/dmsettarget";
	SlashCmdList["DAMAGEMETERSSYNCTALENTS"] = ThreatMeters_SyncTalents;
	SLASH_DAMAGEMETERSSYNCTALENTS1 = "/dmsynctalents";
	SlashCmdList["DAMAGEMETERSSYNCEQUIP"] = ThreatMeters_SyncEquipment;
	SLASH_DAMAGEMETERSSYNCEQUIP1 = "/dmsyncequip";
	]]--

	-- Commands for testing.
	-- ["reset"] = "/dmreset - (For Testing) Forces a re-layout of the visual elements.",
	SlashCmdList["DAMAGEMETERSRESET"] = DamageMeters_Reset;
	SLASH_DAMAGEMETERSRESET1 = "/dmreset";
	-- ["test"] = "/dmtest [#] - (For Testing) Adds # test entries to the list.  If no number specified, adds one entry for each visible bar.",
	SlashCmdList["DAMAGEMETERSTEST"] = DamageMeters_Test;
	SLASH_DAMAGEMETERSTEST1 = "/dmtest";
	-- ["add"] = "/dmadd name - (For Testing) Simulates player 'name' doing 1 damage.",
	SlashCmdList["DAMAGEMETERSADD"] = DamageMeters_Add;
	SLASH_DAMAGEMETERSADD1 = "/dmadd";
	-- ["dumptable"] = "/dmdumptable - (For Testing) Dumps the entire internal data table."
	SlashCmdList["DAMAGEMETERSDUMPTABLE"] = DamageMeters_DumpTable;
	SLASH_DAMAGEMETERSDUMPTABLE1 = "/dmdumptable";
	SlashCmdList["DAMAGEMETERSDEBUGPRINT"] = DM_ToggleDMPrintD;
	SLASH_DAMAGEMETERSDEBUGPRINT1 = "/dmdebug";
	SlashCmdList["DAMAGEMETERSDUMPMSG"] = DM_DumpMsg;
	SLASH_DAMAGEMETERSDUMPMSG1 = "/dmdumpmsg";
	SlashCmdList["DAMAGEMETERSCONSOLEPRINT"] = DM_ConsolePrint;
	SLASH_DAMAGEMETERSCONSOLEPRINT1 = "/dmp";

	-- Tell the frame to rebuild itself.
	DamageMeters_UpdateVisibility();
	DamageMeters_frameNeedsToBeGenerated = true;

	DamageMeters_lastUpdateTime = GetTime();
	DamageMeters_lastProcessQueueTime = DamageMeters_lastUpdateTime;
	DamageMeters_lastEventTime = GetTime();
end

-- This function should house code that needs to run after variables have been loaded
-- but before the mod starts updating.
function DamageMeters_OnLoadComplete()
	-- Nothing here atm. :|
end

function DamageMeters_InParty()
	local inParty = false;
	local p = GetNumPartyMembers();
	local r = GetNumRaidMembers();

	if ((p + r) > 0) then
		inParty = true;
	end

	return inParty;
end

function DamageMeters_UpdateVisibility(userCaused)
	local inParty = DamageMeters_InParty();

	if (DamageMeters_flags[DMFLAG_visibleOnlyInParty]) then
		if (inParty and not DamageMetersFrame:IsVisible()) then
			DMPrintD("DMFLAG_visibleOnlyInParty, inParty, and not DamageMetersFrame:IsVisible() - calling _Show()");
			DamageMeters_Show();
		elseif (not inParty and DamageMetersFrame:IsVisible()) then
			DMPrintD("DMFLAG_visibleOnlyInParty, not inParty, and DamageMetersFrame:IsVisible() - calling _Hide()");
			DamageMeters_Hide();
		end
	elseif (userCaused) then
		if (not DamageMetersFrame:IsVisible()) then
			DamageMeters_Show();
		end
	end
end

function DamageMeters_UpdateCount()
	local newCount = DamageMeters_barCount;
	if (DMVIEW_MAX == DamageMeters_viewMode) then
		newCount = DamageMeters_BARCOUNT_MAX;
	elseif (DMVIEW_MIN == DamageMeters_viewMode) then
		newCount = 1;
	else
		if (DamageMeters_autoCountLimit > 0) then
			newCount = table.getn(DamageMeters_tables[DMT_VISIBLE]);
			if (newCount > DamageMeters_autoCountLimit) then
				newCount = DamageMeters_autoCountLimit;
			elseif (newCount == 0) then
				newCount = 1;
			end
		end
	end

	if (newCount ~= DamageMeters_barCount) then
		DamageMeters_barCount = newCount;
		DMPrintD("Frame dirty: count changed.");
		DamageMeters_frameNeedsToBeGenerated = true;
	end
end

function DamageMeters_UpdateDebugTimers()
	local now = GetTime();

	-- /script DMPrint(GetTime().." - "..DamageMeters_lastDebugTime.." = "..(GetTime() - DamageMeters_lastDebugTime));
	if (DamageMeters_lastDebugTime < 0) then
		DamageMeters_lastDebugTime = now;

		local timer;
		for timer = 1, DMPROF_COUNT do
			DamageMeters_debugTimers[timer] = {};
			DamageMeters_debugTimers[timer].time = 0;
			DamageMeters_debugTimers[timer].count = 0;
			DamageMeters_debugTimers[timer].peak = 0;
		end
	end

	local debugTime = now - DamageMeters_lastDebugTime;
	if (debugTime > 1.0) then
		DamageMeters_lastDebugTime = now;

		local timer;

		if (DamageMeters_debugEnabled) then
			if (DMTIMERMODE == 1) then
				local msg = string.format("(%.2f) ", debugTime);
				for timer = 1, DMPROF_COUNT do				
					msg = msg..string.format("%s=%d(%d) ", DMPROF_NAMES[timer], DamageMeters_debugTimers[timer].time, DamageMeters_debugTimers[timer].count);
				end
				DMPrint(msg, nil, true);
			elseif (DMTIMERMODE == 2) then
				local msg = "";
				local uCount = ceil(DamageMeters_debugTimers[DMPROF_UPDATE].time / 10);
				local pCount = ceil(DamageMeters_debugTimers[DMPROF_PARSEMESSAGE].time / 10);
				local aCount = ceil(DamageMeters_debugTimers[DMPROF_ADDVALUE].time / 10);
				local bCount = ceil(DamageMeters_debugTimers[DMPROF_BARS].time / 10);
				msg = msg.."|cFFFF0000"..string.rep("U", uCount);
				msg = msg.."|cFF00FF00"..string.rep("P", pCount);
				msg = msg.."|cFF60FF60"..string.rep("A", aCount);
				msg = msg.."|cFF0000FF"..string.rep("B", bCount);
				DMPrint(msg, nil, true);
			elseif (DMTIMERMODE == 3) then
				local msPerFrame = 1000 / GetFramerate();
				local msg = string.format("Frames (%.2f) ", debugTime);
				for timer = 1, DMPROF_COUNT do				
					msg = msg..string.format("%s=%.2f(%d) ", 
							DMPROF_NAMES[timer], 
							DamageMeters_debugTimers[timer].time / msPerFrame, 
							DamageMeters_debugTimers[timer].count);
				end
				DMPrint(msg, nil, true);
			elseif (DMTIMERMODE == 4) then
				local totalTime = 0;
				local msPerFrame = 1000 / GetFramerate();
				for timer = 1, DMPROF_COUNT do				
					totalTime = totalTime + DamageMeters_debugTimers[timer].time;
				end
				local debugMS = floor(debugTime * 1000);
				local msg = string.format("%.2f Frames @ %.2f FPS | %4d / %4d ms = %.2f%%", 
						totalTime / msPerFrame, 
						GetFramerate(), 
						totalTime,
						debugMS,
						100 * totalTime / debugMS);
				DMPrint(msg, nil, true);
			end
		end

		for timer = 1, DMPROF_COUNT do	
			if (DamageMeters_debugTimers[timer].peak < DamageMeters_debugTimers[timer].time) then
				DamageMeters_debugTimers[timer].peak = DamageMeters_debugTimers[timer].time;
			end
			DamageMeters_debugTimers[timer].time = 0;
			DamageMeters_debugTimers[timer].count = 0;
		end
	end
end

function DMPEAKINFO()
	local msg = "";
	local timer;
	local total = 0;
	for timer = 1, DMPROF_COUNT do
		msg = msg..string.format("%s=%d ", DMPROF_NAMES[timer], DamageMeters_debugTimers[timer].peak);
	end
	DMPrint(msg);
end

-- Call this when the table is dirty to "clean" it.
-- Do sorting and such here.
function DamageMeters_UpdateTables()
	--DMPrintD(GetTime()..": Update Tables called.", nil, true);

	DamageMeters_StartDebugTimer(DMPROF_SORT);

	-- Determine totals -first-, as some quantities (ie. Dande-Rating) require totals in order to
	-- calculate their own values.
	DamageMeters_DetermineTotals();

	DamageMeters_DoSort(DamageMeters_tables[DMT_VISIBLE], DamageMeters_quantity);
	DamageMeters_tablesDirty = false;

	-- Determine ranks for Titan display.
	-- Eventually the rank table could be used to index into the main table, rather than sorting the 
	-- main table itself.  Would add some indirection but would keep us from having to shuffle that 
	-- table around.  Dunno which way is faster, honestly.
	DamageMeters_DetermineRanks(DMT_ACTIVE, true);

	DamageMeters_StopDebugTimer(DMPROF_SORT);
end

function DamageMetersFrame_OnUpdate()
	-- Debug Start
	DamageMeters_StartDebugTimer(DMPROF_UPDATE);
	----------------------

	local updateBars = false;

	local currentTime = GetTime();
	local elapsed = currentTime - DamageMeters_lastUpdateTime;

	if (DamageMeters_debug3.showGCInfo) then
		local gcAmt, gcLimit = gcinfo();

		DamageMeters_processMsgQueueBar:Show();
		DamageMeters_processMsgQueueBar:SetMinMaxValues(0, gcLimit);
		DamageMeters_processMsgQueueBar:SetValue(gcAmt);
	end


	-- If we have queued chain heals, process them now.
	if (DamageMeters_queuedChainHealCount > 0) then
		if (DamageMeters_queuedChainHealCount > 3) then
			-- If we have an unreasonable number, nuke them
			DamageMeters_queuedChainHealCount = 0;
		else
			--DMPrintD("Processing queued chain heals, total = "..DamageMeters_queuedChainHealCount);
			local activeIndex = DamageMeters_GetPlayerIndex(UnitName("Player"), DMT_ACTIVE);
			local fightIndex = DamageMeters_GetPlayerIndex(UnitName("Player"), DMT_FIGHT);
			if (not activeIndex or not fightIndex) then
				-- If the player has no index, maybe we had a clear happen between the heal being queued
				-- and this tick: just clear it.
				DamageMeters_queuedChainHealCount = 0;
			else
				local hitCount = 1;
				while (DamageMeters_queuedChainHealCount > 0) do
					-- Add events for the additional chain heals, but don't add the values again to
					-- the totals.  Also, mark the events with a * at the end to tell other bits of
					-- code not to count this one.
					local spell = "Chain Heal "..hitCount.."*";

					-- index, quantity, spell, amount, crit, relationship
					DamageMeters_AddEvent(DMT_ACTIVE,
							activeIndex, 
							DamageMeters_Quantity_HEALING, 
							spell, 
							DamageMeters_queuedChainHealValue[DamageMeters_queuedChainHealCount], 
							DamageMeters_queuedChainHealCrit[DamageMeters_queuedChainHealCount],
							DamageMeters_Relation_SELF,
							nil );
					DamageMeters_AddEvent(DMT_FIGHT,
							fightIndex, 
							DamageMeters_Quantity_HEALING, 
							spell, 
							DamageMeters_queuedChainHealValue[DamageMeters_queuedChainHealCount], 
							DamageMeters_queuedChainHealCrit[DamageMeters_queuedChainHealCount],
							DamageMeters_Relation_SELF,
							nil );

					DamageMeters_queuedChainHealCount = DamageMeters_queuedChainHealCount - 1;
					hitCount = hitCount + 1;
				end
			end
		end

		DamageMeters_waitingForChainHeal = false;
	end

	------------------

	-- Update quant cycling.
	if (DamageMeters_flags[DMFLAG_cycleVisibleQuantity]) then
		if (DamageMeters_textState < 1) then
			if (GetTime() - DamageMeters_currentQuantStartTime > DamageMeters_QUANTITYSHOWDURATION) then
				DamageMeters_CycleQuant(false, DamageMeters_flags[DMFLAG_applyFilterToAutoCycle]);
				DamageMeters_textStateStartTime = GetTime();
				updateBars = true;
			end
		end
	end

	-- Update visibility.
	DamageMeters_UpdateVisibility();

	-- Update count.
	DamageMeters_UpdateCount();

	-- Generate the frame if needed.
	local forceSort = false;
	if (DamageMeters_frameNeedsToBeGenerated) then
		DamageMetersFrame_GenerateFrame();
		DamageMeters_tablesDirty = true;
		updateBars = true;
		forceSort = true;
	end

	-- Update Background
	-- Determine if we are still in combat.
	local updateBackground = false;
	if (DamageMeters_inCombat) then
		if (DamageMeters_IsQuantityPS(DamageMeters_quantity)) then
			updateBackground = true;
		end

		-- If the player isn't in combat and we haven't received any messages
		-- in a while, automatically end combat.
		if (not DamageMeters_playerInCombat and
			DamageMeters_combatEndTime - DamageMeters_lastEventTime > DM_COMBAT_TIMEOUT_SECONDS) then
			--DMPrintD("Stopping combat due to inactivity.");
			DamageMeters_OnCombatEnd();			
		end
	end
	if (DM_Pause_Not ~= DamageMeters_pauseState) then
		updateBackground = true;
	end
	if (updateBackground) then
		DamageMeters_SetBackgroundColor();
	end

	-- Start delayed Sync.
	if (DamageMeters_syncStartTime > 0) then
		if (currentTime > DamageMeters_syncStartTime) then
			DamageMeters_DoSync();
			DamageMeters_syncStartTime = -1;
		end
	end

	-- Update text state.
	if (DamageMeters_textState > 0) then
		local now = GetTime();
		if (now - DamageMeters_textStateStartTime > DamageMeters_TEXTSTATEDURATION) then
			local lastState = DamageMeters_textState;
			repeat
				DamageMeters_textState = DamageMeters_textState + 1;

				if (DamageMeters_textState > DamageMeters_Text_MAX) then
					DamageMeters_textState = 1;
					if (DamageMeters_flags[DMFLAG_cycleVisibleQuantity]) then
						DamageMeters_CycleQuant(false, DamageMeters_flags[DMFLAG_applyFilterToAutoCycle]);
					end
				end
				
				-- This is a safety to keep us from looping forever.
				if (DamageMeters_textState == lastState) then
					-- Unnecessary, just break.  Stay with the last state.
					--DMPrintD("DamageMeters_textState infinite loop protection activated.");
					--DamageMeters_textOptions[DamageMeters_Text_NAME] = true;
					--DamageMeters_textState = DamageMeters_Text_NAME;
					break;
				end
			until (DamageMeters_textOptions[DamageMeters_textState])
			DamageMeters_textStateStartTime = now;
			updateBars = true;		
		end
	end

	DamageMeters_StopDebugTimer(DMPROF_UPDATE);

	----------------------------------

	local bSecondHasPassedSinceLastBarUpdate = (currentTime - DamageMeters_lastBarUpdateTime > 1.0);

	-- NOTE: DamageMeters_lastBarUpdateTime also means "last sort time".  When the hidden frame
	-- takes over sorting duties when we are hidden it uses that variable, even though no bars are
	-- actually sorted.
	if (DamageMeters_flags[DMFLAG_constantVisualUpdate] or bSecondHasPassedSinceLastBarUpdate) then
		updateBars = true;
		DamageMeters_lastBarUpdateTime = currentTime;
	end
	
	-- Sort the table.
	if (forceSort or (DamageMeters_tablesDirty and (DamageMeters_flags[DMFLAG_constantVisualUpdate] or updateBars))) then
		DamageMeters_UpdateTables();
	end

	----------------------------------
	-- Code which calculates and uses totals.
	-- Must come after Sorting, as some quantity's values are calculated from totals.

	-- Calculate totals.  These are used by tooltips and reports, and should be 
	-- calculated every update.
	local quantIndex;
	local totalValue = 0;
	local maxUnitIndex = 0;
	local maxUnitValue = 0;
	for quantIndex = 1, DMI_MAX do
		DamageMeters_totals[quantIndex] = 0;
	end
	local dmi = DamageMeters_GetQuantityDMI(DamageMeters_quantity);
	local index, playerStruct;
	for index, playerStruct in DamageMeters_tables[DMT_VISIBLE] do 
		local unitValue = DamageMeters_GetQuantityValue(DamageMeters_quantity, DMT_VISIBLE, index);

		if (unitValue > maxUnitValue) then
			maxUnitIndex = index;
			maxUnitValue = unitValue;
		end

		totalValue = totalValue + unitValue;
		
		for dmiIndex = 1, DMI_MAX do
			DamageMeters_totals[dmiIndex] = DamageMeters_totals[dmiIndex] + playerStruct.q[dmiIndex];
		end
	end

	-- Total Button
	if (DamageMeters_flags[DMFLAG_showTotal]) then
		if (DamageMeters_quantity == DamageMeters_Quantity_TIME) then
			DamageMeters_TotalButtonText:SetText("-");
		elseif (DamageMeters_IsQuantityPS(DamageMeters_quantity)) then
			DamageMeters_TotalButtonText:SetText(string.format("T=%.1f", totalValue));
		else
			DamageMeters_TotalButtonText:SetText(string.format("T=%d", totalValue));
		end
	end

	-- Tooltip
	if (DamageMetersTooltip:IsOwned(this)) then
		DamageMeters_SetTooltipText();
	end

	----------------------------------

	-- Bar updating.
	if (updateBars) then
		--DMPrintD(string.format("Updating bars. %.3f", currentTime - DamageMeters_lastBarUpdateTime), nil, true);

		DamageMeters_StartDebugTimer(DMPROF_BARS);

		-- Initialize and clear the bars.
		local i;
		for i = 1,DamageMeters_barCount do
			DamageMeters_bars[i]:SetMinMaxValues(0, maxUnitValue);
			DamageMeters_bars[i]:SetValue(0);
			DamageMeters_text[i]:SetText("");
		end
		
		-- Table index of first bar.
		DamageMeters_barStartIndex = 1;
		local playerIndex = DamageMeters_GetPlayerIndex(UnitName("Player"), DMT_VISIBLE);
		if (DMVIEW_MIN == DamageMeters_viewMode) then
			if (not playerIndex) then
				if (DMVIEW_MIN == DamageMeters_viewMode) then
					-- If we are in miniMode we need the player to be in the table: 
					-- add her by giving her some dummy data.
					DamageMeters_AddValue(UnitName("Player"), 0, DM_DOT, DamageMeters_Relation_SELF, DamageMeters_Quantity_HEALINGRECEIVED, nil);
					playerIndex = DamageMeters_GetPlayerIndex(UnitName("Player"), DMT_VISIBLE);
					if (not playerIndex) then
						-- Could fail if the table was full.
						playerIndex = 1;
					end
				else
					playerIndex = 1;
				end
			end
			DamageMeters_barStartIndex = playerIndex;

			if (DamageMeters_lastPlayerPosition ~= DamageMeters_barStartIndex) then
				DMPrintD("Frame dirty: Player index changed..");
				DamageMeters_frameNeedsToBeGenerated = true;
			end
		elseif (DMVIEW_MAX ~= DamageMeters_viewMode and DamageMeters_flags[DMFLAG_playerAlwaysVisible] and (playerIndex ~= nil) and DamageMeters_barCount) then
			-- /script DMPrint(DamageMeters_flags[DMFLAG_playerAlwaysVisible] and "true" or "false");
			--DMPrint("yes", nil, true);
			local nonPlayerBars = DamageMeters_barCount - 1;				-- 0
			local top = ceil(nonPlayerBars / 2);							-- 0
			local first = playerIndex - top;								-- 2
			local last = playerIndex + (nonPlayerBars - top);				-- 2
			local totalBars = table.getn(DamageMeters_tables[DMT_VISIBLE]); -- 2

			if (last > totalBars) then
				first = totalBars - DamageMeters_barCount + 1;
			end
			if (first < 1) then
				first = 1;
			end
			DamageMeters_barStartIndex = first;
		end
		DamageMeters_lastPlayerPosition = playerIndex;

		--DMPrintD(string.format("setting bars %d to %d", DamageMeters_barStartIndex, table.getn(DamageMeters_tables[DMT_VISIBLE])));

		-- Set bar info.
		local barIndex = 1;
		local struct;
		for i,struct in DamageMeters_tables[DMT_VISIBLE] do 
			if (i >= DamageMeters_barStartIndex) then
				if (barIndex <= DamageMeters_barCount) then
					DamageMetersFrame_SetBarInfo(barIndex, i, totalValue, maxUnitValue, p == maxUnitIndex);
					barIndex = barIndex + 1;
				end
			end
		end

		DamageMeters_StopDebugTimer(DMPROF_BARS);
	end

	DamageMeters_lastUpdateTime = currentTime;

	----------------------
	-- Debug End
	DamageMeters_UpdateDebugTimers();
end

function DamageMetersFrame_GenerateFrame(frame)
	if (not frame) then
		frame = DamageMetersFrame;
		if (not frame) then
			return;
		end
	end

	-- Hide the title button if mini mode.
	if (DMVIEW_MIN == DamageMeters_viewMode) then
		DamageMetersFrame_TitleButton:Hide();
	else
		DamageMetersFrame_TitleButton:Show();
	end

	-- Show/hide the total button.
	if (DamageMeters_flags[DMFLAG_showTotal] and not (DMVIEW_MIN == DamageMeters_viewMode)) then
		DamageMetersFrame_TotalButton:Show();
	else
		DamageMetersFrame_TotalButton:Hide();
	end

	-- Hide all bars: update will reshow those that need to be seen.
	local i;
	for i = 1,DamageMeters_BARCOUNT_MAX do
		DamageMeters_bars[i]:Hide();
		DamageMeters_bars[i]:SetValue(0);
		DamageMeters_text[i]:SetText("");
		-- Put all bars under the first bar.
		DamageMeters_bars[i]:SetPoint("TOPLEFT", frame:GetName(), "TOPLEFT", 5, -6);
	end

	--DMPrint("GenerateFrame : bar count = "..DamageMeters_barCount);

	-- Set the size of the frame.
	local rowCount = 0;
	local columnCount = 1;
	local newWidth = 0;
	if (DamageMeters_barCount > (DamageMeters_BARCOUNT_MAX / 2)) then
		rowCount = ceil(DamageMeters_barCount / 2);
		columnCount = 2;
		newWidth = DamageMeters_BARWIDTH * 2 + 10 + 2;
	else
		columnCount = 1;
		rowCount = DamageMeters_barCount;
		newWidth = DamageMeters_BARWIDTH + 10;
	end
	local newHeight = (DamageMeters_BARHEIGHT * rowCount) + 11;

	local oldWidth = frame:GetWidth();
	local oldHeight = frame:GetHeight();

	frame:SetWidth( newWidth );
	frame:SetHeight( newHeight );

	--if (DamageMeters_debugEnabled) then
	--	if (DamageMeters_firstGeneration) then
	--		DMPrintD("Initializing position to "..frame:GetLeft()..", "..frame:GetTop());
	--	end
	--end

	-- Update pos according to resize direction.
	if (not DamageMeters_firstGeneration) then
		if (DamageMeters_flags[DMFLAG_resizeLeft] or DamageMeters_flags[DMFLAG_resizeUp]) then
			--DMPrint("Resizing...");
			local xPos = frame:GetLeft();
			local yPos = frame:GetTop();

			if (DamageMeters_flags[DMFLAG_resizeLeft]) then
				xPos = xPos - (newWidth - oldWidth);
			end
			if (DamageMeters_flags[DMFLAG_resizeUp]) then
				yPos = yPos + (newHeight - oldHeight);
			end

			-- Note: anchoring to bottomleft since apparently the GetLeft and GetTop
			-- values are relative to that point.
			frame:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", xPos, yPos);
		end
	end

	--DMPrint("DamageMeters: "..rowCount.." rows, "..columnCount.." columns.");

	-- Position the bars.
	local name = frame:GetName();
	local row;
	local column;
	for row = 1, rowCount do
		for column = 1, columnCount do
			--DMPrint("Row = "..row..", column = "..column);
			local index = row + (column - 1) * rowCount;
			if (index <= DamageMeters_barCount) then
				local itemButton = DamageMeters_bars[index];
				local itemText = DamageMeters_text[index];

				itemButton:SetWidth(DamageMeters_BARWIDTH);

				local x = 5 + (column - 1) * (DamageMeters_BARWIDTH + 2);
				local y = -6 - (row - 1) * DamageMeters_BARHEIGHT;
				itemButton:SetPoint("TOPLEFT", name, "TOPLEFT", x, y);

				itemText:SetPoint("CENTER", itemButton:GetName(), "CENTER", 0, 0);
				itemText:SetPoint("LEFT", itemButton:GetName(), "LEFT", 0, 0);
				itemText:SetPoint("TOP", itemButton:GetName(), "TOP", 0, 0);
				itemText:SetPoint("RIGHT", itemButton:GetName(), "RIGHT", 0, 0);
				itemText:SetPoint("BOTTOM", itemButton:GetName(), "BOTTOM", 0, 0);

				-- Justify text
				if (DMVIEW_MIN == DamageMeters_viewMode or DamageMeters_flags[DMFLAG_justifyTextLeft]) then
					itemText:SetJustifyH("LEFT");
				else
					itemText:SetJustifyH("CENTER");
				end
			end
		end
	end

	DamageMeters_SetBackgroundColor();

	DamageMeters_frameNeedsToBeGenerated = false;
	DamageMeters_firstGeneration = false;
end

function DamageMetersFrame_SetBarInfo(barIndex, tableIndex, totalValue, maxValue, isMax)
	--DMPrintD("DamageMetersFrame_SetBarInfo, barIndex = "..barIndex..", totalValue = "..totalValue..", maxValue = "..maxValue);

	local red = 0.00;
	local green = 0.00;
	local blue = 0.00;
	local barString = "";

	local tableEntry = DamageMeters_tables[DMT_VISIBLE][tableIndex];
	local player = tableEntry.player;
	local dmi = DamageMeters_GetQuantityDMI(DamageMeters_quantity);
	local age;
	if (DamageMeters_Quantity_TIME == DamageMeters_quantity) then
		age = GetTime() - tableEntry.lastTime;
	elseif (dmi ~= nil) then
		age = GetTime() - tableEntry.lastQuantTime[dmi];
	else
		-- This case covers quantities without dmis (and hence no last times).
		-- Could put a system in for calculating it, but I doubt we really care.
		age = 60;
	end

	local relationship = tableEntry.relationship;
	if (DMVIEW_MIN == DamageMeters_viewMode) then
		local color = DamageMeters_quantityColor[DamageMeters_quantity];
		red = color[1];
		green = color[2] 
		blue = color[3];
	else
		if (DamageMeters_colorScheme == 1) then
			if (DamageMeters_Relation_SELF == relationship) then
				green = 1.00;
			elseif (DamageMeters_Relation_PET == relationship) then
				green = 0.80;
			elseif (DamageMeters_Relation_PARTY == relationship) then
				blue = 1.00;
			elseif (DamageMeters_Relation_FRIENDLY == relationship) then
				red = 1.00;
				green = 0.50;
			end
		else
			local class = tableEntry.class;
			if (class) then
				local color = DamageMeters_GetClassColor(class);
				red = color.r;
				green = color.g;
				blue = color.b;
			elseif (DamageMeters_Relation_PET == relationship) then
				red = 0.00;
				green = 0.80;
				blue = 0.00;
			else
				red = 0.70;
				green = 0.70;
				blue = 0.70;
			end
		end
	end

	-- Bar color pulse magnitude.
	local pulseMag = 0.00;
	if (DamageMeters_flags[DMFLAG_constantVisualUpdate]) then
		if (age < DamageMeters_PULSE_TIME) then
			pulseMag = 1.00 - age / DamageMeters_PULSE_TIME;
		end
	end

	-- Calc value
	local value;
	local dmi = DamageMeters_GetQuantityDMI(DamageMeters_quantity);
	if (DamageMeters_quantity == DamageMeters_Quantity_TIME) then
		value = age;
	else
		value = DamageMeters_GetQuantityValue(DamageMeters_quantity, DMT_VISIBLE, tableIndex);
	end


	-- TEXT --
	local stateAge = GetTime() - DamageMeters_textStateStartTime;
	local barAge = stateAge - (barIndex / DamageMeters_barCount) * (DamageMeters_BARFADEINMINTIME + DamageMeters_BARFADEINTIME * DamageMeters_barCount);

	if ((barAge > 0) or (not DamageMeters_flags[DMFLAG_constantVisualUpdate])) then
		-- DamageMeters_Text_MAX many entries.
		local rankString = nil;
		local nameString = nil;
		local totalPercentString = nil;
		local leaderPercentString = nil;
		local valueString = nil;

		-- Rank
		if (DMVIEW_MIN == DamageMeters_viewMode or
			((DamageMeters_textState > 0 and DamageMeters_textState == DamageMeters_Text_RANK) or
			(DamageMeters_textState <= 0 and DamageMeters_textOptions[DamageMeters_Text_RANK]))) then
			rankString = tostring(tableIndex);
		end

		-- Name
		if (not (DMVIEW_MIN == DamageMeters_viewMode)) then
			if ((DamageMeters_textState > 0 and DamageMeters_textState == DamageMeters_Text_NAME) or
				(DamageMeters_textState <= 0 and DamageMeters_textOptions[DamageMeters_Text_NAME])) then
				nameString = player;
			end
		end

		-- Total Percentage
		if (DamageMeters_Quantity_TIME ~= DamageMeters_quantity and totalValue ~= nil and (not DamageMeters_IsQuantityPS(DamageMeters_quantity) or (not DamageMeters_flags[DMFLAG_showFightAsPS]))) then
			if ((DamageMeters_textState > 0 and DamageMeters_textState == DamageMeters_Text_TOTALPERCENTAGE) or
				(DamageMeters_textState <= 0 and DamageMeters_textOptions[DamageMeters_Text_TOTALPERCENTAGE])) then
				local percent = (totalValue > 0) and ((value / totalValue) * 100) or 0;
				totalPercentString = string.format("%.2f%%", percent);
			end
		end

		-- Leader Percentage
		if (DamageMeters_Quantity_TIME ~= DamageMeters_quantity and totalValue ~= nil and (not DamageMeters_IsQuantityPS(DamageMeters_quantity) or (not DamageMeters_flags[DMFLAG_showFightAsPS]))) then
			if ((DamageMeters_textState > 0 and DamageMeters_textState == DamageMeters_Text_LEADERPERCENTAGE) or
				(DamageMeters_textState <= 0 and DamageMeters_textOptions[DamageMeters_Text_LEADERPERCENTAGE])) then
				local percent = (maxValue > 0) and ((value / maxValue) * 100) or 0;
				leaderPercentString = format("%.2f%%", percent);
			end
		end

		-- Value
		local buildValueString = false;
		if (DamageMeters_textState > 0 and DamageMeters_textState == DamageMeters_Text_VALUE) then
			buildValueString = true;
		elseif (DamageMeters_textState <= 0 and DamageMeters_textOptions[DamageMeters_Text_VALUE]) then
			buildValueString = true;
		elseif (DamageMeters_textState == 0 and 
				(DamageMeters_quantity == DamageMeters_Quantity_TIME or DamageMeters_IsQuantityPS(DamageMeters_quantity))) then
			buildValueString = true;
		end
	
		if (buildValueString) then
			if (DamageMeters_quantity == DamageMeters_Quantity_TIME) then
				valueString = string.format("%d:%.2d", value / 60, math.mod(value, 60));
			elseif (DamageMeters_IsQuantityPS(DamageMeters_quantity)) then
				valueString = string.format("%.1f", value);
			else
				valueString = tostring(value);
			end
		end

		-- Concatenate strings.
		local strIx;
		local first = true;
		if (rankString) then
			barString = barString..rankString.." ";
		end
		if (nameString) then
			barString = barString..nameString.." ";
		end
		if (totalPercentString) then
			barString = barString..totalPercentString.." ";
		end
		if (leaderPercentString) then
			barString = barString..leaderPercentString.." ";
		end
		if (valueString) then
			barString = barString..valueString;
		end
		if (string.sub(barString, -1) == " ") then
			barString = string.sub(barString, 1, -2);
		end
	end

	--[[ Removed for optimization.
	-- Apply pulse.
	if (red == 1.00 and green == 1.00 and blue == 1.00) then
		red = 0.5 + 0.5 * (1.0 - pulseMag);
		green = red;
		blue = red;
	else
		red = pulseMag > red and pulseMag or red;
		green = pulseMag > green and pulseMag or green;
		blue = pulseMag > blue and pulseMag or blue;
	end
	]]--

	-------

	if (DamageMeters_flags[DMFLAG_constantVisualUpdate]) then
		if (barAge > 0) then
			local charsToShow = floor(barAge / DamageMeters_BARCHARTIME);
			local strLen = string.len(barString);
			if (strLen > charsToShow) then
				local charsToRemove = strLen - charsToShow;
				local leftToRemove, rightToRemove;
				if (DMVIEW_MIN == DamageMeters_viewMode) then
					leftToRemove = 0;
					rightToRemove = charsToRemove;
				else
					leftToRemove = floor(charsToRemove / 2);
					rightToRemove = charsToRemove - leftToRemove;
				end

				barString = string.sub(barString, leftToRemove, -rightToRemove);
			end
		end
	end

	if (DMVIEW_MIN == DamageMeters_viewMode) then
		local titleText = DamageMeters_GetPausedTitleText();
		if (titleText) then
			barString = titleText.." "..barString;
		end
	end

	DamageMeters_bars[barIndex]:Show();
	DamageMeters_bars[barIndex]:SetStatusBarColor(red, green, blue);
	DamageMeters_bars[barIndex]:SetValue(value);
	DamageMeters_text[barIndex]:SetText(barString);
	-- After 1300 patch text wouldn't appear without this.
	DamageMeters_text[barIndex]:Show();
end

-------------------------------------------------------------------------------

function DamageMeters_Clear(leave, silent)
	-- Clear contributor list full: on a partical clear it is impossible to
	-- tell who contributed what.
	DamageMeters_contributorList = {};
	DamageMeters_flags[DMFLAG_haveContributors] = false;

	--Threat ThreatMeters_Clear();

	DamageMeters_DoClear(DMT_ACTIVE, leave, silent)
	DamageMeters_DoClear(DMT_FIGHT, 0, true)
end

function DamageMeters_DoClear(tableIndex, leave, silent)
	DMPrintD("DamageMeters_DoClear("..tableIndex..")");

	DamageMeters_tablesDirty = true;

	-- In case we get a clear call between ticks.
	DamageMeters_queuedChainHealCount = 0;

	local last = table.getn(DamageMeters_tables[tableIndex]);
	if (last == 0) then
		-- This line just to ensure its really wiped out.
		DamageMeters_tables[tableIndex] = {};
		return;
	end

	local first = 1;
	if (leave ~= nil) then
		--DMPrint("leave = '"..leave.."'");
		local c = tonumber(leave);
		if (c) then
			first = leave + 1;
			if (first < 1) then
				first = 1;
			end
		end
	end

	if (not silent) then
		DMPrint(format(DM_MSG_CLEAR, first, last));
	end

	local i;
	for i = last,first,-1 do
		if (DamageMeters_flags[DMFLAG_constantVisualUpdate]) then
			if (tableIndex == DMT_VISIBLE) then
				if (DamageMeters_bars[i]) then
					DamageMeters_bars[i]:SetValue(0);
					DamageMeters_text[i]:SetText("");
				end
			end
		end

		table.remove(DamageMeters_tables[tableIndex]);
	end

	--if (not silent) then
	--	DMPrint(format(DM_MSG_REMAINING, table.getn(DamageMeters_tables[DMT_ACTIVE])));
	--end
end


function DamageMeters_Test(countArg)
	DamageMeters_Clear();

	local count = DamageMeters_barCount;
	if (countArg) then
		count = tonumber(countArg);
		if (not count) then
			count = DamageMeters_barCount
		end

		if (count > DamageMeters_barCount) then
			count = DamageMeters_barCount;
		end
	end

	DamageMeters_lastEvent = {};

	DMPrintD("Adding "..count.." test entries...");
	local index;
	local groupMembersOnlySave = DamageMeters_flags[DMFLAG_groupMembersOnly];
	DamageMeters_flags[DMFLAG_groupMembersOnly] = false;
	for index = 1,count do
		DamageMeters_AddValue("Test"..index, 1*index, DM_HIT, DamageMeters_Relation_FRIENDLY, DamageMeters_Quantity_DAMAGE, "[Test]");
		DamageMeters_AddValue("Test"..index, 2*index, DM_HIT, DamageMeters_Relation_FRIENDLY, DamageMeters_Quantity_HEALING, "[Test]");
		DamageMeters_AddValue("Test"..index, 3*(count - index), DM_HIT, DamageMeters_Relation_FRIENDLY, DamageMeters_Quantity_DAMAGED, "[Test]");
		DamageMeters_AddValue("Test"..index, 4*(count - index), DM_HIT, DamageMeters_Relation_FRIENDLY, DamageMeters_Quantity_HEALINGRECEIVED, "[Test]");
	end
	DamageMeters_flags[DMFLAG_groupMembersOnly] = groupMembersOnlySave;
end

function DamageMeters_Add(player)
	if (player) then
		DamageMeters_AddDamage(player, 0, DM_HIT, DamageMeters_Relation_FRIENDLY, "[Test]");
	end
end

function DamageMeters_SetSort(sortArg)
	local usage = true;
	if (sortArg) then
		local sort = tonumber(sortArg);
		if (sort) then
			if (sort >= 1 and sort <= DamageMeters_Sort_MAX) then
				DamageMeters_sort = sort;
				DamageMeters_tablesDirty = true;
				DMPrint(DM_MSG_SORT..DamageMeters_sort);
				usage = false;
			else
				DMPrint(DM_ERROR_INVALIDARG);
			end
		end
	end

	if (usage) then
		DMPrint(DM_MSG_CURRENTSORT..DamageMeters_Sort_STRING[DamageMeters_sort]);
		local i;
		for i=1,DamageMeters_Sort_MAX do
			DMPrint(" "..i..": "..DamageMeters_Sort_STRING[i]);
		end
	end
end

function DamageMeters_SetQuantity(quantArg, bSilent)
	local usage = true;
	if (quantArg) then
		local quant = tonumber(quantArg);
		if (quant) then
			if (quant >= 1 and quant <= DamageMeters_Quantity_MAX) then
				DamageMeters_quantity = quant;
				if (not bSilent) then
					DMPrint(DM_MSG_SETQUANT..DM_QUANTDEFS[DamageMeters_quantity].name);
				end
				usage = false;
			else
				if (not bSilent) then
					DMPrint(DM_ERROR_INVALIDARG);
				end
			end
		end
	end

	if (usage) then
		DMPrint(DM_MSG_CURRENTQUANT..DM_QUANTDEFS[DamageMeters_quantity].name);
		local i;
		for i=1,DamageMeters_Quantity_MAX do
			DMPrint(" "..i..": "..DM_QUANTDEFS[i].name);
		end
	end

	DamageMeters_SetBackgroundColor();
	--DMPrintD("Frame dirty: quantity changed.");
	DamageMeters_frameNeedsToBeGenerated = true;
	DamageMeters_currentQuantStartTime = GetTime();

	-- If a Fight quantity, make the visible table the combat table.
	if (DamageMeters_IsQuantityFight(DamageMeters_quantity)) then
		--DMPrintD("Visible table set to Combat");
		DMT_VISIBLE = DMT_FIGHT;
	else
		--DMPrintD("Visible table set to Active");
		DMT_VISIBLE = DMT_ACTIVE;
	end
end

function DamageMeters_SetBackgroundColor()
	local frame = DamageMetersFrame;
	if (frame) then
		local color = DamageMeters_quantityColor[DamageMeters_quantity];
		local titleR, titleG, titleB, titleA = DamageMeters_GetTitleButtonColors();

		if (DMVIEW_MIN == DamageMeters_viewMode) then
			frame:SetBackdropColor(titleR, titleG, titleB, titleA);
		else
			frame:SetBackdropColor(color[1], color[2], color[3], color[4]);
		end

		-- Set title button text.
		local pausedText = DamageMeters_GetPausedTitleText();
		if (pausedText) then
			DamageMeters_TitleButtonText:SetText(pausedText);
		else
			if (DamageMeters_IsQuantityPS(DamageMeters_quantity)) then
				local title;
				local combatTime = DamageMeters_combatEndTime - DamageMeters_combatStartTime;
				if (combatTime > 60) then
					title = format("%s %d:%.2d", DM_QUANTDEFS[DamageMeters_quantity].psName, combatTime / 60, math.mod(combatTime, 60));
				else
					title = format("%s %.1fs", DM_QUANTDEFS[DamageMeters_quantity].psName, combatTime);
				end
				DamageMeters_TitleButtonText:SetText(title);
			else
				local title = DM_QUANTDEFS[DamageMeters_quantity].name;
				DamageMeters_TitleButtonText:SetText(title);
			end
		end

		-- Set title button color.
		DamageMetersFrame_TitleButton:SetBackdropColor(titleR, titleG, titleB, titleA);

		-- Set total button color.
		DamageMetersFrame_TotalButton:SetBackdropColor(color[1], color[2], color[3], color[4]);
	end
end

function DamageMeters_GetPausedTitleText()
	local time = GetTime();
	local showPausedText = false;
	
	if (DMVIEW_MIN ~= DamageMeters_viewMode) then
		if (DM_Pause_Not == DamageMeters_pauseState) then
			return nil;
		else
			local flooredTime = floor(time);
			if (math.mod(flooredTime, 4) > 1) then
				return nil;
			end
		end
	end

	if (DM_Pause_Paused == DamageMeters_pauseState) then
		return DM_MSG_PAUSEDTITLE;
	elseif (DM_Pause_Ready == DamageMeters_pauseState) then
		return DM_MSG_READYTITLE;
	end

	return nil;
end

function DamageMeters_GetTitleButtonColors()
	local color = DamageMeters_quantityColor[DamageMeters_quantity];
	if (DM_Pause_Ready == DamageMeters_pauseState) then
		local time = GetTime();
		local pulseFactor = 1.0 - (time * 0.5 - floor(time * 0.5));
		return color[1] * pulseFactor, color[2] * pulseFactor, color[3] * pulseFactor, 1.0;
	elseif (DM_Pause_Paused == DamageMeters_pauseState) then
		return 0.0, 0.0, 0.0, color[4];
	end

	return color[1], color[2], color[3], color[4];
end

function DamageMeters_SetRelationship(index, relationship)
	if (nil == relationship) then
		DMPrintD("DamageMeters_SetRelationship ("..DamageMeters_tables[DMT_ACTIVE][index].player.."), relationship = nil.");
		relationship = DamageMeters_Relation_FRIENDLY;
	end

	relationship = tonumber(relationship);

	if (relationship < 1 or relationship > DamageMeters_Relation_MAX) then
		DMPrintD("DamageMeters_SetRelationship ("..DamageMeters_tables[DMT_ACTIVE][index].player.."), relationship = "..relationship);
		relationship = DamageMeters_Relation_FRIENDLY;
	end
	DamageMeters_tables[DMT_ACTIVE][index].relationship = relationship;
	--Print("relationship = "..relationship);

	if (relationship == DamageMeters_Relation_SELF) then
		DamageMeters_tables[DMT_ACTIVE][index].class = UnitClass("player");
		--Print("Adding self, class = "..DamageMeters_tables[DMT_ACTIVE][index].class);
	elseif (relationship == DamageMeters_Relation_PARTY) then
		local i;
		for i=1,5 do
			local partyUnitName = "party"..i;
			local partyName = UnitName(partyUnitName);
			if (partyName == DamageMeters_tables[DMT_ACTIVE][index].player) then
				DamageMeters_tables[DMT_ACTIVE][index].class = UnitClass(partyUnitName);
				--Print("Party member found: index = "..i..", class = "..DamageMeters_tables[DMT_ACTIVE][index].class);
				return relationship;
			end
		end
	else
		DamageMeters_UpdateRaidMemberClasses();
	end

	return relationship;
end

function DamageMeters_AddValue(player, amount, crit, relationship, quantity, spell, damageType)
	if (nil == player) then
		DMPrint("DamageMeters: INTERNAL ERROR! player = nil.");
		return 0;
	end
	if (nil == quantity) then
		DMPrint("DamageMeters: INTERNAL ERROR! quantity = nil.");
	end

	if (DM_UNKNOWNENTITY == player) then
		return 0;
	end

	if (DamageMeters_debugEnabled) then
		if (string.find(player, "Julie's") or
			string.find(player, "Night Dragon")) then
			DMPrintD(string.format("HEY!: Player = %s, spell = %s", player, spell));
			DMPrintD(string.format("[%s]: %s (%s)", DamageMeters_lastEvent.event, DamageMeters_lastEvent.fullMsg, DamageMeters_lastEvent.desc));
		end
	end

	if (DamageMeters_debug3.msgWatchMode) then
		if (spell ~= "[Msg]") then
			return 0;
		end
	end

	-- Because sometimes messages say "x dmg done by spell."/"x dmg done by spell (blah absorbed)", the
	-- spell sometimes appears as "spell.".  This code strips it off.
	if (spell ~= nil and "." == string.sub(spell, -1)) then
		--DMPrint("Stripping period from spell "..spell);
		spell = string.sub(spell, 1, -2);
	end

	if (relationship == nil) then
		DMPrintD("Relationship = nil, player("..player.."), amount("..amount.."), quantity("..quantity..")");
		relationship = DamageMeters_Relation_FRIENDLY;
	end

	-- Fix pet relationship if necessary.
	if (DamageMeters_Relation_PET ~= relationship and player == UnitName("Pet")) then
		--DMPrintD("Fixing Pet Relationship: spell = "..spell, nil, true);
		relationship = DamageMeters_Relation_PET;
	end

	-- Assign to self if it is a pet and the option is set.
	if (DamageMeters_flags[DMFLAG_addPetToPlayer] and relationship == DamageMeters_Relation_PET) then
		relationship = DamageMeters_Relation_SELF;
		player = UnitName("Player");
	end

	amount = tonumber(amount);
	relationship = tonumber(relationship);
	local currentTime = GetTime();

	--DMPrint("DamageMeters_AddValue : relationship = "..relationship);

	local index = DamageMeters_GetPlayerIndex(player);
	local found = (index ~= nil);
	if (nil == index) then

		-- Reject if list locked.
		if (DamageMeters_listLocked) then
			return 0;
		end
		
		-- Reject if list full.
		if (table.getn(DamageMeters_tables[DMT_ACTIVE]) >= DamageMeters_TABLE_MAX) then
			return 0;
		end

		-- Reject if player is banned.
		if (DamageMeters_IsBanned(player)) then
			--DMPrintD("Rejecting banned player "..player);
			return 0;
		end

		-- Reject if we are excluding non-group members.
		-- This code lets the player's pets through, btw.
		if (DamageMeters_flags[DMFLAG_groupMembersOnly] and 
				(DamageMeters_Relation_PARTY == relationship or DamageMeters_Relation_FRIENDLY == relationship)) then
			local foundRelation = DamageMeters_GetGroupRelation(player);
			if (foundRelation < 0) then
				--DMPrintD(player.." not in party or raid, rejecting.");
				return 0;
			end
		end

		-- ** At this point we've determined the value is ok to add to the table. **

		-- If we are "ready", unpause.
		if (DamageMeters_DoReadyCheck(quantity, spell)) then
			return;
		end

		if (quantity == DamageMeters_Quantity_DAMAGE and spell ~= DM_SYNCSPELLNAME) then
			if (DamageMeters_startCombatOnNextValue) then
				DamageMeters_startCombatOnNextValue = false;
				if (DamageMeters_flags[DMFLAG_resetWhenCombatStarts]) then
					DamageMeters_Clear(0, true);
				end
				DamageMeters_OnCombatStart();
			end
		end

		-- OK: Add the new player.
		index = DamageMeters_AddNewPlayer(DamageMeters_tables[DMT_ACTIVE], player);
		relationship = DamageMeters_SetRelationship(index, relationship);

		if (index <= DamageMeters_barCount) then
			DamageMeters_bars[index]:Show();
		end
	else
		-- If we are "ready", unpause.
		if (DamageMeters_DoReadyCheck(quantity, spell)) then
			return;
		end

		if (DamageMeters_startCombatOnNextValue and quantity == DamageMeters_Quantity_DAMAGE) then
			DamageMeters_startCombatOnNextValue = false;
			if (DamageMeters_flags[DMFLAG_resetWhenCombatStarts]) then
				DamageMeters_Clear(0, true);
			end
			DamageMeters_OnCombatStart();

			-- Very dangerous!  Recursing here.
			DamageMeters_AddValue(player, amount, crit, relationship, quantity, spell);
			return;
		end

		if (relationship < DamageMeters_tables[DMT_ACTIVE][index].relationship) then
			DMPrintD("Updating "..player.."'s relationship from "..DamageMeters_tables[DMT_ACTIVE][index].relationship.." to "..relationship);
			relationship = DamageMeters_SetRelationship(index, relationship);
		end
	end

	-- ADD THE DATA TO THE MAIN TABLE
	--DMPrintD("DamageMeters_UpdateTableEntry active");
	DamageMeters_UpdateTableEntry(DMT_ACTIVE, index, quantity, amount, crit, found, relationship, spell, damageType);

	-----------------------------------------------------------------
	-- This is where the data gets added to the combat table.

	if (DamageMeters_inCombat) then
		local combatIndex = DamageMeters_GetPlayerIndex(player, DMT_FIGHT);
		if (nil == combatIndex) then
			combatIndex = DamageMeters_AddNewPlayer(DamageMeters_tables[DMT_FIGHT], player);
			-- Relationship and class is tricky: copy it directly from the main table.
			DamageMeters_tables[DMT_FIGHT][combatIndex].relationship = relationship;
			DamageMeters_tables[DMT_FIGHT][combatIndex].class = DamageMeters_tables[DMT_ACTIVE][index].class;
		end

		-- ADD THE DATA TO THE COMBAT TABLE
		--DMPrintD("DamageMeters_UpdateTableEntry combat");
		DamageMeters_UpdateTableEntry(DMT_FIGHT, combatIndex, quantity, amount, crit, found, relationship, spell, damageType);
	end

	-----------------------------------------------------------------
	-- This is where data is accumulated to the memory table.

	if (DamageMeters_flags[DMFLAG_accumulateToMemory]) then
		local memIndex = DamageMeters_GetPlayerIndex(player, DMT_SAVED);
		if (nil == memIndex) then
			memIndex = DamageMeters_AddNewPlayer(DamageMeters_tables[DMT_SAVED], player);
			-- Relationship is tricky: copy it directly from the main table.
			DamageMeters_tables[DMT_SAVED][memIndex].relationship = relationship;
			DamageMeters_tables[DMT_SAVED][memIndex].class = DamageMeters_tables[DMT_ACTIVE][index].class;
		end
	
		DamageMeters_UpdateTableEntry(DMT_SAVED, memIndex, quantity, amount, crit, found, relationship, spell, damageType);

		-- Take time from master table.
		DamageMeters_tables[DMT_SAVED][memIndex].lastTime = DamageMeters_tables[DMT_ACTIVE][index].lastTime;
	end

	-----------------------------------------------------------------

	if (DamageMeters_Quantity_DAMAGE == quantity or DamageMeters_Quantity_DAMAGED == quantity) then
		DamageMeters_lastEventTime = currentTime;
	end

	if (DamageMeters_debug3.showValueChanges) then
		DMPrint(format("Added %d %s to %s from %s.", amount, DM_QUANTDEFS[quantity].name, DamageMeters_tables[DMT_ACTIVE][index].player, spell), nil, true);
	end

	-- Debug info.
	if (DamageMeters_lastEvent.event and DamageMeters_lastEvent.event ~= "") then
		DamageMeters_tables[DMT_ACTIVE][index].firstMsg = {};
		DamageMeters_tables[DMT_ACTIVE][index].firstMsg.event = DamageMeters_lastEvent.event;
		DamageMeters_tables[DMT_ACTIVE][index].firstMsg.desc = DamageMeters_lastEvent.desc;
		DamageMeters_tables[DMT_ACTIVE][index].firstMsg.fullMsg = DamageMeters_lastEvent.fullMsg;

		DamageMeters_lastEvent = {};
	end

	return index;
end

function DamageMeters_UpdateTableEntry(destTableIndex, index, quantity, amount, crit, existingEntry, relationship, spell, damageType)
	DamageMeters_tablesDirty = true;

	local destTable = DamageMeters_tables[destTableIndex];

	-----------------------------------------------------------------
	-- This is where the table entry gets modified with the new data.

	if (index == nil) then
		DMPrintD("index = nil, spell = "..spell);
	end
	if (quantity == nil) then
		DMPrintD("quantity = nil, spell = "..spell);
	end

	-- Lookup the DMI.
	local dmi = DM_QUANTDEFS[quantity].dmi;

	-- Update quantity.
	--DMPrintD("index = "..index..", quantity = "..quantity);
	destTable[index].q[dmi] = destTable[index].q[dmi] + amount;

	-- Update crit count.
	if (crit ~= DM_DOT) then
		destTable[index].hitCount[dmi] = destTable[index].hitCount[dmi] + 1;
		if (crit == DM_CRIT) then
			destTable[index].critCount[dmi] = destTable[index].critCount[dmi] + 1;
		end
	end

	-- We use amount = 0 just to add empty people to the list.  
	-- Only update time if it was because of a player action.
	if (existingEntry and (amount > 0) and (dmi == DMI_DAMAGE or dmi == DMI_HEALING)) then
		destTable[index].lastTime = GetTime();
	end
	destTable[index].lastQuantTime[dmi] = GetTime();

	-----------------------------------------------------------------
	-- Event Data collection. --

	if (spell and 
		spell ~= DM_SYNCSPELLNAME and
		((DamageMeters_eventDataLevel == DamageMeters_EventData_ALL) or 
		 (DamageMeters_eventDataLevel == DamageMeters_EventData_SELF and (DamageMeters_Relation_SELF == relationship)))) then

		-- Special case for Chain Heal.
		-- If we get one, queue into a global array.  Chain heal messages come in reverse order
		-- (smallest to biggest) and all in the same frame.  At the next tick a bit of code in Update
		-- adds fake events for them (fake events have a * at the end and aren't counted towards 
		-- totals.
		if (destTableIndex == DMT_ACTIVE and
			DamageMeters_Relation_SELF == relationship and 
			"Chain Heal" == spell and
			DamageMeters_Quantity_HEALING == quantity and
			DamageMeters_waitingForChainHeal) then

			DamageMeters_queuedChainHealCount = DamageMeters_queuedChainHealCount + 1;
			DamageMeters_queuedChainHealValue[DamageMeters_queuedChainHealCount] = amount;
			DamageMeters_queuedChainHealCrit[DamageMeters_queuedChainHealCount] = crit;

			--DMPrintD("Chain Heal cast for "..amount);
		end

		DamageMeters_AddEvent(destTableIndex, index, quantity, spell, amount, crit, relationship, damageType);
	end
end

function DamageMeters_StartChainHeal()
	DamageMeters_queuedChainHealCount = 0;
	DamageMeters_waitingForChainHeal = true;
end

function DamageMeters_DebugError(msg)
	DMPrint(msg);
	DamageMeters_SendSyncMsg("ERROR: "..msg);
end

function DamageMeters_AddEvent(destTableIx, index, quantity, spell, amount, crit, relationship, damageType)
	local destTable = DamageMeters_tables[destTableIx];
	local countIndex = crit;
	if (crit == DM_DOT) then
		countIndex = DM_HIT;

		if ((string.sub(spell, 1, 1) ~= "[")) then
			if (quantity == DamageMeters_Quantity_HEALING or
				quantity == DamageMeters_Quantity_HEALINGRECEIVED) then
				spell = spell.." [HOT]";
			else
				spell = spell.." [DOT]";
			end
		end
	end
	
	-- Beta error handling--this shouldn't ever happen, think I fixed the bug elsewhere.
	-- (Calls to this function not using proper table's index).
	if (not index) then
		DamageMeters_DebugError("DamageMeters_AddEvent index = nil.  Spell = "..spell);
		return;
	end
	if (index == 0) then
		DamageMeters_DebugError("DamageMeters_AddEvent index = 0.  Spell = "..spell);
		return;
	end
	if (not quantity or quantity == 0) then
		DamageMeters_DebugError("DamageMeters_AddEvent bad quantity.  Spell = "..spell);
		return;
	end
	if (not destTable[index]) then
		DamageMeters_DebugError("DamageMeters_AddEvent destTable["..index.."] = nil.  Spell = "..spell);
		return;
	end

	-- Lookup the DMI.
	local dmi = DM_QUANTDEFS[quantity].dmi;

	if (not destTable[index].events) then
		destTable[index].events = {};
	end
	if (not destTable[index].events[dmi]) then
		--DMPrintD("EventTable: Adding dmi "..dmi);
		destTable[index].events[dmi] = {};
		destTable[index].events[dmi].spellTable = {};
		destTable[index].events[dmi].hash = {};
		destTable[index].events[dmi].dirty = true;
	end
	if (not destTable[index].events[dmi].spellTable[spell]) then
		--DMPrintD("EventTable: Adding spell "..spell);
		destTable[index].events[dmi].spellTable[spell] = {};
		destTable[index].events[dmi].spellTable[spell].value = 0;
		destTable[index].events[dmi].spellTable[spell].counts = {0,0};
		destTable[index].events[dmi].spellTable[spell].damageType = DM_DMGTYPE_DEFAULT;
		destTable[index].events[dmi].spellTable[spell].resistanceSum = 0;
		destTable[index].events[dmi].spellTable[spell].resistanceCount = 0;
	end
	destTable[index].events[dmi].spellTable[spell].value = destTable[index].events[dmi].spellTable[spell].value + amount;
	destTable[index].events[dmi].spellTable[spell].counts[countIndex] = destTable[index].events[dmi].spellTable[spell].counts[countIndex] + 1;

	if (relationship == DamageMeters_Relation_SELF and dmi == DMI_DAMAGED) then
		local dmgType = DM_DMGTYPE_DEFAULT;
		local resistance = 0;
		if (damageType) then
			dmgType = DM_DMGNAMETOID[damageType];

			if (nil == dmgType) then
				DMPrintD("ERROR: Unrecognized damage type >"..damageType.."<, fixing.");
				dmgType = DM_DMGTYPE_DEFAULT;
			end

			if (destTable[index].events[dmi].spellTable[spell].damageType ~= DM_DMGTYPE_DEFAULT and
				destTable[index].events[dmi].spellTable[spell].damageType ~= dmgType) then
				DMPrintD("Switching types from "..destTable[index].events[dmi].spellTable[spell].damageType .." to "..dmgType);
			end

			destTable[index].events[dmi].spellTable[spell].damageType = dmgType;
			resistance = DamageMeters_GetResistance(dmgType);

			--DMPrintD(spell..": "..damageType.." damage, "..resistance.." resistance.");

			destTable[index].events[dmi].spellTable[spell].resistanceSum = destTable[index].events[dmi].spellTable[spell].resistanceSum + resistance;
			destTable[index].events[dmi].spellTable[spell].resistanceCount = destTable[index].events[dmi].spellTable[spell].resistanceCount + 1;
		end
	end

	destTable[index].events[dmi].hash = {};
	destTable[index].events[dmi].dirty = true;

	if (crit == DM_CRIT) then
		destTable[index].events[dmi].spellTable[spell].counts[DM_HIT] = destTable[index].events[dmi].spellTable[spell].counts[DM_HIT] + 1;
	end
end

function DamageMeters_DoReadyCheck(quantity, spell)
	if (DM_Pause_Ready == DamageMeters_pauseState) then
		if (DamageMeters_Quantity_DAMAGE == quantity or DamageMeters_Quantity_DAMAGED == quantity) then
			if (DM_DMG_FALLING == spell or DM_DMG_LAVA == spell or DM_SYNCSPELLNAME == spell) then
				return true;
			else
				if (DamageMeters_CheckSyncChan(true)) then
					DMPrint(DM_MSG_READYUNPAUSING, nil, true);
				end
				DamageMeters_SyncUnpause(true, spell);
			end
		else
			return true;
		end
	end

	return false;
end

function DamageMeters_AddNewPlayer(destTable, player)
	--DMPrintD("Adding player "..player);

	local now = GetTime();

	local index = table.getn(destTable) + 1;
	table.setn(destTable, index);
	destTable[index] = {};
	destTable[index].hitCount = {};
	destTable[index].critCount = {};
	destTable[index].lastQuantTime = {};
	destTable[index].q = {};
	local quant;
	for quant = 1, DMI_MAX do
		destTable[index].q[quant] = 0;
		destTable[index].hitCount[quant] = 0;
		destTable[index].critCount[quant] = 0;
		destTable[index].lastQuantTime[quant] = now;
	end
	destTable[index].player = player;
	destTable[index].lastTime = now;
	destTable[index].damageThisCombat = 0;

	return index;
end

function DamageMeters_GetResistance(resistId)
	if (resistId < DM_DMGTYPE_ARCANE or resistId > DM_DMGTYPE_SHADOW) then
		return 0;
	end

	local base, resistance, positive, negative;
	local frame = getglobal("MagicResFrame"..resistId);
	base, resistance, positive, negative = UnitResistance("player", frame:GetID());
	return resistance;
end

function DamageMeters_AddDamage(player, amount, crit, relationship, spell)
	DamageMeters_StopDebugTimer(DMPROF_PARSEMESSAGE);

	DamageMeters_StartDebugTimer(DMPROF_ADDVALUE);
	DamageMeters_AddValue(player, amount, crit, relationship, DamageMeters_Quantity_DAMAGE, spell);
	DamageMeters_StopDebugTimer(DMPROF_ADDVALUE);
end

function DamageMeters_AddDamageReceived(player, amount, crit, relationship, spell, damageType, resisted)
	DamageMeters_StopDebugTimer(DMPROF_PARSEMESSAGE);

	DamageMeters_StartDebugTimer(DMPROF_ADDVALUE);
	local index = DamageMeters_AddValue(player, amount, crit, relationship, DamageMeters_Quantity_DAMAGED, spell, damageType);
	--Threat ThreatMeters_UpdateUnit(player, amount);
	DamageMeters_StopDebugTimer(DMPROF_ADDVALUE);
end

--[[ work in progress
function DamageMeters_GetUnitID(entity, relationship)
	if (relationship == DamageMeters_Relation_SELF) then
		return "player";
	elseif (relationship == DamageMeters_Relation_PET) then
		return "pet";
	elseif (relationship == DamageMeters_Relation_PARTY) then
		for i=1,5 do
			local partyUnitName = "party"..i;
			local partyName = UnitName(partyUnitName);
			if (partyName and partyName ~= "" and partyName == entity) then
				return partyUnitName;
			end
		end
	elseif (relationship == DamageMeters_Relation_FRIENDLY) then
		for index = 1, GetNumRaidMembers() do
			if (entity == GetRaidRosterInfo(index)) then
				return "raid"..index;
			end
		end
	end
	
	return nil;
end
]]--

function DamageMeters_AddHealing(player, target, amount, crit, relationship, targetRelationship, spell)
	--[[ work in progress
	local targetUnitID = DamageMeters_GetUnitID(target, targetRelationship);
	if (targetUnitID ~= nil) then
		local health = UnitHealth(targetUnitID);
		local maxHealth = UnitHealthMax(targetUnitID);
		local overhealed = amount - (maxHealth - health);
		if (overhealed < 0) then overhealed = 0; end
		DMPrintD(string.format("%s %d/%d -> %d, %d (%.2f%%) over", target, health, maxHealth, amount, overhealed, 100 * overhealed / amount), nil, true);
	end
	]]--

	DamageMeters_StopDebugTimer(DMPROF_PARSEMESSAGE);

	if (DM_UNKNOWNENTITY == player or DM_UNKNOWNENTITY == target) then
		return;
	end

	--DMPrintD(DamageMeters_Relation_STRING[relationship].." healed "..DamageMeters_Relation_STRING[targetRelationship].." for "..amount);

	--DMPrint("AddHealing: "..player.." healed "..target.." for "..amount);
	DamageMeters_StartDebugTimer(DMPROF_ADDVALUE);
	DamageMeters_AddValue(player, amount, crit, relationship, DamageMeters_Quantity_HEALING, spell);
	DamageMeters_AddValue(target, amount, crit, targetRelationship, DamageMeters_Quantity_HEALINGRECEIVED, spell);
	DamageMeters_StopDebugTimer(DMPROF_ADDVALUE);
end

function DamageMeters_Report(arg1)
	local destChar = "c";
	local count = table.getn(DamageMeters_tables[DMT_ACTIVE]);
	local tellTarget = "";
	local params = string.lower(arg1);
	local reportQuantity;
	
	local argsParsed = false;

	if ("help" == params) then
		DamageMeters_ShowReportHelp();
		return;
	end

	local totalStrLen = 5;
	if ("total" == string.sub(params, 1, 5)) then
		reportQuantity = DamageMeters_ReportQuantity_Total;
		if (string.len(params) > totalStrLen) then
			params = string.sub(params, totalStrLen + 1);
		else
			params = "";
		end
	else
		reportQuantity = DamageMeters_quantity;
	end

	if (params == "") then
		argsParsed = true;
	end

	local a, b, c;
	if (not argsParsed) then
		for a, b, c in string.gfind(params, "(.)(%d+) (.+)") do
			destChar = a;
			count = tonumber(b);
			tellTarget = c;
			--DMPrint(1);
			argsParsed = true;
		end
	end
	if (not argsParsed) then
		for a, c in string.gfind(params, "(.) (%d+)") do
			destChar = a;
			--tellTarget = c;
			tellTarget = format("%d", c);
			--DMPrint(2);
			argsParsed = true;
		end
	end
	if (not argsParsed) then
		for a, b in string.gfind(params, "(.)(%d+)") do
			destChar = a;
			count = tonumber(b);
			--DMPrint(3);
			argsParsed = true;
		end
	end
	if (not argsParsed) then
		for a, c in string.gfind(params, "(.) (.+)") do
			destChar = a;
			tellTarget = c;
			--DMPrint(4);
			argsParsed = true;
		end
	end
	if (not argsParsed) then
		for a in string.gfind(params, "(.)") do
			destChar = a;
			--DMPrint(5);
			argsParsed = true;
		end
	end
	--DMPrint("."..destChar.."."..count.."."..tellTarget..".");

	if (not argsParsed) then
		DMPrint(DM_ERROR_INVALIDARG);
		DamageMeters_PrintHelp("report");
	end

	local destination;
	local invert = false;
	if (destChar) then
		--DMPrint("DamageMeters_Report("..params..")");

		local lowerDestChar = string.lower(destChar);
		if (lowerDestChar ~= destChar) then
			invert = true;
			destChar = lowerDestChar;
		end

		if (destChar == "c") then
			destination = "CONSOLE";
		elseif (destChar == "p") then
			destination = "PARTY";
		elseif (destChar == "s") then
			destination = "SAY";
		elseif (destChar == "r") then
			destination = "RAID";
		elseif (destChar == "w") then
			destination = "WHISPER";
		elseif (destChar == "h") then
			destination = "CHANNEL";
		elseif (destChar == "g") then
			destination = "GUILD";
		elseif (destChar == "o") then
			destination = "OFFICER";
		elseif (destChar == "f") then
			destination = "BUFFER";

		else
			DMPrint(DM_ERROR_BADREPORTTARGET..destChar);
			return;
		end
	end

	if (destination == "WHISPER" and tellTarget == "") then
		DMPrint(DM_ERROR_MISSINGWHISPERTARGET);
		return;
	elseif (destination == "CHANNEL" and tellTarget == "") then
		DMPrint(DM_ERROR_MISSINGCHANNEL);
		return;
	end

	DamageMeters_DoReport(reportQuantity, destination, invert, 1, count, tellTarget);

	if (destination == "BUFFER") then
		DamageMeters_OpenReportFrame();
	end
end

function DamageMeters_DumpTable()
	DMPrint(table.getn(DamageMeters_tables[DMT_ACTIVE]).." elements:");

	local index;
	local info;
	for index,info in DamageMeters_tables[DMT_ACTIVE] do 
		DMPrint(index..": "..info.player);
	end
end

function DM_DUMP()
	local table = DamageMeters_tables[DMT_ACTIVE];
	DM_DUMP_RECURSIVE(table, "[root]", "");
end

function DM_DUMP_RECURSIVE(node, name, indent)
	if type(node) ~= "table" then
		if type(node) == "boolean" then
			DMPrint(indent..name.."="..(node and "true" or "false"))
		else 
			DMPrint(indent..name.."="..node)
		end
	else
		DMPrint(indent..name.."{");
		table.foreach(node, function(k,v) DM_DUMP_RECURSIVE(v, k, indent.."-") end)
		DMPrint(indent.."} "..name);
	end
end

function DamageMeters_SendReportMsg(msg, destination, tellTarget)
	local editBox = DEFAULT_CHAT_FRAME.editBox;
	if (destination == "CONSOLE") then
		DMPrint(msg);
	elseif (destination == "TOOLTIP_TITLE") then
		DamageMetersTooltip:AddLine(msg, 1.0, 1.0, 1.0, 1);
	elseif (destination == "TOOLTIP") then
		DamageMetersTooltip:AddLine(msg, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 0);
	elseif (destination == "CHANNEL") then
		--DMPrint("Destination = "..destination..", tellTarget = "..tellTarget);
		SendChatMessage(msg, destination, editBox.language, GetChannelName(tellTarget));
	elseif (destination == "BUFFER") then
		DamageMeters_reportBuffer = DamageMeters_reportBuffer..msg.."\n";
	else
		SendChatMessage(msg, destination, editBox.language, tellTarget);
	end
end

function DamageMeters_SetCount(arg1, bSilent)
	local count = 0;
	if (not arg1 or arg1 == "") then
		DMPrint(DM_MSG_SETCOUNTTOMAX);
		count = DamageMeters_BARCOUNT_MAX;
	else 
		count = tonumber(arg1);
		if (count > DamageMeters_BARCOUNT_MAX) then
			count = DamageMeters_BARCOUNT_MAX;
		end
	end
	
	DamageMeters_barCount = count;
	if (not bSilent) then
		DMPrint(DM_MSG_SETCOUNT..DamageMeters_barCount);
	end
	DMPrintD("Frame dirty: SetCount.");
	DamageMeters_frameNeedsToBeGenerated = true;
	DamageMeters_autoCountLimit = 0;
	DamageMeters_ForceNormalView();
end

function DamageMeters_Reset()
	DamageMeters_UpdateVisibility();
	DamageMeters_UpdateCount();
	DamageMeters_frameNeedsToBeGenerated = true;
end

function DamageMeters_ResetPos()
	local frame = DamageMetersFrame;
	if (not frame) then
		DMPrintD("DamageMetersFrame_Reset : Error getting frame.");
		return;
	end

	DMPrint(DM_MSG_RESETFRAMEPOS);
	local frameWidth = frame:GetWidth();
	local frameHeight = frame:GetHeight();
	frame:ClearAllPoints();
	frame:SetPoint("TOPLEFT", "UIParent", "RIGHT", -frameWidth, floor(frameHeight / 2));

	CloseMenus();

	-- Make sure the window is visible, too.
	DamageMeters_Show();
end

function DamageMeters_SetBarWidth(arg1, bSilent)
	if (arg1 == nil or arg1 == "") then
		DMPrint(string.format(DM_MSG_CURRENTBARWIDTH, DamageMeters_BARWIDTH));
	else
		if (string.lower(arg1) == "default") then
			DamageMeters_BARWIDTH = DamageMeters_DEFAULTBARWIDTH;
		else
			DamageMeters_BARWIDTH = tonumber(arg1);
		end
		if (not bSilent) then
			DMPrint(string.format(DM_MSG_NEWBARWIDTH, DamageMeters_BARWIDTH));
		end
		DamageMeters_frameNeedsToBeGenerated = true;
	end
end

function DamageMeters_ToggleShow()
	local frame = getglobal("DamageMetersFrame");
	DamageMeters_flags[DMFLAG_visibleOnlyInParty] = false;
	if (frame:IsVisible()) then
		DMPrintD("ToggleShow called - calling _Hide()");
		DamageMeters_Hide();
	else
		DMPrintD("ToggleShow called - calling _Show()");
		DamageMeters_Show();
	end
end

function DamageMeters_Show()
	DMPrintD("DamageMeters_Show called.");
	DamageMetersFrame:Show();
	DamageMeters_flags[DMFLAG_isVisible] = true;
	DamageMeters_frameNeedsToBeGenerated = true;
end

function DamageMeters_Hide()
	DamageMetersFrame:Hide();
	DamageMetersFrame_TitleButton:Hide();
	DamageMetersFrame_TotalButton:Hide();
	DamageMeters_flags[DMFLAG_isVisible] = false;
end

function DM_CountMsg(arg1, desc, event, filter)
	event = string.sub(event, 10);

	if (DamageMeters_debugEnabled) then
		DamageMeters_lastEvent.event = event;
		DamageMeters_lastEvent.desc = desc;
		DamageMeters_lastEvent.fullMsg = arg1;
		
		local filterOn = false;
		if (DamageMeters_debug3.showParse) then
			if (not filterOn or filter) then
				
				DMPrint("Parsed("..event..") "..arg1.." ["..desc.."]", nil, true);
			end
		end

		if (DamageMeters_msgCounts[desc]) then
			DamageMeters_msgCounts[desc] = DamageMeters_msgCounts[desc] + 1;
		else
			DamageMeters_msgCounts[desc] = 1;
		end

		if (DamageMeters_debug3.msgWatchMode) then
			DamageMeters_AddValue(desc, 1, DM_HIT, DamageMeters_Relation_PET, DamageMeters_Quantity_DAMAGE, "[Msg]");
		end
	end
end

function DM_DumpMsg()
	local i;
	local desc;
	for key,count in DamageMeters_msgCounts do
		DMPrintD(key.." : "..count)
	end;
end

function DM_ConsolePrint(arg1)
	local script = "DMPrint("..arg1..")";
	RunScript(script);
end

function DM_ToggleDMPrintD()
	DamageMeters_debugEnabled = not DamageMeters_debugEnabled;
	DMPrint("Debug mode enabled = "..(DamageMeters_debugEnabled and "true" or "false"));
end

-------------------------------------------------------------------------------

function DamageMetersBarTemplate_OnEnter()
	if (not DamageMetersFrame:IsVisible()) then
		return;
	end
	-- Getting onenters for invisible bars.  This doesn't seem to work :/
	if (not this:IsVisible()) then
		return;
	end
	-- This to work around above condition not working.
	if (this:GetID() > DamageMeters_barCount) then
		return;
	end

	-- no workee
	if (DamageMetersTooltip:IsVisible()) then
		return;
	end

	-- no workee
	if (DamageMetersFrameBarDropDown:IsVisible()) then
		--DMPrint("Not showing because drop down visible");
		return;
	end
	
	DamageMeters_tooltipBarIndex = this:GetID();

	-- Determine anchor.
	local anchorStyle = "ANCHOR_LEFT";
	local x,y = DamageMetersFrame:GetCenter();
	local screenWidth = UIParent:GetWidth();
	if (x~=nil and screenWidth~=nil) then
		if (x < (screenWidth / 2)) then
			anchorStyle = "ANCHOR_RIGHT";
		end
	end
	
	-- Set owner and anchor.
	DamageMetersTooltip:SetOwner(DamageMetersFrame, anchorStyle);

	-- added 2005-01-13 by arys
	-- makes clock tooltip scale correctly
	DamageMetersTooltip:SetScale(this:GetScale());

	-- Set text.
	DamageMeters_SetTooltipText();
end

function DamageMetersBarTemplate_OnLeave()
	DamageMeters_tooltipBarIndex = nil;
	DamageMetersTooltip:Hide();
end

function DamageMetersBarTemplate_OnClick()
	local index = this:GetID();
	
	--DMPrint("Click '"..arg1.."'");
	if ( arg1 == "LeftButton" ) then
		if (index <= table.getn(DamageMeters_tables[DMT_VISIBLE])) then
			--Print("Targetting "..DamageMeters_tables[DMT_VISIBLE][index].player);
			TargetByName(DamageMeters_tables[DMT_VISIBLE][index].player);
		end
	elseif ( arg1 == "RightButton" ) then
		if (DMVIEW_MIN == DamageMeters_viewMode) then
			DamageMeters_ShowMainMenu();
		else
			if (index <= table.getn(DamageMeters_tables[DMT_VISIBLE])) then
				local frame = DamageMetersFrame;

				local distance;
				distance = ( UIParent:GetWidth() - frame:GetRight() );
				
				DamageMeters_clickedBarIndex = index + DamageMeters_barStartIndex - 1;

				--DMPrint("distance = "..distance);
				local menuMoveDist = -75;
				if ( distance <= menuMoveDist ) then
					local newOffset = distance - menuMoveDist;
					--DMPrint("Too close, new offset = "..newOffset);
					ToggleDropDownMenu(1, nil, DamageMetersFrameBarDropDown, "DamageMetersFrameBarDropDown", newOffset, 0);
				else
					ToggleDropDownMenu(1, nil, DamageMetersFrameBarDropDown, "DamageMetersFrameBarDropDown", 0, 0);
				end
			end
		end
	end
end

function DamageMeters_SetTooltipText()
	local tableIndex = DamageMeters_barStartIndex + DamageMeters_tooltipBarIndex - 1;
	local playerStruct = DamageMeters_tables[DMT_VISIBLE][tableIndex];

	if ((nil == playerStruct) or (not tableIndex) or (tableIndex > table.getn(DamageMeters_tables[DMT_VISIBLE]))) then
		-- (nil == struct.player) or 
		DamageMeters_tooltipBarIndex = nil;
		DamageMetersTooltip:Hide();
		return;
	end

	DamageMetersTooltip:SetText(playerStruct.player, 1.00, 1.00, 1.00);

	if (not IsControlKeyDown()) then
		local msg = DM_MSG_PRESSCONTROLEVENT;
		if (DamageMeters_flags[DMFLAG_showEventTooltipsFirst]) then
			msg = DM_MSG_PRESSCONTROLQUANTITY;
		end
		DamageMetersTooltip:AddLine(msg, 1.0, 0.5, 0.5, 1);	
	end

	local tableIx = DMT_VISIBLE;

	if ((IsControlKeyDown() and not DamageMeters_flags[DMFLAG_showEventTooltipsFirst]) or (not IsControlKeyDown() and DamageMeters_flags[DMFLAG_showEventTooltipsFirst])) then
		local singleQuantity = nil;
		if (DamageMeters_quantity ~= DamageMeters_Quantity_TIME) then
			if (IsAltKeyDown()) then
				singleQuantity = DamageMeters_quantity;
			else
				DamageMetersTooltip:AddLine(DM_MSG_PRESSALTSINGLEQUANTITY, 1.0, 0.5, 0.5, 1);	
			end
		end
		DamageMeters_DumpPlayerEvents(DamageMeters_tables[tableIx][tableIndex].player, "TOOLTIP", false, nil, nil, singleQuantity);
	else
		local percentages = {0, 0, 0, 0};
		local quantIndex;
		for quantIndex = 1, DMI_MAX do
			percentages[quantIndex] = (DamageMeters_totals[quantIndex] > 0) and (100 * playerStruct.q[quantIndex] / DamageMeters_totals[quantIndex]) or 0;
		end

		local text = "";
		for quantIndex = 1, DMI_MAX do
			text = text..(format("%s = %d (%.2f%%)\n", DMI_NAMES[quantIndex], playerStruct.q[quantIndex], percentages[quantIndex]));
			local critPercentage = (playerStruct.hitCount[quantIndex] > 0) and (playerStruct.critCount[quantIndex] / playerStruct.hitCount[quantIndex]) * 100 or 0;
			text = text..(format("    %d/%d (%.2f%%) %s\n", playerStruct.critCount[quantIndex], playerStruct.hitCount[quantIndex], critPercentage, DM_CRITSTR));
		end

		--DMPrint("relationship = "..playerStruct.relationship);

		text = text..format(DM_TOOLTIP, 
				GetTime() - playerStruct.lastTime,
				DamageMeters_Relation_STRING[playerStruct.relationship]);
		if (playerStruct.class) then
			text = text.."\n"..DM_CLASS.." = "..playerStruct.class;
		end

		DamageMetersTooltip:AddLine(text, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b, 1);
	end

	DamageMetersTooltip:Show();
end

function DamageMeters_DoPlayerReport(player, destination)
	local playerIndex = DamageMeters_GetPlayerIndex(player);
	if (not playerIndex) then
		return;
	end
	local playerStruct = DamageMeters_tables[DMT_ACTIVE][playerIndex];

	DamageMeters_SendReportMsg(string.format(DM_MSG_PLAYERREPORTHEADER, player), destination);

	local percentages = {0, 0, 0, 0};
	local quantIndex;
	for quantIndex = 1, DMI_MAX do
		percentages[quantIndex] = (DamageMeters_totals[quantIndex] > 0) and (100 * playerStruct.q[quantIndex] / DamageMeters_totals[quantIndex]) or 0;
	end

	local text = "";
	for quantIndex = 1, DMI_MAX do
		DamageMeters_SendReportMsg(format("%s = %d (%.2f%%)", DM_QUANTDEFS[quantIndex].name, playerStruct.q[quantIndex], percentages[quantIndex]), destination);
		local critPercentage = (playerStruct.hitCount[quantIndex] > 0) and (playerStruct.critCount[quantIndex] / playerStruct.hitCount[quantIndex]) * 100 or 0;
		DamageMeters_SendReportMsg(format("    %d/%d (%.2f%%) %s", playerStruct.critCount[quantIndex], playerStruct.hitCount[quantIndex], critPercentage, DM_CRITSTR), destination);
	end
end

function DamageMeters_PrintHelp(command)
	local index, help;
	for index, help in DamageMeters_helpTable do
		if (1 == string.find(help, "dm"..command)) then
			DMPrint(help);
			return;
		end
	end
end

function DamageMeters_ListCommands()
	local index, help;
	for index, help in DamageMeters_helpTable do
		DMPrint(help);
	end
end

function DamageMeters_Help()
	DamageMeters_ShowVersion();
	DMPrint(DM_MSG_HELP);
end

-- /script DM_MemInfo();
function DM_MemInfo()
	DMPrint("VISIBLE = "..DMT_VISIBLE);
	DMPrint("ACTIVE = "..DMT_ACTIVE..", "..table.getn(DamageMeters_tables[DMT_ACTIVE]).." entries.");
	DMPrint("SAVED = "..DMT_SAVED..", "..table.getn(DamageMeters_tables[DMT_SAVED]).." entries.");
end

function DM_clone(node)
  if type(node) ~= "table" then return node end
  local b = {}
  table.foreach(node, function(k,v) b[k]=DM_clone(v) end)
  return b
end

function DamageMeters_Save()
	DMPrint(DM_MSG_SAVE);
	
	-- This makes the saved table just a reference to the active, so when the active
	-- is cleared it kills the saved.
	--DamageMeters_tables[DMT_SAVED] = DamageMeters_tables[DMT_ACTIVE];

	-- Clear the saved.
	DamageMeters_DoClear(DMT_SAVED, 0, true);

	-- Duplicate the table.
	DamageMeters_tables[DMT_SAVED] = DM_clone(DamageMeters_tables[DMT_ACTIVE]);
end

function DamageMeters_Restore()
	if (DamageMeters_tables[DMT_SAVED] and (table.getn(DamageMeters_tables[DMT_SAVED]) > 0)) then
		DMPrint(DM_MSG_RESTORE);
		DamageMeters_tables[DMT_ACTIVE] = DamageMeters_tables[DMT_SAVED];
		DamageMeters_tables[DMT_SAVED] = {};
	else
		DMPrint(DM_ERROR_NOSAVEDTABLE);
	end
end

function DamageMeters_Swap(silent)
	local tempTable = {};

	if (not silent) then
		DMPrint(format(DM_MSG_SWAP, table.getn(DamageMeters_tables[DMT_ACTIVE]), table.getn(DamageMeters_tables[DMT_SAVED])));
		DMPrintD("DMT_ACTIVE = "..DMT_ACTIVE..", DMT_SAVED = "..DMT_SAVED);
	end

	DMT_ACTIVE = DMT_SAVED;
	DMT_SAVED = (DMT_SAVED == DM_TABLE_B) and DM_TABLE_A or DM_TABLE_B;
	if (not DamageMeters_IsQuantityFight(DamageMeters_quantity)) then
		DMT_VISIBLE = DMT_ACTIVE;
	end

	-- Regen frame to hide any buttons now not needed.
	DamageMeters_frameNeedsToBeGenerated = true;
	--DMPrintD("Frame dirty: Swap.");
end

function DamageMeters_MemClear()
	DMPrint(DM_MSG_MEMCLEAR);
	DamageMeters_tables[DMT_SAVED] = {};
end

function DamageMeters_SetTextOptions(arg1)
	if (arg1 == "") then
		DMPrint(DM_ERROR_MISSINGARG);
		DamageMeters_PrintHelp("text");
		return;
	end

	DamageMeters_textOptions[DamageMeters_Text_RANK] = false;
	DamageMeters_textOptions[DamageMeters_Text_NAME] = false;
	DamageMeters_textOptions[DamageMeters_Text_TOTALPERCENTAGE] = false;
	DamageMeters_textOptions[DamageMeters_Text_LEADERPERCENTAGE] = false;
	DamageMeters_textOptions[DamageMeters_Text_VALUE] = false;		

	if (arg1 == "0") then
		return;	
	end

	local i;
	for i = 1, string.len(arg1) do
		local char = string.lower(string.sub(arg1, i, i));

		if (char == "n") then
			DamageMeters_textOptions[DamageMeters_Text_NAME] = true;
		elseif (char == "p") then
			DamageMeters_textOptions[DamageMeters_Text_TOTALPERCENTAGE] = true;
		elseif (char == "l") then
			DamageMeters_textOptions[DamageMeters_Text_LEADERPERCENTAGE] = true;
		elseif (char == "v") then
			DamageMeters_textOptions[DamageMeters_Text_VALUE] = true;
		elseif (char == "r") then
			DamageMeters_textOptions[DamageMeters_Text_RANK] = true;
		end
	end
end

function DamageMeters_SetColorScheme(arg1)
	local showUsage = false;
	local colorScheme;
	if (not arg1 or arg1 == "") then
		showUsage = true;
	else
		colorScheme = tonumber(arg1);
		if (colorScheme < 1 or colorScheme > DamageMeters_colorScheme_MAX) then
			showUsage = true;
		end	
	end
	
	if (showUsage) then
		DamageMeters_PrintHelp("color");

		local i;
		for i=1, DamageMeters_colorScheme_MAX do
			DMPrint(i..": "..DamageMeters_colorScheme_STRING[i]);
		end

		return;
	end

	DMPrint(DM_MSG_SETCOLORSCHEME..DamageMeters_colorScheme_STRING[colorScheme]);
	DamageMeters_colorScheme = colorScheme;
end

function DamageMeters_UpdateRaidMemberClasses()
	local numRaidMembers = GetNumRaidMembers();
	local name, rank, subgroup, level, class, fileName, zone, online, isDead;
	local i;
	for i = 1,numRaidMembers do
		name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i);

		local tableIndex = DamageMeters_GetPlayerIndex(name);
		if (tableIndex) then
			DamageMeters_tables[DMT_ACTIVE][tableIndex].class = class;
		end

		if (DMT_VISIBLE ~= DMT_ACTIVE) then
			tableIndex = DamageMeters_GetPlayerIndex(name, DMT_VISIBLE);
			if (tableIndex) then
				DamageMeters_tables[DMT_VISIBLE][tableIndex].class = class;
			end
		end
	end
end

function DamageMeters_GetGroupRelation(player)
	
	if (player == UnitName("Player")) then
		return DamageMeters_Relation_SELF;
	end

	local numPartyMembers = GetNumPartyMembers();
	if (numPartyMembers > 0) then
		for i=1,5 do
			local partyUnitName = "party"..i;
			local partyName = UnitName(partyUnitName);
			if (partyName == player) then
				return DamageMeters_Relation_PARTY;
			end
		end			
	end

	local numRaidMembers = GetNumRaidMembers();
	if (numRaidMembers > 0) then
		local name, rank, subgroup, level, class, fileName, zone, online, isDead;
		local i;
		for i = 1,numRaidMembers do
			name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i);
			if (name == player) then
				return DamageMeters_Relation_FRIENDLY;
			end
		end
	end

	return -1;
end

function DamageMeters_SetVisibleInParty(arg1)
	if (arg1 and arg1 ~= "") then
		local arg = string.lower(arg1);
		if (arg == "y") then
			DamageMeters_flags[DMFLAG_visibleOnlyInParty] = true;
			DamageMeters_UpdateVisibility(true);
		elseif (arg == "n") then
			DamageMeters_flags[DMFLAG_visibleOnlyInParty] = false;
			DamageMeters_UpdateVisibility(true);
		else
			DMPrint(DM_ERROR_INVALIDARGS);
			DamageMeters_PrintHelp("visinparty");
		end
	end

	DMPrint(DM_MSG_SETVISINPARTY..(DamageMeters_flags[DMFLAG_visibleOnlyInParty] and DM_MSG_TRUE or DM_MSG_FALSE));
end

function DamageMeters_SetAutoCount(arg1)
	if (not arg1 or arg1 == "") then
		DMPrint(DM_ERROR_MISSINGARG);
		DamageMeters_PrintHelp("autocount");
		return;
	end

	local newAutoCountLimit = tonumber(arg1);
	if (not newAutoCountLimit or newAutoCountLimit <= 0 or newAutoCountLimit > DamageMeters_BARCOUNT_MAX) then
		DMPrint(DM_ERROR_INVALIDARG);
		return;
	end

	DMPrint(DM_MSG_SETAUTOCOUNT..newAutoCountLimit);
	DamageMeters_autoCountLimit = newAutoCountLimit;
	DamageMeters_ForceNormalView();
end

function DamageMeters_ToggleOnlySyncWithGroup()
	DamageMeters_flags[DMFLAG_onlySyncWithGroup] = not DamageMeters_flags[DMFLAG_onlySyncWithGroup];
	if (DamageMeters_flags[DMFLAG_onlySyncWithGroup]) then
		DMPrint(DM_MSG_SYNCINGROUPON);
	else
		DMPrint(DM_MSG_SYNCINGROUPOFF);
	end
end

function DamageMeters_TogglePermitAutoJoin()
	DamageMeters_flags[DMFLAG_permitAutoSyncChanJoin] = not DamageMeters_flags[DMFLAG_permitAutoSyncChanJoin];
	if (DamageMeters_flags[DMFLAG_permitAutoSyncChanJoin]) then
		DMPrint(DM_MSG_AUTOSYNCJOINON);
	else
		DMPrint(DM_MSG_AUTOSYNCJOINOFF);
	end
end

-----------------------------------------

function DamageMeters_FrameDropDown_OnLoad()
	--DMPrint("this = "..this:GetName());
	UIDropDownMenu_Initialize(this, DamageMeters_FrameDropDown_Initialize, "MENU");
end

function DamageMeters_FrameDropDown_Initialize()

	-- If level 2
	if ( UIDROPDOWNMENU_MENU_LEVEL == 2 ) then
		-- If this is the sort style menu then create dropdown
		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_SORT ) then
			local index;
			for index = 1,DamageMeters_Sort_MAX do
				info = {};
				info.text = DamageMeters_Sort_STRING[index];
				info.value = index;
				info.func = DamageMetersFrame_TitleButton_SetSort;
				if ( index == DamageMeters_sort ) then
					info.checked = 1;
				end
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end
			return;	
		end

		-- If this is the quantity menu then create dropdown
		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_VISIBLEQUANTITY ) then
			local index;
			for index = 1,DamageMeters_Quantity_MAX do
				info = {};
				info.text = DamageMeters_GetQuantityString(index);
				info.value = index;
				info.func = DamageMetersFrame_TitleButton_SetQuantity;
				if ( index == DamageMeters_quantity ) then
					info.checked = 1;
				end
				info.swatchFunc = DamageMeters_SetQuantityColor;
				-- Set the swatch color info
				info.hasColorSwatch = 1;
				info.r = DamageMeters_quantityColor[index][1];
				info.g = DamageMeters_quantityColor[index][2];
				info.b = DamageMeters_quantityColor[index][3];
				info.opacity = 1.0 - DamageMeters_quantityColor[index][4];
				info.cancelFunc = DamageMeters_CancelQuantityColorSettings;
				info.hasOpacity = 1;
				info.opacityFunc = DamageMeters_SetQuantityColorOpacity;
				--info.keepShownOnClick = 1;
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end

			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Show fight data as PS.
			info = {};
			info.text = DM_MENU_SHOWFIGHTASPS;
			if (DamageMeters_flags[DMFLAG_showFightAsPS]) then
				info.checked = 1;
			end
			info.func = DamageMeters_ToggleShowFightAsPS;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Set for all
			info = {};
			info.text = DM_MENU_SETCOLORFORALL;
			info.func = DamageMeters_SetQuantityColorAllOnClick;
			info.swatchFunc = DamageMeters_SetQuantityColorAll;
			info.hasColorSwatch = 1;
			info.r = DamageMeters_quantityColor[DamageMeters_quantity][1];
			info.g = DamageMeters_quantityColor[DamageMeters_quantity][2];
			info.b = DamageMeters_quantityColor[DamageMeters_quantity][3];
			info.hasOpacity = 1;
			info.opacity = 1.0 - DamageMeters_quantityColor[DamageMeters_quantity][4];
			info.opacityFunc = DamageMeters_SetQuantityColorOpacityAll;
			info.notCheckable = 1;
			info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Default Colors
			info = {};
			info.text = DM_MENU_DEFAULTCOLORS;
			info.notCheckable = 1;
			info.func = DamageMeters_SetDefaultColors;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Show Total
			info = {};
			info.text = DM_MENU_SHOWTOTAL;
			if (DamageMeters_flags[DMFLAG_showTotal]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.value = DMFLAG_showTotal;
			info.func = DamageMetersMenu_ToggleVariableAndRegen;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			return;	
		end

		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_QUANTITYFILTER ) then
			local index;
			for index = 1, DamageMeters_Quantity_MAX do
				info = {};
				info.text = DamageMeters_GetQuantityString(index);
				info.value = index;
				info.func = DamageMetersFrame_TitleButton_ToggleCycleQuantity;
				info.keepShownOnClick = 1;
				if ( DamageMeters_quantitiesFilter[index] ) then
					info.checked = 1;
				end
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end

			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Apply filter to auto-cycle
			info = {};
			info.text = DM_MENU_APPLYFILTERTOAUTOCYCLING;
			if (DamageMeters_flags[DMFLAG_applyFilterToAutoCycle]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.value = DMFLAG_applyFilterToAutoCycle;
			info.func = DamageMetersMenu_ToggleVariable;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Apply filter to manual-cycle
			info = {};
			info.text = DM_MENU_APPLYFILTERTOMANUALCYCLING;
			if (DamageMeters_flags[DMFLAG_applyFilterToManualCycle]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.value = DMFLAG_applyFilterToManualCycle;
			info.func = DamageMetersMenu_ToggleVariable;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Cycle text
			info = {};
			info.text = DM_MENU_QUANTCYCLE;
			if (DamageMeters_flags[DMFLAG_cycleVisibleQuantity]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.func = DamageMeters_ToggleCycleVisibleQuant;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			return;	
		end

		--[[
		-- If this is the color scheme menu then create dropdown
		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_COLORSCHEME ) then
			local index;
			for index = 1, DamageMeters_colorScheme_MAX do
				info = {};
				info.text = DamageMeters_colorScheme_STRING[index];
				info.value = index;
				info.func = DamageMetersFrame_TitleButton_SetColorScheme;
				if ( index == DamageMeters_colorScheme ) then
					info.checked = 1;
				end
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end
			return;	
		end
		]]--

		local barCounts = {3,5,10,15,20,25,30,35,40};

		-- If this is the Bar count menu then create dropdown
		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_BARCOUNT ) then
			local index;
			for index = 1, table.getn(barCounts) do
				info = {};
				info.text = barCounts[index];
				info.value = barCounts[index];
				info.func = DamageMetersFrame_TitleButton_SetCount;
				if ( info.value == DamageMeters_barCount ) then
					info.checked = 1;
				end
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end

			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Show Max
			info = {};
			info.text = DM_MENU_SHOWMAX;
			if (DMVIEW_MAX == DamageMeters_viewMode) then
				info.checked = 1;
			end
			info.func = DamageMeters_ToggleMaxBars;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			return;	
		end

		-- If this is the Bar auto count menu then create dropdown
		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_AUTOCOUNTLIMIT ) then
			local index;
			for index = 1, table.getn(barCounts) do
				info = {};
				info.text = barCounts[index];
				info.value = barCounts[index];
				info.func = DamageMetersFrame_TitleButton_SetAutoCount;
				if ( info.value == DamageMeters_autoCountLimit ) then
					info.checked = 1;
				end
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end
			return;	
		end

		-- If this is the Bar auto count menu then create dropdown
		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_REPORT ) then
			local reportTypes = {"f", "c", "s", "p", "r", "g", "o"};
			local index;
			for index = 1, table.getn(reportTypes) do
				info = {};
				info.text = DM_MENU_REPORTNAMES[index];
				info.value = reportTypes[index];
				info.func = DamageMetersFrame_TitleButton_Report;
				info.notCheckable = 1;
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end

			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Reset Pos
			info = {};
			info.text = DM_MENU_HELP;
			info.notCheckable = 1;
			info.func = DamageMeters_ShowReportHelp;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			return;
		end

		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_MEMORY ) then
			-- Save
			info = {};
			info.text = DM_MENU_SAVE;
			info.notCheckable = 1;
			info.func = DamageMeters_Save;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Clear
			info = {};
			info.text = DM_MENU_CLEAR;
			info.notCheckable = 1;
			info.func = DamageMeters_MemClear;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Restore
			info = {};
			info.text = DM_MENU_RESTORE;
			info.notCheckable = 1;
			info.func = DamageMeters_Restore;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Swap
			info = {};
			info.text = DM_MENU_SWAP;
			info.notCheckable = 1;
			info.func = DamageMeters_Swap;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Accumulate
			info = {};
			info.text = DM_MENU_ACCUMULATEINMEMORY;
			if (DamageMeters_flags[DMFLAG_accumulateToMemory]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.func = DamageMeters_ToggleAccumulateToMemory;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			return;
		end

		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_POSITION ) then
			-- Reset Pos
			info = {};
			info.text = DM_MENU_RESETPOS;
			info.notCheckable = 1;
			info.func = DamageMeters_ResetPos;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Lock Pos
			info = {};
			if (DamageMeters_flags[DMFLAG_positionLocked]) then
				info.text = DM_MENU_UNLOCKPOS;
			else
				info.text = DM_MENU_LOCKPOS;
			end
			info.notCheckable = 1;
			info.func = DamageMeters_ToggleLockPos;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Resize left
			info = {};
			info.text = DM_MENU_RESIZELEFT;
			info.value = DamageMeters_Text_RANK;
			if (DamageMeters_flags[DMFLAG_resizeLeft]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.value = DMFLAG_resizeLeft;
			info.func = DamageMetersMenu_ToggleVariable;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Resize left
			info = {};
			info.text = DM_MENU_RESIZEUP;
			info.value = DamageMeters_Text_RANK;
			if (DamageMeters_flags[DMFLAG_resizeUp]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.value = DMFLAG_resizeUp;
			info.func = DamageMetersMenu_ToggleVariable;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			return;
		end

		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_TEXT ) then
			-- Rank
			info = {};
			info.text = DM_MENU_TEXTRANK;
			info.value = DamageMeters_Text_RANK;
			if (DamageMeters_textOptions[DamageMeters_Text_RANK]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.func = DamageMeters_ToggleTextOption;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Name
			info = {};
			info.text = DM_MENU_TEXTNAME;
			info.value = DamageMeters_Text_NAME;
			if (DamageMeters_textOptions[DamageMeters_Text_NAME]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.func = DamageMeters_ToggleTextOption;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Total %
			info = {};
			info.text = DM_MENU_TEXTPERCENTAGE;
			info.value = DamageMeters_Text_TOTALPERCENTAGE;
			if (DamageMeters_textOptions[DamageMeters_Text_TOTALPERCENTAGE]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.func = DamageMeters_ToggleTextOption;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Leader %
			info = {};
			info.text = DM_MENU_TEXTPERCENTAGELEADER;
			info.value = DamageMeters_Text_LEADERPERCENTAGE;
			if (DamageMeters_textOptions[DamageMeters_Text_LEADERPERCENTAGE]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.func = DamageMeters_ToggleTextOption;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Value
			info = {};
			info.text = DM_MENU_TEXTVALUE;
			info.value = DamageMeters_Text_VALUE;
			if (DamageMeters_textOptions[DamageMeters_Text_VALUE]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.func = DamageMeters_ToggleTextOption;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

	
			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Cycle text
			info = {};
			info.text = DM_MENU_TEXTCYCLE;
			if (DamageMeters_textState > 0) then
				info.checked = 1;
			end
			info.func = DamageMeters_ToggleTextState;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Left Justify Text
			info = {};
			info.text = DM_MENU_LEFTJUSTIFYTEXT;
			if (DamageMeters_flags[DMFLAG_justifyTextLeft]) then
				info.checked = 1;
			end
			info.value = DMFLAG_justifyTextLeft;
			info.func = DamageMetersMenu_ToggleVariableAndRegen;
			info.keepShownOnClick = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			return;
		end

		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_EVENTDATA ) then

			-- No Data
			info = {};
			info.text = DM_MENU_EVENTDATA_NONE;
			if (DamageMeters_eventDataLevel == DamageMeters_EventData_NONE) then
				info.checked = 1;
			end
			info.value = DamageMeters_EventData_NONE;
			info.func = DamageMeters_ChangeEventDataLevel;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Self Data
			info = {};
			info.text = DM_MENU_EVENTDATA_PLAYER;
			if (DamageMeters_eventDataLevel == DamageMeters_EventData_SELF) then
				info.checked = 1;
			end
			info.value = DamageMeters_EventData_SELF;
			info.func = DamageMeters_ChangeEventDataLevel;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- All Data
			info = {};
			info.text = DM_MENU_EVENTDATA_ALL;
			if (DamageMeters_eventDataLevel == DamageMeters_EventData_ALL) then
				info.checked = 1;
			end
			info.value = DamageMeters_EventData_ALL;
			info.func = DamageMeters_ChangeEventDataLevel;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Tooltip Default
			info = {};
			info.text = DM_MENU_SHOWEVENTDATATOOLTIP;
			if (DamageMeters_flags[DMFLAG_showEventTooltipsFirst]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.value = DMFLAG_showEventTooltipsFirst;
			info.func = DamageMetersMenu_ToggleVariable;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			return;
		end

		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_SYNC ) then
			-- Title
			info = {};
			info.isTitle =  true;
			info.notCheckable = 1;
			if (DamageMeters_syncChannel == "") then
				info.text = DM_MENU_NOSYNCCHAN;
			else
				info.text = DM_MENU_SYNCCHAN..DamageMeters_syncChannel;
			end
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Session
			if (DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel) then
				info = {};
				info.isTitle =  true;
				info.notCheckable = 1;
				info.text = DM_MENU_SESSION..DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel.." "..DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex;
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);	
			end

			-- Title 2
			info = {};
			info.isTitle =  true;
			info.notCheckable = 1;
			info.text = DM_MENU_JOINSYNCCHAN;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			info = {};
			info.text = DM_MENU_SYNCLEAVECHAN;
			info.notCheckable = 1;
			info.func = DamageMeters_SyncLeaveChan;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			info = {};
			info.text = DM_MENU_SYNCBROADCASTCHAN;
			info.notCheckable = 1;
			info.func = DamageMeters_SyncBroadcastChan;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			info = {};
			info.text = DM_MENU_PERMITSYNCAUTOJOIN;
			if (DamageMeters_flags[DMFLAG_permitAutoSyncChanJoin]) then
				info.checked = 1;
			end
			info.func = DamageMeters_TogglePermitAutoJoin;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			info = {};
			info.text = DM_MENU_CLEARONAUTOJOIN;
			if (DamageMeters_flags[DMFLAG_autoClearOnChannelJoin]) then
				info.checked = 1;
			end
			info.value = DMFLAG_autoClearOnChannelJoin;
			info.func = DamageMetersMenu_ToggleVariable;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			info = {};
			info.text = DM_MENU_ENABLEDMM;
			if (DamageMeters_flags[DMFLAG_enableDMM]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.value = DMFLAG_enableDMM;
			info.func = DamageMetersMenu_ToggleVariable;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			info = {};
			info.text = DM_MENU_ONLYSYNCWITHGROUP;
			if (DamageMeters_flags[DMFLAG_onlySyncWithGroup]) then
				info.checked = 1;
			end
			info.func = DamageMeters_ToggleOnlySyncWithGroup;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Help
			info = {};
			info.text = DM_MENU_HELP;
			info.notCheckable = 1;
			info.func = DamageMeters_ShowSyncHelp;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			return;
		end

		--[[ Threat
		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_THREAT ) then
			-- Clear
			info = {};
			info.text = DM_MENU_THREAT_CLEAR;
			info.notCheckable = 1;
			info.func = ThreatMeters_ClearThreat;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Participate
			info = {};
			info.text = DM_MENU_THREAT_PARTICIPATE;
			if ThreatMeters["SyncParticipate"] then
				info.checked = 1;
			end
			info.value = "SyncParticipate";
			info.func = ThreatMeters_ToggleVariable;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			
			if ThreatMeters["SyncParticipate"] then
				-- Clear On Combat Start
				info = {};
				info.text = DM_MENU_THREAT_FORCECLEARONCOMBATSTART;
				if ThreatMeters["ForceClearThreatOnCombatStart"] then
					info.checked = 1;
				end
				info.value = "ForceClearThreatOnCombatStart";
				info.func = ThreatMeters_ToggleVariable;
				info.keepShownOnClick = 1;
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

				info = {};
				info.text = DM_MENU_THREAT_PHASE;
				if ThreatMeters["ClearOnPhaseChange"] then
					info.checked = 1;
				end
				info.value = "ClearOnPhaseChange";
				info.func = ThreatMeters_ToggleVariable;
				info.keepShownOnClick = 1;
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

				-- target
				info = {};
				info.text = DM_MENU_THREAT_TARGET;
				info.notCheckable = 1;
				info.func = ThreatMeters_MenuTarget;
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

				-- Current target.
				info = {};
				info.isTitle =  true;
				info.notCheckable = 1;
				info.text = "Current Target = "..((ThreatMeters_currentTarget ~= nil) and ThreatMeters_currentTarget or "<nil>");
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end
			
			return;
		end
		]]--

		if ( UIDROPDOWNMENU_MENU_VALUE == "Debug" ) then
			local varName, value;
			for varName, value in DamageMeters_debug3 do
				info = {};
				info.text = varName;
				if (value) then
					info.checked = 1;
				end
				info.keepShownOnClick = 1;
				info.value = varName;
				info.func = DamageMeters_ToggleDebugVariable;
				UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);
			end

			return;
		end

		if ( UIDROPDOWNMENU_MENU_VALUE == DM_MENU_GENERAL ) then
			-- Player Always Visible
			info = {};
			info.text = DM_MENU_PLAYERALWAYSVISIBLE;
			if (DamageMeters_flags[DMFLAG_playerAlwaysVisible]) then
				info.checked = 1
			end
			info.keepShownOnClick = 1;
			info.value = DMFLAG_playerAlwaysVisible;
			info.func = DamageMetersMenu_ToggleVariableAndRegen;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);	

			-- visible in party
			info = {};
			info.text = DM_MENU_VISINPARTY;
			if (DamageMeters_flags[DMFLAG_visibleOnlyInParty]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.func = DamageMeters_ToggleVisibleInParty;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Group members only
			info = {};
			info.text = DM_MENU_GROUPMEMBERSONLY;
			if (DamageMeters_flags[DMFLAG_groupMembersOnly]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.value = DMFLAG_groupMembersOnly;
			info.func = DamageMetersMenu_ToggleVariable;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Add pet to player
			info = {};
			info.text = DM_MENU_ADDPETTOPLAYER;
			if (DamageMeters_flags[DMFLAG_addPetToPlayer]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.func = DamageMeters_ToggleAddPetToPlayer;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Reset on combat
			info = {};
			info.text = DM_MENU_RESETONCOMBATSTARTS;
			if (DamageMeters_flags[DMFLAG_resetWhenCombatStarts]) then
				info.checked = 1;
			end
			info.keepShownOnClick = 1;
			info.func = DamageMeters_ToggleResetWhenCombatStarts;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Group DPS Mode
			info = {};
			info.text = DM_MENU_GROUPDPSMODE;
			if (DamageMeters_flags[DMFLAG_groupDPSMode]) then
				info.checked = 1
			end
			info.keepShownOnClick = 1;
			info.value = DMFLAG_groupDPSMode;
			info.func = DamageMetersMenu_ToggleVariable;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);	

			-- Constant Update
			info = {};
			info.text = DM_MENU_CONSTANTVISUALUPDATE;
			if (DamageMeters_flags[DMFLAG_constantVisualUpdate]) then
				info.checked = 1
			end
			info.keepShownOnClick = 1;
			info.value = DMFLAG_constantVisualUpdate;
			info.func = DamageMetersMenu_ToggleVariable;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);	

			-- Spacer
			info = {};
			info.disabled = 1;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			-- Restore defaults
			info = {};
			info.text = DM_MENU_RESTOREDEFAULTOPTIONS;
			info.notCheckable = 1;
			info.func = DamageMeters_DoRestoreDefaultOptions;
			UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

			return;
		end
	end

	-- Title
	info = {};
	info.isTitle =  true;
	info.text = "DamageMeters "..DamageMeters_VERSIONSTRING;
	UIDropDownMenu_AddButton(info);

	-- Hide
	info = {};
	if (DamageMetersFrame:IsVisible()) then
		info.text = DM_MENU_HIDE;
	else
		info.text = DM_MENU_SHOW;
	end
	info.notCheckable = 1;
	info.func = DamageMetersBar_ToggleShow;
	-- Just a test.  These fields are only used if noob tooltips are enabled.
	--info.tooltipTitle = info.text;
	--info.tooltipText = "Hello!";
	UIDropDownMenu_AddButton(info);

	-- Clear
	info = {};
	info.text = DM_MENU_CLEAR;
	info.notCheckable = 1;
	info.func = DamageMeters_Clear;
	UIDropDownMenu_AddButton(info);

	-- Pause
	info = {};
	info.text = DM_MENU_PAUSE;
	if (DM_Pause_Not ~= DamageMeters_pauseState) then
		info.checked = 1;
	end
	info.keepShownOnClick = 1;
	info.func = DamageMeters_TogglePause;
	UIDropDownMenu_AddButton(info);

	-- Minimize
	info = {};
	info.text = DM_MENU_MINIMIZE;
	if (DMVIEW_MIN == DamageMeters_viewMode) then
		info.checked = 1;
	end
	--info.keepShownOnClick = 1;
	info.func = DamageMeters_ToggleMiniMode;
	UIDropDownMenu_AddButton(info);

	-- Spacer
	info = {};
	info.disabled = 1;
	UIDropDownMenu_AddButton(info);

	-- General
	info = {};
	info.text = DM_MENU_GENERAL;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);

	-- Report
	info = {};
	info.text = DM_MENU_REPORT;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);

	-- Position
	info = {};
	info.text = DM_MENU_POSITION;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);

	-- Count
	info = {};
	info.text = DM_MENU_BARCOUNT;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);

	-- AutoCount
	info = {};
	info.text = DM_MENU_AUTOCOUNTLIMIT;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);

	-- Sort
	info = {};
	info.text = DM_MENU_SORT;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);

	-- Quantity
	info = {};
	info.text = DM_MENU_VISIBLEQUANTITY;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);

	-- Quantity Filter
	info = {};
	info.text = DM_MENU_QUANTITYFILTER;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);

	--[[
	-- Bar Colors
	info = {};
	info.text = DM_MENU_COLORSCHEME;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);
	]]--

	-- Bar Colors
	info = {};
	info.text = DM_MENU_MEMORY;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);

	-- text optionss
	info = {};
	info.text = DM_MENU_TEXT;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);

	-- Event Options
	info = {};
	info.text = DM_MENU_EVENTDATA;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);

	-- Sync Options
	info = {};
	info.text = DM_MENU_SYNC;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);

	--[[ Threat
	-- Threat Options
	info = {};
	info.text = DM_MENU_THREAT;
	--info.notClickable = 1;
	info.hasArrow = 1;
	info.func = nil;
	info.notCheckable = 1;
	UIDropDownMenu_AddButton(info);
	]]--

	if (DamageMeters_debugEnabled) then
		-- Debug Menu
		info = {};
		info.text = "Debug";
		--info.notClickable = 1;
		info.hasArrow = 1;
		info.func = nil;
		info.notCheckable = 1;
		UIDropDownMenu_AddButton(info);		
	end
end

--------------------------------------------

function DamageMetersFrame_TitleButton_OnLoad()
	DamageMeters_TitleButtonText:SetText("Damage Meters");
	-- Color tables not initialized yet.
	--local color = DamageMeters_quantityColor[DamageMeters_quantity];
	--DamageMetersFrame_TitleButton:SetBackdropColor(color[1], color[2], color[3], color[4]);
	this:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp");
end

function DamageMetersFrame_TitleButton_OnClick()
	local button = arg1;	

	--DMPrint("DamageMetersFrame_TitleButton_OnClick : "..button);

	if ( button  == "LeftButton" ) then
		if ( this:GetButtonState() == "PUSHED" ) then
			DamageMetersFrame:StopMovingOrSizing();
		else
			if (not DamageMeters_flags[DMFLAG_positionLocked] and not DamageMetersFrame.isLocked) then
				DamageMetersFrame:StartMoving();
			end
		end
	elseif ( button == "RightButton" ) then
		DamageMeters_ShowMainMenu();
	end
end

function DamageMeters_ShowMainMenu()
	local frame = DamageMetersFrame_TitleButton;
	local distance;
	distance = ( UIParent:GetWidth() - frame:GetRight() );
	
	--DMPrint("distance = "..distance);
	local menuMoveDist = 250;
	if ( distance <= menuMoveDist ) then
		local newOffset = distance - menuMoveDist;
		--DMPrint("Too close, new offset = "..newOffset);
		ToggleDropDownMenu(1, nil, DamageMetersFrameDropDown, "DamageMetersFrameDropDown", newOffset, 0);
	else
		ToggleDropDownMenu(1, nil, DamageMetersFrameDropDown, "DamageMetersFrameDropDown", 0, 0);
	end
end

function DamageMetersFrame_TitleButton_SetSort()
	DamageMeters_SetSort(this.value);
end

function DamageMetersFrame_TitleButton_SetQuantity()
	DamageMeters_flags[DMFLAG_cycleVisibleQuantity] = false;
	DamageMeters_SetQuantity(this.value, true);
end

function DamageMetersFrame_TitleButton_ToggleCycleQuantity()
	DamageMeters_quantitiesFilter[this.value] = not DamageMeters_quantitiesFilter[this.value];
end

function DamageMetersFrame_TitleButton_SetColorScheme()
	DamageMeters_SetColorScheme(this.value);
end

function DamageMetersFrame_TotalButton_OnLoad()
	DamageMeters_TotalButtonText:SetText("Damage Meters");
end

function DamageMeters_ToggleTextOption()
	DamageMeters_textOptions[this.value] = not DamageMeters_textOptions[this.value];

	if (DamageMeters_textState > 0) then
		-- If we have turned off all text options, make sure we stop cycling.
		local option;
		for option = 1, DamageMeters_Text_MAX do
			if (DamageMeters_textOptions[option]) then
				return;
			end
		end
		-- Fell through...turn off cycling.
		DMPrintD("Turned off all text options: disabling text cycling.");
		DamageMeters_textState = 0;
	end
end

function DamageMeters_ToggleTextState()
	if (DamageMeters_textState < 1) then
		DamageMeters_textStateStartTime = GetTime();

		-- Set the text state to the first set option.
		local nextState;
		for nextState = 1, DamageMeters_Text_MAX do
			if (DamageMeters_textOptions[nextState]) then
				DamageMeters_textState = nextState;
				DMPrintD("Setting text state to "..DamageMeters_textState);
				return;
			end
		end

		-- Cycling enabled but no text options turned on: turn on the name option.
		DamageMeters_textOptions[DamageMeters_Text_NAME] = true;
		DamageMeters_textState = DamageMeters_Text_NAME;
		DMPrintD("Setting text state to (and enabling) "..DamageMeters_textState);
	else
		DamageMeters_textState = 0;
		DMPrintD("Setting text state to 0.");
	end
end

function DamageMeters_ToggleCycleVisibleQuant()
	if (DamageMeters_flags[DMFLAG_cycleVisibleQuantity]) then
		DamageMeters_flags[DMFLAG_cycleVisibleQuantity] = false;
	else
		DamageMeters_flags[DMFLAG_cycleVisibleQuantity] = true;
		DamageMeters_currentQuantStartTime = GetTime();
	end
end

function DamageMeters_CycleQuant(manual, useFilter)
	DamageMeters_flags[DMFLAG_cycleVisibleQuantity] = not manual;
	local newQuant = DamageMeters_quantity;
	repeat
		newQuant = newQuant + 1;
		if (newQuant > DamageMeters_Quantity_MAX) then
			newQuant = 1;
		end

		if (newQuant == DamageMeters_quantity) then
			newQuant = 1;
			DamageMeters_quantitiesFilter[newQuant] = true;
			DMPrintD("No quantities selected for cycling, aborting loop.");
		end
	until ((not useFilter) or DamageMeters_quantitiesFilter[newQuant]);

	DamageMeters_SetQuantity(newQuant, true);
end

function DamageMeters_CycleQuantBack(manual, useFilter)
	DamageMeters_flags[DMFLAG_cycleVisibleQuantity] = not manual;
	local newQuant = DamageMeters_quantity;
	repeat
		newQuant = newQuant - 1;
		if (newQuant < 1) then
			newQuant = DamageMeters_Quantity_MAX;
		end

		if (newQuant == DamageMeters_quantity) then
			newQuant = 1;
			DamageMeters_quantitiesFilter[newQuant] = true;
			DMPrintD("No quantities selected for cycling, aborting loop.");
		end
	until ((not useFilter) or DamageMeters_quantitiesFilter[newQuant]);

	DamageMeters_SetQuantity(newQuant, true);
end


function DamageMeters_ToggleVisibleInParty()
	DamageMeters_flags[DMFLAG_visibleOnlyInParty] = not DamageMeters_flags[DMFLAG_visibleOnlyInParty];
	DamageMeters_UpdateVisibility(true);
end

function DamageMeters_ToggleAddPetToPlayer()
	DamageMeters_flags[DMFLAG_addPetToPlayer] = not DamageMeters_flags[DMFLAG_addPetToPlayer];
	if (DamageMeters_flags[DMFLAG_addPetToPlayer]) then
		DMPrint(DM_MSG_ADDINGPETTOPLAYER);
	else
		DMPrint(DM_MSG_NOTADDINGPETTOPLAYER);
		return;
	end

	-- This code automatically merges pet information into player's.

	local playerName = UnitName("Player");
	local playerIndex = DamageMeters_GetPlayerIndex(playerName);
	if (not playerIndex or playerIndex < 1) then
		DamageMeters_AddValue(playerName, 0, DM_DOT, DamageMeters_Relation_SELF, DamageMeters_Quantity_DAMAGE, "[Pet]");
		playerIndex = DamageMeters_GetPlayerIndex(playerName);
		if (not playerIndex or playerIndex < 1) then
			DMPrint(DM_ERROR_NOROOMFORPLAYER);
			return;
		end
	end
	local target = DamageMeters_tables[DMT_ACTIVE][playerIndex];

	local index;
	local tableN = table.getn(DamageMeters_tables[DMT_ACTIVE]);
	for index = tableN, 1, -1 do
		local playerStruct = DamageMeters_tables[DMT_ACTIVE][index];
		if (DamageMeters_Relation_PET == playerStruct.relationship) then
			DMPrint(format(DM_MSG_PETMERGE, playerStruct.player));

			local quantIndex;
			for quantIndex = 1, DMI_MAX do
				target.q[quantIndex] = target.q[quantIndex] + playerStruct.q[quantIndex];
				target.hitCount[quantIndex] = target.hitCount[quantIndex] + playerStruct.hitCount[quantIndex];
				target.critCount[quantIndex] = target.critCount[quantIndex] + playerStruct.critCount[quantIndex];
			end
			
			target.lastTime = (target.lastTime > playerStruct.lastTime) and target.lastTime or playerStruct.lastTime;

			table.remove(DamageMeters_tables[DMT_ACTIVE], index);
			DamageMeters_frameNeedsToBeGenerated = true;
			--DMPrintD("Frame dirty: Pet removed.");
		end
	end
end

function DamageMetersFrame_TitleButton_SetCount()
	DamageMeters_SetCount(this.value);
	CloseMenus();
end

function DamageMetersFrame_TitleButton_SetAutoCount()
	DamageMeters_SetAutoCount(this.value);
end

function DamageMetersFrame_TitleButton_Report()
	local command = format("%s%d", this.value, DamageMeters_barCount);
	DamageMeters_Report(command);
	CloseMenus();
end

--------------------------------------------

function DamageMeters_BarDropDown_OnLoad()
	UIDropDownMenu_Initialize(this, DamageMeters_BarFrameDropDown_Initialize, "MENU");
end

function DamageMeters_BarFrameDropDown_Initialize()
	DamageMetersTooltip:Hide();

	-- Header
	info = {};
	if (DamageMeters_clickedBarIndex) then
		info.text = DamageMeters_tables[DMT_VISIBLE][DamageMeters_clickedBarIndex].player;
	else
		info.text = "";
	end
	info.notClickable = 1;
	info.isTitle = 1;
	UIDropDownMenu_AddButton(info, UIDROPDOWNMENU_MENU_LEVEL);

	-- Delete
	info = {};
	info.text = DM_MENU_DELETE;
	info.notCheckable = 1;
	info.func = DamageMetersBar_DeleteEntry;
	UIDropDownMenu_AddButton(info);	

	-- Ban
	info = {};
	info.text = DM_MENU_BAN;
	info.notCheckable = 1;
	info.func = DamageMetersBar_BanEntry;
	UIDropDownMenu_AddButton(info);	

	-- Clear above
	info = {};
	info.text = DM_MENU_CLEARABOVE;
	info.notCheckable = 1;
	info.func = DamageMetersBar_ClearAboveEntry;
	UIDropDownMenu_AddButton(info);	

	-- Clear below
	info = {};
	info.text = DM_MENU_CLEARBELOW;
	info.notCheckable = 1;
	info.func = DamageMetersBar_ClearBelowEntry;
	UIDropDownMenu_AddButton(info);	

	-- Event Data
	info = {};
	info.text = DM_MENU_PLAYERREPORT;
	info.notCheckable = 1;
	info.func = DamageMetersBar_DoPlayerReport;
	UIDropDownMenu_AddButton(info);	

	-- Event Data
	info = {};
	info.text = DM_MENU_EVENTREPORT;
	info.notCheckable = 1;
	info.func = DamageMetersBar_DumpPlayerEvents;
	UIDropDownMenu_AddButton(info);	

	-- Spacer
	info = {};
	info.disabled = 1;
	UIDropDownMenu_AddButton(info);

	-- Clear banned
	info = {};
	info.text = DM_MENU_CLEARBANNED;
	info.notCheckable = 1;
	info.func = DamageMeters_ClearBanned;
	UIDropDownMenu_AddButton(info);	
end

function DamageMetersBar_DeleteEntry()
	--DMPrint("DamageMetersBar_DeleteEntry "..this:GetName());

	DamageMeters_DoDelete(DamageMeters_clickedBarIndex);
end

function DamageMetersBar_BanEntry()
	--DMPrint("DamageMetersBar_BanEntry "..this:GetID());
	DamageMeters_DoBan(DamageMeters_clickedBarIndex);
	DamageMeters_clickedBarIndex = nil;
end

function DamageMetersBar_ClearAboveEntry()
	--DMPrint("DamageMetersBar_ClearAboveEntry "..this:GetID());

	local index;
	for index = 1, (DamageMeters_clickedBarIndex - 1) do
		table.remove(DamageMeters_tables[DMT_VISIBLE], 1);
	end

	DamageMeters_frameNeedsToBeGenerated = true;
	DMPrintD("Frame dirty: ClearAboveEntry.");
	DamageMeters_clickedBarIndex = nil;
end

function DamageMetersBar_ClearBelowEntry()
	--DMPrint("DamageMetersBar_ClearBelowEntry");
	DamageMeters_Clear(DamageMeters_clickedBarIndex);
	DamageMeters_clickedBarIndex = nil;
end

function DamageMeters_DoDelete(index)
	table.remove(DamageMeters_tables[DMT_VISIBLE], index);
	DamageMeters_frameNeedsToBeGenerated = true;
	DamageMeters_clickedBarIndex = nil;
end

function DamageMeters_DoBan(index)
	if (index <= 0 or index > table.getn(DamageMeters_tables[DMT_VISIBLE])) then
		DMPrint(DM_ERROR_INVALIDARG);
		return;
	end

	DamageMeters_bannedTable[DamageMeters_tables[DMT_VISIBLE][index].player] = 1;
	DamageMeters_DoDelete(index);
end

function DamageMeters_ListBanned()
	local index, name, unused;
	index = 1;
	DMPrint(DM_MSG_LISTBANNED);
	for name, unused in DamageMeters_bannedTable do
		DMPrint(index..": "..name);
		index = index + 1;
	end
end

function DamageMeters_ClearBanned()
	DMPrint(DM_MSG_CLEARBANNED);
	DamageMeters_bannedTable = {};
end

function DamageMeters_IsBanned(newPlayer)
	local name, unused;
	for name, unused in DamageMeters_bannedTable do
		if (name == newPlayer) then
			return true;
		end
	end	

	return false;
end

function DamageMetersBar_ToggleShow()
	if (DamageMetersFrame:IsVisible()) then
		DMPrint(DM_MSG_HOWTOSHOW);
	end

	DamageMeters_ToggleShow();
end

function DamageMeters_Sync(arg1)
	if (not DamageMeters_syncChannel or DamageMeters_syncChannel == "") then
		DMPrint(DM_ERROR_NOSYNCCHANNEL);
		return;
	end

	if (not DamageMeters_CheckSyncChan()) then
		return;
	end

	DamageMeters_syncEvents = false;
	local delaySync = false;
	for	optionLetter, optionValue in string.gfind(arg1, "(%a)(%d*)") do
		if (optionLetter == "d") then
		--DMPrintD("d found");
			if (optionValue) then
				--DMPrintD("optionValue = "..optionValue);
				local timeUntilSync = tonumber(optionValue);
				if (timeUntilSync and timeUntilSync > 0) then
					DamageMeters_syncStartTime = GetTime() + timeUntilSync;			
					DamageMeters_SendSyncMsg(string.format("<Sync incoming in %d seconds.>", timeUntilSync));
					delaySync = true;
				end
			end
		elseif (optionLetter == "e") then
			--DMPrintD("e found");
			DamageMeters_syncEvents = true;
		end
	end

	if (not delaySync) then
		DamageMeters_DoSync();
	end
end

function DamageMeters_SyncStart(label)
	if (not label or label == "") then
		DMPrint(DM_ERROR_MISSINGARG);
		return;
	end	
	if (not DamageMeters_CheckSyncChan()) then
		return;
	end

	DamageMeters_SyncLabel(label);
	if (DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex == 1) then
		DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex = 0;
	end
	DamageMeters_SyncPause();
	DamageMeters_SyncClear();
end

function DamageMeters_SyncLabel(label)
	if (not label or label == "") then
		DMPrint(DM_ERROR_MISSINGARG);
		return;
	end	

	if (DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel ~= label) then
		DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex = 1;
	end
	DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel = label;
	DMPrintD(label..", new label = "..DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel);

	DMPrint(string.format(DM_MSG_SETLABEL, DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel, DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex));
end

function DamageMeters_DoSync()
	DamageMeters_SyncRequest();
	DamageMeters_SyncReport();
	--DamageMeters_requestSyncWhenReportDone = true;
end

function DamageMeters_SyncReport()
	if (not DamageMeters_syncChannel or DamageMeters_syncChannel == "") then
		DMPrint(DM_ERROR_NOSYNCCHANNEL);
		return;
	end

	if (not DamageMeters_CheckSyncChan()) then
		return;
	end

	if (table.getn(DamageMeters_syncMsgQueue) > 0) then
		DMPrintD("Already reporting.");
		return;
	end

	if (DamageMeters_syncEvents) then
		DMPrint(DM_MSG_SYNCEVENTS, nil, true);
	else
		DMPrint(DM_MSG_SYNC, nil, true);
	end
	local channelName = GetChannelName(DamageMeters_syncChannel)	
	SendChatMessage(DamageMeters_SYNCSTART, "CHANNEL", nil, channelName);

	DamageMeters_DoSyncReport();

	-- Add finishing msg to queue, including any extra data.
	if (1) then
		local msg = string.format("%s", DamageMeters_SYNCEND);
		DamageMeters_AddMsgToSyncQueue(msg);
	end
end

function DamageMeters_DoSyncReport()
	if (not DamageMeters_syncChannel or DamageMeters_syncChannel == "") then
		DMPrint(DM_ERROR_NOSYNCCHANNEL);
		return;
	end

	if (not DamageMeters_CheckSyncChan()) then
		return;
	end

	local startIndex = 1;
	local endIndex = table.getn(DamageMeters_tables[DMT_ACTIVE]);
	--DMPrintD("sync indexes: "..startIndex.."->"..endIndex.."("..table.getn(DamageMeters_tables[DMT_ACTIVE])..")");

	local channelName = GetChannelName(DamageMeters_syncChannel)

	local formatStr = DMSYNC_PREFIX..DMSYNC_QUANTFORMATSTR;
	local index;
	for index = startIndex, endIndex do
		local info = DamageMeters_tables[DMT_ACTIVE][index];
		local playerName = info.player;
		if (DamageMeters_debug3.syncSelfTestMode) then
			playerName = playerName.."x";
		end

		local msg = DamageMeters_GenerateQuantityString(formatStr, playerName, info);
		DamageMeters_AddMsgToSyncQueue(msg);
	end

	-----
	if (DamageMeters_syncEvents) then
		-- Dump events for ourselves only.

		local index, playerStruct;
		for index, playerStruct in DamageMeters_tables[DMT_ACTIVE] do 
			DamageMeters_SyncSendPlayerEvents(playerStruct);
		end
	end
	-- Reset variable: we are done with it.
	DamageMeters_syncEvents = false;

	-------------

	local queueSize = table.getn(DamageMeters_syncMsgQueue);
	DamageMeters_sendMsgQueueBar:Show();
	DamageMeters_sendMsgQueueBar:SetMinMaxValues(0, queueSize);
	DamageMeters_sendMsgQueueBar:SetValue(queueSize);
	DamageMeters_sendMsgQueueBarText:SetText(DM_MENU_SENDINGBAR);
end

function DamageMeters_GenerateQuantityString(formatStr, playerName, info)
	local msg = format(formatStr, playerName, 
		info.q[DMI_DAMAGE], info.q[DMI_HEALING], info.q[DMI_DAMAGED], info.q[DMI_HEALED], info.q[DMI_CURING],
		info.hitCount[DMI_DAMAGE],  info.critCount[DMI_DAMAGE], 
		info.hitCount[DMI_HEALING], info.critCount[DMI_HEALING], 
		info.hitCount[DMI_DAMAGED], info.critCount[DMI_DAMAGED], 
		info.hitCount[DMI_HEALED],  info.critCount[DMI_HEALED],
		info.hitCount[DMI_CURING], info.critCount[DMI_CURING]);

	return msg;
end

function DamageMeters_SyncSendPlayerEvents(playerStruct)
	local playerName = playerStruct.player;
	local playerEventStruct = playerStruct.events;
	if (DamageMeters_debug3.syncSelfTestMode) then
		playerName = playerName.."x";
	end

	if (nil == playerEventStruct) then
		return;
	end

	local quantity, quantityStruct;
	for quantity, quantityStruct in playerEventStruct do
		--DMPrintD(quantity.." hash n = "..table.getn(quantityStruct.hash));

		if (quantityStruct.dirty) then
			DamageMeters_BuildSpellHash(quantityStruct);
		end

		local hashCount = table.getn(quantityStruct.hash);
		for hashIndex = 1, hashCount do
			local formatStr = " %d <%s> %d %d %d %d %d %d; ";
			local msg = DMSYNC_EVENT_PREFIX.."["..playerName.."]";
			local msgLen = string.len(msg);

			local eventIx;
			-- 10 max events per msg.
			local eventCount = math.min(10, hashCount - hashIndex + 1);
			hashIndex = hashIndex - 1;
			for eventIx = 1, eventCount do
				hashIndex = hashIndex + 1;
				local spell = quantityStruct.hash[hashIndex].spell;
				spellStruct = quantityStruct.spellTable[spell];

				newMsgPart = string.format(formatStr, quantity, spell,
					spellStruct.value, spellStruct.counts[1], spellStruct.counts[2],
					spellStruct.damageType, spellStruct.resistanceSum, spellStruct.resistanceCount);
				local newPartLen = string.len(newMsgPart);

				local MAX_MSG_LEN = 255;
				if (newPartLen + msgLen >= MAX_MSG_LEN) then
					--DMPrintD("Aborting at eventIx = "..eventIx);
					hashIndex = hashIndex - 1;
					break;
				else
					msg = msg..newMsgPart;	
					msgLen = msgLen + newPartLen;
				end
			end

			DamageMeters_AddMsgToSyncQueue(msg);
		end
	end	
end

function DamageMeters_SyncChan(arg1)
	if (not arg1 or arg1 == "") then
		DMPrint(DM_ERROR_MISSINGARG);
	else 
		local autobroadcast = false;
		local params = arg1;
		if (string.sub(params, 1, 3) == "-b ") then
			autobroadcast = true;
			params = string.sub(params, 4);
		end

		-- Leave the current channel if we are in a different one.
		if (params ~= DamageMeters_syncChannel) then
			if (DamageMeters_syncChannel and (GetChannelName(DamageMeters_syncChannel) ~= 0)) then
				LeaveChannelByName(DamageMeters_syncChannel);
			end	
		end

		DamageMeters_syncChannel = params;
		DMPrint(DM_MSG_SYNCCHAN..DamageMeters_syncChannel);

		if (0 == GetChannelName(DamageMeters_syncChannel)) then
			-- Autojoin the channel.
			JoinChannelByName(DamageMeters_syncChannel, nil, DEFAULT_CHAT_FRAME:GetID());
		end

		-- Automatically remove channel from the frame's list.
		ChatFrame_RemoveChannel(DEFAULT_CHAT_FRAME, DamageMeters_syncChannel);

		if (autobroadcast) then
			DamageMeters_SyncBroadcastChan();
		end
	end
end

function DamageMeters_SyncBroadcastChan()
	if (not DamageMeters_CheckSyncChan()) then
		--DMPrint(DM_ERROR_NOSYNCCHANNEL);
		return;
	end

	local targetChannel = "";
	if (GetNumRaidMembers() > 0) then
		targetChannel = "RAID";
	elseif (GetNumPartyMembers() > 0) then
		targetChannel = "PARTY";
	else
		DMPrint(DM_ERROR_BROADCASTNOGROUP);
		return;
	end

	local msg = DM_MSG_SYNCCHANBROADCAST..DamageMeters_syncChannel;
	SendChatMessage(msg, targetChannel, nil, nil);
end

function DamageMeters_SyncLeaveChanCmd()
	DamageMeters_SyncLeaveChan(true);
end

function DamageMeters_SyncLeaveChan(bVerbose)
	if (not DamageMeters_syncChannel or DamageMeters_syncChannel == "") then
		DMPrint(DM_ERROR_NOSYNCCHANNEL);
		return;
	end

	if (GetChannelName(DamageMeters_syncChannel) ~= 0) then
		if (bVerbose) then
			DMPrint(string.format(DM_MSG_LEAVECHAN, DamageMeters_syncChannel));
		end

		LeaveChannelByName(DamageMeters_syncChannel);
	end

	DamageMeters_syncChannel = "";
end

function DamageMeters_SyncRequest()
	if (not DamageMeters_CheckSyncChan()) then
		return;
	end

	local msg = DamageMeters_SYNCREQUEST;
	if (DamageMeters_syncEvents) then
		msg = msg.."E";
	end
	if (DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel) then
		msg = string.format("%s <%s %d>", msg, DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel, DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex);
	end
	SendChatMessage(msg, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));
end

function DamageMeters_SyncClear()
	if (not DamageMeters_CheckSyncChan()) then
		return;
	end	

	DMPrint(DM_MSG_SYNCCLEARREQ);
	DamageMeters_Clear(0, true);

	local msg = DamageMeters_SYNCCLEARREQUEST;
	if (DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel) then
		DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex = DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex + 1;
		DMPrintD("Incremented DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex to "..DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex);
		msg = string.format("%s %s %d", msg, DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel, DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex);
	end
	SendChatMessage(msg, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));
end

function DamageMeters_CheckSyncChan(bSilent)
	local channelName = GetChannelName(DamageMeters_syncChannel);
	--DMPrint("channelName = "..channelName);
	if (channelName == 0) then
		if (not bSilent) then
			DMPrint(format(DM_ERROR_JOINSYNCCHANNEL, DamageMeters_syncChannel));
		end
		return false;
	end

	return true;
end

function DamageMeters_SyncPingRequest()
	DMPrint(DM_MSG_PINGING);
	SendChatMessage(DamageMeters_SYNCPINGREQ, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));
end

function DamageMeters_SyncPause()
	DMPrint(DM_MSG_SYNCPAUSEREQ);
	SendChatMessage(DamageMeters_SYNCPAUSEREQ, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));

	if (DM_Pause_Pause ~= DamageMeters_pauseState) then
		DamageMeters_pauseState = DM_Pause_Paused;
		DamageMeters_CompletePauseChange();
	end
end

function DamageMeters_SyncUnpause(silent, details)
	if (not silent) then
		DMPrint(DM_MSG_SYNCUNPAUSEREQ);
	end
	local msg = DamageMeters_SYNCUNPAUSEREQ;
	if (details) then
		msg = msg.." "..details;
	end
	SendChatMessage(msg, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));

	if (DM_Pause_Not ~= DamageMeters_pauseState) then
		DamageMeters_pauseState = DM_Pause_Not;
		DamageMeters_CompletePauseChange(silent);
	end
end

function DamageMeters_SyncReady()
	DamageMeters_SetReady();
	if (DamageMeters_CheckSyncChan(true)) then
		DMPrint(DM_MSG_SYNCREADYREQ);
		SendChatMessage(DamageMeters_SYNCREADYREQ, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));
	end
end

function DamageMeters_SyncKick(arg1)
	if (not DamageMeters_CheckSyncChan()) then
		return;
	end	

	if (nil == arg1 or "" == arg1) then
		DMPrint(DM_ERROR_MISSINGARG);
		return;
	end

	SendChatMessage(DamageMeters_SYNCKICK.." "..arg1, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));
end

function DamageMeters_SyncEmote(arg1)
	if (not DamageMeters_CheckSyncChan()) then
		return;
	end	

	if (not arg1) then
		return;
	end

	local player = nil;
	local message = arg1;
	if (string.sub(arg1, 1, 1) == "@") then
		local a,b;
		for a, b in string.gfind(arg1, "@(%a+) (.+)") do
			player = a;
			message = b;
		end
	end

	-- Do target replacement.
	local target = UnitName("Target");
	if (nil == target) then
		target = "nobody";
	end
	local repStart, repEnd = string.find(message, "%%t");
	while (repStart ~= nil) do
		message = string.sub(message, 1, repStart - 1)..target..string.sub(message, repEnd + 1);
		repStart, repEnd = string.find(message, "%%t");
	end

	--------

	-- Send the message.
	if (nil == player) then player = ""; end
	local msg = DamageMeters_SYNCEMOTE.." <"..player.."> "..message;
	SendChatMessage(msg, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));

	if (player ~= "") then
		DMPrint("[DME -> "..player.."] "..UnitName("Player").." "..message, DamageMeters_SYNCEMOTECOLOR);
	else
		DMPrint("[DME] "..UnitName("Player").." "..message, DamageMeters_SYNCEMOTECOLOR);
	end
end

function DamageMeters_DecodeEmote(source, msg)
	for target, message in string.gfind(msg, "<(.*)> (.+)") do
		
		if (target ~= "") then
			local target = string.lower(target);
			local ourName = string.lower(UnitName("Player"));
			if (target ~= ourName) then
				return;
			end

			DMPrint("[DME "..WHISPER.."] "..source.." "..message, DamageMeters_SYNCEMOTECOLOR);
		else
			DMPrint(source.." "..message, DamageMeters_SYNCEMOTECOLOR);
		end
	end
end

function DamageMeters_SyncPingReply(pinger)
	local msg = DamageMeters_SYNCPING.." <"..pinger.."> <"..DamageMeters_VERSIONSTRING;
	if (DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel) then
		msg = string.format("%s [%s #%d]", msg, DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel, DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex);
	end
	msg = msg..">";
	SendChatMessage(msg, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));
end

function DamageMeters_AddNewPlayerComplete(tableIndex, playerName, relationship)
	local index = DamageMeters_GetPlayerIndex(playerName, tableIndex);
	if (nil == index) then
		index = DamageMeters_AddNewPlayer(DamageMeters_tables[tableIndex], playerName);
		DamageMeters_SetRelationship(index, relationship);
	end
	return index;
end

function DamageMeters_Populate()
	local numPartyMembers = GetNumPartyMembers();
	local numRaidMembers = GetNumRaidMembers();

	local oldLocked = DamageMeters_listLocked;
	DamageMeters_listLocked = false;

	if (numRaidMembers > 0) then
		DamageMeters_AddNewPlayerComplete(DMT_ACTIVE, UnitName("Player"), DamageMeters_Relation_SELF);

		local name, rank, subgroup, level, class, fileName, zone, online, isDead;
		local i;
		for i = 1,numRaidMembers do
			name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i);
			DamageMeters_AddNewPlayerComplete(DMT_ACTIVE, name, DamageMeters_Relation_FRIENDLY);
		end
	elseif (numPartyMembers > 0) then
		DamageMeters_AddNewPlayerComplete(DMT_ACTIVE, UnitName("Player"), DamageMeters_Relation_SELF);

		for i=1,5 do
			local partyUnitName = "party"..i;
			local partyName = UnitName(partyUnitName);
			if (partyName and partyName ~= "") then
				DamageMeters_AddNewPlayerComplete(DMT_ACTIVE, partyName, DamageMeters_Relation_PARTY);
			end
		end	
	else
		DMPrint(DM_ERROR_POPNOPARTY);
	end

	DamageMeters_listLocked = oldLocked;
end

function DamageMeters_ToggleLock()
	DamageMeters_listLocked = not DamageMeters_listLocked;
	if (DamageMeters_listLocked) then
		DMPrint(DM_MSG_LOCKED);
	else
		DMPrint(DM_MSG_NOTLOCKED);
	end
end

function DamageMeters_CompletePauseChange(silent)
	if (not silent) then
		if (DM_Pause_Not ~= DamageMeters_pauseState) then
			DMPrint(DM_MSG_PAUSED);
		else
			DMPrint(DM_MSG_UNPAUSED);
		end
	end
	DamageMeters_SetBackgroundColor();

	if (DM_Pause_Not == DamageMeters_pauseState) then
		if (DamageMeters_playerInCombat) then
			--DMPrintD("Starting combat via unpausing.");
			DamageMeters_OnCombatStart();
		end
	else
		if (DamageMeters_inCombat) then
			DamageMeters_OnCombatEnd();
		end
	end
end

function DamageMeters_TogglePause(silent)
	if (DM_Pause_Not ~= DamageMeters_pauseState) then
		DamageMeters_pauseState = DM_Pause_Not;
	else
		DamageMeters_pauseState = DM_Pause_Paused;
	end

	DamageMeters_CompletePauseChange(silent);
end

function DamageMeters_SetReady()
	if (DamageMeters_pauseState ~= DM_Pause_Ready) then
		DamageMeters_pauseState = DM_Pause_Ready;
		DamageMeters_CompletePauseChange(true);
		--DMPrint("DamageMeters: Ready state activated; DM will automatically unpause on the next damage event.");
	end
end

function DamageMeters_ToggleLockPos()
	DamageMeters_flags[DMFLAG_positionLocked] = not DamageMeters_flags[DMFLAG_positionLocked];
	if (DamageMeters_flags[DMFLAG_positionLocked]) then
		DamageMetersFrame:StopMovingOrSizing();
		DamageMetersFrame:EnableMouse(0);
		DMPrint(DM_MSG_POSLOCKED);
	else
		DamageMetersFrame:EnableMouse(1);
		DMPrint(DM_MSG_POSNOTLOCKED);
	end
	CloseMenus();
end

function DamageMeters_SetQuantityColor()
	local r,g,b = ColorPickerFrame:GetColorRGB();
	DamageMeters_quantityColor[UIDROPDOWNMENU_MENU_VALUE][1] = r;
	DamageMeters_quantityColor[UIDROPDOWNMENU_MENU_VALUE][2] = g;
	DamageMeters_quantityColor[UIDROPDOWNMENU_MENU_VALUE][3] = b;
	DamageMeters_flags[DMFLAG_cycleVisibleQuantity] = false;
	DamageMeters_frameNeedsToBeGenerated = true;
	DamageMeters_tablesDirty = true;
end

function DamageMeters_SetQuantityColorOpacity()
	local alpha = 1.0 - OpacitySliderFrame:GetValue();
	DamageMeters_quantityColor[UIDROPDOWNMENU_MENU_VALUE][4] = alpha;
	DamageMeters_frameNeedsToBeGenerated = true;
end

function DamageMeters_CancelQuantityColorSettings(previousValues)
	if ( previousValues.r ) then
		DamageMeters_quantityColor[UIDROPDOWNMENU_MENU_VALUE][1] = previousValues.r;
		DamageMeters_quantityColor[UIDROPDOWNMENU_MENU_VALUE][2] = previousValues.g;
		DamageMeters_quantityColor[UIDROPDOWNMENU_MENU_VALUE][3] = previousValues.b;
		if (previousValues.opacity) then
			--DMPrint("previousValues.opacity = "..previousValues.opacity);
			DamageMeters_quantityColor[UIDROPDOWNMENU_MENU_VALUE][4] = 1.0 - previousValues.opacity
		end
	end
	DamageMeters_frameNeedsToBeGenerated = true;
end

function DamageMeters_SetQuantityColorAllOnClick()
	local frame = this:GetParent();

	frame.text = DM_MENU_SETCOLORFORALL;
	frame.func = DamageMeters_SetQuantityColorAll;
	frame.swatchFunc = DamageMeters_SetQuantityColorAll;
	frame.hasColorSwatch = 1;
	frame.r = DamageMeters_quantityColor[DamageMeters_quantity][1];
	frame.g = DamageMeters_quantityColor[DamageMeters_quantity][2];
	frame.b = DamageMeters_quantityColor[DamageMeters_quantity][3];
	frame.hasOpacity = 1;
	frame.opacity = 1.0 - DamageMeters_quantityColor[DamageMeters_quantity][4];
	frame.opacityFunc = DamageMeters_SetQuantityColorOpacityAll;
	frame.notCheckable = 1;

	ColorPickerFrame.frame = frame;
	CloseMenus();
	UIDropDownMenuButton_OpenColorPicker(frame);
end

function DamageMeters_SetDefaultColors()
	DamageMeters_quantityColor = {};
	local quant;
	for quant = 1, DamageMeters_Quantity_MAX do
		DamageMeters_quantityColor[quant] = DM_clone(DM_QUANTDEFS[quant].defaultColor);
	end
	DamageMeters_frameNeedsToBeGenerated = true;
end

function DamageMeters_SetQuantityColorAll()
	local r,g,b = ColorPickerFrame:GetColorRGB();
	local index;
	for index = 1, DamageMeters_Quantity_MAX do
		DamageMeters_quantityColor[index][1] = r;
		DamageMeters_quantityColor[index][2] = g;
		DamageMeters_quantityColor[index][3] = b;
	end
	DamageMeters_frameNeedsToBeGenerated = true;
end

function DamageMeters_SetQuantityColorOpacityAll()
	local alpha = 1.0 - OpacitySliderFrame:GetValue();
	local index;
	for index = 1, DamageMeters_Quantity_MAX do
		DamageMeters_quantityColor[index][4] = alpha;
	end
	DamageMeters_frameNeedsToBeGenerated = true;
end

function DamageMeters_ToggleResetWhenCombatStarts()
	DamageMeters_flags[DMFLAG_resetWhenCombatStarts] = not DamageMeters_flags[DMFLAG_resetWhenCombatStarts];
	-- Only print message if we weren't called from the menu option.
	if (not this.value) then
		DMPrint(DM_MSG_RESETWHENCOMBATSTARTSCHANGE..(DamageMeters_flags[DMFLAG_resetWhenCombatStarts] and DM_MSG_TRUE or DM_MSG_FALSE));
	end
end

function DamageMeters_ToggleShowFightAsPS()
	DamageMeters_flags[DMFLAG_showFightAsPS] = not DamageMeters_flags[DMFLAG_showFightAsPS];
	-- Only print message if we weren't called from the menu option.
	if (this and not this.value) then
		DMPrint(DM_MSG_SHOWFIGHTASPS..(DamageMeters_flags[DMFLAG_showFightAsPS] and DM_MSG_TRUE or DM_MSG_FALSE));
	end
	DamageMeters_SetQuantity(DamageMeters_quantity, true);
end

function DamageMeters_ToggleNormalAndFight()
	local newQuant = DM_QUANTDEFS[DamageMeters_quantity].toggleQuant;
	if (newQuant ~= nil) then
		DamageMeters_SetQuantity(newQuant, nil);
	end
end

function DamageMeters_OnCombatStart()
	DamageMeters_combatStartTime = GetTime();
	DamageMeters_combatEndTime = DamageMeters_combatStartTime;
	DamageMeters_inCombat = true;
	--DMPrintD("Starting combat...");

	-- Clear the combat table.
	DamageMeters_DoClear(DMT_FIGHT, 0, true);

	--[[ Threat
	-- The logic is this:
	-- Threat is cleared on combat when:
	-- 1) You're not in a party.
	-- 2) You're in a party, but not participating in threat sync'ing.
	-- 3) You're in a party and participating, but you're forcing threat clear.
	if (ThreatMeters["ForceClearThreatOnCombatStart"] or not DamageMeters_InParty() or not ThreatMeters["SyncParticipate"]) then
		ThreatMeters_ClearThreat();
	end
	]]--
end

function DamageMeters_OnCombatEnd()
	DamageMeters_combatEndTime = GetTime();
	--DMPrintD("Ending combat, duration = "..(DamageMeters_combatEndTime - DamageMeters_combatStartTime));
	DamageMeters_inCombat = false;

	-- This is...complicated.
	--DamageMeters_tableInfo[DMT_ACTIVE].totalCombatTime = (DamageMeters_combatEndTime - DamageMeters_combatStartTime) + DamageMeters_tableInfo[DMT_ACTIVE].totalCombatTime;

	DamageMeters_startCombatOnNextValue = true;
end

function DamageMeters_GetCombatValuePS(combatValue)
	local combatTime = DamageMeters_combatEndTime - DamageMeters_combatStartTime;
	if (combatTime <= 1.0) then
		combatTime = 1.0;
	end
	return combatValue / combatTime;
end

function DamageMeters_OpenReportFrame()
	CloseDropDownMenus();

	ShowUIPanel(DMReportFrame);
	DMReportFrame:SetBackdropColor(0, 0, 0, 1);
	DMSendMailScrollFrame:SetBackdropColor(0, 0, 0, 1);
	DamageMeters_UpdateReportText();
end

function DamageMeters_UpdateReportText()
	DMReportFrame_SendMailBodyEditBox:SetText(DamageMeters_reportBuffer);
	DMReportFrame_SendMailBodyEditBox:SetFocus("");
	DMReportFrame_SendMailBodyEditBox:HighlightText();
end

function DamageMeters_ReportTypeDropDown_OnLoad()
	UIDropDownMenu_Initialize(this, DamageMeters_ReportTypeDropDown_Initialize, "MENU");
end

function DamageMeters_ReportTypeDropDown_Initialize()
	local index;
	for index = 1,DamageMeters_Quantity_MAX do
		info = {};
		info.text = DM_QUANTDEFS[index].name;
		info.value = index;
		info.func = DamageMeters_ReportFrame_DoReport;
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info);
	end	

	info = {};
	info.text = DM_MENU_TOTAL;
	info.value = DamageMeters_ReportQuantity_Total;
	info.func = DamageMeters_ReportFrame_DoReport;
	info.notCheckable = 1
	UIDropDownMenu_AddButton(info);

	info = {};
	info.text = DM_MENU_LEADERS;
	info.value = DamageMeters_ReportQuantity_Leaders;
	info.func = DamageMeters_ReportFrame_DoReport;
	info.notCheckable = 1
	UIDropDownMenu_AddButton(info);

	local index;
	for index = 1, 3 do
		info = {};
		info.text = getglobal("DM_MENU_EVENTS"..index);
		info.value = index;
		info.func = DamageMeters_ReportFrame_DoEventReport;
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info);
	end

	if (DamageMeters_debugEnabled) then
		info = {};
		info.text = "Missed Messages";
		info.func = DamageMeters_ReportMissed;
		info.notCheckable = 1
		UIDropDownMenu_AddButton(info);
	end
end

function DamageMeters_ReportFrame_DoReport()
	DamageMeters_DoReport(this.value, "BUFFER", false, 1, DamageMeters_TABLE_MAX, "");
	DamageMeters_UpdateReportText();
end

function DamageMeters_ReportFrame_DoEventReport()
	local start = ((this.value - 1) * 20) + 1;
	DamageMeters_DoReport(DamageMeters_ReportQuantity_Events, "BUFFER", false, start, 20, "");
	DamageMeters_UpdateReportText();
end

function DamageMeters_ReportTypeButton_OnClick()
	ToggleDropDownMenu(1, nil, DMReportTypeDropDown, "DMReportTypeDropDown", 0, 0);
end

function DamageMeters_ShowReportFrame()
	DamageMeters_Report("f");
end

function DamageMeters_DumpContributors()
	local playerName, unused;
	DMPrint(table.getn(DamageMeters_contributorList).." contributors:");
	for playerName, unused in DamageMeters_contributorList do
		DMPrint(" "..playerName);
	end
end

function DamageMetersBar_DoPlayerReport()
	local destination = "BUFFER";
	DamageMeters_reportBuffer = "";

	DamageMeters_DoPlayerReport(DamageMeters_tables[DMT_VISIBLE][DamageMeters_clickedBarIndex].player, destination);

	if (destination == "BUFFER") then
		DamageMeters_OpenReportFrame();
	end
end

function DamageMetersBar_DumpPlayerEvents()
	local destination = "BUFFER";
	DamageMeters_reportBuffer = "";

	DamageMeters_DumpPlayerEvents(DamageMeters_tables[DMT_VISIBLE][DamageMeters_clickedBarIndex].player, destination, true);

	if (destination == "BUFFER") then
		DamageMeters_OpenReportFrame();
	end
end

function DamageMeters_ShowVersion()
	DMPrint(string.format(DM_MSG_VERSION, DamageMeters_VERSIONSTRING));
end

function DamageMeters_ShowReportHelp()
	DamageMeters_reportBuffer = DM_MSG_REPORTHELP;
	DamageMeters_OpenReportFrame();
	DMReportFrame_SendMailBodyEditBox:HighlightText(0, 0)
end

function DamageMeters_ShowSyncHelp()
	DamageMeters_reportBuffer = DM_MSG_SYNCHELP;
	DamageMeters_OpenReportFrame();
	DMReportFrame_SendMailBodyEditBox:HighlightText(0, 0)
end

function DamageMeters_ToggleAccumulateToMemory()
	DamageMeters_flags[DMFLAG_accumulateToMemory] = not DamageMeters_flags[DMFLAG_accumulateToMemory];	
	DMPrintD("Accumulate = "..(DamageMeters_flags[DMFLAG_accumulateToMemory] and "true" or "false"));
end

function DamageMeters_SendSyncMsg(arg1)
	if (not DamageMeters_CheckSyncChan()) then
		return;
	end

	if (not arg1 or arg1 == "") then
		DMPrint(DM_ERROR_MISSINGARG);
		return;
	end

	-- "|HPlayer:%s|h[%s]|h"
	DMPrint(format(DM_MSG_SYNCMSG, UnitName("Player"), UnitName("Player"), arg1), DamageMeters_SYNCMSGCOLOR);

	local msg = DamageMeters_SYNCMSG..arg1;
	SendChatMessage(msg, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));
end

function DamageMeters_ToggleMaxBars(bSilent)
	DamageMeters_ToggleViewMode(DMVIEW_MAX);

	DamageMeters_frameNeedsToBeGenerated = true;
	if (not bSilent) then
		DMPrint(format(DM_MSG_MAXBARS, ((DMVIEW_MAX == DamageMeters_viewMode) and DM_MSG_TRUE or DM_MSG_FALSE)));
	end
end

function DamageMeters_ToggleViewMode(toggleMode)
	if (toggleMode == DamageMeters_viewMode) then
		DMPrintD("Setting viewmode to normal.");
		DamageMeters_viewMode = DMVIEW_NORMAL;
		DamageMeters_barCount = DamageMeters_savedBarCount;
	else
		if (DMVIEW_NORMAL == DamageMeters_viewMode) then
			DMPrintD("Setting saved bar count to "..DamageMeters_barCount);
			DamageMeters_savedBarCount = DamageMeters_barCount;	
		end
		DMPrintD("Setting viewmode to "..toggleMode);
		DamageMeters_viewMode = toggleMode;
	end
end

function DamageMeters_ForceNormalView()
	if (DMVIEW_NORMAL ~= DamageMeters_viewMode) then
		DamageMeters_barCount = DamageMeters_savedBarCount;
		DMPrintD("Setting viewmode to normal.");
		DamageMeters_viewMode = DMVIEW_NORMAL;
	end
end

function DamageMeters_ChangeEventDataLevel()
	DamageMeters_eventDataLevel = this.value;
	DMPrint(DM_MSG_EVENTDATALEVEL[DamageMeters_eventDataLevel]);
end

function DamageMeters_ChangeSyncEventDataLevel()
	DamageMeters_syncEventDataLevel = this.value;
	DMPrint(DM_MSG_SYNCEVENTDATALEVEL[DamageMeters_syncEventDataLevel]);
end

function DamageMeters_ReportMissed()
	local destination = "BUFFER";
	DamageMeters_reportBuffer = "";

	local msg = table.getn(DamageMeters_missedMessages).." missed messages:";
	DamageMeters_SendReportMsg(msg, destination);

	local index;
	for index = 1, table.getn(DamageMeters_missedMessages) do
		DamageMeters_SendReportMsg(DamageMeters_missedMessages[index], destination);
	end

	if (destination == "BUFFER") then
		DamageMeters_OpenReportFrame();
	end
end

function DamageMeters_ToggleDebugVariable()
	DamageMeters_debug3[this.value] = not DamageMeters_debug3[this.value];
end

function DamageMeters_ProcessSyncMsg(msg, arg2)
	local player, damage, damaged, healing, healed, hitCountDmg, critCountDmg, hitCountHeal, critCountHeal, hitCountDamaged, critCountDamaged, hitCountHealed, critCountHealed;
	--                                 name dmg   dmged  heal  hld  cured dmgh  dmgc  hlh   hlc   dmdh  dmdc  hldh  hldc  cureh curec
	local formatStr = DMSYNC_PREFIX.." (.+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+) (%d+)";
	for		player, 
			damage, healing, damaged, healed, cured,
			hitCountDmg, critCountDmg, 
			hitCountHeal, critCountHeal, 
			hitCountDamaged, critCountDamaged, 
			hitCountHealed, critCountHealed,
			hitCountCured, critCountCured
				in string.gfind(msg, formatStr) do
		local incQuant = {};
		local incHitCount = {};
		local incCritCount = {};
		incQuant[DMI_DAMAGE] = tonumber(damage);
		incQuant[DMI_HEALING] = tonumber(healing);
		incQuant[DMI_DAMAGED] = tonumber(damaged);
		incQuant[DMI_HEALED] = tonumber(healed);
		incQuant[DMI_CURING] = tonumber(cured);
		incHitCount[DMI_DAMAGE] = tonumber(hitCountDmg);
		incCritCount[DMI_DAMAGE] = tonumber(critCountDmg);
		incHitCount[DMI_HEALING] = tonumber(hitCountHeal);
		incCritCount[DMI_HEALING] = tonumber(critCountHeal);
		incHitCount[DMI_DAMAGED] = tonumber(hitCountDamaged);
		incCritCount[DMI_DAMAGED] = tonumber(critCountDamaged);
		incHitCount[DMI_HEALED] = tonumber(hitCountHealed);
		incCritCount[DMI_HEALED] = tonumber(critCountHealed);
		incHitCount[DMI_CURING] = tonumber(hitCountCured);
		incCritCount[DMI_CURING] = tonumber(critCountCured);

		-- We have recieved data from a contributor: add him/her to the list.
		DamageMeters_contributorList[arg2] = true;
		DamageMeters_flags[DMFLAG_haveContributors] = true;

		local index = DamageMeters_GetPlayerIndex(player);
		if (not index) then
			-- There is a problem: if the other player is parsing damage for our pet
			-- we could erroneously add it again to our own if we have the option turned 
			-- on.  This condition attempts to fix that problem.
			if (DamageMeters_flags[DMFLAG_addPetToPlayer] and player == UnitName("Pet")) then
				return;
			end

			index = DamageMeters_AddNewPlayer(DamageMeters_tables[DMT_ACTIVE], player);
			DamageMeters_SetRelationship(index, DamageMeters_Relation_FRIENDLY);

			if (not index) then
				DMPrintD("Couldn't add new player from sync'ing.");
				return;
			end
			if (DamageMeters_debug3.showSyncChanges) then
				DMPrintD("DMSYNC("..arg2.."): Adding new player, "..player..".", nil, true);
			end
		end
		
		local localStruct = DamageMeters_tables[DMT_ACTIVE][index];

		local quantIndex;
		-- Note: We don't sync DMI_THREAT.
		--! BUT NOTE: WE DO SYNC CURING, and so this kind of cludgy code here.
		for quantIndex = 1, DMI_CURING do
			if (incQuant[quantIndex] > localStruct.q[quantIndex]) then
				if (DamageMeters_debug3.showSyncChanges) then
					DMPrintD("DMSYNC("..arg2.."): "..player.."["..DM_QUANTDEFS[quantIndex].name.."] "..localStruct.q[quantIndex].." -> "..incQuant[quantIndex], nil, true);
				end
				localStruct.q[quantIndex] = incQuant[quantIndex];
				DamageMeters_tablesDirty = true;
			end

			if (incHitCount[quantIndex] > localStruct.hitCount[quantIndex]) then
				if (DamageMeters_debug3.showSyncChanges) then
					DMPrintD("DMSYNC("..arg2.."): "..player.."["..DM_QUANTDEFS[quantIndex].name.." hits] "..localStruct.hitCount[quantIndex].." -> "..incHitCount[quantIndex], nil, true);
				end
				localStruct.hitCount[quantIndex] = incHitCount[quantIndex];
				DamageMeters_tablesDirty = true;
			end
			if (incCritCount[quantIndex] > localStruct.critCount[quantIndex]) then
				if (DamageMeters_debug3.showSyncChanges) then
					DMPrintD("DMSYNC("..arg2.."): "..player.."["..DM_QUANTDEFS[quantIndex].name.." crits] "..localStruct.critCount[quantIndex].." -> "..incCritCount[quantIndex], nil, true);
				end
				localStruct.critCount[quantIndex] = incCritCount[quantIndex];
				DamageMeters_tablesDirty = true;
			end
		end

		return;
	end

	----------------------

	local prefixLen = string.len(DMSYNC_EVENT_PREFIX);
	if (strsub(msg, 1, prefixLen) == DMSYNC_EVENT_PREFIX) then
		msg = strsub(msg, prefixLen + 2);
		local originalMsg = msg;
		local msgLeft = "";

		local quantity, spell, total, hit1, hit2, hit3, misc1, misc2;
		--                   name quant spell   val   c1    c2;

		local endName = string.find(msg, "]");
		local player = string.sub(msg, 1, endName - 1);

		-- may not be an index for this player if it is someone's totem or something
		local index = DamageMeters_GetPlayerIndex(player);
		if (index) then
			msg = string.sub(msg, endName + 1);

			local parsed;
			repeat
				local semicolonIndex = string.find(msg, ";");
				if (semicolonIndex) then
					msgLeft = string.sub(msg, semicolonIndex + 3); -- 1 for semicolon, 1 for following space
					msg = string.sub(msg, 1, semicolonIndex - 1);
				end

				--DMPrint("Parsing '"..msg.."'");

				local formatStr = "(%d+) <(.+)> (%d+) (%d+) (%d+) (%d+) (%d+) (%d+)";
				parsed = false;
				for	quantity, spell, total, hit1, hit2, misc1, misc2, misc3 in string.gfind(msg, formatStr) do
					parsed = true;
					--DMPrint("Parsed! "..player..","..quantity..","..spell..","..total..","..hit1..","..hit2);
					if (DamageMeters_debugEnabled) then
						if (string.sub(player, 1, 1) == " ") then
							DMPrintD("ERROR: Player <"..player.."> starts with space: fixing.");
							DMPrintD("org = >"..originalMsg.."<");
							DMPrintD("msg = >"..msg.."<");
							player = string.sub(player, 2);
						end
					end

					if ((DamageMeters_EventData_ALL == DamageMeters_eventDataLevel) or
						((DamageMeters_EventData_SELF == DamageMeters_eventDataLevel) and (player == UnitName("Player")))) then
						--DMPrintD("Accepting >"..spell.."< event for player "..player, nil, true)

						quantity = tonumber(quantity);
						total = tonumber(total);
						hit1 = tonumber(hit1);
						hit2 = tonumber(hit2);
						misc1 = tonumber(misc1);
						misc2 = tonumber(misc2);
						misc3 = tonumber(misc3);

						local bMsgFromPlayer = (string.lower(player) == string.lower(arg2));

						local playerEventStruct = DamageMeters_tables[DMT_ACTIVE][index].events;
						if (nil == playerEventStruct) then
							if (DamageMeters_debug3.showSyncChanges) then
								DMPrintD("DMSYNCE("..arg2.."): Adding new player, <"..player..">.", nil, true);
							end
							DMPrintD("EventTable: Adding player <"..player..">.");
							DamageMeters_tables[DMT_ACTIVE][index].events = {};
							playerEventStruct = DamageMeters_tables[DMT_ACTIVE][index].events;
						end

						if (nil == playerEventStruct[quantity]) then
							if (DamageMeters_debug3.showSyncChanges) then
								DMPrintD("DMSYNCE("..arg2.."): Adding quantity "..quantity.." to player, <"..player..">.", nil, true);
							end
							playerEventStruct[quantity] = {};
							playerEventStruct[quantity].spellTable = {};
							playerEventStruct[quantity].hash = {};
							playerEventStruct[quantity].dirty = true;
						end

						if (nil == playerEventStruct[quantity].spellTable[spell]) then
							if (DamageMeters_debug3.showSyncChanges) then
								DMPrintD("DMSYNCE("..arg2.."): Adding spell "..spell.." to player <"..player..">.", nil, true);
							end
							playerEventStruct[quantity].spellTable[spell] = {};
							playerEventStruct[quantity].spellTable[spell].value = 0;
							playerEventStruct[quantity].spellTable[spell].counts = {0,0};
							playerEventStruct[quantity].spellTable[spell].damageType = DM_DMGTYPE_DEFAULT;
							playerEventStruct[quantity].spellTable[spell].resistanceSum = 0;
							playerEventStruct[quantity].spellTable[spell].resistanceCount = 0;
						end

						if (playerEventStruct[quantity].spellTable[spell].counts[DM_HIT] < hit1 or
							(playerEventStruct[quantity].spellTable[spell].counts[DM_HIT] == hit1 and bMsgFromPlayer)) then
							if (DamageMeters_debug3.showSyncChanges) then
								DMPrintD(string.format("DMSYNCE("..arg2.."): %s %s: %d -> %d", player, spell, playerEventStruct[quantity].spellTable[spell].value, total), nil, true);
							end
							playerEventStruct[quantity].spellTable[spell].value = total;
							playerEventStruct[quantity].spellTable[spell].counts = {hit1, hit2};
							playerEventStruct[quantity].spellTable[spell].damageType = misc1;
							playerEventStruct[quantity].spellTable[spell].resistanceSum = misc2;
							playerEventStruct[quantity].spellTable[spell].resistanceCount = misc3;
						end

						DamageMeters_tablesDirty = true;
					else
						--DMPrintD("Rejecting >"..spell.."< event for player "..player, nil, true)
					end
				end

				msg = msgLeft;
				msgLeft = "";
			until ((msg == "") or (msg == " ") or (not parsed));

			return;
		end
	end
end

function DamageMeters_AddMsgToSyncQueue(msg, bAddToFront)
	if (bAddToFront == true) then
		table.insert(DamageMeters_syncMsgQueue, 1, msg);
	else
		table.insert(DamageMeters_syncMsgQueue, msg);
	end
end

function DamageMeters_ProcessMessages()
	local now = GetTime();

	-- In the case of lag spikes the time can be very large.
	local numToSend = DamageMeters_MAXSYNCMSGPERFRAME;

	local sent = 0;
	local toSend = getn(DamageMeters_syncMsgQueue);
	if ( getn(DamageMeters_syncMsgQueue) > 0 ) then
		while ( now - DamageMeters_lastSyncMsgTime > DamageMeters_SYNCMSGSENDDELAY) do
			if ( getn(DamageMeters_syncMsgQueue) > 0 ) then
				sent = sent + 1;
				SendChatMessage(DamageMeters_syncMsgQueue[1], "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));
				table.remove(DamageMeters_syncMsgQueue, 1);

				numToSend = numToSend - 1;
				if (numToSend <= 0) then
					DamageMeters_lastSyncMsgTime = now;
					break;
				end
			else
				DamageMeters_lastSyncMsgTime = now;
				break;
			end

			DamageMeters_lastSyncMsgTime = DamageMeters_lastSyncMsgTime + DamageMeters_SYNCMSGSENDDELAY;
		end
	else
		DamageMeters_lastSyncMsgTime = now;
	end

	local leftToSend = getn(DamageMeters_syncMsgQueue);
	-- Note: Using 2 here so periodic update messages don't cause the text to show up.
	if (leftToSend < 2) then
		DamageMeters_sendMsgQueueBar:Hide();
		DamageMeters_sendMsgQueueBarText:SetText("");
	else
		DamageMeters_sendMsgQueueBar:SetValue(leftToSend);
		DamageMeters_sendMsgQueueBarText:SetText(DM_MENU_SENDINGBAR);
	end

	-------------------------

	local processed = 0;
	local toProcess = getn(DamageMeters_syncIncMsgQueue);
	local initialElapsed = now - DamageMeters_lastSyncIncMsgTime;

	if (toProcess > 0) then
		DamageMeters_lastProcessQueueTime = now;
	end

	if ( getn(DamageMeters_syncIncMsgQueue) > 0 ) then
		while (now - DamageMeters_lastSyncIncMsgTime > DamageMeters_SYNCMSGPROCESSDELAY) do
			if ( getn(DamageMeters_syncIncMsgQueue) > 0 ) then
				processed = processed + 1;
				DamageMeters_ProcessSyncMsg(DamageMeters_syncIncMsgQueue[1], DamageMeters_syncIncMsgSourceQueue[1]);
				
				table.remove(DamageMeters_syncIncMsgQueue, 1);
				table.remove(DamageMeters_syncIncMsgSourceQueue, 1);
			else
				DamageMeters_lastSyncIncMsgTime = now;
				break;
			end

			DamageMeters_lastSyncIncMsgTime = DamageMeters_lastSyncIncMsgTime + DamageMeters_SYNCMSGPROCESSDELAY;
		end
	else
		DamageMeters_lastSyncIncMsgTime = now;
	end

	-- GCInfo doesn't show if this code runs.  Hope this doesn't break anything.
	if (not DamageMeters_debug3.showGCInfo) then
		local leftToProcess = getn(DamageMeters_syncIncMsgQueue);
		if ((now - DamageMeters_lastProcessQueueTime) < 1.0) then
			DamageMeters_processMsgQueueBar:Show();
			DamageMeters_processMsgQueueBar:SetValue(leftToProcess);
			DamageMeters_processMsgQueueBarText:SetText(DM_MENU_PROCESSINGBAR);
		elseif (DamageMeters_processMsgQueueBar:IsVisible()) then
			DamageMeters_processMsgQueueBar:Hide();
			DamageMeters_processMsgQueueBarText:SetText("");
		end
	end

	if (DamageMeters_debug3.showSyncQueueInfo) then
		if (sent > 0 or processed > 0) then
			DMPrint(string.format("%.4f: sent = %d/%d, processed = %d/%d", initialElapsed, sent, toSend, processed, toProcess));
		end
	end
end

function DamageMeters_ToggleVariable(varName)
	DamageMeters_flags[varName] = not DamageMeters_flags[varName];
end

function DamageMeters_ToggleMiniMode(bSilent)
	DamageMeters_ToggleViewMode(DMVIEW_MIN);

	DamageMeters_frameNeedsToBeGenerated = true;
	if (not bSilent) then
		DMPrint(format(DM_MSG_MINBARS, ((DMVIEW_MIN == DamageMeters_viewMode) and DM_MSG_TRUE or DM_MSG_FALSE)));
	end
end

function DamageMeters_DoRestoreDefaultOptions()
	DamageMeters_SetDefaultOptions();
	DamageMeters_frameNeedsToBeGenerated = true;
end

function DamageMetersMenu_ToggleVariable()
	DamageMeters_ToggleVariable(this.value);
end

function DamageMetersMenu_ToggleVariableAndRegen()
	DamageMeters_ToggleVariable(this.value);
	DamageMeters_frameNeedsToBeGenerated = true;
end

-- Put updating here that must happen even when the meters are hidden.
-- Note that this mostly is for TitanPanel's benefit, as we still need values
-- updated and sorted when hidden because of the titan plugin.
function DamageMetersHiddenFrame_OnUpdate()
	-- Process the message queue.
	DamageMeters_ProcessMessages(elapsed);	

	-- Update combat end time so that the Titan DPS display can be accurate.
	if (DamageMeters_inCombat) then
		DamageMeters_combatEndTime = GetTime();
	end

	-- If we aren't visible then we fire off the table updating (sorting) here.
	if (not DamageMeters_flags[DMFLAG_isVisible]) then
		local bSecondHasPassedSinceLastBarUpdate = (GetTime() - DamageMeters_lastBarUpdateTime) > 1.0;
		if (DamageMeters_tablesDirty and (DamageMeters_flags[DMFLAG_constantVisualUpdate] or bSecondHasPassedSinceLastBarUpdate)) then
			DamageMeters_lastBarUpdateTime = GetTime();
			DamageMeters_UpdateTables();
		end
	end

	DamageMetersFrame_DragUpdate();

	--Threat ThreatMeters_Scan(elapsed);
end

function DamageMeters_SyncHalt()
	if (DamageMeters_CheckSyncChan()) then
		SendChatMessage(DamageMeters_SYNCHALT, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));		
		
		DMPrint(DM_MSG_SYNCHALTSENT);

		-- Clear the message queues.
		DamageMeters_syncMsgQueue = {};
		DamageMeters_syncIncMsgQueue = {};
		DamageMeters_syncIncMsgSourceQueue = {};
	end
end

-------------------------------------------------------------------------------
-- Dragging

-- Drag global variables
DamageMeters_dragStartX = nil;
DamageMeters_dragStartY = nil;
DamageMeters_widthAtDragStart = nil;
DamageMeters_draggingRight = nil;
DamageMeters_draggingBottom = nil;
DamageMeters_barCountAtStart = nil;
DamageMeters_resizeLeftAtDragStart = nil;
DamageMeters_resizeUpAtDragStart = nil;

function DamageMetersFrame_OnMouseDown()
	local xLoc, yLoc = GetCursorPosition();
	--DMPrintD("local = "..xLoc..", "..yLoc);

	local effectiveScale = this:GetEffectiveScale();
	local left = this:GetLeft() * effectiveScale;
	local top = this:GetTop() * effectiveScale;
	local right = this:GetRight() * effectiveScale;
	local bottom = this:GetBottom() * effectiveScale;
	--DMPrintD("Frame: x = ("..left.."->"..right.."), y = ("..top.."->"..bottom..")");

	if (abs(xLoc - left) < 10) then
		DamageMeters_draggingRight = false;
	elseif (abs(xLoc - right) < 10) then
		DamageMeters_draggingRight = true;
	end

	if (abs(yLoc - bottom) < 10) then
		DamageMeters_draggingBottom = true;
	elseif (abs(yLoc - top) < 10) then
		DamageMeters_draggingBottom = false;
	end

	if (not DamageMeters_flags[DMFLAG_positionLocked]) then
		if (nil ~= DamageMeters_draggingRight or nil ~= DamageMeters_draggingBottom) then
			if (DMVIEW_MAX == DamageMeters_viewMode or
				(DMVIEW_MIN == DamageMeters_viewMode and DamageMeters_draggingBottom ~= nil)) then
				-- Do Moving.
				this:StartMoving();
				this.isMoving = true;

				--DMPrintD("Moving");
				DamageMeters_draggingRight = nil;
				DamageMeters_draggingBottom = nil;
			else
				DamageMeters_dragStartX, DamageMeters_dragStartY = GetCursorPosition(UIParent);
				--DMPrintD("Dragging");
			end
		end
	end
end

function DamageMetersFrame_OnMouseUp()
	if (this.isMoving == true) then
		-- Stop dragging.
		this:StopMovingOrSizing();
		this.isMoving = false;
	end
end

function DamageMetersFrame_OnDragStart()
	if ((not DamageMeters_flags[DMFLAG_positionLocked]) and this.isMoving ~= true) then
		DamageMeters_widthAtDragStart = DamageMeters_BARWIDTH;
		DamageMeters_barCountAtStart = DamageMeters_barCount;
		DamageMeters_resizeLeftAtDragStart = DamageMeters_flags[DMFLAG_resizeLeft];
		DamageMeters_resizeUpAtDragStart = DamageMeters_flags[DMFLAG_resizeUp];

		DMPrintD("DamageMetersFrame: OnDragStart ("..DamageMeters_dragStartX..", "..DamageMeters_dragStartY..")");
		DMPrintD("Effective Scale = "..this:GetEffectiveScale());

		if (DamageMeters_draggingRight) then
			DamageMeters_flags[DMFLAG_resizeLeft] = false;
		elseif (not DamageMeters_draggingRight) then
			DamageMeters_flags[DMFLAG_resizeLeft] = true;
		end

		if (DMVIEW_MIN == DamageMeters_viewMode) then
			
		else
			if (DamageMeters_draggingBottom) then
				DamageMeters_flags[DMFLAG_resizeUp] = false;
			elseif(not DamageMeters_draggingBottom) then
				DamageMeters_flags[DMFLAG_resizeUp] = true;
			end
		end
	end
end

function DamageMetersFrame_OnDragStop()
	if (this.isMoving ~= true) then
		local endX, endY = GetCursorPosition(UIParent);
		--DMPrintD("DamageMetersFrame: OnDragStop ("..endX..", "..endY..")");
		local deltaX = endX - DamageMeters_dragStartX;
		local deltaY = endY - DamageMeters_dragStartY;
		--DMPrintD("Delta = ("..deltaX..", "..deltaY..")");

		DamageMeters_flags[DMFLAG_resizeLeft] = DamageMeters_resizeLeftAtDragStart
		DamageMeters_flags[DMFLAG_resizeUp] = DamageMeters_resizeUpAtDragStart;

		DamageMeters_dragStartX = nil;
		DamageMeters_dragStartY = nil;
		DamageMeters_widthAtDragStart = nil;
		DamageMeters_draggingRight = nil;
		DamageMeters_draggingBottom = nil;
		DamageMeters_barCountAtStart = nil;
	end
end

function DamageMetersFrame_DragUpdate()
	if ((not DamageMeters_flags[DMFLAG_positionLocked]) and not this.isMoving) then
		if (DamageMeters_widthAtDragStart ~= nil) then
			local endX, endY = GetCursorPosition(UIParent);
			local deltaX = (endX - DamageMeters_dragStartX) / this:GetEffectiveScale();
			local deltaY = (endY - DamageMeters_dragStartY) / this:GetEffectiveScale();

			if (DamageMeters_draggingRight ~= nil) then
				if (not DamageMeters_draggingRight) then
					deltaX = -deltaX;
				end
				if (DamageMeters_barCount > 20) then
					deltaX = deltaX / 2;
				end

				local newWidth = max(50, DamageMeters_widthAtDragStart + deltaX);
				newWidth = min(600, newWidth);
				DamageMeters_SetBarWidth(newWidth, true);
			end

			if (DamageMeters_draggingBottom ~= nil) then
				if (DamageMeters_draggingBottom) then
					deltaY = -deltaY;
				end
				local barDelta = deltaY / DamageMeters_BARHEIGHT;
				barDelta = floor(barDelta);
				if (DamageMeters_barCount > 20) then
					barDelta = barDelta * 2;
				end
				if (barDelta ~= 0) then
					local newBarCount = DamageMeters_barCountAtStart + barDelta;
					if (((DamageMeters_barCount < 20) and newBarCount < 20 and newBarCount > 0 and DamageMeters_barCount ~= newBarCount) or
						((DamageMeters_barCount > 20) and newBarCount > 20 and newBarCount < 40 and DamageMeters_barCount ~= newBarCount)) then
						DamageMeters_SetCount(newBarCount, true);
					end
					else
				end
			end
		end
	end
end

-------------------------------------------------------------------------------

DMRPS_PREFIX = "DMRPS: ";

DamageMeters_RPSChallengedList = {};
DamageMeters_RPSChallengedByList = {};

function DamageMeters_RPSChallenge(arg)
	if (not DamageMeters_CheckSyncChan()) then
		return;
	end

	if (arg == nil or arg == "") then
		DMPrint(DM_ERROR_MISSINGARG);
		return;
	end

	local found, player, move;
	found,_,player,move = string.find(arg, "(.+) (.)");
	if (not found) then
		DMPrint(DM_ERROR_INVALIDARG);
		return;
	end

	move = string.lower(move);
	if (move ~= "r" and move ~= "p" and move ~= "s") then
		DMPrint(DM_ERROR_INVALIDARG);
		return;
	end

	if (player == nil or player == "") then
		DMPrint(DM_ERROR_MISSINGARG);
		return;
	end

	player = string.lower(player);
	player = string.upper(string.sub(player, 1, 1))..string.sub(player, 2);
	DamageMeters_RPSChallengedList[player] = move;

	DMPrint(string.format(DMRPS_PREFIX..DM_MSG_RPS_CHALLENGE, player, DamageMeters_RPSmoveStrings[move]), DamageMeters_RPSCOLOR);

	local moveNumber = string.byte(move);
	DamageMeters_AddMsgToSyncQueue(string.format("%s %s", DamageMeters_SYNCRPS, player));
end

function DamageMeters_RPSChallengeReceived(player, arg)
	local defender = arg;
	if (string.lower(UnitName("Player")) == string.lower(defender)) then
		DMPrint(string.format(DMRPS_PREFIX..DM_MSG_RPS_CHALLENGED, player), DamageMeters_RPSCOLOR);

		local struct = {player = player, move = ""};
		table.insert(DamageMeters_RPSChallengedByList, struct);
	end
end

function DamageMeters_RPSResponse(arg)
	if (not DamageMeters_CheckSyncChan()) then
		return;
	end

	if (arg == nil or arg == "") then
		DMPrint(DM_ERROR_MISSINGARG);
		return;
	end

	local found, player, move;
	found,_,player,move = string.find(arg, "(.+) (.+)");
	if (not found) then
		found,_,move = string.find(arg, "(.+)");
		if (found) then
			if (table.getn(DamageMeters_RPSChallengedByList) == 1) then
				local index, struct;
				for index, struct in DamageMeters_RPSChallengedByList do
					player = struct.player;
					break;
				end
			else
				DMPrint(table.getn(DamageMeters_RPSChallengedByList));
				for _player, unused in DamageMeters_RPSChallengedByList do
					DMPrint(player);
					break;
				end

				DMPrint(DM_MSG_RPS_MISSING_PLAYER, DamageMeters_RPSCOLOR);
			end
		else
			DMPrint(DM_ERROR_INVALIDARG);
			return;
		end
	end
	if (move == nil or move == "") then
		DMPrint(DM_ERROR_MISSINGARG);
		return;
	end
	if (player == nil or player == "") then
		DMPrint(DM_ERROR_MISSINGARG);
		return;
	end
	player = string.lower(player);
	player = string.upper(string.sub(player, 1, 1))..string.sub(player, 2);

	move = string.lower(move);
	if (move ~= "r" and move ~= "p" and move ~= "s") then
		DMPrint(DM_ERROR_INVALIDARG);
		return;
	end

	local playerListIndex = nil;
	for index, struct in DamageMeters_RPSChallengedByList do
		if (struct.player == player) then
			playerListIndex = index;
			break;
		end
	end

	if (playerListIndex == nil) then
		DMPrint(string.format(DM_MSG_RPS_NOTCHALLENGED, player), DamageMeters_RPSCOLOR);
		return;
	end

	DMPrint(string.format(DMRPS_PREFIX..DM_MSG_RPS_YOUPLAY, DamageMeters_RPSmoveStrings[move]), DamageMeters_RPSCOLOR);

	DamageMeters_RPSChallengedByList[playerListIndex].move = move;

	local moveNumber = string.byte(move);
	DamageMeters_AddMsgToSyncQueue(string.format("%s %s %d", DamageMeters_SYNCRPSRESPONSE, player, moveNumber));
end

function DamageMeters_RPSResponseReceived(sourcePlayer, arg)
	local found, player, moveNumber;
	found,_,player,moveNumber = string.find(arg, "(.+) (%d+)");
	if (not found) then
		DMPrint("Error parsing RPS response.");
		return;
	end

	if (string.lower(player) ~= string.lower(UnitName("player"))) then
		-- Not for us.
		return;
	end

	if (DamageMeters_RPSChallengedList[sourcePlayer] ~= nil) then
		-- We were the attacker.	
		local move = string.char(tonumber(moveNumber));
		DamageMeters_RPSPrintResult(DamageMeters_RPSChallengedList[sourcePlayer], move, sourcePlayer);

		-- Send our move
		local moveNumber = string.byte(DamageMeters_RPSChallengedList[sourcePlayer]);
		DamageMeters_AddMsgToSyncQueue(string.format("%s %s %d", DamageMeters_SYNCRPSCOUNTERRESPONSE, sourcePlayer, moveNumber));

		-- Game over for us.
		DamageMeters_RPSChallengedList[sourcePlayer] = nil;
	end
end

function DamageMeters_RPSCounterresponseRecieved(sourcePlayer, arg)
	local found, player, moveNumber;
	found,_,player,moveNumber = string.find(arg, "(.+) (%d+)");
	if (not found) then
		DMPrint("Error parsing RPS response.");
		return;
	end

	if (string.lower(player) ~= string.lower(UnitName("player"))) then
		-- Not for us.
		return;
	end

	local move = string.char(tonumber(moveNumber));

	if (DamageMeters_RPSChallengedByList[sourcePlayer] ~= nil) then
		-- We were the defender.	
		local move = string.char(tonumber(moveNumber));
		DamageMeters_RPSPrintResult(DamageMeters_RPSChallengedByList[sourcePlayer], move, sourcePlayer);

		-- Game over.
		DamageMeters_RPSChallengedByList[sourcePlayer] = nil;
	end
end

function DamageMeters_RPSPrintResult(myMove, opponentsMove, opponent)
	DMPrint(string.format(DMRPS_PREFIX..DM_MSG_RPS_PLAYS, opponent, DamageMeters_RPSmoveStrings[opponentsMove]), DamageMeters_RPSCOLOR);

	if (myMove == opponentsMove) then
		DMPrint(string.format(DM_MSG_RPS_TIE, opponent), DamageMeters_RPSCOLOR);
	elseif ((opponentsMove == "r" and myMove == "s") or
			 (opponentsMove == "p" and myMove == "r") or
			 (opponentsMove == "s" and myMove == "p")) then
		DMPrint(string.format(DMRPS_PREFIX..DM_MSG_RPS_DEFEATED, opponent), DamageMeters_RPSCOLOR);
	else
		DMPrint(string.format(DMRPS_PREFIX..DM_MSG_RPS_VICTORIOUS, opponent), DamageMeters_RPSCOLOR);
	end
end

function DamageMeters_RPSReset()
	DamageMeters_queuedRPSMove = nil;
	DamageMeters_queuedRPSOpponent = nil;
	DamageMeters_bRPSAttacker = false;
end

function DM_RegisterUltimateUI()
	if(UltimateUI_RegisterButton) then
		UltimateUI_RegisterButton ( 
			"DamageMeters", 
			"Options", 
			"|cFF00CC00DamageMeters|r\nShows detailed damage and healing statistics.", 
			"Interface\\Icons\\Ability_ShockWave", 
			DamageMeters_ToggleShow
		);
	end
end

-------------------------------------------------------------------------------
-- OnEvent

function DamageMetersFrame_OnEvent()

	if (event == "CHAT_MSG_CHANNEL_NOTICE") then
		if (arg1 == "YOU_JOINED" and 
			string.lower(arg9) == string.lower(DamageMeters_syncChannel)) then
			
			-- Broadcast that we've joined.
			SendChatMessage(DamageMeters_SYNCJOINED.." "..DamageMeters_VERSIONSTRING, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));
		end
	end

	if (event == "VARIABLES_LOADED") then
		-- If the saved data is of a different version clear the table.
		DM_RegisterUltimateUI();
		if (DamageMeters_loadedDataVersion ~= DamageMeters_VERSION) then
			DMPrintD("Saved data version mismatch: loaded = "..DamageMeters_loadedDataVersion..", current = "..DamageMeters_VERSION);
			DamageMeters_tables[DMT_ACTIVE] = {};
			DamageMeters_tables[DMT_SAVED] = {};
			DamageMeters_tables[DMT_FIGHT] = {};
			
			if (DamageMeters_loadedDataVersion < 4402) then
				DMPrintD("Restoring default colors.");
				DamageMeters_SetDefaultColors();
			end

			DamageMeters_loadedDataVersion = DamageMeters_VERSION;
		end

		--[[ Threat
		if ThreatMeters["Version"] == nil or ThreatMeters["Version"] ~= DamageMeters_VERSIONSTRING then
			ThreatMeters = { 
				["Version"] = DamageMeters_VERSIONSTRING;
				["Classes"] = {},
				["Talents"] = {},
				["Stances"] = {},
				["Equipment"] = {},
				["ClearOnPhaseChange"] = false;
			};
		end
		]]--

		-- Reset the ages, as age values from old sessions are pointless.
		-- Reset the combat dmg too.
		local index, value;
		local now = GetTime();
		for tableIndex = 1, DMT_MAX do
			for index, value in DamageMeters_tables[tableIndex] do
				value.lastTime = now;
				for quantIx = 1, DMI_MAX do
					value.lastQuantTime[quantIx] = now;
				end
			end
		end

		DamageMeters_Reset();
		DamageMeters_SetQuantity(DamageMeters_quantity, true);

		DamageMeters_textStateStartTime = GetTime();
		DamageMeters_currentQuantStartTime = DamageMeters_textStateStartTime;

		if (not DamageMeters_flags[DMFLAG_isVisible]) then
			DamageMeters_Hide();
		end

		-- Intro text.
		-- DamageMeters_ShowVersion();
		if (DamageMeters_flags[DMFLAG_accumulateToMemory]) then
			DMPrint(DM_MSG_ACCUMULATING);
		end
		if (DamageMeters_debugEnabled) then
			DMPrintD("DamageMeters: Debug enabled.");
		end
		--if (not DamageMeters_takeOnlyPlayerData) then
		--	DMPrint(DM_MSG_PLAYERONLYEVENTDATAOFF);
		--end
		
		DMPrintD("Loading DM into mode "..DamageMeters_viewMode..", count = "..DamageMeters_barCount..", saved = "..DamageMeters_savedBarCount);


		-- This is a hack--if the frame is initially hidden the stupid dropdown 
		-- menu doesn't work right and needs to be opened twice to be seen the first
		-- time.
		DMReportFrame:Hide();

		-- Make sure this is called last.
		DamageMeters_OnLoadComplete();

		return;
	end

	-----------------------

	if ( event == "PARTY_MEMBERS_CHANGED" ) then
		DamageMeters_UpdateVisibility();
		return;
	end

	if ( event == "RAID_ROSTER_UPDATE" ) then
		DamageMeters_UpdateVisibility();
		DamageMeters_UpdateRaidMemberClasses();
		return;
	end

	if ( event == "PLAYER_REGEN_DISABLED" ) then
		--DamageMeters_startCombatOnNextValue = true;
		DamageMeters_playerInCombat = true;

		if (not DamageMeters_flags[DMFLAG_groupDPSMode]) then
			DamageMeters_OnCombatStart();
		end
		return;
	end
	if ( event == "PLAYER_REGEN_ENABLED" ) then
		DamageMeters_playerInCombat = false;

		--[[ Threat
		-- clear threat
		local playerUnitName = UnitName("player");
		ThreatMeters_AddThreat(playerUnitName, playerUnitName, 0, DM_HIT, DamageMeters_Relation_SELF, DM_DMG_COMBAT, "Physical", ThreatType_Special);	
		]]--

		if (DamageMeters_flags[DMFLAG_groupDPSMode]) then
			if (DamageMeters_inCombat) then
				if (DamageMeters_InParty() and UnitIsDead("Player")) then
					-- Dont stop combat: the party could be continuing combat.	
				else
					DMPrintD("In Combat, but either not In Party or Not Dead: Ending Combat.");
					DamageMeters_OnCombatEnd();
				end
			end
			--BAD DamageMeters_startCombatOnNextValue = true;
		else
			if (DamageMeters_inCombat) then
				DamageMeters_OnCombatEnd();
			end
		end
		return;
	end

	-----------------------

	
	if (event == "CHAT_MSG_RAID" or event == "CHAT_MSG_PARTY") then
		if (DamageMeters_flags[DMFLAG_permitAutoSyncChanJoin]) then

			local first, last = string.find(arg1, DM_MSG_SYNCCHANBROADCAST);
			if (last) then
				local sub = string.sub(arg1, last+1);
				DMPrint(sub);

				local newChan;
				local newLabel = nil;
				for newChan, newLabel in string.gfind(sub, "(.+) %((.+)%)") do
				end
				if (newLabel == nil) then
					newChan = sub;
				end

				local changeChan = false;
				if (string.lower(newChan) ~= string.lower(DamageMeters_syncChannel)) then
					changeChan = true;
				elseif (0 == GetChannelName(newChan)) then	
					changeChan = true;
				end

				if (changeChan) then
					DamageMeters_SyncChan(newChan);	
					if (DamageMeters_flags[DMFLAG_autoClearOnChannelJoin]) then
						DamageMeters_Clear();
					end
				end
				return;
			end
			return;
		end

		return;
	end

	if (event == "CHAT_MSG_CHANNEL") then
		local type = strsub(event, 10);
		local info = ChatTypeInfo[type];
		
		--DMPrint("CHAT_MSG_CHANNEL: "..info.id);

		if (DamageMeters_flags[DMFLAG_onlySyncWithGroup] and DamageMeters_GetGroupRelation(arg2) < 0) then
			return;
		end

		local channelLength = strlen(arg4);
		if ( (strsub(type, 1, 7) == "CHANNEL") and (type ~= "CHANNEL_LIST") and (arg1 ~= "INVITE") ) then

			if (info and (arg9 == DamageMeters_syncChannel)) then
				-- arg2 = source, arg9 = channel name
				--DMPrint("arg2 = "..arg2..", arg3 = "..arg3..", arg4 = "..arg4);
				--DMPrint("arg5 = "..arg5..", arg6 = "..arg6..", arg7 = "..arg7);
				--DMPrint("arg8 = "..arg8..", arg9 = "..arg9);
				--DMPrint("arg7 = "..arg7..", arg9 = "..arg9);

				local sender = string.lower(arg2);

				-- Ignore messages from ourself.
				if (not DamageMeters_debug3.syncSelf) then
					if (arg2 == UnitName("Player")) then
						return;
					end
				end
				
				local msg = arg1;

				--[[ Threat
				if (ThreatMeters_ParseChannelMessage(arg2, msg)) then
					return;
				end
				]]--

				if (strsub(msg, 1, string.len(DamageMeters_SYNCREQUEST)) == DamageMeters_SYNCREQUEST) then
					-- Note: +1 doesn't allow for a space between prefix and params.
					local params = strsub(msg, string.len(DamageMeters_SYNCREQUEST) + 1);
					--DMPrintD("Incoming sync params = >"..params.."<");
					--SendChatMessage("Incoming sync params = >"..params.."<", "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));
					if (string.sub(params, 1, 1) == "E") then
						--SendChatMessage("E detected: syncing events.", "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));
						DamageMeters_syncEvents = true;
						params = string.sub(params, 3);
					end
					if (params) then
						for syncLabel, syncIndex in string.gfind(params, "<(.+) (%d+)>") do
							syncLabel = tostring(syncLabel);
							syncIndex = tonumber(syncIndex);
							--! Potential error: local sessionLabel can be nil.
							if (syncLabel ~= DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel or
								syncIndex ~= DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex) then
								DMPrint(DM_MSG_SESSIONMISMATCH);
								DMPrint(string.format("Local = <%s> #%d.  Incoming = <%s> #%d.", 
										DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel, 
										DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex, 
										syncLabel, 
										syncIndex));
								DamageMeters_AddMsgToSyncQueue(string.format("%s %s %d", DamageMeters_SYNCSESSIONMISMATCH, DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel, DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex), true);
								DamageMeters_Clear();
								DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel = syncLabel;
								DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex = syncIndex;
							else
								DMPrintD("Sync request recieved, session matches our own.");
							end
						end
					end

					local now = GetTime();
					if (now - DamageMeters_lastSyncTime > DamageMeters_MINSYNCCOOLDOWN) then
						local ackmsg = DamageMeters_syncEvents and DM_MSG_SYNCREQUESTACKEVENTS or DM_MSG_SYNCREQUESTACK;
						DMPrint(ackmsg..arg2, nil, true);
						DamageMeters_lastSyncTime = now;
						DamageMeters_SyncReport();
					else
						DMPrint(DM_ERROR_SYNCTOOSOON);
					end
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCCLEARREQUEST)) == DamageMeters_SYNCCLEARREQUEST) then
					DMPrint(DM_MSG_CLEARRECEIVED..arg2, nil, true);
					SendChatMessage(DamageMeters_SYNCCLEARACK, "CHANNEL", nil, GetChannelName(DamageMeters_syncChannel));
					DamageMeters_Clear();
					
					-- Check for session information, and update ours if it is there.
					for newLabel, newIndex in string.gfind(msg, DamageMeters_SYNCCLEARREQUEST.." (.+) (%d+)") do
						DamageMeters_tableInfo[DMT_ACTIVE].sessionLabel = tostring(newLabel);
						DamageMeters_tableInfo[DMT_ACTIVE].sessionIndex = tonumber(newIndex);
						break;
					end

					return;
				elseif (msg == DamageMeters_SYNCCLEARACK) then
					--DMPrint(format(DM_MSG_CLEARACKNOWLEDGED, arg2), nil, true);
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCJOINED)) == DamageMeters_SYNCJOINED) then
					local version = strsub(msg, string.len(DamageMeters_SYNCJOINED) + 2);
					DMPrint(string.format(DM_MSG_PLAYERJOINEDSYNCCHAN, arg2, version), nil, true);
					return;
				elseif (msg == DamageMeters_SYNCSTART) then
					DMPrint(format(DM_MSG_RECEIVEDSYNCDATA, arg2), nil, true);
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCEND)) == DamageMeters_SYNCEND) then
					-- Nothing atm.
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCMSG)) == DamageMeters_SYNCMSG) then
					if (DamageMeters_flags[DMFLAG_enableDMM]) then
						local syncMsg = strsub(msg, string.len(DamageMeters_SYNCMSG) + 1);
						DMPrint(format(DM_MSG_SYNCMSG, arg2, arg2, syncMsg), DamageMeters_SYNCMSGCOLOR);
					end
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCPINGREQ)) == DamageMeters_SYNCPINGREQ) then
					DamageMeters_SyncPingReply(arg2);
					return;
				elseif (msg == DamageMeters_SYNCHALT) then
					DMPrint(string.format(DM_MSG_SYNCHALTRECEIVED, arg2), nil, true);
					-- Clear the message queues.
					DamageMeters_syncMsgQueue = {};
					DamageMeters_syncIncMsgQueue = {};
					DamageMeters_syncIncMsgSourceQueue = {};
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCPAUSEREQ)) == DamageMeters_SYNCPAUSEREQ) then
					DMPrint(string.format(DM_MSG_SYNCPAUSE, arg2), nil, true);
					DamageMeters_pauseState = DM_Pause_Paused;
					DamageMeters_CompletePauseChange(true);
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCUNPAUSEREQ)) == DamageMeters_SYNCUNPAUSEREQ) then
					local unpauseMsg = DM_MSG_SYNCUNPAUSE;				
					local additionalInfo = strsub(msg, string.len(DamageMeters_SYNCUNPAUSEREQ) + 2);
					if (additionalInfo and string.len(additionalInfo) > 0) then
						unpauseMsg = unpauseMsg.." ("..additionalInfo..")";
					end

					DMPrint(string.format(unpauseMsg, arg2), nil, true);
					if (DamageMeters_pauseState ~= DM_Pause_Not) then
						DamageMeters_pauseState = DM_Pause_Not;
						DamageMeters_CompletePauseChange(true);
					end
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCREADYREQ)) == DamageMeters_SYNCREADYREQ) then
					DMPrint(string.format(DM_MSG_SYNCREADY, arg2), nil, true);
					DamageMeters_SetReady();
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCPING)) == DamageMeters_SYNCPING) then
					for	pinger, additionalInfo in string.gfind(msg, DamageMeters_SYNCPING.." <(.+)> <(.+)>") do
						if (pinger == UnitName("Player")) then
							DMPrint("DMSYNCPING: "..arg2..", "..additionalInfo.."");
						end
					end
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCSESSIONMISMATCH)) == DamageMeters_SYNCSESSIONMISMATCH) then
					local badSession, badIndex;
					for	badSession, badIndex in string.gfind(msg, DamageMeters_SYNCSESSIONMISMATCH.." (.+) (%d+)") do 						
						local mismatchMsg = string.format(DM_MSG_SYNCSESSIONMISMATCH,
								arg2,
								badSession,
								badIndex);
						DMPrint(mismatchMsg, nil, true);
						return;
					end
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCEMOTE)) == DamageMeters_SYNCEMOTE) then
					DamageMeters_DecodeEmote(arg2, strsub(msg, string.len(DamageMeters_SYNCEMOTE) + 1));
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCRPS)) == DamageMeters_SYNCRPS) then
					DamageMeters_RPSChallengeReceived(arg2, strsub(msg, string.len(DamageMeters_SYNCRPS) + 2));
					return;					
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCRPSRESPONSE)) == DamageMeters_SYNCRPSRESPONSE) then
					DamageMeters_RPSResponseReceived(arg2, strsub(msg, string.len(DamageMeters_SYNCRPSRESPONSE) + 2));
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCRPSCOUNTERRESPONSE)) == DamageMeters_SYNCRPSCOUNTERRESPONSE) then
					DamageMeters_RPSCounterresponseRecieved(arg2, strsub(msg, string.len(DamageMeters_SYNCRPSCOUNTERRESPONSE) + 2));
					return;
				elseif (strsub(msg, 1, string.len(DamageMeters_SYNCKICK)) == DamageMeters_SYNCKICK) then
					local kicked = string.lower(string.sub(msg, string.len(DamageMeters_SYNCKICK) + 2));
					DMPrintD("kicked = >"..kicked.."<");
					if (string.lower(UnitName("Player")) == kicked) then
						DMPrint(string.format(DM_MSG_KICKED, arg2));
						DamageMeters_SyncLeaveChan();
					end
					return;
				elseif ((strsub(msg, 1, string.len(DMSYNC_PREFIX)) == DMSYNC_PREFIX) or
						((strsub(msg, 1, string.len(DMSYNC_EVENT_PREFIX)) == DMSYNC_EVENT_PREFIX))) then
					if (DamageMeters_debug3.syncSelf) then
						for index = 1, DamageMeters_debug_syncTestFactor do
							table.insert(DamageMeters_syncIncMsgQueue, msg);
							table.insert(DamageMeters_syncIncMsgSourceQueue, arg2);
						end
					else
						table.insert(DamageMeters_syncIncMsgQueue, msg);
						table.insert(DamageMeters_syncIncMsgSourceQueue, arg2);
					end
					return;
				end
			end
		end

		return;
	end

	---------------------------

	if (DamageMeters_pauseState == DM_Pause_Paused) then
		return;
	end

	if (DamageMeters_debug3.showAll) then
		local subEvent = string.sub(event, 9);
		DMPrintD("("..subEvent.."): "..arg1, nil, true);
	end

	DamageMeters_ParseMessage(arg1, event);

	---------------------------
end

function DamageMeters_StartDebugTimer(index)
	DamageMeters_activeDebugTimer = index;
	debugprofilestart();
end

function DamageMeters_StopDebugTimer(index)
	if (DamageMeters_activeDebugTimer ~= index) then
		DMPrintD("DM DEBUG ERROR: Wrong debug timer stopped. "..(DamageMeters_activeDebugTimer and DMPROF_NAMES[DamageMeters_activeDebugTimer] or "[none]").." expected, got "..DMPROF_NAMES[index]);
		debugprofilestop()
		DamageMeters_activeDebugTimer = 0;
		return;
	end

	DamageMeters_debugTimers[index].time = DamageMeters_debugTimers[index].time + debugprofilestop();
	DamageMeters_debugTimers[index].count = DamageMeters_debugTimers[index].count + 1;
	DamageMeters_activeDebugTimer = 0;
end

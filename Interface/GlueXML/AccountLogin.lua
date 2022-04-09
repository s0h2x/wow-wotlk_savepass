FADE_IN_TIME = 2;
DEFAULT_TOOLTIP_COLOR = {0.8, 0.8, 0.8, 0.09, 0.09, 0.09};
MAX_PIN_LENGTH = 10;

ACCOUNT_SEPARATOR = "#&|&#";
DATA_SEPARATOR = "#|&|#";

function string_explode(str, div)
	assert(type(str) == "string" and type(div) == "string", "invalid arguments")
	local o = {}
	while true do
		local pos1,pos2 = str:find(div)
		if not pos1 then
			o[#o+1] = str
			break
		end
		o[#o+1],str = str:sub(1,pos1-1),str:sub(pos2+1)
	end
	return o
end

function SaveAccountString(accname, pwstring)
	local data = {}
	local encoded = ""
	data.accountName = accname
	data.password = pwstring

	if not AceSerializer or not LibDeflate then
		SetSavedAccountName("")
		SetSavedAccountList("")
		return
	end

	local serialized = AceSerializer:Serialize(data)
	local compressed = LibDeflate:CompressDeflate(serialized)

	if compressed then
		encoded = LibDeflate:EncodeForPrint(compressed) or ""
	end

	local str1 = encoded:sub(1, 255)
	local str2 = encoded:sub(256)
	SetSavedAccountName(str1)
	SetSavedAccountList(str2)
end

GlueDialogTypes["REMEMBER_PASSWORD"] = {
	text = "Do you really want to save your Password? \nIt's not safe if someone has access to your files as it get's saved in plain text!",
	button1 = OKAY,
	button2 = CANCEL,
	OnAccept = function ()
	end,
	OnCancel = function()
		AccountLoginSavePassword:SetChecked(0);
	end,
}

function AccountLogin_OnLoad(self)
	TOSFrame.noticeType = "EULA";

	self:RegisterEvent("SHOW_SERVER_ALERT");
	self:RegisterEvent("SHOW_SURVEY_NOTIFICATION");
	self:RegisterEvent("CLIENT_ACCOUNT_MISMATCH");
	self:RegisterEvent("CLIENT_TRIAL");
	self:RegisterEvent("SCANDLL_ERROR");
	self:RegisterEvent("SCANDLL_FINISHED");
	AcceptTOS();   
	AcceptEULA();   
	AcceptTerminationWithoutNotice();

	local versionType, buildType, version, internalVersion, date = GetBuildInfo();
	AccountLoginVersion:SetFormattedText(VERSION_TEMPLATE, versionType, version, internalVersion, buildType, date);

	-- Color edit box backdrops
	local backdropColor = DEFAULT_TOOLTIP_COLOR;
	AccountLoginAccountEdit:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3]);
	AccountLoginAccountEdit:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6]);
	AccountLoginPasswordEdit:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3]);
	AccountLoginPasswordEdit:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6]);
	AccountLoginTokenEdit:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3]);
	AccountLoginTokenEdit:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6]);
	TokenEnterDialogBackgroundEdit:SetBackdropBorderColor(backdropColor[1], backdropColor[2], backdropColor[3]);
	TokenEnterDialogBackgroundEdit:SetBackdropColor(backdropColor[4], backdropColor[5], backdropColor[6]);
	
	self:SetCamera(0);
	self:SetSequence(0);
	
	if (IsStreamingTrial()) then
		AccountLoginCinematicsButton:Disable();
		AccountLogin:SetModel("Interface\\Glues\\Models\\UI_MainMenu\\UI_MainMenu.m2");
	else
		AccountLogin:SetModel("Interface\\Glues\\Models\\UI_MainMenu_Northrend\\UI_MainMenu_Northrend.m2");
	end
end

function AccountLogin_OnShow(self)
	local accountName, password = "", ""
	local decoded, decompressed, deserialized, data

	local savedString = GetSavedAccountName()..GetSavedAccountList()

	if savedString and savedString ~= "" then
		if LibDeflate then
			decoded = LibDeflate:DecodeForPrint(savedString)
		end

		if decoded then
			decompressed = LibDeflate:DecompressDeflate(decoded)
		end

		if AceSerializer and decompressed then
			deserialized, data = AceSerializer:Deserialize(decompressed)
		end

		if deserialized then
			accountName = data.accountName or ""
			password = data.password or ""
		else
			-- Old method of decoding passwords.
			ACCOUNT_NAME_PASSWORD, REALM_INFOS = unpack(string_explode(savedString, DATA_SEPARATOR));
			accountName, password = unpack(string_explode(ACCOUNT_NAME_PASSWORD, ACCOUNT_SEPARATOR));
			accountName = accountName or ""
			password = dec(password) or ""
		end
	end

	AccountLoginAccountEdit:SetText(accountName);
	AccountLoginPasswordEdit:SetText(password);
	if accountName ~= "" then
		AccountLoginSavePasswordText:Show();
		AccountLoginSavePassword:Show();
		if (password == "") or (password == nil)  then
			AccountLoginSavePassword:SetChecked(0);
		else
			AccountLoginSavePassword:SetChecked(1);
		end
	else
		AccountLoginSavePassword:Hide();
		AccountLoginSavePasswordText:Hide();
	end

	-- Try to show the EULA or the TOS
	AccountLogin_ShowUserAgreements();
	
	local serverName = GetServerName();
	if(serverName) then
		AccountLoginRealmName:SetText(serverName);
	else
		AccountLoginRealmName:Hide()
	end

	AccountLoginTokenEdit:SetText("");
	if ( accountName and accountName ~= "" and GetUsesToken() ) then
		AccountLoginTokenEdit:Show();
	else
		AccountLoginTokenEdit:Hide();
	end
	
	AccountLogin_SetupAccountListDDL();	
	
	if ( accountName == "" ) then
		AccountLogin_FocusAccountName();
		AccountLoginSaveAccountName:SetChecked(0);
	else
		AccountLogin_FocusPassword();
		AccountLoginSaveAccountName:SetChecked(1);
	end
	
	if( IsTrialAccount() ) then
		AccountLoginUpgradeAccountButton:Show();
	else
		AccountLoginUpgradeAccountButton:Hide();
	end

	ACCOUNT_MSG_NUM_AVAILABLE = 0;
	ACCOUNT_MSG_PRIORITY = 0;
	ACCOUNT_MSG_HEADERS_LOADED = false;
	ACCOUNT_MSG_BODY_LOADED = false;
	ACCOUNT_MSG_CURRENT_INDEX = nil;
end

function AccountLogin_OnHide(self)
	--Stop the sounds from the login screen (like the dragon roaring etc)
	StopAllSFX( 1.0 );
	if ( not AccountLoginSaveAccountName:GetChecked() ) then
		SetSavedAccountList("");
	end
end

function AccountLogin_FocusPassword()
	AccountLoginPasswordEdit:SetFocus();
end

function AccountLogin_FocusAccountName()
	AccountLoginAccountEdit:SetFocus();
end

function DisableLoginKeyboard()
	AccountLoginAccountEdit:EnableKeyboard(false)
	AccountLoginPasswordEdit:EnableKeyboard(false)
end

function EnableLoginKeyboard()
	AccountLoginAccountEdit:EnableKeyboard(true)
	AccountLoginPasswordEdit:EnableKeyboard(true)
end

GlueDialog:HookScript("OnShow", DisableLoginKeyboard)
GlueDialog:HookScript("OnHide", EnableLoginKeyboard)

RealmList:HookScript("OnShow", DisableLoginKeyboard)
RealmList:HookScript("OnHide", EnableLoginKeyboard)

function AccountLogin_OnKeyDown(key)
	if ( key == "ESCAPE" ) then
		if ( ConnectionHelpFrame:IsShown() ) then
			ConnectionHelpFrame:Hide();
			AccountLoginUI:Show();
		elseif ( SurveyNotificationFrame:IsShown() ) then
			-- do nothing
		else
			AccountLogin_Exit();
		end
	elseif ( key == "ENTER" ) then
		if ( not TOSAccepted() ) then
			return;
		elseif ( TOSFrame:IsShown() or ConnectionHelpFrame:IsShown() ) then
			return;
		elseif ( SurveyNotificationFrame:IsShown() ) then
			AccountLogin_SurveyNotificationDone(1);
		end
		AccountLogin_Login();
	elseif ( key == "PRINTSCREEN" ) then
		Screenshot();
	end
end

function AccountLogin_OnEvent(event, arg1, arg2, arg3)
	if ( event == "SHOW_SERVER_ALERT" ) then
		ServerAlertText:SetText(arg1);
		ServerAlertFrame:Show();
	elseif ( event == "SHOW_SURVEY_NOTIFICATION" ) then
		AccountLogin_ShowSurveyNotification();
	elseif ( event == "CLIENT_ACCOUNT_MISMATCH" ) then
		local accountExpansionLevel = arg1;
		local installationExpansionLevel = arg2;
		if ( accountExpansionLevel == 1 ) then
			GlueDialog_Show("CLIENT_ACCOUNT_MISMATCH", CLIENT_ACCOUNT_MISMATCH_BC);	
		else
			GlueDialog_Show("CLIENT_ACCOUNT_MISMATCH", CLIENT_ACCOUNT_MISMATCH_LK);	
		end
	elseif ( event == "CLIENT_TRIAL" ) then
		GlueDialog_Show("CLIENT_TRIAL");
	elseif ( event == "SCANDLL_ERROR" ) then
		GlueDialog:Hide();
		ScanDLLContinueAnyway();
		AccountLoginUI:Show();
	elseif ( event == "SCANDLL_FINISHED" ) then
		if ( arg1 == "OK" ) then
			GlueDialog:Hide();
			AccountLoginUI:Show();
		else
			AccountLogin.hackURL = _G["SCANDLL_URL_"..arg1];
			AccountLogin.hackName = arg2;
			AccountLogin.hackType = arg1;
			local formatString = _G["SCANDLL_MESSAGE_"..arg1];
			if ( arg3 == 1 ) then
				formatString = _G["SCANDLL_MESSAGE_HACKNOCONTINUE"];
			end
			local msg = format(formatString, AccountLogin.hackName, AccountLogin.hackURL);
			if ( arg3 == 1 ) then
				GlueDialog_Show("SCANDLL_HACKFOUND_NOCONTINUE", msg);
			else
				GlueDialog_Show("SCANDLL_HACKFOUND", msg);
			end
			PlaySoundFile("Sound\\Creature\\MobileAlertBot\\MobileAlertBotIntruderAlert01.wav");
		end
	end
end

-- Lua 5.1+ base64 v3.0 (c) 2009 by Alex Kloss <alexthkloss@web.de>
-- licensed under the terms of the LGPL2

-- character table string
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- decoding
function dec(data)
	if not data or data == "" then return "" end
	data = string.gsub(data, '[^'..b..'=]', '')
	return (data:gsub('.', function(x)
	  if (x == '=') then return '' end
	  local r,f='',(b:find(x)-1)
	  for i=5,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
	  return r;
	end):gsub('%d%d%d?%d?%d?%d?%d?', function(x)
	  if (#x ~= 7) then return '' end
	  local c=0
	  for i=1,7 do c=c+(x:sub(i,i)=='1' and 2^(7-i) or 0) end
	  return string.char(c)
	end))
  end

function AccountLogin_Login()

	if string.find(AccountLoginAccountEdit:GetText(), "@") then
		GlueDialogTypes["EMAIL_WARNING"] = {
			text = "Invalid character '@' found in Account Name. Don't use your email to log in!",
			button1 = OKAY,
			showAlert = 1,
		}
		return GlueDialog_Show("EMAIL_WARNING");
	end
	
	PlaySound("gsLogin");
	DefaultServerLogin(AccountLoginAccountEdit:GetText(), AccountLoginPasswordEdit:GetText());
	
	if ( AccountLoginSaveAccountName:GetChecked() ) then
		if ( AccountLoginSavePassword:GetChecked() ) then
			SaveAccountString(AccountLoginAccountEdit:GetText(), AccountLoginPasswordEdit:GetText());
		else
			SaveAccountString(AccountLoginAccountEdit:GetText());
		end
	else
		SaveAccountString();
		SetUsesToken(false);
	end
end

function AccountLogin_TOS()
	if ( not GlueDialog:IsShown() ) then
		PlaySound("gsLoginNewAccount");
		AccountLoginUI:Hide();
		TOSFrame:Show();
		TOSScrollFrameScrollBar:SetValue(0);		
		TOSScrollFrame:Show();
		TOSFrameTitle:SetText(TOS_FRAME_TITLE);
		TOSText:Show();
	end
end

function AccountLogin_ManageAccount()
	PlaySound("gsLoginNewAccount");
	LaunchURL(AUTH_NO_TIME_URL);
end

function AccountLogin_LaunchCommunitySite()
	PlaySound("gsLoginNewAccount");
	LaunchURL(COMMUNITY_URL);
end

function CharacterSelect_UpgradeAccount()
	PlaySound("gsLoginNewAccount");
	LaunchURL(AUTH_NO_TIME_URL);
end

function AccountLogin_Credits()
	CreditsFrame.creditsType = 3;
	PlaySound("gsTitleCredits");
	SetGlueScreen("credits");
end

function AccountLogin_Cinematics()
	if ( not GlueDialog:IsShown() ) then
		PlaySound("gsLoginNewAccount");
		if ( CinematicsFrame.numMovies > 1 ) then
			CinematicsFrame:Show();
		else
			MovieFrame.version = 1;
			SetGlueScreen("movie");
		end
	end
end

function AccountLogin_Options()
	PlaySound("gsTitleOptions");
end

function AccountLogin_Exit()
--	PlaySound("gsTitleQuit");
	QuitGame();
end

function AccountLogin_ShowSurveyNotification()
	GlueDialog:Hide();
	AccountLoginUI:Hide();
	SurveyNotificationAccept:Enable();
	SurveyNotificationDecline:Enable();
	SurveyNotificationFrame:Show();
end

function AccountLogin_SurveyNotificationDone(accepted)
	SurveyNotificationFrame:Hide();
	SurveyNotificationAccept:Disable();
	SurveyNotificationDecline:Disable();
	SurveyNotificationDone(accepted);
	AccountLoginUI:Show();
end

function AccountLogin_ShowUserAgreements()
	TOSScrollFrame:Hide();
	EULAScrollFrame:Hide();
	TerminationScrollFrame:Hide();
	ScanningScrollFrame:Hide();
	ContestScrollFrame:Hide();
	TOSText:Hide();
	EULAText:Hide();
	TerminationText:Hide();
	ScanningText:Hide();
	if ( not EULAAccepted() ) then
		if ( ShowEULANotice() ) then
			TOSNotice:SetText(EULA_NOTICE);
			TOSNotice:Show();
		end
		AccountLoginUI:Hide();
		TOSFrame.noticeType = "EULA";
		TOSFrameTitle:SetText(EULA_FRAME_TITLE);
		TOSFrameHeader:SetWidth(TOSFrameTitle:GetWidth());
		EULAScrollFrame:Show();
		EULAText:Show();
		TOSFrame:Show();
	elseif ( not TOSAccepted() ) then
		if ( ShowTOSNotice() ) then
			TOSNotice:SetText(TOS_NOTICE);
			TOSNotice:Show();
		end
		AccountLoginUI:Hide();
		TOSFrame.noticeType = "TOS";
		TOSFrameTitle:SetText(TOS_FRAME_TITLE);
		TOSFrameHeader:SetWidth(TOSFrameTitle:GetWidth());
		TOSScrollFrame:Show();
		TOSText:Show();
		TOSFrame:Show();
	elseif ( not TerminationWithoutNoticeAccepted() and SHOW_TERMINATION_WITHOUT_NOTICE_AGREEMENT ) then
		if ( ShowTerminationWithoutNoticeNotice() ) then
			TOSNotice:SetText(TERMINATION_WITHOUT_NOTICE_NOTICE);
			TOSNotice:Show();
		end
		AccountLoginUI:Hide();
		TOSFrame.noticeType = "TERMINATION";
		TOSFrameTitle:SetText(TERMINATION_WITHOUT_NOTICE_FRAME_TITLE);
		TOSFrameHeader:SetWidth(TOSFrameTitle:GetWidth());
		TerminationScrollFrame:Show();
		TerminationText:Show();
		TOSFrame:Show();
	elseif ( not ScanningAccepted() and SHOW_SCANNING_AGREEMENT ) then
		if ( ShowScanningNotice() ) then
			TOSNotice:SetText(SCANNING_NOTICE);
			TOSNotice:Show();
		end
		AccountLoginUI:Hide();
		TOSFrame.noticeType = "SCAN";
		TOSFrameTitle:SetText(SCAN_FRAME_TITLE);
		TOSFrameHeader:SetWidth(TOSFrameTitle:GetWidth());
		ScanningScrollFrame:Show();
		ScanningText:Show();
		TOSFrame:Show();
	elseif ( not ContestAccepted() and SHOW_CONTEST_AGREEMENT ) then
		if ( ShowContestNotice() ) then
			TOSNotice:SetText(CONTEST_NOTICE);
			TOSNotice:Show();
		end
		AccountLoginUI:Hide();
		TOSFrame.noticeType = "CONTEST";
		TOSFrameTitle:SetText(CONTEST_FRAME_TITLE);
		TOSFrameHeader:SetWidth(TOSFrameTitle:GetWidth());
		ContestScrollFrame:Show();
		ContestText:Show();
		TOSFrame:Show();
	elseif ( not IsScanDLLFinished() ) then
		AccountLoginUI:Hide();
		TOSFrame:Hide();
		local dllURL = "";
		if ( IsWindowsClient() ) then dllURL = SCANDLL_URL_WIN32_SCAN_DLL; end
		ScanDLLStart(SCANDLL_URL_LAUNCHER_TXT, dllURL);
	else
		AccountLoginUI:Show();
		TOSFrame:Hide();
	end
end

function AccountLogin_UpdateAcceptButton(scrollFrame, isAcceptedFunc, noticeType)
	local scrollbar = _G[scrollFrame:GetName().."ScrollBar"];
	local min, max = scrollbar:GetMinMaxValues();

	-- HACK: scrollbars do not handle max properly
	-- DO NOT CHANGE - without speaking to Mikros/Barris/Thompson
	if (scrollbar:GetValue() >= max - 20) then
		TOSAccept:Enable();
	else
		if ( not isAcceptedFunc() and TOSFrame.noticeType == noticeType ) then
			TOSAccept:Disable();
		end
	end
end																

function ChangedOptionsDialog_OnShow(self)
	if ( not ShowChangedOptionWarnings() ) then
		self:Hide();
		return;
	end

	local options = ChangedOptionsDialog_BuildWarningsString(GetChangedOptionWarnings());
	if ( options == "" ) then
		self:Hide();
		return;
	end

	-- set text
	ChangedOptionsDialogText:SetText(options);

	-- resize the background to fit the text
	local textHeight = ChangedOptionsDialogText:GetHeight();
	local titleHeight = ChangedOptionsDialogTitle:GetHeight();
	local buttonHeight = ChangedOptionsDialogOkayButton:GetHeight();
	ChangedOptionsDialogBackground:SetHeight(26 + titleHeight + 16 + textHeight + 8 + buttonHeight + 16);
	self:Raise();
end

function ChangedOptionsDialog_OnKeyDown(self,key)
	if ( key == "PRINTSCREEN" ) then
		Screenshot();
		return;
	end

	if ( key == "ESCAPE" or key == "ENTER" ) then
		ChangedOptionsDialogOkayButton:Click();
	end
end

function ChangedOptionsDialog_BuildWarningsString(...)
	local options = "";
	for i=1, select("#", ...) do
		if ( i == 1 ) then
			options = select(1, ...);
		else
			options = options.."\n\n"..select(i, ...);
		end
	end
	return options;
end

-- Virtual keypad functions
function VirtualKeypadFrame_OnEvent(event, ...)
	if ( event == "PLAYER_ENTER_PIN" ) then
		for i=1, 10 do
			_G["VirtualKeypadButton"..i]:SetText(select(i,...));
		end							
	end
	-- Randomize location to prevent hacking (yeah right)
	local xPadding = 5;
	local yPadding = 10;
	local xPos = random(xPadding, GlueParent:GetWidth()-VirtualKeypadFrame:GetWidth()-xPadding);
	local yPos = random(yPadding, GlueParent:GetHeight()-VirtualKeypadFrame:GetHeight()-yPadding);
	VirtualKeypadFrame:SetPoint("TOPLEFT", GlueParent, "TOPLEFT", xPos, -yPos);
	
	VirtualKeypadFrame:Show();
	VirtualKeypad_UpdateButtons();
end

function VirtualKeypadButton_OnClick(self)
	local text = VirtualKeypadText:GetText();
	if ( not text ) then
		text = "";
	end
	VirtualKeypadText:SetText(text.."*");
	VirtualKeypadFrame.PIN = VirtualKeypadFrame.PIN..self:GetID();
	VirtualKeypad_UpdateButtons();
end

function VirtualKeypadOkayButton_OnClick()
	local PIN = VirtualKeypadFrame.PIN;
	local numNumbers = strlen(PIN);
	local pinNumber = {};
	for i=1, MAX_PIN_LENGTH do
		if ( i <= numNumbers ) then
			pinNumber[i] = strsub(PIN,i,i);
		else
			pinNumber[i] = nil;
		end
	end
	PINEntered(pinNumber[1] , pinNumber[2], pinNumber[3], pinNumber[4], pinNumber[5], pinNumber[6], pinNumber[7], pinNumber[8], pinNumber[9], pinNumber[10]);
	VirtualKeypadFrame:Hide();
end

function VirtualKeypad_UpdateButtons()
	local numNumbers = strlen(VirtualKeypadFrame.PIN);
	if ( numNumbers >= 4 and numNumbers <= MAX_PIN_LENGTH ) then
		VirtualKeypadOkayButton:Enable();
	else
		VirtualKeypadOkayButton:Disable();
	end
	if ( numNumbers == 0 ) then
		VirtualKeypadBackButton:Disable();
	else
		VirtualKeypadBackButton:Enable();
	end
	if ( numNumbers >= MAX_PIN_LENGTH ) then
		for i=1, MAX_PIN_LENGTH do
			_G["VirtualKeypadButton"..i]:Disable();
		end
	else
		for i=1, MAX_PIN_LENGTH do
			_G["VirtualKeypadButton"..i]:Enable();
		end
	end
end

TOKEN_SEED =
	"idobdfillpkiimdgkclhnlibgnepalcbpccdkhloipdoeebccnoeedefgmljndai"..
	"epicgamehpoifjbggbcihfanenmhkemffilglaebddmbakkhblpencadlaiepoga"..
	"ecpjojaijcefflabhilmmpgjiecbhamoceponkbjiogaodhnagencenlaeljhbna"..
	"ciglpffdnfgaaidccjjgbgiihhnbbjcbanhfdjadljkhmfknfnmpjblnelbfnnjf"..
	"dpakjehajomgjahhljnmnhnpadfkbopppiicnkkkhblkbibgajfmemhhimpjgcoe"..
	"mbkpilkleedkmpnckkcdbhnoanhpjeneinehgknalgglcbdcjdcppbjhgkahamgk"..
	"gijkofghdhopbkjjghmndfdpiadcdigefikbgccfhgkkbmkollbhlkbdobhaofbh"..
	"adbiepfnpiibfkcpflpkjpfmmhbopkcbcblaadaoodnoodgfhjpedmpballngmoo"..
	"bbmkgghdgmhdngbfpmikijmdjgddkeahhidkofihemfmolbcojpiapfkogbdenfc"..
	"cmahmfhlclfkeijbndcllbnffbjbbkfgdboiffhpkfgjckliookjlonenifdbenn"..
	"epeicoloceldnilhlkameoeceiobfnpeccaihhgjdgagjhmeljacpfljlhgnlhkj"..
	"dbihegomcbifklmmhmbaodnaehnbkikcjkloebkhmkhejakcdklndeiinidlgdhc"..
	"ddfbafimcpddekndmbcfemcpfihngpkoccjniboomialmgejaalnfogjofbfgbdk"..
	"poibhankhndpgeldkkdjgbknnahfdbcjhkmaciajeadkfmjcgaipjcilhhlagjcp"..
	"lnbeodabfpofdabnhckmnbjnofopfhglgiociaehalfcclkmjmobmjdbillmompm"..
	"jfgppnfgfancjglolkhoejogfjljnknoeiniiiimcifhlpiefmkkmhonbnppdndl"..
	"hmgpgcniinbaanciifdggklbgoanaihndbjpnannabbmfjkdjfkhimpccelcpjed"..
	"kgmpmpfnbmleiejkgbbknnnhambkmomlbjbhpkegehdfacdnbdfcmfagadbcaemg"..
	"ddhpjoacekfnakamgafmkodcplnhbhblcllikeglfnedlmkcoiegldlhikoncmca"..
	"bloiejelafbjjgmhapobofongodoojelpnkgfjdgpfckjglfbgaipbdpmbpjlcje"..
	"jcpgagffnmappkacgacmokedaicjklinmemijkojchoojjandkcdmjigjeldpepl"..
	"ihpenljefeechdndbdjkcipajcajghnhjackcjnoofebnmhimajekangghkfgcjm"..
	"hndedmcpmdilipgljglplhppcogaidkfaeibkedaihckjodddfblfonfnnljgcbi"..
	"hmnojjolaljebgiegnmjcficnkjchoakajkdhnchbljhonghjffebdobdcahpdjp"..
	"bmhpmnamkgpfjfbfgghjnabakoilmlbkhjoiegldbcdlijakkmehoemokdeafgjl"..
	"khmdjmbkdckdlidapcigbomjikehjddpblijhdgooegdfeinhaiponemlnffcnif"..
	"bkbnihminfmkfhbdneaaegofpacckahbgnmobgehalklcfkncogkanff";

-- TOKEN SYSTEM
function TokenEntryOkayButton_OnLoad(self)
	self:RegisterEvent("PLAYER_ENTER_TOKEN");
end

function TokenEntryOkayButton_OnEvent(self, event)
	if (event == "PLAYER_ENTER_TOKEN") then
		if ( AccountLoginSaveAccountName:GetChecked() ) then
			if ( GetUsesToken() ) then
				if ( AccountLoginTokenEdit:GetText() ~= "" ) then
					TokenEntered(AccountLoginTokenEdit:GetText());
					return;
				end
			else
				SetUsesToken(true);
			end
		end
		self:Show();
	end
end

function TokenEntryOkayButton_OnShow()
	TokenEnterDialogBackgroundEdit:SetText("");
	TokenEnterDialogBackgroundEdit:SetFocus();
end

function TokenEntryOkayButton_OnKeyDown(self, key)
	if ( key == "ENTER" ) then
		TokenEntry_Okay(self);
	elseif ( key == "ESCAPE" ) then
		TokenEntry_Cancel(self);
	end
end

function TokenEntry_Okay(self)
	TokenEntered(TokenEnterDialogBackgroundEdit:GetText());
	TokenEnterDialog:Hide();
end

function TokenEntry_Cancel(self)
	TokenEnterDialog:Hide();
	CancelLogin();
end

-- WOW Account selection
function WoWAccountSelect_OnLoad(self)
	self:RegisterEvent("GAME_ACCOUNTS_UPDATED");
	self:RegisterEvent("OPEN_STATUS_DIALOG");
	WoWAccountSelectDialogBackgroundContainerScrollFrame.offset = 0
	CURRENT_SELECTED_WOW_ACCOUNT = 1;
end

function WoWAccountSelect_OnShow (self)
	AccountLoginAccountEdit:SetFocus();
	AccountLoginAccountEdit:ClearFocus();
	CURRENT_SELECTED_WOW_ACCOUNT = 1;
	WoWAccountSelect_Update();
end

function WoWAccountSelectButton_OnClick(self)
	CURRENT_SELECTED_WOW_ACCOUNT = self:GetID();
	WoWAccountSelect_Update();
end

function WoWAccountSelectButton_OnDoubleClick(self)
	WoWAccountSelect_SelectAccount(self:GetID());
end

function WoWAccountSelect_OnEvent(self, event)
	if ( event == "GAME_ACCOUNTS_UPDATED" ) then
		local str, selectedIndex, selectedName = ""
		for i = 1, GetNumGameAccounts() do
			local name = GetGameAccountInfo(i);
			if ( name == GlueDropDownMenu_GetText(AccountLoginDropDown) ) then
				selectedName = name;
				selectedIndex = i;
			end
			str = str .. name .. "|";
		end
		
		if ( str == strreplace(GetSavedAccountList(), "!", "") and selectedIndex ) then
			WoWAccountSelect_SelectAccount(selectedIndex);
			return;
		else
			self:Show();
		end
	else
		self:Hide();
	end
end

function WoWAccountSelect_SelectAccount(index)
	if ( AccountLoginSaveAccountName:GetChecked() ) then
		WowAccountSelect_UpdateSavedAccountNames(index);
	else
		SetSavedAccountList("");
	end
	WoWAccountSelectDialog:Hide();
	SetGameAccount(index);
end

function WowAccountSelect_UpdateSavedAccountNames(selectedIndex)
	local count = GetNumGameAccounts();
	
	local str = ""
	for i = 1, count do
		local name = GetGameAccountInfo(i);
		if ( i == selectedIndex ) then
			str = str .. "!" .. name .. "|";
		else
			str = str .. name .. "|";
		end
	end
	SetSavedAccountList(str);
end

ACCOUNTNAME_BUTTON_HEIGHT = 20;

function WoWAccountSelect_OnVerticalScroll (self, offset)
	local scrollbar = _G[self:GetName().."ScrollBar"];
	scrollbar:SetValue(offset);
	WoWAccountSelectDialogBackgroundContainerScrollFrame.offset = floor((offset / ACCOUNTNAME_BUTTON_HEIGHT) + 0.5);
	WoWAccountSelect_Update();
end

MAX_ACCOUNTS_DISPLAYED = 8;
function WoWAccountSelect_Update()
    local count = GetNumGameAccounts();
	
	local offset = WoWAccountSelectDialogBackgroundContainerScrollFrame.offset;
	for index=1, MAX_ACCOUNTS_DISPLAYED do
		local button = _G["WoWAccountSelectDialogBackgroundContainerButton" .. index];
		local name, regionID = GetGameAccountInfo(index + offset);
		button:SetButtonState("NORMAL");
		button.BG_Highlight:Hide();
		if ( name ) then
			button:SetID(index + offset);
			button:SetText(name);
			button.regionID = regionID;
			button:Show();
			if ( index == CURRENT_SELECTED_WOW_ACCOUNT) then
				button.BG_Highlight:Show();
			end
		else
			button:Hide();
		end
	end
	
	GlueScrollFrame_Update(WoWAccountSelectDialogBackgroundContainerScrollFrame, count, MAX_ACCOUNTS_DISPLAYED, ACCOUNTNAME_BUTTON_HEIGHT);
end

function WoWAccountSelect_AccountButton_OnClick(self, button)
	CURRENT_SELECTED_WOW_ACCOUNT = self:GetID();
	WoWAccountSelect_Accept();
end

function WoWAccountSelect_OnKeyDown(self, key)
	if ( key == "ESCAPE" ) then
		WoWAccountSelect_OnCancel(self);
	elseif ( key == "UP" ) then
		CURRENT_SELECTED_WOW_ACCOUNT = max(1, CURRENT_SELECTED_WOW_ACCOUNT - 1);
		WoWAccountSelect_Update()
	elseif ( key == "DOWN" ) then
		CURRENT_SELECTED_WOW_ACCOUNT = min(GetNumGameAccounts(), CURRENT_SELECTED_WOW_ACCOUNT + 1);
		WoWAccountSelect_Update()
	elseif ( key == "ENTER" ) then
		WoWAccountSelect_SelectAccount(CURRENT_SELECTED_WOW_ACCOUNT);
	elseif ( key == "PRINTSCREEN" ) then
		Screenshot();
	end
end

function WoWAccountSelect_OnCancel (self)
	self:Hide();
	GlueDialog:Hide();
	CancelLogin();
end

function WoWAccountSelect_Accept()
	WoWAccountSelect_SelectAccount(CURRENT_SELECTED_WOW_ACCOUNT);
end

function AccountLoginDropDown_OnClick(self)
	GlueDropDownMenu_SetSelectedValue(AccountLoginDropDown, self.value);
end

function AccountLoginDropDown_Initialize()
	local selectedValue = GlueDropDownMenu_GetSelectedValue(AccountLoginDropDown);
	local info;

	for i = 1, #AccountList do
		AccountList[i].checked = (AccountList[i].text == selectedValue);
		GlueDropDownMenu_AddButton(AccountList[i]);
	end
end

AccountList = {};
function AccountLogin_SetupAccountListDDL()
	if ( GetSavedAccountName() ~= "" and GetSavedAccountList() ~= "" ) then
		AccountLoginPasswordEdit:SetPoint("BOTTOM", 0, 239);
		AccountLoginLoginButton:SetPoint("BOTTOM", 0, 102);
		AccountLoginDropDown:Show();
	else
		AccountLoginPasswordEdit:SetPoint("BOTTOM", 0, 259);
		AccountLoginLoginButton:SetPoint("BOTTOM", 0, 122);
		AccountLoginDropDown:Hide();
		return;
	end
	
	AccountList = {};
	local i = 1;
	for str in string.gmatch(GetSavedAccountList(), "([%w!]+)|?") do
		local selected = false;
		if ( strsub(str, 1, 1) == "!" ) then
			selected = true;
			str = strsub(str, 2, #str);
			GlueDropDownMenu_SetSelectedName(AccountLoginDropDown, str);
			GlueDropDownMenu_SetText(str, AccountLoginDropDown);
		end
		AccountList[i] = { ["text"] = str, ["value"] = str, ["selected"] = selected, func = AccountLoginDropDown_OnClick };
		i = i + 1;
	end
end

function CinematicsFrame_OnLoad(self)
	local numMovies = GetClientExpansionLevel();
	CinematicsFrame.numMovies = numMovies;
	if ( numMovies < 2 ) then
		return;
	end
	
	for i = 1, numMovies do
		_G["CinematicsButton"..i]:Show();
	end
	CinematicsBackground:SetHeight(numMovies * 40 + 70);
end

function CinematicsFrame_OnKeyDown(key)
	if ( key == "PRINTSCREEN" ) then
		Screenshot();
	else
		PlaySound("igMainMenuOptionCheckBoxOff");
		CinematicsFrame:Hide();
	end	
end

function Cinematics_PlayMovie(self)
	CinematicsFrame:Hide();
	PlaySound("gsTitleOptionOK");
	MovieFrame.version = self:GetID();
	SetGlueScreen("movie");
end
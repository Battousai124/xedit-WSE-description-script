unit EffsDebugLog;

const 
	GlobDebugFunctionNameFrame = '--------------------------------------------------';
	GlobDebugLastLogWasFunctionStart = false;
var	
	GlobIndentLvl : Integer;
	GlobPrevIndentLvl : Integer; //unused at the moment - prepared for a tree-view like visualization of indention
	EnableDebugLog : boolean;
	CachedIndention : string;
	//LastLogDateTime : Datetime;
	GlobLogStart : Datetime;

//=========================================================================
// log function begin
//=========================================================================
procedure LogFunctionStart (functionName : string;);
begin
	if not EnableDebugLog then Exit;	
	
	AddMessage(RuntimeForLog + CachedIndention + FormatFunctionName(functionName));
	
	GlobPrevIndentLvl := GlobIndentLvl;
	GlobIndentLvl := GlobIndentLvl + 1;
	CachedIndention := GetIndention;
	GlobDebugLastLogWasFunctionStart := true;
	if GlobPrevIndentLvl <= 0 then
		GlobPrevIndentLvl := 0;
	
	//LastLogDateTime := Now;
end;

//=========================================================================
// get function name formatted for log
//=========================================================================
function FormatFunctionName (functionName:string) : string;
var
	name : string;
begin
	name := '>-'
		+ ' ' + functionName + ' ' 
		+ Copy(GlobDebugFunctionNameFrame, 1, Length(GlobDebugFunctionNameFrame)-Length(functionName)-3)
		;
	Result := name;
end;

//=========================================================================
// log function end
//=========================================================================
procedure LogFunctionEnd;
begin
	if not EnableDebugLog then Exit;
	
	GlobPrevIndentLvl := GlobIndentLvl;
	GlobIndentLvl := GlobIndentLvl - 1;
	if GlobIndentLvl < 0 then 
		GlobIndentLvl := 0;
	CachedIndention := GetIndention;
	
	if not GlobDebugLastLogWasFunctionStart then 
		AddMessage(
			RuntimeForLog
			+ CachedIndention 
			+ '<' 
			+ GlobDebugFunctionNameFrame
			);
	
	GlobDebugLastLogWasFunctionStart := false;
	//LastLogDateTime := Now;
end;

//=========================================================================
// get indention for monitoring of recursion
//=========================================================================
function GetIndention: string;
const 
	indentSpace = '     ';
var
	i : Integer;
	indentStr : string;
begin
	//DebugLog(Format('%d', [GlobIndentLvl]));
	
	indentStr := '';
	if GlobIndentLvl >= 1 then
		for i := 1 to GlobIndentLvl do
			indentStr := indentStr + indentSpace;
		
	Result := indentStr;
end;

//=========================================================================
// get run time in minutes and seconds since last log
//=========================================================================
function RuntimeForLog: string;
var
	indentStr : string;
begin
	if GlobLogStart = 0 then 
		GlobLogStart := Now;

	Result := '[' + FormatDateTime('nn:ss',(Now - GlobLogStart)) + '] ';
end;

//=========================================================================
// log string
//=========================================================================
procedure Log (s:string;);
begin
	if not EnableDebugLog then
		AddMessage(RuntimeForLog + s)
	else 
		AddMessage(RuntimeForLog + CachedIndention + s);
	GlobDebugLastLogWasFunctionStart := false;
	//LastLogDateTime := Now;
end;

//=========================================================================
// log string if debugLog is turned on
//=========================================================================
procedure DebugLog (s:string;);
begin
	if not EnableDebugLog then Exit;		
	AddMessage(RuntimeForLog + CachedIndention {+ 'DebugLog: ']} + s);
	GlobDebugLastLogWasFunctionStart := false;
	//LastLogDateTime := Now;
end;


	
end.
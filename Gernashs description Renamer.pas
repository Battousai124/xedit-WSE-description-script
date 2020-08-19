//
// Gernashs_OMOD_ReNamer
//
// Ver: 3.3
// WIP (9)
// Author: Gernash
// Scripting: EffEIO
// Tester: KenShin
//

unit Gernashs_OMOD_ReNamer; // FO4PatchOmodDescriptions;

// code for editing xEdit scripts with Delphi
interface

implementation

uses xEditAPI, Classes, SysUtils, StrUtils, Windows;
uses 'Effs_Lib\EffsDebugLog';
uses 'Effs_Lib\EffsFormTools';
uses 'Gernashs_Lib\Gernashs_OMOD_ReNamer_Form';
uses 'Gernashs_Lib\Gernashs_OMOD_ReNamer_Config';
uses 'Gernashs_Lib\Gernashs_OMOD_ReNamer_DescParser';
uses 'Effs_Lib\EffsXEditTools';

const
  sPropertiesList = wbScriptsPath + 'Gernashs_Lib\Gernashs description Renamer - Resource.txt';

var
  slPropertyMap: TStringList;
  plugin: IInterface;
	ResultTextsList, RecordsHeadersList, ModificationsDoneList, ChecksFailedList, ChecksSuccessfulList, BeforeChangesList, AfterChangesList : TStringList;
	bChecksFailed, bAborted, bRecordSkipped, bModificationNecessary : Boolean;
	bSlPropertyMapTranslated, bThisIsTheFirstExecution: Boolean;
	lastFileProcessed : String;
	executionCounter : Integer;

function Initialize: Integer;
begin
	SetDefaultConfig;
	
	LogFunctionStart('Initialize');
	
	RecordsHeadersList:= TStringList.Create;
	ResultTextsList:= TStringList.Create;
	ChecksFailedList:= TStringList.Create;
	ChecksSuccessfulList:= TStringList.Create;
	ModificationsDoneList:= TStringList.Create;
	BeforeChangesList:= TStringList.Create;
	AfterChangesList:= TStringList.Create;
	
  slPropertyMap := TStringList.Create;
	slPropertyMap.LoadFromFile(sPropertiesList);
	if GlobConfig.AlwaysTranslateResourceFileAfterLoading then 
		TranslateDescriptionConfigurationFile;
	
	executionCounter := 0;
	bThisIsTheFirstExecution := true;
	
	LogFunctionEnd;
end;

function Process(e: IInterface): Integer;
var
  desc, oldDesc: string;
  r, tmpEntry : IInterface;
	tmpBool : Boolean;
	recordNameForOutput, tmpStr : String;
begin
	if GlobConfig.Cancelled then 
		raise Exception.Create('Execution intentionally disrupted with an error (saves time when millions of records would be processed, because you executed the script on files, or even worse on Fallout4.esm)');
	//tmpStr := Signature(e);
	//DebugLog(Format('Sig: %s',[tmpStr]));
	
	//executionCounter := executionCounter + 1; //TODO: needs to be removed again: increases processing time of skipped records by 20%
	
	
	
	bRecordSkipped := false;
	bRecordSkipped := (not CheckIfRecordShouldBeSkipped(e));
	
	if bRecordSkipped then
		Exit;
	
	LogFunctionStart('Process');
	
	// create new plugin
	if bThisIsTheFirstExecution then
	begin
		bThisIsTheFirstExecution := false;
		
		DebugLog(Format('File of Record: %s',[GetFileName(e)]));
		
		CreateMainForm;
		
		if GlobConfig.MainAction = 2 then begin
			OverwriteDescriptionConfigurationFile; 
			//(Cancelled is set by the button itself, therefore doesn't need to be set here)
			Exit;
		end;
		
		if GlobConfig.PluginSelectionMode = 1 then 
		begin
			plugin := AddNewFile;
			SetEditValue(ElementByPath(ElementByIndex(plugin, 0), 'CNAM'), 'Gernash');
			SetElementEditValues(ElementByIndex(plugin, 0),'SNAM', 'Automatically created via Gernashs_OMOD_ReNamer script (do not change the part of this description before the bracket or else the automatic mode will not find the plugin anymore)');
			LogModification(Format('new plugin created: %s',[GetFileName(plugin)]));
		end 
		else if GlobConfig.PluginSelectionMode = 2 then 
		begin 
			plugin := FileByIndex(Pred(FileCount));
			LogCheckSuccessful(Format('Existing plugin selected to store records: %s',[GetFileName(plugin)]));
		end 
		else 
		begin //also happening on "Cancel"
			Log('Operation aborted by user.');
			Exit; //--> no result form necessary here
		end;
		
		if not bAborted then
		begin
			if not Assigned(plugin) then begin
				LogCheckFailed('The plugin selected could not be loaded. Operation aborted.');
				bAborted := true;
			end;
		end;
	end;
	
	bModificationNecessary := true;
	
	//if TypeOf (GetFile(e)) = TypeOf (e) then  { True }
		//DebugLog(Format('Sig: %s',[tmpStr]));
		//DebugLog(Signature(e));
	
	//raise Exception.Create('Variable has no value');
	//DebugLog(Format('Mode: "%d"',[GlobConfig.PluginSelectionMode]));

	if not bRecordSkipped then begin
		// patch the winning override record
		e := WinningOverride(e);
		
		recordNameForOutput := RecordToString(e);
		
		if not Assigned(e) then
		begin
			LogCheckFailed(Format('Something went wrong when getting the override for this record. Record skipped. - record: %s',[recordNameForOutput]));
			bRecordSkipped := true;
		end;
	end;

	if (not GlobConfig.Cancelled) and (not bAborted) and (not bRecordSkipped) then begin
		if (not GlobConfig.Cancelled) and (not bAborted) then
		begin
			RecordsHeadersList.Add(Format('record: %s - created by plugin: %s - winning override in: %s',[recordNameForOutput,GetFileName(MasterOrSelf(e)),GetFileName(WinningOverride(e))]));
			
			// skip already copied
			if GetFileName(e) = GetFileName(plugin) then begin
				LogCheckFailed(Format('The plugin selected already carries an override of the record. Record skipped. - record: %s - plugin: %s',[recordNameForOutput, GetFileName(plugin)]));
				bRecordSkipped := true;
			end;
		end;
	end;
	
	if (not GlobConfig.Cancelled) and (not bAborted) and (not bRecordSkipped) then begin
		desc := GetOmodDescription(e);

		if desc = '' then begin
			 LogCheckFailed(Format('The logic would have created an empty description. Record skipped. - record: %s',[recordNameForOutput]));
			 bRecordSkipped := true;
		end;
	end;
	
	if (not GlobConfig.Cancelled) and (not bAborted) and (not bRecordSkipped) then begin
		oldDesc := GetEditValue(ElementByPath(e, 'DESC'));
		
		if SameText(oldDesc, desc) then
		begin
			LogCheckSuccessful(Format('Description already up to date. - record: %s - DESC: "%s"',[recordNameForOutput,desc]));
			bModificationNecessary := false;
		end else begin
			BeforeChangesList.Add(Format('before: %s - DESC: "%s"',[recordNameForOutput, oldDesc]));
		end;
	end;

	if (not GlobConfig.Cancelled) and (not bAborted) and (not bRecordSkipped) and (bModificationNecessary) then begin
		// add masters
		AddRequiredElementMasters(e, plugin, False);

		try
			// copy as override
			r := wbCopyElementToFile(e, plugin, False, true);
			if not Assigned(r) then
			begin
				LogCheckFailed(Format('Something went wrong when creating the override record. Record skipped. - record: %s',[recordNameForOutput]));
				bRecordSkipped := true;
			end else begin
				LogModification(Format('Record was copied as an override to the selected plugin. - record: %s - plugin: %s',[recordNameForOutput,GetFileName(plugin)]));
				
				// setting new description
				SetElementEditValues(r, 'DESC', desc);
				LogModification(Format('Description was replaced: - record: %s - old DESC: "%s" - new DESC: "%s"',[recordNameForOutput,oldDesc,desc]));
				AfterChangesList.Add(Format('after: %s - DESC: "%s"',[recordNameForOutput, desc]));
			end;
		except
			on Ex: Exception do
			begin
				LogCheckFailed(Format('Failed to copy: %s',[FullPath(e)]));
				LogCheckFailed('    reason: ' + Ex.Message);
			end
		end;
	end;
	
	lastFileProcessed := GetFileName(e);
	
	LogFunctionEnd;
end;


function Finalize: Integer;
begin
	LogFunctionStart('Finalize');
  
	if not GlobConfig.Cancelled then begin
		PrepareResults(bChecksFailed, bAborted);
		CreateResultsForm(bChecksFailed, bAborted, ResultTextsList);
	end;

	slPropertyMap.Free;
  slPropertyMap := nil;
	RecordsHeadersList.Free;
	RecordsHeadersList:=nil;	
	ChecksFailedList.Free;
	ChecksFailedList:=nil;	
	ChecksSuccessfulList.Free;
	ChecksSuccessfulList:=nil;
	ModificationsDoneList.Free;
	ModificationsDoneList:=nil;		
	ResultTextsList.Free;
	ResultTextsList:=nil;	
	BeforeChangesList.Free;
	BeforeChangesList:=nil;	
	AfterChangesList.Free;
	AfterChangesList:=nil;	
	
  if Assigned(plugin) then
    SortMasters(plugin);
		
	LogFunctionEnd;
end;


//=========================================================================
//  Translate the resource file / configuration file 
//=========================================================================
procedure OverwriteDescriptionConfigurationFile();
var
	slCurrentFile : TStringList; 
	backupFileName : String;
begin
	LogFunctionStart('OverwriteDescriptionConfigurationFile');
	slCurrentFile := TStringList.Create;
	
	if not bSlPropertyMapTranslated then 
		TranslateDescriptionConfigurationFile;
	
	try
		slCurrentFile.LoadFromFile(sPropertiesList);
		backupFileName := StringReplace(sPropertiesList, '.txt', FormatDateTime('yyyymmdd_hhnnss',Now) + '_backup.txt', [rfIgnoreCase]);
		slCurrentFile.SaveToFile(backupFileName);
		
		slPropertyMap.SaveToFile(sPropertiesList);
	finally
		slCurrentFile.Free;
		slCurrentFile:=nil;	
	end;
	
	LogFunctionEnd;
end;


//=========================================================================
//  Translate the resource file / configuration file 
//=========================================================================
procedure TranslateDescriptionConfigurationFile();
var
	i, delimPos : Integer;
	line, potentialRecord, newRecordStr : String;
	rec : IInterface; 
begin
	LogFunctionStart('TranslateDescriptionConfigurationFile');
	
	for i := 0 to slPropertyMap.Count-1 do begin
		line := slPropertyMap[i];
		delimPos := Pos('=',line);
		
		if delimPos > 0 then begin
			potentialRecord := Copy(line,1,delimPos-1);
			//DebugLog(Format('Test2: %s',[potentialRecord]));
			if Pos('[',potentialRecord) > 0 then begin 
				rec := StringToRecord(potentialRecord);
				if Assigned(rec) then begin
					//DebugLog(Format('Test5: %s',[potentialRecord]));
					newRecordStr := RecordToString(rec);
					//DebugLog(Format('Test6: %s',[newRecordStr]));
					slPropertyMap[i] := newRecordStr + Copy(line,delimPos,Length(line)-Length(potentialRecord));
					//DebugLog(Format('Test7: %s',[newRecordStr]));
					LogCheckSuccessful(Format('Translated load order dependent record notation in resource file to new notation: line-No.: %d - old notation: %s - new notation: %s',[i,potentialRecord,newRecordStr]));
					//DebugLog(Format('Test8: %s',[newRecordStr]));
				end else begin 
					//DebugLog(Format('Test9: %s',[newRecordStr]));
					LogCheckFailed(Format('Error translating the resource file: could not load record: %s',[potentialRecord]));
				end;
			end;
		end;
	end;
	
	bSlPropertyMapTranslated := true;
	
	LogFunctionEnd;
end;


//=========================================================================
//  Pure Checks (do not contain modification)
//=========================================================================

function CheckIfRecordShouldBeSkipped(rec : IInterface;) : Boolean;
begin
	//no logging in here due to performance reasons
	//LogFunctionStart('CheckIfRecordShouldBeSkipped');
	Result:= true;
	
	if Signature(rec) <> 'OMOD' then begin
		//DebugLog(Format('Record has the wrong signature. Record skipped. - record: %s',[FullPath(rec)]));
		Result:=false;
	end else begin
		//DebugLog(Format('Record has the right signature. - record: %s',[recordNameForOutput]));
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  Logs and output beautification
//=========================================================================
procedure LogCheckFailed (message : string;);
begin
	//LogFunctionStart('LogCheckFailed');
	
	bChecksFailed := true;
	ChecksFailedList.Add(message);
	Log('Check failed: ' + message);
	
	//LogFunctionEnd;
end;

procedure LogCheckSuccessful (message : string;);
begin
	//LogFunctionStart('LogCheckSuccessful');
	
	ChecksSuccessfulList.Add(message);
	Log('Check successful: ' + message);
	
	//LogFunctionEnd;
end;

procedure LogModification (message : string;);
begin
	//LogFunctionStart('LogModification');
	
	ModificationsDoneList.Add(message);
	Log('Modification performed: ' + message);
	
	//LogFunctionEnd;
end;

//prepare results list for output (add headers and such)
procedure PrepareResults (bChecksFailed: boolean; bAborted : boolean;);
const
	headerStr = '-------------------------------------------------------------------';
var 
	tmpStr : String; //overwritten with every usage
	i : Integer;
begin
	LogFunctionStart('PrepareResults');
	
	ResultTextsList.Add(FormatResultHeader('General Information:',headerStr));
	ResultTextsList.AddStrings(RecordsHeadersList);
	//ResultTextsList.Add('(EditorID and plugins of records listed below always represent the master/base version of this record - where the record is created)');
	ResultTextsList.Add(' ');
	
	tmpStr:= 'Checks that failed: ';
	if not bChecksFailed then
		tmpStr:= tmpStr + '(No checks failed) ';
	ResultTextsList.Add(FormatResultHeader(tmpStr,headerStr));
	ResultTextsList.AddStrings(ChecksFailedList);
	ResultTextsList.Add(' ');
	
	if bAborted then begin
		ResultTextsList.Add('--> Operation has been aborted before completion!');		
		ResultTextsList.Add(' ');
	end;

	tmpStr:= 'Checks that were successful: ';
	if ChecksSuccessfulList.Count = 0 then
		tmpStr:= tmpStr + '(No successful checks) ';
	ResultTextsList.Add(FormatResultHeader(tmpStr,headerStr));
	ResultTextsList.AddStrings(ChecksSuccessfulList);
	ResultTextsList.Add(' ');
	
	//tmpStr:= 'Masters added: ';
	//if AddedMastersList.Count = 0 then 
	//	tmpStr:= tmpStr + '(no masters added) ';
	//ResultTextsList.Add(FormatResultHeader(tmpStr,headerStr));
	//ResultTextsList.AddStrings(AddedMastersList);
	//ResultTextsList.Add(' ');
	
	tmpStr:= 'Modifications performed: ';
	if ModificationsDoneList.Count = 0 then 
		tmpStr:= tmpStr + '(no modifications) ';
	ResultTextsList.Add(FormatResultHeader(tmpStr,headerStr));
	ResultTextsList.AddStrings(ModificationsDoneList);
	ResultTextsList.Add(' ');
	
	if BeforeChangesList.Count >= 1 then begin
		ResultTextsList.Add(FormatResultHeader('Before changes: ',headerStr));
		ResultTextsList.AddStrings(BeforeChangesList);		
		ResultTextsList.Add(' ');
	end;
	
	if AfterChangesList.Count >= 1 then begin
		ResultTextsList.Add(FormatResultHeader('After changes: ',headerStr));
		ResultTextsList.AddStrings(AfterChangesList);		
		ResultTextsList.Add(' ');
	end;	
	
	LogFunctionEnd;
end;

function FormatResultHeader (text, headerStr : String) : String;
begin
	LogFunctionStart('FormatResultHeader');
	
	Result:= Copy(headerStr,1,5)
		+ ' ' + text + ' '
		+ Copy(headerStr,1,Length(headerStr)-Length(text)-2);
	
	LogFunctionEnd;
end;

end.

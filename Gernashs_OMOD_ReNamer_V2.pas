//
// Gernashs_description_Renamer
//
// Ver: 4
// WIP (2)
//
// Scripting: EffEIO
// Tester: KenShin, Gernash
//

unit Gernashs_description_Renamer; // FO4PatchOmodDescriptions;

// code for editing xEdit scripts with Delphi
interface

implementation

uses
  xEditAPI,
  Classes,
  SysUtils,
  StrUtils,
  Windows;
uses 'Effs_Lib\EffsDebugLog';
uses 'Effs_Lib\EffsFormTools';
uses 'Gernashs_Lib\Gernashs_OMOD_ReNamer_Form';
uses 'Gernashs_Lib\Gernashs_OMOD_ReNamer_Config';
uses 'Gernashs_Lib\Gernashs_OMOD_ReNamer_DescParser';
uses 'Effs_Lib\EffsXEditTools';

const
  sPropertiesList = wbScriptsPath +
    'Gernashs_Lib\Gernashs description Renamer - Resource.txt';
  automaticPluginDescriptionStartStr =
    'Automatically created via Gernashs_OMOD_ReNamer script';

var
  slPropertyMap: TStringList;
  targetPlugin: IwbFile;
  ResultTextsList, RecordsHeadersList, ModificationsDoneList, ChecksFailedList,
    ChecksSuccessfulList, BeforeChangesList, AfterChangesList: TStringList;
  bChecksFailed, bAborted, bModificationNecessary, bTargetPluginLoaded: Boolean;
  bSlPropertyMapTranslated, bThisIsTheFirstExecution: Boolean;
  { lastFileProcessed, } targetPluginName: String;

function Initialize: Integer;
begin
  SetDefaultConfig;

  LogFunctionStart('Initialize');

  RecordsHeadersList := TStringList.Create;
  ResultTextsList := TStringList.Create;
  ChecksFailedList := TStringList.Create;
  ChecksSuccessfulList := TStringList.Create;
  ModificationsDoneList := TStringList.Create;
  BeforeChangesList := TStringList.Create;
  AfterChangesList := TStringList.Create;

  slPropertyMap := TStringList.Create;
  slPropertyMap.LoadFromFile(sPropertiesList);
  if GlobConfig.AlwaysTranslateResourceFileAfterLoading then
    TranslateDescriptionConfigurationFile;

  ReadLoadOrder;

  bThisIsTheFirstExecution := true;

  LogFunctionEnd;
end;

function Process(rec: IInterface): Integer;
begin
  if GlobConfig.Cancelled then
    raise Exception.Create
      ('Execution intentionally disrupted with an error (saves time when millions of records would be processed, because you executed the script on files, or even worse on Fallout4.esm)');

  if CheckIfRecordShouldBeSkipped(rec) and (not bThisIsTheFirstExecution) then
    Exit;

  LogFunctionStart('Process');

  if bThisIsTheFirstExecution then
  begin
    bThisIsTheFirstExecution := false;

    CreateMainForm;

    if GlobConfig.MainAction = 2 then
    begin
      OverwriteDescriptionConfigurationFile;
      // (Cancelled is set by the button itself, therefore doesn't need to be set here)
      Exit;
    end;
  end;

  if (not GlobConfig.Cancelled) and (not bAborted) and (signature(rec) = 'OMOD') then
  begin
    ProcessOneOMODRecord(rec);
  end;

  // lastFileProcessed := GetFileName(rec);

  LogFunctionEnd;
end;

function Finalize: Integer;
begin
  LogFunctionStart('Finalize');

	if GlobConfig.CopyFunctionalDisplay then
		begin
			CopyFunctionalDisplayKYWD;
		end;

  if not GlobConfig.Cancelled then
  begin
    PrepareResults(bChecksFailed, bAborted);
    CreateResultsForm(bChecksFailed, bAborted, ResultTextsList);
  end;

  slPropertyMap.Free;
  slPropertyMap := nil;
  RecordsHeadersList.Free;
  RecordsHeadersList := nil;
  ChecksFailedList.Free;
  ChecksFailedList := nil;
  ChecksSuccessfulList.Free;
  ChecksSuccessfulList := nil;
  ModificationsDoneList.Free;
  ModificationsDoneList := nil;
  ResultTextsList.Free;
  ResultTextsList := nil;
  BeforeChangesList.Free;
  BeforeChangesList := nil;
  AfterChangesList.Free;
  AfterChangesList := nil;
  GlobConfig.NotAllowedPluginNames.Free;
  GlobConfig.NotAllowedPluginNames := nil;
  GlobConfig.ExistingGernashsDescrPlugins.Free;
  GlobConfig.ExistingGernashsDescrPlugins := nil;

  if Assigned(targetPlugin) then
    SortMasters(targetPlugin);

  LogFunctionEnd;
end;

//CopyFunctionalDisplayKYWD

procedure CopyFunctionalDisplayKYWD();
var
	AWKCRplugin, KeywordsGroup, tmpRec, curReferencingRec, WinrecordRef : IInterface;
	i, j, tmpInt, refCount :Integer;
	curKYWDReferenceBy, recNamesCorrected : TStringList;
  recordRefName, WinrecordRefName : string;
	
begin
	LogFunctionStart('CopyFunctionalDisplayKYWD');
	curKYWDReferenceBy := TStringList.Create;
	curKYWDReferenceBy.Sorted := True; //so that .Find() works
	curKYWDReferenceBy.Duplicates := dupIgnore;
	recNamesCorrected := TStringList.Create;
	recNamesCorrected.Sorted := True; //so that .Find() works
	recNamesCorrected.Duplicates := dupIgnore;
	Try
		//Search for AWKR.esp(FD KYWDs) ArmorKeywords.esm
		AWKCRplugin := FileByName('ArmorKeywords.esm');
		KeywordsGroup := GroupBySignature(AWKCRplugin, 'KYWD');
		
		//if found get all records KYWD: 99_Keyword_  11chr
		for i := 0 to ElementCount(KeywordsGroup) - 1 do
		begin
			tmpREC := ElementByIndex(KeywordsGroup, i);
			curKYWDReferenceBy.clear;
			recNamesCorrected.clear;
			if not(SameText(copy(EditorID(tmpRec), 1, 11), '99_Keyword_')) then
				continue;  //22output
			refCount := ReferencedByCount(tmpRec);
		
			//for every KYWD record: look into references get every record that reference KYWD: 99_Keyword_
			for j := 0 to refCount - 1 do
				begin
					curReferencingRec := ReferencedByIndex(tmpRec, j);
					recordRefName := EditorID(curReferencingRec) + '[' + GetFileName(curReferencingRec) + ']' + ':' + Signature(curReferencingRec);
					curKYWDReferenceBy.add(recordRefName); //RecordToString-always returns master record
					end;
			for j := 0 to curKYWDReferenceBy.count -1 do
				begin
					recordRefName := curKYWDReferenceBy[j];
					WinrecordRef := WinningOverride(StringToRecord(recordRefName));
					WinrecordRefName := EditorID(WinrecordRef) + '[' + GetFileName(WinrecordRef) + ']' + ':' + Signature(WinrecordRef);
				//duplicate remover
				if (not(curKYWDReferenceBy.find(WinrecordRefName, tmpInt))) and (not(recNamesCorrected.find(WinrecordRefName, tmpInt))) then
						begin
						//	create override and create keyword
							recNamesCorrected.add(WinrecordRefName);
						end;
				end;
		end;
		
	Finally
		curKYWDReferenceBy.free;
		curKYWDReferenceBy:= Nil;
		recNamesCorrected.free;
		recNamesCorrected:= Nil;
	end;	
	//    for every reference found is the winning override still referencing the keyword 
	//		if not then create override from reference. and copy KYWD
	//


	LogFunctionEnd;
end;


 // =========================================================================
// read the load order and store certain things in the config for later usage
// =========================================================================
procedure ReadLoadOrder();
const
  basicPluginNameSuggestion = 'Gernashs_OMODDescr';
var
  i, j, tmpInt: Integer;
  tmpStr, pluginName, pluginNameWithoutExtension: String;
  plugin: IInterface;
  existsAlready, isNewName: Boolean;
begin
  LogFunctionStart('ReadLoadOrder');

  GlobConfig.LastPluginInLoadOrder := GetFileName(FileByIndex(Pred(FileCount)));

  // read the load order
  for i := 0 to Pred(FileCount) do
  begin
    plugin := FileByIndex(i);
    pluginName := GetFileName(plugin);
    pluginNameWithoutExtension := Copy(pluginName, 1, Length(pluginName) - 4);

    GlobConfig.NotAllowedPluginNames.Add(pluginNameWithoutExtension);

    tmpStr := GetElementEditValues(ElementByIndex(plugin, 0), 'SNAM');
    if Length(tmpStr) >= Length(automaticPluginDescriptionStartStr) then
    begin
      if SameText(automaticPluginDescriptionStartStr,
        Copy(tmpStr, 1, Length(automaticPluginDescriptionStartStr))) then
      begin
        GlobConfig.ExistingGernashsDescrPlugins.Add(pluginName);
      end
    end;
  end;

  // cross check with the data folder, not to create files that already exist there
  AddPluginsInDataFolderToNotAllowedList(GlobConfig.NotAllowedPluginNames);

  // generate a new suggestion for a filename
  existsAlready := false;
  isNewName := false;
  pluginNameWithoutExtension := basicPluginNameSuggestion;
  pluginName := pluginNameWithoutExtension + '.esp';
  i := 1;
  while not isNewName do
  begin
    existsAlready := false;

    if i > 1 then
    begin
      pluginNameWithoutExtension :=
        Format('%s_%d', [basicPluginNameSuggestion, i]);
      pluginName := pluginNameWithoutExtension + '.esp';
    end;

    for j := 0 to GlobConfig.ExistingGernashsDescrPlugins.Count - 1 do
    begin
      if SameText(pluginName, GlobConfig.ExistingGernashsDescrPlugins[j]) then
      begin
        existsAlready := true;
        break;
      end;
    end;

    if not existsAlready then
      if GlobConfig.NotAllowedPluginNames.Find(pluginNameWithoutExtension,
        tmpInt) then
        existsAlready := true;

    if not existsAlready then
      isNewName := true;

    i := i + 1;
  end;

  GlobConfig.NewPluginName := pluginNameWithoutExtension;
  GlobConfig.ExistingGernashsDescrPluginsSelectedIndex :=
    GlobConfig.ExistingGernashsDescrPlugins.Count - 1;

  LogFunctionEnd;
end;

// =========================================================================
// add ESPs residing in the Game's Data folder to the not allowed list, if they are not in there already
// =========================================================================
procedure AddPluginsInDataFolderToNotAllowedList(notAllowedFilesWithoutExtension
  : TStringList;);
var
  tmpStringList: TStringList;
  i, tmpInt: Integer;
  searchRec: TSearchRec;
  dataPath, tmpStr: String;
begin
  LogFunctionStart('AddPluginsInDataFolderToNotAllowedList');

  tmpStringList := TStringList.Create;
  tmpStringList.Sorted := true;
  tmpStringList.Duplicates := dupIgnore;

  try
    // fist copy the existing list over to one that does not grow when there are a lot of files
    for i: = 0 to notAllowedFilesWithoutExtension.Count - 1 do
    begin
      tmpStringList.Add(notAllowedFilesWithoutExtension[i])
    end;

    // now go through all files in the data directory and add them to the forbidden-List
    dataPath := wbDataPath;
    if FindFirst(dataPath + '*.esp', faAnyFile, searchRec) = 0 then
    begin
      repeat
        if SameText(searchRec.Name, '.') then
          continue;
        if SameText(searchRec.Name, '..') then
          continue;

        tmpStr := Copy(searchRec.Name, 1, Length(searchRec.Name) - 4);

        if not tmpStringList.Find(tmpStr, tmpInt) then
          notAllowedFilesWithoutExtension.Add(tmpStr);
      until FindNext(searchRec) <> 0;

      FindClose(searchRec);
    end;

  finally
    tmpStringList.Free;
    tmpStringList := nil;
  end;

  LogFunctionEnd;
end;

// =========================================================================
// get target Plugin - where to store new record overwrites to
// =========================================================================
procedure GetOrCreateTargetPlugin();
var
  tmpRec: IInterface;
  tmpStr: String;
begin
  LogFunctionStart('GetOrCreateTargetPlugin');

  if GlobConfig.PluginSelectionMode = 1 then // automatic
  begin
    if GlobConfig.ExistingGernashsDescrPluginsSelectedIndex < 0 then
    begin
      tmpStr := GlobConfig.NewPluginName;
      if not SameText(Copy(tmpStr, Length(tmpStr) - 4, 4), '.esp') then
        tmpStr := tmpStr + '.esp';
      targetPlugin := AddNewFileName(tmpStr, true);

      SetEditValue(ElementByPath(ElementByIndex(targetPlugin, 0), 'CNAM'),
        'Gernash');
      SetElementEditValues(ElementByIndex(targetPlugin, 0), 'SNAM',
        automaticPluginDescriptionStartStr +
        ' (do not change the part of this description before the bracket or else the automatic mode will not find the plugin anymore)');

      LogModification(Format('new plugin created: %s',
        [GetFileName(targetPlugin)]));
    end
    else
    begin
      targetPlugin := FileByName(GlobConfig.ExistingGernashsDescrPlugins
        [GlobConfig.ExistingGernashsDescrPluginsSelectedIndex]);
      LogCheckSuccessful(Format('Existing plugin selected to store records: %s',
        [GetFileName(targetPlugin)]));
    end;
  end
  else if GlobConfig.PluginSelectionMode = 2 then
  begin
    tmpStr := GlobConfig.NewPluginName;
    if not SameText(Copy(tmpStr, Length(tmpStr) - 4, 4), '.esp') then
      tmpStr := tmpStr + '.esp';
    targetPlugin := AddNewFileName(tmpStr, true);

    SetEditValue(ElementByPath(ElementByIndex(targetPlugin, 0), 'CNAM'),
      'Gernash');
    SetElementEditValues(ElementByIndex(targetPlugin, 0), 'SNAM',
      automaticPluginDescriptionStartStr +
      ' (do not change the part of this description before the bracket or else the automatic mode will not find the plugin anymore)');

    LogModification(Format('new plugin created: %s',
      [GetFileName(targetPlugin)]));
  end
  else if GlobConfig.PluginSelectionMode = 3 then
  begin
    targetPlugin := FileByIndex(Pred(FileCount));
    LogCheckSuccessful(Format('Existing plugin selected to store records: %s',
      [GetFileName(targetPlugin)]));
  end
  else
  begin // also happening on "Cancel"
    LogCheckFailed
      ('Could not read configuration how to select the target plugin.');
    Exit; // --> no result form necessary here
  end;

  if not bAborted then
  begin
    if not Assigned(targetPlugin) then
    begin
      LogCheckFailed
        ('The plugin selected could not be loaded. Operation aborted.');
      bAborted := true;
    end;
  end;

  targetPluginName := GetFileName(targetPlugin);
  bTargetPluginLoaded := true;

  LogFunctionEnd;
end;

// =========================================================================
// processes a single OMOD record
// =========================================================================
procedure ProcessOneOMODRecord(rec: IInterface);
var
  desc, oldDesc, recordPluginName: string;
  newRec, tmpEntry: IInterface;
  bRecordAlreadyPresent: Boolean;
  recordNameForOutput, tmpStr: String;
begin
  LogFunctionStart('ProcessOneOMODRecord');

  bModificationNecessary := true;

  // patch the winning override record
  rec := WinningOverride(rec);

  recordNameForOutput := RecordToString(rec);
  recordPluginName := GetFileName(rec);

  if not Assigned(rec) then
  begin
    LogCheckFailed
      (Format('Something went wrong when getting the override for this record. Record skipped. - record: %s',
      [recordNameForOutput]));
    LogFunctionEnd;
    Exit;
  end;

  // call actual logic for generating the description
  desc := GetOmodDescription(rec);

  if desc = '' then
  begin
    LogCheckFailed
      (Format('The logic would have created an empty description. Record skipped. - record: %s',
      [recordNameForOutput]));
    LogFunctionEnd;
    Exit;
  end;

  if (not bAborted) then
  begin
    oldDesc := GetEditValue(ElementByPath(rec, 'DESC'));

    if SameText(oldDesc, desc) then
    begin
      LogCheckSuccessful
        (Format('Description already up to date. - record: %s - DESC: "%s"',
        [recordNameForOutput, desc]));
      bModificationNecessary := false;
    end
    else
    begin
      BeforeChangesList.Add(Format('before: %s - DESC: "%s"',
        [recordNameForOutput, oldDesc]));
    end;
  end;

  if (not bAborted) and (bModificationNecessary) then
  begin
    // create new plugin
    if not bTargetPluginLoaded then
      GetOrCreateTargetPlugin;

    if (not bAborted) then
    begin
      if GlobConfig.DoNotManipulateMasterRecords then
      begin
        if SameText(GetFileName(MasterOrSelf(rec)), targetPluginName) then
        begin
          LogCheckFailed
            (Format('The plugin selected is the master plugin for this record. Record skipped. - record: %s - plugin: %s',
            [recordNameForOutput, targetPluginName]));
          LogFunctionEnd;
          // --> this will not result in an empty plugin being created, as it can only happen, if an existing plugin is selected
          Exit;
        end;
      end;

      RecordsHeadersList.Add
        (Format('record: %s - created by plugin: %s - winning override in: %s',
        [recordNameForOutput, GetFileName(MasterOrSelf(rec)),
        GetFileName(WinningOverride(rec))]));
      try
        if SameText(recordPluginName, targetPluginName) then
        begin
          newRec := rec;
        end
        else
        begin
          // add masters
          AddRequiredElementMasters(rec, targetPlugin, false);

          // copy as override
          newRec := wbCopyElementToFile(rec, targetPlugin, false, true);
          LogModification
            (Format('Record was copied as an override to the selected plugin. - record: %s - plugin: %s',
            [recordNameForOutput, targetPluginName]));
        end;

        if not Assigned(newRec) then
        begin
          LogCheckFailed
            (Format('Something went wrong when creating the override record. Record skipped. - record: %s',
            [recordNameForOutput]));
          LogFunctionEnd;
          Exit;
        end
        else
        begin
          // setting new description
          SetElementEditValues(newRec, 'DESC', desc);
          LogModification
            (Format('Description was replaced: - record: %s - old DESC: "%s" - new DESC: "%s"',
            [recordNameForOutput, oldDesc, desc]));
          AfterChangesList.Add(Format('after: %s - DESC: "%s"',
            [recordNameForOutput, desc]));
        end;
      except
        on Ex: Exception do
        begin
          LogCheckFailed(Format('Failed to copy: %s', [FullPath(rec)]));
          LogCheckFailed('    reason: ' + Ex.Message);
        end;
      end;
    end;
  end;

  LogFunctionEnd;
end;

// =========================================================================
// Translate the resource file / configuration file
// =========================================================================
procedure OverwriteDescriptionConfigurationFile();
var
  slCurrentFile: TStringList;
  backupFileName: String;
begin
  LogFunctionStart('OverwriteDescriptionConfigurationFile');
  slCurrentFile := TStringList.Create;

  if not bSlPropertyMapTranslated then
    TranslateDescriptionConfigurationFile;

  try
    slCurrentFile.LoadFromFile(sPropertiesList);
    backupFileName := StringReplace(sPropertiesList, '.txt',
      FormatDateTime('yyyymmdd_hhnnss', Now) + '_backup.txt', [rfIgnoreCase]);
    slCurrentFile.SaveToFile(backupFileName);

    slPropertyMap.SaveToFile(sPropertiesList);
  finally
    slCurrentFile.Free;
    slCurrentFile := nil;
  end;

  LogFunctionEnd;
end;

// =========================================================================
// Translate the resource file / configuration file
// =========================================================================
procedure TranslateDescriptionConfigurationFile();
var
  i, delimPos: Integer;
  line, potentialRecord, newRecordStr: String;
  rec: IInterface;
begin
  LogFunctionStart('TranslateDescriptionConfigurationFile');

  for i := 0 to slPropertyMap.Count - 1 do
  begin
    line := slPropertyMap[i];
    delimPos := Pos('=', line);

    if delimPos > 0 then
    begin
      potentialRecord := Copy(line, 1, delimPos - 1);
      // DebugLog(Format('Test2: %s',[potentialRecord]));
      if Pos('[', potentialRecord) > 0 then
      begin
        rec := StringToRecord(potentialRecord);
        if Assigned(rec) then
        begin
          // DebugLog(Format('Test5: %s',[potentialRecord]));
          newRecordStr := RecordToString(rec);
          // DebugLog(Format('Test6: %s',[newRecordStr]));
          slPropertyMap[i] := newRecordStr + Copy(line, delimPos,
            Length(line) - Length(potentialRecord));
          // DebugLog(Format('Test7: %s',[newRecordStr]));
          LogCheckSuccessful
            (Format('Translated load order dependent record notation in resource file to new notation: line-No.: %d - old notation: %s - new notation: %s',
            [i, potentialRecord, newRecordStr]));
          // DebugLog(Format('Test8: %s',[newRecordStr]));
        end
        else
        begin
          // DebugLog(Format('Test9: %s',[newRecordStr]));
          LogCheckFailed
            (Format('Error translating the resource file: could not load record: %s',
            [potentialRecord]));
        end;
      end;
    end;
  end;

  bSlPropertyMapTranslated := true;

  LogFunctionEnd;
end;


// =========================================================================
// Pure Checks (do not contain modification)
// =========================================================================

function CheckIfRecordShouldBeSkipped(rec: IInterface;): Boolean;
begin
  // no logging in here due to performance reasons
  // LogFunctionStart('CheckIfRecordShouldBeSkipped');
  Result := false;

  if Signature(rec) <> 'OMOD' then
  begin
    // DebugLog(Format('Record has the wrong signature. Record skipped. - record: %s',[FullPath(rec)]));
    Result := true;
  end
  else
  begin
    // DebugLog(Format('Record has the right signature. - record: %s',[recordNameForOutput]));
  end;

  // LogFunctionEnd;
end;

// =========================================================================
// Logs and output beautification
// =========================================================================
procedure LogCheckFailed(Message: string;);
begin
  // LogFunctionStart('LogCheckFailed');

  bChecksFailed := true;
  ChecksFailedList.Add(message);
  Log('Check failed: ' + message);

  // LogFunctionEnd;
end;

procedure LogCheckSuccessful(Message: string;);
begin
  // LogFunctionStart('LogCheckSuccessful');

  ChecksSuccessfulList.Add(message);
  Log('Check successful: ' + message);

  // LogFunctionEnd;
end;

procedure LogModification(Message: string;);
begin
  // LogFunctionStart('LogModification');

  ModificationsDoneList.Add(message);
  Log('Modification performed: ' + message);

  // LogFunctionEnd;
end;

// prepare results list for output (add headers and such)
procedure PrepareResults(bChecksFailed: Boolean; bAborted: Boolean;);
const
  headerStr =
    '-------------------------------------------------------------------';
var
  tmpStr: String; // overwritten with every usage
  i: Integer;
begin
  LogFunctionStart('PrepareResults');

  ResultTextsList.Add(FormatResultHeader('General Information:', headerStr));
  ResultTextsList.AddStrings(RecordsHeadersList);
  // ResultTextsList.Add('(EditorID and plugins of records listed below always represent the master/base version of this record - where the record is created)');
  ResultTextsList.Add(' ');

  tmpStr := 'Checks that failed: ';
  if not bChecksFailed then
    tmpStr := tmpStr + '(No checks failed) ';
  ResultTextsList.Add(FormatResultHeader(tmpStr, headerStr));
  ResultTextsList.AddStrings(ChecksFailedList);
  ResultTextsList.Add(' ');

  if bAborted then
  begin
    ResultTextsList.Add('--> Operation has been aborted before completion!');
    ResultTextsList.Add(' ');
  end;

  tmpStr := 'Checks that were successful: ';
  if ChecksSuccessfulList.Count = 0 then
    tmpStr := tmpStr + '(No successful checks) ';
  ResultTextsList.Add(FormatResultHeader(tmpStr, headerStr));
  ResultTextsList.AddStrings(ChecksSuccessfulList);
  ResultTextsList.Add(' ');

  // tmpStr:= 'Masters added: ';
  // if AddedMastersList.Count = 0 then
  // tmpStr:= tmpStr + '(no masters added) ';
  // ResultTextsList.Add(FormatResultHeader(tmpStr,headerStr));
  // ResultTextsList.AddStrings(AddedMastersList);
  // ResultTextsList.Add(' ');

  tmpStr := 'Modifications performed: ';
  if ModificationsDoneList.Count = 0 then
    tmpStr := tmpStr + '(no modifications) ';
  ResultTextsList.Add(FormatResultHeader(tmpStr, headerStr));
  ResultTextsList.AddStrings(ModificationsDoneList);
  ResultTextsList.Add(' ');

  if BeforeChangesList.Count >= 1 then
  begin
    ResultTextsList.Add(FormatResultHeader('Before changes: ', headerStr));
    ResultTextsList.AddStrings(BeforeChangesList);
    ResultTextsList.Add(' ');
  end;

  if AfterChangesList.Count >= 1 then
  begin
    ResultTextsList.Add(FormatResultHeader('After changes: ', headerStr));
    ResultTextsList.AddStrings(AfterChangesList);
    ResultTextsList.Add(' ');
  end;

  LogFunctionEnd;
end;

function FormatResultHeader(text, headerStr: String): String;
begin
  LogFunctionStart('FormatResultHeader');

  Result := Copy(headerStr, 1, 5) + ' ' + text + ' ' +
    Copy(headerStr, 1, Length(headerStr) - Length(text) - 2);

  LogFunctionEnd;
end;

end.

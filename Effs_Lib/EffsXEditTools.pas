unit EffsXEditTools;

// This unit only contains static functions to deal with XEdit challenges, no variables
// (it requires EffsDebugLog to be loaded)

implementation

uses 'Effs_Lib\EffsStringTools';

//=========================================================================
// convert record to string consisting of Editor ID and plugin's name with signature of group
//=========================================================================
function RecordToString(const rec: IInterface): string;
begin
	Result := EditorID(rec) + '[' + GetFileName(rec) + ']' + ':' + Signature(rec);
end;

//=========================================================================
// convert master of record to string consisting of Editor ID and plugin's name with signature of group
//=========================================================================
function RecordMasterToString(const rec: IInterface): string;
var
	baseRec: IInterface;
begin
	baseRec := MasterOrSelf(rec); //use master record to be safe against renames
	Result := EditorID(baseRec) + '[' + GetFileName(baseRec) + ']' + ':' + Signature(baseRec);
end;

//=========================================================================
// locate record in the current load order by string
// works with Effs notation (EditorID[FileName]:Signature) and with the load order dependent xEdit notation (EditorID "FULL name"[Signature:FormID])
// (written in a strange, code-heavy way so that it is comparatively fast even with a dumb Pascal on-time compiler)
//=========================================================================
function StringToRecord(const rec: string): IInterface;
var
	i, j, k, count1, count2, count3 : integer;
	inBracket, beforeBracket, afterBracket: string;
	f, g, tmpRec, tmpRec2, cellRec : IInterface;
	isNewNotation : Boolean;
begin
	//LogFunctionStart('StringToRecord');
	
	if not SameText(rec,'') then begin 
		j := Pos(']', rec);
		//DebugLog(Format('position of closing square brackets: %d',[j]));
		if j <= 0 then begin
			//this is a file
			//DebugLog(Format('this is a file, name: %s',[rec]));
			Result := FileByName(rec);
		end else begin 
			isNewNotation := true;
			
			if Pos('"', rec) > 0 then
				isNewNotation := false;
			
			if isNewNotation then begin
				//j := Pos(']', rec);
				afterBracket := Copy(rec, j + 2, Length(rec)); // Signature of Group where the mainrecord is in keyword

				if afterBracket = '' then 
					isNewNotation := false;
				
				if isNewNotation then begin
					i := Pos('[', rec);
					inBracket := Copy(rec, i + 1, j - i - 1); // plugin of keyword
				
					if Pos(':', inBracket) > 0 then
						isNewNotation := false;
				end;
			end;	
			// DebugLog(Format('Test3 - string: %s, inBracket: %s, afterBracket: %s',[rec,inBracket,afterBracket]));
			
			if isNewNotation then begin
				//Effs notation - not load order dependent
				beforeBracket := Copy(rec, 1, i - 1); // Editor ID of keyword
				for i := 0 to Pred(FileCount) do
					if SameText(GetFileName(FileByIndex(i)), inBracket) then begin
						f := FileByIndex(i);
						// DebugLog(Format('file found: %s',[inBracket]));
						Break;
					end;
				g := GroupBySignature(f, afterBracket);
				// if Assigned(g) then DebugLog(Format('group found: %s',[afterBracket]));
				if SameText(afterBracket,'CELL') then begin
					Result := MainCellRecordByEditorID(g, beforeBracket);
				end else begin
					Result := MainRecordByEditorID(g, beforeBracket);
				end;
				// if Assigned(Result) then DebugLog(Format('record found: %s',[GetElementEditValues(Result, 'Record Header\FormID')]));
			end else begin
				//xEdit notation - load order dependent
				inBracket := ReverseString(rec); //read from the right, as the name could contain a bracket
				i := Pos(':', inBracket);
				inBracket := Copy(inBracket, 2, i-2);
				inBracket := ReverseString(inBracket);
				i := Pos(']', inBracket);
				if i > 0 then 
					inBracket := Copy(inBracket, 1, i-1);
				//DebugLog(Format('Test4 - inBracket: "%s"',[inBracket]));
				i:=StrToInt('$' + Copy(inBracket, 1, 2));
				//DebugLog(Format('Test9 - inBracket: %s, i: %d',[inBracket,i]));
				if i <= Pred(FileCount) then begin
					f := FileByLoadOrder(i); //ATTENTION: if your load order contains any ESLs, this does not work reliably! -> use my load order independent notation!
					
					Result := RecordByFormID(f, StrToInt('$' + inBracket), true);
				end;
			end;
		end;
	end;
	//DebugLog(GetElementEditValues(Result, 'Record Header\FormID'));
	//LogFunctionEnd;
end;

//=========================================================================
// a version of MainRecordByEditorID that works for CELL records
//=========================================================================
function MainCellRecordByEditorID (const g: IwbGroupRecord; const edId: string;): IwbMainRecord;
var
	i, j, k, blockCount, subBlockCount, recordCount : Integer;
	blockRec, subBlockRec, cellRec : IInterface;
begin
	//LogFunctionStart('MainCellRecordByEditorID');
	
	blockCount := ElementCount(g);
	// DebugLog(Format('element Count of group: %d',[blockCount]));
	
	i := 0;
	while i < blockCount do begin
		blockRec := ElementByIndex(g, i);
		subBlockCount := ElementCount(blockRec);
		// DebugLog(Format('element Count of block: %d',[subBlockCount]));
		
		j := 0;
		while j < subBlockCount do begin
			subBlockRec := ElementByIndex(blockRec, j);
			recordCount := ElementCount(subBlockRec);
			// DebugLog(Format('element Count of sub-block: %d',[recordCount]));
			
			k := 0;
			while k < recordCount do begin
				cellRec := ElementByIndex(subBlockRec, k);
				if SameText(EditorID(cellRec),edId) then begin
					Result := cellRec;
					//set exit condition
					k := recordCount + 1;
					j := subBlockCount + 1;
					i := blockCount + 1;
				end;
				inc(k);
			end;
			
			inc(j);
		end;
		
		inc(i);
	end;
	//LogFunctionEnd;
end;


//=========================================================================
// checks if a record notation follows Effs notation (EditorID[FileName]:Signature) or the load order dependent xEdit notation (EditorID "FULL name"[Signature:FormID])
// (not needed if you want the record back - in that case just use StringToRecord)
// (written in a strange, code-heavy way so that it is comparatively fast even with a dumb Pascal on-time compiler)
//=========================================================================
function RecordStringIsEffsNotation(const rec: string): Boolean;
var
	i, j: integer;
	tmpStr : String;
begin
	Result := true;
	
	if Pos('"', rec) > 0 then
		Result := false;
	
	if Result then begin
		j := Pos(']', rec);
		tmpStr := Copy(rec, j + 2, Length(rec)); // after brackets

		if tmpStr = '' then 
			Result := false;
		
		if Result then begin
			i := Pos('[', rec);
			tmpStr := Copy(rec, i + 1, j - i - 1); // in brackets
		
			if Pos(':', tmpStr) > 0 then
				Result := false;
		end;
	end;
end;

//=========================================================================
//get Hex-ID to support referencing to different records having the same EditorID
//=========================================================================
function HexFormID(const e: IInterface): string;
var
	s: string;
	i: integer;
begin
	s := GetElementEditValues(e, 'Record Header\FormID');
	s := ReverseString(s);
	i := Pos('[', s);
	s := Copy(s, 0, i);
	Result := ReverseString(s);
end;

//=========================================================================
//get a record by providing the HEX-FormID (e.g. '0002BFA2')
//=========================================================================
function RecordByHexFormID(const id: string): IInterface;
var
  f: IInterface;
begin
  f := FileByLoadOrder(StrToInt('$' + Copy(id, 1, 2)));
  Result := RecordByFormID(f, StrToInt('$' + id), true);
end;


//=========================================================================
//provided with the record string this function reads out the editorID and then beautifies it, so it can be used for dropdown lists
//=========================================================================
function RecordStringToDropdownEntry(s:String; removeStringList : TStringList;): string;
var
	tmpStr: string;
	i: integer;
begin
	LogFunctionStart('RecordStringToDropdownEntry');
	
	i := Pos('[', s);
	s := Copy(s, 0, i-1);
	
	for i := 0 to removeStringList.Count - 1 do begin
		tmpStr := removeStringList[i];
		s:=StringReplace(s, tmpStr, '', [rfIgnoreCase]);
	end;
	
	s:=StringReplace(s, '_', ' ', [rfReplaceAll,rfIgnoreCase]);
	
	Result := Trim(s);
	
	LogFunctionEnd;
end;

//=========================================================================
//  Gets a file from a filename.
//  Example usage:  f := FileByName('Weaponsmith Extended 2.esp');
//=========================================================================
function FileByName(const filename: string): IInterface;
var
	i: integer;
begin
	LogFunctionStart('FileByName');
	DebugLog('filename: ' + filename);
	
	Result := nil;
	for i := 0 to FileCount - 1 do begin
		//DebugLog(Format('Loop: %d - filename: %s', [i, GetFileName(FileByIndex(i))]));
		if GetFileName(FileByIndex(i)) = filename then begin
			Result := FileByIndex(i);
			// DebugLog(Format('Loop: %d - file found: filename: %s', [i, GetFileName(Result)]));
			break;
		end;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Gets the real cound of sub elements of this element
//  (since ElementCount does not work all the time)
//=========================================================================
function ElementCount2(const element: IInterface): Integer;
var
	recStr, tmpStr : String;
	totalCount, index : integer;
	masterRec : IInterface;
begin
	// LogFunctionStart('ElementCount2');
	Result := 0;

	while Assigned(ElementByIndex(element, Result)) do begin 
		inc(Result);
	end;
	
	// LogFunctionEnd;
end;

//=========================================================================
//  Gets the override index of a record within all overrides of the master of this record
//  returns -1 for the master itself 
//=========================================================================
function OverrideIndex(const rec: IInterface): Integer;
var
	recStr, tmpStr : String;
	totalCount, index : integer;
	masterRec : IInterface;
begin
	LogFunctionStart('OverrideIndex');
	Result := -1;

	if Assigned(rec) then begin 
		masterRec := MasterOrSelf(rec);
		totalCount := OverrideCount(masterRec);
		recStr := RecordToString(rec);
		
		// DebugLog(Format('totalCount: %d, recStr: %s',[totalCount, recStr]));
		
		index := 0;
		while index < totalCount do begin
			tmpStr := RecordToString(OverrideByIndex(masterRec, index));
			
			// DebugLog(Format('index: %d, tmpStr: %s',[index, tmpStr]));
			
			if SameText(tmpStr, recStr) then begin
				// DebugLog(Format('found: recStr: %s, tmpStr: %s',[recStr, tmpStr]));
				Result := index;
				break;
			end;
			inc(index);
		end;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
// returns the next override of this record
// (basically moves one column to the right if you look on a record with all its overrides on the xEdit user interface)
// if called on the master, returns the first override
// if called on the winning override, returns the record itself
// if called on the master and no override exists, returns the record itself
//=========================================================================
function NextOverride(const rec : IInterface) : IInterface;
var 
	tmpInt, elementCount : Integer;
	masterRec : IInterface;
begin
	// LogFunctionStart('NextOverride');
	
	Result := rec;
	
	tmpInt := OverrideIndex(rec);
	masterRec := MasterOrSelf(rec);
	elementCount := OverrideCount(masterRec);
	if elementCount > 0 then begin
		if tmpInt < (elementCount - 1) then begin 
			Result := OverrideByIndex(masterRec ,tmpInt + 1);
		end;
	end;
	
	// LogFunctionEnd;
end;

//=========================================================================
// returns the previous override of this record
// (basically moves one column to the left if you look on a record with all its overrides on the xEdit user interface)
// if called on the first override, returns the master record
// if called on the master record, returns the record itself
//=========================================================================
function PreviousOverride(const rec : IInterface) : IInterface;
var 
	tmpInt : Integer;
	masterRec : IInterface;
begin
	// LogFunctionStart('PreviousOverride');
	
	tmpInt := OverrideIndex(rec);
	masterRec := MasterOrSelf(rec);
	if tmpInt <= 0 then begin
		Result := masterRec;
	end else begin
		Result := OverrideByIndex(masterRec ,tmpInt - 1);
	end;
	
	// LogFunctionEnd;
end;

//=========================================================================
// returns the main record of this element or the element itself if it is a main record
// (just another method necessary, because an xEdit method does not work reliably - ContainingMainRecord() in this case)
//	does not work if the element is of type etFlag
//=========================================================================
function MainRecordOrSelf(const element : IInterface) : IInterface;
var 
	parentRec : IInterface;
begin
	// LogFunctionStart('MainRecordOrSelf');
	
	if ElementType(element) = etMainRecord then begin
		Result := element;
	end else begin 
		parentRec := ElementByPath(element, '..\');
		
		//DebugLog(Format('recordString from element: %s',[RecordToString(element)]));
		
		while Assigned(parentRec) do begin 
			//DebugLog(Format('parentRec-Path: %s',[Path(parentRec)]));
			if ElementType(parentRec) = etMainRecord then begin
				Result := parentRec;
				break;
			end;
			parentRec := ElementByPath(parentRec, '..\');
		end;
	end;
	
	if (not Assigned(Result)) and (not ElementType(element) = etFlag) then 
		Result := GetFile(element);
	
	// LogFunctionEnd;
end;

//=========================================================================
// returns the main record of this element or the element itself if it is a main record
// (expansion of MainRecordOrSelf for use with smartPathSelection)
//	handles etFlag elements correctly if they were selected by path
//=========================================================================
function MainRecordOrSelf2(const element, originalRecord : IInterface; const originalPath : String;) : IInterface;
var 
	tmpInt : Integer;
	curPath : String;
	parentRec : IInterface;
begin
	// LogFunctionStart('MainRecordOrSelf2');
	
	if ElementType(element) = etMainRecord then begin
		Result := element;
	end else begin
		if ElementType(element) = etFlag then begin
			//get the main flag element
			tmpInt := Pos('\', ReverseString(originalPath));
			curPath := Copy(originalPath, 1, Length(originalPath) - max(0, tmpInt));
			parentRec := ElementByPath(originalRecord, curPath);
			Result := MainRecordOrSelf(parentRec);
		end else begin
			Result := MainRecordOrSelf(element);
		end;
	end;
	
	// LogFunctionEnd;
end;


//=========================================================================
// gets all records that reference this record
//=========================================================================
procedure GetReferencedByRecords(const rec : IInterface; records : TStringList;);
var 
	i, elementCount : Integer;
	
begin
	LogFunctionStart('GetReferencedByRecords');
	
	records.Clear;
	
	elementCount := ReferencedByCount(rec);
	i := 0;
	while i < elementCount do begin
		records.Add(RecordToString(ReferencedByIndex(rec, i)));
		inc(i);
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
// gets all records that this record references
//=========================================================================
procedure GetReferencedRecords(const rec : IInterface; records : TStringList;);
var 
	i, tmpInt : Integer;
	tmpStr, curPath : String;
	allPaths, tmpList : TStringList;
	curElement : IInterface;
begin
	LogFunctionStart('GetReferencedRecords');
	
	allPaths := TStringList.Create;
	tmpList := TStringList.Create;
	tmpList.Sorted := true; //so that .Find() works
	records.Clear;
	
	try
		ResolveSmartPath(rec, '\**\', allPaths);
		
		i := 0;
		while i < allPaths.Count do begin 
			curPath := allPaths[i];
			tmpStr := Path(rec);
			tmpInt := Length(tmpStr);
			curElement := ElementByPath(rec, curPath);
			tmpStr := Path(curElement);
			tmpStr := Copy(tmpStr, tmpInt + 4, Length(tmpStr));
			
			if (not SameText(tmpStr,'Record Header \ FormID')) and Assigned(LinksTo(curElement)) then begin
				tmpStr := RecordToString(LinksTo(curElement));
				if not tmpList.Find(tmpStr, tmpInt) then begin 
					tmpList.Add(tmpStr); 
					records.Add(tmpStr); 
				end;
			end;
			inc(i);
		end;
		
	finally
		allPaths.Free;
		allPaths := nil;
		tmpList.Free;
		tmpList := nil;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
// Resolve Smart Path
//	this is an expansion of the path possibilities built into xEdit
//	modifies the TStringList provided and returns TRUE if the smartPath	contained elements to resolve
//=========================================================================
function ResolveSmartPath(const rec : IInterface; const smartPath : String; resolvedPaths : TStringList;) : Boolean;
var 
	i, j, tmpInt, elementCount, curPosWildcard, posWildcardInOrigPath : Integer;
	tmpStr, pathLeftToCheck, curPath, curPathBeforeSmartPart, curPathAfterSmartPart : String;
	curElement : IInterface;
	curNewPaths : TStringList;
begin
	LogFunctionStart('ResolveSmartPath');
	
	curNewPaths := TStringList.Create;
	resolvedPaths.Clear;
	Result := false;
	
	try
	
		//automatically resolve all entries of lists
		if Pos('[*]',smartPath) > 0 then begin
			Result := true;
			pathLeftToCheck := smartPath;
			resolvedPaths.Add(smartPath);
			
			posWildcardInOrigPath := Pos('[*]',pathLeftToCheck); //get the first one to resolve
			//resolve [*]
			while posWildcardInOrigPath > 0 do begin
				curNewPaths.Clear;
				
				for i := 0 to resolvedPaths.Count-1 do begin
					curPath := resolvedPaths[i];
					curPosWildcard := Pos('[*]',curPath); //needs to be re-evaluated, because if there are several [*], then a previous one could have changed the length of the path
					
					curPathBeforeSmartPart := Copy(curPath, 1, curPosWildcard-1);
					curPathAfterSmartPart := Copy(curPath, curPosWildcard + 3, Length(curPath) - curPosWildcard - 2);
					if Copy(curPathBeforeSmartPart,Length(curPathBeforeSmartPart),1) = '\' then
						curPathBeforeSmartPart := Copy(curPathBeforeSmartPart,1,Length(curPathBeforeSmartPart)-1);
					
					// DebugLog(Format('curPathBeforeSmartPart: %s',[curPathBeforeSmartPart]));
					
					if SameText(curPathBeforeSmartPart,'') then begin
						curElement := rec;
					end else begin
						curElement := ElementByPath(rec, curPathBeforeSmartPart);
					end;
					//unfortunately ElementCount() does not work -> find out by hand
					elementCount := ElementCount2(curElement);
					if elementCount = 0 then begin
						//this element does not have any elements -> try just leaving the wildcard out
						tmpStr := curPathBeforeSmartPart + curPathAfterSmartPart;
						curNewPaths.Add(tmpStr);
					end else begin
						for j := 0 to elementCount -1 do begin
							if SameText(curPathBeforeSmartPart,'') then begin
								tmpStr := Format('[%d]%s',[j, curPathAfterSmartPart]);
							end else begin
								tmpStr := Format('%s\[%d]%s',[curPathBeforeSmartPart, j, curPathAfterSmartPart]);
							end;
							curNewPaths.Add(tmpStr);
						end;
					end;
				end;
				
				//fill old batch of resolvedPaths with new Paths
				resolvedPaths.Clear;
				resolvedPaths.AddStrings(curNewPaths); //assuming this keeps the order
				// i := 0;
				// while i < curNewPaths.Count do begin
					// resolvedPaths.Add(curNewPaths[i]);
				// end;
				
				pathLeftToCheck := Copy(pathLeftToCheck, posWildcardInOrigPath + 3, Length(pathLeftToCheck) - posWildcardInOrigPath - 2);
				posWildcardInOrigPath := Pos('[*]',pathLeftToCheck); //get the next one to resolve
			end;
		end;
		
		//recursive resolving of all paths beyond this path
		if Pos('\*\',smartPath) > 0 then begin
			Result := true;
			pathLeftToCheck := smartPath;
			resolvedPaths.Add(smartPath);
			
			posWildcardInOrigPath := Pos('\*\',pathLeftToCheck); //get the first one to resolve
			
			//throw an error if there is more than one
			if Pos('\*\',Copy(pathLeftToCheck,posWildcardInOrigPath + 3, max(0, Length(pathLeftToCheck) - posWildcardInOrigPath - 2))) > 0 then 
				raise Exception.Create(Format('path contains the "\*\" wildcard multiple times. path: %s',[smartPath]));
			
			tmpStr := StringReplace(smartPath, '\*\', '\', [rfIgnoreCase]);
			resolvedPaths.Add(tmpStr);
			
			//resolve \*\
			while posWildcardInOrigPath > 0 do begin
				posWildcardInOrigPath := -1;
				curNewPaths.Clear;
				
				for i := 0 to resolvedPaths.Count-1 do begin
					curPath := resolvedPaths[i];
					curPosWildcard := Pos('\*\',curPath); 
					
					if curPosWildcard > 0 then begin 
						curPathBeforeSmartPart := Copy(curPath, 1, curPosWildcard-1);
						curPathAfterSmartPart := Copy(curPath, curPosWildcard + 3, Length(curPath) - curPosWildcard - 2);
						if Copy(curPathBeforeSmartPart,Length(curPathBeforeSmartPart),1) = '\' then
							curPathBeforeSmartPart := Copy(curPathBeforeSmartPart,1,Length(curPathBeforeSmartPart)-1);
						
						// DebugLog(Format('curPathBeforeSmartPart: %s',[curPathBeforeSmartPart]));
						
						if SameText(curPathBeforeSmartPart,'') then begin
							curElement := rec;
						end else begin
							curElement := ElementByPath(rec, curPathBeforeSmartPart);
						end;
						
						elementCount := ElementCount2(curElement);
						if elementCount = 0 then begin
							//this element does not have any elements -> try just leaving the wildcard out
							tmpStr := curPathBeforeSmartPart + '\' + curPathAfterSmartPart;
							curNewPaths.Add(tmpStr);
							// DebugLog(Format('does not have childs -> save path %s',[tmpStr]));
						end else begin
							posWildcardInOrigPath := 1;
							for j := 0 to elementCount -1 do begin
								if SameText(curPathBeforeSmartPart,'') then begin
									tmpStr := Format('[%d]\*\%s',[j, curPathAfterSmartPart]);
								end else begin
									tmpStr := Format('%s\[%d]\*\%s',[curPathBeforeSmartPart, j, curPathAfterSmartPart]);
								end;
								curNewPaths.Add(tmpStr);
							end;
						end;
					end else begin
						curNewPaths.Add(curPath);
					end;
				end;
				
				//fill old batch of resolvedPaths with new Paths
				resolvedPaths.Clear;
				resolvedPaths.AddStrings(curNewPaths); //assuming this keeps the order
				// i := 0;
				// while i < curNewPaths.Count do begin
					// resolvedPaths.Add(curNewPaths[i]);
				// end;
				
			end;
			
		end;
		
		//recursive resolving of all paths beyond this path including container elements (but without empty container elements)
		if Pos('\**\',smartPath) > 0 then begin
			Result := true;
			pathLeftToCheck := smartPath;
			resolvedPaths.Add(smartPath);
			
			posWildcardInOrigPath := Pos('\**\',pathLeftToCheck); //get the first one to resolve
			
			//throw an error if there is more than one
			if Pos('\**\',Copy(pathLeftToCheck,posWildcardInOrigPath + 4, max(0, Length(pathLeftToCheck) - posWildcardInOrigPath - 2))) > 0 then 
				raise Exception.Create(Format('path contains the "\**\" wildcard multiple times. path: %s',[smartPath]));
			
			tmpStr := StringReplace(smartPath, '\**\', '\', [rfIgnoreCase]);
			resolvedPaths.Add(tmpStr);
			
			//resolve \**\
			while posWildcardInOrigPath > 0 do begin
				posWildcardInOrigPath := -1;
				curNewPaths.Clear;
				
				for i := 0 to resolvedPaths.Count - 1 do begin
					curPath := resolvedPaths[i];
					curPosWildcard := Pos('\**\',curPath); 
					
					if curPosWildcard > 0 then begin 
						curPathBeforeSmartPart := Copy(curPath, 1, curPosWildcard - 1);
						curPathAfterSmartPart := Copy(curPath, curPosWildcard + 4, Length(curPath) - curPosWildcard - 3);
						if Copy(curPathBeforeSmartPart,Length(curPathBeforeSmartPart), 1) = '\' then
							curPathBeforeSmartPart := Copy(curPathBeforeSmartPart, 1, Length(curPathBeforeSmartPart) - 1);
						
						// DebugLog(Format('curPathBeforeSmartPart: %s',[curPathBeforeSmartPart]));
						
						if SameText(curPathBeforeSmartPart,'') then begin
							curElement := rec;
						end else begin
							curElement := ElementByPath(rec, curPathBeforeSmartPart);
						end;
						
						elementCount := ElementCount2(curElement);
						
						//always leave the current element without wildcard in the selection
						if not SameText(curPathBeforeSmartPart,'') then begin
							tmpStr := curPathBeforeSmartPart + '\' + curPathAfterSmartPart;
							curNewPaths.Add(tmpStr);
						end;
						
						if elementCount > 0 then begin
							posWildcardInOrigPath := 1;
							for j := 0 to elementCount -1 do begin
								if SameText(curPathBeforeSmartPart,'') then begin
									tmpStr := Format('[%d]\**\%s',[j, curPathAfterSmartPart]);
								end else begin
									tmpStr := Format('%s\[%d]\**\%s',[curPathBeforeSmartPart, j, curPathAfterSmartPart]);
								end;
								curNewPaths.Add(tmpStr);
							end;
						end;
					end else begin
						curNewPaths.Add(curPath);
					end;
				end;
				
				//fill old batch of resolvedPaths with new Paths
				resolvedPaths.Clear;
				resolvedPaths.AddStrings(curNewPaths); //assuming this keeps the order
				// i := 0;
				// while i < curNewPaths.Count do begin
					// resolvedPaths.Add(curNewPaths[i]);
				// end;
				
			end;
		end;
		
	finally
		curNewPaths.Free;
		curNewPaths := nil;
	end;
	
	// DebugLog(Format('resolved Paths: %s',[resolvedPaths.Text]));
	LogFunctionEnd;
end;

//=========================================================================
// Resolve Smart Record String
//	this is an expansion of the StringToRecord functionality in this lib
//	modifies the TStringList provided and returns TRUE if the smartRecordString	contained elements to resolve
//=========================================================================
function ResolveSmartRecordString(const smartRecordString : String; resolvedRecords : TStringList;) : Boolean;
var 
	i, j, tmpInt, elementCount, curPosWildcard : Integer;
	tmpStr, smartSelectionTag, curRecordStr, resultStr : String;
	curRecord : IInterface;
begin
	LogFunctionStart('ResolveSmartRecordString');
	
	resolvedRecords.Clear;
	Result := false;
	
	curRecordStr := smartRecordString;
	//get last path Part
	tmpStr := ReverseString(smartRecordString);
	tmpInt := Pos('\',tmpStr);
	
	if tmpInt > Pos(':',tmpStr) then //ignore if the backslash is before the last ":"
		tmpInt := -1;
	
	if tmpInt > 4 then begin //ignore if it ends with a backslash
		if tmpStr[1] = ']' then begin 
			if tmpStr[tmpInt-1] = '[' then begin 
				smartSelectionTag := ReverseString(Copy(tmpStr,1,tmpInt));
				curRecordStr := Copy(smartRecordString, 1, max(0, Length(smartRecordString) - Length(smartSelectionTag)));
			end;
		end;
	end;
	
	if not SameText(smartSelectionTag,'') then begin
		Result := true;
		// for i := 1 to 7 do begin //this is basically for avoiding deep IF-ELSE nesting
			// case i of 
				// 1:begin
						if SameText(smartSelectionTag, '\[Master]') then begin
							resultStr := '';
							curRecord := StringToRecord(curRecordStr);
							if Assigned (curRecord) then 
								resultStr := RecordToString(MasterOrSelf(curRecord));
							resolvedRecords.Add(resultStr);
							// break;
						end;
					// end;
				// 2:begin
						if SameText(smartSelectionTag, '\[WinningOverride]') then begin
							resultStr := '';
							curRecord := StringToRecord(curRecordStr);
							if Assigned (curRecord) then 
								resultStr := RecordToString(WinningOverride(curRecord));
							resolvedRecords.Add(resultStr);
							// break;
						end;
					// end;
				// 3:begin
						if SameText(smartSelectionTag, '\[NextOverride]') then begin
							curRecord := StringToRecord(curRecordStr);
							resultStr := RecordToString(NextOverride(curRecord));
							resolvedRecords.Add(resultStr);
							// break;
						end;
					// end;
				// 4:begin
						if SameText(smartSelectionTag, '\[PreviousOverride]') then begin
							curRecord := StringToRecord(curRecordStr);
							resultStr := RecordToString(PreviousOverride(curRecord));
							resolvedRecords.Add(resultStr);
							// break;
						end;
					// end;
				// 5:begin
						if SameText(smartSelectionTag, '\[ReferencedBy]') then begin
							curRecord := StringToRecord(curRecordStr);
							if Assigned(curRecord) then  
								GetReferencedByRecords(curRecord, resolvedRecords);
							//add empty entry so that the code does not break if there are no references
							if resolvedRecords.Count = 0 then 
								resolvedRecords.Add('');
							// break;
						end;
					// end;
				// 6:begin
						if SameText(smartSelectionTag, '\[References]') then begin
							curRecord := StringToRecord(curRecordStr);
							if Assigned(curRecord) then 
								GetReferencedRecords(curRecord, resolvedRecords);
							//add empty entry so that the code does not break if there are no references
							if resolvedRecords.Count = 0 then 
								resolvedRecords.Add('');
							// break;
						end;
					// end;
				// 7:raise Exception.Create(Format('Invalid smartSelector in record string. record String: %s, smartSelector: %s',[smartRecordString, smartSelectionTag]));
			// end; //end case
		// end; //end for
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
// gets different Infos from an element or record
//	this is an expansion of the path possibilities built into xEdit
//=========================================================================
function ElementInfoBySmartPath(const rec : IInterface; const smartPath : String;) : String;
var 
	i, tmpInt : Integer;
	tmpStr, curPath, smartSelectionTag, resultStr, curChar : String;
	curRecord, curElement, tmpElement : IInterface;
	defaultSelection : Boolean;
begin
	// LogFunctionStart('ElementInfoBySmartPath');

	defaultSelection := false;
	curPath := smartPath;
	
	//get last path Part
	tmpStr := ReverseString(smartPath);
	tmpInt := Pos('\',tmpStr);
	
	if tmpInt > 4 then begin //ignore if it ends with a backslash
		
		// DebugLog(Format('tmpStr[1]: %s, tmpStr[tmpInt-1]: %s, tmpStr[tmpInt-2]: %s',[tmpStr[1],tmpStr[tmpInt-1],tmpStr[tmpInt-2]]));
	
		if tmpStr[1] = ']' then begin 
			if tmpStr[tmpInt-1] = '[' then begin 
				curChar := tmpStr[tmpInt-2];
				if (curChar < '0') or (curChar > '9') then begin 
					smartSelectionTag := ReverseString(Copy(tmpStr,1,tmpInt));
					curPath := Copy(smartPath, 1, max(0, Length(smartPath) - Length(smartSelectionTag)));
				end;
			end;
		end;
	end;
	
	if SameText(curPath,'') then begin
		curElement := rec;
	end else begin
		curElement := ElementByPath(rec, curPath);
	end;
	
	if SameText(smartSelectionTag,'') then begin 
		defaultSelection := true;
	end else begin 
		//decide which selection should be done
		// for i := 1 to 25 do begin //this is basically for avoiding deep IF-ELSE nesting
			// case i of 
				// 1:begin
						if SameText(smartSelectionTag, '\[FormID]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							resultStr := IntToHex64(FormID(curRecord), 8);
							// break;
						end;
					// end;
				// 2:begin
						if SameText(smartSelectionTag, '\[IndentedName]') then begin
							if not (ElementType(curElement) = etMainRecord) then begin
								resultStr := Path(curElement);
								//count the depth of the path and prepare indention for each level
								//and remove the useless first part of the path 
								tmpInt := max(0, CountStringInString('\', resultStr, 1, -1) - 1); 
								resultStr := RepeatString('     ', tmpInt) + DisplayName(ElementByPath(rec, curPath));
							end;
							// break;
						end;
					// end;
				// 3:begin
						if SameText(smartSelectionTag, '\[Name]') then begin
							resultStr := DisplayName(ElementByPath(rec, curPath));
							// break;
						end;
					// end;
				// 4:begin
						if SameText(smartSelectionTag, '\[BaseName]') then begin
							resultStr := BaseName(ElementByPath(rec, curPath));
							// break;
						end;
					// end;
				// 5:begin
						if SameText(smartSelectionTag, '\[Path]') then begin
							if not (ElementType(curElement) = etMainRecord) then begin
								//remove the record part of the full path 
								resultStr := Path(curElement);
								tmpInt := max(0, Pos('\', resultStr));
								resultStr := Trimleft(Copy(resultStr, tmpInt + 1, Length(resultStr)));
							end;
							// break;
						end;
					// end;
				// 6:begin
						if SameText(smartSelectionTag, '\[PluginName]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							resultStr := GetFileName(curRecord);
							// break;
						end;
					// end;
				// 7:begin
						if SameText(smartSelectionTag, '\[Exists]') then begin
							if Assigned(curElement) then begin
								resultStr := 'true';
							end else begin
								resultStr := 'false';
							end;
							// break;
						end;
					// end;
				// 8:begin
						if SameText(smartSelectionTag, '\[ElementCount]') then begin
							resultStr := IntToStr(ElementCount2(curElement));
							// break;
						end;
					// end;
				// 9:begin
						if SameText(smartSelectionTag, '\[Index]') then begin
							tmpElement := ElementByPath(curElement, '..\');
							resultStr := IntToStr(IndexOf(tmpElement, curElement));
							// break;
						end;
					// end;
				// 10:begin
						if SameText(smartSelectionTag, '\[IndexedPath]') then begin
							if not (ElementType(curElement) = etMainRecord) then begin
								curRecord := MainRecordOrSelf2(curElement, rec, curPath);
								tmpStr := FullPath(curRecord); //to remove the useless first part of the path in a way that is compatible to cell records
								tmpInt := Length(tmpStr);
								tmpStr := FullPath(curElement);
								resultStr := Copy(tmpStr, tmpInt + 4, Length(tmpStr));
							end;
							// break;
						end;
					// end;
				// 11:begin
						if SameText(smartSelectionTag, '\[IsMaster]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							if Assigned(curRecord) then begin 
								if IsMaster(curRecord) then begin
									resultStr := 'true';
								end else begin
									resultStr := 'false';
								end;
							end;
							// break;
						end;
					// end;
				// 12:begin
						if SameText(smartSelectionTag, '\[Record]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							resultStr := RecordToString(curRecord);
							// break;
						end;
					// end;
				// 13:begin
						if SameText(smartSelectionTag, '\[IsWinningOverride]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							if Assigned(curRecord) then begin 
								if IsWinningOverride(curRecord) then begin
									resultStr := 'true';
								end else begin
									resultStr := 'false';
								end;
							end;
							// break;
						end;
					// end;
				// 14:begin
						if SameText(smartSelectionTag, '\[SortKey]') then begin
							resultStr := SortKey(curElement, True);
							// break;
						end;
					// end;
				// 15:begin
						if SameText(smartSelectionTag, '\[SelectionPath]') then begin
							resultStr := curPath;
							// break;
						end;
					// end;
				// 16:begin
						if SameText(smartSelectionTag, '\[OverrideCount]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							resultStr := OverrideCount(MasterOrSelf(curRecord));
							// break;
						end;
					// end;
				// 17:begin
						if SameText(smartSelectionTag, '\[OverrideIndex]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							resultStr := IntToStr(OverrideIndex(curRecord) + 1); //to make it easy for users of the formula-parser to understand
							// break;
						end;
					// end;
				// 18:begin
						if SameText(smartSelectionTag, '\[ReferencedByCount]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							resultStr := ReferencedByCount(curRecord);
							// break;
						end;
					// end;
				// 19:begin
						if SameText(smartSelectionTag, '\[Master]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							resultStr := RecordToString(MasterOrSelf(curRecord));
							// break;
						end;
					// end;
				// 20:begin
						if SameText(smartSelectionTag, '\[WinningOverride]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							resultStr := RecordToString(WinningOverride(curRecord));
							// break;
						end;
					// end;
				// 21:begin
						if SameText(smartSelectionTag, '\[NextOverride]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							resultStr := RecordToString(NextOverride(curRecord));
							// break;
						end;
					// end;
				// 22:begin
						if SameText(smartSelectionTag, '\[PreviousOverride]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							resultStr := RecordToString(PreviousOverride(curRecord));
							// break;
						end;
					// end;
				// 23:begin
						if SameText(smartSelectionTag, '\[RecordPath]') then begin
							curRecord := MainRecordOrSelf2(curElement, rec, curPath);
							resultStr := FullPath(curRecord);
							// break;
						end;
					// end;
				// 24:begin
						if SameText(smartSelectionTag, '\[EditValue]') then begin
							defaultSelection := true;
							// break;
						end;
					// end;
				// 25:raise Exception.Create(Format('Invalid smartSelector in path. path: %s, smartSelector: %s',[smartPath, smartSelectionTag]));
			// end; //end case
		// end; //end for
	end;
	
	// DebugLog(Format('curPath: %s, smartSelectionTag: %s, smartSelectionSwitch: %d',[curPath, smartSelectionTag, smartSelectionSwitch]));
	
	if defaultSelection then begin 
		tmpStr := Path(curElement);
		tmpInt := Length(tmpStr);
		if tmpInt > 22 then begin 
			tmpStr := Copy(tmpStr, tmpInt - 21, tmpInt);
		end;
		if (not SameText(tmpStr,'Record Header \ FormID')) and Assigned(LinksTo(curElement)) then begin
			resultStr := RecordToString(LinksTo(curElement)); 
		end else begin
			resultStr := GetEditValue(ElementByPath(rec, curPath));
		end;
	end;
	
	Result := resultStr;
	
	// LogFunctionEnd;
end;

//=========================================================================
//  Read information from records utilizing smartPaths and smartSelectors and return them as CSV formatted String
//=========================================================================
function ReadRecords(const recordsStr, pathsStr, emptyReturnValue, recordsDelimiter, elementsDelimiter : String;) : String;
var 	
	i, j, p, r  : Integer;
	tmpStr, resultStr, curPathStr, curRecordStr, curValueStr : String;
	records, paths, curResolvedPaths, curResolvedRecords : TStringList;
	curRecord : IInterface;
	curIsSmartPath, curIsSmartRecordString : Boolean;
begin
	LogFunctionStart('ReadRecords');
	
	//now resolve the two lists 
	records := TStringList.Create;
	paths := TStringList.Create;
	curResolvedPaths := TStringList.Create;
	curResolvedRecords := TStringList.Create;
	
	try
		StringToStringList(recordsStr, ';', records);
		StringToStringList(pathsStr, ';', paths);
		
		// DebugLog(Format('recordsStr: %s, pathsStr: %s, records.Count: %d, paths.Count: %d',[recordsStr, pathsStr, records.Count, paths.Count]));
		
		resultStr := '';
		i := 0;
		while i < records.Count do begin
			// DebugLog(Format('i: %d, records[i]: %s',[i, records[i]]));
			curRecordStr := records[i];
			curIsSmartRecordString := ResolveSmartRecordString(curRecordStr, curResolvedRecords);
			
			r := 0;
			repeat
				if curIsSmartRecordString then
					curRecordStr := curResolvedRecords[r];
						
				curRecord := StringToRecord(curRecordStr);
				
				if (i > 0) or (r > 0) then
					resultStr := resultStr + recordsDelimiter;
					
				j:= 0;
				while j < paths.Count do begin
					if j > 0 then
						resultStr := resultStr + elementsDelimiter;
					
					if Assigned(curRecord) then begin
						curPathStr := paths[j];
						curIsSmartPath := ResolveSmartPath(curRecord, curPathStr, curResolvedPaths);
						
						p := 0;
						repeat
							if curIsSmartPath then 
								curPathStr := curResolvedPaths[p];
							curValueStr := ElementInfoBySmartPath(curRecord, curPathStr);
							if p = 0 then begin
								tmpStr := EscapeStringIfNecessary(curValueStr, '"', recordsDelimiter, elementsDelimiter);
							end else begin
								tmpStr := tmpStr + elementsDelimiter + EscapeStringIfNecessary(curValueStr, '"', recordsDelimiter, elementsDelimiter);
							end;
							inc(p);
						until p >= curResolvedPaths.Count;
						
					end else begin 
						tmpStr := EscapeStringIfNecessary(emptyReturnValue, '"', recordsDelimiter, elementsDelimiter);
						// DebugLog('curRecord not assigned');
					end;
					
					resultStr := resultStr + tmpStr;
					
					inc(j);
				end;
				inc(r);
			until r >= curResolvedRecords.Count;
			
			inc(i);
		end;
	finally
		records.Free;
		records := nil;
		paths.Free;
		paths := nil;
		curResolvedPaths.Free;
		curResolvedPaths := nil;
		curResolvedRecords.Free;
		curResolvedRecords := nil;
	end;
	
	Result:=resultStr;
	
	LogFunctionEnd;
end;

//=========================================================================
//  check if any plugin already uses an EditorID
//=========================================================================
function EditorIdIsInUse(const edid: string;): Boolean;
var
	i,j : integer;
	tmpRec : IInterface;
	targetFile : IwbFile;
begin
	LogFunctionStart('EditorIdIsInUse');
	
	Result:=false;
	
	for i := 0 to FileCount - 1 do begin
		//DebugLog(Format('Searching "%s" in File "%s"',[edid, GetFileName(FileByIndex(i))]));
		targetFile := FileByIndex(i);
		for j := 0 to ElementCount(targetFile) - 1 do begin
			tmpRec := MainRecordByEditorID(ElementByIndex(targetFile,j),edid);
			if Assigned(tmpRec) then begin
				Result:=true;
				break;
			end;
		end;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Get unused EditorID
// 	adds a counter to the end of a suggested EditorID to return one that is not used yet
//=========================================================================
function GetUnusedEditorID(edid: string): String;
var
	i: integer;
begin
	LogFunctionStart('GetUnusedEditorID');
	
	for i := 0 to 10000 do begin
		if i > 0 then begin
			edid:=Format('%s_%d', [edid,i])
		end;
		
		if not EditorIdIsInUse(edid) then
			break;
	end;
	
	Result:=edid;
	LogFunctionEnd;
end;

//=========================================================================
//  process the dynamic naming rule (INNR) assigned to this weapon 
//  (considering keywords the weapon has in its basic form)
//	(returns true if the weapon name plays a role between prefixes and postfixes)
//=========================================================================
function ProcessDynamicNamingRules(w : IInterface; weaponKeywords, prefixes, postfixes : TStringList;) : Boolean;
var 
	i, j, k, tmpInt, keywordsCount : Integer;
	tmpStr, namePart, name : String;
	innrRec, rulesRec, namesRec, entry, keywordsRec : IInterface;
	found, postFixStarted : Boolean;
begin
	LogFunctionStart('ProcessDynamicNamingRules');
	
	postFixStarted := false;
	
	innrRec := WinningOverride(LinksTo(ElementByPath(w,'INRD')));
	rulesRec := ElementByName(innrRec, 'Naming Rules');
	for i := 0 to Pred(ElementCount(rulesRec)) do begin
		namesRec := ElementByName(ElementByIndex(rulesRec, i), 'Names');
		for j := 0 to Pred(ElementCount(namesRec)) do begin
			entry := ElementByIndex(namesRec, j);
			keywordsRec := ElementBySignature(entry, 'KWDA');
			found := true;
			keywordsCount := ElementCount(keywordsRec);
			
			if keywordsCount >= 1 then begin
				//check if name applies (i.e. all keywords are on the weapon)
				for k := 0 to (keywordsCount-1) do begin
					tmpStr := RecordMasterToString(LinksTo(ElementByIndex(keywordsRec, k)));
					if not weaponKeywords.Find(tmpStr,tmpInt) then begin
						found := false;
					end;
				end;
			end;
			
			if found then begin
				namePart := GetElementEditValues(entry, 'WNAM');
				if SameText('*',namePart) then begin
					postFixStarted := true;
				end else if postFixStarted then begin
					postfixes.Add(namePart);
					DebugLog(Format('INNR postfix: %s',[namePart]));
				end else begin
					prefixes.Add(namePart);
					DebugLog(Format('INNR prefix: %s',[namePart]));
				end;
				break; //move on to next ruleset
			end;
		end;	
	end;
	
	Result := postFixStarted;
	LogFunctionEnd;
end;

//=========================================================================
//  get name without parts that are added to the weapon name anyway throuth INNR
//=========================================================================
function GetNameWithoutRedundantNameParts(name : String; prefixes, postfixes : TStringList;) : String;
var 
	i, j, k, tmpInt, keywordsCount : Integer;
	tmpStr, newValue : String;
	rulesRec, namesRec, keywordsRec : IInterface;
	found, postFixStarted : Boolean;
begin
	LogFunctionStart('GetNameWithoutRedundantNameParts');
	
	newValue := Trimleft(name);
	
	//check if name starts with prefixes provided by INNR
	for i := 0 to prefixes.Count-1 do begin
		tmpStr := Trimleft(prefixes[i]);
		tmpInt := Pos(tmpStr,newValue);
		
		if tmpInt = 1 then begin //this is the start of the name
			newValue := Trimleft(Copy(newValue,tmpInt+Length(tmpStr),Length(newValue)-Length(tmpStr)));
		end;
	end;
	
	newValue := Trimright(newValue);
	//check if name ends with postfixes provided by INNR
	for i := (postfixes.Count-1) downto 0 do begin
		tmpStr := Trimright(postfixes[i]);
		tmpInt := Pos(tmpStr,newValue);
		
		//DebugLog(Format('newValue: "%s", tmpStr: "%s", tmpInt: %d, Length(tmpStr): %d, Length(newValue): %d',[newValue, tmpStr, tmpInt, Length(tmpStr),Length(newValue)]));
		
		if tmpInt >= 1 then begin
			if tmpInt + Length(tmpStr) -1 = Length(newValue) then begin //this is the end of the name
				newValue := Trimright(Copy(newValue,1,tmpInt-1));
			end;
		end;
	end;
	
	DebugLog(Format('name: "%s", name without redundant parts: "%s"',[name,newValue]));
	
	Result := newValue;
	LogFunctionEnd;
end;

//=========================================================================
//  get standard name without tags
//  (will return the name generated by its INNR, but without any parts that use brackets "{" or "[" or "(")
//=========================================================================
function GetStandardNameWithoutTags(name : String; prefixes, postfixes : TStringList;) : String;
var 
	i : Integer;
	tmpStr, newValue : String;
begin
	LogFunctionStart('GetStandardNameWithoutTags');
	
	newValue := Trimleft(name);
	
	//add prefixes that are no tags
	for i := 0 to prefixes.Count-1 do begin
		tmpStr := Trimleft(Trimright(prefixes[i]));
				
		if (Pos('{',tmpStr)<1) and (Pos('[',tmpStr)<1) and (Pos('(',tmpStr)<1) then begin 
			newValue := tmpStr + ' ' + newValue;
		end;
	end;
	
	newValue := Trimright(newValue);
	
	//add postfixes that are no tags
	for i := (postfixes.Count-1) downto 0 do begin
		tmpStr := Trimleft(Trimright(postfixes[i]));
		
		if (Pos('{',tmpStr)<1) and (Pos('[',tmpStr)<1) and (Pos('(',tmpStr)<1) then begin
			newValue := newValue + ' ' + tmpStr;
		end;
	end;
	
	DebugLog(Format('name: "%s", interpreted name: "%s"',[name, newValue]));
	Result := newValue;
	LogFunctionEnd;
end;

//=========================================================================
//  Gets all keywords a weapon uses in its main record and its combinations
//=========================================================================
procedure GetAllKeywordsOfThisWeapon(w : IInterface; keywords: TStringList;);
var 
	i, j : Integer;
	entries, combEntries, entry : IInterface;
	tmpStr : String;
begin
	LogFunctionStart('GetAllKeywordsOfThisWeapon');
	
	//main keywords
	entries := ElementBySignature(w, 'KWDA');
	for i := 0 to Pred(ElementCount(entries)) do begin
		entry := ElementByIndex(entries, i);
		tmpStr := RecordMasterToString(LinksTo(entry));
		DebugLog(Format('Keyword from main record: %s',[tmpStr]));
		keywords.Add(tmpStr); 
	end;
	
	//keywords in combinations
	entries := ElementByPath(w,'OBTE\Combinations');
	DebugLog(Format('number of combinations found: %d',[Pred(ElementCount(entries))+1]));
	if Assigned(entries) then begin
		for i := 0 to Pred(ElementCount(entries)) do begin
			combEntries := ElementByPath(ElementByIndex(entries, i),'OBTS\Keywords');
			DebugLog(Format('Loop: %d, number of keywords found in combinations: %d',[i,Pred(ElementCount(combEntries))+1]));
			if Assigned(combEntries) then begin
				for j := 0 to Pred(ElementCount(combEntries)) do begin
					entry := ElementByIndex(combEntries, j);
					tmpStr := RecordMasterToString(LinksTo(entry));
					DebugLog(Format('Keyword from Combination: %s',[tmpStr]));
					keywords.Add(tmpStr);
				end;
			end;
		end;
	end;
		
	LogFunctionEnd;
end;

//=========================================================================
//  Gets all attachment points a weapon uses in its main record 
//=========================================================================
procedure GetAllAttachPointsFromWeapon(w : IInterface; attachPoints: TStringList;);
var 
	i, j : Integer;
	entries : IInterface;
	tmpStr : String;
begin
	LogFunctionStart('GetAllAttachPointsFromWeapon');
	
	entries := ElementBySignature(w, 'APPR');
	for i := 0 to Pred(ElementCount(entries)) do begin
		tmpStr := RecordMasterToString(LinksTo(ElementByIndex(entries, i)));
		DebugLog(Format('Attach Point from main record: %s',[tmpStr]));
		attachPoints.Add(tmpStr); 
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Gets all mods this weapon can possibly use, according to keywords and attach points
// 	(recursive function)
//=========================================================================
procedure GetAllPossibleMods(attachPointsToCheck, weaponAttachPoints, weaponKeywords, newKeywordsFromMods, newAttachPointsFromMods, possibleMods, caliberMods: TStringList; recursionLevel : Integer);
const
	caliberAttachPoint = 'ap_Gun_Caliber[ArmorKeywords.esm]:KYWD';
var 
	i, j, k, refCount, tmpInt : Integer;
	curKeywordsCount, curKeywordsFound : Integer;
	curAttachPoint, curReferencingRec, curKeywords, curFlags : IInterface;
	tmpStr : String;
	curKeywordStr, curOMODStr : String;
	modAlreadyPresent, curModIsCaliberMod : Boolean;
	attachPointsAtTheStartOfThisRecursion, keywordsAtTheStartOfThisRecursion : Integer;
begin
	LogFunctionStart('GetAllPossibleMods');
	DebugLog(Format('Recursion Level: %d',[recursionLevel]));
	
	attachPointsAtTheStartOfThisRecursion := newAttachPointsFromMods.Count;
	keywordsAtTheStartOfThisRecursion := newKeywordsFromMods.Count;
	
	//find all loose mods applicable for this weapon
	//to do so, analyze the OMODs applicable for this weapon and follow them to the loose mods
	//to find the OMODs, follow each attach point of the weapon
	//(also follow each attac point added through a OMOD)	
	//consider each keyword of the weapon to check if an OMOD is applicable to this weapon
	//(also consider each keyword added into a combination of the weapon)
	//(also consider each keyword added by an OMOD applicable for the weapon)
	for i := 0 to attachPointsToCheck.Count-1 do begin
		tmpStr := attachPointsToCheck[i];
		curModIsCaliberMod := SameText(tmpStr,caliberAttachPoint);
		curAttachPoint := StringToRecord(tmpStr);
		refCount := ReferencedByCount(curAttachPoint);
		DebugLog(Format('Loop: %d, current attach point: %s, number of references to check: %d',[i,tmpStr,refCount]));
		
		//get all mods awailable for this attach point
		for j := 0 to refCount-1 do begin
			curReferencingRec := WinningOverride(ReferencedByIndex(curAttachPoint, j));
			
			if Signature(curReferencingRec) = 'OMOD' then begin
				curOMODStr := RecordMasterToString(curReferencingRec);
				
				//check if already added
				modAlreadyPresent := false;
				
				//if not modAlreadyPresent then begin
				if not possibleMods.Find(curOMODStr,tmpInt) then begin
					curKeywords := ElementByPath(curReferencingRec,'MNAM');
					curKeywordsFound := 0;
					curKeywordsCount := Pred(ElementCount(curKeywords))+1;
					
					//if this is a mod collection, strangely provided with keywords, skip it
					tmpStr := GetEditValue(ElementByPath(curReferencingRec,'Record Header\Record Flags\Mod Collection'));
					if not SameText(tmpStr,'1') then begin
						for k := 0 to curKeywordsCount-1 do begin
							//curKeyword := WinningOverride();
							curKeywordStr := RecordMasterToString(LinksTo(ElementByIndex(curKeywords,k)));
							
							if weaponKeywords.Find(curKeywordStr,tmpInt) then begin
								curKeywordsFound := curKeywordsFound + 1;
							end;
							
							if newKeywordsFromMods.Find(curKeywordStr,tmpInt) then begin
								curKeywordsFound := curKeywordsFound + 1;
							end;
							
							//if all keywords are given the OMOD fits to the weapon -> add it to list
							if curKeywordsFound = curKeywordsCount then 
							begin
								DebugLog(Format('Loop: %d, Inner Loop: %d, new fitting OMOD found: %s',[i,j,curOMODStr]));
								possibleMods.Add(curOMODStr);
								if curModIsCaliberMod then
									caliberMods.Add(curOMODStr);
								
								//from the mod added get info needed to find mods that can be added when this mod was added
								GetExtraAttachPointsAddedByOMOD(curReferencingRec, weaponAttachPoints, newAttachPointsFromMods);
								GetExtraKeywordsAddedByOMOD(curReferencingRec, weaponKeywords, newKeywordsFromMods);						
							end; 
						end; 
					end; 
				end; 
			end; 
		end; 
	end; 
	
	//if there were new attach points found: check the new attach points
	if newAttachPointsFromMods.Count > keywordsAtTheStartOfThisRecursion then begin
		GetAllPossibleMods(newAttachPointsFromMods, weaponAttachPoints, weaponKeywords, newKeywordsFromMods, newAttachPointsFromMods, possibleMods, caliberMods, recursionLevel+1);
	end;
	
	//if there were new keywords found: re-check the same attach points
	if newKeywordsFromMods.Count > keywordsAtTheStartOfThisRecursion then begin
		GetAllPossibleMods(attachPointsToCheck, weaponAttachPoints, weaponKeywords, newKeywordsFromMods, newAttachPointsFromMods, possibleMods, caliberMods, recursionLevel+1);
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  gets additional attach points that are not on the weapon record itself, but added through an OMOD
//=========================================================================
procedure GetExtraAttachPointsAddedByOMOD(omod : IInterface; weaponAttachPoints, newAttachPointsFromMods: TStringList;);
var 
	i, tmpInt : Integer;
	entries : IInterface;
	bAlreadyPresent : Boolean;
	tmpStr : String;
begin
	LogFunctionStart('GetExtraAttachPointsAddedByOMOD');
	
	entries := ElementByPath(omod,'Data - Data\Attach Parent Slots');
	DebugLog(Format('number of additional attach points found: %d',[Pred(ElementCount(entries))+1]));
	
	for i := 0 to Pred(ElementCount(entries)) do begin
		//TODO: if this attach point does exist on the weapon: output a warning
		tmpStr := RecordMasterToString(LinksTo(ElementByIndex(entries,i)));
		bAlreadyPresent:= false;
		
		//check if this attach point was already present in the weapon record itself		
		if weaponAttachPoints.Find(tmpStr,tmpInt) then begin
			bAlreadyPresent := true;
			//DebugLog(Format('attach point already present in weapon: %s',[tmpStr]));
		end;
		
		if not bAlreadyPresent then begin
			//check if this attach point is also added by another mod
			if newAttachPointsFromMods.Find(tmpStr,tmpInt) then begin
				bAlreadyPresent := true;
				//DebugLog(Format('attach point already added by another mod: %s',[tmpStr]));
			end;
		end;
		
		if not bAlreadyPresent then begin
			newAttachPointsFromMods.Add(tmpStr);
			DebugLog(Format('new attach point found added by mod: %s',[tmpStr]));
		end;
		
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  gets additional keywords that are not on the weapon record itself, but added through an OMOD
//=========================================================================
procedure GetExtraKeywordsAddedByOMOD(omod : IInterface; weaponKeywords, newKeywordsFromMods: TStringList;);
var 
	i, tmpInt : Integer;
	entries, entry : IInterface;
	bAlreadyPresent : Boolean;
	tmpStr : String;
begin
	LogFunctionStart('GetExtraKeywordsAddedByOMOD');
	
	entries := ElementByPath(omod,'Data - Data\Properties');
	DebugLog(Format('number of properties: %d',[Pred(ElementCount(entries))+1]));
	
	for i := 0 to Pred(ElementCount(entries)) do begin
		//TODO: if this keyword does already exist on the weapon: output a warning
		entry := ElementByIndex(entries,i);
		
		if SameText('ADD',GetElementEditValues(entry, 'Function Type')) 
			and SameText('Keywords',GetElementEditValues(entry, 'Property')) 
			and SameText('FormID,Int',GetElementEditValues(entry, 'Value Type')) then
		begin
			tmpStr := RecordMasterToString(LinksTo(ElementByPath(entry,'Value 1 - FormID')));
			
			bAlreadyPresent:= false;
		
			//check if this keyword was already present in the weapon record itself
			if weaponKeywords.Find(tmpStr,tmpInt) then begin
				bAlreadyPresent := true;
				//DebugLog(Format('keyword already present in weapon: %s',[tmpStr]));
			end;
			
			if not bAlreadyPresent then begin
				//check if this keyword is also added by another mod
				if newKeywordsFromMods.Find(tmpStr,tmpInt) then begin
					bAlreadyPresent := true;
					//DebugLog(Format('keyword already added by another mod: %s',[tmpStr]));
				end;
				
			end;
			
			if not bAlreadyPresent then begin
				newKeywordsFromMods.Add(tmpStr);
				DebugLog(Format('new keyword found added by mod: %s',[tmpStr]));
			end;
			
		end;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Get loose mods referenced by mods
//=========================================================================
procedure GetAllLooseMods(omods, loosemods : TStringList;);
var 
	i, j : Integer;
	looseModRec : IInterface;
	tmpStr : String;
begin
	LogFunctionStart('GetAllLooseMods');
	
	for i := 0 to omods.Count-1 do begin
		looseModRec := ElementBySignature(WinningOverride(StringToRecord(omods[i])),'LNAM');
		if Assigned(looseModRec) then begin
			tmpStr := RecordMasterToString(LinksTo(looseModRec));
			DebugLog(Format('Loose Mod found: %s',[tmpStr]));
			loosemods.Add(tmpStr); 
		end;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Get mod Recipes for OMOD
//=========================================================================
procedure GetModRecipes(omodRec : IInterface; modRecipes : TStringList;);
var 
	i, refCount, tmpInt : Integer;
	curReferencingRec : IInterface;
	tmpStr, curRecipeStr : String;
begin
	LogFunctionStart('GetModRecipes');
	
	modRecipes.Clear;
	
	tmpStr:=RecordMasterToString(omodRec);
	refCount := ReferencedByCount(omodRec);
	DebugLog(Format('current OMOD: %s, number of references to check: %d',[tmpStr,refCount]));
	
	//get Recipes awailable for this OMOD
	for i := 0 to refCount-1 do begin
		curReferencingRec := WinningOverride(ReferencedByIndex(omodRec, i));
		
		if Signature(curReferencingRec) = 'COBJ' then begin
			curRecipeStr := RecordMasterToString(curReferencingRec);
			
			//check if the winning override still points to the referenced record
			if SameText(tmpStr,RecordMasterToString(LinksTo(ElementBySignature(curReferencingRec, 'CNAM')))) then begin 
				//check if already added
				if not modRecipes.Find(curRecipeStr, tmpInt) then begin
					DebugLog(Format('Loop: %d, recipe found: %s',[i,curRecipeStr]));
					modRecipes.Add(curRecipeStr);
				end;
			end;
		end;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Get Recipes for the weapon itself
//=========================================================================
procedure GetWeaponRecipes(w : IInterface; weaponRecipes : TStringList;);
var 
	i, refCount, tmpInt : Integer;
	curReferencingRec : IInterface;
	tmpStr, curRecipeStr : String;
begin
	LogFunctionStart('GetWeaponRecipes');
	
	weaponRecipes.Clear;
	
	tmpStr:=RecordMasterToString(w);
	refCount := ReferencedByCount(w);
	
	//get Recipes awailable for this weapon
	for i := 0 to refCount-1 do begin
		curReferencingRec := WinningOverride(ReferencedByIndex(w, i));
		
		if Signature(curReferencingRec) = 'COBJ' then begin
			curRecipeStr := RecordMasterToString(curReferencingRec);
			
			//check if the winning override still points to the referenced record
			if SameText(tmpStr,RecordMasterToString(LinksTo(ElementBySignature(curReferencingRec, 'CNAM')))) then begin 
				//check if already added
				if not weaponRecipes.Find(curRecipeStr, tmpInt) then begin
					DebugLog(Format('Loop: %d, recipe found: %s',[i,curRecipeStr]));
					weaponRecipes.Add(curRecipeStr);
				end;
			end;
		end;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Get omods for loose mod from list of OMODs
//=========================================================================
procedure GetOmodsForLooseModFromList(looseModRec : IInterface; allOmods, omods : TStringList;);
var 
	i, refCount : Integer;
	curOmodRec : IInterface;
	tmpStr, curLooseModStr, curOmodStr : String;
begin
	LogFunctionStart('GetOmodsForLooseModFromList');
	
	omods.Clear;
	
	tmpStr:=RecordMasterToString(looseModRec);
	for i := 0 to allOmods.Count -1 do begin
		curOmodStr := allOmods[i];
		curOmodRec := WinningOverride(StringToRecord(curOmodStr));
		curLooseModStr := RecordMasterToString(LinksTo(ElementBySignature(curOmodRec,'LNAM')));
		if SameText(tmpStr,curLooseModStr) then begin
			omods.Add(curOmodStr);
		end;
	end;
		
	refCount := omods.Count;
	DebugLog(Format('current loose mod: %s, number of this weapon''s OMODs using it: %d',[tmpStr,refCount]));
		
	LogFunctionEnd;
end;

//=========================================================================
//  Get omods for loose mod from all plugins
//=========================================================================
procedure GetAllOmodsForLooseMod(looseModRec : IInterface; omods : TStringList;);
var 
	i, refCount, tmpInt : Integer;
	curOmodRec : IInterface;
	looseModStr, curLooseModStr, curOmodStr : String;
begin
	LogFunctionStart('GetAllOmodsForLooseMod');
	
	omods.Clear;
	looseModStr:=RecordMasterToString(looseModRec);
	refCount := ReferencedByCount(looseModRec);
	
	//get all mods using this loose mod
	for i := 0 to refCount-1 do begin
		curOmodRec := WinningOverride(ReferencedByIndex(looseModRec, i));
		//check if the reference was not overwritten by an override
		curLooseModStr := RecordMasterToString(LinksTo(ElementBySignature(curOmodRec,'LNAM')));
		if SameText(looseModStr, curLooseModStr) then begin
			curOmodStr := RecordMasterToString(curOmodRec);
			
			if not omods.Find(curOMODStr,tmpInt) then begin //not reported yet
				if Signature(curOmodRec) = 'OMOD' then begin
					omods.Add(curOmodStr);
				end;
			end;
		end;
	end;
		
	refCount := omods.Count;
	DebugLog(Format('current loose mod: %s, total number of OMODs using it: %d',[looseModStr,refCount]));
		
	LogFunctionEnd;
end;

//=========================================================================
//  Get all mod collections for OMODs of this weapon (recursive, supports Modcols in Modcols)
//=========================================================================
procedure GetAllModCollections(omods, allModcols  : TStringList; ignoreVanillaNullMuzzle : Boolean);
const 
	nullMuzzleToIgnore = 'mod_Null_Muzzle[Fallout4.esm]:OMOD';
var 
	i,j, refCount, tmpInt : Integer;
	omodRec, modColRec : IInterface;
	omodStr, tmpStr, modColStr : String;
begin
	LogFunctionStart('GetAllModCollections');
	
	//find mod collections directly using OMODs
	for i := 0 to omods.Count-1 do begin
		omodStr:=omods[i];
		if (ignoreVanillaNullMuzzle) and (SameText(omodStr,nullMuzzleToIgnore)) then
			continue;
		
		omodRec:=WinningOverride(StringToRecord(omodStr));
		refCount := ReferencedByCount(omodRec);
		
		for j := 0 to refCount-1 do begin
			modColRec:= WinningOverride(ReferencedByIndex(omodRec, j));
			
			if Signature(modColRec) = 'OMOD' then begin
				tmpStr := GetEditValue(ElementByPath(modColRec,'Record Header\Record Flags\Mod Collection'));
				if SameText(tmpStr,'1') then begin
					modColStr:= RecordMasterToString(modColRec);
					DebugLog(Format('OMOD is used by mod collection - OMOD: %s - ModCol: %s',[omodStr,modColStr]));
					if not allModcols.Find(modColStr,tmpInt) then begin
						allModcols.Add(modColStr);
					end;
				end;	
			end;
		end;
	end;
	
	//recursively find mod collections using mod collections
	GetModColsUsingModCols(allModcols, allModcols, 0);
	
	DebugLog('The following mod collections play a role for this weapon:');
	//log a list of all applicable modcols
	for i := 0 to allModcols.Count-1 do begin
		DebugLog(allModcols[i]);
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  add all mod collections that are only using other mod collections, not OMODs to the relevant mod collections
//  (recursive function)
//=========================================================================
procedure GetModColsUsingModCols(modcolsToCheck, allModcols  : TStringList; recursionLevel : Integer;);
var 
	i,j, refCount, tmpInt, newlyAddedInThisRecursion : Integer;
	modColToCheckRec, modColRec : IInterface;
	modColToCheckStr, tmpStr, modColStr : String;
	newlyAddedModcols : TStringList;
begin
	LogFunctionStart('GetModColsUsingModCols');
	newlyAddedModcols:=TStringList.Create;
	
	try
		DebugLog(Format('Recursion Level: %d',[recursionLevel]));
		newlyAddedInThisRecursion:= 0;
		
		//find mod collections directly using OMODs
		for i := 0 to modcolsToCheck.Count-1 do begin
			modColToCheckStr:=modcolsToCheck[i];
			modColToCheckRec:=WinningOverride(StringToRecord(modColToCheckStr));
			refCount := ReferencedByCount(modColToCheckRec);
			
			for j := 0 to refCount-1 do begin
				modColRec:= WinningOverride(ReferencedByIndex(modColToCheckRec, j));
				
				if Signature(modColRec) = 'OMOD' then begin
					tmpStr := GetEditValue(ElementByPath(modColRec,'Record Header\Record Flags\Mod Collection'));
					if SameText(tmpStr,'1') then begin
						modColStr:= RecordMasterToString(modColRec);
						DebugLog(Format('Mod collection is used by other mod collection - ModCol: %s - used by ModCol: %s',[modColToCheckStr,modColStr]));
						if not allModcols.Find(modColStr,tmpInt) then begin
							allModcols.Add(modColStr);
							newlyAddedModcols.Add(modColStr);
							newlyAddedInThisRecursion := newlyAddedInThisRecursion + 1;
						end;
					end;	
				end;
			end;
		end;
		
		//recursively call again if new mod collections were found
		if newlyAddedInThisRecursion > 0 then begin
			GetModColsUsingModCols(newlyAddedModcols, allModcols, recursionLevel+1);
		end;
		
	finally
		newlyAddedModcols.Free;
		newlyAddedModcols:=nil;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Get Attach Points with OMODs but without ModCols
//=========================================================================
procedure GetAttachPointsWithoutModCols(allOmods, allModcols : TStringList; includeAttachPointsWithOneOmod : bool; attachPoints : TStringList;);
var 
	i,j, refCount, tmpInt : Integer;
	omodRec, modColRec : IInterface;
	omodStr, tmpStr, modColStr, attachPointStr : String;
begin
	LogFunctionStart('GetAttachPointsWithoutModCols');
	
	for i := 0 to allOmods.Count-1 do begin
		omodStr:=allOmods[i];
		omodRec:=WinningOverride(StringToRecord(omodStr));
		attachPointStr := RecordMasterToString(LinksTo(ElementByPath(omodRec,'Data - Data\Attach Point')));
		
		if attachPoints.Find(attachPointStr,tmpInt) then
			continue;
		
		//check if there is a mod collection using this attach point
		refCount:=0;
		for j := 0 to allModcols.Count-1 do begin
			modColStr:=allModcols[j];
			modColRec:=WinningOverride(StringToRecord(modColStr));
			tmpStr := RecordMasterToString(LinksTo(ElementByPath(modColRec,'Data - Data\Attach Point')));
			if SameText(tmpStr,attachPointStr) then begin
				refCount:=refCount+1;
				break;
			end;
		end;
		
		if refCount<1 then
			continue;
		
		refCount:=0;
		if not includeAttachPointsWithOneOmod then begin
			//find number of omods for this attach point
			for j := 0 to allOmods.Count-1 do begin
				tmpStr := RecordMasterToString(LinksTo(ElementByPath(WinningOverride(StringToRecord(allOmods[j])),'Data - Data\Attach Point')));
				if SameText(tmpStr,attachPointStr) then
					refCount := refCount + 1;
			end;
		end;
		
		if includeAttachPointsWithOneOmod or (refCount>1) then begin
			attachPoints.Add(attachPointStr);
		end;
	end;	
	
	LogFunctionEnd;
end;

//=========================================================================
//  Get mods for an attach point from a list of OMODs or ModCols
//=========================================================================
procedure GetModsForAttachPoint(attachPointStr : String; modsToCheck, mods : TStringList;);
var 
	i : Integer;
	tmpRec : IInterface;
	modStr, tmpStr : String;
begin
	LogFunctionStart('GetModsForAttachPoint');
	
	for i := 0 to modsToCheck.Count-1 do begin
		modStr:=modsToCheck[i];
		tmpRec:=WinningOverride(StringToRecord(modStr));
		tmpStr := RecordMasterToString(LinksTo(ElementByPath(tmpRec,'Data - Data\Attach Point')));
		if SameText(tmpStr,attachPointStr) then begin
			mods.Add(modStr);
		end;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Add all Masters that would be needed for a record if necessary
//=========================================================================
function AddMastersIfMissing(rec : TwbContainer; targetFile : IInterface; silentlyAddMasters : Boolean; addedMasters : TStringList;) : Boolean;
var
	masterIndex, mr, i, j, tmpInt : integer;
	requMasterStr, targetFileName : string;
	requiredMasterList: TStringList;
	curElement : IInterface;
begin
	LogFunctionStart('AddMastersIfMissing');
	
	requiredMasterList:=TStringList.Create;
	requiredMasterList.Sorted := true;
	Result:=true;
	
	try
		targetFileName:= GetFileName(targetFile);
		
		ReportRequiredMasters(rec, requiredMasterList, true, false);
		
		//addtionally check elements of record (else a reference to another main record created in the same file as the winning override would be missed)
		if (Name(ElementByIndex(rec, 0)) = 'Cell') or (Name(ElementByIndex(rec, 0)) = 'Topic') then j := 2 else j := 1;
		for i := j to Pred(ElementCount(rec)) do begin
			curElement := ElementByIndex(rec, i);
			ReportRequiredMasters(curElement, requiredMasterList, False, True);
		end;
		
		for i := 0 to requiredMasterList.Count-1 do begin 
			DebugLog(Format('master necessary: %s',[requiredMasterList[i]]));
		end;
		
		//checking the origin of the record itself
		if not requiredMasterList.Find(GetFileName(GetFile(rec)),tmpInt) then begin
			requiredMasterList.Add(GetFileName(GetFile(rec)));
		end;
				
		if requiredMasterList.Count=0 then begin
			DebugLog('no additional master necessary');
			
		end;
		
		for masterIndex := 0 to requiredMasterList.Count-1 do begin
			requMasterStr := requiredMasterList[masterIndex];
			if not HasMaster(targetFile, requMasterStr) then begin
				if not silentlyAddMasters then begin
					mr := MessageDlg('Add ' + requMasterStr + ' as master to file ' + targetFileName +'?', mtConfirmation, [mbYes, mbAbort], 0);
					if mr = mrYes then begin
						AddMasterIfMissing(targetFile, requMasterStr);
						addedMasters.Add(requMasterStr);
						Log(Format('%s added as master to file %s',[requMasterStr,targetFileName]));
					end else if mr = mrAbort then begin
						Result:=false;
						Log(Format('Aborted by user when asked to add %s as master to file %s',[requMasterStr,targetFileName]));
						break;
					end
				end else begin
					AddMasterIfMissing(targetFile, requMasterStr);
					addedMasters.Add(requMasterStr);
					Log(Format('%s added as master to file %s',[requMasterStr,targetFileName]));
				end;
			end else begin 
				DebugLog(Format('%s is already a master to file %s',[requMasterStr,targetFileName]));
			end;
		end;
	
	finally
		requiredMasterList.Free;
		requiredMasterList:=nil;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Add a keyword to a weapon
//=========================================================================
function AddKeywordToWeapon(w : IInterface; keywordStr: String; silentlyAddMasters : Boolean; addedMasters : TStringList;) : Boolean;
var 
	i, j : Integer;
	entries, keywordRecord, newEntry : IInterface;
	targetFile : IInterface;
	tmpStr, targetFileName : String;
begin
	LogFunctionStart('AddKeywordToWeapon');
	
	Result := true;
	keywordRecord:=StringToRecord(keywordStr);
	targetFile:= GetFile(w);
	targetFileName:=GetFileName(targetFile);
	
	//Add master for new entry
	if not AddMastersIfMissing(keywordRecord, targetFile, silentlyAddMasters, addedMasters) then begin //do not call with MasterOrSelf(), because the overrides could require additional masters according to their elements
		Result := false;
	end else begin 
		//add keyword
		entries := ElementBySignature(w, 'KWDA');
		newEntry := ElementAssign(entries, HighInteger, nil, False);
		SetEditValue(newEntry, HexFormID(keywordRecord));
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Remove a keyword to a weapon
//=========================================================================
procedure RemoveKeywordFromWeapon(w : IInterface; keywordStr: String;);
var 
	i, j : Integer;
	entries, entry : IInterface;
	targetFile : IInterface;
	tmpStr, targetFileName : String;
begin
	LogFunctionStart('RemoveKeywordFromWeapon');
	
	entries := ElementBySignature(w, 'KWDA');
	for i := 0 to Pred(ElementCount(entries)) do begin
		entry := ElementByIndex(entries, i);
		tmpStr := RecordMasterToString(LinksTo(entry));
		if SameText(tmpStr,keywordStr) then begin
			Remove(entry);
		end;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  checks if the record is in the specified file, if not, creates an override in that file
// 	(call using WinningOverride!)
//=========================================================================
function CreateOverrideInFileIfNotExists(rec : IInterface; targetFile : IwbFile; addedRecords, addedMasters : TStringList; silentlyAddMasters : Boolean;) : Boolean;
var 
	newRec : IInterface;
	tmpStr, targetFileName : String;
begin
	LogFunctionStart('CreateOverrideInFileIfNotExists');
	
	Result := true;
	tmpStr:= RecordMasterToString(rec);
	targetFileName:=GetFileName(targetFile);
	DebugLog(Format('record: %s, target file: %s',[tmpStr,targetFileName]));
		
	if Equals(GetFile(rec), targetFile) then begin 
		DebugLog(Format('override for record %s is already present in file %s',[tmpStr,targetFileName]));
	end else begin 
		if not AddMastersIfMissing(rec, targetFile, silentlyAddMasters, addedMasters) then begin //do not call with MasterOrSelf(), because the overrides could require additional masters according to their elements
			Result := false;
		end else begin 
			newRec := wbCopyElementToFile(rec, targetFile, false, true{deep copy});
			addedRecords.Add(tmpStr);
		end;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  creates an copy in that file, adding necessary masters
// 	(call using WinningOverride!)
//=========================================================================
function CreateCopyInFile(rec : IInterface; targetFile : IwbFile; addedMasters : TStringList; silentlyAddMasters : Boolean;) : IInterface;
var 
	tmpStr, targetFileName : String;
begin
	LogFunctionStart('CreateCopyInFile');
	Result:=nil;
	
	tmpStr:= RecordMasterToString(rec);
	targetFileName:=GetFileName(targetFile);
	DebugLog(Format('record: %s, target file: %s',[tmpStr,targetFileName]));
		
	if not AddMastersIfMissing(rec, targetFile, silentlyAddMasters, addedMasters) then begin //do not call with MasterOrSelf(), because the overrides could require additional masters according to their elements
		DebugLog('adding master aborted by user');
	end else begin 
		Result := wbCopyElementToFile(rec, targetFile, true, true{deep copy});
	end;

	LogFunctionEnd;
end;

//=========================================================================
//  Sets values of an empty, newly added loose mod according to its OMOD record
//=========================================================================
procedure SetValuesForNewLooseMod(looseModRec, omodRec, w : IInterface; targetFile : IwbFile; addedMasters : TStringList; weaponName : String);
const
	standardModTransform = 'MiscMod02[Fallout4.esm]:TRNS';
	standardModNif = 'Props\ModsPartbox\ModBox.nif';
	standardModKeyword = 'ObjectTypeLooseMod[Fallout4.esm]:KYWD';
	standardModValue = '39';
var 
	tmpRec : IInterface;
	omodName, newName, newEdId : String;
begin
	LogFunctionStart('SetValuesForNewLooseMod');
	
	//add base .ESM if it is no master yet (no idea if this is possible)
	if not HasMaster(targetFile,'Fallout4.esm') then begin
		AddMasterIfMissing(targetFile,'Fallout4.esm',false);
		addedMasters.ADD(RecordMasterToString(FileByName('Fallout4.esm')));
	end;
	
	//Set basic Values
	SetElementEditValues(looseModRec, 'OBND\X1', '-8');
	SetElementEditValues(looseModRec, 'OBND\Y1', '-6');
	//SetElementEditValues(looseModRec, 'OBND\Z1', '0'); 
	SetElementEditValues(looseModRec, 'OBND\X2', '8');
	SetElementEditValues(looseModRec, 'OBND\Y2', '7');
	SetElementEditValues(looseModRec, 'OBND\Z2', '7');
	SetElementEditValues(looseModRec, 'PTRN', HexFormID(StringToRecord(standardModTransform)));
	tmpRec:= Add(looseModRec, 'Model', True);
	SetElementEditValues(tmpRec, 'MODL', standardModNif);
	tmpRec:= Add(looseModRec, 'KWDA', True);
	tmpRec := ElementAssign(tmpRec, HighInteger, nil, False);
	SetEditValue(tmpRec, HexFormID(StringToRecord(standardModKeyword)));
	SetElementEditValues(looseModRec, 'DATA\Value', standardModValue);
	//SetElementEditValues(looseModRec, 'DATA\Weight', '0');
	
	//get new EditorID and full name
	newEdId := GetUnusedEditorID('miscmod_'+EditorID(omodRec));
	omodName := GetElementEditValues(omodRec, 'FULL');
	if not SameText(omodName,'') then
		newName := '{Mod} ' + weaponName + ' ' + omodName
	else
		newName := '{Mod} '+StringReplace(StringReplace(StringReplace(StringReplace(newEdId, 'misc_mod_', '', [rfIgnoreCase]), 'miscmod_', '', [rfIgnoreCase]), 'mod_', '', [rfIgnoreCase]), '_', ' ', [rfReplaceAll, rfIgnoreCase]);
	
	//set EditorID and Name based on OMOD
	SetElementEditValues(looseModRec, 'EDID', newEdId);
	SetElementEditValues(looseModRec, 'FULL', newName);
	
	LogFunctionEnd;
end;

//=========================================================================
//  Sets values of an empty, newly added mod collection according to an attach point and add OMOD references
//=========================================================================
procedure SetValuesForNewModCol(modColRec, w : IInterface; targetFile : IwbFile; omods, addedMasters : TStringList; weaponName, attachPointStr : String; silentlyAddMasters : Boolean;);
var 
	i : Integer;
	tmpRec, dataRec, attachPointRec, includesRec, omodRec : IInterface;
	newEdId : String;
begin
	LogFunctionStart('SetValuesForNewModCol');
	
	attachPointRec := StringToRecord(attachPointStr);
	
	//Set Flag
	SetElementEditValues(modColRec, 'Record Header\Record Flags\Mod Collection', '1');	
		
	//add masters for attach point if needed
	if not Equals(GetFile(attachPointRec), targetFile) then begin 
		if not AddMastersIfMissing(attachPointRec, targetFile, silentlyAddMasters, addedMasters) then begin //do not call with MasterOrSelf(), because the overrides could require additional masters according to their elements
			Exit;
		end;
	end;
	
	//create DATA sub-record and set attach point
	dataRec:= Add(modColRec, 'DATA', True);
	SetElementEditValues(dataRec, 'Attach Point', HexFormID(attachPointRec));
	
	//add masters for all OMODs needed
	for i := 0 to omods.Count-1 do begin
		omodRec := StringToRecord(omods[i]);
		if not Equals(GetFile(omodRec), targetFile) then begin 
			if not AddMastersIfMissing(omodRec, targetFile, silentlyAddMasters, addedMasters) then begin //do not call with MasterOrSelf(), because the overrides could require additional masters according to their elements
				Exit;
			end;
		end;
	end;
	
	//add omods to mod collection
	for i := 0 to omods.Count-1 do begin
		includesRec:= ElementByName(dataRec, 'Includes');
		tmpRec := ElementAssign(includesRec, HighInteger, nil, False);
		SetElementEditValues(tmpRec, 'Don''t Use All', 'True');
		SetElementEditValues(tmpRec, 'Mod', HexFormID(StringToRecord(omods[i])));
	end;
	
	//get new EditorID based on attach point and gun
	newEdId := GetUnusedEditorID('modcol_' + weaponName + StringReplace(StringReplace(EditorID(attachPointRec),'ap_gun_','', [rfIgnoreCase]),'ap_','', [rfIgnoreCase]));	
	//set EditorID 
	SetElementEditValues(modColRec, 'EDID', newEdId);
	
	LogFunctionEnd;
end;

//=========================================================================
//  Sets values of an empty, newly added mod recipe according to its OMOD record
//=========================================================================
procedure SetValuesForNewModRecipe(modRecipeRec, omodRec : IInterface; targetFile : IwbFile; addedMasters : TStringList;);
const
	componentAluminum = 'c_Aluminum[Fallout4.esm]:CMPO';
	componentAdhesive = 'c_Adhesive[Fallout4.esm]:CMPO';
	componentGears = 'c_Gears[Fallout4.esm]:CMPO';
	componentOil = 'c_Oil[Fallout4.esm]:CMPO';
	componentSprings = 'c_Springs[Fallout4.esm]:CMPO';
	componentScrews = 'c_Screws[Fallout4.esm]:CMPO';
var 
	tmpRec, tmpFVPARec : IInterface;
begin
	LogFunctionStart('SetValuesForNewModRecipe');
	
	//add base .ESM if it is no master yet (no idea if this is possible)
	if not HasMaster(targetFile,'Fallout4.esm') then begin
		AddMasterIfMissing(targetFile,'Fallout4.esm',false);
		addedMasters.ADD(RecordMasterToString(FileByName('Fallout4.esm')));
	end;
	
	//Set basic Values
	tmpRec:= Add(modRecipeRec, 'INTV', True);
	SetElementEditValues(tmpRec, 'Created Object Count', '1');
	
	//set recipe
	tmpFVPARec:= Add(modRecipeRec, 'FVPA', True);
	tmpRec := ElementAssign(tmpFVPARec, HighInteger, nil, False);
	SetElementEditValues(tmpRec, 'Component', HexFormID(StringToRecord(componentAluminum)));
	SetElementEditValues(tmpRec, 'Count', '5');
	tmpRec := ElementAssign(tmpFVPARec, HighInteger, nil, False);
	SetElementEditValues(tmpRec, 'Component', HexFormID(StringToRecord(componentAdhesive)));
	SetElementEditValues(tmpRec, 'Count', '5');
	tmpRec := ElementAssign(tmpFVPARec, HighInteger, nil, False);
	SetElementEditValues(tmpRec, 'Component', HexFormID(StringToRecord(componentGears)));
	SetElementEditValues(tmpRec, 'Count', '5');
	tmpRec := ElementAssign(tmpFVPARec, HighInteger, nil, False);
	SetElementEditValues(tmpRec, 'Component', HexFormID(StringToRecord(componentOil)));
	SetElementEditValues(tmpRec, 'Count', '5');
	tmpRec := ElementAssign(tmpFVPARec, HighInteger, nil, False);
	SetElementEditValues(tmpRec, 'Component', HexFormID(StringToRecord(componentSprings)));
	SetElementEditValues(tmpRec, 'Count', '5');
	tmpRec := ElementAssign(tmpFVPARec, HighInteger, nil, False);
	SetElementEditValues(tmpRec, 'Component', HexFormID(StringToRecord(componentScrews)));
	SetElementEditValues(tmpRec, 'Count', '5');
		
	//set EditorID and OMOD based on OMOD
	SetElementEditValues(modRecipeRec, 'EDID', GetUnusedEditorID('co_'+EditorID(omodRec)));
	SetElementEditValues(modRecipeRec, 'CNAM', HexFormID(omodRec));
	
	LogFunctionEnd;
end;

//=========================================================================
//  Sets values of an empty, newly added weapon recipe according to its weapon record
//=========================================================================
procedure SetValuesForNewWeaponRecipe(recipeRec, w : IInterface; targetFile : IwbFile; addedMasters : TStringList; workbenchStr, workbenchCatStr : String;);
const
	componentAluminum = 'c_Aluminum[Fallout4.esm]:CMPO';
	componentAdhesive = 'c_Adhesive[Fallout4.esm]:CMPO';
	componentGears = 'c_Gears[Fallout4.esm]:CMPO';
	componentOil = 'c_Oil[Fallout4.esm]:CMPO';
	componentSprings = 'c_Springs[Fallout4.esm]:CMPO';
	componentScrews = 'c_Screws[Fallout4.esm]:CMPO';
var 
	tmpRec, tmpFVPARec : IInterface;
begin
	LogFunctionStart('SetValuesForNewWeaponRecipe');
	
	//add base .ESM if it is no master yet (no idea if this is possible)
	if not HasMaster(targetFile,'Fallout4.esm') then begin
		AddMasterIfMissing(targetFile,'Fallout4.esm',false);
		addedMasters.ADD(RecordMasterToString(FileByName('Fallout4.esm')));
	end;
	
	//Set basic Values
	tmpRec:= Add(recipeRec, 'INTV', True);
	SetElementEditValues(tmpRec, 'Created Object Count', '1');
	
	//set recipe
	tmpFVPARec:= Add(recipeRec, 'FVPA', True);
	tmpRec := ElementAssign(tmpFVPARec, HighInteger, nil, False);
	SetElementEditValues(tmpRec, 'Component', HexFormID(StringToRecord(componentAluminum)));
	SetElementEditValues(tmpRec, 'Count', '5');
	tmpRec := ElementAssign(tmpFVPARec, HighInteger, nil, False);
	SetElementEditValues(tmpRec, 'Component', HexFormID(StringToRecord(componentAdhesive)));
	SetElementEditValues(tmpRec, 'Count', '5');
	tmpRec := ElementAssign(tmpFVPARec, HighInteger, nil, False);
	SetElementEditValues(tmpRec, 'Component', HexFormID(StringToRecord(componentGears)));
	SetElementEditValues(tmpRec, 'Count', '5');
	tmpRec := ElementAssign(tmpFVPARec, HighInteger, nil, False);
	SetElementEditValues(tmpRec, 'Component', HexFormID(StringToRecord(componentOil)));
	SetElementEditValues(tmpRec, 'Count', '5');
	tmpRec := ElementAssign(tmpFVPARec, HighInteger, nil, False);
	SetElementEditValues(tmpRec, 'Component', HexFormID(StringToRecord(componentSprings)));
	SetElementEditValues(tmpRec, 'Count', '5');
	tmpRec := ElementAssign(tmpFVPARec, HighInteger, nil, False);
	SetElementEditValues(tmpRec, 'Component', HexFormID(StringToRecord(componentScrews)));
	SetElementEditValues(tmpRec, 'Count', '5');
		
	//set EditorID and weapon based on weapon
	SetElementEditValues(recipeRec, 'EDID', GetUnusedEditorID('co_'+EditorID(w)+'_Recipe'));
	SetElementEditValues(recipeRec, 'CNAM', HexFormID(w));
	
	//set workbench and category
	SetElementEditValues(recipeRec, 'BNAM', HexFormID(StringToRecord(workbenchStr)));
	tmpRec := Add(recipeRec, 'FNAM', True);
	tmpRec := ElementAssign(tmpRec, HighInteger, nil, False);
	SetEditValue(tmpRec, HexFormID(StringToRecord(workbenchCatStr)));
	
	LogFunctionEnd;
end;



end.
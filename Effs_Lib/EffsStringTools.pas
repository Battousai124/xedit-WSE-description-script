unit EffsStringTools;

// This unit only contains static string functions, no variables
// (it requires EffsDebugLog being loaded)

implementation

//=========================================================================
//  Helper Function that reverses a string
//=========================================================================
function ReverseString(const s: string): string;
var
	i: integer;
begin
	Result := '';
	for i := Length(s) downto 1 do begin
		Result := Result + Copy(s, i, 1);
	end;
end;

//=========================================================================
//  get name without hardcoded tags 
//	basically gets rid of everything in brackets and removes single brackets if present
// 	(recursive function)
//=========================================================================
function GetNameWithoutTags(name : string; recursionLevel : Integer) : String;
var 
	i,j : Integer;
	tmpStr : String;
begin
	LogFunctionStart('GetNameWithoutTags');
	DebugLog(Format('Recursion Level: %d',[recursionLevel]));
	
	tmpStr := name;
	
	i := Pos('[',name);
	j := Pos(']',name);
	if (i <= 0) or (j <= 0) then begin
		i := Pos('{',name);
		j := Pos('}',name);
	end;
	if (i <= 0) or (j <= 0) then begin
		i := Pos('(',name);
		j := Pos(')',name);
	end;
	
	if (i > 0) and (j > 0) then begin 
		//get rid of complete tag
		tmpStr := Trimleft(TrimRight(Copy(name,j+2,Length(name)-j-1)));
		
		//remove further tags
		tmpStr := GetNameWithoutTags(tmpStr,recursionLevel+1);
	end;
	
	if recursionLevel = 0 then begin
		//get rid of single brackets
		tmpStr := StringReplace(StringReplace(StringReplace(tmpStr, '[', '', [rfIgnoreCase]), '{', '', [rfIgnoreCase]), '(', '', [rfIgnoreCase]);
		tmpStr := StringReplace(StringReplace(StringReplace(tmpStr, ']', '', [rfIgnoreCase]), '}', '', [rfIgnoreCase]), ')', '', [rfIgnoreCase]);
		
		DebugLog(Format('name: "%s", name without tags: "%s"',[name, tmpStr]));
	end;	
	
	Result := tmpStr;
	
	//old:
	//Result := name;
	//
	//i := Pos('[',name);
	//j := Pos(']',name);
	//if (i <= 0) or (i >= 5) or (j <= 0) then begin
	//	i := Pos('{',name);
	//	j := Pos('}',name);
	//end;
	//
	//if (i > 0) and (i < 5) and (j > 0) then begin //the "i<5" is checked so that brackets at the end of the name are ignored
	//	Result := Trimleft(Copy(name,j+2,Length(name)-j-1));
	//end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Read string to TStringList
// 	(we assume that everything is correctly escaped -> no extra escaping in here)
//=========================================================================
procedure StringToStringList(const strValue, delimiter : String; results : TStringList;);
var 	
	lengthStr, curPos, endPos, lengthDelim, nextStringPos, nextDelimiterPos, nextInterestingPos  : Integer;
	tmpStr : String;
begin
	LogFunctionStart('StringToStringList');
	//unfortunately we have to fill them manually, since PASCAL is not escaping properly with DelimitedText
		
	results.Clear;
	
	lengthStr := Length(strValue);
	lengthDelim := Length(delimiter); //for delimiters longer than 1 char
	tmpStr := '';
	curPos := 1;
	while curPos <= lengthStr do begin
		//(reading ahead with Pos() is way faster than iterating throug every character - mainly interesting for large CSV-Tables with many)
		nextStringPos := Pos('"',Copy(strValue,curPos,lengthStr));
		nextDelimiterPos := Pos(delimiter,Copy(strValue,curPos,lengthStr));
		nextInterestingPos := max(nextStringPos,0);
		if (nextInterestingPos < 1) or (nextInterestingPos > nextDelimiterPos) then
			nextInterestingPos := max(nextDelimiterPos,0);
		
		case nextInterestingPos of 
			0: begin
					//the rest is simply the last field
					tmpStr := tmpStr + Copy(strValue,curPos, lengthStr);
					results.Add(tmpStr);
					curPos := lengthStr;
					// DebugLog(Format('case 0 - tmpStr: %s',[tmpStr]));
				end;
			nextStringPos: begin
					endPos := GetEndOfEscapedString(strValue, curPos + nextInterestingPos);
					tmpStr := tmpStr + Copy(strValue,curPos,endPos-curPos + 1);
					if endPos = lengthStr then 
						results.Add(tmpStr);
					curPos := endPos;
					// DebugLog(Format('case string - tmpStr: %s',[tmpStr]));
				end;
			nextDelimiterPos: begin
					tmpStr := tmpStr + Copy(strValue, curPos, nextInterestingPos - 1); //a,b,c,d
					results.Add(tmpStr);
					// DebugLog(Format('case delim - tmpStr: %s',[tmpStr]));
					tmpStr := '';
					curPos := curPos + nextInterestingPos + lengthDelim - 2; 
				end;
		end;
		
		inc(curPos);
	end;
	
	// DebugLog(Format('results.Count: %d, results: %s',[results.Count, results.Text]));
	
	LogFunctionEnd;
end;


//=========================================================================
//  Read TStringList to String
//	(including escaping)
//=========================================================================
function StringListToString(const list : TStringList; const fieldEncloser, delimiter : String; const escapeTotalString : Boolean) : String;
var 	
	i : Integer;
begin
	LogFunctionStart('StringListToString');
	
	Result := '';
	i := 0;
	while i < list.Count do begin
		if i = 0 then begin
			Result := EscapeStringIfNecessary(list[i], fieldEncloser, delimiter, '');
		end else begin
			Result := Result + delimiter + EscapeStringIfNecessary(list[i], fieldEncloser, delimiter, '');
		end;
		inc(i);
	end;
	
	if escapeTotalString then 
		Result := fieldEncloser + StringReplace(Result, fieldEncloser, fieldEncloser + fieldEncloser, [rfIgnoreCase,rfReplaceAll]) + fieldEncloser;
	
	LogFunctionEnd;
end;

//=========================================================================
//  copy one list to another, keeping the order
//=========================================================================
procedure CopyList(const list : TStringList; results : TStringList;);
var 	
	i  : Integer;
begin
	i := 0;
	while i < list.Count do begin
		results.Add(list[i]);
		inc(i);
	end;
end;

//=========================================================================
//  Transpose a string that represents a table (switch columns and rows)
// 	(we assume that everything is correctly escaped -> no extra escaping in here)
//=========================================================================
function TransposeTableString(const tableStr, rowDelimiter, columnDelimiter : String;) : String;
var 	
	i, rowsCount, colsCount, curCol, tmpInt : Integer;
	tmpStr, curLine, resultStr : String;
	tmpList, outerList, innerList : TStringList;
begin
	LogFunctionStart('TransposeTableString');
	//unfortunately we have to fill them manually, since PASCAL is not escaping properly with DelimitedText
	
	resultStr := '';
	tmpList := TStringList.Create;
	outerList := TStringList.Create;
	innerList := TStringList.Create;
	
	try
		StringToStringList(tableStr, rowDelimiter, outerList);
		// DebugLog(Format('all rows: %s',[outerList.Text]));
		
		rowsCount := outerList.Count;
		
		//get every field from every column in every row into a lookup-List
		i := 0;
		while i < rowsCount do begin
			curLine := outerList[i];
			StringToStringList(curLine, columnDelimiter, innerList);
			
			tmpInt := innerList.Count;
			curCol := 0;
			while curCol < tmpInt do begin
				tmpStr := Format('%d|%d=%s',[i, curCol, innerList[curCol]]);
				tmpList.Add(tmpStr);
				inc(curCol);
			end;
			colsCount := max(colsCount, tmpInt);
			
			inc(i);
		end;
		
		//now loop over all columns, then all rows and build the new string 
		resultStr := '';
		curCol := 0;
		while curCol < colsCount do begin
			if curCol > 0 then
				resultStr := resultStr + rowDelimiter;
			
			i := 0;
			while i < rowsCount do begin
				tmpStr := Format('%d|%d',[i, curCol]);
				tmpStr := tmpList.Values[tmpStr];
				
				if i > 0 then begin
					resultStr := resultStr + columnDelimiter + tmpStr;
				end else begin
					resultStr := resultStr + tmpStr;
				end;
				
				inc(i);
			end;
			inc(curCol);
		end;
		
	finally
		tmpList.Free;
		tmpList := nil;
		outerList.Free;
		outerList := nil;
		innerList.Free;
		innerList := nil;
	end;
	
	Result := resultStr;
	
	LogFunctionEnd;
end;

//=========================================================================
//  escape string if necessary
// (considers 2 delimiters in order to support escaping a string for a CSV table like string ouptut)
//=========================================================================
function EscapeStringIfNecessary(const stringValue, fieldEncloser, delimiter1, delimiter2 : String; ) : String;
var 	
	tmpStr : String;
	tmpBool : Boolean;
begin
	//LogFunctionStart('EscapeStringIfNecessary');
	
	Result := stringValue;
	
	if (not SameText(fieldEncloser,'')) and (Pos(fieldEncloser,stringValue) > 0) then begin
		Result := fieldEncloser + StringReplace(stringValue, fieldEncloser, fieldEncloser + fieldEncloser, [rfIgnoreCase,rfReplaceAll]) + fieldEncloser;
	end else begin
		if ((not SameText(delimiter1, '')) and (Pos(delimiter1,stringValue) > 0)) 
			or ((not SameText(delimiter2, '')) and (Pos(delimiter2,stringValue) > 0)) then begin
			Result := fieldEncloser + stringValue + fieldEncloser;
		end;
	end;
	
	//LogFunctionEnd;
end;

//=========================================================================
//  get end pos of escaped string in formula
//	e.g. when called with "as"df and curPos 2 it will return 4
//=========================================================================
function GetEndOfEscapedString(const formula : String; curPos : Integer;) : Integer;
var 
	endPos, counter, nextPos : Integer;
	endOfPartFound : Boolean;
begin
	LogFunctionStart('GetEndOfEscapedString');
	
	endPos:= curPos+1;
	counter:=1;
	
	while not endOfPartFound do begin
		//fail safe for endless loops
		if counter > 100000 then begin
			raise Exception.Create(Format('endless loop while trying to find end of string in formula - startsAt: %d, formula: %s',[curPos, formula]));
		end;
	
		// DebugLog(Format('formula part to check: %s',[Copy(formula,endPos,Length(formula)-endPos+1)]));
	
		nextPos := Pos('"',Copy(formula,endPos,Length(formula)-endPos+1));
		endPos := endPos + nextPos - 1;
		// DebugLog(Format('string starts at %d, end of string suspected at %d, formula: %s',[curPos,endPos,formula]));
		
		if nextPos <= 0 then begin
			// DebugLog(Format('could not find end of string - endpos: %d',[endPos]));
			raise Exception.Create(Format('Could not find end of string in formula: %s - string started at Position %d',[formula, curPos]));
		end;
		
		//if the next character is also a '"', this is not the end, but an escaped '"' -> go on
		if SameText(Copy(formula,endPos,2),'""') then begin
			// DebugLog(Format('this is an escaped string at position %d',[endPos]));
			endPos:= endPos + 2;
			continue;
		end else begin
			// DebugLog(Format('this is the end of the string: %d',[endPos]));
			endOfPartFound:= true;
		end;
		
		inc(counter);
	end;
	
	Result:= endPos;
	LogFunctionEnd;
end;

//=========================================================================
//  Count how many times a string appears in a string
//	returns 0 if not found
//=========================================================================
function CountStringInString(const findStr, withinStr : String; const startPos : Integer; endPos : Integer) : Integer;
var 
	tmpInt, counter : Integer;
	tmpStr : String;
begin
	// LogFunctionStart('CountStringInString');
	
	if endPos < startPos then
		endpos := Length(withinStr);
	
	//cut down the string to the part we want to search in
	tmpStr := Copy(withinStr, startPos, endPos - startPos + 1); 
	
	counter := 0;
	tmpInt := Pos(findStr, tmpStr);
	while tmpInt > 0 do begin
		inc(counter);
		tmpStr := Copy(tmpStr, tmpInt + Length(findStr), Length(tmpStr) - tmpInt - Length(findStr) + 1);
		tmpInt := Pos(findStr, tmpStr);
	end;

	Result:= counter;
	// LogFunctionEnd;
end;

//=========================================================================
//  Count how many times a string appears in a string
//	returns 0 if not found
//=========================================================================
function RepeatString(const s : String; const numberOfTimes : Integer) : String;
var 
	i : Integer;
begin
	// LogFunctionStart('RepeatString');
	
	Result := '';
	
	i := 0;
	while i < numberOfTimes do begin
		Result := Result + s;
		inc(i);
	end;

	// LogFunctionEnd;
end;


//=========================================================================
//  format string from Excel format string
//=========================================================================
function FormatStringWithExcelFormatString(const formatString, strValue : String;) : String;
var
	i, inFormat : Integer;
	curChar, format1: String;
begin
	LogFunctionStart('FormatStringWithExcelFormatString');
	
	format1:='';
	
	inFormat := 1;
	for i := 1 to Length(formatString) do begin
		curChar := Copy(formatString,i,1);
		
		if SameText(curChar,';') then begin
			inc(inFormat);
			continue;
		end;
	
		if inFormat = 4 then 
			format1 := format1 + curChar;
	end;
	
	Result := strValue;
	
	//if there is a string format
	if inFormat > 3 then begin 
		if SameText(format1,'') then begin
			Result := '';
		end else begin
			//Excel string placeholder is @
			Result := StringReplace(format1,'@',strValue, [rfIgnoreCase,rfReplaceAll]);
		end;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  format PASCAL float from Excel format string
//=========================================================================
function FormatFloatWithExcelFormatString(const formatString : String; floatValue : Double;) : String;
var
	i, inFormat : Integer;
	curChar, format1, format2, format3: String;
begin
	LogFunctionStart('FormatFloatWithExcelFormatString');
	
	format1:='';
	format2:='';
	format3:='';
	
	if Length(formatString) = 0 then
		format2 := '-""';
	
	inFormat := 1;
	for i := 1 to Length(formatString) do begin
		curChar := Copy(formatString,i,1);
		
		if SameText(curChar,';') then begin
			inc(inFormat);
			continue;
		end;
	
		case inFormat of 
			1 : format1 := format1 + curChar;
			2 : format2 := format2 + curChar;
			3 : format3 := format3 + curChar;
		end;
	end;
	
	if SameText(format1,'') then
		format1 := '""';
	if SameText(format2,'') then
		format2 := '""';
	if SameText(format3,'') then
		format3 := '""';
	
	case inFormat of
		1 : begin  //if only 1 format is given, automatically set the other 2
			format2 := '-'+format1;
			format3 := format1;
		end; //if only 2 formats are given, automatically set the 3rd
		2 : format3 := format1;
	end;
	
	//add automatic multiplication by 100 if it is a percentage-value
	if floatValue > 0 then begin
		//check the first format for a % placeholder
		if (Pos('0%',format1) > 0) or (Pos('.%',format1) > 0) or (Pos('#%',format1) > 0) then 
			floatValue := floatValue * 100;
	end else begin
		//check the second format for a % placeholder
		if (Pos('0%',format2) > 0) or (Pos('.%',format2) > 0) or (Pos('#%',format2) > 0) then 
			floatValue := floatValue * 100;
	end;	
	
DebugLog(Format('format1: %s, format2: %s, format3: %s',[format1, format2, format3]));
	
	Result := FormatFloat(Format('%s;%s;%s',[format1,format2,format3]),floatValue);
	
	LogFunctionEnd;
end;

//=========================================================================
//  read string from File
//=========================================================================
function FileToString(fileName: String; const ignoreLinesStartingWith : String; const ignoreEmptyLines : Boolean; const returnValueIfNotFound : String;) : String;
var
	i : Integer;
	linebreak, tmpStr : String;
	tmpList : TStringList;
	filteredOut : Boolean;
	dlg: TOpenDialog;
begin
	LogFunctionStart('FileToString');
	
	Result := '';
	
	if SameText(fileName, '') then begin
		//get file from popup
		dlg := TOpenDialog.Create(nil);
		try
			dlg.InitialDir := wbScriptsPath;
			if dlg.Execute then begin
				fileName := dlg.FileName;
			end else begin
				LogFunctionEnd;
				Exit;
			end;
		finally
			dlg.Free;
		end;
	end else begin
		fileName := wbScriptsPath + fileName;
	end;
	
	
	DebugLog(Format('fileName: %s',[fileName]));
	tmpList := TStringList.Create;
	
	try
		linebreak := chr(13) + chr(10);
		
		try
			tmpList.LoadFromFile(fileName);
			
			i := 0;
			while i < tmpList.Count do begin
				filteredOut := false;
				tmpStr := tmpList[i];
				
				if not SameText(ignoreLinesStartingWith,'') then begin
					if SameText(ignoreLinesStartingWith, Copy(tmpStr,1,Length(ignoreLinesStartingWith))) then
						filteredOut := true;
				end;
				
				if ignoreEmptyLines then begin
					if SameText(tmpStr, '') then
						filteredOut := true;
				end;
				
				//DebugLog(Format('tmpStr: %s',[tmpStr]));
				
				if not filteredOut then begin
					if i = 0 then begin
						Result := tmpStr;
					end else begin
						Result := Result + linebreak + tmpStr;
					end;
				end;
				
				inc(i);
			end;
		except 
			Result := returnValueIfNotFound;
		end;
	finally
		tmpList.Free;
		tmpList := nil;
	end;
	
	LogFunctionEnd;
end;


end.
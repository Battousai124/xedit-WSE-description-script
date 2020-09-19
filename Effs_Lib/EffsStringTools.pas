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
//  Transpose a string that represents a table (switch columns and rows)
// 	(we assume that everything is correctly escaped -> no extra escaping in here)
//=========================================================================
function TransposeTableString(const tableStr, columnDelimiter, rowDelimiter : String;) : String;
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
		DebugLog(Format('before loop',['']));
		
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
	
	if (Pos(fieldEncloser,stringValue) > 0) then begin
		Result := fieldEncloser + StringReplace(stringValue, fieldEncloser, fieldEncloser + fieldEncloser, [rfIgnoreCase,rfReplaceAll]) + fieldEncloser;
	end else begin
		if (Pos(delimiter1,stringValue) > 0) or (Pos(delimiter2,stringValue) > 0) then begin
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

end.
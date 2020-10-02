unit EffsFormulaParser;


implementation

uses 'Effs_Lib\EffsStringTools';

var 
	FormulaParserStopExecution : Boolean;
	FormulaParserInitialized : Boolean;
	operators, functions : TStringList;


//=========================================================================
//  Initialize static lists
//=========================================================================
procedure InitializeFormulaParser();
begin
	
	LogFunctionStart('InitializeFormulaParser');
	
	operators:= TStringList.Create; //may not be sorted
	functions:= TStringList.Create; //should be sorted, so that the Find() operation works
	functions.Sorted := true; 
	
	operators.Add('<='); //needs to be first here in order that it is not identified as 2 operators
	operators.Add('>='); //needs to be first here in order that it is not identified as 2 operators
	operators.Add('<>'); //needs to be first here in order that it is not identified as 2 operators
	operators.Add('&');
	operators.Add('+');
	operators.Add('-');
	operators.Add('*');
	operators.Add('/');
	operators.Add('=');
	operators.Add('<');
	operators.Add('>');
	
	functions.Add('if('); //Excel logical functions
	functions.Add('and(');
	functions.Add('or(');
	functions.Add('xor(');
	functions.Add('not(');
	functions.Add('isLogical(');
	functions.Add('switch(');
	functions.Add('choose(');
	functions.Add('abs('); //Excel numeric functions
	functions.Add('round('); //(trunc not necessary -> use round)
	functions.Add('sign(');
	functions.Add('mod(');
	functions.Add('power(');
	functions.Add('hex2dec(');
	functions.Add('dec2hex(');
	functions.Add('max(');
	functions.Add('min(');
	functions.Add('sum(');
	functions.Add('isOdd(');
	functions.Add('isEven(');
	functions.Add('isNumber(');
	functions.Add('trim('); //Excel string functions
	functions.Add('upper(');
	functions.Add('lower(');
	functions.Add('left(');
	functions.Add('right(');
	functions.Add('mid(');
	functions.Add('len(');
	functions.Add('text(');
	functions.Add('value(');
	functions.Add('search('); //not find - find is case-sensitive
	functions.Add('substitute('); 
	functions.Add('replace('); 
	functions.Add('rept(');
	functions.Add('concat('); 
	functions.Add('textJoin('); 
	functions.Add('formulaText(');
	functions.Add('isText(');
	functions.Add('transpose(');
	functions.Add('trimLeft('); //additional string functions
	functions.Add('trimRight('); 
	functions.Add('searchCount('); 
	functions.Add('linebreak('); 
	functions.Add('calculate(');
//functions.Add('Distinct('); //listOrCSV, ignoreEmptyValues, delimiter1, delimiter2
	//functions.Add('stringFormat(');
	functions.Add('With('); //additional logical functions
	functions.Add('Function('); 
	functions.Add('EndCalculation('); 
//functions.Add('ReadCSV('); ReadCSV(string,aggregationType,formula) formula works with a total variable that is a string, with row and col which are 1-based integers, and with itm which is a string
//functions.Add('ForEach('); foreach(string,variableName,formula,aggregationType,delimiter,fieldEncloser) if fieldEncloser is not defined, use ", 
//functions.Add('For('); ???
//functions.Add('While('); ???
//functions.Add('ExecutionCount(') NoOfExecution() returns numeric count of executions of the formula engine - during the first execution it will return 1
	functions.Add('GetOutput('); //additional functions for easy scripting
	functions.Add('SetOutput('); 
//functions.Add('ReadFromFile('); FileToString(filename,returnValueIfNotFound) if filename is empty, put up a file selection box, returns the context of the file as string, and the returnValueIfNotFound if it couldnt find the file. if returnValueIfNotFound is not set, it will throw an error if it didn't find the file
//functions.Add('SaveToFile(');  SaveToFile(varToSave,FileName,overwriteCondition,returnValue) if varToSave is empty, save all results so far, if filename is empty, show save popup, if returnValue is not set: return fileName
//functions.Add('MsgBox('); 
//functions.Add('EditBox('); ???
//functions.Add('CalculateFormulasFile('); 
	functions.Add('logMsg('); //additional xEdit specific functions
	functions.Add('ReadRecords('); 
	functions.Add('SelectedRecords('); 
	functions.Add('FindRecords('); 
//functions.Add('FindPlugins('); ???
//functions.Add('FindFiles('); ???
//functions.Add('ChangeRecords('); --returns a string that can contain every change that was necessary

			//functions.Add('SplitStringAndForEach('); SplitStringAndForEach(string,delimiter,elementVariableName,ReturnFormatFunction) ?????
			//functions.Add('WithRecords(') WithRecords(recordsString,recordVariableName,aggregationType???,formula)
			//functions.Add('setVar('); 

	//functions.Add('index('); //Excel matrix formulas - for lists?
	
	//functions.Add('sort(');
	//functions.Add('count(');
	//functions.Add('countA(');
	//functions.Add('countBlank(');
	//functions.Add('countIf(');
	//functions.Add('sumIf(');
		
	
	FormulaParserInitialized := true;
	
	LogFunctionEnd;
end;

//=========================================================================
//  free static lists
//=========================================================================
procedure FinalizeFormulaParser();
begin
	
	LogFunctionStart('FinalizeFormulaParser');
	
	if FormulaParserInitialized then begin 
		operators.Free;
		operators:= nil;
		functions.Free;
		functions:= nil;
	end;
	
	LogFunctionEnd;
end;


//=========================================================================
//  reads a file with formulas and parses them to create results
//=========================================================================
function ParseFormulasFile(const filename : String; results : TStringList; const defaultOutput : String; const selectedRecords : String;) : String;
var 	
	formulas : TStringList;
begin
	
	LogFunctionStart('ParseFormulaFile');
	
	if not FormulaParserInitialized then 
		InitializeFormulaParser;
	
	formulas := TStringList.Create;
	formulas.NameValueSeparator := '=';
	try
		LoadFormulasFromFile(filename,formulas);
		if formulas.Count = 0 then 
			raise Exception.Create(Format('Could not load any formulas from file. filename: %s',[filename]));
		// DebugLog(Format('defaultOutput to be set: %s',[defaultOutput])); 
		Result := ParseFormulas(formulas, results, defaultOutput, selectedRecords);
		
		// DebugLog(results.Text);
		
	finally
		formulas.Free;
		formulas := nil;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  parses all formulas in a list - formulas cannot access variables that are not defined in the formulas
//=========================================================================
function ParseFormulas(const formulas : TStringList; results : TStringList; const defaultOutput : String; const selectedRecords : String;) : String;
var 	
	i, tmpInt: Integer;
	variableName, formula, tmpStr, resultStr, output : String;
	resultTypes, tempVariables : TStringList;
begin
	LogFunctionStart('ParseFormulas');
	
	if not FormulaParserInitialized then 
		InitializeFormulaParser;
	
	if formulas.Count = 0 then begin
		LogFunctionEnd;
		Exit;
	end;
	
	resultTypes:= TStringList.Create; //may not be sorted
	tempVariables:= TStringList.Create; 
	
	try
		
		// DebugLog(Format('defaultOutput to be set: %s',[defaultOutput])); 
		results.Values['---OUTPUT---'] := Copy(defaultOutput,1,Length(defaultOutput));
		results.Values['---SELECTEDRECORDS---'] := selectedRecords;
		
		for i:= 0 to formulas.Count-1 do begin
			variableName := formulas.Names[i];
			tmpInt := results.IndexOfName(variableName);
			if tmpInt < 0 then begin 
				formula := formulas.Values[variableName];
				resultStr:= ParseFormula(variableName, formula, formulas, results, resultTypes, operators, functions, tempVariables, 0, false);
				DebugLog(Format('variableName: %s, result: %s',[variableName, resultStr]));
			end;
			if FormulaParserStopExecution then begin
				FormulaParserStopExecution := false;
				break;
			end;
		end;
		
		tmpInt := results.IndexOfName('---SELECTEDRECORDS---');
		if tmpInt > -1 then 
			results.Delete(tmpInt);
		
		Result := '';
		tmpInt := results.IndexOfName('---OUTPUT---');
		if tmpInt > -1 then begin
			Result := results.Values['---OUTPUT---'];
			// DebugLog(Format('Output found: %s',[Result]));
			results.Delete(tmpInt);
		end;
		
	finally
		resultTypes.Free;
		resultTypes:=nil;
	end;
	DebugLog('results:'+ chr(13) + chr(10) + results.Text);
	LogFunctionEnd;
end;

//=========================================================================
//  parses one formula - formulas cannot access variables that are not defined in the results already
// 	(recursive function)
//=========================================================================
function ParseFormula(const variableName : String; formula : String; const formulas : TStringList; results, resultTypes : TStringList; const operators, functions, outerTempVariables : TStringList; const recursionLevel : Integer; const isFunction : Boolean;) : String;
const 
	maxRecursionLevel = 50;
var 	
	i, tmpInt, curType, maxParameterToParse, maxParameterToResolve, curParameter : Integer;
	tmpStr, resultStr, resultFloatStr, resultTypeStr, functionName : String;
	resultFloat : Double;
	resolveParts, isCustomFunction : Boolean;
	formulaParts, formulaPartTypes, tempVariables : TStringList;
begin
	LogFunctionStart('ParseFormula');
	
	DebugLog(Format('variableName: %s, formula: %s, recursionLevel: %d',[variableName, formula, recursionLevel]));
	
	if results.IndexOfName(variableName) >= 0 then begin
		LogFunctionEnd;
		Exit; //--> formula already processed
	end;
	
	if recursionLevel > maxRecursionLevel then begin
		raise Exception.Create('Maximum formula nesting reached. Operation Aborted. Check for circular references.');
	end;
	
	maxParameterToParse := -1;
	maxParameterToResolve := -1;
	resultStr := '';
	resultFloat := nil; // only set if there is a numeric result
	resultFloatStr := ''; // only set if there is a numeric result
	formulaParts := TStringList.Create;
	formulaPartTypes := TStringList.Create;
	tempVariables := TStringList.Create;
	
	//0:unknown,1:String,2:Formula,3:Numeric,4:Operator,5:Pointer,6:Functions,7:Separator,8:Boolean
	try
		i:=0;
		while i < outerTempVariables.Count do begin
			tempVariables.Add(outerTempVariables[i]);
			inc(i);
		end;
	
		if isFunction then begin 
			tmpInt := Pos('(',formula);
			functionName := Copy(formula,1,tmpInt-1);
			formula := Copy(formula,tmpInt+1,Length(formula)-tmpInt-1);
			
			if SameText(functionName,'if') or SameText(functionName,'choose') then begin
				maxParameterToParse := 0;
				maxParameterToResolve := 1;
			end;
			
			if SameText(functionName,'formulaText') then
				// resolveParts := false;
				maxParameterToResolve := 0;
			
			if SameText(functionName,'with') or SameText(functionName,'switch') then
				maxParameterToParse := 0;
			
			if SameText(functionName,'formulaText') then
				maxParameterToResolve := 0;
			
			if SameText(functionName,'ReadRecords') then begin
				maxParameterToParse := 4;
				maxParameterToResolve := 4;
			end;
			
			if SameText(functionName,'FindRecords') then begin
				maxParameterToParse := 7;
				maxParameterToResolve := 7;
			end;
			
			if SameText(functionName,'SelectedRecords') then begin
				maxParameterToParse := 1;
				maxParameterToResolve := 1;
			end;
			
			// DebugLog(Format('functionName: %s, formula: %s',[functionName, formula]));
		end;
	
		GetFormulaParts(formula, operators, functions, tempVariables, formulaParts, formulaPartTypes, formulas, maxParameterToParse);
		
		if formulaParts.Count > 0 then begin 
			//a variable defined as custom function may not contain other parts
			//and: dont calculate functions if they are not called by other formulas
			if recursionLevel = 0 then begin
				i := 0;
				while i < formulaParts.Count do begin
					if SameText(formulaPartTypes[i],'6') then begin
						if (SameText(Copy(formulaParts[i],1,9),'FUNCTION(')) then begin
							isCustomFunction := true;
							break;
						end;
					end;
					inc(i);
				end;
				if isCustomFunction then begin
					if formulaParts.Count > 1 then 
						raise Exception.Create(Format('Either a variable is a function or it is not a function. FUNCTION() is used in combination with other formula parts. Variable: %s, Formula: %s',[variableName,formula]));
					if isCustomFunction then begin
						LogFunctionEnd;
						Exit; //--> formula should not be processed
					end;
				end;
			end;
			
			//check if there is an operator between each part
			CheckIfThereAreOperatorsBetweenParts(formula, formulaPartTypes);
			
			if isFunction then begin
				if SameText(functionName,'switch') then begin
					//for SWITCH we need to calculate the compare values before CalculateFunction decides what the output is
					CalculateSwitchCompareValues(variableName, formula, formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel, false, formulaParts, formulaPartTypes);
				end;
				if SameText(functionName,'with') then begin
					if not (formulaParts.Count >= 3) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, number of arguments: %d',[functionName, formulaParts.Count]));
					
					//first resolve the variables (left to right)
					i := 0;
					while i < formulaParts.Count - 2 do begin
						resultStr := formulaParts[i];
						tmpInt := Pos('=',resultStr);
						if tmpInt < 0 then
							raise Exception.Create(Format('could not find name for temporary variable in WITH function. expected to find "=" in formula part: %s',[resultStr]));
						resultTypeStr := Copy(resultStr,1,tmpInt-1); //variable name
						if formulas.IndexOfName(resultTypeStr) > -1 then
							raise Exception.Create(Format('Function tries to create a temporary variable that would overwrite a real variable. variableName: %s',[resultTypeStr]));
						resultStr := Copy(resultStr,tmpInt+1,Length(resultStr)-tmpInt); //formula
						tmpStr := ParseFormula(Format('%s_%s',[variableName, resultTypeStr]), resultStr, formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel+1, false);
						tempVariables.Values[resultTypeStr] := tmpStr;
						inc(i);
					end;
					//then get rid of the unnecessary parts (right to left)
					for i := (formulaParts.Count - 2) downto 0 do begin 
						formulaPartTypes.Delete(i);
						formulaParts.Delete(i);
					end;
				end;
			end;
			
			curParameter := 1;
			resolveParts := not (maxParameterToResolve = 0);
			if resolveParts then begin
			
				i:=0;
				while i < formulaParts.Count do begin
					curType := StrToInt(formulaPartTypes[i]);
					case curType of 
						7 : begin //count parameters
							inc(curParameter);
							if maxParameterToResolve > -1 then begin
								if curParameter > maxParameterToResolve then
									break;
							end;
						end;
						
						2 : begin //resolve sub-formulas
							tmpStr := ParseFormula(Format('%s_part%d',[variableName,i]), formulaParts[i], formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel+1, false);
							formulaPartTypes[i] := Copy(tmpStr,1,1);
							formulaParts[i] := Copy(tmpStr,3,Length(tmpStr)-2);
						end;
					
						6 : begin //resolve functions
							tmpStr := ParseFormula(Format('%s_part%d',[variableName,i]), formulaParts[i], formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel+1, true);
							formulaPartTypes[i] := Copy(tmpStr,1,1);
							formulaParts[i] := Copy(tmpStr,3,Length(tmpStr)-2);
						end;
					
						5 : begin //resolve pointer and add them to the result if you have to calculate them
							tmpStr := formulaParts[i];
							tmpInt := tempVariables.IndexOfName(tmpStr);
							if tmpInt > -1 then begin
								resultTypeStr := tempVariables.Values[tmpStr];
								formulaPartTypes[i] := Copy(resultTypeStr,1,1);
								resultTypeStr := Copy(resultTypeStr,3,Length(resultTypeStr)-2);
								formulaParts[i] := resultTypeStr;
								DebugLog(Format('temporary variable read: %s, value: %s',[tmpStr, resultTypeStr]));
							end else begin 
								tmpInt := results.IndexOfName(tmpStr);
								if tmpInt < 0 then begin
									isCustomFunction := (SameText(Copy(formulas.Values[tmpStr],1,9),'FUNCTION('));
									resultStr := ParseFormula(tmpStr, formulas.Values[tmpStr], formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel+1, false);
									resultTypeStr := Copy(resultStr,1,1);
									resultTypes.Values[tmpStr] := resultTypeStr;
									resultStr := Copy(resultStr,3,Length(resultStr)-2);
									if SameText(resultTypeStr,'3') then begin
										resultFloat := StrToFloat(resultStr);
										resultStr := FormatFloat('0.##########;-0.##########;"0"',RoundTo(resultFloat,-6));
									end;
									if not isCustomFunction then begin 
										if not SameText(resultStr,'') then begin
											results.Values[tmpStr] := resultStr;
										end else begin
											if not SameText(resultTypeStr,'') then
												results.Add(tmpStr + '=');
										end;
										DebugLog(Format('function calculated: %s, value: %s',[tmpStr, resultStr]));
									end;
									formulaPartTypes[i] := resultTypeStr;
									formulaParts[i] := resultStr;
								end else begin 
									formulaPartTypes[i] := resultTypes.Values[tmpStr];
									formulaParts[i] := results.Values[tmpStr];
								end;
							end;
						end;
					end;
					
					inc(i);
				end;
				
				//calculate the rest ...this is only parts that are on the same level and in between separators
				resultStr := CalculateFormulaParts(formula, operators, formulaParts, formulaPartTypes);
				resultTypeStr := formulaPartTypes[0];
			end;
		end;
		
		//calculate Function
		if isFunction then begin 
			resultStr := CalculateFunction(variableName, formula, formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel, functionName, formulaParts, formulaPartTypes);
			resultTypeStr := formulaPartTypes[0];
			
			if SameText(resultTypeStr,'2') then begin
				// DebugLog(Format('before parsing result. formulaParts: %s, formulaPartTypes: %s',[formulaParts.Text, formulaPartTypes.Text]));
				tmpStr := ParseFormula(Format('%s_part%d',[variableName,0]), formulaParts[0], formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel+1, false);
				// DebugLog(Format('after parsing result. formulaParts: %s, formulaPartTypes: %s',[formulaParts.Text, formulaPartTypes.Text]));
				resultTypeStr := Copy(tmpStr,1,1);
				resultStr := Copy(tmpStr,3,Length(tmpStr)-2);
			end;
		end;
		
		//return result
		if recursionLevel > 0 then begin
			resultStr := Format('%s|%s',[resultTypeStr,resultStr]);
		end else begin
			if not SameText(resultStr,'') then begin
				if SameText(resultTypeStr,'3') then begin //end results are rounded to 6 decimal places
					resultFloat := StrToFloat(resultStr);
					resultStr := FormatFloat('0.##########;-0.##########;"0"',RoundTo(resultFloat,-6));
					//RoundTo(1.234, -2) 
				end;
				results.Values[variableName] := resultStr;
			end else begin
				if not SameText(resultTypeStr,'') then //if there is no type then it should not be logged as result
					results.Add(variableName + '=');
			end;
			resultTypes.Values[variableName] := resultTypeStr;
		end;
	
	finally
		formulaParts.Free;
		formulaParts:= nil;
		formulaPartTypes.Free;
		formulaPartTypes:= nil;
		tempVariables.Free;
		tempVariables:= nil;
	end;
	
	Result:=resultStr;
	
	LogFunctionEnd;
end;


//=========================================================================
//  Read information from records
//=========================================================================
function ParseReadRecords(const variableName : String; formula : String; const formulas : TStringList; results, resultTypes : TStringList; const operators, functions, outerTempVariables : TStringList; const recursionLevel : Integer; formulaParts, formulaPartTypes, parameters, parameterTypes : TStringList;) : String;
var 	
	i, tmpInt, partsCount, counter : Integer;
	recordsStr, pathsStr, emptyReturnValue, recordsDelimiter, elementsDelimiter, conditionFormula, selectionFormula, curPathStr, curRecordStr, tmpStr, curVal, curRecIndex, curPathIndex, lastRecIndex : String;
	tmpList, tmpVarList, tempVariables : TStringList;
	conditionMet : Boolean;
begin
	LogFunctionStart('ParseReadRecords');
	
	tmpList := TStringList.Create;
	tmpVarList := TStringList.Create;
	tempVariables := TStringList.Create;
	
	try
	
		partsCount := formulaParts.Count;
		
		if partsCount < 3 then
			raise Exception.Create(Format('Function ReadRecords was called with too less parameters. Formula: %s',[formula]));
		if SameText(formulaPartTypes[0],'7') then
			raise Exception.Create(Format('Function ReadRecords was called without a records parameter. Formula: %s',[formula]));
		if SameText(formulaPartTypes[2],'7') then
			raise Exception.Create(Format('Function ReadRecords was called without a path parameter. Formula: %s',[formula]));
		
		//set default values 
		parameters.Values['2'] := chr(13) + chr(10);
		parameters.Values['3'] := ',';
		emptyReturnValue := '';
		
		//read parameters
		ReadParameters(6, formulaParts, formulaPartTypes, parameters, parameterTypes);
		recordsStr := parameters.Values['0'];
		pathsStr := parameters.Values['1'];
		recordsDelimiter := parameters.Values['2'];
		elementsDelimiter := parameters.Values['3'];
		conditionFormula := parameters.Values['4'];
		selectionFormula := parameters.Values['5'];
		
		//-> all parameters read from formulaParts;
		DebugLog(Format('parameters: recordsStr: %s, pathsStr: %s, emptyReturnValue: %s, recordsDelimiter: %s, elementsDelimiter: %s, conditionFormula: %s, selectionFormula: %s',[recordsStr, pathsStr, emptyReturnValue, recordsDelimiter, elementsDelimiter, conditionFormula, selectionFormula]));
		
		Result := ReadRecords(recordsStr, pathsStr, emptyReturnValue, recordsDelimiter, elementsDelimiter, tmpList, tmpVarList);
		
		if (not SameText(conditionFormula,'')) or (not SameText(selectionFormula,'')) then begin
			Result := '';
			//copy outer variables to inner
			CopyList(outerTempVariables, tempVariables);
			
			//now for each found record: 
			//create the respective temporary variables, call the filter formula and only keep the record if the result is "true" 
			counter := 0;
			i := 0;
			while i < tmpList.Count do begin
				conditionMet := true;
				curVal := tmpList.ValueFromIndex[i];
				tmpStr := tmpList.Names[i];
				tmpInt := Pos(',', tmpStr);
				curRecIndex := Copy(tmpStr, 1, tmpInt - 1);
				curPathIndex := Copy(tmpStr, tmpInt + 1, Length(tmpStr) - tmpInt);
				curRecordStr := tmpVarList.Values[curRecIndex+',r'];
				curPathStr := tmpVarList.Values[tmpStr+',p'];
				
				//set temporary variables
				tempVariables.Values['rec'] := '1|' + curRecordStr;
				tempVariables.Values['path'] := '1|' + curPathStr;
				tempVariables.Values['val'] := '1|' + curVal;
				tempVariables.Values['i_rec'] := '3|' + curRecIndex;
				tempVariables.Values['i_path'] := '3|' + curPathIndex;
				
				if not SameText(conditionFormula,'') then begin 
					//set temporary variables
					tempVariables.Values['i'] := '3|' + IntToStr(i + 1);
					// DebugLog(Format('i: %d, curVal: %s', [i, curVal]));
					//calculate the formula
					tmpStr := ParseFormula(Format('%s_cond_val%d',[variableName,i]), conditionFormula, formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel+1, false);
					if not SameText(Copy(tmpStr,3,Length(tmpStr)),'true') then begin
						conditionMet := false;
					end;
				end;
				
				if conditionMet then begin 
					if not SameText(selectionFormula,'') then begin 
						//set temporary variables
						tempVariables.Values['i'] := '3|' + IntToStr(counter + 1);
						//calculate the formula
						tmpStr := ParseFormula(Format('%s_sel_val%d',[variableName,i]), selectionFormula, formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel+1, false);
						curVal := Copy(tmpStr,3,Length(tmpStr));
					end;
					
					curVal := EscapeStringIfNecessary(curVal, '"', recordsDelimiter, elementsDelimiter);
					
					if counter = 0 then begin
						Result := curVal;
					end else begin
						if not SameText(lastRecIndex, curRecIndex) then begin 
							Result := Result + recordsDelimiter + curVal;
						end else begin
							Result := Result + elementsDelimiter + curVal;
						end;
					end;
					lastRecIndex := curRecIndex;
					inc(counter);
				end;
				inc(i);
			end;
		end;
		
		
	finally
		tmpList.Free;
		tmpList := nil;
		tmpVarList.Free;
		tmpVarList := nil;
		tempVariables.Free;
		tempVariables := nil;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  find or filter records
//=========================================================================
function ParseFindRecords(const variableName : String; formula : String; const formulas : TStringList; results, resultTypes : TStringList; const operators, functions, outerTempVariables : TStringList; const recursionLevel : Integer; formulaParts, formulaPartTypes, parameters, parameterTypes : TStringList;) : String;
var 	
	i, counter, partsCount, curSeparator, isMasterFilterMode, isWinningOverrideFilterMode, maxParameters, maxNumberOfResults : Integer;
	recordsStr, pluginFilterStr, signatureFilterStr, conditionFormula, tmpStr, curRecordStr, delimiter, selectionFormula : String;
	conditionMet : Boolean;
	tmpList, tempVariables : TStringList;
begin
	LogFunctionStart('ParseFindRecords');
	
	tmpList := TStringList.Create;
	tempVariables := TStringList.Create;
	
	try
		partsCount := formulaParts.Count;
		
		// if partsCount < 1 then
			// raise Exception.Create(Format('Function FindRecords was called with too less parameters. Formula: %s',[formula]));
		
		isMasterFilterMode := 0;
		isWinningOverrideFilterMode := 0;
		
		//set default values 
		parameters.Values['5'] := ';';
		parameters.Values['6'] := '1000';
		parameterTypes.Values['6'] := '3';
		
		//read parameters
		ReadParameters(9, formulaParts, formulaPartTypes, parameters, parameterTypes);
		recordsStr := parameters.Values['0'];
		pluginFilterStr := parameters.Values['1'];
		signatureFilterStr := parameters.Values['2'];
		if not SameText(parameterTypes.Values['3'],'') then begin 
			tmpStr := parameters.Values['3'];
			if SameText(tmpStr, 'true') then begin
				isMasterFilterMode := 1;
			end else begin 
				if SameText(tmpStr, 'false') then 
					isMasterFilterMode := 2;
			end;
		end;
		if not SameText(parameterTypes.Values['4'],'') then begin 
			tmpStr := parameters.Values['4'];
			if SameText(tmpStr, 'true') then begin
				isWinningOverrideFilterMode := 1;
			end else begin 
				if SameText(tmpStr, 'false') then 
					isWinningOverrideFilterMode := 2;
			end;
		end;
		delimiter := parameters.Values['5'];
		if not SameText(parameterTypes.Values['6'], '3') then 
			raise Exception.Create(Format('Function FindRecords was called with a non numeric maxNumberOfResults parameter. Formula: %s',[formula]));
		maxNumberOfResults := StrToInt(parameters.Values['6']);
		conditionFormula := parameters.Values['7'];
		selectionFormula := parameters.Values['8'];
		
		//-> all parameters read from formulaParts;
		DebugLog(Format('parameters: recordsStr: %s, pluginFilterStr: %s, signatureFilterStr: %s, isMasterFilterMode: %d, isWinningOverrideFilterMode: %d, delimiter: %s, maxNumberOfResults: %d, conditionFormula: %s, selectionFormula: %s',[recordsStr, pluginFilterStr, signatureFilterStr, isMasterFilterMode, isWinningOverrideFilterMode, delimiter, maxNumberOfResults, conditionFormula, selectionFormula]));
		
		//process the basic "Find" of "Filter" operations
		if SameText(recordsStr,'') then begin
			Result := FindRecords(pluginFilterStr, signatureFilterStr, delimiter, isMasterFilterMode, isWinningOverrideFilterMode, maxNumberOfResults, tmpList);
		end else begin
			Result := FilterRecords(recordsStr, pluginFilterStr, signatureFilterStr, delimiter, isMasterFilterMode, isWinningOverrideFilterMode, maxNumberOfResults, tmpList);
		end;
		
		if (not SameText(conditionFormula,'')) or (not SameText(selectionFormula,'')) then begin
			Result := '';
			//copy outer variables to inner
			CopyList(outerTempVariables, tempVariables);
			
			//now for each found record: 
			//create the respective temporary variables, call the filter formula and only keep the record if the result is "true" 
			counter := 0;
			i := 0;
			while i < tmpList.Count do begin
				conditionMet := true;
				curRecordStr := tmpList[i];
				
				//set temporary variables
				tempVariables.Values['rec'] := '1|' + curRecordStr;
				
				if not SameText(conditionFormula,'') then begin 
					//set temporary variables
					tempVariables.Values['i'] := '3|' + IntToStr(i + 1);
					// DebugLog(Format('i: %d, curRecordStr: %s', [i, curRecordStr]));
					//calculate the formula
					tmpStr := ParseFormula(Format('%s_cond_rec%d',[variableName,i]), conditionFormula, formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel+1, false);
					if not SameText(Copy(tmpStr,3,Length(tmpStr)),'true') then begin
						conditionMet := false;
					end;
				end;
				
				if conditionMet then begin 
					if not SameText(selectionFormula,'') then begin 
						//set temporary variables
						tempVariables.Values['i'] := '3|' + IntToStr(counter + 1);
						//calculate the formula
						tmpStr := ParseFormula(Format('%s_sel_rec%d',[variableName,i]), selectionFormula, formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel+1, false);
						curRecordStr := Copy(tmpStr,3,Length(tmpStr));
					end;
					
					if counter = 0 then begin
						Result := curRecordStr;
					end else begin
						Result := Result + delimiter + curRecordStr;
					end;
					inc(counter);
				end;
				inc(i);
			end;
		end;
		
	finally
		tmpList.Free;
		tmpList := nil;
		tempVariables.Free;
		tempVariables := nil;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  check if there is an operator between each formula part
//=========================================================================
procedure CheckIfThereAreOperatorsBetweenParts(const formula : String; const formulaPartTypes : TStringList;);
var 	
	i : Integer;
	prevPartType, curPartType : String;
	isOddPart : Boolean;
begin
	LogFunctionStart('CheckIfThereAreOperatorsBetweenParts');
	
	i := 0;
	while i < formulaPartTypes.Count do begin
		curPartType := formulaPartTypes[i];
		if (i = 0) and SameText(curPartType,'4') then begin
			raise Exception.Create(Format('formula starts with an operator - formula: %s',[formula]));
		end 
		else begin 
			if (i = formulaPartTypes.Count-1) and SameText(curPartType,'4') then begin
				raise Exception.Create(Format('formula ends with an operator - formula: %s',[formula]));
			end 
			else begin
				if SameText(curPartType,'4') then begin 
					if SameText(prevPartType,'4') then
						raise Exception.Create(Format('there are 2 operators next to each other. formula: %s',[formula]));
					if SameText(prevPartType,'7') then
						raise Exception.Create(Format('the formula part after an argument separator starts with an operator. formula: %s',[formula]));
				end else begin
					if SameText(curPartType,'7') then begin 
						if SameText(prevPartType,'4') then
							raise Exception.Create(Format('the formula part within an argument ends with an operator. formula: %s',[formula]));
					end;	
				end;
			end;
		end;
		prevPartType := curPartType;
		inc(i);
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  get the parts of a formula
//=========================================================================
procedure GetFormulaParts(const formula : String; const operators, functions, tempVariables : TStringList; formulaParts, formulaPartTypes : TStringList; const formulas : TStringList; const maxParameterToParse : Integer;);
var
	curPos, endPos, i, counter, tmpInt, lastSeparatorEnd, previousSeparatorEnd, curParameter : Integer;
	curPart, curChar, operator, tmpStr : String;
	curPartType : Integer; //0:unknown,1:String,2:Formula,3:Numeric,4:Operator,5:Pointer,6:Functions,7:Separator,8:Boolean
	isFirstPartOrAfterSeparator, parsePartDetails : Boolean;
begin
	LogFunctionStart('GetFormulaParts');
	
	formulaParts.Clear;
	counter := 1;
	curPos := 1;
	curParameter := 1;
	parsePartDetails := (not (maxParameterToParse = 0));
	// DebugLog(Format('Length of formula: %d',[Length(formula)]));
	
	isFirstPartOrAfterSeparator:=true;
	while curPos <= Length(formula) do begin
		//fail safe for endless loops
		if counter > 1000 then begin
			raise Exception.Create(Format('endless loop while trying to get formula parts - curPos: %d, formula: %s',[curPos, formula]));
		end;
		
		curPartType := 0;
		curChar := Copy(formula,curPos,1);
		
		//string
		if SameText(curChar,'"') then begin
			curPartType := 1; //1-string
			// DebugLog('this is a string');
			endPos := GetEndOfEscapedString(formula, curPos);
			curPart := StringReplace(Copy(formula,curPos+1,endPos-curPos-1),'""','"', [rfIgnoreCase,rfReplaceAll]);
			curPos := endPos ;
		end;
		
		//check for argument separator (hardcoded: comma)
		if curPartType = 0 then begin
			if SameText(curChar,',') then begin
				curPartType:=7; //7-Separator
				curPart := curChar;
				endPos := curPos;
				previousSeparatorEnd := lastSeparatorEnd;
				lastSeparatorEnd := curPos;
			end;
		end;
		
		//operators
		if curPartType = 0 then begin
			for i:=0 to operators.Count-1 do begin
				operator := operators[i];
				if SameText(operator,Copy(formula,curPos,Length(operator))) then begin
					// DebugLog(Format('curPos: %d, i: %d, operator: %s',[curPos,i,operator]));
					curPartType := 4; //4-operator
					curPart := operator;
					curPos := curPos+Length(operator)-1;
					break;
				end;
			end;
		end;
		
		//numeric
		if curPartType = 0 then begin
			if (curChar >= '0') and (curChar <= '9') then begin
				curPartType:=3; //3-numeric
				endPos := GetEndOfNumericInFormula(formula, curPos);
				curPart := StrToFloat(Copy(formula,curPos,endPos-curPos));
				curPos := endPos-1;
			end;
		end;
		
		//check for functions
		if (curPartType = 0) and not SameText(curChar,' ') then begin
			tmpInt := Pos('(',Copy(formula,curPos+1,Length(formula)-curPos+1));
			if tmpInt > 0 then begin 
				tmpStr := Copy(formula,curPos,tmpInt+1);
				//DebugLog(Format('finding function: %s',[tmpStr]));
				if functions.Find(tmpStr,tmpInt) then begin
					curPartType := 6; //6-function
					endPos := GetEndOfBracketInFormula(formula, curPos+Length(tmpStr)-1);
					curPart := Copy(formula,curPos,endPos-curPos+1);
					curPos := endPos;
				end;
			end;
		end;
		
		//check for brackets outside of function begin
		if curPartType = 0 then begin
			if SameText(curChar,'(') then begin
				curPartType:=2; //2-formula
				endPos := GetEndOfBracketInFormula(formula, curPos);
				curPart := Copy(formula,curPos+1,endPos-curPos-1);
				curPos := endPos;
			end;
		end;
		
		//check for pointer
		if (curPartType = 0) and (not SameText(curChar,' ')) then begin
			// DebugLog(Format('looking for pointer. start position: %d, pointer: %s',[curPos, curPart]));
			
			endPos := GetEndOfVariablenameInFormula(formula, curPos, operators);
			curPart := Copy(formula,curPos,endPos-curPos+1);
			
			// DebugLog(Format('looking for pointer. start position: %d, pointer: %s',[curPos, curPart]));
			if parsePartDetails then begin 
				if SameText(curPart,'true') or SameText(curPart,'false') then begin 
					curPartType := 8;
				end else begin
					tmpInt := tempVariables.IndexOfName(curPart);
					if tmpInt > -1 then begin
						curPartType:=5; //5-pointer
					end else begin 
						tmpInt := formulas.IndexOfName(curPart);
						if tmpInt < 0 then begin
							raise Exception.Create(Format('Could not find variable with name %s, in formula: %s, position: %d',[curPart, formula, curPos]));
						end;
						curPartType:=5; //5-pointer
					end;
				end;
			end else begin
				curPartType := 5;
			end;
			
			curPos := endPos;
		end;
		
		if (curPartType > 0) then begin
			if (maxParameterToParse > -1) then begin 
				if curParameter >= maxParameterToParse then
					parsePartDetails := false;
			end;
			
			if parsePartDetails then begin 
				if isFirstPartOrAfterSeparator then begin
					if curPartType = 4 and (SameText(curPart,'-') or SameText(curPart,'+')) then begin 
						//the formula starts with a + or - operator -> interpret the part as formula
						formulaParts.Add('0');
						formulaPartTypes.Add('3'); //3-numeric
						DebugLog(Format('formula started with operator. added "0" at the start. formula: %s',[formula]));
					end;
				end;
				formulaParts.Add(curPart);
				formulaPartTypes.Add(IntToStr(curPartType));
				DebugLog(Format('new Formlua part added: type: %d, part: %s',[curPartType,curPart]));
				isFirstPartOrAfterSeparator := (curPartType = 7);
				curPart := '';
				if curPartType = 7 then
					inc(curParameter);
			end else begin 
				//everything is a formula between separators
				if curPartType = 7 then begin
					tmpStr := Copy(formula,previousSeparatorEnd+1,curPos-previousSeparatorEnd-1);
					if Length(tmpStr) > 0 then begin 
						formulaParts.Add(tmpStr);
						formulaPartTypes.Add('2');
						DebugLog(Format('new Formlua part added: type: %d, part: %s',[2,tmpStr]));
					end;
					formulaParts.Add(curPart);
					formulaPartTypes.Add(IntToStr(curPartType));
					DebugLog(Format('new Formlua part added: type: %d, part: %s',[curPartType,curPart]));
					curPart := '';
					inc(curParameter);
				end;
			end;
		end else 
		begin
			if not SameText(curChar,' ') then begin
				raise Exception.Create(Format('could not identify formula part starting at position: %d, formula: %s',[curPos, formula]));
			end;
		end;
			
		Inc(curPos);
		Inc(counter);
	end;
	
	//add part after last separator
	if (not parsePartDetails) and (lastSeparatorEnd > 0) then begin 
		tmpStr := Copy(formula,lastSeparatorEnd+1,curPos-lastSeparatorEnd);
		if Length(tmpStr) > 0 then begin
			formulaParts.Add(tmpStr);
			formulaPartTypes.Add('2');
			DebugLog(Format('new Formlua part added: type: %d, part: %s',[2,tmpStr]));
		end;
	end;	
	
	LogFunctionEnd;
end;

//=========================================================================
//  get end pos for variableName
//=========================================================================
function GetEndOfVariablenameInFormula(const formula : String; curPos : Integer; const operators : TStringList;) : Integer;
var 
	i, counter, startPos, endPos : Integer;
	curChar, operator : String;
	endOfPartFound : Boolean;
begin
	LogFunctionStart('GetEndOfVariablenameInFormula');
	
	startPos:=curPos;
	endPos:=0;
	counter:=1;
	
	inc(curPos);
	
	// DebugLog(Format('looking for pointer. curPos: %d, endPos: %d',[curPos, endPos]));
	
	while curPos <= Length(formula) do begin
		//fail safe for endless loops
		if counter > 1000 then begin
			raise Exception.Create(Format('endless loop while trying to find string in formula - startsAt: %d, formula: %s',[curPos, formula]));
		end;
		
		curChar:=Copy(formula,curPos,1);
		
		if SameText(curChar,')') then begin
			endPos:= curPos-1;
			break;
		end;
		
		if SameText(curChar,',') then begin
			endPos:= curPos-1;
			break;
		end;
		
		for i:=0 to operators.Count-1 do begin
			operator := operators[i];
			if SameText(operator,Copy(formula,curPos,Length(operator))) then begin
				endPos:= curPos-1;
				break;
			end;
		end;
		
		if not (endPos = 0) then begin
			break;
		end;
		
		if SameText(curChar,'"') then begin
			endPos:= curPos-1;
			break;
		end;
		
		if SameText(curChar,'(') then begin
			endPos:= curPos-1;
			break;
		end;
		
		inc(curPos);
		inc(counter);
	end;
	
	if endPos = 0 then begin
		endPos := Length(formula);
	end;
	
	Result:= endPos;
	LogFunctionEnd;
end;

//=========================================================================
//  get next pos of closing bracket in formula
//=========================================================================
function GetEndOfBracketInFormula(const formula : String; curPos : Integer;) : Integer;
var 
	counter, openBracketsCounted, closedBracketsCounted, startPos : Integer;
	curChar : String;
	endOfPartFound, curCharIsInString : Boolean;
begin
	LogFunctionStart('GetEndOfBracketInFormula');
	
	startPos:=curPos;
	counter:=1;
	
	inc(curPos);
	openBracketsCounted := 1;
	closedBracketsCounted := 0;
	
	//for curPos =: curPos+1 to Length(formula) do begin
	while curPos <= Length(formula) do begin
		//fail safe for endless loops
		if counter > 10000 then begin
			raise Exception.Create(Format('endless loop while trying to find string in formula - startsAt: %d, formula: %s',[curPos, formula]));
		end;
		
		curChar:=Copy(formula,curPos,1);
		if SameText(curChar,'"') then
			curCharIsInString := not curCharIsInString;
		
		if not curCharIsInString then begin
			if SameText(curChar,')') then 
				inc(closedBracketsCounted);
			
			if SameText(curChar,'(') then 
				inc(openBracketsCounted);
		end;
		
		if openBracketsCounted=closedBracketsCounted then begin
			endOfPartFound:=true;
			break;
		end;
		
		inc(curPos);
		inc(counter);
	end;
	
	if not endOfPartFound then begin
		raise Exception.Create(Format('could not find closing bracket for bracket starting at: %d, formula: %s',[startPos, formula]));
	end;
	
	Result:= curPos;
	LogFunctionEnd;
end;


//=========================================================================
//  get endpos for numeric value in formula
//=========================================================================
function GetEndOfNumericInFormula(const formula : String; curPos : Integer;) : Integer;
var 
	endPos, counter, nextPos : Integer;
	endOfPartFound : Boolean;
	curChar : String;
begin
	LogFunctionStart('GetEndOfNumericInFormula');
	
	endPos:= curPos+1;
	inc(curPos);//starts with the second character to support leading signs implicitly 
	counter:=1;
	
	while not endOfPartFound do begin
		//fail safe for endless loops
		if counter > 100 then begin
			raise Exception.Create(Format('endless loop while trying to find string in formula - startsAt: %d, formula: %s',[curPos, formula]));
		end;
		
		curChar:= Copy(formula,curPos,1);
		// DebugLog(Format('finding end of numeric. curChar: %s',[curChar]));
		if ((curChar >= '0') and (curChar <= '9')) or SameText(curChar,'.') then begin
			inc(endPos);
		end else begin
			endOfPartFound:= true;
			//DebugLog(Format('end found: %d',[endPos]));
		end;
		
		inc(curPos);
		inc(counter);
	end;
	
	Result:= endPos;
	LogFunctionEnd;
end;

//=========================================================================
//  calculate a function
//=========================================================================
function CalculateFunction(const variableName : String; formula : String; const formulas : TStringList; results, resultTypes : TStringList; const operators, functions, outerTempVariables : TStringList; const recursionLevel : Integer; const functionName : String; formulaParts, formulaPartTypes : TStringList;) : String;
var
	i, separatorsCount, curSeparator, partsCount, maxParameters, tmpInt, pickResult, intValue1, intValue2, ifLoop, counter : Integer;
	boolStr, resultStr, strValue1, strValue2, resultType, type1, type2, tmpStr, curItm : String;
	onePartIsAString, bothPartsAreNumeric, resultBool : Boolean;
	floatValue1, floatValue2, resultFloat : Double;
	parameters, parameterTypes, tempVariables, tmpList : TStringList;
begin
	LogFunctionStart('CalculateFunction');
	
	Result := '';
	partsCount := formulaParts.Count;
	resultStr:='';
	separatorsCount := 0;
		
	i:= 0;
	while i <= (partsCount-1) do begin
		if SameText(formulaPartTypes[i],'7') then begin
			inc(separatorsCount);
		end;
		inc(i);
	end;
	
	parameters := TStringList.Create;
	parameterTypes := TStringList.Create;
	tmpList := TStringList.Create;
	tempVariables := TStringList.Create;
	
	try
		//0:unknown,1:String,2:Formula,3:Numeric,4:Operator,5:Pointer,6:Functions,7:Separator,8:Boolean

		// 1:////////////   IF   /////////////
				if SameText(functionName,'if') then begin 
					if (separatorsCount < 1) or (separatorsCount > 2) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					strValue1:= formulaParts[0];
					type1:=formulaPartTypes[0];
					
					if not (SameText(type1,'8') or SameText(type1,'3') or SameText(strValue1,'true') or SameText(strValue1,'false')) then 
						raise Exception.Create(Format('The first argument is no boolean or numeric value. functionName: %s, argument: %s',[functionName, strValue1]));
					
					if SameText(type1,'3') then begin
						floatValue1 := StrToFloat(strValue1);
						resultBool := (not (floatValue1 = 0));
					end else begin
						resultBool := SameText(strValue1,'true');
					end;
					
					resultType:= '';
					if resultBool then begin //pick the thenValue (3rd part)
						resultStr := formulaParts[2];
						resultType := formulaPartTypes[2];
					end else begin //pick the elseValue (last part)
						//pick the last result. 
						resultStr := formulaParts[partsCount-1];
						resultType := formulaPartTypes[partsCount-1];
					end;
					
					//if there is none defined (empty between separators or after last separator), initialize with empty string
					if SameText(resultType,'') or SameText(resultType,'7') then begin
						resultType := '1';
						resultStr := '';
					end;
					// break;
				end;
		
		// 2:////////////   AND   /////////////
				if SameText(functionName,'and') then begin 
					if not (partsCount > 0) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultStr := 'false';
					resultType := '8';
					tmpInt := 0;
					
					//count the number of true elements and compare to total elements
					for i := 0 to partsCount-1 do begin 
						type1 := formulaPartTypes[i];
						strValue1 := formulaParts[i];
						
						if SameText(type1,'7') then 
							continue;
						
						if SameText(type1,'8') then begin
							if SameText(strValue1,'true') then 
								inc(tmpInt);
							continue;
						end;
						
						if SameText(type1,'3') then begin
							floatValue1 := StrToFloat(strValue1);
							if not (floatValue1 = 0) then
								inc(tmpInt);
							continue;
						end;
						
						raise Exception.Create(Format('One of the arguments is neither a boolean nor a numeric value. functionName: %s, argument: %s',[functionName, strValue1]));
					end;
					
					if (tmpInt = (partsCount-separatorsCount)) then  
						resultStr := 'true';
					// break;
				end;
		
		// 3:////////////   OR   /////////////
				if SameText(functionName,'or') then begin 
					if not (partsCount > 0) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultStr := 'false';
					resultType := '8';
					tmpInt := 0;
					
					//count the number of true elements and compare to total elements
					for i := 0 to partsCount-1 do begin 
						type1 := formulaPartTypes[i];
						strValue1 := formulaParts[i];
						
						if SameText(type1,'7') then 
							continue;
						
						if SameText(type1,'8') then begin
							if SameText(strValue1,'true') then 
								inc(tmpInt);
							continue;
						end;
						
						if SameText(type1,'3') then begin
							floatValue1 := StrToFloat(strValue1);
							if not (floatValue1 = 0) then
								inc(tmpInt);
							continue;
						end;
						
						raise Exception.Create(Format('One of the arguments is neither a boolean nor a numeric value. functionName: %s, argument: %s',[functionName, strValue1]));
					end;
					
					if (tmpInt > 0) then  
						resultStr := 'true';
					// break;
				end;
		
		// 4:////////////   XOR   /////////////
				if SameText(functionName,'xor') then begin 
					if not (partsCount > 0) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultStr := 'false';
					resultType := '8';
					tmpInt := 0;
					
					//count the number of true elements and compare to total elements
					for i := 0 to partsCount-1 do begin 
						type1 := formulaPartTypes[i];
						strValue1 := formulaParts[i];
						
						if SameText(type1,'7') then 
							continue;
						
						if SameText(type1,'8') then begin
							if SameText(strValue1,'true') then 
								inc(tmpInt);
							continue;
						end;
						
						if SameText(type1,'3') then begin
							floatValue1 := StrToFloat(strValue1);
							if not (floatValue1 = 0) then
								inc(tmpInt);
							continue;
						end;
						
						raise Exception.Create(Format('One of the arguments is neither a boolean nor a numeric value. functionName: %s, argument: %s',[functionName, strValue1]));
					end;
					
					if (tmpInt = 1) then  
						resultStr := 'true';
					// break;
				end;
		
		// 5:////////////   NOT   /////////////
				if SameText(functionName,'not') then begin 
					resultStr := '';
					resultBool := false;
					resultType := '8';
					
					if not ((separatorsCount = 0) and (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					
					if SameText(type1,'8') then begin
						resultBool := not SameText(strValue1,'true');
					end else begin 
						if SameText(type1,'3') then begin
							floatValue1 := StrToFloat(strValue1);
							resultBool := (floatValue1 = 0);
						end else begin 
							raise Exception.Create(Format('The first argument is no numeric or boolean type. functionName: %s, argument: %s',[functionName, strValue1]));
						end;
					end;
					
					if resultBool then begin 
						resultStr := 'true';
					end else begin
						resultStr := 'false';
					end;
					// break;
				end;
		
		// 6:////////////   ISLOGICAL   /////////////
				if SameText(functionName,'isLogical') then begin 
					if not ((separatorsCount = 0) and (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					
					if SameText(type1,'8') then begin
						resultStr := 'true';
					end else begin
						resultStr := 'false';
					end;
					
					resultType := '8';
					// break;
				end;
		
		// 7:////////////   SWITCH   /////////////
				if SameText(functionName,'switch') then begin 
					//extra function - needed more variables than available here
					tmpStr := CalculateSwitch(separatorsCount,formulaParts,formulaPartTypes);
					resultType := Copy(tmpStr,1,1);
					resultStr := Copy(tmpStr,3,Length(tmpStr)-2);
					// break;
				end;
				
		// 8:////////////   CHOOSE   /////////////
				if SameText(functionName,'choose') then begin 
					if not (separatorsCount > 0) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultType := '1';
					resultStr := '';
					
					//set default values 
					parameters.Values['0'] := '0';
					
					//read parameters
					ReadParameters(separatorsCount + 1, formulaParts, formulaPartTypes, parameters, parameterTypes);
					strValue1 := parameters.Values['0'];//the selected index - stored as string for string comparison
					
					for tmpInt:= 1 to separatorsCount do begin
						if SameText(IntToStr(tmpInt),strValue1) then begin
							resultType := parameterTypes.Values[strValue1];
							if SameText(resultType,'') then begin
								resultStr := '0';
								resultType := '3';
							end else begin
								resultStr := parameters.Values[strValue1];
							end;
							break;
						end;
					end;
					// break;
				end;
		
		// 9:////////////   ABS   /////////////
				if SameText(functionName,'abs') then begin 
					if not ((separatorsCount = 0) and (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultType := formulaPartTypes[0];
					
					if not (SameText(resultType,'3') or SameText(resultType,'8')) then 
						raise Exception.Create(Format('The first argument is no numeric or boolean type. functionName: %s, argument: %s',[functionName, boolStr]));
					
					if SameText(resultType,'8') then begin 
						boolStr := formulaParts[0];
						
						if not (SameText(boolStr,'true') or SameText(boolStr,'false')) then
							raise Exception.Create(Format('Could not read boolean argument. functionName: %s, argument: %s',[functionName, boolStr]));
						
						resultBool := SameText(boolStr,'true');
						
						if resultBool then begin 
							resultStr := '1';
						end else begin 
							resultStr := '0';
						end;
					end else begin
						resultFloat := StrToFloat(formulaParts[0]);
						resultFloat := abs(resultFloat);
						resultStr := FormatFloat('0.##########;-0.##########;"0"',resultFloat);
					end;
					
					resultType := '3';
					// break;
				end;
		
		// 10:////////////   ROUND   /////////////
				if SameText(functionName,'round') then begin 
					if (separatorsCount > 1) or (partsCount < 1) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					
					if not (SameText(type1,'3')) then 
						raise Exception.Create(Format('The first argument is no numeric type. functionName: %s, argument: %s',[functionName, strValue1]));
				
					tmpInt := 0;
					
					if partsCount > 2 then begin
						type2 := formulaPartTypes[2];
						strValue2 := formulaParts[2];
						if not (SameText(type2,'3')) then 
							raise Exception.Create(Format('The second argument is no numeric type. functionName: %s, argument: %s',[functionName, strValue2]));
						tmpInt := StrToInt(strValue2);
					end;
				
					floatValue1 := StrToFloat(strValue1);
					resultFloat := RoundTo(floatValue1,tmpInt*-1);
					resultStr := FormatFloat('0.##########;-0.##########;"0"',resultFloat);
					resultType := '3';
					// break;
				end;
		
		// 11:////////////   SIGN   /////////////
				if SameText(functionName,'sign') then begin 
					if not ((separatorsCount = 0) and (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					
					if not (SameText(type1,'3') or SameText(type1,'8')) then 
						raise Exception.Create(Format('The first argument is no numeric or boolean value. functionName: %s, argument: %s',[functionName, strValue1]));

					if SameText(type1,'3') then begin 
						floatValue1 := StrToFloat(strValue1);
						if floatValue1 = 0 then
							resultStr := '0';
						if floatValue1 < 0 then 
							resultStr := '-1';
						if floatValue1 > 0 then 
							resultStr := '1';
					end else begin
						resultStr := '0';
						if SameText(strValue1,'true') then
							resultStr := '1';
					end;
				
					resultType := '3';
					// break;
				end;
		
		// 12:////////////   MOD   /////////////
				if SameText(functionName,'mod') then begin 
					if (separatorsCount > 1) or (not (partsCount = 3)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					type2 := formulaPartTypes[2];
					strValue2 := formulaParts[2];
							
					if not (SameText(type1,'3') and SameText(type2,'3')) then 
						raise Exception.Create(Format('At least one of the arguments is no numeric type. functionName: %s, first argument: %s, second argument: %s',[functionName, strValue1, strValue2]));
				
					floatValue1 := StrToFloat(strValue1);
					floatValue2 := StrToFloat(strValue2);
					resultFloat := floatValue1 - floatValue2 * Int(floatValue1 / floatValue2);
					resultBool := (floatValue1 < 0) xor (floatValue2 < 0);
					if resultBool then 
						resultFloat := resultFloat + floatValue2;
					resultStr := FormatFloat('0.##########;-0.##########;"0"',resultFloat);
					resultType := '3';
					// break;
				end;
		
		// 13:////////////   POWER   /////////////
				if SameText(functionName,'power') then begin 
					if not ((separatorsCount = 1) and (partsCount > 1) and (partsCount < 4)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					
					if not SameText(type1,'3') then 
						raise Exception.Create(Format('The first argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue1]));
					floatValue1 := StrToFloat(strValue1);
					
					floatValue2 := 0;
					if partsCount = 3 then begin 
						type2 := formulaPartTypes[2];
						strValue2 := formulaParts[2];
							
						if not SameText(type2,'3') then 
							raise Exception.Create(Format('The second argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue2]));

						floatValue2 := StrToFloat(strValue2);
					end;
					
					if floatValue1 = 0 then begin
						resultStr := 0;
					end else begin
						
						resultFloat := Power(floatValue1,floatValue2);
						resultStr := FormatFloat('0.##########;-0.##########;"0"',resultFloat);
					end;
					resultType := '3';
					// break;
				end;
		
		// 14:////////////   MAX   /////////////
				if SameText(functionName,'max') then begin 
					if not (partsCount > 0) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultFloat := 0;
					
					i := 0;
					resultBool := false; 
					while i < partsCount do begin
						type1 := formulaPartTypes[i];
						
						if SameText(type1,'7') then begin
							if i > 0 then begin
								if SameText(formulaPartTypes[i-1],'7') then begin
									resultBool := true;
									if 0 > resultFloat then
										resultFloat := 0;
								end;
							end else begin
								if (i = 0) or (i = (partsCount-1)) then begin
									resultBool := true;
									if 0 > resultFloat then
										resultFloat := 0;
								end;
							end;
						end else begin
							strValue1 := formulaParts[i];
							if not SameText(type1,'3') then 
								raise Exception.Create(Format('At least one of the arguments is no numeric value. functionName: %s, argument: %s',[functionName, strValue1]));
							
							if not resultBool then begin //always initialize with the first value
								resultFloat := StrToFloat(strValue1);
								resultBool := true;
							end else begin
								floatValue1 := StrToFloat(strValue1);
								if floatValue1 > resultFloat then 
									resultFloat := floatValue1;
							end;
						end;
						
						inc(i);
					end;
					resultStr := FormatFloat('0.##########;-0.##########;"0"',resultFloat);
					resultType := '3';
					// break;
				end;
		
		// 15:////////////   MIN   /////////////
				if SameText(functionName,'min') then begin 
					if not (partsCount > 0) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultFloat := 0;
					
					i := 0;
					resultBool := false; 
					while i < partsCount do begin
						type1 := formulaPartTypes[i];
						
						if SameText(type1,'7') then begin
							if i > 0 then begin
								if SameText(formulaPartTypes[i-1],'7') then begin
									resultBool := true;
									if 0 < resultFloat then
										resultFloat := 0;
								end;
							end else begin
								if (i = 0) or (i = (partsCount-1)) then begin
									resultBool := true;
									if 0 < resultFloat then
										resultFloat := 0;
								end;
							end;
						end else begin
							strValue1 := formulaParts[i];
							if not SameText(type1,'3') then 
								raise Exception.Create(Format('At least one of the arguments is no numeric value. functionName: %s, argument: %s',[functionName, strValue1]));
							
							if not resultBool then begin //always initialize with the first value
								resultFloat := StrToFloat(strValue1);
								resultBool := true;
							end else begin
								floatValue1 := StrToFloat(strValue1);
								if floatValue1 < resultFloat then 
									resultFloat := floatValue1;
							end;
						end;
						
						inc(i);
					end;
					resultStr := FormatFloat('0.##########;-0.##########;"0"',resultFloat);
					resultType := '3';
					// break;
				end;
		
		// 16:////////////   SUM   /////////////
				if SameText(functionName,'sum') then begin 
					if not (partsCount > 0) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					//set default values - none 					
					//read parameters
					ReadParameters(separatorsCount + 1, formulaParts, formulaPartTypes, parameters, parameterTypes);
					
					resultFloat := 0;
					i := 0;
					while i < parameters.Count do begin
						type1 := parameterTypes.ValueFromIndex[i];
						if not SameText(type1,'3') then 
							raise Exception.Create(Format('At least one of the arguments is no numeric value. functionName: %s, formula: %s',[functionName, formula]));
						strValue1 := parameters.ValueFromIndex[i];
						floatValue1 := StrToFloat(strValue1);
						resultFloat := resultFloat + floatValue1;
						inc(i);
					end;
					
					resultStr := FormatFloat('0.##########;-0.##########;"0"',resultFloat);
					resultType := '3';
					// break;
				end;
		
		// 17:////////////   ISODD   /////////////
				if SameText(functionName,'isOdd') then begin 
					if not ((separatorsCount = 0) and (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					
					if not SameText(type1,'3') then 
						raise Exception.Create(Format('The first argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue1]));
					
					floatValue1 := StrToFloat(strValue1);
					
					//resultBool := Odd(floatValue1); //does not work in xEdit scripts -> use modulo		
					floatValue2 := 2;
					resultFloat := floatValue1 mod floatValue2; //works with built in modulo function, no need to calculate it manually
					//resultFloat := floatValue1 - floatValue2 * Int(floatValue1 / floatValue2);
					// resultBool := (floatValue1 < 0) xor (floatValue2 < 0);
					// if resultBool then 
						// resultFloat := resultFloat + floatValue2;
					
					resultBool := not(resultFloat = 0);
					
					if resultBool then begin
						resultStr := 'true';
					end else begin
						resultStr := 'false';
					end;
					resultType := '8';
					// break;
				end;
		
		// 18:////////////   ISEVEN   /////////////
				if SameText(functionName,'isEven') then begin 
					if not ((separatorsCount = 0) and (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					
					if not SameText(type1,'3') then 
						raise Exception.Create(Format('The first argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue1]));
					
					floatValue1 := StrToFloat(strValue1);
					
					//resultBool := Odd(floatValue1); //does not work in xEdit scripts -> use modulo		
					floatValue2 := 2;
					resultFloat := floatValue1 mod floatValue2; //works with built in modulo function, no need to calculate it manually
					//resultFloat := floatValue1 - floatValue2 * Int(floatValue1 / floatValue2);
					// resultBool := (floatValue1 < 0) xor (floatValue2 < 0);
					// if resultBool then 
						// resultFloat := resultFloat + floatValue2;
					
					resultBool := (resultFloat = 0);
					
					if resultBool then begin
						resultStr := 'true';
					end else begin
						resultStr := 'false';
					end;
					resultType := '8';
					// break;
				end;
		
		// 19:////////////   ISNUMBER   /////////////
				if SameText(functionName,'isNumber') then begin 
					if not ((separatorsCount = 0) and (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					
					if SameText(type1,'3') then begin
						resultStr := 'true';
					end else begin
						resultStr := 'false';
					end;
					
					resultType := '8';
					// break;
				end;
		
		// 20:////////////   DEC2HEX   /////////////
				if SameText(functionName,'dec2hex') then begin 
					if not ((separatorsCount < 2) and (partsCount > 0) and (partsCount < 4)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					
					if not (SameText(type1,'3')) then 
						raise Exception.Create(Format('The first argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue1]));
						
					floatValue1 := StrToFloat(strValue1);
					intValue1 := Int(floatValue1);

					intValue2 := -1;
					if partsCount = 3 then begin
						type2 := formulaPartTypes[2];
						strValue2 := formulaParts[2];
								
						if not (SameText(type2,'3')) then 
							raise Exception.Create(Format('The second argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue2]));
								
						floatValue2 := StrToFloat(strValue2);
						intValue2 := Int(floatValue2);
					end;
					
					//how it is used in some xEdit internals
					//IntToHex64((FormID.ToCardinal and $00FFFFFF),6)
					//IntToHex64(wbCRC32App, 8)
					//IntToHex(Int64(Cardinal(CurrentRec.Signature)), 8)
					//IntToHex(i, 3)
					//RecordByFormID(f, StrToInt('$' + id), true);
				
					resultStr := IntToHex64(intValue1, intValue2);
					resultType := '1';
					// break;
				end;
		
		// 21:////////////   HEX2DEC   /////////////
				if SameText(functionName,'hex2dec') then begin 
					if not ((separatorsCount = 0) and (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					
					intValue1 := StrToInt('$'+strValue1);
					//floatValue1 := StrToFloat('$'+strValue1);
					
					resultStr := IntToStr(intValue1);
					//resultStr := FormatFloat('0.##########;-0.##########;"0"',floatValue1);
					resultType := '3';
					// break;
				end;
		
		// 22:////////////   UPPER   /////////////
				if SameText(functionName,'upper') then begin 
					if (separatorsCount > 0) or (not (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
							
					resultStr := UpperCase(strValue1);
					resultType := '1';
					// break;
				end;
		
		// 23:////////////   LOWER   /////////////
				if SameText(functionName,'lower') then begin 
					if (separatorsCount > 0) or (not (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
							
					resultStr := LowerCase(strValue1);
					resultType := '1';
					// break;
				end;
				
		// 24:////////////   LEFT   /////////////
				if SameText(functionName,'left') then begin 
					if (separatorsCount > 1) or (partsCount < 1) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					tmpInt := 1;
					
					if partsCount > 2 then begin
						type2 := formulaPartTypes[2];
						strValue2 := formulaParts[2];
						
						if not (SameText(type2,'3')) then 
							raise Exception.Create(Format('The second argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue2]));
						
						tmpInt := StrToInt(strValue2);
					end;
					
					resultStr := Copy(strValue1,1,tmpInt);
					resultType := '1';
					// break;
				end;
		
		// 25:////////////   RIGHT   /////////////
				if SameText(functionName,'right') then begin 
					if (separatorsCount > 1) or (partsCount < 1) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					tmpInt := 1;
					
					if partsCount > 2 then begin
						type2 := formulaPartTypes[2];
						strValue2 := formulaParts[2];
						
						if not (SameText(type2,'3')) then 
							raise Exception.Create(Format('The second argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue2]));
						
						tmpInt := StrToInt(strValue2);
					end;
					
					resultStr := ReverseString(Copy(ReverseString(strValue1),1,tmpInt));
					resultType := '1';
					// break;
				end;
		
		// 26:////////////   MID   /////////////
				if SameText(functionName,'mid') then begin 
					if (separatorsCount < 1) or (separatorsCount > 2) or (partsCount < 3) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					type2 := formulaPartTypes[2];
					strValue2 := formulaParts[2];
					
					if not SameText(type2,'3') then 
						raise Exception.Create(Format('The second argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue2]));
					intValue2 := StrToInt(strValue2);
					
					tmpInt := 1;
					
					if partsCount > 4 then begin
						type2 := formulaPartTypes[4]; //re-used
						strValue2 := formulaParts[4];
						
						if not (SameText(type2,'3')) then 
							raise Exception.Create(Format('The third argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue2]));
						
						tmpInt := StrToInt(strValue2);
					end;
					
					resultStr := Copy(strValue1,intValue2,tmpInt);
					resultType := '1';
					// break;
				end;
		
		// 27:////////////   TRIM   /////////////
				if SameText(functionName,'trim') then begin 
					if (separatorsCount > 0) or (not (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
							
					resultStr := Trim(strValue1);
					resultType := '1';
					// break;
				end;
		
		// 28:////////////   TRIMLEFT   /////////////
				if SameText(functionName,'trimLeft') then begin 
					if (separatorsCount > 0) or (not (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
							
					resultStr := TrimLeft(strValue1);
					resultType := '1';
					// break;
				end;
		
		// 29:////////////   TRIMRIGHT   /////////////
				if SameText(functionName,'trimRight') then begin 
					if (separatorsCount > 0) or (not (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
							
					resultStr := TrimRight(strValue1);
					resultType := '1';
					// break;
				end;
		
		
		// 30:////////////   LEN   /////////////
				if SameText(functionName,'len') then begin 
					if (separatorsCount > 0) or (not (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
							
					resultStr := Length(strValue1);
					resultType := '3';
					// break;
				end;
		
		// 31:////////////   TEXT   /////////////
				if SameText(functionName,'text') then begin 
					if (separatorsCount > 1) or (partsCount < 1) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					
					if SameText(type1,'3') then 
						floatValue1 := StrToFloat(strValue1);
					
					if partsCount > 2 then begin
						type2 := formulaPartTypes[2];
						strValue2 := formulaParts[2];
						
						if not (SameText(type2,'1')) then 
							raise Exception.Create(Format('The second argument is no string value. functionName: %s, argument: %s',[functionName, strValue2]));
						
						if SameText(type1,'3') then begin
							resultStr := FormatFloatWithExcelFormatString(strValue2,floatValue1);
						end else begin
							resultStr := FormatStringWithExcelFormatString(strValue2,strValue1);
						end;
					end else begin //this is how Excel behaves if no format was given
						if SameText(type1,'3') then begin 
							resultStr := FormatFloat('"";-"";""',floatValue1); 
						end else begin
							resultStr := strValue1;
						end;
					end;
					
					resultType := '1';
					// break;
				end;
		
		// 32:////////////   VALUE   /////////////
				if SameText(functionName,'value') then begin 
					if (separatorsCount > 0) or (partsCount < 1) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					
					// DebugLog(Format('strValue1: %s',[strValue1]));
					
					type2 := '1'; //string
					strValue2 := ''; //default default value
					
					if partsCount > 2 then begin
						type2 := formulaPartTypes[2];
						strValue2 := formulaParts[2]; //defined default value
					end;
					
					if SameText(type1,'3') then begin
						resultStr := strValue1;
						resultType := type1;
					end else begin
						if SameText(type2,'8') then begin //bool -> always return default value
							resultStr := strValue2;
							resultType := type2;
						end else begin 
							//val(strValue1,floatValue1,tmpInt); //not allowed in xEdit scripts
							if isNumeric(strValue1) then begin
								floatValue1 := StrToFloat(strValue1);
								resultStr := FormatFloat('0.##########;-0.##########;"0"',floatValue1);
								resultType := '3';
							end else begin
								resultStr := strValue2;
								resultType := type2;
							end;
						end;
					end;
					// break;
				end;
		
		// 33:////////////   SEARCH   /////////////
				if SameText(functionName,'search') then begin 
					if (separatorsCount < 1) or (separatorsCount > 2) or (partsCount < 3) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					//set default values 
					parameters.Values['2'] := '1';
					parameterTypes.Values['2'] := '3';
					
					//read parameters
					ReadParameters(3, formulaParts, formulaPartTypes, parameters, parameterTypes);
					strValue1 := parameters.Values['0'];//findText
					strValue2 := parameters.Values['1'];//withinText
					tmpStr := parameters.Values['2'];//startPos 
					type1 := parameterTypes.Values['2'];//startPos type
					if not (SameText(type1,'3')) then 
						raise Exception.Create(Format('The third argument is no numeric value. functionName: %s, formula: %s',[functionName, formula]));
					intValue1 := StrToInt(tmpStr);
					
					resultStr := '0';
					intValue2 := Pos(strValue1,Copy(strValue2,intValue1,Length(strValue2)-intValue1+1));
					if intValue2 > 0 then begin
						intValue2 := intValue2 + intValue1 - 1;
						resultStr := IntToStr(intValue2);
					end;
					
					resultType := '3';
					// break;
				end;
		
		// 34:////////////   SEARCHCOUNT   /////////////
				if SameText(functionName,'searchCount') then begin 
					if (separatorsCount < 1) or (separatorsCount > 3) or (partsCount < 3) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					//set default values - none 
					parameters.Values['2'] := '1';
					parameters.Values['3'] := '0';
					parameterTypes.Values['2'] := '3';
					parameterTypes.Values['3'] := '3';
					
					//read parameters
					ReadParameters(4, formulaParts, formulaPartTypes, parameters, parameterTypes);
					strValue1 := parameters.Values['0'];//findText
					strValue2 := parameters.Values['1'];//withinText
					type1 := parameterTypes.Values['2'];//startPos type
					type2 := parameterTypes.Values['3'];//endPos type
					if not (SameText(type1,'3')) then 
						raise Exception.Create(Format('The third argument is no numeric value. functionName: %s, formula: %s',[functionName, formula]));
					intValue1 := StrToInt(parameters.Values['2']);
					if not (SameText(type2,'3')) then 
						raise Exception.Create(Format('The fourth argument is no numeric value. functionName: %s, formula: %s',[functionName, formula]));
					intValue2 := StrToInt(parameters.Values['3']);
					
					resultStr := IntToStr(CountStringInString(strValue1, strValue2, intValue1, intValue2));
					resultType := '3';
					// break;
				end;
		
		// 35:////////////   SUBSTITUTE   /////////////
				if SameText(functionName,'substitute') then begin 
					if (separatorsCount < 2) or (separatorsCount > 3) or (partsCount < 5) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultStr := formulaParts[0];
					strValue1 := formulaParts[2];
					strValue2 := formulaParts[4];
					
					if partsCount > 6 then begin
						type2 := formulaPartTypes[6]; //re-used
						tmpStr := formulaParts[6];
						
						if not (SameText(type2,'3')) then 
							raise Exception.Create(Format('The fourth argument is no numeric value. functionName: %s, argument: %s',[functionName, tmpStr]));
						
						intValue1 := StrToInt(tmpStr);
						
						if intValue1 = 1 then begin //do not waste time with looping when a normal function does the job
							resultStr := StringReplace(resultStr, strValue1, strValue2, [rfIgnoreCase]);
						end else begin
							
							i := 0; //this is our counter
							tmpInt := Pos(strValue1,resultStr);
							intValue2 := 0;
							while tmpInt > 0 do begin
								inc(i);
								intValue2 := intValue2 + tmpInt;
								
								if i = intValue1 then begin
									resultStr := Copy(resultStr, 1, intValue2 - 2) 
										+ strValue2 
										+ Copy(resultStr, intValue2 + Length(strValue1) - 1, Length(resultStr) - intValue2 - Length(strValue1) + 2);
									break;
								end;
								
								intValue2 := intValue2 + Length(strValue1);
								tmpStr := Copy(resultStr, intValue2, Length(resultStr) - intValue2 + 1);
								tmpInt := Pos(strValue1, tmpStr);
							end;
						end;
					end else begin
						resultStr := StringReplace(resultStr, strValue1, strValue2, [rfIgnoreCase,rfReplaceAll]);
					end;
					
					resultType := '1';
					// break;
				end;
		
		// 36:////////////   REPLACE   /////////////
				if SameText(functionName,'replace') then begin 
					if not ((separatorsCount = 3) and (partsCount = 7)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultStr := formulaParts[0];
					strValue1 := formulaParts[6];
					
					type2 := formulaPartTypes[2];
					strValue2 := formulaParts[2];
					if not SameText(type2,'3') then
						raise Exception.Create(Format('The second argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue2]));
					intValue1 := StrToInt(strValue2);
					
					type2 := formulaPartTypes[4];
					strValue2 := formulaParts[4];
					if not SameText(type2,'3') then
						raise Exception.Create(Format('The third argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue2]));
					intValue2 := StrToInt(strValue2);
					
					if (intValue1 > 0) and (intValue2 >= 0) then begin
						resultStr := Copy(resultStr, 1, intValue1 - 1)
							+ strValue1
							+ Copy(resultStr, intValue1 + intValue2, Length(resultStr) - intValue1 - intValue2 + 1);
					end;
					
					resultType := '1';
					// break;
				end;
		
		// 37:////////////   REPT   /////////////
				if SameText(functionName,'rept') then begin 
					if not ((separatorsCount = 1) and (partsCount = 3)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultStr := '';
					strValue1 := formulaParts[0];
					strValue2 := formulaParts[2];
					type2 := formulaPartTypes[2];
					
					if not SameText(type2,'3') then
						raise Exception.Create(Format('The second argument is no numeric value. functionName: %s, argument: %s',[functionName, strValue2]));
					intValue2 := StrToInt(strValue2);
					
					resultStr := RepeatString(strValue1, intValue2);
					
					resultType := '1';
					// break;
				end;
		
		// 38:////////////   CONCAT   /////////////
				if SameText(functionName,'concat') then begin 
					resultStr := '';
					
					i := 0;
					while i < partsCount do begin
						if not SameText(formulaPartTypes[i],'7') then 
							resultStr := resultStr + formulaParts[i];
						inc(i);
					end;
					
					resultType := '1';
					// break;
				end;
		
		// 39:////////////   TEXTJOIN   /////////////
				if SameText(functionName,'textJoin') then begin 
					if not ((separatorsCount > 1) and (partsCount > 2)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					//set default values 
					parameters.Values['1'] := 'true' ;//ignoreEmptyValues
					
					//read parameters
					ReadParameters(separatorsCount + 1, formulaParts, formulaPartTypes, parameters, parameterTypes);
					strValue1 := parameters.Values['0'];//delimiter
					resultBool :=  SameText(parameters.Values['1'],'true'); //used for condition
					
					resultStr := '';
					i := 2;
					counter := 0;
					while i < (separatorsCount + 1) do begin						
						tmpStr := parameters.Values[IntToStr(i)];
						if (not resultBool) or (not SameText(tmpStr,'')) then begin
							if counter = 0 then begin
								resultStr := tmpStr;
							end else begin
								resultStr := resultStr + strValue1 + tmpStr;
							end;
							inc(counter);
						end;
						inc(i);
					end;
					
					resultType := '1';
					// break;
				end;
		
		// 40:////////////   FORMULATEXT   /////////////
				if SameText(functionName,'formulaText') then begin 
					if not ((separatorsCount = 0) and (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					strValue1 := formulaParts[0];
					
					if not SameText(type1,'5') then
						raise Exception.Create(Format('The argument is no variable name. functionName: %s, argument: %s',[functionName, strValue1]));
					
					resultStr := formulas.Values[strValue1];
					resultType := '1';
					// break;
				end;
		
		// 41:////////////   ISTEXT   /////////////
				if SameText(functionName,'isText') then begin 
					if not ((separatorsCount = 0) and (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					type1 := formulaPartTypes[0];
					
					if SameText(type1,'1') then begin
						resultStr := 'true';
					end else begin
						resultStr := 'false';
					end;
					
					resultType := '8';
					// break;
				end;
		
		// 42:////////////   LINEBREAK   /////////////
				if SameText(functionName,'linebreak') then begin 
					if (partsCount > 0) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultType := '1';
					resultStr := chr(13) + chr(10);
					// break;
				end;
		
		// ???:////////////   CALCULATE   /////////////
				if SameText(functionName,'Calculate') then begin 
					if not (formulaParts.Count = 1) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					//formulaPartTypes[0] := 2;
					resultStr := ParseFormula(variableName, formulaParts[0], formulas, results, resultTypes, operators, functions, outerTempVariables, recursionLevel+1, false);
					resultType := Copy(resultStr,1,1);
					resultStr := Copy(resultStr,3,Length(resultStr)-2);
					// break;
				end;

		// 43:////////////   TRANSPOSE   /////////////
				if SameText(functionName,'transpose') then begin 
					if (partsCount < 1) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					//set default values
					parameters.Values['1'] := ',';
					parameters.Values['2'] := chr(13) + chr(10);
					
					//read parameters
					ReadParameters(3, formulaParts, formulaPartTypes, parameters, parameterTypes);
					resultStr := parameters.Values['0'];
					strValue1 := parameters.Values['1'];
					strValue2 := parameters.Values['2'];
					
					if SameText(parameterTypes[0], '') then 
						raise Exception.Create(Format('The first argument was not provided. functionName: %s',[functionName]));

					resultType := '1';
					resultStr := TransposeTableString(resultStr, strValue1, strValue2);
					// break;
				end;
		
		// 44:////////////   LOGMSG   /////////////
				if SameText(functionName,'logMsg') then begin 
					if not (partsCount > 0) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					//set default values
					parameterTypes.Values['1'] := '1';
					
					//read parameters
					ReadParameters(2, formulaParts, formulaPartTypes, parameters, parameterTypes);
					tmpStr := parameters.Values['0'];
					resultStr := parameters.Values['1'];
					resultType := parameterTypes.Values['1'];
					
					Log(tmpStr);
					// break;
				end;
		
		// 45:////////////   WITH   /////////////
				if SameText(functionName,'with') then begin 
					if not ((separatorsCount = 0) and (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultType := formulaPartTypes[0];
					resultStr := formulaParts[0];
					// break;
				end;
		
		// 46:////////////   FUNCTION   /////////////
				if SameText(functionName,'function') then begin 
					if not ((separatorsCount = 0) and (partsCount = 1)) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultType := formulaPartTypes[0];
					resultStr := formulaParts[0];
					// break;
				end;
		
		// 47:////////////   ENDCALCULATION   /////////////
				if SameText(functionName,'endCalculation') then begin 
					if (partsCount > 1) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					FormulaParserStopExecution := true;
					
					//set default values
					parameterTypes.Values['0'] := '1';
					
					//read parameters
					ReadParameters(1, formulaParts, formulaPartTypes, parameters, parameterTypes);
					resultStr := parameters.Values['0'];
					resultType := parameterTypes.Values['0'];
					// break;
				end;
		
		// 48:////////////   GETOUTPUT   /////////////
				if SameText(functionName,'GetOutput') then begin 
					if (partsCount > 0) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					resultType := '1';
					resultStr := results.Values['---OUTPUT---'];
					// break;
				end;
		
		// 49:////////////   SETOUTPUT   /////////////
				if SameText(functionName,'SetOutput') then begin 
					if (partsCount > 3) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					//set default values - none
					
					//read parameters
					ReadParameters(2, formulaParts, formulaPartTypes, parameters, parameterTypes);
					strValue1 := parameters.Values['0'];
					strValue2 := parameters.Values['1'];
					type1 := parameterTypes.Values['0'];
					type2 := parameterTypes.Values['1'];
					
					tmpStr := '';
					if SameText(type1,'') then begin //if the first parameter is not provided
						//first remove the output, then read it
						results.Values['---OUTPUT---'] := '';
						tmpStr := results.Text;
					end else begin
						tmpStr := strValue1;
					end;
					
					results.Values['---OUTPUT---'] := tmpStr;
					
					resultStr := strValue2;
					resultType := type2;
					if SameText(resultType,'') then
						resultType := '1';
					// break;
				end;
		
		// 51:////////////   SELECTEDRECORDS   /////////////
				if SameText(functionName,'SelectedRecords') then begin 
					if (partsCount > 2) then 
						raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: %s, formula: %s',[functionName, formula]));
					
					//set default values
					parameters.Values['0'] := ';';
					
					//read optional parameters
					ReadParameters(2, formulaParts, formulaPartTypes, parameters, parameterTypes);
					strValue1 := parameters.Values['0'];
					strValue2 := parameters.Values['1'];
					
					resultStr := results.Values['---SELECTEDRECORDS---'];
					
					if SameText(strValue2, '') then begin
						if not SameText(strValue1,';') then 
							resultStr := StringReplace(resultStr, ';', strValue1, [rfIgnoreCase,rfReplaceAll]);
					end else begin
						StringToStringList(resultStr, ';', tmpList);
						resultStr := '';
						
						//add temporary variable for record and call formula
						CopyList(outerTempVariables, tempVariables);
						i := 0;
						while i < tmpList.Count do begin
							curItm := tmpList[i];
							tempVariables.Values['rec'] := '1|' + curItm;
							tempVariables.Values['i'] := '3|' + IntToStr(i + 1);
							tmpStr := ParseFormula(Format('%s_rec%d',[variableName,i]), strValue2, formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel+1, false);
							tmpStr := Copy(tmpStr, 3, Length(tmpStr));
							//if it returns true
							if i = 0 then begin
								resultStr := tmpStr;
							end else begin
								resultStr := resultStr + strValue1 + tmpStr;
							end;
							inc(i);
						end;
					end;
					
					resultType := '1';
					// break;
				end;
		
		// 52:////////////   READRECORDS   /////////////
				if SameText(functionName,'ReadRecords') then begin 
					resultStr := ParseReadRecords(variableName, formula, formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel, formulaParts, formulaPartTypes, parameters, parameterTypes);
					resultType := '1';
					// break;
				end;
		
		// ???:////////////   FINDRECORDS   /////////////
				if SameText(functionName,'FindRecords') then begin 
					resultStr := ParseFindRecords(variableName, formula, formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel, formulaParts, formulaPartTypes, parameters, parameterTypes);
					resultType := '1';
					// break;
				end;
	
	finally
		parameters.Free;
		parameters := nil;
		parameterTypes.Free;
		parameterTypes := nil;
		tmpList.Free;
		tmpList := nil;
	end;
		
	if partsCount > 0 then begin 
		//empty out all the formula parts except the first one and set the result
		for i := partsCount-1 downto 1 do begin 
			formulaParts.Delete(i);
			formulaPartTypes.Delete(i);
		end;
		
		formulaParts[0] := resultStr;
		formulaPartTypes[0] := resultType;
	end else begin 
		formulaParts.Add(resultStr);
		formulaPartTypes.Add(resultType);
	end;
		
	//there can only be one result per section left (i.e. between separators)
	partsCount := formulaParts.Count;
	if (partsCount > 1) then begin
		raise Exception.Create(Format('The formula could not be completely calculated. formula: %s, parts left: %s',[formula,formulaParts.Text]));
	end;
	
	Result:= resultStr;
	
	DebugLog(Format('Function calculated. functionName: %s, result: %s',[
		functionName,
		resultStr
		]));
	
	LogFunctionEnd;
end;

//=========================================================================
//  read parameters from formula parts, overwriting default parameters
//=========================================================================
procedure ReadParameters(const maxParameters : Integer; const formulaParts, formulaPartTypes : TStringList; parameters, parameterTypes : TStringList;);
var
	i, partsCount, curSeparator : Integer;
	tmpStr : String;
begin
	partsCount := formulaParts.Count;

	//read optional parameters
	i := 0;
	curSeparator := 0;
	while curSeparator < maxParameters do begin
		// stop the loop if we counted higher than the number of parameters that are present
		if (i >= partsCount) then 
			break;
		// DebugLog(Format('curSeparator: %d, i: %d',[curSeparator, i]));
		
		if SameText(formulaPartTypes[i],'7') then begin
			// if parameters.IndexOfName(IntToStr(curSeparator)) <= -1 then
				// parameters.Add(IntToStr(curSeparator)+'=');
			inc(i);
			inc(curSeparator);
		end;
		
		// stop the loop if we counted higher than the number of parameters that are present
		if (i >= partsCount) then 
			break;
		// DebugLog(Format('curSeparator: %d, i: %d, formulaPartTypes[i]: %s, formulaParts[i]: %s, partsCount: %d',[curSeparator, i, formulaPartTypes[i], formulaParts[i], partsCount]));
		
		if SameText(formulaPartTypes[i],'7') then begin
			// if parameters.IndexOfName(IntToStr(curSeparator)) <= -1 then
				// parameters.Add(IntToStr(curSeparator)+'=');
		end else begin
			tmpStr := formulaParts[i];
			if SameText(tmpStr, '') then begin
				if parameters.IndexOfName(IntToStr(curSeparator)) <= -1 then
					parameters.Add(IntToStr(curSeparator)+'=');
			end else begin
				parameters.Values[IntToStr(curSeparator)] := formulaParts[i];
			end;
			parameterTypes.Values[IntToStr(curSeparator)] := formulaPartTypes[i];
			inc(i);
		end;
	end;
	
	// DebugLog(Format('parameters: %s, curSeparator: %d, i: %d',[parameters.Text, curSeparator, i]));
	
end;


//=========================================================================
//  calculate SWITCH compare values that are needed to decide which option is to select
//=========================================================================
procedure CalculateSwitchCompareValues(const variableName : String; formula : String; const formulas : TStringList; results, resultTypes : TStringList; const operators, functions : TStringList; tempVariables : TStringList; const recursionLevel : Integer; const isFunction : Boolean; formulaParts, formulaPartTypes : TStringList;);
var
	i, partsCount, separatorsCount, numberOfOptions, defaultOptionIndex, curOption, curSeparator : Integer;
	tmpStr, optionResultStr, optionResultType, compareStr, compareType : String;
begin
	LogFunctionStart('CalculateSwitch');
		
	partsCount := formulaParts.Count;
	
	separatorsCount := 0;
	i := 0;
	while i < partsCount do begin
		if SameText(formulaPartTypes[i],'7') then
			inc(separatorsCount);
		inc(i);
	end;
	
	if not (separatorsCount > 1) then 
			raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: switch, number of arguments: %d',[partsCount-separatorsCount]));
		
	defaultOptionIndex := 0;
	//is there a default option?
	if not((separatorsCount mod 2) = 0) then 
		defaultOptionIndex := partsCount - 1;
	
	//how many options are there?
	if defaultOptionIndex > 0 then begin
		numberOfOptions := (separatorsCount - 1) / 2;
	end else begin
		numberOfOptions := separatorsCount / 2;
	end;
	
	// DebugLog(Format('partsCount: %d, separatorsCount: %d, lookupStr: %s, defaultOptionIndex: %d, numberOfOptions: %d, defaultOptionType: %s, defaultOptionStr: %s',[partsCount, separatorsCount, lookupStr, defaultOptionIndex, numberOfOptions, defaultOptionType, defaultOptionStr]));
	
	curSeparator := 0;
	i := 0;
	for curOption := 1 to numberOfOptions do begin
		//spool forward to the part before the one we want to read
		while curSeparator < (((curOption - 1) * 2) + 1) do begin
			if SameText(formulaPartTypes[i+1],'7') then
				inc(curSeparator);
			inc(i);
		end;
		//now we are at the separator directly before the compareValue -> move to the next part
		
		// DebugLog(Format('separator before compare-Value. curOption: %d, curSeparator: %d, i: %d ',[curOption, curSeparator, i]));
		
		inc(i);
		if not SameText(formulaPartTypes[i],'7') then begin 
			//the compareValue was explicitly set
			compareStr := formulaParts[i];
			compareType := formulaPartTypes[i];
			
			if SameText(compareType,'2') then begin
				//calculate compareValue
				tmpStr := ParseFormula(Format('%s_part%d',[variableName,i]), compareStr, formulas, results, resultTypes, operators, functions, tempVariables, recursionLevel+1, false);
				formulaPartTypes[i] := Copy(tmpStr,1,1);
				formulaParts[i] := Copy(tmpStr,3,Length(tmpStr)-2);
			end;
			
			inc(i);
			inc(curSeparator);
		end else begin
			inc(curSeparator);
		end;
	end;

	LogFunctionEnd;
end;

//=========================================================================
//  calculate a SWITCH function
//=========================================================================
function CalculateSwitch(const separatorsCount: Integer; const formulaParts, formulaPartTypes : TStringList;) : String;
var
	i, partsCount, tmpInt, numberOfOptions, defaultOptionIndex, curOption, curSeparator, pickResult : Integer;
	resultStr, resultType, tmpStr, lookupStr, compareStr, optionResultStr, optionResultType, defaultOptionType, defaultOptionStr : String;
	optionPicked : Boolean;
begin
	LogFunctionStart('CalculateSwitch');
	
	partsCount := formulaParts.Count;
	
	if not (separatorsCount > 1) then 
			raise Exception.Create(Format('Function is supplied with the wrong number of arguments. functionName: switch, number of arguments: %d',[partsCount-separatorsCount]));
	
	//this is the value we will look up in our switch
	lookupStr := '0';
	if not SameText(formulaPartTypes[0],'7') then begin
		lookupStr := formulaParts[0];
	end;
		
	//default: empty string
	resultType := '1'; 
	resultStr := '';
	
	defaultOptionType := '3';
	defaultOptionStr := '0';
		
	defaultOptionIndex := 0;
	//is there a default option?
	if not((separatorsCount mod 2) = 0) then begin
		defaultOptionIndex := partsCount - 1;
		
		tmpStr := formulaPartTypes[defaultOptionIndex];
		if not SameText(tmpStr,'7') then begin
			defaultOptionType := tmpStr;
			defaultOptionStr := formulaParts[defaultOptionIndex];
		end;
	end;
	
	//how many options are there?
	if defaultOptionIndex > 0 then begin
		numberOfOptions := (separatorsCount - 1) / 2;
	end else begin
		numberOfOptions := separatorsCount / 2;
	end;
	
	// DebugLog(Format('partsCount: %d, separatorsCount: %d, lookupStr: %s, defaultOptionIndex: %d, numberOfOptions: %d, defaultOptionType: %s, defaultOptionStr: %s',[partsCount, separatorsCount, lookupStr, defaultOptionIndex, numberOfOptions, defaultOptionType, defaultOptionStr]));
	
	curSeparator := 0;
	i := 0;
	for curOption := 1 to numberOfOptions do begin
		//spool forward to the part before the one we want to read
		while curSeparator < (((curOption - 1) * 2) + 1) do begin
			if SameText(formulaPartTypes[i+1],'7') then
				inc(curSeparator);
			inc(i);
		end;
		//now we are at the separator directly before the compareValue -> move to the next part
		
		// DebugLog(Format('separator before compare-Value. curOption: %d, curSeparator: %d, i: %d ',[curOption, curSeparator, i]));
		
		inc(i);
		compareStr := '0';
		if not SameText(formulaPartTypes[i],'7') then begin 
			//the compareValue was explicitly set
			compareStr := formulaParts[i];
			inc(i);
			inc(curSeparator);
		end else begin
			inc(curSeparator);
		end;
		//now we are at the separator directly before the resultValue
		
		// DebugLog(Format('separator before compareResult-Value. curOption: %d, curSeparator: %d, i: %d, compareStr: %s ',[curOption, curSeparator, i, compareStr]));
		
		inc(i);
		optionResultType := '3';
		optionResultStr := '0';
		if i < partsCount then begin 
			//if we are not looking for a part that does not exist - else stay with the "empty argument" setting
			tmpStr := formulaPartTypes[i];
			if not SameText(tmpStr,'7') then begin 
				optionResultType := tmpStr;
				optionResultStr := formulaParts[i];
				inc(i);
				inc(curSeparator);
			end else begin
				inc(curSeparator);
			end;
		end;
		
		// DebugLog(Format('ready to check if there is a match. curOption: %d, curSeparator: %d, i: %d, optionResultType: %s, optionResultStr: %s',[curOption, curSeparator, i, optionResultType, optionResultStr ]));
		
		if SameText(lookupStr,compareStr) then begin
			resultType := optionResultType;
			resultStr := optionResultStr;
			optionPicked := true;
			break;
		end;
	end;
	
	if (not optionPicked) and (defaultOptionIndex > 0) then begin
		resultType := defaultOptionType;
		resultStr := defaultOptionStr;
	end;

	Result := Format('%s|%s', [resultType, resultStr]);

	LogFunctionEnd;
end;

//=========================================================================
//  check if a string can be converted to a numeric value
//=========================================================================
function isNumeric(const strValue : String;) : Boolean;
var
	i, countComma, countNumber, tmpInt, countNotAllowed : Integer;
	curChar : String;
begin
	LogFunctionStart('FormatFloatWithExcelFormatString');
	
	Result := false;
	if SameText(Trim(strValue),'') then begin
		LogFunctionEnd;
		Exit;
	end;
	
	countComma := 0;
	countNumber := 0;
	countNotAllowed := 0;
	for i := 1 to Length(strValue) do begin
		curChar := Copy(strValue,i,1);
		
		if (i = 1) and (SameText(curChar,'+') or SameText(curChar,'-')) then
			continue;
		
		if SameText(curChar,'.') then begin
			inc(countComma);
			continue;
		end;
			
		if (curChar >= '0') and (curChar <= '9') then begin
			inc(countNumber);
			continue;
		end;
		
		inc(countNotAllowed);
	end;
	
	// DebugLog(Format('countNotAllowed: %d, countNumber: %d, countComma: %d',[countNotAllowed,countNumber,countComma]));
	
	case countNotAllowed of
		0: begin
				case countNumber of 
					0: Result := false;
					else begin 
						case countComma of
							0,1: Result := true;
							else Result := false;
						end;
					end;
				end;
		end;
		else Result := false;
	end;	
	
	LogFunctionEnd;
end;

//=========================================================================
//  calculate the formula parts that only contain base calculations
//=========================================================================
function CalculateFormulaParts(const formula : String; const operators : TStringList; formulaParts, formulaPartTypes : TStringList;) : String;
var
	i, separatorsCount, partsCount, compareResult : Integer;
	operator, resultStr, strValue1, strValue2, resultType, type1, type2 : String;
	onePartIsAString, bothPartsAreNumeric : Boolean;
	floatValue1, floatValue2, resultFloat : Double;
begin
	LogFunctionStart('CalculateFormulaParts');

	Result := '';
	partsCount := formulaParts.Count;
	
	if partsCount=1 then begin
		Result := formulaParts[0];
		LogFunctionEnd;
		Exit;
	end;
	
	if partsCount=2 then begin
		//raise Exception.Create(Format('cannot calculate something if there is only 2 variables. need at least 3 - 2 variables and an operator. formula: %s',[formula]));
		//should allow this situation for functions that allow empty arguments
		Result := formulaParts[0];
		LogFunctionEnd;
		Exit;
	end;
	
	separatorsCount := 0;
	i:= 0;
	while i <= (partsCount-1) do begin
		if SameText(formulaPartTypes[i],'7') then begin
			inc(separatorsCount);
		end;
		inc(i);
	end;
	
	//0:unknown,1:String,2:Formula,3:Numeric,4:Operator,5:Pointer,6:Functions,7:Separator,8:Boolean
	
	i := 1;
	//first calculate / and *
	while i < partsCount-1 do begin 
		resultStr:='';
		
		if SameText(formulaPartTypes[i],'4') then begin
			operator := formulaParts[i];
			type1 := formulaPartTypes[i-1];
			type2 := formulaPartTypes[i+1];
			strValue1 := formulaParts[i-1];
			strValue2 := formulaParts[i+1];
			if SameText(operator,'/') then begin
				if not (SameText(type1,'3') and SameText(type2,'3')) then //3-numeric
					raise Exception.Create(Format('This operator can only be used for calculating numeric values. operator: %s, 1st value: %s, 2nd value: %s, formula: %s',[operator, strValue1, strValue2, formula]));
				floatValue1 := StrToFloat(strValue1);
				floatValue2 := StrToFloat(strValue2);
				resultFloat := floatValue1 / floatValue2;
				resultStr := FormatFloat('0.##########;-0.##########;"0"',resultFloat);
				resultType := '3';
			end else begin
				if SameText(operator,'*') then begin
					if not (SameText(type1,'3') and SameText(type2,'3')) then //3-numeric
						raise Exception.Create(Format('This operator can only be used for calculating numeric values. operator: %s, 1st value: %s, 2nd value: %s, formula: %s',[operator, strValue1, strValue2, formula]));
					floatValue1 := StrToFloat(strValue1);
					floatValue2 := StrToFloat(strValue2);
					resultFloat := floatValue1 * floatValue2;
					resultStr := FormatFloat('0.##########;-0.##########;"0"',resultFloat);
					resultType := '3';
				end;
			end;
		end;
		
		if not SameText(resultStr,'') then begin
			//now replace the 3 parts with one new
			formulaParts.Delete(i+1);
			formulaPartTypes.Delete(i+1);
			formulaParts.Delete(i);
			formulaPartTypes.Delete(i);
			formulaParts[i-1]:=resultStr;
			formulaPartTypes[i-1]:=resultType;
			partsCount := formulaParts.Count;
			if resultType = '3' then 
				DebugLog(Format('Calculation performed. operator: %s, Value1: %s, Value2: %s, result: %s',[
					operator,
					FormatFloat('0.##########;-0.##########;"0"',floatValue1),
					FormatFloat('0.##########;-0.##########;"0"',floatValue2),
					resultStr
					]));
		end else begin
			inc(i);
		end; 
	end;
	
	//then calculate + and -
	i := 1;
	while i < partsCount-1 do begin 
		resultStr:='';
		
		if SameText(formulaPartTypes[i],'4') then begin
			operator := formulaParts[i];
			type1 := formulaPartTypes[i-1];
			type2 := formulaPartTypes[i+1];
			strValue1 := formulaParts[i-1];
			strValue2 := formulaParts[i+1];
			if SameText(operator,'-') then begin
				if not (SameText(type1,'3') and SameText(type2,'3')) then //3-numeric
					raise Exception.Create(Format('This operator can only be used for calculating numeric values. operator: %s, 1st value: %s, 2nd value: %s, formula: %s',[operator, strValue1, strValue2, formula]));
				floatValue1 := StrToFloat(strValue1);
				floatValue2 := StrToFloat(strValue2);
				resultFloat := floatValue1 - floatValue2;
				resultStr := FormatFloat('0.##########;-0.##########;"0"',resultFloat);
				resultType := '3';
			end else begin
				if SameText(operator,'+') then begin
					onePartIsAString := (SameText(type1,'1') or SameText(type2,'1'));
					if onePartIsAString then begin 
						if not ((SameText(type1,'1') or SameText(type1,'3') or SameText(type1,'8')) //1-string,3-numeric,8-boolean
								and (SameText(type2,'1') or SameText(type2,'3') or SameText(type1,'8'))) then 
							raise Exception.Create(Format('Since on of the two values is a string, this operator can only be used if the other is numeric, string an boolean. operator: %s, 1st value: %s, 2nd value: %s, formula: %s',[operator, strValue1, strValue2, formula]));
						resultStr := strValue1 + strValue2;
						resultType := '1';
					end else begin 
						if not (SameText(type1,'3') and SameText(type2,'3')) then //1-string,3-numeric,8-boolean
							raise Exception.Create(Format('Since none of the two values is a string, this operator can only be used for calculating 2 numeric values. operator: %s, 1st value: %s, 2nd value: %s, formula: %s',[operator, strValue1, strValue2, formula]));
						floatValue1 := StrToFloat(strValue1);
						floatValue2 := StrToFloat(strValue2);
						resultFloat := floatValue1 + floatValue2;
						resultStr := FormatFloat('0.##########;-0.##########;"0"',resultFloat);
						resultType := '3';
					end;
				end;
			end;
		end;
		
		if not SameText(resultStr,'') then begin
			//now replace the 3 parts with one new
			formulaParts.Delete(i+1);
			formulaPartTypes.Delete(i+1);
			formulaParts.Delete(i);
			formulaPartTypes.Delete(i);
			formulaParts[i-1]:=resultStr;
			formulaPartTypes[i-1]:=resultType;
			partsCount := formulaParts.Count;
			if resultType = '3' then 
				DebugLog(Format('Calculation performed. operator: %s, Value1: %s, Value2: %s, result: %s',[
					operator,
					FormatFloat('0.##########;-0.##########;"0"',floatValue1),
					FormatFloat('0.##########;-0.##########;"0"',floatValue2),
					resultStr
					]));
		end else begin
			inc(i);
		end;
	end;
	
	//then &
	i := 1;
	while i < partsCount-1 do begin 
		resultStr:='';
		
		if SameText(formulaPartTypes[i],'4') then begin
			operator := formulaParts[i];
			type1 := formulaPartTypes[i-1];
			type2 := formulaPartTypes[i+1];
			strValue1 := formulaParts[i-1];
			strValue2 := formulaParts[i+1];
			if SameText(operator,'&') then begin
				resultStr := strValue1 + strValue2;
				resultType := '1';
			end;
		end;
		
		if not SameText(resultStr,'') then begin
			//now replace the 3 parts with one new
			formulaParts.Delete(i+1);
			formulaPartTypes.Delete(i+1);
			formulaParts.Delete(i);
			formulaPartTypes.Delete(i);
			formulaParts[i-1]:=resultStr;
			formulaPartTypes[i-1]:=resultType;
			partsCount := formulaParts.Count;
			if resultType = '3' then 
				DebugLog(Format('Calculation performed. operator: %s, Value1: %s, Value2: %s, result: %s',[
					operator,
					FormatFloat('0.##########;-0.##########;"0"',floatValue1),
					FormatFloat('0.##########;-0.##########;"0"',floatValue2),
					resultStr
					]));
		end else begin
			inc(i);
		end;
	end;
	
	//then calculate comparison operators
	i := 1;
	while i < partsCount-1 do begin 
		resultStr:='';
		resultType:='8';
		compareResult := 99;
		
		if SameText(formulaPartTypes[i],'4') then begin
			//now only compare operators are left
			operator := formulaParts[i];
			type1 := formulaPartTypes[i-1];
			type2 := formulaPartTypes[i+1];
			strValue1 := formulaParts[i-1];
			strValue2 := formulaParts[i+1];
			bothPartsAreNumeric := (SameText(type1,'3') and SameText(type2,'3'));
			compareResult := CompareText(strValue1,strValue2);
			if bothPartsAreNumeric then begin
				floatValue1 := StrToFloat(strValue1);
				floatValue2 := StrToFloat(strValue2);
				//compareResult := CompareValue(floatValue1,floatValue2);
				if floatValue1 < floatValue2 then compareResult := -1;
				if floatValue1 > floatValue2 then compareResult := 1;
				if floatValue1 = floatValue2 then compareResult := 0;
			end;
			if SameText(operator,'=') then begin
				if (compareResult = 0) then begin
					resultStr := 'true';
				end else begin
					resultStr := 'false';
				end;
			end else begin
				if SameText(operator,'<') then begin
					if (compareResult = -1) then begin
						resultStr := 'true';
					end else begin
						resultStr := 'false';
					end;
				end else begin
					if SameText(operator,'>') then begin
						if (compareResult = 1) then begin
							resultStr := 'true';
						end else begin
							resultStr := 'false';
						end;
					end else begin
						if SameText(operator,'<=') then begin
							if ((compareResult = 0) or (compareResult = -1)) then begin
								resultStr := 'true';
							end else begin
								resultStr := 'false';
							end;
						end else begin
							if SameText(operator,'>=') then begin
								if ((compareResult = 0) or (compareResult = 1)) then begin
									resultStr := 'true';
								end else begin
									resultStr := 'false';
								end;
							end else begin
								if SameText(operator,'<>') then begin
									if not(compareResult = 0) then begin
										resultStr := 'true';
									end else begin
										resultStr := 'false';
									end;
								end;
							end;
						end;
					end;
				end;
			end;
		end;
		
		if not SameText(resultStr,'') then begin
			//now replace the 3 parts with one new
			formulaParts.Delete(i+1);
			formulaPartTypes.Delete(i+1);
			formulaParts.Delete(i);
			formulaPartTypes.Delete(i);
			formulaParts[i-1]:=resultStr;
			formulaPartTypes[i-1]:=resultType;
			partsCount := formulaParts.Count;
			DebugLog(Format('Comparison performed. operator: %s, Value1: %s, Value2: %s, result: %s',[
				operator,
				strValue1,
				strValue2,
				resultStr
				]));
		end else begin
			inc(i);
		end;
	end;
	
	//there can only be one result per section left (i.e. between separators)
	partsCount := formulaParts.Count;
	if (partsCount > (separatorsCount*2+1)) then begin
		raise Exception.Create(Format('The formula could not be completely calculated. formula: %s, parts left: %s',[formula,formulaParts.Text]));
	end;
	
	Result:= formulaParts[0];
	
	LogFunctionEnd;
end;

//=========================================================================
//  loads a file with formulas and returns these formulas
//=========================================================================
procedure LoadFormulasFromFile(const filename : String; formulas : TStringList;);
var 	
	allLines : TStringList;
	i, posEqual, posApostrophe, counter, lengthToNextApostrophe : Integer;
	line, variableName, formula : String;
	lineEndsWithinAStringValue, prevlineEndsWithinAStringValue : Boolean;
begin
	LogFunctionStart('LoadFormulasFromFile');
	allLines := TStringList.Create;
	
	try
		allLines.LoadFromFile(filename);
		variableName := '';
		formula:='';
		lineEndsWithinAStringValue := false;
		counter :=1;
		
		for i := 0 to allLines.Count-1 do begin
				line := allLines[i];
				if Copy(line,1,1) = '/' then
					continue;
				
				posEqual := Pos('=',line);
				posApostrophe := Pos('"',line);
				lengthToNextApostrophe := posApostrophe;
				prevlineEndsWithinAStringValue:=lineEndsWithinAStringValue;
				
				while lengthToNextApostrophe > 0 do begin
					if counter > 1000 then begin
						raise Exception.Create(Format('endless loop while trying to decide if we are in a string. posApostrophe: %d, rest of line: %s',[posApostrophe,Copy(line,posApostrophe+1,Length(line)-posApostrophe)]));
					end;
					
					lineEndsWithinAStringValue := not lineEndsWithinAStringValue;
					
					lengthToNextApostrophe := Pos('"',Copy(line,posApostrophe+1,Length(line)-posApostrophe));
					posApostrophe := posApostrophe + lengthToNextApostrophe;
					// DebugLog(Format('deciding if we need a line break within the formula: posApostrophe: %d, rest of line: %s',[posApostrophe,Copy(line,posApostrophe+1,Length(line)-posApostrophe)]));
					inc(counter);
				end;
				
				if prevlineEndsWithinAStringValue then begin
					// DebugLog(Format('there is a linebreak we should conider. variableName: %s, formula so far: %s',[variableName,formula]));
					formula := formula + chr(13) + chr(10) + line;
					continue;
				end;
				
				//add the previous variable to the formulas
				if not (SameText(variableName,'')) then begin
					formulas.Values[variableName] := formula;
					DebugLog(Format('added formulaEntry - variableName: %s, formula: %s',[variableName,formula]));
				end;
				
				variableName := Copy(line,1,posEqual-1);
				formula := Copy(line,posEqual+1,Length(line)-posEqual);
		end;
		
		//add the last variable after the loop
		if not (variableName = '') then begin
			if formulas.IndexOfName(variableName) > -1 then 
				raise Exception.Create(Format('Variable has been defined twice. variableName: %s',[variableName]));
				
			formulas.Values[variableName] := formula;
			DebugLog(Format('added formulaEntry - variableName: %s, formula: %s',[variableName,formula]));
		end;
		
	finally
		allLines.Free;
		allLines := nil;
	end;
	
	LogFunctionEnd;
end;

end.
//
// Date:2020-08-01 WIP (5)
// Ver: 1.0
// Author: Gernash
//

unit MODRenamerv2; // FO4PatchOmodDescriptions;

// code for editing xEdit scripts with Delphi
interface

implementation

uses xEditAPI, Classes, SysUtils, StrUtils, Windows;

const
  sPropertiesList = wbScriptsPath + 'Gernashs description Renamer - Resource.txt';

var
  slPropertyMap: TStringList;
  plugin: IInterface;

procedure GetMappedValues(rec : IInterface; mappedValues, indicesToSkip : TStringList;);
var
  valuetype, valuefunctiontype, valuePropertytype : string;
	valuetype2, valuefunctiontype2, valuePropertytype2 : string;
	loopResult, loopResult2, propname : string;
  floatValue, floatValue2: Real;
	prop, prop2, properties: IInterface;
	i,j,dummyInt : Integer;
  // OMOD Property Value Sort to %, x, deg or Value {{{THE MATHS}}}
begin
	properties := ElementByPath(rec, 'DATA\Properties');
	for i := 0 to Pred(ElementCount(properties)) do
	begin
		if indicesToSkip.Find(i,dummyInt) then begin
			mappedValues.Add('');//necessary, so that number of records stay the same
			continue;
		end;
	
		prop := ElementByIndex(properties, i);
		propname := GetElementEditValues(prop, 'Property');
		j := slPropertyMap.IndexOfName(propname);
		if j = -1 then begin
			mappedValues.Add('');//necessary, so that number of records stay the same
			Continue;
		end;
		
		loopResult:= '';
		
		valuetype := GetElementEditValues(prop, 'Value Type');
		valuePropertytype := GetElementEditValues(prop, 'Property');
		valuefunctiontype := GetElementEditValues(prop, 'Function Type');

		if (valuetype = 'FormID,Float') and (valuefunctiontype = 'MUL+ADD') then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 7));
			if floatValue > 1.0 then
				loopResult := FloatToStr(floatValue) + 'x'
			else if floatValue > 0.0 then
				loopResult := '+' + IntToStr(Int(floatValue * 100)) + '%'
			else
				loopResult := IntToStr(Int(floatValue * 100)) + '%';
		end

		else if (valuetype = 'FormID,Float') and
			(valuePropertytype = 'DamageTypeValue') then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 7));
			loopResult := FloatToStr(floatValue);
		end

		else if (valuetype = 'FormID,Float') and
			(valuePropertytype = 'DamageTypeValue') then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			if floatValue > 5.0 then
				loopResult := FloatToStr(floatValue) + '%'
			else if floatValue > 0.0 then
				loopResult := FloatToStr(floatValue)
		end

		else if valuetype = 'FormID,Float' then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 7));
			if floatValue > 5.0 then
				loopResult := FloatToStr(floatValue) + '%'
			else if floatValue > 0.0 then
				loopResult := FloatToStr(floatValue)
		end

		else if (valuePropertytype = 'AimModelRecoilArcRotateDeg') or
			(valuePropertytype = 'AimModelRecoilMinDegPerShot') or
			(valuePropertytype = 'AimModelRecoilMaxDegPerShot') or
			(valuePropertytype = 'AimModelRecoilArcDeg') then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			if floatValue > 1.0 then
				loopResult := '+' + FloatToStr(floatValue) + chr($00B0)
			else if floatValue > 0.0 then
				loopResult := '+' + IntToStr(Int(floatValue * 100)) + chr($00B0)
			else
				loopResult := IntToStr(Int(floatValue * 100)) + chr($00B0);
		end

		else if (valuePropertytype = 'AimModelMinConeDegrees') or (valuePropertytype = 'AimModelMaxConeDegrees') then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			if floatValue > 1.0 then
				loopResult := FloatToStr(floatValue * 100) + '%'
			else if floatValue > 0.0 then
				loopResult := '+' + IntToStr(Int(floatValue * 100)) + '%'
			else
				loopResult := IntToStr(Int(floatValue * 100)) + '%';
		end

		else if (valuetype = 'Float') and (valuefunctiontype = 'MUL+ADD') then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			if floatValue > 1.0 then
				loopResult := FloatToStr(floatValue) + 'x'
			else if floatValue > 0.0 then
				loopResult := '+' + IntToStr(Int(floatValue * 100)) + '%'
			else
				loopResult := IntToStr(Int(floatValue * 100)) + '%';
		end

		else if (valuetype = 'Float') and (valuefunctiontype = 'MinRange') then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			loopResult := FloatToStr(floatValue) + 'units';
		end

		else if valuetype = 'Float' then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			if floatValue > 1.0 then
				loopResult := FloatToStr(floatValue) + 'x'
			else if floatValue > 0.0 then
				loopResult := '+' + IntToStr(Int(floatValue * 100)) + '%'
			else
				loopResult := IntToStr(Int(floatValue * 100)) + '%';
		end

		else if (valuetype = 'FormID,Int') and (valuePropertytype = 'ZoomData') then
		begin
			loopResult := slPropertyMap.Values[GetEditValue(ElementByIndex(prop, 6))];
		end

		else if (valuetype = 'FormID,Int') then
		begin
			loopResult := '';
		end

		else if (valuetype = 'Int') then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			loopResult := FloatToStr(floatValue);
		//AddMessage(Format('INT: %s', [loopResult]));
		end;
		
		
		
		
		//////////////////////////////////////
		//@Halgoth: example for how to consider another property for this property
		//////////////////////////////////////
		if (propname = 'AstoroidPotato') then 
		begin
			
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			loopResult := FloatToStr(floatValue);
		
			for j := i to Pred(ElementCount(properties)) do //look ahead for other interesting property
			begin
				if (j=i) then //here not in the declaration of the for loop so that the last property does not need special code
					continue; 
				prop2 := ElementByIndex(properties, j);
				
				if slPropertyMap.IndexOfName(GetElementEditValues(prop2, 'Property')) = -1 then begin
					Continue; //no idea if necessary, but works the same as other loops
				end; 
				
				//get second propert info
				valuetype2 := GetElementEditValues(prop2, 'Value Type');
				valuePropertytype2 := GetElementEditValues(prop2, 'Property');
				valuefunctiontype2 := GetElementEditValues(prop2, 'Function Type');
				
				//some logic that says: here we should consider both elements
				if (valuetype2 = 'FormID,Int') and (valuePropertytype2 = 'ZoomData') then
				begin
					//remember that this other property should not be processed anymore, because it was already included in the output of this property
					indicesToSkip.Add(j);
					//decide the ouptut for this property by using values of the second property
					loopResult := 'AstoroidPotato' + slPropertyMap.Values[GetEditValue(ElementByIndex(prop2, 6))];
					break;
				end
			end
		end;
		//////////////////////////////////////
		
		
		
		
		
		// add property index as prefix for sorting
		mappedValues.Add(loopResult);
	end;
end;


// Property to Name Mapping Layout

procedure GetMappedDescription(rec : IInterface; sl : TStringList;);
var
  mappedName, mappedValue, query, query2, queryfunction, propname, loopResult: String;
  valuetype, valuefunctiontype, valuePropertytype : string;
  valuetype2, valuefunctiontype2, valuePropertytype2, value1output2 : string;
  floatValue: Real;
	prop, properties, prop2 : IInterface; 
	mappedValues, indicesToSkip : TStringList;
	i,j,dummyInt : Integer;
begin
	mappedValues:=TStringList.Create;
	indicesToSkip:=TStringList.Create;
	indicesToSkip.Sorted:=true; //so that .Find() works
	
	try
		GetMappedValues(rec, mappedValues, indicesToSkip);
		
		properties := ElementByPath(rec, 'DATA\Properties');
		for i := 0 to Pred(ElementCount(properties)) do
		begin
			loopResult  := '';
			if indicesToSkip.Find(i,dummyInt) then 
				continue;
		
			prop := ElementByIndex(properties, i);
			propname := GetElementEditValues(prop, 'Property');
			j := slPropertyMap.IndexOfName(propname);
			if j = -1 then
				Continue;
			
			mappedName := slPropertyMap.Values[propname];
			mappedValue := mappedValues[i];
			
			query := slPropertyMap.Values[GetEditValue(ElementByIndex(prop, 6))];
			query2 := GetElementEditValues(prop, 'Function Type');
			queryfunction := GetElementEditValues(prop, 'Function Type');

//			if mappedName = '\' then
//				loopResult := Format('%s%s' + '', [mappedName, mappedValue])

		if mappedName = 'Damage_Type' then 
		begin
			
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			loopResult := FloatToStr(floatValue);
		
			for j := 0 to Pred(ElementCount(properties)) do //look ahead for other interesting property
			begin
				if (j=i) then //here not in the declaration of the for loop so that the last property does not need special code
					continue; 
				prop2 := ElementByIndex(properties, j);
				
				if slPropertyMap.IndexOfName(GetElementEditValues(prop2, 'Property')) = -1 then begin
					Continue; //no idea if necessary, but works the same as other loops
				end; 
							
				
				//get second propert info
				valuetype2 := GetElementEditValues(prop2, 'Value Type');
				valuePropertytype2 := GetElementEditValues(prop2, 'Property');
				valuefunctiontype2 := GetElementEditValues(prop2, 'Function Type');
				value1output2 := slPropertyMap.Values[GetEditValue(ElementByIndex(prop2, 6))];
				if value1output2 = '' then continue;
				//some logic that says: here we should consider both elements
				//if (valuetype2 = 'FormID,Int') and (valuePropertytype2 = 'ZoomData') then
				if (valuetype2 = 'FormID,Int') and (valuePropertytype2 = 'Keywords') then
				begin
					//remember that this other property should not be processed anymore, because it was already included in the output of this property
					indicesToSkip.Add(j);
					//decide the ouptut for this property by using values of the second property
					loopResult := Format('Additional %s Damage: %s', [value1output2, mappedValue]);
					//if (j) < i then sl[j] := '';
					break;
					//continue;
				end;
			end;
		end

		else if  mappedName = 'Damage_Resistance' then 
		begin
			
			floatValue := GetNativeValue(ElementByIndex(prop, 6)); // WTF is this for
			loopResult := FloatToStr(floatValue);  // WTF is this for
		
			for j := 0 to Pred(ElementCount(properties)) do
			begin
				if (j=i) then
					continue; 
				prop2 := ElementByIndex(properties, j);
				
				if slPropertyMap.IndexOfName(GetElementEditValues(prop2, 'Property')) = -1 then begin
					Continue; //no idea if necessary, but works the same as other loops
				end; 
				
				//get second property info
				valuetype2 := GetElementEditValues(prop2, 'Value Type');
				valuePropertytype2 := GetElementEditValues(prop2, 'Property');
				valuefunctiontype2 := GetElementEditValues(prop2, 'Function Type');
				value1output2 := slPropertyMap.Values[GetEditValue(ElementByIndex(prop2, 6))];
				
				if value1output2 = '' then continue;
				
//			AddMessage(Format('query2: %s', [query2]));
//			AddMessage(Format('valuetype2: %s', [valuetype2]));
//			AddMessage(Format('valuePropertytype2: %s', [valuePropertytype2]));
//			AddMessage(Format('valuefunctiontype2: %s', [valuefunctiontype2]));
//			AddMessage(Format('value1output2: %s', [value1output2]));
//			AddMessage(Format('loopResult: %s', [loopResult]));			
//			AddMessage(Format('floatValue: %s', [floatValue]));

				if (valuetype2 = 'FormID,Int') and (valuePropertytype2 = 'Keywords') then
				begin
					indicesToSkip.Add(j);
					loopResult := Format('Reduces %s damage by: %s', [value1output2, mappedValue]);
					break;
				end;	
					
				if (valuetype2 = 'FormID,Float') and (valuePropertytype2 = 'DamageTypeValue') then
				begin
					indicesToSkip.Add(j);
					loopResult := Format('Reduces %s damage by: %s', [value1output2, mappedValue]);
					break;
				end;
			end;
		end 

			else if (mappedName = 'Actor_Values_Type') and (query <> 'NFW') and (query <> '') then
				loopResult := Format('%s' + '+' + '%s', [query, mappedValue])
// Legendary Effect multiplier
			else if (mappedName = 'Actor_Values_Type') and (query <> 'NFW') and	(query = '') then
				loopResult := mappedValue

//			else if ((mappedName = 'MaterialSwaps_Values_Type') and (query2 <> 'REM') and (query <> 'NFW')) or (mappedName = 'Ammo_Type') then //((mappedName = 'Keywords_Values_Type') and (query <> '1')) or 
//				loopResult := query

//			else if ((mappedName = 'Enchantments_Value') and (query <> 'NFW')) then
//				loopResult := query

//			else if (mappedName = 'Range (Min\Max):') or (mappedName = 'Recoil (Min\Max):') or (mappedName = 'Cone (Min\Max):') then
//				loopResult := Format('%s%s', [mappedName, mappedValue]);

			else if (query <> 'NFW') and (mappedName <> 'Damage_Type') and (mappedName <> 'Damage_Resistance') and (query2 <> 'REM') and (mappedName <> 'Keywords_Values_Type') and (mappedName <> 'NFW') and (mappedValue <> 'NFW') then
				loopResult := Format('%s%s', [mappedName, mappedValue]); // output layout

//			AddMessage(Format('mappedName: %s', [mappedName]));
//			AddMessage(Format('mappedValue: %s', [mappedValue]));
//			AddMessage(Format('query: %s', [query]));
//			AddMessage(Format('query2: %s', [query2]));
//			AddMessage(Format('valuetype2: %s', [valuetype2]));
//			AddMessage(Format('valuePropertytype2: %s', [valuePropertytype2]));
//			AddMessage(Format('valuefunctiontype2: %s', [valuefunctiontype2]));
//			AddMessage(Format('value1output2: %s', [value1output2]));
//			AddMessage(Format('loopResult: %s', [loopResult]));

			// add property index as prefix for sorting
			//if loopResult <> '\-200%' then
			sl.Add(Format('%.3d', [j]) + loopResult);
			//AddMessage(Format('sl: %s', [sl[j]]));
		end;
		
	finally
		mappedValues.Free;
		mappedValues:=nil;
		indicesToSkip.Free;
		indicesToSkip:=nil;
	end;
end;

function GetOmodDescription(rec: IInterface): String;
var
  i: Integer;
  prop, properties: IInterface;
  proprefix, prosuffix, propname: string;
  sl: TStringList;

begin
  sl := TStringList.Create;
  sl.Sorted := true; // sorting automatically happens at insert

  try
    
		GetMappedDescription(rec, sl);

    // concatenate and remove prefixes

    for i := 0 to sl.Count - 1 do
    begin
      proprefix := Copy(sl[i], 4, Length(1));
      prosuffix := RightStr(Result, 1);
      if (proprefix = '') or (proprefix = '\') or (prosuffix = ' ') then
      begin
        Result := Result
      end
      else if Result <> '' then
      begin
        Result := Result + ' | '
      end;
      Result := Result + Copy(sl[i], 4, Length(sl[i]))
    end;
  finally
    sl.Free;
    sl := nil;
  end;
end;

function Initialize: Integer;
begin
  slPropertyMap := TStringList.Create;
  slPropertyMap.LoadFromFile(sPropertiesList);
end;

function Process(e: IInterface): Integer;
var
  desc, oldDesc: string;
  r: IInterface;
begin
  if Signature(e) <> 'OMOD' then
    Exit;

  // patch the winning override record

  e := WinningOverride(e);

  if not Assigned(e) then
  begin
    AddMessage
      ('something went wrong when getting the override for this record.');
    Exit;
  end;
  desc := GetOmodDescription(e);

  if desc = '' then
    Exit;

  oldDesc := GetEditValue(ElementByPath(e, 'DESC'));
  if SameText(oldDesc, desc) then
  begin
    AddMessage
      (Format('description already up to date, ending script - description: "%s"',
      [desc]));
    Exit;
  end;

  // create new plugin
  if not Assigned(plugin) then
  begin
    if MessageDlg
      ('Create new patch plugin [YES] or append to the last loaded one [NO]?',
      mtConfirmation, [mbYes, mbNo], 0) = mrYes then
      plugin := AddNewFile
    else
      plugin := FileByIndex(Pred(FileCount));
    if not Assigned(plugin) then
    begin
      Result := 1;
      Exit;
    end;
  end;

  // skip already copied
  if GetFileName(e) = GetFileName(plugin) then
    Exit;

  // add masters
  AddRequiredElementMasters(e, plugin, False);

  try
    // copy as override
    r := wbCopyElementToFile(e, plugin, False, true);
    if not Assigned(r) then
    begin
      AddMessage('something went wrong when creating the override record.');
      Exit;
    end;
    // setting new description
    SetElementEditValues(r, 'DESC', desc);
  except
    on Ex: Exception do
    begin
      AddMessage('Failed to copy: ' + FullPath(e));
      AddMessage('    reason: ' + Ex.Message);
    end
  end;

end;

function Finalize: Integer;
begin
  slPropertyMap.Free;
  slPropertyMap := nil;
  if Assigned(plugin) then
    SortMasters(plugin);
end;

end.

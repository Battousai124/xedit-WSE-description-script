//
// Ver: 3.3
// WIP (3)
// Author: Gernash
// Scripting: EffEIO
// Tester: KenShin
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

procedure GetMappedValues(rec : IInterface; mappedValues, indicesToSkip, formatstrings : TStringList;);
var
  valuetype, valuefunctiontype, valuePropertytype : string;
	valuetype2, valuefunctiontype2, valuePropertytype2 : string;
	loopResult, loopResult2 : string;
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
			formatstrings.Add('');
			continue;
		end;
	
		prop := ElementByIndex(properties, i);
		valuePropertytype := GetElementEditValues(prop, 'Property');
		j := slPropertyMap.IndexOfName(valuePropertytype);
		if j = -1 then begin
			mappedValues.Add('');//necessary, so that number of records stay the same
			formatstrings.Add('');
			Continue;
		end;
		
		loopResult:= '';
		loopResult2:= '';
		
		valuetype := GetElementEditValues(prop, 'Value Type');
		valuePropertytype := GetElementEditValues(prop, 'Property');
		valuefunctiontype := GetElementEditValues(prop, 'Function Type');

		if (valuetype = 'Float') and (valuefunctiontype = 'MUL+ADD') then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			if floatValue > 1.0 then
			Begin
				loopResult := FloatToStr(floatValue);			// + 'x'
				loopResult2 := FloatToStr(floatValue) + 'x';
			end else if floatValue > 0.0 then
			begin
				loopResult := IntToStr(Int(floatValue * 100));	//'+' + IntToStr(Int(floatValue * 100)) + '%'
				loopResult2 := '+' + IntToStr(Int(floatValue * 100)) + '%';
			end else
			begin
				loopResult := IntToStr(Int(floatValue * 100));	// + '%';
				loopResult2 := IntToStr(Int(floatValue * 100)) + '%';
			end;
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
				loopResult := FloatToStr(floatValue)			// + '%'
			else if floatValue > 0.0 then
				loopResult := FloatToStr(floatValue);
		end

		else if valuetype = 'FormID,Float' then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 7));
			if floatValue > 5.0 then
				loopResult := FloatToStr(floatValue)			// + '%'
			else if floatValue > 0.0 then
				loopResult := FloatToStr(floatValue);
		end

		else if (valuePropertytype = 'AimModelRecoilArcRotateDeg') or
			(valuePropertytype = 'AimModelRecoilMinDegPerShot') or
			(valuePropertytype = 'AimModelRecoilMaxDegPerShot') or
			(valuePropertytype = 'AimModelRecoilArcDeg') then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			if floatValue > 1.0 then
				loopResult := FloatToStr(floatValue)			//'+' + FloatToStr(floatValue) + chr($00B0)
			else if floatValue > 0.0 then
				loopResult := IntToStr(Int(floatValue * 100))	//'+' + IntToStr(Int(floatValue * 100)) + chr($00B0)
			else
				loopResult := IntToStr(Int(floatValue * 100)); 	//+ chr($00B0);
		end

//		else if (valuePropertytype = 'AimModelMinConeDegrees') or (valuePropertytype = 'AimModelMaxConeDegrees') then
//		begin
//			floatValue := GetNativeValue(ElementByIndex(prop, 6));
//			if floatValue > 1.0 then
//				loopResult := FloatToStr(floatValue * 100) + '%'
//			else if floatValue > 0.0 then
//				loopResult := '+' + IntToStr(Int(floatValue * 100)) + '%'
//			else
//				loopResult := IntToStr(Int(floatValue * 100)) + '%';
//		end

//		else if (valuetype = 'Float') and (valuefunctiontype = 'MUL+ADD') then
//		begin
//			floatValue := GetNativeValue(ElementByIndex(prop, 6));
//			loopResult := FloatToStr(floatValue)
//			if floatValue > 1.0 then
//				loopResult := FloatToStr(floatValue) 			//+ 'x'
//			else if floatValue > 0.0 then
//				loopResult := IntToStr(Int(floatValue * 100))	//'+' + IntToStr(Int(floatValue * 100)) + '%'
//			else
//				loopResult := IntToStr(Int(floatValue * 100)); 	//+ '%';
//		end

//		else if (valuetype = 'Float') and (valuefunctiontype = 'MinRange') then
//		begin
//			floatValue := GetNativeValue(ElementByIndex(prop, 6));
//			loopResult := FloatToStr(floatValue); 				//+ 'units';
//		end

//		else if valuetype = 'Float' then
//		begin
//			floatValue := GetNativeValue(ElementByIndex(prop, 6));
//			if floatValue > 1.0 then
//				loopResult := FloatToStr(floatValue) 			//+ 'x'
//			else if floatValue > 0.0 then
//				loopResult := IntToStr(Int(floatValue * 100))	//'+' + IntToStr(Int(floatValue * //100)) + '%'
//			else
//				loopResult := IntToStr(Int(floatValue * 100)); 	//+ '%';
//		end

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
		
        	AddMessage(Format('loopResult2: %s', [loopResult2]));
        	AddMessage(Format('loopResult: %s', [loopResult]));
		// add property index as prefix for sorting
		mappedValues.Add(loopResult);
		formatstrings.Add(loopResult2);
	end;
end;


// Property to Name Mapping Layout

procedure GetMappedDescription(rec : IInterface; sl : TStringList;);
var
  loopResult: String;
  valuetype, valuefunctiontype, valuePropertytype, value1Loop1, mappedName, mappedValue : string;
  valuetype2, valuefunctiontype2, valuePropertytype2, value1Loop2, mappedValue2 : string;
  mappedValueFORMAT, mappedValue2FORMAT : string;
  floatValue: Real;
	prop, properties, prop2 : IInterface; 
	formatstrings, mappedValues, indicesToSkip : TStringList;
	i,j,dummyInt : Integer;
begin
	mappedValues:=TStringList.Create;
	indicesToSkip:=TStringList.Create;
	formatstrings:=TStringList.Create;
	indicesToSkip.Sorted:=true; //so that .Find() works
	
	try
		GetMappedValues(rec, mappedValues, indicesToSkip, formatstrings);
		properties := ElementByPath(rec, 'DATA\Properties');
		
		for i := 0 to Pred(ElementCount(properties)) do
		begin
			loopResult  := '';
			if indicesToSkip.Find(i,dummyInt) then 
				continue;
		
			prop := ElementByIndex(properties, i);
			valuePropertytype := GetElementEditValues(prop, 'Property');
			j := slPropertyMap.IndexOfName(valuePropertytype);
			
			if j = -1 then
				Continue;
			
			mappedName := slPropertyMap.Values[valuePropertytype];
			mappedValue := mappedValues[i];
			mappedValueFormat := formatstrings[i];
			value1Loop1 := slPropertyMap.Values[GetEditValue(ElementByIndex(prop, 6))];
			valuefunctiontype := GetElementEditValues(prop, 'Function Type');
			valuetype := GetElementEditValues(prop, 'Value Type');

		if mappedName = 'Damage_Type' then 
		begin
			
			for j := 0 to Pred(ElementCount(properties)) do
			begin
				if (j=i) then
					continue; 
				prop2 := ElementByIndex(properties, j);
				
				if slPropertyMap.IndexOfName(GetElementEditValues(prop2, 'Property')) = -1 then begin
					Continue;
				end; 
							
				valuetype2 := GetElementEditValues(prop2, 'Value Type');
				valuePropertytype2 := GetElementEditValues(prop2, 'Property');
				valuefunctiontype2 := GetElementEditValues(prop2, 'Function Type');
				value1Loop2 := slPropertyMap.Values[GetEditValue(ElementByIndex(prop2, 6))];
			
				if value1Loop2 = '' then continue;

                if (valuetype2 = 'FormID,Int') and (valuePropertytype2 = 'Keywords') then
                begin
                    indicesToSkip.Add(j);
                    loopResult := Format('Additional %s damage by: %s', [value1Loop2, mappedValue]);
                    break;
				end;
			end;
			
			if loopResult = '' then
				loopResult := Format('Additional %s damage by: %s', [value1Loop1, mappedValue]);
		end

		else if mappedName = 'Damage_Resistance' then 
		begin
		
            for j := 0 to Pred(ElementCount(properties)) do
            begin
                if (j=i) then
                    continue; 
                prop2 := ElementByIndex(properties, j);

                if slPropertyMap.IndexOfName(GetElementEditValues(prop2, 'Property')) = -1 then begin
                    Continue;
                end; 

                valuetype2 := GetElementEditValues(prop2, 'Value Type');
                valuePropertytype2 := GetElementEditValues(prop2, 'Property');
                valuefunctiontype2 := GetElementEditValues(prop2, 'Function Type');
                value1Loop2 := slPropertyMap.Values[GetEditValue(ElementByIndex(prop2, 6))];

                if value1Loop2 = '' then continue;

                if (valuetype2 = 'FormID,Int') and (valuePropertytype2 = 'Keywords') then
                begin
                    indicesToSkip.Add(j);
                    loopResult := Format('Reduces %s damage by: %s', [value1Loop2, mappedValue]);
                    break;
                end;
			end;

			if loopResult = '' then
				loopResult := Format('Reduces %s damage by: %s', [value1Loop1, mappedValue]);
        end 

		else if (mappedName = 'Range (Min\Max):') or (mappedName = 'Recoil (Min\Max):') or (mappedName = 'Spread (Min\Max):') then
        begin
		
              for j := 0 to Pred(ElementCount(properties)) do
              begin
                  if (j=i) then
                      continue;
                  prop2 := ElementByIndex(properties, j);

                  if slPropertyMap.IndexOfName(GetElementEditValues(prop2, 'Property')) = -1 then begin
                      Continue;
                  end;

                  valuetype2 := GetElementEditValues(prop2, 'Value Type');
                  valuePropertytype2 := GetElementEditValues(prop2, 'Property');
                  valuefunctiontype2 := GetElementEditValues(prop2, 'Function Type');
				  value1Loop2 := GetNativeValue(ElementByIndex(prop2, 6));
				  mappedValue2 := FloatToStr(value1Loop2);

				
 //         if (mappedName = 'Range (Min\Max):')  or (mappedName = 'Spread (Min\Max):') then
			if (valuetype2 = 'Float') and (valuefunctiontype2 = 'MUL+ADD') then
              begin


                    if value1Loop2 > 1.0 then
                    begin
              //				mappedValueFORMAT := format('%sx',[FloatToStr(mappedValue)]);
                      mappedValue2FORMAT := format('%sx',[FloatToStr(value1Loop2)]);
                    end
                    else if value1Loop2 > 0.0 then
                    begin
              //                 mappedValueFORMAT := format('+%s%', [IntToStr(Int(mappedValue * 100))]);
                       mappedValue2FORMAT := format('+%s%', [IntToStr(Int(value1Loop2 * 100))]);
                    end
                    else
              //				mappedValueFORMAT := IntToStr(Int(mappedValue * 100)) + '%';
                      mappedValue2FORMAT := IntToStr(Int(value1Loop2 * 100)) + '%';

              end ;

//          else if (mappedName = 'Recoil (Min\Max):') then
 //         begin
 //           if value1Loop2 > 1.0 then
//              mappedValue2 := FloatToStr(value1Loop2)				//'+' + //FloatToStr(value1Loop2) + chr($00B0)
 //           else if value1Loop2 > 0.0 then
//              mappedValue2 := IntToStr(Int(value1Loop2 * 100))		//'+' + IntToStr(Int(value1Loop2 * 100)) + chr($00B0)
 //           else
 //             mappedValue2 := IntToStr(Int(value1Loop2 * 100)); 		//+ chr($00B0);
 //         end;

          if value1Loop2 = '' then continue; //not looking for a string does nothing????

         if (mappedName = 'Range (Min\Max):') and (valuePropertytype2 = 'MaxRange') then
         begin
            indicesToSkip.Add(j);
            if (mappedValue = mappedValue2) then
              loopResult := Format('Range: %s', [mappedValueFORMAT])
            else begin
              loopResult := Format('%s %s\%s', [mappedName, mappedValueFORMAT, mappedValue2FORMAT]);
              break;
			end;
		end
        else if (mappedName = 'Recoil (Min\Max):') and (valuePropertytype2 = 'AimModelRecoilMaxDegPerShot') then
        begin
              indicesToSkip.Add(j);
              if (mappedValue = mappedValue2) then
                loopResult := Format('Recoil: %s', [mappedValueFORMAT])
              else begin
                loopResult := Format('%s %s\%s', [mappedName, mappedValueFORMAT, mappedValue2FORMAT]);
                break;
              end;
		end
            else if (mappedName = 'Spread (Min\Max):') and (valuePropertytype2 = 'AimModelMaxConeDegrees') then
            begin
              indicesToSkip.Add(j);
              if (StrToFloat(mappedValue) >= StrToFloat(mappedValue2)) then
                loopResult := Format('Spread: %s', [mappedValueFORMAT])
              else begin
                loopResult := Format('%s %s\%s', [mappedName, mappedValueFORMAT, mappedValue2FORMAT]);
                break;
              end;
		end;
				if (mappedName = 'Range (Min\Max):') and (loopResult = '') then
					loopResult := Format('Range: %s', [mappedValueFORMAT]);
				if (mappedName = 'Recoil (Min\Max):') and (loopResult = '') then
					loopResult := Format('Recoil: %s', [mappedValueFORMAT]);
				if (mappedName = 'Spread (Min\Max):') and (loopResult = '') then
					loopResult := Format('Spread: %s', [mappedValueFORMAT]);
        end;

        
      end
				
			else if (mappedName = 'Actor_Values_Type') and (value1Loop1 <> 'NFW') and (value1Loop1 <> '') then
				loopResult := Format('%s' + '+' + '%s', [value1Loop1, mappedValue])
// Legendary Effect multiplier
			else if (mappedName = 'Actor_Values_Type') and (value1Loop1 <> 'NFW') and (value1Loop1 = '') then
				loopResult := mappedValue

			else if ((mappedName = 'MaterialSwaps_Values_Type') and (valuetype <> 'REM') and (value1Loop1 <> 'NFW')) or 
				(mappedName = 'Ammo_Type') then
				loopResult := value1Loop1

			else if ((mappedName = 'Enchantments_Value') and (value1Loop1 <> 'NFW')) or 
				((mappedName = 'Keywords_Values_Type') and (value1Loop1 <> '') and (value1Loop1 <> 'Energy') and (value1Loop1 <> 'Cold') and (value1Loop1 <> 'Radiation') and (value1Loop1 <> 'Split Beam Shotgun Energy')) then
				loopResult := value1Loop1

			else if (value1Loop1 <> 'NFW') and 
				(mappedName <> '\') and
				(valuetype <> 'REM') and 
				(mappedName <> 'Keywords_Values_Type') and 
				(mappedName <> 'NFW') and 
				(mappedValue <> 'NFW') then
				loopResult := Format('%s%s', [mappedName, mappedValueFormat]);

//        	AddMessage(Format('mappedName: %s', [mappedName]));
//        	AddMessage(Format('mappedValue: %s', [mappedValue]));
//       	AddMessage(Format('value1Loop1: %s', [value1Loop1]));
//        	AddMessage(Format('valuetype: %s', [valuetype]));
//        	AddMessage(Format('valuetype2: %s', [valuetype2]));
//        	AddMessage(Format('mappedValue2: %s', [mappedValue2]));
//        	AddMessage(Format('valuePropertytype2: %s', [valuePropertytype2]));
//        	AddMessage(Format('valuefunctiontype2: %s', [valuefunctiontype2]));
//        	AddMessage(Format('value1Loop2: %s', [value1Loop2]));
//        	AddMessage(Format('loopResult: %s', [loopResult]));

			// add property index as prefix for sorting
		//	if valuePropertytype = '
			sl.Add(Format('%.3d', [j]) + loopResult);
		end;
		
	finally
		mappedValues.Free;
		mappedValues:=nil;
		indicesToSkip.Free;
		indicesToSkip:=nil;
		formatstrings.Free;
		formatstrings:=nil;
	end;
end;

function GetOmodDescription(rec: IInterface): String;
var
  i: Integer;
  proprefix, prosuffix: string;
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

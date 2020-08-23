unit Gernashs_OMOD_ReNamer_DescParser;

interface

implementation

uses
  xEditAPI,
  Classes,
  SysUtils,
  StrUtils,
  Windows;

procedure GetMappedDescription(rec: IInterface; sl, TStringList;); // stuff in here GLOBAL?
	
var
  tmpint, prop, properties: IInterface;
  i, j, dummyInt: Integer;
  mappedValues, indicesToSkip : TStringList; 
  value_Type, value_FunctionType, value_PropertyType, loopResult: String;
  mappedName, mappedValue, mappedHelperFileValue: String;
  floatValue: Real;

begin
  LogFunctionStart('GetMappedDescription');
  mappedValues := TStringList.Create;
  mappedValues.Sorted := True; // so that .Find() works
  mappedValues.Duplicates := dupIgnore;
  indicesToSkip := TStringList.Create;
  indicesToSkip.Sorted := True; // so that .Find() works
  indicesToSkip.Duplicates := dupIgnore;
	try
		properties := ElementByPath(rec, 'DATA\Properties');
		for i := 0 to Pred(ElementCount(properties)) do
		begin
			if indicesToSkip.Find(i, dummyInt) then
			begin
				mappedValues.Add(''); // necessary, so that number of records stay the same
				continue;
			end;

			prop := ElementByIndex(properties, i);
			value_PropertyType := GetElementEditValues(prop, 'Property');
			j := slPropertyMap.IndexOfName(value_PropertyType);
			
			if j = -1 then
			begin
				mappedValues.Add('');	// necessary, so that number of records stay the same
				continue;
			end;

			loopResult := '';
			mappedValue := '';

			value_Type := GetElementEditValues(prop, 'Value Type');
			value_PropertyType := GetElementEditValues(prop, 'Property');
			value_FunctionType := GetElementEditValues(prop, 'Function Type');
			mappedName := slPropertyMap.Values[value_PropertyType];
			mappedHelperFileValue := slPropertyMap.Values[RecordToString(LinksTo(ElementByIndex(prop, 6)))];
	
			if (value_Type = 'Float') and ((value_FunctionType = 'SET') or (value_FunctionType = 'ADD')) then
				begin
					floatValue := GetElementEditValues(prop, 'Value 1');
					if floatValue > 1.0 then
						begin
						loopResult := format('%sx', [FloatToStr(round(floatValue * 10) / 10)]);
						end
						else if floatValue > 0.0 then
						begin
							loopResult := format('+%s%%', [IntToStr(Int(round(floatValue * 1000) / 10))]);
						end
						else
						begin
							loopResult := format('%s%%', [IntToStr(Int(round(floatValue * 1000) / 10))]);
						end;
				end;
				
			if (value_Type = 'Float') and (value_FunctionType = 'MUL+ADD') then
				begin
					floatValue := GetElementEditValues(prop, 'Value 1');
					if floatValue > 1.0 then
						begin
							loopResult := format('%ssec', [FloatToStr(round(floatValue * 10) / 10)]);
						end
						else if floatValue > 0.0 then
						begin
							loopResult := format('+%s%%', [IntToStr(Int(round(floatValue * 1000) / 10))]);
						end
						else
						begin
							loopResult := format('%s%%', [IntToStr(Int(round(floatValue * 1000) / 10))]);
						end;
				end;
				
			// Pure Value	
			if (value_Propertytype = 'NumProjectiles') then
				begin
					floatValue := GetElementEditValues(prop, 'Value 1'); 
					loopResult := format('%s', [FloatToStr(round(floatValue * 10) / 10)]);
				end;
				
			// calculate off 'Value 2'	
				
			if (value_Propertytype = 'DamageTypeValue') or
      (value_Propertytype = 'DamageTypeValues') then
			begin
				floatValue := GetElementEditValues(prop, 'Value 2'); 
				if floatValue > 1.0 then
				begin
					loopResult := FloatToStr(round(floatValue * 10) / 10);
				end
				else if floatValue > 0.0 then
				begin
					loopResult := format('+%s%%', [IntToStr(Int(round(floatValue * 1000) / 10))]);
				end
				else
				begin
					loopResult := format('%s%%', [IntToStr(Int(round(floatValue * 1000) / 10))]);
				end;
			end;

			if (mappedName = 'MaterialSwaps_Values_Type') or
				(mappedName = 'MaterialSwaps_Values_Type') or
				(mappedName = 'Keywords_Values_Type')  or
				(mappedName = 'Actor_Values_Type') then	
				begin
				continue;
				end;
			//Default Mapped name
			mappedValue := format('%s%s', [mappedName, loopResult]);
				
			if (mappedName = 'Enchantments_Value') or
				(value_PropertyType = 'ZoomData') then	
				begin
				mappedValue := format('%s', [mappedHelperFileValue]);
				end;
			
			if mappedName = 'Damage_Type' then
				begin
					mappedValue := format('%s damage: %s', [mappedHelperFileValue, loopResult]);
				end;
			
			if mappedName = 'Damage_Resistance' then
				begin
					mappedValue := format('Reduces %s damage by: %s', [mappedHelperFileValue, loopResult]);
				end;
			
			if (mappedValue = 'Ammo_Type') then
				begin
					tmpint := LinksTo(ElementByIndex(prop, 6));
					loopResult := GetEditValue(ElementByPath(tmpint, 'ONAM'));
					if Length(loopResult) = 0 then
							mappedValue := GetEditValue(ElementByPath(tmpint, 'FULL'));
					mappedValue := format('Changes Ammo to %s', [GetNameWithoutTags(loopResult, 0)]);
				end;
				
			sl.Add(format('%.3d', [j]) + mappedValue);
			
			//DebugLog(Format('floatValue: %s, loopResult: %s'  , [floatValue,loopResult]));
			//DebugLog(Format('mappedName: %s, mappedValue: %s'  , [mappedName,mappedValue]));
			//DebugLog(Format('mappedHelperFileValue: %s'  , [mappedHelperFileValue]));
			//DebugLog(Format('mappedName: %s, loopResult: %s'  , [mappedName,loopResult]));
			
	 end;
	
	finally
    mappedValues.Free;
    mappedValues := nil;
    indicesToSkip.Free;
    indicesToSkip := nil;
  end;
    LogFunctionEnd;
end;

  function GetOmodDescription(rec: IInterface): String;
  var
    i: Integer;
    proprefix, prosuffix: string;
    sl: TStringList;

  begin
    LogFunctionStart('GetOmodDescription');
    sl := TStringList.Create;
    sl.Sorted := True; // sorting automatically happens at insert

    try
      GetMappedDescription(rec, sl);

      // concatenate and remove prefixes

      for i := 0 to sl.Count - 1 do
      begin
        proprefix := Copy(sl[i], 4, Length(1));
        prosuffix := RightStr(Result, 1);
        if (proprefix = '') or (proprefix = '\') or (prosuffix = ' ') then
        begin
          Result := Result;
        end
        else if Result <> '' then
        begin
          Result := Result + ' | ';
        end;
        Result := Result + Copy(sl[i], 4, Length(sl[i]))
      end;
    finally
      sl.Free;
      sl := nil;
    end;
    LogFunctionEnd;
  end;

end.

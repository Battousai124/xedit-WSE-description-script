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
  tmpint, prop, proploop2, properties: IInterface;
  i, i2, j, j2, dummyInt: Integer;
  mappedValues, indicesToSkip : TStringList;
	dummyStr : String;
  value_Type, value_FunctionType, value_PropertyType, loop1Result : String;
  mappedName, mappedValue, mappedHelperFileValue : String;
	loop2Result, formatedloop2Result, formatedloop1Result, value_Type_Loop2, valuePropertytype2, valuefunctiontype2 : String;
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
			tmpint := '';
			loop1Result := '';
			mappedValue := '';
			prop := ElementByIndex(properties, i);
			value_PropertyType := GetElementEditValues(prop, 'Property');
			j := slPropertyMap.IndexOfName(value_PropertyType);

			if j = -1 then
			begin
				mappedValues.Add('');	// necessary, so that number of records stay the same
				continue;
			end;

			value_Type := GetElementEditValues(prop, 'Value Type');
			value_PropertyType := GetElementEditValues(prop, 'Property');
			value_FunctionType := GetElementEditValues(prop, 'Function Type');
			mappedName := slPropertyMap.Values[value_PropertyType];
			mappedHelperFileValue := slPropertyMap.Values[RecordToString(LinksTo(ElementByIndex(prop, 6)))];

			//	begin 2nd LOOP

			if ((value_PropertyType = 'AimModelRecoilMinDegPerShot') or
				(value_PropertyType = 'AimModelMinConeDegrees') or
				(value_PropertyType = 'MinRange'))  and (mappedValue = '') then
			begin
		//		mappedValue := '';
				for i2 := 0 to Pred(ElementCount(properties)) do
        begin
          if (i2 = i) then
            continue;

          proploop2 := ElementByIndex(properties, i2);
          valuePropertytype2 := GetElementEditValues(proploop2, 'Property');
					j2 := slPropertyMap.IndexOfName(valuePropertytype2);

					if j2 = -1 then
          begin
            continue;
          end;

					loop1Result := '';
					loop2Result := '';
          value_Type_Loop2 := GetElementEditValues(proploop2, 'Value Type');
          valuefunctiontype2 := GetElementEditValues(proploop2, 'Function Type');
          loop2Result := GetNativeValue(ElementByIndex(proploop2, 6));
					loop1Result := GetNativeValue(ElementByIndex(prop, 6));

          if ((value_PropertyType = 'MinRange') and (valuePropertytype2 = 'MaxRange')) then
          begin
						dummyStr := 'Extend Range';
						if loop2Result > 1.0 then
            begin
						  loop1Result :=  FloatToStr(round((((256 * loop1Result) + 256) * 0.0142875) * 10) / 10);
						  loop2Result :=  FloatToStr(round((((256 * loop2Result) + 256) * 0.0142875) * 10) / 10);
              formatedloop1Result := format('%sm', [loop1Result]);
              formatedloop2Result := format('%sm', [loop2Result]);
						end
            else if loop2Result > 0.0 then
            begin
							loop1Result := IntToStr(Int(round(loop1Result * 1000) / 10));
							loop2Result := IntToStr(Int(round(loop2Result * 1000) / 10));
							formatedloop1Result := format('+%s%%', [loop1Result]);
							formatedloop2Result := format('+%s%%', [loop2Result]);
            end
            else
            begin
              loop1Result := IntToStr(Int(round(loop1Result * 1000) / 10));
              loop2Result := IntToStr(Int(round(loop2Result * 1000) / 10));
              formatedloop1Result := format('%s%%', [loop1Result]);
              formatedloop2Result := format('%s%%', [loop2Result]);
						end;
					end;

					if ((value_PropertyType = 'AimModelRecoilMinDegPerShot') and (valuePropertytype2 = 'AimModelRecoilMaxDegPerShot')) or
					((value_PropertyType = 'AimModelMinConeDegrees') and (valuePropertytype2 = 'AimModelMaxConeDegrees')) then
					begin
						if (value_PropertyType = 'AimModelRecoilMinDegPerShot') then dummyStr:= 'Recoil';
						if (value_PropertyType = 'AimModelMinConeDegrees') then dummyStr:= 'Spread';
            if loop2Result > 1.0 then
            begin
              loop1Result := FloatToStr(round(loop1Result * 10) / 10);
              loop2Result := FloatToStr(round(loop2Result * 10) / 10);
							formatedloop1Result := '+' + loop1Result + chr($00B0);
              formatedloop2Result := '+' + loop2Result + chr($00B0);
            end
            else if loop2Result > 0.0 then
            begin
              loop1Result := IntToStr(Int(round(loop1Result * 1000) / 10));
              loop2Result := IntToStr(Int(round(loop2Result * 1000) / 10));
              formatedloop1Result := '+' + loop1Result + chr($00B0);
              formatedloop2Result := '+' + loop2Result + chr($00B0);
            end
            else
            begin
              loop1Result := IntToStr(Int(round(loop1Result * 1000) / 10));
              loop2Result := IntToStr(Int(round(loop2Result * 1000) / 10));
							formatedloop1Result := loop1Result + chr($00B0);
              formatedloop2Result := loop2Result + chr($00B0);
            end;
					end;

					if loop2Result = '' then
						continue; // not looking for a string does nothing????

					if ((value_PropertyType = 'MinRange') and (valuePropertytype2 = 'MaxRange')) or
					((value_PropertyType = 'AimModelRecoilMinDegPerShot') and (valuePropertytype2 = 'AimModelRecoilMaxDegPerShot')) or
					((value_PropertyType = 'AimModelMinConeDegrees') and (valuePropertytype2 = 'AimModelMaxConeDegrees')) then
						begin
							indicesToSkip.Add(i);
							indicesToSkip.Add(i2);
							if (StrToFloat(loop1Result) >= StrToFloat(loop2Result)) then
								begin
									mappedValue := format('%s : %s', [dummyStr,formatedloop1Result]);
								end
								else
								begin
									mappedValue := format('%s (Min\Max): %s\%s', [dummyStr, formatedloop1Result, formatedloop2Result]);
									break;
								end;
						end;
				end;
			end;

	//	end 2nd LOOP AimModelRecoilMaxDegPerShot 

			if (((value_Type = 'Float') and (value_FunctionType = 'MUL+ADD') and (mappedValue = '')) and
			(not(value_PropertyType = 'MinRange') and
			not(value_PropertyType = 'MaxRange') and
			not(value_PropertyType = 'AimModelRecoilMinDegPerShot') and
			not(value_PropertyType = 'AimModelRecoilMaxDegPerShot') and
			not(value_PropertyType = 'AimModelMinConeDegrees') and
			not(value_PropertyType = 'AimModelMaxConeDegrees') and
			not(value_Propertytype = 'AimModelRecoilShotsForRunaway'))) then
			begin
					floatValue := GetElementEditValues(prop, 'Value 1');
					if floatValue > 1.0 then
						begin
							loop1Result := format('%s', [FloatToStr(round(floatValue * 10) / 10)]);
						end
						else if floatValue > 0.0 then
						begin
							loop1Result := format('+%s%%', [IntToStr(Int(round(floatValue * 1000) / 10))]);
						end
						else
						begin
							loop1Result := format('%s%%', [IntToStr(Int(round(floatValue * 1000) / 10))]);
						end;
						mappedValue := format('%s%s', [mappedName, loop1Result]);
			end;

			if ((value_Type = 'Float') and ((value_FunctionType = 'SET') or (value_FunctionType = 'ADD'))) and
			(not(value_PropertyType = 'MinRange') and
			not(value_PropertyType = 'MaxRange') and
			not(value_PropertyType = 'AimModelRecoilMinDegPerShot') and
			not(value_PropertyType = 'AimModelRecoilMaxDegPerShot') and
			not(value_PropertyType = 'AimModelMinConeDegrees') and
			not(value_PropertyType = 'AimModelMaxConeDegrees')) and (mappedValue = '') then
				begin
					floatValue := GetElementEditValues(prop, 'Value 1');
					if floatValue > 1.0 then
						begin
						loop1Result := format('%sx', [FloatToStr(round(floatValue * 10) / 10)]);
						end
						else if floatValue > 0.0 then
						begin
							loop1Result := format('+%s%%', [IntToStr(Int(round(floatValue * 1000) / 10))]);
						end
						else
						begin
							loop1Result := format('%s%%', [IntToStr(Int(round(floatValue * 1000) / 10))]);
						end;
						mappedValue := format('%s%s', [mappedName, loop1Result]);
				end;

			// Pure Value

			if ((value_Propertytype = 'NumProjectiles') or
				(value_Propertytype = 'AimModelRecoilShotsForRunaway') or
			(value_Propertytype = 'AttackDamage')) and (mappedValue = '') then
				begin
					floatValue := GetElementEditValues(prop, 'Value 1');
					loop1Result := format('%s', [FloatToStr(round(floatValue * 10) / 10)]);
					mappedValue := format('%s%s', [mappedName, loop1Result]);
				end;

			// calculate off 'Value 2'

			if ((value_Propertytype = 'DamageTypeValue') or
      (value_Propertytype = 'DamageTypeValues'))  and (mappedValue = '') then
			begin
				floatValue := GetElementEditValues(prop, 'Value 2');
				if floatValue > 1.0 then
				begin
					loop1Result := FloatToStr(round(floatValue * 10) / 10);
				end
				else if floatValue > 0.0 then
				begin
					loop1Result := format('+%s%%', [IntToStr(Int(round(floatValue * 1000) / 10))]);
				end
				else
				begin
					loop1Result := format('%s%%', [IntToStr(Int(round(floatValue * 1000) / 10))]);
				end;
			mappedValue := format('%s Damage: %s', [mappedHelperFileValue, loop1Result]);
			end;

			if ((mappedName = 'MaterialSwaps_Values_Type') or
				(mappedName = 'MaterialSwaps_Values_Type') or
				(mappedName = 'Keywords_Values_Type')  or
				(mappedName = 'Actor_Values_Type')) and (mappedValue = '') then
						continue;

			if ((mappedName = 'Enchantments_Value') or
				(value_PropertyType = 'ZoomData'))  and (mappedValue = '')  then
				begin
				mappedValue := format('%s', [mappedHelperFileValue]);
				end;

			if ((mappedName = 'Damage_Resistance')  and (mappedValue = ''))  then
				begin
					mappedValue := format('Reduces %s damage by: %s', [mappedHelperFileValue, loop1Result]);
				end;
			if (mappedName = 'Ammo_Type')  and (mappedValue = '') then
				begin
					tmpint := LinksTo(ElementByIndex(prop, 6));
					loop1Result := GetEditValue(ElementByPath(tmpint, 'ONAM'));
					if Length(loop1Result) = 0 then
						begin
							mappedValue := GetEditValue(ElementByPath(tmpint, 'FULL'));
							mappedValue := format('Changes Ammo to %s', [GetNameWithoutTags(loop1Result, 0)]);
						end else
					mappedValue := format('Changes Ammo to %s', [GetNameWithoutTags(loop1Result, 0)]);
				end;

			DebugLog(Format('EOF value_PropertyType: %s | EOF mappedName: %s | EOF mappedValue: %s'  , [value_PropertyType, mappedName, mappedValue]));
			sl.Add(format('%.3d', [j]) + mappedValue);

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

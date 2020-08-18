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
//uses 'Effs_Lib\EffsXEditTools';


const
  sPropertiesList = wbScriptsPath + 'Gernashs_Lib\Gernashs description Renamer - Resource.txt';

var
  slPropertyMap: TStringList;
  plugin: IInterface;
	ResultTextsList, ModificationsDoneList, ChecksFailedList, ChecksSuccessfulList, BeforeChangesList, AfterChangesList : TStringList;
	bChecksFailed, bAborted, bModificationNecessary : Boolean;
	

procedure GetMappedValues(rec : IInterface; mappedValues, indicesToSkip, mappedValuesFormat : TStringList;);
var
  valuetype, valuefunctiontype, valuePropertytype : string;
	loopResult, loopResultFormatted : string;
  floatValue : Real;
	prop, properties: IInterface;
	i,j,dummyInt : Integer;
	
  // OMOD Property Value Sort to %, x, deg or Value {{{THE MATHS}}}
  
  
begin
	LogFunctionStart('GetMappedValues');
	properties := ElementByPath(rec, 'DATA\Properties');
	for i := 0 to Pred(ElementCount(properties)) do
	begin
		if indicesToSkip.Find(i,dummyInt) then begin
			mappedValues.Add('');//necessary, so that number of records stay the same
			mappedValuesFormat.Add('');
			continue;
		end;
	
		prop := ElementByIndex(properties, i);
		valuePropertytype := GetElementEditValues(prop, 'Property');
		j := slPropertyMap.IndexOfName(valuePropertytype);
		if j = -1 then begin
			mappedValues.Add('');//necessary, so that number of records stay the same
			mappedValuesFormat.Add('');
			Continue;
		end;
		
		loopResult:= '';
		loopResultFormatted:= '';
		
		valuetype := GetElementEditValues(prop, 'Value Type');
		valuePropertytype := GetElementEditValues(prop, 'Property');
		valuefunctiontype := GetElementEditValues(prop, 'Function Type');

		if (valuePropertytype = 'AimModelRecoilArcRotateDeg') or 
			(valuePropertytype = 'AimModelMinConeDegrees') or
			(valuePropertytype = 'AimModelMaxConeDegrees') or  
			(valuePropertytype = 'AimModelRecoilMinDegPerShot') or
			(valuePropertytype = 'AimModelRecoilMaxDegPerShot') or
			(valuePropertytype = 'AimModelRecoilHipMult') or
			(valuePropertytype = 'AimModelRecoilArcDeg') then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			if floatValue > 1.0 then
			begin
				loopResult := FloatToStr(floatValue);
				loopResultFormatted := '+' + FloatToStr(floatValue) + chr($00B0);
			end else if floatValue > 0.0 then
			begin
				loopResult := IntToStr(Int(floatValue * 100));
				loopResultFormatted := '+' + IntToStr(Int(floatValue * 100)) + chr($00B0);
			end else
			begin
				loopResult := IntToStr(Int(floatValue * 100));
				loopResultFormatted := IntToStr(Int(floatValue * 100))+ chr($00B0);
			end;
		end
		
		else if (valuePropertytype = 'Speed') or
			(valuePropertytype = 'MinRange') or
			(valuePropertytype = 'MaxRange') or  
			(valuePropertytype = 'OutOfRangeDamageMult') or
			(valuePropertytype = 'AttackActionPointCost') or
			(valuePropertytype = 'CriticalDamageMult') or
			(valuePropertytype = 'MinPowerPerShot') or
			(valuePropertytype = 'AimModelConeIronSightsMultiplier') or
			(valuePropertytype = 'ZoomDataFOVMult') or
			(valuePropertytype = 'SecondaryDamage') or
			(valuePropertytype = 'AimModelBaseStability') or
			(valuePropertytype = 'AttackDamage') or
			(valuePropertytype = 'AmmoCapacity') or
			(valuePropertytype = 'ReloadSpeed') then
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			if floatValue > 1.0 then
			Begin
					loopResult := FloatToStr(floatValue);
					loopResultFormatted := FloatToStr(floatValue) + 'x';
					if valuePropertytype = 'AmmoCapacity' then
					loopResultFormatted := FloatToStr(floatValue);
				end else if floatValue > 0.0 then
				begin
					loopResult := IntToStr(Int(floatValue * 100));
					loopResultFormatted := '+' + IntToStr(Int(floatValue * 100)) + '%';
				end else
				begin
					loopResult := IntToStr(Int(floatValue * 100));
					loopResultFormatted := IntToStr(Int(floatValue * 100)) + '%';
				end;
		end
		
		else if (valuePropertytype = 'Rating') or
			(valuePropertytype = 'Health') then
			begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			if floatValue > 1.0 then
				Begin
					loopResult := FloatToStr(floatValue);
					loopResultFormatted := FloatToStr(floatValue);
				end else if floatValue > 0.0 then
				begin
					loopResult := IntToStr(Int(floatValue * 100));
					loopResultFormatted := '+' + IntToStr(Int(floatValue * 100)) + '%';
				end else
				begin
					loopResult := IntToStr(Int(floatValue * 100));
					loopResultFormatted := IntToStr(Int(floatValue * 100)) + '%';
				end;
		end
			
		else if (valuePropertytype = 'NumProjectiles') or 
			(valuePropertytype = 'AimModelRecoilShotsForRunaway')then 
		begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			loopResult := FloatToStr(floatValue);
			loopResultFormatted := FloatToStr(floatValue) + ' rnd';
		end	
		
		else if (valuePropertytype = 'SightedTransitionSeconds') or
			(valuePropertytype = 'FullPowerSeconds') or
			(valuePropertytype = 'AttackDelaySec') then
			begin
			floatValue := GetNativeValue(ElementByIndex(prop, 6));
			if floatValue > 1.0 then
				Begin
					loopResult := FloatToStr(floatValue);
					loopResultFormatted := FloatToStr(floatValue) + ' sec';
				end else if floatValue > 0.0 then
				begin
					loopResult := IntToStr(Int(floatValue * 100));
					loopResultFormatted := '+' + IntToStr(Int(floatValue * 100)) + '%';
				end else
				begin
					loopResult := IntToStr(Int(floatValue * 100));
					loopResultFormatted := IntToStr(Int(floatValue * 100)) + '%';
				end;
		end
		
		else if (valuePropertytype = 'DamageTypeValue') or
			(valuePropertytype = 'DamageTypeValues') then 
			begin 
				floatValue := GetNativeValue(ElementByIndex(prop, 7)); // Value 2
				if floatValue > 1.0 then
				begin
					loopResult := FloatToStr(floatValue);
					loopResultFormatted := FloatToStr(floatValue);
				end else if floatValue > 0.0 then
				begin
					loopResult := IntToStr(Int(floatValue * 100));
					loopResultFormatted := '+' + IntToStr(Int(floatValue * 100)) + '%';
				end else
				begin
					loopResult := IntToStr(Int(floatValue * 100));
					loopResultFormatted := IntToStr(Int(floatValue * 100)) + '%';
				end;
		end
		
		else if (valuePropertytype = 'ActorValues') then
		begin
			floatValue := GetElementEditValues(prop, 'Value 2'); // Value 2
			loopResult := IntToStr(floatValue);
			loopResultFormatted := IntToStr(floatValue);
			end
	
		else if	(valuePropertytype = 'Enchantments') then 
		begin	
		  loopResult := slPropertyMap.Values[GetEditValue(ElementByIndex(prop, 6))];
		  loopResultFormatted := slPropertyMap.Values[GetEditValue(ElementByIndex(prop, 6))];
		end;
	
     // DebugLog(Format('loopResultFormatted: %s', [loopResultFormatted]));
     //   DebugLog(Format('loopResult: %s', [loopResult]));
		
		// add property index as prefix for sorting
		
		mappedValues.Add(loopResult);
		mappedValuesFormat.Add(loopResultFormatted);
	end;
	LogFunctionEnd;
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
	mappedValuesFormat, mappedValues, indicesToSkip : TStringList;
	i,j,k, dummyInt : Integer;
begin
	LogFunctionStart('GetMappedDescription');
	mappedValues:=TStringList.Create;
	indicesToSkip:=TStringList.Create;
	mappedValuesFormat:=TStringList.Create;
	indicesToSkip.Sorted:=true; //so that .Find() works
	
	try
		GetMappedValues(rec, mappedValues, indicesToSkip, mappedValuesFormat);
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
			mappedValueFormat := mappedValuesFormat[i];
			value1Loop1 := slPropertyMap.Values[GetEditValue(ElementByIndex(prop, 6))];
			valuefunctiontype := GetElementEditValues(prop, 'Function Type');
			valuetype := GetElementEditValues(prop, 'Value Type');

		if mappedName = 'Damage_Type' then 
		begin
			
			for k := 0 to Pred(ElementCount(properties)) do
			begin
				if (k=i) then
					continue; 
				prop2 := ElementByIndex(properties, k);
				
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
                    indicesToSkip.Add(k);
                    loopResult := Format('%s damage: %s', [value1Loop2, mappedValueFORMAT]);
                    break;
				end;
			end;
			
			if loopResult = '' then
				loopResult := Format('%s damage: %s', [value1Loop1, mappedValueFORMAT]);
		end

		else if mappedName = 'Damage_Resistance' then 
		begin
		
            for k := 0 to Pred(ElementCount(properties)) do
            begin
                if (k=i) then
                    continue; 
					prop2 := ElementByIndex(properties, k);

                if slPropertyMap.IndexOfName(GetElementEditValues(prop2, 'Property')) = -1 then 
				begin
                    Continue;
                end; 

                valuetype2 := GetElementEditValues(prop2, 'Value Type');
                valuePropertytype2 := GetElementEditValues(prop2, 'Property');
                valuefunctiontype2 := GetElementEditValues(prop2, 'Function Type');
                value1Loop2 := slPropertyMap.Values[GetEditValue(ElementByIndex(prop2, 6))];

                if value1Loop2 = '' then continue;

                if (valuetype2 = 'FormID,Int') and (valuePropertytype2 = 'Keywords') then
                begin
                    indicesToSkip.Add(k);
                    loopResult := Format('Reduces %s damage by: %s', [value1Loop2, mappedValueFORMAT]);
                    break;
                end;
			end;

			if loopResult = '' then
				loopResult := Format('Reduces %s damage by: %s', [value1Loop1, mappedValueFORMAT]);
        end 

		else if (mappedName = 'Range (Min\Max):') or (mappedName = 'Recoil (Min\Max):') or (mappedName = 'Spread (Min\Max):') then
        begin
		
              for k := 0 to Pred(ElementCount(properties)) do
              begin
                  if (k=i) then
                      continue;
                  prop2 := ElementByIndex(properties, k);

                  if slPropertyMap.IndexOfName(GetElementEditValues(prop2, 'Property')) = -1 then begin
                      Continue;
                  end;

                  valuetype2 := GetElementEditValues(prop2, 'Value Type');
                  valuePropertytype2 := GetElementEditValues(prop2, 'Property');
                  valuefunctiontype2 := GetElementEditValues(prop2, 'Function Type');
				  value1Loop2 := GetNativeValue(ElementByIndex(prop2, 6));
				  mappedValue2 := FloatToStr(value1Loop2);

				
         if (mappedName = 'Range (Min\Max):') then
            begin
                    if value1Loop2 > 1.0 then
                    begin
						mappedValue2 := FloatToStr(value1Loop2);
						mappedValue2FORMAT := format('%sx',[FloatToStr(value1Loop2)]);
                    end else if value1Loop2 > 0.0 then
                    begin
						mappedValue2 := IntToStr(Int(value1Loop2 * 100));
						mappedValue2FORMAT := format('+%s%', [IntToStr(Int(value1Loop2 * 100))]);
                    end else
					begin
						mappedValue2 := IntToStr(Int(value1Loop2 * 100));
						mappedValue2FORMAT := IntToStr(Int(value1Loop2 * 100)) + '%';
					end;
			end 

			else if (mappedName = 'Recoil (Min\Max):') or (mappedName = 'Spread (Min\Max):') then
            begin
                    if value1Loop2 > 1.0 then
                    begin
						mappedValue2 := FloatToStr(value1Loop2);
						mappedValue2FORMAT := '+' + FloatToStr(value1Loop2) + chr($00B0);
                    end else if value1Loop2 > 0.0 then
                    begin
						mappedValue2 := IntToStr(Int(value1Loop2 * 100));
						mappedValue2FORMAT := '+' + IntToStr(Int(value1Loop2 * 100)) + chr($00B0);
                    end else
					begin
						mappedValue2 := IntToStr(Int(value1Loop2 * 100));
						mappedValue2FORMAT := IntToStr(Int(value1Loop2 * 100)) + chr($00B0);
					end;
			end ;

        if value1Loop2 = '' then continue; //not looking for a string does nothing????

         if (mappedName = 'Range (Min\Max):') and (valuePropertytype2 = 'MaxRange') then
         begin
            indicesToSkip.Add(k);
            if (mappedValue = mappedValue2) then
              loopResult := Format('Range: %s', [mappedValueFORMAT])
            else begin
              loopResult := Format('%s %s\%s', [mappedName, mappedValueFORMAT, mappedValue2FORMAT]);
              break;
			end;
		end
        else if (mappedName = 'Recoil (Min\Max):') and (valuePropertytype2 = 'AimModelRecoilMaxDegPerShot') then
        begin
              indicesToSkip.Add(k);
              if (mappedValue = mappedValue2) then
                loopResult := Format('Recoil: %s', [mappedValueFORMAT])
              else begin
                loopResult := Format('%s %s\%s', [mappedName, mappedValueFORMAT, mappedValue2FORMAT]);
                break;
              end;
		end
            else if (mappedName = 'Spread (Min\Max):') and (valuePropertytype2 = 'AimModelMaxConeDegrees') then
            begin
              indicesToSkip.Add(k);
              if (StrToFloat(mappedValue) >= StrToFloat(mappedValue2)) then
                loopResult := Format('Spread: %s', [mappedValueFORMAT])
              else begin
                loopResult := Format('%s %s\%s', [mappedName, mappedValueFORMAT, mappedValue2FORMAT]);
                break;
              end;
		end;
				if (mappedName = 'Range (Min\Max):') and (loopResult = '') then
				begin
					loopResult := Format('Range: %s', [mappedValueFORMAT]);
					end;
				if (mappedName = 'Recoil (Min\Max):') and (loopResult = '') then
				begin
					loopResult := Format('Recoil: %s', [mappedValueFORMAT]);
					end;
				if (mappedName = 'Spread (Min\Max):') and (loopResult = '') then
				begin
					loopResult := Format('Spread: %s', [mappedValueFORMAT]);
					end;
        end;

        
      end
				
			else if (mappedName = 'Actor_Values_Type') and 
				(value1Loop1 <> 'NFW') then
				begin if (mappedValue = '1') or (value1Loop1 = '') then
					begin
					loopResult := value1Loop1;
					end	else
					loopResult := Format('%s' + '+' + '%s', [value1Loop1, mappedValue])
				end
				
				
		
				
			else if ((mappedName = 'MaterialSwaps_Values_Type') and
					(valuetype <> 'REM') and 
					(value1Loop1 <> 'NFW')) or 				
					(mappedName = 'Ammo_Type') then
				begin
					loopResult := value1Loop1;
				end
			
			else if ((mappedName = 'Enchantments_Value') and 
					(value1Loop1 <> 'NFW')) or 
					((mappedName = 'Keywords_Values_Type') and 
					(value1Loop1 <> '') and 
					(value1Loop1 <> 'Energy') and 
					(value1Loop1 <> 'Cold') and 
					(value1Loop1 <> 'Radiation') and 
					(value1Loop1 <> 'Split Beam Shotgun Energy')) then
				begin
					loopResult := value1Loop1;
				end
				
			else if (value1Loop1 <> 'NFW') and 
				(mappedName <> '\') and
				(valuetype <> 'REM') and 
				(mappedName <> 'Keywords_Values_Type') and
				(mappedName <> 'Actor_Values_Type') and 
				(mappedName <> 'Enchantments_Value') and
				(mappedName <> 'NFW') and 
				(mappedValue <> 'NFW') then
				begin
				loopResult := Format('%s%s', [mappedName, mappedValueFormat]);
				end

//        	DebugLog(Format('mappedName: %s', [mappedName]));
//        	DebugLog(Format('mappedValue: %s', [mappedValue]));
//       	DebugLog(Format('value1Loop1: %s', [value1Loop1]));
//        	DebugLog(Format('valuetype: %s', [valuetype]));
//        	DebugLog(Format('valuetype2: %s', [valuetype2]));
//        	DebugLog(Format('mappedValue2: %s', [mappedValue2]));
//        	DebugLog(Format('valuePropertytype2: %s', [valuePropertytype2]));
//        	DebugLog(Format('valuefunctiontype2: %s', [valuefunctiontype2]));
//        	DebugLog(Format('value1Loop2: %s', [value1Loop2]));
//        	DebugLog(Format('loopResult: %s', [loopResult]));

			// add property index as prefix for sorting

			sl.Add(Format('%.3d', [j]) + loopResult);
		end;
		
	finally
		mappedValues.Free;
		mappedValues:=nil;
		indicesToSkip.Free;
		indicesToSkip:=nil;
		mappedValuesFormat.Free;
		mappedValuesFormat:=nil;
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
  sl.Sorted := true; // sorting automatically happens at insert

  try
    
		GetMappedDescription(rec, sl);

    // concatenate and remove prefixes

    for i := 0 to sl.Count - 1 do
    begin
      proprefix := Copy(sl[i], 4, Length(1));
      prosuffix := RightStr(Result, 1);
      if (proprefix = '') or 
	  (proprefix = '\') or 
	  (prosuffix = ' ') then
      begin
        Result := Result;
      end else if Result <> '' then
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

function Initialize: Integer;
begin
	bModificationNecessary := true;
	LogFunctionStart('Initialize');
	
  slPropertyMap := TStringList.Create;
  slPropertyMap.LoadFromFile(sPropertiesList);
	
	ResultTextsList:= TStringList.Create;
	ChecksFailedList:= TStringList.Create;
	ChecksSuccessfulList:= TStringList.Create;
	ModificationsDoneList:= TStringList.Create;
	BeforeChangesList:= TStringList.Create;
	AfterChangesList:= TStringList.Create;
	
	SetDefaultConfig;
	
	LogFunctionEnd;
end;

function Process(e: IInterface): Integer;
var
  desc, oldDesc: string;
  r: IInterface;
begin
	LogFunctionStart('Process');
	
	if not CheckRecordSignature(e) then
		Exit
	else
		LogCheckSuccessful('This record has the right signature');
	
	// patch the winning override record
	e := WinningOverride(e);

  if not Assigned(e) then
  begin
    LogCheckFailed
      ('something went wrong when getting the override for this record.');
    bAborted := true;
  end;
	
	//DebugLog(Format('Mode: "%d"',[GlobConfig.PluginSelectionMode]));
	
	if not bAborted then begin
		// create new plugin
		if not Assigned(plugin) then
		begin
			CreateMainForm;
			
			if GlobConfig.PluginSelectionMode = 1 then begin
				plugin := AddNewFile;
				LogModification(Format('new plugin created: %s',[GetFileName(plugin)]));
			end else if GlobConfig.PluginSelectionMode = 2 then begin 
				plugin := FileByIndex(Pred(FileCount));
				LogCheckSuccessful(Format('Existing plugin selected to store record: %s',[GetFileName(plugin)]));
			end else begin //also happening on "Cancel"
				//bAborted := true;
				Log('Operation aborted by user.');
				Exit; //--> no result form necessary here
			end;
			
			if not bAborted and not Assigned(plugin) then
			begin
				LogCheckFailed('The plugin selected could not be loaded. Operation aborted.');
				bAborted := true;
			end;
		end;

		// skip already copied
		if (not bAborted) and (GetFileName(e) = GetFileName(plugin)) then begin
			LogCheckFailed(Format('The plugin to store the record would overwrite the existing record. Operation aborted. - plugin: %s',[GetFileName(plugin)]));
			bAborted := true;
		end;
	end;
	
	if not bAborted then begin
		desc := GetOmodDescription(e);

		if desc = '' then begin
			 LogCheckFailed('The logic would have created an empty description. Operation aborted.');
			 bAborted := true;
		end;
	end;
	
	if not bAborted then begin
		oldDesc := GetEditValue(ElementByPath(e, 'DESC'));
		
		if SameText(oldDesc, desc) then
		begin
			LogCheckSuccessful(Format('Description already up to date. Operation aborted. - DESC: "%s"',[desc]));
			bModificationNecessary := false;
		end else begin
			BeforeChangesList.Add(Format('DESC: "%s"',[oldDesc]));
		end;
	end;

	if (not bAborted) and (bModificationNecessary) then begin
		// add masters
		AddRequiredElementMasters(e, plugin, False);

		try
			// copy as override
			r := wbCopyElementToFile(e, plugin, False, true);
			if not Assigned(r) then
			begin
				LogCheckFailed('Something went wrong when creating the override record.');
				bAborted := true;
			end else begin
				LogModification(Format('The record was copied to the selected plugin as an override. - plugin: %s',[GetFileName(plugin)]));
				
				// setting new description
				SetElementEditValues(r, 'DESC', desc);
				LogModification(Format('Description was replaced: - old DESC: "%s" - new DESC: "%s"',[oldDesc,desc]));
				AfterChangesList.Add(Format('DESC: "%s"',[desc]));
			end;
		except
			on Ex: Exception do
			begin
				LogCheckFailed('Failed to copy: ' + FullPath(e));
				LogCheckFailed('    reason: ' + Ex.Message);
			end
		end;
	end;
		
	PrepareResults(bChecksFailed, bAborted, e);
	
	LogFunctionEnd;
end;


function Finalize: Integer;
begin
	LogFunctionStart('Finalize');
  
	CreateResultsForm(bChecksFailed, bAborted, ResultTextsList);

	slPropertyMap.Free;
  slPropertyMap := nil;
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
//  Pure Checks (do not contain modification)
//=========================================================================

function CheckRecordSignature(rec : IInterface;) : Boolean;
begin
	LogFunctionStart('CheckRecordSignature');
	Result:= true;
	
	if Signature(rec) <> 'OMOD' then begin
		MessageDlg('The record you are trying to perform this script on has the wrong signature. It should be an OMOD.', mtWarning, [mbAbort], 0);
		Result:=false;
	end;
	
	LogFunctionEnd;
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
procedure PrepareResults (bChecksFailed: boolean; bAborted : boolean; rec : IInterface;);
const
	headerStr = '-------------------------------------------------------------------';
var 
	tmpStr : String; //overwritten with every usage
	i : Integer;
begin
	LogFunctionStart('PrepareResults');
	
	ResultTextsList.Add(FormatResultHeader('General Information:',headerStr));
	ResultTextsList.Add('OMOD: ' + GetElementEditValues(rec, 'Record Header\FormID'));
	ResultTextsList.Add('Created by plugin: ' + GetFileName(MasterOrSelf(rec)));
	ResultTextsList.Add('Winning Override in plugin: ' + GetFileName(WinningOverride(rec)));
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
	
	ChecksFailedList.Clear;
	ChecksSuccessfulList.Clear;
	ModificationsDoneList.Clear;
	BeforeChangesList.Clear;
	AfterChangesList.Clear;
	
	
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

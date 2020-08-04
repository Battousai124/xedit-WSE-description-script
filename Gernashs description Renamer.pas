//
// Date:2020-08-01 WIP (3)
// Ver: 1.0
// Author: Gernash
//

unit Renamer; //FO4PatchOmodDescriptions;
 
const
  sPropertiesList = wbScriptsPath + 'Gernashs description Renamer - Resource.txt';
 
var
  slPropertyMap: TStringList;
  plugin: IInterface;
 
function GetMappedValue(prop: IInterface): String;
var
  valuetype, valuefunctiontype, valuePropertytype: string;
  f: Real;
  g: String;
  

// OMOD Property Value Sort to %, x, deg or Value {{{THE MATHS}}}

  
begin
	valuetype := GetElementEditValues(prop, 'Value Type');
  valuePropertytype := GetElementEditValues(prop, 'Property');
  valuefunctiontype := GetElementEditValues(prop, 'Function Type');
 
if (valuetype = 'FormID,Float') and (valuefunctiontype = 'MUL+ADD') then begin
    f := GetNativeValue(ElementByIndex(prop, 7));
		if f > 1.0 then
		  Result := FloatToStr(f) + 'x'
   	else if f > 0.0 then
		  Result := '+' + IntToStr(Int(f * 100)) + '%'
		else
		  Result := IntToStr(Int(f * 100)) + '%';
	end
	
else if (valuetype = 'FormID,Float') and (valuePropertytype = 'DamageTypeValue') then begin 
    f := GetNativeValue(ElementByIndex(prop, 7));
		  Result := FloatToStr(f);
	end
	
else if valuetype = 'FormID,Float' then begin
	f := GetNativeValue(ElementByIndex(prop, 7));
		if f > 5.0 then
		  Result := FloatToStr(f) + '%'
		else if f > 0.0 then
		  Result := FloatToStr(f)
	end
	
else if (valuePropertytype = 'AimModelRecoilArcRotateDeg') or (valuePropertytype = 'AimModelRecoilMinDegPerShot') or (valuePropertytype = 'AimModelRecoilMaxDegPerShot') or (valuePropertytype = 'AimModelRecoilArcDeg') then begin
    f := GetNativeValue(ElementByIndex(prop, 6));
		if f > 1.0 then
		  Result := '+' + FloatToStr(f) + chr($00B0)
		else if f > 0.0 then
		  Result := '+' + IntToStr(Int(f * 100)) + chr($00B0)
		else
		  Result := IntToStr(Int(f * 100)) + chr($00B0);
	end

else if (valuePropertytype = 'AimModelMinConeDegrees') or (valuePropertytype = 'AimModelMaxConeDegrees') then begin
    f := GetNativeValue(ElementByIndex(prop, 6));
		if f > 1.0 then
		  Result := FloatToStr(f * 100) + '%'
		else if f > 0.0 then
		  Result := '+' + IntToStr(Int(f * 100)) + '%'
		else
		  Result := IntToStr(Int(f * 100)) + '%';
	end
	
else if (valuetype = 'Float') and (valuefunctiontype = 'MUL+ADD') then begin
    f := GetNativeValue(ElementByIndex(prop, 6));
		if f > 1.0 then
		  Result := FloatToStr(f) + 'x'
		else if f > 0.0 then
		  Result := '+' + IntToStr(Int(f * 100)) + '%'
		else
		  Result := IntToStr(Int(f * 100)) + '%';
	end

else if (valuetype = 'Float') and (valuefunctiontype = 'MinRange') then begin
    f := GetNativeValue(ElementByIndex(prop, 6));
		  Result := FloatToStr(f) + 'units';
		end

else if valuetype = 'Float' then begin
    f := GetNativeValue(ElementByIndex(prop, 6));
		if f > 1.0 then
		  Result := FloatToStr(f) + 'x'
		else if f > 0.0 then
		  Result := '+' + IntToStr(Int(f * 100)) + '%'
		else
		  Result := IntToStr(Int(f * 100)) + '%';
	end

else if valuetype = 'Int' then begin	
	f := GetNativeValue(ElementByIndex(prop, 6));
		  Result := FloatToStr(f);
	end

else if (valuetype = 'FormID,Int') and ((valuePropertytype = 'ZoomData') or (valuePropertytype = 'Enchantments')) then begin	
		  Result := slPropertyMap.Values[GetEditValue(ElementByIndex(prop, 6))];
	end

else if valuetype = 'FormID,Int' then begin	
	f := GetNativeValue(ElementByIndex(prop, 6));
		if f > 1.0 then
		  Result := FloatToStr(f)
	end

end;
 
 
 // Property to Name Mapping Layout

 
function GetMappedDescription(prop: IInterface; propname: String): String;
var
  mappedName, mappedValue, query, queryfunction: String;
  f: Real;
begin
  mappedName := slPropertyMap.Values[propname];
  mappedValue := GetMappedValue(prop);
  query := slPropertyMap.Values[GetEditValue(ElementByIndex(prop, 6))];
  queryfunction := GetElementEditValues(prop, 'Function Type');
	
	if mappedValue = '\' then
		Result := Format('%s%s', [mappedName, mappedValue])+ ''
		
	else if mappedName = 'Damage_Type' then  
		Result := Format('Additional ' + '%s' + ' Damage: ' + '%s', [query, mappedValue])
		
	else if mappedName = 'Damage_Resistance' then  
		Result := Format('%s' + ' Damage Reduced by: ' + '%s', [query, mappedValue])
		
	else if	(mappedName = 'Actor_Values_Type') and (query <> 'NFW') then
		Result := Format('%s' '+' + '%s', [query, mappedValue])
		
	else if	(mappedName = 'Keywords_Values_Type') or (mappedName = 'MaterialSwaps_Values_Type')  or (mappedName = 'MaterialSwaps_Values_Type') or (mappedName = 'Enchantments_Value') or (mappedName = 'Ammo_Type') then
		Result := Format('%s', [query])
		
	else if (mappedName = 'Range (Min\Max):') or (mappedName = 'Recoil (Min\Max):') or (mappedName = 'Cone (Min\Max):') then  
		Result := Format('%s%s', [mappedName, mappedValue])
	
	else  if (query <> 'NFW') then
		Result := Format('%s%s', [mappedName, mappedValue]); //output layout 
		
end;
 
function GetOmodDescription(rec: IInterface): String;
var
  i, j: Integer;
  prop, properties: IInterface; 
  proprefix, prosuffix, propname: string;
  sl: TStringList;
  
begin
  sl := TStringList.Create;
	sl.Sorted := true; //sorting automatically happens at insert 
  
  try
		properties := ElementByPath(rec, 'DATA\Properties');
		
		for i := 0 to Pred(ElementCount(properties)) do begin
			prop := ElementByIndex(properties, i);
			propname := GetElementEditValues(prop, 'Property');
			j := slPropertyMap.IndexOfName(propname);
		if j = -1 then Continue;
			// add property index as prefix for sorting
			sl.Add( Format('%.3d', [j]) + GetMappedDescription(prop, propname) );
		end;

		//concatenate and remove prefixes

		for i := 0 to sl.Count - 1 do begin
			proprefix := Copy(sl[i], 4, Length(1));
			prosuffix := RightStr(Result, 1);
			if  (proprefix = '') or (proprefix = '\') or (prosuffix = ' ')then begin
				 Result := Result
			end
			else if  Result <> '' then begin
				 Result := Result + ' | '
			end
			Result := Result + Copy(sl[i], 4, Length(sl[i]));
		end
	finally
		sl.Free;
		sl:=nil;
	end;
end;
 
function Initialize: Integer;
begin
  slPropertyMap := TStringList.Create;
  slPropertyMap.LoadFromFile(sPropertiesList);
end;
 
function Process(e: IInterface): Integer;
var
  desc, oldDesc : string;
  r: IInterface;
begin
  if Signature(e) <> 'OMOD' then
    Exit;
 
  // patch the winning override record
 
  e := WinningOverride(e);
	
	if not Assigned(e) then begin
		AddMessage('something went wrong when getting the override for this record.');
		Exit;
	end;
  desc := GetOmodDescription(e);
 
  if desc = '' then
    Exit;
  
  oldDesc := GetEditValue(ElementByPath(e,'DESC'));
  if SameText(oldDesc,desc) then begin
		AddMessage(Format('description already up to date, ending script - description: "%s"',[desc]));
    Exit;
	end;
 
  // create new plugin
  if not Assigned(plugin) then begin
    if MessageDlg('Create new patch plugin [YES] or append to the last loaded one [NO]?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
      plugin := AddNewFile
    else
      plugin := FileByIndex(Pred(FileCount));
    if not Assigned(plugin) then begin
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
    r := wbCopyElementToFile(e, plugin, False, True);
		if not Assigned(r) then begin
			AddMessage('something went wrong when creating the override record.');
			Exit;
		end;
    // setting new description
    SetElementEditValues(r, 'DESC', desc);
  except
    on Ex: Exception do begin
      AddMessage('Failed to copy: ' + FullPath(e));
      AddMessage('    reason: ' + Ex.Message);
    end
  end;
 
end;
 
function Finalize: Integer;
begin
  slPropertyMap.Free;
  slPropertyMap:=nil;
  if Assigned(plugin) then
    SortMasters(plugin);
end;
 
end.

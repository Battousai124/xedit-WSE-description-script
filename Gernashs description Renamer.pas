//
// Date:2020-08-01 01:56
// Ver: 1.0
// Author: Gernash
//

unit FO4PatchOmodDescriptions;
 
const
  sPropertiesList = wbScriptsPath + '1MODRenamer.txt';
 
var
  slPropertyMap: TStringList;
  plugin: IInterface;
 
function GetMappedValue(prop: IInterface): String;
var
  valuetype, valuefunctiontype, valuePropertytype: string;
  f: Real;
  g: String;
  

// OMOD Property Value Sort to % or Value

  
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
else if (valuePropertytype = 'AimModelRecoilArcRotateDeg') or (valuePropertytype = 'AimModelRecoilMinDegPerShot') or (valuePropertytype = 'AimModelRecoilMaxDegPerShot') or (valuePropertytype = 'AimModelRecoilArcDeg') or (valuePropertytype = 'AimModelMinConeDegrees') or (valuePropertytype = 'AimModelMaxConeDegrees') then begin
    f := GetNativeValue(ElementByIndex(prop, 6));
		if f > 1.0 then
		  Result := '+' + FloatToStr(f) + chr($00B0)
	else if f > 0.0 then
		  Result := '+' + IntToStr(Int(f * 100)) + chr($00B0)
		else
		  Result := IntToStr(Int(f * 100)) + chr($00B0);
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
else if valuetype = 'FormID,Float' then begin
    f := GetNativeValue(ElementByIndex(prop, 7));
		  Result := FloatToStr(f);
	end
else if valuetype = 'Int' then begin	
	 f := GetNativeValue(ElementByIndex(prop, 6));
		  Result := FloatToStr(f);
 
	end
else if (valuetype = 'FormID,Int') and (valuePropertytype = 'ZoomData') then begin	
		Result := slPropertyMap.Values[GetEditValue(ElementByIndex(prop, 6))];
	end
	else if valuetype = 'FormID,Int' then begin	
	 f := GetNativeValue(ElementByIndex(prop, 6));
		if f > 1.0 then
		  Result := FloatToStr(f);
	end
	else if valuetype = 'FormID,Float' then begin
		Result := slPropertyMap.Values[GetEditValue(ElementByIndex(prop, 7))];
	end
end;
 
 
 // Mapping Name

 
function GetMappedDescription(prop: IInterface; propname: String): String;
var
  mappedName, mappedValue, query, queryfunction: String;
  f: Real;
begin
  mappedName := slPropertyMap.Values[propname];
  mappedValue := GetMappedValue(prop);
  query := slPropertyMap.Values[GetEditValue(ElementByIndex(prop, 6))];
  queryfunction := GetElementEditValues(prop, 'Function Type');
 
  if mappedValue = '' then exit;
  if mappedName = 'Potato' then exit;
  if query = 'Potato' then exit;
  if mappedValue = '\' then 
		Result := Format('%s%s', [mappedName, mappedValue])+ ''
	else if mappedName = 'Damage_Type' then 
		Result := 'Additional ' + Format('%s' + ' Damage: ' + '%s', [query, mappedValue])
	else if mappedName = 'Damage_Resistance' then 
		Result := Format('%s' + ' Damage Reduced by: ' + '%s', [query, mappedValue])
	else if	mappedName = 'Actor_Values_Type' then 
		Result := Format('%s' + '+' + '%s', [query, mappedValue])
	else if	(mappedName = 'Keywords_Values_Type') or (mappedName = 'MaterialSwaps_Values_Type') or (mappedName = 'Enchantments_Value') or (mappedName = 'MaterialSwaps_Values_Type') or (mappedName = 'Ammo_Type') then 
		Result := Format('%s', [query])
	else if (mappedName = 'Range (Min\Max):') or (mappedName = 'Recoil (Min\Max):') or (mappedName = 'Cone (Min\Max):')then 
		Result := Format('%s%s', [mappedName, mappedValue])
	else
		Result := Format('%s%s', [mappedName, mappedValue]); //output layout 
end;
 
function GetOmodDescription(rec: IInterface): String;
var
  i, j: Integer;
  prop, properties: IInterface; 
  propname: string;
  sl: TStringList;
  
begin
  sl := TStringList.Create;
  properties := ElementByPath(rec, 'DATA\Properties');
  
  for i := 0 to Pred(ElementCount(properties)) do begin
    prop := ElementByIndex(properties, i);
    propname := GetElementEditValues(prop, 'Property');
    j := slPropertyMap.IndexOfName(propname);
	if j = -1 then Continue;
// add property index as prefix for sorting
		sl.Add( Format('%.3d', [j]) + GetMappedDescription(prop, propname) );
  end;

// sort, concatenate and remove prefixes

  sl.Sort;
  for i := 0 to sl.Count - 1 do begin
	if  Result <> '' then Result := Result + ' | ';
		Result := Result + Copy(sl[i], 4, Length(sl[i]));
  end
    sl.Free;
end;
 
function Initialize: Integer;
begin
  slPropertyMap := TStringList.Create;
  slPropertyMap.LoadFromFile(sPropertiesList);
end;
 
function Process(e: IInterface): Integer;
var
  desc: string;
  r: IInterface;
begin
  if Signature(e) <> 'OMOD' then
    Exit;
 
  // patch the winning override record
 
  e := WinningOverride(e);
  desc := GetOmodDescription(e);
 
  if desc = '' then
    Exit;
 
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
  if Assigned(plugin) then
    SortMasters(plugin);
end;
 
end.

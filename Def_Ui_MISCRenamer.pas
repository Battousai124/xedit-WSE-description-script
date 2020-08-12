//
// Ver: 1
// WIP (2)
// Author: Gernash
// Scripting: 
// Tester:
//

  
unit Def_Ui_MISCRenamer; // FO4PatchOmodDescriptions;

// code for editing xEdit scripts with Delphi

interface

implementation

uses xEditAPI, Classes, SysUtils, StrUtils, Windows;

const
  sPropertiesList = wbScriptsPath + 'Def_Ui_MISCRenamer.txt';

var
  slPropertyMap: TStringList;
  plugin: IInterface;

procedure GetMappedValues(rec : IInterface; mappedValues, indicesToSkip, formatstrings : TStringList;);
var
  valuetype, valuefunctiontype, valuePropertytype : string;
  valuetype2, valuefunctiontype2, valuePropertytype2 : string;
  loopResult : string;
  floatValue, floatValue2: Real;
  prop, prop2, properties: IInterface;
  i,j,dummyInt : Integer;

  // OMOD Property Value Sort to %, x, deg or Value {{{THE MATHS}}}


begin
	properties := ElementBySignature(rec, 'CVPA - Components\Component');
	//properties := ElementByPath(rec, 'Component');
  for i := 0 to Pred(ElementCount(properties)) do
    begin
      if indicesToSkip.Find(i,dummyInt) then 
	  begin
        mappedValues.Add('');//necessary, so that number of records stay the same
        formatstrings.Add('');
        continue;
       end;

		prop := ElementByIndex(properties, i);
		valuePropertytype := GetElementEditValues(prop, 'Component');
		j := slPropertyMap.IndexOfName(valuePropertytype);
		if j = -1 then 
		begin
		  mappedValues.Add('');//necessary, so that number of records stay the same
		  formatstrings.Add('');
		  Continue;
		end;

		loopResult:= '';
		valuePropertytype := GetElementEditValues(prop, 'Component');
		floatValue := GetElementEditValues(prop, 'Count');
		loopResult:= FloatToStr(floatValue);

			// add property index as prefix for sorting

		mappedValues.Add(loopResult);
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
  i,j,k, dummyInt : Integer;
begin
  mappedValues:=TStringList.Create;
  indicesToSkip:=TStringList.Create;
  formatstrings:=TStringList.Create;
  indicesToSkip.Sorted:=true; //so that .Find() works

  try
    GetMappedValues(rec, mappedValues, indicesToSkip, formatstrings);
    properties := ElementBySignature(rec, 'CVPA - Components\Component');

    for i := 0 to Pred(ElementCount(properties)) do
      begin
        loopResult := '';
        if indicesToSkip.Find(i,dummyInt) then
          continue;

          prop := ElementByIndex(properties, i);
          valuePropertytype := GetElementEditValues(prop, 'Component');
          j := slPropertyMap.IndexOfName(valuePropertytype);

        if j = -1 then
          Continue;
	  loopResult := '';

          mappedName := slPropertyMap.Values[valuePropertytype];
          mappedValue := mappedValues[i];

			if (mappedName <> '') then
          loopResult := Format('%s (%s)', [mappedName, mappedValue]);
			
                // add property index as prefix for sorting

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
	  if Result <> '' then
            begin
              Result := Result + ', ';
            end;
		Result := Result + Copy(sl[i], 4, Length(sl[i]));
      end;
	Result := GetEditValue(ElementByPath(rec, 'FULL')) +' {{{' + Result + '}}}';
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
  if Signature(e) <> 'MISC' then
  Exit;

  // patch the winning override record

  e := WinningOverride(e);

  if not Assigned(e) then
  begin
    AddMessage('something went wrong when getting the override for this record.');
    Exit;
  end;
desc:= '';
    desc := GetOmodDescription(e);
  if desc = '' then
    Exit;

  oldDesc := GetEditValue(ElementByPath(e, 'FULL'));
  if SameText(oldDesc, desc) then
    begin
      AddMessage(Format('description already up to date, ending script - description: "%s"',[desc]));
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
        SetElementEditValues(r, 'FULL', desc);
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
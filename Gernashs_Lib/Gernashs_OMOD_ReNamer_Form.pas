unit Gernashs_OMOD_ReNamer_Form;

interface

implementation

uses xEditAPI, Classes, SysUtils, StrUtils, Windows;

uses ClipBrd;

uses StdCtrls;

var
  rgPluginSelectionMode, pnlPluginNameNew, pnlPluginNameDisplay,
    pnlPluginNameSelect, ddlPluginNameSelect: TPanel;
  tbFileName: TEdit;
  btnOk: TButton;
  lblPluginNameNotAllowed: TLabel;

  // =========================================================================
  // configuration form, opened as first form when the script is started - before any modifications
  // =========================================================================
procedure CreateMainForm(settings : TStringList);
var
  lbl: TLabel; // label object - re-used/overwritten for every label
  i, tmpInt, curTopPos: Integer; // re-used/overwritten every time
  tmpStringList: TStringList; // re-used/overwritten every time
  tmpStr: String; // re-used/overwritten every time
  tmpCbState: TCheckBoxState; // re-used/overwritten every time
  frm: TForm;
  gbGeneral, gbMainSettings, gbTranslateResourceFile: TGroupBox;
  cbGeneralWriteDebugLog, cbMainFunctionalDisplay: TCheckBox;
  pnlButtons, pnlTranslate: TPanel;
  btnCancel, btnTranslate: TButton;
begin
  LogFunctionStart('CreateMainForm');
  frm := TForm.Create(nil);
  tmpStringList := TStringList.Create;

  try
    frm.Caption := 'Gernash''s OMOD description renamer';
    frm.Width := 650;
    frm.Height := 400;
    frm.Position := poScreenCenter;

    lbl := ConstructLabel(frm, frm, 10, 10, 0, frm.Width - 30,
      'This tool automatically creates proper descriptions for OMODs. ' +
      chr(13) + chr(10) +
      'It analyzes the actual changes an OMOD does and creates a description that considers the changes the plugins you use introduced. This way the OMOD description is true to your personal mod setup.'
      + chr(13) + chr(10) + chr(13) + chr(10) +
      'Select the functionality you want the script to perform: (hover your mouse over an option and read the hints if something is unclear)',
      '');
    curTopPos := lbl.Top + lbl.Height + 12;

    // general settings
    tmpInt := frm.Height - curTopPos - 65;
    if GlobConfig.ShowResourceFileTranslationOption then
      tmpInt := (tmpInt / 2) + 6;
    gbGeneral := ConstructGroupBox(frm, frm, curTopPos, 10, tmpInt,
      (frm.Width - 20) / 4, 'General Settings ', '');
    cbGeneralWriteDebugLog := ConstructCheckBox2(frm, gbGeneral, 18, 10,
      gbGeneral.Width - 18, 'Write Debug Log', EnableDebugLog,
      'if checked: will write a detailed debug log into the Messages tab of xEdit - else only relevant outputs will be logged there'
      + chr(13) + chr(10) +
      '(This comes in handy if there is an error, so you can follow the execution path in the script.)'
      + chr(13) + chr(10) +
      '(At the end of the operation there will always be a result-window displayed.)');

    // special stuff
    if GlobConfig.ShowResourceFileTranslationOption then
    begin
      gbTranslateResourceFile := ConstructGroupBox(frm, frm,
        gbGeneral.Top + gbGeneral.Height, 10, frm.Height - gbGeneral.Height -
        gbGeneral.Top - 65, (frm.Width - 20) / 4, 'Translate File ', '');
      pnlTranslate := ConstructPanel(frm, gbTranslateResourceFile, 20, 0,
        gbTranslateResourceFile.Height, gbTranslateResourceFile.Width, '', '');
      pnlTranslate.BevelOuter := bvNone;
      lbl := ConstructLabel(frm, pnlTranslate, 10, 10, 0, pnlTranslate.Width,
        'create backup & then translate resorce' + chr(13) + chr(10), '');
      btnTranslate := ConstructButton(frm, pnlTranslate,
        pnlTranslate.Height - 55, 10, 0, 0, 'Translate File');
      btnTranslate.OnClick := OnClickTranslate;
      btnTranslate.ModalResult := mrCancel;

    end;

    // main settings
    gbMainSettings := ConstructGroupBox(frm, frm, gbGeneral.Top,
      gbGeneral.Width + 16, frm.Height - gbGeneral.Top - 65,
      frm.Width - gbGeneral.Width - 25, 'Check / Modification Settings ', '');

    // Plugin and Records
    lbl := ConstructLabel(frm, gbMainSettings, 20, 10, 16,
      gbMainSettings.Width - 30, 'Plugin and Records:', '');
    curTopPos := lbl.Top + 16;

    // plugin selection mode
    tmpStringList.Clear;
    tmpStringList.Add('automatic');
    tmpStringList.Add('create new');
    tmpStringList.Add('last in load order');
    rgPluginSelectionMode := ConstructPseudoRadioGroup(frm, gbMainSettings,
      curTopPos, 10, 20, gbMainSettings.Width - 12, 'Plugin to store changes',
      (gbMainSettings.Width - 12) / 3,
      'defines where changes are stored - e.g. a new plugin can be created at the end of the load order or an existing plugin can be used',
      tmpStringList, (gbMainSettings.Width - (gbMainSettings.Width - 12) / 3 -
      20) / tmpStringList.Count, GlobConfig.PluginSelectionMode, '');

    for i := 1 to tmpStringList.Count do
    begin
      rgPluginSelectionMode.Controls[i].OnClick := OnChangePluginSelectionMode;
    end;

    // plugin name
    pnlPluginNameSelect := ConstructPanel(frm, gbMainSettings,
      rgPluginSelectionMode.Top + rgPluginSelectionMode.Height, 10, 22,
      rgPluginSelectionMode.Width, '', '');
    pnlPluginNameSelect.BevelOuter := bvNone;
    lbl := ConstructLabel(frm, pnlPluginNameSelect, 3, 10, 16,
      (gbMainSettings.Width - 16) / 3, 'Select from found plugins',
      'Lists all plugins that were automatically created by this script before. The one lowest in the load order is selected by default.');
    if GlobConfig.ExistingGernashsDescrPlugins.Count > 0 then
      tmpStr := ''
    else
      tmpStr := GlobConfig.NewPluginName + '.esp';
    ddlPluginNameSelect := ConstructDropdown(frm, pnlPluginNameSelect, 0,
      lbl.Left + lbl.Width, 26,
      (gbMainSettings.Width - (gbMainSettings.Width - 12) / 3 - 20) * 2 / 3,
      GlobConfig.ExistingGernashsDescrPlugins.Count - 1,
      GlobConfig.ExistingGernashsDescrPlugins, lbl.Hint, tmpStr);
    ddlPluginNameSelect.Controls[1].OnChange := OnChangeExistingPluginDropdown;
    if GlobConfig.ExistingGernashsDescrPlugins.Count = 0 then
    begin
      lbl.Caption := 'New plugin name';
      lbl.Hint :=
        'There was no plugin found in the current load order that was automatically created by this script. Therefore a new plugin will be created with a default name.';
      lbl.Font.color := clGray;
      ddlPluginNameSelect.Controls[0].Top := ddlPluginNameSelect.Controls
        [0].Top - 1;
      ddlPluginNameSelect.Hint := lbl.Hint;
      ddlPluginNameSelect.Controls[0].Hint := lbl.Hint;
    end;
    if not(GlobConfig.PluginSelectionMode = 1) then
    begin
      pnlPluginNameSelect.Visible := false;
    end
    pnlPluginNameNew := ConstructPanel(frm, gbMainSettings,
      rgPluginSelectionMode.Top + rgPluginSelectionMode.Height, 10, 21,
      rgPluginSelectionMode.Width, '', '');
    pnlPluginNameNew.BevelOuter := bvNone;
    lbl := ConstructLabel(frm, pnlPluginNameNew, 3, 10, 16,
      (gbMainSettings.Width - 16) / 3, 'New plugin name',
      'Enter a plugin name for the new plugin (without file extension).');
    tbFileName := ConstructEdit(frm, pnlPluginNameNew, 0, lbl.Left + lbl.Width,
      21, (gbMainSettings.Width - (gbMainSettings.Width - 12) / 3 - 20) * 2 / 3,
      GlobConfig.NewPluginName, 'name for new ESP to be created');
    tbFileName.OnKeyUp := OnChangePluginName;
    lbl := ConstructLabel(frm, pnlPluginNameNew, lbl.Top,
      tbFileName.Left + tbFileName.Width, 16, 20, '.esp', '');
    lblPluginNameNotAllowed := ConstructLabel(frm, pnlPluginNameNew, lbl.Top,
      lbl.Left + lbl.Width + 20, 16, pnlPluginNameNew.Width - lbl.Left -
      lbl.Width, 'not allowed',
      'The name you entered is not allowed (e.g. because it starts or ends with a space, contains forbidden characters or it already exists in the load order or the game''s Data folder).');
    lblPluginNameNotAllowed.Font.color := clRed;
    lblPluginNameNotAllowed.Visible := false;
    // the suggestion is always allowed, because it is validated before showing the GUI
    if not(GlobConfig.PluginSelectionMode = 2) then
    begin
      pnlPluginNameNew.Visible := false;
    end
    pnlPluginNameDisplay := ConstructPanel(frm, gbMainSettings,
      rgPluginSelectionMode.Top + rgPluginSelectionMode.Height, 10, 21,
      rgPluginSelectionMode.Width, '', '');
    pnlPluginNameDisplay.BevelOuter := bvNone;
    lbl := ConstructLabel(frm, pnlPluginNameDisplay, 3, 10, 16,
      (gbMainSettings.Width - 16) / 3, 'Plugin name',
      'automatically selects the last plugin in your load order' + chr(13) +
      chr(10) + 'ATTENTION: this could be a master or a vanilla plugin or something you do not want to overwrite!'
      + chr(13) + chr(10) + 'Don''t use this option if you are not sure.');
    lbl.Font.color := $0080FF; // darker orange
    lbl := ConstructLabel(frm, pnlPluginNameDisplay, lbl.Top,
      lbl.Left + lbl.Width, 16, pnlPluginNameDisplay.Width - lbl.Left -
      lbl.Width, GlobConfig.LastPluginInLoadOrder, lbl.Hint);
    lbl.Font.color := $0080FF; // darker orange
    if not(GlobConfig.PluginSelectionMode = 3) then
    begin
      pnlPluginNameDisplay.Visible := false;
    end

			
		// //  Grey out if no AWKR.esp located
    // // FuntionalDisplays
    // lbl := ConstructLabel(frm, gbMainSettings, pnlPluginNameNew.Top + pnlPluginNameNew.Height, 10, 16, gbMainSettings.Width - 30,
      // 'FunctionalDisplay', '');
    // curTopPos := lbl.Top + 16;
    // cbMainFunctionalDisplay := ConstructCheckBox2(frm, gbMainSettings, lbl.Top + 20, lbl.Left + 10, gbGeneral.Width - 18, 'Copy Keywords [KYWD]', GlobConfig.CopyFunctionalDisplay,
      // 'This will copy all the FunctionalDisplays Keywords into your Overwrite mod'+ chr(13) + chr(10) + 
			// 'Make sure you have installed the patch from Armor keywords as this affects the KYWD'
			
			// );
	

    // Buttons at the bottom
    pnlButtons := ConstructPanel(frm, frm, frm.Height - 75, -5, 75,
      frm.Width + 10, '', '');

    btnCancel := ConstructButton(frm, pnlButtons, 6, pnlButtons.Width - 18 - 87,
      0, 0, 'Cancel');
    btnCancel.OnClick := OnClickCancel;
    btnCancel.ModalResult := mrCancel;

    btnOk := ConstructButton(frm, pnlButtons, 6,
      btnCancel.Left - btnCancel.Width - 5, 0, 0, 'Next');
    btnOk.ModalResult := mrOk;

    // lbl := ConstructLabel(frm, pnlButtons, 12, 14, 0, frm.Width - 30,
    // '(When you press "Next" an analysis of the OMOD is conducted to create a new description mirroring your personal load order.)'
    // , '');

    if GlobIndentLvl = 0 then
    begin
      GlobIndentLvl := 2;
      CachedIndention := GetIndention;
    end;

    if frm.ShowModal = mrOk then
    begin
      // set back time counter
      GlobLogStart := Now;

      DebugLog('MainForm: OK');

      // Remember Settings in Global Variables
      if (not bAborted) and (not GlobConfig.Cancelled) then
      begin
        // General
        EnableDebugLog := (cbGeneralWriteDebugLog.State = cbChecked); 

        // main settings
        GlobConfig.PluginSelectionMode := GetPseudoRadioButtonGroupValue
          (rgPluginSelectionMode);
        GlobConfig.NewPluginName := tbFileName.Text;
				// GlobConfig.CopyFunctionalDisplay := (cbMainFunctionalDisplay.State = cbChecked); 
      end;
    end
    else
    begin
      // set back time counter
      GlobLogStart := Now;

      DebugLog('MainForm: Cancel');
    end;
  finally
    tmpStringList.Free;
    tmpStringList := nil;
    rgPluginSelectionMode := nil;
    pnlPluginNameSelect := nil;
    ddlPluginNameSelect := nil;
    pnlPluginNameNew := nil;
    pnlPluginNameDisplay := nil;
    frm.Free;
  end;

  LogFunctionEnd;
end;

// =========================================================================
// Event when the plugin selection mode is changed
// =========================================================================
procedure OnChangeExistingPluginDropdown(Sender: TObject;);
begin
  LogFunctionStart('OnChangeExistingPluginDropdown');

  if GlobConfig.ExistingGernashsDescrPlugins.Count > 0 then
    GlobConfig.ExistingGernashsDescrPluginsSelectedIndex :=
      ddlPluginNameSelect.Controls[1].ItemIndex;

  LogFunctionEnd;
end;

// =========================================================================
// Event when the plugin name is edited in the textbox
// (needs to be fast in order to be usable - hence written code-heavy with performance in mind)
// =========================================================================
procedure OnChangePluginName(Sender: TObject;);
const
  badChars = '<>:"/\|?*';
var
  ch: char;
  i, tmpInt: Integer;
  tmpStr: String;
  forbidden: Boolean;
begin
  LogFunctionStart('OnChangePluginName');

  forbidden := false;
  tmpStr := tbFileName.Text;
  if tmpStr = '' then
    forbidden := true;

  if not forbidden then
  begin
    if Copy(tmpStr, Length(tmpStr), 1) = ' ' then
      forbidden := true;

    if not forbidden then
    begin
      if Copy(tmpStr, 1, 1) = ' ' then
        forbidden := true;

      if not forbidden then
      begin
        if Length(tmpStr) > 50 then
          forbidden := true;

        if not forbidden then
        begin
          for i := Length(tmpStr) - 1 downto 0 do
          begin
            ch := Copy(tmpStr, i, 1);
            if (Pos(ch, badChars) > 0) or (Ord(ch) < 32) then
            begin
              forbidden := true;
              break;
            end;
          end;

          if not forbidden then
            if GlobConfig.NotAllowedPluginNames.Find(tmpStr, tmpInt) then
              forbidden := true;
        end;
      end;
    end;
  end;

  if forbidden then
  begin
    btnOk.Enabled := false;
    lblPluginNameNotAllowed.Visible := true;
  end
  else
  begin
    btnOk.Enabled := true;
    lblPluginNameNotAllowed.Visible := false;
    GlobConfig.NewPluginName := tmpStr;
  end;

  LogFunctionEnd;
end;

// =========================================================================
// Event when the plugin selection mode is changed
// =========================================================================
procedure OnChangePluginSelectionMode(Sender: TObject;);
begin
  LogFunctionStart('OnChangePluginSelectionMode');

  GlobConfig.PluginSelectionMode := GetPseudoRadioButtonGroupValue
    (rgPluginSelectionMode);
  if GlobConfig.PluginSelectionMode = 1 then
  begin
    pnlPluginNameSelect.Visible := true;
    pnlPluginNameNew.Visible := false;
    pnlPluginNameDisplay.Visible := false;

    if GlobConfig.ExistingGernashsDescrPluginsSelectedIndex = 0 then
    begin
      GlobConfig.NewPluginName := ddlPluginNameSelect.Controls[0].Text;
    end;
    btnOk.Enabled := true;
  end
  else if GlobConfig.PluginSelectionMode = 2 then
  begin
    pnlPluginNameSelect.Visible := false;
    pnlPluginNameNew.Visible := true;
    pnlPluginNameDisplay.Visible := false;
    btnOk.Enabled := not lblPluginNameNotAllowed.Visible;
  end
  else if GlobConfig.PluginSelectionMode = 3 then
  begin
    pnlPluginNameSelect.Visible := false;
    pnlPluginNameNew.Visible := false;
    pnlPluginNameDisplay.Visible := true;
    btnOk.Enabled := true;
  end;

  LogFunctionEnd;
end;

// =========================================================================
// Event when Cancel is clicked
// =========================================================================
procedure OnClickCancel(Sender: TObject;);
begin
  LogFunctionStart('OnClickCancel');

  GlobConfig.PluginSelectionMode := 0;
  GlobConfig.Cancelled := true;
  bAborted := true;

  LogFunctionEnd;
end;

// =========================================================================
// Event when Translate is clicked
// =========================================================================
procedure OnClickTranslate(Sender: TObject;);
begin
  LogFunctionStart('OnClickTranslate');

  GlobConfig.MainAction := 2;
  GlobConfig.Cancelled := true;

  LogFunctionEnd;
end;

// =========================================================================
// results form used to visualize whatever the script did
// =========================================================================
procedure CreateResultsForm(bChecksFailed: Boolean; bAborted: Boolean;
  ResultTextsList: TStringList);
var
  frm: TForm;
  lbl: TLabel; // label object - re-used/overwritten for every label
  curTopPos: Integer;
  lblCaption: String;
  btnOk: TButton;
  mResult: TMemo;
  pnlButtons: TPanel;
begin
  LogFunctionStart('CreateResultsForm');

  frm := TForm.Create(nil);
  try

    frm.Caption := 'Gernash''s OMOD description renamer';
    frm.Width := 800;
    frm.Height := 650;
    frm.Position := poScreenCenter;

    lblCaption := 'Results:';
    if bChecksFailed then
      lblCaption := lblCaption + ' Attention: Some Checks failed.';
    if bAborted then
      lblCaption := lblCaption + ' Processing has been aborted.';

    lbl := ConstructLabel(frm, frm, 10, 10, 0, frm.Width - 30, lblCaption, '');
    if bChecksFailed or bAborted then
      lbl.Font.color := clRed;

    curTopPos := lbl.Top + lbl.Height + 8;

    mResult := ConstructMemo(frm, frm, curTopPos, 10, frm.Height - curTopPos -
      80, frm.Width - 35, true, true, ssBoth, ResultTextsList);

    pnlButtons := ConstructPanel(frm, frm, frm.Height - 75, -5, 75,
      frm.Width + 10, '', '');

    btnOk := TButton.Create(frm);
    btnOk.Parent := pnlButtons;
    btnOk.Caption := 'Copy to Clipboard and Close';
    btnOk.ModalResult := mrOk;
    btnOk.Width := 200;
    btnOk.Top := 6;
    btnOk.Left := frm.Width div 2 - btnOk.Width div 2;
    // btnOk.Left := frm.Width - btnOk.Width - 18;

    if frm.ShowModal = mrOk then
    begin
      // set back time counter
      GlobLogStart := Now;

      mResult.SelectAll;
      mResult.CopyToClipboard;
      mResult.SelLength := 0;
    end;
  finally
    frm.Free;
  end;

  LogFunctionEnd;
end;

end.

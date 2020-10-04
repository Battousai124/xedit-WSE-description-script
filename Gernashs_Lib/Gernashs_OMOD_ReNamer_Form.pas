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
  i: Integer; // re-used/overwritten every time
  tmpStringList: TStringList; // re-used/overwritten every time
  tmpCbState: TCheckBoxState; // re-used/overwritten every time
  frm: TForm;
  gbGeneral, gbMainSettings, gbTranslateResourceFile: TGroupBox;
  cbGeneralWriteDebugLog, cbMainFunctionalDisplay: TCheckBox;
  pnlButtons, pnlTranslate: TPanel;
  btnCancel, btnTranslate: TButton;
begin
  LogFunctionStart('CreateMainForm');
	frm := FormFromSettings('frmConfig', settings);
  tmpStringList := TStringList.Create;

  try
		lbl := LabelFromSettings(frm, frm, 'frmConfig', 'desc', settings);
		
		// general settings
    gbGeneral := GroupBoxFromSettings(frm, frm, 'frmConfig', 'gbGeneral', settings);
		cbGeneralWriteDebugLog := CheckBoxFromSettings(frm, gbGeneral, 'gbGeneral', 'cbGeneralWriteDebugLog', settings);
		
    // special stuff
    if GlobConfig.ShowResourceFileTranslationOption then
    begin
			gbTranslateResourceFile := GroupBoxFromSettings(frm, frm, 'frmConfig', 'gbTranslateResourceFile', settings);
			pnlTranslate := PanelFromSettings(frm, gbTranslateResourceFile, 'gbTranslateResourceFile', 'pnlTranslate', settings);
      lbl := LabelFromSettings(frm, pnlTranslate, 'pnlTranslate', 'lblTranslate', settings);
			btnTranslate := ButtonFromSettings(frm, pnlTranslate, 'pnlTranslate', 'btnTranslate', settings);
			btnTranslate.OnClick := OnClickTranslate;
    end;

    // main settings
		gbMainSettings := GroupBoxFromSettings(frm, frm, 'frmConfig', 'gbMainSettings', settings);
    
    // Plugin and Records
		lbl := LabelFromSettings(frm, gbMainSettings, 'gbMainSettings', 'lblPluginsHeader', settings);
    
		// plugin selection mode
		rgPluginSelectionMode := PseudoRadioGroupFromSettings(frm, gbMainSettings, 'gbMainSettings', 'rgPluginSelectionMode', settings, tmpStringList);
		for i := 1 to tmpStringList.Count do begin
      rgPluginSelectionMode.Controls[i].OnClick := OnChangePluginSelectionMode;
    end;
		
		// plugin name
    pnlPluginNameSelect := PanelFromSettings(frm, gbMainSettings, 'gbMainSettings', 'pnlPluginNameSelect', settings);
		lbl := LabelFromSettings(frm, pnlPluginNameSelect, 'pnlPluginNameSelect', 'lblPluginSelection', settings);
		ddlPluginNameSelect := DropdownFromSettings(frm, pnlPluginNameSelect, 'pnlPluginNameSelect', 'ddlPluginNameSelect', settings, tmpStringList);
    ddlPluginNameSelect.Controls[1].OnChange := OnChangeExistingPluginDropdown;
		if GlobConfig.ExistingGernashsDescrPlugins.Count = 0 then begin
      //just because it bothers me when something is 1 pixel off:
      ddlPluginNameSelect.Controls[0].Top := ddlPluginNameSelect.Controls[0].Top - 1;
    end;
		pnlPluginNameNew := PanelFromSettings(frm, gbMainSettings, 'gbMainSettings', 'pnlPluginNameNew', settings);
    lbl := LabelFromSettings(frm, pnlPluginNameNew, 'pnlPluginNameNew', 'lblPluginNameNew', settings);
		tbFileName := EditFromSettings(frm, pnlPluginNameNew, 'pnlPluginNameNew', 'tbFileName', settings);
		tbFileName.OnKeyUp := OnChangePluginName;
		lbl := LabelFromSettings(frm, pnlPluginNameNew, 'pnlPluginNameNew', 'lblPluginNameNewExt', settings);
		lblPluginNameNotAllowed := LabelFromSettings(frm, pnlPluginNameNew, 'pnlPluginNameNew', 'lblPluginNameNotAllowed', settings);
		pnlPluginNameDisplay := PanelFromSettings(frm, gbMainSettings, 'gbMainSettings', 'pnlPluginNameDisplay', settings);
    lbl := LabelFromSettings(frm, pnlPluginNameDisplay, 'pnlPluginNameDisplay', 'lblPluginNameDisplay', settings);
		lbl := LabelFromSettings(frm, pnlPluginNameDisplay, 'pnlPluginNameDisplay', 'lblPluginNameDisplayName', settings);
			
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
		pnlButtons := PanelFromSettings(frm, frm, 'frmConfig', 'pnlButtons', settings);
    btnCancel := ButtonFromSettings(frm, pnlButtons, 'pnlButtons', 'btnCancel', settings);
		btnCancel.OnClick := OnClickCancel;
    btnOk := ButtonFromSettings(frm, pnlButtons, 'pnlButtons', 'btnOk', settings);
    
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
  ResultTextsList, settings: TStringList; );
var
  frmResult: TForm;
  lbl: TLabel; // label object - re-used/overwritten for every label
  curTopPos: Integer;
  lblCaption: String;
  btnOk: TButton;
  mResult: TMemo;
  pnlButtons: TPanel;
begin
  LogFunctionStart('CreateResultsForm');

  frmResult := TForm.Create(nil);
  try
		
    frmResult.Caption := 'Gernash''s OMOD description renamer';
    frmResult.Width := 800;
    frmResult.Height := 650;
    frmResult.Position := poScreenCenter;
		
		lblCaption := 'Results:';
    if bChecksFailed then
      lblCaption := lblCaption + ' Attention: Some Checks failed.';
    if bAborted then
      lblCaption := lblCaption + ' Processing has been aborted.';
		lbl := ConstructLabel(frmResult, frmResult, 10, 10, 0, frmResult.Width - 30, lblCaption, '');
    if bChecksFailed or bAborted then
      lbl.Font.color := clRed;

    curTopPos := lbl.Top + lbl.Height + 8;

    mResult := ConstructMemo(frmResult, frmResult, curTopPos, 10, frmResult.Height - curTopPos -
      80, frmResult.Width - 35, true, true, ssBoth, ResultTextsList);

    pnlButtons := ConstructPanel(frmResult, frmResult, frmResult.Height - 75, -5, 75,
      frmResult.Width + 10, '', '');

    btnOk := TButton.Create(frmResult);
    btnOk.Parent := pnlButtons;
    btnOk.Caption := 'Copy to Clipboard and Close';
    btnOk.ModalResult := mrOk;
    btnOk.Width := 200;
    btnOk.Top := 6;
    btnOk.Left := frmResult.Width div 2 - btnOk.Width div 2;
    // btnOk.Left := frmResult.Width - btnOk.Width - 18;

    if frmResult.ShowModal = mrOk then
    begin
      // set back time counter
      GlobLogStart := Now;

      mResult.SelectAll;
      mResult.CopyToClipboard;
      mResult.SelLength := 0;
    end;
  finally
    frmResult.Free;
  end;

  LogFunctionEnd;
end;

end.

unit Gernashs_OMOD_ReNamer_Form;

interface

implementation

uses ClipBrd;
uses StdCtrls;
uses Windows;

//=========================================================================
//  configuration form, opened as first form when the script is started - before any modifications
//=========================================================================
procedure CreateMainForm ();
var 
	lbl: TLabel; //label object - re-used/overwritten for every label
	i, tmpInt, curTopPos : Integer; //re-used/overwritten every time
	tmpStringList : TStringList; //re-used/overwritten every time
	tmpStr : String; //re-used/overwritten every time
	tmpCbState : TCheckBoxState; //re-used/overwritten every time
	frm : TForm;
	gbGeneral, gbMainSettings, gbTranslateResourceFile : TGroupBox;
	cbGeneralWriteDebugLog : TCheckBox; 
	pnlButtons, rgPluginSelectionMode, pnlTranslate : TPanel;
	btnCancel, btnOk, btnTranslate : TButton;
begin
	LogFunctionStart('CreateMainForm');
	frm := TForm.Create(nil);
	tmpStringList:=TStringList.Create;
	
	try
		frm.Caption := 'Gernash''s OMOD description renamer';
		frm.Width := 600;
		frm.Height := 400;
		frm.Position := poScreenCenter;
		
		lbl := ConstructLabel(frm, frm, 10, 10, 0, frm.Width - 30, 
			'This tool automatically creates proper descriptions for OMODs. '
			+ chr(13) + chr(10)
			+ 'It analyzes the actual changes an OMOD does and creates a description that considers the changes the plugins you use introduced. This way the OMOD description is true to your personal mod setup.'
			+ chr(13) + chr(10)
			+ chr(13) + chr(10)
			+ 'Select the functionality you want the script to perform: (hover your mouse over an option and read the hints if something is unclear)'
			, '');
		curTopPos := lbl.Top + lbl.Height + 12;
		
		//general settings
		tmpInt := frm.Height-curTopPos-65;
		if GlobConfig.ShowResourceFileTranslationOption then
			tmpInt := (tmpInt/2) + 6;
		gbGeneral := ConstructGroupBox(frm, frm, curTopPos, 10, tmpInt, (frm.Width-20)/4, 'General Settings ', '');
		cbGeneralWriteDebugLog := ConstructCheckBox2(frm, gbGeneral, 18, 10, gbGeneral.Width-18, 
			'Write Debug Log', EnableDebugLog, 
			'if checked: will write a detailed debug log into the Messages tab of xEdit - else only relevant outputs will be logged there'
			+ chr(13) + chr(10)
			+ '(This comes in handy if there is an error, so you can follow the execution path in the script.)'
			+ chr(13) + chr(10)
			+ '(At the end of the operation there will always be a result-window displayed.)'
			);
		
		//special stuff 
		if GlobConfig.ShowResourceFileTranslationOption then begin
			gbTranslateResourceFile := ConstructGroupBox(frm, frm, gbGeneral.Top + gbGeneral.Height, 10, frm.Height-gbGeneral.Height-gbGeneral.Top-65, (frm.Width-20)/4, 'Translate File ', '');
			pnlTranslate := ConstructPanel(frm, gbTranslateResourceFile, 20, 0, gbTranslateResourceFile.Height, gbTranslateResourceFile.Width, '', '');
			pnlTranslate.BevelOuter := bvNone;
			lbl := ConstructLabel(frm, pnlTranslate, 10, 10, 0, pnlTranslate.Width, 'create backup & then translate resorce'+ chr(13) + chr(10), '');
			btnTranslate:= ConstructButton(frm, pnlTranslate, pnlTranslate.Height-55, 10, 0, 0, 'Translate File');
			btnTranslate.OnClick:=OnClickTranslate;
			btnTranslate.ModalResult:= mrCancel;
		
		end;
		
		//main settings
		gbMainSettings := ConstructGroupBox(frm, frm, gbGeneral.Top, gbGeneral.Width+16, frm.Height-gbGeneral.Top-65, frm.Width-gbGeneral.Width-25, 'Check / Modification Settings ', '');
		
		//Plugin and Records
		lbl := ConstructLabel(frm, gbMainSettings, 20, 10, 16, gbMainSettings.Width - 30, 'Plugin and Records:', '');
		curTopPos := lbl.Top + 16;
		
		tmpStringList.Clear;
		tmpStringList.Add('create new');
		tmpStringList.Add('last in load order');
		rgPluginSelectionMode:=ConstructPseudoRadioGroup(frm, gbMainSettings, curTopPos, 10, 20, gbMainSettings.Width-16, 'Plugin to store changes', (gbMainSettings.Width-16)/3, 
			'defines where changes are stored - e.g. a new plugin can be created at the end of the load order or an existing plugin can be used'
			, tmpStringList, (gbMainSettings.Width-16)*2/3/tmpStringList.Count, GlobConfig.PluginSelectionMode, '');
		
		
		
		
		
		
		
		
		
		//Buttons at the bottom
		pnlButtons:=ConstructPanel(frm, frm, frm.Height - 75, -5, 75, frm.Width + 10, '', '');
		
		btnCancel:= ConstructButton(frm, pnlButtons, 6, pnlButtons.Width - 18 - 87, 0, 0, 'Cancel');
		btnCancel.OnClick:=OnClickCancel;
		btnCancel.ModalResult:= mrCancel;
		
		btnOk:= ConstructButton(frm, pnlButtons, 6, btnCancel.Left - btnCancel.Width - 5, 0, 0, 'Next');
		btnOk.ModalResult:= mrOk;
		
		//lbl := ConstructLabel(frm, pnlButtons, 12, 14, 0, frm.Width - 30, 
		//	'(When you press "Next" an analysis of the OMOD is conducted to create a new description mirroring your personal load order.)'
		//	, '');
		
		if GlobIndentLvl = 0 then begin
			GlobIndentLvl := 2;
			CachedIndention := GetIndention;
		end;
		
		if frm.ShowModal = mrOk then begin
			//set back time counter
			GlobLogStart := Now;
			
			DebugLog('MainForm: OK');
			
			//Remember Settings in Global Variables
			if (not bAborted) and (not GlobConfig.Cancelled) then begin
				//General
				EnableDebugLog := (cbGeneralWriteDebugLog.State = cbChecked);
			
				//main settings
				GlobConfig.PluginSelectionMode:=GetPseudoRadioButtonGroupValue(rgPluginSelectionMode);
			end;
		end else begin
			//set back time counter
			GlobLogStart := Now;
			
			DebugLog('MainForm: Cancel');
		end;
	finally
		tmpStringList.Free;
		tmpStringList:=nil;
		rgPluginSelectionMode:=nil;
		frm.Free;
	end;
	
	LogFunctionEnd;
end;

//=========================================================================
//  Event when Cancel is clicked
//=========================================================================
procedure OnClickCancel(Sender: TObject;);
begin
	LogFunctionStart('OnClickCancel');
	
	GlobConfig.PluginSelectionMode := 0;
	GlobConfig.Cancelled := true;
	bAborted := true;
	
	LogFunctionEnd;
end;


//=========================================================================
//  Event when Translate is clicked
//=========================================================================
procedure OnClickTranslate(Sender: TObject;);
begin
	LogFunctionStart('OnClickTranslate');
	
	GlobConfig.MainAction := 2;
	GlobConfig.Cancelled := true;
	
	LogFunctionEnd;
end;

//=========================================================================
//  results form used to visualize whatever the script did
//=========================================================================
procedure CreateResultsForm (bChecksFailed: boolean; bAborted : boolean; ResultTextsList : TStringList);
var 
	frm: TForm;
	lbl: TLabel; //label object - re-used/overwritten for every label
	curTopPos : Integer;
	lblCaption : String;
	btnOk : TButton;
	mResult : TMemo;
	pnlButtons : TPanel;
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
		
		mResult := ConstructMemo(frm, frm, curTopPos, 10, frm.Height-curTopPos-80, frm.Width - 35, true, true, ssBoth, ResultTextsList);
		
		pnlButtons:=ConstructPanel(frm, frm, frm.Height - 75, -5, 75, frm.Width+10,'','');
				
		btnOk := TButton.Create(frm);
		btnOk.Parent := pnlButtons;
		btnOk.Caption := 'Copy to Clipboard and Close';
		btnOk.ModalResult := mrOk;
		btnOk.Width := 200;
		btnOk.Top := 6;
		btnOk.Left := frm.Width div 2 - btnOk.Width div 2;
		//btnOk.Left := frm.Width - btnOk.Width - 18;
			
		if frm.ShowModal = mrOk then begin
			//set back time counter
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
unit Gernashs_OMOD_ReNamer_Form;

interface

implementation

uses ClipBrd;
uses StdCtrls;
uses Windows;


//=========================================================================
//  create the results form
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
	
		frm.Caption := 'Eff''s Weapon Patch Helper';
		frm.Width := 800;
		frm.Height := 800;
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
unit EffsFormTools;

//=========================================================================
//  create a button.
//  Example usage: btn1 := ConstructButton(frm, pnlBottom, 8, 8, 160, 60, 'OK');
//=========================================================================
function ConstructButton(frm, parent: TObject; top, left, height, width: Integer; caption: String): TButton;
var 
	btn: TButton;
begin
	LogFunctionStart('ConstructButton');
	DebugLog('caption: ' + caption);
	
	btn := TButton.Create(frm);
	btn.Parent := parent;
	btn.Top := top;
	btn.Left := left;
	if height > 0 then btn.Height := height;
	if width > 0 then btn.Width := width;
	btn.Caption := caption;

	Result := btn;
	LogFunctionEnd;
end;

//=========================================================================
//  creates the standard OK and Cancel buttons on a form.
//  Example usage: ConstructModalButtons(frm, pnlBottom, frm.Height - 80);
//=========================================================================
procedure ConstructModalButtons(frm, parent: TObject; top: Integer; okButtonCaption : String);
var
	btnOk: TButton;
	btnCancel: TButton;
begin
	LogFunctionStart('ConstructModalButtons');

	btnCancel := TButton.Create(frm);
	btnCancel.Parent := parent;
	btnCancel.Caption := 'Cancel';
	btnCancel.ModalResult := mrCancel;
	//btnCancel.Left := btnOk.Left + btnOk.Width + 16;
	btnCancel.Left := frm.Width - btnCancel.Width - 18;
	btnCancel.Top := top;
	
	
	btnOk := TButton.Create(frm);
	btnOk.Parent := parent;
	btnOk.Caption := okButtonCaption;
	btnOk.ModalResult := mrOk;
	//btnOk.Left := frm.Width div 2 - btnOk.Width - 8;
	btnOk.Left := btnCancel.Left - btnOk.Width - 5;
	btnOk.Top := top;

	LogFunctionEnd;
end;

//=========================================================================
//  construct a label.  
//  Example usage: lbl3 := ConstructLabel(frm, pnlBottom, 65, 8, 0, 0, 'label text');
//=========================================================================
function ConstructLabel(frm, parent: TObject; top, left, height, width: Integer; caption, hint: String): TLabel;
var
	lbl: TLabel;
begin
	LogFunctionStart('ConstructLabel');
	if Length(caption)>30 then
		DebugLog('caption: ' + Copy(caption,1,30) + '...')
	else 
		DebugLog('caption: ' + caption);
	
	lbl := TLabel.Create(frm);
	lbl.Parent := parent;
	lbl.Top := top;
	lbl.Left := left;
	lbl.AutoSize := false;
	lbl.WordWrap := true;
	if (height = 0) and (width = 0) then lbl.AutoSize := true;
	if (height = 0) and (Pos(#13, caption) > 0) then lbl.AutoSize := true;
	if height > 0 then lbl.Height := height;
	if width > 0 then lbl.Width := width;
	lbl.Caption := caption;
	if (hint <> '') then begin
		lbl.ShowHint := true;
		lbl.Hint := hint;
	end;
  
	Result := lbl;
	LogFunctionEnd;
end;

//=========================================================================
//  construct a Panel.  
//  Example usage: pnl := ConstructPanel(frm, pnlBottom, 65, 8, 0, 0, 'panel header');
//=========================================================================
function ConstructPanel(frm, parent: TObject; top, left, height, width: Integer; caption, hint: String): TLabel;
var
	pnl: TPanel;
begin
	LogFunctionStart('ConstructPanel');
	
	pnl := TPanel.Create(frm);
	pnl.Parent := parent;
	pnl.Top := top;
	pnl.Left := left;
	pnl.AutoSize := false;
	if (height = 0) and (width = 0) then pnl.AutoSize := true;
	if (height = 0) and (Pos(#13, caption) > 0) then pnl.AutoSize := true;
	if height > 0 then pnl.Height := height;
	if width > 0 then pnl.Width := width;
	pnl.BevelOuter := bvRaised;
	//pnl.BevelInner := bvLowered;
	pnl.Caption := caption;
	if (hint <> '') then begin
		pnl.ShowHint := true;
		pnl.Hint := hint;
	end;
  
	Result := pnl;
	LogFunctionEnd;
end;



//=========================================================================
//  creates a checkbox.
//  Example usage: cb := ConstructCheckBox(frm, pnlBottom, 8, 8, 160, 'Setting1', cbChecked, '');
//=========================================================================
function ConstructCheckBox(frm, parent: TObject; top, left, width: Integer; caption: String; state: TCheckBoxState; hint: string): TCheckBox;
var
	cb: TCheckBox;
begin
	LogFunctionStart('ConstructCheckBox');
	DebugLog('caption: ' + caption);
	
	cb := TCheckBox.Create(frm);
	cb.Parent := parent;
	cb.Top := top;
	cb.Left := left;
	cb.Width := width;
	cb.Caption := caption;
	cb.State := state;
	if (hint <> '') then begin
		cb.ShowHint := true;
		cb.Hint := hint;
	end;

	Result := cb;
	LogFunctionEnd;
end;

//=========================================================================
//  creates a checkbox.
//  Example usage: cb := ConstructCheckBox(frm, pnlBottom, 8, 8, 160, 'Setting1', true, '');
//=========================================================================
function ConstructCheckBox2(frm, parent: TObject; top, left, width: Integer; caption: String; checked: boolean; hint: string): TCheckBox;
var
	cb: TCheckBox;
begin
	LogFunctionStart('ConstructCheckBox');
	DebugLog('caption: ' + caption);
	
	cb := TCheckBox.Create(frm);
	cb.Parent := parent;
	cb.Top := top;
	cb.Left := left;
	cb.Width := width;
	cb.Caption := caption;
	if checked then 
		cb.State := cbChecked
	else
		cb.State := cbUnchecked;
		
	if (hint <> '') then begin
		cb.ShowHint := true;
		cb.Hint := hint;
	end;

	Result := cb;
	LogFunctionEnd;
end;

//=========================================================================
//  creates a memo field.
//  Example usages: memo := ConstructMemo(frm, frm, 0, 0, 200, 400, True, True, ssBoth, '');
//=========================================================================
function ConstructMemo(frm, parent: TObject; top, left, height, width: Integer; bWordWrap, bReadOnly: boolean; scrollStyle: TScrollStyle; text: TStringList): TMemo;
var
	memo: TMemo;
begin
	LogFunctionStart('ConstructMemo');
		
	memo := TMemo.Create(frm);
	memo.Parent := parent;
	memo.Top := top;
	memo.Left := left;
	if width > 0 then memo.Width := width;
	if height > 0 then memo.Height := height;
	memo.WordWrap := bWordWrap;
	memo.ReadOnly := bReadOnly;
	memo.ScrollBars := scrollStyle;
	//memo.Text := text;
	memo.Lines.Assign(text);

	Result := memo;
	LogFunctionEnd;
end;

//=========================================================================
//  construct an edit field.  
//  Example usage:  ed3 := ConstructEdit(frm, frm, 100, 8, 0, 0, 'Edit me!');
//=========================================================================
function ConstructEdit(frm, parent: TObject; top, left, height, 
  width: Integer; text, hint: String): TEdit;
var
  ed: TEdit;
begin
	LogFunctionStart('ConstructEdit');
	DebugLog('text: ' + text);
	
  ed := TEdit.Create(frm);
  ed.Parent := parent;
  ed.Top := top;
  ed.Left := left;
  if height > 0 then ed.Height := height;
  if width > 0 then ed.Width := width;
  if (height = 0) and (width = 0) then ed.AutoSize := true;
  ed.Text := text;
  if (hint <> '') then begin
    ed.ShowHint := true;
    ed.Hint := hint;
  end;
  
  Result := ed;
	LogFunctionEnd;
end;

//=========================================================================
//  create a GroupBox.  
//  Example usage: groupbox := ConstructGroup(frm, frm, 8, 8, 300, 300, 'general settings:','');
//=========================================================================
function ConstructGroupBox(frm, parent: TObject; top, left, height, width: Integer; caption, hint: string): TGroupBox;
var
	gb: TGroupBox;
begin
	LogFunctionStart('ConstructGroupBox');
	
	gb := TGroupBox.Create(frm);
	gb.Parent := parent;
	gb.Top := top;
	gb.Left := left;
	gb.Width := width;
	gb.Height := height;
	gb.ClientWidth := width - 15;
	gb.ClientHeight := height - 15;
	gb.Caption := caption;
	if (hint <> '') then begin
		gb.ShowHint := true;
		gb.Hint := hint;
	end;

	Result := gb;
	LogFunctionEnd;
end;

//=========================================================================
//	create a radio group.  
//  Example usage: rg := ConstructRadioGroup(frm, frm, 8, 8, 200, 400, 'mode', 3, items);
//=========================================================================
function ConstructRadioGroup(frm, parent: TObject; top, left, height, width: Integer; caption: String; columns: Integer; items : TStringList;): TRadioGroup;
var
	rg: TRadioGroup;
begin
	LogFunctionStart('ConstructRadioGroup');
	
	rg := TRadioGroup.Create(frm);
	rg.Parent := parent;
	rg.Top := top;
	rg.Left := left;
	rg.Width := width;
	rg.Height := height;
	rg.Caption := caption;
	rg.ClientHeight := height - 15;
	rg.ClientWidth := width - 15;
	rg.Columns := columns;
	rg.Items := items;
	rg.ClientHeight := 35;
	
	Result := rg;
	LogFunctionEnd;
end;


//=========================================================================
//	create a a panel with radio buttons that acts similar but better than a radiobuttongroup 
// 	(currently only supports horizontal radio buttons
//  Example usage: rg:=ConstructPseudoRadioGroup(frm, frm, 10,0, 20,460, 'settings', 220, '', items, 70,1);
//=========================================================================
function ConstructPseudoRadioGroup(frm, parent: TObject; top, left, height, width: Integer; lblText : String; lblWidth: Integer; hint : String; items : TStringList; itemWidth, indexChecked: Integer; disabledText : String): TRadioGroup;
var
	pnl : TPanel;
	rb : TRadioButton;
	i : Integer;
	lbl, disabledLbl : TLabel;
begin
	LogFunctionStart('ConstructPseudoRadioGroup');
	
	pnl := TPanel.Create(frm);
	pnl.Parent := parent;
	pnl.Top := top;
	pnl.Left := left;
	pnl.AutoSize := false;
	if (height = 0) and (width = 0) then pnl.AutoSize := true;
	if height > 0 then pnl.Height := height;
	if width > 0 then pnl.Width := width;
	pnl.BevelOuter := bvNone;//bvNone; //bvRaised;
	pnl.BevelInner := bvNone;
	if (hint <> '') then begin
		pnl.ShowHint := true;
		pnl.Hint := hint;
	end;
	
	lbl := TLabel.Create(frm);
	lbl.Parent := pnl;
	lbl.Top := 3+(pnl.Height-20)/2;
	lbl.Left := 10;
	lbl.AutoSize := false;
	lbl.WordWrap := false;
	lbl.Width := lblWidth;
	lbl.Caption := lblText;
	if (hint <> '') then begin
		lbl.ShowHint := true;
		lbl.Hint := hint;
	end;
	// lbl.Transparent := false;
	// lbl.Color := clRed;
	
	if disabledText <> '' then begin
		disabledLbl := TLabel.Create(frm);
		disabledLbl.Parent := pnl;
		disabledLbl.Top := 3+(pnl.Height-20)/2;
		disabledLbl.Left := 10+lbl.Width+i*itemWidth;
		disabledLbl.AutoSize := false;
		disabledLbl.WordWrap := false;
		disabledLbl.Width := width-disabledLbl.Left;
		disabledLbl.Caption := disabledText;
		if (hint <> '') then begin
			disabledLbl.ShowHint := true;
			disabledLbl.Hint := hint;
		end;
		disabledLbl.Font.color := clGray;
	end else begin
		for i := 0 to items.Count-1 do begin
			rb := TRadioButton.Create(frm);
			rb.Parent := pnl;
			rb.Top := 0+(pnl.Height-20)/2;
			rb.Left := 10+lbl.Width+i*itemWidth;
			rb.Width := itemWidth;
			rb.Caption := items[i];
			if (hint <> '') then begin
				rb.ShowHint := true;
				rb.Hint := hint;
			end;
			if i+1 = indexChecked then
				rb.Checked := true;
		end;
	end;
	
	
	Result := pnl;
	LogFunctionEnd;
end;


//=========================================================================
//	create a dropdown box.  
//=========================================================================
function ConstructDropdown(frm, parent: TObject; top, left, height, width, selectedItemIndex: Integer; items : TStringList; hint, disabledText : String;): TPanel;
var
	cb: TComboBox;
	pnl : TPanel;
	lbl : TLabel;
begin
	LogFunctionStart('ConstructDropdown');
	
	pnl := ConstructPanel(frm, parent, top, left, height, width, '', hint);
	pnl.BevelOuter := bvNone;//bvNone; //bvRaised;
	pnl.BevelInner := bvNone;
	//pnl.ClientHeight := height;
	//pnl.Height := height+20;
	
	lbl := ConstructLabel(frm, pnl, 4, 4, height, width, disabledText, hint);
	lbl.Font.color := clGray;
	  
	cb := TComboBox.Create(frm);
	cb.Parent := pnl;
	cb.Top := 0;
	cb.Left := 0;
	cb.Width := width;
	cb.Height := height;
	cb.Style := csDropDownList;
	cb.Items := items;
	cb.ItemIndex := selectedItemIndex;
	//cb.ItemHeight := 16;
	
	if disabledText = '' then begin
		cb.Top := 0;
		lbl.Top := -100;
	end else begin
		cb.Top := -100;
		lbl.Top := 4;
	end;
	
	Result := pnl;
	
	LogFunctionEnd;
end;


//=========================================================================
//  Read radio button configuration out of pseudo-RadioGroup
//=========================================================================
function GetPseudoRadioButtonGroupValue(rg: TPanel) : Integer;
var 
	i : Integer;
	tmpStr : String;
begin
	LogFunctionStart('GetPseudoRadioButtonGroupValue');
	
	Result:= 0;
	
	if rg.ControlCount-1 > 1 then begin
		for i := rg.ControlCount-1 downto 1 do begin
			if rg.Controls[i].Checked then begin
				Result:= i;
				break;
			end;
		end;
	end;
	//(if - for any reason - no radio button is checked, function returns 0)
	
	DebugLog(Format('Setting for "%s": %d',[rg.Controls[0].Caption,Result]));
	
	LogFunctionEnd;
end;

	
end.
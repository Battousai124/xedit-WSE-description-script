unit EffsGraphicsHelper;

// This unit rebuilds Pascal functionality that amputated by xEdit's scripting engine
// (it does not require EffsDebugLog being loaded - uses no logging)

implementation

var 
	GraphicsHelperInitialized : Boolean;
	Colors : Array[0..41] of TColor;
	ColorNames : Array[0..41] of String;

//=========================================================================
//  Initialize static lists
//=========================================================================
procedure InitializeGraphicsHelper();
begin
	Colors[0] := clBlack;
	ColorNames[0] := 'clBlack';
	Colors[1] := clGray;
	ColorNames[1] := 'clGray';
	Colors[2] := clRed;
	ColorNames[2] := 'clRed';
	Colors[3] := clMaroon;
	ColorNames[3] := 'clMaroon';
	Colors[4] := clGreen;
	ColorNames[4] := 'clGreen';
	Colors[5] := clOlive;
	ColorNames[5] := 'clOlive';
	Colors[6] := clNavy;
	ColorNames[6] := 'clNavy';
	Colors[7] := clPurple;
	ColorNames[7] := 'clPurple';
	Colors[8] := clTeal;
	ColorNames[8] := 'clTeal';
	Colors[9] := clSilver;
	ColorNames[9] := 'clSilver';
	Colors[10] := clLime;
	ColorNames[10] := 'clLime';
	Colors[11] := clYellow;
	ColorNames[11] := 'clYellow';
	Colors[12] := clBlue;
	ColorNames[12] := 'clBlue';
	Colors[13] := clFuchsia;
	ColorNames[13] := 'clFuchsia';
	Colors[14] := clAqua;
	ColorNames[14] := 'clAqua';
	Colors[15] := clWhite;
	ColorNames[15] := 'clWhite';
	Colors[16] := clScrollBar;
	ColorNames[16] := 'clScrollBar';
	Colors[17] := clBackground;
	ColorNames[17] := 'clBackground';
	Colors[18] := clActiveCaption;
	ColorNames[18] := 'clActiveCaption';
	Colors[19] := clInactiveCaption;
	ColorNames[19] := 'clInactiveCaption';
	Colors[20] := clMenu;
	ColorNames[20] := 'clMenu';
	Colors[21] := clWindow;
	ColorNames[21] := 'clWindow';
	Colors[22] := clWindowFrame;
	ColorNames[22] := 'clWindowFrame';
	Colors[23] := clMenuText;
	ColorNames[23] := 'clMenuText';
	Colors[24] := clWindowText;
	ColorNames[24] := 'clWindowText';
	Colors[25] := clCaptionText;
	ColorNames[25] := 'clCaptionText';
	Colors[26] := clActiveBorder;
	ColorNames[26] := 'clActiveBorder';
	Colors[27] := clInactiveBorder;
	ColorNames[27] := 'clInactiveBorder';
	Colors[28] := clAppWorkSpace;
	ColorNames[28] := 'clAppWorkSpace';
	Colors[29] := clHighlight;
	ColorNames[29] := 'clHighlight';
	Colors[30] := clHighlightText;
	ColorNames[30] := 'clHighlightText';
	Colors[31] := clBtnFace;
	ColorNames[31] := 'clBtnFace';
	Colors[32] := clBtnShadow;
	ColorNames[32] := 'clBtnShadow';
	Colors[33] := clGrayText;
	ColorNames[33] := 'clGrayText';
	Colors[34] := clBtnText;
	ColorNames[34] := 'clBtnText';
	Colors[35] := clInactiveCaptionText;
	ColorNames[35] := 'clInactiveCaptionText';
	Colors[36] := clBtnHighlight;
	ColorNames[36] := 'clBtnHighlight';
	Colors[37] := cl3DDkShadow;
	ColorNames[37] := 'cl3DDkShadow';
	Colors[38] := cl3DLight;
	ColorNames[38] := 'cl3DLight';
	Colors[39] := clInfoText;
	ColorNames[39] := 'clInfoText';
	Colors[40] := clInfoBk;
	ColorNames[40] := 'clInfoBk';
	Colors[41] := clNone;
	ColorNames[41] := 'clNone';

	GraphicsHelperInitialized := true;
end;


function IdentToColor(const Ident: string): Longint;
var
  I: Integer;
begin
	if not GraphicsHelperInitialized then
		InitializeGraphicsHelper;

  for I := Low(Colors) to High(Colors) do
    if CompareText(ColorNames[I], Ident) = 0 then
    begin
  		Result := Longint(Colors[I]);
      Exit;
    end;
		
	Result := -1;
end;

function StringToColor(const S: string): TColor;
begin
	Result := IdentToColor(S);
	if Result = -1 then
		Result := StrToInt(S);
end;

end.
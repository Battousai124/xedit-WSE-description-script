unit Gernashs_OMOD_ReNamer_Config;

interface

//classes are not supported as parameters or return parameters of functions 
// when code is called from xEdit 
//-> they only work as global variables
	
type 
	TDescRenamerConfig = record
		PluginSelectionMode : Integer;
		Cancelled : Boolean;
		ShowResourceFileTranslationOption : Boolean;
		MainAction : Integer;
		AlwaysTranslateResourceFileAfterLoading : Boolean;
	end;

var
	GlobConfig : TDescRenamerConfig;

implementation

procedure SetDefaultConfig;
begin
	LogFunctionStart('SetDefaultConfig');
	//all properties of the config class need to be initialized here. 
	//(Without initialization they do not carry their correct data type.)
	
	EnableDebugLog := true; //resides in its own unit
	GlobConfig.PluginSelectionMode := 2;
	GlobConfig.Cancelled := false;
	GlobConfig.ShowResourceFileTranslationOption := false;
	GlobConfig.AlwaysTranslateResourceFileAfterLoading := false;
	GlobConfig.MainAction := 1; //1: normal stuff, rest is super special stuff, like translating a file or so
	
	LogFunctionEnd;
end;

end.
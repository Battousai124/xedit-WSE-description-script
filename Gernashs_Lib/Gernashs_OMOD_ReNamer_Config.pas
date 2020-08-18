unit Gernashs_OMOD_ReNamer_Config;

interface

//classes are not supported as parameters or return parameters of functions 
// when code is called from xEdit 
//-> they only work as global variables
	
type 
	TDescRenamerConfig = record
		PluginSelectionMode : Integer;
	end;

var
	GlobConfig : TDescRenamerConfig;

implementation

procedure SetDefaultConfig;
begin
	LogFunctionStart('SetDefaultConfig');
	//all properties of the config class need to be initialized here. 
	//(Without initialization they do not carry their correct data type.)
	
	EnableDebugLog := false; //resides in its own unit
	GlobConfig.PluginSelectionMode := 2;
	
	LogFunctionEnd;
end;

end.
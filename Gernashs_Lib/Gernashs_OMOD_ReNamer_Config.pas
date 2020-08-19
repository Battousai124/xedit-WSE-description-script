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
		DoNotManipulateMasterRecords : Boolean;
		NewPluginName : String;
		NotAllowedPluginNames : TStringList; //should be sorted, so that .Find() works to compare it efficiently
		ExistingGernashsDescrPlugins : TStringList; //may not be sorted, else we do not know what the last such plugin is in the load order
		LastPluginInLoadOrder : String;
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
	GlobConfig.DoNotManipulateMasterRecords := true;
	GlobConfig.NewPluginName := ''; //will be set depending on the load order
	GlobConfig.NotAllowedPluginNames := TStringList.Create; //will be set depending on the load order
	GlobConfig.NotAllowedPluginNames.Sorted := true; //so that .Find() works
	GlobConfig.ExistingGernashsDescrPlugins := TStringList.Create; //will be set depending on the load order
	GlobConfig.LastPluginInLoadOrder := ''; //will be set depending on the load order
	
	LogFunctionEnd;
end;

end.
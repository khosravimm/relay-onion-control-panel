unit FlowBrowserV3;

interface

uses
  System.SysUtils, System.IOUtils, System.Classes, System.JSON;

type
  TFlowBrowserV3 = class
  public
    class function LocateBypassExtension: string; static;
    class function LocateChrome: string; static;
  end;

implementation

class function TFlowBrowserV3.LocateChrome: string;
var
  Base: string;
begin
  Result := '';
  for Base in [
    GetEnvironmentVariable('ProgramFiles'),
    GetEnvironmentVariable('ProgramFiles(x86)'),
    GetEnvironmentVariable('LOCALAPPDATA')
  ] do
    if (Base <> '') and
      FileExists(TPath.Combine(Base, 'Google\Chrome\Application\chrome.exe')) then
      Exit(TPath.Combine(Base, 'Google\Chrome\Application\chrome.exe'));
end;

class function TFlowBrowserV3.LocateBypassExtension: string;
var
  Root, Profile, ExtensionDir, VersionDir, FileName: string;
  J: TJSONValue;
begin
  Result := '';
  Root := TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'),
    'Google\Chrome\User Data');
  if not TDirectory.Exists(Root) then Exit;
  for Profile in TDirectory.GetDirectories(Root) do
  begin
    if not (SameText(ExtractFileName(Profile), 'Default') or
      ExtractFileName(Profile).StartsWith('Profile ')) then Continue;
    ExtensionDir := TPath.Combine(Profile, 'Extensions');
    if not TDirectory.Exists(ExtensionDir) then Continue;
    for ExtensionDir in TDirectory.GetDirectories(ExtensionDir) do
      for VersionDir in TDirectory.GetDirectories(ExtensionDir) do
      begin
        FileName := TPath.Combine(VersionDir, 'manifest.json');
        if not FileExists(FileName) then Continue;
        try
          J := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName));
          try
            if (J is TJSONObject) and SameText(
              TJSONObject(J).GetValue<string>('name', ''), 'AI Flow Bypasser') then
              Exit(VersionDir);
          finally
            J.Free;
          end;
        except
          // Malformed or unrelated Chrome extension is not our concern.
        end;
      end;
  end;
end;

end.

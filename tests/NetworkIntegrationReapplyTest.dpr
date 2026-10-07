program NetworkIntegrationReapplyTest;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.IOUtils, System.JSON, Winapi.Windows, NetworkIntegration;
type
  TFakeManager = class(TNetworkIntegrationManager)
  public
    Running: Boolean;
    Starts, Stops, Checks: Integer;
  protected
    function IsEngineRunning: Boolean; override;
    function StartEngine(NeedElevation: Boolean; out ErrorText: string): Boolean; override;
    function StopEngine(out ErrorText: string): Boolean; override;
    function RunConfigCheck(out ErrorText: string): Boolean; override;
  end;
function TFakeManager.IsEngineRunning: Boolean;
begin Result := Running end;
function TFakeManager.StartEngine(NeedElevation: Boolean; out ErrorText: string): Boolean;
begin Inc(Starts); Running := True; ErrorText := ''; Result := True end;
function TFakeManager.StopEngine(out ErrorText: string): Boolean;
begin Inc(Stops); Running := False; ErrorText := ''; Result := True end;
function TFakeManager.RunConfigCheck(out ErrorText: string): Boolean;
begin Inc(Checks); ErrorText := ''; Result := True end;
function InterfaceName(const Config: string): string;
var J: TJSONObject;
begin
  J := TJSONObject.ParseJSONValue(Config) as TJSONObject;
  try Result := (J.GetValue<TJSONArray>('inbounds').Items[0] as TJSONObject).GetValue<string>('interface_name')
  finally J.Free end;
end;
procedure Check(Ok: Boolean; const Msg: string);
begin if not Ok then raise Exception.Create(Msg); Writeln('PASS: ', Msg) end;
var M: TFakeManager; Err, Dir, Before: string; I: Integer;
begin
  try
    Dir := TPath.Combine(TPath.GetTempPath, 'ROCP-Reapply-' + IntToStr(GetCurrentProcessId));
    M := TFakeManager.Create(Dir, Dir, 0);
    try
      Check(not M.Apply(False, True, '127.0.0.1', 9050, False, Err), 'fresh automatic TUN denied');
      Check((M.Starts=0) and (M.Stops=0), 'denial does not mutate runtime');
      Check(M.Apply(False, True, '127.0.0.1', 9050, True, Err), 'explicit TUN starts');
      Before := TFile.ReadAllText(TPath.Combine(Dir,'network\sing-box.json'));
      for I := 1 to 20 do
        Check(M.Apply(False, True, '127.0.0.1', 9050, False, Err), 'identical automatic reapply');
      Check((M.Starts=1) and (M.Stops=0) and (M.Checks=1), '20 reapplies preserve engine');
      Check(not M.Apply(False, True, '127.0.0.1', 9051, False, Err), 'changed automatic TUN denied');
      Check(M.Running and (M.Stops=0), 'denied change preserves active TUN');
      Check(TFile.ReadAllText(TPath.Combine(Dir,'network\sing-box.json'))=Before, 'denied change preserves config');
      Check(M.Apply(False, True, '127.0.0.1', 9051, True, Err), 'explicit change restarts');
      Check((M.Starts=2) and (M.Stops=1), 'explicit change performs one restart');
      Check(InterfaceName(TFile.ReadAllText(TPath.Combine(Dir,'network\sing-box.json'))) <>
        InterfaceName(Before), 'explicit restart uses a fresh TUN identity');
      Check(M.Apply(False, False, '127.0.0.1', 9051, False, Err), 'off stops engine');
      Check(not M.Running, 'off leaves runtime stopped');
      M.Running := False;
      Check(not M.Apply(False, True, '127.0.0.1', 9051, False, Err), 'dead engine cannot bypass approval');
    finally M.Free; TDirectory.Delete(Dir, True) end;
  except on E: Exception do begin Writeln('FAIL: ', E.Message); Halt(1) end end;
end.
program FlowExitFilterHarness;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, Winapi.Windows, System.IniFiles, FlowExitFilter, FlowExitCache;
type
  TTestFilter = class(TFlowExitFilter)
  private
    FCount: Integer;
  protected
    function RecheckInterval: UInt64; override;
    function CircuitWaitTimeout: UInt64; override;
    function Probe: Boolean; override;
  end;
function TTestFilter.CircuitWaitTimeout: UInt64;
begin
  Result := 1200;
end;

function TTestFilter.RecheckInterval: UInt64;
begin
  if ParamStr(2) = 'fail-member' then Result := 800 else Result := inherited RecheckInterval;
end;
function TTestFilter.Probe: Boolean;
begin
  Inc(FCount);
  SetProbeLatencyMs(100 * FCount);
  if ParamStr(2) = 'duplicate' then SetProbeIP('192.0.2.1')
  else SetProbeIP('192.0.2.' + IntToStr(FCount));
  if ParamStr(2) = 'cancel' then Sleep(400);
  if (ParamStr(2) = 'background') and (FCount >= 4) then Sleep(500);
  if (ParamStr(2) = 'router-disconnect') and (FCount >= 4) then Sleep(500);
  Result := (ParamStr(2) <> 'deny') and (ParamStr(2) <> 'cache-deny') and not ((ParamStr(2) = 'background') and (FCount >= 4));
  if (ParamStr(2) = 'fail-member') and (FCount >= 4) then Result := False;
end;
procedure TestCache(const Path: string);
var Cache: TFlowExitCache; Ini: TMemIniFile; Items: TArray<string>; Stamp: Int64;
    A, D, E, F, Old, Future, Legacy: string;
  procedure Seed(const FP: string; Latency, Age: Int64; Passed: Boolean);
  var Section: string;
  begin
    Section := 'Exit.' + FP;
    Ini.WriteString(Section, 'Country', 'us');
    Ini.WriteString(Section, 'ActualIP', '192.0.2.99');
    Ini.WriteString(Section, 'LastSuccessUtc', IntToStr(Stamp - Age));
    Ini.WriteString(Section, 'FlowLatencyMs', IntToStr(Latency));
    Ini.WriteInteger(Section, 'Successes', 2);
    Ini.WriteInteger(Section, 'Failures', 0);
    Ini.WriteBool(Section, 'LastPassed', Passed);
  end;
begin
  A := StringOfChar('A',40); D := StringOfChar('D',40); E := StringOfChar('E',40);
  F := StringOfChar('F',40); Old := StringOfChar('1',40);
  Future := StringOfChar('2',40); Legacy := StringOfChar('3',40);
  Stamp := TFlowExitCache.UtcNow;
  Ini := TMemIniFile.Create(Path, TEncoding.UTF8);
  try
    Ini.WriteString('Flow','Fingerprints',string.Join(',', [A,D,E,F,Old,Future,Legacy]));
    Seed(A, 300, 60, True); Seed(D, 100, 60, True);
    Seed(E, 1, 2*86400, True); Seed(F, 10, 60, False);
    Seed(Old, 1, 8*86400, True); Seed(Future, 1, -3600, True);
    Ini.UpdateFile;
  finally Ini.Free end;
  Cache := TFlowExitCache.Create(Path);
  try
    Items := Cache.OrderedHints;
    if string.Join(',',Items) <> string.Join(',', [D,A,E,F,Legacy]) then
      raise Exception.Create('Cache freshness/speed/failure order incorrect');
    Cache.RecordSuccess(A, '192.0.2.99', 100);
    Cache.RecordFailure(D);
    Cache.Save;
  finally Cache.Free end;
  Cache := TFlowExitCache.Create(Path);
  try
    Items := Cache.OrderedHints;
    if Items[0] <> A then raise Exception.Create('Failed fastest cache entry not demoted');
  finally Cache.Free end;
  Ini := TMemIniFile.Create(Path, TEncoding.UTF8);
  try
    if Ini.ReadString('Exit.'+A,'FlowLatencyMs','') <> '250' then
      raise Exception.Create('Latency smoothing incorrect');
    if Ini.ReadInteger('Exit.'+A,'Successes',0) <> 3 then raise Exception.Create('Success not persisted');
    if Ini.ReadInteger('Exit.'+D,'Failures',0) <> 1 then raise Exception.Create('Failure not persisted');
    if Ini.ReadBool('Exit.'+D,'LastPassed',True) then raise Exception.Create('Failure result not persisted');
  finally Ini.Free end;
  System.SysUtils.DeleteFile(Path);
  Ini := TMemIniFile.Create(Path, TEncoding.UTF8);
  try Ini.WriteString('Flow','Fingerprint',A); Ini.UpdateFile;
  finally Ini.Free end;
  Cache := TFlowExitCache.Create(Path);
  try
    Items := Cache.OrderedHints;
    if (Length(Items) <> 1) or (Items[0] <> A) then raise Exception.Create('Legacy cache migration failed');
  finally Cache.Free end;
  Writeln('PASS: cache freshness, speed order, failure demotion, EWMA, counters, round-trip and legacy migration');
end;

var Filter: TFlowExitFilter; State, I, Limit: Integer; Text: string; Values: TArray<string>;
begin
  try
    if ParamStr(2) = 'cache-unit' then
    begin TestCache(ParamStr(4)); Halt(0) end;
    if not TFlowExitFilter.FingerprintValid(StringOfChar('A',40)) then raise Exception.Create('valid fingerprint rejected');
    if TFlowExitFilter.FingerprintValid(StringOfChar('G',40)) then raise Exception.Create('invalid fingerprint accepted');
    if TFlowExitFilter.FlowResponseAccepted(200, 'unusual traffic Google Flow /fx/') then raise Exception.Create('denial accepted');
    if TFlowExitFilter.FlowResponseAccepted(200, '<html>OK</html>') then raise Exception.Create('generic 200 accepted');
    if TFlowExitFilter.FlowResponseAccepted(403, 'Google Flow /fx/') then raise Exception.Create('403 accepted');
    if not TFlowExitFilter.FlowResponseAccepted(200, '<html>Google Flow /fx/tools/flow</html>') then raise Exception.Create('Flow rejected');
    if not TFlowExitFilter.FlowResponseAccepted(200, '<title>Flow</title><link rel="canonical" href="https://flow.google.com/">') then raise Exception.Create('Canonical Flow rejected');
    if TFlowExitFilter.FlowResponseAccepted(308, 'Google Flow /fx/') then raise Exception.Create('Redirect accepted as readiness');
    Values := [StringOfChar('B',40), StringOfChar('C',40), StringOfChar('A',40),
      StringOfChar('D',40), StringOfChar('E',40), StringOfChar('F',40),
      StringOfChar('1',40), StringOfChar('2',40)];
    if ParamStr(2) = 'cap' then
      Values := [StringOfChar('A',40), StringOfChar('D',40), StringOfChar('E',40),
        StringOfChar('F',40), StringOfChar('1',40), StringOfChar('2',40),
        StringOfChar('3',40), StringOfChar('4',40), StringOfChar('5',40),
        StringOfChar('6',40), StringOfChar('9',40)];
    Limit := 100;
    if (ParamStr(2) = 'cancel') or (ParamStr(2) = 'seed-cancel') then Limit := 1;
    if (ParamStr(2) = 'live') or (ParamStr(2) = 'wire-deny') then
    begin
      if ParamStr(2) = 'live' then begin Values := nil; Limit := 3600 end;
      Filter := TFlowExitFilter.Create;
    end
    else Filter := TTestFilter.Create;
    try
      Filter.Start(StrToInt(ParamStr(1)), ParamStr(3), ParamStr(4), Values);
      for I := 1 to Limit do
      begin
        Sleep(100);
        Filter.Snapshot(State, Text);
        if State in [2,3] then Break;
      end;
      Writeln('STATE=', State, ' ', Text);
      if State = 2 then Sleep(700);
      if (ParamStr(2) = 'fail-member') and (State = 2) then Sleep(1600);
      if (ParamStr(2) = 'allow') and (State <> 2) then raise Exception.Create('Expected ready');
      if (ParamStr(2) = 'deny') and (State <> 3) then raise Exception.Create('Expected fail closed');
      Filter.Stop;
      Filter.Snapshot(State, Text);
      Writeln('STOP=', State, ' ', Text);
      if State <> 0 then raise Exception.Create('Restoration failed');
    finally Filter.Free end;
    Writeln('PASS');
  except
    on E: Exception do begin Writeln('FAIL: ', E.Message); Halt(1) end;
  end;
end.

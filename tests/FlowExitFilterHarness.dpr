program FlowExitFilterHarness;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.Classes, Winapi.Windows, FlowExitFilter;
type
  TTestFilter = class(TFlowExitFilter)
  private
    FCount: Integer;
  protected
    function RecheckInterval: UInt64; override;
    function Probe: Boolean; override;
  end;
function TTestFilter.RecheckInterval: UInt64;
begin
  if ParamStr(2) = 'fail-member' then Result := 800 else Result := inherited RecheckInterval;
end;
function TTestFilter.Probe: Boolean;
begin
  Inc(FCount);
  if ParamStr(2) = 'duplicate' then SetProbeIP('192.0.2.1')
  else SetProbeIP('192.0.2.' + IntToStr(FCount));
  if ParamStr(2) = 'cancel' then Sleep(400);
  if (ParamStr(2) = 'background') and (FCount >= 4) then Sleep(500);
  if (ParamStr(2) = 'router-disconnect') and (FCount >= 4) then Sleep(500);
  Result := (ParamStr(2) <> 'deny') and not ((ParamStr(2) = 'background') and (FCount >= 4));
  if (ParamStr(2) = 'fail-member') and (FCount >= 4) then Result := False;
end;
var Filter: TFlowExitFilter; State, I, Limit: Integer; Text: string; Values: TArray<string>;
begin
  try
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
    if ParamStr(2) = 'cancel' then Limit := 1;
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


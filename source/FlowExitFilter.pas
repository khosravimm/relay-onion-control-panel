unit FlowExitFilter;

interface

uses
  Winapi.Windows, System.Math, System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  System.IniFiles, System.IOUtils, System.JSON, System.NetEncoding, System.DateUtils, System.Net.HttpClient, System.Net.URLClient,
  blcksock;

type
  TFlowExitFilter = class
  private
    FWorker: TThread;
    FCancel: TEvent;
    FLock: TObject;
    FSocket: TTCPBlockSocket;
    FState: Integer;
    FMessage: string;
    FLastFailure: string;
    FPort: Integer;
    FAuth, FCache: string;
    FCandidates: TArray<string>;
    FSaved: TStringList;
    FProbePort: string;
    FChanged: Boolean;
    FControlLock: TObject;
    FRouter: TThread;
    FRouterCancel: TEvent;
    FEvents: TTCPBlockSocket;
    FRouterFailed: Integer;
    FProbeCircuit, FPrefix, FActualIP: string;
    FProbeGroup: Integer;
    FProbeAttachments: Integer;
    procedure StartRouter;
    procedure StopRouter;
    procedure RouteStreams;
    function BuildProbeCircuit(const Fingerprint: string): Boolean;
    function CircuitPrefix: string;
    function ProbePathAllowed(const Fingerprint: string): Boolean;
    procedure CloseProbeCircuit;
    procedure Status(State: Integer; const MessageText: string);
    function Command(const Text: string): TStringList;
    procedure SetCommand(const Text: string);
    function Info(const Key: string): string;
    function SavedCommand(const PortsOnly: Boolean): string;
    function ConsensusCurrent: Boolean;
    procedure Discover(Candidates: TList<string>);
    procedure Trace(const Text: string);
    procedure BlockUsers;
    procedure CloseCircuits;
    function ValidateRelay(const Fingerprint: string): Boolean;
    procedure Execute;
  protected
    function RecheckInterval: UInt64; virtual;
    procedure SetProbeIP(const IP: string);
    function Probe: Boolean; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(Port: Integer; const Auth, Cache: string;
      const Candidates: TArray<string>);
    procedure Stop;
    procedure TorStopped;
    function Active: Boolean;
    procedure Snapshot(out State: Integer; out MessageText: string);
    class function Quote(const Value: string): string; static;
    class function FingerprintValid(const Value: string): Boolean; static;
    class function FlowResponseAccepted(Code: Integer; const Body: string): Boolean; static;
  end;

implementation

const
  MIN_VALID_IPS = 3;
  MAX_VALID_IPS = 10;

function ControlFields(const Line: string): TArray<string>;
var Items: TList<string>; Current: string; C: Char; Quoted, Escaped: Boolean;
begin
  Items := TList<string>.Create;
  try
    Current := ''; Quoted := False; Escaped := False;
    for C in Line do
    begin
      if (C = ' ') and not Quoted then
      begin
        if Current <> '' then Items.Add(Current);
        Current := ''; Continue;
      end;
      Current := Current + C;
      if Escaped then Escaped := False
      else if Quoted and (C = '\') then Escaped := True
      else if C = '"' then Quoted := not Quoted;
    end;
    if Quoted or Escaped then raise Exception.Create('Malformed Tor stream event');
    if Current <> '' then Items.Add(Current);
    Result := Items.ToArray;
  finally Items.Free end;
end;

const
  FLOW_URL = 'https://flow.google.com/';
  CONFIG_KEYS = 'ExitNodes StrictNodes SocksPort HTTPTunnelPort DNSPort TransPort DisableNetwork __LeaveStreamsUnattached';

class function TFlowExitFilter.Quote(const Value: string): string;
begin
  if (Pos(#13, Value) > 0) or (Pos(#10, Value) > 0) then
    raise Exception.Create('Invalid control value');
  Result := '"' + StringReplace(StringReplace(Value, '\', '\\', [rfReplaceAll]),
    '"', '\"', [rfReplaceAll]) + '"';
end;

class function TFlowExitFilter.FingerprintValid(const Value: string): Boolean;
var C: Char;
begin
  Result := Length(Value) = 40;
  if Result then
    for C in Value do
      if not CharInSet(C, ['0'..'9', 'a'..'f', 'A'..'F']) then Exit(False);
end;

class function TFlowExitFilter.FlowResponseAccepted(Code: Integer; const Body: string): Boolean;
var S: string;
begin
  S := LowerCase(Body);
  // A generic HTTP 200, login redirect or denial page is not Flow readiness.
  Result := (Code = 200) and (Pos('flow', S) > 0) and
    ((Pos('/fx/', S) > 0) or (Pos('google flow', S) > 0) or
      ((Pos('<title>flow</title>', S) > 0) and (Pos('flow.google.com', S) > 0))) and
    (Pos('unusual traffic', S) = 0) and (Pos('not available in your country', S) = 0) and
    (Pos('unsupported country', S) = 0) and (Pos('access denied', S) = 0);
end;

constructor TFlowExitFilter.Create;
begin
  inherited;
  FCancel := TEvent.Create(nil, True, False, '');
  FLock := TObject.Create;
  FControlLock := TObject.Create;
  FRouterCancel := TEvent.Create(nil, True, False, '');
  FSaved := TStringList.Create;
end;

destructor TFlowExitFilter.Destroy;
begin
  Stop;
  FSaved.Free;
  FRouterCancel.Free;
  FControlLock.Free;
  FLock.Free;
  FCancel.Free;
  inherited;
end;

procedure TFlowExitFilter.Status(State: Integer; const MessageText: string);
begin
  TMonitor.Enter(FLock);
  try FState := State; FMessage := MessageText;
  finally TMonitor.Exit(FLock) end;
end;

procedure TFlowExitFilter.Snapshot(out State: Integer; out MessageText: string);
begin
  TMonitor.Enter(FLock);
  try State := FState; MessageText := FMessage;
  finally TMonitor.Exit(FLock) end;
end;

function TFlowExitFilter.Active: Boolean;
begin
  Result := Assigned(FWorker);
end;

procedure TFlowExitFilter.Start(Port: Integer; const Auth, Cache: string;
  const Candidates: TArray<string>);
begin
  if Active then Exit;
  FPort := Port; FAuth := Auth; FCache := Cache;
  if FileExists(FCache + '.restore') then
  begin
    FAuth := '';
    Status(3, 'Pending recovery: stop and restart Tor before enabling Flow.');
    Exit;
  end;
  FCandidates := Copy(Candidates);
  FChanged := False;
  FLastFailure := '';
  FProbeCircuit := '';
  FProbePort := '';
  FRouterFailed := 0;
  FSaved.Clear;
  FCancel.ResetEvent;
  Status(1, 'Checking US exits for Google Flow');
  FWorker := TThread.CreateAnonymousThread(Execute);
  FWorker.FreeOnTerminate := False;
  FWorker.Start;
end;

procedure TFlowExitFilter.Stop;
begin
  if not Active then Exit;
  FCancel.SetEvent;
  FWorker.WaitFor;
  FreeAndNil(FWorker);
  if FState <> 3 then Status(0, 'Flow filter OFF');
end;

procedure TFlowExitFilter.TorStopped;
begin
  if Active then Exit;
  if FCache <> '' then DeleteFile(FCache + '.restore');
  Status(0, 'Flow filter OFF');
end;

function TFlowExitFilter.Command(const Text: string): TStringList;
var Line: string; DataBlock: Boolean; Deadline: UInt64;
begin
  Result := TStringList.Create;
  TMonitor.Enter(FControlLock);
  try
    try
    FSocket.SendString(AnsiString(Text + #13#10));
    if FSocket.LastError <> 0 then raise Exception.Create('Tor control send failed');
    DataBlock := False;
    Deadline := GetTickCount64 + 15000;
    while True do
    begin
      if GetTickCount64 > Deadline then raise Exception.Create('Tor control timeout');
      Line := string(FSocket.RecvString(3000));
      if FSocket.LastError <> 0 then raise Exception.Create('Tor control disconnected');
      if DataBlock then
      begin
        if Line = '.' then DataBlock := False
        else begin
          if Line.StartsWith('..') then Delete(Line, 1, 1);
          Result.Add(Line);
        end;
        Continue;
      end;
      if not Line.StartsWith('250') then raise Exception.Create('Tor rejected command: ' + Line);
      if Length(Line) < 4 then raise Exception.Create('Malformed control response');
      if Copy(Line, 1, 4) = '250+' then DataBlock := True;
      if Copy(Line, 5, MaxInt) <> 'OK' then Result.Add(Copy(Line, 5, MaxInt));
      if Line[4] = ' ' then Break;
    end;
    except Result.Free; raise end;
  finally TMonitor.Exit(FControlLock) end;
end;

procedure TFlowExitFilter.SetCommand(const Text: string);
var Reply: TStringList;
begin
  Reply := Command(Text);
  Reply.Free;
end;

function TFlowExitFilter.Info(const Key: string): string;
var Reply: TStringList;
begin
  Reply := Command('GETINFO ' + Key);
  try Result := Reply.Text;
  finally Reply.Free end;
end;

function TFlowExitFilter.SavedCommand(const PortsOnly: Boolean): string;
var Line, Key, Value: string; P: Integer;
begin
  Result := 'SETCONF';
  for Line in FSaved do
  begin
    P := Pos('=', Line);
    if P = 0 then begin Key := Line; Value := '' end
    else begin Key := Copy(Line, 1, P-1); Value := Copy(Line, P+1, MaxInt) end;
    if PortsOnly and ((Key = 'ExitNodes') or (Key = 'StrictNodes') or
      (Key = 'DisableNetwork') or (Key = '__LeaveStreamsUnattached')) then Continue;
    if PortsOnly and (Key = 'HTTPTunnelPort') and ((Value = '0') or (Value = '')) then Continue;
    Result := Result + ' ' + Key;
    if P > 0 then Result := Result + '=' + Quote(Value);
  end;
end;

procedure TFlowExitFilter.Trace(const Text: string);
begin
  TFile.AppendAllText(FCache + '.log', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now) + ' ' + Text + sLineBreak, TEncoding.UTF8);
end;

function TFlowExitFilter.ConsensusCurrent: Boolean;
var AfterText, UntilText: string; Stamp, AfterStamp, UntilStamp: TDateTime;
begin
  Result := False;
  AfterText := Trim(Info('consensus/valid-after'));
  UntilText := Trim(Info('consensus/valid-until'));
  AfterText := Copy(AfterText, Pos('=', AfterText)+1, MaxInt);
  UntilText := Copy(UntilText, Pos('=', UntilText)+1, MaxInt);
  try
    AfterStamp := ISO8601ToDate(StringReplace(AfterText, ' ', 'T', []) + 'Z', True);
    UntilStamp := ISO8601ToDate(StringReplace(UntilText, ' ', 'T', []) + 'Z', True);
    Stamp := TTimeZone.Local.ToUniversalTime(Now);
    Result := (Stamp >= AfterStamp) and (Stamp < UntilStamp);
  except end;
end;

procedure TFlowExitFilter.Discover(Candidates: TList<string>);
var Reply: TStringList; Line, FP: string; Fields: TArray<string>; Bytes: TBytes; B: Byte;
begin
  Reply := Command('GETINFO ns/all');
  try
    FP := '';
    for Line in Reply do
    begin
      if FCancel.WaitFor(0) = wrSignaled then Exit;
      if Line.StartsWith('r ') then
      begin
        FP := '';
        Fields := Line.Split([' '], TStringSplitOptions.ExcludeEmpty);
        if Length(Fields) > 2 then
        try
          Bytes := TNetEncoding.Base64.DecodeStringToBytes(Fields[2]);
          if Length(Bytes) = 20 then
            for B in Bytes do FP := FP + IntToHex(B, 2);
        except FP := '' end;
      end
      else if Line.StartsWith('s ') and (FP <> '') then
      begin
        if (Pos(' Exit ', ' ' + Line + ' ') > 0) and
          (Pos(' BadExit ', ' ' + Line + ' ') = 0) and not Candidates.Contains(FP) then
          Candidates.Add(FP);
        FP := '';
      end;
    end;
  finally Reply.Free end;
end;

procedure TFlowExitFilter.BlockUsers;
begin
  // Only the private probe listener is open during discovery. Existing streams
  // are closed too; NEWNYM alone would leave user streams on old exits.
  FChanged := True;
  SetCommand('SETCONF SocksPort=0 DNSPort=0 TransPort=0 HTTPTunnelPort=0 DisableNetwork=1');
  CloseCircuits;
end;

procedure TFlowExitFilter.CloseCircuits;
var Reply: TStringList; Line, ID: string; P: Integer;
begin
  Reply := Command('GETINFO circuit-status');
  try
    for Line in Reply do
    begin
      P := Pos(' ', Line);
      if P = 0 then Continue;
      ID := Copy(Line, 1, P-1);
      if StrToIntDef(ID, -1) > 0 then SetCommand('CLOSECIRCUIT ' + ID);
    end;
  finally Reply.Free end;
end;

function TFlowExitFilter.ValidateRelay(const Fingerprint: string): Boolean;
var NS, Line, IP, Country: string; Fields: TArray<string>;
begin
  Result := False;
  if not FingerprintValid(Fingerprint) then Exit;
  if not ConsensusCurrent then raise Exception.Create('No current Tor consensus');
  NS := Info('ns/id/' + Fingerprint);
  IP := '';
  for Line in NS.Split([#10]) do
    if Line.StartsWith('r ') then
    begin
      Fields := Trim(Line).Split([' '], TStringSplitOptions.ExcludeEmpty);
      if Length(Fields) > 6 then IP := Fields[6];
    end;
  if IP = '' then Exit;
  if (Pos(' Exit ', NS) = 0) or (Pos(' Running ', NS) = 0) or
    (Pos(' Valid', NS) = 0) or (Pos(' BadExit', NS) > 0) then Exit;
  Country := LowerCase(Trim(Info('ip-to-country/' + IP)));
  Result := Country.EndsWith('=us');
end;

function TFlowExitFilter.Probe: Boolean;
var Http: THTTPClient; Response: IHTTPResponse; Json: TJSONValue; IP, Country: string;
begin
  Http := THTTPClient.Create;
  try
    Http.ProxySettings := TProxySettings.Create('127.0.0.1', StrToInt(FProbePort));
    Http.ConnectionTimeout := 15000;
    Http.ResponseTimeout := 15000;
    Http.HandleRedirects := False;
    // Platform certificate validation remains enabled. No direct fallback.
    Response := Http.Get('https://check.torproject.org/api/ip');
    if Response.StatusCode <> 200 then Exit(False);
    Json := TJSONObject.ParseJSONValue(Response.ContentAsString);
    try
      if not Assigned(Json) or not Json.GetValue<Boolean>('IsTor', False) then Exit(False);
      IP := Json.GetValue<string>('IP', '');
      if IP = '' then Exit(False);
      Country := LowerCase(Trim(Info('ip-to-country/' + IP)));
      if not Country.EndsWith('=us') then
      begin FLastFailure := 'Actual exit IP is not US'; Trace(FLastFailure); Exit(False) end;
      Trace('Actual exit IP ' + IP + ' country=us');
      SetProbeIP(IP);
    finally Json.Free end;
    Response := Http.Get(FLOW_URL);
    Result := FlowResponseAccepted(Response.StatusCode, Response.ContentAsString) and
      (TInterlocked.CompareExchange(FProbeAttachments, 0, 0) >= 2);
    FLastFailure := Format('Flow HTTP %d; accepted=%s', [Response.StatusCode, BoolToStr(Result, True)]);
    Trace(FLastFailure);
  finally Http.Free end;
end;

procedure TFlowExitFilter.SetProbeIP(const IP: string);
begin
  FActualIP := IP;
end;

function TFlowExitFilter.RecheckInterval: UInt64;
begin
  Result := 300000;
end;

function TFlowExitFilter.CircuitPrefix: string;
var Line: string; Fields, Nodes: TArray<string>;
begin
  Result := '';
  for Line in Info('circuit-status').Split([#10]) do
  begin
    Fields := Trim(Line).Split([' '], TStringSplitOptions.ExcludeEmpty);
    if (Length(Fields) < 3) or (Fields[1] <> 'BUILT') or
      (Pos('PURPOSE=GENERAL', Line) = 0) or (Pos('IS_INTERNAL', Line) > 0) then Continue;
    Nodes := Fields[2].Split([',']);
    if (Length(Nodes) < 3) or not FingerprintValid(Copy(Nodes[0], 2, 40)) or
      not FingerprintValid(Copy(Nodes[1], 2, 40)) then Continue;
    Result := '$' + Copy(Nodes[0], 2, 40) + ',$' + Copy(Nodes[1], 2, 40);
    Exit;
  end;
end;

procedure TFlowExitFilter.StartRouter;
var Line: string;
begin
  FEvents := TTCPBlockSocket.Create;
  FEvents.Connect('127.0.0.1', IntToStr(FPort));
  if FEvents.LastError <> 0 then raise Exception.Create('Flow stream router unavailable');
  FEvents.SendString(AnsiString('AUTHENTICATE ' + FAuth + #13#10));
  Line := string(FEvents.RecvString(5000));
  if not Line.StartsWith('250 ') then raise Exception.Create('Flow stream router authentication failed');
  FAuth := '';
  FEvents.SendString('SETEVENTS STREAM'#13#10);
  Line := string(FEvents.RecvString(5000));
  if not Line.StartsWith('250 ') then raise Exception.Create('Flow stream events unavailable');
  FRouterCancel.ResetEvent;
  FRouter := TThread.CreateAnonymousThread(RouteStreams);
  FRouter.FreeOnTerminate := False;
  FRouter.Start;
end;

procedure TFlowExitFilter.StopRouter;
begin
  FRouterCancel.SetEvent;
  if Assigned(FRouter) then
  begin
    FRouter.WaitFor;
    FreeAndNil(FRouter);
  end;
  FreeAndNil(FEvents);
end;

procedure TFlowExitFilter.RouteStreams;
var Line, CircuitID, Field, StreamID: string; Fields: TArray<string>; PrivateProbe: Boolean;
begin
  try
    while FRouterCancel.WaitFor(0) <> wrSignaled do
    begin
      Line := string(FEvents.RecvString(500));
      if FEvents.LastError = 10060 then Continue;
      if FEvents.LastError <> 0 then raise Exception.Create('Flow stream router disconnected');
      if not Line.StartsWith('650 STREAM ') then Continue;
      Fields := ControlFields(Line);
      if (Length(Fields) < 6) or not ((Fields[3] = 'NEW') or
        (Fields[3] = 'NEWRESOLVE') or (Fields[3] = 'DETACHED')) then Continue;
      StreamID := Fields[2];
      if StrToIntDef(StreamID, 0) <= 0 then Continue;
      PrivateProbe := False;
      for Field in Fields do
        if Field = 'SESSION_GROUP=' + IntToStr(FProbeGroup) then PrivateProbe := True;
      TMonitor.Enter(FLock);
      try CircuitID := FProbeCircuit;
      finally TMonitor.Exit(FLock) end;
      try
        if PrivateProbe then
        begin
          // Never return a probe stream to Tor's automatic/user selection.
          if CircuitID = '' then SetCommand('CLOSESTREAM ' + StreamID + ' 1')
          else
          begin
            SetCommand('ATTACHSTREAM ' + StreamID + ' ' + CircuitID);
            TInterlocked.Increment(FProbeAttachments);
          end;
        end
        else
          // Automatic selection can only use GENERAL circuits and the strict
          // validated ExitNodes pool. CONTROLLER circuits are never eligible.
          SetCommand('ATTACHSTREAM ' + StreamID + ' 0');
      except
        on E: Exception do
        begin
        // A stream can close between its event and our response. Drop it rather
        // than route it to a different candidate or repeatedly retry it.
          if not E.Message.StartsWith('Tor rejected command: 552 ') and
            not E.Message.StartsWith('Tor rejected command: 555 ') then
          begin
            if not E.Message.StartsWith('Tor rejected command: ') then raise;
            try SetCommand('CLOSESTREAM ' + StreamID + ' 1');
            except
              on CloseError: Exception do
                if not CloseError.Message.StartsWith('Tor rejected command: 552 ') and
                  not CloseError.Message.StartsWith('Tor rejected command: 555 ') then raise;
            end;
          end;
        end;
      end;
    end;
  except
    on E: Exception do
    begin
      if FRouterCancel.WaitFor(0) <> wrSignaled then
      begin
        TInterlocked.Exchange(FRouterFailed, 1);
        Trace('Stream router failed: ' + E.Message);
        try SetCommand('SETCONF SocksPort=0 DNSPort=0 TransPort=0 DisableNetwork=1'); except end;
        Status(3, 'Flow stream router failed; Tor traffic blocked');
      end;
    end;
  end;
end;

procedure TFlowExitFilter.CloseProbeCircuit;
var ID: string;
begin
  TMonitor.Enter(FLock);
  try ID := FProbeCircuit; FProbeCircuit := '';
  finally TMonitor.Exit(FLock) end;
  if ID <> '' then
    try SetCommand('CLOSECIRCUIT ' + ID); except end;
end;

function TFlowExitFilter.ProbePathAllowed(const Fingerprint: string): Boolean;
var Nodes: TArray<string>; Descs, Nets, Families: TArray<string>;
    I, J, P: Integer; Line, Address, Token: string; Parts: TArray<string>;
begin
  Result := False;
  Nodes := (FPrefix + ',$' + Fingerprint).Split([',']);
  if Length(Nodes) <> 3 then Exit;
  SetLength(Descs, 3); SetLength(Nets, 3); SetLength(Families, 3);
  for I := 0 to 2 do
  begin
    Nodes[I] := Copy(Nodes[I], 2, 40);
    Descs[I] := Info('md/id/' + Nodes[I]);
    if Pos('ntor-onion-key ', Descs[I]) = 0 then Exit;
    for Line in Info('ns/id/' + Nodes[I]).Split([#10]) do
      if Line.StartsWith('r ') then
      begin
        Parts := Trim(Line).Split([' '], TStringSplitOptions.ExcludeEmpty);
        if Length(Parts) < 7 then Exit;
        Address := Parts[6]; Parts := Address.Split(['.']);
        if Length(Parts) <> 4 then Exit;
        Nets[I] := Parts[0] + '.' + Parts[1];
      end;
    if Nets[I] = '' then Exit;
    for Line in Descs[I].Split([#10]) do
      if Line.StartsWith('family ') then Families[I] := UpperCase(Line);
    for J := 0 to I-1 do
    begin
      if SameText(Nodes[I], Nodes[J]) or (Nets[I] = Nets[J]) then Exit;
      // Conservatively reject even a one-sided declared family relationship.
      if (Pos('$' + Nodes[J], Families[I]) > 0) or
        (Pos('$' + Nodes[I], Families[J]) > 0) then Exit;
      for Line in Descs[I].Split([#10]) do
        if Line.StartsWith('family-ids ') then
          for Token in Trim(Line).Split([' '], TStringSplitOptions.ExcludeEmpty) do
            if Token <> 'family-ids' then
              for Address in Descs[J].Split([#10]) do
                if Address.StartsWith('family-ids ') and
                  (Pos(' ' + Token + ' ', ' ' + Trim(Address) + ' ') > 0) then Exit;
      // IPv6 OR addresses are written in canonical compressed form. Compare
      // the first 32 bits where present, including a leading zero compression.
      for Line in Descs[I].Split([#10]) do
        if Line.StartsWith('a [') then
          for Address in Descs[J].Split([#10]) do
            if Address.StartsWith('a [') then
            begin
              Parts := Copy(Line, 4, MaxInt).Split([':']);
              if Length(Parts) < 2 then Exit;
              P := StrToIntDef('$' + Parts[0], 0);
              Token := IntToStr(P) + ':' + IntToStr(StrToIntDef('$' + Parts[1], 0));
              Parts := Copy(Address, 4, MaxInt).Split([':']);
              if (Length(Parts) >= 2) and (Token = IntToStr(StrToIntDef('$' + Parts[0], 0)) +
                ':' + IntToStr(StrToIntDef('$' + Parts[1], 0))) then Exit;
            end;
    end;
  end;
  Result := True;
end;

function TFlowExitFilter.BuildProbeCircuit(const Fingerprint: string): Boolean;
var Reply: TStringList; ID, Line: string; Fields, Nodes: TArray<string>; Deadline: UInt64;
begin
  Result := False;
  CloseProbeCircuit;
  TInterlocked.Exchange(FProbeAttachments, 0);
  if Pos('$' + Fingerprint, FPrefix) > 0 then Exit;
  if not ProbePathAllowed(Fingerprint) then Exit;
  Reply := Command('EXTENDCIRCUIT 0 ' + FPrefix + ',$' + Fingerprint + ' purpose=controller');
  try
    if (Reply.Count <> 1) or not Reply[0].StartsWith('EXTENDED ') then Exit;
    ID := Trim(Copy(Reply[0], 10, MaxInt));
  finally Reply.Free end;
  if StrToIntDef(ID, 0) <= 0 then Exit;
  TMonitor.Enter(FLock);
  try FProbeCircuit := ID;
  finally TMonitor.Exit(FLock) end;
  Deadline := GetTickCount64 + 30000;
  while (GetTickCount64 < Deadline) and (FCancel.WaitFor(0) <> wrSignaled) do
  begin
    if TInterlocked.CompareExchange(FRouterFailed, 0, 0) <> 0 then
      raise Exception.Create('Flow stream router failed');
    for Line in Info('circuit-status').Split([#10]) do
    begin
      Fields := Trim(Line).Split([' '], TStringSplitOptions.ExcludeEmpty);
      if (Length(Fields) < 3) or (Fields[0] <> ID) then Continue;
      if Fields[1] <> 'BUILT' then Continue;
      Nodes := Fields[2].Split([',']);
      Result := (Length(Nodes) = 3) and (Pos('PURPOSE=CONTROLLER', Line) > 0) and
        SameText(Copy(Nodes[2], 2, 40), Fingerprint);
      Exit;
    end;
    if FCancel.WaitFor(200) = wrSignaled then Break;
  end;
end;

procedure TFlowExitFilter.Execute;
var Reply: TStringList; Candidates, Pool, Hints: TList<string>; Ini: TMemIniFile;
    IPs: TDictionary<string, string>; Checked: TDictionary<string, UInt64>;
    FP, Cached, Listener, Nodes, Oldest: string;
    I, J: Integer; UsersOpen, OK, DiscoveryComplete: Boolean; Stamp: UInt64;

  procedure ApplyPool;
  var Item, Line: string; Fields, Path: TArray<string>;
  begin
    Nodes := '';
    for Item in Pool do
    begin
      if Nodes <> '' then Nodes := Nodes + ',';
      Nodes := Nodes + '$' + Item;
    end;
    // With all user listeners closed, keep directory path availability for
    // controller probes. No unvalidated GENERAL circuit survives reopening.
    if Nodes = '' then Nodes := '{us}';
    if (Pool.Count < MIN_VALID_IPS) and UsersOpen then
    begin
      SetCommand('SETCONF SocksPort=0 DNSPort=0 TransPort=0 HTTPTunnelPort=' +
        Quote('127.0.0.1:' + FProbePort + ' SessionGroup=' + IntToStr(FProbeGroup)));
      UsersOpen := False;
      CloseCircuits;
      Trace('Pool below minimum; user listeners closed');
    end;
    SetCommand('SETCONF ExitNodes=' + Quote(Nodes) + ' StrictNodes=1');
    // Remove existing user circuits on an exit that has failed revalidation.
    for Line in Info('circuit-status').Split([#10]) do
    begin
      Fields := Trim(Line).Split([' '], TStringSplitOptions.ExcludeEmpty);
      if (Length(Fields) < 3) or ((Pos('PURPOSE=GENERAL', Line) = 0) and
        (Pos('PURPOSE=CONFLUX_LINKED', Line) = 0) and (Pos('PURPOSE=CONFLUX_UNLINKED', Line) = 0)) or
        (Pos('IS_INTERNAL', Line) > 0) then Continue;
      Path := Fields[2].Split([',']);
      if (Length(Path) < 3) or not Pool.Contains(Copy(Path[High(Path)], 2, 40)) then
        SetCommand('CLOSECIRCUIT ' + Fields[0]);
    end;
    if (Pool.Count >= MIN_VALID_IPS) and not UsersOpen then
    begin
      if FCancel.WaitFor(0) = wrSignaled then Exit;
      if TInterlocked.CompareExchange(FRouterFailed, 0, 0) <> 0 then
        raise Exception.Create('Flow stream router failed');
      SetCommand(SavedCommand(True) + ' HTTPTunnelPort=' +
        Quote('127.0.0.1:' + FProbePort + ' SessionGroup=' + IntToStr(FProbeGroup)));
      UsersOpen := True;
      Trace('READY: ' + IntToStr(Pool.Count) + ' distinct US IPs; user listeners opened; background scan continues');
    end;
    Ini := TMemIniFile.Create(FCache, TEncoding.UTF8);
    try
      Ini.EraseSection('Flow');
      Ini.WriteString('Flow', 'Fingerprints', string.Join(',', Hints.ToArray));
      Ini.WriteDateTime('Flow', 'CheckedAt', Now);
      Ini.UpdateFile;
    finally Ini.Free end;
  end;

  function CheckExit(const Item: string): Boolean;
  begin
    Result := False;
    FActualIP := '';
    if not ValidateRelay(Item) then Exit;
    Trace('Testing US fingerprint ' + Item);
    try
      if BuildProbeCircuit(Item) then Result := Probe and (FActualIP <> '');
    finally CloseProbeCircuit end;
    if FCancel.WaitFor(0) = wrSignaled then Result := False;
    if TInterlocked.CompareExchange(FRouterFailed, 0, 0) <> 0 then
      raise Exception.Create('Flow stream router failed');
  end;

begin
  FSocket := TTCPBlockSocket.Create;
  Candidates := TList<string>.Create;
  Pool := TList<string>.Create;
  Hints := TList<string>.Create;
  IPs := TDictionary<string, string>.Create;
  Checked := TDictionary<string, UInt64>.Create;
  UsersOpen := False;
  DiscoveryComplete := False;
  try
    try
      FSocket.Connect('127.0.0.1', IntToStr(FPort));
      if FSocket.LastError <> 0 then raise Exception.Create('Tor control unavailable');
      SetCommand('AUTHENTICATE ' + FAuth);
      Reply := Command('GETCONF ' + CONFIG_KEYS);
      try FSaved.Assign(Reply);
      finally Reply.Free end;
      if FSaved.IndexOf('__LeaveStreamsUnattached=1') >= 0 then
        raise Exception.Create('Another controller owns stream attachment');
      FPrefix := CircuitPrefix;
      if FPrefix = '' then raise Exception.Create('No built three-hop Tor circuit; reconnect Tor and retry Flow');
      FProbeGroup := 100000000 + Random(900000000);
      for Cached in FSaved do
        if Pos('SessionGroup=' + IntToStr(FProbeGroup), Cached) > 0 then
          raise Exception.Create('Probe session group conflict; retry Flow');
      FSaved.SaveToFile(FCache + '.restore', TEncoding.UTF8);
      BlockUsers;
      StartRouter;
      SetCommand('SETCONF ExitNodes="{us}" StrictNodes=1 ' +
        '__LeaveStreamsUnattached=1 HTTPTunnelPort=' +
        Quote('127.0.0.1:auto SessionGroup=' + IntToStr(FProbeGroup)) + ' DisableNetwork=0');
      Listener := Info('net/listeners/httptunnel');
      Listener := StringReplace(Trim(Copy(Listener, Pos('=', Listener)+1, MaxInt)), '"', '', [rfReplaceAll]);
      FProbePort := Copy(Listener, LastDelimiter(':', Listener)+1, MaxInt);
      if StrToIntDef(FProbePort, 0) = 0 then raise Exception.Create('No probe listener');
      Ini := TMemIniFile.Create(FCache, TEncoding.UTF8);
      try
        Cached := Ini.ReadString('Flow', 'Fingerprints', Ini.ReadString('Flow', 'Fingerprint', ''));
        for FP in Cached.Split([',']) do
          if FingerprintValid(FP) and not Candidates.Contains(FP) then Candidates.Add(FP);
      finally Ini.Free end;
      for FP in FCandidates do
        if FingerprintValid(FP) and not Candidates.Contains(FP) then Candidates.Add(FP);
      if Length(FCandidates) = 0 then Discover(Candidates);
      I := 0;
      while FCancel.WaitFor(0) <> wrSignaled do
      begin
        if TInterlocked.CompareExchange(FRouterFailed, 0, 0) <> 0 then
          raise Exception.Create('Flow stream router failed');
        if not ConsensusCurrent then raise Exception.Create('No current Tor consensus');
        // Revalidate old members while discovery continues. Background probes
        // never alter the user pool or close healthy user circuits.
        Oldest := ''; Stamp := GetTickCount64;
        for FP in Pool do
          if (Checked[FP] + RecheckInterval <= Stamp) and
            ((Oldest = '') or (Checked[FP] < Checked[Oldest])) then Oldest := FP;
        if Oldest <> '' then FP := Oldest
        else if not DiscoveryComplete and (I < Candidates.Count) then begin FP := Candidates[I]; Inc(I) end
        else
        begin
          if not UsersOpen then
            Status(3, Format('Only %d / %d valid US IPs; Tor traffic blocked', [Pool.Count, MIN_VALID_IPS]))
          else Status(2, Format('%d US IPs | scan complete', [Pool.Count]));
          if FCancel.WaitFor(1000) = wrSignaled then Break;
          Continue;
        end;
        if UsersOpen then
          Status(2, Format('%d US IPs | scan %d/%d', [Pool.Count, I, Candidates.Count]))
        else Status(1, Format('%d/%d IPs | scan %d/%d', [Pool.Count, MIN_VALID_IPS, I, Candidates.Count]));
        try
          OK := CheckExit(FP);
          if OK then
          begin
            for J := 0 to Pool.Count-1 do
              if (Pool[J] <> FP) and (IPs[Pool[J]] = FActualIP) then OK := False;
            if not OK then Trace('Duplicate actual IP rejected: ' + FActualIP);
          end;
          if OK then
          begin
            if not Hints.Contains(FP) then Hints.Add(FP);
            if Pool.Contains(FP) or (Pool.Count < MAX_VALID_IPS) then
            begin
              if not Pool.Contains(FP) then Pool.Add(FP);
              IPs.AddOrSetValue(FP, FActualIP);
              Checked.AddOrSetValue(FP, GetTickCount64);
            end;
            Trace('Validated ' + FP + ' IP=' + FActualIP + '; active=' + IntToStr(Pool.Count));
            ApplyPool;
            if (Pool.Count >= MAX_VALID_IPS) and not DiscoveryComplete then
            begin
              DiscoveryComplete := True;
              Trace('Discovery stopped: 10 distinct valid IPs; periodic health checks continue');
            end;
          end
          else if Pool.Contains(FP) then
          begin
            Pool.Remove(FP); Hints.Remove(FP); IPs.Remove(FP); Checked.Remove(FP);
            ApplyPool;
          end;
        except
          on E: Exception do
          begin
            if TInterlocked.CompareExchange(FRouterFailed, 0, 0) <> 0 then raise;
            FLastFailure := E.Message; Trace('Rejected: ' + E.Message);
            if Pool.Contains(FP) then
            begin
              Pool.Remove(FP); Hints.Remove(FP); IPs.Remove(FP); Checked.Remove(FP); ApplyPool;
            end;
          end;
        end;
      end;
    except
      on E: Exception do
      begin
        if FChanged then
          try SetCommand('SETCONF SocksPort=0 DNSPort=0 TransPort=0 DisableNetwork=1'); except end;
        Status(3, E.Message + ' (Flow not ready)');
        FCancel.WaitFor(INFINITE);
      end;
    end;
    if FChanged then
    begin
      try
        SetCommand('SETCONF DisableNetwork=1');
        StopRouter;
        CloseCircuits;
        SetCommand(SavedCommand(False));
        DeleteFile(FCache + '.restore');
        Status(0, 'Flow filter OFF; previous Tor settings restored');
      except
        on E: Exception do Status(3, 'Restore failed; restart Tor before using it: ' + E.Message);
      end;
    end
    else Status(0, 'Flow filter OFF; Tor settings were not changed');
  finally
    StopRouter;
    FAuth := '';
    Checked.Free; IPs.Free; Hints.Free; Pool.Free; Candidates.Free;
    FSocket.Free; FSocket := nil;
  end;
end;

end.

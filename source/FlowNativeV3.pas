unit FlowNativeV3;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils,
  System.SyncObjs, System.Generics.Collections,
  System.Net.HttpClient, System.Net.URLClient;

type
  TFlowCandidateV3 = record
    Fingerprint: string;
    IPv4: string;
  end;

  TFlowNativeV3 = class
  private
    FThread: TThread;
    FStop: Integer;
    FProcessID: Cardinal;
    FProcessHandle: THandle;
    FStatus: Integer; // 0 off, 1 starting, 2 ready, 3 failed
    FLastMessage: string;
    FSelectedIP: string;
    FRoot: string;
    FInstallRoot: string;
    FUserDir: string;
    FCandidates: TArray<TFlowCandidateV3>;
    FLock: TObject;
    procedure SetStatus(Value: Integer; const Msg, IP: string);
    procedure Worker;
    function LaunchTor(const FP: string): Boolean;
    procedure KillDedicatedTor;
    function ProbeFlow(out HttpCode: Integer): Boolean;
    procedure PrepareDirectory;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(const Root, UserDir: string;
      const Candidates: TArray<TFlowCandidateV3>);
    procedure Stop;
    procedure Snapshot(out Status: Integer; out MessageText, ExitIP: string);
  end;

implementation

constructor TFlowNativeV3.Create;
begin
  inherited;
  FLock := TObject.Create;
  FStatus := 0;
  FProcessHandle := 0;
end;

destructor TFlowNativeV3.Destroy;
begin
  Stop;
  FLock.Free;
  inherited;
end;

procedure TFlowNativeV3.SetStatus(Value: Integer; const Msg, IP: string);
begin
  TMonitor.Enter(FLock);
  try
    FStatus := Value;
    FLastMessage := Msg;
    FSelectedIP := IP;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TFlowNativeV3.Snapshot(out Status: Integer;
  out MessageText, ExitIP: string);
begin
  TMonitor.Enter(FLock);
  try
    Status := FStatus;
    MessageText := FLastMessage;
    ExitIP := FSelectedIP;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TFlowNativeV3.KillDedicatedTor;
var
  H: THandle;
begin
  TMonitor.Enter(FLock);
  try
    H := FProcessHandle;
    FProcessHandle := 0;
    FProcessID := 0;
  finally
    TMonitor.Exit(FLock);
  end;
  if H <> 0 then
  try
    if WaitForSingleObject(H, 0) = WAIT_TIMEOUT then
      TerminateProcess(H, 0);
    WaitForSingleObject(H, 3000);
  finally
    CloseHandle(H);
  end;
end;

procedure TFlowNativeV3.PrepareDirectory;
var
  Base, Src, Dest, Name: string;
begin
  Base := TPath.Combine(GetEnvironmentVariable('LOCALAPPDATA'),
    'RelayOnionControlPanel\FlowV3Native');
  ForceDirectories(Base);
  FRoot := Base;
  ForceDirectories(TPath.Combine(Base, 'tor-data'));
  for Name in ['cached-certs','cached-microdesc-consensus','cached-microdescs'] do
  begin
    Src := TPath.Combine(FUserDir, Name);
    Dest := TPath.Combine(TPath.Combine(Base, 'tor-data'), Name);
    if TFile.Exists(Src) and
       ((not TFile.Exists(Dest)) or
       (TFile.GetLastWriteTime(Src) > TFile.GetLastWriteTime(Dest))) then
      TFile.Copy(Src, Dest, True);
  end;
end;

function TFlowNativeV3.LaunchTor(const FP: string): Boolean;
var
  Exe, Args: string;
  StartInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
begin
  Result := False;
  Exe := TPath.Combine(FInstallRoot, 'Tor\tor.exe');
  if not FileExists(Exe) then Exit;
  Args := '"' + Exe + '" --SocksPort 127.0.0.1:19050' +
    ' --ControlPort 127.0.0.1:19051 --HTTPTunnelPort 127.0.0.1:19052' +
    ' --CookieAuthentication 1' +
    ' --DataDirectory "' + TPath.Combine(FRoot, 'tor-data') + '"' +
    ' --ExitNodes ' + #36 + FP + ' --StrictNodes 1 --ClientUseIPv6 0';
  if FileExists(TPath.Combine(FInstallRoot, 'Data\geoip')) then
    Args := Args + ' --GeoIPFile "' +
      TPath.Combine(FInstallRoot, 'Data\geoip') + '"';
  if FileExists(TPath.Combine(FInstallRoot, 'Data\geoip6')) then
    Args := Args + ' --GeoIPv6File "' +
      TPath.Combine(FInstallRoot, 'Data\geoip6') + '"';
  FillChar(StartInfo, SizeOf(StartInfo), 0);
  FillChar(ProcessInfo, SizeOf(ProcessInfo), 0);
  StartInfo.cb := SizeOf(StartInfo);
  StartInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartInfo.wShowWindow := SW_HIDE;
  UniqueString(Args);
  Result := CreateProcess(PChar(Exe), PChar(Args), nil, nil,
    False, CREATE_NO_WINDOW, nil, nil, StartInfo, ProcessInfo);
  if Result then
  begin
    TMonitor.Enter(FLock);
    try
      FProcessID := ProcessInfo.dwProcessId;
      FProcessHandle := ProcessInfo.hProcess;
    finally
      TMonitor.Exit(FLock);
    end;
    CloseHandle(ProcessInfo.hThread);
  end;
end;

function TFlowNativeV3.ProbeFlow(out HttpCode: Integer): Boolean;
var
  Http: THTTPClient;
  Response: IHTTPResponse;
begin
  HttpCode := 0;
  Result := False;
  Http := THTTPClient.Create;
  try
    Http.ProxySettings := TProxySettings.Create('127.0.0.1', 19052);
    Http.ConnectionTimeout := 5000;
    Http.ResponseTimeout := 9000;
    try
      Response := Http.Get('https://flow.google.com/');
      HttpCode := Response.StatusCode;
      Result := HttpCode = 200;
    except
      on E: Exception do
        HttpCode := 0;
    end;
  finally
    Http.Free;
  end;
end;

procedure TFlowNativeV3.Worker;
var
  Entry: TFlowCandidateV3;
  I, Attempt, Code: Integer;
  OK: Boolean;
begin
  try
    PrepareDirectory;
    for I := 0 to High(FCandidates) do
    begin
      if TInterlocked.CompareExchange(FStop, 0, 0) <> 0 then Break;
      Entry := FCandidates[I];
      SetStatus(1, Format('Checking exit %d/%d', [I+1, Length(FCandidates)]),
        Entry.IPv4);
      KillDedicatedTor;
      if not LaunchTor(Entry.Fingerprint) then
      begin
        SetStatus(3, 'Unable to start bundled Tor process', '');
        Exit;
      end;
      OK := False;
      for Attempt := 1 to 6 do
      begin
        if TInterlocked.CompareExchange(FStop, 0, 0) <> 0 then Break;
        Sleep(3000);
        if ProbeFlow(Code) then
        begin
          OK := True;
          Break;
        end;
        // An HTTP denial is definitive for this exit; retry another relay.
        if (Code = 403) or (Code = 429) then Break;
      end;
      if OK then
      begin
        TFile.AppendAllText(TPath.Combine(FRoot, 'exit-health.log'),
          Format('%s,%s,http=200,verified%s', [
            FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), Entry.IPv4,
            sLineBreak]), TEncoding.UTF8);
        SetStatus(2, 'Flow HTTP 200 verified through selected exit',
          Entry.IPv4);
        Exit;
      end;
      TFile.AppendAllText(TPath.Combine(FRoot, 'exit-health.log'),
        Format('%s,%s,http=%d,failed%s', [
          FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), Entry.IPv4,
          Code, sLineBreak]), TEncoding.UTF8);
    end;
    KillDedicatedTor;
    if TInterlocked.CompareExchange(FStop, 0, 0) = 0 then
      SetStatus(3, 'No validated Flow exit available', '');
  except
    on E: Exception do
    begin
      KillDedicatedTor;
      SetStatus(3, E.Message, '');
    end;
  end;
end;

procedure TFlowNativeV3.Start(const Root, UserDir: string;
  const Candidates: TArray<TFlowCandidateV3>);
begin
  // A completed validation thread must be reaped before the profile reloads.
  if Assigned(FThread) then
  begin
    if WaitForSingleObject(FThread.Handle, 0) = WAIT_TIMEOUT then Exit;
    FreeAndNil(FThread);
    KillDedicatedTor;
  end;
  if Length(Candidates) = 0 then
  begin
    SetStatus(3, 'Flow profile contains no candidate exits', '');
    Exit;
  end;
  FCandidates := Copy(Candidates);
  FUserDir := UserDir;
  FInstallRoot := Root;
  TInterlocked.Exchange(FStop, 0);
  SetStatus(1, 'Discovering and validating US exit relays', '');
  FThread := TThread.CreateAnonymousThread(Worker);
  FThread.FreeOnTerminate := False;
  FThread.Start;
end;

procedure TFlowNativeV3.Stop;
begin
  TInterlocked.Exchange(FStop, 1);
  KillDedicatedTor;
  if Assigned(FThread) then
  begin
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  // A worker can race with Stop just before spawning its own child.
  // Reap any child it started during the join, but never touch other Tor instances.
  KillDedicatedTor;
  SetStatus(0, 'Stopped', '');
end;

end.

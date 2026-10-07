unit NetworkIntegration;

interface

uses
  Winapi.Windows, Winapi.ShellAPI, Winapi.WinInet,
  System.SysUtils, System.Classes, System.IniFiles, System.IOUtils,
  System.Win.Registry, ConstData, Functions;

type
  TNetworkIntegrationManager = class
  private
    FProgramDir: string;
    FUserDir: string;
    FEngineExe: string;
    FConfigFile: string;
    FProxyStateFile: string;
    FLogFile: string;
    FProcess: TProcessInfo;
    FSystemProxyActive: Boolean;
    FTunActive: Boolean;
    FJobHandle: THandle;
    FAppliedConfig: string;
    FTunInterfaceName: string;
    FRuntimeLogFile: string;
    procedure RenewTunInterfaceName;
    function TunRoutesReady: Boolean;
  protected
    function BuildConfig(SystemProxyEnabled, TunEnabled: Boolean;
      const TorHost: string; TorPort: Word): string;
    function StartEngine(NeedElevation: Boolean; out ErrorText: string): Boolean; virtual;
    function StopEngine(out ErrorText: string): Boolean; virtual;
    procedure SaveProxySnapshot;
    procedure ApplySystemProxy;
    procedure RestoreSystemProxy;
    procedure NotifyProxyChanged;
    function IsEngineRunning: Boolean; virtual;
    procedure AppendLog(const Msg: string);
    function RunConfigCheck(out ErrorText: string): Boolean; virtual;
  public
    constructor Create(const AProgramDir, AUserDir: string; AJobHandle: THandle);
    destructor Destroy; override;
    procedure RecoverStaleState;
    function Apply(SystemProxyEnabled, TunEnabled: Boolean;
      const TorHost: string; TorPort: Word; AllowElevation: Boolean; out ErrorText: string): Boolean;
    procedure Shutdown;
    property SystemProxyActive: Boolean read FSystemProxyActive;
    property TunActive: Boolean read FTunActive;
  end;

implementation

uses Winapi.IpHlpApi, Winapi.IpTypes, Winapi.IpRtrMib, System.JSON;

const
  INTERNET_SETTINGS_KEY = 'Software\Microsoft\Windows\CurrentVersion\Internet Settings';
  MIXED_PROXY_PORT = 2080;

constructor TNetworkIntegrationManager.Create(const AProgramDir, AUserDir: string; AJobHandle: THandle);
begin
  inherited Create;
  FProgramDir := IncludeTrailingPathDelimiter(AProgramDir);
  FUserDir := IncludeTrailingPathDelimiter(AUserDir);
  FEngineExe := FProgramDir + 'optional\sing-box\sing-box.exe';
  ForceDirectories(FUserDir + 'network');
  FConfigFile := FUserDir + 'network\sing-box.json';
  FProxyStateFile := FUserDir + 'network\windows-proxy-state.ini';
  FLogFile := FUserDir + 'network\network-integration.log';
  FRuntimeLogFile := FUserDir + 'network\sing-box-runtime.log';
  RenewTunInterfaceName;
  FProcess := cDefaultProcessInfo;
  FSystemProxyActive := False;
  FTunActive := False;
  FJobHandle := AJobHandle;
end;

procedure TNetworkIntegrationManager.RenewTunInterfaceName;
var Id: TGUID;
begin
  if CreateGUID(Id) <> 0 then
    raise Exception.Create('Unable to allocate a TUN interface identity');
  FTunInterfaceName := 'RelayOnion-' + Copy(GUIDToString(Id), 2, 8);
end;

function TNetworkIntegrationManager.TunRoutesReady: Boolean;
var
  Buffer: TBytes;
  Size, IfIndex: ULONG;
  Adapter: PIP_ADAPTER_ADDRESSES;
  Table: PMIB_IPFORWARDTABLE;
  Row: PMIB_IPFORWARDROW;
  I: Integer;
  LowerHalf, UpperHalf: Boolean;
begin
  Result := False;
  IfIndex := 0;
  Size := 0;
  if GetAdaptersAddresses(2, 0, nil, nil, @Size) <> ERROR_BUFFER_OVERFLOW then Exit;
  SetLength(Buffer, Size);
  Adapter := PIP_ADAPTER_ADDRESSES(@Buffer[0]);
  if GetAdaptersAddresses(2, 0, nil, Adapter, @Size) <> NO_ERROR then Exit;
  while Adapter <> nil do
  begin
    if (Adapter.FriendlyName <> nil) and
      SameText(string(Adapter.FriendlyName), FTunInterfaceName) and
      (Ord(Adapter.OperStatus) = 1) then
    begin
      IfIndex := Adapter.Union.IfIndex;
      Break;
    end;
    Adapter := Adapter.Next;
  end;
  if IfIndex = 0 then Exit;
  Size := 0;
  if GetIpForwardTable(nil, Size, False) <> ERROR_INSUFFICIENT_BUFFER then Exit;
  SetLength(Buffer, Size);
  Table := PMIB_IPFORWARDTABLE(@Buffer[0]);
  if GetIpForwardTable(Table, Size, False) <> NO_ERROR then Exit;
  LowerHalf := False;
  UpperHalf := False;
  for I := 0 to Integer(Table.dwNumEntries) - 1 do
  begin
    Row := PMIB_IPFORWARDROW(PByte(@Table.table[0]) + I * SizeOf(MIB_IPFORWARDROW));
    // IPv4 DWORDs are stored in network byte order (128.0.0.0 = $80).
    if (Row.dwForwardIfIndex = IfIndex) and (Row.dwForwardMask = $80) and
      (Row.dwForwardType <> MIB_IPROUTE_TYPE_INVALID) then
    begin
      if Row.dwForwardDest = 0 then LowerHalf := True;
      if Row.dwForwardDest = $80 then UpperHalf := True;
    end;
  end;
  Result := LowerHalf and UpperHalf;
end;

destructor TNetworkIntegrationManager.Destroy;
begin
  Shutdown;
  inherited;
end;

procedure TNetworkIntegrationManager.AppendLog(const Msg: string);
begin
  try
    ForceDirectories(ExtractFilePath(FLogFile));
    TFile.AppendAllText(FLogFile,
      FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' ' + Msg + sLineBreak,
      TEncoding.UTF8);
  except
  end;
end;

function TNetworkIntegrationManager.RunConfigCheck(out ErrorText: string): Boolean;
var
  CmdLine: string;
  CheckProcess: TProcessInfo;
  WaitResult, ExitCode: DWORD;
begin
  Result := False;
  ErrorText := '';
  if not FileExists(FEngineExe) then
  begin
    ErrorText := 'sing-box.exe is not installed in optional\sing-box: ' + FEngineExe;
    AppendLog(ErrorText);
    Exit;
  end;

  CmdLine := '"' + FEngineExe + '" check -c "' + FConfigFile + '"';
  AppendLog('check: ' + CmdLine);
  CheckProcess := ExecuteProcess(CmdLine, [pfHideWindow], 0);
  if CheckProcess.hProcess = INVALID_HANDLE_VALUE then
  begin
    ErrorText := 'Unable to start sing-box config check';
    AppendLog('check failed: ' + ErrorText);
    Exit;
  end;
  try
    WaitResult := WaitForSingleObject(CheckProcess.hProcess, 7000);
    if WaitResult = WAIT_TIMEOUT then
    begin
      TerminateProcess(CheckProcess.hProcess, 2);
      ErrorText := 'sing-box config check timed out';
      AppendLog('check failed: ' + ErrorText);
      Exit;
    end;
    ExitCode := 1;
    GetExitCodeProcess(CheckProcess.hProcess, ExitCode);
    if ExitCode <> 0 then
    begin
      ErrorText := 'sing-box config check failed, exit code ' + IntToStr(ExitCode) +
        '. See ' + FLogFile;
      AppendLog(ErrorText);
      Exit;
    end;
  finally
    CloseHandle(CheckProcess.hProcess);
  end;
  AppendLog('check: PASS');
  Result := True;
end;
procedure TNetworkIntegrationManager.NotifyProxyChanged;
begin
  InternetSetOption(nil, INTERNET_OPTION_SETTINGS_CHANGED, nil, 0);
  InternetSetOption(nil, INTERNET_OPTION_REFRESH, nil, 0);
end;

procedure TNetworkIntegrationManager.SaveProxySnapshot;
var
  Reg: TRegistry;
  Ini: TMemIniFile;
begin
  if FileExists(FProxyStateFile) then
    Exit;

  Reg := TRegistry.Create(KEY_READ);
  Ini := TMemIniFile.Create(FProxyStateFile, TEncoding.UTF8);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if not Reg.OpenKeyReadOnly(INTERNET_SETTINGS_KEY) then
      raise Exception.Create('Unable to read Windows proxy settings');

    Ini.WriteBool('Proxy', 'ProxyEnableExists', Reg.ValueExists('ProxyEnable'));
    if Reg.ValueExists('ProxyEnable') then
      Ini.WriteInteger('Proxy', 'ProxyEnable', Reg.ReadInteger('ProxyEnable'));

    Ini.WriteBool('Proxy', 'ProxyServerExists', Reg.ValueExists('ProxyServer'));
    if Reg.ValueExists('ProxyServer') then
      Ini.WriteString('Proxy', 'ProxyServer', Reg.ReadString('ProxyServer'));

    Ini.WriteBool('Proxy', 'ProxyOverrideExists', Reg.ValueExists('ProxyOverride'));
    if Reg.ValueExists('ProxyOverride') then
      Ini.WriteString('Proxy', 'ProxyOverride', Reg.ReadString('ProxyOverride'));

    Ini.UpdateFile;
  finally
    Ini.Free;
    Reg.Free;
  end;
end;

procedure TNetworkIntegrationManager.ApplySystemProxy;
var
  Reg: TRegistry;
begin
  SaveProxySnapshot;
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if not Reg.OpenKey(INTERNET_SETTINGS_KEY, False) then
      raise Exception.Create('Unable to update Windows proxy settings');
    Reg.WriteInteger('ProxyEnable', 1);
    Reg.WriteString('ProxyServer', '127.0.0.1:' + IntToStr(MIXED_PROXY_PORT));
    Reg.WriteString('ProxyOverride', '<local>;localhost;127.*');
  finally
    Reg.Free;
  end;
  NotifyProxyChanged;
  FSystemProxyActive := True;
end;

procedure TNetworkIntegrationManager.RestoreSystemProxy;
var
  Reg: TRegistry;
  Ini: TMemIniFile;
begin
  if not FileExists(FProxyStateFile) then
  begin
    FSystemProxyActive := False;
    Exit;
  end;

  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  Ini := TMemIniFile.Create(FProxyStateFile, TEncoding.UTF8);
  try
    Reg.RootKey := HKEY_CURRENT_USER;
    if not Reg.OpenKey(INTERNET_SETTINGS_KEY, False) then
      raise Exception.Create('Unable to restore Windows proxy settings');

    if Ini.ReadBool('Proxy', 'ProxyEnableExists', False) then
      Reg.WriteInteger('ProxyEnable', Ini.ReadInteger('Proxy', 'ProxyEnable', 0))
    else if Reg.ValueExists('ProxyEnable') then
      Reg.DeleteValue('ProxyEnable');

    if Ini.ReadBool('Proxy', 'ProxyServerExists', False) then
      Reg.WriteString('ProxyServer', Ini.ReadString('Proxy', 'ProxyServer', ''))
    else if Reg.ValueExists('ProxyServer') then
      Reg.DeleteValue('ProxyServer');

    if Ini.ReadBool('Proxy', 'ProxyOverrideExists', False) then
      Reg.WriteString('ProxyOverride', Ini.ReadString('Proxy', 'ProxyOverride', ''))
    else if Reg.ValueExists('ProxyOverride') then
      Reg.DeleteValue('ProxyOverride');
  finally
    Ini.Free;
    Reg.Free;
  end;

  DeleteFile(FProxyStateFile);
  NotifyProxyChanged;
  FSystemProxyActive := False;
end;

procedure TNetworkIntegrationManager.RecoverStaleState;
begin
  if FileExists(FProxyStateFile) then
    RestoreSystemProxy;
end;

function TNetworkIntegrationManager.BuildConfig(SystemProxyEnabled, TunEnabled: Boolean;
  const TorHost: string; TorPort: Word): string;
var
  Inbounds, DnsPart, RouteRules, LogPath: string;
  JsonPath: TJSONString;
begin
  JsonPath := TJSONString.Create(FRuntimeLogFile);
  try LogPath := JsonPath.ToJSON finally JsonPath.Free end;
  Inbounds := '';
  if SystemProxyEnabled then
    Inbounds :=
      '{"type":"mixed","tag":"mixed-in","listen":"127.0.0.1","listen_port":' +
      IntToStr(MIXED_PROXY_PORT) + '}';

  if TunEnabled then
  begin
    if Inbounds <> '' then
      Inbounds := Inbounds + ',';
    Inbounds := Inbounds +
      '{"type":"tun","tag":"tun-in","interface_name":"' + FTunInterfaceName + '",' +
      // More-specific routes win over a VPN default route regardless of metric.
      // sing-box owns these routes and removes them when the TUN closes.
      '"address":["172.19.0.1/30"],"auto_route":true,' +
      '"route_address":["0.0.0.0/1","128.0.0.0/1"],' +
      '"strict_route":true,"dns_mode":"hijack"}';

    DnsPart :=
      '"dns":{"servers":[{"type":"tls","tag":"tor-dns","server":"8.8.8.8",' +
      '"detour":"tor","tls":{"enabled":true,"server_name":"dns.google"}}],' +
      '"strategy":"ipv4_only"},';

    RouteRules :=
      '{"action":"sniff"},' +
      '{"protocol":"dns","action":"hijack-dns"},' +
      '{"process_name":["tor.exe","TorControlPanel.exe","sing-box.exe"],"outbound":"direct"},' +
      '{"ip_is_private":true,"outbound":"direct"},' +
      '{"network":"udp","action":"reject"}';
  end
  else
  begin
    DnsPart := '';
    RouteRules := '';
  end;

  Result :=
    '{' +
      '"log":{"level":"warn","timestamp":true,"output":' + LogPath + '},' +
      DnsPart +
      '"inbounds":[' + Inbounds + '],' +
      '"outbounds":[' +
        '{"type":"socks","tag":"tor","server":"' + TorHost + '","server_port":' +
          IntToStr(TorPort) + ',"version":"5","network":"tcp"},' +
        '{"type":"direct","tag":"direct"}' +
      '],' +
      '"route":{' +
        '"rules":[' + RouteRules + '],' +
        '"final":"tor","auto_detect_interface":true' +
      '}' +
    '}';
end;

function TNetworkIntegrationManager.IsEngineRunning: Boolean;
begin
  Result := (FProcess.ProcessID <> 0) and ProcessExists(FProcess, False, False);
end;

function TNetworkIntegrationManager.StartEngine(NeedElevation: Boolean; out ErrorText: string): Boolean;
var
  CmdLine, Params: string;
  Sei: TShellExecuteInfo;
  WaitResult, ExitCode: DWORD;
  Deadline: UInt64;
  StopError: string;
begin
  Result := False;
  ErrorText := '';

  if not FileExists(FEngineExe) then
  begin
    ErrorText := 'sing-box.exe is not installed in optional\sing-box: ' + FEngineExe;
    AppendLog(ErrorText);
    Exit;
  end;

  if NeedElevation then
  begin
    FillChar(Sei, SizeOf(Sei), 0);
    Sei.cbSize := SizeOf(Sei);
    Sei.fMask := SEE_MASK_NOCLOSEPROCESS;
    Sei.Wnd := 0;
    Sei.lpVerb := 'runas';
    Sei.lpFile := PChar(FEngineExe);
    Params := 'run -c "' + FConfigFile + '"';
    Sei.lpParameters := PChar(Params);
    Sei.lpDirectory := PChar(ExtractFilePath(FEngineExe));
    Sei.nShow := SW_HIDE;
    if not ShellExecuteEx(@Sei) then
    begin
      ErrorText := SysErrorMessage(GetLastError);
      Exit;
    end;
    FProcess.hProcess := Sei.hProcess;
    FProcess.ProcessID := GetProcessId(Sei.hProcess);
    FProcess.hStdOutput := INVALID_HANDLE_VALUE;
  end
  else
  begin
    CmdLine := '"' + FEngineExe + '" run -c "' + FConfigFile + '"';
    FProcess := ExecuteProcess(CmdLine, [pfHideWindow], FJobHandle);
    if FProcess.hProcess = INVALID_HANDLE_VALUE then
    begin
      ErrorText := 'Unable to start sing-box: ' + CmdLine + '. LastError=' + SysErrorMessage(GetLastError);
      AppendLog(ErrorText);
      Exit;
    end;
  end;

  Deadline := GetTickCount64 + 20000;
  WaitResult := WaitForSingleObject(FProcess.hProcess, 700);
  if NeedElevation then
  begin
    while (WaitResult = WAIT_TIMEOUT) and not TunRoutesReady do
    begin
      if GetTickCount64 >= Deadline then
      begin
        ErrorText := 'TUN interface/routes were not ready within 20 seconds. See ' + FRuntimeLogFile;
        AppendLog(ErrorText);
        StopEngine(StopError);
        Exit;
      end;
      WaitResult := WaitForSingleObject(FProcess.hProcess, 100);
    end;
  end;
  if WaitResult <> WAIT_TIMEOUT then
  begin
    ExitCode := 0;
    GetExitCodeProcess(FProcess.hProcess, ExitCode);
    ErrorText := 'sing-box stopped during startup (exit ' + IntToStr(ExitCode) + '). See ' + FRuntimeLogFile;
    AppendLog(ErrorText);
    CloseHandle(FProcess.hProcess);
    FProcess := cDefaultProcessInfo;
    Exit;
  end;

  AppendLog('run: started pid=' + IntToStr(FProcess.ProcessID));
  Result := True;
end;

function TNetworkIntegrationManager.StopEngine(out ErrorText: string): Boolean;
var
  H: THandle;
begin
  Result := True;
  ErrorText := '';
  if FProcess.ProcessID = 0 then
    Exit;

  H := OpenProcess(PROCESS_TERMINATE or SYNCHRONIZE, False, FProcess.ProcessID);
  if H = 0 then
  begin
    if IsEngineRunning then
    begin
      ErrorText := 'Unable to stop sing-box process';
      Exit(False);
    end;
  end
  else
  begin
    try
      if not TerminateProcess(H, 0) then
      begin
        ErrorText := SysErrorMessage(GetLastError);
        Exit(False);
      end;
      WaitForSingleObject(H, 3000);
    finally
      CloseHandle(H);
    end;
  end;

  if FProcess.hProcess <> INVALID_HANDLE_VALUE then
    CloseHandle(FProcess.hProcess);
  FProcess := cDefaultProcessInfo;
  FTunActive := False;
  FAppliedConfig := '';
end;

function TNetworkIntegrationManager.Apply(SystemProxyEnabled, TunEnabled: Boolean;
  const TorHost: string; TorPort: Word; AllowElevation: Boolean; out ErrorText: string): Boolean;
var
  Config: string;
  EncodingNoBom: TUTF8Encoding;
  EngineNeeded: Boolean;
begin
  Result := False;
  ErrorText := '';
  EngineNeeded := SystemProxyEnabled or TunEnabled;
  Config := BuildConfig(SystemProxyEnabled, TunEnabled, TorHost, TorPort);

  // Reapply is a no-op only when both the runtime and applied configuration match.
  if EngineNeeded and IsEngineRunning and (FAppliedConfig = Config) and
    (FTunActive = TunEnabled) and (FSystemProxyActive = SystemProxyEnabled) then
  begin
    AppendLog('apply: unchanged; keeping running pid=' + IntToStr(FProcess.ProcessID));
    Exit(True);
  end;

  // Authorization precedes all mutation, including stopping a healthy engine.
  if TunEnabled and not AllowElevation then
  begin
    ErrorText := 'TUN requires explicit user confirmation. Click TUN (LAN) to re-enable it.';
    AppendLog('blocked automatic TUN elevation request; existing engine preserved');
    Exit;
  end;

  try
    if FSystemProxyActive and not SystemProxyEnabled then
      RestoreSystemProxy;

    if IsEngineRunning then
      if not StopEngine(ErrorText) then
        Exit;

    if not EngineNeeded then
    begin
      FSystemProxyActive := False;
      FTunActive := False;
      Exit(True);
    end;

    if TunEnabled then RenewTunInterfaceName;
    Config := BuildConfig(SystemProxyEnabled, TunEnabled, TorHost, TorPort);
    EncodingNoBom := TUTF8Encoding.Create(False);
    try
      TFile.WriteAllText(FConfigFile, Config, EncodingNoBom);
    finally
      EncodingNoBom.Free;
    end;
    AppendLog('config written: system_proxy=' + BoolToStr(SystemProxyEnabled, True) +
      ', tun=' + BoolToStr(TunEnabled, True) + ', tor=' + TorHost + ':' + IntToStr(TorPort));
    if not RunConfigCheck(ErrorText) then
      Exit;



    if not StartEngine(TunEnabled, ErrorText) then
      Exit;

    FAppliedConfig := Config;
    FTunActive := TunEnabled;
    if SystemProxyEnabled then
      ApplySystemProxy
    else
      FSystemProxyActive := False;

    Result := True;
  except
    on E: Exception do
    begin
      ErrorText := E.Message;
      try
        if FSystemProxyActive or FileExists(FProxyStateFile) then
          RestoreSystemProxy;
      except
      end;
      StopEngine(ErrorText);
    end;
  end;
end;

procedure TNetworkIntegrationManager.Shutdown;
var
  ErrorText: string;
begin
  try
    if FSystemProxyActive or FileExists(FProxyStateFile) then
      RestoreSystemProxy;
  except
  end;
  StopEngine(ErrorText);
end;

end.

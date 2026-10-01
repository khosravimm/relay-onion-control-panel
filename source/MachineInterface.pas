unit MachineInterface;

interface

uses
  System.SysUtils,
  System.IniFiles,
  System.Hash,
  System.DateUtils,
  System.Classes,
  System.SyncObjs,
  System.StrUtils,
  synsock,
  blcksock;

const
  TCP_MACHINE_SECTION = 'MachineInterface';
  TCP_API_SECTION = 'Api';
  TCP_MCP_SECTION = 'Mcp';
  TCP_DEFAULT_API_BIND = '127.0.0.1';
  TCP_DEFAULT_API_PORT = 19090;
  TCP_DEFAULT_MCP_BIND = '127.0.0.1';
  TCP_DEFAULT_MCP_PORT = 19091;

type
  TTcpMachineSettings = class
  public
    Enabled: Boolean;
    ControlMode: Boolean;
    RequireApprovalForControl: Boolean;
    EvidenceEnabled: Boolean;

    ApiEnabled: Boolean;
    ApiAllowRemote: Boolean;
    ApiBindAddress: string;
    ApiPort: Word;
    ApiAllowLoopbackWithoutKey: Boolean;
    ApiKeyHash: string;
    ApiKeyId: string;
    ApiKeyCreatedAt: string;

    McpEnabled: Boolean;
    McpAllowRemote: Boolean;
    McpStdioEnabled: Boolean;
    McpHttpEnabled: Boolean;
    McpBindAddress: string;
    McpPort: Word;

    constructor Create;
    procedure SetDefaults;
    procedure Load(Ini: TMemIniFile);
    procedure Save(Ini: TMemIniFile);
    function Validate(out ErrorText: string): Boolean;
  end;

  TTcpApiKeyMaterial = record
    KeyId: string;
    PlainText: string;
    Hash: string;
    CreatedAt: string;
  end;

  TTcpApiKeyPolicy = class
  private
    class function ConstantTimeEquals(const A, B: string): Boolean; static;
    class function CompactGuid: string; static;
  public
    class function IsLoopbackAddress(const Address: string): Boolean; static;
    class function RequiresKey(const PeerAddress: string; Settings: TTcpMachineSettings): Boolean; static;
    class function HashKey(const PlainText: string): string; static;
    class function ValidateKey(const PlainText, ExpectedHash: string): Boolean; static;
    class function GenerateKey: TTcpApiKeyMaterial; static;
    class function IsAuthorized(const PeerAddress, PresentedKey: string; Settings: TTcpMachineSettings): Boolean; static;
  end;

  TTcpMachineStatus = record
    ProgramVersion: string;
    TorVersion: string;
    ConnectState: Integer;
    BootstrapPercent: Integer;
  end;

  TTcpMachineService = class
  private
    FSettings: TTcpMachineSettings;
    FStatus: TTcpMachineStatus;
    FStatusLock: TCriticalSection;
  public
    constructor Create(ASettings: TTcpMachineSettings);
    destructor Destroy; override;
    procedure UpdateStatus(const AProgramVersion, ATorVersion: string; AConnectState, ABootstrapPercent: Integer);
    function GetStatus: TTcpMachineStatus;
    function IsRequestAuthorized(const PeerAddress, PresentedKey: string): Boolean;
    property Settings: TTcpMachineSettings read FSettings;
  end;

  TTcpRestServer = class(TThread)
  private
    FService: TTcpMachineService;
    FSettings: TTcpMachineSettings;
    FListener: TTCPBlockSocket;
    FReadyEvent: TEvent;
    FRunning: Boolean;
    FStartError: string;
    FThreadStarted: Boolean;
    procedure ProcessClient(ASocket: TSocket);
    function HeaderValue(Headers: TStrings; const Name: string): string;
    function ExtractPresentedKey(Headers: TStrings): string;
    function BuildJsonResponse(const PeerAddress, Method, Path: string; Headers: TStrings;
      out StatusCode: Integer; out Reason: string): string;
    procedure SendHttpResponse(Client: TTCPBlockSocket; StatusCode: Integer;
      const Reason, Body: string; const ExtraHeaders: string = '');
    class function JsonEscape(const S: string): string; static;
  protected
    procedure Execute; override;
  public
    constructor Create(AService: TTcpMachineService; ASettings: TTcpMachineSettings);
    destructor Destroy; override;
    function StartAndWait(out ErrorText: string; TimeoutMs: Cardinal = 3000): Boolean;
    procedure StopAndWait;
    property Running: Boolean read FRunning;
    property StartError: string read FStartError;
  end;
implementation

function ClampPort(Value, DefaultValue: Integer): Word;
begin
  if (Value < 1) or (Value > 65535) then
    Result := DefaultValue
  else
    Result := Value;
end;

{ TTcpMachineSettings }

constructor TTcpMachineSettings.Create;
begin
  inherited Create;
  SetDefaults;
end;

procedure TTcpMachineSettings.SetDefaults;
begin
  Enabled := False;
  ControlMode := False;
  RequireApprovalForControl := True;
  EvidenceEnabled := True;

  ApiEnabled := False;
  ApiAllowRemote := False;
  ApiBindAddress := TCP_DEFAULT_API_BIND;
  ApiPort := TCP_DEFAULT_API_PORT;
  ApiAllowLoopbackWithoutKey := True;
  ApiKeyHash := '';
  ApiKeyId := '';
  ApiKeyCreatedAt := '';

  McpEnabled := False;
  McpAllowRemote := False;
  McpStdioEnabled := True;
  McpHttpEnabled := False;
  McpBindAddress := TCP_DEFAULT_MCP_BIND;
  McpPort := TCP_DEFAULT_MCP_PORT;
end;

procedure TTcpMachineSettings.Load(Ini: TMemIniFile);
begin
  SetDefaults;
  if not Assigned(Ini) then
    Exit;

  Enabled := Ini.ReadBool(TCP_MACHINE_SECTION, 'Enabled', Enabled);
  ControlMode := SameText(Ini.ReadString(TCP_MACHINE_SECTION, 'Mode', 'ReadOnly'), 'Control');
  RequireApprovalForControl := Ini.ReadBool(TCP_MACHINE_SECTION, 'RequireApprovalForControl',
    Ini.ReadBool(TCP_MCP_SECTION, 'RequireApproval', RequireApprovalForControl));
  EvidenceEnabled := Ini.ReadBool(TCP_MACHINE_SECTION, 'EvidenceEnabled',
    Ini.ReadBool('Evidence', 'Enabled', EvidenceEnabled));

  ApiEnabled := Ini.ReadBool(TCP_API_SECTION, 'Enabled', ApiEnabled);
  ApiAllowRemote := Ini.ReadBool(TCP_API_SECTION, 'AllowRemote', ApiAllowRemote);
  ApiBindAddress := Trim(Ini.ReadString(TCP_API_SECTION, 'BindAddress', ApiBindAddress));
  ApiPort := ClampPort(Ini.ReadInteger(TCP_API_SECTION, 'Port', ApiPort), TCP_DEFAULT_API_PORT);
  ApiAllowLoopbackWithoutKey := not Ini.ReadBool(TCP_API_SECTION, 'RequireKeyForLoopback',
    not ApiAllowLoopbackWithoutKey);
  ApiKeyHash := LowerCase(Trim(Ini.ReadString(TCP_API_SECTION, 'KeyHash', '')));
  ApiKeyId := Trim(Ini.ReadString(TCP_API_SECTION, 'KeyId', ''));
  ApiKeyCreatedAt := Trim(Ini.ReadString(TCP_API_SECTION, 'KeyCreatedAt', ''));

  McpEnabled := Ini.ReadBool(TCP_MCP_SECTION, 'Enabled', McpEnabled);
  McpAllowRemote := Ini.ReadBool(TCP_MCP_SECTION, 'AllowRemote', McpAllowRemote);
  McpStdioEnabled := Ini.ReadBool(TCP_MCP_SECTION, 'StdioEnabled',
    SameText(Ini.ReadString(TCP_MCP_SECTION, 'Transport', 'stdio'), 'stdio'));
  McpHttpEnabled := Ini.ReadBool(TCP_MCP_SECTION, 'HttpEnabled', McpHttpEnabled);
  McpBindAddress := Trim(Ini.ReadString(TCP_MCP_SECTION, 'HttpBindAddress', McpBindAddress));
  McpPort := ClampPort(Ini.ReadInteger(TCP_MCP_SECTION, 'HttpPort', McpPort), TCP_DEFAULT_MCP_PORT);
end;

procedure TTcpMachineSettings.Save(Ini: TMemIniFile);
begin
  if not Assigned(Ini) then
    Exit;

  Ini.WriteBool(TCP_MACHINE_SECTION, 'Enabled', Enabled);
  if ControlMode then
    Ini.WriteString(TCP_MACHINE_SECTION, 'Mode', 'Control')
  else
    Ini.WriteString(TCP_MACHINE_SECTION, 'Mode', 'ReadOnly');
  Ini.WriteBool(TCP_MACHINE_SECTION, 'RequireApprovalForControl', RequireApprovalForControl);
  Ini.WriteBool(TCP_MACHINE_SECTION, 'EvidenceEnabled', EvidenceEnabled);

  Ini.WriteBool(TCP_API_SECTION, 'Enabled', ApiEnabled);
  Ini.WriteBool(TCP_API_SECTION, 'AllowRemote', ApiAllowRemote);
  Ini.WriteString(TCP_API_SECTION, 'BindAddress', ApiBindAddress);
  Ini.WriteInteger(TCP_API_SECTION, 'Port', ApiPort);
  Ini.WriteBool(TCP_API_SECTION, 'RequireKeyForLoopback', not ApiAllowLoopbackWithoutKey);
  Ini.WriteBool(TCP_API_SECTION, 'RequireKeyForRemote', True);
  Ini.WriteString(TCP_API_SECTION, 'KeyHash', ApiKeyHash);
  Ini.WriteString(TCP_API_SECTION, 'KeyId', ApiKeyId);
  Ini.WriteString(TCP_API_SECTION, 'KeyCreatedAt', ApiKeyCreatedAt);
  Ini.DeleteKey(TCP_API_SECTION, 'Key');
  Ini.DeleteKey(TCP_API_SECTION, 'ApiKey');
  Ini.DeleteKey(TCP_API_SECTION, 'PlainTextKey');

  Ini.WriteBool(TCP_MCP_SECTION, 'Enabled', McpEnabled);
  Ini.WriteBool(TCP_MCP_SECTION, 'AllowRemote', McpAllowRemote);
  Ini.WriteBool(TCP_MCP_SECTION, 'StdioEnabled', McpStdioEnabled);
  if McpStdioEnabled then
    Ini.WriteString(TCP_MCP_SECTION, 'Transport', 'stdio')
  else
    Ini.WriteString(TCP_MCP_SECTION, 'Transport', 'http');
  Ini.WriteBool(TCP_MCP_SECTION, 'HttpEnabled', McpHttpEnabled);
  Ini.WriteString(TCP_MCP_SECTION, 'HttpBindAddress', McpBindAddress);
  Ini.WriteInteger(TCP_MCP_SECTION, 'HttpPort', McpPort);
  Ini.WriteBool(TCP_MCP_SECTION, 'RequireKeyForLoopback', not ApiAllowLoopbackWithoutKey);
  Ini.WriteBool(TCP_MCP_SECTION, 'RequireKeyForRemote', True);
  Ini.WriteBool(TCP_MCP_SECTION, 'RequireApproval', RequireApprovalForControl);

  Ini.WriteBool('Evidence', 'Enabled', EvidenceEnabled);
end;

function TTcpMachineSettings.Validate(out ErrorText: string): Boolean;
begin
  ErrorText := '';

  if ApiBindAddress = '' then
  begin
    ErrorText := 'API bind address cannot be empty.';
    Exit(False);
  end;

  if McpBindAddress = '' then
  begin
    ErrorText := 'MCP bind address cannot be empty.';
    Exit(False);
  end;

  if ApiEnabled and (not TTcpApiKeyPolicy.IsLoopbackAddress(ApiBindAddress)) then
  begin
    if not ApiAllowRemote then
    begin
      ErrorText := 'Non-loopback API bind requires AllowRemote.';
      Exit(False);
    end;
    if ApiKeyHash = '' then
    begin
      ErrorText := 'Non-loopback API access requires an API key.';
      Exit(False);
    end;
  end;

  if McpEnabled and McpHttpEnabled and (not TTcpApiKeyPolicy.IsLoopbackAddress(McpBindAddress)) then
  begin
    if not McpAllowRemote then
    begin
      ErrorText := 'Non-loopback MCP HTTP bind requires AllowRemote.';
      Exit(False);
    end;
    if ApiKeyHash = '' then
    begin
      ErrorText := 'Non-loopback MCP HTTP access requires an API key.';
      Exit(False);
    end;
  end;

  Result := True;
end;

{ TTcpApiKeyPolicy }

class function TTcpApiKeyPolicy.CompactGuid: string;
var
  G: TGUID;
begin
  CreateGUID(G);
  Result := GUIDToString(G);
  Result := StringReplace(Result, '{', '', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '', [rfReplaceAll]);
  Result := StringReplace(Result, '-', '', [rfReplaceAll]);
  Result := LowerCase(Result);
end;

class function TTcpApiKeyPolicy.ConstantTimeEquals(const A, B: string): Boolean;
var
  I, Diff: Integer;
begin
  if Length(A) <> Length(B) then
    Exit(False);
  Diff := 0;
  for I := 1 to Length(A) do
    Diff := Diff or (Ord(A[I]) xor Ord(B[I]));
  Result := Diff = 0;
end;

class function TTcpApiKeyPolicy.IsLoopbackAddress(const Address: string): Boolean;
var
  S: string;
begin
  S := LowerCase(Trim(Address));
  Result := (S = 'localhost') or (S = '::1') or (S = '[::1]') or
    (S = '127.0.0.1') or S.StartsWith('127.');
end;

class function TTcpApiKeyPolicy.RequiresKey(const PeerAddress: string; Settings: TTcpMachineSettings): Boolean;
begin
  if not Assigned(Settings) then
    Exit(True);
  if Trim(PeerAddress) = '' then
    Exit(True);
  if IsLoopbackAddress(PeerAddress) then
    Result := not Settings.ApiAllowLoopbackWithoutKey
  else
    Result := True;
end;

class function TTcpApiKeyPolicy.HashKey(const PlainText: string): string;
begin
  Result := LowerCase(THashSHA2.GetHashString(PlainText));
end;

class function TTcpApiKeyPolicy.ValidateKey(const PlainText, ExpectedHash: string): Boolean;
var
  Actual: string;
begin
  if (PlainText = '') or (ExpectedHash = '') then
    Exit(False);
  Actual := HashKey(PlainText);
  Result := ConstantTimeEquals(Actual, LowerCase(ExpectedHash));
end;

class function TTcpApiKeyPolicy.GenerateKey: TTcpApiKeyMaterial;
var
  RawId: string;
begin
  RawId := CompactGuid;
  Result.KeyId := Copy(RawId, 1, 12);
  Result.PlainText := 'tcp_' + RawId + CompactGuid;
  Result.Hash := HashKey(Result.PlainText);
  Result.CreatedAt := DateToISO8601(Now, False);
end;

class function TTcpApiKeyPolicy.IsAuthorized(const PeerAddress, PresentedKey: string;
  Settings: TTcpMachineSettings): Boolean;
begin
  if not RequiresKey(PeerAddress, Settings) then
    Exit(True);
  if not Assigned(Settings) then
    Exit(False);
  Result := ValidateKey(PresentedKey, Settings.ApiKeyHash);
end;

{ TTcpMachineService }

constructor TTcpMachineService.Create(ASettings: TTcpMachineSettings);
begin
  inherited Create;
  FSettings := ASettings;
  FStatusLock := TCriticalSection.Create;
  FStatus.ProgramVersion := '';
  FStatus.TorVersion := '';
  FStatus.ConnectState := 0;
  FStatus.BootstrapPercent := 0;
end;

destructor TTcpMachineService.Destroy;
begin
  FreeAndNil(FStatusLock);
  inherited Destroy;
end;

procedure TTcpMachineService.UpdateStatus(const AProgramVersion, ATorVersion: string;
  AConnectState, ABootstrapPercent: Integer);
begin
  FStatusLock.Acquire;
  try
    FStatus.ProgramVersion := AProgramVersion;
    FStatus.TorVersion := ATorVersion;
    FStatus.ConnectState := AConnectState;
    if ABootstrapPercent < 0 then
      FStatus.BootstrapPercent := 0
    else if ABootstrapPercent > 100 then
      FStatus.BootstrapPercent := 100
    else
      FStatus.BootstrapPercent := ABootstrapPercent;
  finally
    FStatusLock.Release;
  end;
end;

function TTcpMachineService.GetStatus: TTcpMachineStatus;
begin
  FStatusLock.Acquire;
  try
    Result := FStatus;
  finally
    FStatusLock.Release;
  end;
end;

function TTcpMachineService.IsRequestAuthorized(const PeerAddress, PresentedKey: string): Boolean;
begin
  Result := TTcpApiKeyPolicy.IsAuthorized(PeerAddress, PresentedKey, FSettings);
end;

{ TTcpRestServer }

constructor TTcpRestServer.Create(AService: TTcpMachineService; ASettings: TTcpMachineSettings);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FService := AService;
  FSettings := ASettings;
  FListener := nil;
  FReadyEvent := TEvent.Create(nil, True, False, '');
  FRunning := False;
  FStartError := '';
  FThreadStarted := False;
end;

destructor TTcpRestServer.Destroy;
begin
  StopAndWait;
  FreeAndNil(FReadyEvent);
  inherited Destroy;
end;

class function TTcpRestServer.JsonEscape(const S: string): string;
begin
  Result := StringReplace(S, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #9, '\t', [rfReplaceAll]);
end;

function TTcpRestServer.HeaderValue(Headers: TStrings; const Name: string): string;
var
  I, P: Integer;
  Line, HeaderName: string;
begin
  Result := '';
  for I := 0 to Headers.Count - 1 do
  begin
    Line := Headers[I];
    P := Pos(':', Line);
    if P <= 1 then
      Continue;
    HeaderName := Trim(Copy(Line, 1, P - 1));
    if SameText(HeaderName, Name) then
      Exit(Trim(Copy(Line, P + 1, MaxInt)));
  end;
end;

function TTcpRestServer.ExtractPresentedKey(Headers: TStrings): string;
var
  Value: string;
begin
  Value := HeaderValue(Headers, 'Authorization');
  if StartsText('Bearer ', Value) then
    Exit(Trim(Copy(Value, 8, MaxInt)));
  Result := HeaderValue(Headers, 'X-TCP-API-Key');
end;

function TTcpRestServer.BuildJsonResponse(const PeerAddress, Method, Path: string;
  Headers: TStrings; out StatusCode: Integer; out Reason: string): string;
var
  S: TTcpMachineStatus;
  RequestPath, PresentedKey: string;
  Q: Integer;
  TorReady: string;
begin
  PresentedKey := ExtractPresentedKey(Headers);
  if not FService.IsRequestAuthorized(PeerAddress, PresentedKey) then
  begin
    StatusCode := 401;
    Reason := 'Unauthorized';
    Exit('{"error":"unauthorized"}');
  end;

  if not SameText(Method, 'GET') then
  begin
    StatusCode := 405;
    Reason := 'Method Not Allowed';
    Exit('{"error":"method_not_allowed","allowed":["GET"]}');
  end;

  RequestPath := Path;
  Q := Pos('?', RequestPath);
  if Q > 0 then
    Delete(RequestPath, Q, MaxInt);

  S := FService.GetStatus;
  if SameText(RequestPath, '/api/v1/version') then
  begin
    StatusCode := 200;
    Reason := 'OK';
    Exit('{"product":"Relay Onion Control Panel","version":"' + JsonEscape(S.ProgramVersion) + '"}');
  end;

  if SameText(RequestPath, '/api/v1/status') then
  begin
    StatusCode := 200;
    Reason := 'OK';
    Exit(Format('{"program_version":"%s","tor_version":"%s","connect_state":%d,"bootstrap_percent":%d}',
      [JsonEscape(S.ProgramVersion), JsonEscape(S.TorVersion), S.ConnectState, S.BootstrapPercent]));
  end;

  if SameText(RequestPath, '/api/v1/health') then
  begin
    if S.BootstrapPercent >= 100 then
      TorReady := 'true'
    else
      TorReady := 'false';
    StatusCode := 200;
    Reason := 'OK';
    Exit(Format('{"status":"ok","api":"ready","tor":{"connect_state":%d,"bootstrap_percent":%d,"ready":%s}}',
      [S.ConnectState, S.BootstrapPercent, TorReady]));
  end;

  StatusCode := 404;
  Reason := 'Not Found';
  Result := '{"error":"not_found"}';
end;

procedure TTcpRestServer.SendHttpResponse(Client: TTCPBlockSocket; StatusCode: Integer;
  const Reason, Body, ExtraHeaders: string);
var
  Header: string;
  HeaderUtf8, BodyUtf8: UTF8String;
begin
  BodyUtf8 := UTF8String(Body);
  Header := Format('HTTP/1.1 %d %s'#13#10, [StatusCode, Reason]) +
    'Content-Type: application/json; charset=utf-8'#13#10 +
    'Content-Length: ' + IntToStr(Length(BodyUtf8)) + #13#10 +
    'Connection: close'#13#10 +
    'Cache-Control: no-store'#13#10 +
    'X-Content-Type-Options: nosniff'#13#10;
  if ExtraHeaders <> '' then
    Header := Header + ExtraHeaders;
  Header := Header + #13#10;
  HeaderUtf8 := UTF8String(Header);
  Client.SendString(AnsiString(HeaderUtf8));
  Client.SendString(AnsiString(BodyUtf8));
end;

procedure TTcpRestServer.ProcessClient(ASocket: TSocket);
var
  Client: TTCPBlockSocket;
  Headers: TStringList;
  RequestLine, Line, MethodName, RequestPath, Reason, ExtraHeaders: string;
  Parts: TArray<string>;
  I, StatusCode: Integer;
  Body, PeerAddress: string;
begin
  Client := TTCPBlockSocket.Create;
  Headers := TStringList.Create;
  try
    Client.Socket := ASocket;
    Client.MaxLineLength := 8192;
    PeerAddress := Client.GetRemoteSinIP;
    RequestLine := string(Client.RecvString(3000));
    if RequestLine = '' then
    begin
      SendHttpResponse(Client, 400, 'Bad Request', '{"error":"bad_request"}');
      Exit;
    end;

    Parts := RequestLine.Split([' '], TStringSplitOptions.ExcludeEmpty);
    if Length(Parts) < 2 then
    begin
      SendHttpResponse(Client, 400, 'Bad Request', '{"error":"bad_request"}');
      Exit;
    end;
    MethodName := Parts[0];
    RequestPath := Parts[1];

    for I := 0 to 63 do
    begin
      Line := string(Client.RecvString(3000));
      if Line = '' then
        Break;
      Headers.Add(Line);
    end;

    Body := BuildJsonResponse(PeerAddress, MethodName, RequestPath, Headers, StatusCode, Reason);
    ExtraHeaders := '';
    if StatusCode = 401 then
      ExtraHeaders := 'WWW-Authenticate: Bearer realm="TorControlPanel"'#13#10
    else if StatusCode = 405 then
      ExtraHeaders := 'Allow: GET'#13#10;
    SendHttpResponse(Client, StatusCode, Reason, Body, ExtraHeaders);
  finally
    Headers.Free;
    Client.Free;
  end;
end;

procedure TTcpRestServer.Execute;
var
  AcceptedSocket: TSocket;
begin
  FListener := TTCPBlockSocket.Create;
  try
    try
      FListener.CreateSocket;
      if FListener.LastError <> 0 then
        raise Exception.Create('CreateSocket failed: ' + FListener.LastErrorDesc);
      FListener.SetLinger(True, 0);
      FListener.Bind(FSettings.ApiBindAddress, IntToStr(FSettings.ApiPort));
      if FListener.LastError <> 0 then
        raise Exception.Create('Bind failed: ' + FListener.LastErrorDesc);
      FListener.Listen;
      if FListener.LastError <> 0 then
        raise Exception.Create('Listen failed: ' + FListener.LastErrorDesc);
      FRunning := True;
      FReadyEvent.SetEvent;

      while not Terminated do
      begin
        if not FListener.CanRead(250) then
          Continue;
        if Terminated then
          Break;
        AcceptedSocket := FListener.Accept;
        if AcceptedSocket <> INVALID_SOCKET then
          ProcessClient(AcceptedSocket);
      end;
    except
      on E: Exception do
      begin
        FStartError := E.Message;
        FReadyEvent.SetEvent;
      end;
    end;
  finally
    FRunning := False;
    FReadyEvent.SetEvent;
    FreeAndNil(FListener);
  end;
end;

function TTcpRestServer.StartAndWait(out ErrorText: string; TimeoutMs: Cardinal): Boolean;
begin
  ErrorText := '';
  if FThreadStarted then
  begin
    Result := FRunning;
    if not Result then
      ErrorText := FStartError;
    Exit;
  end;
  FThreadStarted := True;
  Start;
  if FReadyEvent.WaitFor(TimeoutMs) <> wrSignaled then
  begin
    ErrorText := 'REST listener start timed out.';
    StopAndWait;
    Exit(False);
  end;
  Result := FRunning;
  if not Result then
    ErrorText := FStartError;
end;

procedure TTcpRestServer.StopAndWait;
begin
  if not FThreadStarted then
    Exit;
  Terminate;
  if Assigned(FListener) then
    FListener.CloseSocket;
  WaitFor;
  FThreadStarted := False;
end;
end.

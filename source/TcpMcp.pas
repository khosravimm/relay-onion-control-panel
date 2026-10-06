unit TcpMcp;

interface

uses
  System.SysUtils,
  System.Classes,
  MachineInterface
  {$IFDEF TCP_ENABLE_MCP_CONNECT}
  , IdSocketHandle,
  MCPConnect.MCP.Attributes,
  MCPConnect.MCP.Server,
  MCPConnect.MCP.Server.Api,
  MCPConnect.Configuration.MCP,
  MCPConnect.Transport.Indy
  {$ENDIF};

type
{$IFDEF TCP_ENABLE_MCP_CONNECT}
  TTcpMcpTools = class
  public
    [McpTool('tcp_version', 'Return Relay Onion Control Panel product and version information', 'readonly')]
    function Version: string;

    [McpTool('tcp_status', 'Return read-only Relay Onion Control Panel and Tor runtime status', 'readonly')]
    function Status: string;

    [McpTool('tcp_network', 'Return read-only Proxy/TUN network integration mode and state', 'readonly')]
    function Network: string;

    [McpTool('tcp_health', 'Return read-only Machine Interface and Tor readiness status', 'readonly')]
    function Health: string;
  end;
{$ENDIF}

  TTcpMcpHost = class(TComponent)
  private
    {$IFDEF TCP_ENABLE_MCP_CONNECT}
    FServer: TMCPIndyServer;
    {$ENDIF}
    FService: TTcpMachineService;
    FBindAddress: string;
    FPort: Word;
    FProgramVersion: string;
    FRunning: Boolean;
  public
    constructor Create(AOwner: TComponent; AService: TTcpMachineService); reintroduce;
    destructor Destroy; override;
    function Start(const ABindAddress: string; APort: Word; const AProgramVersion: string;
      out ErrorText: string): Boolean;
    procedure Stop;
    property Running: Boolean read FRunning;
    property BindAddress: string read FBindAddress;
    property Port: Word read FPort;
  end;

implementation

var
  GTcpMachineService: TTcpMachineService = nil;

function JsonEscape(const S: string): string;
begin
  Result := StringReplace(S, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #9, '\t', [rfReplaceAll]);
end;

function BoolJson(Value: Boolean): string;
begin
  if Value then
    Result := 'true'
  else
    Result := 'false';
end;

{$IFDEF TCP_ENABLE_MCP_CONNECT}
{ TTcpMcpTools }

function TTcpMcpTools.Version: string;
var
  S: TTcpMachineStatus;
begin
  if not Assigned(GTcpMachineService) then
    Exit('{"error":"service_unavailable"}');
  S := GTcpMachineService.GetStatus;
  Result := '{"product":"Relay Onion Control Panel","version":"' + JsonEscape(S.ProgramVersion) + '"}';
end;

function TTcpMcpTools.Status: string;
var
  S: TTcpMachineStatus;
begin
  if not Assigned(GTcpMachineService) then
    Exit('{"error":"service_unavailable"}');
  S := GTcpMachineService.GetStatus;
  Result := Format('{"program_version":"%s","tor_version":"%s","connect_state":%d,"bootstrap_percent":%d,"network_integration":{"mode":"%s","system_proxy":{"enabled":%s,"state":%d},"tun":{"enabled":%s,"state":%d}}}',
    [JsonEscape(S.ProgramVersion), JsonEscape(S.TorVersion), S.ConnectState, S.BootstrapPercent,
     JsonEscape(S.NetworkMode), BoolJson(S.SystemProxyEnabled), S.SystemProxyState,
     BoolJson(S.TunEnabled), S.TunState]);
end;

function TTcpMcpTools.Network: string;
var
  S: TTcpMachineStatus;
begin
  if not Assigned(GTcpMachineService) then
    Exit('{"error":"service_unavailable"}');
  S := GTcpMachineService.GetStatus;
  Result := Format('{"mode":"%s","system_proxy":{"enabled":%s,"state":%d},"tun":{"enabled":%s,"state":%d}}',
    [JsonEscape(S.NetworkMode), BoolJson(S.SystemProxyEnabled), S.SystemProxyState,
     BoolJson(S.TunEnabled), S.TunState]);
end;

function TTcpMcpTools.Health: string;
var
  S: TTcpMachineStatus;
  ReadyText: string;
begin
  if not Assigned(GTcpMachineService) then
    Exit('{"error":"service_unavailable"}');
  S := GTcpMachineService.GetStatus;
  if S.BootstrapPercent >= 100 then
    ReadyText := 'true'
  else
    ReadyText := 'false';
  Result := Format('{"status":"ok","mcp":"ready","tor":{"connect_state":%d,"bootstrap_percent":%d,"ready":%s},"network_integration":{"mode":"%s","system_proxy":{"enabled":%s,"state":%d},"tun":{"enabled":%s,"state":%d}}}',
    [S.ConnectState, S.BootstrapPercent, ReadyText, JsonEscape(S.NetworkMode),
     BoolJson(S.SystemProxyEnabled), S.SystemProxyState, BoolJson(S.TunEnabled), S.TunState]);
end;
{$ENDIF}

{ TTcpMcpHost }

constructor TTcpMcpHost.Create(AOwner: TComponent; AService: TTcpMachineService);
begin
  inherited Create(AOwner);
  FService := AService;
  {$IFDEF TCP_ENABLE_MCP_CONNECT}
  FServer := nil;
  {$ENDIF}
  FBindAddress := '';
  FPort := 0;
  FProgramVersion := '';
  FRunning := False;
end;

destructor TTcpMcpHost.Destroy;
begin
  Stop;
  inherited Destroy;
end;

function TTcpMcpHost.Start(const ABindAddress: string; APort: Word;
  const AProgramVersion: string; out ErrorText: string): Boolean;
{$IFDEF TCP_ENABLE_MCP_CONNECT}
var
  Binding: TIdSocketHandle;
{$ENDIF}
begin
  ErrorText := '';
  Stop;

  if not Assigned(FService) then
  begin
    ErrorText := 'Shared Machine Interface service is not available.';
    Exit(False);
  end;

  if not TTcpApiKeyPolicy.IsLoopbackAddress(ABindAddress) then
  begin
    ErrorText := 'Remote MCP HTTP binding is not enabled in this local read-only MCP stage.';
    Exit(False);
  end;

  {$IFNDEF TCP_ENABLE_MCP_CONNECT}
  ErrorText := 'MCP HTTP support was not compiled because MCPConnect is not available in this build environment.';
  Result := False;
  Exit;
  {$ENDIF}

  {$IFDEF TCP_ENABLE_MCP_CONNECT}
  try
    GTcpMachineService := FService;
    FBindAddress := ABindAddress;
    FPort := APort;
    FProgramVersion := AProgramVersion;

    FServer := TMCPIndyServer.CreateMCPServer(Self);
    FServer.MCPServer
      .Plugin.Configure<IMCPConfig>
        .Server
          .SetName('tor-control-panel')
          .SetVersion(FProgramVersion)
        .BackToMCP
        .Security
          .SetCORS(False)
          .SetAllowedMethods(['POST'])
        .BackToMCP
        .Tools
          .RegisterClass(TTcpMcpTools)
        .BackToMCP
      .BackToApp;

    FServer.Active := False;
    FServer.Bindings.Clear;
    Binding := FServer.Bindings.Add;
    Binding.IP := FBindAddress;
    Binding.Port := FPort;
    FServer.DefaultPort := FPort;
    FServer.Active := True;
    FRunning := FServer.Active;
    Result := FRunning;
    if not Result then
      ErrorText := 'MCP listener did not become active.';
  except
    on E: Exception do
    begin
      ErrorText := E.Message;
      Stop;
      Result := False;
    end;
  end;
  {$ENDIF}
end;

procedure TTcpMcpHost.Stop;
begin
  FRunning := False;
  {$IFDEF TCP_ENABLE_MCP_CONNECT}
  if Assigned(FServer) then
  begin
    try
      FServer.Active := False;
    except
      // Continue deterministic cleanup even if Indy reports a socket shutdown error.
    end;
    FreeAndNil(FServer);
  end;
  {$ENDIF}
  if GTcpMachineService = FService then
    GTcpMachineService := nil;
end;

end.

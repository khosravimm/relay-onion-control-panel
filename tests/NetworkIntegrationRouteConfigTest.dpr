program NetworkIntegrationRouteConfigTest;
{$APPTYPE CONSOLE}
uses System.SysUtils, System.IOUtils, System.JSON, NetworkIntegration;
type
  TConfigManager = class(TNetworkIntegrationManager)
  public
    function Config(Proxy, Tun: Boolean): string;
  end;
function TConfigManager.Config(Proxy, Tun: Boolean): string;
begin Result := BuildConfig(Proxy, Tun, '127.0.0.1', 9050) end;
procedure Check(Ok: Boolean; const Msg: string);
begin if not Ok then raise Exception.Create(Msg); Writeln('PASS: ', Msg) end;
var M: TConfigManager; J, Inbound, Route, Tor: TJSONObject;
  Inbounds, Routes, Outbounds: TJSONArray; Dir, S: string; Proxy, Tun: Boolean;
begin
  try
    if ParamCount <> 1 then raise Exception.Create('Supply fixture output directory');
    Dir := TPath.GetFullPath(ParamStr(1)); ForceDirectories(Dir);
    M := TConfigManager.Create(Dir, Dir, 0);
    try
      for Proxy := False to True do
        for Tun := False to True do
        begin
          S := M.Config(Proxy, Tun);
          J := TJSONObject.ParseJSONValue(S) as TJSONObject;
          Check(J <> nil, 'configuration parses as JSON');
          try
            Inbounds := J.GetValue<TJSONArray>('inbounds');
            Check(Inbounds.Count = Ord(Proxy) + Ord(Tun), 'mode selects expected inbounds');
            Route := J.GetValue<TJSONObject>('route');
            Check(Route.GetValue<Boolean>('auto_detect_interface'), 'upstream interface detection enabled');
            Check(Route.GetValue<string>('final') = 'tor', 'ordinary traffic uses Tor');
            Outbounds := J.GetValue<TJSONArray>('outbounds');
            Tor := Outbounds.Items[0] as TJSONObject;
            Check((Tor.GetValue<string>('server') = '127.0.0.1') and
              (Tor.GetValue<Integer>('server_port') = 9050), 'Tor SOCKS remains local');
            if Tun then
            begin
              Inbound := Inbounds.Items[Inbounds.Count - 1] as TJSONObject;
              Routes := Inbound.GetValue<TJSONArray>('route_address');
              Check((Routes.Count = 2) and (Routes.Items[0].Value = '0.0.0.0/1') and
                (Routes.Items[1].Value = '128.0.0.0/1'), 'both IPv4 halves override default routes');
              Check(Inbound.GetValue<Boolean>('auto_route'), 'engine owns route lifecycle');
            end;
            TFile.WriteAllBytes(TPath.Combine(Dir, Format('proxy%d-tun%d.json',
              [Ord(Proxy), Ord(Tun)])), TEncoding.UTF8.GetBytes(S));
          finally J.Free end;
        end;
    finally M.Free end;
  except on E: Exception do begin Writeln('FAIL: ', E.Message); Halt(1) end end;
end.
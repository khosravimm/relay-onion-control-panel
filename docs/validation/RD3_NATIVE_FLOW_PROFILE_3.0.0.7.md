# RD-3 native Flow profile convergence — 3.0.0.7

- **Canonical native profile** selected by `TorControlPanel.exe -profile=Flow`: `%APPDATA%\Tcp\Flow\settings.ini` in standard installations; portable layouts can use `Data\Flow\settings.ini`, following the main EXE's profile rules.
- The Flow button now loads `[Routers] ExitNodes` from the sibling native Flow profile `settings.ini` derived from the active profile `UserDir`; not the parallel `%LOCALAPPDATA%\RelayOnionControlPanel\FlowV3Native\Flow.ini`.
- Existing legacy selected exits are imported once from that legacy Flow.ini **only if** the native Flow profile has no ExitNodes; native selections are never overwritten by import.
- Legacy `TFlowNativeV3` successful exit writer has been changed to target the standard native `%APPDATA%\Tcp\Flow\settings.ini`; the old engine is **not used by the Flow button** and currently no HTTP 200 scan runs when that button is pressed. This conversion therefore does NOT constitute validated-Exit automatic discovery.
- Launching the app with `-profile=Flow` selects native Flow configuration at bootstrap but **does not automatically press/activate Flow mode**. This release aligns selected relay storage, not the full live mode transition or verified HTTP 200 workflow.
- Standard Delphi Win64 build completed. Live testing of mode restoration, portable profile path, and HTTP 200 with existing Tor is pending. Scope excludes Chrome and extension execution.

unit RD3ModeController;

interface

uses
  System.SysUtils;

type
  TRD3Mode = (rmOff, rmFlow, rmTun, rmProxy);
  TRD3Phase = (rpOff, rpPreparing, rpApplying, rpReady, rpRecovering, rpFailed);
  TRD3Snapshot = record
    Mode: TRD3Mode;
    Phase: TRD3Phase;
    Sequence: Cardinal;
  end;

  // Pure state machine. No network side-effects are performed here.
  // A separate adapter must verify side-effects before Commit.
  TRD3ModeController = class
  private
    FMode: TRD3Mode;
    FPhase: TRD3Phase;
    FSequence: Cardinal;
    FPending: Boolean;
    FBefore: TRD3Snapshot;
    FRequested: TRD3Mode;
  public
    constructor Create;
    function BeginTransition(Target: TRD3Mode; out Token: Cardinal;
      out Reason: string): Boolean;
    function Commit(Token: Cardinal; VerifiedMode: TRD3Mode): Boolean;
    function Rollback(Token: Cardinal): Boolean;
    function Snapshot: TRD3Snapshot;
    function RestoreAfterCrash(const LastVerified: TRD3Snapshot;
      out Reason: string): Boolean;
    property Mode: TRD3Mode read FMode;
    property Phase: TRD3Phase read FPhase;
    property Pending: Boolean read FPending;
  end;

implementation

constructor TRD3ModeController.Create;
begin
  inherited Create;
  FMode := rmOff;
  FPhase := rpOff;
  FSequence := 0;
  FPending := False;
end;

function TRD3ModeController.Snapshot: TRD3Snapshot;
begin
  Result.Mode := FMode;
  Result.Phase := FPhase;
  Result.Sequence := FSequence;
end;

function TRD3ModeController.BeginTransition(Target: TRD3Mode;
  out Token: Cardinal; out Reason: string): Boolean;
begin
  Token := 0;
  Reason := '';
  Result := False;
  if FPending then
  begin
    Reason := 'A mode transition is already pending';
    Exit;
  end;
  if (Target = FMode) and (FPhase in [rpOff, rpReady]) then
  begin
    Reason := 'Requested mode is already selected';
    Exit;
  end;
  // Never claim a requested mode is active prior to external verification.
  FBefore := Snapshot;
  Inc(FSequence);
  Token := FSequence;
  FRequested := Target;
  FPending := True;
  FPhase := rpPreparing;
  Result := True;
end;

function TRD3ModeController.Commit(Token: Cardinal;
  VerifiedMode: TRD3Mode): Boolean;
begin
  Result := FPending and (Token = FSequence) and
    (VerifiedMode = FRequested);
  if not Result then Exit;
  FMode := VerifiedMode;
  if FMode = rmOff then FPhase := rpOff
  else FPhase := rpReady;
  FPending := False;
end;

function TRD3ModeController.Rollback(Token: Cardinal): Boolean;
begin
  Result := FPending and (Token = FSequence);
  if not Result then Exit;
  FMode := FBefore.Mode;
  FPhase := FBefore.Phase;
  FPending := False;
end;

function TRD3ModeController.RestoreAfterCrash(
  const LastVerified: TRD3Snapshot; out Reason: string): Boolean;
begin
  // External environment may have changed while the process was down.
  // Fail closed: require external discovery/reconciliation first.
  FMode := rmOff;
  FPhase := rpRecovering;
  FPending := False;
  FSequence := LastVerified.Sequence;
  Reason := 'Recovery requires external mode/proxy/TUN verification';
  Result := False;
end;

end.

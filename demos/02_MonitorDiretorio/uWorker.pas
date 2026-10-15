unit uWorker;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

interface

uses
  SysUtils, Classes, SyncObjs;

type
  { TServiceWorkerThread: Thread de execucao independente e segura }
  TServiceWorkerThread = class(TThread)
  private
    FTermEvent: TEvent;
    FIntervalMs: Cardinal;
    FInboxPath: string;
    FOutboxPath: string;
    procedure ScanAndProcessDirectory;
  protected
    procedure Execute; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure TerminateWork;
    procedure UpdateInterval(const ANewIntervalMs: Cardinal);
  end;

  { TServiceWorker: Fachada de controle do modulo de trabalho }
  TServiceWorker = class
  private
    FThread: TServiceWorkerThread;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    procedure OnConfigReload;
  end;

implementation

uses
  uConfig, uServiceCore;

function IsFileLocked(const AFileName: string): Boolean;
var
  FHandle: THandle;
begin
  // Testa se o arquivo terminou de ser copiado/gravado
  FHandle := FileOpen(AFileName, fmOpenRead or fmShareExclusive);
  if FHandle = THandle(-1) then
    Result := True // Arquivo em uso ou bloqueado
  else
  begin
    FileClose(FHandle);
    Result := False;
  end;
end;

procedure TServiceWorkerThread.ScanAndProcessDirectory;
var
  Rec: TSearchRec;
  LFile, LDest: string;
begin
  if not DirectoryExists(FInboxPath) then
    ForceDirectories(FInboxPath);
  if not DirectoryExists(FOutboxPath) then
    ForceDirectories(FOutboxPath);

  if FindFirst(IncludeTrailingPathDelimiter(FInboxPath) + '*.*', faAnyFile and not faDirectory, Rec) = 0 then
  try
    repeat
      LFile := IncludeTrailingPathDelimiter(FInboxPath) + Rec.Name;
      if not IsFileLocked(LFile) then
      begin
        TServiceCore.LogMessage('INFO', '[DIR-MONITOR] Processando arquivo: ' + Rec.Name);
        LDest := IncludeTrailingPathDelimiter(FOutboxPath) + Rec.Name;
        if RenameFile(LFile, LDest) then
          TServiceCore.LogMessage('INFO', '[DIR-MONITOR] Arquivo movido para saida: ' + Rec.Name)
        else
          TServiceCore.LogMessage('WARN', '[DIR-MONITOR] Falha ao mover arquivo: ' + Rec.Name);
      end
      else
        TServiceCore.LogMessage('DEBUG', '[DIR-MONITOR] Arquivo em uso (aguardando liberacao): ' + Rec.Name);
    until FindNext(Rec) <> 0;
  finally
    FindClose(Rec);
  end;
end;

{ TServiceWorkerThread }

constructor TServiceWorkerThread.Create;
begin
  inherited Create(True); // Cria suspensa
  FreeOnTerminate := False;
  FTermEvent := TEvent.Create(nil, True, False, '');
  FIntervalMs := TAppConfig.Instance.PollingIntervalMs;
  FInboxPath := TAppConfig.Instance.MonitorInbox;
  FOutboxPath := TAppConfig.Instance.MonitorOutbox;
end;

destructor TServiceWorkerThread.Destroy;
begin
  FreeAndNil(FTermEvent);
  inherited Destroy;
end;

procedure TServiceWorkerThread.TerminateWork;
begin
  Terminate;
  if Assigned(FTermEvent) then
    FTermEvent.SetEvent; // Desperta a thread imediatamente sem aguardar sleep
end;

procedure TServiceWorkerThread.UpdateInterval(const ANewIntervalMs: Cardinal);
begin
  FIntervalMs := ANewIntervalMs;
end;

procedure TServiceWorkerThread.Execute;
begin
  TServiceCore.LogMessage('INFO', 'Thread de trabalho iniciada. Intervalo: ' + IntToStr(FIntervalMs) + ' ms');
  while not Terminated do
  begin
    try
      ScanAndProcessDirectory;
    except
      on E: Exception do
        TServiceCore.LogMessage('ERROR', '[DIR-MONITOR] Erro ao monitorar pasta: ' + E.Message);
    end;
    // Aguarda o intervalo de forma responsiva ao sinal de encerramento
    if FTermEvent.WaitFor(FIntervalMs) = wrSignaled then
      Break;
  end;
  TServiceCore.LogMessage('INFO', 'Thread de trabalho finalizada com sucesso.');
end;

{ TServiceWorker }

constructor TServiceWorker.Create;
begin
  inherited Create;
end;

destructor TServiceWorker.Destroy;
begin
  Stop;
  inherited Destroy;
end;

procedure TServiceWorker.Start;
begin
  if not Assigned(FThread) then
  begin
    FThread := TServiceWorkerThread.Create;
    FThread.Start;
  end;
end;

procedure TServiceWorker.Stop;
begin
  if Assigned(FThread) then
  begin
    FThread.TerminateWork;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
end;

procedure TServiceWorker.OnConfigReload;
begin
  if Assigned(FThread) then
    FThread.UpdateInterval(TAppConfig.Instance.PollingIntervalMs);
end;

end.

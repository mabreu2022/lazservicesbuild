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
    FQueryCount: Int64;
    FLastCheck: TDateTime;
    procedure ConnectAndProcessQueries;
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

procedure TServiceWorkerThread.ConnectAndProcessQueries;
begin
  Inc(FQueryCount);
  FLastCheck := Now;
  TServiceCore.LogMessage('DEBUG', '[DB-POOL] Verificando fila de registros no banco ' + TAppConfig.Instance.DatabaseName + ' (Ciclo #' + IntToStr(FQueryCount) + ')...');
  // Simulação de processamento de lote
  // Aqui você instancia seu TSQLQuery / Conexão (FCL-DB, ZEOS, Firebird, etc.)
  // Exemplo:
  // Query := TSQLQuery.Create(nil);
  // try
  //   Query.SQL.Text := 'SELECT * FROM FILA_PROCESSAMENTO WHERE STATUS = 0';
  //   Query.Open;
  //   ...
  // finally
  //   Query.Free;
  // end;
end;

{ TServiceWorkerThread }

constructor TServiceWorkerThread.Create;
begin
  inherited Create(True); // Cria suspensa
  FreeOnTerminate := False;
  FTermEvent := TEvent.Create(nil, True, False, '');
  FIntervalMs := TAppConfig.Instance.PollingIntervalMs;
  FQueryCount := 0;
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
      ConnectAndProcessQueries;
    except
      on E: Exception do
        TServiceCore.LogMessage('ERROR', '[DB-POOL] Erro na consulta de banco: ' + E.Message);
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

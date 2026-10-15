unit uTemplateEngine;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

interface

uses
  Classes, SysUtils, IniFiles;

type
  { Plataforma de destino }
  TTargetPlatform = (tpWindows, tpLinux, tpHybrid);

  { Arquétipo da tarefa do serviço }
  TArchetypeKind = (
    akDatabasePool,      // Consulta / Pooling de Banco de Dados
    akDirectoryMonitor,  // Monitor de Pastas com teste de arquivos bloqueados
    akHttpMicroservice,  // API / WebService / Microserviço com socket
    akTaskScheduler,     // Agendador de Tarefas / Backup em horário fixo
    akQueueWorker        // Loop Contínuo com Fila de Mensagens
  );

  { Unidade de intervalo }
  TIntervalUnit = (iuMilliseconds, iuSeconds, iuMinutes);

  { Opções completas coletadas pelo Wizard }
  TWizardConfig = class
  public
    // Etapa 1: Identificação
    ServiceName: string;        // sem espaços, ex: SyncVendasSvc
    DisplayName: string;        // legível, ex: Serviço de Sincronização de Vendas
    Description: string;        // Descrição do serviço
    TargetPlatform: TTargetPlatform;
    OutputDir: string;

    // Etapa 2: Arquétipo
    Archetype: TArchetypeKind;

    // Etapa 3: Frequência e Parâmetros
    IntervalValue: Cardinal;
    IntervalUnit: TIntervalUnit;
    UseIniConfig: Boolean;
    EnableSighupReload: Boolean;
    EnableDebugMode: Boolean;

    // Etapa 4: Infraestrutura & OS
    RestartOnFailure: Boolean;
    RestartDelaySec: Cardinal;
    LinuxUser: string;
    WaitNetwork: Boolean;
    WaitDatabase: Boolean;
    DatabaseType: string;       // 'firebird', 'postgresql', 'mysql'
    LogLocalFile: Boolean;
    LogSystemdJournal: Boolean;
    LogWindowsEventLog: Boolean;
    EnableHeapTrc: Boolean;

    constructor Create;
    function GetIntervalMs: Cardinal;
    function GetArchetypeName: string;
    function GetPlatformName: string;
  end;

  { Motor de geração de templates de produção }
  TTemplateEngine = class
  public
    class function ReplaceTags(const ATemplate: string; const AConfig: TWizardConfig): string;
    class function GenerateLpr(const AConfig: TWizardConfig): string;
    class function GenerateLpi(const AConfig: TWizardConfig): string;
    class function GenerateServiceCore(const AConfig: TWizardConfig): string;
    class function GenerateWorker(const AConfig: TWizardConfig): string;
    class function GenerateConfig(const AConfig: TWizardConfig): string;
    class function GenerateIni(const AConfig: TWizardConfig): string;
    class function GenerateSystemdService(const AConfig: TWizardConfig): string;
    class function GenerateInstallBat(const AConfig: TWizardConfig): string;
    class function GenerateUninstallBat(const AConfig: TWizardConfig): string;
    class function GenerateInstallSh(const AConfig: TWizardConfig): string;
    class function GenerateRemoveSh(const AConfig: TWizardConfig): string;
    class function GenerateStatusSh(const AConfig: TWizardConfig): string;
    class function GenerateViewLogsSh(const AConfig: TWizardConfig): string;

    class function GenerateProject(const AConfig: TWizardConfig; out AErrorMsg: string): Boolean;
  end;

implementation

{ TWizardConfig }

constructor TWizardConfig.Create;
begin
  inherited Create;
  ServiceName := 'SyncVendasSvc';
  DisplayName := 'Serviço de Sincronização de Vendas';
  Description := 'Serviço corporativo cross-platform para sincronização e automação.';
  TargetPlatform := tpHybrid;
  OutputDir := '';

  Archetype := akDatabasePool;
  IntervalValue := 5;
  IntervalUnit := iuSeconds;
  UseIniConfig := True;
  EnableSighupReload := True;
  EnableDebugMode := True;

  RestartOnFailure := True;
  RestartDelaySec := 5;
  LinuxUser := 'root';
  WaitNetwork := True;
  WaitDatabase := False;
  DatabaseType := 'firebird';
  LogLocalFile := True;
  LogSystemdJournal := True;
  LogWindowsEventLog := False;
  EnableHeapTrc := True;
end;

function TWizardConfig.GetIntervalMs: Cardinal;
begin
  case IntervalUnit of
    iuMilliseconds: Result := IntervalValue;
    iuSeconds: Result := IntervalValue * 1000;
    iuMinutes: Result := IntervalValue * 60 * 1000;
  else
    Result := 5000;
  end;
  if Result < 50 then
    Result := 50;
end;

function TWizardConfig.GetArchetypeName: string;
begin
  case Archetype of
    akDatabasePool: Result := 'Consulta / Pooling de Banco de Dados';
    akDirectoryMonitor: Result := 'Monitor de Pastas (Arquivos Bloqueados)';
    akHttpMicroservice: Result := 'API / WebService / Microserviço';
    akTaskScheduler: Result := 'Agendador de Tarefas / Backup Diário';
    akQueueWorker: Result := 'Fila de Mensagens / Tarefas Contínuas';
  else
    Result := 'Padrão';
  end;
end;

function TWizardConfig.GetPlatformName: string;
begin
  case TargetPlatform of
    tpWindows: Result := 'Windows Service (SCM)';
    tpLinux: Result := 'Linux Daemon (Systemd)';
    tpHybrid: Result := 'Híbrido Cross-Platform (Windows e Linux)';
  else
    Result := 'Híbrido';
  end;
end;

{ TTemplateEngine }

class function TTemplateEngine.ReplaceTags(const ATemplate: string; const AConfig: TWizardConfig): string;
var
  S: string;
  LSystemdAfter, LSystemdWants, LWinDepend: string;
begin
  S := ATemplate;
  S := StringReplace(S, '{{SERVICE_NAME}}', AConfig.ServiceName, [rfReplaceAll]);
  S := StringReplace(S, '{{DISPLAY_NAME}}', AConfig.DisplayName, [rfReplaceAll]);
  S := StringReplace(S, '{{DESCRIPTION}}', AConfig.Description, [rfReplaceAll]);
  S := StringReplace(S, '{{INTERVAL_MS}}', IntToStr(AConfig.GetIntervalMs), [rfReplaceAll]);
  S := StringReplace(S, '{{INTERVAL_SEC}}', IntToStr(AConfig.GetIntervalMs div 1000), [rfReplaceAll]);
  S := StringReplace(S, '{{RESTART_SEC}}', IntToStr(AConfig.RestartDelaySec), [rfReplaceAll]);
  S := StringReplace(S, '{{LINUX_USER}}', AConfig.LinuxUser, [rfReplaceAll]);

  // Systemd dependências
  LSystemdAfter := 'network.target';
  LSystemdWants := '';
  if AConfig.WaitNetwork then
  begin
    LSystemdAfter := LSystemdAfter + ' network-online.target';
    LSystemdWants := 'network-online.target';
  end;
  if AConfig.WaitDatabase then
  begin
    if AConfig.DatabaseType = 'firebird' then
      LSystemdAfter := LSystemdAfter + ' firebird.service'
    else if AConfig.DatabaseType = 'postgresql' then
      LSystemdAfter := LSystemdAfter + ' postgresql.service'
    else if AConfig.DatabaseType = 'mysql' then
      LSystemdAfter := LSystemdAfter + ' mysql.service';
  end;
  S := StringReplace(S, '{{SYSTEMD_AFTER}}', Trim(LSystemdAfter), [rfReplaceAll]);
  S := StringReplace(S, '{{SYSTEMD_WANTS}}', Trim(LSystemdWants), [rfReplaceAll]);

  // Windows SCM dependências
  LWinDepend := '';
  if AConfig.WaitNetwork then
    LWinDepend := 'depend= Tcpip/LanmanWorkstation';
  if AConfig.WaitDatabase then
  begin
    if LWinDepend = '' then
      LWinDepend := 'depend= FirebirdServerDefaultInstance'
    else
      LWinDepend := LWinDepend + '/FirebirdServerDefaultInstance';
  end;
  S := StringReplace(S, '{{SC_DEPEND}}', LWinDepend, [rfReplaceAll]);

  if AConfig.RestartOnFailure then
    S := StringReplace(S, '{{SYSTEMD_RESTART}}', 'always', [rfReplaceAll])
  else
    S := StringReplace(S, '{{SYSTEMD_RESTART}}', 'no', [rfReplaceAll]);

  Result := S;
end;

class function TTemplateEngine.GenerateLpr(const AConfig: TWizardConfig): string;
var
  S: string;
begin
  S :=
    'program {{SERVICE_NAME}};' + sLineBreak +
    '' + sLineBreak +
    '{$mode objfpc}{$H+}' + sLineBreak +
    '{$CODEPAGE UTF8}' + sLineBreak +
    '{$APPTYPE CONSOLE}' + sLineBreak +
    '' + sLineBreak +
    'uses' + sLineBreak +
    '  {$IFDEF UNIX}' + sLineBreak +
    '  cthreads, BaseUnix,' + sLineBreak +
    '  {$ENDIF}' + sLineBreak +
    '  SysUtils, Classes,' + sLineBreak +
    '  uConfig in ''uConfig.pas'',' + sLineBreak +
    '  uWorker in ''uWorker.pas'',' + sLineBreak +
    '  uServiceCore in ''uServiceCore.pas'';' + sLineBreak +
    '' + sLineBreak +
    'var' + sLineBreak +
    '  LParam: string;' + sLineBreak +
    '  I: Integer;' + sLineBreak +
    '  LIsDebug: Boolean;' + sLineBreak +
    'begin' + sLineBreak +
    '  LIsDebug := False;' + sLineBreak +
    '' + sLineBreak +
    '  // Processamento de parâmetros de linha de comando' + sLineBreak +
    '  if ParamCount > 0 then' + sLineBreak +
    '  begin' + sLineBreak +
    '    for I := 1 to ParamCount do' + sLineBreak +
    '    begin' + sLineBreak +
    '      LParam := LowerCase(ParamStr(I));' + sLineBreak +
    '      if (LParam = ''/debug'') or (LParam = ''-d'') or (LParam = ''--debug'') then' + sLineBreak +
    '        LIsDebug := True' + sLineBreak +
    '      else if (LParam = ''/install'') or (LParam = ''--install'') or (LParam = ''-i'') then' + sLineBreak +
      '      begin' + sLineBreak +
      '        TServiceCore.InstallService;' + sLineBreak +
      '        Exit;' + sLineBreak +
      '      end' + sLineBreak +
      '      else if (LParam = ''/uninstall'') or (LParam = ''--uninstall'') or (LParam = ''-u'') then' + sLineBreak +
      '      begin' + sLineBreak +
      '        TServiceCore.UninstallService;' + sLineBreak +
      '        Exit;' + sLineBreak +
      '      end' + sLineBreak +
      '      else if (LParam = ''/help'') or (LParam = ''--help'') or (LParam = ''-h'') or (LParam = ''/?'') then' + sLineBreak +
      '      begin' + sLineBreak +
      '        TServiceCore.PrintHelp;' + sLineBreak +
      '        Exit;' + sLineBreak +
      '      end;' + sLineBreak +
    '    end;' + sLineBreak +
    '  end;' + sLineBreak +
    '' + sLineBreak +
    '  // Inicialização e despacho do serviço' + sLineBreak +
    '  TServiceCore.Run(LIsDebug);' + sLineBreak +
    'end.' + sLineBreak;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateLpi(const AConfig: TWizardConfig): string;
var
  S, LHeapTrcOpt: string;
begin
  if AConfig.EnableHeapTrc then
    LHeapTrcOpt := '<CustomOptions Value="-gh"/>'
  else
    LHeapTrcOpt := '';

  S :=
    '<?xml version="1.0" encoding="UTF-8"?>' + sLineBreak +
    '<CONFIG>' + sLineBreak +
    '  <ProjectOptions>' + sLineBreak +
    '    <Version Value="12"/>' + sLineBreak +
    '    <PathDelim Value="\"/>' + sLineBreak +
    '    <General>' + sLineBreak +
    '      <Flags>' + sLineBreak +
    '        <MainUnitHasCreateFormStatements Value="False"/>' + sLineBreak +
    '        <MainUnitHasTitleStatement Value="False"/>' + sLineBreak +
    '        <MainUnitHasScaledStatement Value="False"/>' + sLineBreak +
    '      </Flags>' + sLineBreak +
    '      <SessionStorage Value="InProjectDir"/>' + sLineBreak +
    '      <Title Value="{{SERVICE_NAME}}"/>' + sLineBreak +
    '      <UseAppBundle Value="False"/>' + sLineBreak +
    '      <ResourceType Value="res"/>' + sLineBreak +
    '    </General>' + sLineBreak +
    '    <BuildModes>' + sLineBreak +
    '      <Item Name="Default" Default="True"/>' + sLineBreak +
    '    </BuildModes>' + sLineBreak +
    '    <PublishOptions>' + sLineBreak +
    '      <Version Value="2"/>' + sLineBreak +
    '      <UseFileFilters Value="True"/>' + sLineBreak +
    '    </PublishOptions>' + sLineBreak +
    '    <RunParams>' + sLineBreak +
    '      <FormatVersion Value="2"/>' + sLineBreak +
    '    </RunParams>' + sLineBreak +
    '    <Units>' + sLineBreak +
    '      <Unit>' + sLineBreak +
    '        <Filename Value="{{SERVICE_NAME}}.lpr"/>' + sLineBreak +
    '        <IsPartOfProject Value="True"/>' + sLineBreak +
    '      </Unit>' + sLineBreak +
    '      <Unit>' + sLineBreak +
    '        <Filename Value="uConfig.pas"/>' + sLineBreak +
    '        <IsPartOfProject Value="True"/>' + sLineBreak +
    '      </Unit>' + sLineBreak +
    '      <Unit>' + sLineBreak +
    '        <Filename Value="uWorker.pas"/>' + sLineBreak +
    '        <IsPartOfProject Value="True"/>' + sLineBreak +
    '      </Unit>' + sLineBreak +
    '      <Unit>' + sLineBreak +
    '        <Filename Value="uServiceCore.pas"/>' + sLineBreak +
    '        <IsPartOfProject Value="True"/>' + sLineBreak +
    '      </Unit>' + sLineBreak +
    '    </Units>' + sLineBreak +
    '  </ProjectOptions>' + sLineBreak +
    '  <CompilerOptions>' + sLineBreak +
    '    <Version Value="11"/>' + sLineBreak +
    '    <PathDelim Value="\"/>' + sLineBreak +
    '    <Target>' + sLineBreak +
    '      <Filename Value="{{SERVICE_NAME}}"/>' + sLineBreak +
    '    </Target>' + sLineBreak +
    '    <SearchPaths>' + sLineBreak +
    '      <IncludeFiles Value="$(ProjOutDir)"/>' + sLineBreak +
    '      <UnitOutputDirectory Value="lib\$(TargetCPU)-$(TargetOS)"/>' + sLineBreak +
    '    </SearchPaths>' + sLineBreak +
    '    <Linking>' + sLineBreak +
    '      <Debugging>' + sLineBreak +
    '        <GenerateDebugInfo Value="True"/>' + sLineBreak +
    '      </Debugging>' + sLineBreak +
    '    </Linking>' + sLineBreak +
    '    <Other>' + sLineBreak +
    '      ' + LHeapTrcOpt + sLineBreak +
    '    </Other>' + sLineBreak +
    '  </CompilerOptions>' + sLineBreak +
    '</CONFIG>' + sLineBreak;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateServiceCore(const AConfig: TWizardConfig): string;
var
  S: string;
begin
  S :=
    'unit uServiceCore;' + sLineBreak +
    '' + sLineBreak +
    '{$mode objfpc}{$H+}' + sLineBreak +
    '{$CODEPAGE UTF8}' + sLineBreak +
    '' + sLineBreak +
    'interface' + sLineBreak +
    '' + sLineBreak +
    'uses' + sLineBreak +
    '  SysUtils, Classes, SyncObjs,' + sLineBreak +
    '  {$IFDEF WINDOWS}' + sLineBreak +
    '  Windows,' + sLineBreak +
    '  {$ENDIF}' + sLineBreak +
    '  {$IFDEF UNIX}' + sLineBreak +
    '  BaseUnix,' + sLineBreak +
    '  {$ENDIF}' + sLineBreak +
    '  uConfig, uWorker;' + sLineBreak +
    '' + sLineBreak +
    'type' + sLineBreak +
    '  { TServiceCore: Núcleo de gerenciamento de ciclo de vida multiplataforma }' + sLineBreak +
    '  TServiceCore = class' + sLineBreak +
    '  private' + sLineBreak +
    '    class var FIsRunning: Boolean;' + sLineBreak +
    '    class var FIsDebugMode: Boolean;' + sLineBreak +
    '    class var FTermEvent: TEvent;' + sLineBreak +
    '    class var FWorker: TServiceWorker;' + sLineBreak +
    '    class procedure SetupSignals;' + sLineBreak +
    '    class procedure RunInteractiveDebug;' + sLineBreak +
    '    {$IFDEF WINDOWS}' + sLineBreak +
    '    class procedure RunWindowsService;' + sLineBreak +
    '    {$ENDIF}' + sLineBreak +
    '    {$IFDEF UNIX}' + sLineBreak +
    '    class procedure RunLinuxDaemon;' + sLineBreak +
    '    {$ENDIF}' + sLineBreak +
    '  public' + sLineBreak +
    '    class procedure Run(const AIsDebug: Boolean);' + sLineBreak +
    '    class procedure RequestStop;' + sLineBreak +
    '    class procedure ReloadConfiguration;' + sLineBreak +
    '    class procedure LogMessage(const ALevel, AMsg: string);' + sLineBreak +
    '    class procedure InstallService;' + sLineBreak +
    '    class procedure UninstallService;' + sLineBreak +
    '    class procedure PrintHelp;' + sLineBreak +
    '    class property IsDebugMode: Boolean read FIsDebugMode;' + sLineBreak +
    '  end;' + sLineBreak +
    '' + sLineBreak +
    'implementation' + sLineBreak +
    '' + sLineBreak +
    '{$IFDEF WINDOWS}' + sLineBreak +
    'var' + sLineBreak +
    '  GServiceStatusHandle: SERVICE_STATUS_HANDLE;' + sLineBreak +
    '  GServiceStatus: SERVICE_STATUS;' + sLineBreak +
    '' + sLineBreak +
    'procedure SetCurrentServiceStatus(const ACurrentState, AExitCode, AWaitHint: DWORD);' + sLineBreak +
    'begin' + sLineBreak +
    '  GServiceStatus.dwCurrentState := ACurrentState;' + sLineBreak +
    '  GServiceStatus.dwWin32ExitCode := AExitCode;' + sLineBreak +
    '  GServiceStatus.dwWaitHint := AWaitHint;' + sLineBreak +
    '  if ACurrentState = SERVICE_START_PENDING then' + sLineBreak +
    '    GServiceStatus.dwControlsAccepted := 0' + sLineBreak +
    '  else' + sLineBreak +
    '    GServiceStatus.dwControlsAccepted := SERVICE_ACCEPT_STOP or SERVICE_ACCEPT_SHUTDOWN;' + sLineBreak +
    '  SetServiceStatus(GServiceStatusHandle, GServiceStatus);' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'function ServiceCtrlHandler(Opcode: DWORD): BOOL; stdcall;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := True;' + sLineBreak +
    '  case Opcode of' + sLineBreak +
    '    SERVICE_CONTROL_STOP, SERVICE_CONTROL_SHUTDOWN:' + sLineBreak +
    '    begin' + sLineBreak +
    '      SetCurrentServiceStatus(SERVICE_STOP_PENDING, NO_ERROR, 5000);' + sLineBreak +
    '      TServiceCore.RequestStop;' + sLineBreak +
    '    end;' + sLineBreak +
    '    SERVICE_CONTROL_INTERROGATE:' + sLineBreak +
    '      SetServiceStatus(GServiceStatusHandle, GServiceStatus);' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'procedure ServiceMain(dwArgc: DWORD; lpszArgv: PPChar); stdcall;' + sLineBreak +
    'begin' + sLineBreak +
    '  GServiceStatus.dwServiceType := SERVICE_WIN32_OWN_PROCESS;' + sLineBreak +
    '  GServiceStatus.dwCurrentState := SERVICE_START_PENDING;' + sLineBreak +
    '  GServiceStatus.dwControlsAccepted := 0;' + sLineBreak +
    '  GServiceStatus.dwWin32ExitCode := 0;' + sLineBreak +
    '  GServiceStatus.dwServiceSpecificExitCode := 0;' + sLineBreak +
    '  GServiceStatus.dwCheckPoint := 0;' + sLineBreak +
    '  GServiceStatus.dwWaitHint := 5000;' + sLineBreak +
    '' + sLineBreak +
    '  GServiceStatusHandle := RegisterServiceCtrlHandlerA(''{{SERVICE_NAME}}'', @ServiceCtrlHandler);' + sLineBreak +
    '  if GServiceStatusHandle = 0 then' + sLineBreak +
    '    Exit;' + sLineBreak +
    '' + sLineBreak +
    '  SetCurrentServiceStatus(SERVICE_START_PENDING, NO_ERROR, 3000);' + sLineBreak +
    '' + sLineBreak +
    '  // Inicia o worker em background' + sLineBreak +
    '  TServiceCore.FTermEvent := TEvent.Create(nil, True, False, '''');' + sLineBreak +
    '  TServiceCore.FWorker := TServiceWorker.Create;' + sLineBreak +
    '  TServiceCore.FWorker.Start;' + sLineBreak +
    '' + sLineBreak +
    '  SetCurrentServiceStatus(SERVICE_RUNNING, NO_ERROR, 0);' + sLineBreak +
    '  TServiceCore.LogMessage(''INFO'', ''Servico {{SERVICE_NAME}} iniciado com sucesso pelo Windows SCM.'');' + sLineBreak +
    '' + sLineBreak +
    '  // Aguarda sinal de encerramento' + sLineBreak +
    '  TServiceCore.FTermEvent.WaitFor(INFINITE);' + sLineBreak +
    '' + sLineBreak +
    '  SetCurrentServiceStatus(SERVICE_STOP_PENDING, NO_ERROR, 3000);' + sLineBreak +
    '  if Assigned(TServiceCore.FWorker) then' + sLineBreak +
    '  begin' + sLineBreak +
    '    TServiceCore.FWorker.Stop;' + sLineBreak +
    '    FreeAndNil(TServiceCore.FWorker);' + sLineBreak +
    '  end;' + sLineBreak +
    '  FreeAndNil(TServiceCore.FTermEvent);' + sLineBreak +
    '' + sLineBreak +
    '  SetCurrentServiceStatus(SERVICE_STOPPED, NO_ERROR, 0);' + sLineBreak +
    '  TServiceCore.LogMessage(''INFO'', ''Servico {{SERVICE_NAME}} parado com sucesso.'');' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'function ConsoleCtrlHandler(dwCtrlType: DWORD): BOOL; stdcall;' + sLineBreak +
    'begin' + sLineBreak +
    '  case dwCtrlType of' + sLineBreak +
    '    CTRL_C_EVENT, CTRL_BREAK_EVENT, CTRL_CLOSE_EVENT:' + sLineBreak +
    '    begin' + sLineBreak +
    '      Writeln('''');' + sLineBreak +
    '      TServiceCore.LogMessage(''WARN'', ''Sinal de encerramento recebido (Ctrl+C). Parando servico...'');' + sLineBreak +
    '      TServiceCore.RequestStop;' + sLineBreak +
    '      Result := True;' + sLineBreak +
    '    end;' + sLineBreak +
    '  else' + sLineBreak +
    '    Result := False;' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '' + sLineBreak +
    '{$IFDEF UNIX}' + sLineBreak +
    'procedure PosixSigHandler(Sig: LongInt); cdecl;' + sLineBreak +
    'begin' + sLineBreak +
    '  case Sig of' + sLineBreak +
    '    SIGTERM, SIGINT:' + sLineBreak +
    '    begin' + sLineBreak +
    '      TServiceCore.LogMessage(''WARN'', ''Sinal POSIX '' + IntToStr(Sig) + '' recebido. Encerrando servico...'');' + sLineBreak +
    '      TServiceCore.RequestStop;' + sLineBreak +
    '    end;' + sLineBreak +
    '    SIGHUP:' + sLineBreak +
    '    begin' + sLineBreak +
    '      TServiceCore.LogMessage(''INFO'', ''Sinal SIGHUP recebido. Recarregando configuracoes...'');' + sLineBreak +
    '      TServiceCore.ReloadConfiguration;' + sLineBreak +
    '    end;' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '' + sLineBreak +
    '{ TServiceCore }' + sLineBreak +
    '' + sLineBreak +
    'class procedure TServiceCore.SetupSignals;' + sLineBreak +
    'begin' + sLineBreak +
    '  {$IFDEF WINDOWS}' + sLineBreak +
    '  SetConsoleCtrlHandler(@ConsoleCtrlHandler, True);' + sLineBreak +
    '  {$ENDIF}' + sLineBreak +
    '  {$IFDEF UNIX}' + sLineBreak +
    '  fpSignal(SIGTERM, SignalHandler(@PosixSigHandler));' + sLineBreak +
    '  fpSignal(SIGINT,  SignalHandler(@PosixSigHandler));' + sLineBreak +
    '  fpSignal(SIGHUP,  SignalHandler(@PosixSigHandler));' + sLineBreak +
    '  {$ENDIF}' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'class procedure TServiceCore.LogMessage(const ALevel, AMsg: string);' + sLineBreak +
    'var' + sLineBreak +
    '  LLine, LDateStr, LLogFile: string;' + sLineBreak +
    '  F: TextFile;' + sLineBreak +
    'begin' + sLineBreak +
    '  LDateStr := FormatDateTime(''yyyy-mm-dd hh:nn:ss.zzz'', Now);' + sLineBreak +
    '  LLine := ''['' + LDateStr + ''] ['' + UpperCase(ALevel) + ''] '' + AMsg;' + sLineBreak +
    '' + sLineBreak +
    '  // Se estiver no modo interativo ou terminal' + sLineBreak +
    '  if FIsDebugMode or (ParamCount > 0) then' + sLineBreak +
    '    Writeln(LLine);' + sLineBreak +
    '' + sLineBreak +
    '  // Gravação em arquivo de log rotativo' + sLineBreak +
    '  try' + sLineBreak +
    '    LLogFile := ExtractFilePath(ParamStr(0)) + ''{{SERVICE_NAME}}-'' + FormatDateTime(''yyyy-mm-dd'', Now) + ''.log'';' + sLineBreak +
    '    AssignFile(F, LLogFile);' + sLineBreak +
    '    if FileExists(LLogFile) then' + sLineBreak +
    '      Append(F)' + sLineBreak +
    '    else' + sLineBreak +
    '      Rewrite(F);' + sLineBreak +
    '    Writeln(F, LLine);' + sLineBreak +
    '    CloseFile(F);' + sLineBreak +
    '  except' + sLineBreak +
    '    // Não interrompe o serviço em falha de escrita de log' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'class procedure TServiceCore.RequestStop;' + sLineBreak +
    'begin' + sLineBreak +
    '  FIsRunning := False;' + sLineBreak +
    '  if Assigned(FTermEvent) then' + sLineBreak +
    '    FTermEvent.SetEvent;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'class procedure TServiceCore.ReloadConfiguration;' + sLineBreak +
    'begin' + sLineBreak +
    '  TAppConfig.Instance.Reload;' + sLineBreak +
    '  if Assigned(FWorker) then' + sLineBreak +
    '    FWorker.OnConfigReload;' + sLineBreak +
    '  LogMessage(''INFO'', ''Configuracoes recarregadas com sucesso a partir de: '' + TAppConfig.Instance.IniFileName);' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'class procedure TServiceCore.RunInteractiveDebug;' + sLineBreak +
    'begin' + sLineBreak +
    '  FIsDebugMode := True;' + sLineBreak +
    '  SetupSignals;' + sLineBreak +
    '' + sLineBreak +
    '  Writeln(''================================================================'');' + sLineBreak +
    '  Writeln(''  {{DISPLAY_NAME}}'');' + sLineBreak +
    '  Writeln(''  Modo: Console Interativo de Debug (/debug)'');' + sLineBreak +
    '  Writeln(''  Pressione Ctrl+C para encerrar limpo e com segurança'');' + sLineBreak +
    '  Writeln(''================================================================'');' + sLineBreak +
    '  Writeln('''');' + sLineBreak +
    '' + sLineBreak +
    '  LogMessage(''INFO'', ''Iniciando modulo de trabalho (Worker)...'');' + sLineBreak +
    '  FTermEvent := TEvent.Create(nil, True, False, '''');' + sLineBreak +
    '  try' + sLineBreak +
    '    FWorker := TServiceWorker.Create;' + sLineBreak +
    '    FWorker.Start;' + sLineBreak +
    '    FIsRunning := True;' + sLineBreak +
    '    LogMessage(''INFO'', ''Servico executando no terminal interativo. Aguardando eventos...'');' + sLineBreak +
    '' + sLineBreak +
    '    // Aguarda encerramento' + sLineBreak +
    '    FTermEvent.WaitFor(INFINITE);' + sLineBreak +
    '' + sLineBreak +
    '    LogMessage(''INFO'', ''Encerrando modulo de trabalho...'');' + sLineBreak +
    '    FWorker.Stop;' + sLineBreak +
    '    FreeAndNil(FWorker);' + sLineBreak +
    '    LogMessage(''INFO'', ''Servico finalizado com sucesso.'');' + sLineBreak +
    '  finally' + sLineBreak +
    '    FreeAndNil(FTermEvent);' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    '{$IFDEF WINDOWS}' + sLineBreak +
    'class procedure TServiceCore.RunWindowsService;' + sLineBreak +
    'var' + sLineBreak +
    '  LServiceTable: array[0..1] of SERVICE_TABLE_ENTRYA;' + sLineBreak +
    'begin' + sLineBreak +
    '  LServiceTable[0].lpServiceName := PAnsiChar(''{{SERVICE_NAME}}'');' + sLineBreak +
    '  LServiceTable[0].lpServiceProc := @ServiceMain;' + sLineBreak +
    '  LServiceTable[1].lpServiceName := nil;' + sLineBreak +
    '  LServiceTable[1].lpServiceProc := nil;' + sLineBreak +
    '' + sLineBreak +
    '  if not StartServiceCtrlDispatcherA(@LServiceTable[0]) then' + sLineBreak +
    '  begin' + sLineBreak +
    '    // Se falhar ao conectar ao SCM (ex: executado em janela comum sem /debug)' + sLineBreak +
    '    Writeln(''Aviso: Este programa e um servico do Windows e deve ser iniciado pelo SCM.'');' + sLineBreak +
    '    Writeln(''Para testar interativamente, use o parametro: /debug'');' + sLineBreak +
    '    Writeln(''Para registrar o servico, use: /install ou executar instalar.bat'');' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '' + sLineBreak +
    '{$IFDEF UNIX}' + sLineBreak +
    'class procedure TServiceCore.RunLinuxDaemon;' + sLineBreak +
    'begin' + sLineBreak +
    '  // No Linux moderno com Systemd (Type=simple), o daemon roda como processo primário' + sLineBreak +
    '  SetupSignals;' + sLineBreak +
    '  LogMessage(''INFO'', ''Iniciando daemon Linux {{SERVICE_NAME}} via Systemd...'');' + sLineBreak +
    '' + sLineBreak +
    '  FTermEvent := TEvent.Create(nil, True, False, '''');' + sLineBreak +
    '  try' + sLineBreak +
    '    FWorker := TServiceWorker.Create;' + sLineBreak +
    '    FWorker.Start;' + sLineBreak +
    '    FIsRunning := True;' + sLineBreak +
    '    LogMessage(''INFO'', ''Daemon {{SERVICE_NAME}} rodando com sucesso.'');' + sLineBreak +
    '' + sLineBreak +
    '    FTermEvent.WaitFor(INFINITE);' + sLineBreak +
    '' + sLineBreak +
    '    LogMessage(''INFO'', ''Parando daemon {{SERVICE_NAME}}...'');' + sLineBreak +
    '    FWorker.Stop;' + sLineBreak +
    '    FreeAndNil(FWorker);' + sLineBreak +
    '    LogMessage(''INFO'', ''Daemon finalizado.'');' + sLineBreak +
    '  finally' + sLineBreak +
    '    FreeAndNil(FTermEvent);' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '' + sLineBreak +
    'class procedure TServiceCore.Run(const AIsDebug: Boolean);' + sLineBreak +
    'begin' + sLineBreak +
    '  // Carrega configurações iniciais' + sLineBreak +
    '  TAppConfig.Instance;' + sLineBreak +
    '' + sLineBreak +
    '  if AIsDebug then' + sLineBreak +
    '    RunInteractiveDebug' + sLineBreak +
    '  else' + sLineBreak +
    '  begin' + sLineBreak +
    '    {$IFDEF WINDOWS}' + sLineBreak +
    '    RunWindowsService;' + sLineBreak +
    '    {$ENDIF}' + sLineBreak +
    '    {$IFDEF UNIX}' + sLineBreak +
    '    RunLinuxDaemon;' + sLineBreak +
    '    {$ENDIF}' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'class procedure TServiceCore.InstallService;' + sLineBreak +
    'begin' + sLineBreak +
    '  Writeln(''Para instalar este servico com privilegios elevados, utilize:'');' + sLineBreak +
    '  {$IFDEF WINDOWS}' + sLineBreak +
    '  Writeln(''  Execute o script: instalar.bat (como Administrador)'');' + sLineBreak +
    '  {$ENDIF}' + sLineBreak +
    '  {$IFDEF UNIX}' + sLineBreak +
    '  Writeln(''  Execute o script: sudo ./instalar.sh'');' + sLineBreak +
    '  {$ENDIF}' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'class procedure TServiceCore.UninstallService;' + sLineBreak +
    'begin' + sLineBreak +
    '  Writeln(''Para desinstalar este servico com privilegios elevados, utilize:'');' + sLineBreak +
    '  {$IFDEF WINDOWS}' + sLineBreak +
    '  Writeln(''  Execute o script: desinstalar.bat (como Administrador)'');' + sLineBreak +
    '  {$ENDIF}' + sLineBreak +
    '  {$IFDEF UNIX}' + sLineBreak +
    '  Writeln(''  Execute o script: sudo ./remover.sh'');' + sLineBreak +
    '  {$ENDIF}' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'class procedure TServiceCore.PrintHelp;' + sLineBreak +
    'begin' + sLineBreak +
    '  Writeln(''Uso do executavel {{SERVICE_NAME}}:'');' + sLineBreak +
    '  Writeln(''  /debug  ou -d   : Executa em modo Console interativo com logs coloridos'');' + sLineBreak +
    '  Writeln(''  /install ou -i  : Orienta a instalacao como servico no SCM/Systemd'');' + sLineBreak +
    '  Writeln(''  /uninstall ou -u: Orienta a desinstalacao do servico'');' + sLineBreak +
    '  Writeln(''  /help   ou -h   : Exibe esta mensagem de ajuda'');' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'end.' + sLineBreak;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateWorker(const AConfig: TWizardConfig): string;
var
  S, LWorkerFields, LWorkerMethods, LWorkerBody, LWorkerInit: string;
begin
  case AConfig.Archetype of
    akDatabasePool:
    begin
      LWorkerFields :=
        '    FQueryCount: Int64;' + sLineBreak +
        '    FLastCheck: TDateTime;' + sLineBreak +
        '    procedure ConnectAndProcessQueries;' + sLineBreak;
      LWorkerMethods :=
        'procedure TServiceWorkerThread.ConnectAndProcessQueries;' + sLineBreak +
        'begin' + sLineBreak +
        '  Inc(FQueryCount);' + sLineBreak +
        '  FLastCheck := Now;' + sLineBreak +
        '  TServiceCore.LogMessage(''DEBUG'', ''[DB-POOL] Verificando fila de registros no banco '' + TAppConfig.Instance.DatabaseName + '' (Ciclo #'' + IntToStr(FQueryCount) + '')...'');' + sLineBreak +
        '  // Simulação de processamento de lote' + sLineBreak +
        '  // Aqui você instancia seu TSQLQuery / Conexão (FCL-DB, ZEOS, Firebird, etc.)' + sLineBreak +
        '  // Exemplo:' + sLineBreak +
        '  // Query := TSQLQuery.Create(nil);' + sLineBreak +
        '  // try' + sLineBreak +
        '  //   Query.SQL.Text := ''SELECT * FROM FILA_PROCESSAMENTO WHERE STATUS = 0'';' + sLineBreak +
        '  //   Query.Open;' + sLineBreak +
        '  //   ...' + sLineBreak +
        '  // finally' + sLineBreak +
        '  //   Query.Free;' + sLineBreak +
        '  // end;' + sLineBreak +
        'end;' + sLineBreak;
      LWorkerBody :=
        '    try' + sLineBreak +
        '      ConnectAndProcessQueries;' + sLineBreak +
        '    except' + sLineBreak +
        '      on E: Exception do' + sLineBreak +
        '        TServiceCore.LogMessage(''ERROR'', ''[DB-POOL] Erro na consulta de banco: '' + E.Message);' + sLineBreak +
        '    end;';
      LWorkerInit := '  FQueryCount := 0;' + sLineBreak;
    end;

    akDirectoryMonitor:
    begin
      LWorkerFields :=
        '    FInboxPath: string;' + sLineBreak +
        '    FOutboxPath: string;' + sLineBreak +
        '    procedure ScanAndProcessDirectory;' + sLineBreak;
      LWorkerMethods :=
        'function IsFileLocked(const AFileName: string): Boolean;' + sLineBreak +
        'var' + sLineBreak +
        '  FHandle: THandle;' + sLineBreak +
        'begin' + sLineBreak +
        '  // Testa se o arquivo terminou de ser copiado/gravado' + sLineBreak +
        '  FHandle := FileOpen(AFileName, fmOpenRead or fmShareExclusive);' + sLineBreak +
        '  if FHandle = THandle(-1) then' + sLineBreak +
        '    Result := True // Arquivo em uso ou bloqueado' + sLineBreak +
        '  else' + sLineBreak +
        '  begin' + sLineBreak +
        '    FileClose(FHandle);' + sLineBreak +
        '    Result := False;' + sLineBreak +
        '  end;' + sLineBreak +
        'end;' + sLineBreak +
        '' + sLineBreak +
        'procedure TServiceWorkerThread.ScanAndProcessDirectory;' + sLineBreak +
        'var' + sLineBreak +
        '  Rec: TSearchRec;' + sLineBreak +
        '  LFile, LDest: string;' + sLineBreak +
        'begin' + sLineBreak +
        '  if not DirectoryExists(FInboxPath) then' + sLineBreak +
        '    ForceDirectories(FInboxPath);' + sLineBreak +
        '  if not DirectoryExists(FOutboxPath) then' + sLineBreak +
        '    ForceDirectories(FOutboxPath);' + sLineBreak +
        '' + sLineBreak +
        '  if FindFirst(IncludeTrailingPathDelimiter(FInboxPath) + ''*.*'', faAnyFile and not faDirectory, Rec) = 0 then' + sLineBreak +
        '  try' + sLineBreak +
        '    repeat' + sLineBreak +
        '      LFile := IncludeTrailingPathDelimiter(FInboxPath) + Rec.Name;' + sLineBreak +
        '      if not IsFileLocked(LFile) then' + sLineBreak +
        '      begin' + sLineBreak +
        '        TServiceCore.LogMessage(''INFO'', ''[DIR-MONITOR] Processando arquivo: '' + Rec.Name);' + sLineBreak +
        '        LDest := IncludeTrailingPathDelimiter(FOutboxPath) + Rec.Name;' + sLineBreak +
        '        if RenameFile(LFile, LDest) then' + sLineBreak +
        '          TServiceCore.LogMessage(''INFO'', ''[DIR-MONITOR] Arquivo movido para saida: '' + Rec.Name)' + sLineBreak +
        '        else' + sLineBreak +
        '          TServiceCore.LogMessage(''WARN'', ''[DIR-MONITOR] Falha ao mover arquivo: '' + Rec.Name);' + sLineBreak +
        '      end' + sLineBreak +
        '      else' + sLineBreak +
        '        TServiceCore.LogMessage(''DEBUG'', ''[DIR-MONITOR] Arquivo em uso (aguardando liberacao): '' + Rec.Name);' + sLineBreak +
        '    until FindNext(Rec) <> 0;' + sLineBreak +
        '  finally' + sLineBreak +
        '    FindClose(Rec);' + sLineBreak +
        '  end;' + sLineBreak +
        'end;' + sLineBreak;
      LWorkerBody :=
        '    try' + sLineBreak +
        '      ScanAndProcessDirectory;' + sLineBreak +
        '    except' + sLineBreak +
        '      on E: Exception do' + sLineBreak +
        '        TServiceCore.LogMessage(''ERROR'', ''[DIR-MONITOR] Erro ao monitorar pasta: '' + E.Message);' + sLineBreak +
        '    end;';
      LWorkerInit :=
        '  FInboxPath := TAppConfig.Instance.MonitorInbox;' + sLineBreak +
        '  FOutboxPath := TAppConfig.Instance.MonitorOutbox;' + sLineBreak;
    end;

    akHttpMicroservice:
    begin
      LWorkerFields :=
        '    FPort: Word;' + sLineBreak +
        '    procedure ProcessHeartbeat;' + sLineBreak;
      LWorkerMethods :=
        'procedure TServiceWorkerThread.ProcessHeartbeat;' + sLineBreak +
        'begin' + sLineBreak +
        '  TServiceCore.LogMessage(''DEBUG'', ''[MICROSERVICE] Servico HTTP ativo escutando na porta '' + IntToStr(FPort) + ''...'');' + sLineBreak +
        '  // Aqui você conecta seu servidor HTTP (ex: fphttpapp, Brook, Horse, mORMot ou sockets nativos)' + sLineBreak +
        'end;' + sLineBreak;
      LWorkerBody :=
        '    try' + sLineBreak +
        '      ProcessHeartbeat;' + sLineBreak +
        '    except' + sLineBreak +
        '      on E: Exception do' + sLineBreak +
        '        TServiceCore.LogMessage(''ERROR'', ''[MICROSERVICE] Erro no microservico: '' + E.Message);' + sLineBreak +
        '    end;';
      LWorkerInit :=
        '  FPort := TAppConfig.Instance.HttpPort;' + sLineBreak +
        '  TServiceCore.LogMessage(''INFO'', ''[MICROSERVICE] Inicializando socket HTTP na porta '' + IntToStr(FPort));' + sLineBreak;
    end;

    akTaskScheduler:
    begin
      LWorkerFields :=
        '    FScheduleTime: string;' + sLineBreak +
        '    FLastExecutionDate: TDateTime;' + sLineBreak +
        '    procedure CheckAndExecuteSchedule;' + sLineBreak;
      LWorkerMethods :=
        'procedure TServiceWorkerThread.CheckAndExecuteSchedule;' + sLineBreak +
        'var' + sLineBreak +
        '  LNowTime, LTargetTime: TDateTime;' + sLineBreak +
        'begin' + sLineBreak +
        '  LNowTime := Time;' + sLineBreak +
        '  LTargetTime := StrToTimeDef(FScheduleTime, EncodeTime(2, 0, 0, 0));' + sLineBreak +
        '' + sLineBreak +
        '  // Executa uma vez ao dia no horário configurado' + sLineBreak +
        '  if (Trunc(Date) <> Trunc(FLastExecutionDate)) and (LNowTime >= LTargetTime) then' + sLineBreak +
        '  begin' + sLineBreak +
        '    FLastExecutionDate := Date;' + sLineBreak +
        '    TServiceCore.LogMessage(''INFO'', ''[SCHEDULER] >>> Executando tarefa agendada diaria das '' + FScheduleTime + '' <<<'');' + sLineBreak +
        '    // Execute aqui sua rotina de backup ou processamento noturno pesado' + sLineBreak +
        '    TServiceCore.LogMessage(''INFO'', ''[SCHEDULER] Tarefa agendada finalizada com sucesso.'');' + sLineBreak +
        '  end;' + sLineBreak +
        'end;' + sLineBreak;
      LWorkerBody :=
        '    try' + sLineBreak +
        '      CheckAndExecuteSchedule;' + sLineBreak +
        '    except' + sLineBreak +
        '      on E: Exception do' + sLineBreak +
        '        TServiceCore.LogMessage(''ERROR'', ''[SCHEDULER] Erro no agendador de tarefas: '' + E.Message);' + sLineBreak +
        '    end;';
      LWorkerInit :=
        '  FScheduleTime := TAppConfig.Instance.ScheduleTime;' + sLineBreak +
        '  FLastExecutionDate := 0;' + sLineBreak +
        '  TServiceCore.LogMessage(''INFO'', ''[SCHEDULER] Agendado para execucao diaria as: '' + FScheduleTime);' + sLineBreak;
    end;

    akQueueWorker:
    begin
      LWorkerFields :=
        '    FProcessedCount: Int64;' + sLineBreak +
        '    procedure ProcessMessageQueue;' + sLineBreak;
      LWorkerMethods :=
        'procedure TServiceWorkerThread.ProcessMessageQueue;' + sLineBreak +
        'begin' + sLineBreak +
        '  Inc(FProcessedCount);' + sLineBreak +
        '  TServiceCore.LogMessage(''DEBUG'', ''[QUEUE] Consumindo mensagens da fila de tarefas (#'' + IntToStr(FProcessedCount) + '')...'');' + sLineBreak +
        '  // Aqui você processa itens de sua fila (TThreadList, Redis, RabbitMQ, etc.)' + sLineBreak +
        'end;' + sLineBreak;
      LWorkerBody :=
        '    try' + sLineBreak +
        '      ProcessMessageQueue;' + sLineBreak +
        '    except' + sLineBreak +
        '      on E: Exception do' + sLineBreak +
        '        TServiceCore.LogMessage(''ERROR'', ''[QUEUE] Erro ao consumir fila: '' + E.Message);' + sLineBreak +
        '    end;';
      LWorkerInit := '  FProcessedCount := 0;' + sLineBreak;
    end;
  end;

  S :=
    'unit uWorker;' + sLineBreak +
    '' + sLineBreak +
    '{$mode objfpc}{$H+}' + sLineBreak +
    '{$CODEPAGE UTF8}' + sLineBreak +
    '' + sLineBreak +
    'interface' + sLineBreak +
    '' + sLineBreak +
    'uses' + sLineBreak +
    '  SysUtils, Classes, SyncObjs;' + sLineBreak +
    '' + sLineBreak +
    'type' + sLineBreak +
    '  { TServiceWorkerThread: Thread de execucao independente e segura }' + sLineBreak +
    '  TServiceWorkerThread = class(TThread)' + sLineBreak +
    '  private' + sLineBreak +
    '    FTermEvent: TEvent;' + sLineBreak +
    '    FIntervalMs: Cardinal;' + sLineBreak +
    LWorkerFields +
    '  protected' + sLineBreak +
    '    procedure Execute; override;' + sLineBreak +
    '  public' + sLineBreak +
    '    constructor Create;' + sLineBreak +
    '    destructor Destroy; override;' + sLineBreak +
    '    procedure TerminateWork;' + sLineBreak +
    '    procedure UpdateInterval(const ANewIntervalMs: Cardinal);' + sLineBreak +
    '  end;' + sLineBreak +
    '' + sLineBreak +
    '  { TServiceWorker: Fachada de controle do modulo de trabalho }' + sLineBreak +
    '  TServiceWorker = class' + sLineBreak +
    '  private' + sLineBreak +
    '    FThread: TServiceWorkerThread;' + sLineBreak +
    '  public' + sLineBreak +
    '    constructor Create;' + sLineBreak +
    '    destructor Destroy; override;' + sLineBreak +
    '    procedure Start;' + sLineBreak +
    '    procedure Stop;' + sLineBreak +
    '    procedure OnConfigReload;' + sLineBreak +
    '  end;' + sLineBreak +
    '' + sLineBreak +
    'implementation' + sLineBreak +
    '' + sLineBreak +
    'uses' + sLineBreak +
    '  uConfig, uServiceCore;' + sLineBreak +
    '' + sLineBreak +
    LWorkerMethods +
    '' + sLineBreak +
    '{ TServiceWorkerThread }' + sLineBreak +
    '' + sLineBreak +
    'constructor TServiceWorkerThread.Create;' + sLineBreak +
    'begin' + sLineBreak +
    '  inherited Create(True); // Cria suspensa' + sLineBreak +
    '  FreeOnTerminate := False;' + sLineBreak +
    '  FTermEvent := TEvent.Create(nil, True, False, '''');' + sLineBreak +
    '  FIntervalMs := TAppConfig.Instance.PollingIntervalMs;' + sLineBreak +
    LWorkerInit +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'destructor TServiceWorkerThread.Destroy;' + sLineBreak +
    'begin' + sLineBreak +
    '  FreeAndNil(FTermEvent);' + sLineBreak +
    '  inherited Destroy;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'procedure TServiceWorkerThread.TerminateWork;' + sLineBreak +
    'begin' + sLineBreak +
    '  Terminate;' + sLineBreak +
    '  if Assigned(FTermEvent) then' + sLineBreak +
    '    FTermEvent.SetEvent; // Desperta a thread imediatamente sem aguardar sleep' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'procedure TServiceWorkerThread.UpdateInterval(const ANewIntervalMs: Cardinal);' + sLineBreak +
    'begin' + sLineBreak +
    '  FIntervalMs := ANewIntervalMs;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'procedure TServiceWorkerThread.Execute;' + sLineBreak +
    'begin' + sLineBreak +
    '  TServiceCore.LogMessage(''INFO'', ''Thread de trabalho iniciada. Intervalo: '' + IntToStr(FIntervalMs) + '' ms'');' + sLineBreak +
    '  while not Terminated do' + sLineBreak +
    '  begin' + sLineBreak +
    LWorkerBody + sLineBreak +
    '    // Aguarda o intervalo de forma responsiva ao sinal de encerramento' + sLineBreak +
    '    if FTermEvent.WaitFor(FIntervalMs) = wrSignaled then' + sLineBreak +
    '      Break;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TServiceCore.LogMessage(''INFO'', ''Thread de trabalho finalizada com sucesso.'');' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    '{ TServiceWorker }' + sLineBreak +
    '' + sLineBreak +
    'constructor TServiceWorker.Create;' + sLineBreak +
    'begin' + sLineBreak +
    '  inherited Create;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'destructor TServiceWorker.Destroy;' + sLineBreak +
    'begin' + sLineBreak +
    '  Stop;' + sLineBreak +
    '  inherited Destroy;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'procedure TServiceWorker.Start;' + sLineBreak +
    'begin' + sLineBreak +
    '  if not Assigned(FThread) then' + sLineBreak +
    '  begin' + sLineBreak +
    '    FThread := TServiceWorkerThread.Create;' + sLineBreak +
    '    FThread.Start;' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'procedure TServiceWorker.Stop;' + sLineBreak +
    'begin' + sLineBreak +
    '  if Assigned(FThread) then' + sLineBreak +
    '  begin' + sLineBreak +
    '    FThread.TerminateWork;' + sLineBreak +
    '    FThread.WaitFor;' + sLineBreak +
    '    FreeAndNil(FThread);' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'procedure TServiceWorker.OnConfigReload;' + sLineBreak +
    'begin' + sLineBreak +
    '  if Assigned(FThread) then' + sLineBreak +
    '    FThread.UpdateInterval(TAppConfig.Instance.PollingIntervalMs);' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'end.' + sLineBreak;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateConfig(const AConfig: TWizardConfig): string;
var
  S, LConfigProps, LConfigFields, LConfigLoad, LConfigSave: string;
begin
  case AConfig.Archetype of
    akDatabasePool:
    begin
      LConfigFields :=
        '    FDatabaseHost: string;' + sLineBreak +
        '    FDatabasePort: Integer;' + sLineBreak +
        '    FDatabaseName: string;' + sLineBreak +
        '    FDatabaseUser: string;' + sLineBreak +
        '    FDatabasePass: string;' + sLineBreak;
      LConfigProps :=
        '    property DatabaseHost: string read FDatabaseHost;' + sLineBreak +
        '    property DatabasePort: Integer read FDatabasePort;' + sLineBreak +
        '    property DatabaseName: string read FDatabaseName;' + sLineBreak +
        '    property DatabaseUser: string read FDatabaseUser;' + sLineBreak +
        '    property DatabasePass: string read FDatabasePass;' + sLineBreak;
      LConfigLoad :=
        '  FDatabaseHost := Ini.ReadString(''DATABASE'', ''Host'', ''127.0.0.1'');' + sLineBreak +
        '  FDatabasePort := Ini.ReadInteger(''DATABASE'', ''Port'', 3050);' + sLineBreak +
        '  FDatabaseName := Ini.ReadString(''DATABASE'', ''Database'', ''meu_banco.fdb'');' + sLineBreak +
        '  FDatabaseUser := Ini.ReadString(''DATABASE'', ''User'', ''SYSDBA'');' + sLineBreak +
        '  FDatabasePass := Ini.ReadString(''DATABASE'', ''Password'', ''masterkey'');';
      LConfigSave :=
        '  Ini.WriteString(''DATABASE'', ''Host'', FDatabaseHost);' + sLineBreak +
        '  Ini.WriteInteger(''DATABASE'', ''Port'', FDatabasePort);' + sLineBreak +
        '  Ini.WriteString(''DATABASE'', ''Database'', FDatabaseName);' + sLineBreak +
        '  Ini.WriteString(''DATABASE'', ''User'', FDatabaseUser);' + sLineBreak +
        '  Ini.WriteString(''DATABASE'', ''Password'', FDatabasePass);';
    end;

    akDirectoryMonitor:
    begin
      LConfigFields :=
        '    FMonitorInbox: string;' + sLineBreak +
        '    FMonitorOutbox: string;' + sLineBreak +
        '    FMonitorError: string;' + sLineBreak;
      LConfigProps :=
        '    property MonitorInbox: string read FMonitorInbox;' + sLineBreak +
        '    property MonitorOutbox: string read FMonitorOutbox;' + sLineBreak +
        '    property MonitorError: string read FMonitorError;' + sLineBreak;
      LConfigLoad :=
        '  FMonitorInbox := Ini.ReadString(''MONITOR'', ''InboxPath'', ''./inbox'');' + sLineBreak +
        '  FMonitorOutbox := Ini.ReadString(''MONITOR'', ''OutboxPath'', ''./outbox'');' + sLineBreak +
        '  FMonitorError := Ini.ReadString(''MONITOR'', ''ErrorPath'', ''./error'');';
      LConfigSave :=
        '  Ini.WriteString(''MONITOR'', ''InboxPath'', FMonitorInbox);' + sLineBreak +
        '  Ini.WriteString(''MONITOR'', ''OutboxPath'', FMonitorOutbox);' + sLineBreak +
        '  Ini.WriteString(''MONITOR'', ''ErrorPath'', FMonitorError);';
    end;

    akHttpMicroservice:
    begin
      LConfigFields :=
        '    FHttpPort: Word;' + sLineBreak +
        '    FBindAddress: string;' + sLineBreak;
      LConfigProps :=
        '    property HttpPort: Word read FHttpPort;' + sLineBreak +
        '    property BindAddress: string read FBindAddress;' + sLineBreak;
      LConfigLoad :=
        '  FHttpPort := Ini.ReadInteger(''HTTP'', ''Port'', 8080);' + sLineBreak +
        '  FBindAddress := Ini.ReadString(''HTTP'', ''BindAddress'', ''0.0.0.0'');';
      LConfigSave :=
        '  Ini.WriteInteger(''HTTP'', ''Port'', FHttpPort);' + sLineBreak +
        '  Ini.WriteString(''HTTP'', ''BindAddress'', FBindAddress);';
    end;

    akTaskScheduler:
    begin
      LConfigFields :=
        '    FScheduleTime: string;' + sLineBreak +
        '    FBackupTargetDir: string;' + sLineBreak;
      LConfigProps :=
        '    property ScheduleTime: string read FScheduleTime;' + sLineBreak +
        '    property BackupTargetDir: string read FBackupTargetDir;' + sLineBreak;
      LConfigLoad :=
        '  FScheduleTime := Ini.ReadString(''SCHEDULE'', ''DailyExecutionTime'', ''02:00:00'');' + sLineBreak +
        '  FBackupTargetDir := Ini.ReadString(''SCHEDULE'', ''TargetDir'', ''./backups'');';
      LConfigSave :=
        '  Ini.WriteString(''SCHEDULE'', ''DailyExecutionTime'', FScheduleTime);' + sLineBreak +
        '  Ini.WriteString(''SCHEDULE'', ''TargetDir'', FBackupTargetDir);';
    end;

    akQueueWorker:
    begin
      LConfigFields :=
        '    FQueueBatchSize: Integer;' + sLineBreak +
        '    FMaxWorkers: Integer;' + sLineBreak;
      LConfigProps :=
        '    property QueueBatchSize: Integer read FQueueBatchSize;' + sLineBreak +
        '    property MaxWorkers: Integer read FMaxWorkers;' + sLineBreak;
      LConfigLoad :=
        '  FQueueBatchSize := Ini.ReadInteger(''QUEUE'', ''BatchSize'', 100);' + sLineBreak +
        '  FMaxWorkers := Ini.ReadInteger(''QUEUE'', ''MaxWorkers'', 4);';
      LConfigSave :=
        '  Ini.WriteInteger(''QUEUE'', ''BatchSize'', FQueueBatchSize);' + sLineBreak +
        '  Ini.WriteInteger(''QUEUE'', ''MaxWorkers'', FMaxWorkers);';
    end;
  end;

  S :=
    'unit uConfig;' + sLineBreak +
    '' + sLineBreak +
    '{$mode objfpc}{$H+}' + sLineBreak +
    '{$CODEPAGE UTF8}' + sLineBreak +
    '' + sLineBreak +
    'interface' + sLineBreak +
    '' + sLineBreak +
    'uses' + sLineBreak +
    '  SysUtils, Classes, IniFiles, SyncObjs;' + sLineBreak +
    '' + sLineBreak +
    'type' + sLineBreak +
    '  { TAppConfig: Gerenciador de configuracao do servico (.ini) }' + sLineBreak +
    '  TAppConfig = class' + sLineBreak +
    '  private' + sLineBreak +
    '    FLock: TCriticalSection;' + sLineBreak +
    '    FIniFileName: string;' + sLineBreak +
    '    FPollingIntervalMs: Cardinal;' + sLineBreak +
    '    FLogLevel: string;' + sLineBreak +
    LConfigFields +
    '    procedure EnsureDefaultsCreated(const AIniPath: string);' + sLineBreak +
    '    class var FInstance: TAppConfig;' + sLineBreak +
    '  public' + sLineBreak +
    '    constructor Create;' + sLineBreak +
    '    destructor Destroy; override;' + sLineBreak +
    '    class function Instance: TAppConfig;' + sLineBreak +
    '    class procedure ReleaseInstance;' + sLineBreak +
    '    procedure Reload;' + sLineBreak +
    '    property IniFileName: string read FIniFileName;' + sLineBreak +
    '    property PollingIntervalMs: Cardinal read FPollingIntervalMs;' + sLineBreak +
    '    property LogLevel: string read FLogLevel;' + sLineBreak +
    LConfigProps +
    '  end;' + sLineBreak +
    '' + sLineBreak +
    'implementation' + sLineBreak +
    '' + sLineBreak +
    '{ TAppConfig }' + sLineBreak +
    '' + sLineBreak +
    'constructor TAppConfig.Create;' + sLineBreak +
    'begin' + sLineBreak +
    '  inherited Create;' + sLineBreak +
    '  FLock := TCriticalSection.Create;' + sLineBreak +
    '  FIniFileName := ExtractFilePath(ParamStr(0)) + ''{{SERVICE_NAME}}.ini'';' + sLineBreak +
    '  FPollingIntervalMs := {{INTERVAL_MS}};' + sLineBreak +
    '  FLogLevel := ''INFO'';' + sLineBreak +
    '  EnsureDefaultsCreated(FIniFileName);' + sLineBreak +
    '  Reload;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'destructor TAppConfig.Destroy;' + sLineBreak +
    'begin' + sLineBreak +
    '  FreeAndNil(FLock);' + sLineBreak +
    '  inherited Destroy;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'class function TAppConfig.Instance: TAppConfig;' + sLineBreak +
    'begin' + sLineBreak +
    '  if not Assigned(FInstance) then' + sLineBreak +
    '    FInstance := TAppConfig.Create;' + sLineBreak +
    '  Result := FInstance;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'class procedure TAppConfig.ReleaseInstance;' + sLineBreak +
    'begin' + sLineBreak +
    '  FreeAndNil(FInstance);' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'procedure TAppConfig.EnsureDefaultsCreated(const AIniPath: string);' + sLineBreak +
    'var' + sLineBreak +
    '  Ini: TIniFile;' + sLineBreak +
    'begin' + sLineBreak +
    '  if not FileExists(AIniPath) then' + sLineBreak +
    '  begin' + sLineBreak +
    '    Ini := TIniFile.Create(AIniPath);' + sLineBreak +
    '    try' + sLineBreak +
    '      Ini.WriteInteger(''SERVICE'', ''PollingIntervalMs'', {{INTERVAL_MS}});' + sLineBreak +
    '      Ini.WriteString(''SERVICE'', ''LogLevel'', ''INFO'');' + sLineBreak +
    LConfigSave + sLineBreak +
    '    finally' + sLineBreak +
    '      FreeAndNil(Ini);' + sLineBreak +
    '    end;' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'procedure TAppConfig.Reload;' + sLineBreak +
    'var' + sLineBreak +
    '  Ini: TIniFile;' + sLineBreak +
    'begin' + sLineBreak +
    '  FLock.Enter;' + sLineBreak +
    '  try' + sLineBreak +
    '    if FileExists(FIniFileName) then' + sLineBreak +
    '    begin' + sLineBreak +
    '      Ini := TIniFile.Create(FIniFileName);' + sLineBreak +
    '      try' + sLineBreak +
    '        FPollingIntervalMs := Ini.ReadInteger(''SERVICE'', ''PollingIntervalMs'', {{INTERVAL_MS}});' + sLineBreak +
    '        FLogLevel := Ini.ReadString(''SERVICE'', ''LogLevel'', ''INFO'');' + sLineBreak +
    LConfigLoad + sLineBreak +
    '      finally' + sLineBreak +
    '        FreeAndNil(Ini);' + sLineBreak +
    '      end;' + sLineBreak +
    '    end;' + sLineBreak +
    '  finally' + sLineBreak +
    '    FLock.Leave;' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    '' + sLineBreak +
    'initialization' + sLineBreak +
    '' + sLineBreak +
    'finalization' + sLineBreak +
    '  TAppConfig.ReleaseInstance;' + sLineBreak +
    '' + sLineBreak +
    'end.' + sLineBreak;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateIni(const AConfig: TWizardConfig): string;
var
  S, LArchetypeSection: string;
begin
  case AConfig.Archetype of
    akDatabasePool:
      LArchetypeSection :=
        '[DATABASE]' + sLineBreak +
        '; Host do banco de dados' + sLineBreak +
        'Host=127.0.0.1' + sLineBreak +
        '; Porta do servico' + sLineBreak +
        'Port=3050' + sLineBreak +
        '; Caminho ou alias do banco' + sLineBreak +
        'Database=meu_banco.fdb' + sLineBreak +
        '; Credenciais de conexao' + sLineBreak +
        'User=SYSDBA' + sLineBreak +
        'Password=masterkey' + sLineBreak;

    akDirectoryMonitor:
      LArchetypeSection :=
        '[MONITOR]' + sLineBreak +
        '; Pasta monitorada para entrada de arquivos' + sLineBreak +
        'InboxPath=./inbox' + sLineBreak +
        '; Pasta de destino de arquivos processados' + sLineBreak +
        'OutboxPath=./outbox' + sLineBreak +
        '; Pasta para arquivos com falha' + sLineBreak +
        'ErrorPath=./error' + sLineBreak;

    akHttpMicroservice:
      LArchetypeSection :=
        '[HTTP]' + sLineBreak +
        '; Porta TCP para o servidor HTTP' + sLineBreak +
        'Port=8080' + sLineBreak +
        '; Endereco de bind (0.0.0.0 = todas as interfaces)' + sLineBreak +
        'BindAddress=0.0.0.0' + sLineBreak;

    akTaskScheduler:
      LArchetypeSection :=
        '[SCHEDULE]' + sLineBreak +
        '; Horario diario de execucao (formato hh:nn:ss)' + sLineBreak +
        'DailyExecutionTime=02:00:00' + sLineBreak +
        '; Pasta de destino para o backup/tarefa' + sLineBreak +
        'TargetDir=./backups' + sLineBreak;

    akQueueWorker:
      LArchetypeSection :=
        '[QUEUE]' + sLineBreak +
        '; Quantidade de mensagens processadas por lote' + sLineBreak +
        'BatchSize=100' + sLineBreak +
        '; Limite de workers concorrentes' + sLineBreak +
        'MaxWorkers=4' + sLineBreak;
  end;

  S :=
    '; ===========================================================================' + sLineBreak +
    '; Arquivo de Configuracao do Servico: {{SERVICE_NAME}}' + sLineBreak +
    '; Gerado pela Fabrica de Servicos Cross-Platform (Lazarus / Free Pascal)' + sLineBreak +
    '; ===========================================================================' + sLineBreak +
    '' + sLineBreak +
    '[SERVICE]' + sLineBreak +
    '; Intervalo de execucao da thread em milissegundos' + sLineBreak +
    'PollingIntervalMs={{INTERVAL_MS}}' + sLineBreak +
    '; Nivel de log: DEBUG, INFO, WARN, ERROR' + sLineBreak +
    'LogLevel=INFO' + sLineBreak +
    '' + sLineBreak +
    LArchetypeSection;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateSystemdService(const AConfig: TWizardConfig): string;
var
  S: string;
begin
  S :=
    '[Unit]' + sLineBreak +
    'Description={{DISPLAY_NAME}}' + sLineBreak +
    'After={{SYSTEMD_AFTER}}' + sLineBreak +
    'Wants={{SYSTEMD_WANTS}}' + sLineBreak +
    '' + sLineBreak +
    '[Service]' + sLineBreak +
    'Type=simple' + sLineBreak +
    'ExecStart=/usr/local/bin/{{SERVICE_NAME}}' + sLineBreak +
    'Restart={{SYSTEMD_RESTART}}' + sLineBreak +
    'RestartSec={{RESTART_SEC}}s' + sLineBreak +
    'User={{LINUX_USER}}' + sLineBreak +
    'StandardOutput=journal' + sLineBreak +
    'StandardError=journal' + sLineBreak +
    'KillMode=process' + sLineBreak +
    '' + sLineBreak +
    '[Install]' + sLineBreak +
    'WantedBy=multi-user.target' + sLineBreak;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateInstallBat(const AConfig: TWizardConfig): string;
var
  S: string;
begin
  S :=
    '@echo off' + sLineBreak +
    'chcp 65001 >nul' + sLineBreak +
    'title Instalador do Servico {{SERVICE_NAME}}' + sLineBreak +
    '' + sLineBreak +
    ':: Auto-elevacao de Administrador (UAC)' + sLineBreak +
    'net session >nul 2>&1' + sLineBreak +
    'if %errorLevel% neq 0 (' + sLineBreak +
    '    echo ====================================================================' + sLineBreak +
    '    echo Solicitando privilegios de Administrador para registro do servico...' + sLineBreak +
    '    echo ====================================================================' + sLineBreak +
    '    powershell -Command "Start-Process ''%~f0'' -Verb RunAs"' + sLineBreak +
    '    exit /b' + sLineBreak +
    ')' + sLineBreak +
    '' + sLineBreak +
    'cd /d "%~dp0"' + sLineBreak +
    'set "BIN_PATH=%~dp0{{SERVICE_NAME}}.exe"' + sLineBreak +
    '' + sLineBreak +
    'if not exist "%BIN_PATH%" (' + sLineBreak +
    '    echo [ERRO] O executavel "%BIN_PATH%" nao foi encontrado!' + sLineBreak +
    '    echo Compile o projeto no Lazarus antes de executar este instalador.' + sLineBreak +
    '    pause' + sLineBreak +
    '    exit /b 1' + sLineBreak +
    ')' + sLineBreak +
    '' + sLineBreak +
    'echo [1/3] Registrando servico "{{SERVICE_NAME}}" no Windows SCM...' + sLineBreak +
    'sc.exe create "{{SERVICE_NAME}}" binPath= "\"%BIN_PATH%\"" start= auto DisplayName= "{{DISPLAY_NAME}}" {{SC_DEPEND}}' + sLineBreak +
    'if %errorLevel% neq 0 (' + sLineBreak +
    '    echo [ERRO] Falha ao registrar o servico no SCM.' + sLineBreak +
    '    pause' + sLineBreak +
    '    exit /b %errorLevel%' + sLineBreak +
    ')' + sLineBreak +
    '' + sLineBreak +
    'echo [2/3] Configurando descricao do servico...' + sLineBreak +
    'sc.exe description "{{SERVICE_NAME}}" "{{DESCRIPTION}}"' + sLineBreak +
    '' + sLineBreak +
    'echo [3/3] Iniciando o servico...' + sLineBreak +
    'sc.exe start "{{SERVICE_NAME}}"' + sLineBreak +
    '' + sLineBreak +
    'echo ====================================================================' + sLineBreak +
    'echo Servico "{{SERVICE_NAME}}" instalado e iniciado com sucesso!' + sLineBreak +
    'echo ====================================================================' + sLineBreak +
    'pause' + sLineBreak;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateUninstallBat(const AConfig: TWizardConfig): string;
var
  S: string;
begin
  S :=
    '@echo off' + sLineBreak +
    'chcp 65001 >nul' + sLineBreak +
    'title Desinstalador do Servico {{SERVICE_NAME}}' + sLineBreak +
    '' + sLineBreak +
    ':: Auto-elevacao de Administrador (UAC)' + sLineBreak +
    'net session >nul 2>&1' + sLineBreak +
    'if %errorLevel% neq 0 (' + sLineBreak +
    '    powershell -Command "Start-Process ''%~f0'' -Verb RunAs"' + sLineBreak +
    '    exit /b' + sLineBreak +
    ')' + sLineBreak +
    '' + sLineBreak +
    'echo [1/2] Parando o servico "{{SERVICE_NAME}}"...' + sLineBreak +
    'sc.exe stop "{{SERVICE_NAME}}"' + sLineBreak +
    'timeout /t 3 /nobreak >nul' + sLineBreak +
    '' + sLineBreak +
    'echo [2/2] Removendo o servico "{{SERVICE_NAME}}" do sistema...' + sLineBreak +
    'sc.exe delete "{{SERVICE_NAME}}"' + sLineBreak +
    '' + sLineBreak +
    'echo ====================================================================' + sLineBreak +
    'echo Servico "{{SERVICE_NAME}}" removido com sucesso!' + sLineBreak +
    'echo ====================================================================' + sLineBreak +
    'pause' + sLineBreak;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateInstallSh(const AConfig: TWizardConfig): string;
var
  S: string;
begin
  S :=
    '#!/bin/bash' + sLineBreak +
    '# Script de Instalacao do Servico {{SERVICE_NAME}} no Linux Systemd' + sLineBreak +
    '' + sLineBreak +
    'if [ "$EUID" -ne 0 ]; then' + sLineBreak +
    '  echo "Por favor, execute como root ou utilize: sudo $0"' + sLineBreak +
    '  exit 1' + sLineBreak +
    'fi' + sLineBreak +
    '' + sLineBreak +
    'SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"' + sLineBreak +
    'BIN_SOURCE="$SCRIPT_DIR/{{SERVICE_NAME}}"' + sLineBreak +
    'BIN_DEST="/usr/local/bin/{{SERVICE_NAME}}"' + sLineBreak +
    'SERVICE_FILE="/etc/systemd/system/{{SERVICE_NAME}}.service"' + sLineBreak +
    '' + sLineBreak +
    'if [ ! -f "$BIN_SOURCE" ]; then' + sLineBreak +
    '  echo "[ERRO] Executavel $BIN_SOURCE nao encontrado! Compile no Lazarus primeiro."' + sLineBreak +
    '  exit 1' + sLineBreak +
    'fi' + sLineBreak +
    '' + sLineBreak +
    'echo "[1/4] Copiando binario para $BIN_DEST..."' + sLineBreak +
    'cp "$BIN_SOURCE" "$BIN_DEST"' + sLineBreak +
    'chmod +x "$BIN_DEST"' + sLineBreak +
    '' + sLineBreak +
    'echo "[2/4] Instalando arquivo de servico em $SERVICE_FILE..."' + sLineBreak +
    'cp "$SCRIPT_DIR/{{SERVICE_NAME}}.service" "$SERVICE_FILE"' + sLineBreak +
    '' + sLineBreak +
    'echo "[3/4] Recarregando Systemd..."' + sLineBreak +
    'systemctl daemon-reload' + sLineBreak +
    '' + sLineBreak +
    'echo "[4/4] Habilitando e iniciando servico {{SERVICE_NAME}}..."' + sLineBreak +
    'systemctl enable {{SERVICE_NAME}}' + sLineBreak +
    'systemctl start {{SERVICE_NAME}}' + sLineBreak +
    '' + sLineBreak +
    'echo "====================================================================="' + sLineBreak +
    'echo "Servico {{SERVICE_NAME}} instalado e ativo com sucesso no Linux!"' + sLineBreak +
    'echo "Verifique o status com: systemctl status {{SERVICE_NAME}}"' + sLineBreak +
    'echo "====================================================================="' + sLineBreak;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateRemoveSh(const AConfig: TWizardConfig): string;
var
  S: string;
begin
  S :=
    '#!/bin/bash' + sLineBreak +
    '# Script de Remocao do Servico {{SERVICE_NAME}}' + sLineBreak +
    '' + sLineBreak +
    'if [ "$EUID" -ne 0 ]; then' + sLineBreak +
    '  echo "Por favor, execute como root ou utilize: sudo $0"' + sLineBreak +
    '  exit 1' + sLineBreak +
    'fi' + sLineBreak +
    '' + sLineBreak +
    'echo "[1/4] Parando servico {{SERVICE_NAME}}..."' + sLineBreak +
    'systemctl stop {{SERVICE_NAME}} 2>/dev/null' + sLineBreak +
    '' + sLineBreak +
    'echo "[2/4] Desabilitando servico do boot..."' + sLineBreak +
    'systemctl disable {{SERVICE_NAME}} 2>/dev/null' + sLineBreak +
    '' + sLineBreak +
    'echo "[3/4] Removendo arquivo de servico..."' + sLineBreak +
    'rm -f "/etc/systemd/system/{{SERVICE_NAME}}.service"' + sLineBreak +
    'systemctl daemon-reload' + sLineBreak +
    '' + sLineBreak +
    'echo "[4/4] Removendo binario de /usr/local/bin/{{SERVICE_NAME}}..."' + sLineBreak +
    'rm -f "/usr/local/bin/{{SERVICE_NAME}}"' + sLineBreak +
    '' + sLineBreak +
    'echo "====================================================================="' + sLineBreak +
    'echo "Servico {{SERVICE_NAME}} removido com sucesso!"' + sLineBreak +
    'echo "====================================================================="' + sLineBreak;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateStatusSh(const AConfig: TWizardConfig): string;
var
  S: string;
begin
  S :=
    '#!/bin/bash' + sLineBreak +
    'echo "=== STATUS DO SERVICO {{SERVICE_NAME}} ==="' + sLineBreak +
    'systemctl status {{SERVICE_NAME}}' + sLineBreak;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateViewLogsSh(const AConfig: TWizardConfig): string;
var
  S: string;
begin
  S :=
    '#!/bin/bash' + sLineBreak +
    'echo "=== EXIBINDO ULTIMOS LOGS DO SERVICO {{SERVICE_NAME}} (Ctrl+C para sair) ==="' + sLineBreak +
    'journalctl -u {{SERVICE_NAME}} -f -n 50' + sLineBreak;

  Result := ReplaceTags(S, AConfig);
end;

class function TTemplateEngine.GenerateProject(const AConfig: TWizardConfig; out AErrorMsg: string): Boolean;
var
  LDir, LFile: string;

  procedure SaveText(const AFileName, AContent: string);
  var
    SL: TStringList;
  begin
    SL := TStringList.Create;
    try
      SL.Text := AContent;
      SL.SaveToFile(AFileName);
    finally
      FreeAndNil(SL);
    end;
  end;

begin
  Result := False;
  AErrorMsg := '';

  if Trim(AConfig.ServiceName) = '' then
  begin
    AErrorMsg := 'O nome do serviço não pode ficar vazio.';
    Exit;
  end;

  if Trim(AConfig.OutputDir) = '' then
  begin
    AErrorMsg := 'O diretório de saída não foi especificado.';
    Exit;
  end;

  try
    LDir := IncludeTrailingPathDelimiter(AConfig.OutputDir);
    if not ForceDirectories(LDir) then
    begin
      AErrorMsg := 'Não foi possível criar o diretório: ' + LDir;
      Exit;
    end;

    // 1. .lpr
    LFile := LDir + AConfig.ServiceName + '.lpr';
    SaveText(LFile, GenerateLpr(AConfig));

    // 2. .lpi
    LFile := LDir + AConfig.ServiceName + '.lpi';
    SaveText(LFile, GenerateLpi(AConfig));

    // 3. uServiceCore.pas
    LFile := LDir + 'uServiceCore.pas';
    SaveText(LFile, GenerateServiceCore(AConfig));

    // 4. uWorker.pas
    LFile := LDir + 'uWorker.pas';
    SaveText(LFile, GenerateWorker(AConfig));

    // 5. uConfig.pas
    if AConfig.UseIniConfig then
    begin
      LFile := LDir + 'uConfig.pas';
      SaveText(LFile, GenerateConfig(AConfig));

      LFile := LDir + AConfig.ServiceName + '.ini';
      SaveText(LFile, GenerateIni(AConfig));
    end;

    // 6. Scripts Windows
    if AConfig.TargetPlatform in [tpWindows, tpHybrid] then
    begin
      LFile := LDir + 'instalar.bat';
      SaveText(LFile, GenerateInstallBat(AConfig));

      LFile := LDir + 'desinstalar.bat';
      SaveText(LFile, GenerateUninstallBat(AConfig));
    end;

    // 7. Scripts Linux e Unit Systemd
    if AConfig.TargetPlatform in [tpLinux, tpHybrid] then
    begin
      LFile := LDir + AConfig.ServiceName + '.service';
      SaveText(LFile, GenerateSystemdService(AConfig));

      LFile := LDir + 'instalar.sh';
      SaveText(LFile, GenerateInstallSh(AConfig));

      LFile := LDir + 'remover.sh';
      SaveText(LFile, GenerateRemoveSh(AConfig));

      LFile := LDir + 'status.sh';
      SaveText(LFile, GenerateStatusSh(AConfig));

      LFile := LDir + 'ver_logs.sh';
      SaveText(LFile, GenerateViewLogsSh(AConfig));
    end;

    Result := True;
  except
    on E: Exception do
      AErrorMsg := E.Message;
  end;
end;

end.

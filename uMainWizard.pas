unit uMainWizard;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, StdCtrls,
  ExtCtrls, Spin, EditBtn, LCLIntf,
  uTemplateEngine;

type
  { TMainWizardForm }
  TMainWizardForm = class(TForm)
    pnlHeader: TPanel;
    lblTitle: TLabel;
    lblSubtitle: TLabel;
    pnlStepsBar: TPanel;
    lblStepBadge1: TLabel;
    lblStepBadge2: TLabel;
    lblStepBadge3: TLabel;
    lblStepBadge4: TLabel;
    lblStepBadge5: TLabel;

    pgControl: TPageControl;

    { Etapa 1: Identificação & Diretórios }
    tabStep1: TTabSheet;
    grpIdent: TGroupBox;
    lblServiceName: TLabel;
    edtServiceName: TEdit;
    lblDisplayName: TLabel;
    edtDisplayName: TEdit;
    lblDescription: TLabel;
    edtDescription: TEdit;
    grpPlatform: TGroupBox;
    rbPlatformHybrid: TRadioButton;
    rbPlatformWindows: TRadioButton;
    rbPlatformLinux: TRadioButton;
    grpOutputDir: TGroupBox;
    lblOutputDir: TLabel;
    dirOutputDir: TDirectoryEdit;

    { Etapa 2: Arquétipo de Tarefa }
    tabStep2: TTabSheet;
    grpArchetype: TGroupBox;
    rbArchDbPool: TRadioButton;
    lblArchDbPoolDesc: TLabel;
    rbArchDirMonitor: TRadioButton;
    lblArchDirMonitorDesc: TLabel;
    rbArchHttp: TRadioButton;
    lblArchHttpDesc: TLabel;
    rbArchScheduler: TRadioButton;
    lblArchSchedulerDesc: TLabel;
    rbArchQueue: TRadioButton;
    lblArchQueueDesc: TLabel;

    { Etapa 3: Frequência, Timer e Parâmetros }
    tabStep3: TTabSheet;
    grpFrequency: TGroupBox;
    lblInterval: TLabel;
    seInterval: TSpinEdit;
    cmbIntervalUnit: TComboBox;
    grpConfigOptions: TGroupBox;
    chkUseIni: TCheckBox;
    chkSighup: TCheckBox;
    chkDebugMode: TCheckBox;

    { Etapa 4: Sistema Operacional & Infraestrutura }
    tabStep4: TTabSheet;
    grpFailures: TGroupBox;
    chkRestartOnFail: TCheckBox;
    lblRestartDelay: TLabel;
    seRestartDelay: TSpinEdit;
    grpLinuxAndDeps: TGroupBox;
    lblLinuxUser: TLabel;
    edtLinuxUser: TEdit;
    chkWaitNetwork: TCheckBox;
    chkWaitDatabase: TCheckBox;
    cmbDatabaseType: TComboBox;
    grpLogging: TGroupBox;
    chkLogFile: TCheckBox;
    chkLogJournal: TCheckBox;
    chkLogEventLog: TCheckBox;
    chkHeapTrc: TCheckBox;

    { Etapa 5: Resumo, Pré-Visualização e Geração }
    tabStep5: TTabSheet;
    pnlSummary: TPanel;
    mmoSummary: TMemo;
    pnlPreviewTop: TPanel;
    lblPreviewFile: TLabel;
    cmbPreviewFile: TComboBox;
    btnRefreshPreview: TButton;
    mmoPreview: TMemo;

    { Barra Inferior }
    pnlBottom: TPanel;
    btnCancel: TButton;
    lblValidationMsg: TLabel;
    btnBack: TButton;
    btnNext: TButton;
    btnFinish: TButton;

    procedure FormCreate(Sender: TObject);
    procedure edtServiceNameChange(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnBackClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnFinishClick(Sender: TObject);
    procedure chkWaitDatabaseChange(Sender: TObject);
    procedure chkUseIniChange(Sender: TObject);
    procedure cmbPreviewFileChange(Sender: TObject);
    procedure btnRefreshPreviewClick(Sender: TObject);
  private
    function IsValidIdentifier(const AName: string): Boolean;
    function ValidateCurrentStep(const AStepIndex: Integer; out AErrorMsg: string): Boolean;
    procedure UpdateStepUI;
    function BuildConfigFromUI: TWizardConfig;
    procedure RefreshSummaryAndPreview;
  public
  end;

var
  MainWizardForm: TMainWizardForm;

implementation

{$R *.lfm}

{ TMainWizardForm }

procedure TMainWizardForm.FormCreate(Sender: TObject);
var
  LBaseDir: string;
begin
  LBaseDir := ExtractFilePath(ParamStr(0));
  if not DirectoryExists(LBaseDir) then
    LBaseDir := 'd:\Fontes Lazarus\Fabrica de Seriços\Lazarus\';

  dirOutputDir.Directory := IncludeTrailingPathDelimiter(LBaseDir) + 'ProjetosGerados' + PathDelim + 'SyncVendasSvc';
  cmbIntervalUnit.ItemIndex := 0; // Segundos
  cmbDatabaseType.ItemIndex := 0; // Firebird
  cmbPreviewFile.ItemIndex := 0;

  pgControl.ShowTabs := False;
  pgControl.ActivePageIndex := 0;
  UpdateStepUI;
end;

procedure TMainWizardForm.edtServiceNameChange(Sender: TObject);
var
  LName: string;
begin
  LName := Trim(edtServiceName.Text);
  if LName <> '' then
  begin
    edtDisplayName.Text := 'Serviço ' + LName;
    dirOutputDir.Directory := ExtractFilePath(ExcludeTrailingPathDelimiter(dirOutputDir.Directory)) + LName;
  end;
end;

procedure TMainWizardForm.chkWaitDatabaseChange(Sender: TObject);
begin
  cmbDatabaseType.Enabled := chkWaitDatabase.Checked;
end;

procedure TMainWizardForm.chkUseIniChange(Sender: TObject);
begin
  chkSighup.Enabled := chkUseIni.Checked;
end;

function TMainWizardForm.IsValidIdentifier(const AName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  if Length(AName) = 0 then
    Exit;

  // Primeiro caractere deve ser letra ou underscore
  if not (AName[1] in ['a'..'z', 'A'..'Z', '_']) then
    Exit;

  // Demais caracteres devem ser alfanuméricos ou underscore
  for I := 2 to Length(AName) do
    if not (AName[I] in ['a'..'z', 'A'..'Z', '0'..'9', '_']) then
      Exit;

  Result := True;
end;

function TMainWizardForm.ValidateCurrentStep(const AStepIndex: Integer; out AErrorMsg: string): Boolean;
var
  LName: string;
begin
  Result := True;
  AErrorMsg := '';

  case AStepIndex of
    0: // Etapa 1
    begin
      LName := Trim(edtServiceName.Text);
      if LName = '' then
      begin
        AErrorMsg := 'Informe o Nome do Serviço.';
        Result := False;
        Exit;
      end;

      if not IsValidIdentifier(LName) then
      begin
        AErrorMsg := 'O Nome do Serviço deve ser um identificador válido (sem espaços ou caracteres especiais).';
        Result := False;
        Exit;
      end;

      if Trim(dirOutputDir.Directory) = '' then
      begin
        AErrorMsg := 'Selecione a Pasta de Destino do projeto.';
        Result := False;
        Exit;
      end;
    end;

    1: // Etapa 2: Arquétipo
    begin
      if not (rbArchDbPool.Checked or rbArchDirMonitor.Checked or
              rbArchHttp.Checked or rbArchScheduler.Checked or rbArchQueue.Checked) then
      begin
        AErrorMsg := 'Selecione um Arquétipo de Tarefa para o serviço.';
        Result := False;
        Exit;
      end;
    end;

    2: // Etapa 3: Frequência
    begin
      if seInterval.Value <= 0 then
      begin
        AErrorMsg := 'O intervalo de execução deve ser maior que zero.';
        Result := False;
        Exit;
      end;
    end;

    3: // Etapa 4: Infra
    begin
      if Trim(edtLinuxUser.Text) = '' then
      begin
        AErrorMsg := 'Informe o Usuário de Execução no Linux (ex: root ou www-data).';
        Result := False;
        Exit;
      end;
    end;
  end;
end;

procedure TMainWizardForm.UpdateStepUI;
var
  LIdx: Integer;
begin
  LIdx := pgControl.ActivePageIndex;

  // Visibilidade de botões
  btnBack.Enabled := (LIdx > 0);
  btnNext.Visible := (LIdx < 4);
  btnFinish.Visible := (LIdx = 4);
  lblValidationMsg.Caption := '';

  // Destaque visual dos Badges
  lblStepBadge1.Font.Style := [];
  lblStepBadge2.Font.Style := [];
  lblStepBadge3.Font.Style := [];
  lblStepBadge4.Font.Style := [];
  lblStepBadge5.Font.Style := [];

  lblStepBadge1.Font.Color := clGray;
  lblStepBadge2.Font.Color := clGray;
  lblStepBadge3.Font.Color := clGray;
  lblStepBadge4.Font.Color := clGray;
  lblStepBadge5.Font.Color := clGray;

  case LIdx of
    0:
    begin
      lblStepBadge1.Font.Style := [fsBold];
      lblStepBadge1.Font.Color := $00C05000;
      lblSubtitle.Caption := 'Etapa 1 de 5: Identificação do serviço, exibição e plataforma de destino.';
    end;
    1:
    begin
      lblStepBadge2.Font.Style := [fsBold];
      lblStepBadge2.Font.Color := $00C05000;
      lblSubtitle.Caption := 'Etapa 2 de 5: Selecione o arquétipo de trabalho especializado do serviço.';
    end;
    2:
    begin
      lblStepBadge3.Font.Style := [fsBold];
      lblStepBadge3.Font.Color := $00C05000;
      lblSubtitle.Caption := 'Etapa 3 de 5: Frequência do loop, recarregamento automático e modo /debug.';
    end;
    3:
    begin
      lblStepBadge4.Font.Style := [fsBold];
      lblStepBadge4.Font.Color := $00C05000;
      lblSubtitle.Caption := 'Etapa 4 de 5: Comportamento em falhas, dependências de boot e logs.';
    end;
    4:
    begin
      lblStepBadge5.Font.Style := [fsBold];
      lblStepBadge5.Font.Color := $00C05000;
      lblSubtitle.Caption := 'Etapa 5 de 5: Pré-visualização do código e geração completa do projeto.';
      RefreshSummaryAndPreview;
    end;
  end;
end;

function TMainWizardForm.BuildConfigFromUI: TWizardConfig;
var
  C: TWizardConfig;
begin
  C := TWizardConfig.Create;

  // Etapa 1
  C.ServiceName := Trim(edtServiceName.Text);
  C.DisplayName := Trim(edtDisplayName.Text);
  C.Description := Trim(edtDescription.Text);
  C.OutputDir := dirOutputDir.Directory;

  if rbPlatformWindows.Checked then
    C.TargetPlatform := tpWindows
  else if rbPlatformLinux.Checked then
    C.TargetPlatform := tpLinux
  else
    C.TargetPlatform := tpHybrid;

  // Etapa 2
  if rbArchDbPool.Checked then
    C.Archetype := akDatabasePool
  else if rbArchDirMonitor.Checked then
    C.Archetype := akDirectoryMonitor
  else if rbArchHttp.Checked then
    C.Archetype := akHttpMicroservice
  else if rbArchScheduler.Checked then
    C.Archetype := akTaskScheduler
  else
    C.Archetype := akQueueWorker;

  // Etapa 3
  C.IntervalValue := seInterval.Value;
  case cmbIntervalUnit.ItemIndex of
    0: C.IntervalUnit := iuSeconds;
    1: C.IntervalUnit := iuMilliseconds;
    2: C.IntervalUnit := iuMinutes;
  else
    C.IntervalUnit := iuSeconds;
  end;
  C.UseIniConfig := chkUseIni.Checked;
  C.EnableSighupReload := chkSighup.Checked;
  C.EnableDebugMode := chkDebugMode.Checked;

  // Etapa 4
  C.RestartOnFailure := chkRestartOnFail.Checked;
  C.RestartDelaySec := seRestartDelay.Value;
  C.LinuxUser := Trim(edtLinuxUser.Text);
  C.WaitNetwork := chkWaitNetwork.Checked;
  C.WaitDatabase := chkWaitDatabase.Checked;
  case cmbDatabaseType.ItemIndex of
    0: C.DatabaseType := 'firebird';
    1: C.DatabaseType := 'postgresql';
    2: C.DatabaseType := 'mysql';
  else
    C.DatabaseType := 'firebird';
  end;
  C.LogLocalFile := chkLogFile.Checked;
  C.LogSystemdJournal := chkLogJournal.Checked;
  C.LogWindowsEventLog := chkLogEventLog.Checked;
  C.EnableHeapTrc := chkHeapTrc.Checked;

  Result := C;
end;

procedure TMainWizardForm.RefreshSummaryAndPreview;
var
  C: TWizardConfig;
begin
  C := BuildConfigFromUI;
  try
    mmoSummary.Clear;
    mmoSummary.Lines.Add('=== RESUMO DAS ESCOLHAS DO WIZARD ===');
    mmoSummary.Lines.Add('Nome do Serviço:   ' + C.ServiceName);
    mmoSummary.Lines.Add('Nome de Exibição:  ' + C.DisplayName);
    mmoSummary.Lines.Add('Plataforma:        ' + C.GetPlatformName);
    mmoSummary.Lines.Add('Arquétipo:         ' + C.GetArchetypeName);
    mmoSummary.Lines.Add('Intervalo de Loop: ' + IntToStr(C.GetIntervalMs) + ' ms');
    mmoSummary.Lines.Add('Leitor de .ini:    ' + BoolToStr(C.UseIniConfig, 'Sim (uConfig.pas)', 'Não'));
    mmoSummary.Lines.Add('Modo /debug:       ' + BoolToStr(C.EnableDebugMode, 'Ativo (Console Interativo)', 'Desativado'));
    mmoSummary.Lines.Add('Systemd Restart:   ' + BoolToStr(C.RestartOnFailure, 'always (' + IntToStr(C.RestartDelaySec) + 's)', 'no'));
    mmoSummary.Lines.Add('Aguardar Rede:     ' + BoolToStr(C.WaitNetwork, 'Sim (network-online.target / Tcpip)', 'Não'));
    mmoSummary.Lines.Add('Pasta de Destino:  ' + C.OutputDir);

    case cmbPreviewFile.ItemIndex of
      0: mmoPreview.Text := TTemplateEngine.GenerateLpr(C);
      1: mmoPreview.Text := TTemplateEngine.GenerateServiceCore(C);
      2: mmoPreview.Text := TTemplateEngine.GenerateWorker(C);
      3: mmoPreview.Text := TTemplateEngine.GenerateConfig(C);
      4: mmoPreview.Text := TTemplateEngine.GenerateIni(C);
      5: mmoPreview.Text := TTemplateEngine.GenerateSystemdService(C);
      6: mmoPreview.Text := TTemplateEngine.GenerateInstallBat(C);
      7: mmoPreview.Text := TTemplateEngine.GenerateInstallSh(C);
    end;
  finally
    FreeAndNil(C);
  end;
end;

procedure TMainWizardForm.btnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TMainWizardForm.btnBackClick(Sender: TObject);
begin
  if pgControl.ActivePageIndex > 0 then
  begin
    pgControl.ActivePageIndex := pgControl.ActivePageIndex - 1;
    UpdateStepUI;
  end;
end;

procedure TMainWizardForm.btnNextClick(Sender: TObject);
var
  LErr: string;
begin
  if not ValidateCurrentStep(pgControl.ActivePageIndex, LErr) then
  begin
    lblValidationMsg.Caption := LErr;
    Exit;
  end;

  if pgControl.ActivePageIndex < 4 then
  begin
    pgControl.ActivePageIndex := pgControl.ActivePageIndex + 1;
    UpdateStepUI;
  end;
end;

procedure TMainWizardForm.btnFinishClick(Sender: TObject);
var
  C: TWizardConfig;
  LErrorMsg: string;
begin
  C := BuildConfigFromUI;
  try
    lblValidationMsg.Font.Color := clNavy;
    lblValidationMsg.Caption := 'Gerando arquivos de produção do serviço...';
    Application.ProcessMessages;

    if TTemplateEngine.GenerateProject(C, LErrorMsg) then
    begin
      lblValidationMsg.Font.Color := clGreen;
      lblValidationMsg.Caption := 'Projeto gerado com sucesso em: ' + C.OutputDir;
      ShowMessage('Fábrica de Serviços Cross-Platform' + sLineBreak + sLineBreak +
                  'Projeto "' + C.ServiceName + '" gerado com SUCESSO!' + sLineBreak + sLineBreak +
                  'Destino: ' + C.OutputDir + sLineBreak + sLineBreak +
                  'Os fontes, arquivos de configuração (.ini), unit systemd e scripts com auto-elevação UAC foram criados.');

      if DirectoryExists(C.OutputDir) then
        OpenDocument(C.OutputDir);
    end
    else
    begin
      lblValidationMsg.Font.Color := clRed;
      lblValidationMsg.Caption := 'Erro na geração: ' + LErrorMsg;
      ShowMessage('Falha ao gerar o projeto de serviço:' + sLineBreak + LErrorMsg);
    end;
  finally
    FreeAndNil(C);
  end;
end;

procedure TMainWizardForm.cmbPreviewFileChange(Sender: TObject);
begin
  RefreshSummaryAndPreview;
end;

procedure TMainWizardForm.btnRefreshPreviewClick(Sender: TObject);
begin
  RefreshSummaryAndPreview;
end;

end.

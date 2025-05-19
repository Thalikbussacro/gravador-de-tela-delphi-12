
unit uFrmPrincipal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Winapi.ShellAPI, System.IOUtils, System.IniFiles, Vcl.FileCtrl,
  System.ImageList, Vcl.ImgList;

type
  TfrmPrincipal = class(TForm)
    Timer1: TTimer;
    dlgSelecionarPasta: TFileOpenDialog;
    TrayIcon1: TTrayIcon;
    GroupBox1: TGroupBox;
    btnSelecionarDiretorio: TButton;
    lbl1: TLabel;
    edtDiretorio: TEdit;
    lbl2: TLabel;
    edtTempoSegmento: TEdit;
    cboUnidadeTempoGravacao: TComboBox;
    Label2: TLabel;
    edtTempoManute: TEdit;
    cboUnidadeTempoManute: TComboBox;
    lblUltimaExecManute: TLabel;
    cbMonitor: TComboBox;
    lblMonitor: TLabel;
    GroupBox2: TGroupBox;
    btnGravar: TButton;
    lblStatus: TLabel;
    btnParar: TButton;
    ImageList1: TImageList;
    Label1: TLabel;
    edtPeriodicidadeManute: TEdit;
    cboUnidadeTempoPeriodicidadeManute: TComboBox;
    chkIniciaMinimizadoGravando: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure btnGravarClick(Sender: TObject);
    procedure btnPararClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btnSelecionarDiretorioClick(Sender: TObject);
    procedure edtTempoManuteKeyPress(Sender: TObject; var Key: Char);
    procedure edtTempoSegmentoKeyPress(Sender: TObject; var Key: Char);
    procedure TrayIcon1Click(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure edtPeriodicidadeManuteChange(Sender: TObject);
    procedure cboUnidadeTempoPeriodicidadeManuteChange(Sender: TObject);
    procedure edtPeriodicidadeManuteKeyPress(Sender: TObject; var Key: Char);
  private
    procedure IniciarGravacao;
    procedure PararGravacao;
    procedure ListarMonitores;
    procedure AtualizaStatus;
    procedure RealizaManutencaoArquivos;
    procedure CarregarConfiguracoes;
    procedure SalvarConfiguracoes;
    procedure AtualizaIntervaloTimer;
    procedure WndProc(var Msg: TMessage); override;
    function GetConfigFilePath: String;
    function TestaConfiguracoesBasicas: Boolean;
    var
      vGravando: Boolean;
      hProcess: THandle;
      hInputWrite: THandle;
  public
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

{$R *.dfm}

procedure TfrmPrincipal.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  if vGravando then
  begin
    if MessageDlg('Uma gravação está em andamento. Deseja realmente sair e interromper a gravação?',
                  mtConfirmation, [mbYes, mbNo], 0) = mrNo then
    begin
      Action := caNone; // Cancela o fechamento
      Exit;
    end;

    PararGravacao;
  end;

  AtualizaStatus;
  ForceDirectories(ExtractFilePath(GetConfigFilePath));
  SalvarConfiguracoes;
end;

procedure TfrmPrincipal.FormCreate(Sender: TObject);
begin
  CarregarConfiguracoes;
  ListarMonitores;

  // Aplica minimização se marcado
  if chkIniciaMinimizadoGravando.Checked and TestaConfiguracoesBasicas then
    PostMessage(Handle, WM_USER + 1, 0, 0) // posterga a minimização
  else
    chkIniciaMinimizadoGravando.Checked := False;

end;


procedure TfrmPrincipal.FormResize(Sender: TObject);
begin
  if WindowState = wsMinimized then
  begin
    Hide;
    TrayIcon1.Visible := True;
    TrayIcon1.ShowBalloonHint;
  end;
end;

procedure TfrmPrincipal.ListarMonitores;
var
  i: Integer;
begin
  cbMonitor.Items.Clear;
  for i := 0 to Screen.MonitorCount - 1 do
    cbMonitor.Items.Add(Format('Monitor %d (%d x %d)', [i + 1, Screen.Monitors[i].Width, Screen.Monitors[i].Height]));
  cbMonitor.ItemIndex := 0;
end;

procedure TfrmPrincipal.btnGravarClick(Sender: TObject);
begin
  IniciarGravacao;
  AtualizaStatus;
end;

procedure TfrmPrincipal.btnPararClick(Sender: TObject);
begin
  PararGravacao;
  AtualizaStatus;
end;

procedure TfrmPrincipal.btnSelecionarDiretorioClick(Sender: TObject);
begin
  if dlgSelecionarPasta.Execute then
    edtDiretorio.Text := IncludeTrailingPathDelimiter(dlgSelecionarPasta.FileName);
end;

procedure TfrmPrincipal.IniciarGravacao;
var
  CmdLine, NomeArquivo: string;
  TempoSegmento: Integer;
  MonitorIndex: Integer;
  OffsetX, OffsetY, Width, Height: Integer;
  si: STARTUPINFO;
  pi: PROCESS_INFORMATION;
  sa: SECURITY_ATTRIBUTES;
  hInputRead: THandle;
begin

  if not TestaConfiguracoesBasicas then
    Exit;

  ForceDirectories(edtDiretorio.Text);

  if cboUnidadeTempoGravacao.Text = 'Segundos' then
    TempoSegmento := StrToIntDef(edtTempoSegmento.Text, 5)
  else if cboUnidadeTempoGravacao.Text = 'Minutos' then
    TempoSegmento := StrToIntDef(edtTempoSegmento.Text, 5) * 60
  else if cboUnidadeTempoGravacao.Text = 'Horas' then
    TempoSegmento := StrToIntDef(edtTempoSegmento.Text, 5) * 3600;

  NomeArquivo := FormatDateTime('dd-mm-yyyy_HH-MM-SS', Now);

  MonitorIndex := cbMonitor.ItemIndex;
  if MonitorIndex < 0 then MonitorIndex := 0;

  OffsetX := Screen.Monitors[MonitorIndex].Left;
  OffsetY := Screen.Monitors[MonitorIndex].Top;
  Width := Screen.Monitors[MonitorIndex].Width;
  Height := Screen.Monitors[MonitorIndex].Height;

  CmdLine := Format(
    'ffmpeg.exe -f gdigrab -framerate 30 -offset_x %d -offset_y %d -video_size %dx%d ' +
    '-i desktop -c:v libx264 -preset ultrafast -f segment -segment_time %d ' +
    '-reset_timestamps 1 -force_key_frames "expr:gte(t,n_forced*%d)" "%s%s_%%03d.mkv"',
    [OffsetX, OffsetY, Width, Height, TempoSegmento, TempoSegmento, IncludeTrailingPathDelimiter(edtDiretorio.Text), NomeArquivo]
  );

  FillChar(sa, SizeOf(sa), 0);
  sa.nLength := SizeOf(sa);
  sa.bInheritHandle := True;

  if not CreatePipe(hInputRead, hInputWrite, @sa, 0) then
    RaiseLastOSError;

  FillChar(si, SizeOf(si), 0);
  si.cb := SizeOf(si);
  si.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  si.wShowWindow := SW_HIDE;
  si.hStdInput := hInputRead;
  si.hStdOutput := GetStdHandle(STD_OUTPUT_HANDLE);
  si.hStdError := GetStdHandle(STD_ERROR_HANDLE);

  if not CreateProcess(nil, PChar(CmdLine),
    nil, nil, True, CREATE_NO_WINDOW, nil, nil, si, pi) then
    RaiseLastOSError;

  hProcess := pi.hProcess;
  CloseHandle(pi.hThread);
  CloseHandle(hInputRead);

  vGravando := True;
end;


procedure TfrmPrincipal.PararGravacao;
var
  BytesWritten: DWORD;
  qChar: AnsiChar;
begin
  if vGravando and (hInputWrite <> 0) then
  begin
    qChar := 'q';
    WriteFile(hInputWrite, qChar, 1, BytesWritten, nil);
    FlushFileBuffers(hInputWrite);
    CloseHandle(hInputWrite);
    hInputWrite := 0;
  end;

  if hProcess <> 0 then
  begin
    WaitForSingleObject(hProcess, 5000);
    CloseHandle(hProcess);
    hProcess := 0;
  end;

  vGravando := False;
end;

procedure TfrmPrincipal.Timer1Timer(Sender: TObject);
begin
  RealizaManutencaoArquivos;
end;

procedure TfrmPrincipal.TrayIcon1Click(Sender: TObject);
begin
  Show;
  WindowState := wsNormal;
  TrayIcon1.Visible := False;
end;

procedure TfrmPrincipal.AtualizaStatus;
begin
  if vGravando then
  begin
    lblStatus.Caption := 'Gravando...';
    btnGravar.Enabled := False;
    btnParar.Enabled := True;
    GroupBox1.Enabled := False;

    // Atualiza ícones para "gravando"
    ImageList1.GetIcon(1, TrayIcon1.Icon);     // ícone da bandeja
    ImageList1.GetIcon(1, Application.Icon);   // ícone do formulário
    ImageList1.GetIcon(1, FrmPrincipal.Icon);   // ícone do formulário
  end
  else
  begin
    lblStatus.Caption := 'Parado';
    btnGravar.Enabled := True;
    btnParar.Enabled := False;
    GroupBox1.Enabled := True;

    // Atualiza ícones para "parado"
    ImageList1.GetIcon(0, TrayIcon1.Icon);     // ícone da bandeja
    ImageList1.GetIcon(0, Application.Icon);   // ícone do formulário
    ImageList1.GetIcon(0, FrmPrincipal.Icon);   // ícone do formulário
  end;
end;


procedure TfrmPrincipal.RealizaManutencaoArquivos;
var
  Arquivos: TArray<string>;
  Arquivo: string;
  Info: TSearchRec;
  Limite: TDateTime;
  Tempo: Integer;
begin
  if edtDiretorio.Text = '' then
    Exit;

  Tempo := StrToIntDef(edtTempoManute.Text, 0);
  if Tempo <= 0 then Exit;

  if cboUnidadeTempoManute.Text = 'Segundos' then
    Limite := Now - (Tempo / SecsPerDay)
  else if cboUnidadeTempoManute.Text = 'Minutos' then
    Limite := Now - (Tempo * 60 / SecsPerDay)
  else if cboUnidadeTempoManute.Text = 'Horas' then
    Limite := Now - (Tempo * 3600 / SecsPerDay)
  else if cboUnidadeTempoManute.Text = 'Dias' then
    Limite := Now - Tempo
  else
    Exit;

  Arquivos := TDirectory.GetFiles(edtDiretorio.Text, '*.mkv');
  for Arquivo in Arquivos do
  begin
    if FindFirst(Arquivo, faAnyFile, Info) = 0 then
    begin
      try
        if FileDateToDateTime(Info.Time) < Limite then
          DeleteFile(Arquivo);
      finally
        FindClose(Info);
      end;
    end;
  end;

  lblUltimaExecManute.Caption := 'Última limpeza: ' + FormatDateTime('dd/mm/yyyy hh:nn:ss', Now);
end;

procedure TfrmPrincipal.SalvarConfiguracoes;
var
  ini: TIniFile;
begin
  ForceDirectories(ExtractFilePath(GetConfigFilePath));
  ini := TIniFile.Create(GetConfigFilePath);
  try
    ini.WriteString('Gravacao', 'Diretorio', edtDiretorio.Text);
    ini.WriteString('Gravacao', 'TempoSegmento', edtTempoSegmento.Text);
    ini.WriteInteger('Gravacao', 'UnidadeTempoIndex', cboUnidadeTempoGravacao.ItemIndex);
    ini.WriteInteger('Gravacao', 'MonitorIndex', cbMonitor.ItemIndex);

    ini.WriteString('Manutencao', 'Tempo', edtTempoManute.Text);
    ini.WriteInteger('Manutencao', 'UnidadeTempoIndex', cboUnidadeTempoManute.ItemIndex);

    ini.WriteString('Manutencao', 'TempoVaredura', edtPeriodicidadeManute.Text);
    ini.WriteInteger('Manutencao', 'UnidadeTempoVarreduraIndex', cboUnidadeTempoPeriodicidadeManute.ItemIndex);

    ini.WriteBool('Geral', 'IniciarMinimizadoGravando', chkIniciaMinimizadoGravando.Checked);
  finally
    ini.Free;
  end;
end;

procedure TfrmPrincipal.CarregarConfiguracoes;
var
  ini: TIniFile;
begin
  ini := TIniFile.Create(GetConfigFilePath);
  try
    edtDiretorio.Text := ini.ReadString('Gravacao', 'Diretorio', edtDiretorio.Text);
    edtTempoSegmento.Text := ini.ReadString('Gravacao', 'TempoSegmento', '5');
    cboUnidadeTempoGravacao.ItemIndex := ini.ReadInteger('Gravacao', 'UnidadeTempoIndex', 1);
    cbMonitor.ItemIndex := ini.ReadInteger('Gravacao', 'MonitorIndex', 0);

    edtTempoManute.Text := ini.ReadString('Manutencao', 'Tempo', '24');
    cboUnidadeTempoManute.ItemIndex := ini.ReadInteger('Manutencao', 'UnidadeTempoIndex', 2);

    edtPeriodicidadeManute.Text := ini.ReadString('Manutencao', 'TempoVaredura', '60');
    cboUnidadeTempoPeriodicidadeManute.ItemIndex := ini.ReadInteger('Manutencao', 'UnidadeTempoVarreduraIndex', 0);

    chkIniciaMinimizadoGravando.Checked := ini.ReadBool('Geral', 'IniciarMinimizadoGravando', False);

  finally
    ini.Free;
  end;
end;

procedure TfrmPrincipal.cboUnidadeTempoPeriodicidadeManuteChange(
  Sender: TObject);
begin
  AtualizaIntervaloTimer;
end;

procedure TfrmPrincipal.edtPeriodicidadeManuteChange(Sender: TObject);
begin
  AtualizaIntervaloTimer;
end;

procedure TfrmPrincipal.edtPeriodicidadeManuteKeyPress(Sender: TObject;
  var Key: Char);
begin
  if not (Key in ['0'..'9', #8]) then
    Key := #0;
end;

procedure TfrmPrincipal.edtTempoManuteKeyPress(Sender: TObject; var Key: Char);
begin
  if not (Key in ['0'..'9', #8]) then
    Key := #0;
end;

procedure TfrmPrincipal.edtTempoSegmentoKeyPress(Sender: TObject; var Key: Char);
begin
  if not (Key in ['0'..'9', #8]) then
    Key := #0;
end;

function TfrmPrincipal.GetConfigFilePath: string;
begin
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) +
            'GravadorDeTela\Config.ini';
end;

function TFrmPrincipal.TestaConfiguracoesBasicas: Boolean;
begin
  if edtDiretorio.Text = '' then
  begin
    ShowMessage('Selecione um diretório para as gravações!');
    Exit(False);
  end;

  if edtTempoSegmento.Text = '0' then
  begin
    ShowMessage('Tempo por vídeo deve ser maior que zero!');
    Exit(False);
  end;

  if edtTempoManute.Text = '0' then
  begin
    ShowMessage('Tempo para manter as gravações deve ser maior que zero!');
    Exit(False);
  end;

  if edtPeriodicidadeManute.Text = '0' then
  begin
    ShowMessage('Tempo para realizar a manutenção das gravações deve ser maior que zero!');
    Exit(False);
  end;

  Result := True;
end;


procedure TFrmPrincipal.AtualizaIntervaloTimer;
begin
  if cboUnidadeTempoPeriodicidadeManute.Text = 'Segundos' then
    Timer1.Interval := StrToInt(edtPeriodicidadeManute.Text) * 1000
  else if cboUnidadeTempoPeriodicidadeManute.Text = 'Minutos' then
    Timer1.Interval := (StrToInt(edtPeriodicidadeManute.Text) * 60) * 1000
  else if cboUnidadeTempoPeriodicidadeManute.Text = 'Horas' then
    Timer1.Interval := (StrToInt(edtPeriodicidadeManute.Text) * 3600) * 1000;

end;

procedure TfrmPrincipal.WndProc(var Msg: TMessage);
begin
  inherited;

  if Msg.Msg = WM_USER + 1 then
  begin
    IniciarGravacao;
    AtualizaStatus;
    WindowState := wsMinimized;
    Hide;
    TrayIcon1.Visible := True;
  end;
end;


end.


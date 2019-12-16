unit principal;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ComCtrls;

type
  TfrmPrincipal = class(TForm)
    Label6: TLabel;
    pgControl: TPageControl;
    formEmissao: TTabSheet;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    btnEnviar: TButton;
    memoConteudoEnviar: TMemo;
    cbTpConteudo: TComboBox;
    chkExibir: TCheckBox;
    txtCNPJ: TEdit;
    GroupBox4: TGroupBox;
    memoRetorno: TMemo;
    txtCaminhoSalvar: TEdit;
    labelTokenEnviar: TLabel;
    cbTpDown: TComboBox;
    cbTpAmb: TComboBox;
    procedure btnEnviarClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmPrincipal: TfrmPrincipal;

implementation

{$R *.dfm}

uses NFeAPI, System.JSON;

procedure TfrmPrincipal.btnEnviarClick(Sender: TObject);
var
  retorno, statusEnvio, statusConsulta, statusDownload: String;
  cStat, chNFe, nProt, motivo, nsNRec, erros: String;
  jsonRetorno : TJSONObject;
begin
  // Valida se todos os campos foram preenchidos
  if ((txtCaminhoSalvar.Text <> '') and (txtCNPJ.Text <> '') and
    (memoConteudoEnviar.Text <> '')) then
  begin
    memoRetorno.Lines.Clear;
    retorno := emitirNFeSincrono(memoConteudoEnviar.Text,
    cbTpConteudo.Text, txtCNPJ.Text, cbTpDown.Text, cbTpAmb.Text,
    txtCaminhoSalvar.Text, chkExibir.Checked);
    memoRetorno.Text := retorno;

    jsonRetorno := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(retorno), 0) as TJSONObject;
	  statusEnvio := jsonRetorno.GetValue('statusEnvio').Value;
	  statusConsulta := jsonRetorno.GetValue('statusConsulta').Value;
    statusDownload := jsonRetorno.GetValue('statusDownload').Value;
    cStat := jsonRetorno.GetValue('cStat').Value;
    chNFe := jsonRetorno.GetValue('chNFe').Value;
    nProt := jsonRetorno.GetValue('nProt').Value;
    motivo := jsonRetorno.GetValue('motivo').Value;
	  nsNRec := jsonRetorno.GetValue('nsNRec').Value;
    erros := jsonRetorno.GetValue('erros').Value;

    if ((statusEnvio = '200') Or (statusEnvio = '-6')) then
    begin
		  if(statusConsulta = '200') then
		  begin
        if (cStat = '100') then
        begin
          ShowMessage(motivo);
          if (statusDownload <> '200') then
          begin
              // Aqui você pode realizar um tratamento em caso de erro no download
          end;
        end
        else
        begin
          ShowMessage(motivo);
        end;
		  end
		  else
		  begin
			  ShowMessage(motivo + #13 + erros);
		  end
    end
    else
    begin
      ShowMessage(motivo + #13 + erros);
    end
  end
  else
  begin
    Showmessage('Todos os campos devem estar preenchidos');
  end
end;


end.

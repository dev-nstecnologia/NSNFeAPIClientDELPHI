program NFeAPIClientDelphi10_1;

uses
  Vcl.Forms,
  principal in 'principal.pas' {frmPrincipal},
  NFeAPI in 'NFeAPI.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmPrincipal, frmPrincipal);
  Application.Run;
end.

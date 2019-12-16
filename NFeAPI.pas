unit NFeAPI;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls, IdHTTP, IdIOHandler, IdIOHandlerSocket,
  IdIOHandlerStack,
  IdSSL, IdSSLOpenSSL, ShellApi, IdCoderMIME, EncdDecd;

// Assinatura das funções
function enviaConteudoParaAPI(conteudoEnviar, url, tpConteudo: String): String;
function emitirNFeSincrono(conteudo, tpConteudo, CNPJ, tpDown, tpAmb,
caminho: String; exibeNaTela: boolean = false): String;
function emitirNFe(conteudo, tpConteudo: String): String;
function consultarStatusProcessamento(CNPJ, nsNRec, tpAmb: String): String;
function downloadNFe(chNFe, tpDown, tpAmb: String): String;
function downloadNFeESalvar(chNFe, tpDown, tpAmb, caminho: String;
exibeNaTela: boolean = false): String;
function downloadEventoNFe(chNFe, tpAmb, tpDown, tpEvento, nSeqEvento: String): String;
function downloadEventoNFeESalvar(chNFe, tpAmb, tpDown, tpEvento, nSeqEvento,
caminho: String; exibeNaTela: boolean = false): String;
function cancelarNFe(chNFe, tpAmb, dhEvento, nProt, xJust, tpDown,
caminho: String; exibeNaTela: boolean = false): String;
function corrigirNFe(chNFe, tpAmb, dhEvento, nSeqEvento, xCorrecao,
tpDown, caminho: String; exibeNaTela: boolean = false): String;
function consultaCadastroContribuinte(CNPJCont, UF, documentoConsulta,
tpConsulta: String): String;
function consultaSituacao(licencaCNPJ, chNFe, tpAmb, versao: String): String;
function enviaEmail(chNFe, email, enviaEmailDoc: String): String;
function inutilizar(cUF, tpAmb, ano, CNPJ, serie, nNFIni, nNFFin,
xJust: String): String;
function listarNSNRecs(chNFe: String): String;
function salvarXML(xml, caminho, chNFe: String; tpEvento: String = ''; nSeqEvento: String = ''): String;
function salvarJSON(json, caminho, chNFe: String; tpEvento: String = ''; nSeqEvento: String = ''): String;
function salvarPDF(pdf, caminho, chNFe: String; tpEvento: String = ''; nSeqEvento: String = ''): String;
procedure gravaLinhaLog(conteudo: String);

implementation

uses
  System.json, StrUtils, System.Types;

var
  tempoEspera: Integer = 500;
  token: String = 'SEU TOKEN';

// Função genérica de envio para um url, contendo o token no header
function enviaConteudoParaAPI(conteudoEnviar, url, tpConteudo: String): String;
var
  retorno: String;
  conteudo: TStringStream;
  HTTP: TIdHTTP; // Disponível na aba 'Indy Servers'
  IdSSLIOHandlerSocketOpenSSL1: TIdSSLIOHandlerSocketOpenSSL;
  // Disponivel na aba Indy I/O Handlers
begin
  conteudo := TStringStream.Create(conteudoEnviar, TEncoding.UTF8);
  HTTP := TIdHTTP.Create(nil);
  try
    if tpConteudo = 'txt' then // Informa que vai mandar um TXT
    begin
      HTTP.Request.ContentType := 'text/plain;charset=utf-8';
    end
    else if tpConteudo = 'xml' then // Se for XML
    begin
      HTTP.Request.ContentType := 'application/xml;charset=utf-8';
    end
    else // JSON
    begin
      HTTP.Request.ContentType := 'application/json;charset=utf-8';
    end;

    // Abre SSL
    IdSSLIOHandlerSocketOpenSSL1 := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
    HTTP.IOHandler := IdSSLIOHandlerSocketOpenSSL1;

    // Avisa o uso de UTF-8
    HTTP.Request.ContentEncoding := 'UTF-8';

    // Adiciona o token ao header
    HTTP.Request.CustomHeaders.Values['X-AUTH-TOKEN'] := token;
    // Result := conteudo.ToString;
    // Faz o envio por POST do json para a url
    try
      retorno := HTTP.Post(url, conteudo);

    except
      on E: EIdHTTPProtocolException do
        retorno := E.ErrorMessage;
      on E: Exception do
        retorno := E.Message;
    end;

  finally
    conteudo.Free();
    HTTP.Free();
  end;

  // Devolve o json de retorno da API
  Result := retorno;
end;

// Esta função emite uma NF-e de forma síncrona, fazendo o envio, a consulta e o download da nota
function emitirNFeSincrono(conteudo, tpConteudo, CNPJ, tpDown, tpAmb,
caminho: String; exibeNaTela: boolean = false): String;
var
  retorno, resposta: String;
  statusEnvio, statusConsulta, statusDownload, motivo, nsNRec: String;
  erros: TJSONValue;
  chNFe, cStat, nProt: String;
  jsonRetorno, jsonAux: TJSONObject;
  aux: String;
begin
  // Inicia as variáveis vazias
  statusEnvio := '';
  statusConsulta := '';
  statusDownload := '';
  motivo := '';
  nsNRec := '';
  erros := TJSONString.Create('');
  chNFe := '';
  cStat := '';
  nProt := '';

  resposta := emitirNFe(conteudo, tpConteudo);
  jsonRetorno := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(resposta),
    0) as TJSONObject;
  statusEnvio := jsonRetorno.GetValue('status').Value;

  if (statusEnvio = '200') or (statusEnvio = '-6') then
  begin

    nsNRec := jsonRetorno.GetValue('nsNRec').Value;

    sleep(tempoEspera);

    resposta := consultarStatusProcessamento(CNPJ, nsNRec, tpAmb);
    jsonRetorno := TJSONObject.ParseJSONValue
      (TEncoding.ASCII.GetBytes(resposta), 0) as TJSONObject;
    statusConsulta := jsonRetorno.GetValue('status').Value;

    if (statusConsulta = '200') then
    begin

      cStat := jsonRetorno.GetValue('cStat').Value;

      if (cStat = '100') or (cStat = '150') then
      begin

        chNFe := jsonRetorno.GetValue('chNFe').Value;
        nProt := jsonRetorno.GetValue('nProt').Value;
        motivo := jsonRetorno.GetValue('xMotivo').Value;

        resposta := downloadNFeESalvar(chNFe, tpDown, tpAmb, caminho, exibeNaTela);
        jsonRetorno := TJSONObject.ParseJSONValue
          (TEncoding.ASCII.GetBytes(resposta), 0) as TJSONObject;
        statusDownload := jsonRetorno.GetValue('status').Value;

        if (statusDownload <> '200') then
        begin
          motivo := jsonRetorno.GetValue('motivo').Value;
        end;
      end
      else
      begin
        motivo := jsonRetorno.GetValue('xMotivo').Value;
      end;
    end
    else
    begin
      motivo := jsonRetorno.GetValue('motivo').Value;
    end;
  end

  else if (statusEnvio = '-7') then
  begin
    motivo := jsonRetorno.GetValue('motivo').Value;
    nsNRec := jsonRetorno.GetValue('nsNRec').Value;
  end

  else if (statusEnvio = '-4') or (statusEnvio = '-2') then
  begin
    motivo := jsonRetorno.GetValue('motivo').Value;
    try
      erros := jsonRetorno.Get('erros').JsonValue;
    except
    end;
  end

  else if (statusEnvio = '-999') or (statusEnvio = '-5') then
  begin
    erros := jsonRetorno.Get('erro').JsonValue;
    jsonAux := TJSONObject.ParseJSONValue
      (TEncoding.ASCII.GetBytes(erros.ToString), 0) as TJSONObject;
    motivo := jsonAux.GetValue('xMotivo').Value;
  end

  else
  begin
    try
      motivo := jsonRetorno.GetValue('motivo').Value;
    except
      motivo := jsonRetorno.ToString;
    end;
  end;

  // Monta o JSON de retorno
  retorno := '{' +
                  '"statusEnvio": "'    + statusEnvio    + '",'  +
                  '"statusConsulta": "' + statusConsulta + '",'  +
                  '"statusDownload": "' + statusDownload + '",'  +
                  '"cStat": "'          + cStat          + '",'  +
                  '"chNFe": "'          + chNFe          + '",'  +
                  '"nProt": "'          + nProt          + '",'  +
                  '"nsNRec": "'         + nsNRec         + '",'  +
                  '"motivo": "'         + motivo         + '",'  +
                  '"erros": '           + erros.ToString +
             '}';

  // Grava dados de retorno
  gravaLinhaLog('[JSON_RETORNO]');
  gravaLinhaLog(retorno);
  gravaLinhaLog('');

  Result := retorno;
end;

// Emitir NF-e
function emitirNFe(conteudo, tpConteudo: String): String;
var
  url, resposta: String;
begin
  // Informa a url para onde deve ser enviado
  url := 'https://nfe.ns.eti.br/nfe/issue';

  // Grava dados envio
  gravaLinhaLog('[ENVIO_DADOS]');
  gravaLinhaLog(conteudo);

  // Envia o conteudo para a URL
  resposta := enviaConteudoParaAPI(conteudo, url, tpConteudo);

  // Grava resposta API
  gravaLinhaLog('[ENVIO_RESPOSTA]');
  gravaLinhaLog(resposta);

  Result := resposta;
end;

// Consultar Status de Processamento
function consultarStatusProcessamento(CNPJ, nsNRec, tpAmb: String): String;
var
  json: String;
  url, resposta: String;
begin

  json := '{' +
              '"CNPJ": "'         + CNPJ   + '",' +
              '"nsNRec": "'       + nsNRec + '",' +
              '"tpAmb": "'        + tpAmb  + '"'  +
          '}';

  url := 'https://nfe.ns.eti.br/nfe/issue/status';

  gravaLinhaLog('[CONSULTA_DADOS]');
  gravaLinhaLog(json);

  resposta := enviaConteudoParaAPI(json, url, 'json');

  gravaLinhaLog('[CONSULTA_RESPOSTA]');
  gravaLinhaLog(resposta);

  Result := resposta;
end;

// Download da NF-e
function downloadNFe(chNFe, tpDown, tpAmb: String): String;
var
  json: String;
  url, resposta, status: String;
  jsonRetorno: TJSONObject;
begin

  json := '{' +
              '"chNFe": "'        + chNFe  + '",' +
              '"tpDown": "'       + tpDown + '",' +
              '"tpAmb": "'        + tpAmb  + '"'  +
          '}';

  url := 'https://nfe.ns.eti.br/nfe/get';

  gravaLinhaLog('[DOWNLOAD_NFE_DADOS]');
  gravaLinhaLog(json);

  resposta := enviaConteudoParaAPI(json, url, 'json');

  jsonRetorno := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(resposta),
    0) as TJSONObject;
  status := jsonRetorno.GetValue('status').Value;

  if (status <> '200') then
  begin
    gravaLinhaLog('[DOWNLOAD_NFE_RESPOSTA]');
    gravaLinhaLog(resposta);
  end
  else
  begin
    gravaLinhaLog('[DOWNLOAD_NFE_STATUS]');
    gravaLinhaLog(status);
  end;

  Result := resposta;
end;

// Download da NF-e e Salvar
function downloadNFeESalvar(chNFe, tpDown, tpAmb, caminho: String;
exibeNaTela: boolean = false): String;
var
  xml, json, pdf: String;
  status, resposta: String;
  jsonRetorno: TJSONObject;
begin

  resposta := downloadNFe(chNFe, tpDown, tpAmb);
  jsonRetorno := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(resposta),
    0) as TJSONObject;
  status := jsonRetorno.GetValue('status').Value;

  if status = '200' then
  begin
    if not DirectoryExists(caminho) then
      CreateDir(caminho);

    if Pos('X', tpDown) <> 0 then
    begin
      xml := jsonRetorno.GetValue('xml').Value;
      salvarXML(xml, caminho, chNFe);
    end;

    if Pos('J', tpDown) <> 0 then
      // Se não baixou XML, baixa JSON
      if Pos('X', tpDown) = 0 then
      begin
        json := jsonRetorno.GetValue('nfeProc').ToString;
        salvarJSON(json, caminho, chNFe);
      end;

    if Pos('P', tpDown) <> 0 then
    begin
      pdf := jsonRetorno.GetValue('pdf').Value;
      salvarPDF(pdf, caminho, chNFe);

      if exibeNaTela then
        ShellExecute(0, nil, PChar(caminho + chNFe + '-procNFe.pdf'), nil, nil,
        SW_SHOWNORMAL);
    end;

  end
  else
  begin
    Showmessage('Ocorreu um erro, veja o Retorno da API para mais informações');
  end;

  // Devolve o retorno da API
  Result := resposta;
end;

// Download do Evento da NF-e
function downloadEventoNFe(chNFe, tpAmb, tpDown, tpEvento, nSeqEvento: String): String;
var
  json: String;
  url, resposta, status: String;
  jsonRetorno: TJSONObject;
begin

  json := '{' +
              '"chNFe": "'      + chNFe      + '",' +
              '"tpAmb": "'      + tpAmb      + '",' +
              '"tpDown": "'     + tpDown     + '",' +
              '"tpEvento": "'   + tpEvento   + '",' +
              '"nSeqEvento": "' + nSeqEvento + '"'  +
          '}';

  url := 'https://nfe.ns.eti.br/nfe/get/event';

  gravaLinhaLog('[DOWNLOAD_EVENTO_DADOS]');
  gravaLinhaLog(json);

  resposta := enviaConteudoParaAPI(json, url, 'json');
  jsonRetorno := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(resposta),
    0) as TJSONObject;
  status := jsonRetorno.GetValue('status').Value;

  if (status <> '200') then
  begin
    gravaLinhaLog('[DOWNLOAD_EVENTO_RESPOSTA]');
    gravaLinhaLog(resposta);
  end
  else
  begin
    gravaLinhaLog('[DOWNLOAD_EVENTO_STATUS]');
    gravaLinhaLog(status);
  end;

  Result := resposta;
end;

// Download do Evento da NF-e e Salvar
function downloadEventoNFeESalvar(chNFe, tpAmb, tpDown, tpEvento, nSeqEvento,
caminho: String; exibeNaTela: boolean = false): String;
var
  xml, json, pdf: String;
  status, resposta, tpEventoSalvar: String;
  jsonRetorno: TJSONObject;
begin

  resposta := downloadEventoNFe(chNFe, tpAmb, tpDown, tpEvento, nSeqEvento);
  jsonRetorno := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(resposta),
    0) as TJSONObject;
  status := jsonRetorno.GetValue('status').Value;

  if status = '200' then
  begin

    if not DirectoryExists(caminho) then
      CreateDir(caminho);

    if (tpEvento.ToUpper = 'CANC') then
      tpEventoSalvar := '110111'
    else
      tpEventoSalvar := '110110';

    // Checa se deve baixar XML
    if Pos('X', tpDown) <> 0 then
    begin
      xml := jsonRetorno.GetValue('xml').Value;
      salvarXML(xml, caminho, chNFe, tpEventoSalvar, nSeqEvento)
    end;

    // Checa se deve baixar JSON
    if Pos('J', tpDown) <> 0 then

      if Pos('X', tpDown) = 0  then
      begin
        json := jsonRetorno.GetValue('json').ToString;
        salvarJSON(json, caminho, chNFe, tpEventoSalvar, nSeqEvento);
      end;

    // Checa se deve baixar PDF
    if Pos('P', tpDown) <> 0 then
    begin
      pdf := jsonRetorno.GetValue('pdf').Value;
      salvarPDF(pdf, caminho, chNFe, tpEventoSalvar, nSeqEvento);

      if exibeNaTela then
        ShellExecute(0, nil, PChar(caminho + tpEventoSalvar + chNFe + nSeqEvento + '-procNFe.pdf'),
        nil, nil, SW_SHOWNORMAL);
    end;

  end
  else
  begin
    Showmessage('Ocorreu um erro, veja o Retorno da API para mais informações');
  end;

  Result := resposta;
end;

// Realizar o cancelamento da NF-e
function cancelarNFe(chNFe, tpAmb, dhEvento, nProt, xJust, tpDown,
caminho: String; exibeNaTela: boolean = false): String;
var
  json: String;
  url, resposta, respostaDownload: String;
  status: String;
  jsonRetorno: TJSONObject;
begin

  json := '{' +
              '"chNFe": "'        + chNFe    + '",' +
              '"tpAmb": "'        + tpAmb    + '",' +
              '"dhEvento": "'     + dhEvento + '",' +
              '"nProt": "'        + nProt    + '",' +
              '"xJust": "'        + xJust    + '"'  +
          '}';

  url := 'https://nfe.ns.eti.br/nfe/cancel';

  gravaLinhaLog('[CANCELAMENTO_DADOS]');
  gravaLinhaLog(json);

  resposta := enviaConteudoParaAPI(json, url, 'json');

  gravaLinhaLog('[CANCELAMENTO_RESPOSTA]');
  gravaLinhaLog(resposta);

  jsonRetorno := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(resposta),
    0) as TJSONObject;
  status := jsonRetorno.GetValue('status').Value;

  if (status = '200') then
  begin
    respostaDownload := downloadEventoNFeESalvar(chNFe, tpAmb, tpDown,
      'CANC', '1', caminho, exibeNaTela);
    jsonRetorno := TJSONObject.ParseJSONValue
      (TEncoding.ASCII.GetBytes(respostaDownload), 0) as TJSONObject;
    status := jsonRetorno.GetValue('status').Value;

    if (status <> '200') then
    begin
      ShowMessage('Ocorreu um erro ao fazer o download. Verifique os logs.')
    end;

  end;

  Result := resposta;
end;

// Realizar a Carta de Correção da NF-e
function corrigirNFe(chNFe, tpAmb, dhEvento, nSeqEvento, xCorrecao,
tpDown, caminho: String; exibeNaTela: boolean = false): String;
var
  json: String;
  url, resposta, respostaDownload: String;
  status: String;
  jsonRetorno: TJSONObject;
begin
  // Monta o Json
  json := '{' +
              '"chNFe": "'        + chNFe      + '",' +
              '"tpAmb": "'        + tpAmb      + '",' +
              '"dhEvento": "'     + dhEvento   + '",' +
              '"nSeqEvento": "'   + nSeqEvento + '",' +
              '"xCorrecao": "'    + xCorrecao  + '"'  +
          '}';

  url := 'https://nfe.ns.eti.br/nfe/cce';

  gravaLinhaLog('[CCE_DADOS]');
  gravaLinhaLog(json);

  resposta := enviaConteudoParaAPI(json, url, 'json');

  gravaLinhaLog('[CCE_RESPOSTA]');
  gravaLinhaLog(resposta);

  jsonRetorno := TJSONObject.ParseJSONValue(TEncoding.ASCII.GetBytes(resposta),
    0) as TJSONObject;
  status := jsonRetorno.GetValue('status').Value;

  if (status = '200') then
  begin
    respostaDownload := downloadEventoNFeESalvar(chNFe, tpAmb, tpDown,
    'CCE', nSeqEvento, caminho, exibeNaTela);
    jsonRetorno := TJSONObject.ParseJSONValue
      (TEncoding.ASCII.GetBytes(respostaDownload), 0) as TJSONObject;
    status := jsonRetorno.GetValue('status').Value;

    if (status <> '200') then
    begin
      ShowMessage('Ocorreu um erro ao fazer o download. Verifique os logs.')
    end;
  end;

  Result := resposta;
end;

//Realiza a consulta do cadastro de contribuinte da NF-e
function consultaCadastroContribuinte(CNPJCont, UF, documentoConsulta,
tpConsulta: String): String;
var
  json: String;
  url, resposta, respostaDownload: String;
  status: String;
  jsonRetorno: TJSONObject;
begin
  // Monta o Json
  json := '{' +
              '"CNPJCont": "'        + CNPJCont          + '",' +
              '"UF": "'              + UF                + '",' +
              '"'+tpConsulta+'": "'  + documentoConsulta + '"'  +
          '}';

  url := 'https://nfe.ns.eti.br/util/conscad';

  gravaLinhaLog('[CONSULTA_CADASTRO_DADOS]');
  gravaLinhaLog(json);

  resposta := enviaConteudoParaAPI(json, url, 'json');

  gravaLinhaLog('[CONSULTA_CADASTRO_RESPOSTA]');
  gravaLinhaLog(resposta);

  Result := resposta;
end;

//Realiza a consulta de situação atual de uma NF-e
function consultaSituacao(licencaCNPJ, chNFe, tpAmb, versao: String): String;
var
  json: String;
  url, resposta, respostaDownload: String;
  status: String;
  jsonRetorno: TJSONObject;
begin
  // Monta o Json
  json := '{' +
              '"licencaCnpj": "'  + licencaCNPJ  + '",' +
              '"chNFe": "'        + chNFe        + '",' +
              '"tpAmb": "'        + tpAmb        + '",' +
              '"versao": "'       + versao       + '"'  +
          '}';

  url := 'https://nfe.ns.eti.br/nfe/stats';

  gravaLinhaLog('[CONSULTA_SITUACAO_DADOS]');
  gravaLinhaLog(json);

  resposta := enviaConteudoParaAPI(json, url, 'json');

  gravaLinhaLog('[CONSULTA_SITUACAO_RESPOSTA]');
  gravaLinhaLog(resposta);

  Result := resposta;
end;

//Realiza o envio de e-mail de uma NF-e
function enviaEmail(chNFe, email, enviaEmailDoc: String): String;
var
  quantidade, i: Integer;
  json: String;
  url, resposta, respostaDownload: String;
  status: String;
  emails: TStringDynArray;
  jsonRetorno: TJSONObject;
begin
  // Monta o Json
  json := '{' +
              '"chNFe": "'           + chNFe         + '",' +
              '"enviaEmailDoc": "'   + enviaEmailDoc + '",' +
              '"email": [';

  emails := SplitString(Trim(email), ',');
  quantidade := length(emails)-1;

  for i := 0 to quantidade do
  begin
     if (i = quantidade) then
     begin
        json := json + '"' + emails[i] + '"';
     end
     else
     begin
        json := json + '"' + emails[i] + '",';
     end;
  end;

  json := json + ']}';

  url := 'https://nfe.ns.eti.br/util/resendemail';

  gravaLinhaLog('[ENVIO_EMAIL_DADOS]');
  gravaLinhaLog(json);

  resposta := enviaConteudoParaAPI(json, url, 'json');

  gravaLinhaLog('[ENVIO_EMAIL_RESPOSTA]');
  gravaLinhaLog(resposta);

  Result := resposta;
end;

//Realiza a inutilização de um intervalo de numeração de NF-e
function inutilizar(cUF, tpAmb, ano, CNPJ, serie, nNFIni, nNFFin,
xJust: String): String;
var
  json: String;
  url, resposta, respostaDownload: String;
  status: String;
  jsonRetorno: TJSONObject;
begin
  // Monta o Json
  json := '{' +
              '"cUF": "'    + cUF    + '",' +
              '"ano": "'    + ano    + '",' +
              '"tpAmb": "'  + tpAmb  + '",' +
              '"CNPJ": "'   + CNPJ   + '",' +
              '"serie": "'  + serie  + '",' +
              '"nNFIni": "' + nNFIni + '",' +
              '"nNFFin": "' + nNFFin + '"'  +
          '}';

  url := 'https://nfe.ns.eti.br/nfe/inut';

  gravaLinhaLog('[INUTILIZACAO_DADOS]');
  gravaLinhaLog(json);

  resposta := enviaConteudoParaAPI(json, url, 'json');

  gravaLinhaLog('[INUTILIZACAO_RESPOSTA]');
  gravaLinhaLog(resposta);

  Result := resposta;
end;

//Realiza a listagem de nsNRec vinculados a uma chave de NF-e
function listarNSNRecs(chNFe: String): String;
var
  json: String;
  url, resposta, respostaDownload: String;
  status: String;
  jsonRetorno: TJSONObject;
begin
  // Monta o Json
  json := '{' + '"chNFe": "' + chNFe + '"' + '}';

  url := 'https://nfe.ns.eti.br/util/list/nsnrecs';

  gravaLinhaLog('[LISTA_NSNRECS_DADOS]');
  gravaLinhaLog(json);

  resposta := enviaConteudoParaAPI(json, url, 'json');

  gravaLinhaLog('[LISTA_NSNRECS_RESPOSTA]');
  gravaLinhaLog(resposta);

  Result := resposta;
end;

// Função para salvar o XML de retorno
function salvarXML(xml, caminho, chNFe: String; tpEvento: String = ''; nSeqEvento: String = ''): String;
var
  arquivo: TextFile;
  conteudoSalvar, localParaSalvar: String;
begin
  // Seta o caminho para o arquivo XML
  localParaSalvar := caminho + tpEvento + chNFe + nSeqEvento + '-procNFe.xml';

  // Associa o arquivo ao caminho
  AssignFile(arquivo, localParaSalvar);
  // Abre para escrita o arquivo
  Rewrite(arquivo);

  // Copia o retorno
  conteudoSalvar := xml;
  // Ajeita o XML retirando as barras antes das aspas duplas
  conteudoSalvar := StringReplace(conteudoSalvar, '\"', '"',
    [rfReplaceAll, rfIgnoreCase]);

  // Escreve o retorno no arquivo
  Writeln(arquivo, conteudoSalvar);

  // Fecha o arquivo
  CloseFile(arquivo);
end;

// Função para salvar o JSON de retorno
function salvarJSON(json, caminho, chNFe: String; tpEvento: String = ''; nSeqEvento: String = ''): String;
var
  arquivo: TextFile;
  conteudoSalvar, localParaSalvar: String;
begin
  // Seta o caminho para o arquivo JSON
  localParaSalvar := caminho + tpEvento + chNFe + nSeqEvento + '-procNFe.json';

  // Associa o arquivo ao caminho
  AssignFile(arquivo, localParaSalvar);
  // Abre para escrita o arquivo
  Rewrite(arquivo);

  // Copia o retorno
  conteudoSalvar := json;

  // Escreve o retorno no arquivo
  Writeln(arquivo, conteudoSalvar);

  // Fecha o arquivo
  CloseFile(arquivo);
end;

// Função para salvar o PDF de retorno
function salvarPDF(pdf, caminho, chNFe: String; tpEvento: String = ''; nSeqEvento: String = ''): String;
var
  conteudoSalvar, localParaSalvar: String;
  base64decodificado: TStringStream;
  arquivo: TFileStream;
begin
  /// /Seta o caminho para o arquivo PDF
  localParaSalvar := caminho + tpEvento + chNFe + nSeqEvento + '-procNFe.pdf';

  // Copia e cria uma TString com o base64
  conteudoSalvar := pdf;
  base64decodificado := TStringStream.Create(conteudoSalvar);

  // Cria o arquivo .pdf e decodifica o base64 para o arquivo
  try
    arquivo := TFileStream.Create(localParaSalvar, fmCreate);
    try
      DecodeStream(base64decodificado, arquivo);
    finally
      arquivo.Free;
    end;
  finally
    base64decodificado.Free;
  end;
end;

// Grava uma linha no log
procedure gravaLinhaLog(conteudo: String);
var
  caminhoEXE, nomeArquivo, data: String;
  log: TextFile;
begin
  // Pega o caminho do executável
  caminhoEXE := ExtractFilePath(GetCurrentDir);
  caminhoEXE := caminhoEXE + 'log\';

  // Pega a data atual
  data := DateToStr(Date);

  // Ajeita o XML retirando as barras antes das aspas duplas
  data := StringReplace(data, '/', '', [rfReplaceAll, rfIgnoreCase]);

  nomeArquivo := caminhoEXE + data;

  // Se diretório \log não existe, é criado
  if not DirectoryExists(caminhoEXE) then
    CreateDir(caminhoEXE);

  AssignFile(log, nomeArquivo + '.txt');
{$I-}
  Reset(log);
{$I+}
  if (IOResult <> 0) then
    Rewrite(log) { arquivo não existe e será criado }
  else
  begin
    CloseFile(log);
    Append(log); { o arquivo existe e será aberto para saídas adicionais }
  end;

  Writeln(log, DateTimeToStr(Now) + ' - ' + conteudo);

  CloseFile(log);
end;

end.


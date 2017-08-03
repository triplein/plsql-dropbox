--------------------------------------------------------
--  DDL for Package Body DOCDROPBOX2
--------------------------------------------------------

  CREATE OR REPLACE PACKAGE BODY "DOCDROPBOX2" as

  procedure pAppendUrlParameter(u_vcUrl         in out varchar2
                               ,i_vcParamName   in     varchar2
                               ,i_vcParamValue  in     varchar2) as
  begin
    if i_vcParamName is not null and i_vcParamValue is not null then
         u_vcUrl := u_vcUrl || i_vcParamName || '=' || i_vcParamValue || '&';
    end if;
  end;
                                 
                                 
  procedure pClob2Blob (i_lcData in     clob
                       ,u_lbData in out blob
                       ) is
                       
  /** @headcom
    *    Converts clob to blob
    *
    * @creator    mha
    *
    * @version    n/a
    *
    * @param      i_lcData  clob  clob to convert
    * @param      u_lbData  blob  converted blob
    *
    * @return
    *
    * @exception  default
    *
    * @history
    *       2010-07-01  mha  Initial
    *
    */
     
     l_nuLengthClob number;
     l_raBuf        raw (32767);
     l_vcBuf        varchar2 (32767);
     l_nuLengthBuf  number := 25000;
     l_nuPos        number;
     
  begin
              
     dbms_lob.createtemporary (u_lbData, true, dbms_lob.session);
     dbms_lob.open (u_lbData, dbms_lob.lob_readwrite);
     l_raBuf := null;
     l_nuLengthClob := dbms_lob.getlength (i_lcData);
     l_nuPos := 1;
  
     loop
        dbms_lob.read (i_lcData, l_nuLengthBuf, l_nuPos, l_vcBuf);
        l_raBuf := utl_raw.cast_to_raw (l_vcBuf);
        dbms_lob.writeappend (u_lbData, utl_raw.length (l_raBuf), l_raBuf);
        l_nuPos := l_nuPos + l_nuLengthBuf;
        exit when l_nuPos >= l_nuLengthClob;
     end loop;

  end pClob2Blob;

  procedure pHttpCall (i_vcUrl        in     varchar2
                    ,i_vcProxyUsr     in     varchar2 default null
                    ,i_vcProxyPwd     in     varchar2 default null
                    ,i_vcServerUsr    in     varchar2 default null
                    ,i_vcServerPwd    in     varchar2 default null
                    ,i_lcReq          in     clob
                    ,i_vcContentType  in     varchar2 default 'text/plain'
                    ,o_inHttpCode        out integer
                    ,o_vcHttpCodeMes     out varchar2
                    ,o_lcRes          in out clob
                    ,i_nuTimeOut      in     number default c_nuTimeout
                    ,i_vcWalletPath   in     varchar2 default null
                    ,i_vcWalletPwd    in     varchar2 default null
                    ,i_vcMethod       in     varchar2 default 'GET'
                    ,i_vcBearerToken in     varchar2 default null
                    ) is
                    
  /** @headcom
    *    HTTP call, returns Body, HTTP Code and additional message. 
    *
    * @creator    mha
    *
    * @version    n/a
    *
    * @param      i_vcUrl         Server url z.B. http://xxxx/xx/
    * @param      i_vcProxyUser   Proxy user
    * @param      i_vcProxyPwd    Proxy password
    * @param      i_vcServerUser  Server user
    * @param      i_vcServerPwd   Server password
    * @param      i_lcReq         Request data to send
    * @param      o_inHttpCod     Out Parameter Http Return Code
    * @param      o_vcHttpCodMes  Out Parameter Http Return Message
    * @param      o_lcRes         Out Parameter Response data as clob
    *
    *
    * @exception  default
    *
    * @history
    *       2011-07-25  mha  Initial
    *
    */
     
     l_trHttpReq    utl_http.req;
     l_trHttpResp   utl_http.resp;
     l_nuLengthReq  number;
     l_nuLengthFrom number;
     l_nuLengthRead number;
     l_vcBuf       varchar2 (32767);
     l_raBuf      raw (32767);
     l_nuLengthBuf  number;
     l_lbData      blob;
     
  begin


     l_nuLengthBuf := 32767;
     utl_http.set_persistent_conn_support (false, 1);
     -- Damit wir nicht ewig warten ein Timeout
     utl_http.set_transfer_timeout (i_nuTimeOut);     -- in seconds
  
     -- Proxy Authentifizierung
     if i_vcProxyUsr is not null then
        utl_http.set_proxy (i_vcProxyUsr, i_vcProxyPwd);
     end if;
  
     -- HTTPS via Wallet
     if i_vcWalletPath is not null then
        utl_http.set_wallet (i_vcWalletPath, i_vcWalletPwd);
     end if;
  
     -- Prüfen ob Daten mitgesendet werden      
     if i_vcMethod = 'POST' then
        l_trHttpReq := utl_http.begin_request (i_vcUrl, 'POST', 'HTTP/1.1');
  
        -- Web Server Authentifizierung ( Basic )
        if i_vcServerUsr is not null then
           utl_http.set_authentication (l_trHttpReq, i_vcServerUsr, i_vcServerPwd);
        end if;
  
        -- fix text/plain bei clob
        utl_http.set_header (l_trHttpReq, 'Content-Type', i_vcContentType);
        if i_vcBearerToken is not null then
          utl_http.set_header(l_trHttpReq, 'Authorization', 'Bearer ' || i_vcBearerToken);
        end if;
  
        if i_lcReq is null then
           utl_http.set_header (l_trHttpReq, 'Content-Length', '0');
           utl_http.set_body_charset ('UTF8');
        else
           dbms_lob.createtemporary (l_lbData, true);
           pClob2Blob (i_lcReq, l_lbData);
           -- Request Datenlänge ermitteln
           l_nuLengthReq := dbms_lob.getlength (l_lbData);
           utl_http.set_header (l_trHttpReq, 'Content-Length', to_char (l_nuLengthReq));
           utl_http.set_body_charset ('UTF8');
           l_nuLengthFrom := 1;
  
          <<write_next_buffer>>
           l_nuLengthRead := l_nuLengthReq - l_nuLengthFrom + 1;
  
           if l_nuLengthRead > l_nuLengthBuf then
              l_nuLengthRead := l_nuLengthBuf;
           end if;
  
           -- Daten versenden
           dbms_lob.read (l_lbData, l_nuLengthRead, l_nuLengthFrom, l_raBuf);
           utl_http.write_raw (l_trHttpReq, l_raBuf);
           l_nuLengthFrom := l_nuLengthFrom + l_nuLengthRead;
  
           if l_nuLengthFrom <= l_nuLengthReq then
              goto write_next_buffer;
           end if;
  
           dbms_lob.freeTemporary (l_lbData);
        end if;
     elsif i_vcMethod = 'GET' then
        l_trHttpReq := utl_http.begin_request (i_vcUrl);
  
        -- Web Server Authentifizierung ( Basic )
        if i_vcServerUsr is not null then
           utl_http.set_authentication (l_trHttpReq, i_vcServerUsr, i_vcServerPwd);
        --dbms_output.put_line('Setze ServerUser / ServerPwd:' || i_vcServerUsr || '/' || i_vcServerPwd);
        end if;
  
        utl_http.set_header (l_trHttpReq, 'Content-Type', 'text/plain');
        utl_http.set_header (l_trHttpReq, 'Content-Length', '0');
        if i_vcBearerToken is not null then
          utl_http.set_header(l_trHttpReq, 'Authorization', 'Bearer ' || i_vcBearerToken);
        end if;
        utl_http.set_body_charset ('UTF8');
     end if;
  
     -- Http Call ausführen
     l_trHttpResp := utl_http.get_response (l_trHttpReq);
     -- Http Response zuweisen
     o_inHttpCode := l_trHttpResp.status_code;
     o_vcHttpCodeMes := l_trHttpResp.reason_phrase;
  
     begin
        loop
           --utl_http.read_line(l_trHttpResp, l_vcBuffer, true);
           utl_http.read_text (l_trHttpResp, l_vcBuf, 32000);
           --dbms_output.put_line(l_vcBuf);
           if l_vcBuf is not null then
              dbms_lob.writeAppend (o_lcRes, length (l_vcBuf), l_vcBuf);
           end if;
        end loop;
     exception
        when utl_http.end_of_body then
           -- alles gelesen
           null;
     end;
  
     -- Http Call fertig
     utl_http.end_response (l_trHttpResp);
  -- utl_http.set_persistent_conn_support(FALSE,1);
     
  exception
     when others then
        utl_http.end_response(l_trHttpResp);
        dbms_output.put_line(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
end pHttpCall;
  

  function fBoolToVarchar(i_boValue in    boolean) return varchar2 as
  /** @headcom
    *    Translates a boolean value to a varchar
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_boValue    Value to convert
    * 
    * @history
    *       2014-08-18  ms  Initial
    *
    */
  begin
    if i_boValue then
      return 'true';
    else return 'false';
    end if;
  end;

  function fGetAuthURL(i_vcResponseType   in    varchar2 default 'code'
                      ,i_boDisableSignup  in    boolean  default false
                      ,i_boForceReapprove in    boolean  default false
                      ,i_vcRedirectUri    in    varchar2 default null
                      ,i_vcState          in    varchar2 default null
                      )return varchar2 as
  /** @headcom
    *    Returns a Dropbox Authentication URL for the app
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcResponseType    The requested grant type
    * @param      i_boDisableSignup   Whether the sign up button should be visible to comply with the App Store policy
    * @param      i_boForceReapprove  Whether the user will be force to reapprove the app
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#oa2-authorize
    *
    * @history
    *       2017-08-02  ms  Update for APIv2
    *       2014-08-18  ms  Initial
    *
    */
    
    l_vcAuthURL varchar2(300);
  begin
    /* l_vcAuthURL := 'https://www.dropbox.com/1/oauth2/authorize' ||
                        '?response_type='   || i_vcResponseType ||
                        '&client_id='       || c_vcAppKey ||
                        '&force_reapprove=' || docDropbox2.fBoolToVarchar(i_boForceReapprove) ||
                        '&disable_signup='  || docDropbox2.fBoolToVarchar(i_boDisableSignup);
                      
    if i_vcRedirectUri is not null then
        l_vcAuthURL := l_vcAuthURL || '&redirect_uri=' || i_vcRedirectUri;
    end if;
    if i_vcState is not null then
        l_vcAuthURL := l_vcAuthURL || '&state=' || i_vcState;
    end if; */
    
    l_vcAuthURL := 'https://www.dropbox.com/oauth2/authorize?';
    pAppendUrlParameter(l_vcAuthURL, 'response_type', i_vcResponseType);
    pAppendUrlParameter(l_vcAuthURL, 'client_id', c_vcAppKey);
    pAppendUrlParameter(l_vcAuthURL, 'force_reapprove', docDropbox2.fBoolToVarchar(i_boForceReapprove));
    pAppendUrlParameter(l_vcAuthURL, 'disable_signup', docDropbox2.fBoolToVarchar(i_boDisableSignup));
    pAppendUrlParameter(l_vcAuthURL, 'redirect_uri', i_vcRedirectUri);
    pAppendUrlParameter(l_vcAuthURL, 'state', i_vcState);
    return l_vcAuthURL;                 
  end;

  function fExchangeToken(i_vcCode      in    varchar2
                         ,i_vcGrantType in    varchar2
                         ) return json as
    
    /** @headcom
    *    Exchanges the code submitted by the user for an exchange token, used for API calls
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcCode            The code from the authorization page
    * @param      i_vcGrantType       The grant type, which must be 'authorization_code'
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#oa2-token
    *
    * @history
    *       2017-08-02  ms  Update for APIv2
    *       2014-08-18  ms  Initial
    *
    */
    
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(3000);
    l_jsResult json;
  begin
                   
    pAppendUrlParameter(l_lcRequest, 'code', i_vcCode);
    pAppendUrlParameter(l_lcRequest, 'grant_type', i_vcGrantType);
                   
    dbms_lob.createTemporary(l_lcResult, TRUE);               
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropboxapi.com/oauth2/token'
              ,i_vcProxyUsr     => null
              ,i_vcProxyPwd     => null
              ,i_vcServerUsr    => c_vcAppKey
              ,i_vcServerPwd    => c_vcAppSecret
              ,i_lcReq          => l_lcRequest
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'POST'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd);
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;
  end;
  
  function fGetAccountInfo(i_vcToken    in      varchar2
                          ,i_vcLocale   in      varchar2 default c_vcLocale
                          ) return json as
                          
    /** @headcom
    *    Retrieves information about the users account
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken     API Token
    * @param      i_vcLocale    Use to specify language settings      
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#account-info
    *
    * @history
    *       2017-08-02  ms  Update for APIv2
    *       2014-08-18  ms  Initial
    *
    */
                          
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
  begin 
    pAppendUrlParameter(l_lcRequest, 'locale', i_vcLocale);
                   
    dbms_lob.createTemporary(l_lcResult, true);               
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropboxapi.com/2/users/get_current_account'
              ,i_lcReq          => l_lcRequest
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'GET'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;
  end;

  function fUploadData(i_vcToken      in varchar2
                      ,i_vcTargetPath in varchar2
                      ,i_vcMode       in varchar2
                      ,i_lbData in blob) return json as
    /** @headcom
    *    Uploads data to the specified path. Limited to 150 MB per upload.
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken       API Token
    * @param      i_vcTargetPath  The full path to the file you want to write to
    * @param      i_boOverwrite   Whether files with equal names should be overwritten or renamed instead 
    * @param      i_lbData        The data as a blob for the upload
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#files_put
    *
    * @history
    *       2017-08-02  ms  Update for APIv2
    *       2014-08-18  ms  Initial
    *
    */                     
    
                         
    l_trReq         utl_http.req;
    l_trResp        utl_http.resp;
    l_vcParamList   varchar2(512);
    
    l_nuLength      number;
    
    l_raBuffer      raw(2000);
    l_nuAmount      number := 2000;
    l_nuOffset      number := 1;
    
    l_vcResponse     varchar2(2048);
    l_vcResponse_tmp varchar2(1024);
    
  begin
  
    utl_http.set_wallet (c_vcWalletPath, c_vcWalletPwd);
    
    pAppendUrlParameter(l_vcParamList, 'mode', i_vcMode);
    l_trReq := utl_http.begin_request('https://content.dropboxapi.com/2/files/upload' ||
                                           i_vcTargetPath || '?' || l_vcParamList, 'PUT');
    l_nuLength := dbms_lob.getLength(i_lbData);
    utl_http.set_header(l_trReq, 'Authorization', 'Bearer ' || i_vcToken);
    utl_http.set_header(l_trReq, 'Content-Length', l_nuLength);
    
    if l_nuLength <= 32767 then
      utl_http.write_raw(l_trReq, i_lbData);
    elsif l_nuLength > 32767 then
      utl_http.set_header(l_trReq, 'Transfer-Encoding', 'chunked');
      
      while (l_nuOffset < l_nuLength)
      loop
        dbms_lob.read(i_lbData, l_nuAmount, l_nuOffset, l_raBuffer);
        utl_http.write_raw(l_trReq, l_raBuffer);
        l_nuOffset := l_nuOffset + l_nuAmount;
      end loop;
    end if;
    
    l_trResp := utl_http.get_response(l_trReq);
    
    if l_trResp.status_code = 411 then raise g_exMissingContentLength; end if;
    
    begin
      loop
          utl_http.read_line(l_trResp, l_vcResponse_tmp, false);
          l_vcResponse := l_vcResponse || l_vcResponse_tmp;
      end loop;
      exception
        when utl_http.end_of_body then
          utl_http.end_response(l_trResp);
    end;
    return json(l_vcResponse);
    
    exception
      when others then
        dbms_output.put_line(l_trResp.status_code);
        dbms_output.put_line(l_trResp.reason_phrase);
        utl_http.end_request(l_trReq);
        utl_http.end_response(l_trResp);
  end;
  
  function fChunkedUpload(i_vcToken    in    varchar2
                           ,i_vcUploadId in    varchar2 default null
                           ,i_nuOffset   in    number   default 0
                           ,i_lbData     in    blob
                           )return json as
    /** @headcom
    *     Uploads a file chunk. Allows for larger uploads. See the documentation for usage information.
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken       API Token
    * @param      i_vcUploadId    The unique ID of the in-progress upload on the server
    * @param      i_nuOffset      The byte offset of this chunk, relative to the beginning of the full file
    * @param      i_lbData        A chunk of data from the file being uploaded. The chunk should begin at the number of bytes into the files that equals the offset
    * @param      i_vcLocale      Used to specify language settings, see https://www.dropbox.com/developers/core/docs#param.locale
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#chunked-upload
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */
    l_trReq         utl_http.req;
    l_trResp        utl_http.resp;
    l_vcRequestURL  varchar2(512);
    
    l_nuLength      number;
    
    l_raBuffer      raw(2000);
    l_nuAmount      number := 2000;
    l_nuOffset      number := 1;
    
    l_vcResponse     varchar2(2048);
    l_vcResponse_tmp varchar2(1024);
    
  begin
    utl_http.set_wallet (c_vcWalletPath, c_vcWalletPwd);
    l_vcRequestURL := 'https://api-content.dropbox.com/1/chunked_upload/?';
    pAppendUrlParameter(l_vcRequestURL, 'upload_id', i_vcUploadId);
    pAppendUrlParameter(l_vcRequestURL, 'offset', i_nuOffset);
    
    
    l_trReq := utl_http.begin_request(l_vcRequestURL, 'PUT');
    l_nuLength := dbms_lob.getLength(i_lbData);
    utl_http.set_header(l_trReq, 'Authorization', 'Bearer ' || i_vcToken);
    utl_http.set_header(l_trReq, 'Content-Length', l_nuLength);
    utl_http.set_header(l_trReq, 'Transfer-Encoding', 'chunked');
      
    while (l_nuOffset < l_nuLength)
    loop
      dbms_lob.read(i_lbData, l_nuAmount, l_nuOffset, l_raBuffer);
      utl_http.write_raw(l_trReq, l_raBuffer);
      l_nuOffset := l_nuOffset + l_nuAmount;
    end loop;
    
    l_trResp := utl_http.get_response(l_trReq);
    
    begin
      loop
          utl_http.read_line(l_trResp, l_vcResponse_tmp, false);
          l_vcResponse := l_vcResponse || l_vcResponse_tmp;
      end loop;
      exception
        when utl_http.end_of_body then
          utl_http.end_response(l_trResp);
    end;
    return json(l_vcResponse);
    exception
      when others then
        utl_http.end_response(l_trResp);
  end;
                           
  function fCommitChunkedUpload(i_vcToken     in      varchar2
                               ,i_vcPath      in      varchar2
                               ,i_vcUploadId  in      varchar2
                               ,i_boOverwrite in      boolean   default true
                               ,i_vcParentRev in      varchar2  default null
                               ,i_vcLocale    in      varchar2  default c_vcLocale
                               )return json as
    /** @headcom
    *     Completes an upload initiated by fChunkedUpload.
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken       API Token
    * @param      i_vcPath        The full path to the file you want to write to
    * @param      i_vcUploadId    Used to identify the chunked upload session you'd like to commit
    * @param      i_boOverwrite   Whether a file with the same name should be overwritten or renamed instead
    * @param      i_vcParentRev   This parameter specifies the revision of the file you're editing
    * @param      i_vcLocale      Used to specify language settings, see https://www.dropbox.com/developers/core/docs#param.locale
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#commit-chunked-upload
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
  begin
    
    pAppendUrlParameter(l_lcRequest, 'upload_id', i_vcUploadId);
    pAppendUrlParameter(l_lcRequest, 'overwrite', docDropbox2.fBoolToVarchar(i_boOverwrite));
    pAppendUrlParameter(l_lcRequest, 'parent_rev', i_vcParentRev);
                   
    dbms_lob.createTemporary(l_lcResult, true);               
    docDropbox2.pHttpCall (i_vcUrl => 'https://api-content.dropbox.com/1/commit_chunked_upload/auto/' || i_vcPath
              ,i_lcReq          => l_lcRequest
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'POST'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;
  end;
  
  
  
  function fDownloadData(i_vcToken in varchar2,
                         i_vcPath in varchar2) return blob as
    l_trReq         utl_http.req;
    l_trResp        utl_http.resp;
    l_lbFile        blob;
    l_raRaw         RAW(32767);
    
  /** @headcom
    *    Downloads a file from the specified path as a blob.
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken       API Token
    * @param      i_vcPath        The path to the file you want to retrieve
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#files-GET
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */     
    
  BEGIN
    dbms_lob.createtemporary(l_lbFile, FALSE);
  
    utl_http.set_wallet (c_vcWalletPath, c_vcWalletPwd);
    l_trReq := utl_http.begin_request('https://api-content.dropbox.com/1/files/auto/' || i_vcPath, 'GET');
    utl_http.set_header(l_trReq, 'Authorization', 'Bearer ' || i_vcToken);
    
    l_trResp := utl_http.get_response(l_trReq);
    
    if l_trResp.status_code = 404 then raise g_exFileNotFound; end if;
    
    BEGIN
      LOOP
        utl_http.read_raw(l_trResp, l_raRaw, 32766);
        dbms_lob.writeappend(l_lbFile, utl_raw.length(l_raRaw), l_raRaw);
      END LOOP;
      EXCEPTION
        WHEN utl_http.end_of_body THEN
          utl_http.end_response(l_trResp);
    END;
    return l_lbFile;
  END;
  
  
  function fGetMetadata (i_vcToken                     in varchar2
                        ,i_vcPath                      in varchar2
                        ,i_boIncludeMediaInfo          in boolean default false
                        ,i_boIncludeDeleted            in boolean default false
                        ,i_boIncludeHasExplicitMembers in boolean default false
                        ,i_vcLocale                    in varchar2 default c_vcLocale
                        ) return json as
                        
    /** @headcom
    *    Retrieves the metadata of the specified file or folder
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken                     API Token
    * @param      i_vcPath                      The path to the file or folder
    * @param      i_vcLocale                    Use to specify language settings
    * @param      i_boIncludeMediaInfo          If true, FileMetadata.media_info is set for photo and video.
    * @param      i_boIncludeDeleted            If true, DeletedMetadata will be returned for deleted file or folder, otherwise LookupError.not_found will be returned.
    * @param      i_boIncludeHasExplicidMembers If true, the results will include a flag for each file indicating whether or not that file has any explicit members.
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#metadata
    *
    * @history
    *       2017-08-02  ms  Update for v2
    *       2014-08-18  ms  Initial
    *
    */     
    
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
    
    l_nuFileLimit   number(5) := 25000;
    
  begin
    
    pAppendUrlParameter(l_lcRequest, 'file_limit', l_nuFileLimit);
    pAppendUrlParameter(l_lcRequest, 'path', i_vcPath);
    pAppendUrlParameter(l_lcRequest, 'include_media_info', docDropbox2.fBoolToVarchar(i_boIncludeMediaInfo));
    pAppendUrlParameter(l_lcRequest, 'include_deleted', docDropbox2.fBoolToVarchar(i_boIncludeDeleted));
    pAppendUrlParameter(l_lcRequest, 'include_has_explicit_shared_members', docDropbox2.fBoolToVarchar(i_boIncludeHasExplicitMembers));
    pAppendUrlParameter(l_lcRequest, 'locale', i_vcLocale);
    pAppendUrlParameter(l_lcRequest, 'hash', i_vcHash);
                
    dbms_lob.createTemporary(l_lcResult, TRUE);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropboxapi.com/2/files/get_metadata'
              ,i_lcReq          => l_lcRequest
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'GET'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
              
    if l_inHttpCode = 406 then raise g_exTooManyFiles; end if;
              /*
    dbms_output.put_line('Result 1: ' || l_lcResult);
    dbms_output.put_line('Request : ' || l_lcRequest);
    dbms_output.put_line('URL: ' || i_vcPath);
    dbms_output.put_line('Code: ' || l_inHttpCode);
    dbms_output.put_line('Mes: ' || l_vcHttpCodeMes);
    */
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;

  end;
  
  
  function fGetDelta(i_vcToken      in      varchar2
                    ,i_vcCursor     in      varchar2
                    ,i_vcPathPrefix in      varchar2
                    ,i_vcLocale     in      varchar2 default c_vcLocale
                    )return json as
                      
    /** @headcom
    *    Retrieves a list of the last changes to the users Dropbox, can be used to synchronize folders.
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken       API Token
    * @param      i_vcCursor      Used to keep track of the current state
    * @param      i_vcPathPrefix  Define a path to filter the changelist to a specific folder 
    * @param      i_vcLocale      Used to specify language settings, see https://www.dropbox.com/developers/core/docs#param.locale
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#delta
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */  
                      
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
    
  begin
    
    pAppendUrlParameter(l_lcRequest, 'cursor', i_vcCursor);
    pAppendUrlParameter(l_lcRequest, 'path_prefix', i_vcPathPrefix);
    pAppendUrlParameter(l_lcRequest, 'locale', i_vcLocale);
    
    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropbox.com/1/delta'
              ,i_lcReq          => l_lcRequest
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'POST'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
              
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;          
              
  end;  
  
  function fCallLongpollDelta(i_vcToken   in      varchar2
                             ,i_vcCursor  in      varchar2
                             ,i_nuTimeout in      number default 30
                             )return json as
     /** @headcom
    *    Opens a long-poll endpoint to wait for changes on an account. Requires a cursor from a previous fGetDelta call. 
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken       API Token
    * @param      i_vcCursor      Use a previous cursor from a fGetDelta call
    * @param      i_nuTimeout     Time in seconds, until the connection is closed
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#longpoll-delta
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */                           
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
  begin
    pAppendUrlParameter(l_lcRequest, 'cursor', i_vcCursor);
    pAppendUrlParameter(l_lcRequest, 'timeout', i_nuTimeout);

    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api-notify.dropbox.com/1/longpoll_delta?' || l_lcRequest
              ,i_lcReq          => l_lcRequest
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => i_nuTimeOut
              ,i_vcMethod       => 'GET'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
              
    if l_inHttpCode = 400 then raise g_exTooManyFiles; end if;
    
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;   
  end;
  
  function fGetRevisions(i_vcToken    in      varchar2
                        ,i_vcPath     in      varchar2
                        )return json_list as
     /** @headcom
    *     Obtains metadata for the previous revisions of a file.
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken       API Token
    * @param      i_vcPath        The path to the file
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#revisions
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */
                        
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jlResult json_list;
  begin
    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropbox.com/1/revisions/auto/' || i_vcPath
              ,i_lcReq          => l_lcRequest
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'GET'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
              
    l_jlResult := json_list(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jlResult;   
  end;
  
  function fRestore(i_vcToken   in    varchar2
                   ,i_vcPath    in    varchar2
                   ,i_vcRev     in    varchar2
                   ,i_vcLocale  in    varchar2 default c_vcLocale
                   )return json as
     /** @headcom
    *     Restores a file path to a previous revision
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken       API Token
    * @param      i_vcPath        The path to the file
    * @param      i_vcRev         The revision of the file to restore
    * @param      i_vcLocale      Used to specify language settings, see https://www.dropbox.com/developers/core/docs#param.locale
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#restore
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */
                   
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
    
  begin
    
    pAppendUrlParameter(l_lcRequest, 'rev', i_vcRev);
    pAppendUrlParameter(l_lcRequest, 'locale', i_vcLocale);
    
    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropbox.com/1/restore/auto/' || i_vcPath
              ,i_lcReq          => l_lcRequest
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'POST'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
              
    if l_inHttpCode = 404 then raise g_exFileNotFound; end if;
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;   
  
  end;
  
  function fSearch(i_vcToken          in    varchar2
                  ,i_vcPath           in    varchar2  default null
                  ,i_vcQuery          in    varchar2
                  ,i_nuFileLimit      in    number    default 1000
                  ,i_boIncludeDeleted in    boolean   default false
                  ,i_vcLocale         in    varchar2  default c_vcLocale
                  )return json_list as
     /** @headcom
    *     Returns metadata for all files and folders whose filenames contains the given search string as a substring.
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken           API Token
    * @param      i_vcPath            The path to the folder you want to search from
    * @param      i_vcQuery           The search string
    * @param      i_nuFileLimit       Defines the maximum amount of search results. 1000 is default and maximum
    * @param      i_boIncludeDeleted  Whether deleted files should be included as well
    * @param      i_vcLocale          Used to specify language settings, see https://www.dropbox.com/developers/core/docs#param.locale
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#search
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jlResult json_list;
    
  begin 
    pAppendUrlParameter(l_lcRequest, 'query', i_vcQuery);
    pAppendUrlParameter(l_lcRequest, 'file_limit', i_nuFileLimit);
    pAppendUrlParameter(l_lcRequest, 'include_deleted', docDropbox2.fBoolToVarchar(i_boIncludeDeleted));
    pAppendUrlParameter(l_lcRequest, 'locale', i_vcLocale);
    
    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropbox.com/1/search/auto/' || i_vcPath
              ,i_lcReq          => l_lcRequest
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'POST'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
              
    l_jlResult := json_list(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jlResult;   
  
  end;
                          
  function fShares(i_vcToken    in    varchar2
                    ,i_vcPath     in    varchar2
                    ,i_boURLShort in    boolean  default true
                    ,i_vcLocale   in    varchar2 default c_vcLocale
                    )return json as
     /** @headcom
    *     Creates and returns a Dropbox link to files or folders users can use to view a preview of the file in a web browser.
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken           API Token
    * @param      i_vcPath            The path to the folder or file you want to link to
    * @param      i_vcQuery           The search string
    * @param      i_nuFileLimit       Defines the maximum amount of search results. 1000 is default and maximum
    * @param      i_boIncludeDeleted  Whether deleted files should be included as well
    * @param      i_vcLocale          Used to specify language settings, see https://www.dropbox.com/developers/core/docs#param.locale
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#shares
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
    
  begin
    
    pAppendUrlParameter(l_lcRequest, 'short_url', docDropbox2.fBoolToVarchar(i_boURLShort));
    pAppendUrlParameter(l_lcRequest, 'locale', i_vcLocale);
    
    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropbox.com/1/shares/auto/' || i_vcPath
              ,i_lcReq          => l_lcRequest
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'POST'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
              
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;  
  
  end;
  
  function fMedia(i_vcToken   in      varchar2
                 ,i_vcPath    in      varchar2
                 ,i_vcLocale  in      varchar2 default c_vcLocale
                 )return json as
     /** @headcom
    *     Returns a link directly to a file.
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken           API Token
    * @param      i_vcPath            The path to the folder or file you want a direct link to
    * @param      i_vcLocale          Used to specify language settings, see https://www.dropbox.com/developers/core/docs#param.locale
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#media
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */             
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
  begin  
    pAppendUrlParameter(l_lcRequest, 'locale', i_vcLocale);
    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropbox.com/1/media/auto/' || i_vcPath
              ,i_lcReq          => l_lcRequest
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'POST'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
              
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;  
  
  end;
  
  function fCopyRef(i_vcToken   in    varchar2
                   ,i_vcPath    in    varchar2
                   )return json as
     /** @headcom
    *    Creates and returns a copy_ref to a file. 
    *    This reference string can be used to copy that file to another users Dropbox by passing it in as the from_copy_ref parameter in fCopy
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken           API Token
    * @param      i_vcPath            The path to the folder or file you want a copy_ref to refer to
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#media
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */      
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
  begin
    dbms_lob.createTemporary(l_lcRequest, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropbox.com/1/copy_ref/auto/' || i_vcPath
              ,i_lcReq          => l_lcRequest
              --,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'GET'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
              
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;               
  end;
  
  function fGetThumbnail(i_vcToken  in   varchar2
                          ,i_vcPath   in   varchar2
                          ,i_vcFormat in   varchar2 default 'jpeg'
                          ,i_vcSize   in   varchar2 default 's'
                          )return blob as
     /** @headcom
    *     Returns a thumbnail for an image. 
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken           API Token
    * @param      i_vcPath            The path to the file you want a thumbnail from
    * @param      i_vcFormat          The format for the thumbnail. 'jpeg' or 'png' possible.
    * @param      i_vcSize            Defines the size of the thumbnail. See documentation for details.
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#thumbnails
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */      
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_lbResult blob;
  begin    
    pAppendUrlParameter(l_lcRequest, 'format', i_vcFormat);
    pAppendUrlParameter(l_lcRequest, 'size', i_vcSize);
    
    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api-content.dropbox.com/1/thumbnails/auto/' || i_vcPath
              ,i_lcReq          => l_lcRequest
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'GET'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
              
    if l_inHttpCode = 404 then raise g_exFileNotFound; end if;
    if l_inHttpCode = 415 then raise g_exInvalidImage; end if;
    
    pClob2Blob(l_lcResult, l_lbResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_lbResult;
  end;
  
  function fGetPreview(i_vcToken  in    varchar2
                      ,i_vcPath   in    varchar2
                      ,i_vcRev    in    varchar2 default null
                      )return blob as
     /** @headcom
    *     Returns a preview for a document. Restricted to closed beta participants as of 18.08.14
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken           API Token
    * @param      i_vcPath            The path to the document you want a preview from
    * @param      i_vcRev             The revision of the file to retrieve.
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#previews
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */      
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_lbResult blob;
  begin
    pAppendUrlParameter(l_lcRequest, 'rev', i_vcRev);
    
    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api-content.dropbox.com/1/previews/auto/' || i_vcPath
              ,i_lcReq          => l_lcRequest
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'GET'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
              
    if l_inHttpCode = 404 then raise g_exFileNotFound; end if;
    if l_inHttpCode = 409 then raise g_exPreviewMissing; end if;
    
    pClob2Blob(l_lcResult, l_lbResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_lbResult;
  end;
 
  -----------------
  -- File Operations
                          
  function fCreateFolder(i_vcToken  in      varchar2
                        ,i_vcRoot   in      varchar2 default 'auto'
                        ,i_vcPath   in      varchar2
                        ,i_vcLocale in      varchar2 default c_vcLocale
                        ) return json as
     /** @headcom
    *     Creates a folder at the specified path. 
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken       API Token
    * @param      i_vcRoot        Defines the root folder. Depends on the type of app. Can be 'auto', 'sandbox', 'dropbox'.
    * @param      i_vcPath        The path to the new folder to create, relative to root
    * @param      i_vcLocale      Used to specify language settings, see https://www.dropbox.com/developers/core/docs#param.locale
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#fileops-create-folder
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
  begin  
    pAppendUrlParameter(l_lcRequest, 'root', i_vcRoot);
    pAppendUrlParameter(l_lcRequest, 'path', i_vcPath);
    pAppendUrlParameter(l_lcRequest, 'locale', i_vcLocale);
    
    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropbox.com/1/fileops/create_folder'
              ,i_lcReq          => l_lcRequest
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'POST'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
    
    if l_inHttpCode = 403 then raise g_exInvalidFileOp; end if;
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;
  end;
  
  function fDelete(i_vcToken  in      varchar2
                    ,i_vcRoot   in      varchar2 default 'auto'
                    ,i_vcPath   in      varchar2
                    ,i_vcLocale in      varchar2 default c_vcLocale
                    ) return json as
     /** @headcom
    *     Deletes the file or folder from the specified path.
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken       API Token
    * @param      i_vcRoot        Defines the root folder. Can be 'auto', 'sandbox', 'dropbox'.
    * @param      i_vcPath        The path to file or folder which you wish to delete
    * @param      i_vcLocale      Used to specify language settings, see https://www.dropbox.com/developers/core/docs#param.locale
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#fileops-delete
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
  begin
    pAppendUrlParameter(l_lcRequest, 'root', i_vcRoot);
    pAppendUrlParameter(l_lcRequest, 'path', i_vcPath);
    pAppendUrlParameter(l_lcRequest, 'locale', i_vcLocale);
      
  
    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropbox.com/1/fileops/delete'
              ,i_lcReq          => l_lcRequest
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'POST'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
    
    if l_inHttpCode = 404 then raise g_exFileNotFound; end if;
    if l_inHttpCode = 406 then raise g_exInvalidFileOp; end if;
    
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;
  end;
  
  function fMove(i_vcToken    in      varchar2
                ,i_vcRoot     in      varchar2 default 'auto'
                ,i_vcPathFrom in      varchar2
                ,i_vcPathTo   in      varchar2
                ,i_vcLocale   in      varchar2 default c_vcLocale
                ) return json as
     /** @headcom
    *     Moves a file or folder to a new location
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken       API Token
    * @param      i_vcRoot        Defines the root folder. Can be 'auto', 'sandbox', 'dropbox'.
    * @param      i_vcPathFrom    Specifies the file or folder to be moved
    * @param      i_vcPathTo      Specifies the destination path, including the new name for the file or folder, relative to root
    * @param      i_vcLocale      Used to specify language settings, see https://www.dropbox.com/developers/core/docs#param.locale
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#fileops-move
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
  begin
    pAppendUrlParameter(l_lcRequest, 'root', i_vcRoot);
    pAppendUrlParameter(l_lcRequest, 'from_path', i_vcPathFrom);
    pAppendUrlParameter(l_lcRequest, 'to_path', i_vcPathTo);
    pAppendUrlParameter(l_lcRequest, 'locale', i_vcLocale);
      
  
    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropbox.com/1/fileops/move'
              ,i_lcReq          => l_lcRequest
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'POST'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
    
    if l_inHttpCode = 403 then raise g_exInvalidFileOp; end if;
    if l_inHttpCode = 404 then raise g_exFileNotFound; end if;
    if l_inHttpCode = 406 then raise g_exInvalidFileOp; end if;
    
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;
  end;
  
  function fCopy(i_vcToken    in      varchar2
                ,i_vcRoot     in      varchar2 default 'auto'
                ,i_vcPathFrom in      varchar2
                ,i_vcPathTo   in      varchar2
                ,i_vcLocale   in      varchar2 default c_vcLocale
                ,i_vcCopyRef  in      varchar2 default null
                ) return json as
     /** @headcom
    *     Copies a file or folder to a new location
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcToken       API Token
    * @param      i_vcRoot        Defines the root folder. Can be 'auto', 'sandbox', 'dropbox'.
    * @param      i_vcPathFrom    Specifies the file or folder to be copied from relative to root
    * @param      i_vcPathTo      Specifies the destination path, including the new name for the file or folder, relative to root
    * @param      i_vcLocale      Used to specify language settings, see https://www.dropbox.com/developers/core/docs#param.locale
    * @param      i_vcCopyRef     Specifies a copy_ref generated from a previous fGetCopyRef call. See the documentation for more details
    * 
    * @see
    *   https://www.dropbox.com/developers/core/docs#fileops-copy
    *
    * @history
    *       2014-08-18  ms  Initial
    *
    */
    l_lcResult clob;
    l_lcRequest clob;
    l_inHttpCode integer;
    l_vcHttpCodeMes varchar2(300);
    l_jsResult json;
  begin
    pAppendUrlParameter(l_lcRequest, 'root', i_vcRoot);
    pAppendUrlParameter(l_lcRequest, 'from_path', i_vcPathFrom);
    pAppendUrlParameter(l_lcRequest, 'to_path', i_vcPathTo);
    pAppendUrlParameter(l_lcRequest, 'locale', i_vcLocale);
    pAppendUrlParameter(l_lcRequest, 'from_copy_ref', i_vcCopyRef);
    
    dbms_lob.createTemporary(l_lcResult, true);
    docDropbox2.pHttpCall (i_vcUrl => 'https://api.dropbox.com/1/fileops/copy'
              ,i_lcReq          => l_lcRequest
              ,o_inHttpCode     => l_inHttpCode
              ,o_vcHttpCodeMes  => l_vcHttpCodeMes
              ,i_vcContentType  => 'application/x-www-form-urlencoded'
              ,o_lcRes          => l_lcResult
              ,i_nuTimeOut      => c_nuTimeout
              ,i_vcMethod       => 'POST'
              ,i_vcWalletPath   => c_vcWalletPath
              ,i_vcWalletPwd    => c_vcWalletPwd
              ,i_vcBearerToken => i_vcToken);
              
    if l_inHttpCode = 403 then raise g_exInvalidFileOp; end if;
    if l_inHttpCode = 404 then raise g_exFileNotFound; end if;
    if l_inHttpCode = 406 then raise g_exTooManyFiles; end if;
    
    l_jsResult := json(l_lcResult);
    dbms_lob.freeTemporary(l_lcResult);
    return l_jsResult;
  end;
  
  
  function fLargeUpload(i_vcToken      in     varchar2
                       ,i_vcTargetPath in    varchar2
                       ,i_boOverwrite  in    boolean
                       ,i_lbData       in    blob
                        ) return json as
    l_nuChunkSize     number := 4000000;
    
    -- Unterschiedliche Anfangswerte für Dropbox Offset und Copy Offset
    l_nuOffsetCopy    number := 1;
    l_nuOffsetDropbox number := 0;
    l_lbChunk         blob;
    l_vcUploadId      varchar2(200);
    l_jsReturn        json;
    l_nuCount         number := 0;
  begin
    if dbms_lob.getLength(i_lbData) < l_nuChunkSize then
      return docDropbox2.fUploadData(i_vcToken
                        ,i_vcTargetPath
                        ,i_boOverwrite
                        ,i_lbData);
    end if;
    dbms_lob.createTemporary(l_lbChunk, true);
    dbms_lob.copy(l_lbChunk, i_lbData, l_nuChunkSize, 1, l_nuOffsetCopy);
    
    l_jsReturn := docDropbox2.fChunkedUpload(i_vcToken, null, l_nuOffsetDropbox, l_lbChunk);
    l_vcUploadId := replace(l_jsReturn.get('upload_id').to_char(), '"', '');
    l_nuOffsetCopy := l_nuOffsetCopy + l_nuChunkSize;
    l_nuOffsetDropbox := l_nuOffsetDropbox + l_nuChunkSize;
    while (l_nuOffsetCopy + l_nuChunkSize) <= dbms_lob.getLength(i_lbData)
      loop
        dbms_lob.copy(l_lbChunk, i_lbData, l_nuChunkSize, 1, l_nuOffsetCopy);
        l_jsReturn := docDropbox2.fChunkedUpload(i_vcToken, l_vcUploadId, l_nuOffsetDropbox, l_lbChunk);
        l_nuOffsetDropbox := l_nuOffsetDropbox + l_nuChunkSize;
        l_nuOffsetCopy := l_nuOffsetCopy + l_nuChunkSize;
      end loop;
      
    if (dbms_lob.getLength(i_lbData) - l_nuOffsetCopy + 1) > 0 then
      dbms_lob.freeTemporary(l_lbChunk);
      dbms_lob.createTemporary(l_lbChunk, true);
      dbms_lob.copy(l_lbChunk, i_lbData, dbms_lob.getLength(i_lbData) - l_nuOffsetCopy + 1, 1, l_nuOffsetCopy);
      l_jsReturn := docDropbox2.fChunkedUpload(i_vcToken, l_vcUploadId, l_nuOffsetDropbox, l_lbChunk);
    end if;
    
    l_jsReturn := docDropbox2.fCommitChunkedUpload(i_vcToken, i_vcTargetPath, l_vcUploadId, i_boOverwrite, null, 'de');
    return l_jsReturn;
  end;
end docDropbox2;

/

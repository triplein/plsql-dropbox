--------------------------------------------------------
--  DDL for Package DOCDROPBOX2
--------------------------------------------------------

  CREATE OR REPLACE PACKAGE "DOCDROPBOX2" AS 
/**
  *    Package used for communication with Dropbox Core APIs
  *
  * @creator    ms
  *
  * @version    1.0
  *
  * @depend
  *   PL/JSON
  * @see
  *       https://www.dropbox.com/developers/core/docs
  * @history
  *       2014-08-22  ms  Complete API functionality
  *       2014-08-18  ms  General functionality, file management, authorization
  *
  */
  
  
    -- Create an app at https://www.dropbox.com/developers/apps/ to get these keys
    c_vcAppKey      constant varchar2(20 char)    := 'xxxxxxxxxxxxxxx';
    c_vcAppSecret   constant varchar2(20 char)    := 'xxxxxxxxxxxxxxx';
    
    c_vcLocale      constant varchar2(6 char)     := 'de';
    c_vcWalletPath  constant varchar2(200 char)   := 'file:/path/to/wallet/folder/';
    c_vcWalletPwd   constant varchar2(200 char)   := 'xxxxxxx';
    c_nuTimeout     constant number               := 300;
  
    -- Exception whenever a file on the cloud is not found
    c_exFileNotFound                constant number     := -20059;
    g_exFileNotFound                exception;
    pragma exception_init(g_exFileNotFound, -20058);  
    
    -- Exception when a specific action is not allowed
    c_exNotAllowed                  constant number     := -20060;
    g_exNotAllowed                  exception;
    pragma exception_init(g_exNotAllowed, -20060);
    
    -- Exception in case overwriting is prohibited
    c_exFileExists                  constant number     := -20061;
    g_exFileExists                  exception;
    pragma exception_init(g_exFileExists, -20061);
    
    -- 411 - Missing Content-Length
    c_exMissingContentLength        constant number     := -20062;
    g_exMissingContentLength        exception;
    pragma exception_init(g_exMissingContentLength, -20062);
    
    -- 406 - Too many file entries to return
    c_exTooManyFiles                constant number     := -20063;
    g_exTooManyFiles                exception;
    pragma exception_init(g_exTooManyFiles, -20064);
    
    -- 400 - Invalid Parameters
    c_exInvalidParameters           constant number     := -20064;
    g_exInvalidParameters           exception;
    pragma exception_init(g_exInvalidParameters, -20064);
    
    -- 415 - Image is invalid and cannot be converted to a thumbnail
    c_exInvalidImage                constant number     := -20065;
    g_exInvalidImage                exception;
    pragma exception_init(g_exInvalidImage, -20065);
    
    -- 409 - No preview has been generated yet
    c_exPreviewMissing              constant number     := -20066;
    g_exPreviewMissing              exception;
    pragma exception_init(g_exPreviewMissing, -20066);
    
    -- 403 - Invalid File operation (File already exists at destination and similar)
    c_exInvalidFileOp               constant number     := -20067;
    g_exInvalidFileOp               exception;
    pragma exception_init(g_exInvalidFileOp, -20067);
    

        
    procedure pAppendUrlParameter(u_vcUrl         in out varchar2
                                 ,i_vcParamName   in     varchar2
                                 ,i_vcParamValue  in     varchar2);
    
    
     procedure pClob2Blob (i_lcData in     clob
                          ,u_lbData in out blob
                          );
    
    procedure pHttpCall (i_vcUrl          in     varchar2
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
                        ,i_vcBearerToken  in     varchar2 default null
                        );
  
    
    function fBoolToVarchar(i_boValue in    boolean) return varchar2;
    function fGetAuthURL(i_vcResponseType   in    varchar2 default 'code'
                        ,i_boDisableSignup  in    boolean  default false
                        ,i_boForceReapprove in    boolean  default false
                        ,i_vcRedirectUri    in    varchar2 default null
                        ,i_vcState          in    varchar2 default null
                        )return varchar2;
    
    function fExchangeToken(i_vcCode      in    varchar2
                           ,i_vcGrantType in    varchar2 default 'authorization_code'
                           ) return json;
                             
    function fGetAccountInfo(i_vcToken  in    varchar2
                            ,i_vcLocale in    varchar2 default c_vcLocale
                            )return json;

    
    function fUploadData(i_vcToken      in    varchar2
                        ,i_vcTargetPath in    varchar2
                        ,i_boOverwrite  in    boolean
                        ,i_lbData       in    blob
                        ) return json;
                        
    function fChunkedUpload(i_vcToken    in    varchar2
                           ,i_vcUploadId in    varchar2 default null
                           ,i_nuOffset   in    number   default 0
                           ,i_lbData     in    blob
                           )return json;
                           
    function fCommitChunkedUpload(i_vcToken     in      varchar2
                                 ,i_vcPath      in      varchar2
                                 ,i_vcUploadId  in      varchar2
                                 ,i_boOverwrite in      boolean   default true
                                 ,i_vcParentRev in      varchar2  default null
                                 ,i_vcLocale    in      varchar2  default c_vcLocale
                                 )return json;
                         
    function fDownloadData(i_vcToken in varchar2,
                           i_vcPath in varchar2) return blob;
                           
    function fGetMetadata(i_vcToken   in      varchar2
                         ,i_vcPath    in      varchar2
                         ,i_vcHash    in      varchar2
                         ,i_boList    in      boolean default false
                         ,i_vcLocale  in      varchar2 default c_vcLocale
                         ) return json;
                          
    function fGetDelta(i_vcToken      in      varchar2
                      ,i_vcCursor     in      varchar2
                      ,i_vcPathPrefix in      varchar2
                      ,i_vcLocale     in      varchar2 default c_vcLocale
                      )return json;
    
    function fCallLongpollDelta(i_vcToken   in      varchar2
                               ,i_vcCursor  in      varchar2
                               ,i_nuTimeout in      number default 30
                               )return json;
                     
    function fGetRevisions(i_vcToken  in      varchar2
                          ,i_vcPath   in      varchar2
                          )return json_list;
                          
    function fRestore(i_vcToken   in    varchar2
                     ,i_vcPath    in    varchar2
                     ,i_vcRev     in    varchar2
                     ,i_vcLocale  in    varchar2 default c_vcLocale
                     )return json;
                     
    function fSearch(i_vcToken          in    varchar2
                    ,i_vcPath           in    varchar2 default null
                    ,i_vcQuery          in    varchar2
                    ,i_nuFileLimit      in    number    default 1000
                    ,i_boIncludeDeleted in    boolean   default false
                    ,i_vcLocale         in    varchar2  default c_vcLocale
                    )return json_list;
    
    function fShares(i_vcToken    in    varchar2
                    ,i_vcPath     in    varchar2
                    ,i_boURLShort in    boolean  default true
                    ,i_vcLocale   in    varchar2 default c_vcLocale
                    )return json;
                    
    function fMedia(i_vcToken   in      varchar2
                   ,i_vcPath    in      varchar2
                   ,i_vcLocale  in      varchar2 default c_vcLocale
                   )return json;
                   
    function fCopyRef(i_vcToken   in    varchar2
                     ,i_vcPath    in    varchar2
                     )return json;
                     
    function fGetThumbnail(i_vcToken  in   varchar2
                          ,i_vcPath   in   varchar2
                          ,i_vcFormat in   varchar2 default 'jpeg'
                          ,i_vcSize   in   varchar2 default 's'
                          )return blob;
                          
    function fGetPreview(i_vcToken  in    varchar2
                        ,i_vcPath   in    varchar2
                        ,i_vcRev    in    varchar2 default null
                        )return blob;
                                
    -----------------                           
    -- File Operations                           
    function fCreateFolder(i_vcToken  in      varchar2
                          ,i_vcRoot   in      varchar2 default 'auto'
                          ,i_vcPath   in      varchar2
                          ,i_vcLocale in      varchar2 default c_vcLocale
                          ) return json;
                          
    function fDelete(i_vcToken  in      varchar2
                    ,i_vcRoot   in      varchar2 default 'auto'
                    ,i_vcPath   in      varchar2
                    ,i_vcLocale in      varchar2 default c_vcLocale
                    ) return json;
                    
    function fMove(i_vcToken    in      varchar2
                  ,i_vcRoot     in      varchar2 default 'auto'
                  ,i_vcPathFrom in      varchar2
                  ,i_vcPathTo   in      varchar2
                  ,i_vcLocale   in      varchar2 default c_vcLocale
                  ) return json;
                  
    function fCopy(i_vcToken    in      varchar2
                  ,i_vcRoot     in      varchar2 default 'auto'
                  ,i_vcPathFrom in      varchar2
                  ,i_vcPathTo   in      varchar2
                  ,i_vcLocale   in      varchar2 default c_vcLocale
                  ,i_vcCopyRef  in      varchar2 default null
                  ) return json;
                  
     ------------
     -- Weitere Funktionen
     
     function fLargeUpload(i_vcToken      in     varchar2
                          ,i_vcTargetPath in    varchar2
                          ,i_boOverwrite  in    boolean
                          ,i_lbData       in    blob
                          ) return json;
    
END docDropbox2;

/

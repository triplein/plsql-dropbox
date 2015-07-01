--------------------------------------------------------
--  DDL for Type DOGTOFILEDATA
--------------------------------------------------------

  CREATE OR REPLACE TYPE "DOGTOFILEDATA" force as object (
    lbdata      blob,
    vcToken     varchar2(100),
    vcPath      varchar2(255),
    vcProvider  varchar2(50),
    
    constructor function dogtofiledata(i_lbdata     in    blob
                                      ,i_vcPath     in    varchar2
                                      ,i_vcProvider in    varchar2
                                      ,i_vcToken    in    varchar2
                                      )return self as result,
                                      
    constructor function dogToFiledata(i_vcPath     in varchar2
                                      ,i_vcToken    in varchar2
                                      ,i_vcProvider in varchar2
                                      ) return self as result,
    member procedure pDownloadFile
);
/
CREATE OR REPLACE TYPE BODY "DOGTOFILEDATA" as

  constructor function dogtofiledata(i_lbdata     in    blob
                                    ,i_vcPath     in    varchar2
                                    ,i_vcProvider in    varchar2
                                    ,i_vcToken    in    varchar2
                                    )return self as result as
  begin
    vcToken := i_vcToken;
    vcPath := i_vcPath;
    lbData := i_lbData;
    vcProvider := i_vcProvider;
    return;
  end dogtofiledata;


  constructor function dogToFiledata(i_vcPath     in varchar2
                                    ,i_vcToken    in varchar2
                                    ,i_vcProvider in varchar2
                                    ) return self as result as
  begin
    vcToken := i_vcToken;
    vcPath := i_vcPath;
    vcProvider := i_vcProvider;
    return;
  end dogtofiledata;

  member procedure pDownloadFile as
  begin
    case upper(vcProvider)
      when 'DROPBOX' then
        lbData := docDropbox.fDownloadData(vcToken, vcPath);
    else
      null;
    end case;
  end pdownloadfile;

end;

/

--------------------------------------------------------
--  DDL for Type DOGTOMETADATA
--------------------------------------------------------

  CREATE OR REPLACE TYPE "DOGTOMETADATA" force as object (
  vcName        varchar2(255),
  nuSize        number,
  vcPath        varchar2(255),
  chIsDir       char(1),
  vcRev         varchar2(255),
  daModified    date,
  vcMimeType    varchar2(100),
  chThumbExists char(1),
  vcIconLink    varchar2(255),
  lcContent     clob,
  vcProvider    varchar2(50),
  chExists      char(1),
  vcToken       varchar2(100),

  
  
  constructor function dogToMetadata(i_vcToken in varchar2, i_vcPath in varchar2, i_vcProvider in varchar2) return self as result,
  constructor function dogToMetadata(i_jsJson in json, i_vcToken in varchar2, i_vcProvider in varchar2) return self as result,
  member procedure pDownloadMetadata(i_vcPath in varchar2),
  member procedure pSetValues(i_jsJson in json)
  );
/
CREATE OR REPLACE TYPE BODY "DOGTOMETADATA" AS
  
  constructor function dogToMetadata(i_vcToken in varchar2, i_vcPath in varchar2, i_vcProvider in varchar2) return self as result as
  begin
    vcProvider := i_vcProvider;
    vcToken := i_vcToken;
    pDownloadMetadata(i_vcPath);
    return;
    exception
      when docDropbox.g_exFileNotFound then
        chExists := 'N';
        vcPath := i_vcPath;
        return;
  end dogToMetadata;
  
  constructor function dogToMetadata(i_jsJson in json, i_vcToken in varchar2, i_vcProvider in varchar2) return self as result as
  begin
    vcProvider := i_vcProvider;
    vcToken := i_vcToken;
    pSetValues(i_jsJson);
    return;
  end dogToMetadata;
  
   /** @headcom
    *     Lädt die Metadaten der Datei herunter und platziert sie in das Metadaten-Objekt
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_vcPath       Pfad zur Datei
    * 
    * @see
    *   
    *
    * @history
    *       2014-08-25  ms  Initial
    *
    */
  member procedure  pDownloadMetadata(i_vcPath in varchar2) as
    i_jsJson       json;
    file_not_found exception;
  begin
    case upper(vcProvider)
      when 'DROPBOX' then
        i_jsJson := docDropbox.fGetMetadata(vcToken, i_vcPath, null, true, null);
        if i_jsJson.exist('error') then
          if(instr(i_jsJson.get('error').get_string, 'not found') != 0) then
            raise docDropbox.g_exFileNotFound;
          else return;
          end if;
        else pSetValues(i_jsJson);
        end if;
    else 
      null;
    end case;
    exception
      when file_not_found then
        raise file_not_found;
  end pDownloadMetadata;
  
  
  /** @headcom
    *     Platziert alle Daten aus der JSON Datei in die Werteliste
    *
    * @creator    ms
    *
    * @version    n/a
    *
    * @param      i_jsJson   Die zu verarbeitende JSON Datei
    * 
    * @see
    *   
    *
    * @history
    *       2014-08-25  ms  Initial
    *
    */
  
  member procedure pSetValues(i_jsJson in json) as
    i_vcFormatDate varchar2(255);
  begin
    case upper(vcProvider)
      when 'DROPBOX' then
        vcName := rtrim(substr(i_jsJson.get('path').to_char, instr(i_jsJson.get('path').to_char, '/', -1, 1)+1), '"');
        nuSize := i_jsJson.get('bytes').get_number;
        vcPath := i_jsJson.get('path').get_string;
        if i_jsJson.get('is_dir').to_char = 'true' then
          chIsDir := 'Y';
        else
          chIsDir := 'N';
          vcMimeType := i_jsJson.get('mime_type').get_string;
        end if;
        
        if(i_jsJson.exist('rev')) then
          vcRev := i_jsJson.get('rev').get_string;
        end if;
        
        if(i_jsJson.exist('modified')) then
          i_vcFormatDate := i_jsJson.get('modified').to_char;
          i_vcFormatDate := substr(i_vcFormatDate, 0, length(i_vcFormatDate)-6);
          i_vcFormatDate := ltrim(i_vcFormatDate, '"');
          i_vcFormatDate := substr(i_vcFormatDate, 6, length(i_vcFormatDate));
        
          self.daModified := to_date(i_vcFormatDate, 'DD MON YYYY HH24:MI:SS');
        end if;
        
        
        if i_jsJson.get('thumb_exists').get_bool = true then
          chThumbExists := 'Y';
        else
          chThumbExists := 'N';
        end if;
        
        vcIconLink := i_jsJson.get('icon').get_string;
        if chIsDir = 'Y' and i_jsJson.exist('contents') then
          self.lcContent := i_jsJson.get('contents').to_char;
        end if;
        
        chExists := 'Y';
        else
          null;
    end case;
    
  end;

end;

/

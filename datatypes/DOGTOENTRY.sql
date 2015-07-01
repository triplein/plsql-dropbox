--------------------------------------------------------
--  DDL for Type DOGTOENTRY
--------------------------------------------------------

  CREATE OR REPLACE TYPE "DOGTOENTRY" force under dogToEntryAbstract (
    vcToken   varchar2(100),
    constructor function dogToEntry(i_vcToken    in varchar2 
                                   ,i_vcPath     in varchar2 
                                   ,i_vcProvider in varchar2
                                   ) return self as result,
    
    constructor function dogToEntry(i_toMetadata in dogToMetadata,
                                    i_toFiledata in dogToFiledata
                                   ) return self as result,
                                   
    member function fCopyEntry(i_vcTargetPath in varchar2) return dogToEntry,
    member procedure pCreateEntry(i_lbData in blob),  -- Datei hochladen
    member procedure pCreateEntry,                    -- Ordner erstellen
    member procedure pUpdateEntry(i_lbData in blob),  -- Existierende Datei überschreiben
    member procedure pMoveEntry(i_vcTargetPath in varchar2),
    member procedure pDeleteEntry,
    
    member function  fGetEntriesChd  return dogTtEntry,
    member function  fGetEntryPar    return dogTtEntry,
    member function  fGetEntriesSib  return dogTtEntry,
    
    member function  fGetFileLinkTmp    return varchar2
    
    
)
/
CREATE OR REPLACE TYPE BODY "DOGTOENTRY" as

  constructor function dogToEntry(i_vcToken in varchar2, i_vcPath in varchar2, i_vcProvider in varchar2) return self as result AS
  begin
    toMetadata := dogToMetadata(i_vcToken, i_vcPath, i_vcProvider);
    return;
  end dogToEntry;
  
  constructor function dogToEntry(i_ToMetadata in dogToMetadata, i_toFiledata in dogToFiledata) return self as result as
  begin
    toMetadata := i_toMetadata;
    toFiledata := i_toFiledata;
    return;
  end dogToEntry;
  
  member function fCopyEntry(i_vcTargetPath in varchar2) return dogToEntry as
    l_toMetadata  dogToMetadata;
    l_toFiledata  dogToFiledata;
    l_toEntry     dogToEntry;
  begin
    case upper(toMetadata.vcProvider)
      when 'DROPBOX' then
        l_toMetadata := dogToMetadata(docDropbox.fCopy(vcToken, 'auto', toMetadata.vcPath, i_vcTargetPath), vcToken, 'Dropbox');
        l_toFiledata := dogToFiledata(l_toMetadata.vcPath, vcToken, 'Dropbox');
        l_toEntry := dogToEntry(l_toMetadata, l_toFiledata);
      else
        null;
    end case;
    return l_toEntry; 
  end fCopyEntry;
  
  member procedure pCreateEntry as
  begin
    case upper(toMetadata.vcProvider)
      when 'DROPBOX' then
        toMetadata.pSetValues(docDropbox.fCreateFolder(toMetadata.vcToken, 'auto', toMetadata.vcPath, null));
      else
        null;
      end case;
  end pCreateEntry;
  
  member procedure pCreateEntry(i_lbData in blob) as
  begin
    case upper(toMetadata.vcProvider)
      when 'DROPBOX' then
        toMetadata.pSetValues(docDropbox.fLargeUpload(toMetadata.vcToken, toMetadata.vcPath, false, i_lbData));
      else
        null;
      end case;
  end pCreateEntry;

  
  member procedure pUpdateEntry(i_lbData in blob) as
  begin
    case upper(toMetadata.vcProvider)
      when 'DROPBOX' then
        if toMetadata.chExists != 'Y' then  
          toMetadata.pSetValues(docDropbox.fLargeUpload(toMetadata.vcToken, toMetadata.vcPath, true, i_lbData));
        else 
          raise docDropbox.g_exFileExists;
        end if;
      end case;
  end pUpdateEntry;
  
  member procedure pMoveEntry(i_vcTargetPath in varchar2) as
  begin
    case upper(toMetadata.vcProvider)
      when 'DROPBOX' then
        toMetadata.pSetValues(docDropbox.fMove(vcToken, 'auto', toMetadata.vcPath, i_vcTargetPath, null));
      else
        null;
      end case;
  end pMoveEntry;
  
  member procedure pDeleteEntry as
  begin
    case upper(toMetadata.vcProvider)
      when 'DROPBOX' then
        toMetadata.pSetValues(docDropbox.fDelete(vcToken, 'auto', toMetadata.vcPath, null));
      else
        null;
      end case;
  end pDeleteEntry;
  
  member function fGetEntriesChd return dogTtEntry as
    l_ttTable dogTtEntry := dogTtEntry();
    l_jlJson json_list;
    l_jsJson json;
    l_toMetadata    dogToMetadata;
    l_toFiledata    dogToFiledata;
    l_toEntry       dogToEntry;
  begin
    l_jlJson := json_list(toMetadata.lcContent);
    for i in 1..l_jlJson.count loop
      l_ttTable.extend;
      l_toMetadata := dogToMetadata(json(l_jlJson.get(i).to_char), toMetadata.vcToken, 'Dropbox');
      l_toFiledata := dogToFiledata(l_toMetadata.vcPath, vcToken, 'Dropbox');
      l_toEntry := dogToEntry(l_toMetadata, l_toFiledata);
      l_ttTable(l_ttTable.last) := l_toEntry;
    end loop;
    return l_ttTable;
  end;
  
  member function fGetEntryPar return dogTtEntry as
    l_toMetadata    dogToMetadata;
    l_toFiledata    dogToFiledata;
    l_ttEntry       dogTtEntry := dogTtEntry();
    l_vcParentPath  varchar2(255);
  begin
    
    l_vcParentPath := substr(toMetadata.vcPath, 0, instr(toMetadata.vcPath, '/', -1)-1);
    
    l_toMetadata := dogToMetadata(toMetadata.vcToken, l_vcParentPath, 'Dropbox');
    l_toFiledata := dogToFiledata(l_vcParentPath, toMetadata.vcToken, 'Dropbox');
    
    l_ttEntry.extend;
    l_ttEntry(l_ttEntry.first) := dogToEntry(l_toMetadata, l_toFiledata);
    
    return l_ttEntry;
    
  end;
  
  member function fGetEntriesSib return dogTtEntry as
  l_ttTable dogTtEntry := dogTtEntry();
    l_jlJson json_list;
    l_jsJson json;
    l_toMetadata    dogToMetadata;
    l_toFiledata    dogToFiledata;
    l_toEntry       dogToEntry;
    l_ttEntry       dogTtEntry;
    l_toParent      dogToEntry;
  begin
    
    l_ttEntry := self.fGetEntryPar;
    l_toParent := dogToEntry(l_ttEntry(l_ttEntry.first).toMetadata, l_ttEntry(l_ttEntry.first).toFiledata);
    l_jlJson := json_list(l_toParent.toMetadata.lcContent);
    for i in 1..l_jlJson.count loop
      l_ttTable.extend;
      l_toMetadata := dogToMetadata(json(l_jlJson.get(i).to_char), toMetadata.vcToken, 'Dropbox');
      l_toFiledata := dogToFiledata(l_toMetadata.vcPath, vcToken, 'Dropbox');
      l_toEntry := dogToEntry(l_toMetadata, l_toFiledata);
      l_ttTable(l_ttTable.last) := l_toEntry;
    end loop;
    return l_ttTable;
  end;
  
  member function  fGetFileLinkTmp return varchar2 as
    l_jsResult    json;
  begin
    l_jsResult := docDropbox.fMedia(toMetadata.vcToken, toMetadata.vcPath, null);
    if l_jsResult.exist('url') then
      return l_jsResult.get('url').get_string;
    else 
      dbms_output.put_line(l_jsResult.get('error').get_string);
      raise docDropbox.g_exNotAllowed;
    end if;
  end;
end;

/

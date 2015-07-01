
/*                     =============================
*                      === Authenticating a user ===
*                      =============================
*
* To authenticate a user, the easiest method is to generate a authentication url,
* let the user login there, accept your app and copy the key back in your app.
* 
* Afterwards you can exchange this key for an access token, which allows you
* to do API calls for this user for some years or until he withdraws the key. 
*
* But first, define your App key and App secret in the package specifications
* as instructed in the README. Then you're ready to go. 
*
*
* 1. Generate a authentication URL
*/

DECLARE
  l_vcAuthURL varchar2(255);
BEGIN
  l_vcAuthURL := docDropbox.fGetAuthURL(
                            i_vcResponseType    => 'code',
                            i_boDisableSignup   => false,
                            i_boForceReapprove  => false,
                            i_vcRedirectUri     => null,
                            i_vcState           => null);
  /*
  * With the authorization URL in hand, we can now ask the user to authorize your
  * app. To avoid the hassle of setting up a web server to automatically get
  * the token, we're just printing the URL and asking the user to copy the exchange
  * token. 
  * In real world apps however you might prefer the more seamless approach of using the
  * redirection. 
  */
  dbms_output.put_line('1. Go to: ' || l_vcAuthURL);
  dbms_output.put_line('2. Click "Allow" (you might have to log in first)');
  dbms_output.put_line('3. Copy the authorization code.');
  dbms_output.put_line('4. Insert this code in l_vcExchangeToken in the next step');
END;

/*
* 2. Exchange the code for a permanent access token
*
* We can now exchange the code for a access token. This will then be used for
* every API call.
*/

DECLARE
  l_vcExchangeToken varchar2(300) := 'ExxxxxxxxAAAAAAAAAr_RwfjxxxxxxLn1YhE-dg'; -- Insert token from previous part here
  l_jsAccessToken   json;
BEGIN
  l_jsAccessToken := docDropbox.fExchangeToken(
                              i_vcCode      => l_vcExchangeToken,
                              i_vcGrantType => 'authorization_code');
                              
  l_jsAccessToken.print();
  /*
  * Copy the code from the DBMS Output at "access_token" and insert it in every
  * following example in the variable l_vcAuthCode
  */
END;

/*
* The access token is all you'll need to make API requests on behalf of this 
* user, so you should store it away for safe-keeping. 
* The authentication process is now finished and we can test the token by
* retrieving the users account information.
*/

DECLARE
  l_vcAuthCode           varchar2(300) := 'EzeO6kKTiq4AAAAAAAAAsHPpCnkq5UWMfhN-xxxxxxxxxxxxxxxxxxxx';
  l_jsAccountInformation json;
BEGIN
  l_jsAccountInformation := docDropbox.fGetAccountInfo(
                                            i_vcToken => 'EzeO6kKTiq4AAAAAAAAAsHPpCnkq5UWMfhN-xxxxxxxxxxxxxxxxxxxx');
  
  l_jsAccountInformation.print();
END;

/*                      =======================
*                       === Uploading files ===
*                       =======================
*               
* Uploading files is done by passing a blob to the function. 
* For this example we can use the data types, to simplify the process. 
* Every dogToEntry represents a file or folder on the cloud, dogToMetadata
* and dogToFiledata contain further information and the raw blob. 
*/

DECLARE
  l_toNewEntry  dogToEntry;
  l_vcAuthCode  varchar2(300) := 'EzeO6kKTiq4AAAAAAAAAsHPpCnkq5UWMfhN-xxxxxxxxxxxxxxxxxxxx';
  
  -- Insert a file in an Oracle Directory to test the upload with
  l_fiSrcLoc    BFILE := bfilename('TESTDATEN', 'redrock.jpg');
  l_lbDestLoc   BLOB;
BEGIN
  -- Preparing the file for upload by converting it into a blob
  dbms_lob.createTemporary(l_lbDestLoc, true);
  dbms_lob.open(l_fiSrcLoc, dbms_lob.lob_readonly);
  dbms_lob.open(l_lbDestLoc, dbms_lob.lob_readwrite);
  dbms_lob.loadFromFile(DEST_LOB => l_lbDestLoc, SRC_LOB => l_fiSrcLoc, AMOUNT => dbms_lob.getlength(l_fiSrcLoc));
  
  dbms_lob.close(l_lbDestLoc);
  dbms_lob.close(l_fiSrcLoc);
  
  -- Define a new entry, no changes are made to the Dropbox at this point
  l_toNewEntry := dogToEntry(
                        i_vcToken    => l_vcAuthCode,
                        i_vcPath     => '/RedRock.jpg',
                        i_vcProvider => 'Dropbox');
  -- Create the entry with the blob
  l_toNewEntry.pCreateEntry(l_lbDestLoc);
END;

/*                    =======================
*                     === Listing folders ===
*                     =======================
*
* Using the data types you can easily list the content of folders in a table.
* The next example will list all the necessary data needed to display a folder
* in a similar structure like Dropbox. 
* Insert the access token from before into the placeholder below to test it.
*/ 

SELECT 
  tList.toMetadata.vcName,
  tList.toMetadata.vcMimeType,
  tList.toMetadata.daModified,
  tList.toMetadata.nuSize,
  tList.toMetadata.chThumbExists,
  tList.toMetadata.vcIconLink
  FROM table(dogToEntry('EzeO6kKTiq4AAAAAAAAAsHPpCnkq5UWMfhN-xxxxxxxxxxxxxxxxxxxx', '/', 'Dropbox').fGetEntriesChd()) tList;
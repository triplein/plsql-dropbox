Dropbox API for PL/SQL
==================

This set includes various packages and data types for handling with the Dropbox Core API. Basically every function that is listed on the [Dropbox Core API Documentation](https://www.dropbox.com/developers/core/docs#thumbnails) is usable with simple PL/SQL functions, named and specified in a similar fashion to simplify looking up in the official documentation. 

The *docDropbox* package will return simple JSON data, as returned from the Dropbox API itself. The data types can be used to access some of these functions in a more native way, by placing the values in variables. 

## Requirements

- Oracle Database 11g (10g *might* be supported)
- Installed [PL/JSON](https://github.com/pljson/pljson)
- [Database ACL configured](http://docs.oracle.com/cd/B28359_01/appdev.111/b28419/d_networkacl_adm.htm#CHDJFJFF) to allow every call to `https://*.dropboxapi.com` and `https://*.dropbox.com`
- [Oracle Wallet](http://docs.oracle.com/cd/B10501_01/network.920/a96573/asowalet.htm) configured

## Installation
  
Import the `.pkb`, `.pks` and `.sql` files into your database.
 
- **docDropbox** is *required* for basic functionality
- **dogTo(...)** and **dogTt(...)** are *optional* data types that wrap several functions of docDropbox to provide a more native way of accessing a users Dropbox

## Configuration

To use the functions of the Dropbox API, it's required to create an App at the Developer Console. 

1. If you haven't already, register at [Dropbox](www.dropbox.com) and log in afterwards
2. Create a new Dropbox API app at the [Developer App Console](https://www.dropbox.com/developers/apps/create) with the settings you need 
3. Afterwards open your App from the [Your apps](https://www.dropbox.com/developers/apps) list and copy the **App key** and **App secret**
4. Open the docDropbox package specifications and insert your App key into `c_vcAppKey` and the App secret into `c_vcAppSecret`

Also, setup the Oracle Wallet by inserting the corresponding values into `c_vcWalletPath` and `c_vcWalletPwd`. 

## Usage

The functions in docDropbox basically only call the HTTP API of Dropbox. Every function is documented and includes a link to the Dropbox API Documentation for the underlying feature. Using this link you can get a closer look at the expected input values and output. 

Take a look at the `Introduction.sql` file for a short tutorial on authorizing users, uploading files, and listing folders. 

## Troubleshooting

### Oracle ACL
Starting with Oracle Database 11g, Access Control Lists restrict the traffic from the database. docDropbox will report an error as the `utl_http` call to dropbox.com will fail usually with standard settings.
#### Solution
[This](http://docs.oracle.com/cd/B28359_01/appdev.111/b28419/d_networkacl_adm.htm#CHDJFJFF) provides more information on configuring the Oracle ACL.

Every subdomain of `dropbox.com` should be accessible through the database to provide full functionality. 

### Oracle Wallet
To make calls to HTTPS servers using the `utl_http` package, the Oracle Wallet has to be configured.

#### Solution

For more information on Oracle Wallet see [Using Oracle Wallet Manager](http://docs.oracle.com/cd/B10501_01/network.920/a96573/asowalet.htm)

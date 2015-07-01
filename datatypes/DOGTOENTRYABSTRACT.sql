--------------------------------------------------------
--  DDL for Type DOGTOENTRYABSTRACT
--------------------------------------------------------

  CREATE OR REPLACE TYPE "DOGTOENTRYABSTRACT" force as object (
    toMetadata  dogToMetadata,
    toFiledata  dogToFiledata
) not final not instantiable

/

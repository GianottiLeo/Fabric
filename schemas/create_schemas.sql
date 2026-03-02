IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = '_Gold')    EXEC('CREATE SCHEMA [_Gold]');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = '_Silver')  EXEC('CREATE SCHEMA [_Silver]');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = '_Staging') EXEC('CREATE SCHEMA [_Staging]');

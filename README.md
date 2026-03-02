# EverChain Fabric Data Pipeline

This repository documents the SQL stored procedures, views, and pipeline architecture.

## Architecture
Source: [EC Production] -> Gold Layer -> Staging Layer -> Silver Layer -> View

## Execution
EXEC [_Gold].[usp_Refresh_All_Gold];
EXEC [_Silver].[usp_Refresh_EC_Portfolio_Expanded];

## Folders
- docs/ - Full documentation
- schemas/ - Schema creation
- gold/ - Gold layer (8 procs + 1 view)
- staging/ - Staging layer (7 procs)
- silver/ - Silver orchestrator (1 proc)

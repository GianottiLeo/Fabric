# EverChain Data Pipeline — Complete Inventory

## Architecture Overview

```
Source: [EC Production]  →  Gold Layer  →  Staging Layer  →  Silver Layer  →  View
```

### Execution Order

```
[_Gold].[usp_Refresh_All_Gold]                          ← Run FIRST
  ├── Step 1: [_Gold].[usp_Refresh_Portfolio]
  ├── Step 2: [_Gold].[usp_Refresh_Business]
  ├── Step 3: [_Gold].[usp_Refresh_Portfolio_Row]
  ├── Step 4: [_Gold].[usp_Refresh_Portfolio_Aggregate]
  ├── Step 5: [_Gold].[usp_Refresh_Portfolio_Bid]
  ├── Step 6: [_Gold].[usp_Refresh_Complaints]
  └── Step 7: [_Gold].[usp_Refresh_Complaint_Aggregate]

[_Silver].[usp_Refresh_EC_Portfolio_Expanded]            ← Run SECOND
  ├── Step 1: [_Staging].[usp_Refresh_PortfolioEvents]
  ├── Step 2: [_Staging].[usp_Refresh_PortfolioFunding]
  ├── Step 3: [_Staging].[usp_Refresh_PortfolioRowAggregates]
  ├── Step 4: [_Staging].[usp_Refresh_BidsPostSaleComplaints]
  ├── Step 5: [_Staging].[usp_Refresh_SilverBase]
  ├── Step 6: [_Staging].[usp_Refresh_Partnership]
  ├── Step 7a: [_Staging].[usp_Refresh_Formulas]
  ├── Step 7b: Builds [_Silver].[_EC_Portfolio_Expanded]
  └── Cleanup: Drops staging tables

[_Gold].[VW_Bidders]                                     ← Live view, no refresh needed
```

### Scheduling (Fabric Notebook)

```sql
%%sql
EXEC [_Gold].[usp_Refresh_All_Gold];
EXEC [_Silver].[usp_Refresh_EC_Portfolio_Expanded];
```

---

## Procedure Inventory

| # | Schema | Procedure / View | Type | Creates | File |
|---|--------|-----------------|------|---------|------|
| 1 | `_Gold` | `usp_Refresh_Portfolio` | Proc | `[_Gold].[Portfolio]` | `gold_01_Portfolio.sql` |
| 2 | `_Gold` | `usp_Refresh_Business` | Proc | `[_Gold].[Business]` | `gold_02_Business.sql` |
| 3 | `_Gold` | `usp_Refresh_Portfolio_Row` | Proc | `[_Gold].[Portfolio_Row]` | `gold_03_Portfolio_Row.sql` |
| 4 | `_Gold` | `usp_Refresh_Portfolio_Aggregate` | Proc | `[_Gold].[Portfolio_Aggregate]` | `gold_04_Portfolio_Aggregate.sql` |
| 5 | `_Gold` | `usp_Refresh_Portfolio_Bid` | Proc | `[_Gold].[Portfolio_Bid]` | `gold_05_Portfolio_Bid.sql` |
| 6 | `_Gold` | `usp_Refresh_Complaints` | Proc | `[_Gold].[Complaints]` | `gold_06_Complaints.sql` |
| 7 | `_Gold` | `usp_Refresh_Complaint_Aggregate` | Proc | `[_Gold].[Complaint_Aggregate]` | `gold_07_Complaint_Aggregate.sql` |
| 8 | `_Staging` | `usp_Refresh_PortfolioEvents` | Proc | `[_Staging].[PortfolioEvents]` | `proc_01_PortfolioEvents.sql` |
| 9 | `_Staging` | `usp_Refresh_PortfolioFunding` | Proc | `[_Staging].[PortfolioFunding]` | `proc_02_PortfolioFunding.sql` |
| 10 | `_Staging` | `usp_Refresh_PortfolioRowAggregates` | Proc | `[_Staging].[PortfolioRowAggregates]` | `proc_03_PortfolioRowAggregates.sql` |
| 11 | `_Staging` | `usp_Refresh_BidsPostSaleComplaints` | Proc | `[_Staging].[BidAggregates]`, `[_Staging].[PostSaleAggregates]`, `[_Staging].[ComplaintsByBuyer]`, `[_Staging].[ComplaintsByPID]` | `proc_04_BidsPostSaleComplaints.sql` |
| 12 | `_Staging` | `usp_Refresh_SilverBase` | Proc | `[_Staging].[SilverBase]` | `proc_05_SilverBase.sql` |
| 13 | `_Staging` | `usp_Refresh_Partnership` | Proc | `[_Staging].[PartnershipBase]` | `proc_06_Partnership.sql` |
| 14 | `_Staging` | `usp_Refresh_Formulas` | Proc | `[_Staging].[FormulaComplete]` | `proc_07_Formulas.sql` |
| 15 | `_Gold` | `usp_Refresh_All_Gold` | Orchestrator | Calls 1–7 | `gold_00_Master.sql` |
| 16 | `_Silver` | `usp_Refresh_EC_Portfolio_Expanded` | Orchestrator | Calls 8–14 + builds `[_Silver].[_EC_Portfolio_Expanded]` | `proc_08_Final.sql` |
| 17 | `_Gold` | `VW_Bidders` | View | Live read | `gold_08_Bidders.sql` |

---

## Schemas Required

```sql
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = '_Gold')    EXEC('CREATE SCHEMA [_Gold]');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = '_Silver')  EXEC('CREATE SCHEMA [_Silver]');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = '_Staging') EXEC('CREATE SCHEMA [_Staging]');
```

---

## Tables Created

### Gold Layer (persisted, indexed)
| Table | Indexes |
|-------|---------|
| `[_Gold].[Portfolio]` | `Id`, `SellerId`, `BuyerId`, `PortfolioNumber` |
| `[_Gold].[Business]` | `Id`, `ClientId` |
| `[_Gold].[Portfolio_Row]` | `PID`, `PortfolioRowGuid` |
| `[_Gold].[Portfolio_Aggregate]` | `PortfolioId`, `Category` |
| `[_Gold].[Portfolio_Bid]` | `PortfolioId`, `BuyerId` |
| `[_Gold].[Complaints]` | `PID` |
| `[_Gold].[Complaint_Aggregate]` | — |

### Staging Layer (temporary, cleaned up after Silver build)
| Table | Purpose |
|-------|---------|
| `[_Staging].[PortfolioEvents]` | Listed/Awarded/PSA/Sold event dates |
| `[_Staging].[PortfolioFunding]` | Funding event dates |
| `[_Staging].[PortfolioRowAggregates]` | Row-level aggregates per portfolio |
| `[_Staging].[BidAggregates]` | Bid stats per portfolio |
| `[_Staging].[PostSaleAggregates]` | Post-sale stats per portfolio |
| `[_Staging].[ComplaintsByBuyer]` | Complaint counts by buyer |
| `[_Staging].[ComplaintsByPID]` | Complaint counts by portfolio |
| `[_Staging].[SilverBase]` | Joined base for formulas |
| `[_Staging].[PartnershipBase]` | Partnership scores |
| `[_Staging].[FormulaComplete]` | All computed formulas |

### Silver Layer (final output)
| Table | Purpose |
|-------|---------|
| `[_Silver].[_EC_Portfolio_Expanded]` | Final denormalized portfolio table |
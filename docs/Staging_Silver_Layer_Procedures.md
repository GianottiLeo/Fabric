# Staging & Silver Layer Procedures

> **Note:** These procedures are called internally by `[_Silver].[usp_Refresh_EC_Portfolio_Expanded]`.
> You do NOT need to run them individually.

## Schema Setup

```sql
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = '_Staging') EXEC('CREATE SCHEMA [_Staging]');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = '_Silver')  EXEC('CREATE SCHEMA [_Silver]');
```

---

## proc_01_PortfolioEvents.sql

> Refer to your existing file: `proc_01_PortfolioEvents.sql`
> Creates: `[_Staging].[PortfolioEvents]`

---

## proc_02_PortfolioFunding.sql

> Refer to your existing file: `proc_02_PortfolioFunding.sql`
> Creates: `[_Staging].[PortfolioFunding]`

---

## proc_03_PortfolioRowAggregates.sql

> Refer to your existing file: `proc_03_PortfolioRowAggregates.sql`
> Creates: `[_Staging].[PortfolioRowAggregates]`

---

## proc_04_BidsPostSaleComplaints.sql

> Refer to your existing file: `proc_04_BidsPostSaleComplaints.sql`
> Creates: `[_Staging].[BidAggregates]`, `[_Staging].[PostSaleAggregates]`, `[_Staging].[ComplaintsByBuyer]`, `[_Staging].[ComplaintsByPID]`

---

## proc_05_SilverBase.sql

> Refer to your existing file: `proc_05_SilverBase.sql`
> Creates: `[_Staging].[SilverBase]`

---

## proc_06_Partnership.sql

> Refer to your existing file: `proc_06_Partnership.sql`
> Creates: `[_Staging].[PartnershipBase]`

---

## proc_07_Formulas.sql

> Refer to your existing file: `proc_07_Formulas.sql`
> Creates: `[_Staging].[FormulaComplete]`

---

## proc_08_Final.sql — Silver Orchestrator

```sql
IF OBJECT_ID('[_Silver].[usp_Refresh_EC_Portfolio_Expanded]', 'P') IS NOT NULL
    DROP PROCEDURE [_Silver].[usp_Refresh_EC_Portfolio_Expanded];
GO

CREATE OR ALTER PROCEDURE [_Silver].[usp_Refresh_EC_Portfolio_Expanded]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_start DATETIME2, @msg NVARCHAR(200);

    -- Step 1
    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 1/7: Refreshing Portfolio Events...';
    EXEC [_Staging].[usp_Refresh_PortfolioEvents];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    -- Step 2
    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 2/7: Refreshing Portfolio Funding...';
    EXEC [_Staging].[usp_Refresh_PortfolioFunding];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    -- Step 3
    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 3/7: Refreshing Portfolio Row Aggregates...';
    EXEC [_Staging].[usp_Refresh_PortfolioRowAggregates];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    -- Step 4
    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 4/7: Refreshing Bids, PostSale & Complaints...';
    EXEC [_Staging].[usp_Refresh_BidsPostSaleComplaints];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    -- Step 5
    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 5/7: Building Silver Base...';
    EXEC [_Staging].[usp_Refresh_SilverBase];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    -- Step 6
    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 6/7: Computing Partnership Scores...';
    EXEC [_Staging].[usp_Refresh_Partnership];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    -- Step 7a
    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 7a/7: Computing Formulas...';
    EXEC [_Staging].[usp_Refresh_Formulas];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    -- Step 7b: Final Expanded table
    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 7b/7: Building Final Expanded Table...';

    IF OBJECT_ID('[_Silver].[_EC_Portfolio_Expanded]', 'U') IS NOT NULL
        DROP TABLE [_Silver].[_EC_Portfolio_Expanded];

    ;WITH Goals AS (
        SELECT
            Value AS GoalPercentageOfPostSaleRequestsCompletedIn30DaysOrLess,
            CAST(LEFT(YearMonth, 4) AS INTEGER) AS GoalYear,
            CAST(RIGHT(YearMonth, 2) AS INTEGER) AS GoalMonth
        FROM [Portfolio_Main_WH].[dbo].[goals-debt-sales]
        WHERE Metric = 'NumberOfBidsPerAuction'
    ),
    J1 AS (
        SELECT f15.*, g.GoalPercentageOfPostSaleRequestsCompletedIn30DaysOrLess
        FROM [_Staging].[FormulaComplete] f15
        LEFT JOIN Goals g ON g.GoalYear = f15.ListedUtcYear AND g.GoalMonth = f15.ListedUtcMonth
    ),
    F1 AS (
        SELECT *,
            MONTH(PortfolioCloseUtc) AS PortfolioCloseUtcMonth,
            YEAR(PortfolioCloseUtc) AS PortfolioCloseUtcYear,
            DATEPART(QUARTER, PortfolioCloseUtc) AS PortfolioCloseUtcQuarter
        FROM J1
    ),
    Macro AS (
        SELECT DISTINCT *,
            YEAR(FormattedDate) AS MacroeconomicDateYear,
            MONTH(FormattedDate) AS MacroeconomicDateMonth,
            DATEPART(QUARTER, FormattedDate) AS MacroeconomicDateQuarter
        FROM [Portfolio_Main_WH].[dbo].[macroeconomic-variable]
    )
    SELECT
        F1.*,
        m.*,
        CASE
            WHEN F1.PSAConfirmedUtc IS NULL OR F1.PSAConfirmedUtc IS NULL THEN NULL
            WHEN F1.PSAConfirmedUtc <= EOMONTH(DATEADD(month, 6, F1.[Update.AverageWriteOffDate]))
                AND F1.PSAConfirmedUtc >= F1.[Update.AverageWriteOffDate]
            THEN 0
            ELSE 1
        END AS WarehousedAvgWriteOfftoPSAConfirmed,
        CASE
            WHEN F1.PortfolioCloseUtc IS NULL OR F1.PSAConfirmedUtc IS NULL THEN NULL
            WHEN F1.PortfolioCloseUtc <= EOMONTH(DATEADD(month, 6, F1.[Update.AverageWriteOffDate]))
                AND F1.PortfolioCloseUtc >= F1.[Update.AverageWriteOffDate]
            THEN 0
            ELSE 1
        END AS WarehousedAvgWriteOfftoPortfolioClosed,
        CASE
            WHEN F1.SoldUtc IS NULL OR F1.PSAConfirmedUtc IS NULL THEN NULL
            WHEN F1.SoldUtc <= EOMONTH(DATEADD(month, 6, F1.[Update.AverageWriteOffDate]))
                AND F1.SoldUtc >= F1.[Update.AverageWriteOffDate]
            THEN 0
            ELSE 1
        END AS WarehousedAvgWriteOfftoSold
    INTO [_Silver].[_EC_Portfolio_Expanded]
    FROM F1
    LEFT JOIN Macro m
        ON F1.PortfolioCloseUtcQuarter = m.MacroeconomicDateQuarter
        AND F1.PortfolioCloseUtcYear = m.MacroeconomicDateYear
    WHERE ISNULL(F1.SellerLegalName, '') <> 'Halifax Highland Loans'
      AND ISNULL(F1.SellerClientName, '') <> '$DEF SELLERS - CANADA TEST';

    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    -- Cleanup staging
    PRINT 'Cleaning up staging tables...';
    IF OBJECT_ID('[_Staging].[PartnershipBase]', 'U') IS NOT NULL DROP TABLE [_Staging].[PartnershipBase];
    IF OBJECT_ID('[_Staging].[SilverBase]', 'U') IS NOT NULL DROP TABLE [_Staging].[SilverBase];
    IF OBJECT_ID('[_Staging].[FormulaComplete]', 'U') IS NOT NULL DROP TABLE [_Staging].[FormulaComplete];

    PRINT 'Pipeline refresh complete.';
END;
GO
```
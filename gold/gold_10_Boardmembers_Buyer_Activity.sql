-- Gold View: Boardmembers_Buyer_Activity
-- Source: Power Query M -> T-SQL conversion
-- Groups EC_Portfolio_Expanded by BuyerClientId to get first/last PortfolioCloseUtc
IF OBJECT_ID('[_Gold].[VW_Boardmembers_Buyer_Activity]', 'V') IS NOT NULL
    DROP VIEW [_Gold].[VW_Boardmembers_Buyer_Activity];
GO

CREATE VIEW [_Gold].[VW_Boardmembers_Buyer_Activity] AS
SELECT
    BuyerClientId,
    MAX(PortfolioCloseUtc) AS MaxDate,
    MIN(PortfolioCloseUtc) AS MinDate
FROM [_Silver].[_EC_Portfolio_Expanded]
WHERE BuyerClientId IS NOT NULL
GROUP BY BuyerClientId
HAVING MAX(PortfolioCloseUtc) IS NOT NULL;
GO
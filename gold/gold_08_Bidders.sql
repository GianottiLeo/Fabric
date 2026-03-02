IF OBJECT_ID('[_Gold].[VW_Bidders]', 'V') IS NOT NULL
    DROP VIEW [_Gold].[VW_Bidders];
GO

CREATE VIEW [_Gold].[VW_Bidders] AS
WITH PortfolioViewers AS (
    SELECT
        PE.PortfolioId AS C_PID,
        B.ClientId AS C_ClientId
    FROM [EC Production].[dbo].[PortfolioEvent] PE
    LEFT JOIN [EC Production].[AppAuthorization].[User] U
        ON PE.UserId = U.Id
    LEFT JOIN [_Gold].[Business] B
        ON U.TenantId COLLATE Latin1_General_100_CI_AS_KS_WS_SC_UTF8 = B.ClientTenantId COLLATE Latin1_General_100_CI_AS_KS_WS_SC_UTF8
    WHERE PE.EventType IN ('download data-masked', 'download data-masked uri', 'download data-masked-additional-unmask uri', 'read')
      AND B.IsBuyer = 1
),
BidsByBuyer AS (
    SELECT
        PB.PortfolioNumber AS PB_PortfolioNumber,
        PB.BuyerId AS PB_BuyerId,
        PB.Status AS PB_Status,
        B.ClientId AS B_ClientId
    FROM [_Gold].[Portfolio_Bid] PB
    LEFT JOIN [_Gold].[Business] B
        ON PB.BuyerId COLLATE Latin1_General_100_CI_AS_KS_WS_SC_UTF8 = B.Id COLLATE Latin1_General_100_CI_AS_KS_WS_SC_UTF8
)
SELECT DISTINCT
    BidsByBuyer.B_ClientId AS BidderClientId,
    B.BusinessName AS BuyerName,
    MONTH(PE.PortfolioCloseUtc) AS BidderMonth,
    YEAR(PE.PortfolioCloseUtc) AS BidderYear
FROM [Digital Hub].[_Silver].[_EC_Portfolio_Expanded] PE
LEFT JOIN BidsByBuyer
    ON BidsByBuyer.PB_PortfolioNumber COLLATE Latin1_General_100_CI_AS_KS_WS_SC_UTF8 = PE.PortfolioNumber COLLATE Latin1_General_100_CI_AS_KS_WS_SC_UTF8
LEFT JOIN [_Gold].[Business] B
    ON B.Id COLLATE Latin1_General_100_CI_AS_KS_WS_SC_UTF8 = BidsByBuyer.PB_BuyerId COLLATE Latin1_General_100_CI_AS_KS_WS_SC_UTF8
FULL OUTER JOIN PortfolioViewers
    ON PortfolioViewers.C_PID COLLATE Latin1_General_100_CI_AS_KS_WS_SC_UTF8 = PE.Id COLLATE Latin1_General_100_CI_AS_KS_WS_SC_UTF8
    AND PE.BuyerClientId COLLATE Latin1_General_100_CI_AS_KS_WS_SC_UTF8 = PortfolioViewers.C_ClientId COLLATE Latin1_General_100_CI_AS_KS_WS_SC_UTF8
WHERE BidsByBuyer.PB_Status IS NOT NULL
  AND YEAR(PE.PortfolioCloseUtc) > 2024
  AND PE.Status <> 'Purged';
GO
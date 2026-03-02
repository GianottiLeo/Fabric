IF OBJECT_ID('[_Gold].[usp_Refresh_Portfolio_Bid]', 'P') IS NOT NULL
    DROP PROCEDURE [_Gold].[usp_Refresh_Portfolio_Bid];
GO

CREATE PROCEDURE [_Gold].[usp_Refresh_Portfolio_Bid]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('[_Gold].[Portfolio_Bid]', 'U') IS NOT NULL
        DROP TABLE [_Gold].[Portfolio_Bid];

    ;WITH ListedDates AS (
        SELECT PortfolioId, MIN(EventUtc) AS ListedUtc
        FROM [EC Production].[dbo].[PortfolioEvent]
        WHERE EventType = 'listed'
        GROUP BY PortfolioId
    ),
    AwardedDates AS (
        SELECT PortfolioId, MIN(EventUtc) AS AwardedUtc
        FROM [EC Production].[dbo].[PortfolioEvent]
        WHERE LOWER(EventType) = 'awarded'
        GROUP BY PortfolioId
    )
    SELECT
        PB.Id,
        P.Id AS PortfolioId,
        P.PortfolioNumber,
        P.Status AS PortfolioStatus,
        P.AssetTypes,
        A.BidCloseUtc AS BidClose,
        ld.ListedUtc AS [Listed],
        ad.AwardedUtc AS [Awarded],
        P.SoldUtc AS Sold,
        NS.Name AS Seller_Name,
        CS.Name AS SellerClient,
        P.Issuers,
        NB.Name AS Buyer,
        PB.Status,
        PB.BidType,
        PB.BidPercent,
        PB.ForwardFlowBidMonths,
        PB.ForwardFlowMaxFaceValue,
        PB.BuyerId,
        PB.BidContingency,
        PB.BidPortfolioCloseDate,
        PB.BidFundingDate,
        CONCAT(SU.FirstName, ' ', SU.LastName) AS PlacedBy,
        PB.PlacedUtc,
        DATEDIFF(HOUR, PB.PlacedUtc, A.BidCloseUtc) AS PlacedHours
    INTO [_Gold].[Portfolio_Bid]
    FROM [EC Production].[dbo].[PortfolioBid] PB
    INNER JOIN [EC Production].[dbo].[Portfolio] P ON PB.PortfolioId = P.Id
    LEFT JOIN [EC Production].[PortfolioProcessing].[Auction] A ON P.Id = A.PortfolioId
    INNER JOIN [EC Production].[dbo].[Business] BB ON PB.BuyerId = BB.Id
    INNER JOIN [EC Production].[dbo].[BusinessName] NB ON NB.BusinessId = BB.Id AND NB.EndDateUtc IS NULL
    INNER JOIN [EC Production].[dbo].[Business] BS ON P.SellerId = BS.Id
    INNER JOIN [EC Production].[dbo].[Client] CS ON BS.ClientId = CS.Id
    INNER JOIN [EC Production].[dbo].[BusinessName] NS ON NS.BusinessId = BS.Id AND NS.EndDateUtc IS NULL
    LEFT JOIN [EC Production].[AppAuthorization].[User] SU ON PB.PlacedByUserId = SU.Id
    LEFT JOIN ListedDates ld ON ld.PortfolioId = P.Id
    LEFT JOIN AwardedDates ad ON ad.PortfolioId = P.Id
    WHERE PB.BuyerId <> '845eb6ad-c3cb-44bb-b353-d75090bd0ecd';

    CREATE NONCLUSTERED INDEX IX_Bid_PortfolioId ON [_Gold].[Portfolio_Bid] (PortfolioId);
    CREATE NONCLUSTERED INDEX IX_Bid_BuyerId ON [_Gold].[Portfolio_Bid] (BuyerId);
END;
GO
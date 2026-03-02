IF OBJECT_ID('[_Gold].[usp_Refresh_Portfolio_Aggregate]', 'P') IS NOT NULL
    DROP PROCEDURE [_Gold].[usp_Refresh_Portfolio_Aggregate];
GO

CREATE PROCEDURE [_Gold].[usp_Refresh_Portfolio_Aggregate]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('[_Gold].[Portfolio_Aggregate]', 'U') IS NOT NULL
        DROP TABLE [_Gold].[Portfolio_Aggregate];

    SELECT
        PA.*,
        P.PortfolioNumber,
        P.Status AS PortfolioStatus,
        P.AssetTypes AS PortfolioAssetTypes,
        N.Name AS SellerName,
        PA.TotalPrincipal + PA.TotalInterest + PA.TotalFees AS TotalFaceValue
    INTO [_Gold].[Portfolio_Aggregate]
    FROM [EC Production].[dbo].[PortfolioAggregate] PA
    INNER JOIN [EC Production].[dbo].[Portfolio] P ON P.Id = PA.PortfolioId
    INNER JOIN [EC Production].[dbo].[Business] BS ON P.SellerId = BS.Id
    INNER JOIN [EC Production].[dbo].[BusinessName] N ON N.BusinessId = BS.Id AND N.EndDateUtc IS NULL;

    CREATE NONCLUSTERED INDEX IX_PortfolioAgg_PortfolioId ON [_Gold].[Portfolio_Aggregate] (PortfolioId);
    CREATE NONCLUSTERED INDEX IX_PortfolioAgg_Category ON [_Gold].[Portfolio_Aggregate] (Category);
END;
GO
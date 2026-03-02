IF OBJECT_ID('[_Gold].[usp_Refresh_Portfolio]', 'P') IS NOT NULL
    DROP PROCEDURE [_Gold].[usp_Refresh_Portfolio];
GO

CREATE PROCEDURE [_Gold].[usp_Refresh_Portfolio]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('[_Gold].[Portfolio]', 'U') IS NOT NULL
        DROP TABLE [_Gold].[Portfolio];

    SELECT
        P.[Id],
        P.[PortfolioTypeId],
        P.[PortfolioNumber],
        P.[Status],
        P.[UploadDateUtc],
        P.[SellerUploadTemplateId],
        P.[FileDefinitionId],
        P.[SellerId],
        P.[SellerName],
        P.[BuyerId],
        P.[BuyerName],
        P.[PortfolioCloseUtc],
        P.[FundingDateUtc],
        P.[InitialPsaDateUtc],
        P.[SoldUtc],
        P.[WinningBidId],
        P.[TitleStatus],
        P.[MaxResalesAllowed],
        P.[LicenseType],
        P.[IsWarehoused],
        P.[WarehousedHowLong],
        P.[OriginalFaceValue],
        P.[PreScrubFaceValue],
        P.[FinalFaceValue],
        P.[PurchasePricePercent],
        P.[PurchasePriceAmount],
        P.[BuyerFeePercent],
        P.[BuyerFeeAmount],
        P.[SellerFeePercent],
        P.[SellerFeeAmount],
        P.[ForwardFlowAgreementId],
        P.[Issuers],
        P.[AssetTypes],
        P.[TotalFaceValue],
        P.[TotalPrincipal],
        P.[TotalInterest],
        P.[TotalFees],
        P.[NumberOfAccounts],
        P.[AverageBalance],
        P.[IsDisclosureEnabled],
        P.[DisclosureLastUpdateUTC],
        P.[SalesAgentId],
        P.[SalesAgentDisplayName],
        P.[NextActionBusinessId],
        P.[NextActionType],
        P.[PortfolioCountry],
        P.[AverageChargeOffBalance],
        P.[ListDateUtc],
        P.[BidCloseUtc],
        P.[AgreementTemplatePsaId],
        P.[AgreementTemplateBOSId],
        P.[AveragePrincipalBalance],
        P.[AverageFeeBalance],
        P.[AverageInterestBalance],
        P.[CutOffDateUtc],
        P.[NoDaysProvideMediaFiles],
        P.[FixedMonthlyFee],
        P.[ScrubEnabled],
        P.[ConfirmFundingEnabled],
        PT.TypeName AS PortfolioTypeName,
        A.Id AS AuctionId,
        A.AuctionType,
        A.BidCloseUtc AS AuctionBidCloseUtc,
        A.BuyerBidAccessOption AS AuctionBuyerBidAccessOption,
        PD.ReservePrice AS PortfolioReservePrice,
        bd.MaxDownloadedUtc AS BuyerDownloaded,
        sd.MaxDownloadedUtc AS SellerDownloaded
    INTO [_Gold].[Portfolio]
    FROM [EC Production].[dbo].[Portfolio] P
    LEFT JOIN [EC Production].[dbo].[PortfolioType] PT
        ON P.PortfolioTypeId = PT.Id
    LEFT JOIN [EC Production].[PortfolioProcessing].[Auction] A
        ON P.Id = A.PortfolioId
    LEFT JOIN [EC Production].[dbo].[PortfolioData] PD
        ON PD.PortfolioId = P.Id
    LEFT JOIN (
        SELECT BusinessId, MAX(DownloadedUtc) AS MaxDownloadedUtc
        FROM [EC Production].[dbo].[PortfolioDownload]
        GROUP BY BusinessId
    ) bd ON bd.BusinessId = P.BuyerId
    LEFT JOIN (
        SELECT BusinessId, MAX(DownloadedUtc) AS MaxDownloadedUtc
        FROM [EC Production].[dbo].[PortfolioDownload]
        GROUP BY BusinessId
    ) sd ON sd.BusinessId = P.SellerId
    WHERE P.SellerId <> '47087737-7939-4ddd-8ec2-64bc54b92513'
      AND (P.BuyerId NOT IN ('845eb6ad-c3cb-44bb-b353-d75090bd0ecd', 'e396866a-7269-42b5-9948-e473545d86b5')
           OR P.BuyerId IS NULL);

    CREATE NONCLUSTERED INDEX IX_Portfolio_Id ON [_Gold].[Portfolio] (Id);
    CREATE NONCLUSTERED INDEX IX_Portfolio_SellerId ON [_Gold].[Portfolio] (SellerId);
    CREATE NONCLUSTERED INDEX IX_Portfolio_BuyerId ON [_Gold].[Portfolio] (BuyerId);
    CREATE NONCLUSTERED INDEX IX_Portfolio_PortfolioNumber ON [_Gold].[Portfolio] (PortfolioNumber);
END;
GO
IF OBJECT_ID('[_Gold].[usp_Refresh_Complaint_Aggregate]', 'P') IS NOT NULL
    DROP PROCEDURE [_Gold].[usp_Refresh_Complaint_Aggregate];
GO

CREATE PROCEDURE [_Gold].[usp_Refresh_Complaint_Aggregate]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('[_Gold].[Complaint_Aggregate]', 'U') IS NOT NULL
        DROP TABLE [_Gold].[Complaint_Aggregate];

    SELECT
        a.*,
        a.Value * 5000 AS BCR,
        prev.Value AS PreviousMonthValue,
        prev.Value * 5000 AS PreviousMonthBCR,
        n.Name AS BuyerBusinessName,
        ns.Name AS SellerBusinessName
    INTO [_Gold].[Complaint_Aggregate]
    FROM [EC Production].[Reporting].[ComplaintAggregate] a
    LEFT JOIN [EC Production].[dbo].[Business_Buyer] bb ON bb.Id = a.BuyerGuid
    LEFT JOIN [EC Production].[dbo].[Business] b ON bb.Id = b.Id
    LEFT JOIN [EC Production].[dbo].[BusinessName] n ON n.BusinessId = b.Id AND n.EndDateUtc IS NULL
    LEFT JOIN [EC Production].[dbo].[Business_Seller] bs ON bs.Id = a.SellerGuid
    LEFT JOIN [EC Production].[dbo].[Business] s ON bs.Id = s.Id
    LEFT JOIN [EC Production].[dbo].[BusinessName] ns ON ns.BusinessId = s.Id AND ns.EndDateUtc IS NULL
    LEFT JOIN [EC Production].[Reporting].[ComplaintAggregate] prev
        ON prev.AggregateType = a.AggregateType
        AND ISNULL(prev.BuyerGuid, '') = ISNULL(a.BuyerGuid, '')
        AND ISNULL(prev.SellerGuid, '') = ISNULL(a.SellerGuid, '')
        AND ISNULL(prev.AgencyGuid, '') = ISNULL(a.AgencyGuid, '')
        AND a.Month IS NOT NULL
        AND a.Year IS NOT NULL
        AND (
            (a.Month > 1 AND prev.Month = a.Month - 1 AND prev.Year = a.Year) OR
            (a.Month = 1 AND prev.Month = 12 AND prev.Year = a.Year - 1)
        );
END;
GO
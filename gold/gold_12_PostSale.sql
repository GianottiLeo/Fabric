IF OBJECT_ID('[_Gold].[usp_Refresh_PostSale]', 'P') IS NOT NULL
    DROP PROCEDURE [_Gold].[usp_Refresh_PostSale];
GO

CREATE PROCEDURE [_Gold].[usp_Refresh_PostSale]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('[_Gold].[PostSale]', 'U') IS NOT NULL
        DROP TABLE [_Gold].[PostSale];

    ;WITH CloseDates AS (
        SELECT
            RequestId,
            MAX(Created) AS CloseDate
        FROM [EC Production].[PostSale].[RequestEvent]
        WHERE EventType = 'closed'
        GROUP BY RequestId
    ),
    AwardedDates AS (
        SELECT
            PortfolioId,
            MIN(EventUtc) AS PortfolioAwardedUtc
        FROM [EC Production].[dbo].[PortfolioEvent]
        WHERE EventType = 'awarded'
        GROUP BY PortfolioId
    )
    SELECT
        r.Id AS RequestId,
        r.InitiatedByBuyer,
        IIF(r.InitiatedByBuyer = 1, 'Buyer', 'Seller') AS InitiatedBy,
        IIF(r.InitiatedByBuyer = 1, bbc.Name, bsc.Name) AS RequestedBy,
        IIF(r.InitiatedByBuyer = 1, bsc.Name, bbc.Name) AS RequestedTo,
        LOWER(r.Status) AS RequestStatus,
        r.RequestType,
        UPPER(rt.RequestTypeStr) AS RequestTypeStr,
        r.DebtAccountId,
        r.BulkUploadDataRowId,
        DATEDIFF(DAY, r.Created, GETDATE()) AS AgeInDays,
        r.Created AS CreatedDateStr,
        r.CreatedByAppUserId,
        cd.CloseDate,
        r.FundingAmount,
        r.RejectComment,
        r.Escalated,
        r.CSRAction,
        r.FundingNotificationId,
        r.Closed,
        r.ClosedByAppUserId,
        r.LastUpdatedAppUserId,
        r.LastUpdatedSqlId,
        r.LastUpdated,
        r.SysEndTime,
        r.EffortExausted,
        p.SellerId,
        p.BuyerId,
        p.AssetTypes,
        (pr.PrincipalBalance + pr.InterestBalance + pr.OtherFeesBalance) * p.SellerFeePercent AS DT_SellerFee,
        (pr.PrincipalBalance + pr.InterestBalance + pr.OtherFeesBalance) * p.BuyerFeePercent AS DT_BuyerFee,
        pr.LenderLoanId,
        pr.Lender AS LenderName,
        pr.Product,
        CASE
            WHEN pr.Product IN ('Auto Deficiency','Auto Finance','Auto Skip','Skip auto','Auto Deficiency ,Skip',
                                'Auto Title','Auto Secured','Deficiency') THEN 'Auto'
            WHEN pr.Product LIKE '%installment%' OR pr.Product LIKE '%Installment%' OR
                 pr.Product IN ('ILP','Refinanced Loan','CSO STIL','CSO STIL - Checkless','Consumer') THEN 'Installment'
            WHEN pr.Product IN ('Line of Credit','LineOfCredit','LINE OF CREDIT') THEN 'Line of Credit'
            WHEN pr.Product IN ('Business Installment Loan','Small Business','Merchant Cash Advance') THEN 'Business Loan'
            WHEN pr.Product LIKE '%Payday%' OR pr.Product IN ('Payday','Payday Loan','Online Payday Loan',
                 'Consumer Loan - Check','SINGLE PAY','PDL','CSO_Payday','Online Short-Term Loan',
                 'Short Term Loan','Store Front Unsecure Loan','Retail Short-Term Loan',
                 'Store Front Secure Loan','Standard Loan','Short-term loan','PRA - Check',
                 'Advance','Single Payment Loan') THEN 'Payday'
            WHEN pr.Product IN ('Title','Title Loan','Title - Express','Retail Title Loan','TitleLOC') THEN 'Title'
            WHEN pr.Product LIKE '%Bank Line%' THEN 'Bank Line'
            WHEN pr.Product LIKE '%Consumer Unsecured%' THEN 'Consumer Unsecured'
            WHEN pr.Product IN ('MLA Loan','MTIL Loan') THEN 'Other'
            ELSE pr.Product
        END AS AssetType,
        pr.StateCode,
        pr.City,
        pr.OriginationDate,
        pr.OriginalLoanAmount,
        (pr.PrincipalBalance + pr.InterestBalance + pr.OtherFeesBalance) AS AccountTotalBalance,
        pr.PrincipalBalance,
        pr.InterestBalance,
        pr.OtherFeesBalance,
        pr.WriteOffDate,
        pr.DefaultDate,
        pr.LastPaymentDate,
        pr.LastPaymentAmount,
        CASE
            WHEN pr.BKPoc = 1
                THEN CONVERT(DECIMAL(18,2), ROUND((pr.PrincipalBalance + pr.InterestBalance + pr.OtherFeesBalance) * p.PurchasePricePercent - 25, 2))
            ELSE CONVERT(DECIMAL(18,2), ROUND((pr.PrincipalBalance + pr.InterestBalance + pr.OtherFeesBalance) * p.PurchasePricePercent, 2))
        END AS PurchasePriceAmount,
        CASE
            WHEN pr.BKPoc = 1 AND bkData.FinalPurchasePricePercent IS NOT NULL
                THEN bkData.FinalPurchasePricePercent
            ELSE p.PurchasePricePercent
        END AS PurchasePricePercent,
        p.PortfolioNumber,
        p.Id AS PortfolioId,
        p.Status AS PortfolioStatus,
        ad.PortfolioAwardedUtc,
        p.SoldUtc AS PortfolioSoldUtc,
        t.Name AS TemplateName,
        CASE
            WHEN LOWER(r.Status) IN ('closed','withdrawn','unresolved') THEN 'completed'
            WHEN LOWER(r.Status) IN ('pending seller funding','pending buyer funding confirmation') THEN 'pending funding'
            WHEN r.RequestType = 7 THEN 'pif-sif'
            WHEN r.RequestType = 3 THEN 'info'
            WHEN r.RequestType = 10 THEN 'innacurate-data'
            WHEN r.RequestType = 2 AND r.InitiatedByBuyer = 1 THEN 'direct-pay'
            WHEN r.RequestType = 4 THEN 'legal'
            WHEN r.RequestType IN (0,1,5,6,8,9,11,12) AND r.InitiatedByBuyer = 1 THEN 'put-back'
            WHEN r.RequestType IN (0,1,5,6,8,9,11,12) AND r.InitiatedByBuyer = 0 THEN 'buy-back'
        END AS Category,
        bs.ClientId AS SellerClientId,
        bb.ClientId AS BuyerClientId,
        CASE
            WHEN LOWER(bs.Status) = 'terminated - out of business' THEN bsn.Name + ' (Out of Business)'
            ELSE bsn.Name
        END AS SellerName,
        bsc.Name AS ClientName_Seller,
        CASE
            WHEN LOWER(bb.Status) = 'terminated - out of business' THEN bbn.Name + ' (Out of Business)'
            ELSE bbn.Name
        END AS BuyerName,
        bbc.Name AS ClientName_Buyer,
        fund.Status AS FundingStatus,
        fund.Amount AS FundingCheckAmount,
        fund.Mailed AS FundingCheckMailDate,
        fund.ReferenceOrCheckNumber AS FundingReferenceOrCheckNumber,
        fund.ConfirmedReceived AS FundingConfirmedReceived,
        fund.ConfirmedSent AS FundingConfirmedSent,
        pin.InfoRequested,
        COALESCE(a.Explanation, b.Explanation, c.Explanation) AS Explanation,
        d.Chapter AS bk_chapter,
        pifsif.PaymentDate AS PifSifPaymentDate,
        pifsif.PaymentAmount AS PifSifPaymentAmount,
        pifsif.PifSifType,
        CASE
            WHEN cd.CloseDate IS NOT NULL AND LOWER(r.Status) NOT IN ('closed','withdrawn','rejected') THEN 1
            ELSE 0
        END AS ReqStatusOpen,
        CASE
            WHEN LOWER(r.Status) IN ('closed','rejected','withdrawn')
                THEN DATEDIFF(DAY, r.Created, cd.CloseDate)
            ELSE -1
        END AS ClosedRejectedWithdrawnReqsAgeDays
    INTO [_Gold].[PostSale]
    FROM [EC Production].[PostSale].[Request] r
    INNER JOIN [EC Production].[PostSale].[RequestType] rt
        ON r.RequestType = rt.Id
    INNER JOIN [EC Production].[dbo].[PortfolioRow] pr
        ON r.DebtAccountId = pr.PortfolioRowGuid
    INNER JOIN [EC Production].[dbo].[Portfolio] p
        ON pr.PortfolioId = p.Id
    INNER JOIN [EC Production].[dbo].[SellerUploadTemplate] t
        ON p.SellerUploadTemplateId = t.Id
    LEFT JOIN [EC Production].[dbo].[PortfolioBkData] bkData
        ON p.Id = bkData.PortfolioId
    LEFT JOIN [EC Production].[dbo].[Business] bs
        ON p.SellerId = bs.Id
    LEFT JOIN [EC Production].[dbo].[BusinessName] bsn
        ON bs.Id = bsn.BusinessId AND bsn.EndDateUtc IS NULL
    LEFT JOIN [EC Production].[dbo].[Client] bsc
        ON bs.ClientId = bsc.Id
    LEFT JOIN [EC Production].[dbo].[Business] bb
        ON p.BuyerId = bb.Id
    LEFT JOIN [EC Production].[dbo].[BusinessName] bbn
        ON bb.Id = bbn.BusinessId AND bbn.EndDateUtc IS NULL
    LEFT JOIN [EC Production].[dbo].[Client] bbc
        ON bb.ClientId = bbc.Id
    LEFT JOIN [EC Production].[PostSale].[FundingNotification] fund
        ON r.FundingNotificationId = fund.Id
    LEFT JOIN [EC Production].[PostSale].[Info] pin
        ON pin.RequestId = r.Id
    LEFT JOIN [EC Production].[PostSale].[Legal] a
        ON a.RequestId = r.Id
    LEFT JOIN [EC Production].[PostSale].[Other] b
        ON b.RequestId = r.Id
    LEFT JOIN [EC Production].[PostSale].[Fraud] c
        ON c.RequestId = r.Id
    LEFT JOIN [EC Production].[PostSale].[Bankrupt] d
        ON d.RequestId = r.Id
    LEFT JOIN [EC Production].[PostSale].[PifSif] pifsif
        ON pifsif.RequestId = r.Id
    LEFT JOIN CloseDates cd
        ON cd.RequestId = r.Id
    LEFT JOIN AwardedDates ad
        ON ad.PortfolioId = p.Id;

    -- Indexes for common query patterns
    CREATE NONCLUSTERED INDEX IX_PostSale_RequestId ON [_Gold].[PostSale] (RequestId);
    CREATE NONCLUSTERED INDEX IX_PostSale_PortfolioId ON [_Gold].[PostSale] (PortfolioId);
    CREATE NONCLUSTERED INDEX IX_PostSale_PortfolioNumber ON [_Gold].[PostSale] (PortfolioNumber);
    CREATE NONCLUSTERED INDEX IX_PostSale_DebtAccountId ON [_Gold].[PostSale] (DebtAccountId);
    CREATE NONCLUSTERED INDEX IX_PostSale_SellerId ON [_Gold].[PostSale] (SellerId);
    CREATE NONCLUSTERED INDEX IX_PostSale_BuyerId ON [_Gold].[PostSale] (BuyerId);
    CREATE NONCLUSTERED INDEX IX_PostSale_RequestStatus ON [_Gold].[PostSale] (RequestStatus);
    CREATE NONCLUSTERED INDEX IX_PostSale_Category ON [_Gold].[PostSale] (Category);
END;
GO
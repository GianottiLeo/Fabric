# Gold Layer Procedures

## Schema Setup

```sql
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = '_Gold') EXEC('CREATE SCHEMA [_Gold]');
```

---

## gold_00_Master.sql — Orchestrator

```sql
IF OBJECT_ID('[_Gold].[usp_Refresh_All_Gold]', 'P') IS NOT NULL
    DROP PROCEDURE [_Gold].[usp_Refresh_All_Gold];
GO

CREATE PROCEDURE [_Gold].[usp_Refresh_All_Gold]
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @step_start DATETIME2, @msg NVARCHAR(200);

    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 1/7: Refreshing Gold Portfolio...';
    EXEC [_Gold].[usp_Refresh_Portfolio];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 2/7: Refreshing Gold Business...';
    EXEC [_Gold].[usp_Refresh_Business];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 3/7: Refreshing Gold Portfolio Row...';
    EXEC [_Gold].[usp_Refresh_Portfolio_Row];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 4/7: Refreshing Gold Portfolio Aggregate...';
    EXEC [_Gold].[usp_Refresh_Portfolio_Aggregate];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 5/7: Refreshing Gold Portfolio Bid...';
    EXEC [_Gold].[usp_Refresh_Portfolio_Bid];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 6/7: Refreshing Gold Complaints...';
    EXEC [_Gold].[usp_Refresh_Complaints];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    SET @step_start = SYSUTCDATETIME();
    PRINT 'Step 7/7: Refreshing Gold Complaint Aggregate...';
    EXEC [_Gold].[usp_Refresh_Complaint_Aggregate];
    SET @msg = CONCAT('  Completed in ', DATEDIFF(SECOND, @step_start, SYSUTCDATETIME()), 's');
    PRINT @msg;

    PRINT '=== Gold layer refresh complete ===';
END;
GO
```

---

## gold_01_Portfolio.sql

```sql
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
```

---

## gold_02_Business.sql

```sql
IF OBJECT_ID('[_Gold].[usp_Refresh_Business]', 'P') IS NOT NULL
    DROP PROCEDURE [_Gold].[usp_Refresh_Business];
GO

CREATE PROCEDURE [_Gold].[usp_Refresh_Business]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('[_Gold].[Business]', 'U') IS NOT NULL
        DROP TABLE [_Gold].[Business];

    ;WITH BuyerAggs AS (
        SELECT
            BuyerId,
            MAX(PlacedUtc) AS BuyerLastBidDate,
            MIN(PlacedUtc) AS BuyerFirstBidDate,
            COUNT(Id) AS BuyerTotalBids,
            COUNT(CASE WHEN Status = 'Won' THEN Id END) AS BuyerTotalWon
        FROM [EC Production].[dbo].[PortfolioBid]
        GROUP BY BuyerId
    ),
    PortfolioAggs_Seller AS (
        SELECT
            SellerId,
            MIN(PortfolioNumber) AS MinPid,
            MAX(PortfolioNumber) AS MaxPid,
            SUM(NumberOfAccounts) AS TotalAccounts,
            SUM(CASE WHEN DATEDIFF(MONTH, SoldUtc, GETUTCDATE()) <= 11 THEN NumberOfAccounts ELSE 0 END) AS PurchLast12
        FROM [EC Production].[dbo].[Portfolio]
        WHERE LOWER(Status) <> 'purged'
        GROUP BY SellerId
    ),
    PortfolioAggs_Buyer AS (
        SELECT
            BuyerId,
            MIN(PortfolioNumber) AS MinPid,
            MAX(PortfolioNumber) AS MaxPid,
            SUM(NumberOfAccounts) AS TotalAccounts,
            SUM(CASE WHEN DATEDIFF(MONTH, SoldUtc, GETUTCDATE()) <= 11 THEN NumberOfAccounts ELSE 0 END) AS PurchLast12
        FROM [EC Production].[dbo].[Portfolio]
        WHERE LOWER(Status) <> 'purged'
        GROUP BY BuyerId
    ),
    AwardedEvents AS (
        SELECT
            P.SellerId,
            P.PortfolioNumber,
            MIN(Pe.EventUtc) AS EventUtc
        FROM [EC Production].[dbo].[Portfolio] P
        LEFT JOIN [EC Production].[dbo].[PortfolioEvent] Pe
            ON P.Id = Pe.PortfolioId AND Pe.EventType = 'Awarded'
        WHERE LOWER(P.Status) <> 'purged'
        GROUP BY P.SellerId, P.PortfolioNumber
    ),
    LoginStats AS (
        SELECT
            C1.Id AS ClientId,
            MIN(Ua.ActionDate) AS FirstLoginDateTime,
            MAX(Ua.ActionDate) AS LastLoginDateTime
        FROM [EC Production].[AppAuthorization].[UserAction] Ua
        JOIN [EC Production].[AppAuthorization].[User] U ON Ua.UserId = U.Id
        JOIN [EC Production].[AppAuthorization].[Tenant] T ON U.TenantId = T.Id
        JOIN [EC Production].[dbo].[Client] C1 ON T.Id = C1.TenantId
        WHERE Ua.ActionDate > '2000-01-01'
        GROUP BY C1.Id
    ),
    ActiveSellers AS (
        SELECT DISTINCT SellerId
        FROM [EC Production].[dbo].[Portfolio]
        WHERE PortfolioCloseUtc > DATEADD(YEAR, -1, SYSDATETIME())
    ),
    ActiveBuyers AS (
        SELECT DISTINCT BuyerId
        FROM [EC Production].[dbo].[Portfolio]
        WHERE PortfolioCloseUtc > DATEADD(YEAR, -1, SYSDATETIME())
    ),
    BN AS (
        SELECT BusinessId, Name, StartDateUtc
        FROM [EC Production].[dbo].[BusinessName]
        WHERE EndDateUtc IS NULL
    ),
    BN_MinDate AS (
        SELECT BusinessId, MIN(StartDateUtc) AS MinNameStartDateUtc
        FROM [EC Production].[dbo].[BusinessName]
        WHERE EndDateUtc IS NULL
        GROUP BY BusinessId
    )
    SELECT
        B.Id,
        B.ClientId,
        B.Status,
        B.LegalName,
        B.StateCode,
        B.BillingStateCode,
        B.Street1,
        B.Street2,
        B.City,
        B.PostalCode,
        B.CorpHQPhoneNumber,
        B.CustomerServiceEmail,
        B.PrimaryContact_LastName,
        B.PrimaryContact_FirstName,
        B.PrimaryContact_EMail,
        B.PrimaryContact_OfficePhone,
        TRIM(Bn.Name) AS BusinessName,
        BnMin.MinNameStartDateUtc,
        C.Name AS ClientName,
        C.Status AS ClientStatus,
        C.TenantId AS ClientTenantId,
        ISNULL(Bb.DefaultBankAccountId, Bs.DefaultBankAccountId) AS DefaultBankAccountId,
        ISNULL(Bb.FeePercent, Bs.FeePercent) AS FeePercent,
        ISNULL(Bb.EnforceMinimumFee, Bs.EnforceMinimumFee) AS EnforceMinimumFee,
        ISNULL(Bb.MinimumFee, Bs.MinimumFee) AS MinimumFee,
        CASE WHEN Ba.Id IS NOT NULL THEN 1 ELSE 0 END AS IsAgency,
        Ba.WebSiteUrl AS AgencyWebSiteUrl,
        Ba.PaymentSiteUrl AS AgencyPaymentSiteUrl,
        Ba.MembershipEstablished AS AgencyMembershipEstablished,
        Ba.OnSiteAudit AS AgencyOnSiteAudit,
        Ba.RecertificationFrequency AS AgencyRecertificationFrequency,
        CASE WHEN Bb.Id IS NOT NULL THEN 1 ELSE 0 END AS IsBuyer,
        Bb.DTCanPlaceBid AS BuyerDTCanPlaceBid,
        Bb.DTCanUploadDownloadPSA AS BuyerDTCanUploadDownloadPsa,
        Bb.DTCanConfirmFundsSent AS BuyerDTCanConfirmFundsSent,
        Bb.DTCanCreatePostSaleRequest AS BuyerDTCanCreatePostSaleRequest,
        Bb.DTCanRespondToPostSaleRequest AS BuyerDTCanRespondToPostSaleRequest,
        Bb.DTCanClosePostSaleRequest AS BuyerDTCanClosePostSaleRequest,
        Bb.DTCanMaintainComplaints AS BuyerDTCanMaintainComplaints,
        Bb.PermissionsLastUpdatedByUserId AS BuyerPermissionsLastUpdatedByUserId,
        Bb.PermissionsLastUpdatedUTC AS BuyerPermissionsLastUpdatedUtc,
        Bb.Signer_FullName AS BuyerSigner_FullName,
        Bb.Signer_Title AS BuyerSigner_Title,
        Bb.TU_ScoringEnabled AS BuyerTU_ScoringEnabled,
        Bb.TU_UploadDirectory AS BuyerTU_UploadDirectory,
        Bb.TU_ProductType AS BuyerTU_ProductType,
        Bb.BCOBuyerType AS BuyerBCOBuyerType,
        Bb.BCOAgenciesCertified AS BuyerBCOAgenciesCertified,
        Bb.BCOOfficerBackgroundChecks AS BuyerBCOOfficerBackgroundChecks,
        Bb.BCOAttestation AS BuyerBCOAttestation,
        Bb.BCOComplianceNotes AS BuyerBCOComplianceNotes,
        Bb.BCOEnabled AS BuyerBCOEnabled,
        Bb.BCOFinancials AS BuyerBCOFinancials,
        Bb.MembershipEstablished AS BuyerMembershipEstablished,
        Bb.OnSiteAudit AS BuyerOnSiteAudit,
        Bb.RecertificationFrequency AS BuyerRecertificationFrequency,
        CASE WHEN ab.BuyerId IS NOT NULL AND Bb.Id IS NOT NULL THEN 1 ELSE 0 END AS ActiveBuyer,
        bagg.BuyerLastBidDate,
        bagg.BuyerFirstBidDate,
        bagg.BuyerTotalBids,
        bagg.BuyerTotalWon,
        pagg_b.MaxPid AS BuyerLastPortfolio,
        pagg_b.TotalAccounts AS BuyerActsPurch,
        pagg_b.PurchLast12,
        CASE WHEN Bs.Id IS NOT NULL THEN 1 ELSE 0 END AS IsSeller,
        Bs.SoftwareUsed AS SellerSoftwareUsed,
        Bs.ForwardFlowFeePercent AS SellerForwardFlowFeePercent,
        Bs.IsOriginator AS SellerIsOriginator,
        Bs.HoldScrub AS SellerHoldScrub,
        Bs.IncludeTLODismissals AS SellerIncludeTLODismissals,
        Bs.DTCanList AS SellerDTCanList,
        Bs.DTCanRemoveAccountsFromPortfolio AS SellerDTCanRemoveAccountsFromPortfolio,
        Bs.DTCanAcceptBid AS SellerDTCanAcceptBid,
        Bs.DTCanUploadDownloadPSA AS SellerDTCanUploadDownloadPsa,
        Bs.DTCanConfirmFundsReceived AS SellerDTCanConfirmFundsReceived,
        Bs.DTCanCreatePostSaleRequest AS SellerDTCanCreatePostSaleRequest,
        Bs.DTCanRespondToPostSaleRequest AS SellerDTCanRespondToPostSaleRequest,
        Bs.DTCanClosePostSaleRequest AS SellerDTCanClosePostSaleRequest,
        Bs.DTCanMaintainComplaints AS SellerDTCanMaintainComplaints,
        Bs.EnableBcoReport AS SellerEnableBcoReport,
        Bs.MilitaryScrub AS SellerMilitaryScrub,
        Bs.MilitaryCertificates AS SellerMilitaryCertificates,
        Bs.PermissionsLastUpdatedByUserId AS SellerPermissionsLastUpdatedByUserId,
        Bs.PermissionsLastUpdatedUTC AS SellerPermissionsLastUpdatedUtc,
        Bs.Signer_FullName AS SellerSigner_FullName,
        Bs.Signer_Title AS SellerSigner_Title,
        Bs.BuyerBidAccessOption AS SellerBuyerBidAccessOption,
        Bs.BidReviewQuantity AS SellerBidReviewQuantity,
        Bs.ShowWinningBid AS SellerShowWinningBid,
        Bs.RequireBCOFinancials AS SellerRequireBcoFinancials,
        Bs.AllowAdditionalUnmaskedData AS SellerAllowAdditionalUnmaskedData,
        Bs.SellerTerms AS SellerSellerTerms,
        Bs.SalesAgentId AS SellerSalesAgentId,
        Bs.SalesAgentDisplayName AS SellerSalesAgentDisplayName,
        Bs.ClientSuccessUserId AS SellerClientSuccessUserId,
        Bs.ScrubReviewThreshold AS SellerScrubReviewThreshold,
        Bs.OriginationState AS SellerOriginationState,
        Bs.Disclosure AS SellerDisclosure,
        Bs.ProjectedMonthlyPlacementVolumes AS SellerProjectedMonthlyPlacementVolumes,
        Bs.FF_PSA_SignatureRequired AS SellerFf_Psa_SignatureRequired,
        Bs.AllowPortfolioSplit AS SellerAllowPortfolioSplit,
        Bs.BusinessDevelopmentRepresentative,
        CASE WHEN asell.SellerId IS NOT NULL AND Bs.Id IS NOT NULL THEN 1 ELSE 0 END AS ActiveSeller,
        pagg_s.MinPid AS SellerFirstPidListed,
        pagg_s.MaxPid AS SellerLastPidListed,
        ae_first.EventUtc AS SellerFirstPidAwardedDate,
        ae_last.EventUtc AS SellerLastPidAwardedDate,
        ls.FirstLoginDateTime,
        ls.LastLoginDateTime
    INTO [_Gold].[Business]
    FROM [EC Production].[dbo].[Business] B
    JOIN BN Bn ON B.Id = Bn.BusinessId
    JOIN [EC Production].[dbo].[Client] C ON B.ClientId = C.Id
    LEFT JOIN BN_MinDate BnMin ON B.Id = BnMin.BusinessId
    LEFT JOIN [EC Production].[dbo].[Business_Agency] Ba ON B.Id = Ba.Id
    LEFT JOIN [EC Production].[dbo].[Business_Buyer] Bb ON B.Id = Bb.Id
    LEFT JOIN [EC Production].[dbo].[Business_Seller] Bs ON B.Id = Bs.Id
    LEFT JOIN BuyerAggs bagg ON B.Id = bagg.BuyerId
    LEFT JOIN PortfolioAggs_Buyer pagg_b ON B.Id = pagg_b.BuyerId
    LEFT JOIN PortfolioAggs_Seller pagg_s ON Bs.Id = pagg_s.SellerId
    LEFT JOIN LoginStats ls ON B.ClientId = ls.ClientId
    LEFT JOIN ActiveBuyers ab ON B.Id = ab.BuyerId
    LEFT JOIN ActiveSellers asell ON B.Id = asell.SellerId
    LEFT JOIN AwardedEvents ae_first
        ON ae_first.SellerId = Bs.Id AND ae_first.PortfolioNumber = pagg_s.MinPid
    LEFT JOIN AwardedEvents ae_last
        ON ae_last.SellerId = Bs.Id AND ae_last.PortfolioNumber = pagg_s.MaxPid
    WHERE B.Id NOT IN ('47087737-7939-4ddd-8ec2-64bc54b92513', '845eb6ad-c3cb-44bb-b353-d75090bd0ecd');

    CREATE NONCLUSTERED INDEX IX_Business_Id ON [_Gold].[Business] (Id);
    CREATE NONCLUSTERED INDEX IX_Business_ClientId ON [_Gold].[Business] (ClientId);
END;
GO
```

---

## gold_03_Portfolio_Row.sql

```sql
IF OBJECT_ID('[_Gold].[usp_Refresh_Portfolio_Row]', 'P') IS NOT NULL
    DROP PROCEDURE [_Gold].[usp_Refresh_Portfolio_Row];
GO

CREATE PROCEDURE [_Gold].[usp_Refresh_Portfolio_Row]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('[_Gold].[Portfolio_Row]', 'U') IS NOT NULL
        DROP TABLE [_Gold].[Portfolio_Row];

    ;WITH ListedDates AS (
        SELECT PortfolioId, MIN(EventUtc) AS ListedUtc
        FROM [EC Production].[dbo].[PortfolioEvent]
        WHERE EventType = 'listed'
        GROUP BY PortfolioId
    ),
    PostSaleCounts AS (
        SELECT DebtAccountId, COUNT(1) AS CountPostSaleRequest
        FROM [EC Production].[PostSale].[Request]
        WHERE LOWER(Status) <> 'withdrawn'
        GROUP BY DebtAccountId
    ),
    DeceasedData AS (
        SELECT
            d.DebtAccountId,
            d.DateOfDeath,
            dr.Received AS DeceasedScrubReceived,
            COUNT(1) OVER (PARTITION BY d.DebtAccountId) AS TotalDeceasedHits,
            ROW_NUMBER() OVER (PARTITION BY d.DebtAccountId ORDER BY d.Id) AS RowNum
        FROM [EC Production].[LCI].[DeceasedResult] d
        LEFT JOIN [EC Production].[LCI].[ResultFile] dr ON d.ResultFileId = dr.Id
    ),
    BankruptcyData AS (
        SELECT
            b.DebtAccountId,
            b.FileDate,
            b.Chapter,
            b.CaseStatus,
            b.CaseNumber,
            b.BarDate,
            b.CourtCity,
            b.CourtState,
            b.CourtZip,
            b.PlanFiledDate,
            b.ConfirmationHearingDate,
            b.PlanConfirmationDate,
            b.LastDateToObjectToDischarge,
            br.Received AS BankruptcyScrubReceived,
            COUNT(1) OVER (PARTITION BY b.DebtAccountId) AS TotalBankruptyHits,
            ROW_NUMBER() OVER (PARTITION BY b.DebtAccountId ORDER BY b.Id) AS RowNum
        FROM [EC Production].[LCI].[BankruptcyResult] b
        LEFT JOIN [EC Production].[LCI].[ResultFile] br ON b.ResultFileId = br.Id
    ),
    ScraData AS (
        SELECT
            s.DebtAccountId,
            s.ActiveDutyStatus,
            s.ActiveDutyStartDate,
            s.ActiveDutyEndDate,
            s.ServiceAgency,
            sr.Received AS ScraScrubReceived,
            COUNT(1) OVER (PARTITION BY s.DebtAccountId) AS TotalSCRAHits,
            ROW_NUMBER() OVER (PARTITION BY s.DebtAccountId ORDER BY s.Id) AS RowNum
        FROM [EC Production].[LCI].[ScraResult] s
        LEFT JOIN [EC Production].[LCI].[ResultFile] sr ON s.ResultFileId = sr.Id
    ),
    PifSifData AS (
        SELECT
            psr.DebtAccountId,
            pspifsif.PaymentDate,
            pspifsif.PaymentAmount,
            COUNT(1) OVER (PARTITION BY psr.DebtAccountId) AS TotalPifSif,
            ROW_NUMBER() OVER (PARTITION BY psr.DebtAccountId ORDER BY psr.Id) AS RowNum
        FROM [EC Production].[PostSale].[Request] psr
        JOIN [EC Production].[PostSale].[PifSif] pspifsif ON psr.Id = pspifsif.RequestId
        WHERE LOWER(psr.Status) = 'closed'
    ),
    AccountClosedData AS (
        SELECT
            psr.DebtAccountId,
            psclosed.ClosedDate,
            COUNT(1) OVER (PARTITION BY psr.DebtAccountId) AS TotalAccountClosed,
            ROW_NUMBER() OVER (PARTITION BY psr.DebtAccountId ORDER BY psr.Id) AS RowNum
        FROM [EC Production].[PostSale].[Request] psr
        JOIN [EC Production].[PostSale].[AccountClosed] psclosed ON psr.Id = psclosed.RequestId
        WHERE psr.Status = 'closed'
    )
    SELECT
        pid.SellerName,
        cs.Name AS SellerClient,
        pid.SellerId,
        pid.BuyerName,
        cb.Name AS BuyerClient,
        pid.BuyerId,
        pid.PortfolioNumber AS PID,
        pid.PortfolioTypeId,
        pr.Product,
        pid.[Status] AS PortfolioStatus,
        pr.Lender,
        pr.LenderLoanId,
        CASE
            WHEN LOWER(pr.Product) IN ('auto deficiency','auto finance','auto skip','skip auto','auto deficiency ,skip','auto title','auto secured','deficiency') THEN 'Auto'
            WHEN LOWER(pr.Product) LIKE '%installment%' OR LOWER(pr.Product) IN ('ilp','refinanced loan','cso stil','cso stil - checkless','consumer') THEN 'Installment'
            WHEN LOWER(pr.Product) IN ('line of credit','lineofcredit') THEN 'Line of Credit'
            WHEN LOWER(pr.Product) IN ('business installment loan','small business','merchant cash advance') THEN 'Business Loan'
            WHEN LOWER(pr.Product) LIKE '%payday%' OR LOWER(pr.Product) IN ('payday','payday loan','online payday loan','consumer loan - check','single pay','pdl','cso_payday','online short-term loan','short term loan','store front unsecure loan','retail short-term loan','store front secure loan','standard loan','short-term loan','pra - check','advance','single payment loan') THEN 'Payday'
            WHEN LOWER(pr.Product) IN ('title','title loan','title - express','retail title loan','titleloc') THEN 'Title'
            WHEN LOWER(pr.Product) LIKE '%bank line%' THEN 'Bank Line'
            WHEN LOWER(pr.Product) LIKE '%consumer unsecured%' THEN 'Consumer Unsecured'
            WHEN LOWER(pr.Product) IN ('mla loan','mtil loan') THEN 'Other'
            ELSE LOWER(pr.Product)
        END AS AssetType,
        pid.AssetTypes AS PortfolioAssetTypes,
        TRIM(UPPER(pr.StateCode)) AS ConsumerState,
        TRIM(pr.City) AS ConsumerCity,
        CASE WHEN prcd.BusinessDBA IS NULL THEN '' ELSE CONVERT(VARCHAR(256), HASHBYTES('SHA2_256', TRIM(UPPER(prcd.BusinessDBA))), 2) END AS BusinessDBAHashed,
        CASE WHEN prcd.BusinessLegalName IS NULL THEN '' ELSE CONVERT(VARCHAR(256), HASHBYTES('SHA2_256', TRIM(UPPER(prcd.BusinessLegalName))), 2) END AS BusinessLegalNameHashed,
        ISNULL(prcd.BusinessCity, '') AS BusinessCity,
        ISNULL(prcd.BusinessState, '') AS BusinessState,
        pr.OriginalLoanAmount,
        pr.PrincipalBalance,
        pr.InterestBalance,
        pr.OtherFeesBalance,
        pr.OriginationDate AS FundDate,
        pr.WriteOffDate,
        pr.DefaultDate,
        pr.FirstDelinquencyDate,
        pr.LastPaymentDate,
        pr.LastPaymentAmount,
        pr.PrincipalBalance + pr.InterestBalance + pr.OtherFeesBalance AS TotalBalance,
        pid.PurchasePricePercent AS PurchaseRate,
        ROUND((pr.PrincipalBalance + pr.InterestBalance + pr.OtherFeesBalance) * pid.PurchasePricePercent, 2) AS AccountPurchacePrice,
        pid.PurchasePriceAmount AS PortfolioPurchasePrice,
        pid.SoldUtc AS PortfolioSoldDate,
        pid.PortfolioCloseUtc AS PortfolioCloseDate,
        ld.ListedUtc AS Listed,
        ISNULL(pid.BuyerFeePercent, 0) AS BuyerFeePercent,
        ISNULL(pid.SellerFeePercent, 0) AS SellerFeePercent,
        ISNULL(pid.BuyerFeePercent, 0) + ISNULL(pid.SellerFeePercent, 0) AS TotalFeePercent,
        (ROUND((pr.PrincipalBalance + pr.InterestBalance + pr.OtherFeesBalance) * pid.PurchasePricePercent, 2) * ISNULL(pid.BuyerFeePercent, 0))
        + (ROUND((pr.PrincipalBalance + pr.InterestBalance + pr.OtherFeesBalance) * pid.PurchasePricePercent, 2) * ISNULL(pid.SellerFeePercent, 0)) AS TotalFeeAmount,
        pr.PortfolioRowGuid,
        pr.[ChainOfTitleId],
        pr.ComplianceHoldStatus AS DTComplianceHold,
        pr.SFComplaintId,
        pr.ChargeOffBalance,
        pr.TotalPaymentsSinceChargeOff,
        CASE WHEN pr.RemovedUTCDate IS NULL THEN DATEPART(YYYY, pid.SoldUtc) ELSE NULL END AS YearSold,
        pid.ForwardFlowAgreementId,
        pr.RemovedUTCDate AS RemovedDate,
        pr.RemoveComment,
        CASE
            WHEN pr.RemoveComment = 'lci-bankrupt' THEN 'BK-' + CONVERT(VARCHAR(10), bk.Chapter)
            WHEN pr.RemoveComment = 'lci-deceased' THEN 'Deceased'
            WHEN pr.RemoveComment = 'lci-scra' THEN 'SCRA-' + scra.ActiveDutyStatus
        END AS RemovedReason,
        CASE WHEN pr.RemovedUTCDate IS NULL THEN 'YES' ELSE 'NO' END AS SOLD,
        CASE
            WHEN TRIM(pid.LicenseType) IN ('Sovereign','Tribal Lending','Tribal-Sovereign','Soveriegn') THEN 'Tribal'
            WHEN TRIM(pid.LicenseType) = 'Lease to Own' THEN 'Lease to Own'
            WHEN TRIM(pid.LicenseType) IN ('State by State','State-by-State','State by state','State be State','STATE BY STATE','State','CSO','State by State, CSO','Bank Charter','State Licensed, Bank Charter, CSO','State Licensed, CSO','State Licensed Bank Charter, CSO','Single State Export') THEN 'State by State'
            WHEN TRIM(pid.LicenseType) IN ('Off-Shore','Off Shore') THEN 'Off-Shore'
            WHEN TRIM(pid.LicenseType) = 'Other' THEN 'Other'
            ELSE 'Missing'
        END AS LicenseType,
        pt.TypeName AS PortfolioTypeStr,
        ISNULL(psc.CountPostSaleRequest, 0) AS CountPostSaleRequest,
        deceased.DateOfDeath AS Deceased_DateOfDeath,
        DATEDIFF(DAY, pr.OriginationDate, deceased.DateOfDeath) AS Deceased_OriginationDateDiff,
        CASE WHEN deceased.DateOfDeath IS NULL THEN 0 ELSE 1 END AS IsDeceased,
        ISNULL(deceased.TotalDeceasedHits, 0) AS TotalDeceasedHits,
        deceased.DeceasedScrubReceived,
        bk.FileDate AS BK_FileDate,
        DATEDIFF(DAY, pr.OriginationDate, bk.FileDate) AS BK_OriginationDateDiff,
        bk.Chapter AS BK_Chapter,
        bk.CaseStatus AS BK_CaseStatus,
        bk.CaseNumber AS BK_CaseNumber,
        bk.BarDate AS BK_BarDate,
        bk.CourtCity AS BK_CourtCity,
        bk.CourtState AS BK_StateCode,
        bk.CourtZip AS BK_CourtZip,
        bk.PlanFiledDate AS BK_PlanFileDate,
        bk.ConfirmationHearingDate AS BK_ConfirmationHearingDate,
        bk.PlanConfirmationDate AS BK_PlanConfirmationDate,
        bk.LastDateToObjectToDischarge AS BK_LastDateToObjectToDischarge,
        CASE WHEN bk.CaseNumber IS NULL THEN 0 ELSE 1 END AS IsBk,
        ISNULL(bk.TotalBankruptyHits, 0) AS TotalBankruptyHits,
        bk.BankruptcyScrubReceived,
        scra.ActiveDutyStatus AS SCRA_ActiveDutyStatus,
        scra.ActiveDutyStartDate AS SCRA_ActiveDutyStartDate,
        scra.ActiveDutyEndDate AS SCRA_ActiveDutyEndDate,
        scra.ServiceAgency AS SCRA_ServiceAgency,
        CASE WHEN scra.ActiveDutyStatus IS NULL THEN 0 ELSE 1 END AS IsSCRA,
        ISNULL(scra.TotalSCRAHits, 0) AS TotalSCRAHits,
        scra.ScraScrubReceived,
        pifsif.PaymentDate AS PifSifPaymentDate,
        pifsif.PaymentAmount AS PifSifPaymentAmount,
        ISNULL(pifsif.TotalPifSif, 0) AS TotalPifSifRequest,
        closed.ClosedDate AS AccountClosedDate,
        ISNULL(closed.TotalAccountClosed, 0) AS TotalAccountClosedRequest
    INTO [_Gold].[Portfolio_Row]
    FROM [EC Production].[dbo].[PortfolioRow] pr
    JOIN [EC Production].[dbo].[Portfolio] pid ON pid.Id = pr.PortfolioId
    JOIN [EC Production].[dbo].[PortfolioType] pt ON pid.PortfolioTypeId = pt.Id
    JOIN [EC Production].[dbo].[Business] bb ON pid.BuyerId = bb.Id
    JOIN [EC Production].[dbo].[Business] bs ON pid.SellerId = bs.Id
    JOIN [EC Production].[dbo].[Client] cb ON bb.ClientId = cb.Id
    JOIN [EC Production].[dbo].[Client] cs ON bs.ClientId = cs.Id
    LEFT JOIN [EC Production].[dbo].[PortfolioRowCommercialData] prcd ON prcd.PortfolioRowGuid = pr.PortfolioRowGuid
    LEFT JOIN ListedDates ld ON ld.PortfolioId = pid.Id
    LEFT JOIN PostSaleCounts psc ON psc.DebtAccountId = pr.PortfolioRowGuid
    LEFT JOIN DeceasedData deceased ON deceased.DebtAccountId = pr.PortfolioRowGuid AND deceased.RowNum = 1
    LEFT JOIN BankruptcyData bk ON bk.DebtAccountId = pr.PortfolioRowGuid AND bk.RowNum = 1
    LEFT JOIN ScraData scra ON scra.DebtAccountId = pr.PortfolioRowGuid AND scra.RowNum = 1
    LEFT JOIN PifSifData pifsif ON pifsif.DebtAccountId = pr.PortfolioRowGuid AND pifsif.RowNum = 1
    LEFT JOIN AccountClosedData closed ON closed.DebtAccountId = pr.PortfolioRowGuid AND closed.RowNum = 1
    WHERE LOWER(pid.Status) IN ('closed','funded','awaiting seller fee','pending buyer funding')
      AND pid.SellerId <> '47087737-7939-4ddd-8ec2-64bc54b92513'
      AND (pid.BuyerId NOT IN ('845eb6ad-c3cb-44bb-b353-d75090bd0ecd','e396866a-7269-42b5-9948-e473545d86b5')
           OR pid.BuyerId IS NULL);

    CREATE NONCLUSTERED INDEX IX_PortfolioRow_PID ON [_Gold].[Portfolio_Row] (PID);
    CREATE NONCLUSTERED INDEX IX_PortfolioRow_PortfolioRowGuid ON [_Gold].[Portfolio_Row] (PortfolioRowGuid);
END;
GO
```

---

## gold_04_Portfolio_Aggregate.sql

```sql
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
```

---

## gold_05_Portfolio_Bid.sql

```sql
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
```

---

## gold_06_Complaints.sql

```sql
IF OBJECT_ID('[_Gold].[usp_Refresh_Complaints]', 'P') IS NOT NULL
    DROP PROCEDURE [_Gold].[usp_Refresh_Complaints];
GO

CREATE PROCEDURE [_Gold].[usp_Refresh_Complaints]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('[_Gold].[Complaints]', 'U') IS NOT NULL
        DROP TABLE [_Gold].[Complaints];

    SELECT
        CT.[Id],
        NS.Name AS Seller_Issuer,
        NB.Name AS Buyer,
        PID.PortfolioNumber AS PID,
        PR.PortfolioRowGuid AS DebtTraderID,
        PR.Lender,
        PR.LenderLoanId,
        PR.ComplianceHoldStatus,
        PR.SFComplaintId,
        PR.Product,
        PR.StateCode AS State,
        CT.[Status],
        CT.[Category],
        CT.[SourceType],
        CT.[ViolationType],
        CT.[Outcome],
        CT.[AccountStatus],
        CT.[Summary],
        CT.[AgencyId],
        ISNULL(CT.[AgencyName], 'Unknown') AS AgencyName,
        CT.[AgencyName_External],
        CT.[ComplainantName],
        CT.[ComplainantPhone],
        CT.[ComplainantEmail],
        CT.[AttorneyContacted],
        CT.[FollowUpRequired],
        CT.[DocumentsRequired],
        CT.[EmployeesInvolved],
        CT.[AgencyAction],
        CT.[AgencyResponse],
        CT.[AgencyPreventionSteps],
        CASE
            WHEN CT.[CreatedByBusinessId] IS NOT NULL THEN NCB.Name
            ELSE 'EverChain Compliance'
        END AS CreatedBy,
        CT.[CreatedByBusinessId],
        DATEADD(HOUR, 8, CT.[DateSubmitted]) AS DateSubmitted,
        CT.[ComplaintResolution],
        CT.[DebtTraderActions] AS EverChainActions
    INTO [_Gold].[Complaints]
    FROM [EC Production].[ComplaintTracking].[Complaint] CT
    INNER JOIN [EC Production].[dbo].[PortfolioRow] PR ON PR.PortfolioRowGuid = CT.[PortfolioRowId]
    INNER JOIN [EC Production].[dbo].[Portfolio] PID ON PID.Id = PR.PortfolioId
    INNER JOIN [EC Production].[dbo].[Business] BS ON PID.SellerId = BS.Id
    INNER JOIN [EC Production].[dbo].[Business] BB ON PID.BuyerId = BB.Id
    INNER JOIN [EC Production].[dbo].[BusinessName] NS ON NS.BusinessId = BS.Id AND NS.EndDateUtc IS NULL
    INNER JOIN [EC Production].[dbo].[BusinessName] NB ON NB.BusinessId = BB.Id AND NB.EndDateUtc IS NULL
    LEFT JOIN [EC Production].[dbo].[Business] CB ON CB.Id = CT.[CreatedByBusinessId]
    LEFT JOIN [EC Production].[dbo].[BusinessName] NCB ON NCB.BusinessId = CB.Id AND NCB.EndDateUtc IS NULL;

    CREATE NONCLUSTERED INDEX IX_Complaints_PID ON [_Gold].[Complaints] (PID);
END;
GO
```

---

## gold_07_Complaint_Aggregate.sql

```sql
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
```

---

## gold_08_Bidders.sql — View

```sql
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
```
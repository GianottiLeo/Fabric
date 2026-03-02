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
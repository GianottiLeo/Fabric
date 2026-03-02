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
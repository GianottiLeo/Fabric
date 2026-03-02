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
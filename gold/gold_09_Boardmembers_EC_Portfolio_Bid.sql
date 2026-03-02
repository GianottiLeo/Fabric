-- Gold View: Boardmembers_EC_Portfolio_Bid
-- Source: Power Query M  T-SQL conversion
-- Joins Joined_Portfolio_Bid with Business to get ClientId and ClientName
IF OBJECT_ID('[_Gold].[VW_Boardmembers_EC_Portfolio_Bid]', 'V') IS NOT NULL
    DROP VIEW [_Gold].[VW_Boardmembers_EC_Portfolio_Bid];
GO

CREATE VIEW [_Gold].[VW_Boardmembers_EC_Portfolio_Bid] AS
SELECT
    pb.*,
    b.ClientId,
    c.Name AS ClientName
FROM [Portfolio_Main_WH].[dbo].[Joined_Portfolio_Bid] pb
LEFT JOIN [EC Production].[dbo].[Business] b
    ON pb.BuyerId = b.Id
LEFT JOIN [EC Production].[dbo].[Client] c
    ON b.ClientId = c.Id;
GO
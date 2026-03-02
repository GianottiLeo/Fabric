-- ===========================================
-- Gold View: Boardmembers_ForwardFlow
-- ===========================================
-- Combines Portfolio_To_Join (FF agreements with 2+ portfolios)
-- with ForwardFlowAgreement to get EndDate and MaxUploadDate
--
-- ===========================================
-- T-SQL Version:
-- ===========================================

IF OBJECT_ID('[_Gold].[VW_Boardmembers_ForwardFlow]', 'V') IS NOT NULL
    DROP VIEW [_Gold].[VW_Boardmembers_ForwardFlow];
GO

CREATE VIEW [_Gold].[VW_Boardmembers_ForwardFlow] AS
WITH Portfolio_To_Join AS (
    SELECT
        ForwardFlowAgreementId,
        MAX(UploadDateUtc) AS MaxUploadDate,
        COUNT(*) AS PortfolioCount
    FROM [_Silver].[_EC_Portfolio_Expanded]
    WHERE ForwardFlowAgreementId IS NOT NULL
    GROUP BY ForwardFlowAgreementId
    HAVING COUNT(*) > 1
)
SELECT
    ffa.Id,
    ffa.EndDate,
    ptj.ForwardFlowAgreementId,
    ptj.MaxUploadDate
FROM [EC Production].[dbo].[ForwardFlowAgreement] ffa
LEFT JOIN Portfolio_To_Join ptj
    ON ffa.Id = ptj.ForwardFlowAgreementId
WHERE ptj.ForwardFlowAgreementId IS NOT NULL;
GO

-- ===========================================
-- Fabric / Power Query M Version:
-- ===========================================
--
-- Step 1: Portfolio_To_Join (separate query)
--
-- let
--     Source = EC_Portfolio_Expanded,
--     #"Select Columns" = Table.SelectColumns(Source, {"PortfolioNumber", "UploadDateUtc", "ForwardFlowAgreementId"}),
--     #"Filter FF Not Null" = Table.SelectRows(#"Select Columns", each [ForwardFlowAgreementId] <> null),
--     #"Group By FF" = Table.Group(#"Filter FF Not Null", {"ForwardFlowAgreementId"}, {
--         {"MaxDate", each List.Max([UploadDateUtc]), type nullable datetime},
--         {"Count", each Table.RowCount(_), Int64.Type}
--     }),
--     #"Filter Multiple" = Table.SelectRows(#"Group By FF", each [Count] <> 1),
--     #"Remove Count" = Table.RemoveColumns(#"Filter Multiple", {"Count"})
-- in
--     #"Remove Count"
--
-- Step 2: Final joined query
--
-- let
--     Fonte = Sql.Databases("tbhojlowt33evelkhiq7x3ltke-ut3flkknylqezclxie4zv5lvie.datawarehouse.fabric.microsoft.com"),
--     #"EC Production" = Fonte{[Name="EC Production"]}[Data],
--     dbo_ForwardFlowAgreement = #"EC Production"{[Schema="dbo",Item="ForwardFlowAgreement"]}[Data],
--     #"Select Columns" = Table.SelectColumns(dbo_ForwardFlowAgreement, {"Id", "EndDate"}),
--     #"Merge With Portfolio_To_Join" = Table.NestedJoin(#"Select Columns", {"Id"}, EC_Portfolio_To_Join, {"ForwardFlowAgreementId"}, "PTJ", JoinKind.LeftOuter),
--     #"Expand PTJ" = Table.ExpandTableColumn(#"Merge With Portfolio_To_Join", "PTJ", {"ForwardFlowAgreementId", "MaxDate"}, {"ForwardFlowAgreementId", "MaxUploadDate"}),
--     #"Filter FF Not Null" = Table.SelectRows(#"Expand PTJ", each [ForwardFlowAgreementId] <> null)
-- in
--     #"Filter FF Not Null"
--
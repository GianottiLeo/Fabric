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
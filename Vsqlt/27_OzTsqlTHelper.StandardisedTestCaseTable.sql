IF EXISTS(SELECT 1 FROM sys.procedures 
          WHERE object_id = OBJECT_ID(N'VsqltHelper.StandardisedTestCaseTable'))
BEGIN
    DROP PROCEDURE [VsqltHelper].[StandardisedTestCaseTable]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [VsqltHelper].[StandardisedTestCaseTable]
AS

BEGIN

SET NOCOUNT ON

	IF OBJECT_ID('tempdb..#TESTCASES') IS NOT NULL
		BEGIN
			ALTER TABLE #TESTCASES ADD ExpectedResult XML NULL, SQLForExpectedResult NVARCHAR(MAX) NULL, ResultNumber INT NULL, ExpectedReturnValue SQL_VARIANT DEFAULT 0, AssertReturnValue BIT DEFAULT 1
		END
	ELSE
		BEGIN
			CREATE TABLE #TESTCASES 
			(
			ExpectedResult XML NULL, 
			SQLForExpectedResult NVARCHAR(MAX) NULL, 
			ResultNumber INT NULL,
			ExpectedReturnValue SQL_VARIANT DEFAULT 0,
			AssertReturnValue BIT DEFAULT 1
			)
		END

SET NOCOUNT OFF

END

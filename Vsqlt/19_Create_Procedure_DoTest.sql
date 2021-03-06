IF EXISTS(SELECT 1 FROM sys.procedures 
          WHERE object_id = OBJECT_ID(N'VsqltHelper.DoTest'))
BEGIN
    DROP PROCEDURE [VsqltHelper].[DoTest]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [VsqltHelper].[DoTest]
(
@ATargetDatabaseName NVARCHAR(100),
@ASPFunctionName NVARCHAR(100),
@ATestCaseName NVARCHAR(100),
@ADmlTest BIT = 0
)
AS
BEGIN

SET NOCOUNT ON

IF @ADmlTest = 0 --Test SP without DML operation
	EXEC [VsqltHelper].[DoNoneDmlProcTest] @ATargetDatabaseName = @ATargetDatabaseName, @ASPFunctionName = @ASPFunctionName, @ATestCaseName = @ATestCaseName

ELSE --Test SP or Function's result set
	EXEC [VsqltHelper].[DoDmlProcTest] @ATargetDatabaseName = @ATargetDatabaseName, @ASPFunctionName = @ASPFunctionName, @ATestCaseName = @ATestCaseName

--Below will be tested for both scenario because this is to test the return value of the stored procedure. Function will be ignored.
EXEC [VsqltHelper].[DoTestReturnValue] @ATargetDatabaseName = @ATargetDatabaseName, @ASPFunctionName = @ASPFunctionName, @ATestCaseName = @ATestCaseName

SET NOCOUNT OFF

END

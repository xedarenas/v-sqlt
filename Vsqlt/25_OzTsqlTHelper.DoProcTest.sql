IF EXISTS(SELECT 1 FROM sys.procedures 
          WHERE object_id = OBJECT_ID(N'VsqltHelper.DoProcTest'))
BEGIN
    DROP PROCEDURE [VsqltHelper].[DoProcTest]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [VsqltHelper].[DoProcTest]
(
@ASPName NVARCHAR(100),
@ATestCaseName NVARCHAR(MAX)
)
AS
BEGIN

SET NOCOUNT ON

DECLARE	@generatedSQL NVARCHAR(MAX),
        @CreateExpectedData BIT, -- 1 = Generate Expected data, 2 = Generate Actual data
		@ExpectedResult NVARCHAR(MAX),
		@ActualResult NVARCHAR(MAX),
		@TestCaseKey NVARCHAR(MAX),
		@sequenceNo INT = 0,
		@ExpectedTableHash VARCHAR(200),
		@ActualTableHash VARCHAR(200),
		@ResultNo NVARCHAR(3),
		@DefinedExpectedResult XML,
		@ErrNo INT = 0

BEGIN TRY

	IF OBJECT_ID('tempdb..#SQLAndParam') IS NOT NULL
	BEGIN
		DROP TABLE #SQLAndParam
	END

	CREATE TABLE #SQLAndParam
	(
	SPFunctionName NVARCHAR(1000) NOT NULL,
	ResultNumber NVARCHAR(3) NOT NULL,
	TestParameters NVARCHAR(MAX) NULL,
	ExpectedResult XML NULL
	)

	DECLARE @selectSQLParam NVARCHAR(MAX)
	EXEC [VsqltHelper].[GenerateSQLToRetrieveParam] @selectSQLParam OUTPUT

	DECLARE @testData NVARCHAR(MAX)
	IF(LEN(@selectSQLParam) > 1) --There is at least one parameter execptected by the sp or function to be tested
		SET @testData = 'INSERT #SQLAndParam SELECT ''' + @ASPName + ''', CONVERT(NVARCHAR(3),ResultNumber), ' + @selectSQLParam + ',ExpectedResult FROM #TestCases'
	ELSE
		SET @testData = 'INSERT #SQLAndParam SELECT ''' + @ASPName + ''', CONVERT(NVARCHAR(3),ResultNumber),null,ExpectedResult FROM #TestCases'

	EXEC(@testData)

	DECLARE @spFunctionSQL NVARCHAR(MAX),
	        @tblMD5Hash NVARCHAR(MAX)

	--Generate hash based on result table definition
	EXEC [VsqltHelper].[GenerateTableHash] @tblMD5Hash OUTPUT

	WHILE(SELECT COUNT(1) FROM #SQLAndParam) > 0
		BEGIN
			
			SET @sequenceNo= @sequenceNo + 1
			SET @TestCaseKey = @ATestCaseName + '[' + CONVERT(NVARCHAR(30),@sequenceNo) + ']'
			--SELECT @TestCaseKey,'@TestCaseKey'

			--SET @ResultNo = (SELECT TOP 1 CONVERT(NVARCHAR(3),ResultNumber)  FROM #SQLAndParam)
			SELECT TOP 1 
					@ResultNo = CONVERT(NVARCHAR(3),ResultNumber),
					@DefinedExpectedResult = ExpectedResult
			FROM #SQLAndParam
			
			SET @spFunctionSQL = (SELECT TOP 1 'INSERT into #TESTRESULT EXEC tSQLt.ResultSetFilter ' +  CONVERT(NVARCHAR(3),ResultNumber) + ', ''EXEC ' + SPFunctionName + ' ' +  [VsqltHelper].[GenerateNonXMLParam](TestParameters) + ''''  FROM #SQLAndParam)

			--Execute creation of Expected Data
			SET @CreateExpectedData = 1
			TRUNCATE TABLE #TESTRESULT --Cleanup temp table that holds data to be converted to xml
			SET @generatedSQL = VsqltHelper.CreateStoredProcTestData(@TestCaseKey,@ATestCaseName,@spFunctionSQL,@ResultNo,@CreateExpectedData,@tblMD5Hash,@DefinedExpectedResult) 
			--SELECT @generatedSQL,'@generatedSQL 1'
			EXEC(@generatedSQL)

			--Execute creation of Actual Data
			SET @CreateExpectedData = 0
			TRUNCATE TABLE #TESTRESULT --Cleanup temp table that holds data to be converted to xml
			SET @generatedSQL = VsqltHelper.CreateStoredProcTestData(@TestCaseKey,@ATestCaseName,@spFunctionSQL,@ResultNo,@CreateExpectedData,@tblMD5Hash,NULL)  
			UPDATE OzTSQLT.ExecutionLog SET StartDate=SYSUTCDATETIME() WHERE TestCaseKey = @TestCaseKey --Update the start date
			EXEC(@generatedSQL)
			--SELECT @generatedSQL,'@generatedSQL 2'
			UPDATE OzTSQLT.ExecutionLog SET EndDate=SYSUTCDATETIME() WHERE TestCaseKey = @TestCaseKey --Update the end date

			----Perform ASSERT
			SELECT	@ExpectedResult = CONVERT(NVARCHAR(MAX),isnull(ExpectedResult,'')),
					@ActualResult = CONVERT(NVARCHAR(MAX),isnull(ActualResult,'')),
					@ExpectedTableHash = ExpectedTableHash,
					@ActualTableHash = ActualTableHash
				FROM [OzTSQLT].[ExecutionLog]
			WHERE TestCaseKey = @TestCaseKey

			IF (@ExpectedTableHash = @ActualTableHash)
			BEGIN
				EXEC [VsqltHelper].[CreateRunLog] @TestCaseKey,@ATestCaseName,@ASPName,@resultNo,'SUCCESS',NULL
			END
			ELSE
			BEGIN
				SELECT @ErrNo = 1
				EXEC [VsqltHelper].[CreateRunLog] @TestCaseKey,@ATestCaseName,@ASPName,@resultNo,'ERROR','Discrepancy between original and current result schema.'
			END

			----This will capture a scenario where there are no data generated based on the parameters supplied to test stored procedure
			--IF (@ExpectedResult IS NULL OR @ActualResult IS NULL)
			--BEGIN
			--	SELECT @ErrNo = 1
			--	EXEC [VsqltHelper].[CreateRunLog] @TestCaseKey,@ATestCaseName,@ASPName,@resultNo,'ERROR','No data generated for a given parameters to test the target stored procedure.'
			--END

			IF (@ErrNo = 0)
			BEGIN
			IF (@ExpectedResult = @ActualResult)
				EXEC [VsqltHelper].[CreateRunLog] @TestCaseKey,@ATestCaseName,@ASPName,@resultNo,'SUCCESS',NULL
			ELSE
				EXEC [VsqltHelper].[CreateRunLog] @TestCaseKey,@ATestCaseName,@ASPName,@resultNo,'ERROR','Discrepancy between expected and actual result.'
			END

			DELETE TOP(1) FROM #SQLAndParam		
		END


END TRY


BEGIN CATCH
	DECLARE @errorMessage NVARCHAR(1000) = (SELECT ERROR_MESSAGE())
	EXEC [VsqltHelper].[CreateRunLog] @TestCaseKey,@ATestCaseName,@ASPName,@resultNo,'ERROR',@errorMessage
END CATCH


SET NOCOUNT OFF

END
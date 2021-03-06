IF EXISTS(SELECT 1 FROM sys.procedures 
          WHERE object_id = OBJECT_ID(N'VsqltHelper.DoNoneDmlProcTest'))
BEGIN
    DROP PROCEDURE [VsqltHelper].[DoNoneDmlProcTest]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [VsqltHelper].[DoNoneDmlProcTest]
(
@ATargetDatabaseName NVARCHAR(100),
@ASPFunctionName NVARCHAR(100),
@ATestCaseName NVARCHAR(100)
)
AS
BEGIN

SET NOCOUNT ON

DECLARE	@generatedSQL NVARCHAR(MAX),
        @CreateExpectedData BIT, -- 1 = Generate Expected data, 2 = Generate Actual data
		@ExpectedResult NVARCHAR(MAX),
		@ActualResult NVARCHAR(MAX),
		@TestCaseKey NVARCHAR(100),
		@sequenceNo INT = 0,
		@ExpectedTableHash VARCHAR(200),
		@ActualTableHash VARCHAR(200),
		@ResultNo NVARCHAR(3),
		@DefinedExpectedResult XML,
		@ErrNo INT = 0,
		@SPFunctionName NVARCHAR(100),
		@TestTargetServerName NVARCHAR(100) = null, --Need to put values on this in the future releases
		@ExpectedReturnValue SQL_Variant = 0,
		@AssertReturnValue BIT = 1

BEGIN TRY

	--SELECT @ASPFunctionName,'Before @ASPFunctionName'
	SET @SPFunctionName = [VsqltHelper].[BuildSpOrFuncUnderTestName] (@TestTargetServerName, @ATargetDatabaseName, @ASPFunctionName)

	IF OBJECT_ID('tempdb..#SQLAndParam') IS NOT NULL
	BEGIN
		DROP TABLE #SQLAndParam
	END

	CREATE TABLE #SQLAndParam
	(
	SPFunctionName NVARCHAR(1000) NOT NULL,
	ResultNumber NVARCHAR(3) NULL,
	TestParameters NVARCHAR(MAX) NOT NULL,
	ExpectedResult XML NULL,
	ExpectedReturnValue SQL_Variant NULL,
	AssertReturnValue BIT NULL
	)

	--Table Value variable that will hold the content of #ExecutionLog. This will be the source of the actual test log while content of #ExecutionLog
	--will be rolledback along with the execution of the sp to be tested so that there will be no harm than or changes made to the datababase while executing
	--sp or function to be tested.
	DECLARE @ExecutionLog TABLE
	(
	[TestCaseKey] [nvarchar](max) NULL,
	[TestCaseName] [nvarchar](max) NULL,
	[ObjectToTest] [nvarchar](max) NULL,
	[ExecSPWithParam] [nvarchar](max) NOT NULL,
	[ResultNo] [nvarchar](3) NULL,
	[ExpectedTableHash] [nvarchar](max) NULL,
	[ActualTableHash] [nvarchar](max) NULL,
	[ExpectedResult] [xml] NULL,
	[ActualResult] [xml] NULL,
	[ExpectedReturnValue] [sql_variant] NULL,
	[ActualReturnValue] [sql_variant] NULL,
	[StartDate] [datetime2](7) NULL,
	[EndDate] [datetime2](7) NULL,
	[Status] [nvarchar](10) NULL,
	[ErrorMessage] [nvarchar](max) NULL
	)

	TRUNCATE TABLE OzTSQLT.TempExecutionLog --This will cleanup any dirty data that remained in the previous run if there are unhandled error

	DECLARE @selectSQLParam NVARCHAR(MAX)
	EXEC [VsqltHelper].[GenerateSQLToRetrieveParam] @selectSQLParam OUTPUT

	DECLARE @testData NVARCHAR(MAX) 
	
	IF(@selectSQLParam = '''')
		SET @testData = 'INSERT #SQLAndParam SELECT ''' + @SPFunctionName + ''', CONVERT(NVARCHAR(3),ResultNumber),'''',ExpectedResult,ExpectedReturnValue,AssertReturnValue FROM #TestCases'	
	ELSE
		SET @testData = 'INSERT #SQLAndParam SELECT ''' + @SPFunctionName + ''', CONVERT(NVARCHAR(3),ResultNumber), ' + @selectSQLParam + ',ExpectedResult,ExpectedReturnValue,AssertReturnValue FROM #TestCases'
	
	EXEC(@testData)

	DECLARE @spFunctionSQL NVARCHAR(MAX),
	        @tblMD5Hash NVARCHAR(MAX),
			@ObjectType NVARCHAR(30),
			@errorMessage NVARCHAR(1000)

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
					@DefinedExpectedResult = ExpectedResult,
					@ExpectedReturnValue = ExpectedReturnValue,
					@AssertReturnValue = AssertReturnValue
			FROM #SQLAndParam

			EXEC [VsqltHelper].[DetermineObjectTye] @ATargetDatabaseName,@SPFunctionName,@ObjectType OUTPUT

			--select @ObjectType,'@ObjectType'
		
			--Generate SQL based on @IsTestForSP. 1 = We are testing SP, 0 = We are testing Function
			IF(@ObjectType = 'STORED_PROCEDURE')
				SET @spFunctionSQL = (SELECT TOP 1 'INSERT into #TestResult EXEC tSQLt.ResultSetFilter ' +  CONVERT(NVARCHAR(3),ResultNumber) + ', ''EXEC ' + SPFunctionName + ' ' +  [VsqltHelper].[GenerateNonXMLParam](TestParameters,1) + ''''  FROM #SQLAndParam)
			ELSE IF(@ObjectType = 'FUNCTION')
				SET @spFunctionSQL = (SELECT TOP 1 'INSERT into #TestResult SELECT ' + SPFunctionName + '(' +  [VsqltHelper].[GenerateNonXMLParam](TestParameters,0) + ')'  FROM #SQLAndParam)

				
				IF(@ObjectType IN ('STORED_PROCEDURE','FUNCTION')) --For now, our framework is design to test function and stored procedure only
					BEGIN

						BEGIN TRAN OZTEST1 --Checkpoint to start transaction so that all operation below can be rollback after test execution

							--Execute creation of Expected Data
							SET @CreateExpectedData = 1
							TRUNCATE TABLE #TestResult --Cleanup temp table that holds data to be converted to xml
							--DELETE FROM #TestResult --Cleanup temp table that holds data to be converted to xml

							--select @TestCaseKey,@ATestCaseName,@ASPFunctionName,@spFunctionSQL,@ResultNo,@CreateExpectedData,@tblMD5Hash,@DefinedExpectedResult,'Before 1 @generatedSQL'
							SET @generatedSQL = [VsqltHelper].CreateStoredProcTestData(@TestCaseKey,@ATestCaseName,@ASPFunctionName,@spFunctionSQL,@ResultNo,@CreateExpectedData,@tblMD5Hash,@DefinedExpectedResult) 
							--select @generatedSQL,'1 @generatedSQL'
							EXEC(@generatedSQL)

							--Better place here the statement that ExpectedReturn Value since [VsqltHelper].[CreateStoredProcWithDMLTestData] has issue with sql_variant datatype.
							--Will come back to fix this
							IF @AssertReturnValue = 1
								UPDATE [OzTSQLT].[TempExecutionLog] SET ExpectedReturnValue = @ExpectedReturnValue WHERE TestCaseKey = @TestCaseKey --Update the start date
							ELSE
								UPDATE [OzTSQLT].[TempExecutionLog] SET ExpectedReturnValue = 'IGNORE', ActualReturnValue = 'IGNORE' WHERE TestCaseKey = @TestCaseKey --Update the start date

							--Execute creation of Actual Data
							SET @CreateExpectedData = 0
							TRUNCATE TABLE #TestResult --Cleanup temp table that holds data to be converted to xml
							--DELETE FROM #TestResult --Cleanup temp table that holds data to be converted to xml
							SET @generatedSQL = [VsqltHelper].CreateStoredProcTestData(@TestCaseKey,@ATestCaseName,@ASPFunctionName,@spFunctionSQL,@ResultNo,@CreateExpectedData,@tblMD5Hash,NULL)  
							UPDATE [OzTSQLT].[TempExecutionLog] SET StartDate=SYSUTCDATETIME() WHERE TestCaseKey = @TestCaseKey --Update the start date
							--select @generatedSQL,'2 @generatedSQL'
							EXEC(@generatedSQL)						
							UPDATE [OzTSQLT].[TempExecutionLog] SET EndDate=SYSUTCDATETIME() WHERE TestCaseKey = @TestCaseKey --Update the end date
			
							--Call the SP helper that will do the actual assert
							EXEC [VsqltHelper].[PerformAssert] @SPFunctionName,@ATestCaseName,@TestCaseKey,@ResultNo

							--Insert the content of temp table to the table variable so that changes will not be lost when we do rollback
							INSERT @ExecutionLog (TestCaseKey,TestCaseName,ObjectToTest,ExecSPWithParam,ResultNo,ExpectedTableHash,ActualTableHash,ExpectedResult,ActualResult,ExpectedReturnValue,ActualReturnValue,StartDate,EndDate,Status,ErrorMessage) SELECT TestCaseKey,TestCaseName,ObjectToTest,ExecSPWithParam,ResultNo,ExpectedTableHash,ActualTableHash,ExpectedResult,ActualResult,ExpectedReturnValue,ActualReturnValue,StartDate,EndDate,Status,ErrorMessage FROM [OzTSQLT].[TempExecutionLog]

						ROLLBACK TRAN OZTEST1 --This is to rollback all operations above which include execution of the sp to be tested so that no changes will be done to the table affected by sp run.
					END
				ELSE --If object supplied to be tested is not catered for testing
					BEGIN
						

						IF(@ObjectType = 'OTHER_OBJECTS')
							SET @errorMessage = 'Object to be tested is not yet catered by this framework. Please inform the administrator.'

						IF(@ObjectType = 'NOT_EXIST')
							SET @errorMessage = 'Object to be tested does not exist.'

						EXEC [VsqltHelper].[CreateRunLog] @TestCaseKey,@ATestCaseName,@SPFunctionName,@resultNo,'ERROR',@errorMessage
				

					END
			DELETE TOP(1) FROM #SQLAndParam		
		END

		--Test only if there is data in @ExecutionLog after rollback
		--SELECT * FROM @ExecutionLog 

		--Now that we have the result of the test to a table variable after we rollback the changes made by the actual execution of the test, we can
		--now store it in the actual table log.
		INSERT OzTSQLT.ExecutionLog (TestCaseKey,TestCaseName,ObjectToTest,ExecSPWithParam,ResultNo,ExpectedTableHash,ActualTableHash,ExpectedResult,ActualResult,ExpectedReturnValue,ActualReturnValue,StartDate,EndDate,Status,ErrorMessage)
		SELECT TestCaseKey,TestCaseName,ObjectToTest,ExecSPWithParam,ResultNo,ExpectedTableHash,ActualTableHash,ExpectedResult,ActualResult,ExpectedReturnValue,ActualReturnValue,StartDate,EndDate,Status,ErrorMessage 
		FROM @ExecutionLog varE WHERE NOT EXISTS
		(
		SELECT 1 FROM OzTSQLT.ExecutionLog el WHERE el.TestCaseKey = varE.TestCaseKey
		)

		UPDATE OzTSQLT.ExecutionLog
		SET TestCaseName = varE.TestCaseName,
			ObjectToTest = varE.ObjectToTest,
			ExecSPWithParam = varE.ExecSPWithParam,
			ResultNo = varE.ResultNo,
			ExpectedTableHash = varE.ExpectedTableHash,
			ActualTableHash = varE.ActualTableHash,
			ExpectedResult = varE.ExpectedResult,
			ActualResult = varE.ActualResult,
		    ExpectedReturnValue = varE.ExpectedReturnValue,
		    ActualReturnValue = varE.ActualReturnValue,
			StartDate = varE.StartDate,
			EndDate = varE.EndDate,
			Status = varE.Status,
			ErrorMessage = varE.ErrorMessage
		FROM OzTSQLT.ExecutionLog el
		INNER JOIN @ExecutionLog varE
		ON el.TestCaseKey = varE.TestCaseKey


END TRY


BEGIN CATCH

	IF @@TRANCOUNT > 0 ROLLBACK TRAN OZTEST1 

	SET @errorMessage = (SELECT ERROR_MESSAGE())

	SELECT @TestCaseKey,@ATestCaseName,@SPFunctionName,@resultNo,@errorMessage,'Error'

	IF EXISTS(SELECT 1 FROM [OzTSQLT].[ExecutionLog] WHERE TestCaseKey = @TestCaseKey)
		UPDATE [OzTSQLT].[ExecutionLog] SET Status = 'ERROR', ErrorMessage =@errorMessage WHERE TestCaseKey = @TestCaseKey
    ELSE
		INSERT [OzTSQLT].[ExecutionLog] (TestCaseName,TestCaseKey,ExecSPWithParam,ObjectToTest,ResultNo,Status,ErrorMessage) VALUES (isnull(@ATestCaseName,''),isnull(@TestCaseKey,''),'UNHANDLED',isnull(@SPFunctionName,''),@resultNo,'ERROR',@errorMessage)

	SELECT @errorMessage
END CATCH


SET NOCOUNT OFF

END
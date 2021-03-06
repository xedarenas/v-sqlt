IF EXISTS(SELECT 1 FROM sys.procedures 
          WHERE object_id = OBJECT_ID(N'VsqltHelper.DoTestReturnValue'))
BEGIN
    DROP PROCEDURE [VsqltHelper].[DoTestReturnValue]
END/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [VsqltHelper].[DoTestReturnValue]
(
@ATargetDatabaseName NVARCHAR(100),
@ASPFunctionName NVARCHAR(100),
@ATestCaseName NVARCHAR(100)
)
AS
BEGIN

--DA: APRIL 25: Changes are for tagged with APRIL 25

SET NOCOUNT ON

DECLARE	@TestCaseKey NVARCHAR(100),
		@sequenceNo INT = 0,
		@ResultNo NVARCHAR(3),
		@ErrNo INT = 0,
		@SPFunctionName NVARCHAR(100),
		@TestTargetServerName NVARCHAR(100) = null, --Need to put values on this in the future releases
		@AssertReturnValue BIT = 1

BEGIN TRY

	SET @SPFunctionName = [VsqltHelper].[BuildSpOrFuncUnderTestName] (@TestTargetServerName, @ATargetDatabaseName, @ASPFunctionName)

	--SELECT @SPFunctionName,'@SPFunctionName'

	IF OBJECT_ID('tempdb..#SQLAndParam') IS NOT NULL
	BEGIN
		DROP TABLE #SQLAndParam
	END

	CREATE TABLE #SQLAndParam
	(
	SPFunctionName NVARCHAR(1000) NOT NULL,
	TestParameters NVARCHAR(MAX) NOT NULL,
	AssertReturnValue BIT
	)


	--Table Value variable that will hold the content of [OzTSQLT].[TempExecutionLog]. This will be the source of the actual test log while content of [OzTSQLT].[TempExecutionLog]
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
		SET @testData = 'INSERT #SQLAndParam SELECT ''' + @SPFunctionName + ''','''',AssertReturnValue FROM #TestCases'	
	ELSE
		SET @testData = 'INSERT #SQLAndParam SELECT ''' + @SPFunctionName + ''', ' + @selectSQLParam + ',AssertReturnValue FROM #TestCases'

	EXEC(@testData)

	DECLARE @spFunctionSQL NVARCHAR(MAX),
	        @tblMD5Hash NVARCHAR(MAX),
			@ObjectType NVARCHAR(30),
			@errorMessage NVARCHAR(1000),
			@procOperation BIT = 1,
			@ExpectedReturnValue SQL_Variant,
			@ActualReturnValue SQL_Variant

	--Generate hash based on result table definition
	EXEC [VsqltHelper].[GenerateTableHash] @tblMD5Hash OUTPUT

	WHILE(SELECT COUNT(1) FROM #SQLAndParam) > 0
		BEGIN
			
			SET @sequenceNo= @sequenceNo + 1
			SET @TestCaseKey = @ATestCaseName + '[' + CONVERT(NVARCHAR(30),@sequenceNo) + ']'

			SELECT TOP 1 
					@AssertReturnValue = AssertReturnValue
			FROM #SQLAndParam

			If @AssertReturnValue = 1 --Perform assert for return value only if intented to.
				BEGIN
					EXEC [VsqltHelper].[DetermineObjectTye] @ATargetDatabaseName,@SPFunctionName,@ObjectType OUTPUT
			
					--Generate SQL based on @IsTestForSP. 1 = We are testing SP, 0 = We are testing Function
					IF(@ObjectType = 'STORED_PROCEDURE')
						BEGIN
							INSERT [OzTSQLT].[TempExecutionLog] (TestCaseKey,TestCaseName,ObjectToTest,ExecSPWithParam,ResultNo,ExpectedTableHash,ActualTableHash,ExpectedResult,ActualResult,ExpectedReturnValue,ActualReturnValue,StartDate,EndDate,Status,ErrorMessage) SELECT TestCaseKey,TestCaseName,ObjectToTest,ExecSPWithParam,ResultNo,ExpectedTableHash,ActualTableHash,ExpectedResult,ActualResult,ExpectedReturnValue,ActualReturnValue,StartDate,EndDate,Status,ErrorMessage FROM [OzTSQLT].[ExecutionLog] WHERE TestCaseKey =  @TestCaseKey 	
							SET @spFunctionSQL = (SELECT TOP 1 'EXEC(''DECLARE @returnValue int  exec @returnValue = ' + '' + SPFunctionName + ' ' +  [VsqltHelper].[GenerateNonXMLParam](TestParameters,@procOperation) + ' UPDATE [OzTSQLT].[TempExecutionLog] SET ActualReturnValue = @returnValue WHERE TestCaseKey =''''' + @TestCaseKey + '''''''' +  ')' FROM #SQLAndParam)					
				
							BEGIN TRAN OZTEST1 --Checkpoint to start transaction so that all operation below can be rollback after test execution
								
								EXEC(@spFunctionSQL)

								--Perform Assert for Return Value. Need to come back to centralised this and put inside PerformAssert helper SP
								SELECT	@ExpectedReturnValue = ExpectedReturnValue,
										@ActualReturnValue = ActualReturnValue
								FROM [OzTSQLT].[TempExecutionLog]
								WHERE TestCaseKey = @TestCaseKey

								IF (@ExpectedReturnValue <> @ActualReturnValue)
									UPDATE [OzTSQLT].[TempExecutionLog] SET Status = 'ERROR', ErrorMessage = 'Discrepancy between expected and actual return value.' Where TestCaseKey = @TestCaseKey

								INSERT @ExecutionLog (TestCaseKey,TestCaseName,ObjectToTest,ExecSPWithParam,ResultNo,ExpectedTableHash,ActualTableHash,ExpectedResult,ActualResult,ExpectedReturnValue,ActualReturnValue,StartDate,EndDate,Status,ErrorMessage) SELECT TestCaseKey,TestCaseName,ObjectToTest,ExecSPWithParam,ResultNo,ExpectedTableHash,ActualTableHash,ExpectedResult,ActualResult,ExpectedReturnValue,ActualReturnValue,StartDate,EndDate,Status,ErrorMessage FROM [OzTSQLT].[TempExecutionLog]

							ROLLBACK TRAN OZTEST1 --This is to rollback all operations above which include execution of the sp to be tested so that no changes will be done to the table affected by sp run.
						END
				END


			DELETE TOP(1) FROM #SQLAndParam		
		END

		--We are expecting update at this stage only since insert is done in previous operation
		UPDATE OzTSQLT.ExecutionLog
		SET ExpectedReturnValue = varE.ExpectedReturnValue,
		    ActualReturnValue = varE.ActualReturnValue,
			Status = varE.Status,
			ErrorMessage = varE.ErrorMessage
		FROM OzTSQLT.ExecutionLog el
		INNER JOIN @ExecutionLog varE
		ON el.TestCaseKey = varE.TestCaseKey

END TRY


BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRAN OZTEST1  

	SET @errorMessage = (SELECT ERROR_MESSAGE())

	IF EXISTS(SELECT 1 FROM [OzTSQLT].[ExecutionLog] WHERE TestCaseKey = isnull(@TestCaseKey,''))
		UPDATE [OzTSQLT].[ExecutionLog] SET Status = 'ERROR', ErrorMessage =@errorMessage WHERE TestCaseKey = isnull(@TestCaseKey,'')
    ELSE
		INSERT [OzTSQLT].[ExecutionLog] (TestCaseName,TestCaseKey,ExecSPWithParam,ObjectToTest,ResultNo,Status,ErrorMessage) VALUES (isnull(@ATestCaseName,''),isnull(@TestCaseKey,''),'UNHANDLED',isnull(@SPFunctionName,''),@resultNo,'ERROR',@errorMessage)

	SELECT @errorMessage,'Error'

END CATCH


SET NOCOUNT OFF

END
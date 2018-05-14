IF EXISTS (SELECT 1
           FROM   sys.objects
           WHERE  object_id = OBJECT_ID(N'[VsqltHelper].[CreateStoredProcWithDMLTestData]')
                  AND type IN ( N'FN', N'IF', N'TF', N'FS', N'FT' ))
  DROP FUNCTION [VsqltHelper].[CreateStoredProcWithDMLTestData]

GO 


SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [VsqltHelper].[CreateStoredProcWithDMLTestData](@testCaseKey NVARCHAR(MAX),@testCaseName NVARCHAR(MAX), @sqlSPToTest NVARCHAR(MAX),@createExpectedData bit,@tblMD5Hash NVARCHAR(MAX),@definedExpectedResult XML)  
RETURNS NVARCHAR(MAX) 
AS   
BEGIN  
	
	--DA: APRIL 25: Changes are for tagged with APRIL 25

	DECLARE @execSPViatSQLtResultSetFilter NVARCHAR(MAX)
	DECLARE @generateXML NVARCHAR(MAX)
	DECLARE @retValue NVARCHAR(MAX)
	DECLARE @ExecutionLog NVARCHAR(MAX)
	DECLARE @formattedSqlSPToTest NVARCHAR(MAX) = (SELECT REPLACE(@sqlSPToTest,'''',''''''))

	----Do below if defined expected result is supplied
	--IF(@definedExpectedResult IS NOT NULL)
	--	BEGIN
	--		SET @ExecutionLog = 'IF NOT EXISTS(SELECT 1 FROM [OzTSQLT].[TempExecutionLog] WHERE TestCaseKey = ''' + @testCaseKey + ''') INSERT [OzTSQLT].[TempExecutionLog] (TestCaseName,TestCaseKey,ExecSPWithParam,ResultNo,ExpectedTableHash,ExpectedResult) VALUES (''' + @testCaseName + ''',''' + @testCaseKey + ''',''' + @formattedSqlSPToTest + ''',''' + NULL + ''',''' + @tblMD5Hash + ''',''' + CONVERT(NVARCHAR(MAX),@definedExpectedResult) + ''') ELSE UPDATE [OzTSQLT].[TempExecutionLog] SET ExpectedResult = ''' + CONVERT(NVARCHAR(MAX),@definedExpectedResult) + ''', ExecSPWithParam = ''' + @formattedSqlSPToTest + '''  WHERE TestCaseKey = ''' + @testCaseKey + '''' 
	--		SET @retValue = @ExecutionLog
	--	END
	--ELSE
	--	BEGIN
			--Generate Expected Result
			SET @execSPViatSQLtResultSetFilter = @sqlSPToTest

			--Insert the expected result to the table to be used for assert. This will be created only on the first run and will not be executed in the succeeding run
			IF(@createExpectedData = 1) -- Operation is to create expected data
				BEGIN
					--SET @ExecutionLog = 'IF NOT EXISTS(SELECT 2 FROM [OzTSQLT].[TempExecutionLog] WHERE TestCaseKey = ''' + @testCaseKey + ''') INSERT [OzTSQLT].[TempExecutionLog] (TestCaseName,TestCaseKey,ExecSPWithParam,ExpectedTableHash,ExpectedResult,ActualResult) VALUES (''' + @testCaseName + ''',''' + @testCaseKey + ''',''' + @formattedSqlSPToTest + ''',''' + @tblMD5Hash + ''',@results,'''') ELSE UPDATE [OzTSQLT].[TempExecutionLog] SET ExpectedResult = @results, ExpectedTableHash = ''' + @tblMD5Hash + ''', ExecSPWithParam = ''' + @formattedSqlSPToTest + '''  WHERE TestCaseKey = ''' + @testCaseKey + '''' 
					SET @ExecutionLog = 'IF NOT EXISTS(SELECT 1 FROM [OzTSQLT].[TempExecutionLog] WHERE TestCaseKey = ''' + @testCaseKey + ''') INSERT [OzTSQLT].[TempExecutionLog] (TestCaseName,TestCaseKey,ExecSPWithParam,ExpectedTableHash,ExpectedResult) VALUES (''' + @testCaseName + ''',''' + @testCaseKey + ''',''' + @formattedSqlSPToTest + ''','''  + @tblMD5Hash + ''',''' + CONVERT(NVARCHAR(MAX),@definedExpectedResult) + ''') ELSE UPDATE [OzTSQLT].[TempExecutionLog] SET ExpectedResult = ''' + CONVERT(NVARCHAR(MAX),@definedExpectedResult) + ''', ExecSPWithParam = ''' + @formattedSqlSPToTest + '''  WHERE TestCaseKey = ''' + @testCaseKey + '''' 
					SET @retValue = @ExecutionLog
				END
			ELSE -- Operation is to create actual data
				BEGIN
					SET @ExecutionLog = 'IF NOT EXISTS(SELECT 3 FROM [OzTSQLT].[TempExecutionLog] WHERE TestCaseKey = ''' + @testCaseKey + ''') INSERT [OzTSQLT].[TempExecutionLog] (TestCaseName,TestCaseKey,ExecSPWithParam,ActualTableHash,ActualResult) VALUES (''' + @testCaseName + ''',''' + @testCaseKey + ''','''  + @formattedSqlSPToTest + ''',''' + @tblMD5Hash + ''',@results' + ') ELSE UPDATE [OzTSQLT].[TempExecutionLog] SET ActualResult = @results, ActualTableHash = ''' + @tblMD5Hash + '''  WHERE TestCaseKey = ''' + @testCaseKey + '''' 
					SET @retValue = @execSPViatSQLtResultSetFilter + ' ' + @ExecutionLog
				END
		--END


	RETURN @retValue

END
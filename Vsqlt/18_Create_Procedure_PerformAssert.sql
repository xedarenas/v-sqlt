IF EXISTS(SELECT 1 FROM sys.procedures 
          WHERE object_id = OBJECT_ID(N'VsqltHelper.PerformAssert'))
BEGIN
    DROP PROCEDURE [VsqltHelper].[PerformAssert]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [VsqltHelper].[PerformAssert]
(
@ASPFunctionName NVARCHAR(100),
@ATestCase NVARCHAR(100),
@ATestCaseKey NVARCHAR(100),
@AResultNo NVARCHAR(3) = NULL
)
AS
BEGIN

DECLARE	@ExpectedResult NVARCHAR(MAX),
		@ActualResult NVARCHAR(MAX),
		@ExpectedTableHash VARCHAR(200),
		@ActualTableHash VARCHAR(200),
		@ErrNo INT = 0

SET NOCOUNT ON

BEGIN TRY

	----Perform ASSERT
	SELECT	@ExpectedResult = CONVERT(NVARCHAR(MAX),ExpectedResult),
			@ActualResult = CONVERT(NVARCHAR(MAX),ActualResult),
			@ExpectedTableHash = ExpectedTableHash,
			@ActualTableHash = ActualTableHash
	FROM [OzTSQLT].[TempExecutionLog]
	WHERE TestCaseKey = @ATestCaseKey

	IF (@ExpectedTableHash = @ActualTableHash)
		BEGIN
			EXEC [VsqltHelper].[CreateRunLog] @ATestCaseKey,@ATestCase,@ASPFunctionName,@AResultNo,'SUCCESS',NULL
		END
		ELSE
		BEGIN
			SELECT @ErrNo = 1
			EXEC [VsqltHelper].[CreateRunLog] @ATestCaseKey,@ATestCase,@ASPFunctionName,@AResultNo,'ERROR','Discrepancy between original and current result schema.'
		END

	IF (@ErrNo = 0)
		BEGIN
			IF (isnull(@ExpectedResult,'') = isnull(@ActualResult,''))
				EXEC [VsqltHelper].[CreateRunLog] @ATestCaseKey,@ATestCase,@ASPFunctionName,@AResultNo,'SUCCESS',NULL
			ELSE
				EXEC [VsqltHelper].[CreateRunLog] @ATestCaseKey,@ATestCase,@ASPFunctionName,@AResultNo,'ERROR','Discrepancy between expected and actual result.'
		END

END TRY


BEGIN CATCH
	DECLARE @errorMessage NVARCHAR(1000) = (SELECT ERROR_MESSAGE())
	EXEC [VsqltHelper].[CreateRunLog] @ATestCaseKey,@ATestCase,@ASPFunctionName,@AResultNo,'ERROR',@errorMessage
END CATCH


SET NOCOUNT OFF

END

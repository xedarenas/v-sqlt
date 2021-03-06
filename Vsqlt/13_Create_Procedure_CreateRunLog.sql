IF EXISTS(SELECT 1 FROM sys.procedures 
          WHERE object_id = OBJECT_ID(N'VsqltHelper.CreateRunLog'))
BEGIN
    DROP PROCEDURE [VsqltHelper].[CreateRunLog]
END
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [VsqltHelper].[CreateRunLog]
(
@testCaseKey NVARCHAR(200),
@testCaseName NVARCHAR(200),
@sqlSPToTest NVARCHAR(200),
@resultNo NVARCHAR(3) = NULL,
@status NVARCHAR(10),
@errorMessage NVARCHAR(MAX)
)
AS

BEGIN

SET NOCOUNT ON

IF EXISTS(SELECT 1 FROM [OzTSQLT].[TempExecutionLog] WHERE TestCaseKey = @testCaseKey)
	UPDATE [OzTSQLT].[TempExecutionLog] SET Status = @status, ErrorMessage =@errorMessage WHERE TestCaseKey = @testCaseKey
ELSE
	INSERT [OzTSQLT].[TempExecutionLog] (TestCaseName,TestCaseKey,ExecSPWithParam,ResultNo,Status,ErrorMessage) VALUES (isnull(@testCaseName,''),isnull(@testCaseKey,''),isnull(@sqlSPToTest,''),@resultNo,@status,@errorMessage)

SET NOCOUNT OFF

END
